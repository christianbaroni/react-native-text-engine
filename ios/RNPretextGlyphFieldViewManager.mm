#import <React/RCTViewManager.h>

#import "RNPretextBindings.h"

@interface RNPretextGlyphFieldView : UIView
@property (nonatomic, assign) NSInteger handle;
@end

@implementation RNPretextGlyphFieldView {
  NSInteger _registeredHandle;
}

- (instancetype)init
{
  if ((self = [super init])) {
    self.backgroundColor = UIColor.clearColor;
    self.contentMode = UIViewContentModeRedraw;
    self.opaque = NO;
  }

  return self;
}

- (void)dealloc
{
  if (_registeredHandle > 0) {
    rnpretext::unregisterGlyphFieldView((uint64_t)_registeredHandle, self);
  }
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  [self setNeedsDisplay];
}

- (void)setHandle:(NSInteger)handle
{
  if (_registeredHandle > 0) {
    rnpretext::unregisterGlyphFieldView((uint64_t)_registeredHandle, self);
  }

  _handle = handle;
  _registeredHandle = handle;

  if (_registeredHandle > 0) {
    rnpretext::registerGlyphFieldView((uint64_t)_registeredHandle, self);
  }

  [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
  [super drawRect:rect];
  rnpretext::drawGlyphFieldHandle((uint64_t)_handle, UIGraphicsGetCurrentContext(), self.bounds);
}

@end

@interface RNPretextGlyphFieldViewManager : RCTViewManager
@end

@implementation RNPretextGlyphFieldViewManager

RCT_EXPORT_MODULE(RNPretextGlyphFieldView)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (UIView *)view
{
  return [RNPretextGlyphFieldView new];
}

RCT_EXPORT_VIEW_PROPERTY(handle, NSInteger)

@end
