#import "SCISubscriptionManager.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>
#import "Libbox.objc.h"
#import "../../Utils.h"

static NSString * const kSCISubURL = @"sci_subscription_url";
static NSString * const kSCICachedConfig = @"sci_subscription_config";
static NSString * const kSCIServerName = @"sci_subscription_server_name";
static NSString * const kSCIEnabled = @"sci_subscription_enabled";
static const int32_t kSCILocalPort = 2080;

static LibboxCommandServer *sCommandServer = nil;
static BOOL sRunning = NO;
static BOOL sSetupDone = NO;

typedef id (*SCINWEndpointCreateHostFn)(const char *, const char *);
typedef id (*SCINWProxyCreateHTTPConnectFn)(id, id);
typedef void (*SCINWProxySetFailoverFn)(id, BOOL);

@implementation SCISubscriptionManager

+ (NSUserDefaults *)defaults {
    return [NSUserDefaults standardUserDefaults];
}

+ (BOOL)isConfigured {
    return [[[self defaults] stringForKey:kSCICachedConfig] length] > 0;
}

+ (BOOL)isRunning {
    return sRunning;
}

+ (NSString *)statusText {
    if (![[self defaults] boolForKey:kSCIEnabled]) return @"Выключен";
    NSString *name = [[self defaults] stringForKey:kSCIServerName] ?: @"";
    if (sRunning) {
        return name.length ? [NSString stringWithFormat:@"Подключено • %@", name] : @"Подключено";
    }
    if ([self isConfigured]) {
        return name.length ? [NSString stringWithFormat:@"Готово • %@", name] : @"Готово к подключению";
    }
    return @"Подписка не настроена";
}

+ (UIViewController *)topController {
    UIWindow *window = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) { window = candidate; break; }
        }
        if (window) break;
    }
    if (!window) window = [UIApplication sharedApplication].keyWindow;
    UIViewController *vc = window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    if ([vc isKindOfClass:[UINavigationController class]]) {
        vc = ((UINavigationController *)vc).visibleViewController ?: vc;
    }
    return vc;
}

+ (void)showAlert:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [[self topController] presentViewController:alert animated:YES completion:nil];
    });
}

+ (NSString *)decodeBase64Text:(NSString *)input {
    if (!input.length) return nil;
    NSString *clean = [[input stringByReplacingOccurrencesOfString:@"-" withString:@"+"]
                       stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    while (clean.length % 4) clean = [clean stringByAppendingString:@"="];
    NSData *data = [[NSData alloc] initWithBase64EncodedString:clean options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!data.length) return nil;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (NSDictionary *)queryDictionary:(NSURLComponents *)components {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *item in components.queryItems ?: @[]) {
        if (item.name.length) result[item.name] = item.value ?: @"";
    }
    return result;
}

+ (NSDictionary *)transportForQuery:(NSDictionary *)q {
    NSString *type = q[@"type"] ?: q[@"net"] ?: @"";
    if ([type isEqualToString:@"ws"]) {
        NSMutableDictionary *transport = [@{@"type": @"ws"} mutableCopy];
        NSString *path = q[@"path"];
        if (path.length) transport[@"path"] = path;
        NSString *host = q[@"host"];
        if (host.length) transport[@"headers"] = @{@"Host": host};
        return transport;
    }
    if ([type isEqualToString:@"grpc"]) {
        NSMutableDictionary *transport = [@{@"type": @"grpc"} mutableCopy];
        NSString *service = q[@"serviceName"] ?: q[@"service_name"];
        if (service.length) transport[@"service_name"] = service;
        return transport;
    }
    if ([type isEqualToString:@"http"] || [type isEqualToString:@"h2"]) {
        NSMutableDictionary *transport = [@{@"type": @"http"} mutableCopy];
        NSString *path = q[@"path"];
        if (path.length) transport[@"path"] = path;
        NSString *host = q[@"host"];
        if (host.length) transport[@"host"] = @[host];
        return transport;
    }
    return nil;
}

+ (NSDictionary *)tlsForHost:(NSString *)host query:(NSDictionary *)q {
    NSString *security = q[@"security"] ?: @"";
    if (!([security isEqualToString:@"tls"] || [security isEqualToString:@"reality"])) return nil;

    NSMutableDictionary *tls = [@{@"enabled": @YES} mutableCopy];
    NSString *sni = q[@"sni"] ?: q[@"serverName"];
    tls[@"server_name"] = sni.length ? sni : host;

    NSString *fp = q[@"fp"];
    if (fp.length) tls[@"utls"] = @{@"enabled": @YES, @"fingerprint": fp};

    NSString *alpn = q[@"alpn"];
    if (alpn.length) tls[@"alpn"] = [alpn componentsSeparatedByString:@","];

    if ([security isEqualToString:@"reality"]) {
        NSString *pbk = q[@"pbk"] ?: q[@"publicKey"];
        NSString *sid = q[@"sid"] ?: q[@"shortId"];
        NSMutableDictionary *reality = [@{@"enabled": @YES} mutableCopy];
        if (pbk.length) reality[@"public_key"] = pbk;
        if (sid.length) reality[@"short_id"] = sid;
        tls[@"reality"] = reality;
    }
    return tls;
}

+ (NSDictionary *)parseVLESSOrTrojan:(NSString *)link type:(NSString *)type name:(NSString **)nameOut {
    NSURLComponents *c = [NSURLComponents componentsWithString:link];
    if (!c.host.length || !c.port) return nil;

    NSDictionary *q = [self queryDictionary:c];
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    out[@"type"] = type;
    out[@"tag"] = @"vpn-out";
    out[@"server"] = c.host;
    out[@"server_port"] = c.port;
    out[@"domain_resolver"] = @"local";

    if ([type isEqualToString:@"vless"]) {
        if (!c.user.length) return nil;
        out[@"uuid"] = c.user;
        NSString *flow = q[@"flow"];
        if (flow.length) out[@"flow"] = flow;
    } else {
        NSString *password = c.user ?: @"";
        if (!password.length) return nil;
        out[@"password"] = password;
    }

    NSDictionary *tls = [self tlsForHost:c.host query:q];
    if (tls) out[@"tls"] = tls;

    NSDictionary *transport = [self transportForQuery:q];
    if (transport) out[@"transport"] = transport;

    NSString *fragment = c.fragment.stringByRemovingPercentEncoding ?: c.fragment;
    if (nameOut) *nameOut = fragment.length ? fragment : c.host;
    return out;
}

+ (NSDictionary *)parseVMess:(NSString *)link name:(NSString **)nameOut {
    NSString *payload = [link substringFromIndex:[@"vmess://" length]];
    NSString *jsonText = [self decodeBase64Text:payload];
    NSData *data = [jsonText dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *j = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if (![j isKindOfClass:[NSDictionary class]]) return nil;

    NSString *host = [j[@"add"] description];
    NSInteger port = [[j[@"port"] description] integerValue];
    NSString *uuid = [j[@"id"] description];
    if (!host.length || port <= 0 || !uuid.length) return nil;

    NSMutableDictionary *out = [@{
        @"type": @"vmess",
        @"tag": @"vpn-out",
        @"server": host,
        @"server_port": @(port),
        @"uuid": uuid,
        @"security": ([j[@"scy"] description].length ? [j[@"scy"] description] : @"auto"),
        @"domain_resolver": @"local"
    } mutableCopy];

    NSInteger aid = [[j[@"aid"] description] integerValue];
    if (aid > 0) out[@"alter_id"] = @(aid);

    NSMutableDictionary *q = [NSMutableDictionary dictionary];
    NSString *net = [j[@"net"] description];
    if (net.length) q[@"type"] = net;
    for (NSString *key in @[@"path", @"host", @"sni", @"fp"]) {
        NSString *v = [j[key] description];
        if (v.length) q[key] = v;
    }
    NSString *tlsFlag = [j[@"tls"] description];
    if (tlsFlag.length && ![tlsFlag isEqualToString:@"none"]) q[@"security"] = @"tls";

    NSDictionary *tls = [self tlsForHost:host query:q];
    if (tls) out[@"tls"] = tls;
    NSDictionary *transport = [self transportForQuery:q];
    if (transport) out[@"transport"] = transport;

    NSString *name = [j[@"ps"] description];
    if (nameOut) *nameOut = name.length ? name : host;
    return out;
}

+ (NSDictionary *)parseShadowsocks:(NSString *)link name:(NSString **)nameOut {
    NSString *body = [link substringFromIndex:[@"ss://" length]];
    NSString *fragment = nil;
    NSRange hash = [body rangeOfString:@"#"];
    if (hash.location != NSNotFound) {
        fragment = [[body substringFromIndex:hash.location + 1] stringByRemovingPercentEncoding];
        body = [body substringToIndex:hash.location];
    }
    NSRange query = [body rangeOfString:@"?"];
    if (query.location != NSNotFound) body = [body substringToIndex:query.location];

    NSString *userinfo = nil;
    NSString *hostport = nil;
    NSRange at = [body rangeOfString:@"@" options:NSBackwardsSearch];
    if (at.location == NSNotFound) {
        NSString *decoded = [self decodeBase64Text:body];
        at = [decoded rangeOfString:@"@" options:NSBackwardsSearch];
        if (at.location == NSNotFound) return nil;
        userinfo = [decoded substringToIndex:at.location];
        hostport = [decoded substringFromIndex:at.location + 1];
    } else {
        userinfo = [body substringToIndex:at.location];
        hostport = [body substringFromIndex:at.location + 1];
        if (![userinfo containsString:@":"]) {
            NSString *decoded = [self decodeBase64Text:userinfo];
            if (decoded.length) userinfo = decoded;
        }
    }

    NSRange colon = [userinfo rangeOfString:@":"];
    NSRange portColon = [hostport rangeOfString:@":" options:NSBackwardsSearch];
    if (colon.location == NSNotFound || portColon.location == NSNotFound) return nil;

    NSString *method = [userinfo substringToIndex:colon.location];
    NSString *password = [userinfo substringFromIndex:colon.location + 1];
    NSString *host = [hostport substringToIndex:portColon.location];
    NSInteger port = [[hostport substringFromIndex:portColon.location + 1] integerValue];
    if (!method.length || !password.length || !host.length || port <= 0) return nil;

    if (nameOut) *nameOut = fragment.length ? fragment : host;
    return @{
        @"type": @"shadowsocks",
        @"tag": @"vpn-out",
        @"server": host,
        @"server_port": @(port),
        @"method": method,
        @"password": password,
        @"domain_resolver": @"local"
    };
}

+ (NSDictionary *)outboundFromLink:(NSString *)link name:(NSString **)nameOut {
    NSString *trimmed = [link stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmed hasPrefix:@"vless://"]) return [self parseVLESSOrTrojan:trimmed type:@"vless" name:nameOut];
    if ([trimmed hasPrefix:@"trojan://"]) return [self parseVLESSOrTrojan:trimmed type:@"trojan" name:nameOut];
    if ([trimmed hasPrefix:@"vmess://"]) return [self parseVMess:trimmed name:nameOut];
    if ([trimmed hasPrefix:@"ss://"]) return [self parseShadowsocks:trimmed name:nameOut];
    return nil;
}

+ (NSString *)configFromOutbound:(NSDictionary *)outbound {
    NSDictionary *config = @{
        @"log": @{@"level": @"warn", @"timestamp": @NO},
        @"dns": @{@"servers": @[@{@"type": @"local", @"tag": @"local"}]},
        @"inbounds": @[@{
            @"type": @"mixed",
            @"tag": @"instagram-local",
            @"listen": @"127.0.0.1",
            @"listen_port": @(kSCILocalPort)
        }],
        @"outbounds": @[outbound]
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:config options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (NSString *)configFromSubscriptionText:(NSString *)text serverName:(NSString **)serverName error:(NSString **)errorOut {
    NSString *trim = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trim.length) {
        if (errorOut) *errorOut = @"Подписка вернула пустой ответ.";
        return nil;
    }

    // Native sing-box JSON subscriptions/configs.
    if ([trim hasPrefix:@"{"]) {
        NSData *data = [trim dataUsingEncoding:NSUTF8StringEncoding];
        NSMutableDictionary *json = [[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil] mutableCopy];
        if ([json isKindOfClass:[NSMutableDictionary class]]) {
            NSArray *outs = json[@"outbounds"];
            if ([outs isKindOfClass:[NSArray class]] && outs.count) {
                json[@"inbounds"] = @[@{
                    @"type": @"mixed",
                    @"tag": @"instagram-local",
                    @"listen": @"127.0.0.1",
                    @"listen_port": @(kSCILocalPort)
                }];
                if (!json[@"dns"]) json[@"dns"] = @{@"servers": @[@{@"type": @"local", @"tag": @"local"}]};
                NSData *outData = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
                if (serverName) *serverName = @"sing-box подписка";
                return [[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding];
            }
        }
    }

    NSString *decoded = [self decodeBase64Text:trim];
    if (decoded.length && ([decoded containsString:@"://"] || [decoded containsString:@"\n"])) trim = decoded;

    NSArray<NSString *> *lines = [trim componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSInteger supported = 0;
    for (NSString *line in lines) {
        NSString *name = nil;
        NSDictionary *outbound = [self outboundFromLink:line name:&name];
        if (outbound) {
            supported++;
            if (serverName) *serverName = name ?: @"VPN сервер";
            return [self configFromOutbound:outbound];
        }
    }

    if (errorOut) {
        *errorOut = @"Не найден поддерживаемый сервер. Сейчас поддерживаются VLESS, VMess, Trojan, Shadowsocks и готовый sing-box JSON.";
    }
    return nil;
}

+ (BOOL)setupLibbox:(NSError **)error {
    if (sSetupDone) return YES;

    NSString *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    NSString *base = [library stringByAppendingPathComponent:@"SCInstaVPN"];
    NSString *work = [base stringByAppendingPathComponent:@"work"];
    NSString *temp = [base stringByAppendingPathComponent:@"tmp"];

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:base withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:work withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:temp withIntermediateDirectories:YES attributes:nil error:nil];

    LibboxSetupOptions *options = [LibboxSetupOptions new];
    options.basePath = base;
    options.workingPath = work;
    options.tempPath = temp;
    options.appVersion = @"SCInsta";
    options.appMarketingVersion = @"1.0";
    options.logMaxLines = 300;
    options.debug = NO;

    if (!LibboxSetup(options, error)) return NO;
    sSetupDone = YES;
    return YES;
}

+ (BOOL)startConfig:(NSString *)config error:(NSError **)error {
    if (!config.length) return NO;
    if (![self setupLibbox:error]) return NO;

    NSError *checkError = nil;
    if (!LibboxCheckConfig(config, &checkError)) {
        if (error) *error = checkError;
        return NO;
    }

    if (!sCommandServer) {
        sCommandServer = LibboxNewCommandServer(nil, nil, error);
        if (!sCommandServer) return NO;
        if (![sCommandServer start:error]) return NO;
    }

    LibboxOverrideOptions *override = [LibboxOverrideOptions new];
    if (![sCommandServer startOrReloadService:config options:override error:error]) return NO;
    sRunning = YES;
    return YES;
}

+ (void)ensureStarted {
    if (sRunning || ![[self defaults] boolForKey:kSCIEnabled]) return;
    NSString *config = [[self defaults] stringForKey:kSCICachedConfig];
    if (!config.length) return;

    NSError *error = nil;
    if (![self startConfig:config error:&error]) {
        NSLog(@"[SCInsta VPN] start failed: %@", error);
        sRunning = NO;
    }
}

+ (void)stopTunnel {
    if (sCommandServer) {
        NSError *error = nil;
        [sCommandServer closeService:&error];
        if (error) NSLog(@"[SCInsta VPN] stop failed: %@", error);
    }
    sRunning = NO;
}

+ (void *)networkFrameworkHandle {
    static void *handle = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handle = dlopen("/System/Library/Frameworks/Network.framework/Network", RTLD_LAZY | RTLD_LOCAL);
    });
    return handle;
}

+ (BOOL)applyModernLocalProxy:(NSURLSessionConfiguration *)configuration {
    SEL setter = NSSelectorFromString(@"setProxyConfigurations:");
    if (![configuration respondsToSelector:setter]) return NO;

    void *handle = [self networkFrameworkHandle];
    if (!handle) return NO;
    SCINWEndpointCreateHostFn createHost = (SCINWEndpointCreateHostFn)dlsym(handle, "nw_endpoint_create_host");
    SCINWProxyCreateHTTPConnectFn createHTTP = (SCINWProxyCreateHTTPConnectFn)dlsym(handle, "nw_proxy_config_create_http_connect");
    SCINWProxySetFailoverFn setFailover = (SCINWProxySetFailoverFn)dlsym(handle, "nw_proxy_config_set_failover_allowed");
    if (!createHost || !createHTTP) return NO;

    id endpoint = createHost("127.0.0.1", "2080");
    id proxyConfig = endpoint ? createHTTP(endpoint, nil) : nil;
    if (!proxyConfig) return NO;
    if (setFailover) setFailover(proxyConfig, NO);

    ((void (*)(id, SEL, id))objc_msgSend)(configuration, setter, @[proxyConfig]);
    return YES;
}

+ (void)applyTunnelToConfiguration:(NSURLSessionConfiguration *)configuration {
    [self ensureStarted];
    if (!sRunning || !configuration) return;
    if ([self applyModernLocalProxy:configuration]) return;

    configuration.connectionProxyDictionary = @{
        @"HTTPEnable": @YES,
        @"HTTPProxy": @"127.0.0.1",
        @"HTTPPort": @(kSCILocalPort),
        @"HTTPSEnable": @YES,
        @"HTTPSProxy": @"127.0.0.1",
        @"HTTPSPort": @(kSCILocalPort),
        @"ExceptionsList": @[]
    };
}

+ (void)importURL:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url || !url.scheme.length || !url.host.length) {
        [self showAlert:@"Неверная ссылка" message:@"Вставьте полную HTTPS-ссылку на VPN-подписку."];
        return;
    }

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest = 20;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"sing-box/1.14 SCInsta" forHTTPHeaderField:@"User-Agent"];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [self showAlert:@"Не удалось загрузить подписку" message:error.localizedDescription ?: @"Ошибка сети"];
            return;
        }
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSString *name = nil;
        NSString *parseError = nil;
        NSString *config = [self configFromSubscriptionText:text serverName:&name error:&parseError];
        if (!config.length) {
            [self showAlert:@"Подписка не распознана" message:parseError ?: @"Неизвестный формат"];
            return;
        }

        NSError *checkError = nil;
        if (!LibboxCheckConfig(config, &checkError)) {
            [self setupLibbox:nil];
            checkError = nil;
            if (!LibboxCheckConfig(config, &checkError)) {
                [self showAlert:@"Конфигурация не поддерживается" message:checkError.localizedDescription ?: @"sing-box отклонил конфигурацию"];
                return;
            }
        }

        NSUserDefaults *d = [self defaults];
        [d setObject:urlString forKey:kSCISubURL];
        [d setObject:config forKey:kSCICachedConfig];
        [d setObject:name ?: @"VPN сервер" forKey:kSCIServerName];
        [d setBool:YES forKey:kSCIEnabled];
        [d synchronize];

        [self stopTunnel];
        NSError *startError = nil;
        if (![self startConfig:config error:&startError]) {
            [self showAlert:@"Подписка сохранена, но VPN не запустился" message:startError.localizedDescription ?: @"Ошибка запуска sing-box"];
            return;
        }
        [self showAlert:@"VPN-подписка подключена"
                message:[NSString stringWithFormat:@"Сервер: %@\nInstagram теперь использует этот туннель автоматически.", name ?: @"VPN сервер"]];
    }];
    [task resume];
}

+ (void)presentSubscriptionUI {
    NSString *current = [[self defaults] stringForKey:kSCISubURL] ?: @"";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"VPN-подписка"
                                                                   message:@"Вставьте ссылку подписки. Поддерживаются VLESS, VMess, Trojan, Shadowsocks и sing-box JSON. Ссылка хранится только внутри Instagram."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"https://connect.example/...";
        field.text = current;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.keyboardType = UIKeyboardTypeURL;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Импортировать и подключить" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *url = alert.textFields.firstObject.text ?: @"";
        [self importURL:url];
    }]];

    if ([self isConfigured]) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Переподключить" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self stopTunnel];
            [[self defaults] setBool:YES forKey:kSCIEnabled];
            [self ensureStarted];
            [self showAlert:sRunning ? @"Подключено" : @"Не удалось подключиться" message:[self statusText]];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Отключить VPN" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [[self defaults] setBool:NO forKey:kSCIEnabled];
            [[self defaults] synchronize];
            [self stopTunnel];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [[self topController] presentViewController:alert animated:YES completion:nil];
}

+ (void)presentConnectionTest {
    [self ensureStarted];
    if (!sRunning) {
        [self showAlert:@"VPN не подключён" message:@"Сначала импортируйте подписку и подключитесь."];
        return;
    }

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    [self applyTunnelToConfiguration:config];
    config.timeoutIntervalForRequest = 15;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    NSURLSessionDataTask *task = [session dataTaskWithURL:[NSURL URLWithString:@"https://api.ipify.org?format=json"]
                                       completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [self showAlert:@"VPN не отвечает"
                    message:[NSString stringWithFormat:@"%@ (%@ %ld)", error.localizedDescription ?: @"Ошибка", error.domain, (long)error.code]];
            return;
        }
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSString *ip = [json isKindOfClass:[NSDictionary class]] ? json[@"ip"] : nil;
        [self showAlert:@"VPN работает"
                message:[NSString stringWithFormat:@"Внешний IP: %@\nСервер: %@", ip ?: @"не определён", [[self defaults] stringForKey:kSCIServerName] ?: @"VPN"]];
        (void)response;
    }];
    [task resume];
}

@end
