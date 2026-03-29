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
@property (nonatomic, copy) NSArray<RNPretextTextRun *> *runs;
@property (nonatomic, assign) BOOL selectable;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *textAlign;
@end

@implementation RNPretextTextView {
  UILabel *_label;
  UITextView *_textView;
}

+ (UIColor *)resolveColorString:(NSString *)value
{
  if (value.length == 0) return nil;

  if ([value hasPrefix:@"#"]) {
    NSString *hex = [value substringFromIndex:1];
    unsigned long long parsed = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    if (![scanner scanHexLongLong:&parsed]) return nil;

    CGFloat alpha = 1;
    CGFloat red = 0;
    CGFloat green = 0;
    CGFloat blue = 0;

    if (hex.length == 3) {
      red = ((parsed >> 8) & 0xF) / 15.0;
      green = ((parsed >> 4) & 0xF) / 15.0;
      blue = (parsed & 0xF) / 15.0;
    } else if (hex.length == 6) {
      red = ((parsed >> 16) & 0xFF) / 255.0;
      green = ((parsed >> 8) & 0xFF) / 255.0;
      blue = (parsed & 0xFF) / 255.0;
    } else if (hex.length == 8) {
      alpha = ((parsed >> 24) & 0xFF) / 255.0;
      red = ((parsed >> 16) & 0xFF) / 255.0;
      green = ((parsed >> 8) & 0xFF) / 255.0;
      blue = (parsed & 0xFF) / 255.0;
    } else {
      return nil;
    }

    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
  }

  return [RCTConvert UIColor:value];
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

- (instancetype)init
{
  if ((self = [super init])) {
    self.backgroundColor = UIColor.clearColor;

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
}

- (void)setText:(NSString *)text
{
  _text = [text copy];
  [self updateTextDisplay];
}

- (void)setColor:(UIColor *)color
{
  _color = color;
  [self updateTextDisplay];
}

- (void)setFontFamily:(NSString *)fontFamily
{
  _fontFamily = [fontFamily copy];
  [self updateTextDisplay];
}

- (void)setFontSize:(CGFloat)fontSize
{
  _fontSize = fontSize;
  [self updateTextDisplay];
}

- (void)setFontStyle:(NSString *)fontStyle
{
  _fontStyle = [fontStyle copy];
  [self updateTextDisplay];
}

- (void)setFontWeight:(NSString *)fontWeight
{
  _fontWeight = [fontWeight copy];
  [self updateTextDisplay];
}

- (void)setLetterSpacing:(CGFloat)letterSpacing
{
  _letterSpacing = letterSpacing;
  [self updateTextDisplay];
}

- (void)setLineHeight:(CGFloat)lineHeight
{
  _lineHeight = lineHeight;
  [self updateTextDisplay];
}

- (void)setRuns:(NSArray<RNPretextTextRun *> *)runs
{
  _runs = [runs copy];
  [self updateTextDisplay];
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
  [self updateTextDisplay];
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
  if (_runs.count == 0) {
    return [[NSAttributedString alloc] initWithString:text attributes:baseAttributes];
  }

  NSMutableAttributedString *attributedText =
      [[NSMutableAttributedString alloc] initWithString:text attributes:baseAttributes];
  NSInteger previousEnd = 0;

  for (RNPretextTextRun *run in _runs) {
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
      style.color = [RNPretextTextView resolveColorString:(NSString *)rawColor];
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
