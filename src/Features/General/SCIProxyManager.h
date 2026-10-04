#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIProxyManager : NSObject

+ (BOOL)isEnabled;
+ (NSDictionary *)proxyDictionary;
+ (void)applyToConfiguration:(NSURLSessionConfiguration *)configuration;
+ (NSString *)statusText;
+ (void)presentConfigurationUI;

@end

NS_ASSUME_NONNULL_END
