#pragma once

#include "EventEmitters.h"
#include "Props.h"
#include <react/renderer/components/view/ConcreteViewShadowNode.h>

namespace facebook::react {

inline constexpr char RNPretextPreparedTextViewComponentName[] = "RNPretextPreparedTextView";

using RNPretextPreparedTextViewShadowNode =
    ConcreteViewShadowNode<RNPretextPreparedTextViewComponentName, RNPretextPreparedTextViewProps>;

} // namespace facebook::react
