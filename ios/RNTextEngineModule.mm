#import "RNTextEngineModule.h"

#import "RNTextEngineBindings.h"

#import <React/RCTBridge+Private.h>
#if RNTEXTENGINE_HAS_CODEGEN
#import <ReactCommon/RCTTurboModule.h>
#endif

using namespace facebook;

namespace {

bool RNTextEngineInstallBindings(jsi::Runtime &runtime) {
  try {
    rntextengine::install(runtime);
    return true;
  } catch (const std::exception &exception) {
    NSLog(@"RNTextEngine install failed: %s", exception.what());
    return false;
  } catch (...) {
    NSLog(@"RNTextEngine install failed with an unknown error.");
    return false;
  }
}

}

@implementation RNTextEngineModule

RCT_EXPORT_MODULE(RNTextEngine)

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

- (void)invalidate {
  rntextengine::cleanup();
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(install) {
  RCTBridge *bridge = [RCTBridge currentBridge];
  RCTCxxBridge *cxxBridge = (RCTCxxBridge *)bridge;
  if (cxxBridge == nil) return @false;

  auto runtime = (facebook::jsi::Runtime *)cxxBridge.runtime;
  if (runtime == nil) return @false;

  return @(RNTextEngineInstallBindings(*runtime));
}

#if RNTEXTENGINE_HAS_CODEGEN
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeRNTextEngineSpecJSI>(params);
}

- (void)installJSIBindingsWithRuntime:(facebook::jsi::Runtime &)runtime
                          callInvoker:(const std::shared_ptr<facebook::react::CallInvoker> &)callInvoker
{
  (void)callInvoker;
  RNTextEngineInstallBindings(runtime);
}

- (void)installJSIBindingsWithRuntime:(facebook::jsi::Runtime &)runtime
{
  RNTextEngineInstallBindings(runtime);
}
#endif

@end
