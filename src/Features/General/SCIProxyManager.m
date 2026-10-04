#import "SCIProxyManager.h"
#import <UIKit/UIKit.h>
#import "../../Utils.h"

static NSString * const kSCIProxyEnabled = @"sci_proxy_enabled";
static NSString * const kSCIProxyType = @"sci_proxy_type";
static NSString * const kSCIProxyHost = @"sci_proxy_host";
static NSString * const kSCIProxyPort = @"sci_proxy_port";
static NSString * const kSCIProxyUsername = @"sci_proxy_username";
static NSString * const kSCIProxyPassword = @"sci_proxy_password";

@implementation SCIProxyManager

+ (NSUserDefaults *)defaults {
    return [NSUserDefaults standardUserDefaults];
}

+ (BOOL)isEnabled {
    return [[self defaults] boolForKey:kSCIProxyEnabled];
}

+ (NSDictionary *)proxyDictionary {
    NSString *host = [[self defaults] stringForKey:kSCIProxyHost] ?: @"";
    NSInteger port = [[self defaults] integerForKey:kSCIProxyPort];
    NSString *type = [[self defaults] stringForKey:kSCIProxyType] ?: @"http";
    NSString *username = [[self defaults] stringForKey:kSCIProxyUsername] ?: @"";
    NSString *password = [[self defaults] stringForKey:kSCIProxyPassword] ?: @"";

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

    // CFNetwork recognizes these keys for proxies that support authentication.
    // They are intentionally stored only in this app's sandbox.
    if (username.length > 0) proxy[@"ProxyUsername"] = username;
    if (password.length > 0) proxy[@"ProxyPassword"] = password;

    // Avoid silently bypassing the proxy for common destinations.
    proxy[@"ExceptionsList"] = @[];
    proxy[@"ExcludeSimpleHostnames"] = @NO;

    return proxy;
}

+ (void)applyToConfiguration:(NSURLSessionConfiguration *)configuration {
    if (!configuration || ![self isEnabled]) return;
    NSDictionary *proxy = [self proxyDictionary];
    if (proxy.count == 0) return;
    configuration.connectionProxyDictionary = proxy;
}

+ (NSString *)statusText {
    if (![self isEnabled]) return @"Выключен";

    NSString *host = [[self defaults] stringForKey:kSCIProxyHost] ?: @"";
    NSInteger port = [[self defaults] integerForKey:kSCIProxyPort];
    NSString *type = [[self defaults] stringForKey:kSCIProxyType] ?: @"http";
    NSString *typeName = [type isEqualToString:@"socks5"] ? @"SOCKS5" : @"HTTP(S)";

    if (host.length == 0 || port <= 0) {
        return [NSString stringWithFormat:@"%@: не настроен", typeName];
    }
    return [NSString stringWithFormat:@"%@: %@:%ld", typeName, host, (long)port];
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

+ (void)presentConfigurationUI {
    NSUserDefaults *d = [self defaults];
    NSString *currentHost = [d stringForKey:kSCIProxyHost] ?: @"";
    NSInteger currentPort = [d integerForKey:kSCIProxyPort];
    NSString *currentUser = [d stringForKey:kSCIProxyUsername] ?: @"";
    NSString *currentPass = [d stringForKey:kSCIProxyPassword] ?: @"";

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Прокси только для Instagram"
        message:@"Трафик Instagram будет направляться через указанный прокси. TLS не расшифровывается. После сохранения полностью перезапустите Instagram."
        preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Адрес, например 1.2.3.4";
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

    UIAlertAction *http = [UIAlertAction actionWithTitle:@"Сохранить как HTTP(S)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSArray<UITextField *> *fields = alert.textFields;
        NSString *host = fields.count > 0 ? fields[0].text ?: @"" : @"";
        NSInteger port = fields.count > 1 ? fields[1].text.integerValue : 0;
        [d setObject:@"http" forKey:kSCIProxyType];
        [d setObject:host forKey:kSCIProxyHost];
        [d setInteger:port forKey:kSCIProxyPort];
        if (fields.count > 2) [d setObject:fields[2].text ?: @"" forKey:kSCIProxyUsername];
        if (fields.count > 3) [d setObject:fields[3].text ?: @"" forKey:kSCIProxyPassword];
        [d setBool:(host.length > 0 && port > 0) forKey:kSCIProxyEnabled];
        [d synchronize];
        [SCIUtils showRestartConfirmation];
    }];

    UIAlertAction *socks = [UIAlertAction actionWithTitle:@"Сохранить как SOCKS5" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSArray<UITextField *> *fields = alert.textFields;
        NSString *host = fields.count > 0 ? fields[0].text ?: @"" : @"";
        NSInteger port = fields.count > 1 ? fields[1].text.integerValue : 0;
        [d setObject:@"socks5" forKey:kSCIProxyType];
        [d setObject:host forKey:kSCIProxyHost];
        [d setInteger:port forKey:kSCIProxyPort];
        if (fields.count > 2) [d setObject:fields[2].text ?: @"" forKey:kSCIProxyUsername];
        if (fields.count > 3) [d setObject:fields[3].text ?: @"" forKey:kSCIProxyPassword];
        [d setBool:(host.length > 0 && port > 0) forKey:kSCIProxyEnabled];
        [d synchronize];
        [SCIUtils showRestartConfirmation];
    }];

    UIAlertAction *disable = [UIAlertAction actionWithTitle:@"Выключить прокси" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [d setBool:NO forKey:kSCIProxyEnabled];
        [d synchronize];
        [SCIUtils showRestartConfirmation];
    }];

    [alert addAction:http];
    [alert addAction:socks];
    if ([self isEnabled]) [alert addAction:disable];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];

    [[self topController] presentViewController:alert animated:YES completion:nil];
}

+ (void)presentConnectionTest {
    UIViewController *presenter = [self topController];

    if (![self isEnabled] || [self proxyDictionary].count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Прокси не настроен"
                                                                       message:@"Сначала укажите адрес и порт прокси."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [presenter presentViewController:alert animated:YES completion:nil];
        return;
    }

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    [self applyToConfiguration:config];
    config.timeoutIntervalForRequest = 12.0;
    config.timeoutIntervalForResource = 15.0;

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.instagram.com/"]];
    request.HTTPMethod = @"GET";
    request.timeoutInterval = 12.0;

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *title = nil;
            NSString *message = nil;

            if (error) {
                title = @"Прокси не отвечает";
                message = error.localizedDescription ?: @"Не удалось выполнить запрос через прокси.";
            } else if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
                title = (status >= 200 && status < 500) ? @"Прокси работает" : @"Ответ получен";
                message = [NSString stringWithFormat:@"Instagram ответил с HTTP-кодом %ld.", (long)status];
            } else {
                title = @"Прокси работает";
                message = @"Соединение с Instagram через прокси установлено.";
            }

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                           message:message
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [[self topController] presentViewController:alert animated:YES completion:nil];
        });
    }];
    [task resume];
}

@end
