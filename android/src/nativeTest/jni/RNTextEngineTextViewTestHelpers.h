#pragma once

#include <react/renderer/components/RNTextEngineSpec/RNTextEngineTextViewShadowNode.h>
#include <react/renderer/componentregistry/ComponentDescriptorRegistry.h>
#include <react/renderer/components/root/RootShadowNode.h>
#include <react/renderer/element/Element.h>

#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

namespace rntextengine::test {

using namespace facebook;
using namespace facebook::react;

constexpr int kRunStyleHasFontSize = 1 << 2;

struct TextStyleFixture {
  double fontSize{16};
  double letterSpacing{0};
  double lineHeight{24};
  bool tabularNumbers{false};
  std::string fontStyle{};
  std::string fontWeight{"400"};
};

static void Require(bool condition, const std::string &message) {
  if (!condition) throw std::runtime_error(message);
}

static LayoutConstraints BuildLayoutConstraints(double width)
{
  return LayoutConstraints{
      .minimumSize = {.width = 0, .height = 0},
      .maximumSize = {.width = static_cast<Float>(width), .height = std::numeric_limits<Float>::infinity()},
      .layoutDirection = LayoutDirection::LeftToRight,
  };
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

static std::shared_ptr<ShadowNode> BuildShadowNode(
    const ComponentDescriptorRegistry::Shared &registry,
    const ElementFragment &fragment)
{
  const auto &componentDescriptor = registry->at(fragment.componentHandle);

  auto children = std::vector<std::shared_ptr<const ShadowNode>>{};
  children.reserve(fragment.children.size());
  for (const auto &child : fragment.children) {
    children.push_back(BuildShadowNode(registry, child));
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
static std::shared_ptr<ShadowNodeT> BuildShadowNode(
    const ComponentDescriptorRegistry::Shared &registry,
    Element<ShadowNodeT> element)
{
  return std::static_pointer_cast<ShadowNodeT>(
      BuildShadowNode(registry, static_cast<ElementFragment>(element)));
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

} // namespace rntextengine::test
