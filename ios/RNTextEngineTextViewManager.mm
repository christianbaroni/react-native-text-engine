#import "RNTextEngineColorUtils.h"
#import "RNTextEngineAttributedTextDisplayView.h"
#import "RNTextEngineTextTransform.h"
#import "RNTextEngineTextShadowView.h"
#ifdef RCT_NEW_ARCH_ENABLED
#import "RNTextEngineTextViewShadowNode.h"
#endif
#import "RNTextEngineTextLayoutMetrics.h"
#import <CoreText/SFNTLayoutTypes.h>
#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTShadowView+Layout.h>
#import <React/RCTUIManager.h>
#import <React/RCTUIManagerObserverCoordinator.h>
#import <React/RCTUIManagerUtils.h>
#ifdef RCT_NEW_ARCH_ENABLED
#import <React/RCTConversions.h>
#import <React/RCTViewComponentView.h>
#import <react/renderer/components/RNTextEngineSpec/Props.h>
#import <react/renderer/components/RNTextEngineSpec/RCTComponentViewHelpers.h>
#endif
#import <React/RCTFont.h>
#import <React/RCTViewManager.h>
#import <React/UIView+React.h>

@interface RNTextEngineTextRunStyle : NSObject
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, copy) NSString *fontFamily;
@property (nonatomic, strong) NSNumber *fontSize;
@property (nonatomic, copy) NSString *fontStyle;
@property (nonatomic, copy) NSString *fontWeight;
@property (nonatomic, strong) NSNumber *letterSpacing;
@property (nonatomic, strong) NSNumber *lineHeight;
@property (nonatomic, strong) NSNumber *tabularNumbers;
@end

@interface RNTextEngineResolvedTextPayload : NSObject
@property (nonatomic, assign) BOOL hasNested;
@property (nonatomic, assign) int64_t payloadHash;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSArray<NSNumber *> *runStarts;
@property (nonatomic, copy) NSArray<NSNumber *> *runEnds;
@property (nonatomic, copy) NSArray<NSNumber *> *runStyleMasks;
@property (nonatomic, copy) NSArray<NSString *> *runColors;
@property (nonatomic, copy) NSArray<NSString *> *runFontFamilies;
@property (nonatomic, copy) NSArray<NSNumber *> *runFontSizes;
@property (nonatomic, copy) NSArray<NSString *> *runFontWeights;
@property (nonatomic, copy) NSArray<NSString *> *runFontStyles;
@property (nonatomic, copy) NSArray<NSNumber *> *runLetterSpacings;
@property (nonatomic, copy) NSArray<NSNumber *> *runLineHeights;
@property (nonatomic, copy) NSArray<NSNumber *> *runTabularNumbers;
@end

@class RNTextEngineTextRun;

@interface RNTextEngineTextView : UIView
@property (nonatomic, assign) BOOL allowFontScaling;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, copy) NSString *ellipsizeMode;
@property (nonatomic, copy) NSString *fontFamily;
@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, copy) NSString *fontStyle;
@property (nonatomic, copy) NSString *fontWeight;
@property (nonatomic, assign) CGFloat letterSpacing;
@property (nonatomic, assign) CGFloat lineHeight;
@property (nonatomic, assign) NSInteger numberOfLines;
@property (nonatomic, assign) BOOL anchorToCapHeight;
@property (nonatomic, assign) BOOL tabularNumbers;
@property (nonatomic, copy) NSArray<NSString *> *runColors;
@property (nonatomic, assign) NSInteger runCount;
@property (nonatomic, copy) NSArray<NSNumber *> *runEnds;
@property (nonatomic, copy) NSArray<NSString *> *runFontFamilies;
@property (nonatomic, copy) NSArray<NSNumber *> *runFontSizes;
@property (nonatomic, copy) NSArray<NSString *> *runFontStyles;
@property (nonatomic, copy) NSArray<NSString *> *runFontWeights;
@property (nonatomic, copy) NSArray<NSNumber *> *runLetterSpacings;
@property (nonatomic, copy) NSArray<NSNumber *> *runLineHeights;
@property (nonatomic, copy) NSArray<NSNumber *> *runStarts;
@property (nonatomic, copy) NSArray<NSNumber *> *runStyleMasks;
@property (nonatomic, copy) NSArray<NSNumber *> *runTabularNumbers;
@property (nonatomic, copy) NSArray<RNTextEngineTextRun *> *runs;
@property (nonatomic, assign) BOOL selectable;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *textAlign;
@property (nonatomic, copy) NSString *textTransform;
@property (nonatomic, strong) RNTextEngineResolvedTextPayload *resolvedNestedPayload;
@property (nonatomic, strong) UIColor *textDecorationColor;
@property (nonatomic, copy) NSString *textDecorationLine;
@property (nonatomic, copy) NSString *textDecorationStyle;
@property (nonatomic, assign) UIEdgeInsets reactBorderInsets;
@property (nonatomic, assign) UIEdgeInsets reactPaddingInsets;
@property (nonatomic, strong) UIColor *textShadowColor;
@property (nonatomic, assign) CGSize textShadowOffset;
@property (nonatomic, assign) CGFloat textShadowRadius;
@property (nonatomic, assign) BOOL rnteIsVirtualTextSpan;
- (void)applyResolvedNestedPayloadMap:(NSDictionary<NSString *, id> *)payloadMap;
@end

#ifdef RCT_NEW_ARCH_ENABLED

using namespace facebook::react;

static NSArray<NSString *> *RNTextEngineNSStringArrayFromVector(const std::vector<std::string> &values)
{
  if (values.empty()) return @[];

  NSMutableArray<NSString *> *array = [NSMutableArray arrayWithCapacity:values.size()];
  for (const std::string &value : values) {
    [array addObject:RCTNSStringFromString(value)];
  }
  return array;
}

static NSArray<NSNumber *> *RNTextEngineNSNumberArrayFromDoubleVector(const std::vector<double> &values)
{
  if (values.empty()) return @[];

  NSMutableArray<NSNumber *> *array = [NSMutableArray arrayWithCapacity:values.size()];
  for (double value : values) {
    [array addObject:@(value)];
  }
  return array;
}

static NSArray<NSNumber *> *RNTextEngineNSNumberArrayFromBoolVector(const std::vector<bool> &values)
{
  if (values.empty()) return @[];

  NSMutableArray<NSNumber *> *array = [NSMutableArray arrayWithCapacity:values.size()];
  for (bool value : values) {
    [array addObject:@(value)];
  }
  return array;
}

static NSArray<NSNumber *> *RNTextEngineNSNumberArrayFromIntVector(const std::vector<int> &values)
{
  if (values.empty()) return @[];

  NSMutableArray<NSNumber *> *array = [NSMutableArray arrayWithCapacity:values.size()];
  for (int value : values) {
    [array addObject:@(value)];
  }
  return array;
}

static RNTextEngineResolvedTextPayload *RNTextEngineResolvedPayloadFromStateData(
    const RNTextEngineTextViewStateData &data)
{
  if (!data.hasNested) return nil;

  RNTextEngineResolvedTextPayload *payload = [RNTextEngineResolvedTextPayload new];
  payload.hasNested = YES;
  payload.payloadHash = data.hash;
  payload.text = RCTNSStringFromString(data.text) ?: @"";
  payload.runStarts = RNTextEngineNSNumberArrayFromIntVector(data.runStarts);
  payload.runEnds = RNTextEngineNSNumberArrayFromIntVector(data.runEnds);
  payload.runStyleMasks = RNTextEngineNSNumberArrayFromIntVector(data.runStyleMasks);
  payload.runColors = RNTextEngineNSStringArrayFromVector(data.runColors);
  payload.runFontFamilies = RNTextEngineNSStringArrayFromVector(data.runFontFamilies);
  payload.runFontSizes = RNTextEngineNSNumberArrayFromDoubleVector(data.runFontSizes);
  payload.runFontWeights = RNTextEngineNSStringArrayFromVector(data.runFontWeights);
  payload.runFontStyles = RNTextEngineNSStringArrayFromVector(data.runFontStyles);
  payload.runLetterSpacings = RNTextEngineNSNumberArrayFromDoubleVector(data.runLetterSpacings);
  payload.runLineHeights = RNTextEngineNSNumberArrayFromDoubleVector(data.runLineHeights);
  payload.runTabularNumbers = RNTextEngineNSNumberArrayFromBoolVector(data.runTabularNumbers);
  return payload;
}

@interface RNTextEngineTextViewComponentView : RCTViewComponentView <RCTRNTextEngineTextViewViewProtocol>
@end

@implementation RNTextEngineTextViewComponentView {
  RNTextEngineTextView *_textView;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNTextEngineTextViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    static const auto defaultProps = std::make_shared<const RNTextEngineTextViewProps>();
    _props = defaultProps;
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.layer.backgroundColor = UIColor.clearColor.CGColor;
    _textView = [[RNTextEngineTextView alloc] initWithFrame:self.bounds];
    _textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_textView];
  }

  return self;
}

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &oldViewProps = static_cast<const RNTextEngineTextViewProps &>(*_props);
  const auto &newViewProps = static_cast<const RNTextEngineTextViewProps &>(*props);

  if (oldViewProps.text != newViewProps.text) {
    _textView.text = RCTNSStringFromString(newViewProps.text);
  }
  if (oldViewProps.color != newViewProps.color) {
    _textView.color = RCTUIColorFromSharedColor(newViewProps.color);
  }
  if (oldViewProps.allowFontScaling != newViewProps.allowFontScaling) {
    _textView.allowFontScaling = newViewProps.allowFontScaling;
  }
  if (oldViewProps.fontFamily != newViewProps.fontFamily) {
    _textView.fontFamily = RCTNSStringFromStringNilIfEmpty(newViewProps.fontFamily);
  }
  if (oldViewProps.fontSize != newViewProps.fontSize) {
    _textView.fontSize = newViewProps.fontSize;
  }
  if (oldViewProps.fontStyle != newViewProps.fontStyle) {
    _textView.fontStyle = RCTNSStringFromStringNilIfEmpty(newViewProps.fontStyle);
  }
  if (oldViewProps.fontWeight != newViewProps.fontWeight) {
    _textView.fontWeight = RCTNSStringFromStringNilIfEmpty(newViewProps.fontWeight);
  }
  if (oldViewProps.letterSpacing != newViewProps.letterSpacing) {
    _textView.letterSpacing = newViewProps.letterSpacing;
  }
  if (oldViewProps.lineHeight != newViewProps.lineHeight) {
    _textView.lineHeight = newViewProps.lineHeight;
  }
  if (oldViewProps.tabularNumbers != newViewProps.tabularNumbers) {
    _textView.tabularNumbers = newViewProps.tabularNumbers;
  }
  if (oldViewProps.anchorToCapHeight != newViewProps.anchorToCapHeight) {
    _textView.anchorToCapHeight = newViewProps.anchorToCapHeight;
  }
  if (oldViewProps.numberOfLines != newViewProps.numberOfLines) {
    _textView.numberOfLines = newViewProps.numberOfLines;
  }
  if (oldViewProps.selectable != newViewProps.selectable) {
    _textView.selectable = newViewProps.selectable;
  }
  if (oldViewProps.ellipsizeMode != newViewProps.ellipsizeMode) {
    _textView.ellipsizeMode = RCTNSStringFromStringNilIfEmpty(newViewProps.ellipsizeMode);
  }
  if (oldViewProps.textAlign != newViewProps.textAlign) {
    _textView.textAlign = RCTNSStringFromStringNilIfEmpty(newViewProps.textAlign);
  }
  if (oldViewProps.textTransform != newViewProps.textTransform) {
    _textView.textTransform = RCTNSStringFromStringNilIfEmpty(newViewProps.textTransform);
  }
  if (oldViewProps.textDecorationColor != newViewProps.textDecorationColor) {
    _textView.textDecorationColor = RCTUIColorFromSharedColor(newViewProps.textDecorationColor);
  }
  if (oldViewProps.textDecorationLine != newViewProps.textDecorationLine) {
    _textView.textDecorationLine = RCTNSStringFromStringNilIfEmpty(newViewProps.textDecorationLine);
  }
  if (oldViewProps.textDecorationStyle != newViewProps.textDecorationStyle) {
    _textView.textDecorationStyle = RCTNSStringFromStringNilIfEmpty(newViewProps.textDecorationStyle);
  }
  if (oldViewProps.textShadowColor != newViewProps.textShadowColor) {
    _textView.textShadowColor = RCTUIColorFromSharedColor(newViewProps.textShadowColor);
  }
  if (oldViewProps.textShadowOffset.width != newViewProps.textShadowOffset.width ||
      oldViewProps.textShadowOffset.height != newViewProps.textShadowOffset.height) {
    _textView.textShadowOffset = CGSizeMake(newViewProps.textShadowOffset.width, newViewProps.textShadowOffset.height);
  }
  if (oldViewProps.textShadowRadius != newViewProps.textShadowRadius) {
    _textView.textShadowRadius = newViewProps.textShadowRadius;
  }
  if (oldViewProps.runCount != newViewProps.runCount) {
    _textView.runCount = newViewProps.runCount;
  }
  if (oldViewProps.runStarts != newViewProps.runStarts) {
    _textView.runStarts = RNTextEngineNSNumberArrayFromDoubleVector(newViewProps.runStarts);
  }
  if (oldViewProps.runEnds != newViewProps.runEnds) {
    _textView.runEnds = RNTextEngineNSNumberArrayFromDoubleVector(newViewProps.runEnds);
  }
  if (oldViewProps.runStyleMasks != newViewProps.runStyleMasks) {
    _textView.runStyleMasks = RNTextEngineNSNumberArrayFromDoubleVector(newViewProps.runStyleMasks);
  }
  if (oldViewProps.runColors != newViewProps.runColors) {
    _textView.runColors = RNTextEngineNSStringArrayFromVector(newViewProps.runColors);
  }
  if (oldViewProps.runFontFamilies != newViewProps.runFontFamilies) {
    _textView.runFontFamilies = RNTextEngineNSStringArrayFromVector(newViewProps.runFontFamilies);
  }
  if (oldViewProps.runFontSizes != newViewProps.runFontSizes) {
    _textView.runFontSizes = RNTextEngineNSNumberArrayFromDoubleVector(newViewProps.runFontSizes);
  }
  if (oldViewProps.runFontStyles != newViewProps.runFontStyles) {
    _textView.runFontStyles = RNTextEngineNSStringArrayFromVector(newViewProps.runFontStyles);
  }
  if (oldViewProps.runFontWeights != newViewProps.runFontWeights) {
    _textView.runFontWeights = RNTextEngineNSStringArrayFromVector(newViewProps.runFontWeights);
  }
  if (oldViewProps.runLetterSpacings != newViewProps.runLetterSpacings) {
    _textView.runLetterSpacings = RNTextEngineNSNumberArrayFromDoubleVector(newViewProps.runLetterSpacings);
  }
  if (oldViewProps.runLineHeights != newViewProps.runLineHeights) {
    _textView.runLineHeights = RNTextEngineNSNumberArrayFromDoubleVector(newViewProps.runLineHeights);
  }
  if (oldViewProps.runTabularNumbers != newViewProps.runTabularNumbers) {
    _textView.runTabularNumbers = RNTextEngineNSNumberArrayFromBoolVector(newViewProps.runTabularNumbers);
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)updateLayoutMetrics:(const LayoutMetrics &)layoutMetrics oldLayoutMetrics:(const LayoutMetrics &)oldLayoutMetrics
{
  [super updateLayoutMetrics:layoutMetrics oldLayoutMetrics:oldLayoutMetrics];

  UIEdgeInsets borderInsets = RCTUIEdgeInsetsFromEdgeInsets(layoutMetrics.borderWidth);
  UIEdgeInsets paddingInsets = RCTUIEdgeInsetsFromEdgeInsets(layoutMetrics.contentInsets - layoutMetrics.borderWidth);
  _textView.reactBorderInsets = borderInsets;
  _textView.reactPaddingInsets = paddingInsets;
  _textView.frame = self.bounds;
}

- (void)updateState:(const State::Shared &)state oldState:(const State::Shared &)oldState
{
  const auto textState = std::static_pointer_cast<const RNTextEngineTextViewShadowNode::ConcreteState>(state);
  _textView.resolvedNestedPayload = textState ? RNTextEngineResolvedPayloadFromStateData(textState->getData()) : nil;
  [super updateState:state oldState:oldState];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _textView.frame = self.bounds;
}

- (void)prepareForRecycle
{
  const Props::Shared oldProps = _props;
  static const auto defaultProps = std::make_shared<const RNTextEngineTextViewProps>();
  [self updateProps:defaultProps oldProps:oldProps];
  _textView.resolvedNestedPayload = nil;
  [super prepareForRecycle];
}

@end

#endif

@implementation RNTextEngineTextRunStyle
@end

@implementation RNTextEngineResolvedTextPayload
@end

@interface RNTextEngineTextRun : NSObject
@property (nonatomic, assign) NSInteger end;
@property (nonatomic, assign) NSInteger start;
@property (nonatomic, strong) RNTextEngineTextRunStyle *style;
@end

@implementation RNTextEngineTextRun
@end

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

static UIEdgeInsets RNTextEngineUIEdgeInsetsAdd(UIEdgeInsets left, UIEdgeInsets right)
{
  return UIEdgeInsetsMake(
      left.top + right.top,
      left.left + right.left,
      left.bottom + right.bottom,
      left.right + right.right);
}

static void RNTextEngineApplyTextDecorationAttributes(
    NSMutableDictionary<NSAttributedStringKey, id> *attributes,
    NSString *textDecorationLine,
    NSString *textDecorationStyle,
    UIColor *textDecorationColor,
    UIColor *effectiveForegroundColor)
{
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

@implementation RNTextEngineTextView {
  RNTextEngineAttributedTextDisplayView *_displayView;
  NSAttributedString *_displayText;
  UITextView *_interactionTextView;
  BOOL _textDisplayDirty;
}

@synthesize anchorToCapHeight = _anchorToCapHeight;

- (void)commonInit
{
  self.backgroundColor = UIColor.clearColor;
  self.clipsToBounds = NO;
  self.opaque = NO;
  self.layer.backgroundColor = UIColor.clearColor.CGColor;
  self.layer.opaque = NO;
  _textDisplayDirty = YES;
  _fontSize = 14;
  _reactBorderInsets = UIEdgeInsetsZero;
  _reactPaddingInsets = UIEdgeInsetsZero;

  _displayView = [[RNTextEngineAttributedTextDisplayView alloc] initWithFrame:self.bounds];
  _displayView.userInteractionEnabled = NO;
  [self addSubview:_displayView];
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    [self commonInit];
  }

  return self;
}

- (BOOL)isOpaque
{
  return NO;
}

- (void)didUpdateReactSubviews
{
  // Nested TextView children are virtual text payload inputs. The display surface
  // is this view's attributed-text owner, so React-managed child view mounting is
  // intentionally disabled.
}

- (void)setRnteIsVirtualTextSpan:(BOOL)rnteIsVirtualTextSpan
{
}

static NSTextAlignment RNTextEngineTextResolveAlignment(NSString *textAlign)
{
  if ([textAlign isEqualToString:@"center"]) return NSTextAlignmentCenter;
  if ([textAlign isEqualToString:@"right"]) return NSTextAlignmentRight;
  if ([textAlign isEqualToString:@"justify"]) return NSTextAlignmentJustified;
  return NSTextAlignmentLeft;
}

- (NSShadow *)resolvedTextShadow
{
  if (_textShadowColor == nil || CGColorGetAlpha(_textShadowColor.CGColor) == 0) {
    return nil;
  }

  NSShadow *shadow = [NSShadow new];
  shadow.shadowBlurRadius = _textShadowRadius;
  shadow.shadowColor = _textShadowColor;
  shadow.shadowOffset = _textShadowOffset;
  return shadow;
}

- (UIFont *)resolveFontWithFamily:(NSString *)fontFamily
                  allowFontScaling:(BOOL)allowFontScaling
                             size:(NSNumber *)size
                           weight:(NSString *)fontWeight
                            style:(NSString *)fontStyle
                  tabularNumbers:(BOOL)tabularNumbers
{
  CGFloat scaleMultiplier = allowFontScaling ? RCTFontSizeMultiplier() : 1;
  UIFont *font =
      [RCTFont updateFont:nil
               withFamily:fontFamily
                    size:size
                   weight:fontWeight
                    style:fontStyle
                  variant:nil
          scaleMultiplier:scaleMultiplier];
  if (!font) font = [UIFont systemFontOfSize:(size ? size.doubleValue : _fontSize) * scaleMultiplier];

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

- (CGFloat)resolveTypographyValue:(CGFloat)value allowFontScaling:(BOOL)allowFontScaling
{
  return allowFontScaling ? value * RCTFontSizeMultiplier() : value;
}

- (NSDictionary<NSAttributedStringKey, id> *)buildRunAttributes:(RNTextEngineTextRunStyle *)style
                                             preScaledTypography:(BOOL)preScaledTypography
{
  BOOL usesTabularNumbers = style.tabularNumbers != nil ? style.tabularNumbers.boolValue : _tabularNumbers;
  BOOL runAllowFontScaling = preScaledTypography ? NO : _allowFontScaling;
  NSNumber *resolvedFontSize =
      style.fontSize != nil ? @([self resolveTypographyValue:style.fontSize.doubleValue allowFontScaling:runAllowFontScaling])
                            : @([self resolveTypographyValue:_fontSize allowFontScaling:_allowFontScaling]);
  UIFont *font =
      [self resolveFontWithFamily:style.fontFamily ?: _fontFamily
                allowFontScaling:NO
                             size:resolvedFontSize
                           weight:style.fontWeight ?: _fontWeight
                            style:style.fontStyle ?: _fontStyle
                  tabularNumbers:usesTabularNumbers];

  NSMutableDictionary<NSAttributedStringKey, id> *attributes =
      [NSMutableDictionary dictionaryWithObject:font forKey:NSFontAttributeName];

  UIColor *color = style.color ?: _color;
  if (color != nil) {
    attributes[NSForegroundColorAttributeName] = color;
  }

  RNTextEngineApplyTextDecorationAttributes(
      attributes,
      _textDecorationLine,
      _textDecorationStyle,
      _textDecorationColor,
      color);

  NSShadow *shadow = [self resolvedTextShadow];
  if (shadow != nil) {
    attributes[NSShadowAttributeName] = shadow;
  }

  NSNumber *letterSpacing = style.letterSpacing;
  if (letterSpacing != nil) {
    attributes[NSKernAttributeName] =
        @([self resolveTypographyValue:letterSpacing.doubleValue allowFontScaling:runAllowFontScaling]);
  } else if (_letterSpacing != 0) {
    attributes[NSKernAttributeName] = @([self resolveTypographyValue:_letterSpacing allowFontScaling:_allowFontScaling]);
  }

  NSNumber *lineHeight = style.lineHeight;
  CGFloat resolvedLineHeight =
      lineHeight != nil ? [self resolveTypographyValue:lineHeight.doubleValue allowFontScaling:runAllowFontScaling]
                        : [self resolveTypographyValue:_lineHeight allowFontScaling:_allowFontScaling];
  NSTextAlignment alignment = RNTextEngineTextResolveAlignment(_textAlign);
  if (resolvedLineHeight > 0 || alignment != NSTextAlignmentLeft) {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    if (resolvedLineHeight > 0) {
      paragraphStyle.minimumLineHeight = resolvedLineHeight;
      paragraphStyle.maximumLineHeight = resolvedLineHeight;
    }
    paragraphStyle.alignment = alignment;
    attributes[NSParagraphStyleAttributeName] = paragraphStyle;
  }

  return attributes;
}

- (NSArray<RNTextEngineTextRun *> *)resolvedRuns
{
  if (_runStarts.count == 0 || _runEnds.count == 0 || _runStyleMasks.count == 0) {
    return _runs;
  }

  NSInteger runCount = _runCount > 0 ? _runCount : MIN(_runStarts.count, MIN(_runEnds.count, _runStyleMasks.count));
  runCount = MIN(runCount, MIN(_runStarts.count, MIN(_runEnds.count, _runStyleMasks.count)));
  NSMutableArray<RNTextEngineTextRun *> *resolvedRuns = [NSMutableArray arrayWithCapacity:runCount];

  for (NSInteger index = 0; index < runCount; index += 1) {
    NSNumber *styleMaskValue = RNTextEngineNumberOrNil(_runStyleMasks[index]);
    NSNumber *startValue = RNTextEngineNumberOrNil(_runStarts[index]);
    NSNumber *endValue = RNTextEngineNumberOrNil(_runEnds[index]);
    if (styleMaskValue == nil || startValue == nil || endValue == nil) continue;

    NSInteger styleMask = styleMaskValue.integerValue;
    RNTextEngineTextRunStyle *style = [RNTextEngineTextRunStyle new];

    if ((styleMask & RNTextEngineRunStyleHasColor) != 0 && index < _runColors.count) {
      NSString *color = RNTextEngineStringOrNil(_runColors[index]);
      if (color != nil) {
        style.color = RNTextEngineResolveColorValue(color);
      }
    }
    if ((styleMask & RNTextEngineRunStyleHasFontFamily) != 0 && index < _runFontFamilies.count) {
      style.fontFamily = RNTextEngineStringOrNil(_runFontFamilies[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasFontSize) != 0 && index < _runFontSizes.count) {
      style.fontSize = RNTextEngineNumberOrNil(_runFontSizes[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasFontStyle) != 0 && index < _runFontStyles.count) {
      style.fontStyle = RNTextEngineStringOrNil(_runFontStyles[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasFontWeight) != 0 && index < _runFontWeights.count) {
      style.fontWeight = RNTextEngineStringOrNil(_runFontWeights[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasLetterSpacing) != 0 && index < _runLetterSpacings.count) {
      style.letterSpacing = RNTextEngineNumberOrNil(_runLetterSpacings[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasLineHeight) != 0 && index < _runLineHeights.count) {
      style.lineHeight = RNTextEngineNumberOrNil(_runLineHeights[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasTabularNumbers) != 0 && index < _runTabularNumbers.count) {
      style.tabularNumbers = RNTextEngineNumberOrNil(_runTabularNumbers[index]);
    }

    RNTextEngineTextRun *run = [RNTextEngineTextRun new];
    run.start = startValue.integerValue;
    run.end = endValue.integerValue;
    run.style = style;
    [resolvedRuns addObject:run];
  }

  return resolvedRuns;
}

- (NSArray<RNTextEngineTextRun *> *)resolvedRunsFromPayload:(RNTextEngineResolvedTextPayload *)payload
{
  if (payload == nil || !payload.hasNested || payload.runStarts.count == 0 || payload.runEnds.count == 0 || payload.runStyleMasks.count == 0) {
    return @[];
  }

  NSInteger runCount = MIN(payload.runStarts.count, MIN(payload.runEnds.count, payload.runStyleMasks.count));
  NSMutableArray<RNTextEngineTextRun *> *resolvedRuns = [NSMutableArray arrayWithCapacity:runCount];
  NSInteger previousEnd = 0;

  for (NSInteger index = 0; index < runCount; index += 1) {
    NSNumber *styleMaskValue = RNTextEngineNumberOrNil(payload.runStyleMasks[index]);
    NSNumber *startValue = RNTextEngineNumberOrNil(payload.runStarts[index]);
    NSNumber *endValue = RNTextEngineNumberOrNil(payload.runEnds[index]);
    if (styleMaskValue == nil || startValue == nil || endValue == nil) continue;

    NSInteger styleMask = styleMaskValue.integerValue;
    NSInteger start = startValue.integerValue;
    NSInteger end = endValue.integerValue;
    if (styleMask == 0 || start < previousEnd || start < 0 || end <= start) continue;

    RNTextEngineTextRunStyle *style = [RNTextEngineTextRunStyle new];
    if ((styleMask & RNTextEngineRunStyleHasColor) != 0 && index < payload.runColors.count) {
      NSString *color = RNTextEngineStringOrNil(payload.runColors[index]);
      if (color != nil) style.color = RNTextEngineResolveColorValue(color);
    }
    if ((styleMask & RNTextEngineRunStyleHasFontFamily) != 0 && index < payload.runFontFamilies.count) {
      style.fontFamily = RNTextEngineStringOrNil(payload.runFontFamilies[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasFontSize) != 0 && index < payload.runFontSizes.count) {
      style.fontSize = RNTextEngineNumberOrNil(payload.runFontSizes[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasFontStyle) != 0 && index < payload.runFontStyles.count) {
      style.fontStyle = RNTextEngineStringOrNil(payload.runFontStyles[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasFontWeight) != 0 && index < payload.runFontWeights.count) {
      style.fontWeight = RNTextEngineStringOrNil(payload.runFontWeights[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasLetterSpacing) != 0 && index < payload.runLetterSpacings.count) {
      style.letterSpacing = RNTextEngineNumberOrNil(payload.runLetterSpacings[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasLineHeight) != 0 && index < payload.runLineHeights.count) {
      style.lineHeight = RNTextEngineNumberOrNil(payload.runLineHeights[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasTabularNumbers) != 0 && index < payload.runTabularNumbers.count) {
      style.tabularNumbers = RNTextEngineNumberOrNil(payload.runTabularNumbers[index]);
    }

    RNTextEngineTextRun *run = [RNTextEngineTextRun new];
    run.start = start;
    run.end = end;
    run.style = style;
    [resolvedRuns addObject:run];
    previousEnd = end;
  }

  return resolvedRuns;
}

- (instancetype)init
{
  return [self initWithFrame:CGRectZero];
}

- (UITextView *)ensureInteractionTextView
{
  if (_interactionTextView != nil) return _interactionTextView;

  _interactionTextView = [[UITextView alloc] initWithFrame:self.bounds];
  RNTextEngineConfigureInteractionTextView(_interactionTextView);
  _interactionTextView.textContainer.maximumNumberOfLines = _numberOfLines > 0 ? _numberOfLines : 0;
  _interactionTextView.textContainer.lineBreakMode = RNTextEngineResolveLineBreakMode(_numberOfLines, _ellipsizeMode);
  _interactionTextView.textAlignment = RNTextEngineTextResolveAlignment(_textAlign);
  [self addSubview:_interactionTextView];
  return _interactionTextView;
}

- (void)discardInteractionTextView
{
  [_interactionTextView removeFromSuperview];
  _interactionTextView = nil;
}

- (void)layoutSubviews
{
  [super layoutSubviews];

  if (_textDisplayDirty) {
    _textDisplayDirty = NO;
    [self updateTextDisplay];
  }

  [self updateContentFrames];
}

- (void)invalidateTextDisplay
{
  _textDisplayDirty = YES;
  [self setNeedsLayout];
}

- (UIEdgeInsets)resolvedCapHeightInsets
{
  if (!_anchorToCapHeight || CGRectIsEmpty(self.bounds)) return UIEdgeInsetsZero;

  CGFloat width = CGRectGetWidth(self.bounds);
  return [_displayView capHeightInsetsForWidth:width];
}

- (UIEdgeInsets)resolvedTextInsets
{
  return RNTextEngineUIEdgeInsetsAdd(_reactBorderInsets, _reactPaddingInsets);
}

- (void)updateContentFrames
{
  UIEdgeInsets textInsets = [self resolvedTextInsets];
  _displayView.contentInsets = textInsets;

  UIEdgeInsets capInsets = [self resolvedCapHeightInsets];
  CGRect displayFrame = self.bounds;
  displayFrame.origin.y -= capInsets.top;
  displayFrame.size.height += capInsets.top + capInsets.bottom;

  _displayView.frame = displayFrame;
  RNTextEngineApplyInteractionTextViewFrame(_interactionTextView, displayFrame, textInsets);
}

- (void)setReactBorderInsets:(UIEdgeInsets)reactBorderInsets
{
  if (UIEdgeInsetsEqualToEdgeInsets(_reactBorderInsets, reactBorderInsets)) return;
  _reactBorderInsets = reactBorderInsets;
  [self setNeedsLayout];
}

- (void)setReactPaddingInsets:(UIEdgeInsets)reactPaddingInsets
{
  if (UIEdgeInsetsEqualToEdgeInsets(_reactPaddingInsets, reactPaddingInsets)) return;
  _reactPaddingInsets = reactPaddingInsets;
  [self setNeedsLayout];
}

- (void)setText:(NSString *)text
{
  _text = [text copy];
  [self invalidateTextDisplay];
}

- (void)setAllowFontScaling:(BOOL)allowFontScaling
{
  if (_allowFontScaling == allowFontScaling) return;
  _allowFontScaling = allowFontScaling;
  [self invalidateTextDisplay];
}

- (void)setColor:(UIColor *)color
{
  _color = color;
  [self invalidateTextDisplay];
}

- (void)setFontFamily:(NSString *)fontFamily
{
  _fontFamily = [fontFamily copy];
  [self invalidateTextDisplay];
}

- (void)setFontSize:(CGFloat)fontSize
{
  _fontSize = fontSize;
  [self invalidateTextDisplay];
}

- (void)setFontStyle:(NSString *)fontStyle
{
  _fontStyle = [fontStyle copy];
  [self invalidateTextDisplay];
}

- (void)setFontWeight:(NSString *)fontWeight
{
  _fontWeight = [fontWeight copy];
  [self invalidateTextDisplay];
}

- (void)setLetterSpacing:(CGFloat)letterSpacing
{
  _letterSpacing = letterSpacing;
  [self invalidateTextDisplay];
}

- (void)setLineHeight:(CGFloat)lineHeight
{
  _lineHeight = lineHeight;
  [self invalidateTextDisplay];
}

- (void)setTabularNumbers:(BOOL)tabularNumbers
{
  if (_tabularNumbers == tabularNumbers) return;
  _tabularNumbers = tabularNumbers;
  [self invalidateTextDisplay];
}

- (void)setAnchorToCapHeight:(BOOL)anchorToCapHeight
{
  if (_anchorToCapHeight == anchorToCapHeight) return;
  _anchorToCapHeight = anchorToCapHeight;
  [self setNeedsLayout];
}

- (void)setRuns:(NSArray<RNTextEngineTextRun *> *)runs
{
  _runs = [runs copy];
  [self invalidateTextDisplay];
}

- (void)setRunStarts:(NSArray<NSNumber *> *)runStarts
{
  _runStarts = [runStarts copy];
  [self invalidateTextDisplay];
}

- (void)setRunCount:(NSInteger)runCount
{
  _runCount = runCount;
  [self invalidateTextDisplay];
}

- (void)setRunEnds:(NSArray<NSNumber *> *)runEnds
{
  _runEnds = [runEnds copy];
  [self invalidateTextDisplay];
}

- (void)setRunStyleMasks:(NSArray<NSNumber *> *)runStyleMasks
{
  _runStyleMasks = [runStyleMasks copy];
  [self invalidateTextDisplay];
}

- (void)setRunColors:(NSArray<NSString *> *)runColors
{
  _runColors = [runColors copy];
  [self invalidateTextDisplay];
}

- (void)setRunFontFamilies:(NSArray<NSString *> *)runFontFamilies
{
  _runFontFamilies = [runFontFamilies copy];
  [self invalidateTextDisplay];
}

- (void)setRunFontSizes:(NSArray<NSNumber *> *)runFontSizes
{
  _runFontSizes = [runFontSizes copy];
  [self invalidateTextDisplay];
}

- (void)setRunFontWeights:(NSArray<NSString *> *)runFontWeights
{
  _runFontWeights = [runFontWeights copy];
  [self invalidateTextDisplay];
}

- (void)setRunFontStyles:(NSArray<NSString *> *)runFontStyles
{
  _runFontStyles = [runFontStyles copy];
  [self invalidateTextDisplay];
}

- (void)setRunLetterSpacings:(NSArray<NSNumber *> *)runLetterSpacings
{
  _runLetterSpacings = [runLetterSpacings copy];
  [self invalidateTextDisplay];
}

- (void)setRunLineHeights:(NSArray<NSNumber *> *)runLineHeights
{
  _runLineHeights = [runLineHeights copy];
  [self invalidateTextDisplay];
}

- (void)setRunTabularNumbers:(NSArray<NSNumber *> *)runTabularNumbers
{
  _runTabularNumbers = [runTabularNumbers copy];
  [self invalidateTextDisplay];
}

- (void)setNumberOfLines:(NSInteger)numberOfLines
{
  _numberOfLines = numberOfLines;
  _displayView.numberOfLines = numberOfLines;
  _interactionTextView.textContainer.maximumNumberOfLines = numberOfLines > 0 ? numberOfLines : 0;
  _interactionTextView.textContainer.lineBreakMode = RNTextEngineResolveLineBreakMode(numberOfLines, _ellipsizeMode);
  [self setNeedsLayout];
}

- (void)setEllipsizeMode:(NSString *)ellipsizeMode
{
  _ellipsizeMode = [ellipsizeMode copy];
  _displayView.ellipsizeMode = _ellipsizeMode;
  _interactionTextView.textContainer.lineBreakMode = RNTextEngineResolveLineBreakMode(_numberOfLines, ellipsizeMode);
  [self setNeedsLayout];
}

- (void)setTextAlign:(NSString *)textAlign
{
  _textAlign = [textAlign copy];
  NSTextAlignment alignment = RNTextEngineTextResolveAlignment(textAlign);
  _interactionTextView.textAlignment = alignment;
  [self invalidateTextDisplay];
}

- (void)setTextTransform:(NSString *)textTransform
{
  if ((_textTransform == textTransform) || [_textTransform isEqualToString:textTransform]) return;
  _textTransform = [textTransform copy];
  [self invalidateTextDisplay];
}

- (void)setResolvedNestedPayload:(RNTextEngineResolvedTextPayload *)resolvedNestedPayload
{
  BOOL nextHasNested = resolvedNestedPayload != nil && resolvedNestedPayload.hasNested;
  BOOL hasCurrentNested = _resolvedNestedPayload != nil && _resolvedNestedPayload.hasNested;
  if (hasCurrentNested == nextHasNested &&
      (!nextHasNested || (_resolvedNestedPayload.payloadHash == resolvedNestedPayload.payloadHash &&
                          [_resolvedNestedPayload.text isEqualToString:resolvedNestedPayload.text]))) {
    return;
  }

  _resolvedNestedPayload = nextHasNested ? resolvedNestedPayload : nil;
  [self invalidateTextDisplay];
}

- (void)applyResolvedNestedPayloadMap:(NSDictionary<NSString *, id> *)payloadMap
{
  if (![payloadMap isKindOfClass:[NSDictionary class]]) {
    self.resolvedNestedPayload = nil;
    return;
  }

  BOOL hasNested = [RCTConvert BOOL:payloadMap[@"hasNested"]];
  if (!hasNested) {
    self.resolvedNestedPayload = nil;
    return;
  }

  RNTextEngineResolvedTextPayload *payload = [RNTextEngineResolvedTextPayload new];
  payload.hasNested = YES;
  payload.payloadHash = [RCTConvert int64_t:payloadMap[@"hash"]];
  payload.text = [RCTConvert NSString:payloadMap[@"text"]] ?: @"";
  payload.runStarts = [RCTConvert NSArray:payloadMap[@"runStarts"]] ?: @[];
  payload.runEnds = [RCTConvert NSArray:payloadMap[@"runEnds"]] ?: @[];
  payload.runStyleMasks = [RCTConvert NSArray:payloadMap[@"runStyleMasks"]] ?: @[];
  payload.runColors = [RCTConvert NSArray:payloadMap[@"runColors"]] ?: @[];
  payload.runFontFamilies = [RCTConvert NSArray:payloadMap[@"runFontFamilies"]] ?: @[];
  payload.runFontSizes = [RCTConvert NSArray:payloadMap[@"runFontSizes"]] ?: @[];
  payload.runFontWeights = [RCTConvert NSArray:payloadMap[@"runFontWeights"]] ?: @[];
  payload.runFontStyles = [RCTConvert NSArray:payloadMap[@"runFontStyles"]] ?: @[];
  payload.runLetterSpacings = [RCTConvert NSArray:payloadMap[@"runLetterSpacings"]] ?: @[];
  payload.runLineHeights = [RCTConvert NSArray:payloadMap[@"runLineHeights"]] ?: @[];
  payload.runTabularNumbers = [RCTConvert NSArray:payloadMap[@"runTabularNumbers"]] ?: @[];
  self.resolvedNestedPayload = payload;
}

- (void)setTextDecorationColor:(UIColor *)textDecorationColor
{
  _textDecorationColor = textDecorationColor;
  [self invalidateTextDisplay];
}

- (void)setTextDecorationLine:(NSString *)textDecorationLine
{
  if ((_textDecorationLine == textDecorationLine) || [_textDecorationLine isEqualToString:textDecorationLine]) return;
  _textDecorationLine = [textDecorationLine copy];
  [self invalidateTextDisplay];
}

- (void)setTextDecorationStyle:(NSString *)textDecorationStyle
{
  if ((_textDecorationStyle == textDecorationStyle) || [_textDecorationStyle isEqualToString:textDecorationStyle]) return;
  _textDecorationStyle = [textDecorationStyle copy];
  [self invalidateTextDisplay];
}

- (void)setTextShadowColor:(UIColor *)textShadowColor
{
  _textShadowColor = textShadowColor;
  [self invalidateTextDisplay];
}

- (void)setTextShadowOffset:(CGSize)textShadowOffset
{
  if (CGSizeEqualToSize(_textShadowOffset, textShadowOffset)) return;
  _textShadowOffset = textShadowOffset;
  [self invalidateTextDisplay];
}

- (void)setTextShadowRadius:(CGFloat)textShadowRadius
{
  if (_textShadowRadius == textShadowRadius) return;
  _textShadowRadius = textShadowRadius;
  [self invalidateTextDisplay];
}

- (void)setSelectable:(BOOL)selectable
{
  if (_selectable == selectable) return;
  _selectable = selectable;
  if (selectable) {
    [self ensureInteractionTextView];
  } else {
    [self discardInteractionTextView];
  }
  [self updateTextDisplay];
  [self setNeedsLayout];
}

- (NSAttributedString *)buildAttributedText
{
  RNTextEngineResolvedTextPayload *nestedPayload = _resolvedNestedPayload;
  BOOL usesResolvedNestedPayload = nestedPayload != nil && nestedPayload.hasNested;
  NSString *text = usesResolvedNestedPayload ? (nestedPayload.text ?: @"") : (_text ?: @"");
  NSDictionary<NSAttributedStringKey, id> *baseAttributes =
      [self buildRunAttributes:[RNTextEngineTextRunStyle new] preScaledTypography:usesResolvedNestedPayload];
  NSArray<RNTextEngineTextRun *> *runs =
      usesResolvedNestedPayload ? [self resolvedRunsFromPayload:nestedPayload] : [self resolvedRuns];
  NSArray<NSNumber *> *runStarts = nil;
  NSArray<NSNumber *> *runEnds = nil;
  if (runs.count > 0) {
    NSMutableArray<NSNumber *> *resolvedStarts = [NSMutableArray arrayWithCapacity:runs.count];
    NSMutableArray<NSNumber *> *resolvedEnds = [NSMutableArray arrayWithCapacity:runs.count];
    for (RNTextEngineTextRun *run in runs) {
      [resolvedStarts addObject:@(run.start)];
      [resolvedEnds addObject:@(run.end)];
    }
    runStarts = resolvedStarts;
    runEnds = resolvedEnds;
  }

  NSString *textTransform = usesResolvedNestedPayload ? nil : _textTransform;
  RNTextEngineTextTransformResult *transformedText = RNTextEngineTransformText(text, textTransform, runStarts, runEnds);
  NSString *resolvedText = transformedText.text ?: @"";
  if (runs.count == 0) {
    NSMutableAttributedString *attributedText =
        [[NSMutableAttributedString alloc] initWithString:resolvedText attributes:baseAttributes];
    UIFont *font = [baseAttributes[NSFontAttributeName] isKindOfClass:[UIFont class]]
        ? (UIFont *)baseAttributes[NSFontAttributeName]
        : nil;
    if (font != nil) {
      RNTextEngineSetUniformCapHeight(attributedText, font.capHeight);
    }
    return attributedText;
  }

  NSMutableAttributedString *attributedText =
      [[NSMutableAttributedString alloc] initWithString:resolvedText attributes:baseAttributes];
  NSInteger previousEnd = 0;

  for (NSInteger index = 0; index < runs.count; index += 1) {
    RNTextEngineTextRun *run = runs[index];
    if (run == nil || run.style == nil) continue;
    NSInteger start = index < transformedText.runStarts.count ? transformedText.runStarts[index].integerValue : run.start;
    NSInteger end = index < transformedText.runEnds.count ? transformedText.runEnds[index].integerValue : run.end;
    if (start < previousEnd || start < 0 || end > resolvedText.length || end <= start) continue;

    [attributedText addAttributes:[self buildRunAttributes:run.style preScaledTypography:usesResolvedNestedPayload]
                            range:NSMakeRange(start, end - start)];
    previousEnd = end;
  }

  RNTextEngineAnnotateUniformCapHeight(attributedText);
  return attributedText;
}

- (void)updateTextDisplay
{
  _displayText = [self buildAttributedText];
  _displayView.attributedText = _displayText ?: [[NSAttributedString alloc] initWithString:@""];
  _displayView.ellipsizeMode = _ellipsizeMode;
  _displayView.numberOfLines = _numberOfLines;
  _displayView.textAlignment = RNTextEngineTextResolveAlignment(_textAlign);
  _displayView.hidden = _selectable;
  if (_selectable) {
    UITextView *interactionTextView = [self ensureInteractionTextView];
    interactionTextView.attributedText = _displayText ?: [[NSAttributedString alloc] initWithString:@""];
    [self bringSubviewToFront:interactionTextView];
  }
  [self setNeedsLayout];
}

@end

@interface RNTextEngineTextViewManager : RCTViewManager <RCTUIManagerObserver>
@end

@implementation RNTextEngineTextViewManager {
  NSHashTable<RNTextEngineTextShadowView *> *_shadowViews;
}

RCT_EXPORT_MODULE(RNTextEngineTextView)

- (void)setBridge:(RCTBridge *)bridge
{
  [super setBridge:bridge];
  _shadowViews = [NSHashTable weakObjectsHashTable];
  [bridge.uiManager.observerCoordinator addObserver:self];
}

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (UIView *)view
{
  return [RNTextEngineTextView new];
}

- (RCTShadowView *)shadowView
{
  RNTextEngineTextShadowView *shadowView = [[RNTextEngineTextShadowView alloc] initWithBridge:self.bridge];
  [_shadowViews addObject:shadowView];
  return shadowView;
}

- (void)uiManagerWillPerformMounting:(__unused RCTUIManager *)uiManager
{
  for (RNTextEngineTextShadowView *shadowView in _shadowViews) {
    [shadowView uiManagerWillPerformMounting];
  }
}

RCT_EXPORT_VIEW_PROPERTY(color, UIColor)
RCT_EXPORT_VIEW_PROPERTY(allowFontScaling, BOOL)
RCT_EXPORT_VIEW_PROPERTY(ellipsizeMode, NSString)
RCT_EXPORT_VIEW_PROPERTY(fontFamily, NSString)
RCT_EXPORT_VIEW_PROPERTY(fontSize, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(fontStyle, NSString)
RCT_EXPORT_VIEW_PROPERTY(fontWeight, NSString)
RCT_EXPORT_VIEW_PROPERTY(letterSpacing, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(lineHeight, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(tabularNumbers, BOOL)
RCT_EXPORT_VIEW_PROPERTY(anchorToCapHeight, BOOL)
RCT_EXPORT_VIEW_PROPERTY(numberOfLines, NSInteger)
RCT_EXPORT_VIEW_PROPERTY(runColors, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runCount, NSInteger)
RCT_EXPORT_VIEW_PROPERTY(runEnds, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runFontFamilies, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runFontSizes, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runFontStyles, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runFontWeights, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runLetterSpacings, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runLineHeights, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runStarts, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runStyleMasks, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runTabularNumbers, NSArray)
RCT_EXPORT_VIEW_PROPERTY(textDecorationColor, UIColor)
RCT_EXPORT_VIEW_PROPERTY(textDecorationLine, NSString)
RCT_EXPORT_VIEW_PROPERTY(textDecorationStyle, NSString)
RCT_EXPORT_VIEW_PROPERTY(textShadowColor, UIColor)
RCT_EXPORT_VIEW_PROPERTY(textShadowOffset, CGSize)
RCT_EXPORT_VIEW_PROPERTY(textShadowRadius, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(rnteIsVirtualTextSpan, BOOL)
RCT_CUSTOM_VIEW_PROPERTY(runs, NSArray, RNTextEngineTextView)
{
  NSArray *rawRuns = json == nil || json == (id)kCFNull ? nil : [RCTConvert NSArray:json];
  if (rawRuns == nil) {
    view.runs = nil;
    return;
  }

  NSMutableArray<RNTextEngineTextRun *> *resolvedRuns = [NSMutableArray arrayWithCapacity:rawRuns.count];
  for (id rawRun in rawRuns) {
    if (![rawRun isKindOfClass:[NSDictionary class]]) continue;
    NSDictionary *runDictionary = (NSDictionary *)rawRun;
    NSNumber *start = [RCTConvert NSNumber:runDictionary[@"start"]];
    NSNumber *end = [RCTConvert NSNumber:runDictionary[@"end"]];
    NSDictionary *styleDictionary = [RCTConvert NSDictionary:runDictionary[@"style"]];
    if (start == nil || end == nil || styleDictionary == nil) continue;

    RNTextEngineTextRunStyle *style = [RNTextEngineTextRunStyle new];
    id rawColor = styleDictionary[@"color"];
    if ([rawColor isKindOfClass:[NSString class]]) {
      style.color = RNTextEngineResolveColorValue((NSString *)rawColor);
    }
    style.fontFamily = [RCTConvert NSString:styleDictionary[@"fontFamily"]];
    style.fontSize = [RCTConvert NSNumber:styleDictionary[@"fontSize"]];
    style.fontStyle = [RCTConvert NSString:styleDictionary[@"fontStyle"]];
    style.fontWeight = [RCTConvert NSString:styleDictionary[@"fontWeight"]];
    style.letterSpacing = [RCTConvert NSNumber:styleDictionary[@"letterSpacing"]];
    style.lineHeight = [RCTConvert NSNumber:styleDictionary[@"lineHeight"]];
    style.tabularNumbers = [RCTConvert NSNumber:styleDictionary[@"tabularNumbers"]];

    RNTextEngineTextRun *run = [RNTextEngineTextRun new];
    run.start = start.integerValue;
    run.end = end.integerValue;
    run.style = style;
    [resolvedRuns addObject:run];
  }

  view.runs = resolvedRuns;
}
RCT_EXPORT_VIEW_PROPERTY(selectable, BOOL)
RCT_EXPORT_VIEW_PROPERTY(text, NSString)
RCT_EXPORT_VIEW_PROPERTY(textAlign, NSString)
RCT_EXPORT_VIEW_PROPERTY(textTransform, NSString)
RCT_EXPORT_SHADOW_PROPERTY(anchorToCapHeight, BOOL)
RCT_CUSTOM_SHADOW_PROPERTY(ellipsizeMode, NSString, RNTextEngineTextShadowView)
{
  view.ellipsizeMode = [RCTConvert NSString:json];
}
RCT_EXPORT_SHADOW_PROPERTY(allowFontScaling, BOOL)
RCT_EXPORT_SHADOW_PROPERTY(color, UIColor)
RCT_EXPORT_SHADOW_PROPERTY(fontFamily, NSString)
RCT_EXPORT_SHADOW_PROPERTY(fontSize, CGFloat)
RCT_EXPORT_SHADOW_PROPERTY(fontStyle, NSString)
RCT_EXPORT_SHADOW_PROPERTY(fontWeight, NSString)
RCT_EXPORT_SHADOW_PROPERTY(letterSpacing, CGFloat)
RCT_EXPORT_SHADOW_PROPERTY(lineHeight, CGFloat)
RCT_EXPORT_SHADOW_PROPERTY(rnteHasAllowFontScaling, BOOL)
RCT_EXPORT_SHADOW_PROPERTY(rnteHasLetterSpacing, BOOL)
RCT_EXPORT_SHADOW_PROPERTY(rnteHasTabularNumbers, BOOL)
RCT_EXPORT_SHADOW_PROPERTY(tabularNumbers, BOOL)
RCT_EXPORT_SHADOW_PROPERTY(numberOfLines, NSInteger)
RCT_EXPORT_SHADOW_PROPERTY(runColors, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runCount, NSInteger)
RCT_EXPORT_SHADOW_PROPERTY(runEnds, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runFontFamilies, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runFontSizes, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runFontStyles, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runFontWeights, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runLetterSpacings, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runLineHeights, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runStarts, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runStyleMasks, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runTabularNumbers, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(text, NSString)
RCT_EXPORT_SHADOW_PROPERTY(textTransform, NSString)

@end
