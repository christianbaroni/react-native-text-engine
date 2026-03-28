#import "RNPretextModule.h"

#import "RNPretextBindings.h"

#import <React/RCTBridge+Private.h>

@implementation RNPretextModule

RCT_EXPORT_MODULE(RNPretext)

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

- (void)invalidate {
  rnpretext::cleanup();
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(install) {
  RCTBridge *bridge = [RCTBridge currentBridge];
  RCTCxxBridge *cxxBridge = (RCTCxxBridge *)bridge;
  if (cxxBridge == nil) return @false;

  auto runtime = (facebook::jsi::Runtime *)cxxBridge.runtime;
  if (runtime == nil) return @false;

  try {
    rnpretext::install(*runtime);
    return @true;
  } catch (const std::exception& exception) {
    NSLog(@"RNPretext install failed: %s", exception.what());
    return @false;
  } catch (...) {
    NSLog(@"RNPretext install failed with an unknown error.");
    return @false;
  }
}

@end
