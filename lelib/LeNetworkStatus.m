
#import <netinet/in.h>
#import <SystemConfiguration/SystemConfiguration.h>


#import <CoreFoundation/CoreFoundation.h>

#import "lelib.h"
#import "LeNetworkStatus.h"

@interface LeNetworkStatus () {
    
	SCNetworkReachabilityRef reachabilityRef;
}

- (void)callback;

@end

@implementation LeNetworkStatus

static void ReachabilityCallback(SCNetworkReachabilityRef target __attribute__((unused)),
                                 SCNetworkReachabilityFlags flags __attribute__((unused)),
                                 void* info)
{
    LeNetworkStatus* networkStatus = (__bridge LeNetworkStatus*)info;
    [networkStatus callback];
}

-(void)callback
{
    id<LeNetworkStatusDelegete> strongDelegate = self.delegate;
    [strongDelegate networkStatusDidChange:self];
}

- (void)start
{
	SCNetworkReachabilityContext context = {0, (__bridge void*)self, NULL, NULL, NULL};
	if (!SCNetworkReachabilitySetCallback(reachabilityRef, ReachabilityCallback, &context)) return;
    SCNetworkReachabilityScheduleWithRunLoop(reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
}

- (void)stop
{
	if (reachabilityRef == NULL) return;
    SCNetworkReachabilityUnscheduleFromRunLoop(reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
}

- (id)init
{
    self = [super init];
    if (!self) return nil;
    
    struct sockaddr_in addr;
	bzero(&addr, sizeof(addr));
	addr.sin_len = sizeof(addr);
	addr.sin_family = AF_INET;
    
    reachabilityRef = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)&addr);
    if (reachabilityRef != NULL) [self start];
    
    LE_DEBUG(@"created network status instance");
    
    return self;
}

- (void)dealloc
{
	[self stop];
	if (reachabilityRef != NULL) CFRelease(reachabilityRef);
}

- (BOOL)connected
{
    SCNetworkReachabilityFlags flags;
    if (SCNetworkReachabilityGetFlags(reachabilityRef, &flags))
    {
        NetworkStatus status = [self networkStatusForFlags:flags];
        return ((status == ReachableViaWiFi) || (status == ReachableViaWWAN));
    }
    
    return YES;
}

- (NetworkStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags
{
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
    {
        // The target host is not reachable.
        return NotReachable;
    }
    
    NetworkStatus returnValue = NotReachable;
    
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
    {
        /*
         If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
         */
        returnValue = ReachableViaWiFi;
    }
    
    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
         (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
    {
        /*
         ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
         */
        
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
        {
            /*
             ... and no [user] intervention is needed...
             */
            returnValue = ReachableViaWiFi;
        }
    }
    
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
    {
        /*
         ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
         */
        returnValue = ReachableViaWWAN;
    }
    
    return returnValue;
}

-(BOOL)reachabilityForLocalWiFi
{
    struct sockaddr_in localWifiAddress;
    bzero(&localWifiAddress, sizeof(localWifiAddress));
    localWifiAddress.sin_len = sizeof(localWifiAddress);
    localWifiAddress.sin_family = AF_INET;
    
    // IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0.
    localWifiAddress.sin_addr.s_addr = htonl(IN_LINKLOCALNETNUM);
    
    SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&localWifiAddress);
    
    SCNetworkReachabilityFlags flags;
    if (!SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags)) {
        return NotReachable;
    }
    return ([self networkStatusForFlags:flags] == ReachableViaWiFi);
}

@end
