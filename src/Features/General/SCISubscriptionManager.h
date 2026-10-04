#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCISubscriptionManager : NSObject

+ (BOOL)isConfigured;
+ (BOOL)isRunning;
+ (NSString *)statusText;

+ (void)presentSubscriptionUI;
+ (void)presentConnectionTest;
+ (void)toggleTunnel;
+ (void)resetSettings;

+ (void)stopTunnel;
+ (void)applyTunnelToConfiguration:(NSURLSessionConfiguration *)configuration;

@end

NS_ASSUME_NONNULL_END
