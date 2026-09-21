#import "RNTextEngineAttributedTextDisplayView.h"

static CGFloat RNTextEngineResolveHorizontalDrawOrigin(
    NSLayoutManager *layoutManager,
    NSTextContainer *textContainer,
    NSRange glyphRange,
    NSTextAlignment textAlignment,
    CGFloat width)
{
  if (textAlignment == NSTextAlignmentCenter || textAlignment == NSTextAlignmentNatural) return 0;
  CGRect glyphBounds = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];

  CGFloat leftInset = MAX(0, -CGRectGetMinX(glyphBounds));
  CGFloat rightOverflow = MAX(0, CGRectGetMaxX(glyphBounds) - width);
  if (textAlignment == NSTextAlignmentRight) return -ceil(rightOverflow);
  return ceil(leftInset);
}

NSLineBreakMode RNTextEngineResolveLineBreakMode(NSInteger numberOfLines, NSString *ellipsizeMode)
{
  if (numberOfLines <= 0) return NSLineBreakByWordWrapping;
  if ([ellipsizeMode isEqualToString:@"head"]) return NSLineBreakByTruncatingHead;
  if ([ellipsizeMode isEqualToString:@"middle"]) return NSLineBreakByTruncatingMiddle;
  if ([ellipsizeMode isEqualToString:@"clip"]) return NSLineBreakByClipping;
  if ([ellipsizeMode isEqualToString:@"tail"]) return NSLineBreakByTruncatingTail;
  return NSLineBreakByTruncatingTail;
}

UITextView *RNTextEngineCreateInteractionTextView(UIView *view)
{
  UITextView *textView;
  if (@available(iOS 16.0, *)) {
    textView = [UITextView textViewUsingTextLayoutManager:NO];
  } else {
    textView = [[UITextView alloc] initWithFrame:view.bounds];
  }
  textView.frame = view.bounds;
  textView.backgroundColor = UIColor.clearColor;
  textView.clipsToBounds = NO;
  textView.opaque = NO;
  textView.layer.opaque = NO;
  textView.editable = NO;
  textView.scrollEnabled = NO;
  textView.selectable = YES;
  textView.showsHorizontalScrollIndicator = NO;
  textView.showsVerticalScrollIndicator = NO;
  textView.textContainerInset = UIEdgeInsetsZero;
  textView.textContainer.lineFragmentPadding = 0;
  textView.userInteractionEnabled = YES;
  return textView;
}

void RNTextEngineApplyInteractionTextViewFrame(
    UITextView *textView,
    CGRect frame,
    UIEdgeInsets contentInsets)
{
  if (textView == nil) return;
  textView.frame = frame;
  textView.textContainerInset = contentInsets;
  textView.textContainer.size = CGSizeMake(
      MAX(CGRectGetWidth(frame) - contentInsets.left - contentInsets.right, 0),
      MAX(CGRectGetHeight(frame) - contentInsets.top - contentInsets.bottom, 0));
}

@implementation RNTextEngineAttributedTextDisplayView {
  UIEdgeInsets _cachedCapHeightInsets;
  BOOL _capHeightInsetsDirty;
  NSLayoutManager *_layoutManager;
  NSTextContainer *_textContainer;
  NSTextStorage *_textStorage;
  CGFloat _layoutWidth;
  BOOL _layoutDirty;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.contentMode = UIViewContentModeRedraw;

    _layoutManager = [[NSLayoutManager alloc] init];
    _textContainer = [[NSTextContainer alloc] initWithSize:CGSizeZero];
    _textContainer.lineFragmentPadding = 0;
    [_layoutManager addTextContainer:_textContainer];

    _textStorage = [[NSTextStorage alloc] init];
    [_textStorage addLayoutManager:_layoutManager];

    _attributedText = [[NSAttributedString alloc] initWithString:@""];
    _contentInsets = UIEdgeInsetsZero;
    _textAlignment = NSTextAlignmentNatural;
    _uniformCapHeight = 0;
    _capHeightInsetsDirty = YES;
    _layoutDirty = YES;
  }

  return self;
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
  if (_attributedText == attributedText) return;
  _attributedText = [attributedText copy] ?: [[NSAttributedString alloc] initWithString:@""];
  [_textStorage setAttributedString:_attributedText];
  if (_attributedText.length == 0) self.layer.contents = nil;
  [self invalidateLayout];
}

- (void)setUniformCapHeight:(CGFloat)uniformCapHeight
{
  if (_uniformCapHeight == uniformCapHeight) return;
  _uniformCapHeight = uniformCapHeight;
  _capHeightInsetsDirty = YES;
}

- (void)setEllipsizeMode:(NSString *)ellipsizeMode
{
  if ((_ellipsizeMode == ellipsizeMode) || [_ellipsizeMode isEqualToString:ellipsizeMode]) return;
  _ellipsizeMode = [ellipsizeMode copy];
  [self invalidateLayout];
}

- (void)setNumberOfLines:(NSInteger)numberOfLines
{
  if (_numberOfLines == numberOfLines) return;
  _numberOfLines = numberOfLines;
  [self invalidateLayout];
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment
{
  if (_textAlignment == textAlignment) return;
  _textAlignment = textAlignment;
  [self setNeedsDisplay];
}

- (void)setContentInsets:(UIEdgeInsets)contentInsets
{
  if (UIEdgeInsetsEqualToEdgeInsets(_contentInsets, contentInsets)) return;
  _contentInsets = contentInsets;
  [self invalidateLayout];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  [self setNeedsDisplay];
}

- (CGFloat)capHeightTopInsetForSize:(CGSize)size
{
  return [self capHeightInsetsForWidth:size.width].top;
}

- (UIEdgeInsets)capHeightInsetsForWidth:(CGFloat)width
{
  [self ensureLayoutForWidth:width];
  if (!_capHeightInsetsDirty) return _cachedCapHeightInsets;

  _cachedCapHeightInsets = RNTextEngineCapHeightInsetsForLayoutManagerWithUniformCapHeight(
      _layoutManager,
      _textContainer,
      _attributedText,
      _uniformCapHeight);
  _capHeightInsetsDirty = NO;
  return _cachedCapHeightInsets;
}

- (void)drawRect:(CGRect)rect
{
  [self ensureLayoutForWidth:CGRectGetWidth(self.bounds)];

  NSRange glyphRange = [_layoutManager glyphRangeForTextContainer:_textContainer];
  if (glyphRange.length == 0) return;

  CGFloat contentWidth = MAX(CGRectGetWidth(self.bounds) - _contentInsets.left - _contentInsets.right, 0);
  CGFloat drawOriginX =
      _contentInsets.left +
      RNTextEngineResolveHorizontalDrawOrigin(_layoutManager, _textContainer, glyphRange, _textAlignment, contentWidth);
  CGPoint drawPoint = CGPointMake(drawOriginX, _contentInsets.top);
  [_layoutManager drawBackgroundForGlyphRange:glyphRange atPoint:drawPoint];
  [_layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:drawPoint];
}

- (void)invalidateLayout
{
  _capHeightInsetsDirty = YES;
  _layoutDirty = YES;
  _layoutWidth = -1;
  [self setNeedsDisplay];
}

- (void)ensureLayoutForWidth:(CGFloat)width
{
  CGFloat resolvedWidth = MAX(width - _contentInsets.left - _contentInsets.right, 0);
  if (!_layoutDirty && _layoutWidth == resolvedWidth) return;

  _textContainer.size = CGSizeMake(resolvedWidth, CGFLOAT_MAX);
  _textContainer.lineBreakMode = RNTextEngineResolveLineBreakMode(_numberOfLines, _ellipsizeMode);
  _textContainer.maximumNumberOfLines = _numberOfLines > 0 ? _numberOfLines : 0;
  [_layoutManager ensureLayoutForTextContainer:_textContainer];

  _capHeightInsetsDirty = YES;
  _layoutWidth = resolvedWidth;
  _layoutDirty = NO;
}

@end
