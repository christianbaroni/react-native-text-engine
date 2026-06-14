#import "RNTextEngineExampleReactNativeFactory.h"

#import <react/featureflags/ReactNativeFeatureFlags.h>
#import <react/featureflags/ReactNativeFeatureFlagsOverridesOSSCanary.h>
#import <react/featureflags/ReactNativeFeatureFlagsOverridesOSSExperimental.h>
#import <react/featureflags/ReactNativeFeatureFlagsOverridesOSSStable.h>

using namespace facebook::react;

namespace {

class RNTextEngineFeatureFlagsOverridesOSSStable final : public ReactNativeFeatureFlagsOverridesOSSStable {
 public:
  bool preventShadowTreeCommitExhaustion() override
  {
    return true;
  }
};

} // namespace

@implementation RNTextEngineExampleReactNativeFactory

- (void)_setUpFeatureFlags:(RCTReleaseLevel)releaseLevel
{
  static BOOL initialized = NO;
  static RCTReleaseLevel chosenReleaseLevel;
  if (!initialized) {
    chosenReleaseLevel = releaseLevel;
    initialized = YES;
  } else if (chosenReleaseLevel != releaseLevel) {
    [NSException raise:@"RCTReactNativeFactory::_setUpFeatureFlags releaseLevel mismatch between React Native instances"
                format:@"The releaseLevel (%li) of the new instance does not match the previous instance's releaseLevel (%li)",
                       releaseLevel,
                       chosenReleaseLevel];
  }

  static dispatch_once_t setupFeatureFlagsToken;
  dispatch_once(&setupFeatureFlagsToken, ^{
    switch (releaseLevel) {
      case Canary:
        ReactNativeFeatureFlags::override(std::make_unique<ReactNativeFeatureFlagsOverridesOSSCanary>());
        break;
      case Experimental:
        ReactNativeFeatureFlags::override(std::make_unique<ReactNativeFeatureFlagsOverridesOSSExperimental>());
        break;
      case Stable:
      default:
        ReactNativeFeatureFlags::override(std::make_unique<RNTextEngineFeatureFlagsOverridesOSSStable>());
        break;
    }
  });
}

@end
