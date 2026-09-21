#include "RNTextEngineTextViewTestHelpers.h"
#include <jni.h>
#include <fbjni/fbjni.h>
#include <react/fabric/StateWrapperImpl.h>
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
#include <cstring>
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
using namespace rntextengine::test;

namespace {
// Values cross the test-only JNI boundary to the corresponding view manager.
enum class Implementation { RNText, TextView, PreparedTextView };
constexpr const char *kImplementationNames[] = {"RN Text", "TextView", "PreparedTextView"};

struct PreparedHandles {
  std::vector<jlong> values;
  PreparedHandles() = default;
  PreparedHandles(const PreparedHandles &) = delete;
  ~PreparedHandles() {
    if (values.empty()) return;
    static auto bindings = jni::findClassStatic("com/rntextengine/RNTextEngineBindings");
    static auto release = bindings->getStaticMethod<void(jlong)>("release");
    for (auto handle : values) release(bindings, handle);
  }
};

constexpr int kRunStyleHasFontStyle = 1 << 3;
constexpr int kRunStyleHasFontWeight = 1 << 4;
constexpr int kRunStyleHasLetterSpacing = 1 << 5;
constexpr int kRunStyleHasLineHeight = 1 << 6;
constexpr int kRunStyleHasTabularNumbers = 1 << 7;

struct RunFixture {
  int start{0};
  int end{0};
  int styleMask{0};
  TextStyleFixture style{};
};
volatile double sink = 0;
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

static TextLayoutContext BuildTextLayoutContext(float density) {
  return TextLayoutContext{.pointScaleFactor = density, .surfaceId = 0};
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
  providerRegistry.add(concreteComponentDescriptorProvider<RNTextEnginePreparedTextViewComponentDescriptor>());

  auto descriptorRegistry = providerRegistry.createComponentDescriptorRegistry(ComponentDescriptorParameters{
      .eventDispatcher = {},
      .contextContainer = std::move(contextContainer),
      .flavor = nullptr,
  });

  return descriptorRegistry;
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
  return BuildShadowNode(registry, Element<RootShadowNode>()
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
  return BuildShadowNode(registry, Element<RootShadowNode>()
      .surfaceId(0).tag(1).props(BuildRootProps(320, density)).children(std::move(children)));
}

static std::shared_ptr<RootShadowNode> BuildPreparedTextViewTree(
    const ComponentDescriptorRegistry::Shared &registry,
    const std::vector<std::string> &texts,
    const TextStyleFixture &style,
    float density,
    PreparedHandles &handles)
{
  static auto bindings = jni::findClassStatic("com/rntextengine/RNTextEngineBindings");
  static auto prepare = bindings->getStaticMethod<jlong(jstring, jstring, jstring, jdouble,
      jstring, jstring, jdouble, jdouble, jboolean, jboolean, jboolean, jstring)>("prepare");
  static auto layout = bindings->getStaticMethod<jni::JArrayDouble::javaobject(
      jlong, jdouble, jint, jstring, jboolean)>("layout");
  auto fontWeight = jni::make_jstring(style.fontWeight);
  auto fontStyle = jni::make_jstring(style.fontStyle);
  auto breakStrategy = jni::make_jstring("highQuality");
  std::vector<ElementFragment> children;
  children.reserve(texts.size());
  handles.values.reserve(texts.size());
  for (const auto &text : texts) {
    auto handle = prepare(bindings, jni::make_jstring(text).get(), nullptr, nullptr, style.fontSize,
        fontWeight.get(), fontStyle.get(), style.letterSpacing, style.lineHeight,
        false, false, style.tabularNumbers, breakStrategy.get());
    handles.values.push_back(handle);
    auto measured = layout(bindings, handle, 256.0, 0, nullptr, false);
    double height;
    measured->getRegion(1, 1, &height);
    auto props = std::make_shared<RNTextEnginePreparedTextViewProps>();
    props->handle = handle;
    props->anchorToCapHeight = false;
    props->yogaStyle.setDimension(yoga::Dimension::Width, yoga::StyleSizeLength::points(256));
    props->yogaStyle.setDimension(yoga::Dimension::Height, yoga::StyleSizeLength::points(height));
    children.push_back(Element<RNTextEnginePreparedTextViewShadowNode>().surfaceId(0).props(props));
  }
  return BuildShadowNode(registry, Element<RootShadowNode>()
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
      style.fontWeight, style.fontStyle, style.letterSpacing, style.lineHeight, style.tabularNumbers, runs, rntextengine::textEnvironmentVersion());
  Require(handle != 0, "TextView preparation failed");
  return handle;
}

Size MeasureTextView(uint64_t handle, double width, int maxLines) {
  auto size = rntextengine::measurePreparedTextMeasurementLayout(handle, width, maxLines,
      maxLines > 0 ? "tail" : "", false);
  sink = sink + size.width + size.height;
  return {static_cast<Float>(size.width), static_cast<Float>(size.height)};
}

uint64_t CheckTextViewMeasurement() {
  static auto bindings = jni::findClassStatic("com/rntextengine/RNTextEngineBindings");
  static auto layout = bindings->getStaticMethod<jni::JArrayDouble::javaobject(
      jlong, jdouble, jint, jstring, jboolean)>("layout");
  const TextStyleFixture style{.fontSize = 17.3, .letterSpacing = 0.15, .lineHeight = 23.7};
  const std::vector<RunFixture> runs{{.start = 0, .end = 7,
      .styleMask = kRunStyleHasFontSize | kRunStyleHasFontWeight,
      .style = {.fontSize = 21.5, .fontWeight = "700"}}};
  uint64_t checksum = 14695981039346656037ULL;

  for (const std::string text : {"A", "Leading text with enough words to wrap.\nAnother line.",
           "Leading text with Arabic العربية and CJK 中文."}) {
    for (bool styled : {false, true}) {
      if (styled && text.size() < 7) continue;
      auto handle = PrepareText(text, style, styled ? TextViewRuns(runs) : rntextengine::TextViewMeasurementRuns{});
      for (double width : {0.0, 0.125, 80.25, 256.125}) {
        for (int maxLines : {-1, 0, 1, 2, std::numeric_limits<int>::max()}) {
          for (const std::string mode : {"", "clip", "head", "middle", "tail", "unknown"}) {
            for (bool anchor : {false, true}) {
              auto javaMode = mode.empty() ? jni::local_ref<jni::JString>{} : jni::make_jstring(mode);
              for (int repeat = 0; repeat < 2; ++repeat) {
                auto measured = rntextengine::measurePreparedTextMeasurementLayout(handle, width, maxLines, mode, anchor);
                auto packed = layout(bindings, static_cast<jlong>(handle), width, maxLines, javaMode.get(), anchor);
                Require(packed->size() == 4, "Layout projection must retain all four public metrics");
                double metrics[4];
                packed->getRegion(0, 4, metrics);
                Require(static_cast<Float>(measured.width) == static_cast<Float>(metrics[0]) &&
                        static_cast<Float>(measured.height) == static_cast<Float>(metrics[1]),
                    "Native measurement differs from public layout: mode=" + mode +
                        "; lines=" + std::to_string(maxLines) + "; width=" + std::to_string(width));
                for (double value : metrics) {
                  uint64_t bits;
                  std::memcpy(&bits, &value, sizeof(bits));
                  checksum = (checksum ^ bits) * 1099511628211ULL;
                }
              }
            }
          }
        }
      }
      rntextengine::releasePreparedTextMeasurementHandle(handle);
    }
  }
  return checksum;
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
  auto sourceText = jni::make_jstring(text);
  static auto stringLength = jni::JString::javaClassStatic()->getMethod<jint()>("length");
  static auto substring = jni::JString::javaClassStatic()->getMethod<jstring(jint, jint)>("substring");
  auto slice = [&](int start, int end) {
    Require(start >= 0 && end >= start && end <= stringLength(sourceText.get()), "Invalid UTF-16 line range");
    return substring(sourceText.get(), start, end)->toStdString();
  };
  auto trim = [](std::string value) {
    while (!value.empty() && value.back() == ' ') value.pop_back();
    return value;
  };
  auto checkLine = [&](size_t index, const std::string &rnText, double rnWidth) {
    int start = static_cast<int>(values[4 + index * 4]);
    int end = static_cast<int>(values[5 + index * 4]);
    Require(trim(rnText) == trim(slice(start, end)),
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
      checkLine(index, slice(start, end), getLineWidth(layout.get(), index) / density);
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

std::vector<double> Measure(const std::function<void()> &work, int repetitions) {
  std::vector<double> samples;
  for (int index = -10; index < 9; ++index) {
    const auto start = std::chrono::steady_clock::now();
    for (int pass = 0; pass < repetitions; ++pass) work();
    const double elapsed = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
    if (index >= 0) samples.push_back(elapsed);
  }
  return samples;
}

void WriteSamples(std::ostream &output, const std::string &scenario, int operations,
    Implementation implementation, const std::vector<double> &samples) {
  output << "{\"scenario\":\"" << scenario << "\",\"implementation\":\"" << kImplementationNames[static_cast<int>(implementation)]
      << "\",\"operations\":" << operations << ",\"samplesMs\":[";
  for (size_t index = 0; index < samples.size(); ++index) {
    if (index) output << ',';
    Require(std::isfinite(samples[index]) && samples[index] > 0, "Invalid duration");
    output << samples[index];
  }
  output << "]}";
}

std::string RunComparison(const jni::global_ref<jobject> &fabricManager, float density, bool prepared, Implementation implementation) {
  const bool engine = implementation == Implementation::TextView;
  Require(ReactNativeFeatureFlags::enablePreparedTextLayout() == prepared, "RN prepared mode does not match the request");
  Require(!ReactNativeFeatureFlags::disableTextLayoutManagerCacheAndroid() &&
      ReactNativeFeatureFlags::preparedTextCacheSize() == 200, "RN layout cache defaults changed");
  const auto chatTexts = ChatTexts();
  std::vector<std::string> labelTexts;
  const std::vector<std::string> labelPrefixes{"OK", "Done 🙂", "日本語", "বাংলা"};
  for (int index = 0; index < 128; ++index) {
    labelTexts.push_back(labelPrefixes[index % labelPrefixes.size()] + " " + std::to_string(index + 1));
  }
  const TextStyleFixture labelStyle{.fontSize = 16, .lineHeight = std::numeric_limits<double>::quiet_NaN()};
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
    for (const auto &text : labelTexts) {
      AttributedStringBox input{BuildRNAttributedString(text, labelStyle, {})};
      auto handle = PrepareText(text, labelStyle);
      for (double width : {96, 160}) {
        CheckLines(manager, input, handle, text, width, density);
        CheckSizes(MeasureRN(manager, input, width, 0, density),
            MeasureTextView(handle, width, 0), width, density, "Natural-height label: " + text);
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
    auto preparedRegistry = BuildBenchmarkComponentDescriptorRegistry(fabricManager);
    PreparedHandles handles;
    auto preparedRoot = BuildPreparedTextViewTree(preparedRegistry, chatTexts, chatStyle, density, handles);
    Require(rnRoot->layoutIfNeeded() && tvRoot->layoutIfNeeded() && preparedRoot->layoutIfNeeded(), "Fabric tree did not lay out");
    Require(preparedRoot->getChildren().size() == chatTexts.size(), "Incomplete PreparedTextView tree");
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
      auto ptv = static_cast<const LayoutableShadowNode &>(*preparedRoot->getChildren()[i]).getLayoutMetrics().frame;
      CheckSizes(rn.size, ptv.size, 256, density, "PreparedTextView child " + std::to_string(i));
      Require(std::abs(rn.size.width - ptv.size.width) <= 1.0 / density &&
          std::abs(rn.origin.x - ptv.origin.x) <= 1.0 / density &&
          std::abs(rn.origin.y - ptv.origin.y) <= 1.0 / density, "PreparedTextView frame mismatch: " + std::to_string(i));
    }
  }

  std::ostringstream output;
  output << std::setprecision(17) << '[';
  bool first = true;
  auto measure = [&](const std::function<void()> &rn, const std::function<void()> &textView, int repetitions) {
    return Measure(engine ? textView : rn, repetitions);
  };
  auto record = [&](const std::string &scenario, int operations, const std::vector<double> &samples) {
    if (!first) output << ',';
    first = false;
    WriteSamples(output, scenario, operations, implementation, samples);
  };
  record("fabric_chat_shadow_tree_layout", 512, Measure([&] {
    auto registry = BuildBenchmarkComponentDescriptorRegistry(fabricManager);
    PreparedHandles handles;
    auto root = implementation == Implementation::PreparedTextView
        ? BuildPreparedTextViewTree(registry, chatTexts, chatStyle, density, handles)
        : engine ? BuildTextViewTree(registry, chatTexts, chatStyle, density)
                 : BuildRNTextTree(registry, chatTexts, chatStyle, density);
    sink = sink + root->layoutIfNeeded();
  }, 4));
  if (implementation == Implementation::PreparedTextView) {
    output << ']';
    return output.str();
  }
  {
    auto registry = BuildBenchmarkComponentDescriptorRegistry(fabricManager);
    auto root = engine ? BuildTextViewTree(registry, chatTexts, chatStyle, density)
                       : BuildRNTextTree(registry, chatTexts, chatStyle, density);
    Require(root->layoutIfNeeded(), "Retained tree did not lay out");
    auto retainedContext = BuildFabricLayoutContext(density);
    auto retainedConstraints = BuildLayoutConstraints(256);
    retainedConstraints.minimumSize.width = 256;
    record("retained_paragraph_measurement", 16384, measure([&] {
      for (const auto &child : root->getChildren()) {
        sink = sink + static_cast<const ParagraphShadowNode &>(*child).measureContent(
            retainedContext, retainedConstraints).height;
      }
    }, [&] {
      for (const auto &child : root->getChildren()) {
        sink = sink + static_cast<const RNTextEngineTextViewShadowNode &>(*child).measureContent(
            retainedContext, retainedConstraints).height;
      }
    }, 128));
  }
  record("cold_uniform_chat_layout", 512, measure([&] {
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
  }, 4));

  record("cold_short_label_layout", 512, measure([&] {
    TextLayoutManager manager(context);
    for (const auto &text : labelTexts) {
      AttributedStringBox input{BuildRNAttributedString(text, labelStyle, {})};
      MeasureRN(manager, input, 160, 0, density);
    }
  }, [&] {
    for (const auto &text : labelTexts) {
      auto handle = PrepareText(text, labelStyle);
      MeasureTextView(handle, 160, 0);
      rntextengine::releasePreparedTextMeasurementHandle(handle);
    }
  }, 4));

  struct QueryWorkingSet { size_t texts; size_t widths; };
  for (const auto workingSet : {QueryWorkingSet{50, 4}, QueryWorkingSet{chatTexts.size(), widths.size()}}) {
    const size_t keyCount = workingSet.texts * workingSet.widths;
    const std::vector<double> queryWidths(widths.begin(), widths.begin() + workingSet.widths);
    std::vector<AttributedStringBox> inputs;
    std::vector<uint64_t> handles;
    for (size_t index = 0; index < workingSet.texts; ++index) {
      if (engine) handles.push_back(PrepareText(chatTexts[index], chatStyle));
      else inputs.emplace_back(BuildRNAttributedString(chatTexts[index], chatStyle, {}));
    }
    for (int maxLines : {0, 2}) {
      TextLayoutManager manager(context);
      if (prepared && !engine) {
        // Retain identities only for validation; measured queries still go through the manager.
        std::vector<TextLayoutManager::PreparedTextLayout> layouts;
        const auto paragraph = BuildParagraphAttributes(maxLines);
        const auto layoutContext = BuildTextLayoutContext(density);
        for (double width : queryWidths) for (const auto &input : inputs) {
          layouts.push_back(manager.prepareLayout(input.getValue(), paragraph, layoutContext, BuildLayoutConstraints(width)));
        }
        size_t index = 0;
        for (double width : queryWidths) for (const auto &input : inputs) {
          auto layout = manager.prepareLayout(input.getValue(), paragraph, layoutContext, BuildLayoutConstraints(width));
          bool reused = jni::Environment::current()->IsSameObject(layouts[index++].get(), layout.get());
          Require(reused == (keyCount <= ReactNativeFeatureFlags::preparedTextCacheSize()),
              "Prepared cache reuse mismatch: " + std::to_string(keyCount) + " keys, maxLines=" + std::to_string(maxLines));
        }
      }
      std::string scenario = maxLines == 0 ? "cached_uniform_layout_queries" : "cached_truncated_layout_queries";
      if (keyCount == 200) scenario += "_200_keys";
      record(scenario, keyCount * 8, measure([&] {
        for (double width : queryWidths) for (const auto &input : inputs) MeasureRN(manager, input, width, maxLines, density);
      }, [&] {
        for (double width : queryWidths) for (auto handle : handles) MeasureTextView(handle, width, maxLines);
      }, 8));
    }
    for (auto handle : handles) rntextengine::releasePreparedTextMeasurementHandle(handle);
  }

  record("cold_rich_inline_layout", 384, measure([&] {
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
  }, 4));
  Require(std::isfinite(sink) && sink > 0, "Measurement sink is invalid");
  output << ']';
  return output.str();
}

std::string RunFirstDraw(jni::alias_ref<jobject> receiver,
    const jni::global_ref<jobject> &fabricManager, float density, Implementation implementation) {
  auto mountAndDraw = receiver->getClass()->getMethod<void(jint, ReadableNativeMap::javaobject,
      StateWrapper::javaobject, jint, jint, jstring)>("mountAndDraw");
  const auto texts = ChatTexts();
  const TextStyleFixture style{.fontSize = 16, .letterSpacing = 0.1, .lineHeight = 24, .fontWeight = "700"};
  auto draw = [&](bool validate) {
    auto registry = BuildBenchmarkComponentDescriptorRegistry(fabricManager);
    PreparedHandles handles;
    auto root = implementation == Implementation::PreparedTextView
        ? BuildPreparedTextViewTree(registry, texts, style, density, handles)
        : implementation == Implementation::TextView ? BuildTextViewTree(registry, texts, style, density)
                                                   : BuildRNTextTree(registry, texts, style, density);
    Require(root->layoutIfNeeded(), "Mounted tree did not lay out");
    for (size_t index = 0; index < root->getChildren().size(); ++index) {
      const auto &node = static_cast<const LayoutableShadowNode &>(*root->getChildren()[index]);
      auto props = ReadableNativeMap::newObjectCxxArgs(node.getProps()->getDiffProps(nullptr));
      auto state = StateWrapperImpl::newObjectJavaArgs();
      jni::cthis(state)->setState(node.getState());
      const auto &metrics = node.getLayoutMetrics();
      auto expectedText = validate ? jni::make_jstring(texts[index]) : nullptr;
      mountAndDraw(receiver, static_cast<jint>(implementation), props.get(), state.get(),
          std::round(metrics.frame.size.width * density), std::round(metrics.frame.size.height * density), expectedText.get());
    }
  };
  draw(true);
  const auto samples = Measure([&] { draw(false); }, 4);
  std::ostringstream output;
  output << std::setprecision(17) << '[';
  WriteSamples(output, "fabric_mount_and_first_draw", 512, implementation, samples);
  output << ']';
  return output.str();
}

} // namespace

extern "C" JNIEXPORT jstring JNICALL
Java_com_rntextengine_RNTextEngineTextComparisonBenchmark_checkNativeMeasurement(JNIEnv *env, jobject) {
  try {
    return env->NewStringUTF(std::to_string(CheckTextViewMeasurement()).c_str());
  } catch (const std::exception &error) {
    env->ThrowNew(env->FindClass("java/lang/RuntimeException"), error.what());
    return nullptr;
  }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_rntextengine_RNTextEngineTextComparisonBenchmark_runNativeComparison(
    JNIEnv *env, jobject, jobject manager, jfloat density, jboolean prepared, jint implementation) {
  try {
    return env->NewStringUTF(RunComparison(jni::make_global(manager), density, prepared, static_cast<Implementation>(implementation)).c_str());
  } catch (const std::exception &error) {
    env->ThrowNew(env->FindClass("java/lang/RuntimeException"), error.what());
    return nullptr;
  }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_rntextengine_RNTextEngineTextComparisonBenchmark_runNativeFirstDraw(
    JNIEnv *env, jobject receiver, jobject manager, jfloat density, jint implementation) {
  try {
    return env->NewStringUTF(RunFirstDraw(jni::wrap_alias(receiver), jni::make_global(manager), density, static_cast<Implementation>(implementation)).c_str());
  } catch (const std::exception &error) {
    env->ThrowNew(env->FindClass("java/lang/RuntimeException"), error.what());
    return nullptr;
  }
}
