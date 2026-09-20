#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <hermes/hermes.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "../../../ios/RNTextEngineBindings.h"
#import "../../../ios/RNTextEngineModule.h"
#import "../../../ios/RNTextEngineAttributedTextDisplayView.h"
#import "RNTextEngineTestRuntimeHelpers.h"

#import <memory>
#import <string>

using namespace facebook;
using namespace rntextengine;

typedef void (^RNTextEngineViewManagerUIBlock)(id uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry);

@interface RNTextEngineFakeUIManager : NSObject
@property (nonatomic, strong) NSMutableArray<RNTextEngineViewManagerUIBlock> *blocks;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIView *> *viewsByTag;
@property (nonatomic, assign) NSInteger setNeedsLayoutCallCount;
@end

@implementation RNTextEngineFakeUIManager

- (instancetype)init
{
  if ((self = [super init])) {
    _blocks = [NSMutableArray array];
    _viewsByTag = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)addUIBlock:(RNTextEngineViewManagerUIBlock)block
{
  if (block != nil) {
    [self.blocks addObject:[block copy]];
  }
}

- (UIView *)viewForReactTag:(NSNumber *)reactTag
{
  return reactTag != nil ? self.viewsByTag[reactTag] : nil;
}

- (void)setNeedsLayout
{
  self.setNeedsLayoutCallCount += 1;
}

@end

@interface RNTextEngineFakeBridge : NSObject
@property (nonatomic, strong) RNTextEngineFakeUIManager *uiManager;
@end

@implementation RNTextEngineFakeBridge
@end

@class RCTBridge;

@interface RNTextEngineTextShadowView : NSObject
- (instancetype)initWithBridge:(RCTBridge *)bridge;
- (void)insertReactSubview:(id)subview atIndex:(NSInteger)index;
- (void)uiManagerWillPerformMounting;
@property (nonatomic, copy) NSString *fontWeight;
@property (nonatomic, strong) NSNumber *reactTag;
@property (nonatomic, copy) NSString *text;
@end

@interface RNTextEngineTextShadowView (RNTextEngineTestingAccess)
- (id)resolvePayload;
@end

@interface NSObject (RNTextEngineResolvedPayloadTestingAccess)
- (NSDictionary<NSString *, id> *)asMap;
@end

namespace {

class StringBuffer final : public jsi::Buffer {
 public:
  explicit StringBuffer(std::string source) : source_(std::move(source)) {}

  size_t size() const override
  {
    return source_.size();
  }

  const uint8_t *data() const override
  {
    return reinterpret_cast<const uint8_t *>(source_.data());
  }

 private:
  std::string source_;
};

static NSString *NSStringFromStdString(const std::string &value)
{
  return [NSString stringWithUTF8String:value.c_str()] ?: @"";
}

static void RunOnMainSync(dispatch_block_t block)
{
  if (NSThread.isMainThread) {
    block();
    return;
  }

  dispatch_sync(dispatch_get_main_queue(), block);
}

static id FindTextViewSubview(id view)
{
  Class textViewClass = NSClassFromString(@"UITextView");
  for (id subview in [view subviews]) {
    if ([subview isKindOfClass:textViewClass]) {
      return subview;
    }
  }

  return nil;
}

static char RNTextEngineLayoutRequestCountKey;

static void RNTextEngineCountingSetNeedsLayout(id self, SEL selector)
{
  NSNumber *current = objc_getAssociatedObject(self, &RNTextEngineLayoutRequestCountKey);
  objc_setAssociatedObject(
      self,
      &RNTextEngineLayoutRequestCountKey,
      @((current != nil ? current.integerValue : 0) + 1),
      OBJC_ASSOCIATION_RETAIN_NONATOMIC);

  struct objc_super superInfo = {
      .receiver = self,
      .super_class = class_getSuperclass(object_getClass(self)),
  };
  ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&superInfo, selector);
}

static Class LayoutCountingTextViewClass(void)
{
  static Class countingClass;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    Class textViewClass = NSClassFromString(@"RNTextEngineTextView");
    if (textViewClass == Nil) return;
    countingClass = objc_allocateClassPair(textViewClass, "RNTextEngineLayoutCountingTextView", 0);
    class_addMethod(countingClass, @selector(setNeedsLayout), (IMP)RNTextEngineCountingSetNeedsLayout, "v@:");
    objc_registerClassPair(countingClass);
  });
  return countingClass;
}

static id FindDisplaySubview(id view)
{
  Class textViewClass = NSClassFromString(@"UITextView");
  for (id subview in [view subviews]) {
    if (![subview isKindOfClass:textViewClass]) {
      return subview;
    }
  }

  return nil;
}

static void SetBoolProperty(id view, NSString *propertyName, BOOL value)
{
  SEL selector = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:",
                                       [[propertyName substringToIndex:1] uppercaseString],
                                       [propertyName substringFromIndex:1]]);
  XCTAssertTrue([view respondsToSelector:selector], @"%@ should respond to %@", view, NSStringFromSelector(selector));
  ((void (*)(id, SEL, BOOL))objc_msgSend)(view, selector, value);
}

typedef struct {
  CGFloat bottomInset;
  CGFloat height;
  CGFloat topInset;
} ExpectedCapHeightLayoutMetrics;

typedef struct {
  CGFloat height;
  CGFloat lastLineWidth;
  NSInteger lineCount;
  CGFloat width;
} ExpectedLayoutMetrics;

static ExpectedCapHeightLayoutMetrics ExpectedCapHeightMetrics(NSAttributedString *attributedText, CGSize size, NSInteger numberOfLines)
{
  if (attributedText.length == 0) {
    return (ExpectedCapHeightLayoutMetrics) {
      .bottomInset = 0,
      .height = 0,
      .topInset = 0,
    };
  }

  NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:attributedText];
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:size];
  textContainer.lineFragmentPadding = 0;
  textContainer.maximumNumberOfLines = numberOfLines > 0 ? numberOfLines : 0;
  [layoutManager addTextContainer:textContainer];
  [textStorage addLayoutManager:layoutManager];
  [layoutManager ensureLayoutForTextContainer:textContainer];

  NSRange glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
  if (glyphRange.length == 0) {
    return (ExpectedCapHeightLayoutMetrics) {
      .bottomInset = 0,
      .height = 0,
      .topInset = 0,
    };
  }

  CGFloat measuredHeight = 0;
  CGFloat topInset = 0;
  CGFloat lastBaseline = 0;
  BOOL resolvedFirstLine = NO;
  NSUInteger glyphIndex = glyphRange.location;

  while (glyphIndex < NSMaxRange(glyphRange)) {
    NSRange lineGlyphRange = NSMakeRange(0, 0);
    CGRect lineRect = [layoutManager lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:&lineGlyphRange];
    if (lineGlyphRange.length == 0) break;

    CGRect usedRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphIndex effectiveRange:nil];
    NSRange lineCharacterRange = [layoutManager characterRangeForGlyphRange:lineGlyphRange actualGlyphRange:nil];
    CGPoint firstGlyphLocation = [layoutManager locationForGlyphAtIndex:glyphIndex];
    CGFloat baseline = lineRect.origin.y + firstGlyphLocation.y;

    if (!resolvedFirstLine && lineCharacterRange.length > 0) {
      __block CGFloat maxCapHeight = 0;
      [attributedText enumerateAttribute:NSFontAttributeName
                                 inRange:lineCharacterRange
                                 options:0
                              usingBlock:^(id value, NSRange, BOOL *) {
        UIFont *font = [value isKindOfClass:[UIFont class]] ? (UIFont *)value : nil;
        if (font != nil) {
          maxCapHeight = MAX(maxCapHeight, font.capHeight);
        }
      }];
      topInset = MAX(0, baseline - maxCapHeight);
      resolvedFirstLine = YES;
    }

    lastBaseline = baseline;
    measuredHeight = MAX(measuredHeight, usedRect.origin.y + usedRect.size.height);
    glyphIndex = NSMaxRange(lineGlyphRange);
  }

  return (ExpectedCapHeightLayoutMetrics) {
    .bottomInset = MAX(0, measuredHeight - lastBaseline),
    .height = MAX(0, lastBaseline - topInset),
    .topInset = topInset,
  };
}

static ExpectedLayoutMetrics ExpectedLayoutMetricsForAttributedText(
    NSAttributedString *attributedText,
    CGSize size,
    NSInteger numberOfLines,
    NSString *ellipsizeMode)
{
  if (attributedText.length == 0) {
    return (ExpectedLayoutMetrics) {
      .height = 0,
      .lastLineWidth = 0,
      .lineCount = 0,
      .width = 0,
    };
  }

  NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:attributedText];
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:size];
  textContainer.lineFragmentPadding = 0;
  textContainer.lineBreakMode = RNTextEngineResolveLineBreakMode(numberOfLines, ellipsizeMode);
  textContainer.maximumNumberOfLines = numberOfLines > 0 ? numberOfLines : 0;
  [layoutManager addTextContainer:textContainer];
  [textStorage addLayoutManager:layoutManager];
  [layoutManager ensureLayoutForTextContainer:textContainer];

  CGFloat measuredHeight = 0;
  CGFloat measuredWidth = 0;
  CGFloat lastLineWidth = 0;
  NSInteger lineCount = 0;
  NSUInteger glyphIndex = 0;

  while (glyphIndex < layoutManager.numberOfGlyphs) {
    NSRange glyphRange = NSMakeRange(0, 0);
    CGRect usedRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphIndex effectiveRange:&glyphRange];
    lineCount += 1;
    measuredWidth = MAX(measuredWidth, usedRect.size.width);
    measuredHeight = MAX(measuredHeight, usedRect.origin.y + usedRect.size.height);
    lastLineWidth = usedRect.size.width;
    glyphIndex = NSMaxRange(glyphRange);
  }

  return (ExpectedLayoutMetrics) {
    .height = measuredHeight,
    .lastLineWidth = lastLineWidth,
    .lineCount = lineCount,
    .width = measuredWidth,
  };
}

static NSAttributedString *BuildAttributedText(NSString *text, NSString *fontFamily, CGFloat fontSize, CGFloat lineHeight, NSTextAlignment alignment)
{
  UIFont *font = [UIFont fontWithName:fontFamily size:fontSize];
  XCTAssertNotNil(font, @"Expected font %@ to be available for tests.", fontFamily);
  if (font == nil) {
    font = [UIFont systemFontOfSize:fontSize];
  }

  NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
  paragraphStyle.minimumLineHeight = lineHeight;
  paragraphStyle.maximumLineHeight = lineHeight;
  paragraphStyle.alignment = alignment;

  return [[NSAttributedString alloc] initWithString:text
                                         attributes:@{
                                           NSFontAttributeName: font,
                                           NSParagraphStyleAttributeName: paragraphStyle,
                                         }];
}

static uint64_t CreateTextViewMeasurementHandle(
    NSString *text,
    CGFloat fontSize,
    CGFloat lineHeight,
    NSString *fontFamily = nil,
    NSString *fontWeight = nil,
    NSString *fontStyle = nil,
    CGFloat letterSpacing = 0,
    NSString *textTransform = nil)
{
  return createPreparedTextHandleForTextView(
      text,
      NO,
      fontFamily,
      fontSize,
      fontWeight,
      fontStyle,
      letterSpacing,
      lineHeight,
      NO,
      textTransform,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil);
}

static uint64_t CreateTextViewMeasurementHandleWithRunFontSizes(
    NSString *text,
    CGFloat fontSize,
    CGFloat lineHeight,
    NSArray<NSNumber *> *runStarts,
    NSArray<NSNumber *> *runEnds,
    NSArray<NSNumber *> *runStyleMasks,
    NSArray<NSNumber *> *runFontSizes,
    NSString *textTransform = nil)
{
  return createPreparedTextHandleForTextView(
      text,
      NO,
      nil,
      fontSize,
      nil,
      nil,
      0,
      lineHeight,
      NO,
      textTransform,
      runStarts,
      runEnds,
      runStyleMasks,
      nil,
      runFontSizes,
      nil,
      nil,
      nil,
      nil,
      nil);
}

static NSTextContainer *DisplayTextContainer(UIView *displayView)
{
  return [displayView valueForKey:@"_textContainer"];
}

static void AssertRectEqualsRectWithAccuracy(CGRect actual, CGRect expected, CGFloat accuracy)
{
  XCTAssertEqualWithAccuracy(actual.origin.x, expected.origin.x, accuracy);
  XCTAssertEqualWithAccuracy(actual.origin.y, expected.origin.y, accuracy);
  XCTAssertEqualWithAccuracy(actual.size.width, expected.size.width, accuracy);
  XCTAssertEqualWithAccuracy(actual.size.height, expected.size.height, accuracy);
}

static void AssertInteractionTextViewGeometry(
    UITextView *textView,
    CGRect expectedFrame)
{
  AssertRectEqualsRectWithAccuracy(textView.frame, expectedFrame, 0.001);
  XCTAssertEqualWithAccuracy(textView.textContainerInset.top, 0, 0.001);
  XCTAssertEqualWithAccuracy(textView.textContainerInset.left, 0, 0.001);
  XCTAssertEqualWithAccuracy(textView.textContainerInset.bottom, 0, 0.001);
  XCTAssertEqualWithAccuracy(textView.textContainerInset.right, 0, 0.001);
  XCTAssertEqualWithAccuracy(textView.textContainer.size.width, expectedFrame.size.width, 0.001);
  XCTAssertEqualWithAccuracy(textView.textContainer.size.height, expectedFrame.size.height, 0.001);
}

static void AssertDisplayViewUsesBoundsGeometry(UIView *displayView, UIView *hostView)
{
  AssertRectEqualsRectWithAccuracy(displayView.frame, hostView.bounds, 0.001);
}

} // namespace

@interface exampleTests : XCTestCase
@end

@implementation exampleTests {
  std::unique_ptr<jsi::Runtime> _runtime;
}

- (void)setUp
{
  [super setUp];
  _runtime = facebook::hermes::makeHermesRuntime();
  rntextengine::install(*_runtime);
  rntextengine::testhelpers::installRuntimeHandleTracking(*_runtime);
}

- (void)tearDown
{
  rntextengine::testhelpers::releaseTrackedRuntimeHandles(*_runtime);
  _runtime.reset();
  [super tearDown];
}

- (jsi::Value)evaluateSource:(const std::string &)source
{
  return _runtime->evaluateJavaScript(
      std::make_unique<StringBuffer>(source),
      "RNTextEngineBindingsTests.js");
}

- (double)evaluateNumber:(const std::string &)expression
{
  return [self evaluateSource:expression].asNumber();
}

- (id)evaluateJSONExpression:(const std::string &)expression
{
  std::string source = "(function(){ return JSON.stringify(" + expression + "); })()";
  jsi::Value value = [self evaluateSource:source];
  std::string json = value.asString(*_runtime).utf8(*_runtime);
  NSData *jsonData = [NSStringFromStdString(json) dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error = nil;
  id result = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:&error];
  XCTAssertNil(error);
  return result;
}

- (void)assertLayoutDictionary:(NSDictionary *)left equals:(NSDictionary *)right
{
  XCTAssertEqualWithAccuracy([left[@"width"] doubleValue], [right[@"width"] doubleValue], 0.001);
  XCTAssertEqualWithAccuracy([left[@"height"] doubleValue], [right[@"height"] doubleValue], 0.001);
  XCTAssertEqualWithAccuracy([left[@"lineCount"] doubleValue], [right[@"lineCount"] doubleValue], 0.001);
  XCTAssertEqualWithAccuracy([left[@"lastLineWidth"] doubleValue], [right[@"lastLineWidth"] doubleValue], 0.001);
}

- (void)assertJSErrorContains:(NSString *)fragment source:(const std::string &)source
{
  try {
    [self evaluateSource:source];
    XCTFail(@"Expected JSI evaluation to throw.");
  } catch (const jsi::JSError &error) {
    NSString *message = NSStringFromStdString(error.getMessage());
    XCTAssertTrue([message containsString:fragment], @"Unexpected error: %@", message);
  }
}

- (void)assertLayoutDictionary:(NSDictionary *)layout equalsExpectedMetrics:(ExpectedLayoutMetrics)expected
{
  XCTAssertEqualWithAccuracy([layout[@"width"] doubleValue], expected.width, 0.001);
  XCTAssertEqualWithAccuracy([layout[@"height"] doubleValue], expected.height, 0.001);
  XCTAssertEqualWithAccuracy([layout[@"lineCount"] doubleValue], expected.lineCount, 0.001);
  XCTAssertEqualWithAccuracy([layout[@"lastLineWidth"] doubleValue], expected.lastLineWidth, 0.001);
}

- (void)testModuleReportsInstallationUntilInvalidated
{
  RNTextEngineModule *module = [RNTextEngineModule new];
  XCTAssertFalse([[module install] boolValue]);

  [module installJSIBindingsWithRuntime:*_runtime callInvoker:nullptr];
  XCTAssertTrue([[module install] boolValue]);
  XCTAssertGreaterThan([self evaluateNumber:"__RNTextEngineMeasureWidth('Installed runtime', {fontSize: 17})"], 0);

  [module invalidate];
  XCTAssertFalse([[module install] boolValue]);
}

- (void)testPreparedTextMeasureLayoutAndReleaseStayConsistent
{
  double handle = [self evaluateNumber:R"(
    (globalThis.__preparedHandle = __RNTextEnginePrepare(
      "Prepared layout should match one-shot measurement.",
      { fontSize: 17, fontWeight: "500", letterSpacing: 0.2, lineHeight: 24 }
    ))
  )"];

  NSDictionary *measured = [self evaluateJSONExpression:R"(
    __RNTextEngineMeasure(
      "Prepared layout should match one-shot measurement.",
      { fontSize: 17, fontWeight: "500", letterSpacing: 0.2, lineHeight: 24 },
      { width: 180 }
    )
  )"];
  NSDictionary *laidOut = [self evaluateJSONExpression:R"(
    __RNTextEngineLayout(globalThis.__preparedHandle, { width: 180 })
  )"];

  [self assertLayoutDictionary:measured equals:laidOut];

  NSAttributedString *preparedText = rntextengine::preparedAttributedTextForHandle((uint64_t)handle);
  XCTAssertEqualObjects(preparedText.string, @"Prepared layout should match one-shot measurement.");

  [self evaluateSource:R"(__RNTextEngineRelease(globalThis.__preparedHandle))"];

  XCTAssertNil(rntextengine::preparedAttributedTextForHandle((uint64_t)handle));
  [self assertJSErrorContains:@"invalid prepared text handle" source:R"(
    __RNTextEngineLayout(globalThis.__preparedHandle, { width: 180 })
  )"];
}

- (void)testResolveLineBreakModeFollowsRNTextPolicy
{
  XCTAssertEqual(RNTextEngineResolveLineBreakMode(0, nil), NSLineBreakByWordWrapping);
  XCTAssertEqual(RNTextEngineResolveLineBreakMode(0, @"tail"), NSLineBreakByWordWrapping);
  XCTAssertEqual(RNTextEngineResolveLineBreakMode(1, nil), NSLineBreakByTruncatingTail);
  XCTAssertEqual(RNTextEngineResolveLineBreakMode(1, @"clip"), NSLineBreakByClipping);
  XCTAssertEqual(RNTextEngineResolveLineBreakMode(1, @"head"), NSLineBreakByTruncatingHead);
  XCTAssertEqual(RNTextEngineResolveLineBreakMode(1, @"middle"), NSLineBreakByTruncatingMiddle);
  XCTAssertEqual(RNTextEngineResolveLineBreakMode(1, @"tail"), NSLineBreakByTruncatingTail);
}

- (void)testAttributedTextDisplayViewUsesSharedLineBreakPolicy
{
  RunOnMainSync(^{
    Class displayViewClass = NSClassFromString(@"RNTextEngineAttributedTextDisplayView");
    XCTAssertNotNil(displayViewClass);

    id displayView = [[displayViewClass alloc] initWithFrame:CGRectMake(0, 0, 120, 24)];
    [displayView setValue:BuildAttributedText(@"One two three four", @"TestTiemposText-Regular", 17, 24, NSTextAlignmentLeft)
                   forKey:@"attributedText"];

    [displayView setValue:@1 forKey:@"numberOfLines"];
    [displayView capHeightInsetsForWidth:120];
    XCTAssertEqual(DisplayTextContainer((UIView *)displayView).lineBreakMode, NSLineBreakByTruncatingTail);

    [displayView setValue:@"middle" forKey:@"ellipsizeMode"];
    [displayView capHeightInsetsForWidth:120];
    XCTAssertEqual(DisplayTextContainer((UIView *)displayView).lineBreakMode, NSLineBreakByTruncatingMiddle);

    [displayView setValue:@0 forKey:@"numberOfLines"];
    [displayView capHeightInsetsForWidth:120];
    XCTAssertEqual(DisplayTextContainer((UIView *)displayView).lineBreakMode, NSLineBreakByWordWrapping);
  });
}

- (void)testTextViewSelectableUsesSharedLineBreakPolicy
{
  RunOnMainSync(^{
    Class textViewClass = NSClassFromString(@"RNTextEngineTextView");
    XCTAssertNotNil(textViewClass);

    id view = [[textViewClass alloc] initWithFrame:CGRectMake(0, 0, 120, 24)];
    [view setValue:@"One two three four" forKey:@"text"];
    [view setValue:@"TestTiemposText-Regular" forKey:@"fontFamily"];
    [view setValue:@17 forKey:@"fontSize"];
    [view setValue:@24 forKey:@"lineHeight"];
    [view setValue:@YES forKey:@"selectable"];
    [view setValue:@1 forKey:@"numberOfLines"];
    [view layoutIfNeeded];

    UITextView *interactionTextView = (UITextView *)FindTextViewSubview(view);
    XCTAssertNotNil(interactionTextView);
    XCTAssertEqual(interactionTextView.textContainer.lineBreakMode, NSLineBreakByTruncatingTail);

    [view setValue:@"middle" forKey:@"ellipsizeMode"];
    [view layoutIfNeeded];
    XCTAssertEqual(interactionTextView.textContainer.lineBreakMode, NSLineBreakByTruncatingMiddle);

    [view setValue:@0 forKey:@"numberOfLines"];
    [view layoutIfNeeded];
    XCTAssertEqual(interactionTextView.textContainer.lineBreakMode, NSLineBreakByWordWrapping);
  });
}

- (void)testTextViewTextTransformUpdatesMountedText
{
  RunOnMainSync(^{
    Class textViewClass = NSClassFromString(@"RNTextEngineTextView");
    XCTAssertNotNil(textViewClass);

    id view = [[textViewClass alloc] initWithFrame:CGRectMake(0, 0, 120, 24)];
    [view setValue:@"gas" forKey:@"text"];
    [view setValue:@"uppercase" forKey:@"textTransform"];
    [view layoutIfNeeded];

    id displayView = FindDisplaySubview(view);
    XCTAssertNotNil(displayView);
    XCTAssertEqualObjects([[displayView valueForKey:@"attributedText"] string], @"GAS");
  });
}

- (void)testTextViewAppliesResolvedNestedPayloadWithNoRuns
{
  RunOnMainSync(^{
    Class textViewClass = NSClassFromString(@"RNTextEngineTextView");
    XCTAssertNotNil(textViewClass);

    id view = [[textViewClass alloc] initWithFrame:CGRectMake(0, 0, 220, 44)];
    [view setValue:@"TestTiemposText-Regular" forKey:@"fontFamily"];
    [view setValue:@17 forKey:@"fontSize"];
    [view setValue:@24 forKey:@"lineHeight"];

    NSDictionary *payloadMap = @{
      @"hasNested" : @YES,
      @"hash" : @1,
      @"text" : @"Nested payload text",
      @"runStarts" : @[],
      @"runEnds" : @[],
      @"runStyleMasks" : @[],
      @"runColors" : @[],
      @"runFontFamilies" : @[],
      @"runFontSizes" : @[],
      @"runFontWeights" : @[],
      @"runFontStyles" : @[],
      @"runLetterSpacings" : @[],
      @"runLineHeights" : @[],
      @"runTabularNumbers" : @[],
    };
    SEL applyPayloadSelector = NSSelectorFromString(@"applyResolvedNestedPayloadMap:");
    XCTAssertTrue([view respondsToSelector:applyPayloadSelector]);
    ((void (*)(id, SEL, NSDictionary *))objc_msgSend)(view, applyPayloadSelector, payloadMap);

    [view layoutIfNeeded];

    id displayView = FindDisplaySubview(view);
    XCTAssertNotNil(displayView);
    NSAttributedString *attributedText = [displayView valueForKey:@"attributedText"];
    XCTAssertEqualObjects(attributedText.string, @"Nested payload text");
  });
}

- (void)testTextShadowViewResolvesNestedPayloadForVirtualChildren
{
#ifdef RCT_REMOVE_LEGACY_ARCH
  XCTSkip(@"Requires the legacy RCTShadowView implementation, which this React Native build removes.");
#endif

  @try {
    RunOnMainSync(^{
      RNTextEngineFakeBridge *bridge = [RNTextEngineFakeBridge new];
      bridge.uiManager = [RNTextEngineFakeUIManager new];

      RNTextEngineTextShadowView *root = [[RNTextEngineTextShadowView alloc] initWithBridge:(RCTBridge *)bridge];
      root.text = @"";

      RNTextEngineTextShadowView *left = [[RNTextEngineTextShadowView alloc] initWithBridge:(RCTBridge *)bridge];
      left.text = @"Alpha ";

      RNTextEngineTextShadowView *right = [[RNTextEngineTextShadowView alloc] initWithBridge:(RCTBridge *)bridge];
      right.text = @"Beta";
      right.fontWeight = @"700";

      [root insertReactSubview:left atIndex:0];
      [root insertReactSubview:right atIndex:1];

      id payload = [root resolvePayload];
      XCTAssertNotNil(payload);

      NSDictionary *payloadMap = [payload asMap];
      XCTAssertNotNil(payloadMap);

      XCTAssertEqualObjects(payloadMap[@"hasNested"], @YES);
      XCTAssertEqualObjects(payloadMap[@"text"], @"Alpha Beta");
      NSArray<NSNumber *> *runStarts = payloadMap[@"runStarts"];
      NSArray<NSNumber *> *runEnds = payloadMap[@"runEnds"];
      NSArray<NSNumber *> *runStyleMasks = payloadMap[@"runStyleMasks"];
      XCTAssertEqual(runStarts.count, 1);
      XCTAssertEqual(runEnds.count, 1);
      XCTAssertEqual(runStyleMasks.count, 1);
      XCTAssertEqualObjects(runStarts.firstObject, @6);
      XCTAssertEqualObjects(runEnds.firstObject, @10);
      XCTAssertEqualObjects(runStyleMasks.firstObject, @(1 << 4));
    });
  } @catch (NSException *exception) {
    XCTFail(@"Unexpected exception %@: %@", exception.name, exception.reason);
  }
}

- (void)testTextShadowViewEnqueuesMountingWhileYogaNodeIsDirty
{
#ifdef RCT_REMOVE_LEGACY_ARCH
  XCTSkip(@"Requires the legacy RCTShadowView implementation, which this React Native build removes.");
#endif

  @try {
    RunOnMainSync(^{
      RNTextEngineFakeUIManager *uiManager = [RNTextEngineFakeUIManager new];
      RNTextEngineFakeBridge *bridge = [RNTextEngineFakeBridge new];
      bridge.uiManager = uiManager;

      RNTextEngineTextShadowView *root = [[RNTextEngineTextShadowView alloc] initWithBridge:(RCTBridge *)bridge];
      [root setValue:@42 forKey:@"reactTag"];

      RNTextEngineTextShadowView *child = [[RNTextEngineTextShadowView alloc] initWithBridge:(RCTBridge *)bridge];
      child.text = @"Nested payload text";
      [root insertReactSubview:child atIndex:0];

      [root uiManagerWillPerformMounting];
      XCTAssertEqual(uiManager.blocks.count, 1);
    });
  } @catch (NSException *exception) {
    XCTFail(@"Unexpected exception %@: %@", exception.name, exception.reason);
  }
}

- (void)testTextShadowViewAppliesNestedPayloadOnFirstMountingPass
{
#ifdef RCT_REMOVE_LEGACY_ARCH
  XCTSkip(@"Requires the legacy RCTShadowView implementation, which this React Native build removes.");
#endif

  @try {
    RunOnMainSync(^{
      RNTextEngineFakeUIManager *uiManager = [RNTextEngineFakeUIManager new];
      RNTextEngineFakeBridge *bridge = [RNTextEngineFakeBridge new];
      bridge.uiManager = uiManager;

      RNTextEngineTextShadowView *root = [[RNTextEngineTextShadowView alloc] initWithBridge:(RCTBridge *)bridge];
      [root setValue:@42 forKey:@"reactTag"];

      RNTextEngineTextShadowView *child = [[RNTextEngineTextShadowView alloc] initWithBridge:(RCTBridge *)bridge];
      child.text = @"Nested payload text";
      [root insertReactSubview:child atIndex:0];

      [root uiManagerWillPerformMounting];
      XCTAssertEqual(uiManager.blocks.count, 1);

      Class textViewClass = NSClassFromString(@"RNTextEngineTextView");
      XCTAssertNotNil(textViewClass);
      id view = [[textViewClass alloc] initWithFrame:CGRectMake(0, 0, 220, 44)];
      uiManager.viewsByTag[@42] = view;

      RNTextEngineViewManagerUIBlock mountBlock = uiManager.blocks.lastObject;
      XCTAssertNotNil(mountBlock);
      mountBlock(uiManager, @{ @42 : view });
      [view layoutIfNeeded];

      id displayView = FindDisplaySubview(view);
      XCTAssertNotNil(displayView);
      NSAttributedString *attributedText = [displayView valueForKey:@"attributedText"];
      XCTAssertEqualObjects(attributedText.string, @"Nested payload text");
    });
  } @catch (NSException *exception) {
    XCTFail(@"Unexpected exception %@: %@", exception.name, exception.reason);
  }
}

- (void)testTextShadowViewRequestsLayoutRetryWhenFirstMountMissesView
{
#ifdef RCT_REMOVE_LEGACY_ARCH
  XCTSkip(@"Requires the legacy RCTShadowView implementation, which this React Native build removes.");
#endif

  @try {
    RunOnMainSync(^{
      RNTextEngineFakeUIManager *uiManager = [RNTextEngineFakeUIManager new];
      RNTextEngineFakeBridge *bridge = [RNTextEngineFakeBridge new];
      bridge.uiManager = uiManager;

      RNTextEngineTextShadowView *root = [[RNTextEngineTextShadowView alloc] initWithBridge:(RCTBridge *)bridge];
      [root setValue:@42 forKey:@"reactTag"];

      RNTextEngineTextShadowView *child = [[RNTextEngineTextShadowView alloc] initWithBridge:(RCTBridge *)bridge];
      child.text = @"Nested payload text";
      [root insertReactSubview:child atIndex:0];

      [root uiManagerWillPerformMounting];
      XCTAssertEqual(uiManager.blocks.count, 1);

      RNTextEngineViewManagerUIBlock firstBlock = uiManager.blocks.lastObject;
      XCTAssertNotNil(firstBlock);
      firstBlock(uiManager, @{});
      XCTAssertEqual(uiManager.setNeedsLayoutCallCount, 1);

      [root uiManagerWillPerformMounting];
      XCTAssertEqual(uiManager.blocks.count, 2);

      Class textViewClass = NSClassFromString(@"RNTextEngineTextView");
      XCTAssertNotNil(textViewClass);
      id view = [[textViewClass alloc] initWithFrame:CGRectMake(0, 0, 220, 44)];
      uiManager.viewsByTag[@42] = view;

      RNTextEngineViewManagerUIBlock secondBlock = uiManager.blocks.lastObject;
      XCTAssertNotNil(secondBlock);
      secondBlock(uiManager, @{});
      [view layoutIfNeeded];

      id displayView = FindDisplaySubview(view);
      XCTAssertNotNil(displayView);
      NSAttributedString *attributedText = [displayView valueForKey:@"attributedText"];
      XCTAssertEqualObjects(attributedText.string, @"Nested payload text");
    });
  } @catch (NSException *exception) {
    XCTFail(@"Unexpected exception %@: %@", exception.name, exception.reason);
  }
}

- (void)testTextViewMeasurementHandleRemapsRunsAfterTextExpansion
{
  uint64_t handle = createPreparedTextHandleForTextView(
      @"ßb",
      NO,
      nil,
      16,
      nil,
      nil,
      0,
      20,
      NO,
      @"uppercase",
      @[ @1 ],
      @[ @2 ],
      @[ @(1 << 4) ],
      nil,
      nil,
      nil,
      @[ @"700" ],
      nil,
      nil,
      nil);
  NSAttributedString *attributedText = preparedAttributedTextForHandle(handle);
  XCTAssertEqualObjects(attributedText.string, @"SSB");

  UIFont *middleFont = [attributedText attribute:NSFontAttributeName atIndex:1 effectiveRange:nil];
  UIFont *lastFont = [attributedText attribute:NSFontAttributeName atIndex:2 effectiveRange:nil];
  XCTAssertFalse((middleFont.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) == UIFontDescriptorTraitBold);
  XCTAssertTrue((lastFont.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) == UIFontDescriptorTraitBold);

  releasePreparedTextHandle(handle);
}

- (void)testBatchPrepareAndLayoutMatchSinglePrepareAndLayout
{
  [self evaluateSource:R"(
    globalThis.__singleHandleOne = __RNTextEnginePrepare(
      "Alpha beta gamma",
      { fontSize: 16, lineHeight: 20 },
      [{ start: 0, end: 5, style: { fontWeight: "700" } }]
    );
    globalThis.__singleHandleTwo = __RNTextEnginePrepare("Delta epsilon zeta", { fontSize: 16, lineHeight: 20 });
    globalThis.__batchHandles = __RNTextEnginePrepareBatch(
      ["Alpha beta gamma", "Delta epsilon zeta"],
      { fontSize: 16, lineHeight: 20 },
      [[{ start: 0, end: 5, style: { fontWeight: "700" } }], null]
    );
  )"];

  NSArray<NSDictionary *> *singleResults = [self evaluateJSONExpression:R"(
    [
      __RNTextEngineLayout(globalThis.__singleHandleOne, { width: 120 }),
      __RNTextEngineLayout(globalThis.__singleHandleTwo, { width: 120 })
    ]
  )"];
  NSArray<NSDictionary *> *batchResults = [self evaluateJSONExpression:R"(
    __RNTextEngineLayoutBatch(globalThis.__batchHandles, { width: 120 })
  )"];

  XCTAssertEqual(singleResults.count, 2);
  XCTAssertEqual(batchResults.count, 2);
  [self assertLayoutDictionary:singleResults[0] equals:batchResults[0]];
  [self assertLayoutDictionary:singleResults[1] equals:batchResults[1]];

  [self evaluateSource:R"(
    __RNTextEngineRelease(globalThis.__singleHandleOne);
    __RNTextEngineRelease(globalThis.__singleHandleTwo);
    __RNTextEngineReleaseMany(globalThis.__batchHandles);
  )"];
}

- (void)testPlainBatchMeasureMatchesPreparedBatchLayout
{
  NSArray<NSArray<NSDictionary *> *> *result = [self evaluateJSONExpression:R"(
    (() => {
      const texts = [
        "Message 1. The renderer should know the bubble height before the row mounts. Inline emphasis, quoted citations, and tabular figures still need exact native metrics.",
        "Message 2. Prepared text lets layout reuse stay width-bound instead of rebuilding typography. Worklet-driven lists need stable line counts, widths, and last-line geometry to avoid jank.",
        "Message 3. Glyph fields should mutate cells, not paragraphs, when the phenomenon is fixed-grid text. Prepared text performance should remain exact under changing widths.",
        "Message 4. Exact line breaks matter when high-quality paragraph optimization and hyphenation both participate in the result geometry.",
        "Message 5. Trailing whitespace should trim from visible width but never corrupt the line end contract.   ",
      ];
      const style = { fontSize: 17, fontWeight: "500", letterSpacing: 0.1, lineHeight: 24 };
      const layout = { width: 260 };
      const handles = __RNTextEnginePrepareBatch(texts, style);
      try {
        return [
          __RNTextEngineMeasureBatch(texts, style, layout),
          __RNTextEngineLayoutBatch(handles, layout),
        ];
      } finally {
        __RNTextEngineReleaseMany(handles);
      }
    })()
  )"];

  NSArray<NSDictionary *> *measured = result[0];
  NSArray<NSDictionary *> *laidOut = result[1];
  XCTAssertEqual(measured.count, laidOut.count);
  for (NSUInteger index = 0; index < measured.count; index += 1) {
    [self assertLayoutDictionary:measured[index] equals:laidOut[index]];
  }
}

- (void)testLayoutLinesAndNextLineStayAlignedForResolvedLineStarts
{
  [self evaluateSource:R"(
    globalThis.__lineHandle = __RNTextEnginePrepare(
      "One two three four five six seven",
      { fontSize: 16, lineHeight: 20 }
    );
  )"];

  NSDictionary *layoutLines = [self evaluateJSONExpression:R"(
    __RNTextEngineLayoutLines(globalThis.__lineHandle, { width: 92 })
  )"];
  NSArray<NSDictionary *> *lines = layoutLines[@"lines"];
  NSDictionary *firstNextLine = [self evaluateJSONExpression:R"(
    __RNTextEngineLayoutNextLine(globalThis.__lineHandle, 0, 92)
  )"];
  NSDictionary *secondNextLine = [self evaluateJSONExpression:R"(
    __RNTextEngineLayoutNextLine(globalThis.__lineHandle, globalThis.__RNTextEngineLayoutLines(globalThis.__lineHandle, { width: 92 }).lines[1].start, 92)
  )"];

  XCTAssertGreaterThanOrEqual(lines.count, 2u);

  XCTAssertEqualObjects(firstNextLine[@"start"], lines[0][@"start"]);
  XCTAssertEqualObjects(firstNextLine[@"end"], lines[0][@"end"]);
  XCTAssertEqualWithAccuracy([firstNextLine[@"width"] doubleValue], [lines[0][@"width"] doubleValue], 0.001);
  XCTAssertEqualWithAccuracy([firstNextLine[@"bottom"] doubleValue], [lines[0][@"bottom"] doubleValue], 0.001);

  XCTAssertEqualObjects(secondNextLine[@"start"], lines[1][@"start"]);
  XCTAssertEqualObjects(secondNextLine[@"end"], lines[1][@"end"]);
  XCTAssertEqualWithAccuracy([secondNextLine[@"width"] doubleValue], [lines[1][@"width"] doubleValue], 0.001);
  XCTAssertGreaterThan([secondNextLine[@"bottom"] doubleValue], 0.0);
}

- (void)testInlineRunsValidationRejectsEmptyAndUnsortedRuns
{
  [self assertJSErrorContains:@"override at least one inline style field" source:R"(
    __RNTextEnginePrepare("inline", { fontSize: 16, lineHeight: 20 }, [{ start: 0, end: 3, style: {} }])
  )"];
  [self assertJSErrorContains:@"sorted and non-overlapping" source:R"(
    __RNTextEnginePrepare(
      "inline",
      { fontSize: 16, lineHeight: 20 },
      [
        { start: 3, end: 5, style: { color: "#fff" } },
        { start: 1, end: 2, style: { color: "#000" } }
      ]
    )
  )"];
}

- (void)testLayoutNextLineRespectsExplicitLineHeight
{
  [self evaluateSource:R"(
    globalThis.__lineHeightHandle = __RNTextEnginePrepare(
      "Alpha beta gamma delta",
      { fontSize: 16, lineHeight: 32 }
    );
  )"];

  NSDictionary *nextLine = [self evaluateJSONExpression:R"(
    __RNTextEngineLayoutNextLine(globalThis.__lineHeightHandle, 0, 240)
  )"];

  XCTAssertEqualObjects(nextLine[@"start"], @0);
  XCTAssertGreaterThan([nextLine[@"end"] integerValue], 0);
  XCTAssertEqualWithAccuracy([nextLine[@"bottom"] doubleValue], 32.0, 0.001);

  [self evaluateSource:R"(__RNTextEngineRelease(globalThis.__lineHeightHandle))"];
}

- (void)testLayoutNextLineMatchesInlineRunFirstLineMetrics
{
  [self evaluateSource:R"(
    globalThis.__inlineMetricsHandle = __RNTextEnginePrepare(
      "Large run should affect next-line metrics without changing the public contract.",
      { fontSize: 14 },
      [{ start: 0, end: 9, style: { fontSize: 28, fontWeight: "700" } }]
    );
  )"];

  NSDictionary *layoutLines = [self evaluateJSONExpression:R"(
    __RNTextEngineLayoutLines(globalThis.__inlineMetricsHandle, { width: 180 })
  )"];
  NSArray<NSDictionary *> *lines = layoutLines[@"lines"];
  NSDictionary *nextLine = [self evaluateJSONExpression:R"(
    __RNTextEngineLayoutNextLine(globalThis.__inlineMetricsHandle, 0, 180)
  )"];

  XCTAssertGreaterThanOrEqual(lines.count, 1u);
  XCTAssertEqualObjects(nextLine[@"start"], lines[0][@"start"]);
  XCTAssertEqualObjects(nextLine[@"end"], lines[0][@"end"]);
  XCTAssertEqualWithAccuracy([nextLine[@"width"] doubleValue], [lines[0][@"width"] doubleValue], 0.001);
  XCTAssertEqualWithAccuracy([nextLine[@"bottom"] doubleValue], [lines[0][@"bottom"] doubleValue], 0.001);

  [self evaluateSource:R"(__RNTextEngineRelease(globalThis.__inlineMetricsHandle))"];
}

- (void)testLayoutNextLineMatchesExplicitLineBreaks
{
  [self evaluateSource:R"(
    globalThis.__lineBreakHandle = __RNTextEnginePrepare(
      "Alpha beta  \nGamma delta",
      { fontSize: 16, lineHeight: 20 }
    );
  )"];

  NSDictionary *layoutLines = [self evaluateJSONExpression:R"(
    __RNTextEngineLayoutLines(globalThis.__lineBreakHandle, { width: 240 })
  )"];
  NSArray<NSDictionary *> *lines = layoutLines[@"lines"];
  NSDictionary *firstNextLine = [self evaluateJSONExpression:R"(
    __RNTextEngineLayoutNextLine(globalThis.__lineBreakHandle, 0, 240)
  )"];
  NSDictionary *secondNextLine = [self evaluateJSONExpression:R"(
    __RNTextEngineLayoutNextLine(globalThis.__lineBreakHandle, globalThis.__RNTextEngineLayoutLines(globalThis.__lineBreakHandle, { width: 240 }).lines[1].start, 240)
  )"];

  XCTAssertEqual(lines.count, 2u);

  XCTAssertEqualObjects(firstNextLine[@"start"], lines[0][@"start"]);
  XCTAssertEqualObjects(firstNextLine[@"end"], lines[0][@"end"]);
  XCTAssertEqualWithAccuracy([firstNextLine[@"width"] doubleValue], [lines[0][@"width"] doubleValue], 0.001);
  XCTAssertEqualWithAccuracy([firstNextLine[@"bottom"] doubleValue], [lines[0][@"bottom"] doubleValue], 0.001);

  XCTAssertEqualObjects(secondNextLine[@"start"], lines[1][@"start"]);
  XCTAssertEqualObjects(secondNextLine[@"end"], lines[1][@"end"]);
  XCTAssertEqualWithAccuracy([secondNextLine[@"width"] doubleValue], [lines[1][@"width"] doubleValue], 0.001);
  XCTAssertEqualWithAccuracy([secondNextLine[@"bottom"] doubleValue], 20.0, 0.001);

  [self evaluateSource:R"(__RNTextEngineRelease(globalThis.__lineBreakHandle))"];
}

- (void)testLayoutWidthsExcludeTrailingWhitespace
{
  [self evaluateSource:R"(
    globalThis.__trailingWhitespaceHandle = __RNTextEnginePrepare(
      "Alpha   ",
      { fontSize: 16, lineHeight: 20 }
    );
  )"];

  NSDictionary *layoutLines = [self evaluateJSONExpression:R"(
    __RNTextEngineLayoutLines(globalThis.__trailingWhitespaceHandle, { width: 240 })
  )"];
  NSArray<NSDictionary *> *lines = layoutLines[@"lines"];
  NSDictionary *nextLine = [self evaluateJSONExpression:R"(
    __RNTextEngineLayoutNextLine(globalThis.__trailingWhitespaceHandle, 0, 240)
  )"];
  NSDictionary *trimmed = [self evaluateJSONExpression:R"(
    __RNTextEngineMeasure("Alpha", { fontSize: 16, lineHeight: 20 }, { width: 240 })
  )"];

  XCTAssertEqual(lines.count, 1u);
  XCTAssertEqualObjects(lines[0][@"end"], @5);
  XCTAssertEqualObjects(nextLine[@"end"], @5);

  XCTAssertEqualWithAccuracy([layoutLines[@"width"] doubleValue], [trimmed[@"width"] doubleValue], 0.001);
  XCTAssertEqualWithAccuracy([layoutLines[@"lastLineWidth"] doubleValue], [trimmed[@"lastLineWidth"] doubleValue], 0.001);
  XCTAssertEqualWithAccuracy([lines[0][@"width"] doubleValue], [trimmed[@"width"] doubleValue], 0.001);
  XCTAssertEqualWithAccuracy([nextLine[@"width"] doubleValue], [trimmed[@"width"] doubleValue], 0.001);

  [self evaluateSource:R"(__RNTextEngineRelease(globalThis.__trailingWhitespaceHandle))"];
}

- (void)testGlyphFieldIndicesAndBuffersValidateAndCommit
{
  [self evaluateSource:R"(
    globalThis.__fieldHandle = __RNTextEngineCreateGlyphField({
      columns: 3,
      rows: 2,
      fontSize: 14,
      glyphPalette: ".#*",
      lineHeight: 16,
      textAlign: "center",
      variants: [{ color: "#ffffff" }]
    });
    __RNTextEngineUpdateGlyphFieldIndices(
      globalThis.__fieldHandle,
      new Uint8Array([0, 1, 2, 2, 1, 0]),
      new Uint8Array([0, 0, 0, 0, 0, 0])
    );

    const buffers = __RNTextEngineCreateGlyphFieldBuffers(globalThis.__fieldHandle);
    new Uint8Array(buffers.glyphIndices).set([2, 1, 0, 0, 1, 2]);
    new Uint8Array(buffers.variantIndices).set([0, 0, 0, 0, 0, 0]);
    __RNTextEngineCommitGlyphFieldBuffers(globalThis.__fieldHandle);
  )"];

  [self assertJSErrorContains:@"glyph index exceeded the configured glyphPalette length" source:R"(
    __RNTextEngineUpdateGlyphFieldIndices(
      globalThis.__fieldHandle,
      new Uint8Array([3, 0, 0, 0, 0, 0]),
      new Uint8Array([0, 0, 0, 0, 0, 0])
    )
  )"];

  [self evaluateSource:R"(__RNTextEngineReleaseGlyphField(globalThis.__fieldHandle))"];
}

- (void)testPreparedTextViewSelectableCreatesInteractionOwnerLazily
{
  NSString *text = @"Prepared selectable text should attach a real interaction owner.";
  CGFloat width = 240;
  ExpectedCapHeightLayoutMetrics expectedMetrics =
      ExpectedCapHeightMetrics(BuildAttributedText(text, @"TestEpiceneDisplay-Regular", 40, 48, NSTextAlignmentLeft),
                               CGSizeMake(width, CGFLOAT_MAX),
                               1);

  double handle = [self evaluateNumber:R"(
    (globalThis.__selectablePreparedHandle = __RNTextEnginePrepare(
      "Prepared selectable text should attach a real interaction owner.",
      { color: "#ff3b30", fontFamily: "TestEpiceneDisplay-Regular", fontSize: 40, lineHeight: 48 }
    ))
  )"];

  NSDictionary *anchoredLayout = [self evaluateJSONExpression:R"(
    __RNTextEngineLayout(globalThis.__selectablePreparedHandle, { anchorToCapHeight: true, maxLines: 1, width: 240 })
  )"];
  XCTAssertEqualWithAccuracy([anchoredLayout[@"height"] doubleValue], expectedMetrics.height, 0.001);

  RunOnMainSync(^{
    Class preparedTextViewClass = NSClassFromString(@"RNTextEnginePreparedTextView");
    XCTAssertNotNil(preparedTextViewClass);

    id view = [[preparedTextViewClass alloc] initWithFrame:CGRectMake(0, 0, width, expectedMetrics.height)];
    XCTAssertNil(FindTextViewSubview(view));

    [view setValue:@(handle) forKey:@"handle"];
    SetBoolProperty(view, @"anchorToCapHeight", YES);
    [view setValue:@1 forKey:@"numberOfLines"];
    [view setValue:@YES forKey:@"selectable"];
    [view layoutIfNeeded];

    id interactionView = FindTextViewSubview(view);
    id displayView = FindDisplaySubview(view);
    XCTAssertNotNil(interactionView);
    XCTAssertNotNil(displayView);
    XCTAssertTrue(((UIView *)displayView).hidden);
    XCTAssertTrue([[interactionView valueForKey:@"selectable"] boolValue]);
    XCTAssertEqualObjects([[interactionView valueForKey:@"attributedText"] string], text);
    UIView *typedView = (UIView *)view;
    UITextView *interactionTextView = (UITextView *)interactionView;
    XCTAssertEqual(interactionTextView.textContainer.lineBreakMode, NSLineBreakByTruncatingTail);
    [view setValue:@"middle" forKey:@"ellipsizeMode"];
    [view layoutIfNeeded];
    XCTAssertEqual(interactionTextView.textContainer.lineBreakMode, NSLineBreakByTruncatingMiddle);

    [view setValue:@0 forKey:@"numberOfLines"];
    [view layoutIfNeeded];
    XCTAssertEqual(interactionTextView.textContainer.lineBreakMode, NSLineBreakByWordWrapping);

    CGRect expectedFrame = typedView.bounds;
    expectedFrame.origin.y -= expectedMetrics.topInset;
    expectedFrame.size.height += expectedMetrics.topInset + expectedMetrics.bottomInset;
    AssertInteractionTextViewGeometry(interactionTextView, expectedFrame);
    UIColor *foregroundColor = [interactionTextView.attributedText attribute:NSForegroundColorAttributeName
                                                                    atIndex:0
                                                             effectiveRange:nil];
    XCTAssertNotNil(foregroundColor);
    XCTAssertNotEqualObjects(foregroundColor, UIColor.clearColor);

    [view setValue:@NO forKey:@"selectable"];
    [view layoutIfNeeded];
    XCTAssertNil(FindTextViewSubview(view));
    XCTAssertFalse(((UIView *)FindDisplaySubview(view)).hidden);
  });

  [self evaluateSource:R"(__RNTextEngineRelease(globalThis.__selectablePreparedHandle))"];
}

- (void)testTextViewSelectableCreatesInteractionOwnerOnlyWhenRequested
{
  NSString *text = @"Selectable title text";
  CGFloat width = 240;
  ExpectedCapHeightLayoutMetrics expectedMetrics =
      ExpectedCapHeightMetrics(BuildAttributedText(text, @"TestEpiceneDisplay-Regular", 40, 48, NSTextAlignmentCenter),
                               CGSizeMake(width, CGFLOAT_MAX),
                               1);
  NSDictionary *anchoredLayout = [self evaluateJSONExpression:R"(
    __RNTextEngineMeasure(
      "Selectable title text",
      { fontFamily: "TestEpiceneDisplay-Regular", fontSize: 40, lineHeight: 48 },
      { anchorToCapHeight: true, maxLines: 1, width: 240 }
    )
  )"];
  XCTAssertEqualWithAccuracy([anchoredLayout[@"height"] doubleValue], expectedMetrics.height, 0.001);

  RunOnMainSync(^{
    Class textViewClass = NSClassFromString(@"RNTextEngineTextView");
    XCTAssertNotNil(textViewClass);

    id view = [[textViewClass alloc] initWithFrame:CGRectMake(0, 0, width, expectedMetrics.height)];
    [view setValue:text forKey:@"text"];
    [view setValue:UIColor.systemBlueColor forKey:@"color"];
    [view setValue:@"TestEpiceneDisplay-Regular" forKey:@"fontFamily"];
    [view setValue:@40 forKey:@"fontSize"];
    [view setValue:@48 forKey:@"lineHeight"];
    [view setValue:@"center" forKey:@"textAlign"];
    SetBoolProperty(view, @"anchorToCapHeight", YES);
    [view setNeedsLayout];
    [view layoutIfNeeded];

    XCTAssertNil(FindTextViewSubview(view));

    [view setValue:@YES forKey:@"selectable"];
    [view layoutIfNeeded];

    id interactionView = FindTextViewSubview(view);
    id displayView = FindDisplaySubview(view);
    XCTAssertNotNil(interactionView);
    XCTAssertNotNil(displayView);
    XCTAssertTrue(((UIView *)displayView).hidden);
    XCTAssertTrue([[interactionView valueForKey:@"selectable"] boolValue]);
    XCTAssertEqualObjects([interactionView valueForKey:@"textAlignment"], @1);
    XCTAssertEqualObjects([[interactionView valueForKey:@"attributedText"] string], text);
    UIView *typedView = (UIView *)view;
    UITextView *interactionTextView = (UITextView *)interactionView;
    CGRect expectedFrame = typedView.bounds;
    expectedFrame.origin.y -= expectedMetrics.topInset;
    expectedFrame.size.height += expectedMetrics.topInset + expectedMetrics.bottomInset;
    AssertInteractionTextViewGeometry(interactionTextView, expectedFrame);
    UIColor *foregroundColor = [interactionTextView.attributedText attribute:NSForegroundColorAttributeName
                                                                    atIndex:0
                                                             effectiveRange:nil];
    XCTAssertNotNil(foregroundColor);
    XCTAssertNotEqualObjects(foregroundColor, UIColor.clearColor);
  });
}

- (void)testTextViewDisplayRefreshDoesNotScheduleFollowUpLayout
{
  RunOnMainSync(^{
    Class textViewClass = LayoutCountingTextViewClass();
    XCTAssertNotNil(textViewClass);

    UIView *view = [[textViewClass alloc] initWithFrame:CGRectMake(0, 0, 240, 48)];
    [view setValue:@"A direct text view must settle display text in one layout pass." forKey:@"text"];
    [view setValue:@"TestTiemposText-Regular" forKey:@"fontFamily"];
    [view setValue:@18 forKey:@"fontSize"];
    [view setValue:@26 forKey:@"lineHeight"];
    SetBoolProperty(view, @"anchorToCapHeight", YES);

    objc_setAssociatedObject(view, &RNTextEngineLayoutRequestCountKey, @0, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [view setNeedsLayout];
    [view layoutIfNeeded];

    NSNumber *requests = objc_getAssociatedObject(view, &RNTextEngineLayoutRequestCountKey);
    XCTAssertEqual(requests.integerValue, 1);
  });
}

- (void)testPreparedTextViewWithoutCapHeightUsesStandardDisplayBounds
{
  RunOnMainSync(^{
    Class preparedTextViewClass = NSClassFromString(@"RNTextEnginePreparedTextView");
    XCTAssertNotNil(preparedTextViewClass);

    UIView *view = [[preparedTextViewClass alloc] initWithFrame:CGRectMake(0, 0, 180, 36)];
    [view layoutIfNeeded];

    id displayView = FindDisplaySubview(view);
    XCTAssertNotNil(displayView);
    AssertDisplayViewUsesBoundsGeometry((UIView *)displayView, view);
  });
}

- (void)testTextViewWithoutCapHeightUsesStandardDisplayBounds
{
  RunOnMainSync(^{
    Class textViewClass = NSClassFromString(@"RNTextEngineTextView");
    XCTAssertNotNil(textViewClass);

    id view = [[textViewClass alloc] initWithFrame:CGRectMake(0, 0, 180, 36)];
    [view setValue:@"Standard bounds" forKey:@"text"];
    [view setValue:@"TestTiemposText-Regular" forKey:@"fontFamily"];
    [view setValue:@17 forKey:@"fontSize"];
    [view setValue:@24 forKey:@"lineHeight"];
    [view layoutIfNeeded];

    id displayView = FindDisplaySubview(view);
    XCTAssertNotNil(displayView);
    AssertDisplayViewUsesBoundsGeometry((UIView *)displayView, (UIView *)view);
  });
}

- (void)testPreparedTextViewSelectableWithoutCapHeightUsesStandardInteractionBounds
{
  NSString *text = @"Prepared standard selectable";
  double handle = [self evaluateNumber:R"(
    (globalThis.__standardPreparedSelectableHandle = __RNTextEnginePrepare(
      "Prepared standard selectable",
      { fontFamily: "TestTiemposText-Regular", fontSize: 17, lineHeight: 24 }
    ))
  )"];

  RunOnMainSync(^{
    Class preparedTextViewClass = NSClassFromString(@"RNTextEnginePreparedTextView");
    XCTAssertNotNil(preparedTextViewClass);

    id view = [[preparedTextViewClass alloc] initWithFrame:CGRectMake(0, 0, 180, 24)];
    [view setValue:@(handle) forKey:@"handle"];
    [view setValue:@YES forKey:@"selectable"];
    [view layoutIfNeeded];

    UITextView *interactionTextView = (UITextView *)FindTextViewSubview(view);
    XCTAssertNotNil(interactionTextView);
    AssertInteractionTextViewGeometry(interactionTextView, ((UIView *)view).bounds);
    XCTAssertEqualObjects(interactionTextView.attributedText.string, text);
  });

  [self evaluateSource:R"(__RNTextEngineRelease(globalThis.__standardPreparedSelectableHandle))"];
}

- (void)testTextViewSelectableWithoutCapHeightUsesStandardInteractionBounds
{
  RunOnMainSync(^{
    Class textViewClass = NSClassFromString(@"RNTextEngineTextView");
    XCTAssertNotNil(textViewClass);

    id view = [[textViewClass alloc] initWithFrame:CGRectMake(0, 0, 180, 24)];
    [view setValue:@"Standard selectable" forKey:@"text"];
    [view setValue:@"TestTiemposText-Regular" forKey:@"fontFamily"];
    [view setValue:@17 forKey:@"fontSize"];
    [view setValue:@24 forKey:@"lineHeight"];
    [view setValue:@YES forKey:@"selectable"];
    [view layoutIfNeeded];

    UITextView *interactionTextView = (UITextView *)FindTextViewSubview(view);
    XCTAssertNotNil(interactionTextView);
    AssertInteractionTextViewGeometry(interactionTextView, ((UIView *)view).bounds);
    XCTAssertEqualObjects(interactionTextView.attributedText.string, @"Standard selectable");
  });
}

- (void)testTextViewAnchorToCapHeightOffsetsDisplayOwnerWithoutSelection
{
  NSString *text = @"Cap anchored title";
  CGFloat width = 240;
  ExpectedCapHeightLayoutMetrics expectedMetrics =
      ExpectedCapHeightMetrics(BuildAttributedText(text, @"TestEpiceneDisplay-Regular", 40, 48, NSTextAlignmentLeft),
                               CGSizeMake(width, CGFLOAT_MAX),
                               1);
  NSDictionary *anchoredLayout = [self evaluateJSONExpression:R"(
    __RNTextEngineMeasure(
      "Cap anchored title",
      { fontFamily: "TestEpiceneDisplay-Regular", fontSize: 40, lineHeight: 48 },
      { anchorToCapHeight: true, maxLines: 1, width: 240 }
    )
  )"];
  XCTAssertEqualWithAccuracy([anchoredLayout[@"height"] doubleValue], expectedMetrics.height, 0.001);

  RunOnMainSync(^{
    Class textViewClass = NSClassFromString(@"RNTextEngineTextView");
    XCTAssertNotNil(textViewClass);

    id view = [[textViewClass alloc] initWithFrame:CGRectMake(0, 0, width, expectedMetrics.height)];
    [view setValue:text forKey:@"text"];
    [view setValue:@"TestEpiceneDisplay-Regular" forKey:@"fontFamily"];
    [view setValue:@40 forKey:@"fontSize"];
    [view setValue:@48 forKey:@"lineHeight"];
    SetBoolProperty(view, @"anchorToCapHeight", YES);
    [view setNeedsLayout];
    [view layoutIfNeeded];

    id displayView = FindDisplaySubview(view);
    XCTAssertNotNil(displayView);
    CGRect displayFrame = [displayView frame];
    UIView *typedView = (UIView *)view;
    XCTAssertEqualWithAccuracy(displayFrame.origin.y, -expectedMetrics.topInset, 0.001);
    XCTAssertEqualWithAccuracy(
        displayFrame.size.height,
        typedView.bounds.size.height + expectedMetrics.topInset + expectedMetrics.bottomInset,
        0.001);
  });
}

- (void)testPreparedTextViewAnchorToCapHeightOffsetsDisplayOwnerWithoutSelection
{
  NSString *text = @"Cap anchored prepared text";
  CGFloat width = 240;
  ExpectedCapHeightLayoutMetrics expectedMetrics =
      ExpectedCapHeightMetrics(BuildAttributedText(text, @"TestEpiceneDisplay-Regular", 40, 48, NSTextAlignmentLeft),
                               CGSizeMake(width, CGFLOAT_MAX),
                               1);

  double handle = [self evaluateNumber:R"(
    (globalThis.__displayPreparedHandle = __RNTextEnginePrepare(
      "Cap anchored prepared text",
      { fontFamily: "TestEpiceneDisplay-Regular", fontSize: 40, lineHeight: 48 }
    ))
  )"];
  NSDictionary *anchoredLayout = [self evaluateJSONExpression:R"(
    __RNTextEngineLayout(globalThis.__displayPreparedHandle, { anchorToCapHeight: true, maxLines: 1, width: 240 })
  )"];
  XCTAssertEqualWithAccuracy([anchoredLayout[@"height"] doubleValue], expectedMetrics.height, 0.001);

  RunOnMainSync(^{
    Class preparedTextViewClass = NSClassFromString(@"RNTextEnginePreparedTextView");
    XCTAssertNotNil(preparedTextViewClass);

    id view = [[preparedTextViewClass alloc] initWithFrame:CGRectMake(0, 0, width, expectedMetrics.height)];
    [view setValue:@(handle) forKey:@"handle"];
    SetBoolProperty(view, @"anchorToCapHeight", YES);
    [view setValue:@1 forKey:@"numberOfLines"];
    [view layoutIfNeeded];

    id displayView = FindDisplaySubview(view);
    XCTAssertNotNil(displayView);
    CGRect displayFrame = [displayView frame];
    UIView *typedView = (UIView *)view;
    XCTAssertEqualWithAccuracy(displayFrame.origin.y, -expectedMetrics.topInset, 0.001);
    XCTAssertEqualWithAccuracy(
        displayFrame.size.height,
        typedView.bounds.size.height + expectedMetrics.topInset + expectedMetrics.bottomInset,
        0.001);
  });

  [self evaluateSource:R"(__RNTextEngineRelease(globalThis.__displayPreparedHandle))"];
}

- (void)testPreparedTextViewAnchorToCapHeightUsesFirstVisibleLineWhenWrapped
{
  NSString *text = @"Wrapped prepared text should still anchor from the first line cap height rather than the full glyph box.";
  CGSize viewSize = CGSizeMake(180, 140);
  ExpectedCapHeightLayoutMetrics expectedMetrics =
      ExpectedCapHeightMetrics(BuildAttributedText(text, @"TestTiemposText-Regular", 17, 24, NSTextAlignmentLeft),
                               CGSizeMake(viewSize.width, CGFLOAT_MAX),
                               0);

  double handle = [self evaluateNumber:R"(
    (globalThis.__wrappedPreparedHandle = __RNTextEnginePrepare(
      "Wrapped prepared text should still anchor from the first line cap height rather than the full glyph box.",
      { fontFamily: "TestTiemposText-Regular", fontSize: 17, lineHeight: 24 }
    ))
  )"];
  NSDictionary *anchoredLayout = [self evaluateJSONExpression:R"(
    __RNTextEngineLayout(globalThis.__wrappedPreparedHandle, { anchorToCapHeight: true, width: 180 })
  )"];
  XCTAssertEqualWithAccuracy([anchoredLayout[@"height"] doubleValue], expectedMetrics.height, 0.001);

  RunOnMainSync(^{
    Class preparedTextViewClass = NSClassFromString(@"RNTextEnginePreparedTextView");
    XCTAssertNotNil(preparedTextViewClass);

    id view = [[preparedTextViewClass alloc] initWithFrame:CGRectMake(0, 0, viewSize.width, expectedMetrics.height)];
    [view setValue:@(handle) forKey:@"handle"];
    SetBoolProperty(view, @"anchorToCapHeight", YES);
    [view layoutIfNeeded];

    id displayView = FindDisplaySubview(view);
    XCTAssertNotNil(displayView);
    CGRect displayFrame = [displayView frame];
    UIView *typedView = (UIView *)view;
    XCTAssertEqualWithAccuracy(displayFrame.origin.y, -expectedMetrics.topInset, 0.001);
    XCTAssertEqualWithAccuracy(
        displayFrame.size.height,
        typedView.bounds.size.height + expectedMetrics.topInset + expectedMetrics.bottomInset,
        0.001);
  });

  [self evaluateSource:R"(__RNTextEngineRelease(globalThis.__wrappedPreparedHandle))"];
}

- (void)testLayoutLinesAnchorToCapHeightPreservesInterlineSpacing
{
  double handle = [self evaluateNumber:R"(
    (globalThis.__linesHandle = __RNTextEnginePrepare(
      "A narrow column should wrap this text across several lines so anchored line geometry can be inspected.",
      { fontFamily: "TestTiemposText-Regular", fontSize: 17, lineHeight: 24 }
    ))
  )"];

  NSDictionary *linesLayout = [self evaluateJSONExpression:R"(
    __RNTextEngineLayoutLines(globalThis.__linesHandle, { anchorToCapHeight: true, width: 120 })
  )"];
  NSArray<NSDictionary *> *lines = linesLayout[@"lines"];
  XCTAssertTrue(lines.count >= 2);

  CGFloat firstBottom = [lines[0][@"bottom"] doubleValue];
  CGFloat secondBottom = [lines[1][@"bottom"] doubleValue];
  XCTAssertEqualWithAccuracy(secondBottom - firstBottom, 24, 0.001);

  [self evaluateSource:R"(__RNTextEngineRelease(globalThis.__linesHandle))"];
  XCTAssertNotEqual(handle, 0);
}

- (void)testTextViewPreparedMeasurementHandleReportsIntrinsicWidth
{
  NSString *text = @"Intrinsic measurement text";
  uint64_t handle = CreateTextViewMeasurementHandle(text, 20, 24);

  CGFloat preferredWidth = measurePreparedTextWidthForHandle(handle);
  CGSize intrinsicSize = measurePreparedTextLayoutForHandle(handle, preferredWidth, 0, nil, NO);
  releasePreparedTextHandle(handle);

  XCTAssertGreaterThan(preferredWidth, 0);
  XCTAssertEqualWithAccuracy(intrinsicSize.width, preferredWidth, 0.5);
  XCTAssertEqualWithAccuracy(intrinsicSize.height, 24, 0.001);
}

- (void)testTextViewPreparedMeasurementHandlePublishesTypesetterAcrossConcurrentFirstLayout
{
  NSString *text =
      @"Concurrent prepared text layout should publish the lazily-created CoreText typesetter without racing readers "
       "on layout threads.";
  uint64_t handle = CreateTextViewMeasurementHandle(text, 18, 24, @"TestTiemposText-Regular");
  dispatch_queue_t queue =
      dispatch_queue_create("com.rntextengine.tests.prepared-typesetter", DISPATCH_QUEUE_CONCURRENT);

  dispatch_apply(32, queue, ^(size_t index) {
    CGFloat width = 96 + (index % 8) * 13;
    CGSize measuredSize = measurePreparedTextLayoutForHandle(handle, width, 0, nil, NO);
    XCTAssertGreaterThan(measuredSize.width, 0);
    XCTAssertGreaterThan(measuredSize.height, 0);
  });

  releasePreparedTextHandle(handle);
}

- (void)testTextViewPreparedMeasurementHandleWrapsAtNarrowWidths
{
  NSString *text = @"Wrapped measurement text should occupy more than one line at narrow widths.";
  uint64_t handle = CreateTextViewMeasurementHandle(text, 18, 22);

  CGFloat preferredWidth = measurePreparedTextWidthForHandle(handle);
  CGSize intrinsicSize = measurePreparedTextLayoutForHandle(handle, preferredWidth, 0, nil, NO);
  CGSize wrappedSize = measurePreparedTextLayoutForHandle(handle, preferredWidth * 0.5, 0, nil, NO);
  releasePreparedTextHandle(handle);

  XCTAssertLessThanOrEqual(wrappedSize.width, preferredWidth * 0.5 + 0.001);
  XCTAssertGreaterThan(wrappedSize.height, intrinsicSize.height);
}

- (void)testPreparedMeasurementMatchesRenderedFontFallbackHeight
{
  RunOnMainSync(^{
    NSArray<NSString *> *texts = @[
      @"Hello", @"🙂", @"Hello 🙂 world", @"日本語の短い文章", @"বাংলা ভাষা", @"देवनागरी पाठ",
      @"Hello বাংলা ভাষা", @"Hello\nदेवनागरी पाठ"
    ];
    for (NSString *text in texts) {
      NSData *encodedText = [NSJSONSerialization dataWithJSONObject:text options:NSJSONWritingFragmentsAllowed error:nil];
      std::string jsText = [[NSString alloc] initWithData:encodedText encoding:NSUTF8StringEncoding].UTF8String;
      for (NSNumber *fontSizeValue in @[@14, @17, @32]) {
        for (NSNumber *lineHeightValue in @[@0, @24]) {
          for (NSNumber *widthValue in @[@48, @160]) {
            CGFloat fontSize = fontSizeValue.doubleValue;
            CGFloat lineHeight = lineHeightValue.doubleValue;
            CGFloat width = widthValue.doubleValue;
            uint64_t handle = CreateTextViewMeasurementHandle(text, fontSize, lineHeight);
            NSAttributedString *attributedText = preparedAttributedTextForHandle(handle);
            std::string style = "{allowFontScaling:false,fontSize:" + std::to_string(fontSize) +
                (lineHeight > 0 ? ",lineHeight:" + std::to_string(lineHeight) : "") + "}";
            for (NSNumber *anchorValue in @[@NO, @YES]) {
              BOOL anchor = anchorValue.boolValue;
              CGFloat renderedHeight = anchor
                  ? ExpectedCapHeightMetrics(attributedText, CGSizeMake(width, CGFLOAT_MAX), 0).height
                  : ExpectedLayoutMetricsForAttributedText(attributedText, CGSizeMake(width, CGFLOAT_MAX), 0, nil).height;
              CGSize measured = measurePreparedTextLayoutForHandle(handle, width, 0, nil, anchor);
              NSString *context = [NSString stringWithFormat:@"Text %@, font %.1f, line height %.1f, width %.1f, anchored %d",
                  text, fontSize, lineHeight, width, anchor];
              XCTAssertEqualWithAccuracy(measured.height, renderedHeight, 1.0 / UIScreen.mainScreen.scale, @"%@", context);
              std::string options = "{width:" + std::to_string(width) + ",anchorToCapHeight:" + (anchor ? "true" : "false") + "}";
              NSDictionary *oneShot = [self evaluateJSONExpression:"__RNTextEngineMeasure(" + jsText + "," + style + "," + options + ")"];
              NSDictionary *prepared = [self evaluateJSONExpression:"__RNTextEngineLayout(" + std::to_string(handle) + "," + options + ")"];
              XCTAssertEqualWithAccuracy([oneShot[@"height"] doubleValue], renderedHeight, 1.0 / UIScreen.mainScreen.scale, @"%@", context);
              XCTAssertEqualWithAccuracy([prepared[@"height"] doubleValue], renderedHeight, 1.0 / UIScreen.mainScreen.scale, @"%@", context);
              NSDictionary *lines = [self evaluateJSONExpression:"__RNTextEngineLayoutLines(" + std::to_string(handle) + "," + options + ")"];
              NSDictionary *firstLine = [lines[@"lines"] firstObject];
              NSDictionary *nextLine = [self evaluateJSONExpression:"__RNTextEngineLayoutNextLine(" + std::to_string(handle) + ",0," + std::to_string(width) + "," + (anchor ? "true" : "false") + ")"];
              XCTAssertEqualWithAccuracy([nextLine[@"bottom"] doubleValue], [firstLine[@"bottom"] doubleValue], 1.0 / UIScreen.mainScreen.scale, @"%@", context);
            }
            releasePreparedTextHandle(handle);
          }
        }
      }
    }
  });
}

- (void)testPreparedRunMeasurementMatchesRenderedFallbackBaselines
{
  RunOnMainSync(^{
    for (NSString *text in @[@"বাংলা ভাষা", @"देवनागरी पाठ", @"Hello বাংলা ভাষা"]) {
      for (NSNumber *mask in @[@1, @4]) {
        uint64_t handle = CreateTextViewMeasurementHandleWithRunFontSizes(
            text, 17, 0, @[@0], @[@(text.length)], @[mask], @[@32]);
        NSAttributedString *attributedText = preparedAttributedTextForHandle(handle);
        for (NSNumber *widthValue in @[@48, @160]) {
          CGFloat width = widthValue.doubleValue;
          for (NSNumber *anchorValue in @[@NO, @YES]) {
            BOOL anchored = anchorValue.boolValue;
            CGFloat expected = anchored
                ? ExpectedCapHeightMetrics(attributedText, CGSizeMake(width, CGFLOAT_MAX), 0).height
                : ExpectedLayoutMetricsForAttributedText(attributedText, CGSizeMake(width, CGFLOAT_MAX), 0, nil).height;
            CGSize measured = measurePreparedTextLayoutForHandle(handle, width, 0, nil, anchored);
            XCTAssertEqualWithAccuracy(measured.height, expected, 1.0 / UIScreen.mainScreen.scale,
                @"Text %@, run mask %@, width %@, anchored %@", text, mask, widthValue, anchorValue);
          }
        }
        releasePreparedTextHandle(handle);
      }
    }
  });
}

- (void)testMixedFontRunsMatchRenderedBaselines
{
  RunOnMainSync(^{
    XCTAssertNotNil([UIFont fontWithName:@"TestTiemposText-Regular" size:17]);
    XCTAssertNotNil([UIFont fontWithName:@"TestEpiceneDisplay-Regular" size:17]);
    for (NSString *text in @[@"A A\nA A", @"A A\r\nA A", @"A A\u2028A A", @"A A\u2029A A", @"A A\n\nA A", @"A A\n \nA A"]) {
      NSData *encodedText = [NSJSONSerialization dataWithJSONObject:text options:NSJSONWritingFragmentsAllowed error:nil];
      std::string jsText = [[NSString alloc] initWithData:encodedText encoding:NSUTF8StringEncoding].UTF8String;
      for (const std::string &baseHeight : {"", ",lineHeight:24"}) {
        for (const std::string &runHeight : {"", ",lineHeight:40"}) {
          for (int runStart : {0, 2}) {
            std::string source = "__RNTextEnginePrepare(" + jsText +
                ",{fontFamily:\"TestTiemposText-Regular\",fontSize:17,allowFontScaling:false" + baseHeight + "},[" +
                "{start:" + std::to_string(runStart) + ",end:" + std::to_string(runStart + 1) +
                ",style:{fontFamily:\"TestEpiceneDisplay-Regular\"" + runHeight + "}}," +
                "{start:" + std::to_string(text.length - 3) + ",end:" + std::to_string(text.length - 2) +
                ",style:{fontFamily:\"TestEpiceneDisplay-Regular\"}}])";
            uint64_t handle = static_cast<uint64_t>([self evaluateNumber:source]);
            NSAttributedString *attributedText = preparedAttributedTextForHandle(handle);
            for (NSNumber *width in @[@12, @160]) {
              for (NSNumber *anchor in @[@NO, @YES]) {
                CGFloat expected = anchor.boolValue
                    ? ExpectedCapHeightMetrics(attributedText, CGSizeMake(width.doubleValue, CGFLOAT_MAX), 0).height
                    : ExpectedLayoutMetricsForAttributedText(attributedText, CGSizeMake(width.doubleValue, CGFLOAT_MAX), 0, nil).height;
                CGSize measured = measurePreparedTextLayoutForHandle(handle, width.doubleValue, 0, nil, anchor.boolValue);
                XCTAssertEqualWithAccuracy(measured.height, expected, 1.0 / UIScreen.mainScreen.scale,
                    @"Text %@, width %@, anchored %@, base height %s, run height %s, run start %d",
                    text, width, anchor, baseHeight.c_str(), runHeight.c_str(), runStart);
                std::string jsHandle = std::to_string(handle);
                std::string options = "{width:" + std::to_string(width.doubleValue) + ",anchorToCapHeight:" + (anchor.boolValue ? "true" : "false") + "}";
                NSDictionary *layout = [self evaluateJSONExpression:"__RNTextEngineLayout(" + jsHandle + "," + options + ")"];
                NSDictionary *layoutLines = [self evaluateJSONExpression:"__RNTextEngineLayoutLines(" + jsHandle + "," + options + ")"];
                NSArray<NSDictionary *> *lines = layoutLines[@"lines"];
                XCTAssertEqual([layout[@"lineCount"] unsignedIntegerValue], lines.count);
                for (NSDictionary *line in lines) {
                  NSDictionary *next = [self evaluateJSONExpression:"__RNTextEngineLayoutNextLine(" + jsHandle + "," +
                      std::to_string([line[@"start"] integerValue]) + "," + std::to_string(width.doubleValue) + "," +
                      (anchor.boolValue ? "true" : "false") + ")"];
                  XCTAssertEqualObjects(next[@"start"], line[@"start"]);
                  XCTAssertEqualObjects(next[@"end"], line[@"end"]);
                  if (line == lines.firstObject) {
                    XCTAssertEqualWithAccuracy([next[@"bottom"] doubleValue], [line[@"bottom"] doubleValue], 1.0 / UIScreen.mainScreen.scale);
                  }
                }
              }
            }
            releasePreparedTextHandle(handle);
          }
        }
      }
    }
  });
}

- (void)testTextViewPreparedMeasurementHandleRespectsNumberOfLines
{
  NSString *text = @"One two three four five six seven eight nine ten.";
  uint64_t handle = CreateTextViewMeasurementHandle(text, 17, 24);

  CGFloat preferredWidth = measurePreparedTextWidthForHandle(handle);
  CGSize singleLineSize = measurePreparedTextLayoutForHandle(handle, preferredWidth * 0.4, 1, @"tail", NO);
  releasePreparedTextHandle(handle);

  XCTAssertEqualWithAccuracy(singleLineSize.height, 24, 0.001);
}

- (void)testPreparedLayoutMatchesTextKitForSingleLineTruncationModes
{
  NSString *text = @"One two three four five six seven eight nine ten.";
  NSAttributedString *attributedText = BuildAttributedText(text, @"TestTiemposText-Regular", 17, 24, NSTextAlignmentLeft);
  NSArray<NSString *> *modes = @[ @"tail", @"head", @"middle", @"clip" ];

  for (NSString *mode in modes) {
    NSString *prepareSource = [NSString stringWithFormat:
        @"(globalThis.__truncationHandle = __RNTextEnginePrepare(\"%@\", { fontFamily: \"TestTiemposText-Regular\", fontSize: 17, lineHeight: 24 }))",
        text];
    NSString *layoutSource = [NSString stringWithFormat:
        @"__RNTextEngineLayout(globalThis.__truncationHandle, { width: 120, maxLines: 1, ellipsizeMode: \"%@\" })",
        mode];
    double handle = [self evaluateNumber:prepareSource.UTF8String];
    NSDictionary *layout = [self evaluateJSONExpression:layoutSource.UTF8String];
    ExpectedLayoutMetrics expected = ExpectedLayoutMetricsForAttributedText(attributedText, CGSizeMake(120, CGFLOAT_MAX), 1, mode);
    [self assertLayoutDictionary:layout equalsExpectedMetrics:expected];
    [self evaluateSource:"__RNTextEngineRelease(globalThis.__truncationHandle)"];
    XCTAssertNotEqual(handle, 0);
  }
}

- (void)testPreparedLayoutMatchesTextKitForSingleLineTruncationModesAcrossExplicitBreaks
{
  NSString *text = @"Short first line.\nSecond paragraph should stay hidden from the first visible line.";
  NSAttributedString *attributedText = BuildAttributedText(text, @"TestTiemposText-Regular", 17, 24, NSTextAlignmentLeft);
  NSArray<NSString *> *modes = @[ @"tail", @"head", @"middle", @"clip" ];

  for (NSString *mode in modes) {
    NSString *prepareSource = [NSString stringWithFormat:
        @"(globalThis.__explicitBreakTruncationHandle = __RNTextEnginePrepare(\"%@\", { fontFamily: \"TestTiemposText-Regular\", fontSize: 17, lineHeight: 24 }))",
        [text stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"]];
    NSString *layoutSource = [NSString stringWithFormat:
        @"__RNTextEngineLayout(globalThis.__explicitBreakTruncationHandle, { width: 220, maxLines: 1, ellipsizeMode: \"%@\" })",
        mode];
    double handle = [self evaluateNumber:prepareSource.UTF8String];
    NSDictionary *layout = [self evaluateJSONExpression:layoutSource.UTF8String];
    ExpectedLayoutMetrics expected = ExpectedLayoutMetricsForAttributedText(attributedText, CGSizeMake(220, CGFLOAT_MAX), 1, mode);
    [self assertLayoutDictionary:layout equalsExpectedMetrics:expected];
    [self evaluateSource:"__RNTextEngineRelease(globalThis.__explicitBreakTruncationHandle)"];
    XCTAssertNotEqual(handle, 0);
  }
}

- (void)testPreparedLayoutMatchesTextKitForMultiLineTailTruncation
{
  NSString *text = @"Prepared layout should match TextKit when the final visible line is truncated.";
  NSAttributedString *attributedText = BuildAttributedText(text, @"TestTiemposText-Regular", 17, 24, NSTextAlignmentLeft);
  double handle = [self evaluateNumber:R"(
    (globalThis.__multiLineTruncationHandle = __RNTextEnginePrepare(
      "Prepared layout should match TextKit when the final visible line is truncated.",
      { fontFamily: "TestTiemposText-Regular", fontSize: 17, lineHeight: 24 }
    ))
  )"];

  NSDictionary *layout = [self evaluateJSONExpression:R"(
    __RNTextEngineLayout(globalThis.__multiLineTruncationHandle, { width: 180, maxLines: 2, ellipsizeMode: "tail" })
  )"];
  ExpectedLayoutMetrics expected =
      ExpectedLayoutMetricsForAttributedText(attributedText, CGSizeMake(180, CGFLOAT_MAX), 2, @"tail");

  [self assertLayoutDictionary:layout equalsExpectedMetrics:expected];
  [self evaluateSource:"__RNTextEngineRelease(globalThis.__multiLineTruncationHandle)"];
  XCTAssertNotEqual(handle, 0);
}

- (void)testTextViewPreparedMeasurementHandleMatchesTextKitForSingleLineTruncationModes
{
  NSString *text = @"One two three four five six seven eight nine ten.";
  NSAttributedString *attributedText = BuildAttributedText(text, @"TestTiemposText-Regular", 17, 24, NSTextAlignmentLeft);
  NSArray<NSString *> *modes = @[ @"tail", @"head", @"middle", @"clip" ];

  for (NSString *mode in modes) {
    uint64_t handle = CreateTextViewMeasurementHandle(text, 17, 24, @"TestTiemposText-Regular");
    CGSize measuredSize = measurePreparedTextLayoutForHandle(handle, 120, 1, mode, NO);
    releasePreparedTextHandle(handle);

    ExpectedLayoutMetrics expected = ExpectedLayoutMetricsForAttributedText(attributedText, CGSizeMake(120, CGFLOAT_MAX), 1, mode);
    XCTAssertEqualWithAccuracy(measuredSize.width, expected.width, 0.001);
    XCTAssertEqualWithAccuracy(measuredSize.height, expected.height, 0.001);
  }
}

- (void)testTextViewPreparedMeasurementHandleIncludesInlineRunOverrides
{
  NSString *text = @"base LARGE base";
  NSArray<NSNumber *> *runStarts = @[ @5 ];
  NSArray<NSNumber *> *runEnds = @[ @10 ];
  NSArray<NSNumber *> *runStyleMasks = @[ @(1 << 2) ];
  NSArray<NSNumber *> *runFontSizes = @[ @28 ];

  uint64_t baseHandle = CreateTextViewMeasurementHandle(text, 16, 20);
  uint64_t runHandle =
      CreateTextViewMeasurementHandleWithRunFontSizes(text, 16, 20, runStarts, runEnds, runStyleMasks, runFontSizes);

  CGFloat baseWidth = measurePreparedTextWidthForHandle(baseHandle);
  CGFloat runWidth = measurePreparedTextWidthForHandle(runHandle);
  releasePreparedTextHandle(baseHandle);
  releasePreparedTextHandle(runHandle);

  XCTAssertGreaterThan(runWidth, baseWidth);
}

@end
