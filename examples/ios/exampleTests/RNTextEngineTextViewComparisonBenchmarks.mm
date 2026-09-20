#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import "../../../ios/RNTextEngineBindings.h"
#import "../../../ios/RNTextEngineTextViewShadowNode.h"

#import <react/renderer/attributedstring/AttributedString.h>
#import <react/renderer/attributedstring/AttributedStringBox.h>
#import <react/renderer/attributedstring/ParagraphAttributes.h>
#import <react/renderer/componentregistry/ComponentDescriptorProviderRegistry.h>
#import <react/renderer/componentregistry/ComponentDescriptorRegistry.h>
#import <react/renderer/components/root/RootComponentDescriptor.h>
#import <react/renderer/components/root/RootShadowNode.h>
#import <react/renderer/components/text/ParagraphComponentDescriptor.h>
#import <react/renderer/components/text/ParagraphProps.h>
#import <react/renderer/components/text/ParagraphShadowNode.h>
#import <react/renderer/components/text/RawTextComponentDescriptor.h>
#import <react/renderer/components/text/RawTextShadowNode.h>
#import <react/renderer/components/text/TextComponentDescriptor.h>
#import <react/renderer/components/view/ViewComponentDescriptor.h>
#import <react/renderer/core/LayoutConstraints.h>
#import <react/renderer/element/Element.h>
#import <react/renderer/textlayoutmanager/TextLayoutContext.h>
#import <react/renderer/textlayoutmanager/TextLayoutManager.h>
#import <react/utils/ContextContainer.h>

#include <algorithm>
#include <atomic>
#include <cmath>
#include <limits>
#include <optional>
#include <string>
#include <sys/utsname.h>
#include <thread>
#include <vector>

using namespace facebook;
using namespace facebook::react;
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

struct TextStyleFixture {
  double fontSize{17};
  double letterSpacing{0};
  double lineHeight{0};
  bool tabularNumbers{false};
  std::string fontStyle{};
  std::string fontWeight{"400"};
};

struct RunFixture {
  NSInteger start{0};
  NSInteger end{0};
  NSInteger styleMask{0};
  TextStyleFixture style{};
};

struct BenchmarkSamples {
  std::vector<double> rn;
  std::vector<double> textView;
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

static LayoutConstraints BuildLayoutConstraints(double width)
{
  return LayoutConstraints{
      .minimumSize = {.width = 0, .height = 0},
      .maximumSize = {.width = static_cast<Float>(width), .height = std::numeric_limits<Float>::infinity()},
      .layoutDirection = LayoutDirection::LeftToRight,
  };
}

static TextLayoutContext BuildTextLayoutContext()
{
  return TextLayoutContext{
      .pointScaleFactor = static_cast<Float>(UIScreen.mainScreen.scale),
      .surfaceId = 1,
  };
}

static LayoutContext BuildFabricLayoutContext()
{
  return LayoutContext{
      .pointScaleFactor = static_cast<Float>(UIScreen.mainScreen.scale),
      .affectedNodes = nullptr,
      .swapLeftAndRightInRTL = false,
      .fontSizeMultiplier = 1.0,
      .viewportOffset = {},
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

static BenchmarkSamples MeasurePair(dispatch_block_t rn, dispatch_block_t textView, NSInteger repetitions, NSInteger run)
{
  constexpr NSInteger warmups = 2;
  constexpr NSInteger samples = 9;
  BenchmarkSamples result;
  result.rn.reserve(samples);
  result.textView.reserve(samples);

  for (NSInteger index = -warmups; index < samples; index += 1) {
    double rnMs;
    double textViewMs;
    if ((index + warmups + run - 1) % 2 == 0) {
      rnMs = MeasureBlock(rn, repetitions);
      textViewMs = MeasureBlock(textView, repetitions);
    } else {
      textViewMs = MeasureBlock(textView, repetitions);
      rnMs = MeasureBlock(rn, repetitions);
    }
    if (index >= 0) {
      result.rn.push_back(rnMs);
      result.textView.push_back(textViewMs);
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
  return rntextengine::createPreparedTextHandleForTextView(
      text,
      NO,
      nil,
      style.fontSize,
      ToNSString(style.fontWeight),
      ToNSString(style.fontStyle),
      style.letterSpacing,
      style.lineHeight,
      style.tabularNumbers,
      nil,
      runStarts,
      runEnds,
      runStyleMasks,
      nil,
      runFontSizes,
      runFontStyles,
      runFontWeights,
      runLetterSpacings,
      runLineHeights,
      runTabularNumbers);
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

static ComponentDescriptorRegistry::Shared BuildBenchmarkComponentDescriptorRegistry()
{
  auto contextContainer = std::make_shared<ContextContainer>();
  contextContainer->insert<std::shared_ptr<TextLayoutManager>>(
      TextLayoutManagerKey,
      std::make_shared<TextLayoutManager>(contextContainer));

  ComponentDescriptorProviderRegistry providerRegistry;
  providerRegistry.add(concreteComponentDescriptorProvider<RootComponentDescriptor>());
  providerRegistry.add(concreteComponentDescriptorProvider<ViewComponentDescriptor>());
  providerRegistry.add(concreteComponentDescriptorProvider<ParagraphComponentDescriptor>());
  providerRegistry.add(concreteComponentDescriptorProvider<TextComponentDescriptor>());
  providerRegistry.add(concreteComponentDescriptorProvider<RawTextComponentDescriptor>());
  providerRegistry.add(concreteComponentDescriptorProvider<RNTextEngineTextViewComponentDescriptor>());

  auto descriptorRegistry = providerRegistry.createComponentDescriptorRegistry(ComponentDescriptorParameters{
      .eventDispatcher = {},
      .contextContainer = std::move(contextContainer),
      .flavor = nullptr,
  });

  return descriptorRegistry;
}

static std::shared_ptr<ShadowNode> BuildBenchmarkShadowNode(
    const ComponentDescriptorRegistry::Shared &registry,
    const ElementFragment &fragment)
{
  const auto &componentDescriptor = registry->at(fragment.componentHandle);

  auto children = std::vector<std::shared_ptr<const ShadowNode>>{};
  children.reserve(fragment.children.size());
  for (const auto &child : fragment.children) {
    children.push_back(BuildBenchmarkShadowNode(registry, child));
  }

  auto family = componentDescriptor.createFamily(ShadowNodeFamilyFragment{
      .tag = fragment.tag,
      .surfaceId = fragment.surfaceId,
      .instanceHandle = nullptr,
  });
  auto initialState = componentDescriptor.createInitialState(fragment.props, family);
  auto node = componentDescriptor.createShadowNode(
      ShadowNodeFragment{
          .props = fragment.props,
          .children = std::make_shared<const std::vector<std::shared_ptr<const ShadowNode>>>(std::move(children)),
          .state = initialState,
      },
      family);
  auto mutableNode = std::const_pointer_cast<ShadowNode>(node);

  if (fragment.referenceCallback) fragment.referenceCallback(mutableNode);
  if (fragment.finalizeCallback) fragment.finalizeCallback(*mutableNode);

  return mutableNode;
}

template <typename ShadowNodeT>
static std::shared_ptr<ShadowNodeT> BuildBenchmarkShadowNode(
    const ComponentDescriptorRegistry::Shared &registry,
    Element<ShadowNodeT> element)
{
  return std::static_pointer_cast<ShadowNodeT>(
      BuildBenchmarkShadowNode(registry, static_cast<ElementFragment>(element)));
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

static std::shared_ptr<RNTextEngineTextViewProps> BuildTextViewProps(
    const std::string &text,
    const TextStyleFixture &style,
    double width)
{
  auto props = std::make_shared<RNTextEngineTextViewProps>();
  props->allowFontScaling = false;
  props->anchorToCapHeight = false;
  props->fontSize = style.fontSize;
  props->fontStyle = style.fontStyle;
  props->fontWeight = style.fontWeight;
  props->letterSpacing = style.letterSpacing;
  props->lineHeight = style.lineHeight;
  props->rnteHasAllowFontScaling = true;
  props->rnteHasLetterSpacing = true;
  props->rnteHasTabularNumbers = true;
  props->tabularNumbers = style.tabularNumbers;
  props->text = text;
  props->yogaStyle.setDimension(yoga::Dimension::Width, yoga::StyleSizeLength::points(static_cast<float>(width)));
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
  return BuildBenchmarkShadowNode(registry, Element<RootShadowNode>()
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
  return BuildBenchmarkShadowNode(registry, Element<RootShadowNode>()
      .surfaceId(1).tag(1).props(BuildRootProps(320)).children(std::move(children)));
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

- (BOOL)validateLayoutsWithChatStyle:(const TextStyleFixture &)chatStyle
                          richStyle:(const TextStyleFixture &)richStyle
                             widths:(const std::vector<double> &)widths
{
  const double tolerance = 1.0 / UIScreen.mainScreen.scale;
  auto check = [&](CGSize rn, CGSize textView, double width, NSString *fixture) {
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
  };

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
        if (!check(rn, textView, width, text)) {
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
    if (!check(rn, textView, 280, text)) return NO;
  }

  auto rnRegistry = BuildBenchmarkComponentDescriptorRegistry();
  auto rnRoot = BuildRNTextTree(rnRegistry, _chatStdTexts, chatStyle);
  auto textViewRegistry = BuildBenchmarkComponentDescriptorRegistry();
  auto textViewRoot = BuildTextViewTree(textViewRegistry, _chatStdTexts, chatStyle);
  bool laidOut = rnRoot->layoutIfNeeded() && textViewRoot->layoutIfNeeded();
  XCTAssertTrue(laidOut);
  if (!laidOut) return NO;
  const auto &rnChildren = rnRoot->getChildren();
  const auto &textViewChildren = textViewRoot->getChildren();
  XCTAssertEqual(rnChildren.size(), _chatTexts.count);
  XCTAssertEqual(textViewChildren.size(), _chatTexts.count);
  if (rnChildren.size() != _chatTexts.count || textViewChildren.size() != _chatTexts.count) return NO;
  for (NSUInteger index = 0; index < _chatTexts.count; index += 1) {
    auto rn = static_cast<const ParagraphShadowNode &>(*rnChildren[index]).getLayoutMetrics().frame;
    auto textView = static_cast<const RNTextEngineTextViewShadowNode &>(*textViewChildren[index]).getLayoutMetrics().frame;
    if (!check(CGSizeMake(rn.size.width, rn.size.height), CGSizeMake(textView.size.width, textView.size.height), 260, _chatTexts[index])) return NO;
    bool sameFrame = std::abs(rn.size.width - textView.size.width) <= tolerance &&
        std::abs(rn.origin.x - textView.origin.x) <= tolerance && std::abs(rn.origin.y - textView.origin.y) <= tolerance;
    XCTAssertTrue(sameFrame, @"Fabric frame mismatch at child %lu", (unsigned long)index);
    if (!sameFrame) return NO;
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
{
  NSInteger run = [NSProcessInfo.processInfo.environment[@"RNTE_BENCHMARK_RUN"] integerValue];
  auto samples = MeasurePair(rn, textView, repetitions, run);
  [self emitResult:scenario implementation:@"RN Text" operations:operations * repetitions samples:samples.rn];
  [self emitResult:scenario implementation:@"TextView" operations:operations * repetitions samples:samples.textView];
}

#endif

- (void)testTextViewMeasurementCacheDistinguishesAdjacentWidths
{
#ifdef RCT_NEW_ARCH_ENABLED
  auto registry = BuildBenchmarkComponentDescriptorRegistry();
  const auto context = BuildFabricLayoutContext();
  const auto makeNode = [&] {
    return BuildBenchmarkShadowNode(registry, Element<RNTextEngineTextViewShadowNode>()
        .props(BuildTextViewProps("Word word word word word word word word", {.fontSize = 17, .lineHeight = 24}, 160)));
  };
  const auto heightAt = [&](Float width) {
    return makeNode()->measureContent(context, BuildLayoutConstraints(width)).height;
  };
  Float low = 20;
  Float high = 160;
  const Float lowerHeight = heightAt(low);
  XCTAssertNotEqual(lowerHeight, heightAt(high));
  while (std::nextafter(low, high) < high) {
    const Float midpoint = low + (high - low) / 2;
    if (heightAt(midpoint) == lowerHeight) low = midpoint;
    else high = midpoint;
  }
  XCTAssertLessThan(high - low, 0.005);
  XCTAssertNotEqual(heightAt(low), heightAt(high));
  for (bool reverse : {false, true}) {
    auto retained = makeNode();
    for (Float width : {reverse ? high : low, reverse ? low : high}) {
      const auto expected = makeNode()->measureContent(context, BuildLayoutConstraints(width));
      const auto actual = retained->measureContent(context, BuildLayoutConstraints(width));
      XCTAssertEqual(actual.height, expected.height, @"width=%.9g reverse=%d", width, reverse);
    }
  }
#endif
}

- (void)testConcurrentTextViewMeasurements
{
#ifdef RCT_NEW_ARCH_ENABLED
  auto registry = BuildBenchmarkComponentDescriptorRegistry();
  const auto context = BuildFabricLayoutContext();
  const TextStyleFixture style{.fontSize = 17, .lineHeight = 24};
  const auto buildNode = [&](bool nested) {
    auto element = Element<RNTextEngineTextViewShadowNode>()
        .props(BuildTextViewProps(_chatStdTexts.front(), style, 260));
    if (nested) {
      element.children({Element<RNTextEngineTextViewShadowNode>()
          .props(BuildTextViewProps(" Nested emphasis with more wrapping.",
              {.fontSize = 23, .lineHeight = 29, .fontWeight = "700"}, 260))});
    }
    return BuildBenchmarkShadowNode(registry, element);
  };

  for (bool nested : {false, true}) {
    auto reference = buildNode(nested);
    std::vector<LayoutConstraints> constraints;
    std::vector<facebook::react::Size> expected;
    for (int index = 0; index < 32; ++index) {
      constraints.push_back(BuildLayoutConstraints(80 + index * 7));
      expected.push_back(reference->measureContent(context, constraints.back()));
    }
    for (bool warm : {false, true}) {
      auto source = buildNode(nested);
      if (warm) source->measureContent(context, constraints.front());
      source->sealRecursive();
      std::atomic<bool> start{false};
      std::atomic<bool> matches{true};
      std::vector<std::thread> workers;
      for (int worker = 0; worker < 6; ++worker) {
        workers.emplace_back([&, worker] {
          @autoreleasepool {
            while (!start.load()) std::this_thread::yield();
            for (int iteration = 0; iteration < 128; ++iteration) {
              auto clone = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(source->clone({}));
              const auto &node = worker == 0 ? source : clone;
              const auto index = (iteration * 7 + worker * 11) % constraints.size();
              if (node->measureContent(context, constraints[index]) != expected[index]) {
                matches.store(false);
              }
            }
          }
        });
      }
      start.store(true);
      for (auto &worker : workers) worker.join();
      XCTAssertTrue(matches.load(), @"Concurrent geometry differs: nested=%d warm=%d", nested, warm);
    }
  }
  auto nested = buildNode(true);
  nested->layout(context);
  XCTAssertTrue(nested->getStateData().hasNested);
  const auto nestedState = nested->getState();
  auto unchanged = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(
      nested->clone({.props = nested->getProps()}));
  unchanged->layout(context);
  XCTAssertTrue(unchanged->getState() == nestedState);
  auto flat = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(nested->clone({
      .children = std::make_shared<const std::vector<std::shared_ptr<const ShadowNode>>>()}));
  flat->layout(context);
  XCTAssertFalse(flat->getStateData().hasNested);
#endif
}

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
  if (![self validateLayoutsWithChatStyle:chatStyle richStyle:richStyle widths:widths]) return;
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
                 auto registry = BuildBenchmarkComponentDescriptorRegistry();
                 auto root = BuildRNTextTree(registry, *chatStdTexts, chatStyle);
                 RNTextBenchmarkSink += root->layoutIfNeeded() ? 1 : 0;
               }
        textView:^{
                 auto registry = BuildBenchmarkComponentDescriptorRegistry();
                 auto root = BuildTextViewTree(registry, *chatStdTexts, chatStyle);
                 RNTextBenchmarkSink += root->layoutIfNeeded() ? 1 : 0;
               }];

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
               }];

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
               }];

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
               }];

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
               }];

  const double sink = RNTextBenchmarkSink;
  XCTAssertTrue(std::isfinite(sink));
  XCTAssertGreaterThan(sink, 0);
#endif
}

@end
