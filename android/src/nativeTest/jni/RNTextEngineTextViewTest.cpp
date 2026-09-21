#include "RNTextEngineTextViewTestHelpers.h"

#include <jni.h>
#include <fbjni/fbjni.h>
#include <react/fabric/StateWrapperImpl.h>
#include <react/renderer/componentregistry/ComponentDescriptorProviderRegistry.h>
#include <react/renderer/components/RNTextEngineSpec/ComponentDescriptors.h>
#include <react/renderer/components/root/RootComponentDescriptor.h>
#include <react/utils/ContextContainer.h>

#include <atomic>
#include <cmath>
#include <thread>

using namespace facebook;
using namespace facebook::react;
using namespace rntextengine::test;

namespace {

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
        auto flat = BuildShadowNode(registry,
            Element<RNTextEngineTextViewShadowNode>().surfaceId(0).props(flatProps));
        auto nested = BuildShadowNode(registry,
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
    return BuildShadowNode(registry, Element<RNTextEngineTextViewShadowNode>().surfaceId(0)
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
  auto fontScale = receiver->getClass()->getMethod<jfloat()>("environmentFontScale");
  ComponentDescriptorProviderRegistry providers;
  providers.add(concreteComponentDescriptorProvider<RootComponentDescriptor>());
  providers.add(concreteComponentDescriptorProvider<RNTextEngineTextViewComponentDescriptor>());
  auto registry = providers.createComponentDescriptorRegistry(ComponentDescriptorParameters{
      .eventDispatcher = {}, .contextContainer = std::make_shared<ContextContainer>(), .flavor = nullptr});
  auto build = [&](bool nested, bool fixedSize = false) {
    auto props = BuildTextViewProps(nested ? "initial " : "initial child", {.fontSize = 18, .lineHeight = 0}, 120);
    if (fixedSize) props->yogaStyle.setDimension(yoga::Dimension::Height, yoga::StyleSizeLength::points(100));
    else props->yogaStyle.setDimension(yoga::Dimension::Width, yoga::StyleSizeLength::ofAuto());
    props->allowFontScaling = true;
    props->textTransform = "uppercase";
    auto element = Element<RNTextEngineTextViewShadowNode>().surfaceId(0).props(props);
    if (nested) {
      auto child = BuildTextViewProps("child", {.fontSize = 23, .lineHeight = 0}, 120);
      child->allowFontScaling = false;
      element.children({Element<RNTextEngineTextViewShadowNode>().surfaceId(0).props(child)});
    }
    return BuildShadowNode(registry, element);
  };
  update(receiver, 0);
  for (bool nested : {false, true}) {
    update(receiver, 0);
    auto retained = build(nested);
    std::shared_ptr<const rntextengine::PreparedTextHandle> previous;
    for (int stage = 0; stage < 8; ++stage) {
      const auto previousRevision = retained;
      const auto previousSize = previousRevision->measureContent(
          BuildFabricLayoutContext(1), BuildLayoutConstraints(120));
      const float density = update(receiver, stage);
      const auto context = BuildFabricLayoutContext(density);
      retained = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(previousRevision->clone({}));
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
      Require(previousRevision->measureContent(context, BuildLayoutConstraints(120)) == previousSize,
          "New environment changed an admitted revision's measurement");
      Require(previousRevision->getStateData().preparedText == previous,
          "New environment changed an admitted revision's State");
      previous = resource;
    }

    for (bool exactSize : {false, true}) {
      std::shared_ptr<RootShadowNode> root;
      for (int stage = 0; stage < 8; ++stage) {
        const float density = update(receiver, stage);
        const float width = stage % 2 ? 160 : 280;
        auto props = BuildRootProps(width, density);
        props->layoutContext.fontSizeMultiplier = fontScale(receiver);
        auto freshRoot = [&] {
          auto result = BuildShadowNode(registry,
              Element<RootShadowNode>().surfaceId(0).tag(1).props(props));
          result->appendChild(build(nested, exactSize));
          return result;
        };
        const auto previousRoot = root;
        root = root ? std::static_pointer_cast<RootShadowNode>(root->ShadowNode::clone({.props = props}))
                    : freshRoot();
        const auto expected = freshRoot();
        Require(root->layoutIfNeeded() && expected->layoutIfNeeded(), "Environment update did not lay out");
        const auto& node = static_cast<const RNTextEngineTextViewShadowNode&>(*root->getChildren().front());
        const auto& reference = static_cast<const RNTextEngineTextViewShadowNode&>(*expected->getChildren().front());
        Require(node.getLayoutMetrics().frame == reference.getLayoutMetrics().frame,
            "Updated Fabric root retained stale geometry: stage=" + std::to_string(stage));
        check(receiver, static_cast<jlong>(node.getStateData().preparedText->handle));
        if (previousRoot) {
          Require(root->getChildren().front() != previousRoot->getChildren().front(),
              "Re-layout reused a sealed child revision");
          if (!exactSize) {
            const auto& oldNode = static_cast<const RNTextEngineTextViewShadowNode&>(*previousRoot->getChildren().front());
            const auto constraints = BuildLayoutConstraints(width + 40);
            const auto actualSize = oldNode.measure(props->layoutContext, constraints);
            const auto expectedSize = reference.measure(props->layoutContext, constraints);
            Require(actualSize == expectedSize,
                "Standalone measurement mismatch: stage=" + std::to_string(stage) +
                    " nested=" + std::to_string(nested) + " exact=" + std::to_string(exactSize) +
                    " actual=" + std::to_string(actualSize.width) + "," + std::to_string(actualSize.height) +
                    " expected=" + std::to_string(expectedSize.width) + "," + std::to_string(expectedSize.height));
          }
        }
        root->sealRecursive();
      }
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
    return BuildShadowNode(registry, element);
  };
  for (bool nested : {false, true}) {
    auto reference = buildNode(nested);
    std::vector<LayoutConstraints> constraints;
    std::vector<Size> expected;
    for (int index = 0; index < 32; ++index) {
      constraints.push_back(BuildLayoutConstraints(80 + index * 7));
      expected.push_back(reference->measureContent(context, constraints.back()));
    }
    auto retained = buildNode(nested);
    retained->measureContent(context, constraints.front());
    retained->layout(context);
    for (int index = 0; index < 4096; ++index) {
      auto props = std::make_shared<RNTextEngineTextViewProps>(retained->getConcreteProps());
      props->numberOfLines = index % 3;
      props->anchorToCapHeight = index % 2 == 0;
      retained = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(retained->clone({.props = props}));
      const auto query = BuildLayoutConstraints(80 + index * 0.25f);
      auto freshNode = buildNode(nested);
      freshNode = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(freshNode->clone({.props = props}));
      const auto actual = retained->measureContent(context, query);
      const auto fresh = freshNode->measureContent(context, query);
      Require(actual == fresh, "Width history changed geometry");
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
    auto next = BuildShadowNode(registry, element);
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
      root = BuildShadowNode(registry, Element<RootShadowNode>().surfaceId(0).tag(1)
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
    auto node = BuildShadowNode(registry, Element<RNTextEngineTextViewShadowNode>().surfaceId(0)
        .props(BuildTextViewProps("A", {.fontSize = 18, .lineHeight = 24}, 240)).children({
            Element<RNTextEngineTextViewShadowNode>().surfaceId(0).props(child)}));
    node->layout(context);
    checkColor(receiver, static_cast<jlong>(node->getStateData().preparedText->handle), color);
  }

}

} // namespace

extern "C" JNIEXPORT void JNICALL
Java_com_rntextengine_RNTextEngineTextViewTest_checkTextEnvironment(JNIEnv* env, jobject receiver) {
  try {
    CheckTextEnvironment(jni::wrap_alias(receiver));
  } catch (const std::exception& error) {
    env->ThrowNew(env->FindClass("java/lang/RuntimeException"), error.what());
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_rntextengine_RNTextEngineTextViewTest_checkMeasurementBoundaries(JNIEnv* env, jobject, jfloat density) {
  try {
    CheckMeasurementBoundaries(density);
  } catch (const std::exception& error) {
    env->ThrowNew(env->FindClass("java/lang/RuntimeException"), error.what());
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_rntextengine_RNTextEngineTextViewTest_checkConcurrentMeasurement(
    JNIEnv *env, jobject, jfloat density) {
  try {
    CheckConcurrentMeasurement(density);
  } catch (const std::exception &error) {
    env->ThrowNew(env->FindClass("java/lang/RuntimeException"), error.what());
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_rntextengine_RNTextEngineTextViewTest_checkNestedFontScaling(
    JNIEnv *env, jobject, jfloat density, jdouble fontSize, jdouble lineHeight, jdouble letterSpacing) {
  try {
    CheckNestedFontScaling(density, fontSize, lineHeight, letterSpacing);
  } catch (const std::exception &error) {
    env->ThrowNew(env->FindClass("java/lang/RuntimeException"), error.what());
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_rntextengine_RNTextEngineTextViewTest_checkPreparedContentState(
    JNIEnv *env, jobject receiver, jfloat density) {
  try {
    CheckPreparedContentState(jni::wrap_alias(receiver), density);
  } catch (const std::exception &error) {
    env->ThrowNew(env->FindClass("java/lang/RuntimeException"), error.what());
  }
}
