#import "RNPretextColorUtils.h"
#import <CoreText/SFNTLayoutTypes.h>
#import <React/RCTConvert.h>
#import <React/RCTFont.h>
#import <React/RCTViewManager.h>

@interface RNPretextTextRunStyle : NSObject
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, copy) NSString *fontFamily;
@property (nonatomic, strong) NSNumber *fontSize;
@property (nonatomic, copy) NSString *fontStyle;
@property (nonatomic, copy) NSString *fontWeight;
@property (nonatomic, strong) NSNumber *letterSpacing;
@property (nonatomic, strong) NSNumber *lineHeight;
@property (nonatomic, strong) NSNumber *tabularNumbers;
@end

@implementation RNPretextTextRunStyle
@end

@interface RNPretextTextRun : NSObject
@property (nonatomic, assign) NSInteger end;
@property (nonatomic, assign) NSInteger start;
@property (nonatomic, strong) RNPretextTextRunStyle *style;
@end

@implementation RNPretextTextRun
@end

static const NSInteger RNPretextRunStyleHasColor = 1 << 0;
static const NSInteger RNPretextRunStyleHasFontFamily = 1 << 1;
static const NSInteger RNPretextRunStyleHasFontSize = 1 << 2;
static const NSInteger RNPretextRunStyleHasFontStyle = 1 << 3;
static const NSInteger RNPretextRunStyleHasFontWeight = 1 << 4;
static const NSInteger RNPretextRunStyleHasLetterSpacing = 1 << 5;
static const NSInteger RNPretextRunStyleHasLineHeight = 1 << 6;
static const NSInteger RNPretextRunStyleHasTabularNumbers = 1 << 7;

static NSNumber *RNPretextNumberOrNil(id value)
{
  return [value isKindOfClass:[NSNumber class]] ? (NSNumber *)value : nil;
}

static NSString *RNPretextStringOrNil(id value)
{
  return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

@interface RNPretextTextView : UIView
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
@property (nonatomic, copy) NSArray<RNPretextTextRun *> *runs;
@property (nonatomic, assign) BOOL selectable;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *textAlign;
@end

@implementation RNPretextTextView {
  UILabel *_label;
  BOOL _textDisplayDirty;
  UITextView *_textView;
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

- (NSDictionary<NSAttributedStringKey, id> *)buildRunAttributes:(RNPretextTextRunStyle *)style
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
    paragraphStyle.alignment = _label.textAlignment;
    attributes[NSParagraphStyleAttributeName] = paragraphStyle;
  }

  return attributes;
}

- (NSArray<RNPretextTextRun *> *)resolvedRuns
{
  if (_runStarts.count == 0 || _runEnds.count == 0 || _runStyleMasks.count == 0) {
    return _runs;
  }

  NSInteger runCount = _runCount > 0 ? _runCount : MIN(_runStarts.count, MIN(_runEnds.count, _runStyleMasks.count));
  runCount = MIN(runCount, MIN(_runStarts.count, MIN(_runEnds.count, _runStyleMasks.count)));
  NSMutableArray<RNPretextTextRun *> *resolvedRuns = [NSMutableArray arrayWithCapacity:runCount];

  for (NSInteger index = 0; index < runCount; index += 1) {
    NSNumber *styleMaskValue = RNPretextNumberOrNil(_runStyleMasks[index]);
    NSNumber *startValue = RNPretextNumberOrNil(_runStarts[index]);
    NSNumber *endValue = RNPretextNumberOrNil(_runEnds[index]);
    if (styleMaskValue == nil || startValue == nil || endValue == nil) continue;

    NSInteger styleMask = styleMaskValue.integerValue;
    RNPretextTextRunStyle *style = [RNPretextTextRunStyle new];

    if ((styleMask & RNPretextRunStyleHasColor) != 0 && index < _runColors.count) {
      NSString *color = RNPretextStringOrNil(_runColors[index]);
      if (color != nil) {
        style.color = RNPretextResolveColorValue(color);
      }
    }
    if ((styleMask & RNPretextRunStyleHasFontFamily) != 0 && index < _runFontFamilies.count) {
      style.fontFamily = RNPretextStringOrNil(_runFontFamilies[index]);
    }
    if ((styleMask & RNPretextRunStyleHasFontSize) != 0 && index < _runFontSizes.count) {
      style.fontSize = RNPretextNumberOrNil(_runFontSizes[index]);
    }
    if ((styleMask & RNPretextRunStyleHasFontStyle) != 0 && index < _runFontStyles.count) {
      style.fontStyle = RNPretextStringOrNil(_runFontStyles[index]);
    }
    if ((styleMask & RNPretextRunStyleHasFontWeight) != 0 && index < _runFontWeights.count) {
      style.fontWeight = RNPretextStringOrNil(_runFontWeights[index]);
    }
    if ((styleMask & RNPretextRunStyleHasLetterSpacing) != 0 && index < _runLetterSpacings.count) {
      style.letterSpacing = RNPretextNumberOrNil(_runLetterSpacings[index]);
    }
    if ((styleMask & RNPretextRunStyleHasLineHeight) != 0 && index < _runLineHeights.count) {
      style.lineHeight = RNPretextNumberOrNil(_runLineHeights[index]);
    }
    if ((styleMask & RNPretextRunStyleHasTabularNumbers) != 0 && index < _runTabularNumbers.count) {
      style.tabularNumbers = RNPretextNumberOrNil(_runTabularNumbers[index]);
    }

    RNPretextTextRun *run = [RNPretextTextRun new];
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
    _textDisplayDirty = YES;

    _fontSize = 14;
    _label = [[UILabel alloc] initWithFrame:self.bounds];
    _label.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _label.backgroundColor = UIColor.clearColor;
    _label.numberOfLines = 0;
    [self addSubview:_label];

    _textView = [[UITextView alloc] initWithFrame:self.bounds];
    _textView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _textView.backgroundColor = UIColor.clearColor;
    _textView.editable = NO;
    _textView.scrollEnabled = NO;
    _textView.selectable = NO;
    _textView.showsHorizontalScrollIndicator = NO;
    _textView.showsVerticalScrollIndicator = NO;
    _textView.textContainerInset = UIEdgeInsetsZero;
    _textView.textContainer.lineFragmentPadding = 0;
    _textView.hidden = YES;
    [self addSubview:_textView];
  }

  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _label.frame = self.bounds;
  _label.preferredMaxLayoutWidth = CGRectGetWidth(self.bounds);
  _textView.frame = self.bounds;
  _textView.textContainer.size = self.bounds.size;

  if (_textDisplayDirty) {
    _textDisplayDirty = NO;
    [self updateTextDisplay];
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

- (void)setRuns:(NSArray<RNPretextTextRun *> *)runs
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
  _label.numberOfLines = numberOfLines > 0 ? numberOfLines : 0;
  _textView.textContainer.maximumNumberOfLines = numberOfLines > 0 ? numberOfLines : 0;
}

- (void)setEllipsizeMode:(NSString *)ellipsizeMode
{
  _ellipsizeMode = [ellipsizeMode copy];
  NSLineBreakMode lineBreakMode = NSLineBreakByClipping;

  if ([ellipsizeMode isEqualToString:@"head"]) {
    lineBreakMode = NSLineBreakByTruncatingHead;
  } else if ([ellipsizeMode isEqualToString:@"middle"]) {
    lineBreakMode = NSLineBreakByTruncatingMiddle;
  } else if ([ellipsizeMode isEqualToString:@"tail"]) {
    lineBreakMode = NSLineBreakByTruncatingTail;
  }

  _label.lineBreakMode = lineBreakMode;
  _textView.textContainer.lineBreakMode = lineBreakMode;
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

  _label.textAlignment = alignment;
  _textView.textAlignment = alignment;
  [self invalidateTextDisplay];
}

- (void)setSelectable:(BOOL)selectable
{
  _selectable = selectable;
  _label.hidden = selectable;
  _textView.hidden = !selectable;
  _textView.selectable = selectable;
  _textView.userInteractionEnabled = selectable;
}

- (NSAttributedString *)buildAttributedText
{
  NSString *text = _text ?: @"";
  NSDictionary<NSAttributedStringKey, id> *baseAttributes = [self buildRunAttributes:[RNPretextTextRunStyle new]];
  NSArray<RNPretextTextRun *> *runs = [self resolvedRuns];
  if (runs.count == 0) {
    return [[NSAttributedString alloc] initWithString:text attributes:baseAttributes];
  }

  NSMutableAttributedString *attributedText =
      [[NSMutableAttributedString alloc] initWithString:text attributes:baseAttributes];
  NSInteger previousEnd = 0;

  for (RNPretextTextRun *run in runs) {
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
  NSAttributedString *attributedText = [self buildAttributedText];
  _label.attributedText = attributedText;
  _textView.attributedText = attributedText;
}

@end

@interface RNPretextTextViewManager : RCTViewManager
@end

@implementation RNPretextTextViewManager

RCT_EXPORT_MODULE(RNPretextTextView)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (UIView *)view
{
  return [RNPretextTextView new];
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
RCT_CUSTOM_VIEW_PROPERTY(runs, NSArray, RNPretextTextView)
{
  NSArray *rawRuns = json == nil || json == (id)kCFNull ? nil : [RCTConvert NSArray:json];
  if (rawRuns == nil) {
    view.runs = nil;
    return;
  }

  NSMutableArray<RNPretextTextRun *> *resolvedRuns = [NSMutableArray arrayWithCapacity:rawRuns.count];
  for (id rawRun in rawRuns) {
    if (![rawRun isKindOfClass:[NSDictionary class]]) continue;
    NSDictionary *runDictionary = (NSDictionary *)rawRun;
    NSNumber *start = [RCTConvert NSNumber:runDictionary[@"start"]];
    NSNumber *end = [RCTConvert NSNumber:runDictionary[@"end"]];
    NSDictionary *styleDictionary = [RCTConvert NSDictionary:runDictionary[@"style"]];
    if (start == nil || end == nil || styleDictionary == nil) continue;

    RNPretextTextRunStyle *style = [RNPretextTextRunStyle new];
    id rawColor = styleDictionary[@"color"];
    if ([rawColor isKindOfClass:[NSString class]]) {
      style.color = RNPretextResolveColorValue((NSString *)rawColor);
    }
    style.fontFamily = [RCTConvert NSString:styleDictionary[@"fontFamily"]];
    style.fontSize = [RCTConvert NSNumber:styleDictionary[@"fontSize"]];
    style.fontStyle = [RCTConvert NSString:styleDictionary[@"fontStyle"]];
    style.fontWeight = [RCTConvert NSString:styleDictionary[@"fontWeight"]];
    style.letterSpacing = [RCTConvert NSNumber:styleDictionary[@"letterSpacing"]];
    style.lineHeight = [RCTConvert NSNumber:styleDictionary[@"lineHeight"]];
    style.tabularNumbers = [RCTConvert NSNumber:styleDictionary[@"tabularNumbers"]];

    RNPretextTextRun *run = [RNPretextTextRun new];
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
