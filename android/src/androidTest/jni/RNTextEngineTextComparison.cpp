#include <jni.h>
#include <fbjni/fbjni.h>
#include <react/featureflags/ReactNativeFeatureFlags.h>
#include <react/renderer/components/RNTextEngineSpec/ComponentDescriptors.h>
#include <react/renderer/components/RNTextEngineSpec/RNTextEngineTextViewShadowNode.h>
#include <react/renderer/attributedstring/AttributedString.h>
#include <react/renderer/attributedstring/AttributedStringBox.h>
#include <react/renderer/attributedstring/ParagraphAttributes.h>
#include <react/renderer/componentregistry/ComponentDescriptorProviderRegistry.h>
#include <react/renderer/componentregistry/ComponentDescriptorRegistry.h>
#include <react/renderer/components/root/RootComponentDescriptor.h>
#include <react/renderer/components/root/RootShadowNode.h>
#include <react/renderer/components/text/ParagraphComponentDescriptor.h>
#include <react/renderer/components/text/ParagraphProps.h>
#include <react/renderer/components/text/ParagraphShadowNode.h>
#include <react/renderer/components/text/RawTextComponentDescriptor.h>
#include <react/renderer/components/text/RawTextShadowNode.h>
#include <react/renderer/components/text/TextComponentDescriptor.h>
#include <react/renderer/components/view/ViewComponentDescriptor.h>
#include <react/renderer/core/LayoutConstraints.h>
#include <react/renderer/element/Element.h>
#include <react/renderer/textlayoutmanager/TextLayoutContext.h>
#include <react/renderer/textlayoutmanager/TextLayoutManager.h>
#include <react/utils/ContextContainer.h>


#include <algorithm>
#include <chrono>
#include <cmath>
#include <functional>
#include <iomanip>
#include <limits>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

using namespace facebook;
using namespace facebook::react;

namespace {
constexpr int kRunStyleHasFontSize = 1 << 2;
constexpr int kRunStyleHasFontStyle = 1 << 3;
constexpr int kRunStyleHasFontWeight = 1 << 4;
constexpr int kRunStyleHasLetterSpacing = 1 << 5;
constexpr int kRunStyleHasLineHeight = 1 << 6;
constexpr int kRunStyleHasTabularNumbers = 1 << 7;

struct TextStyleFixture {
  double fontSize{16};
  double letterSpacing{0};
  double lineHeight{24};
  bool tabularNumbers{false};
  std::string fontStyle{};
  std::string fontWeight{"400"};
};
struct RunFixture {
  int start{0};
  int end{0};
  int styleMask{0};
  TextStyleFixture style{};
};
volatile double sink = 0;
void Require(bool condition, const std::string &message) {
  if (!condition) throw std::runtime_error(message);
}
static FontWeight ResolveFontWeight(const std::string &value)
{
  if (value == "700") return FontWeight::Weight700;
  return FontWeight::Weight400;
}

static FontStyle ResolveFontStyle(const std::string &value)
{
  if (value == "italic") return FontStyle::Italic;
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

  int cursor = 0;
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

  if (cursor < static_cast<int>(text.size())) {
    AppendFragment(attributedString, text.substr(static_cast<size_t>(cursor)), baseAttributes);
  }

  return attributedString;
}

static ParagraphAttributes BuildParagraphAttributes(int maxLines)
{
  ParagraphAttributes attributes;
  attributes.maximumNumberOfLines = static_cast<int>(maxLines);
  attributes.ellipsizeMode = EllipsizeMode::Tail;
  attributes.includeFontPadding = false;
  attributes.textBreakStrategy = TextBreakStrategy::HighQuality;
  attributes.android_hyphenationFrequency = HyphenationFrequency::Normal;
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


static TextLayoutContext BuildTextLayoutContext(float density) {
  return TextLayoutContext{.pointScaleFactor = density, .surfaceId = 0};
}
static LayoutContext BuildFabricLayoutContext(float density) {
  return LayoutContext{
      .pointScaleFactor = density,
      .affectedNodes = nullptr,
      .swapLeftAndRightInRTL = false,
      .fontSizeMultiplier = 1.0,
      .viewportOffset = {},
  };
}
static ComponentDescriptorRegistry::Shared BuildBenchmarkComponentDescriptorRegistry(const jni::global_ref<jobject> &manager)
{
  auto contextContainer = std::make_shared<ContextContainer>();
  contextContainer->insert("FabricUIManager", jni::make_global(manager));

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

static std::shared_ptr<RootProps> BuildRootProps(double width, float density)
{
  auto props = std::make_shared<RootProps>();
  props->layoutConstraints = LayoutConstraints{
      .minimumSize = {.width = static_cast<Float>(width), .height = 0},
      .maximumSize = {.width = static_cast<Float>(width), .height = std::numeric_limits<Float>::infinity()},
      .layoutDirection = LayoutDirection::LeftToRight,
  };
  props->layoutContext = BuildFabricLayoutContext(density);
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
    const TextStyleFixture &style,
    float density)
{
  std::vector<ElementFragment> children;
  children.reserve(texts.size());
  for (const auto &text : texts) {
    children.push_back(Element<ParagraphShadowNode>().surfaceId(0)
        .props(BuildParagraphProps(style, 256))
        .children({Element<RawTextShadowNode>().surfaceId(0).props(BuildRawTextProps(text))}));
  }
  return BuildBenchmarkShadowNode(registry, Element<RootShadowNode>()
      .surfaceId(0).tag(1).props(BuildRootProps(320, density)).children(std::move(children)));
}

static std::shared_ptr<RootShadowNode> BuildTextViewTree(
    const ComponentDescriptorRegistry::Shared &registry,
    const std::vector<std::string> &texts,
    const TextStyleFixture &style,
    float density)
{
  std::vector<ElementFragment> children;
  children.reserve(texts.size());
  for (const auto &text : texts) {
    children.push_back(Element<RNTextEngineTextViewShadowNode>().surfaceId(0).props(BuildTextViewProps(text, style, 256)));
  }
  return BuildBenchmarkShadowNode(registry, Element<RootShadowNode>()
      .surfaceId(0).tag(1).props(BuildRootProps(320, density)).children(std::move(children)));
}

std::vector<std::string> ChatTexts() {
  const std::vector<std::string> fragments = {
      "The renderer should know the bubble height before the row mounts.",
      "Prepared text keeps width work separate from shaping work in a virtualized list.",
      "Inline emphasis, tabular numbers, and quoted citations still need exact native metrics.",
      "Worklet-driven layout needs stable widths, line counts, and last-line geometry to stay smooth.",
      "A text surface should update content without rebuilding unrelated host objects.",
  };
  std::vector<std::string> texts;
  for (int index = 0; index < 128; ++index) {
    texts.push_back("Message " + std::to_string(index + 1) + ". " + fragments[index % 5] + " " +
        fragments[(index + 2) % 5] + " " + fragments[(index + 4) % 5]);
  }
  return texts;
}

std::vector<RunFixture> RichRuns(const std::string &text) {
  std::vector<RunFixture> runs;
  auto add = [&](const std::string &needle, int mask, TextStyleFixture style) {
    auto start = text.find(needle);
    Require(start != std::string::npos, "Missing rich text range");
    runs.push_back({static_cast<int>(start), static_cast<int>(start + needle.size()), mask, std::move(style)});
  };
  add("inline emphasis", kRunStyleHasFontWeight, {.fontWeight = "700"});
  add("quoted insertions", kRunStyleHasFontStyle, {.fontStyle = "italic"});
  add("editorial spans", kRunStyleHasFontSize, {.fontSize = 24});
  add("tabular 1234567890", kRunStyleHasTabularNumbers | kRunStyleHasLetterSpacing,
      {.letterSpacing = 0.12, .tabularNumbers = true});
  add("final weighted phrase", kRunStyleHasFontWeight | kRunStyleHasFontSize,
      {.fontSize = 24, .fontWeight = "700"});
  return runs;
}

rntextengine::TextViewMeasurementRuns TextViewRuns(const std::vector<RunFixture> &runs) {
  rntextengine::TextViewMeasurementRuns result;
  for (const auto &run : runs) {
    result.colors.emplace_back();
    result.starts.push_back(run.start);
    result.ends.push_back(run.end);
    result.styleMasks.push_back(run.styleMask);
    result.fontFamilies.emplace_back();
    result.fontSizes.push_back(run.style.fontSize);
    result.fontStyles.push_back(run.style.fontStyle);
    result.fontWeights.push_back(run.style.fontWeight);
    result.letterSpacings.push_back(run.style.letterSpacing);
    result.lineHeights.push_back(run.style.lineHeight);
    result.tabularNumbers.push_back(run.style.tabularNumbers);
  }
  return result;
}

uint64_t PrepareText(const std::string &text, const TextStyleFixture &style,
    const rntextengine::TextViewMeasurementRuns &runs = {}) {
  auto handle = rntextengine::prepareTextViewMeasurementHandle(text, "", false, "", style.fontSize,
      style.fontWeight, style.fontStyle, style.letterSpacing, style.lineHeight, style.tabularNumbers, runs);
  Require(handle != 0, "TextView preparation failed");
  return handle;
}

Size MeasureTextView(uint64_t handle, double width, int maxLines) {
  auto size = rntextengine::measurePreparedTextMeasurementLayout(handle, width, maxLines,
      maxLines > 0 ? "tail" : "", false);
  sink = sink + size.width + size.height;
  return {static_cast<Float>(size.width), static_cast<Float>(size.height)};
}

Size MeasureRN(const TextLayoutManager &manager, const AttributedStringBox &input,
    double width, int maxLines, float density) {
  auto attributes = BuildParagraphAttributes(maxLines);
  auto context = BuildTextLayoutContext(density);
  auto constraints = BuildLayoutConstraints(width);
  auto measurement = ReactNativeFeatureFlags::enablePreparedTextLayout()
      ? manager.measurePreparedLayout(manager.prepareLayout(input.getValue(), attributes, context, constraints),
            context, constraints)
      : manager.measure(input, attributes, context, constraints);
  sink = sink + measurement.size.width + measurement.size.height;
  return measurement.size;
}

void CheckSizes(Size rn, Size textView, double width, float density, const std::string &name) {
  double tolerance = 1.0 / density;
  for (auto size : {rn, textView}) {
    Require(std::isfinite(size.width) && std::isfinite(size.height) && size.width > 0 &&
        size.height > 0 && size.width <= width + tolerance, "Invalid geometry: " + name +
            "; constraint=" + std::to_string(width) + "; RN=" + std::to_string(rn.width) +
            "x" + std::to_string(rn.height) + "; TextView=" + std::to_string(textView.width) +
            "x" + std::to_string(textView.height));
  }
  Require(std::abs(rn.height - textView.height) <= tolerance,
      "Height mismatch: " + name + "; RN=" + std::to_string(rn.height) + "; TextView=" + std::to_string(textView.height));
}

class JAndroidLayout : public jni::JavaClass<JAndroidLayout> {
 public:
  static constexpr auto kJavaDescriptor = "Landroid/text/Layout;";
};

void CheckLines(const TextLayoutManager &manager, const AttributedStringBox &input,
    uint64_t handle, const std::string &text, double width, float density) {
  static auto bindings = jni::findClassStatic("com/rntextengine/RNTextEngineBindings");
  static auto layoutLines = bindings->getStaticMethod<jni::JArrayDouble::javaobject(
      jlong, jdouble, jint, jstring, jboolean)>("layoutLines");
  auto packed = layoutLines(bindings, static_cast<jlong>(handle), width, 0, nullptr, false);
  std::vector<double> values(packed->size());
  packed->getRegion(0, values.size(), values.data());
  auto checkCount = [&](size_t count) {
    Require(values.size() >= 4 && values[2] == count && values.size() == 4 + count * 4,
        "Line count mismatch at width " + std::to_string(width));
    if (width == 10000) Require(count == 1, "Unconstrained text must fit on one line: " + text);
  };
  auto trim = [](std::string value) {
    while (!value.empty() && value.back() == ' ') value.pop_back();
    return value;
  };
  auto checkLine = [&](size_t index, const std::string &rnText, double rnWidth) {
    int start = static_cast<int>(values[4 + index * 4]);
    int end = static_cast<int>(values[5 + index * 4]);
    Require(start >= 0 && end >= start && end <= text.size(), "Invalid line range");
    Require(trim(rnText) == trim(text.substr(start, end - start)),
        "Line break mismatch at width " + std::to_string(width) + ": " + text);
    if (width == 10000) {
      Require(std::abs(rnWidth - values[6]) <= 1.0 / density,
          "Single-line glyph width mismatch: " + text + "; RN=" + std::to_string(rnWidth) +
              "; TextView=" + std::to_string(values[6]) + "; density=" + std::to_string(density));
    }
  };
  size_t lineCount;
  if (ReactNativeFeatureFlags::enablePreparedTextLayout()) {
    static auto getLayout = JPreparedLayout::javaClassStatic()->getMethod<JAndroidLayout::javaobject()>("getLayout");
    static auto layoutClass = JAndroidLayout::javaClassStatic();
    static auto getLineCount = layoutClass->getMethod<jint()>("getLineCount");
    static auto getLineStart = layoutClass->getMethod<jint(jint)>("getLineStart");
    static auto getLineEnd = layoutClass->getMethod<jint(jint)>("getLineEnd");
    static auto getLineWidth = layoutClass->getMethod<jfloat(jint)>("getLineWidth");
    auto prepared = manager.prepareLayout(input.getValue(), BuildParagraphAttributes(0),
        BuildTextLayoutContext(density), BuildLayoutConstraints(width));
    auto layout = getLayout(prepared.get());
    const int count = getLineCount(layout.get());
    lineCount = count;
    checkCount(lineCount);
    for (int index = 0; index < count; ++index) {
      const int start = getLineStart(layout.get(), index);
      const int end = getLineEnd(layout.get(), index);
      Require(start >= 0 && end >= start && end <= text.size(), "Invalid prepared line range");
      checkLine(index, text.substr(start, end - start), getLineWidth(layout.get(), index) / density);
    }
  } else {
    auto lines = manager.measureLines(input, BuildParagraphAttributes(0),
        {.width = static_cast<Float>(width), .height = 10000});
    lineCount = lines.size();
    checkCount(lineCount);
    for (size_t index = 0; index < lines.size(); ++index) {
      checkLine(index, lines[index].text, lines[index].frame.size.width);
    }
  }
  auto truncated = layoutLines(bindings, static_cast<jlong>(handle), width, 2, jni::make_jstring("tail").get(), false);
  double header[4];
  truncated->getRegion(0, 4, header);
  Require(header[2] == std::min<size_t>(2, lineCount), "Invalid two-line limit");
}

struct Samples {
  std::vector<double> rn;
  std::vector<double> textView;
};

Samples MeasurePair(const std::function<void()> &rn, const std::function<void()> &textView,
    int repetitions, int run) {
  auto measure = [&](const auto &work) {
    auto start = std::chrono::steady_clock::now();
    for (int i = 0; i < repetitions; ++i) work();
    return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
  };
  Samples samples;
  constexpr int warmups = 10;
  for (int index = -warmups; index < 9; ++index) {
    double rnMs, textViewMs;
    if ((index + warmups + run - 1) % 2 == 0) {
      rnMs = measure(rn);
      textViewMs = measure(textView);
    } else {
      textViewMs = measure(textView);
      rnMs = measure(rn);
    }
    if (index >= 0) {
      samples.rn.push_back(rnMs);
      samples.textView.push_back(textViewMs);
    }
  }
  return samples;
}

std::string RunComparison(const jni::global_ref<jobject> &fabricManager, float density, int run, bool prepared) {
  Require(ReactNativeFeatureFlags::enablePreparedTextLayout() == prepared, "RN prepared mode does not match the request");
  Require(!ReactNativeFeatureFlags::disableTextLayoutManagerCacheAndroid() &&
      ReactNativeFeatureFlags::preparedTextCacheSize() == 200, "RN layout cache defaults changed");
  const auto chatTexts = ChatTexts();
  const std::string richText = "Prepared text performance should cover inline emphasis, quoted insertions, editorial spans, tabular 1234567890, and a final weighted phrase while preserving one coherent source string.";
  std::vector<std::string> richTexts;
  for (int index = 1; index <= 96; ++index) {
    std::ostringstream text;
    text << richText << " Case " << std::setw(3) << std::setfill('0') << index << ".";
    richTexts.push_back(text.str());
  }
  const TextStyleFixture chatStyle{.fontSize = 16, .letterSpacing = 0.1, .lineHeight = 24, .fontWeight = "700"};
  const TextStyleFixture richStyle{.fontSize = 16, .letterSpacing = 0.05, .lineHeight = 32};
  const auto richRuns = RichRuns(richText);
  const auto packedRuns = TextViewRuns(richRuns);
  const std::vector<double> widths{256, 224, 304, 240, 280, 200};
  auto checkPixels = [&](double value) {
    Require(std::abs(value * density - std::round(value * density)) < 0.0001,
        "Benchmark sizes must align to physical pixels at this device density");
  };
  for (double value : widths) checkPixels(value);
  for (double value : {320.0, 10000.0, chatStyle.fontSize, chatStyle.lineHeight,
           richStyle.fontSize, richStyle.lineHeight}) checkPixels(value);
  for (const auto &styleRun : richRuns) {
    if (styleRun.styleMask & kRunStyleHasFontSize) checkPixels(styleRun.style.fontSize);
    if (styleRun.styleMask & kRunStyleHasLineHeight) checkPixels(styleRun.style.lineHeight);
  }
  std::weak_ptr<const ContextContainer> releasedContext;
  {
    auto registry = BuildBenchmarkComponentDescriptorRegistry(fabricManager);
    releasedContext = registry->at(ParagraphShadowNode::Handle()).getContextContainer();
    auto root = BuildRNTextTree(registry, chatTexts, chatStyle, density);
    Require(root->layoutIfNeeded(), "Lifecycle preflight tree did not lay out");
  }
  Require(releasedContext.expired(), "Fabric registry retained its layout context");
  auto context = std::make_shared<ContextContainer>();
  context->insert("FabricUIManager", jni::make_global(fabricManager));

  {
    TextLayoutManager manager(context);
    for (const auto &text : chatTexts) {
      AttributedStringBox input{BuildRNAttributedString(text, chatStyle, {})};
      auto handle = PrepareText(text, chatStyle);
      for (double width : widths) CheckLines(manager, input, handle, text, width, density);
      CheckLines(manager, input, handle, text, 10000, density);
      for (int maxLines : {0, 2}) {
        for (double width : widths) {
          CheckSizes(MeasureRN(manager, input, width, maxLines, density),
              MeasureTextView(handle, width, maxLines), width, density, "Direct maxLines=" + std::to_string(maxLines) + ": " + text);
        }
      }
      rntextengine::releasePreparedTextMeasurementHandle(handle);
    }
    for (const auto &text : richTexts) {
      AttributedStringBox input{BuildRNAttributedString(text, richStyle, richRuns)};
      auto handle = PrepareText(text, richStyle, packedRuns);
      CheckLines(manager, input, handle, text, 280, density);
      CheckLines(manager, input, handle, text, 10000, density);
      auto actual = MeasureTextView(handle, 280, 0);
      rntextengine::releasePreparedTextMeasurementHandle(handle);
      CheckSizes(MeasureRN(manager, input, 280, 0, density), actual, 280, density, text);
    }
    auto rnRegistry = BuildBenchmarkComponentDescriptorRegistry(fabricManager);
    auto rnRoot = BuildRNTextTree(rnRegistry, chatTexts, chatStyle, density);
    auto tvRegistry = BuildBenchmarkComponentDescriptorRegistry(fabricManager);
    auto tvRoot = BuildTextViewTree(tvRegistry, chatTexts, chatStyle, density);
    Require(rnRoot->layoutIfNeeded() && tvRoot->layoutIfNeeded(), "Fabric tree did not lay out");
    Require(rnRoot->getChildren().size() == 128 && tvRoot->getChildren().size() == 128, "Incomplete Fabric tree");
    for (size_t i = 0; i < chatTexts.size(); ++i) {
      const auto &rnNode = static_cast<const ParagraphShadowNode &>(*rnRoot->getChildren()[i]);
      Require(rnNode.getStateData().attributedString.getString() == chatTexts[i], "Fabric paragraph lost its input text");
      auto rn = rnNode.getLayoutMetrics().frame;
      auto tv = static_cast<const RNTextEngineTextViewShadowNode &>(*tvRoot->getChildren()[i]).getLayoutMetrics().frame;
      CheckSizes(rn.size, tv.size, 256, density, "Fabric child " + std::to_string(i) + ": " + chatTexts[i]);
      Require(std::abs(rn.size.width - tv.size.width) <= 1.0 / density &&
          std::abs(rn.origin.x - tv.origin.x) <= 1.0 / density &&
          std::abs(rn.origin.y - tv.origin.y) <= 1.0 / density, "Fabric frame mismatch: " + std::to_string(i));
    }
  }

  std::ostringstream output;
  output << std::setprecision(17) << '[';
  bool first = true;
  auto record = [&](const std::string &scenario, int operations, const Samples &samples) {
    for (int impl = 0; impl < 2; ++impl) {
      if (!first) output << ',';
      first = false;
      output << "{\"scenario\":\"" << scenario << "\",\"implementation\":\"" << (impl == 0 ? "RN Text" : "TextView")
          << "\",\"operations\":" << operations << ",\"samplesMs\":[";
      const auto &values = impl == 0 ? samples.rn : samples.textView;
      for (size_t i = 0; i < values.size(); ++i) {
        if (i) output << ',';
        Require(std::isfinite(values[i]) && values[i] > 0, "Invalid duration");
        output << values[i];
      }
      output << "]}";
    }
  };
  record("fabric_chat_shadow_tree_layout", 512, MeasurePair([&] {
    auto registry = BuildBenchmarkComponentDescriptorRegistry(fabricManager);
    auto root = BuildRNTextTree(registry, chatTexts, chatStyle, density);
    sink = sink + root->layoutIfNeeded();
  }, [&] {
    auto registry = BuildBenchmarkComponentDescriptorRegistry(fabricManager);
    auto root = BuildTextViewTree(registry, chatTexts, chatStyle, density);
    sink = sink + root->layoutIfNeeded();
  }, 4, run));
  record("cold_uniform_chat_layout", 512, MeasurePair([&] {
    TextLayoutManager manager(context);
    for (const auto &text : chatTexts) {
      AttributedStringBox input{BuildRNAttributedString(text, chatStyle, {})};
      MeasureRN(manager, input, 256, 0, density);
    }
  }, [&] {
    for (const auto &text : chatTexts) {
      auto handle = PrepareText(text, chatStyle);
      MeasureTextView(handle, 256, 0);
      rntextengine::releasePreparedTextMeasurementHandle(handle);
    }
  }, 4, run));

  std::vector<AttributedStringBox> inputs;
  std::vector<uint64_t> handles;
  for (const auto &text : chatTexts) {
    inputs.emplace_back(BuildRNAttributedString(text, chatStyle, {}));
    handles.push_back(PrepareText(text, chatStyle));
  }
  for (int maxLines : {0, 2}) {
    TextLayoutManager manager(context);
    record(maxLines == 0 ? "cached_uniform_layout_queries" : "cached_truncated_layout_queries", 6144,
        MeasurePair([&] {
          for (double width : widths) for (const auto &input : inputs) MeasureRN(manager, input, width, maxLines, density);
        }, [&] {
          for (double width : widths) for (auto handle : handles) MeasureTextView(handle, width, maxLines);
        }, 8, run));
  }
  for (auto handle : handles) rntextengine::releasePreparedTextMeasurementHandle(handle);

  record("cold_rich_inline_layout", 384, MeasurePair([&] {
    TextLayoutManager manager(context);
    for (const auto &text : richTexts) {
      AttributedStringBox input{BuildRNAttributedString(text, richStyle, richRuns)};
      MeasureRN(manager, input, 280, 0, density);
    }
  }, [&] {
    for (const auto &text : richTexts) {
      auto handle = PrepareText(text, richStyle, packedRuns);
      MeasureTextView(handle, 280, 0);
      rntextengine::releasePreparedTextMeasurementHandle(handle);
    }
  }, 4, run));
  Require(std::isfinite(sink) && sink > 0, "Measurement sink is invalid");
  output << ']';
  return output.str();
}

} // namespace

extern "C" JNIEXPORT jstring JNICALL
Java_com_rntextengine_RNTextEngineTextComparisonBenchmark_runNativeComparison(
    JNIEnv *env, jobject, jobject manager, jfloat density, jint run, jboolean prepared) {
  try {
    return env->NewStringUTF(RunComparison(jni::make_global(manager), density, run, prepared).c_str());
  } catch (const std::exception &error) {
    env->ThrowNew(env->FindClass("java/lang/RuntimeException"), error.what());
    return nullptr;
  }
}
