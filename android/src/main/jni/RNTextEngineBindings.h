#pragma once

#include <jni.h>
#include <jsi/jsi.h>

namespace rntextengine {
void cleanup(JNIEnv* env);
void install(facebook::jsi::Runtime& runtime);
} // namespace rntextengine
