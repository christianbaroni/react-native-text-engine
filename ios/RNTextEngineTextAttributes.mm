#import "RNTextEngineTextAttributes.h"
#import "RNTextEngineColorUtils.h"
#import "RNTextEngineTextLayoutMetrics.h"
#import "RNTextEngineTextTransform.h"
#import <CoreText/SFNTLayoutTypes.h>
#import <React/RCTConvert.h>
#import <React/RCTFont.h>
#ifdef RCT_NEW_ARCH_ENABLED
#import <React/RCTConversions.h>
#endif

#include <cmath>

static const NSInteger RNTextEngineRunStyleHasColor = 1 << 0;
static const NSInteger RNTextEngineRunStyleHasFontFamily = 1 << 1;
static const NSInteger RNTextEngineRunStyleHasFontSize = 1 << 2;
static const NSInteger RNTextEngineRunStyleHasFontStyle = 1 << 3;
static const NSInteger RNTextEngineRunStyleHasFontWeight = 1 << 4;
static const NSInteger RNTextEngineRunStyleHasLetterSpacing = 1 << 5;
static const NSInteger RNTextEngineRunStyleHasLineHeight = 1 << 6;
static const NSInteger RNTextEngineRunStyleHasTabularNumbers = 1 << 7;

static NSNumber *RNTextEngineNumberOrNil(id value)
{
  return [value isKindOfClass:[NSNumber class]] ? (NSNumber *)value : nil;
}

static NSString *RNTextEngineStringOrNil(id value)
{
  return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

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
    NSInteger requestedCount)
{
  NSInteger runCount = requestedCount > 0 ? requestedCount : MIN(runStarts.count, MIN(runEnds.count, runStyleMasks.count));
  runCount = MIN(runCount, MIN(runStarts.count, MIN(runEnds.count, runStyleMasks.count)));
  std::vector<RNTextEngineTextRun> resolvedRuns;
  resolvedRuns.reserve(runCount);

  for (NSInteger index = 0; index < runCount; index += 1) {
    NSNumber *styleMaskValue = RNTextEngineNumberOrNil(runStyleMasks[index]);
    NSNumber *startValue = RNTextEngineNumberOrNil(runStarts[index]);
    NSNumber *endValue = RNTextEngineNumberOrNil(runEnds[index]);
    if (styleMaskValue == nil || startValue == nil || endValue == nil) continue;

    NSInteger styleMask = styleMaskValue.integerValue;
    RNTextEngineTextRunStyle style;

    if ((styleMask & RNTextEngineRunStyleHasColor) != 0 && index < runColors.count) {
      NSString *color = RNTextEngineStringOrNil(runColors[index]);
      if (color != nil) {
        style.color = RNTextEngineResolveColorValue(color);
      }
    }
    if ((styleMask & RNTextEngineRunStyleHasFontFamily) != 0 && index < runFontFamilies.count) {
      style.fontFamily = RNTextEngineStringOrNil(runFontFamilies[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasFontSize) != 0 && index < runFontSizes.count) {
      NSNumber *value = RNTextEngineNumberOrNil(runFontSizes[index]);
      if (value != nil) style.fontSize = value.doubleValue;
    }
    if ((styleMask & RNTextEngineRunStyleHasFontStyle) != 0 && index < runFontStyles.count) {
      style.fontStyle = RNTextEngineStringOrNil(runFontStyles[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasFontWeight) != 0 && index < runFontWeights.count) {
      style.fontWeight = RNTextEngineStringOrNil(runFontWeights[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasLetterSpacing) != 0 && index < runLetterSpacings.count) {
      NSNumber *value = RNTextEngineNumberOrNil(runLetterSpacings[index]);
      if (value != nil) style.letterSpacing = value.doubleValue;
    }
    if ((styleMask & RNTextEngineRunStyleHasLineHeight) != 0 && index < runLineHeights.count) {
      NSNumber *value = RNTextEngineNumberOrNil(runLineHeights[index]);
      if (value != nil) style.lineHeight = value.doubleValue;
    }
    if ((styleMask & RNTextEngineRunStyleHasTabularNumbers) != 0 && index < runTabularNumbers.count) {
      NSNumber *value = RNTextEngineNumberOrNil(runTabularNumbers[index]);
      if (value != nil) style.tabularNumbers = value.boolValue;
    }

    RNTextEngineTextRun run;
    run.start = startValue.integerValue;
    run.end = endValue.integerValue;
    run.style = style;
    resolvedRuns.push_back(std::move(run));
  }

  return resolvedRuns;
}

NSTextAlignment RNTextEngineTextResolveAlignment(NSString *textAlign)
{
  if ([textAlign isEqualToString:@"center"]) return NSTextAlignmentCenter;
  if ([textAlign isEqualToString:@"right"]) return NSTextAlignmentRight;
  if ([textAlign isEqualToString:@"justify"]) return NSTextAlignmentJustified;
  if ([textAlign isEqualToString:@"left"]) return NSTextAlignmentLeft;
  return NSTextAlignmentNatural;
}

static UIFont *ResolveFont(NSString *fontFamily, NSNumber *size, NSString *fontWeight,
                           NSString *fontStyle, BOOL tabularNumbers)
{
  UIFont *font =
      [RCTFont updateFont:nil
               withFamily:fontFamily
                    size:size
                   weight:fontWeight
                    style:fontStyle
                  variant:nil
          scaleMultiplier:1];
  if (!font) font = [UIFont systemFontOfSize:(size ? size.doubleValue : 14)];

  if (!tabularNumbers) return font;

  NSDictionary *featureSettings = @{
    UIFontFeatureTypeIdentifierKey: @(kNumberSpacingType),
    UIFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector),
  };
  UIFontDescriptor *descriptor =
      [font.fontDescriptor fontDescriptorByAddingAttributes:@{
        UIFontDescriptorFeatureSettingsAttribute: @[ featureSettings ]
      }];
  return [UIFont fontWithDescriptor:descriptor size:font.pointSize];
}

static void RNTextEngineApplyTextDecorationAttributes(
    NSMutableDictionary<NSAttributedStringKey, id> *attributes,
    NSString *textDecorationLine,
    NSString *textDecorationStyle,
    UIColor *textDecorationColor,
    UIColor *effectiveForegroundColor)
{
  if (textDecorationLine.length == 0 && textDecorationColor == nil) return;
  RCTTextDecorationLineType decorationLine = [RCTConvert RCTTextDecorationLineType:textDecorationLine];
  NSUnderlineStyle decorationStyle = [RCTConvert NSUnderlineStyle:textDecorationStyle];
  BOOL decorationEnabled = NO;

  if (decorationLine == RCTTextDecorationLineTypeUnderline ||
      decorationLine == RCTTextDecorationLineTypeUnderlineStrikethrough) {
    decorationEnabled = YES;
    attributes[NSUnderlineStyleAttributeName] = @(decorationStyle);
  }

  if (decorationLine == RCTTextDecorationLineTypeStrikethrough ||
      decorationLine == RCTTextDecorationLineTypeUnderlineStrikethrough) {
    decorationEnabled = YES;
    attributes[NSStrikethroughStyleAttributeName] = @(decorationStyle);
  }

  if (textDecorationColor != nil || decorationEnabled) {
    UIColor *resolvedDecorationColor = textDecorationColor ?: effectiveForegroundColor ?: UIColor.blackColor;
    attributes[NSUnderlineColorAttributeName] = resolvedDecorationColor;
    attributes[NSStrikethroughColorAttributeName] = resolvedDecorationColor;
  }
}

static NSParagraphStyle *BuildParagraphStyle(CGFloat lineHeight, NSTextAlignment alignment)
{
  if (!(lineHeight > 0) && alignment == NSTextAlignmentNatural) return nil;
  NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
  if (lineHeight > 0) {
    paragraphStyle.minimumLineHeight = lineHeight;
    paragraphStyle.maximumLineHeight = lineHeight;
  }
  paragraphStyle.alignment = alignment;
  return paragraphStyle;
}

static NSMutableDictionary<NSAttributedStringKey, id> *BuildBaseAttributes(
    const RNTextEngineTextAttributes &base)
{
  CGFloat scale = base.allowFontScaling ? base.fontScale : 1;
  UIFont *font = ResolveFont(base.fontFamily, @(base.fontSize * scale),
      base.fontWeight, base.fontStyle, base.tabularNumbers);
  NSMutableDictionary<NSAttributedStringKey, id> *attributes =
      [NSMutableDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
  if (base.color != nil) attributes[NSForegroundColorAttributeName] = base.color;

  RNTextEngineApplyTextDecorationAttributes(attributes, base.textDecorationLine,
      base.textDecorationStyle, base.textDecorationColor, base.color);
  if (base.textShadowColor != nil) {
    NSShadow *shadow = [NSShadow new];
    shadow.shadowBlurRadius = base.textShadowRadius;
    shadow.shadowColor = base.textShadowColor;
    shadow.shadowOffset = base.textShadowOffset;
    attributes[NSShadowAttributeName] = shadow;
  }
  if (base.letterSpacing != 0) attributes[NSKernAttributeName] = @(base.letterSpacing * scale);

  NSParagraphStyle *paragraphStyle = BuildParagraphStyle(
      base.lineHeight * scale, RNTextEngineTextResolveAlignment(base.textAlign));
  if (paragraphStyle != nil) attributes[NSParagraphStyleAttributeName] = paragraphStyle;
  return attributes;
}

static NSDictionary<NSAttributedStringKey, id> *BuildRunOverrides(
    const RNTextEngineTextAttributes &base,
    NSDictionary<NSAttributedStringKey, id> *baseAttributes,
    const RNTextEngineTextRunStyle &style,
    BOOL preScaledTypography)
{
  CGFloat scale = base.allowFontScaling ? base.fontScale : 1;
  CGFloat runScale = preScaledTypography ? 1 : scale;
  CGFloat fontSize = style.fontSize ? *style.fontSize * runScale : base.fontSize * scale;
  BOOL tabularNumbers = style.tabularNumbers.value_or(base.tabularNumbers);
  BOOL changesFont = (style.fontFamily != nil && ![style.fontFamily isEqual:base.fontFamily]) ||
      fontSize != base.fontSize * scale ||
      (style.fontWeight != nil && ![style.fontWeight isEqual:base.fontWeight]) ||
      (style.fontStyle != nil && ![style.fontStyle isEqual:base.fontStyle]) ||
      tabularNumbers != base.tabularNumbers;
  NSMutableDictionary<NSAttributedStringKey, id> *attributes = [NSMutableDictionary new];
  if (changesFont) {
    attributes[NSFontAttributeName] = ResolveFont(style.fontFamily ?: base.fontFamily, @(fontSize),
        style.fontWeight ?: base.fontWeight, style.fontStyle ?: base.fontStyle, tabularNumbers);
  }
  if (style.color != nil) {
    attributes[NSForegroundColorAttributeName] = style.color;
    if (base.textDecorationColor == nil && baseAttributes[NSUnderlineColorAttributeName] != nil) {
      attributes[NSUnderlineColorAttributeName] = style.color;
      attributes[NSStrikethroughColorAttributeName] = style.color;
    }
  }
  if (style.letterSpacing) attributes[NSKernAttributeName] = @(*style.letterSpacing * runScale);
  if (style.lineHeight && *style.lineHeight * runScale != base.lineHeight * scale) {
    attributes[NSParagraphStyleAttributeName] = BuildParagraphStyle(
        *style.lineHeight * runScale, RNTextEngineTextResolveAlignment(base.textAlign))
        ?: NSParagraphStyle.defaultParagraphStyle;
  }
  return attributes;
}

NSAttributedString *RNTextEngineBuildAttributedText(
    NSString *text,
    const RNTextEngineTextAttributes &attributes,
    const std::vector<RNTextEngineTextRun> &runs,
    NSString *textTransform,
    BOOL preScaledTypography,
    CGFloat *emptyLineHeight)
{
  NSMutableDictionary<NSAttributedStringKey, id> *baseAttributes =
      BuildBaseAttributes(attributes);
  if (emptyLineHeight != nullptr) {
    *emptyLineHeight = attributes.lineHeight > 0
        ? attributes.lineHeight * (attributes.allowFontScaling ? attributes.fontScale : 1)
        : ((UIFont *)baseAttributes[NSFontAttributeName]).lineHeight;
  }
  RNTextEngineTextTransformResult *transformedText = nil;
  if (textTransform.length > 0 && ![textTransform isEqualToString:@"none"]) {
    NSMutableArray<NSNumber *> *starts = runs.empty() ? nil : [NSMutableArray arrayWithCapacity:runs.size()];
    NSMutableArray<NSNumber *> *ends = runs.empty() ? nil : [NSMutableArray arrayWithCapacity:runs.size()];
    for (const auto &run : runs) {
      [starts addObject:@(run.start)];
      [ends addObject:@(run.end)];
    }
    transformedText = RNTextEngineTransformText(text, textTransform, starts, ends);
  }
  NSString *resolvedText = transformedText != nil ? transformedText.text : text;
  if (runs.empty()) {
    UIFont *font = baseAttributes[NSFontAttributeName];
    if (font != nil && resolvedText.length > 0) {
      baseAttributes[RNTextEngineUniformCapHeightAttributeName] = @(font.capHeight);
    }
    return [[NSAttributedString alloc] initWithString:resolvedText attributes:baseAttributes];
  }

  NSMutableAttributedString *attributedText =
      [[NSMutableAttributedString alloc] initWithString:resolvedText attributes:baseAttributes];
  NSInteger previousEnd = 0;
  CGFloat baseCapHeight = ((UIFont *)baseAttributes[NSFontAttributeName]).capHeight;
  CGFloat uniformCapHeight = -1;
  BOOL uniform = YES;
  auto includeCapHeight = [&](CGFloat capHeight) {
    if (uniformCapHeight < 0) uniformCapHeight = capHeight;
    else if (std::abs(uniformCapHeight - capHeight) > 0.001) uniform = NO;
  };

  for (size_t index = 0; index < runs.size(); ++index) {
    const auto &run = runs[index];
    NSInteger start = index < transformedText.runStarts.count ? transformedText.runStarts[index].integerValue : run.start;
    NSInteger end = index < transformedText.runEnds.count ? transformedText.runEnds[index].integerValue : run.end;
    if (start < previousEnd || start < 0 || end > resolvedText.length || end <= start) continue;

    auto runAttributes = BuildRunOverrides(attributes, baseAttributes, run.style, preScaledTypography);
    if (start > previousEnd) includeCapHeight(baseCapHeight);
    UIFont *runFont = runAttributes[NSFontAttributeName] ?: baseAttributes[NSFontAttributeName];
    includeCapHeight(runFont.capHeight);
    [attributedText addAttributes:runAttributes range:NSMakeRange(start, end - start)];
    previousEnd = end;
  }

  if (previousEnd < resolvedText.length) includeCapHeight(baseCapHeight);
  if (uniform && uniformCapHeight >= 0) {
    RNTextEngineSetUniformCapHeight(attributedText, uniformCapHeight);
  }
  return [attributedText copy];
}

#ifdef RCT_NEW_ARCH_ENABLED

using namespace facebook::react;

RNTextEngineTextAttributes RNTextEngineTextAttributesFromProps(const RNTextEngineTextViewProps &props, CGFloat fontScale)
{
  return {
      .allowFontScaling = props.allowFontScaling,
      .fontScale = fontScale,
      .color = RCTUIColorFromSharedColor(props.color),
      .fontFamily = RCTNSStringFromStringNilIfEmpty(props.fontFamily),
      .fontSize = props.fontSize > 0 ? props.fontSize : 14,
      .fontStyle = RCTNSStringFromStringNilIfEmpty(props.fontStyle),
      .fontWeight = RCTNSStringFromStringNilIfEmpty(props.fontWeight),
      .letterSpacing = props.letterSpacing,
      .lineHeight = props.lineHeight,
      .tabularNumbers = props.tabularNumbers,
      .textAlign = RCTNSStringFromStringNilIfEmpty(props.textAlign),
      .textDecorationColor = RCTUIColorFromSharedColor(props.textDecorationColor),
      .textDecorationLine = RCTNSStringFromStringNilIfEmpty(props.textDecorationLine),
      .textDecorationStyle = RCTNSStringFromStringNilIfEmpty(props.textDecorationStyle),
      .textShadowColor = RCTUIColorFromSharedColor(props.textShadowColor),
      .textShadowOffset = CGSizeMake(props.textShadowOffset.width, props.textShadowOffset.height),
      .textShadowRadius = props.textShadowRadius,
  };
}

std::vector<RNTextEngineTextRun> RNTextEngineTextRunsFromProps(const RNTextEngineTextViewProps &props)
{
  size_t count = std::min({props.runStarts.size(), props.runEnds.size(), props.runStyleMasks.size()});
  if (props.runCount > 0) count = std::min(count, static_cast<size_t>(props.runCount));
  std::vector<RNTextEngineTextRun> runs;
  runs.reserve(count);
  for (size_t index = 0; index < count; ++index) {
    int mask = static_cast<int>(props.runStyleMasks[index]);
    RNTextEngineTextRunStyle style;
    if ((mask & (1 << 0)) && index < props.runColors.size()) style.color = RNTextEngineResolveColorValue(RCTNSStringFromString(props.runColors[index]));
    if ((mask & (1 << 1)) && index < props.runFontFamilies.size()) style.fontFamily = RCTNSStringFromString(props.runFontFamilies[index]);
    if ((mask & (1 << 2)) && index < props.runFontSizes.size()) style.fontSize = props.runFontSizes[index];
    if ((mask & (1 << 3)) && index < props.runFontStyles.size()) style.fontStyle = RCTNSStringFromString(props.runFontStyles[index]);
    if ((mask & (1 << 4)) && index < props.runFontWeights.size()) style.fontWeight = RCTNSStringFromString(props.runFontWeights[index]);
    if ((mask & (1 << 5)) && index < props.runLetterSpacings.size()) style.letterSpacing = props.runLetterSpacings[index];
    if ((mask & (1 << 6)) && index < props.runLineHeights.size()) style.lineHeight = props.runLineHeights[index];
    if ((mask & (1 << 7)) && index < props.runTabularNumbers.size()) style.tabularNumbers = props.runTabularNumbers[index];
    RNTextEngineTextRun run;
    run.start = static_cast<NSInteger>(props.runStarts[index]);
    run.end = static_cast<NSInteger>(props.runEnds[index]);
    run.style = style;
    runs.push_back(std::move(run));
  }
  return runs;
}

bool RNTextEngineHasSameTextAttributes(
    const RNTextEngineTextViewProps &left, const RNTextEngineTextViewProps &right, bool inherited)
{
  if (&left == &right) return true;
  if (inherited) {
    if (left.rnteHasAllowFontScaling != right.rnteHasAllowFontScaling ||
        left.rnteHasLetterSpacing != right.rnteHasLetterSpacing ||
        left.rnteHasTabularNumbers != right.rnteHasTabularNumbers) return false;
  } else if (left.textAlign != right.textAlign ||
             left.textDecorationColor != right.textDecorationColor ||
             left.textDecorationLine != right.textDecorationLine ||
             left.textDecorationStyle != right.textDecorationStyle ||
             left.textShadowColor != right.textShadowColor ||
             left.textShadowOffset.width != right.textShadowOffset.width ||
             left.textShadowOffset.height != right.textShadowOffset.height ||
             left.textShadowRadius != right.textShadowRadius) {
    return false;
  }
  return left.text == right.text &&
      left.textTransform == right.textTransform &&
      left.allowFontScaling == right.allowFontScaling &&
      left.color == right.color &&
      left.fontFamily == right.fontFamily &&
      left.fontSize == right.fontSize &&
      left.fontStyle == right.fontStyle &&
      left.fontWeight == right.fontWeight &&
      left.letterSpacing == right.letterSpacing &&
      left.lineHeight == right.lineHeight &&
      left.tabularNumbers == right.tabularNumbers &&
      left.runCount == right.runCount &&
      left.runStarts == right.runStarts &&
      left.runEnds == right.runEnds &&
      left.runStyleMasks == right.runStyleMasks &&
      left.runColors == right.runColors &&
      left.runFontFamilies == right.runFontFamilies &&
      left.runFontSizes == right.runFontSizes &&
      left.runFontStyles == right.runFontStyles &&
      left.runFontWeights == right.runFontWeights &&
      left.runLetterSpacings == right.runLetterSpacings &&
      left.runLineHeights == right.runLineHeights &&
      left.runTabularNumbers == right.runTabularNumbers;
}
#endif
