#pragma once

#include "EventEmitters.h"
#include "Props.h"
#include <react/renderer/components/view/ConcreteViewShadowNode.h>

namespace facebook::react {

inline constexpr char RNPretextGlyphFieldViewComponentName[] = "RNPretextGlyphFieldView";

using RNPretextGlyphFieldViewShadowNode =
    ConcreteViewShadowNode<RNPretextGlyphFieldViewComponentName, RNPretextGlyphFieldViewProps>;

} // namespace facebook::react
