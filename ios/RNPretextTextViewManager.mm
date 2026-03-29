#import <React/RCTConvert.h>
#import <React/RCTFont.h>
#import <React/RCTViewManager.h>

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
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *textAlign;
@end

@implementation RNPretextTextView {
  UILabel *_label;
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
  }

  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _label.frame = self.bounds;
  _label.preferredMaxLayoutWidth = CGRectGetWidth(self.bounds);
}

- (void)setText:(NSString *)text
{
  _text = [text copy];
  [self updateLabel];
}

- (void)setColor:(UIColor *)color
{
  _color = color;
  [self updateLabel];
}

- (void)setFontFamily:(NSString *)fontFamily
{
  _fontFamily = [fontFamily copy];
  [self updateLabel];
}

- (void)setFontSize:(CGFloat)fontSize
{
  _fontSize = fontSize;
  [self updateLabel];
}

- (void)setFontStyle:(NSString *)fontStyle
{
  _fontStyle = [fontStyle copy];
  [self updateLabel];
}

- (void)setFontWeight:(NSString *)fontWeight
{
  _fontWeight = [fontWeight copy];
  [self updateLabel];
}

- (void)setLetterSpacing:(CGFloat)letterSpacing
{
  _letterSpacing = letterSpacing;
  [self updateLabel];
}

- (void)setLineHeight:(CGFloat)lineHeight
{
  _lineHeight = lineHeight;
  [self updateLabel];
}

- (void)setNumberOfLines:(NSInteger)numberOfLines
{
  _numberOfLines = numberOfLines;
  _label.numberOfLines = numberOfLines > 0 ? numberOfLines : 0;
}

- (void)setEllipsizeMode:(NSString *)ellipsizeMode
{
  _ellipsizeMode = [ellipsizeMode copy];

  if ([ellipsizeMode isEqualToString:@"head"]) {
    _label.lineBreakMode = NSLineBreakByTruncatingHead;
    return;
  }

  if ([ellipsizeMode isEqualToString:@"middle"]) {
    _label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    return;
  }

  if ([ellipsizeMode isEqualToString:@"tail"]) {
    _label.lineBreakMode = NSLineBreakByTruncatingTail;
    return;
  }

  _label.lineBreakMode = NSLineBreakByClipping;
}

- (void)setTextAlign:(NSString *)textAlign
{
  _textAlign = [textAlign copy];

  if ([textAlign isEqualToString:@"center"]) {
    _label.textAlignment = NSTextAlignmentCenter;
    return;
  }

  if ([textAlign isEqualToString:@"right"]) {
    _label.textAlignment = NSTextAlignmentRight;
    return;
  }

  if ([textAlign isEqualToString:@"justify"]) {
    _label.textAlignment = NSTextAlignmentJustified;
    return;
  }

  _label.textAlignment = NSTextAlignmentLeft;
}

- (void)updateLabel
{
  NSString *text = _text ?: @"";
  UIFont *font =
      [RCTFont updateFont:nil
               withFamily:_fontFamily
                     size:@(_fontSize)
                   weight:_fontWeight
                    style:_fontStyle
                  variant:nil
          scaleMultiplier:1];
  if (!font) font = [UIFont systemFontOfSize:_fontSize];

  NSMutableDictionary<NSAttributedStringKey, id> *attributes =
      [NSMutableDictionary dictionaryWithObject:font forKey:NSFontAttributeName];

  if (_color != nil) {
    attributes[NSForegroundColorAttributeName] = _color;
  }

  if (_letterSpacing != 0) {
    attributes[NSKernAttributeName] = @(_letterSpacing);
  }

  if (_lineHeight > 0) {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.minimumLineHeight = _lineHeight;
    paragraphStyle.maximumLineHeight = _lineHeight;
    paragraphStyle.alignment = _label.textAlignment;
    attributes[NSParagraphStyleAttributeName] = paragraphStyle;
  }

  _label.attributedText =
      [[NSAttributedString alloc] initWithString:text attributes:attributes];
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
RCT_EXPORT_VIEW_PROPERTY(text, NSString)
RCT_EXPORT_VIEW_PROPERTY(textAlign, NSString)

@end
