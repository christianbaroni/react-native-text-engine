#pragma once

#ifdef RCT_NEW_ARCH_ENABLED

#import <UIKit/UIKit.h>
#import "../../../ios/RNTextEngineTextViewShadowNode.h"
#import <react/renderer/componentregistry/ComponentDescriptorProviderRegistry.h>
#import <react/renderer/componentregistry/ComponentDescriptorRegistry.h>
#import <react/renderer/components/root/RootComponentDescriptor.h>
#import <React/RCTComponentViewProtocol.h>
#import <react/renderer/components/text/ParagraphComponentDescriptor.h>
#import <react/renderer/components/text/RawTextComponentDescriptor.h>
#import <react/renderer/components/text/TextComponentDescriptor.h>
#import <react/renderer/components/view/ViewComponentDescriptor.h>
#import <react/renderer/element/Element.h>
#import <react/renderer/textlayoutmanager/TextLayoutManager.h>
#import <react/utils/ContextContainer.h>

#include <limits>
#include <memory>
#include <string>
#include <vector>

namespace rntextengine::test {

using namespace facebook;
using namespace facebook::react;

struct TextStyleFixture {
  double fontSize{17};
  double letterSpacing{0};
  double lineHeight{0};
  bool tabularNumbers{false};
  std::string fontStyle{};
  std::string fontWeight{"400"};
};

static LayoutConstraints BuildLayoutConstraints(double width)
{
  return LayoutConstraints{
      .minimumSize = {.width = 0, .height = 0},
      .maximumSize = {.width = static_cast<Float>(width), .height = std::numeric_limits<Float>::infinity()},
      .layoutDirection = LayoutDirection::LeftToRight,
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

static ComponentDescriptorRegistry::Shared BuildComponentDescriptorRegistry()
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
  providerRegistry.add([NSClassFromString(@"RNTextEnginePreparedTextViewComponentView") componentDescriptorProvider]);

  auto descriptorRegistry = providerRegistry.createComponentDescriptorRegistry(ComponentDescriptorParameters{
      .eventDispatcher = {},
      .contextContainer = std::move(contextContainer),
      .flavor = nullptr,
  });

  return descriptorRegistry;
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

static void DisplayLayers(CALayer *layer)
{
  [layer displayIfNeeded];
  for (CALayer *child in layer.sublayers) DisplayLayers(child);
}

} // namespace rntextengine::test

#endif
