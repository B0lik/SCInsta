#import <Foundation/Foundation.h>
#import "SCIProxyManager.h"

// Apply the user-configured proxy to the common NSURLSession configurations
// created by Instagram. This is app-only: it does not install a VPN profile
// and does not affect other apps on the device.

%hook NSURLSessionConfiguration

+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
    NSURLSessionConfiguration *config = %orig;
    [SCIProxyManager applyToConfiguration:config];
    return config;
}

+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration {
    NSURLSessionConfiguration *config = %orig;
    [SCIProxyManager applyToConfiguration:config];
    return config;
}

+ (NSURLSessionConfiguration *)backgroundSessionConfigurationWithIdentifier:(NSString *)identifier {
    NSURLSessionConfiguration *config = %orig(identifier);
    [SCIProxyManager applyToConfiguration:config];
    return config;
}

- (void)setConnectionProxyDictionary:(NSDictionary *)dictionary {
    if ([SCIProxyManager isEnabled]) {
        NSDictionary *proxy = [SCIProxyManager proxyDictionary];
        if (proxy.count > 0) {
            %orig(proxy);
            return;
        }
    }
    %orig(dictionary);
}

%end
