#import <React/RCTShadowView.h>
#import <UIKit/UIKit.h>

@class RCTBridge;

NS_ASSUME_NONNULL_BEGIN

@interface RNTextEngineTextShadowView : RCTShadowView

- (instancetype)initWithBridge:(RCTBridge *)bridge;
- (void)uiManagerWillPerformMounting;

@property (nonatomic, assign) BOOL anchorToCapHeight;
@property (nonatomic, assign) BOOL allowFontScaling;
@property (nonatomic, strong, nullable) UIColor *color;
@property (nonatomic, copy, nullable) NSString *ellipsizeMode;
@property (nonatomic, copy, nullable) NSString *fontFamily;
@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, copy, nullable) NSString *fontStyle;
@property (nonatomic, copy, nullable) NSString *fontWeight;
@property (nonatomic, assign) CGFloat letterSpacing;
@property (nonatomic, assign) CGFloat lineHeight;
@property (nonatomic, assign) NSInteger numberOfLines;
@property (nonatomic, assign) BOOL rnteHasAllowFontScaling;
@property (nonatomic, assign) BOOL rnteHasLetterSpacing;
@property (nonatomic, assign) BOOL rnteHasTabularNumbers;
@property (nonatomic, assign) BOOL tabularNumbers;
@property (nonatomic, assign) NSInteger runCount;
@property (nonatomic, copy, nullable) NSArray<NSString *> *runColors;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *runEnds;
@property (nonatomic, copy, nullable) NSArray<NSString *> *runFontFamilies;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *runFontSizes;
@property (nonatomic, copy, nullable) NSArray<NSString *> *runFontStyles;
@property (nonatomic, copy, nullable) NSArray<NSString *> *runFontWeights;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *runLetterSpacings;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *runLineHeights;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *runStarts;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *runStyleMasks;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *runTabularNumbers;
@property (nonatomic, copy, nullable) NSString *text;
@property (nonatomic, copy, nullable) NSString *textTransform;

@end

NS_ASSUME_NONNULL_END
