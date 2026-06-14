#pragma once

#include <react/renderer/components/RNTextEngineSpec/EventEmitters.h>
#include <react/renderer/components/RNTextEngineSpec/Props.h>
#include <react/renderer/components/RNTextEngineSpec/States.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>

#include "RNTextEngineTextViewShadowNode.h"

namespace facebook::react {

extern const char RNTextEngineGlyphFieldViewComponentName[];
using RNTextEngineGlyphFieldViewShadowNode = ConcreteViewShadowNode<
    RNTextEngineGlyphFieldViewComponentName,
    RNTextEngineGlyphFieldViewProps,
    RNTextEngineGlyphFieldViewEventEmitter,
    RNTextEngineGlyphFieldViewState>;

extern const char RNTextEnginePreparedTextViewComponentName[];
using RNTextEnginePreparedTextViewShadowNode = ConcreteViewShadowNode<
    RNTextEnginePreparedTextViewComponentName,
    RNTextEnginePreparedTextViewProps,
    RNTextEnginePreparedTextViewEventEmitter,
    RNTextEnginePreparedTextViewState>;

} // namespace facebook::react
