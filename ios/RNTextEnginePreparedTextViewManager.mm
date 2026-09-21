#import "RNTextEngineAttributedTextDisplayView.h"
#import "RNTextEngineTextLayoutMetrics.h"
#import <React/RCTConvert.h>
#ifdef RCT_NEW_ARCH_ENABLED
#import <React/RCTConversions.h>
#import <React/RCTViewComponentView.h>
#import <react/renderer/components/RNTextEngineSpec/ComponentDescriptors.h>
#import <react/renderer/components/RNTextEngineSpec/Props.h>
#import <react/renderer/components/RNTextEngineSpec/RCTComponentViewHelpers.h>
#endif
#import <React/RCTViewManager.h>
#import <React/RCTView.h>

#import "RNTextEngineBindings.h"

#ifdef RCT_NEW_ARCH_ENABLED
@interface RNTextEnginePreparedTextView : UIView <RNTextEngineAccessibilityOwner>
#else
@interface RNTextEnginePreparedTextView : RCTView <RNTextEngineAccessibilityOwner>
#endif
@property (nonatomic, assign) NSInteger handle;
@property (nonatomic, assign) NSInteger numberOfLines;
@property (nonatomic, copy) NSString *ellipsizeMode;
@property (nonatomic, assign) BOOL anchorToCapHeight;
@property (nonatomic, assign) BOOL selectable;
@end

#ifdef RCT_NEW_ARCH_ENABLED

using namespace facebook::react;

@interface RNTextEnginePreparedTextViewComponentView : RCTViewComponentView <RCTRNTextEnginePreparedTextViewViewProtocol, RNTextEngineAccessibilityOwner>
@end

@implementation RNTextEnginePreparedTextViewComponentView {
  RNTextEnginePreparedTextView *_preparedTextView;
}

- (BOOL)isTextAccessibilityElement { return [super isAccessibilityElement]; }
- (NSString *)explicitAccessibilityLabel { return [super accessibilityLabel]; }
- (UIAccessibilityTraits)accessibilityTraits { return [super accessibilityTraits] | UIAccessibilityTraitStaticText; }
- (BOOL)isAccessibilityElement { return !_preparedTextView.selectable && [super isAccessibilityElement]; }
- (NSString *)accessibilityLabel { return [super accessibilityLabel] ?: _preparedTextView.accessibilityLabel; }

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNTextEnginePreparedTextViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    static const auto defaultProps = std::make_shared<const RNTextEnginePreparedTextViewProps>();
    _props = defaultProps;
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.layer.backgroundColor = UIColor.clearColor.CGColor;
    _preparedTextView = [[RNTextEnginePreparedTextView alloc] initWithFrame:self.bounds];
    _preparedTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_preparedTextView];
  }

  return self;
}

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &oldViewProps = static_cast<const RNTextEnginePreparedTextViewProps &>(*_props);
  const auto &newViewProps = static_cast<const RNTextEnginePreparedTextViewProps &>(*props);

  if (oldViewProps.handle != newViewProps.handle) {
    _preparedTextView.handle = static_cast<NSInteger>(newViewProps.handle);
  }

  if (oldViewProps.anchorToCapHeight != newViewProps.anchorToCapHeight) {
    _preparedTextView.anchorToCapHeight = newViewProps.anchorToCapHeight;
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
  const Props::Shared oldProps = _props;
  static const auto defaultProps = std::make_shared<const RNTextEnginePreparedTextViewProps>();
  [self updateProps:defaultProps oldProps:oldProps];
  [super prepareForRecycle];
}

@end

#endif

@implementation RNTextEnginePreparedTextView {
  RNTextEngineAttributedTextDisplayView *_displayView;
  UITextView *_interactionTextView;
  NSAttributedString *_resolvedText;
}

@synthesize anchorToCapHeight = _anchorToCapHeight;

- (BOOL)isTextAccessibilityElement { return [super isAccessibilityElement]; }
- (NSString *)explicitAccessibilityLabel { return [super accessibilityLabel]; }
- (UIAccessibilityTraits)accessibilityTraits { return [super accessibilityTraits] | UIAccessibilityTraitStaticText; }
- (BOOL)isAccessibilityElement { return !_selectable && [super isAccessibilityElement]; }
- (NSString *)accessibilityLabel { return [super accessibilityLabel] ?: _resolvedText.string; }

- (void)commonInit
{
  self.backgroundColor = UIColor.clearColor;
  self.opaque = NO;
  self.layer.backgroundColor = UIColor.clearColor.CGColor;
  self.layer.opaque = NO;

  _displayView = [[RNTextEngineAttributedTextDisplayView alloc] initWithFrame:self.bounds];
  _displayView.userInteractionEnabled = NO;
  [self addSubview:_displayView];
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    [self commonInit];
  }

  return self;
}

- (BOOL)isOpaque
{
  return NO;
}

- (instancetype)init
{
  return [self initWithFrame:CGRectZero];
}

- (UITextView *)ensureInteractionTextView
{
  if (_interactionTextView != nil) return _interactionTextView;

  _interactionTextView = RNTextEngineCreateInteractionTextView(self);
  _interactionTextView.textContainer.maximumNumberOfLines = _numberOfLines > 0 ? _numberOfLines : 0;
  _interactionTextView.textContainer.lineBreakMode = RNTextEngineResolveLineBreakMode(_numberOfLines, _ellipsizeMode);
  [self addSubview:_interactionTextView];
  return _interactionTextView;
}

- (void)discardInteractionTextView
{
  [_interactionTextView removeFromSuperview];
  _interactionTextView = nil;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  [self updateContentFrames];
}

- (void)setHandle:(NSInteger)handle
{
  if (_handle == handle) return;
  _handle = handle;

  if (handle <= 0) {
    _resolvedText = nil;
    _displayView.uniformCapHeight = 0;
    [self updateTextDisplay];
    return;
  }

  _resolvedText = rntextengine::preparedAttributedTextForHandle((uint64_t)handle);
  _displayView.uniformCapHeight = rntextengine::preparedUniformCapHeightForHandle((uint64_t)handle);
  [self updateTextDisplay];
}

- (void)setAnchorToCapHeight:(BOOL)anchorToCapHeight
{
  if (_anchorToCapHeight == anchorToCapHeight) return;
  _anchorToCapHeight = anchorToCapHeight;
  [self setNeedsLayout];
}

- (void)setNumberOfLines:(NSInteger)numberOfLines
{
  _numberOfLines = numberOfLines;
  _displayView.numberOfLines = numberOfLines;
  _interactionTextView.textContainer.maximumNumberOfLines = numberOfLines > 0 ? numberOfLines : 0;
  _interactionTextView.textContainer.lineBreakMode = RNTextEngineResolveLineBreakMode(numberOfLines, _ellipsizeMode);
  [self setNeedsLayout];
}

- (void)setEllipsizeMode:(NSString *)ellipsizeMode
{
  _ellipsizeMode = [ellipsizeMode copy];
  _displayView.ellipsizeMode = _ellipsizeMode;
  _interactionTextView.textContainer.lineBreakMode = RNTextEngineResolveLineBreakMode(_numberOfLines, ellipsizeMode);
  [self setNeedsLayout];
}

- (void)setSelectable:(BOOL)selectable
{
  if (_selectable == selectable) return;
  _selectable = selectable;
  if (selectable) {
    [self ensureInteractionTextView];
  } else {
    [self discardInteractionTextView];
  }
  [self updateTextDisplay];
}

- (void)updateTextDisplay
{
  BOOL textChanged = self.window != nil && UIAccessibilityIsVoiceOverRunning() &&
      ![_displayView.attributedText.string isEqualToString:_resolvedText.string ?: @""];
  _displayView.attributedText = _resolvedText ?: [[NSAttributedString alloc] initWithString:@""];
  _displayView.ellipsizeMode = _ellipsizeMode;
  _displayView.numberOfLines = _numberOfLines;
  _displayView.hidden = _selectable;
  if (_selectable) {
    UITextView *interactionTextView = [self ensureInteractionTextView];
    interactionTextView.attributedText = _resolvedText ?: [[NSAttributedString alloc] initWithString:@""];
    [self bringSubviewToFront:interactionTextView];
  }
  [self setNeedsLayout];
  if (textChanged) UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

- (UIEdgeInsets)resolvedCapHeightInsets
{
  if (!_anchorToCapHeight || CGRectIsEmpty(self.bounds)) return UIEdgeInsetsZero;

  CGFloat width = CGRectGetWidth(self.bounds);
  return [_displayView capHeightInsetsForWidth:width];
}

- (CGRect)contentFrameForInsets:(UIEdgeInsets)insets
{
  CGRect frame = self.bounds;
  frame.origin.y -= insets.top;
  frame.size.height += insets.top + insets.bottom;
  return frame;
}

- (void)updateContentFrames
{
  UIEdgeInsets insets = [self resolvedCapHeightInsets];
  CGRect contentFrame = [self contentFrameForInsets:insets];

  _displayView.frame = contentFrame;
  RNTextEngineApplyInteractionTextViewFrame(_interactionTextView, contentFrame, UIEdgeInsetsZero);
}

@end

@interface RNTextEnginePreparedTextViewManager : RCTViewManager
@end

@implementation RNTextEnginePreparedTextViewManager

RCT_EXPORT_MODULE(RNTextEnginePreparedTextView)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (UIView *)view
{
  return [RNTextEnginePreparedTextView new];
}

RCT_EXPORT_VIEW_PROPERTY(handle, NSInteger)
RCT_EXPORT_VIEW_PROPERTY(anchorToCapHeight, BOOL)
RCT_EXPORT_VIEW_PROPERTY(numberOfLines, NSInteger)
RCT_EXPORT_VIEW_PROPERTY(selectable, BOOL)
RCT_CUSTOM_VIEW_PROPERTY(ellipsizeMode, NSString, RNTextEnginePreparedTextView)
{
  view.ellipsizeMode = [RCTConvert NSString:json];
}

@end
