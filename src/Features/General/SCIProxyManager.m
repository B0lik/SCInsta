#import "SCIProxyManager.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>
#import "../../Utils.h"

static NSString * const kSCIProxyEnabled = @"sci_proxy_enabled";
static NSString * const kSCIProxyType = @"sci_proxy_type";
static NSString * const kSCIProxyHost = @"sci_proxy_host";
static NSString * const kSCIProxyPort = @"sci_proxy_port";
static NSString * const kSCIProxyUsername = @"sci_proxy_username";
static NSString * const kSCIProxyPassword = @"sci_proxy_password";

typedef id (*SCINWEndpointCreateHostFn)(const char *, const char *);
typedef id (*SCINWProxyCreateHTTPConnectFn)(id, id);
typedef id (*SCINWProxyCreateSOCKSv5Fn)(id);
typedef void (*SCINWProxySetCredentialsFn)(id, const char *, const char *);
typedef void (*SCINWProxySetFailoverFn)(id, BOOL);

@implementation SCIProxyManager

+ (NSUserDefaults *)defaults {
    return [NSUserDefaults standardUserDefaults];
}

+ (BOOL)isEnabled {
    return [[self defaults] boolForKey:kSCIProxyEnabled];
}

+ (NSString *)proxyType {
    return [[self defaults] stringForKey:kSCIProxyType] ?: @"http";
}

+ (NSString *)proxyHost {
    NSString *host = [[self defaults] stringForKey:kSCIProxyHost] ?: @"";
    host = [host stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // Accept accidental scheme prefixes from copied proxy URLs.
    NSArray<NSString *> *prefixes = @[@"http://", @"https://", @"socks5://", @"socks://"];
    for (NSString *prefix in prefixes) {
        if ([[host lowercaseString] hasPrefix:prefix]) {
            host = [host substringFromIndex:prefix.length];
            break;
        }
    }

    // If a full host:port string was pasted into the host field, keep only the host.
    if ([host containsString:@":"] && ![host containsString:@"]"]) {
        NSArray<NSString *> *parts = [host componentsSeparatedByString:@":"];
        if (parts.count == 2 && [parts[1] integerValue] > 0) {
            host = parts[0];
        }
    }

    return host;
}

+ (NSInteger)proxyPort {
    return [[self defaults] integerForKey:kSCIProxyPort];
}

+ (NSDictionary *)proxyDictionary {
    NSString *host = [self proxyHost];
    NSInteger port = [self proxyPort];
    NSString *type = [self proxyType];

    if (![self isEnabled] || host.length == 0 || port <= 0 || port > 65535) {
        return @{};
    }

    NSMutableDictionary *proxy = [NSMutableDictionary dictionary];

    if ([type isEqualToString:@"socks5"]) {
        proxy[@"SOCKSEnable"] = @YES;
        proxy[@"SOCKSProxy"] = host;
        proxy[@"SOCKSPort"] = @(port);
    } else {
        proxy[@"HTTPEnable"] = @YES;
        proxy[@"HTTPProxy"] = host;
        proxy[@"HTTPPort"] = @(port);
        proxy[@"HTTPSEnable"] = @YES;
        proxy[@"HTTPSProxy"] = host;
        proxy[@"HTTPSPort"] = @(port);
    }

    proxy[@"ExceptionsList"] = @[];
    proxy[@"ExcludeSimpleHostnames"] = @NO;
    return proxy;
}

+ (void *)networkFrameworkHandle {
    static void *handle = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handle = dlopen("/System/Library/Frameworks/Network.framework/Network", RTLD_LAZY | RTLD_LOCAL);
    });
    return handle;
}

+ (id)modernProxyConfiguration {
    if (![self isEnabled]) return nil;

    NSString *host = [self proxyHost];
    NSInteger port = [self proxyPort];
    if (host.length == 0 || port <= 0 || port > 65535) return nil;

    void *handle = [self networkFrameworkHandle];
    if (!handle) return nil;

    SCINWEndpointCreateHostFn createHost = (SCINWEndpointCreateHostFn)dlsym(handle, "nw_endpoint_create_host");
    SCINWProxyCreateHTTPConnectFn createHTTP = (SCINWProxyCreateHTTPConnectFn)dlsym(handle, "nw_proxy_config_create_http_connect");
    SCINWProxyCreateSOCKSv5Fn createSOCKS = (SCINWProxyCreateSOCKSv5Fn)dlsym(handle, "nw_proxy_config_create_socksv5");
    SCINWProxySetCredentialsFn setCredentials = (SCINWProxySetCredentialsFn)dlsym(handle, "nw_proxy_config_set_username_and_password");
    SCINWProxySetFailoverFn setFailover = (SCINWProxySetFailoverFn)dlsym(handle, "nw_proxy_config_set_failover_allowed");

    if (!createHost || (!createHTTP && !createSOCKS)) return nil;

    NSString *portString = [NSString stringWithFormat:@"%ld", (long)port];
    id endpoint = createHost(host.UTF8String, portString.UTF8String);
    if (!endpoint) return nil;

    id proxyConfig = nil;
    if ([[self proxyType] isEqualToString:@"socks5"]) {
        if (!createSOCKS) return nil;
        proxyConfig = createSOCKS(endpoint);
    } else {
        if (!createHTTP) return nil;
        proxyConfig = createHTTP(endpoint, nil);
    }

    if (!proxyConfig) return nil;

    NSString *username = [[self defaults] stringForKey:kSCIProxyUsername] ?: @"";
    NSString *password = [[self defaults] stringForKey:kSCIProxyPassword] ?: @"";
    if (setCredentials && username.length > 0) {
        setCredentials(proxyConfig, username.UTF8String, password.length > 0 ? password.UTF8String : NULL);
    }

    // Never silently fall back to a direct connection: otherwise Instagram may
    // appear to work while bypassing the configured proxy.
    if (setFailover) setFailover(proxyConfig, NO);

    return proxyConfig;
}

+ (BOOL)applyModernProxyToConfiguration:(NSURLSessionConfiguration *)configuration {
    if (!configuration || ![self isEnabled]) return NO;

    SEL setter = NSSelectorFromString(@"setProxyConfigurations:");
    if (![configuration respondsToSelector:setter]) return NO;

    id proxyConfig = [self modernProxyConfiguration];
    if (!proxyConfig) return NO;

    NSArray *configs = @[proxyConfig];
    ((void (*)(id, SEL, id))objc_msgSend)(configuration, setter, configs);
    return YES;
}

+ (void)applyToConfiguration:(NSURLSessionConfiguration *)configuration {
    if (!configuration || ![self isEnabled]) return;

    // iOS 17+ / iOS 26 preferred path. This also supports proxy credentials
    // correctly via Network.framework.
    if ([self applyModernProxyToConfiguration:configuration]) {
        return;
    }

    // Fallback for older iOS versions.
    NSDictionary *proxy = [self proxyDictionary];
    if (proxy.count > 0) {
        configuration.connectionProxyDictionary = proxy;
    }
}

+ (NSString *)statusText {
    if (![self isEnabled]) return @"Выключен";

    NSString *host = [self proxyHost];
    NSInteger port = [self proxyPort];
    NSString *typeName = [[self proxyType] isEqualToString:@"socks5"] ? @"SOCKS5" : @"HTTP(S)";

    if (host.length == 0 || port <= 0) {
        return [NSString stringWithFormat:@"%@: не настроен", typeName];
    }

    NSString *api = [NSURLSessionConfiguration instancesRespondToSelector:NSSelectorFromString(@"setProxyConfigurations:")]
        ? @"Network.framework"
        : @"CFNetwork";
    return [NSString stringWithFormat:@"%@: %@:%ld • %@", typeName, host, (long)port, api];
}

+ (UIViewController *)topController {
    UIWindow *window = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }
        if (window) break;
    }
    if (!window) window = [UIApplication sharedApplication].keyWindow;

    UIViewController *vc = window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    if ([vc isKindOfClass:[UINavigationController class]]) {
        vc = ((UINavigationController *)vc).visibleViewController ?: vc;
    }
    if ([vc isKindOfClass:[UITabBarController class]]) {
        vc = ((UITabBarController *)vc).selectedViewController ?: vc;
    }
    return vc;
}

+ (void)saveFields:(NSArray<UITextField *> *)fields type:(NSString *)type {
    NSUserDefaults *d = [self defaults];
    NSString *host = fields.count > 0 ? fields[0].text ?: @"" : @"";
    NSInteger port = fields.count > 1 ? fields[1].text.integerValue : 0;

    [d setObject:type forKey:kSCIProxyType];
    [d setObject:host forKey:kSCIProxyHost];
    [d setInteger:port forKey:kSCIProxyPort];
    if (fields.count > 2) [d setObject:fields[2].text ?: @"" forKey:kSCIProxyUsername];
    if (fields.count > 3) [d setObject:fields[3].text ?: @"" forKey:kSCIProxyPassword];
    [d setBool:(host.length > 0 && port > 0 && port <= 65535) forKey:kSCIProxyEnabled];
    [d synchronize];
}

+ (void)presentConfigurationUI {
    NSUserDefaults *d = [self defaults];
    NSString *currentHost = [d stringForKey:kSCIProxyHost] ?: @"";
    NSInteger currentPort = [d integerForKey:kSCIProxyPort];
    NSString *currentUser = [d stringForKey:kSCIProxyUsername] ?: @"";
    NSString *currentPass = [d stringForKey:kSCIProxyPassword] ?: @"";

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Прокси только для Instagram"
        message:@"Укажите IP/домен БЕЗ http:// или socks5://, затем порт, логин и пароль. На iOS 26 используется современный Network.framework. После сохранения перезапустите Instagram."
        preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"IP или домен, например 1.2.3.4";
        field.text = currentHost;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Порт";
        field.text = currentPort > 0 ? [NSString stringWithFormat:@"%ld", (long)currentPort] : @"";
        field.keyboardType = UIKeyboardTypeNumberPad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Логин (необязательно)";
        field.text = currentUser;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Пароль (необязательно)";
        field.text = currentPass;
        field.secureTextEntry = YES;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Сохранить как HTTP(S)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self saveFields:alert.textFields type:@"http"];
        [SCIUtils showRestartConfirmation];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Сохранить как SOCKS5" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self saveFields:alert.textFields type:@"socks5"];
        [SCIUtils showRestartConfirmation];
    }]];

    if ([self isEnabled]) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Выключить прокси" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [d setBool:NO forKey:kSCIProxyEnabled];
            [d synchronize];
            [SCIUtils showRestartConfirmation];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [[self topController] presentViewController:alert animated:YES completion:nil];
}

+ (NSString *)errorDescription:(NSError *)error {
    if (!error) return @"Неизвестная ошибка";
    return [NSString stringWithFormat:@"%@\n%@ (%@ %ld)",
            error.localizedDescription ?: @"Ошибка соединения",
            error.localizedFailureReason ?: @"",
            error.domain ?: @"",
            (long)error.code];
}

+ (void)showTestResultWithTitle:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [[self topController] presentViewController:alert animated:YES completion:nil];
    });
}

+ (void)presentConnectionTest {
    UIViewController *presenter = [self topController];

    if (![self isEnabled] || [self proxyHost].length == 0 || [self proxyPort] <= 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Прокси не настроен"
                                                                       message:@"Сначала укажите адрес и порт прокси."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [presenter presentViewController:alert animated:YES completion:nil];
        return;
    }

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    [self applyToConfiguration:config];
    config.timeoutIntervalForRequest = 15.0;
    config.timeoutIntervalForResource = 20.0;

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    // First verify that the request really exits through the proxy and show
    // the public IP. Then verify that Instagram itself is reachable.
    NSURL *ipURL = [NSURL URLWithString:@"https://api.ipify.org?format=json"];
    NSURLSessionDataTask *ipTask = [session dataTaskWithURL:ipURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [self showTestResultWithTitle:@"Прокси не отвечает"
                                  message:[self errorDescription:error]];
            return;
        }

        NSString *publicIP = @"не определён";
        if (data.length > 0) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json isKindOfClass:[NSDictionary class]] && [json[@"ip"] isKindOfClass:[NSString class]]) {
                publicIP = json[@"ip"];
            }
        }

        NSURL *instagramURL = [NSURL URLWithString:@"https://www.instagram.com/"];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:instagramURL];
        request.HTTPMethod = @"GET";
        request.timeoutInterval = 15.0;

        NSURLSessionDataTask *instagramTask = [session dataTaskWithRequest:request completionHandler:^(NSData *igData, NSURLResponse *igResponse, NSError *igError) {
            if (igError) {
                NSString *message = [NSString stringWithFormat:@"Прокси-соединение установлено.\nВнешний IP: %@\n\nНо Instagram не открылся:\n%@",
                                     publicIP, [self errorDescription:igError]];
                [self showTestResultWithTitle:@"Прокси работает, Instagram — нет" message:message];
                return;
            }

            NSInteger status = [igResponse isKindOfClass:[NSHTTPURLResponse class]]
                ? ((NSHTTPURLResponse *)igResponse).statusCode
                : 0;
            NSString *message = [NSString stringWithFormat:@"Внешний IP через прокси: %@\nInstagram: HTTP %ld\n\nЕсли этот IP отличается от вашего обычного — трафик теста действительно идёт через прокси.",
                                 publicIP, (long)status];
            [self showTestResultWithTitle:@"Прокси работает" message:message];
            (void)igData;
        }];
        [instagramTask resume];
        (void)response;
    }];
    [ipTask resume];
}

@end
