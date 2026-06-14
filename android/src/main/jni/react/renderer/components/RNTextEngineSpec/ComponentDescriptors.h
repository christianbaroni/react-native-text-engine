#pragma once

#include <react/renderer/componentregistry/ComponentDescriptorProviderRegistry.h>
#include <react/renderer/core/ConcreteComponentDescriptor.h>

#include <react/renderer/components/RNTextEngineSpec/ShadowNodes.h>

namespace facebook::react {

using RNTextEngineGlyphFieldViewComponentDescriptor =
    ConcreteComponentDescriptor<RNTextEngineGlyphFieldViewShadowNode>;
using RNTextEnginePreparedTextViewComponentDescriptor =
    ConcreteComponentDescriptor<RNTextEnginePreparedTextViewShadowNode>;
using RNTextEngineTextViewComponentDescriptor =
    ConcreteComponentDescriptor<RNTextEngineTextViewShadowNode>;

void RNTextEngineSpec_registerComponentDescriptorsFromCodegen(
    std::shared_ptr<const ComponentDescriptorProviderRegistry> registry);

} // namespace facebook::react
