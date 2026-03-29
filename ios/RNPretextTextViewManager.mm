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
@property (nonatomic, assign) BOOL selectable;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *textAlign;
@end

@implementation RNPretextTextView {
  UILabel *_label;
  UITextView *_textView;
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

  return [[NSAttributedString alloc] initWithString:text attributes:attributes];
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
RCT_EXPORT_VIEW_PROPERTY(selectable, BOOL)
RCT_EXPORT_VIEW_PROPERTY(text, NSString)
RCT_EXPORT_VIEW_PROPERTY(textAlign, NSString)

@end
