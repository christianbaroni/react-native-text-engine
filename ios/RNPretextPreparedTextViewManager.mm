#import <React/RCTConvert.h>
#import <React/RCTViewManager.h>

#import "RNPretextBindings.h"

@interface RNPretextPreparedTextView : UIView
@property (nonatomic, assign) NSInteger handle;
@property (nonatomic, assign) NSInteger numberOfLines;
@property (nonatomic, copy) NSString *ellipsizeMode;
@property (nonatomic, assign) BOOL selectable;
@end

@implementation RNPretextPreparedTextView {
  UILabel *_label;
  UITextView *_textView;
  NSAttributedString *_resolvedText;
}

- (instancetype)init
{
  if ((self = [super init])) {
    self.backgroundColor = UIColor.clearColor;

    _label = [[UILabel alloc] initWithFrame:self.bounds];
    _label.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _label.backgroundColor = UIColor.clearColor;
    _label.lineBreakMode = NSLineBreakByClipping;
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

- (void)setSelectable:(BOOL)selectable
{
  _selectable = selectable;
  _label.hidden = selectable;
  _textView.hidden = !selectable;
  _textView.selectable = selectable;
  _textView.userInteractionEnabled = selectable;
}

- (void)updateTextDisplay
{
  _label.attributedText = _resolvedText;
  _textView.attributedText = _resolvedText;
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
