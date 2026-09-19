#import "RNTextEngineModule.h"

#import "RNTextEngineBindings.h"

#ifndef RCT_NEW_ARCH_ENABLED
#import <React/RCTBridge+Private.h>
#endif
#if RNTEXTENGINE_HAS_CODEGEN
#import <ReactCommon/RCTTurboModule.h>
#endif

#include <atomic>

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

@implementation RNTextEngineModule {
  std::atomic<bool> _installed;
}

RCT_EXPORT_MODULE(RNTextEngine)

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

- (void)invalidate {
  _installed = false;
  rntextengine::cleanup();
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(install) {
#ifdef RCT_NEW_ARCH_ENABLED
  return @(_installed.load());
#else
  RCTBridge *bridge = [RCTBridge currentBridge];
  RCTCxxBridge *cxxBridge = (RCTCxxBridge *)bridge;
  if (cxxBridge == nil) return @false;

  auto runtime = (facebook::jsi::Runtime *)cxxBridge.runtime;
  if (runtime == nil) return @false;

  _installed = RNTextEngineInstallBindings(*runtime);
  return @(_installed.load());
#endif
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
  _installed = RNTextEngineInstallBindings(runtime);
}

- (void)installJSIBindingsWithRuntime:(facebook::jsi::Runtime &)runtime
{
  _installed = RNTextEngineInstallBindings(runtime);
}
#endif

@end
