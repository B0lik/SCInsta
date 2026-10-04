#import <Foundation/Foundation.h>
#import "SCIProxyManager.h"

// App-only proxy integration for URLSession.
// The actual proxy is configured by SCIProxyManager using
// NSURLSessionConfiguration.proxyConfigurations on modern iOS.

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

%end
