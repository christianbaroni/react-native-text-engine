#pragma once

#include "EventEmitters.h"
#include "Props.h"
#include <react/renderer/components/view/ConcreteViewShadowNode.h>

namespace facebook::react {

inline constexpr char RNPretextTextViewComponentName[] = "RNPretextTextView";

using RNPretextTextViewShadowNode = ConcreteViewShadowNode<RNPretextTextViewComponentName, RNPretextTextViewProps>;

} // namespace facebook::react
