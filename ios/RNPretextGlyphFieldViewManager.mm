#ifdef RCT_NEW_ARCH_ENABLED
#import <React/RCTViewComponentView.h>
#import <react/renderer/components/RNPretextSpec/Props.h>
#import <react/renderer/components/RNPretextSpec/RCTComponentViewHelpers.h>
#import "../common/cpp/react/renderer/components/RNPretextSpec/RNPretextGlyphFieldViewComponentDescriptor.h"
#endif
#import <React/RCTViewManager.h>

#import "RNPretextBindings.h"

@interface RNPretextGlyphFieldView : UIView
@property (nonatomic, assign) NSInteger handle;
@end

#ifdef RCT_NEW_ARCH_ENABLED

using namespace facebook::react;

@interface RNPretextGlyphFieldViewComponentView : RCTViewComponentView <RCTRNPretextGlyphFieldViewViewProtocol>
@end

@implementation RNPretextGlyphFieldViewComponentView {
  NSInteger _registeredHandle;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNPretextGlyphFieldViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    static const auto defaultProps = std::make_shared<const RNPretextGlyphFieldViewProps>();
    _props = defaultProps;
    self.backgroundColor = UIColor.clearColor;
    self.clearsContextBeforeDrawing = NO;
    self.contentMode = UIViewContentModeRedraw;
    self.opaque = NO;
    self.layer.backgroundColor = UIColor.clearColor.CGColor;
  }

  return self;
}

- (void)dealloc
{
  if (_registeredHandle > 0) {
    rnpretext::unregisterGlyphFieldView((uint64_t)_registeredHandle, self);
  }
}

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &oldViewProps = static_cast<const RNPretextGlyphFieldViewProps &>(*_props);
  const auto &newViewProps = static_cast<const RNPretextGlyphFieldViewProps &>(*props);

  if (oldViewProps.handle != newViewProps.handle) {
    if (_registeredHandle > 0) {
      rnpretext::unregisterGlyphFieldView((uint64_t)_registeredHandle, self);
    }

    _registeredHandle = static_cast<NSInteger>(newViewProps.handle);
    if (_registeredHandle > 0) {
      rnpretext::registerGlyphFieldView((uint64_t)_registeredHandle, self);
    }

    [self setNeedsDisplay];
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
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
  rnpretext::drawGlyphFieldHandle((uint64_t)_registeredHandle, context, self.bounds);
}

- (void)prepareForRecycle
{
  if (_registeredHandle > 0) {
    rnpretext::unregisterGlyphFieldView((uint64_t)_registeredHandle, self);
    _registeredHandle = 0;
  }
  [super prepareForRecycle];
  [self setNeedsDisplay];
}

@end

#endif

@implementation RNPretextGlyphFieldView {
  NSInteger _registeredHandle;
}

- (instancetype)init
{
  if ((self = [super init])) {
    self.backgroundColor = UIColor.clearColor;
    self.clearsContextBeforeDrawing = NO;
    self.contentMode = UIViewContentModeRedraw;
    self.opaque = NO;
    self.layer.backgroundColor = UIColor.clearColor.CGColor;
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
  CGContextRef context = UIGraphicsGetCurrentContext();
  if (context == nullptr) return;

  CGContextSetBlendMode(context, kCGBlendModeCopy);
  CGContextSetFillColorWithColor(context, UIColor.clearColor.CGColor);
  CGContextFillRect(context, self.bounds);
  CGContextSetBlendMode(context, kCGBlendModeNormal);
  rnpretext::drawGlyphFieldHandle((uint64_t)_handle, context, self.bounds);
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
