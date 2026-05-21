#import <CoreBluetooth/CoreBluetooth.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wquoted-include-in-framework-header"
#pragma clang diagnostic ignored "-Wincomplete-umbrella"
#import "VeepooBleSDK.framework/Headers/VPBleCentralManage.h"
#pragma clang diagnostic pop

@implementation VPBleCentralManage (WatchProbeRestoreSilencer)

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(centralManager:willRestoreState:)) {
        return NO;
    }
    return [super respondsToSelector:aSelector];
}

@end
