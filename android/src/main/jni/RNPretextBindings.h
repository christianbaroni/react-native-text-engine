#pragma once

#include <jni.h>
#include <jsi/jsi.h>

namespace rnpretext {
void cleanup(JNIEnv* env);
void install(facebook::jsi::Runtime& runtime, JNIEnv* env, jobject context);
} // namespace rnpretext
