
#import <Foundation/Foundation.h>

@class LeNetworkStatus;

typedef enum : NSInteger {
    NotReachable = 0,
    ReachableViaWiFi,
    ReachableViaWWAN
} NetworkStatus;

@protocol LeNetworkStatusDelegete <NSObject>

- (void)networkStatusDidChange:(LeNetworkStatus*)networkStatus;

@end

@interface LeNetworkStatus: NSObject

@property (nonatomic, weak) id<LeNetworkStatusDelegete> delegate;
- (BOOL)connected;
- (BOOL)reachabilityForLocalWiFi;

@end


