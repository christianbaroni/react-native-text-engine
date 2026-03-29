#import <React/RCTBridgeModule.h>

#if __has_include(<RNPretextSpec/RNPretextSpec.h>)
#import <RNPretextSpec/RNPretextSpec.h>
#import <ReactCommon/RCTTurboModuleWithJSIBindings.h>
#define RNPRETEXT_HAS_CODEGEN 1
#elif __has_include("RNPretextSpec.h")
#import "RNPretextSpec.h"
#import <ReactCommon/RCTTurboModuleWithJSIBindings.h>
#define RNPRETEXT_HAS_CODEGEN 1
#else
#define RNPRETEXT_HAS_CODEGEN 0
#endif

#if RNPRETEXT_HAS_CODEGEN
@interface RNPretextModule : NSObject <NativeRNPretextSpec, RCTTurboModuleWithJSIBindings>
#else
@interface RNPretextModule : NSObject <RCTBridgeModule>
#endif
@end
