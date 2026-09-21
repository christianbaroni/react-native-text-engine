#import "RNTextEngineColorUtils.h"
#import "RNTextEngineAttributedTextDisplayView.h"
#import "RNTextEngineTextAttributes.h"
#import "RNTextEngineTextShadowView.h"
#ifdef RCT_NEW_ARCH_ENABLED
#import "RNTextEngineTextViewShadowNode.h"
#endif
#import "RNTextEngineTextLayoutMetrics.h"
#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTShadowView+Layout.h>
#import <React/RCTUIManager.h>
#import <React/RCTUIManagerObserverCoordinator.h>
#import <React/RCTUIManagerUtils.h>
#ifdef RCT_NEW_ARCH_ENABLED
#import <React/RCTConversions.h>
#import <React/RCTViewComponentView.h>
#import <react/renderer/components/RNTextEngineSpec/Props.h>
#import <react/renderer/components/RNTextEngineSpec/RCTComponentViewHelpers.h>
#endif
#import <React/RCTViewManager.h>
#import <React/RCTView.h>
#import <React/UIView+React.h>

@interface RNTextEngineResolvedTextPayload : NSObject
@property (nonatomic, assign) BOOL hasNested;
@property (nonatomic, assign) int64_t payloadHash;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSArray<NSNumber *> *runStarts;
@property (nonatomic, copy) NSArray<NSNumber *> *runEnds;
@property (nonatomic, copy) NSArray<NSNumber *> *runStyleMasks;
@property (nonatomic, copy) NSArray<NSString *> *runColors;
@property (nonatomic, copy) NSArray<NSString *> *runFontFamilies;
@property (nonatomic, copy) NSArray<NSNumber *> *runFontSizes;
@property (nonatomic, copy) NSArray<NSString *> *runFontWeights;
@property (nonatomic, copy) NSArray<NSString *> *runFontStyles;
@property (nonatomic, copy) NSArray<NSNumber *> *runLetterSpacings;
@property (nonatomic, copy) NSArray<NSNumber *> *runLineHeights;
@property (nonatomic, copy) NSArray<NSNumber *> *runTabularNumbers;
@end

#ifdef RCT_NEW_ARCH_ENABLED
@interface RNTextEngineTextView : UIView <RNTextEngineAccessibilityOwner>
#else
@interface RNTextEngineTextView : RCTView <RNTextEngineAccessibilityOwner>
#endif
@property (nonatomic, assign) BOOL allowFontScaling;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, copy) NSString *ellipsizeMode;
@property (nonatomic, copy) NSString *fontFamily;
@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, copy) NSString *fontStyle;
@property (nonatomic, copy) NSString *fontWeight;
@property (nonatomic, assign) CGFloat letterSpacing;
@property (nonatomic, assign) CGFloat lineHeight;
@property (nonatomic, assign) NSInteger numberOfLines;
@property (nonatomic, assign) BOOL anchorToCapHeight;
@property (nonatomic, assign) BOOL tabularNumbers;
@property (nonatomic, copy) NSArray<NSString *> *runColors;
@property (nonatomic, assign) NSInteger runCount;
@property (nonatomic, copy) NSArray<NSNumber *> *runEnds;
@property (nonatomic, copy) NSArray<NSString *> *runFontFamilies;
@property (nonatomic, copy) NSArray<NSNumber *> *runFontSizes;
@property (nonatomic, copy) NSArray<NSString *> *runFontStyles;
@property (nonatomic, copy) NSArray<NSString *> *runFontWeights;
@property (nonatomic, copy) NSArray<NSNumber *> *runLetterSpacings;
@property (nonatomic, copy) NSArray<NSNumber *> *runLineHeights;
@property (nonatomic, copy) NSArray<NSNumber *> *runStarts;
@property (nonatomic, copy) NSArray<NSNumber *> *runStyleMasks;
@property (nonatomic, copy) NSArray<NSNumber *> *runTabularNumbers;
- (void)setRuns:(std::vector<RNTextEngineTextRun>)runs;
@property (nonatomic, assign) BOOL selectable;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *textAlign;
@property (nonatomic, copy) NSString *textTransform;
@property (nonatomic, strong) RNTextEngineResolvedTextPayload *resolvedNestedPayload;
@property (nonatomic, strong) UIColor *textDecorationColor;
@property (nonatomic, copy) NSString *textDecorationLine;
@property (nonatomic, copy) NSString *textDecorationStyle;
@property (nonatomic, assign) UIEdgeInsets reactBorderInsets;
@property (nonatomic, assign) UIEdgeInsets reactPaddingInsets;
@property (nonatomic, strong) UIColor *textShadowColor;
@property (nonatomic, assign) CGSize textShadowOffset;
@property (nonatomic, assign) CGFloat textShadowRadius;
@property (nonatomic, assign) BOOL rnteIsVirtualTextSpan;
- (void)applyResolvedNestedPayloadMap:(NSDictionary<NSString *, id> *)payloadMap;
#ifdef RCT_NEW_ARCH_ENABLED
- (void)setFabricProps:(std::shared_ptr<const facebook::react::RNTextEngineTextViewProps>)props;
- (void)setPreparedContent:(std::shared_ptr<const RNTextEngineTextContent>)content;
- (void)prepareForRecycle;
#endif
@end

#ifdef RCT_NEW_ARCH_ENABLED

using namespace facebook::react;

@interface RNTextEngineTextViewComponentView : RCTViewComponentView <RCTRNTextEngineTextViewViewProtocol, RNTextEngineAccessibilityOwner>
@end

@implementation RNTextEngineTextViewComponentView {
  RNTextEngineTextView *_textView;
}

- (BOOL)isTextAccessibilityElement { return [super isAccessibilityElement]; }
- (NSString *)explicitAccessibilityLabel { return [super accessibilityLabel]; }
- (UIAccessibilityTraits)accessibilityTraits { return [super accessibilityTraits] | UIAccessibilityTraitStaticText; }
- (BOOL)isAccessibilityElement { return !_textView.selectable && [super isAccessibilityElement]; }
- (NSString *)accessibilityLabel { return [super accessibilityLabel] ?: _textView.accessibilityLabel; }

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNTextEngineTextViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    static const auto defaultProps = std::make_shared<const RNTextEngineTextViewProps>();
    _props = defaultProps;
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.layer.backgroundColor = UIColor.clearColor.CGColor;
    _textView = [[RNTextEngineTextView alloc] initWithFrame:self.bounds];
    _textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_textView];
  }

  return self;
}

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &oldViewProps = static_cast<const RNTextEngineTextViewProps &>(*_props);
  const auto &newViewProps = static_cast<const RNTextEngineTextViewProps &>(*props);

  [_textView setFabricProps:std::static_pointer_cast<const RNTextEngineTextViewProps>(props)];
  if (oldViewProps.anchorToCapHeight != newViewProps.anchorToCapHeight) {
    _textView.anchorToCapHeight = newViewProps.anchorToCapHeight;
  }
  if (oldViewProps.numberOfLines != newViewProps.numberOfLines) {
    _textView.numberOfLines = newViewProps.numberOfLines;
  }
  if (oldViewProps.selectable != newViewProps.selectable) {
    _textView.selectable = newViewProps.selectable;
  }
  if (oldViewProps.ellipsizeMode != newViewProps.ellipsizeMode) {
    _textView.ellipsizeMode = RCTNSStringFromStringNilIfEmpty(newViewProps.ellipsizeMode);
  }
  if (oldViewProps.textAlign != newViewProps.textAlign) {
    _textView.textAlign = RCTNSStringFromStringNilIfEmpty(newViewProps.textAlign);
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)updateLayoutMetrics:(const LayoutMetrics &)layoutMetrics oldLayoutMetrics:(const LayoutMetrics &)oldLayoutMetrics
{
  [super updateLayoutMetrics:layoutMetrics oldLayoutMetrics:oldLayoutMetrics];

  UIEdgeInsets borderInsets = RCTUIEdgeInsetsFromEdgeInsets(layoutMetrics.borderWidth);
  UIEdgeInsets paddingInsets = RCTUIEdgeInsetsFromEdgeInsets(layoutMetrics.contentInsets - layoutMetrics.borderWidth);
  _textView.reactBorderInsets = borderInsets;
  _textView.reactPaddingInsets = paddingInsets;
  _textView.frame = self.bounds;
}

- (void)updateState:(const State::Shared &)state oldState:(const State::Shared &)oldState
{
  const auto textState = std::static_pointer_cast<const RNTextEngineTextViewShadowNode::ConcreteState>(state);
  [_textView setPreparedContent:textState ? textState->getData().content : nullptr];
  [super updateState:state oldState:oldState];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _textView.frame = self.bounds;
}

- (void)prepareForRecycle
{
  const Props::Shared oldProps = _props;
  static const auto defaultProps = std::make_shared<const RNTextEngineTextViewProps>();
  [self updateProps:defaultProps oldProps:oldProps];
  [_textView prepareForRecycle];
  [super prepareForRecycle];
}

@end

#endif

@implementation RNTextEngineResolvedTextPayload
@end

static UIEdgeInsets RNTextEngineUIEdgeInsetsAdd(UIEdgeInsets left, UIEdgeInsets right)
{
  return UIEdgeInsetsMake(
      left.top + right.top,
      left.left + right.left,
      left.bottom + right.bottom,
      left.right + right.right);
}

@implementation RNTextEngineTextView {
  RNTextEngineAttributedTextDisplayView *_displayView;
  NSAttributedString *_displayText;
  UITextView *_interactionTextView;
  BOOL _textDisplayDirty;
  std::vector<RNTextEngineTextRun> _runs;
#ifdef RCT_NEW_ARCH_ENABLED
  std::shared_ptr<const RNTextEngineTextViewProps> _fabricProps;
  std::shared_ptr<const RNTextEngineTextContent> _preparedContent;
#endif
}

@synthesize anchorToCapHeight = _anchorToCapHeight;

- (BOOL)isTextAccessibilityElement { return [super isAccessibilityElement]; }
- (NSString *)explicitAccessibilityLabel { return [super accessibilityLabel]; }
- (UIAccessibilityTraits)accessibilityTraits { return [super accessibilityTraits] | UIAccessibilityTraitStaticText; }
- (BOOL)isAccessibilityElement { return !_selectable && [super isAccessibilityElement]; }
- (NSString *)accessibilityLabel { return [super accessibilityLabel] ?: _displayText.string; }

- (void)commonInit
{
  self.backgroundColor = UIColor.clearColor;
  self.clipsToBounds = NO;
  self.opaque = NO;
  self.layer.backgroundColor = UIColor.clearColor.CGColor;
  self.layer.opaque = NO;
  _textDisplayDirty = YES;
  _fontSize = 14;
  _reactBorderInsets = UIEdgeInsetsZero;
  _reactPaddingInsets = UIEdgeInsetsZero;

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

- (void)didUpdateReactSubviews
{
  // Nested TextView children are virtual text payload inputs. The display surface
  // is this view's attributed-text owner, so React-managed child view mounting is
  // intentionally disabled.
}

- (void)setRnteIsVirtualTextSpan:(BOOL)rnteIsVirtualTextSpan
{
}

- (std::vector<RNTextEngineTextRun>)resolvedRuns
{
  if (_runStarts.count == 0 || _runEnds.count == 0 || _runStyleMasks.count == 0) return _runs;
  return RNTextEngineTextRunsFromArrays(
      _runStarts, _runEnds, _runStyleMasks, _runColors, _runFontFamilies, _runFontSizes,
      _runFontStyles, _runFontWeights, _runLetterSpacings, _runLineHeights, _runTabularNumbers, _runCount);
}

- (std::vector<RNTextEngineTextRun>)resolvedRunsFromPayload:(RNTextEngineResolvedTextPayload *)payload
{
  if (!payload.hasNested) return {};
  return RNTextEngineTextRunsFromArrays(
      payload.runStarts, payload.runEnds, payload.runStyleMasks, payload.runColors,
      payload.runFontFamilies, payload.runFontSizes, payload.runFontStyles, payload.runFontWeights,
      payload.runLetterSpacings, payload.runLineHeights, payload.runTabularNumbers);
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
  _interactionTextView.textAlignment = RNTextEngineTextResolveAlignment(_textAlign);
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

  if (_textDisplayDirty) {
    _textDisplayDirty = NO;
    [self updateTextDisplay];
  }

  [self updateContentFrames];
}

- (void)invalidateTextDisplay
{
  _textDisplayDirty = YES;
  [self setNeedsLayout];
}

- (UIEdgeInsets)resolvedCapHeightInsets
{
  if (!_anchorToCapHeight || CGRectIsEmpty(self.bounds)) return UIEdgeInsetsZero;

  CGFloat width = CGRectGetWidth(self.bounds);
  return [_displayView capHeightInsetsForWidth:width];
}

- (UIEdgeInsets)resolvedTextInsets
{
  return RNTextEngineUIEdgeInsetsAdd(_reactBorderInsets, _reactPaddingInsets);
}

- (void)updateContentFrames
{
  UIEdgeInsets textInsets = [self resolvedTextInsets];
  _displayView.contentInsets = textInsets;

  UIEdgeInsets capInsets = [self resolvedCapHeightInsets];
  CGRect displayFrame = self.bounds;
  displayFrame.origin.y -= capInsets.top;
  displayFrame.size.height += capInsets.top + capInsets.bottom;

  _displayView.frame = displayFrame;
  RNTextEngineApplyInteractionTextViewFrame(_interactionTextView, displayFrame, textInsets);
}

- (void)setReactBorderInsets:(UIEdgeInsets)reactBorderInsets
{
  if (UIEdgeInsetsEqualToEdgeInsets(_reactBorderInsets, reactBorderInsets)) return;
  _reactBorderInsets = reactBorderInsets;
  [self setNeedsLayout];
}

- (void)setReactPaddingInsets:(UIEdgeInsets)reactPaddingInsets
{
  if (UIEdgeInsetsEqualToEdgeInsets(_reactPaddingInsets, reactPaddingInsets)) return;
  _reactPaddingInsets = reactPaddingInsets;
  [self setNeedsLayout];
}

- (void)setText:(NSString *)text
{
  _text = [text copy];
  [self invalidateTextDisplay];
}

- (void)setAllowFontScaling:(BOOL)allowFontScaling
{
  if (_allowFontScaling == allowFontScaling) return;
  _allowFontScaling = allowFontScaling;
  [self invalidateTextDisplay];
}

- (void)setColor:(UIColor *)color
{
  _color = color;
  [self invalidateTextDisplay];
}

- (void)setFontFamily:(NSString *)fontFamily
{
  _fontFamily = [fontFamily copy];
  [self invalidateTextDisplay];
}

- (void)setFontSize:(CGFloat)fontSize
{
  _fontSize = fontSize;
  [self invalidateTextDisplay];
}

- (void)setFontStyle:(NSString *)fontStyle
{
  _fontStyle = [fontStyle copy];
  [self invalidateTextDisplay];
}

- (void)setFontWeight:(NSString *)fontWeight
{
  _fontWeight = [fontWeight copy];
  [self invalidateTextDisplay];
}

- (void)setLetterSpacing:(CGFloat)letterSpacing
{
  _letterSpacing = letterSpacing;
  [self invalidateTextDisplay];
}

- (void)setLineHeight:(CGFloat)lineHeight
{
  _lineHeight = lineHeight;
  [self invalidateTextDisplay];
}

- (void)setTabularNumbers:(BOOL)tabularNumbers
{
  if (_tabularNumbers == tabularNumbers) return;
  _tabularNumbers = tabularNumbers;
  [self invalidateTextDisplay];
}

- (void)setAnchorToCapHeight:(BOOL)anchorToCapHeight
{
  if (_anchorToCapHeight == anchorToCapHeight) return;
  _anchorToCapHeight = anchorToCapHeight;
  [self setNeedsLayout];
}

- (void)setRuns:(std::vector<RNTextEngineTextRun>)runs
{
  _runs = std::move(runs);
  [self invalidateTextDisplay];
}

- (void)setRunStarts:(NSArray<NSNumber *> *)runStarts
{
  _runStarts = [runStarts copy];
  [self invalidateTextDisplay];
}

- (void)setRunCount:(NSInteger)runCount
{
  _runCount = runCount;
  [self invalidateTextDisplay];
}

- (void)setRunEnds:(NSArray<NSNumber *> *)runEnds
{
  _runEnds = [runEnds copy];
  [self invalidateTextDisplay];
}

- (void)setRunStyleMasks:(NSArray<NSNumber *> *)runStyleMasks
{
  _runStyleMasks = [runStyleMasks copy];
  [self invalidateTextDisplay];
}

- (void)setRunColors:(NSArray<NSString *> *)runColors
{
  _runColors = [runColors copy];
  [self invalidateTextDisplay];
}

- (void)setRunFontFamilies:(NSArray<NSString *> *)runFontFamilies
{
  _runFontFamilies = [runFontFamilies copy];
  [self invalidateTextDisplay];
}

- (void)setRunFontSizes:(NSArray<NSNumber *> *)runFontSizes
{
  _runFontSizes = [runFontSizes copy];
  [self invalidateTextDisplay];
}

- (void)setRunFontWeights:(NSArray<NSString *> *)runFontWeights
{
  _runFontWeights = [runFontWeights copy];
  [self invalidateTextDisplay];
}

- (void)setRunFontStyles:(NSArray<NSString *> *)runFontStyles
{
  _runFontStyles = [runFontStyles copy];
  [self invalidateTextDisplay];
}

- (void)setRunLetterSpacings:(NSArray<NSNumber *> *)runLetterSpacings
{
  _runLetterSpacings = [runLetterSpacings copy];
  [self invalidateTextDisplay];
}

- (void)setRunLineHeights:(NSArray<NSNumber *> *)runLineHeights
{
  _runLineHeights = [runLineHeights copy];
  [self invalidateTextDisplay];
}

- (void)setRunTabularNumbers:(NSArray<NSNumber *> *)runTabularNumbers
{
  _runTabularNumbers = [runTabularNumbers copy];
  [self invalidateTextDisplay];
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

- (void)setTextAlign:(NSString *)textAlign
{
  _textAlign = [textAlign copy];
  NSTextAlignment alignment = RNTextEngineTextResolveAlignment(textAlign);
  _interactionTextView.textAlignment = alignment;
  [self invalidateTextDisplay];
}

- (void)setTextTransform:(NSString *)textTransform
{
  if ((_textTransform == textTransform) || [_textTransform isEqualToString:textTransform]) return;
  _textTransform = [textTransform copy];
  [self invalidateTextDisplay];
}

- (void)setResolvedNestedPayload:(RNTextEngineResolvedTextPayload *)resolvedNestedPayload
{
  BOOL nextHasNested = resolvedNestedPayload != nil && resolvedNestedPayload.hasNested;
  BOOL hasCurrentNested = _resolvedNestedPayload != nil && _resolvedNestedPayload.hasNested;
  if (hasCurrentNested == nextHasNested &&
      (!nextHasNested || (_resolvedNestedPayload.payloadHash == resolvedNestedPayload.payloadHash &&
                          [_resolvedNestedPayload.text isEqualToString:resolvedNestedPayload.text]))) {
    return;
  }

  _resolvedNestedPayload = nextHasNested ? resolvedNestedPayload : nil;
  [self invalidateTextDisplay];
}

- (void)applyResolvedNestedPayloadMap:(NSDictionary<NSString *, id> *)payloadMap
{
  if (![payloadMap isKindOfClass:[NSDictionary class]]) {
    self.resolvedNestedPayload = nil;
    return;
  }

  BOOL hasNested = [RCTConvert BOOL:payloadMap[@"hasNested"]];
  if (!hasNested) {
    self.resolvedNestedPayload = nil;
    return;
  }

  RNTextEngineResolvedTextPayload *payload = [RNTextEngineResolvedTextPayload new];
  payload.hasNested = YES;
  payload.payloadHash = [RCTConvert int64_t:payloadMap[@"hash"]];
  payload.text = [RCTConvert NSString:payloadMap[@"text"]] ?: @"";
  payload.runStarts = [RCTConvert NSArray:payloadMap[@"runStarts"]] ?: @[];
  payload.runEnds = [RCTConvert NSArray:payloadMap[@"runEnds"]] ?: @[];
  payload.runStyleMasks = [RCTConvert NSArray:payloadMap[@"runStyleMasks"]] ?: @[];
  payload.runColors = [RCTConvert NSArray:payloadMap[@"runColors"]] ?: @[];
  payload.runFontFamilies = [RCTConvert NSArray:payloadMap[@"runFontFamilies"]] ?: @[];
  payload.runFontSizes = [RCTConvert NSArray:payloadMap[@"runFontSizes"]] ?: @[];
  payload.runFontWeights = [RCTConvert NSArray:payloadMap[@"runFontWeights"]] ?: @[];
  payload.runFontStyles = [RCTConvert NSArray:payloadMap[@"runFontStyles"]] ?: @[];
  payload.runLetterSpacings = [RCTConvert NSArray:payloadMap[@"runLetterSpacings"]] ?: @[];
  payload.runLineHeights = [RCTConvert NSArray:payloadMap[@"runLineHeights"]] ?: @[];
  payload.runTabularNumbers = [RCTConvert NSArray:payloadMap[@"runTabularNumbers"]] ?: @[];
  self.resolvedNestedPayload = payload;
}

- (void)setTextDecorationColor:(UIColor *)textDecorationColor
{
  _textDecorationColor = textDecorationColor;
  [self invalidateTextDisplay];
}

- (void)setTextDecorationLine:(NSString *)textDecorationLine
{
  if ((_textDecorationLine == textDecorationLine) || [_textDecorationLine isEqualToString:textDecorationLine]) return;
  _textDecorationLine = [textDecorationLine copy];
  [self invalidateTextDisplay];
}

- (void)setTextDecorationStyle:(NSString *)textDecorationStyle
{
  if ((_textDecorationStyle == textDecorationStyle) || [_textDecorationStyle isEqualToString:textDecorationStyle]) return;
  _textDecorationStyle = [textDecorationStyle copy];
  [self invalidateTextDisplay];
}

- (void)setTextShadowColor:(UIColor *)textShadowColor
{
  _textShadowColor = textShadowColor;
  [self invalidateTextDisplay];
}

- (void)setTextShadowOffset:(CGSize)textShadowOffset
{
  if (CGSizeEqualToSize(_textShadowOffset, textShadowOffset)) return;
  _textShadowOffset = textShadowOffset;
  [self invalidateTextDisplay];
}

- (void)setTextShadowRadius:(CGFloat)textShadowRadius
{
  if (_textShadowRadius == textShadowRadius) return;
  _textShadowRadius = textShadowRadius;
  [self invalidateTextDisplay];
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
  [self invalidateTextDisplay];
}

#ifdef RCT_NEW_ARCH_ENABLED
- (void)prepareForRecycle
{
  _preparedContent.reset();
  _displayText = nil;
  _displayView.attributedText = nil;
  _textDisplayDirty = NO;
}

- (void)setFabricProps:(std::shared_ptr<const RNTextEngineTextViewProps>)props
{
  if (_fabricProps == nullptr || !RNTextEngineHasSameTextAttributes(*_fabricProps, *props)) {
    [self invalidateTextDisplay];
  }
  _fabricProps = std::move(props);
}

- (void)setPreparedContent:(std::shared_ptr<const RNTextEngineTextContent>)content
{
  if (_preparedContent == content) return;
  _preparedContent = std::move(content);
  [self invalidateTextDisplay];
}
#endif

- (NSAttributedString *)buildAttributedText
{
#ifdef RCT_NEW_ARCH_ENABLED
  if (_fabricProps != nullptr) {
    const auto &props = *_fabricProps;
    BOOL nested = _preparedContent != nullptr && _preparedContent->nestedText != nil;
    CGFloat fontScale = props.allowFontScaling ? RCTFontSizeMultiplier() : 1;
    BOOL environmentMatches = _preparedContent != nullptr &&
        (!props.allowFontScaling || _preparedContent->fontScale == fontScale) &&
        (nested || _preparedContent->locale == nil || [_preparedContent->locale isEqual:NSLocale.currentLocale]);
    if (environmentMatches && RNTextEngineHasSameTextAttributes(props, *_preparedContent->props)) {
      return _preparedContent->attributedText;
    }
    const auto flatRuns = nested ? std::vector<RNTextEngineTextRun>{} : RNTextEngineTextRunsFromProps(props);
    return RNTextEngineBuildAttributedText(
        nested ? _preparedContent->nestedText : RCTNSStringFromString(props.text),
        RNTextEngineTextAttributesFromProps(props, fontScale),
        nested ? _preparedContent->nestedRuns : flatRuns,
        nested ? nil : RCTNSStringFromStringNilIfEmpty(props.textTransform),
        nested);
  }
#endif
  RNTextEngineResolvedTextPayload *payload = _resolvedNestedPayload;
  BOOL nested = payload != nil && payload.hasNested;
  RNTextEngineTextAttributes attributes{
      .allowFontScaling = _allowFontScaling,
      .fontScale = _allowFontScaling ? RCTFontSizeMultiplier() : 1,
      .color = _color,
      .fontFamily = _fontFamily,
      .fontSize = _fontSize,
      .fontStyle = _fontStyle,
      .fontWeight = _fontWeight,
      .letterSpacing = _letterSpacing,
      .lineHeight = _lineHeight,
      .tabularNumbers = _tabularNumbers,
      .textAlign = _textAlign,
      .textDecorationColor = _textDecorationColor,
      .textDecorationLine = _textDecorationLine,
      .textDecorationStyle = _textDecorationStyle,
      .textShadowColor = _textShadowColor,
      .textShadowOffset = _textShadowOffset,
      .textShadowRadius = _textShadowRadius,
  };
  return RNTextEngineBuildAttributedText(
      (nested ? payload.text : _text) ?: @"",
      attributes,
      nested ? [self resolvedRunsFromPayload:payload] : [self resolvedRuns],
      nested ? nil : _textTransform,
      nested);
}

- (void)updateTextDisplay
{
  _displayText = [self buildAttributedText];
  BOOL textChanged = self.window != nil && UIAccessibilityIsVoiceOverRunning() &&
      ![_displayView.attributedText.string isEqualToString:_displayText.string ?: @""];
  _displayView.attributedText = _displayText ?: [[NSAttributedString alloc] initWithString:@""];
  _displayView.ellipsizeMode = _ellipsizeMode;
  _displayView.numberOfLines = _numberOfLines;
  _displayView.textAlignment = RNTextEngineTextResolveAlignment(_textAlign);
  _displayView.hidden = _selectable;
  if (_selectable) {
    UITextView *interactionTextView = [self ensureInteractionTextView];
    interactionTextView.attributedText = _displayText ?: [[NSAttributedString alloc] initWithString:@""];
    [self bringSubviewToFront:interactionTextView];
  }
  if (textChanged) UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

@end

@interface RNTextEngineTextViewManager : RCTViewManager <RCTUIManagerObserver>
@end

@implementation RNTextEngineTextViewManager {
  NSHashTable<RNTextEngineTextShadowView *> *_shadowViews;
}

RCT_EXPORT_MODULE(RNTextEngineTextView)

- (void)setBridge:(RCTBridge *)bridge
{
  [super setBridge:bridge];
  _shadowViews = [NSHashTable weakObjectsHashTable];
  [bridge.uiManager.observerCoordinator addObserver:self];
}

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (UIView *)view
{
  return [RNTextEngineTextView new];
}

- (RCTShadowView *)shadowView
{
  RNTextEngineTextShadowView *shadowView = [[RNTextEngineTextShadowView alloc] initWithBridge:self.bridge];
  [_shadowViews addObject:shadowView];
  return shadowView;
}

- (void)uiManagerWillPerformMounting:(__unused RCTUIManager *)uiManager
{
  for (RNTextEngineTextShadowView *shadowView in _shadowViews) {
    [shadowView uiManagerWillPerformMounting];
  }
}

RCT_EXPORT_VIEW_PROPERTY(color, UIColor)
RCT_EXPORT_VIEW_PROPERTY(allowFontScaling, BOOL)
RCT_EXPORT_VIEW_PROPERTY(ellipsizeMode, NSString)
RCT_EXPORT_VIEW_PROPERTY(fontFamily, NSString)
RCT_EXPORT_VIEW_PROPERTY(fontSize, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(fontStyle, NSString)
RCT_EXPORT_VIEW_PROPERTY(fontWeight, NSString)
RCT_EXPORT_VIEW_PROPERTY(letterSpacing, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(lineHeight, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(tabularNumbers, BOOL)
RCT_EXPORT_VIEW_PROPERTY(anchorToCapHeight, BOOL)
RCT_EXPORT_VIEW_PROPERTY(numberOfLines, NSInteger)
RCT_EXPORT_VIEW_PROPERTY(runColors, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runCount, NSInteger)
RCT_EXPORT_VIEW_PROPERTY(runEnds, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runFontFamilies, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runFontSizes, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runFontStyles, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runFontWeights, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runLetterSpacings, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runLineHeights, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runStarts, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runStyleMasks, NSArray)
RCT_EXPORT_VIEW_PROPERTY(runTabularNumbers, NSArray)
RCT_EXPORT_VIEW_PROPERTY(textDecorationColor, UIColor)
RCT_EXPORT_VIEW_PROPERTY(textDecorationLine, NSString)
RCT_EXPORT_VIEW_PROPERTY(textDecorationStyle, NSString)
RCT_EXPORT_VIEW_PROPERTY(textShadowColor, UIColor)
RCT_EXPORT_VIEW_PROPERTY(textShadowOffset, CGSize)
RCT_EXPORT_VIEW_PROPERTY(textShadowRadius, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(rnteIsVirtualTextSpan, BOOL)
RCT_CUSTOM_VIEW_PROPERTY(runs, NSArray, RNTextEngineTextView)
{
  NSArray *rawRuns = json == nil || json == (id)kCFNull ? nil : [RCTConvert NSArray:json];
  if (rawRuns == nil) {
    [view setRuns:{}];
    return;
  }

  std::vector<RNTextEngineTextRun> resolvedRuns;
  resolvedRuns.reserve(rawRuns.count);
  for (id rawRun in rawRuns) {
    if (![rawRun isKindOfClass:[NSDictionary class]]) continue;
    NSDictionary *runDictionary = (NSDictionary *)rawRun;
    NSNumber *start = [RCTConvert NSNumber:runDictionary[@"start"]];
    NSNumber *end = [RCTConvert NSNumber:runDictionary[@"end"]];
    NSDictionary *styleDictionary = [RCTConvert NSDictionary:runDictionary[@"style"]];
    if (start == nil || end == nil || styleDictionary == nil) continue;

    RNTextEngineTextRunStyle style;
    id rawColor = styleDictionary[@"color"];
    if ([rawColor isKindOfClass:[NSString class]]) {
      style.color = RNTextEngineResolveColorValue((NSString *)rawColor);
    }
    style.fontFamily = [RCTConvert NSString:styleDictionary[@"fontFamily"]];
    NSNumber *fontSize = [RCTConvert NSNumber:styleDictionary[@"fontSize"]];
    if (fontSize != nil) style.fontSize = fontSize.doubleValue;
    style.fontStyle = [RCTConvert NSString:styleDictionary[@"fontStyle"]];
    style.fontWeight = [RCTConvert NSString:styleDictionary[@"fontWeight"]];
    NSNumber *letterSpacing = [RCTConvert NSNumber:styleDictionary[@"letterSpacing"]];
    if (letterSpacing != nil) style.letterSpacing = letterSpacing.doubleValue;
    NSNumber *lineHeight = [RCTConvert NSNumber:styleDictionary[@"lineHeight"]];
    if (lineHeight != nil) style.lineHeight = lineHeight.doubleValue;
    NSNumber *tabularNumbers = [RCTConvert NSNumber:styleDictionary[@"tabularNumbers"]];
    if (tabularNumbers != nil) style.tabularNumbers = tabularNumbers.boolValue;

    RNTextEngineTextRun run;
    run.start = start.integerValue;
    run.end = end.integerValue;
    run.style = style;
    resolvedRuns.push_back(std::move(run));
  }

  [view setRuns:std::move(resolvedRuns)];
}
RCT_EXPORT_VIEW_PROPERTY(selectable, BOOL)
RCT_EXPORT_VIEW_PROPERTY(text, NSString)
RCT_EXPORT_VIEW_PROPERTY(textAlign, NSString)
RCT_EXPORT_VIEW_PROPERTY(textTransform, NSString)
RCT_EXPORT_SHADOW_PROPERTY(anchorToCapHeight, BOOL)
RCT_CUSTOM_SHADOW_PROPERTY(ellipsizeMode, NSString, RNTextEngineTextShadowView)
{
  view.ellipsizeMode = [RCTConvert NSString:json];
}
RCT_EXPORT_SHADOW_PROPERTY(allowFontScaling, BOOL)
RCT_EXPORT_SHADOW_PROPERTY(color, UIColor)
RCT_EXPORT_SHADOW_PROPERTY(fontFamily, NSString)
RCT_EXPORT_SHADOW_PROPERTY(fontSize, CGFloat)
RCT_EXPORT_SHADOW_PROPERTY(fontStyle, NSString)
RCT_EXPORT_SHADOW_PROPERTY(fontWeight, NSString)
RCT_EXPORT_SHADOW_PROPERTY(letterSpacing, CGFloat)
RCT_EXPORT_SHADOW_PROPERTY(lineHeight, CGFloat)
RCT_EXPORT_SHADOW_PROPERTY(textAlign, NSString)
RCT_EXPORT_SHADOW_PROPERTY(rnteHasAllowFontScaling, BOOL)
RCT_EXPORT_SHADOW_PROPERTY(rnteHasLetterSpacing, BOOL)
RCT_EXPORT_SHADOW_PROPERTY(rnteHasTabularNumbers, BOOL)
RCT_EXPORT_SHADOW_PROPERTY(tabularNumbers, BOOL)
RCT_EXPORT_SHADOW_PROPERTY(numberOfLines, NSInteger)
RCT_EXPORT_SHADOW_PROPERTY(runColors, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runCount, NSInteger)
RCT_EXPORT_SHADOW_PROPERTY(runEnds, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runFontFamilies, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runFontSizes, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runFontStyles, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runFontWeights, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runLetterSpacings, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runLineHeights, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runStarts, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runStyleMasks, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(runTabularNumbers, NSArray)
RCT_EXPORT_SHADOW_PROPERTY(text, NSString)
RCT_EXPORT_SHADOW_PROPERTY(textTransform, NSString)

@end
