#ifdef RCT_NEW_ARCH_ENABLED
#import <React/RCTViewComponentView.h>
#import <react/renderer/components/RNTextEngineSpec/ComponentDescriptors.h>
#import <react/renderer/components/RNTextEngineSpec/Props.h>
#import <react/renderer/components/RNTextEngineSpec/RCTComponentViewHelpers.h>
#endif
#import <React/RCTViewManager.h>

#import "RNTextEngineBindings.h"

@interface RNTextEngineGlyphFieldView : UIView
@property (nonatomic, assign) NSInteger handle;
@end

#ifdef RCT_NEW_ARCH_ENABLED

using namespace facebook::react;

@interface RNTextEngineGlyphFieldViewComponentView : RCTViewComponentView <RCTRNTextEngineGlyphFieldViewViewProtocol>
@end

@implementation RNTextEngineGlyphFieldViewComponentView {
  NSInteger _registeredHandle;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNTextEngineGlyphFieldViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    static const auto defaultProps = std::make_shared<const RNTextEngineGlyphFieldViewProps>();
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
    rntextengine::unregisterGlyphFieldView((uint64_t)_registeredHandle, self);
  }
}

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &oldViewProps = static_cast<const RNTextEngineGlyphFieldViewProps &>(*_props);
  const auto &newViewProps = static_cast<const RNTextEngineGlyphFieldViewProps &>(*props);

  if (oldViewProps.handle != newViewProps.handle) {
    if (_registeredHandle > 0) {
      rntextengine::unregisterGlyphFieldView((uint64_t)_registeredHandle, self);
    }

    _registeredHandle = static_cast<NSInteger>(newViewProps.handle);
    if (_registeredHandle > 0) {
      rntextengine::registerGlyphFieldView((uint64_t)_registeredHandle, self);
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
  CGContextFillRect(context, rect);
  CGContextSetBlendMode(context, kCGBlendModeNormal);
  rntextengine::drawGlyphFieldHandle((uint64_t)_registeredHandle, context, self.bounds, rect);
}

- (void)prepareForRecycle
{
  if (_registeredHandle > 0) {
    rntextengine::unregisterGlyphFieldView((uint64_t)_registeredHandle, self);
    _registeredHandle = 0;
  }
  [super prepareForRecycle];
  [self setNeedsDisplay];
}

@end

#endif

@implementation RNTextEngineGlyphFieldView {
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
    rntextengine::unregisterGlyphFieldView((uint64_t)_registeredHandle, self);
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
    rntextengine::unregisterGlyphFieldView((uint64_t)_registeredHandle, self);
  }

  _handle = handle;
  _registeredHandle = handle;

  if (_registeredHandle > 0) {
    rntextengine::registerGlyphFieldView((uint64_t)_registeredHandle, self);
  }

  [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
  CGContextRef context = UIGraphicsGetCurrentContext();
  if (context == nullptr) return;

  CGContextSetBlendMode(context, kCGBlendModeCopy);
  CGContextSetFillColorWithColor(context, UIColor.clearColor.CGColor);
  CGContextFillRect(context, rect);
  CGContextSetBlendMode(context, kCGBlendModeNormal);
  rntextengine::drawGlyphFieldHandle((uint64_t)_handle, context, self.bounds, rect);
}

@end

@interface RNTextEngineGlyphFieldViewManager : RCTViewManager
@end

@implementation RNTextEngineGlyphFieldViewManager

RCT_EXPORT_MODULE(RNTextEngineGlyphFieldView)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (UIView *)view
{
  return [RNTextEngineGlyphFieldView new];
}

RCT_EXPORT_VIEW_PROPERTY(handle, NSInteger)

@end
