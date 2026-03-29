#import "RNPretextModule.h"

#import "RNPretextBindings.h"

#import <React/RCTBridge+Private.h>
#if RNPRETEXT_HAS_CODEGEN
#import <ReactCommon/RCTTurboModule.h>
#endif

using namespace facebook;

namespace {

bool RNPretextInstallBindings(jsi::Runtime &runtime) {
  try {
    rnpretext::install(runtime);
    return true;
  } catch (const std::exception &exception) {
    NSLog(@"RNPretext install failed: %s", exception.what());
    return false;
  } catch (...) {
    NSLog(@"RNPretext install failed with an unknown error.");
    return false;
  }
}

}

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

  return @(RNPretextInstallBindings(*runtime));
}

#if RNPRETEXT_HAS_CODEGEN
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeRNPretextSpecJSI>(params);
}

- (void)installJSIBindingsWithRuntime:(facebook::jsi::Runtime &)runtime
                          callInvoker:(const std::shared_ptr<facebook::react::CallInvoker> &)callInvoker
{
  (void)callInvoker;
  RNPretextInstallBindings(runtime);
}

- (void)installJSIBindingsWithRuntime:(facebook::jsi::Runtime &)runtime
{
  RNPretextInstallBindings(runtime);
}
#endif

@end
