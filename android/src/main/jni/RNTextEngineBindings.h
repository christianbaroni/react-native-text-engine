#pragma once

#include <jni.h>
#include <jsi/jsi.h>

namespace rntextengine {
void cleanup(JNIEnv* env);
double currentFontScaleMultiplier();
void install(facebook::jsi::Runtime& runtime);
} // namespace rntextengine
