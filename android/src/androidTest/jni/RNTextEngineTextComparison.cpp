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
#include <atomic>
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
#include <thread>
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

void CheckNestedFontScaling(float density, double fontSize, double lineHeight, double letterSpacing) {
  ComponentDescriptorProviderRegistry providers;
  providers.add(concreteComponentDescriptorProvider<RNTextEngineTextViewComponentDescriptor>());
  auto registry = providers.createComponentDescriptorRegistry(ComponentDescriptorParameters{
      .eventDispatcher = {}, .contextContainer = std::make_shared<ContextContainer>(), .flavor = nullptr});
  const auto context = BuildFabricLayoutContext(density);
  const TextStyleFixture unscaled{.fontSize = 18, .letterSpacing = 2, .lineHeight = 40};
  const TextStyleFixture scaled{.fontSize = fontSize, .letterSpacing = letterSpacing, .lineHeight = lineHeight};
  for (bool rootScales : {false, true}) {
    for (bool childScales : {false, true}) {
      for (bool anchored : {false, true}) {
        auto parentProps = BuildTextViewProps("Parent ", unscaled, 240);
        parentProps->allowFontScaling = rootScales;
        parentProps->anchorToCapHeight = anchored;
        auto childProps = BuildTextViewProps("child", unscaled, 240);
        childProps->allowFontScaling = childScales;
        const auto &childStyle = childScales ? scaled : unscaled;
        auto flatProps = BuildTextViewProps("Parent child", rootScales ? scaled : unscaled, 240);
        flatProps->anchorToCapHeight = anchored;
        if (rootScales != childScales) {
          flatProps->runCount = 1;
          flatProps->runStarts = {7};
          flatProps->runEnds = {12};
          flatProps->runStyleMasks = {(1 << 2) | (1 << 5) | (1 << 6)};
          flatProps->runFontSizes = {childStyle.fontSize};
          flatProps->runLetterSpacings = {childStyle.letterSpacing};
          flatProps->runLineHeights = {childStyle.lineHeight};
        }
        auto flat = BuildBenchmarkShadowNode(registry,
            Element<RNTextEngineTextViewShadowNode>().surfaceId(0).props(flatProps));
        auto nested = BuildBenchmarkShadowNode(registry,
            Element<RNTextEngineTextViewShadowNode>().surfaceId(0).props(parentProps).children({
                Element<RNTextEngineTextViewShadowNode>().surfaceId(0).props(childProps)}));
        for (double width : {60.0, 240.0}) {
          const auto constraints = BuildLayoutConstraints(width);
          auto expected = flat->measureContent(context, constraints);
          auto actual = nested->measureContent(context, constraints);
          Require(std::abs(expected.width - actual.width) < 0.001 && std::abs(expected.height - actual.height) < 0.001,
              "Nested font scaling differs: scaledFontSize=" + std::to_string(fontSize) + "; root=" + std::to_string(rootScales) + "; child=" + std::to_string(childScales) +
                  "; anchor=" + std::to_string(anchored) + "; width=" + std::to_string(width) +
                  "; expected=" + std::to_string(expected.width) + "x" + std::to_string(expected.height) +
                  "; actual=" + std::to_string(actual.width) + "x" + std::to_string(actual.height));
        }
      }
    }
  }
}

void CheckMeasurementBoundaries(float density) {
  ComponentDescriptorProviderRegistry providers;
  providers.add(concreteComponentDescriptorProvider<RNTextEngineTextViewComponentDescriptor>());
  auto registry = providers.createComponentDescriptorRegistry(ComponentDescriptorParameters{
      .eventDispatcher = {}, .contextContainer = std::make_shared<ContextContainer>(), .flavor = nullptr});
  const auto context = BuildFabricLayoutContext(density);
  auto build = [&](const std::string& text, double fontSize = 17) {
    return BuildBenchmarkShadowNode(registry, Element<RNTextEngineTextViewShadowNode>().surfaceId(0)
        .props(BuildTextViewProps(text, {.fontSize = fontSize, .lineHeight = 0}, 240)));
  };
  std::string failures;
  for (bool mixed : {false, true}) {
    auto flat = build("AB");
    auto parent = build("A");
    auto child = build("B", mixed ? 23 : 0);
    parent->appendChild(child);
    if (mixed) {
      auto props = std::make_shared<RNTextEngineTextViewProps>(flat->getConcreteProps());
      props->runCount = 1;
      props->runStarts = {1};
      props->runEnds = {2};
      props->runStyleMasks = {kRunStyleHasFontSize};
      props->runFontSizes = {23};
      flat = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(flat->clone({.props = props}));
    }
    const auto expected = flat->measureContent(context, BuildLayoutConstraints(240));
    const auto actual = parent->measureContent(context, BuildLayoutConstraints(240));
    if (expected != actual) failures += "Natural nested height: expected " + std::to_string(expected.height) +
        ", actual " + std::to_string(actual.height) + "; ";
  }
  const std::string text = "Wrapping must change at a physical pixel boundary, even when DIP widths are very close.";
  bool foundBoundary = false;
  for (int pixels = 40; pixels < 640 && !foundBoundary; ++pixels) {
    const float low = pixels / density - 0.001f;
    const float high = pixels / density + 0.001f;
    auto lowConstraints = BuildLayoutConstraints(low);
    auto highConstraints = BuildLayoutConstraints(high);
    const auto lowSize = build(text)->measureContent(context, lowConstraints);
    const auto highSize = build(text)->measureContent(context, highConstraints);
    if (lowSize.height == highSize.height) continue;
    foundBoundary = true;
    for (bool reverse : {false, true}) {
      auto retained = build(text);
      retained->measureContent(context, reverse ? highConstraints : lowConstraints);
      const auto result = retained->measureContent(context, reverse ? lowConstraints : highConstraints);
      const auto expected = reverse ? lowSize : highSize;
      if (result != expected) failures += "Width cache crossed pixel " + std::to_string(pixels) +
          ": expected height " + std::to_string(expected.height) + ", actual " + std::to_string(result.height) + "; ";
    }
  }
  Require(foundBoundary, "Width fixture did not cross a wrapping boundary");
  Require(failures.empty(), failures);
}

void CheckTextEnvironment(jni::alias_ref<jobject> receiver) {
  auto update = receiver->getClass()->getMethod<jfloat(jint)>("updateTextEnvironment");
  auto check = receiver->getClass()->getMethod<void(jlong)>("checkEnvironmentContent");
  ComponentDescriptorProviderRegistry providers;
  providers.add(concreteComponentDescriptorProvider<RNTextEngineTextViewComponentDescriptor>());
  auto registry = providers.createComponentDescriptorRegistry(ComponentDescriptorParameters{
      .eventDispatcher = {}, .contextContainer = std::make_shared<ContextContainer>(), .flavor = nullptr});
  auto build = [&](bool nested) {
    auto props = BuildTextViewProps(nested ? "initial " : "initial child", {.fontSize = 18, .lineHeight = 0}, 120);
    props->allowFontScaling = true;
    props->textTransform = "uppercase";
    auto element = Element<RNTextEngineTextViewShadowNode>().surfaceId(0).props(props);
    if (nested) {
      auto child = BuildTextViewProps("child", {.fontSize = 23, .lineHeight = 0}, 120);
      child->allowFontScaling = false;
      element.children({Element<RNTextEngineTextViewShadowNode>().surfaceId(0).props(child)});
    }
    return BuildBenchmarkShadowNode(registry, element);
  };
  update(receiver, 0);
  for (bool nested : {false, true}) {
    update(receiver, 0);
    auto retained = build(nested);
    std::shared_ptr<const rntextengine::PreparedTextHandle> previous;
    for (int stage = 0; stage < 8; ++stage) {
      const float density = update(receiver, stage);
      const auto context = BuildFabricLayoutContext(density);
      const auto expected = build(nested);
      for (float width : {60.f, 240.f, std::numeric_limits<float>::infinity()}) {
        const auto constraints = BuildLayoutConstraints(width);
        Require(retained->measureContent(context, constraints) == expected->measureContent(context, constraints),
            "Environment transition retained stale dimensions: stage=" + std::to_string(stage) +
                " nested=" + std::to_string(nested));
      }
      retained->layout(context);
      const auto resource = retained->getStateData().preparedText;
      Require(resource != nullptr, "Environment admission did not publish State content");
      check(receiver, static_cast<jlong>(resource->handle));
      if (stage != 1 && stage != 3) {
        Require(resource != previous, "Environment change retained old State content: stage=" + std::to_string(stage));
      }
      retained->layout(context);
      Require(resource == retained->getStateData().preparedText, "Unchanged environment replaced State content");
      previous = resource;
    }
  }
}

void CheckConcurrentMeasurement(float density) {
  auto contextContainer = std::make_shared<ContextContainer>();
  ComponentDescriptorProviderRegistry providers;
  providers.add(concreteComponentDescriptorProvider<RNTextEngineTextViewComponentDescriptor>());
  auto registry = providers.createComponentDescriptorRegistry(ComponentDescriptorParameters{
      .eventDispatcher = {}, .contextContainer = contextContainer, .flavor = nullptr});
  const auto context = BuildFabricLayoutContext(density);
  const TextStyleFixture style{.fontSize = 17, .lineHeight = 24};
  const auto buildNode = [&](bool nested) {
    auto element = Element<RNTextEngineTextViewShadowNode>().surfaceId(0)
        .props(BuildTextViewProps("Concurrent text measurements must preserve wrapping, font metrics, and prepared handle lifetime across revisions.", style, 260));
    if (nested) {
      element.children({Element<RNTextEngineTextViewShadowNode>().surfaceId(0)
          .props(BuildTextViewProps(" Nested emphasis with more wrapping.",
              {.fontSize = 23, .lineHeight = 29, .fontWeight = "700"}, 260))});
    }
    return BuildBenchmarkShadowNode(registry, element);
  };
  for (bool nested : {false, true}) {
    auto reference = buildNode(nested);
    std::vector<LayoutConstraints> constraints;
    std::vector<Size> expected;
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
          jni::ThreadScope attached;
          while (!start.load()) std::this_thread::yield();
          for (int iteration = 0; iteration < 128; ++iteration) {
            auto clone = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(source->clone({}));
            const auto &node = worker == 0 ? source : clone;
            const auto index = (iteration * 7 + worker * 11) % constraints.size();
            if (node->measureContent(context, constraints[index]) != expected[index]) {
              matches.store(false);
            }
          }
        });
      }
      start.store(true);
      for (auto &worker : workers) worker.join();
      Require(matches.load(), "Concurrent geometry differs: nested=" + std::to_string(nested) +
          " warm=" + std::to_string(warm));
    }
  }
  for (bool nested : {false, true}) {
    auto source = buildNode(nested);
    const auto constraints = BuildLayoutConstraints(120);
    source->measureContent(context, constraints);
    source->layout(context);
    const auto resource = source->getStateData().preparedText;
    auto props = std::make_shared<RNTextEngineTextViewProps>(source->getConcreteProps());
    props->opacity = 0.5;
    props->selectable = true;
    props->textDecorationLine = "underline";
    auto unchanged = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(source->clone({.props = props}));
    unchanged->layout(context);
    Require(unchanged->getStateData().preparedText == resource, "Drawing props replaced prepared content");
    props = std::make_shared<RNTextEngineTextViewProps>(*props);
    props->numberOfLines = 1;
    props->ellipsizeMode = "tail";
    auto truncated = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(unchanged->clone({.props = props}));
    const auto size = truncated->measureContent(context, constraints);
    truncated->layout(context);
    Require(truncated->getStateData().preparedText == resource, "Layout options replaced prepared content");
    const auto expected = rntextengine::measurePreparedTextMeasurementLayout(resource->handle, 120, 1, "tail", false);
    Require(size == expected, "Layout option change reused stale dimensions");
    props = std::make_shared<RNTextEngineTextViewProps>(*props);
    props->fontSize = 31;
    auto changed = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(truncated->clone({.props = props}));
    changed->layout(context);
    Require(changed->getStateData().preparedText != resource, "Typography change reused prepared content");
  }
  auto nested = buildNode(true);
  nested->layout(context);
  Require(nested->getStateData().preparedText != nullptr, "Prepared nested content was not published");
  const auto nestedState = nested->getState();
  auto unchanged = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(
      nested->clone({.props = nested->getProps()}));
  unchanged->layout(context);
  Require(unchanged->getState() == nestedState, "Unchanged nested payload was published again");
  auto childProps = std::make_shared<RNTextEngineTextViewProps>(
      static_cast<const RNTextEngineTextViewShadowNode&>(*nested->getChildren().front()).getConcreteProps());
  childProps->opacity = 0.25;
  childProps->textDecorationLine = "underline";
  auto child = nested->getChildren().front()->clone({.props = childProps});
  auto childUpdate = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(nested->clone({
      .children = std::make_shared<const std::vector<std::shared_ptr<const ShadowNode>>>(
          std::vector<std::shared_ptr<const ShadowNode>>{child})}));
  childUpdate->layout(context);
  Require(childUpdate->getState() == nestedState, "A child's drawing props replaced the parent's prepared content");
  childProps = std::make_shared<RNTextEngineTextViewProps>(*childProps);
  childProps->fontSize = 33;
  child = child->clone({.props = childProps});
  auto childTypography = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(childUpdate->clone({
      .children = std::make_shared<const std::vector<std::shared_ptr<const ShadowNode>>>(
          std::vector<std::shared_ptr<const ShadowNode>>{child})}));
  childTypography->layout(context);
  Require(childTypography->getStateData().preparedText != nested->getStateData().preparedText,
      "A child's typography change retained the parent's prepared content");
  auto flat = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(nested->clone({
      .children = std::make_shared<const std::vector<std::shared_ptr<const ShadowNode>>>()}));
  flat->layout(context);
  Require(flat->getStateData().preparedText &&
      flat->getStateData().preparedText != nested->getStateData().preparedText,
      "Removing nested text retained stale prepared content");

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

void CheckPreparedContentState(jni::alias_ref<jobject> receiver, float density) {
  auto apply = receiver->getClass()->getMethod<void(ReadableNativeMap::javaobject,
      StateWrapper::javaobject, jstring, jint, jint)>("applyPreparedState");
  ComponentDescriptorProviderRegistry providers;
  providers.add(concreteComponentDescriptorProvider<RootComponentDescriptor>());
  providers.add(concreteComponentDescriptorProvider<RNTextEngineTextViewComponentDescriptor>());
  auto registry = providers.createComponentDescriptorRegistry(ComponentDescriptorParameters{
      .eventDispatcher = {}, .contextContainer = std::make_shared<ContextContainer>(), .flavor = nullptr});
  std::shared_ptr<RootShadowNode> root;
  std::shared_ptr<RNTextEngineTextViewProps> previousProps;
  for (int stage = 0; stage < 4; ++stage) {
    const std::string expected = stage == 0 ? "Initial 😀" : stage == 1 ? "" : "A😀 ZSS😀";
    auto props = BuildTextViewProps(stage >= 2 ? "a😀 " : expected, {.fontSize = 18, .lineHeight = 24}, 240);
    props->yogaStyle.setDimension(yoga::Dimension::Height, yoga::StyleSizeLength::points(80));
    auto element = Element<RNTextEngineTextViewShadowNode>().surfaceId(0).props(props);
    if (stage >= 2) {
      props->textTransform = "uppercase";
      auto child = BuildTextViewProps("zß😀", {.fontSize = stage == 2 ? 18.0 : 26.0, .lineHeight = 24}, 240);
      element.children({Element<RNTextEngineTextViewShadowNode>().surfaceId(0).props(child)});
    }
    auto next = BuildBenchmarkShadowNode(registry, element);
    if (root) {
      const auto &previousNode = root->getChildren().front();
      next = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(previousNode->clone({
          .props = props,
          .children = std::make_shared<const std::vector<std::shared_ptr<const ShadowNode>>>(next->getChildren()),
      }));
      root = std::static_pointer_cast<RootShadowNode>(root->ShadowNode::clone({
          .children = std::make_shared<const std::vector<std::shared_ptr<const ShadowNode>>>(
              std::vector<std::shared_ptr<const ShadowNode>>{next}),
      }));
    } else {
      root = BuildBenchmarkShadowNode(registry, Element<RootShadowNode>().surfaceId(0).tag(1)
          .props(BuildRootProps(320, density)));
      root->appendChild(next);
    }
    Require(root->layoutIfNeeded(), "Exact-sized updated root did not lay out");
    const auto &node = static_cast<const RNTextEngineTextViewShadowNode &>(*root->getChildren().front());
    Require(node.getStateData().preparedText != nullptr, "Exact-sized text did not publish prepared content");
    auto diff = ReadableNativeMap::newObjectCxxArgs(node.getProps()->getDiffProps(previousProps.get()));
    previousProps = props;
    auto state = StateWrapperImpl::newObjectJavaArgs();
    jni::cthis(state)->setState(node.getState());
    const auto &frame = node.getLayoutMetrics().frame;
    apply(receiver, diff.get(), state.get(), jni::make_jstring(expected).get(),
        std::round(frame.size.width * density), std::round(frame.size.height * density));
    root->sealRecursive();
  }
  auto checkColor = receiver->getClass()->getMethod<void(jlong, jint)>("checkPreparedColor");
  const auto context = BuildFabricLayoutContext(density);
  for (uint32_t alpha = 0; alpha <= 255; ++alpha) {
    const auto color = static_cast<int32_t>((alpha << 24) | 0x7FB3D9);
    auto child = BuildTextViewProps("B", {.fontSize = 18, .lineHeight = 24}, 240);
    child->color = SharedColor(color);
    auto node = BuildBenchmarkShadowNode(registry, Element<RNTextEngineTextViewShadowNode>().surfaceId(0)
        .props(BuildTextViewProps("A", {.fontSize = 18, .lineHeight = 24}, 240)).children({
            Element<RNTextEngineTextViewShadowNode>().surfaceId(0).props(child)}));
    node->layout(context);
    checkColor(receiver, static_cast<jlong>(node->getStateData().preparedText->handle), color);
  }

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
    JNIEnv *env, jobject, jobject manager, jfloat density, jint run, jboolean prepared) {
  try {
    return env->NewStringUTF(RunComparison(jni::make_global(manager), density, run, prepared).c_str());
  } catch (const std::exception &error) {
    env->ThrowNew(env->FindClass("java/lang/RuntimeException"), error.what());
    return nullptr;
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_rntextengine_RNTextEngineTextComparisonBenchmark_checkMeasurementBoundaries(JNIEnv* env, jobject, jfloat density) {
  try {
    CheckMeasurementBoundaries(density);
  } catch (const std::exception& error) {
    env->ThrowNew(env->FindClass("java/lang/RuntimeException"), error.what());
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_rntextengine_RNTextEngineTextComparisonBenchmark_checkConcurrentMeasurement(
    JNIEnv *env, jobject, jfloat density) {
  try {
    CheckConcurrentMeasurement(density);
  } catch (const std::exception &error) {
    env->ThrowNew(env->FindClass("java/lang/RuntimeException"), error.what());
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_rntextengine_RNTextEngineTextComparisonBenchmark_checkNestedFontScaling(
    JNIEnv *env, jobject, jfloat density, jdouble fontSize, jdouble lineHeight, jdouble letterSpacing) {
  try {
    CheckNestedFontScaling(density, fontSize, lineHeight, letterSpacing);
  } catch (const std::exception &error) {
    env->ThrowNew(env->FindClass("java/lang/RuntimeException"), error.what());
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_rntextengine_RNTextEngineTextComparisonBenchmark_checkTextEnvironment(JNIEnv* env, jobject receiver) {
  try {
    CheckTextEnvironment(jni::wrap_alias(receiver));
  } catch (const std::exception& error) {
    env->ThrowNew(env->FindClass("java/lang/RuntimeException"), error.what());
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_rntextengine_RNTextEngineTextComparisonBenchmark_checkPreparedContentState(
    JNIEnv *env, jobject receiver, jfloat density) {
  try {
    CheckPreparedContentState(jni::wrap_alias(receiver), density);
  } catch (const std::exception &error) {
    env->ThrowNew(env->FindClass("java/lang/RuntimeException"), error.what());
  }
}
