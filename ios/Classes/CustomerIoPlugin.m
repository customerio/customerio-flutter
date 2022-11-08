#import "CustomerIoPlugin.h"
#if __has_include(<customer_io/customer_io-Swift.h>)
#import <customer_io/customer_io-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "customer_io-Swift.h"
#endif

@implementation CustomerIoPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftCustomerIoPlugin registerWithRegistrar:registrar];
}
@end
