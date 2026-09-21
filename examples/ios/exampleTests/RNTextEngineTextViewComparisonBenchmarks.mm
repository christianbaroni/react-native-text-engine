#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "RNTextEngineTextViewTestHelpers.h"

#ifdef RCT_NEW_ARCH_ENABLED
#import "../../../ios/RNTextEngineBindings.h"
#import <hermes/hermes.h>
#import <React/RCTParagraphComponentView.h>
#import <React/RCTConversions.h>
#import <React/RCTUtils.h>
#import "../../../ios/RNTextEngineAttributedTextDisplayView.h"

#import <react/renderer/attributedstring/AttributedString.h>
#import <react/renderer/attributedstring/AttributedStringBox.h>
#import <react/renderer/attributedstring/ParagraphAttributes.h>
#import <react/renderer/components/root/RootShadowNode.h>
#import <react/renderer/components/text/ParagraphProps.h>
#import <react/renderer/components/text/ParagraphShadowNode.h>
#import <react/renderer/components/text/RawTextShadowNode.h>
#import <react/renderer/core/LayoutConstraints.h>
#import <react/renderer/textlayoutmanager/TextLayoutContext.h>
#import <react/renderer/textlayoutmanager/TextLayoutManager.h>
#import <react/utils/ContextContainer.h>

#include <algorithm>
#include <cmath>
#include <limits>
#include <optional>
#include <string>
#include <sys/utsname.h>
#include <vector>

using namespace facebook;
using namespace facebook::react;
using namespace rntextengine::test;
#endif

namespace {

#ifdef RCT_NEW_ARCH_ENABLED

constexpr NSInteger kRunStyleHasFontSize = 1 << 2;
constexpr NSInteger kRunStyleHasFontStyle = 1 << 3;
constexpr NSInteger kRunStyleHasFontWeight = 1 << 4;
constexpr NSInteger kRunStyleHasLetterSpacing = 1 << 5;
constexpr NSInteger kRunStyleHasLineHeight = 1 << 6;
constexpr NSInteger kRunStyleHasTabularNumbers = 1 << 7;

volatile double RNTextBenchmarkSink = 0;

struct RunFixture {
  NSInteger start{0};
  NSInteger end{0};
  NSInteger styleMask{0};
  TextStyleFixture style{};
};

enum class Implementation { RNText, TextView, PreparedTextView };

struct PreparedHandles {
  std::vector<uint64_t> values;
  PreparedHandles() = default;
  PreparedHandles(const PreparedHandles &) = delete;
  ~PreparedHandles() {
    for (auto handle : values) rntextengine::releasePreparedTextHandle(handle);
  }
};

static uint64_t NowNanos()
{
  return clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
}

static NSString *ToNSString(const std::string &value)
{
  if (value.empty()) return nil;
  return [NSString stringWithUTF8String:value.c_str()];
}

static FontWeight ResolveFontWeight(const std::string &value)
{
  if (value == "100") return FontWeight::Weight100;
  if (value == "200") return FontWeight::Weight200;
  if (value == "300") return FontWeight::Weight300;
  if (value == "500") return FontWeight::Weight500;
  if (value == "600") return FontWeight::Weight600;
  if (value == "700") return FontWeight::Weight700;
  if (value == "800") return FontWeight::Weight800;
  if (value == "900") return FontWeight::Weight900;
  return FontWeight::Weight400;
}

static FontStyle ResolveFontStyle(const std::string &value)
{
  if (value == "italic") return FontStyle::Italic;
  if (value == "oblique") return FontStyle::Oblique;
  return FontStyle::Normal;
}

static TextAttributes BuildTextAttributes(const TextStyleFixture &style)
{
  auto attributes = TextAttributes::defaultTextAttributes();
  attributes.allowFontScaling = false;
  attributes.fontSize = style.fontSize;
  attributes.fontSizeMultiplier = 1.0;
  attributes.fontStyle = ResolveFontStyle(style.fontStyle);
  attributes.fontWeight = ResolveFontWeight(style.fontWeight);
  attributes.letterSpacing = style.letterSpacing;
  attributes.lineHeight = style.lineHeight;
  if (style.tabularNumbers) attributes.fontVariant = FontVariant::TabularNums;
  return attributes;
}

static TextAttributes MergeTextAttributes(TextAttributes attributes, const RunFixture &run)
{
  if ((run.styleMask & kRunStyleHasFontSize) != 0) attributes.fontSize = run.style.fontSize;
  if ((run.styleMask & kRunStyleHasFontStyle) != 0) attributes.fontStyle = ResolveFontStyle(run.style.fontStyle);
  if ((run.styleMask & kRunStyleHasFontWeight) != 0) attributes.fontWeight = ResolveFontWeight(run.style.fontWeight);
  if ((run.styleMask & kRunStyleHasLetterSpacing) != 0) attributes.letterSpacing = run.style.letterSpacing;
  if ((run.styleMask & kRunStyleHasLineHeight) != 0) attributes.lineHeight = run.style.lineHeight;
  if ((run.styleMask & kRunStyleHasTabularNumbers) != 0) {
    attributes.fontVariant = run.style.tabularNumbers ? std::optional<FontVariant>{FontVariant::TabularNums} : std::nullopt;
  }
  return attributes;
}

static void AppendFragment(AttributedString &attributedString, std::string text, TextAttributes attributes)
{
  AttributedString::Fragment fragment;
  fragment.string = std::move(text);
  fragment.textAttributes = std::move(attributes);
  attributedString.appendFragment(std::move(fragment));
}

static AttributedString BuildRNAttributedString(
    const std::string &text,
    const TextStyleFixture &baseStyle,
    const std::vector<RunFixture> &runs)
{
  AttributedString attributedString;
  const auto baseAttributes = BuildTextAttributes(baseStyle);
  attributedString.setBaseTextAttributes(baseAttributes);

  if (runs.empty()) {
    AppendFragment(attributedString, text, baseAttributes);
    return attributedString;
  }

  NSInteger cursor = 0;
  for (const auto &run : runs) {
    if (run.start > cursor) {
      AppendFragment(
          attributedString,
          text.substr(static_cast<size_t>(cursor), static_cast<size_t>(run.start - cursor)),
          baseAttributes);
    }

    AppendFragment(
        attributedString,
        text.substr(static_cast<size_t>(run.start), static_cast<size_t>(run.end - run.start)),
        MergeTextAttributes(baseAttributes, run));
    cursor = run.end;
  }

  if (cursor < static_cast<NSInteger>(text.size())) {
    AppendFragment(attributedString, text.substr(static_cast<size_t>(cursor)), baseAttributes);
  }

  return attributedString;
}

static ParagraphAttributes BuildParagraphAttributes(NSInteger maxLines)
{
  ParagraphAttributes attributes;
  attributes.maximumNumberOfLines = static_cast<int>(maxLines);
  attributes.ellipsizeMode = EllipsizeMode::Tail;
  return attributes;
}

static TextLayoutContext BuildTextLayoutContext()
{
  return TextLayoutContext{
      .pointScaleFactor = static_cast<Float>(UIScreen.mainScreen.scale),
      .surfaceId = 1,
  };
}

static double MeasureBlock(dispatch_block_t block, NSInteger repetitions)
{
  const uint64_t started = NowNanos();
  @autoreleasepool {
    for (NSInteger repeat = 0; repeat < repetitions; repeat += 1) block();
  }
  return static_cast<double>(NowNanos() - started) / 1000000.0;
}

static std::vector<std::vector<double>> MeasureImplementations(
    NSArray<dispatch_block_t> *blocks, NSInteger repetitions, NSInteger run)
{
  constexpr NSInteger warmups = 2;
  constexpr NSInteger samples = 9;
  std::vector<std::vector<double>> result(blocks.count);
  for (auto &values : result) values.reserve(samples);
  for (NSInteger index = -warmups; index < samples; ++index) {
    for (NSUInteger offset = 0; offset < blocks.count; ++offset) {
      NSUInteger implementation = (index + warmups + run - 1 + offset) % blocks.count;
      double elapsed = MeasureBlock(blocks[implementation], repetitions);
      if (index >= 0) result[implementation].push_back(elapsed);
    }
  }
  return result;
}

static NSArray<NSNumber *> *NumbersFromRuns(const std::vector<RunFixture> &runs, NSInteger (^read)(const RunFixture &run))
{
  NSMutableArray<NSNumber *> *values = [NSMutableArray arrayWithCapacity:runs.size()];
  for (const auto &run : runs) {
    [values addObject:@(read(run))];
  }
  return values;
}

static NSArray<NSString *> *StringValuesFromRuns(const std::vector<RunFixture> &runs, NSString *(^read)(const RunFixture &run))
{
  NSMutableArray<NSString *> *values = [NSMutableArray arrayWithCapacity:runs.size()];
  for (const auto &run : runs) {
    [values addObject:read(run) ?: @""];
  }
  return values;
}

static NSArray<NSNumber *> *DoubleValuesFromRuns(const std::vector<RunFixture> &runs, double (^read)(const RunFixture &run))
{
  NSMutableArray<NSNumber *> *values = [NSMutableArray arrayWithCapacity:runs.size()];
  for (const auto &run : runs) {
    [values addObject:@(read(run))];
  }
  return values;
}

static NSArray<NSNumber *> *BoolValuesFromRuns(const std::vector<RunFixture> &runs, BOOL (^read)(const RunFixture &run))
{
  NSMutableArray<NSNumber *> *values = [NSMutableArray arrayWithCapacity:runs.size()];
  for (const auto &run : runs) {
    [values addObject:@(read(run))];
  }
  return values;
}

static uint64_t CreateTextViewHandle(
    NSString *text,
    const TextStyleFixture &style,
    NSArray<NSNumber *> *runStarts,
    NSArray<NSNumber *> *runEnds,
    NSArray<NSNumber *> *runStyleMasks,
    NSArray<NSString *> *runFontStyles,
    NSArray<NSString *> *runFontWeights,
    NSArray<NSNumber *> *runFontSizes,
    NSArray<NSNumber *> *runLetterSpacings,
    NSArray<NSNumber *> *runLineHeights,
    NSArray<NSNumber *> *runTabularNumbers)
{
  return rntextengine::createPreparedTextHandleForTextView(text, {
      .fontSize = style.fontSize,
      .fontStyle = ToNSString(style.fontStyle),
      .fontWeight = ToNSString(style.fontWeight),
      .letterSpacing = style.letterSpacing,
      .lineHeight = style.lineHeight,
      .tabularNumbers = style.tabularNumbers,
  }, RNTextEngineTextRunsFromArrays(runStarts, runEnds, runStyleMasks,
      nil, nil, runFontSizes, runFontStyles, runFontWeights, runLetterSpacings, runLineHeights, runTabularNumbers));
}

static CGSize MeasureRNTextLayout(
    const TextLayoutManager &manager,
    const AttributedStringBox &input,
    const ParagraphAttributes &paragraphAttributes,
    const TextLayoutContext &context,
    const LayoutConstraints &constraints)
{
  const auto measurement = manager.measure(input, paragraphAttributes, context, constraints);
  RNTextBenchmarkSink += measurement.size.width + measurement.size.height;
  return CGSizeMake(measurement.size.width, measurement.size.height);
}

static CGSize MeasureTextViewLayout(uint64_t handle, CGFloat width, NSInteger maxLines)
{
  const CGSize size = rntextengine::measurePreparedTextLayoutForHandle(handle, width, maxLines, maxLines > 0 ? @"tail" : nil, NO);
  RNTextBenchmarkSink += size.width + size.height;
  return size;
}

static std::shared_ptr<RootProps> BuildRootProps(double width)
{
  auto props = std::make_shared<RootProps>();
  props->layoutConstraints = LayoutConstraints{
      .minimumSize = {.width = static_cast<Float>(width), .height = 0},
      .maximumSize = {.width = static_cast<Float>(width), .height = std::numeric_limits<Float>::infinity()},
      .layoutDirection = LayoutDirection::LeftToRight,
  };
  props->layoutContext = BuildFabricLayoutContext();
  props->yogaStyle.setDimension(yoga::Dimension::Width, yoga::StyleSizeLength::points(static_cast<float>(width)));
  return props;
}

static std::shared_ptr<ParagraphProps> BuildParagraphProps(const TextStyleFixture &style, double width)
{
  auto props = std::make_shared<ParagraphProps>();
  props->textAttributes = BuildTextAttributes(style);
  props->paragraphAttributes = BuildParagraphAttributes(0);
  props->yogaStyle.setDimension(yoga::Dimension::Width, yoga::StyleSizeLength::points(static_cast<float>(width)));
  return props;
}

static std::shared_ptr<RawTextProps> BuildRawTextProps(const std::string &text)
{
  auto props = std::make_shared<RawTextProps>();
  props->text = text;
  return props;
}

static std::shared_ptr<RootShadowNode> BuildRNTextTree(
    const ComponentDescriptorRegistry::Shared &registry,
    const std::vector<std::string> &texts,
    const TextStyleFixture &style)
{
  std::vector<ElementFragment> children;
  children.reserve(texts.size());
  for (const auto &text : texts) {
    children.push_back(Element<ParagraphShadowNode>()
        .props(BuildParagraphProps(style, 260))
        .children({Element<RawTextShadowNode>().props(BuildRawTextProps(text))}));
  }
  return BuildShadowNode(registry, Element<RootShadowNode>()
      .surfaceId(1).tag(1).props(BuildRootProps(320)).children(std::move(children)));
}

static std::shared_ptr<RootShadowNode> BuildTextViewTree(
    const ComponentDescriptorRegistry::Shared &registry,
    const std::vector<std::string> &texts,
    const TextStyleFixture &style)
{
  std::vector<ElementFragment> children;
  children.reserve(texts.size());
  for (const auto &text : texts) {
    children.push_back(Element<RNTextEngineTextViewShadowNode>().props(BuildTextViewProps(text, style, 260)));
  }
  return BuildShadowNode(registry, Element<RootShadowNode>()
      .surfaceId(1).tag(1).props(BuildRootProps(320)).children(std::move(children)));
}

struct PreparedTextFixture {
  jsi::Runtime &runtime;
  jsi::HostFunctionType prepare;
  jsi::Object style;
  std::vector<jsi::String> texts;

  PreparedTextFixture(jsi::Runtime &runtime, const std::vector<std::string> &texts, const TextStyleFixture &style)
      : runtime(runtime),
        prepare(runtime.global().getPropertyAsFunction(runtime, "__RNTextEnginePrepare").getHostFunction(runtime)),
        style(runtime) {
    this->style.setProperty(runtime, "fontSize", style.fontSize);
    this->style.setProperty(runtime, "fontWeight", jsi::String::createFromUtf8(runtime, style.fontWeight));
    this->style.setProperty(runtime, "fontStyle", jsi::String::createFromUtf8(runtime, style.fontStyle));
    this->style.setProperty(runtime, "letterSpacing", style.letterSpacing);
    this->style.setProperty(runtime, "lineHeight", style.lineHeight);
    this->style.setProperty(runtime, "tabularNumbers", style.tabularNumbers);
    this->style.setProperty(runtime, "allowFontScaling", false);
    for (const auto &text : texts) this->texts.push_back(jsi::String::createFromUtf8(runtime, text));
  }
};

static std::shared_ptr<RootShadowNode> BuildPreparedTextViewTree(
    const ComponentDescriptorRegistry::Shared &registry,
    const PreparedTextFixture &fixture,
    PreparedHandles &handles)
{
  std::vector<ElementFragment> children;
  children.reserve(fixture.texts.size());
  handles.values.reserve(fixture.texts.size());
  const auto &descriptor = registry->at("RNTextEnginePreparedTextView");
  for (const auto &text : fixture.texts) {
    jsi::Value arguments[] = {jsi::Value(fixture.runtime, text), jsi::Value(fixture.runtime, fixture.style)};
    auto handle = static_cast<uint64_t>(fixture.prepare(fixture.runtime, jsi::Value::undefined(), arguments, 2).asNumber());
    handles.values.push_back(handle);
    CGSize size = rntextengine::measurePreparedTextLayoutForHandle(handle, 260, 0, nil, NO);
    auto props = std::make_shared<RNTextEnginePreparedTextViewProps>();
    props->handle = handle;
    props->anchorToCapHeight = false;
    props->yogaStyle.setDimension(yoga::Dimension::Width, yoga::StyleSizeLength::points(260));
    props->yogaStyle.setDimension(yoga::Dimension::Height, yoga::StyleSizeLength::points(size.height));
    ElementFragment child{};
    child.componentHandle = descriptor.getComponentHandle();
    child.props = props;
    children.push_back(std::move(child));
  }
  return BuildShadowNode(registry, Element<RootShadowNode>()
      .surfaceId(1).tag(1).props(BuildRootProps(320)).children(std::move(children)));
}

static NSUInteger ValidateDrawingLeaf(UIView *view, NSString *expectedText)
{
  NSUInteger count = 0;
  if ([view isKindOfClass:NSClassFromString(@"RCTParagraphTextView")] ||
      [view isKindOfClass:NSClassFromString(@"RNTextEngineAttributedTextDisplayView")]) {
    XCTAssertFalse(view.layer.needsDisplay);
    XCTAssertEqualWithAccuracy(view.layer.contentsScale, UIScreen.mainScreen.scale, 0.001);
    XCTAssertNotNil(view.layer.contents, @"%@ has no drawn backing store", view.class);
    if ([view isKindOfClass:NSClassFromString(@"RNTextEngineAttributedTextDisplayView")]) {
      NSAttributedString *text = [view valueForKey:@"attributedText"];
      XCTAssertEqualObjects(text.string, expectedText);
    }
    count += 1;
  }
  for (UIView *child in view.subviews) count += ValidateDrawingLeaf(child, expectedText);
  return count;
}

static void MountAndDrawTree(const RootShadowNode &root, Implementation implementation, CGContextRef validationContext = nullptr,
    const std::vector<std::string> &expectedTexts = {})
{
  @autoreleasepool {
    RCTViewComponentView *parent = [RCTViewComponentView new];
    Class componentClass = implementation == Implementation::RNText ? RCTParagraphComponentView.class
        : NSClassFromString(implementation == Implementation::TextView
            ? @"RNTextEngineTextViewComponentView" : @"RNTextEnginePreparedTextViewComponentView");
    size_t index = 0;
    for (const auto &child : root.getChildren()) {
      const auto &node = static_cast<const LayoutableShadowNode &>(*child);
      UIView<RCTComponentViewProtocol> *view = [componentClass new];
      view.tag = node.getTag();
      [view updateProps:node.getProps() oldProps:nullptr];
      [view updateEventEmitter:node.getEventEmitter()];
      [view updateState:node.getState() oldState:nullptr];
      [view updateLayoutMetrics:node.getLayoutMetrics() oldLayoutMetrics:EmptyLayoutMetrics];
      [view finalizeUpdates:RNComponentViewUpdateMaskAll];
      [parent mountChildComponentView:view index:0];
      [view layoutIfNeeded];
      DisplayLayers(view.layer);
      if (validationContext != nullptr) {
        NSString *expectedText = ToNSString(expectedTexts.at(index));
        XCTAssertEqual(ValidateDrawingLeaf(view, expectedText), 1u);
        if (implementation == Implementation::RNText) XCTAssertEqualObjects(((RCTParagraphComponentView *)view).attributedText.string, expectedText);
        XCTAssertGreaterThan(view.bounds.size.width, 0);
        XCTAssertGreaterThan(view.bounds.size.height, 0);
        XCTAssertLessThanOrEqual(view.bounds.size.height, 320);
        CGContextClearRect(validationContext, CGRectMake(0, 0, 320, 320));
        [view.layer renderInContext:validationContext];
        const uint8_t *data = static_cast<const uint8_t *>(CGBitmapContextGetData(validationContext));
        size_t stride = CGBitmapContextGetBytesPerRow(validationContext);
        size_t bytes = stride * CGBitmapContextGetHeight(validationContext);
        CGRect expectedBounds = CGRectInset(CGContextConvertRectToDeviceSpace(validationContext, view.bounds), -1, -1);
        NSUInteger inkCount = 0;
        BOOL inkFits = YES;
        for (size_t index = 3; index < bytes; index += 4) {
          if (data[index] == 0) continue;
          inkCount += 1;
          inkFits &= CGRectContainsPoint(expectedBounds, CGPointMake((index % stride) / 4, index / stride));
        }
        XCTAssertGreaterThan(inkCount, 0u, @"Mounted text did not draw");
        XCTAssertLessThan(inkCount, CGRectGetWidth(expectedBounds) * CGRectGetHeight(expectedBounds));
        XCTAssertTrue(inkFits, @"Mounted text exceeds measured bounds");
      }
      [parent unmountChildComponentView:view index:0];
      ++index;
    }
  }
  // Offscreen layers retain backing stores until their Core Animation transaction commits.
  [CATransaction flush];
}

#endif

} // namespace

@interface RNTextEngineTextViewComparisonBenchmarks : XCTestCase
@end

@implementation RNTextEngineTextViewComparisonBenchmarks {
#ifdef RCT_NEW_ARCH_ENABLED
  NSArray<NSString *> *_chatTexts;
  NSString *_richText;
  NSArray<NSNumber *> *_runEnds;
  NSArray<NSString *> *_runFontStyles;
  NSArray<NSNumber *> *_runFontSizes;
  NSArray<NSString *> *_runFontWeights;
  NSArray<NSNumber *> *_runLetterSpacings;
  NSArray<NSNumber *> *_runLineHeights;
  NSArray<NSNumber *> *_runStarts;
  NSArray<NSNumber *> *_runStyleMasks;
  NSArray<NSNumber *> *_runTabularNumbers;
  NSArray<NSString *> *_richTexts;
  std::vector<RunFixture> _richRuns;
  std::vector<std::string> _chatStdTexts;
  std::vector<std::string> _richStdTexts;
#endif
}

- (void)setUp
{
  [super setUp];

#ifdef RCT_NEW_ARCH_ENABLED
  NSArray<NSString *> *fragments = @[
    @"The renderer should know the bubble height before the row mounts.",
    @"Prepared text keeps width work separate from shaping work in a virtualized list.",
    @"Inline emphasis, tabular numbers, and quoted citations still need exact native metrics.",
    @"Worklet-driven layout needs stable widths, line counts, and last-line geometry to stay smooth.",
    @"A text surface should update content without rebuilding unrelated host objects.",
  ];

  NSMutableArray<NSString *> *texts = [NSMutableArray arrayWithCapacity:128];
  for (NSUInteger index = 0; index < 128; index += 1) {
    NSString *first = fragments[index % fragments.count];
    NSString *second = fragments[(index + 2) % fragments.count];
    NSString *third = fragments[(index + 4) % fragments.count];
    [texts addObject:[NSString stringWithFormat:@"Message %lu. %@ %@ %@", (unsigned long)(index + 1), first, second, third]];
  }

  _chatTexts = texts;
  _chatStdTexts.reserve(_chatTexts.count);
  for (NSString *text in _chatTexts) {
    _chatStdTexts.emplace_back(text.UTF8String ?: "");
  }

  _richText = @"Prepared text performance should cover inline emphasis, quoted insertions, editorial spans, tabular 1234567890, and a final weighted phrase while preserving one coherent source string.";
  NSMutableArray<NSString *> *richTexts = [NSMutableArray arrayWithCapacity:96];
  _richStdTexts.reserve(96);
  for (NSUInteger index = 0; index < 96; index += 1) {
    NSString *text = [_richText stringByAppendingFormat:@" Case %03lu.", (unsigned long)(index + 1)];
    [richTexts addObject:text];
    _richStdTexts.emplace_back(text.UTF8String ?: "");
  }
  _richTexts = richTexts;

  [self buildRichRuns];
#endif
}

- (void)buildRichRuns
{
#ifdef RCT_NEW_ARCH_ENABLED
  auto addRun = [&](NSString *needle, NSInteger styleMask, TextStyleFixture style) {
    NSRange range = [_richText rangeOfString:needle];
    XCTAssertNotEqual(range.location, NSNotFound);
    _richRuns.push_back({
        .start = static_cast<NSInteger>(range.location),
        .end = static_cast<NSInteger>(range.location + range.length),
        .styleMask = styleMask,
        .style = std::move(style),
    });
  };

  addRun(@"inline emphasis", kRunStyleHasFontWeight, {.fontWeight = "700"});
  addRun(@"quoted insertions", kRunStyleHasFontStyle, {.fontStyle = "italic"});
  // Keep paragraph line height uniform: RN and TextView differ for per-run heights.
  addRun(@"editorial spans", kRunStyleHasFontSize, {.fontSize = 20});
  addRun(@"tabular 1234567890", kRunStyleHasTabularNumbers | kRunStyleHasLetterSpacing, {.letterSpacing = 0.12, .tabularNumbers = true});
  addRun(@"final weighted phrase", kRunStyleHasFontWeight | kRunStyleHasFontSize, {.fontSize = 19, .fontWeight = "600"});

  std::sort(_richRuns.begin(), _richRuns.end(), [](const RunFixture &left, const RunFixture &right) {
    return left.start < right.start;
  });

  _runStarts = NumbersFromRuns(_richRuns, ^NSInteger(const RunFixture &run) {
    return run.start;
  });
  _runEnds = NumbersFromRuns(_richRuns, ^NSInteger(const RunFixture &run) {
    return run.end;
  });
  _runStyleMasks = NumbersFromRuns(_richRuns, ^NSInteger(const RunFixture &run) {
    return run.styleMask;
  });
  _runFontStyles = StringValuesFromRuns(_richRuns, ^NSString *(const RunFixture &run) {
    return ToNSString(run.style.fontStyle);
  });
  _runFontWeights = StringValuesFromRuns(_richRuns, ^NSString *(const RunFixture &run) {
    return ToNSString(run.style.fontWeight);
  });
  _runFontSizes = DoubleValuesFromRuns(_richRuns, ^double(const RunFixture &run) {
    return run.style.fontSize;
  });
  _runLetterSpacings = DoubleValuesFromRuns(_richRuns, ^double(const RunFixture &run) {
    return run.style.letterSpacing;
  });
  _runLineHeights = DoubleValuesFromRuns(_richRuns, ^double(const RunFixture &run) {
    return run.style.lineHeight;
  });
  _runTabularNumbers = BoolValuesFromRuns(_richRuns, ^BOOL(const RunFixture &run) {
    return run.style.tabularNumbers;
  });
#endif
}

#ifdef RCT_NEW_ARCH_ENABLED

- (BOOL)validateRNSize:(CGSize)rn
         textViewSize:(CGSize)textView
                width:(double)width
              fixture:(NSString *)fixture
{
  const double tolerance = 1.0 / UIScreen.mainScreen.scale;
  bool valid = std::isfinite(rn.width) && std::isfinite(rn.height) &&
      std::isfinite(textView.width) && std::isfinite(textView.height) &&
      rn.width > 0 && textView.width > 0 && rn.height > 0 && textView.height > 0 &&
      rn.width <= width + tolerance && textView.width <= width + tolerance;
  XCTAssertTrue(valid, @"Invalid geometry for %@: RN %@, TextView %@", fixture, NSStringFromCGSize(rn), NSStringFromCGSize(textView));
  if (!valid) return false;
  // RN returns the container width for wrapped text; TextView returns used glyph width.
  bool sameHeight = std::abs(rn.height - textView.height) <= tolerance;
  XCTAssertTrue(sameHeight, @"Height mismatch for %@: RN %@, TextView %@", fixture, NSStringFromCGSize(rn), NSStringFromCGSize(textView));
  return sameHeight;
}

- (BOOL)validateLayoutsWithChatStyle:(const TextStyleFixture &)chatStyle
                          richStyle:(const TextStyleFixture &)richStyle
                             widths:(const std::vector<double> &)widths
                    preparedFixture:(const PreparedTextFixture &)preparedFixture
{
  auto contextContainer = std::make_shared<ContextContainer>();
  TextLayoutManager manager(contextContainer);
  auto context = BuildTextLayoutContext();
  for (NSUInteger index = 0; index < _chatTexts.count; index += 1) {
    NSString *text = _chatTexts[index];
    // Run offsets are shared between NSString and UTF-8 fixture fragments.
    XCTAssertTrue([text canBeConvertedToEncoding:NSASCIIStringEncoding]);
    if (![text canBeConvertedToEncoding:NSASCIIStringEncoding]) return NO;
    AttributedStringBox input{BuildRNAttributedString(_chatStdTexts[index], chatStyle, {})};
    uint64_t handle = CreateTextViewHandle(text, chatStyle, nil, nil, nil, nil, nil, nil, nil, nil, nil);
    for (NSInteger maxLines : {0, 2}) {
      for (double width : widths) {
        CGSize rn = MeasureRNTextLayout(manager, input, BuildParagraphAttributes(maxLines), context, BuildLayoutConstraints(width));
        CGSize textView = MeasureTextViewLayout(handle, width, maxLines);
        if (![self validateRNSize:rn textViewSize:textView width:width fixture:text]) {
          rntextengine::releasePreparedTextHandle(handle);
          return NO;
        }
      }
    }
    rntextengine::releasePreparedTextHandle(handle);
  }

  for (NSUInteger index = 0; index < _richTexts.count; index += 1) {
    NSString *text = _richTexts[index];
    XCTAssertTrue([text canBeConvertedToEncoding:NSASCIIStringEncoding]);
    if (![text canBeConvertedToEncoding:NSASCIIStringEncoding]) return NO;
    AttributedStringBox input{BuildRNAttributedString(_richStdTexts[index], richStyle, _richRuns)};
    uint64_t handle = CreateTextViewHandle(text, richStyle, _runStarts, _runEnds, _runStyleMasks,
        _runFontStyles, _runFontWeights, _runFontSizes, _runLetterSpacings, _runLineHeights, _runTabularNumbers);
    CGSize rn = MeasureRNTextLayout(manager, input, BuildParagraphAttributes(0), context, BuildLayoutConstraints(280));
    CGSize textView = MeasureTextViewLayout(handle, 280, 0);
    rntextengine::releasePreparedTextHandle(handle);
    if (![self validateRNSize:rn textViewSize:textView width:280 fixture:text]) return NO;
  }

  auto rnRegistry = BuildComponentDescriptorRegistry();
  auto rnRoot = BuildRNTextTree(rnRegistry, _chatStdTexts, chatStyle);
  auto textViewRegistry = BuildComponentDescriptorRegistry();
  auto textViewRoot = BuildTextViewTree(textViewRegistry, _chatStdTexts, chatStyle);
  auto preparedRegistry = BuildComponentDescriptorRegistry();
  PreparedHandles handles;
  auto preparedRoot = BuildPreparedTextViewTree(preparedRegistry, preparedFixture, handles);
  bool laidOut = rnRoot->layoutIfNeeded() && textViewRoot->layoutIfNeeded() && preparedRoot->layoutIfNeeded();
  XCTAssertTrue(laidOut);
  if (!laidOut) return NO;
  const auto &rnChildren = rnRoot->getChildren();
  const auto &textViewChildren = textViewRoot->getChildren();
  XCTAssertEqual(rnChildren.size(), _chatTexts.count);
  XCTAssertEqual(textViewChildren.size(), _chatTexts.count);
  if (rnChildren.size() != _chatTexts.count || textViewChildren.size() != _chatTexts.count) return NO;
  XCTAssertEqual(preparedRoot->getChildren().size(), _chatTexts.count);
  const double tolerance = 1.0 / UIScreen.mainScreen.scale;
  for (NSUInteger index = 0; index < _chatTexts.count; index += 1) {
    auto rn = static_cast<const ParagraphShadowNode &>(*rnChildren[index]).getLayoutMetrics().frame;
    auto textView = static_cast<const RNTextEngineTextViewShadowNode &>(*textViewChildren[index]).getLayoutMetrics().frame;
    if (![self validateRNSize:CGSizeMake(rn.size.width, rn.size.height)
                textViewSize:CGSizeMake(textView.size.width, textView.size.height)
                       width:260
                     fixture:_chatTexts[index]]) return NO;
    bool sameFrame = std::abs(rn.size.width - textView.size.width) <= tolerance &&
        std::abs(rn.origin.x - textView.origin.x) <= tolerance && std::abs(rn.origin.y - textView.origin.y) <= tolerance;
    XCTAssertTrue(sameFrame, @"Fabric frame mismatch at child %lu", (unsigned long)index);
    if (!sameFrame) return NO;
    auto prepared = static_cast<const LayoutableShadowNode &>(*preparedRoot->getChildren()[index]).getLayoutMetrics().frame;
    bool samePreparedFrame = std::abs(rn.size.width - prepared.size.width) <= tolerance &&
        std::abs(rn.size.height - prepared.size.height) <= tolerance &&
        std::abs(rn.origin.x - prepared.origin.x) <= tolerance && std::abs(rn.origin.y - prepared.origin.y) <= tolerance;
    XCTAssertTrue(samePreparedFrame, @"PreparedTextView frame mismatch at child %lu", (unsigned long)index);
    if (!samePreparedFrame) return NO;
  }
  return YES;
}

- (void)emitMeta
{
  UIDevice *device = UIDevice.currentDevice;
  NSDictionary *environment = NSProcessInfo.processInfo.environment;
#if TARGET_OS_SIMULATOR
  NSString *deviceName = device.name;
#else
  struct utsname systemInfo = {};
  XCTAssertEqual(uname(&systemInfo), 0);
  NSString *deviceName = [NSString stringWithUTF8String:systemInfo.machine];
#endif
  NSDictionary *payload = @{
    @"deviceName" : deviceName ?: @"unknown",
    @"osVersion" : device.systemVersion ?: @"unknown",
    @"sdk" : [[NSBundle bundleForClass:self.class] objectForInfoDictionaryKey:@"DTSDKName"] ?: @"unknown",
#ifdef DEBUG
    @"configuration" : @"Debug",
#else
    @"configuration" : @"Release",
#endif
    @"run" : @([environment[@"RNTE_BENCHMARK_RUN"] integerValue]),
    @"pid" : @(NSProcessInfo.processInfo.processIdentifier),
    @"geometryValidated" : @YES,
    @"warmups" : @2,
    @"samples" : @9,
    @"includesAutoreleasePoolDrain" : @YES,
    @"host" : @"native-only",
  };
  [self emitMarker:@"RNTEXT_BENCHMARK_META" payload:payload];
}

- (void)emitMarker:(NSString *)marker payload:(NSDictionary *)payload
{
  NSError *error = nil;
  NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
  XCTAssertNil(error);
  NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  printf("%s %s\n", marker.UTF8String, json.UTF8String);
}

- (void)emitResult:(NSString *)scenario
    implementation:(NSString *)implementation
        operations:(NSInteger)operations
           samples:(const std::vector<double> &)values
{
  NSMutableArray<NSNumber *> *samples = [NSMutableArray arrayWithCapacity:values.size()];
  for (double sample : values) [samples addObject:@(sample)];
  [self emitMarker:@"RNTEXT_BENCHMARK_RESULT" payload:@{
    @"scenario" : scenario,
    @"implementation" : implementation,
    @"operations" : @(operations),
    @"samplesMs" : samples,
  }];
}

- (void)benchmark:(NSString *)scenario
      operations:(NSInteger)operations
     repetitions:(NSInteger)repetitions
              rn:(dispatch_block_t)rn
        textView:(dispatch_block_t)textView
preparedTextView:(dispatch_block_t)preparedTextView
{
  NSInteger run = [NSProcessInfo.processInfo.environment[@"RNTE_BENCHMARK_RUN"] integerValue];
  NSArray<dispatch_block_t> *blocks = preparedTextView ? @[rn, textView, preparedTextView] : @[rn, textView];
  NSArray<NSString *> *names = @[@"RN Text", @"TextView", @"PreparedTextView"];
  auto samples = MeasureImplementations(blocks, repetitions, run);
  for (NSUInteger index = 0; index < blocks.count; ++index) {
    [self emitResult:scenario implementation:names[index] operations:operations * repetitions samples:samples[index]];
  }
}

#endif

- (void)testTextViewComparisonBenchmarks
{
  XCTSkipIf(![NSProcessInfo.processInfo.environment[@"RNTE_BENCHMARK"] isEqualToString:@"1"],
      @"Run this opt-in benchmark with yarn perf:compare:ios.");
#ifndef RCT_NEW_ARCH_ENABLED
  XCTFail(@"The iOS text benchmark requires RCT_NEW_ARCH_ENABLED/Fabric.");
#else
  const TextStyleFixture chatStyle = {
      .fontSize = 17,
      .letterSpacing = 0.1,
      .lineHeight = 24,
      .tabularNumbers = false,
      .fontStyle = "",
      .fontWeight = "500",
  };
  const TextStyleFixture richStyle = {
      .fontSize = 18,
      .letterSpacing = 0.05,
      .lineHeight = 26,
      .tabularNumbers = false,
      .fontStyle = "",
      .fontWeight = "400",
  };
  const std::vector<double> widths = {260, 220, 300, 240, 280, 200};
  auto runtimeOwner = facebook::hermes::makeHermesRuntime();
  auto *runtime = runtimeOwner.get();
  rntextengine::install(*runtime);
  PreparedTextFixture preparedInputs(*runtime, _chatStdTexts, chatStyle);
  const auto *preparedFixture = &preparedInputs;
  if (![self validateLayoutsWithChatStyle:chatStyle richStyle:richStyle widths:widths preparedFixture:*preparedFixture]) return;
  const TextStyleFixture labelStyle = {.fontSize = 17};
  NSArray<NSString *> *labelPrefixes = @[@"OK", @"Done 🙂", @"日本語", @"বাংলা"];
  NSMutableArray<NSString *> *labelTexts = [NSMutableArray arrayWithCapacity:128];
  std::vector<std::string> labelStdTexts;
  for (NSUInteger index = 0; index < 128; ++index) {
    NSString *text = [NSString stringWithFormat:@"%@ %lu", labelPrefixes[index % labelPrefixes.count], (unsigned long)index + 1];
    [labelTexts addObject:text];
    labelStdTexts.emplace_back(text.UTF8String);
  }
  {
    TextLayoutManager manager(std::make_shared<ContextContainer>());
    for (NSUInteger index = 0; index < labelTexts.count; ++index) {
      AttributedStringBox input{BuildRNAttributedString(labelStdTexts[index], labelStyle, {})};
      uint64_t handle = CreateTextViewHandle(labelTexts[index], labelStyle, nil, nil, nil, nil, nil, nil, nil, nil, nil);
      for (double width : {96, 160}) {
        CGSize rn = MeasureRNTextLayout(manager, input, BuildParagraphAttributes(0), BuildTextLayoutContext(), BuildLayoutConstraints(width));
        CGSize textView = MeasureTextViewLayout(handle, width, 0);
        if (![self validateRNSize:rn textViewSize:textView width:width fixture:labelTexts[index]]) {
          rntextengine::releasePreparedTextHandle(handle);
          return;
        }
      }
      rntextengine::releasePreparedTextHandle(handle);
    }
  }
  [self emitMeta];

  NSArray<NSString *> *chatTexts = _chatTexts;
  NSArray<NSString *> *richTexts = _richTexts;
  NSArray<NSNumber *> *runEnds = _runEnds;
  NSArray<NSString *> *runFontStyles = _runFontStyles;
  NSArray<NSNumber *> *runFontSizes = _runFontSizes;
  NSArray<NSString *> *runFontWeights = _runFontWeights;
  NSArray<NSNumber *> *runLetterSpacings = _runLetterSpacings;
  NSArray<NSNumber *> *runLineHeights = _runLineHeights;
  NSArray<NSNumber *> *runStarts = _runStarts;
  NSArray<NSNumber *> *runStyleMasks = _runStyleMasks;
  NSArray<NSNumber *> *runTabularNumbers = _runTabularNumbers;
  const auto *chatStdTexts = &_chatStdTexts;
  const auto *richRuns = &_richRuns;
  const auto *richStdTexts = &_richStdTexts;

  [self benchmark:@"fabric_chat_shadow_tree_layout"
      operations:chatTexts.count
     repetitions:4
              rn:^{
                 auto registry = BuildComponentDescriptorRegistry();
                 auto root = BuildRNTextTree(registry, *chatStdTexts, chatStyle);
                 RNTextBenchmarkSink += root->layoutIfNeeded() ? 1 : 0;
               }
        textView:^{
                 auto registry = BuildComponentDescriptorRegistry();
                 auto root = BuildTextViewTree(registry, *chatStdTexts, chatStyle);
                 RNTextBenchmarkSink += root->layoutIfNeeded() ? 1 : 0;
               }
preparedTextView:^{
                 auto registry = BuildComponentDescriptorRegistry();
                 PreparedHandles handles;
                 auto root = BuildPreparedTextViewTree(registry, *preparedFixture, handles);
                 RNTextBenchmarkSink += root->layoutIfNeeded() ? 1 : 0;
               }];

  dispatch_block_t firstDraw = ^{
    CGFloat scale = UIScreen.mainScreen.scale;
    size_t pixels = static_cast<size_t>(320 * scale);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(nullptr, pixels, pixels, 8, pixels * 4, colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    XCTAssertNotEqual(context, nullptr);
    if (context == nullptr) return;
    CGContextTranslateCTM(context, 0, pixels);
    CGContextScaleCTM(context, scale, -scale);
    for (BOOL textView : {NO, YES}) {
      auto registry = BuildComponentDescriptorRegistry();
      auto root = textView ? BuildTextViewTree(registry, *chatStdTexts, chatStyle)
                           : BuildRNTextTree(registry, *chatStdTexts, chatStyle);
      XCTAssertTrue(root->layoutIfNeeded());
      MountAndDrawTree(*root, textView ? Implementation::TextView : Implementation::RNText, context, *chatStdTexts);
    }
    {
      auto registry = BuildComponentDescriptorRegistry();
      PreparedHandles handles;
      auto root = BuildPreparedTextViewTree(registry, *preparedFixture, handles);
      XCTAssertTrue(root->layoutIfNeeded());
      MountAndDrawTree(*root, Implementation::PreparedTextView, context, *chatStdTexts);
    }
    [self benchmark:@"fabric_mount_and_first_draw"
        operations:chatTexts.count
       repetitions:4
                rn:^{
                   auto registry = BuildComponentDescriptorRegistry();
                   auto root = BuildRNTextTree(registry, *chatStdTexts, chatStyle);
                   root->layoutIfNeeded();
                   MountAndDrawTree(*root, Implementation::RNText);
                 }
          textView:^{
                   auto registry = BuildComponentDescriptorRegistry();
                   auto root = BuildTextViewTree(registry, *chatStdTexts, chatStyle);
                   root->layoutIfNeeded();
                   MountAndDrawTree(*root, Implementation::TextView);
                 }
preparedTextView:^{
                   auto registry = BuildComponentDescriptorRegistry();
                   PreparedHandles handles;
                   auto root = BuildPreparedTextViewTree(registry, *preparedFixture, handles);
                   root->layoutIfNeeded();
                   MountAndDrawTree(*root, Implementation::PreparedTextView);
                 }];
    CGContextRelease(context);
  };
  if (NSThread.isMainThread) firstDraw();
  else dispatch_sync(dispatch_get_main_queue(), firstDraw);

  @autoreleasepool {
    auto retainedRNRegistry = BuildComponentDescriptorRegistry();
    auto retainedRNRoot = BuildRNTextTree(retainedRNRegistry, *chatStdTexts, chatStyle);
    auto retainedTextViewRegistry = BuildComponentDescriptorRegistry();
    auto retainedTextViewRoot = BuildTextViewTree(retainedTextViewRegistry, *chatStdTexts, chatStyle);
    XCTAssertTrue(retainedRNRoot->layoutIfNeeded());
    XCTAssertTrue(retainedTextViewRoot->layoutIfNeeded());
    auto retainedContext = BuildFabricLayoutContext();
    auto retainedConstraints = BuildLayoutConstraints(260);
    retainedConstraints.minimumSize.width = 260;
    [self benchmark:@"retained_paragraph_measurement"
        operations:chatTexts.count
       repetitions:128
                rn:^{
                   for (const auto &child : retainedRNRoot->getChildren()) {
                     auto size = static_cast<const ParagraphShadowNode &>(*child).measureContent(
                         retainedContext, retainedConstraints);
                     RNTextBenchmarkSink += size.height;
                   }
                 }
          textView:^{
                   for (const auto &child : retainedTextViewRoot->getChildren()) {
                     auto size = static_cast<const RNTextEngineTextViewShadowNode &>(*child).measureContent(
                         retainedContext, retainedConstraints);
                     RNTextBenchmarkSink += size.height;
                   }
                 } preparedTextView:nil];
  }

  [self benchmark:@"cold_uniform_chat_layout"
      operations:chatTexts.count
     repetitions:4
              rn:^{
                 auto contextContainer = std::make_shared<ContextContainer>();
                 TextLayoutManager manager(contextContainer);
                 auto context = BuildTextLayoutContext();
                 auto paragraph = BuildParagraphAttributes(0);
                 auto constraints = BuildLayoutConstraints(260);
                 for (const auto &text : *chatStdTexts) {
                   auto attributedString = BuildRNAttributedString(text, chatStyle, {});
                   MeasureRNTextLayout(manager, AttributedStringBox{attributedString}, paragraph, context, constraints);
                 }
               }
        textView:^{
                 for (NSString *text in chatTexts) {
                   uint64_t handle = CreateTextViewHandle(text, chatStyle, nil, nil, nil, nil, nil, nil, nil, nil, nil);
                   MeasureTextViewLayout(handle, 260, 0);
                   rntextengine::releasePreparedTextHandle(handle);
                 }
               } preparedTextView:nil];

  [self benchmark:@"cold_short_label_layout"
      operations:labelTexts.count
     repetitions:4
              rn:^{
                 TextLayoutManager manager(std::make_shared<ContextContainer>());
                 for (const auto &text : labelStdTexts) {
                   AttributedStringBox input{BuildRNAttributedString(text, labelStyle, {})};
                   MeasureRNTextLayout(manager, input, BuildParagraphAttributes(0), BuildTextLayoutContext(), BuildLayoutConstraints(160));
                 }
               }
        textView:^{
                 for (NSString *text in labelTexts) {
                   uint64_t handle = CreateTextViewHandle(text, labelStyle, nil, nil, nil, nil, nil, nil, nil, nil, nil);
                   MeasureTextViewLayout(handle, 160, 0);
                   rntextengine::releasePreparedTextHandle(handle);
                 }
               } preparedTextView:nil];

  NSMutableArray<NSNumber *> *handles = [NSMutableArray arrayWithCapacity:chatTexts.count];
  for (NSString *text in chatTexts) {
    [handles addObject:@(CreateTextViewHandle(text, chatStyle, nil, nil, nil, nil, nil, nil, nil, nil, nil))];
  }

  std::vector<AttributedStringBox> rnInputs;
  rnInputs.reserve(chatStdTexts->size());
  for (const auto &text : *chatStdTexts) {
    rnInputs.emplace_back(BuildRNAttributedString(text, chatStyle, {}));
  }

  auto warmUniformContextContainer = std::make_shared<ContextContainer>();
  auto warmUniformManager = std::make_shared<TextLayoutManager>(warmUniformContextContainer);
  [self benchmark:@"cached_uniform_layout_queries"
      operations:chatTexts.count * widths.size()
     repetitions:128
              rn:^{
                 auto context = BuildTextLayoutContext();
                 auto paragraph = BuildParagraphAttributes(0);
                 for (double width : widths) {
                   auto constraints = BuildLayoutConstraints(width);
                   for (const auto &input : rnInputs) {
                     MeasureRNTextLayout(*warmUniformManager, input, paragraph, context, constraints);
                   }
                 }
               }
        textView:^{
                 for (double width : widths) {
                   for (NSNumber *handle in handles) {
                     MeasureTextViewLayout(handle.unsignedLongLongValue, width, 0);
                   }
                 }
               } preparedTextView:nil];

  auto warmTruncatedContextContainer = std::make_shared<ContextContainer>();
  auto warmTruncatedManager = std::make_shared<TextLayoutManager>(warmTruncatedContextContainer);
  [self benchmark:@"cached_truncated_layout_queries"
      operations:chatTexts.count * widths.size()
     repetitions:128
              rn:^{
                 auto context = BuildTextLayoutContext();
                 auto paragraph = BuildParagraphAttributes(2);
                 for (double width : widths) {
                   auto constraints = BuildLayoutConstraints(width);
                   for (const auto &input : rnInputs) {
                     MeasureRNTextLayout(*warmTruncatedManager, input, paragraph, context, constraints);
                   }
                 }
               }
        textView:^{
                 for (double width : widths) {
                   for (NSNumber *handle in handles) {
                     MeasureTextViewLayout(handle.unsignedLongLongValue, width, 2);
                   }
                 }
               } preparedTextView:nil];

  for (NSNumber *handle in handles) {
    rntextengine::releasePreparedTextHandle(handle.unsignedLongLongValue);
  }

  [self benchmark:@"cold_rich_inline_layout"
      operations:richTexts.count
     repetitions:4
              rn:^{
                 auto contextContainer = std::make_shared<ContextContainer>();
                 TextLayoutManager manager(contextContainer);
                 auto context = BuildTextLayoutContext();
                 auto paragraph = BuildParagraphAttributes(0);
                 auto constraints = BuildLayoutConstraints(280);
                 for (const auto &text : *richStdTexts) {
                   auto attributedString = BuildRNAttributedString(text, richStyle, *richRuns);
                   MeasureRNTextLayout(manager, AttributedStringBox{attributedString}, paragraph, context, constraints);
                 }
               }
        textView:^{
                 for (NSString *text in richTexts) {
                   uint64_t handle = CreateTextViewHandle(
                       text,
                       richStyle,
                       runStarts,
                       runEnds,
                       runStyleMasks,
                       runFontStyles,
                       runFontWeights,
                       runFontSizes,
                       runLetterSpacings,
                       runLineHeights,
                       runTabularNumbers);
                   MeasureTextViewLayout(handle, 280, 0);
                   rntextengine::releasePreparedTextHandle(handle);
                 }
               } preparedTextView:nil];

  const double sink = RNTextBenchmarkSink;
  XCTAssertTrue(std::isfinite(sink));
  XCTAssertGreaterThan(sink, 0);
#endif
}

@end
