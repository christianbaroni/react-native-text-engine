#import <React/RCTBridgeModule.h>
#import <React/RCTInvalidating.h>

#if __has_include(<RNTextEngineSpec/RNTextEngineSpec.h>)
#import <RNTextEngineSpec/RNTextEngineSpec.h>
#import <ReactCommon/RCTTurboModuleWithJSIBindings.h>
#define RNTEXTENGINE_HAS_CODEGEN 1
#elif __has_include("RNTextEngineSpec.h")
#import "RNTextEngineSpec.h"
#import <ReactCommon/RCTTurboModuleWithJSIBindings.h>
#define RNTEXTENGINE_HAS_CODEGEN 1
#else
#define RNTEXTENGINE_HAS_CODEGEN 0
#endif

#if RNTEXTENGINE_HAS_CODEGEN
@interface RNTextEngineModule : NSObject <NativeRNTextEngineSpec, RCTTurboModuleWithJSIBindings, RCTInvalidating>
#else
@interface RNTextEngineModule : NSObject <RCTBridgeModule, RCTInvalidating>
#endif
@end
