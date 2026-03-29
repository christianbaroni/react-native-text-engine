#import <React/RCTConvert.h>
#ifdef RCT_NEW_ARCH_ENABLED
#import <React/RCTConversions.h>
#import <React/RCTViewComponentView.h>
#import <react/renderer/components/RNPretextSpec/Props.h>
#import <react/renderer/components/RNPretextSpec/RCTComponentViewHelpers.h>
#import "../common/cpp/react/renderer/components/RNPretextSpec/RNPretextPreparedTextViewComponentDescriptor.h"
#endif
#import <React/RCTViewManager.h>

#import "RNPretextBindings.h"

@interface RNPretextPreparedTextView : UIView
@property (nonatomic, assign) NSInteger handle;
@property (nonatomic, assign) NSInteger numberOfLines;
@property (nonatomic, copy) NSString *ellipsizeMode;
@property (nonatomic, assign) BOOL selectable;
@end

#ifdef RCT_NEW_ARCH_ENABLED

using namespace facebook::react;

@interface RNPretextPreparedTextViewComponentView : RCTViewComponentView <RCTRNPretextPreparedTextViewViewProtocol>
@end

@implementation RNPretextPreparedTextViewComponentView {
  RNPretextPreparedTextView *_preparedTextView;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNPretextPreparedTextViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    static const auto defaultProps = std::make_shared<const RNPretextPreparedTextViewProps>();
    _props = defaultProps;
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.layer.backgroundColor = UIColor.clearColor.CGColor;
    _preparedTextView = [[RNPretextPreparedTextView alloc] initWithFrame:self.bounds];
    _preparedTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_preparedTextView];
  }

  return self;
}

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &oldViewProps = static_cast<const RNPretextPreparedTextViewProps &>(*_props);
  const auto &newViewProps = static_cast<const RNPretextPreparedTextViewProps &>(*props);

  if (oldViewProps.handle != newViewProps.handle) {
    _preparedTextView.handle = static_cast<NSInteger>(newViewProps.handle);
  }

  if (oldViewProps.numberOfLines != newViewProps.numberOfLines) {
    _preparedTextView.numberOfLines = newViewProps.numberOfLines;
  }

  if (oldViewProps.selectable != newViewProps.selectable) {
    _preparedTextView.selectable = newViewProps.selectable;
  }

  if (oldViewProps.ellipsizeMode != newViewProps.ellipsizeMode) {
    _preparedTextView.ellipsizeMode = RCTNSStringFromStringNilIfEmpty(newViewProps.ellipsizeMode);
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _preparedTextView.frame = self.bounds;
}

- (void)prepareForRecycle
{
  [super prepareForRecycle];
  _preparedTextView.handle = 0;
  _preparedTextView.numberOfLines = 0;
  _preparedTextView.selectable = NO;
  _preparedTextView.ellipsizeMode = nil;
}

@end

#endif

@implementation RNPretextPreparedTextView {
  UITextView *_textView;
  NSAttributedString *_resolvedText;
}

- (BOOL)isOpaque
{
  return NO;
}

static NSLineBreakMode RNPretextPreparedResolveLineBreakMode(NSString *ellipsizeMode)
{
  if ([ellipsizeMode isEqualToString:@"head"]) return NSLineBreakByTruncatingHead;
  if ([ellipsizeMode isEqualToString:@"middle"]) return NSLineBreakByTruncatingMiddle;
  if ([ellipsizeMode isEqualToString:@"tail"]) return NSLineBreakByTruncatingTail;
  return NSLineBreakByClipping;
}

static NSAttributedString *RNPretextPreparedSelectionText(NSAttributedString *attributedText)
{
  if (attributedText.length == 0) return attributedText;

  NSMutableAttributedString *selectionText = [[NSMutableAttributedString alloc] initWithAttributedString:attributedText];
  [selectionText addAttribute:NSForegroundColorAttributeName
                        value:UIColor.clearColor
                        range:NSMakeRange(0, selectionText.length)];
  return selectionText;
}

static void RNPretextPreparedDrawAttributedText(
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
  textContainer.lineBreakMode = RNPretextPreparedResolveLineBreakMode(ellipsizeMode);
  textContainer.maximumNumberOfLines = numberOfLines > 0 ? numberOfLines : 0;

  [layoutManager addTextContainer:textContainer];
  [textStorage addLayoutManager:layoutManager];
  [layoutManager ensureLayoutForTextContainer:textContainer];

  NSRange glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
  [layoutManager drawBackgroundForGlyphRange:glyphRange atPoint:bounds.origin];
  [layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:bounds.origin];
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
  [self setNeedsDisplay];
}

- (void)setHandle:(NSInteger)handle
{
  if (_handle == handle) return;
  _handle = handle;

  if (handle <= 0) {
    _resolvedText = nil;
    [self updateTextDisplay];
    return;
  }

  _resolvedText = rnpretext::preparedAttributedTextForHandle((uint64_t)handle);
  [self updateTextDisplay];
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
  _textView.textContainer.lineBreakMode = RNPretextPreparedResolveLineBreakMode(ellipsizeMode);
  [self setNeedsDisplay];
}

- (void)setSelectable:(BOOL)selectable
{
  _selectable = selectable;
  _textView.hidden = !selectable;
  _textView.selectable = selectable;
  _textView.userInteractionEnabled = selectable;
  [self setNeedsDisplay];
}

- (void)updateTextDisplay
{
  _textView.attributedText = _selectable ? RNPretextPreparedSelectionText(_resolvedText ?: [[NSAttributedString alloc] initWithString:@""]) : nil;
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
  RNPretextPreparedDrawAttributedText(_resolvedText ?: [[NSAttributedString alloc] initWithString:@""], self.bounds, _numberOfLines, _ellipsizeMode);
}

@end

@interface RNPretextPreparedTextViewManager : RCTViewManager
@end

@implementation RNPretextPreparedTextViewManager

RCT_EXPORT_MODULE(RNPretextPreparedTextView)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (UIView *)view
{
  return [RNPretextPreparedTextView new];
}

RCT_EXPORT_VIEW_PROPERTY(handle, NSInteger)
RCT_EXPORT_VIEW_PROPERTY(numberOfLines, NSInteger)
RCT_EXPORT_VIEW_PROPERTY(selectable, BOOL)
RCT_CUSTOM_VIEW_PROPERTY(ellipsizeMode, NSString, RNPretextPreparedTextView)
{
  view.ellipsizeMode = [RCTConvert NSString:json];
}

@end
