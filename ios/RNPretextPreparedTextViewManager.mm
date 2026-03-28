#import <React/RCTConvert.h>
#import <React/RCTViewManager.h>

#import "RNPretextBindings.h"

@interface RNPretextPreparedTextView : UIView
@property (nonatomic, assign) NSInteger handle;
@property (nonatomic, assign) NSInteger numberOfLines;
@property (nonatomic, copy) NSString *ellipsizeMode;
@end

@implementation RNPretextPreparedTextView {
  UILabel *_label;
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
  }

  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _label.frame = self.bounds;
  _label.preferredMaxLayoutWidth = CGRectGetWidth(self.bounds);
}

- (void)setHandle:(NSInteger)handle
{
  if (_handle == handle) return;
  _handle = handle;

  if (handle <= 0) {
    _label.attributedText = nil;
    return;
  }

  _label.attributedText =
      rnpretext::preparedAttributedTextForHandle((uint64_t)handle);
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
RCT_CUSTOM_VIEW_PROPERTY(ellipsizeMode, NSString, RNPretextPreparedTextView)
{
  view.ellipsizeMode = [RCTConvert NSString:json];
}

@end
