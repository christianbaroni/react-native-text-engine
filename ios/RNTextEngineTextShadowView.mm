#import "RNTextEngineTextShadowView.h"

#import "RNTextEngineBindings.h"
#import "RNTextEngineTextTransform.h"
#import <React/RCTBridge.h>
#import <React/RCTShadowView+Layout.h>
#import <React/RCTUIManager.h>
#import <React/RCTUtils.h>
#import <yoga/Yoga.h>

using namespace rntextengine;

@interface UIView (RNTextEngineContentInsets)
@property (nonatomic, assign) UIEdgeInsets reactBorderInsets;
@property (nonatomic, assign) UIEdgeInsets reactPaddingInsets;
@end

@protocol RNTextEngineResolvedPayloadApplying <NSObject>
- (void)applyResolvedNestedPayloadMap:(NSDictionary<NSString *, id> * _Nullable)payloadMap;
@end

@interface RNTextEngineResolvedStyle : NSObject <NSCopying>
@property (nonatomic, copy, nullable) NSString *color;
@property (nonatomic, copy, nullable) NSString *fontFamily;
@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, copy, nullable) NSString *fontStyle;
@property (nonatomic, copy, nullable) NSString *fontWeight;
@property (nonatomic, assign) CGFloat letterSpacing;
@property (nonatomic, assign) CGFloat lineHeight;
@property (nonatomic, assign) BOOL tabularNumbers;
@property (nonatomic, copy, nullable) NSString *textTransform;
@property (nonatomic, assign) BOOL allowFontScaling;
@end

@interface RNTextEngineResolvedRun : NSObject
@property (nonatomic, assign) NSInteger start;
@property (nonatomic, assign) NSInteger end;
@property (nonatomic, strong) RNTextEngineResolvedStyle *style;
@end

@interface RNTextEngineResolvedSegment : NSObject
@property (nonatomic, assign) NSInteger start;
@property (nonatomic, assign) NSInteger end;
@property (nonatomic, strong) RNTextEngineResolvedStyle *style;
@end

@interface RNTextEngineResolvedPayload : NSObject
@property (nonatomic, assign) BOOL hasNested;
@property (nonatomic, assign) int64_t payloadHash;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSArray<NSNumber *> *runStarts;
@property (nonatomic, copy) NSArray<NSNumber *> *runEnds;
@property (nonatomic, copy) NSArray<NSNumber *> *runStyleMasks;
@property (nonatomic, copy) NSArray *runColors;
@property (nonatomic, copy) NSArray *runFontFamilies;
@property (nonatomic, copy) NSArray<NSNumber *> *runFontSizes;
@property (nonatomic, copy) NSArray *runFontWeights;
@property (nonatomic, copy) NSArray *runFontStyles;
@property (nonatomic, copy) NSArray<NSNumber *> *runLetterSpacings;
@property (nonatomic, copy) NSArray<NSNumber *> *runLineHeights;
@property (nonatomic, copy) NSArray<NSNumber *> *runTabularNumbers;
+ (instancetype)empty;
- (NSDictionary<NSString *, id> *)asMap;
@end

@interface RNTextEngineTextShadowView ()

- (CGSize)measureWithWidth:(CGFloat)width
                 widthMode:(YGMeasureMode)widthMode
                    height:(CGFloat)height
                heightMode:(YGMeasureMode)heightMode;

- (RNTextEngineResolvedPayload *)resolvePayload;
- (BOOL)appendNodePayload:(RNTextEngineTextShadowView *)node
              parentStyle:(RNTextEngineResolvedStyle *)parentStyle
              textBuilder:(NSMutableString *)textBuilder
                 segments:(NSMutableArray<RNTextEngineResolvedSegment *> *)segments;
- (void)emitStyledText:(NSString *)text
             baseStyle:(RNTextEngineResolvedStyle *)baseStyle
                  runs:(NSArray<RNTextEngineResolvedRun *> *)runs
           textBuilder:(NSMutableString *)textBuilder
              segments:(NSMutableArray<RNTextEngineResolvedSegment *> *)segments;
- (void)appendSegment:(NSString *)text
                style:(RNTextEngineResolvedStyle *)style
          textBuilder:(NSMutableString *)textBuilder
             segments:(NSMutableArray<RNTextEngineResolvedSegment *> *)segments;
- (RNTextEngineResolvedStyle *)resolveNodeStyleWithParent:(nullable RNTextEngineResolvedStyle *)parentStyle;
- (BOOL)hasValidatedNestedTextChildren;
- (NSArray<RNTextEngineResolvedRun *> *)resolveLocalRunsWithBaseStyle:(RNTextEngineResolvedStyle *)baseStyle;
- (NSString *)resolveTransformedText:(NSString *)text
                       textTransform:(NSString *)textTransform
                                runs:(NSMutableArray<RNTextEngineResolvedRun *> *)runs;
- (RNTextEngineResolvedPayload *)buildPayloadFromText:(NSString *)text
                                             segments:(NSArray<RNTextEngineResolvedSegment *> *)segments
                                            rootStyle:(RNTextEngineResolvedStyle *)rootStyle
                                            hasNested:(BOOL)hasNested;
- (BOOL)isVirtualNestedTextNode;
- (void)markMeasurementDirtyForYogaOwnerChain;
- (void)invalidateParentChainFromChildAffectingMeasurement:(BOOL)affectsMeasurement;
- (void)invalidateFromNestedChildAffectingMeasurement:(BOOL)affectsMeasurement;

@end

static YGSize RNTextEngineTextShadowViewMeasure(
    YGNodeConstRef node,
    float width,
    YGMeasureMode widthMode,
    float height,
    YGMeasureMode heightMode)
{
  RNTextEngineTextShadowView *shadowView = (__bridge RNTextEngineTextShadowView *)YGNodeGetContext(node);
  CGSize measuredSize = [shadowView measureWithWidth:width widthMode:widthMode height:height heightMode:heightMode];
  return (YGSize){RCTYogaFloatFromCoreGraphicsFloat(measuredSize.width), RCTYogaFloatFromCoreGraphicsFloat(measuredSize.height)};
}

static NSString *RNTextEngineDescribeShadowChild(RCTShadowView *child)
{
  NSString *viewName = child.viewName;
  if (viewName.length > 0) return viewName;
  return NSStringFromClass(child.class);
}

@implementation RNTextEngineResolvedStyle

- (id)copyWithZone:(NSZone *)zone
{
  RNTextEngineResolvedStyle *copy = [[[self class] allocWithZone:zone] init];
  copy.color = self.color;
  copy.fontFamily = self.fontFamily;
  copy.fontSize = self.fontSize;
  copy.fontStyle = self.fontStyle;
  copy.fontWeight = self.fontWeight;
  copy.letterSpacing = self.letterSpacing;
  copy.lineHeight = self.lineHeight;
  copy.tabularNumbers = self.tabularNumbers;
  copy.textTransform = self.textTransform;
  copy.allowFontScaling = self.allowFontScaling;
  return copy;
}

@end

@implementation RNTextEngineResolvedRun
@end

@implementation RNTextEngineResolvedSegment
@end

@implementation RNTextEngineResolvedPayload

+ (instancetype)empty
{
  RNTextEngineResolvedPayload *payload = [RNTextEngineResolvedPayload new];
  payload.hasNested = NO;
  payload.payloadHash = 0;
  payload.text = @"";
  payload.runStarts = @[];
  payload.runEnds = @[];
  payload.runStyleMasks = @[];
  payload.runColors = @[];
  payload.runFontFamilies = @[];
  payload.runFontSizes = @[];
  payload.runFontWeights = @[];
  payload.runFontStyles = @[];
  payload.runLetterSpacings = @[];
  payload.runLineHeights = @[];
  payload.runTabularNumbers = @[];
  return payload;
}

- (NSDictionary<NSString *, id> *)asMap
{
  if (!self.hasNested) {
    return @{ @"hasNested" : @NO };
  }

  return @{
    @"hasNested" : @YES,
    @"hash" : @(self.payloadHash),
    @"text" : self.text ?: @"",
    @"runStarts" : self.runStarts ?: @[],
    @"runEnds" : self.runEnds ?: @[],
    @"runStyleMasks" : self.runStyleMasks ?: @[],
    @"runColors" : self.runColors ?: @[],
    @"runFontFamilies" : self.runFontFamilies ?: @[],
    @"runFontSizes" : self.runFontSizes ?: @[],
    @"runFontWeights" : self.runFontWeights ?: @[],
    @"runFontStyles" : self.runFontStyles ?: @[],
    @"runLetterSpacings" : self.runLetterSpacings ?: @[],
    @"runLineHeights" : self.runLineHeights ?: @[],
    @"runTabularNumbers" : self.runTabularNumbers ?: @[],
  };
}

@end

namespace {

static NSInteger RNTextEngineRunStyleHasColor = 1 << 0;
static NSInteger RNTextEngineRunStyleHasFontFamily = 1 << 1;
static NSInteger RNTextEngineRunStyleHasFontSize = 1 << 2;
static NSInteger RNTextEngineRunStyleHasFontStyle = 1 << 3;
static NSInteger RNTextEngineRunStyleHasFontWeight = 1 << 4;
static NSInteger RNTextEngineRunStyleHasLetterSpacing = 1 << 5;
static NSInteger RNTextEngineRunStyleHasLineHeight = 1 << 6;
static NSInteger RNTextEngineRunStyleHasTabularNumbers = 1 << 7;

NSNumber *RNTextEngineNumberOrNil(id value)
{
  return [value isKindOfClass:[NSNumber class]] ? (NSNumber *)value : nil;
}

NSString *RNTextEngineStringOrNil(id value)
{
  return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

BOOL RNTextEngineStyleEquals(RNTextEngineResolvedStyle *left, RNTextEngineResolvedStyle *right)
{
  return ((left.color == right.color) || [left.color isEqualToString:right.color]) &&
      ((left.fontFamily == right.fontFamily) || [left.fontFamily isEqualToString:right.fontFamily]) &&
      left.fontSize == right.fontSize &&
      ((left.fontStyle == right.fontStyle) || [left.fontStyle isEqualToString:right.fontStyle]) &&
      ((left.fontWeight == right.fontWeight) || [left.fontWeight isEqualToString:right.fontWeight]) &&
      left.letterSpacing == right.letterSpacing &&
      left.lineHeight == right.lineHeight &&
      left.tabularNumbers == right.tabularNumbers;
}

CGFloat RNTextEngineScaleTypographyValue(CGFloat value, BOOL allowFontScaling)
{
  return allowFontScaling ? value * RCTFontSizeMultiplier() : value;
}

RNTextEngineResolvedStyle *RNTextEngineNormalizePreparedStyle(RNTextEngineResolvedStyle *style)
{
  if (!style.allowFontScaling) return style;

  RNTextEngineResolvedStyle *normalized = [style copy];
  normalized.fontSize = RNTextEngineScaleTypographyValue(normalized.fontSize, YES);
  normalized.letterSpacing = RNTextEngineScaleTypographyValue(normalized.letterSpacing, YES);
  if (normalized.lineHeight > 0) {
    normalized.lineHeight = RNTextEngineScaleTypographyValue(normalized.lineHeight, YES);
  }
  normalized.allowFontScaling = NO;
  return normalized;
}

NSString *RNTextEngineColorString(UIColor *color)
{
  if (color == nil) return nil;

  CGFloat red = 0;
  CGFloat green = 0;
  CGFloat blue = 0;
  CGFloat alpha = 0;
  if (![color getRed:&red green:&green blue:&blue alpha:&alpha]) {
    CGColorRef cgColor = color.CGColor;
    size_t count = CGColorGetNumberOfComponents(cgColor);
    const CGFloat *components = CGColorGetComponents(cgColor);
    if (count == 2) {
      red = components[0];
      green = components[0];
      blue = components[0];
      alpha = components[1];
    } else if (count >= 4) {
      red = components[0];
      green = components[1];
      blue = components[2];
      alpha = components[3];
    } else {
      return nil;
    }
  }

  NSUInteger a = (NSUInteger)lrint(MIN(MAX(alpha, 0), 1) * 255.0);
  NSUInteger r = (NSUInteger)lrint(MIN(MAX(red, 0), 1) * 255.0);
  NSUInteger g = (NSUInteger)lrint(MIN(MAX(green, 0), 1) * 255.0);
  NSUInteger b = (NSUInteger)lrint(MIN(MAX(blue, 0), 1) * 255.0);
  return [NSString stringWithFormat:@"#%02lx%02lx%02lx%02lx", (unsigned long)a, (unsigned long)r, (unsigned long)g, (unsigned long)b];
}

NSInteger RNTextEngineResolveRunCount(
    NSInteger runCount,
    NSArray<NSNumber *> *runStarts,
    NSArray<NSNumber *> *runEnds,
    NSArray<NSNumber *> *runStyleMasks)
{
  if (runStarts.count == 0 || runEnds.count == 0 || runStyleMasks.count == 0) return 0;

  NSInteger resolvedRunCount = runCount > 0 ? runCount : MIN(runStarts.count, MIN(runEnds.count, runStyleMasks.count));
  resolvedRunCount = MIN(resolvedRunCount, MIN(runStarts.count, MIN(runEnds.count, runStyleMasks.count)));
  return MAX(resolvedRunCount, 0);
}

int64_t RNTextEngineHashCombine(int64_t hash, int64_t value)
{
  return (hash * 31) + value;
}

int64_t RNTextEngineHashObject(id value)
{
  return value == nil || value == (id)kCFNull ? 0 : (int64_t)[value hash];
}

CGFloat RNTextEngineResolveFontSize(CGFloat fontSize)
{
  return fontSize > 0 ? fontSize : 14;
}

} // namespace

@implementation RNTextEngineTextShadowView {
  __weak RCTBridge *_bridge;
  BOOL _needsUpdateView;
  BOOL _requestedMountRetry;
  uint64_t _preparedHandle;
  RNTextEngineResolvedPayload *_cachedResolvedPayload;
  NSNumber *_lastMountedNestedHash;
}

- (instancetype)initWithBridge:(RCTBridge *)bridge
{
  if ((self = [super init])) {
    _bridge = bridge;
    _fontSize = 0;
    _needsUpdateView = YES;
    _requestedMountRetry = NO;
    _preparedHandle = 0;
    _cachedResolvedPayload = nil;
    _lastMountedNestedHash = nil;
    YGNodeSetMeasureFunc(self.yogaNode, RNTextEngineTextShadowViewMeasure);
  }

  return self;
}

- (instancetype)init
{
  return [self initWithBridge:nil];
}

- (void)dealloc
{
  [self releasePreparedHandle];
}

- (BOOL)isYogaLeafNode
{
  return YES;
}

static void RNTextEngineApplyResolvedPayloadToView(
    UIView *view,
    UIEdgeInsets borderInsets,
    UIEdgeInsets paddingInsets,
    NSDictionary<NSString *, id> *payloadMap)
{
  if (view == nil) return;
  view.reactBorderInsets = borderInsets;
  view.reactPaddingInsets = paddingInsets;
  if ([view respondsToSelector:@selector(applyResolvedNestedPayloadMap:)]) {
    [(id<RNTextEngineResolvedPayloadApplying>)view applyResolvedNestedPayloadMap:payloadMap];
  }
}

- (void)insertReactSubview:(RCTShadowView *)subview atIndex:(NSInteger)index
{
  [super insertReactSubview:subview atIndex:index];
  [self invalidatePreparedHandle];
}

- (void)removeReactSubview:(RCTShadowView *)subview
{
  [super removeReactSubview:subview];
  [self invalidatePreparedHandle];
}

- (void)didUpdateReactSubviews
{
  [super didUpdateReactSubviews];
  [self invalidatePreparedHandle];
}

- (void)didSetProps:(NSArray<NSString *> *)changedProps
{
  [super didSetProps:changedProps];
  _needsUpdateView = YES;
}

- (void)dirtyLayout
{
  _needsUpdateView = YES;
  if ([self isVirtualNestedTextNode]) {
    [self invalidateParentChainFromChildAffectingMeasurement:YES];
    return;
  }
  YGNodeMarkDirty(self.yogaNode);
}

- (void)uiManagerWillPerformMounting
{
  if ([self isVirtualNestedTextNode]) {
    return;
  }

  if (!_needsUpdateView || _bridge == nil) {
    return;
  }

  UIEdgeInsets borderInsets = self.borderAsInsets;
  UIEdgeInsets paddingInsets = self.paddingAsInsets;
  NSNumber *tag = self.reactTag;

  RNTextEngineResolvedPayload *payload = [self resolvePayload];
  NSDictionary<NSString *, id> *payloadMap = nil;
  NSNumber *nextMountedNestedHash = nil;
  BOOL clearsMountedNestedPayload = NO;
  if (payload.hasNested) {
    payloadMap = [payload asMap];
    nextMountedNestedHash = @(payload.payloadHash);
  } else if (_lastMountedNestedHash != nil) {
    payloadMap = @{ @"hasNested" : @NO };
    clearsMountedNestedPayload = YES;
  }

  _requestedMountRetry = NO;
  __weak RNTextEngineTextShadowView *weakSelf = self;
  [_bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    RNTextEngineTextShadowView *strongSelf = weakSelf;
    UIView *view = viewRegistry[tag];
    if (view == nil && [uiManager respondsToSelector:@selector(viewForReactTag:)]) {
      view = [uiManager viewForReactTag:tag];
    }
    if (view == nil) {
      if (strongSelf != nil) {
        strongSelf->_needsUpdateView = YES;
        if (!strongSelf->_requestedMountRetry && [uiManager respondsToSelector:@selector(setNeedsLayout)]) {
          strongSelf->_requestedMountRetry = YES;
          [uiManager setNeedsLayout];
        }
      }
      return;
    }

    RNTextEngineApplyResolvedPayloadToView(view, borderInsets, paddingInsets, payloadMap);

    if (strongSelf == nil) return;
    strongSelf->_needsUpdateView = NO;
    strongSelf->_requestedMountRetry = NO;
    if (nextMountedNestedHash != nil) {
      strongSelf->_lastMountedNestedHash = nextMountedNestedHash;
      return;
    }
    if (clearsMountedNestedPayload) {
      strongSelf->_lastMountedNestedHash = nil;
    }
  }];
}

- (void)layoutSubviewsWithContext:(RCTLayoutContext)layoutContext
{
  // `RNTextEngineTextShadowView` is a measurable Yoga leaf. Any React children are
  // virtual text payload sources and are intentionally excluded from Yoga tree
  // ownership. Traversing them here can touch dirty, non-owned Yoga nodes and
  // trigger `Attempt to get layout metrics from dirtied Yoga node`.
  (void)layoutContext;
}

- (BOOL)hasNestedTextChildren
{
  return [self hasValidatedNestedTextChildren];
}

- (BOOL)hasValidatedNestedTextChildren
{
  BOOL hasNested = NO;
  for (RCTShadowView *subview in self.reactSubviews) {
    if (![subview isKindOfClass:[RNTextEngineTextShadowView class]]) {
      @throw [NSException exceptionWithName:@"RNTextEngineInvalidTextViewChild"
                                     reason:[NSString stringWithFormat:
                                                        @"RNTextEngine: TextView nested children must resolve to TextView nodes. Found `%@`.",
                                                        RNTextEngineDescribeShadowChild(subview)]
                                   userInfo:nil];
    }
    hasNested = YES;
  }
  return hasNested;
}

- (BOOL)isVirtualNestedTextNode
{
  return [self.superview isKindOfClass:[RNTextEngineTextShadowView class]];
}

- (void)markMeasurementDirtyForYogaOwnerChain
{
  if ([self isVirtualNestedTextNode]) {
    [self invalidateParentChainFromChildAffectingMeasurement:YES];
    return;
  }

  [self dirtyLayout];
}

- (void)invalidateResolvedPayloadOnly
{
  _cachedResolvedPayload = nil;
  _needsUpdateView = YES;
  [self invalidateParentChainFromChildAffectingMeasurement:NO];
}

- (void)invalidatePreparedHandle
{
  [self releasePreparedHandle];
  _cachedResolvedPayload = nil;
  _needsUpdateView = YES;
  [self markMeasurementDirtyForYogaOwnerChain];
}

- (void)invalidateParentChainFromChildAffectingMeasurement:(BOOL)affectsMeasurement
{
  RCTShadowView *parent = self.superview;
  if (![parent isKindOfClass:[RNTextEngineTextShadowView class]]) {
    return;
  }

  [(RNTextEngineTextShadowView *)parent invalidateFromNestedChildAffectingMeasurement:affectsMeasurement];
}

- (void)invalidateFromNestedChildAffectingMeasurement:(BOOL)affectsMeasurement
{
  if (affectsMeasurement) {
    [self releasePreparedHandle];
  }

  _cachedResolvedPayload = nil;
  _needsUpdateView = YES;

  if (affectsMeasurement) {
    [self markMeasurementDirtyForYogaOwnerChain];
    return;
  }

  [self invalidateParentChainFromChildAffectingMeasurement:NO];
}

- (void)releasePreparedHandle
{
  if (_preparedHandle == 0) return;
  releasePreparedTextHandle(_preparedHandle);
  _preparedHandle = 0;
}

- (uint64_t)preparedHandle
{
  if (_preparedHandle != 0) return _preparedHandle;

  RNTextEngineResolvedPayload *payload = [self resolvePayload];
  RNTextEngineResolvedStyle *style = [self resolveNodeStyleWithParent:nil];
  if (payload.hasNested) style = RNTextEngineNormalizePreparedStyle(style);
  RNTextEngineTextAttributes attributes{
      .allowFontScaling = payload.hasNested ? NO : _allowFontScaling,
      .fontScale = _allowFontScaling && !payload.hasNested ? RCTFontSizeMultiplier() : 1,
      .fontFamily = style.fontFamily,
      .fontSize = RNTextEngineResolveFontSize(style.fontSize),
      .fontStyle = style.fontStyle,
      .fontWeight = style.fontWeight,
      .letterSpacing = style.letterSpacing,
      .lineHeight = style.lineHeight,
      .tabularNumbers = style.tabularNumbers,
      .textAlign = _textAlign,
  };
  std::vector<RNTextEngineTextRun> runs = payload.hasNested
      ? RNTextEngineTextRunsFromArrays(payload.runStarts, payload.runEnds, payload.runStyleMasks,
          nil, payload.runFontFamilies, payload.runFontSizes, payload.runFontStyles,
          payload.runFontWeights, payload.runLetterSpacings, payload.runLineHeights, payload.runTabularNumbers)
      : RNTextEngineTextRunsFromArrays(_runStarts, _runEnds, _runStyleMasks,
          nil, _runFontFamilies, _runFontSizes, _runFontStyles,
          _runFontWeights, _runLetterSpacings, _runLineHeights, _runTabularNumbers, _runCount);
  _preparedHandle = createPreparedTextHandleForTextView(
      (payload.hasNested ? payload.text : _text) ?: @"", attributes, runs, payload.hasNested ? nil : _textTransform);
  return _preparedHandle;
}

- (CGSize)measureWithWidth:(CGFloat)width
                 widthMode:(YGMeasureMode)widthMode
                    height:(CGFloat)height
                heightMode:(YGMeasureMode)heightMode
{
  BOOL hasExactWidth = widthMode == YGMeasureModeExactly;
  BOOL hasExactHeight = heightMode == YGMeasureModeExactly;
  BOOL hasBoundedWidth = widthMode != YGMeasureModeUndefined;
  if (hasExactWidth && hasExactHeight) return CGSizeMake(width, height);

  uint64_t preparedHandle = [self preparedHandle];
  CGFloat constrainedWidth =
      hasBoundedWidth ? MAX(width, 0) : measurePreparedTextWidthForHandle(preparedHandle);
  CGSize layoutSize = measurePreparedTextLayoutForHandle(
      preparedHandle,
      constrainedWidth,
      _numberOfLines,
      _ellipsizeMode,
      _anchorToCapHeight);

  CGFloat measuredWidth = layoutSize.width;
  if (hasExactWidth) measuredWidth = width;
  else if (widthMode == YGMeasureModeAtMost) measuredWidth = MIN(measuredWidth, constrainedWidth);

  CGFloat measuredHeight = layoutSize.height;
  if (hasExactHeight) measuredHeight = height;
  else if (heightMode == YGMeasureModeAtMost) measuredHeight = MIN(measuredHeight, height);

  return CGSizeMake(measuredWidth, measuredHeight);
}

- (RNTextEngineResolvedStyle *)resolveNodeStyleWithParent:(RNTextEngineResolvedStyle *)parentStyle
{
  RNTextEngineResolvedStyle *next = parentStyle != nil ? [parentStyle copy] : [RNTextEngineResolvedStyle new];
  if (parentStyle == nil) {
    next.color = RNTextEngineColorString(_color);
    next.fontFamily = _fontFamily;
    next.fontSize = _fontSize > 0 ? _fontSize : 14;
    next.fontStyle = _fontStyle;
    next.fontWeight = _fontWeight;
    next.letterSpacing = _letterSpacing;
    next.lineHeight = _lineHeight;
    next.tabularNumbers = _tabularNumbers;
    next.textTransform = _textTransform;
    next.allowFontScaling = _allowFontScaling;
  }

  NSString *colorString = RNTextEngineColorString(_color);
  if (colorString != nil) next.color = colorString;
  if (_fontFamily.length > 0) next.fontFamily = _fontFamily;
  if (_fontSize > 0) next.fontSize = _fontSize;
  if (_fontStyle.length > 0) next.fontStyle = _fontStyle;
  if (_fontWeight.length > 0) next.fontWeight = _fontWeight;
  if (parentStyle == nil || _rnteHasLetterSpacing) next.letterSpacing = _letterSpacing;
  if (_lineHeight > 0) next.lineHeight = _lineHeight;
  if (parentStyle == nil || _rnteHasTabularNumbers) next.tabularNumbers = _tabularNumbers;
  if (parentStyle == nil || _rnteHasAllowFontScaling) next.allowFontScaling = _allowFontScaling;
  if (_textTransform.length > 0) next.textTransform = _textTransform;

  return next;
}

- (NSArray<RNTextEngineResolvedRun *> *)resolveLocalRunsWithBaseStyle:(RNTextEngineResolvedStyle *)baseStyle
{
  NSInteger resolvedRunCount = RNTextEngineResolveRunCount(_runCount, _runStarts, _runEnds, _runStyleMasks);
  if (resolvedRunCount == 0) return @[];

  NSInteger previousEnd = 0;
  NSMutableArray<RNTextEngineResolvedRun *> *runs = [NSMutableArray arrayWithCapacity:resolvedRunCount];
  NSInteger textLength = (_text ?: @"").length;

  for (NSInteger index = 0; index < resolvedRunCount; index += 1) {
    NSNumber *styleMaskValue = RNTextEngineNumberOrNil(_runStyleMasks[index]);
    NSNumber *startValue = RNTextEngineNumberOrNil(_runStarts[index]);
    NSNumber *endValue = RNTextEngineNumberOrNil(_runEnds[index]);
    if (styleMaskValue == nil || startValue == nil || endValue == nil) continue;

    NSInteger styleMask = styleMaskValue.integerValue;
    NSInteger start = startValue.integerValue;
    NSInteger end = endValue.integerValue;
    if (styleMask == 0 || start < previousEnd || start < 0 || end <= start || end > textLength) continue;

    RNTextEngineResolvedStyle *style = [baseStyle copy];
    if ((styleMask & RNTextEngineRunStyleHasColor) != 0 && index < _runColors.count) {
      style.color = RNTextEngineStringOrNil(_runColors[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasFontFamily) != 0 && index < _runFontFamilies.count) {
      style.fontFamily = RNTextEngineStringOrNil(_runFontFamilies[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasFontSize) != 0 && index < _runFontSizes.count) {
      style.fontSize = [RNTextEngineNumberOrNil(_runFontSizes[index]) doubleValue];
    }
    if ((styleMask & RNTextEngineRunStyleHasFontStyle) != 0 && index < _runFontStyles.count) {
      style.fontStyle = RNTextEngineStringOrNil(_runFontStyles[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasFontWeight) != 0 && index < _runFontWeights.count) {
      style.fontWeight = RNTextEngineStringOrNil(_runFontWeights[index]);
    }
    if ((styleMask & RNTextEngineRunStyleHasLetterSpacing) != 0 && index < _runLetterSpacings.count) {
      style.letterSpacing = [RNTextEngineNumberOrNil(_runLetterSpacings[index]) doubleValue];
    }
    if ((styleMask & RNTextEngineRunStyleHasLineHeight) != 0 && index < _runLineHeights.count) {
      style.lineHeight = [RNTextEngineNumberOrNil(_runLineHeights[index]) doubleValue];
    }
    if ((styleMask & RNTextEngineRunStyleHasTabularNumbers) != 0 && index < _runTabularNumbers.count) {
      style.tabularNumbers = [RNTextEngineNumberOrNil(_runTabularNumbers[index]) boolValue];
    }

    RNTextEngineResolvedRun *run = [RNTextEngineResolvedRun new];
    run.start = start;
    run.end = end;
    run.style = style;
    [runs addObject:run];
    previousEnd = end;
  }

  return runs;
}

- (NSString *)resolveTransformedText:(NSString *)text
                       textTransform:(NSString *)textTransform
                                runs:(NSMutableArray<RNTextEngineResolvedRun *> *)runs
{
  if (text.length == 0) return @"";

  if (runs.count == 0) {
    return RNTextEngineApplyTextTransform(text, textTransform);
  }

  NSMutableArray<NSNumber *> *runStarts = [NSMutableArray arrayWithCapacity:runs.count];
  NSMutableArray<NSNumber *> *runEnds = [NSMutableArray arrayWithCapacity:runs.count];
  for (RNTextEngineResolvedRun *run in runs) {
    [runStarts addObject:@(run.start)];
    [runEnds addObject:@(run.end)];
  }

  RNTextEngineTextTransformResult *transformed = RNTextEngineTransformText(text, textTransform, runStarts, runEnds);
  if (transformed.runStarts.count == runs.count && transformed.runEnds.count == runs.count) {
    for (NSInteger index = 0; index < runs.count; index += 1) {
      runs[index].start = transformed.runStarts[index].integerValue;
      runs[index].end = transformed.runEnds[index].integerValue;
    }
  }

  return transformed.text ?: @"";
}

- (void)emitStyledText:(NSString *)text
             baseStyle:(RNTextEngineResolvedStyle *)baseStyle
                  runs:(NSArray<RNTextEngineResolvedRun *> *)runs
           textBuilder:(NSMutableString *)textBuilder
              segments:(NSMutableArray<RNTextEngineResolvedSegment *> *)segments
{
  if (text.length == 0) return;

  if (runs.count == 0) {
    [self appendSegment:text style:baseStyle textBuilder:textBuilder segments:segments];
    return;
  }

  NSInteger cursor = 0;
  for (RNTextEngineResolvedRun *run in runs) {
    NSInteger start = MIN(MAX(run.start, 0), text.length);
    NSInteger end = MIN(MAX(run.end, 0), text.length);
    if (end <= start) continue;

    if (start > cursor) {
      [self appendSegment:[text substringWithRange:NSMakeRange((NSUInteger)cursor, (NSUInteger)(start - cursor))]
                    style:baseStyle
              textBuilder:textBuilder
                 segments:segments];
    }

    [self appendSegment:[text substringWithRange:NSMakeRange((NSUInteger)start, (NSUInteger)(end - start))]
                  style:run.style
            textBuilder:textBuilder
               segments:segments];
    cursor = end;
  }

  if (cursor < text.length) {
    [self appendSegment:[text substringFromIndex:(NSUInteger)cursor]
                  style:baseStyle
            textBuilder:textBuilder
               segments:segments];
  }
}

- (void)appendSegment:(NSString *)text
                style:(RNTextEngineResolvedStyle *)style
          textBuilder:(NSMutableString *)textBuilder
             segments:(NSMutableArray<RNTextEngineResolvedSegment *> *)segments
{
  if (text.length == 0) return;
  RNTextEngineResolvedStyle *normalizedStyle = RNTextEngineNormalizePreparedStyle(style);

  NSInteger start = textBuilder.length;
  [textBuilder appendString:text];
  NSInteger end = textBuilder.length;

  RNTextEngineResolvedSegment *last = segments.lastObject;
  if (last != nil && last.end == start && RNTextEngineStyleEquals(last.style, normalizedStyle)) {
    last.end = end;
    return;
  }

  RNTextEngineResolvedSegment *segment = [RNTextEngineResolvedSegment new];
  segment.start = start;
  segment.end = end;
  segment.style = [normalizedStyle copy];
  [segments addObject:segment];
}

- (BOOL)appendNodePayload:(RNTextEngineTextShadowView *)node
              parentStyle:(RNTextEngineResolvedStyle *)parentStyle
              textBuilder:(NSMutableString *)textBuilder
                 segments:(NSMutableArray<RNTextEngineResolvedSegment *> *)segments
{
  RNTextEngineResolvedStyle *nodeStyle = [node resolveNodeStyleWithParent:parentStyle];
  NSMutableArray<RNTextEngineResolvedRun *> *runs = [[node resolveLocalRunsWithBaseStyle:nodeStyle] mutableCopy];
  NSString *text = [node resolveTransformedText:node.text ?: @"" textTransform:nodeStyle.textTransform runs:runs];
  [self emitStyledText:text baseStyle:nodeStyle runs:runs textBuilder:textBuilder segments:segments];

  BOOL hasNested = NO;
  for (RCTShadowView *child in node.reactSubviews) {
    if (![child isKindOfClass:[RNTextEngineTextShadowView class]]) {
      @throw [NSException exceptionWithName:@"RNTextEngineInvalidTextViewChild"
                                     reason:[NSString stringWithFormat:
                                                        @"RNTextEngine: TextView nested children must resolve to TextView nodes. Found `%@`.",
                                                        RNTextEngineDescribeShadowChild(child)]
                                   userInfo:nil];
    }
    hasNested = YES;
    [self appendNodePayload:(RNTextEngineTextShadowView *)child
                parentStyle:nodeStyle
                textBuilder:textBuilder
                   segments:segments];
  }

  return hasNested;
}

- (RNTextEngineResolvedPayload *)buildPayloadFromText:(NSString *)text
                                             segments:(NSArray<RNTextEngineResolvedSegment *> *)segments
                                            rootStyle:(RNTextEngineResolvedStyle *)rootStyle
                                            hasNested:(BOOL)hasNested
{
  if (!hasNested) return [RNTextEngineResolvedPayload empty];
  RNTextEngineResolvedStyle *normalizedRootStyle = RNTextEngineNormalizePreparedStyle(rootStyle);

  RNTextEngineResolvedPayload *payload = [RNTextEngineResolvedPayload new];
  payload.hasNested = YES;
  payload.text = text ?: @"";

  NSMutableArray<NSNumber *> *runStarts = [NSMutableArray array];
  NSMutableArray<NSNumber *> *runEnds = [NSMutableArray array];
  NSMutableArray<NSNumber *> *runStyleMasks = [NSMutableArray array];
  NSMutableArray *runColors = [NSMutableArray array];
  NSMutableArray *runFontFamilies = [NSMutableArray array];
  NSMutableArray<NSNumber *> *runFontSizes = [NSMutableArray array];
  NSMutableArray *runFontWeights = [NSMutableArray array];
  NSMutableArray *runFontStyles = [NSMutableArray array];
  NSMutableArray<NSNumber *> *runLetterSpacings = [NSMutableArray array];
  NSMutableArray<NSNumber *> *runLineHeights = [NSMutableArray array];
  NSMutableArray<NSNumber *> *runTabularNumbers = [NSMutableArray array];

  for (RNTextEngineResolvedSegment *segment in segments) {
    RNTextEngineResolvedStyle *style = segment.style;
    NSInteger styleMask = 0;

    if ((style.color != normalizedRootStyle.color) && ![style.color isEqualToString:normalizedRootStyle.color]) {
      styleMask |= RNTextEngineRunStyleHasColor;
    }
    if ((style.fontFamily != normalizedRootStyle.fontFamily) && ![style.fontFamily isEqualToString:normalizedRootStyle.fontFamily]) {
      styleMask |= RNTextEngineRunStyleHasFontFamily;
    }
    if (style.fontSize != normalizedRootStyle.fontSize) {
      styleMask |= RNTextEngineRunStyleHasFontSize;
    }
    if ((style.fontStyle != normalizedRootStyle.fontStyle) && ![style.fontStyle isEqualToString:normalizedRootStyle.fontStyle]) {
      styleMask |= RNTextEngineRunStyleHasFontStyle;
    }
    if ((style.fontWeight != normalizedRootStyle.fontWeight) && ![style.fontWeight isEqualToString:normalizedRootStyle.fontWeight]) {
      styleMask |= RNTextEngineRunStyleHasFontWeight;
    }
    if (style.letterSpacing != normalizedRootStyle.letterSpacing) {
      styleMask |= RNTextEngineRunStyleHasLetterSpacing;
    }
    if (style.lineHeight != normalizedRootStyle.lineHeight) {
      styleMask |= RNTextEngineRunStyleHasLineHeight;
    }
    if (style.tabularNumbers != normalizedRootStyle.tabularNumbers) {
      styleMask |= RNTextEngineRunStyleHasTabularNumbers;
    }

    if (styleMask == 0) continue;

    [runStarts addObject:@(segment.start)];
    [runEnds addObject:@(segment.end)];
    [runStyleMasks addObject:@(styleMask)];
    [runColors addObject:style.color ?: (id)kCFNull];
    [runFontFamilies addObject:style.fontFamily ?: (id)kCFNull];
    [runFontSizes addObject:@(style.fontSize)];
    [runFontWeights addObject:style.fontWeight ?: (id)kCFNull];
    [runFontStyles addObject:style.fontStyle ?: (id)kCFNull];
    [runLetterSpacings addObject:@(style.letterSpacing)];
    [runLineHeights addObject:@(style.lineHeight)];
    [runTabularNumbers addObject:@(style.tabularNumbers)];
  }

  payload.runStarts = runStarts;
  payload.runEnds = runEnds;
  payload.runStyleMasks = runStyleMasks;
  payload.runColors = runColors;
  payload.runFontFamilies = runFontFamilies;
  payload.runFontSizes = runFontSizes;
  payload.runFontWeights = runFontWeights;
  payload.runFontStyles = runFontStyles;
  payload.runLetterSpacings = runLetterSpacings;
  payload.runLineHeights = runLineHeights;
  payload.runTabularNumbers = runTabularNumbers;

  int64_t hash = 17;
  hash = RNTextEngineHashCombine(hash, RNTextEngineHashObject(payload.text));

  for (NSNumber *value in runStarts) hash = RNTextEngineHashCombine(hash, value.longLongValue);
  for (NSNumber *value in runEnds) hash = RNTextEngineHashCombine(hash, value.longLongValue);
  for (NSNumber *value in runStyleMasks) hash = RNTextEngineHashCombine(hash, value.longLongValue);
  for (id value in runColors) hash = RNTextEngineHashCombine(hash, RNTextEngineHashObject(value));
  for (id value in runFontFamilies) hash = RNTextEngineHashCombine(hash, RNTextEngineHashObject(value));
  for (NSNumber *value in runFontSizes) hash = RNTextEngineHashCombine(hash, RNTextEngineHashObject(value));
  for (id value in runFontWeights) hash = RNTextEngineHashCombine(hash, RNTextEngineHashObject(value));
  for (id value in runFontStyles) hash = RNTextEngineHashCombine(hash, RNTextEngineHashObject(value));
  for (NSNumber *value in runLetterSpacings) hash = RNTextEngineHashCombine(hash, RNTextEngineHashObject(value));
  for (NSNumber *value in runLineHeights) hash = RNTextEngineHashCombine(hash, RNTextEngineHashObject(value));
  for (NSNumber *value in runTabularNumbers) hash = RNTextEngineHashCombine(hash, value.boolValue ? 1 : 0);

  payload.payloadHash = hash;
  return payload;
}

- (RNTextEngineResolvedPayload *)resolvePayload
{
  if (_cachedResolvedPayload != nil) {
    return _cachedResolvedPayload;
  }

  if (![self hasNestedTextChildren]) {
    _cachedResolvedPayload = [RNTextEngineResolvedPayload empty];
    return _cachedResolvedPayload;
  }

  RNTextEngineResolvedStyle *rootStyle = [self resolveNodeStyleWithParent:nil];
  NSMutableString *textBuilder = [NSMutableString new];
  NSMutableArray<RNTextEngineResolvedSegment *> *segments = [NSMutableArray arrayWithCapacity:8];
  BOOL hasNested = [self appendNodePayload:self parentStyle:rootStyle textBuilder:textBuilder segments:segments];
  _cachedResolvedPayload = [self buildPayloadFromText:textBuilder segments:segments rootStyle:rootStyle hasNested:hasNested];
  return _cachedResolvedPayload;
}

- (void)setAnchorToCapHeight:(BOOL)anchorToCapHeight
{
  if (_anchorToCapHeight == anchorToCapHeight) return;
  _anchorToCapHeight = anchorToCapHeight;
  [self markMeasurementDirtyForYogaOwnerChain];
}

- (void)setAllowFontScaling:(BOOL)allowFontScaling
{
  if (_allowFontScaling == allowFontScaling) return;
  _allowFontScaling = allowFontScaling;
  [self invalidatePreparedHandle];
}

- (void)setRnteHasAllowFontScaling:(BOOL)rnteHasAllowFontScaling
{
  if (_rnteHasAllowFontScaling == rnteHasAllowFontScaling) return;
  _rnteHasAllowFontScaling = rnteHasAllowFontScaling;
  [self invalidatePreparedHandle];
}

- (void)setColor:(UIColor *)color
{
  _color = color;
  [self invalidateResolvedPayloadOnly];
}

- (void)setEllipsizeMode:(NSString *)ellipsizeMode
{
  if ((_ellipsizeMode == ellipsizeMode) || [_ellipsizeMode isEqualToString:ellipsizeMode]) return;
  _ellipsizeMode = [ellipsizeMode copy];
  [self markMeasurementDirtyForYogaOwnerChain];
}

- (void)setFontFamily:(NSString *)fontFamily
{
  if ((_fontFamily == fontFamily) || [_fontFamily isEqualToString:fontFamily]) return;
  _fontFamily = [fontFamily copy];
  [self invalidatePreparedHandle];
}

- (void)setFontSize:(CGFloat)fontSize
{
  if (_fontSize == fontSize) return;
  _fontSize = fontSize;
  [self invalidatePreparedHandle];
}

- (void)setFontStyle:(NSString *)fontStyle
{
  if ((_fontStyle == fontStyle) || [_fontStyle isEqualToString:fontStyle]) return;
  _fontStyle = [fontStyle copy];
  [self invalidatePreparedHandle];
}

- (void)setFontWeight:(NSString *)fontWeight
{
  if ((_fontWeight == fontWeight) || [_fontWeight isEqualToString:fontWeight]) return;
  _fontWeight = [fontWeight copy];
  [self invalidatePreparedHandle];
}

- (void)setLetterSpacing:(CGFloat)letterSpacing
{
  if (_letterSpacing == letterSpacing) return;
  _letterSpacing = letterSpacing;
  [self invalidatePreparedHandle];
}

- (void)setRnteHasLetterSpacing:(BOOL)rnteHasLetterSpacing
{
  if (_rnteHasLetterSpacing == rnteHasLetterSpacing) return;
  _rnteHasLetterSpacing = rnteHasLetterSpacing;
  [self invalidatePreparedHandle];
}

- (void)setLineHeight:(CGFloat)lineHeight
{
  if (_lineHeight == lineHeight) return;
  _lineHeight = lineHeight;
  [self invalidatePreparedHandle];
}

- (void)setTextAlign:(NSString *)textAlign
{
  if ((_textAlign == textAlign) || [_textAlign isEqualToString:textAlign]) return;
  _textAlign = [textAlign copy];
  [self invalidatePreparedHandle];
}

- (void)setNumberOfLines:(NSInteger)numberOfLines
{
  if (_numberOfLines == numberOfLines) return;
  _numberOfLines = numberOfLines;
  [self markMeasurementDirtyForYogaOwnerChain];
}

- (void)setTabularNumbers:(BOOL)tabularNumbers
{
  if (_tabularNumbers == tabularNumbers) return;
  _tabularNumbers = tabularNumbers;
  [self invalidatePreparedHandle];
}

- (void)setRnteHasTabularNumbers:(BOOL)rnteHasTabularNumbers
{
  if (_rnteHasTabularNumbers == rnteHasTabularNumbers) return;
  _rnteHasTabularNumbers = rnteHasTabularNumbers;
  [self invalidatePreparedHandle];
}

- (void)setTextTransform:(NSString *)textTransform
{
  if ((_textTransform == textTransform) || [_textTransform isEqualToString:textTransform]) return;
  _textTransform = [textTransform copy];
  [self invalidatePreparedHandle];
}

- (void)setRunCount:(NSInteger)runCount
{
  if (_runCount == runCount) return;
  _runCount = runCount;
  [self invalidatePreparedHandle];
}

- (void)setRunColors:(NSArray<NSString *> *)runColors
{
  _runColors = [runColors copy];
  [self invalidateResolvedPayloadOnly];
}

- (void)setRunEnds:(NSArray<NSNumber *> *)runEnds
{
  _runEnds = [runEnds copy];
  [self invalidatePreparedHandle];
}

- (void)setRunFontFamilies:(NSArray<NSString *> *)runFontFamilies
{
  _runFontFamilies = [runFontFamilies copy];
  [self invalidatePreparedHandle];
}

- (void)setRunFontSizes:(NSArray<NSNumber *> *)runFontSizes
{
  _runFontSizes = [runFontSizes copy];
  [self invalidatePreparedHandle];
}

- (void)setRunFontStyles:(NSArray<NSString *> *)runFontStyles
{
  _runFontStyles = [runFontStyles copy];
  [self invalidatePreparedHandle];
}

- (void)setRunFontWeights:(NSArray<NSString *> *)runFontWeights
{
  _runFontWeights = [runFontWeights copy];
  [self invalidatePreparedHandle];
}

- (void)setRunLetterSpacings:(NSArray<NSNumber *> *)runLetterSpacings
{
  _runLetterSpacings = [runLetterSpacings copy];
  [self invalidatePreparedHandle];
}

- (void)setRunLineHeights:(NSArray<NSNumber *> *)runLineHeights
{
  _runLineHeights = [runLineHeights copy];
  [self invalidatePreparedHandle];
}

- (void)setRunStarts:(NSArray<NSNumber *> *)runStarts
{
  _runStarts = [runStarts copy];
  [self invalidatePreparedHandle];
}

- (void)setRunStyleMasks:(NSArray<NSNumber *> *)runStyleMasks
{
  _runStyleMasks = [runStyleMasks copy];
  [self invalidatePreparedHandle];
}

- (void)setRunTabularNumbers:(NSArray<NSNumber *> *)runTabularNumbers
{
  _runTabularNumbers = [runTabularNumbers copy];
  [self invalidatePreparedHandle];
}

- (void)setText:(NSString *)text
{
  if ((_text == text) || [_text isEqualToString:text]) return;
  _text = [text copy];
  [self invalidatePreparedHandle];
}

@end
