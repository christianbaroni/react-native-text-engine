#pragma once

#import <UIKit/UIKit.h>

#include <optional>
#include <vector>

struct RNTextEngineTextRunStyle {
  UIColor *color{nil};
  NSString *fontFamily{nil};
  std::optional<CGFloat> fontSize;
  NSString *fontStyle{nil};
  NSString *fontWeight{nil};
  std::optional<CGFloat> letterSpacing;
  std::optional<CGFloat> lineHeight;
  std::optional<bool> tabularNumbers;
};

struct RNTextEngineTextRun {
  NSInteger start{0};
  NSInteger end{0};
  RNTextEngineTextRunStyle style;
};

std::vector<RNTextEngineTextRun> RNTextEngineTextRunsFromArrays(
    NSArray<NSNumber *> *runStarts,
    NSArray<NSNumber *> *runEnds,
    NSArray<NSNumber *> *runStyleMasks,
    NSArray<NSString *> *runColors,
    NSArray<NSString *> *runFontFamilies,
    NSArray<NSNumber *> *runFontSizes,
    NSArray<NSString *> *runFontStyles,
    NSArray<NSString *> *runFontWeights,
    NSArray<NSNumber *> *runLetterSpacings,
    NSArray<NSNumber *> *runLineHeights,
    NSArray<NSNumber *> *runTabularNumbers,
    NSInteger requestedCount = 0);

struct RNTextEngineTextAttributes {
  BOOL allowFontScaling{NO};
  CGFloat fontScale{1};
  UIColor *color{nil};
  NSString *fontFamily{nil};
  CGFloat fontSize{14};
  NSString *fontStyle{nil};
  NSString *fontWeight{nil};
  CGFloat letterSpacing{0};
  CGFloat lineHeight{0};
  BOOL tabularNumbers{NO};
  NSString *textAlign{nil};
  UIColor *textDecorationColor{nil};
  NSString *textDecorationLine{nil};
  NSString *textDecorationStyle{nil};
  UIColor *textShadowColor{nil};
  CGSize textShadowOffset{CGSizeZero};
  CGFloat textShadowRadius{0};
};

NSTextAlignment RNTextEngineTextResolveAlignment(NSString *textAlign);
NSAttributedString *RNTextEngineBuildAttributedText(
    NSString *text,
    const RNTextEngineTextAttributes &attributes,
    const std::vector<RNTextEngineTextRun> &runs,
    NSString *textTransform,
    BOOL preScaledTypography,
    CGFloat *emptyLineHeight = nullptr);

#ifdef RCT_NEW_ARCH_ENABLED
#import <react/renderer/components/RNTextEngineSpec/Props.h>

struct RNTextEngineTextContent {
  std::shared_ptr<const facebook::react::RNTextEngineTextViewProps> props;
  NSAttributedString *attributedText{nil};
  NSString *nestedText{nil};
  std::vector<RNTextEngineTextRun> nestedRuns;
  CGFloat fontScale{0};
  NSLocale *locale{nil};
};

RNTextEngineTextAttributes RNTextEngineTextAttributesFromProps(
    const facebook::react::RNTextEngineTextViewProps &props, CGFloat fontScale);
std::vector<RNTextEngineTextRun> RNTextEngineTextRunsFromProps(
    const facebook::react::RNTextEngineTextViewProps &props);
bool RNTextEngineHasSameTextAttributes(
    const facebook::react::RNTextEngineTextViewProps &left,
    const facebook::react::RNTextEngineTextViewProps &right,
    bool inherited = false);
#endif
