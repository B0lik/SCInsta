#import <Foundation/Foundation.h>
#import "SCISubscriptionManager.h"

// Route Instagram's URLSession traffic through the app-local sing-box tunnel.
// The tunnel itself listens only on 127.0.0.1 and does not affect other apps.

%hook NSURLSessionConfiguration

+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
    NSURLSessionConfiguration *config = %orig;
    [SCISubscriptionManager applyTunnelToConfiguration:config];
    return config;
}

+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration {
    NSURLSessionConfiguration *config = %orig;
    [SCISubscriptionManager applyTunnelToConfiguration:config];
    return config;
}

+ (NSURLSessionConfiguration *)backgroundSessionConfigurationWithIdentifier:(NSString *)identifier {
    NSURLSessionConfiguration *config = %orig(identifier);
    [SCISubscriptionManager applyTunnelToConfiguration:config];
    return config;
}

%end
