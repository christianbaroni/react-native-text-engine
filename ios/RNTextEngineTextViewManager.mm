#import "RNTextEngineColorUtils.h"
#import <CoreText/SFNTLayoutTypes.h>
#import <React/RCTConvert.h>
#ifdef RCT_NEW_ARCH_ENABLED
#import <React/RCTConversions.h>
#import <React/RCTViewComponentView.h>
#import <react/renderer/components/RNTextEngineSpec/ComponentDescriptors.h>
#import <react/renderer/components/RNTextEngineSpec/Props.h>
#import <react/renderer/components/RNTextEngineSpec/RCTComponentViewHelpers.h>
#endif
#import <React/RCTFont.h>
#import <React/RCTViewManager.h>

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

@class RNTextEngineTextRun;

@interface RNTextEngineTextView : UIView
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, copy) NSString *ellipsizeMode;
@property (nonatomic, copy) NSString *fontFamily;
@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, copy) NSString *fontStyle;
@property (nonatomic, copy) NSString *fontWeight;
@property (nonatomic, assign) CGFloat letterSpacing;
@property (nonatomic, assign) CGFloat lineHeight;
@property (nonatomic, assign) NSInteger numberOfLines;
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

- (void)layoutSubviews
{
  [super layoutSubviews];
  _textView.frame = self.bounds;
}

- (void)prepareForRecycle
{
  [super prepareForRecycle];
  _textView.text = @"";
  _textView.color = nil;
  _textView.fontFamily = nil;
  _textView.fontSize = 14;
  _textView.fontStyle = nil;
  _textView.fontWeight = nil;
  _textView.letterSpacing = 0;
  _textView.lineHeight = 0;
  _textView.numberOfLines = 0;
  _textView.selectable = NO;
  _textView.ellipsizeMode = nil;
  _textView.textAlign = nil;
  _textView.runs = nil;
  _textView.runCount = 0;
  _textView.runStarts = nil;
  _textView.runEnds = nil;
  _textView.runStyleMasks = nil;
  _textView.runColors = nil;
  _textView.runFontFamilies = nil;
  _textView.runFontSizes = nil;
  _textView.runFontStyles = nil;
  _textView.runFontWeights = nil;
  _textView.runLetterSpacings = nil;
  _textView.runLineHeights = nil;
  _textView.runTabularNumbers = nil;
}

@end

#endif

@implementation RNTextEngineTextRunStyle
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

@implementation RNTextEngineTextView {
  NSAttributedString *_displayText;
  BOOL _textDisplayDirty;
  UITextView *_textView;
}

- (BOOL)isOpaque
{
  return NO;
}

static NSLineBreakMode RNTextEngineTextResolveLineBreakMode(NSString *ellipsizeMode)
{
  if ([ellipsizeMode isEqualToString:@"head"]) return NSLineBreakByTruncatingHead;
  if ([ellipsizeMode isEqualToString:@"middle"]) return NSLineBreakByTruncatingMiddle;
  if ([ellipsizeMode isEqualToString:@"tail"]) return NSLineBreakByTruncatingTail;
  return NSLineBreakByClipping;
}

static NSAttributedString *RNTextEngineTextSelectionText(NSAttributedString *attributedText)
{
  if (attributedText.length == 0) return attributedText;

  NSMutableAttributedString *selectionText = [[NSMutableAttributedString alloc] initWithAttributedString:attributedText];
  [selectionText addAttribute:NSForegroundColorAttributeName
                        value:UIColor.clearColor
                        range:NSMakeRange(0, selectionText.length)];
  return selectionText;
}

static void RNTextEngineTextDrawAttributedText(
    NSAttributedString *attributedText,
    CGRect bounds,
    NSInteger numberOfLines,
    NSString *ellipsizeMode)
{
  if (attributedText.length == 0 || CGRectIsEmpty(bounds)) return;

  NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:attributedText];
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:bounds.size];
  textContainer.lineFragmentPadding = 0;
  textContainer.lineBreakMode = RNTextEngineTextResolveLineBreakMode(ellipsizeMode);
  textContainer.maximumNumberOfLines = numberOfLines > 0 ? numberOfLines : 0;

  [layoutManager addTextContainer:textContainer];
  [textStorage addLayoutManager:layoutManager];
  [layoutManager ensureLayoutForTextContainer:textContainer];

  NSRange glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
  [layoutManager drawBackgroundForGlyphRange:glyphRange atPoint:bounds.origin];
  [layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:bounds.origin];
}

- (UIFont *)resolveFontWithFamily:(NSString *)fontFamily
                             size:(NSNumber *)size
                           weight:(NSString *)fontWeight
                            style:(NSString *)fontStyle
                  tabularNumbers:(BOOL)tabularNumbers
{
  UIFont *font =
      [RCTFont updateFont:nil
               withFamily:fontFamily
                    size:size
                   weight:fontWeight
                    style:fontStyle
                  variant:nil
          scaleMultiplier:1];
  if (!font) font = [UIFont systemFontOfSize:size ? size.doubleValue : _fontSize];

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

- (NSDictionary<NSAttributedStringKey, id> *)buildRunAttributes:(RNTextEngineTextRunStyle *)style
{
  BOOL usesTabularNumbers = style.tabularNumbers != nil ? style.tabularNumbers.boolValue : NO;
  UIFont *font =
      [self resolveFontWithFamily:style.fontFamily ?: _fontFamily
                             size:style.fontSize ?: @(_fontSize)
                           weight:style.fontWeight ?: _fontWeight
                            style:style.fontStyle ?: _fontStyle
                  tabularNumbers:usesTabularNumbers];

  NSMutableDictionary<NSAttributedStringKey, id> *attributes =
      [NSMutableDictionary dictionaryWithObject:font forKey:NSFontAttributeName];

  UIColor *color = style.color ?: _color;
  if (color != nil) {
    attributes[NSForegroundColorAttributeName] = color;
  }

  NSNumber *letterSpacing = style.letterSpacing;
  if (letterSpacing != nil) {
    attributes[NSKernAttributeName] = letterSpacing;
  } else if (_letterSpacing != 0) {
    attributes[NSKernAttributeName] = @(_letterSpacing);
  }

  NSNumber *lineHeight = style.lineHeight;
  CGFloat resolvedLineHeight = lineHeight != nil ? lineHeight.doubleValue : _lineHeight;
  if (resolvedLineHeight > 0) {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.minimumLineHeight = resolvedLineHeight;
    paragraphStyle.maximumLineHeight = resolvedLineHeight;
    paragraphStyle.alignment = _textView.textAlignment;
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

- (instancetype)init
{
  if ((self = [super init])) {
    self.backgroundColor = UIColor.clearColor;
    self.clearsContextBeforeDrawing = NO;
    self.opaque = NO;
    self.contentMode = UIViewContentModeRedraw;
    self.layer.backgroundColor = UIColor.clearColor.CGColor;
    self.layer.opaque = NO;
    _textDisplayDirty = YES;

    _fontSize = 14;
    _textView = [[UITextView alloc] initWithFrame:self.bounds];
    _textView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _textView.backgroundColor = UIColor.clearColor;
    _textView.opaque = NO;
    _textView.layer.opaque = NO;
    _textView.editable = NO;
    _textView.scrollEnabled = NO;
    _textView.selectable = NO;
    _textView.showsHorizontalScrollIndicator = NO;
    _textView.showsVerticalScrollIndicator = NO;
    _textView.textContainerInset = UIEdgeInsetsZero;
    _textView.textContainer.lineFragmentPadding = 0;
    _textView.hidden = YES;
    _textView.userInteractionEnabled = NO;
    [self addSubview:_textView];
  }

  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _textView.frame = self.bounds;
  _textView.textContainer.size = self.bounds.size;

  if (_textDisplayDirty) {
    _textDisplayDirty = NO;
    [self updateTextDisplay];
  } else {
    [self setNeedsDisplay];
  }
}

- (void)invalidateTextDisplay
{
  _textDisplayDirty = YES;
  [self setNeedsLayout];
}

- (void)setText:(NSString *)text
{
  _text = [text copy];
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
  _textView.textContainer.maximumNumberOfLines = numberOfLines > 0 ? numberOfLines : 0;
  [self setNeedsDisplay];
}

- (void)setEllipsizeMode:(NSString *)ellipsizeMode
{
  _ellipsizeMode = [ellipsizeMode copy];
  _textView.textContainer.lineBreakMode = RNTextEngineTextResolveLineBreakMode(ellipsizeMode);
  [self setNeedsDisplay];
}

- (void)setTextAlign:(NSString *)textAlign
{
  _textAlign = [textAlign copy];
  NSTextAlignment alignment = NSTextAlignmentLeft;

  if ([textAlign isEqualToString:@"center"]) {
    alignment = NSTextAlignmentCenter;
  } else if ([textAlign isEqualToString:@"right"]) {
    alignment = NSTextAlignmentRight;
  } else if ([textAlign isEqualToString:@"justify"]) {
    alignment = NSTextAlignmentJustified;
  }

  _textView.textAlignment = alignment;
  [self invalidateTextDisplay];
}

- (void)setSelectable:(BOOL)selectable
{
  _selectable = selectable;
  _textView.hidden = !selectable;
  _textView.selectable = selectable;
  _textView.userInteractionEnabled = selectable;
  [self setNeedsDisplay];
}

- (NSAttributedString *)buildAttributedText
{
  NSString *text = _text ?: @"";
  NSDictionary<NSAttributedStringKey, id> *baseAttributes = [self buildRunAttributes:[RNTextEngineTextRunStyle new]];
  NSArray<RNTextEngineTextRun *> *runs = [self resolvedRuns];
  if (runs.count == 0) {
    return [[NSAttributedString alloc] initWithString:text attributes:baseAttributes];
  }

  NSMutableAttributedString *attributedText =
      [[NSMutableAttributedString alloc] initWithString:text attributes:baseAttributes];
  NSInteger previousEnd = 0;

  for (RNTextEngineTextRun *run in runs) {
    if (run == nil || run.style == nil) continue;
    NSInteger start = run.start;
    NSInteger end = run.end;
    if (start < previousEnd || start < 0 || end > text.length || end <= start) continue;

    [attributedText addAttributes:[self buildRunAttributes:run.style]
                            range:NSMakeRange(start, end - start)];
    previousEnd = end;
  }

  return attributedText;
}

- (void)updateTextDisplay
{
  _displayText = [self buildAttributedText];
  _textView.attributedText = _selectable ? RNTextEngineTextSelectionText(_displayText ?: [[NSAttributedString alloc] initWithString:@""]) : nil;
  [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
  CGContextRef context = UIGraphicsGetCurrentContext();
  if (context == nullptr) return;

  CGContextSetBlendMode(context, kCGBlendModeCopy);
  CGContextSetFillColorWithColor(context, UIColor.clearColor.CGColor);
  CGContextFillRect(context, self.bounds);
  CGContextSetBlendMode(context, kCGBlendModeNormal);
  RNTextEngineTextDrawAttributedText(_displayText ?: [[NSAttributedString alloc] initWithString:@""], self.bounds, _numberOfLines, _ellipsizeMode);
}

@end

@interface RNTextEngineTextViewManager : RCTViewManager
@end

@implementation RNTextEngineTextViewManager

RCT_EXPORT_MODULE(RNTextEngineTextView)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (UIView *)view
{
  return [RNTextEngineTextView new];
}

RCT_EXPORT_VIEW_PROPERTY(color, UIColor)
RCT_EXPORT_VIEW_PROPERTY(ellipsizeMode, NSString)
RCT_EXPORT_VIEW_PROPERTY(fontFamily, NSString)
RCT_EXPORT_VIEW_PROPERTY(fontSize, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(fontStyle, NSString)
RCT_EXPORT_VIEW_PROPERTY(fontWeight, NSString)
RCT_EXPORT_VIEW_PROPERTY(letterSpacing, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(lineHeight, CGFloat)
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

@end
