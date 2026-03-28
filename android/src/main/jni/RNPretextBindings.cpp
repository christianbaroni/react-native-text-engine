#include "RNPretextBindings.h"

#include <android/log.h>
#include <cmath>
#include <cstring>
#include <limits>
#include <string>
#include <vector>

#ifndef RNPRETEXT_HAS_WORKLETS
#define RNPRETEXT_HAS_WORKLETS 0
#endif

#if RNPRETEXT_HAS_WORKLETS
#include <worklets/WorkletRuntime/WorkletRuntime.h>
#endif

using namespace facebook::jsi;

#define LOG_TAG "RNPretext"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace rnpretext {
namespace {

using Handle = long long;

struct StyleArgs {
  bool allowFontScaling = false;
  bool includeFontPadding = true;
  bool tabularNumbers = false;
  double fontSize = std::numeric_limits<double>::quiet_NaN();
  double letterSpacing = std::numeric_limits<double>::quiet_NaN();
  double lineHeight = std::numeric_limits<double>::quiet_NaN();
  std::string fontFamily;
  std::string fontStyle;
  std::string fontWeight;
  std::string textBreakStrategy;
};

struct LayoutArgs {
  double width = 0;
  int maxLines = 0;
  std::string ellipsizeMode;
};

JavaVM* jvm_ = nullptr;
jclass bindingsClass_ = nullptr;

jmethodID initializeMethod_ = nullptr;
jmethodID cleanupMethod_ = nullptr;
jmethodID prepareMethod_ = nullptr;
jmethodID prepareBatchMethod_ = nullptr;
jmethodID releaseMethod_ = nullptr;
jmethodID releaseManyMethod_ = nullptr;
jmethodID measureWidthMethod_ = nullptr;
jmethodID measureMethod_ = nullptr;
jmethodID measureBatchMethod_ = nullptr;
jmethodID layoutMethod_ = nullptr;
jmethodID layoutBatchMethod_ = nullptr;
jmethodID layoutNextLineMethod_ = nullptr;
jmethodID layoutLinesMethod_ = nullptr;

constexpr int PACKED_LAYOUT_SIZE = 4;
constexpr int PACKED_LINE_SIZE = 4;

void throwJSError(Runtime& runtime, const char* message) {
  throw JSError(runtime, message);
}

void clearPendingException(JNIEnv* env, Runtime& runtime, const char* fallback) {
  if (!env->ExceptionCheck()) return;
  env->ExceptionDescribe();
  env->ExceptionClear();
  throwJSError(runtime, fallback);
}

JNIEnv* getEnv(bool& needsDetach) {
  JNIEnv* env = nullptr;
  needsDetach = false;

  jint result = jvm_->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
  if (result == JNI_EDETACHED) {
    if (jvm_->AttachCurrentThread(&env, nullptr) != JNI_OK) return nullptr;
    needsDetach = true;
    return env;
  }
  return result == JNI_OK ? env : nullptr;
}

void initializeIfNeeded(JNIEnv* env, jobject context) {
  if (bindingsClass_ != nullptr) return;

  env->GetJavaVM(&jvm_);

  jclass localClass = env->FindClass("com/rnpretext/RNPretextBindings");
  bindingsClass_ = reinterpret_cast<jclass>(env->NewGlobalRef(localClass));
  env->DeleteLocalRef(localClass);

  initializeMethod_ = env->GetStaticMethodID(bindingsClass_, "initialize", "(Lcom/facebook/react/bridge/ReactApplicationContext;)V");
  cleanupMethod_ = env->GetStaticMethodID(bindingsClass_, "cleanup", "()V");
  prepareMethod_ = env->GetStaticMethodID(
      bindingsClass_,
      "prepare",
      "(Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;)J");
  prepareBatchMethod_ = env->GetStaticMethodID(
      bindingsClass_,
      "prepareBatch",
      "([Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;)[J");
  releaseMethod_ = env->GetStaticMethodID(bindingsClass_, "release", "(J)V");
  releaseManyMethod_ = env->GetStaticMethodID(bindingsClass_, "releaseMany", "([J)V");
  measureWidthMethod_ = env->GetStaticMethodID(
      bindingsClass_,
      "measureWidth",
      "(Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;)D");
  measureMethod_ = env->GetStaticMethodID(
      bindingsClass_,
      "measure",
      "(Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;DILjava/lang/String;)[D");
  measureBatchMethod_ = env->GetStaticMethodID(
      bindingsClass_,
      "measureBatch",
      "([Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;DILjava/lang/String;)[D");
  layoutMethod_ = env->GetStaticMethodID(bindingsClass_, "layout", "(JDILjava/lang/String;)[D");
  layoutBatchMethod_ = env->GetStaticMethodID(bindingsClass_, "layoutBatch", "([JDILjava/lang/String;)[D");
  layoutNextLineMethod_ = env->GetStaticMethodID(bindingsClass_, "layoutNextLine", "(JID)[D");
  layoutLinesMethod_ = env->GetStaticMethodID(bindingsClass_, "layoutLines", "(JDILjava/lang/String;)[D");

  env->CallStaticVoidMethod(bindingsClass_, initializeMethod_, context);
}

jstring toJString(JNIEnv* env, const std::string& value) {
  return value.empty() ? nullptr : env->NewStringUTF(value.c_str());
}

StyleArgs parseStyle(Runtime& runtime, const Value* arguments, size_t index, size_t count) {
  StyleArgs style;
  if (index >= count || arguments[index].isUndefined() || arguments[index].isNull()) return style;
  if (!arguments[index].isObject()) return style;

  Object object = arguments[index].asObject(runtime);

  auto readBool = [&](const char* name, bool& target) {
    if (!object.hasProperty(runtime, name)) return;
    Value value = object.getProperty(runtime, name);
    if (value.isBool()) target = value.getBool();
  };

  auto readNumber = [&](const char* name, double& target) {
    if (!object.hasProperty(runtime, name)) return;
    Value value = object.getProperty(runtime, name);
    if (value.isNumber()) target = value.asNumber();
  };

  auto readString = [&](const char* name, std::string& target) {
    if (!object.hasProperty(runtime, name)) return;
    Value value = object.getProperty(runtime, name);
    if (value.isString()) target = value.asString(runtime).utf8(runtime);
  };

  readBool("allowFontScaling", style.allowFontScaling);
  readBool("includeFontPadding", style.includeFontPadding);
  readBool("tabularNumbers", style.tabularNumbers);
  readNumber("fontSize", style.fontSize);
  readNumber("letterSpacing", style.letterSpacing);
  readNumber("lineHeight", style.lineHeight);
  readString("fontFamily", style.fontFamily);
  readString("fontStyle", style.fontStyle);
  readString("fontWeight", style.fontWeight);
  readString("textBreakStrategy", style.textBreakStrategy);

  return style;
}

LayoutArgs parseLayout(Runtime& runtime, const Value* arguments, size_t index, size_t count) {
  if (index >= count || !arguments[index].isObject()) {
    throwJSError(runtime, "RNPretext: layout options must be an object.");
  }

  LayoutArgs layout;
  Object object = arguments[index].asObject(runtime);
  if (!object.hasProperty(runtime, "width")) {
    throwJSError(runtime, "RNPretext: layout options must include a width.");
  }

  Value width = object.getProperty(runtime, "width");
  if (!width.isNumber()) {
    throwJSError(runtime, "RNPretext: layout width must be a number.");
  }
  layout.width = width.asNumber();

  if (object.hasProperty(runtime, "maxLines")) {
    Value maxLines = object.getProperty(runtime, "maxLines");
    if (maxLines.isNumber()) layout.maxLines = static_cast<int>(maxLines.asNumber());
  }

  if (object.hasProperty(runtime, "ellipsizeMode")) {
    Value mode = object.getProperty(runtime, "ellipsizeMode");
    if (mode.isString()) layout.ellipsizeMode = mode.asString(runtime).utf8(runtime);
  }

  return layout;
}

std::vector<std::string> parseTextArray(Runtime& runtime, const Value& value) {
  if (!value.isObject() || !value.asObject(runtime).isArray(runtime)) {
    throwJSError(runtime, "RNPretext: expected an array of strings.");
  }

  Array array = value.asObject(runtime).asArray(runtime);
  std::vector<std::string> texts;
  texts.reserve(array.size(runtime));

  for (size_t i = 0; i < array.size(runtime); i++) {
    Value item = array.getValueAtIndex(runtime, i);
    if (!item.isString()) {
      throwJSError(runtime, "RNPretext: batch text input must contain strings only.");
    }
    texts.push_back(item.asString(runtime).utf8(runtime));
  }

  return texts;
}

std::vector<Handle> parseHandleArray(Runtime& runtime, const Value& value) {
  if (!value.isObject() || !value.asObject(runtime).isArray(runtime)) {
    throwJSError(runtime, "RNPretext: expected an array of prepared text handles.");
  }

  Array array = value.asObject(runtime).asArray(runtime);
  std::vector<Handle> handles;
  handles.reserve(array.size(runtime));

  for (size_t i = 0; i < array.size(runtime); i++) {
    Value item = array.getValueAtIndex(runtime, i);
    if (!item.isNumber()) {
      throwJSError(runtime, "RNPretext: prepared text handles must be numeric.");
    }
    handles.push_back(static_cast<Handle>(item.asNumber()));
  }

  return handles;
}

jobjectArray makeJavaStringArray(JNIEnv* env, const std::vector<std::string>& values) {
  jclass stringClass = env->FindClass("java/lang/String");
  jobjectArray array = env->NewObjectArray(static_cast<jsize>(values.size()), stringClass, nullptr);
  env->DeleteLocalRef(stringClass);
  for (size_t i = 0; i < values.size(); i++) {
    jstring item = env->NewStringUTF(values[i].c_str());
    env->SetObjectArrayElement(array, static_cast<jsize>(i), item);
    env->DeleteLocalRef(item);
  }
  return array;
}

jlongArray makeJavaLongArray(JNIEnv* env, const std::vector<Handle>& values) {
  jlongArray array = env->NewLongArray(static_cast<jsize>(values.size()));
  std::vector<jlong> data(values.begin(), values.end());
  env->SetLongArrayRegion(array, 0, static_cast<jsize>(data.size()), data.data());
  return array;
}

std::vector<double> toDoubleVector(JNIEnv* env, jdoubleArray array) {
  if (array == nullptr) return {};
  jsize length = env->GetArrayLength(array);
  std::vector<double> values(length);
  env->GetDoubleArrayRegion(array, 0, length, values.data());
  return values;
}

std::vector<Handle> toHandleVector(JNIEnv* env, jlongArray array) {
  if (array == nullptr) return {};
  jsize length = env->GetArrayLength(array);
  std::vector<jlong> values(length);
  env->GetLongArrayRegion(array, 0, length, values.data());
  return std::vector<Handle>(values.begin(), values.end());
}

Object buildLayoutObject(Runtime& runtime, const std::vector<double>& packed, size_t offset) {
  Object result(runtime);
  result.setProperty(runtime, "width", packed[offset + 0]);
  result.setProperty(runtime, "height", packed[offset + 1]);
  result.setProperty(runtime, "lineCount", packed[offset + 2]);
  result.setProperty(runtime, "lastLineWidth", packed[offset + 3]);
  return result;
}

Value buildLayoutLinesObject(Runtime& runtime, const std::vector<double>& packed) {
  if (packed.size() < PACKED_LAYOUT_SIZE) {
    throwJSError(runtime, "RNPretext: native layoutLines() returned an invalid payload.");
  }
  Object result = buildLayoutObject(runtime, packed, 0);
  size_t lineCount = static_cast<size_t>(packed[2]);
  Array lines(runtime, lineCount);

  for (size_t index = 0; index < lineCount; index++) {
    size_t offset = PACKED_LAYOUT_SIZE + index * PACKED_LINE_SIZE;
    Object line(runtime);
    line.setProperty(runtime, "index", static_cast<double>(index));
    line.setProperty(runtime, "start", packed[offset + 0]);
    line.setProperty(runtime, "end", packed[offset + 1]);
    line.setProperty(runtime, "width", packed[offset + 2]);
    line.setProperty(runtime, "bottom", packed[offset + 3]);
    lines.setValueAtIndex(runtime, index, line);
  }

  result.setProperty(runtime, "lines", lines);
  return result;
}

Value buildNextLineObject(Runtime& runtime, const std::vector<double>& packed) {
  if (packed.empty()) return Value::null();
  if (packed.size() != PACKED_LINE_SIZE) {
    throwJSError(runtime, "RNPretext: native next-line layout returned an invalid payload.");
  }

  Object line(runtime);
  line.setProperty(runtime, "start", packed[0]);
  line.setProperty(runtime, "end", packed[1]);
  line.setProperty(runtime, "width", packed[2]);
  line.setProperty(runtime, "bottom", packed[3]);
  return line;
}

Array buildLayoutBatchArray(Runtime& runtime, const std::vector<double>& packed) {
  if (packed.size() % PACKED_LAYOUT_SIZE != 0) {
    throwJSError(runtime, "RNPretext: native batch layout returned an invalid payload.");
  }
  size_t itemCount = packed.size() / PACKED_LAYOUT_SIZE;
  Array results(runtime, itemCount);
  for (size_t index = 0; index < itemCount; index++) {
    results.setValueAtIndex(runtime, index, buildLayoutObject(runtime, packed, index * PACKED_LAYOUT_SIZE));
  }
  return results;
}

Array buildHandleArray(Runtime& runtime, const std::vector<Handle>& handles) {
  Array array(runtime, handles.size());
  for (size_t index = 0; index < handles.size(); index++) {
    array.setValueAtIndex(runtime, index, static_cast<double>(handles[index]));
  }
  return array;
}

Runtime* extractRuntimeFromToken(Runtime& runtime, const Value& value) {
  if (!value.isObject()) {
    throwJSError(runtime, "RNPretext: runtime token must be an ArrayBuffer.");
  }

  Object object = value.asObject(runtime);
  if (!object.isArrayBuffer(runtime)) {
    throwJSError(runtime, "RNPretext: runtime token must be an ArrayBuffer.");
  }

  ArrayBuffer buffer = object.getArrayBuffer(runtime);
  if (buffer.size(runtime) < sizeof(uintptr_t)) {
    throwJSError(runtime, "RNPretext: runtime token had an invalid size.");
  }

  uintptr_t pointer = 0;
  std::memcpy(&pointer, buffer.data(runtime), sizeof(uintptr_t));
  return reinterpret_cast<Runtime*>(pointer);
}

template <typename Fn>
void withStyle(JNIEnv* env, const StyleArgs& style, Fn&& fn) {
  jstring fontFamily = toJString(env, style.fontFamily);
  jstring fontWeight = toJString(env, style.fontWeight);
  jstring fontStyle = toJString(env, style.fontStyle);
  jstring textBreakStrategy = toJString(env, style.textBreakStrategy);

  fn(fontFamily, fontWeight, fontStyle, textBreakStrategy);

  if (fontFamily) env->DeleteLocalRef(fontFamily);
  if (fontWeight) env->DeleteLocalRef(fontWeight);
  if (fontStyle) env->DeleteLocalRef(fontStyle);
  if (textBreakStrategy) env->DeleteLocalRef(textBreakStrategy);
}

} // namespace

void cleanup(JNIEnv* env) {
  if (!bindingsClass_) return;
  env->CallStaticVoidMethod(bindingsClass_, cleanupMethod_);
  if (env->ExceptionCheck()) env->ExceptionClear();
  env->DeleteGlobalRef(bindingsClass_);
  bindingsClass_ = nullptr;
}

void install(Runtime& runtime, JNIEnv* env, jobject context) {
  initializeIfNeeded(env, context);

  auto installFunction = [&](const char* name, unsigned int argCount, auto fn) {
    runtime.global().setProperty(
        runtime,
        name,
        Function::createFromHostFunction(runtime, PropNameID::forAscii(runtime, name), argCount, fn));
  };

  installFunction(
      "__RNPretextInstallRuntime",
      1,
      [&](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throwJSError(runtime, "RNPretext: installRuntime() requires a runtime token.");
        }

        Runtime* targetRuntime = extractRuntimeFromToken(runtime, arguments[0]);
        if (targetRuntime == nullptr) return Value(false);

        rnpretext::install(*targetRuntime, env, context);
        return Value(true);
      });

#if RNPRETEXT_HAS_WORKLETS
  installFunction(
      "__RNPretextInstallWorkletRuntime",
      1,
      [&](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isObject()) {
          throwJSError(
              runtime,
              "RNPretext: installWorkletRuntime() requires a WorkletRuntime.");
        }

        std::shared_ptr<worklets::WorkletRuntime> workletRuntime;
        try {
          workletRuntime =
              worklets::extractWorkletRuntime(runtime, arguments[0]);
        } catch (...) {
          throwJSError(
              runtime,
              "RNPretext: installWorkletRuntime() requires a WorkletRuntime.");
        }

        if (!workletRuntime) return Value(false);

        rnpretext::install(workletRuntime->getJSIRuntime(), env, context);
        return Value(true);
      });
#endif

  installFunction(
      "__RNPretextPrepare",
      2,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isString()) {
          throwJSError(runtime, "RNPretext: prepare() requires a text string.");
        }

        StyleArgs style = parseStyle(runtime, arguments, 1, count);
        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNPretext: failed to access JNI environment.");

        jstring text = env->NewStringUTF(arguments[0].asString(runtime).utf8(runtime).c_str());
        jlong handle = 0;

        withStyle(env, style, [&](jstring fontFamily, jstring fontWeight, jstring fontStyle, jstring textBreakStrategy) {
          handle = env->CallStaticLongMethod(
              bindingsClass_,
              prepareMethod_,
              text,
              fontFamily,
              style.fontSize,
              fontWeight,
              fontStyle,
              style.letterSpacing,
              style.lineHeight,
              style.allowFontScaling,
              style.includeFontPadding,
              style.tabularNumbers,
              textBreakStrategy);
        });

        env->DeleteLocalRef(text);
        clearPendingException(env, runtime, "RNPretext: native prepare() failed.");
        if (needsDetach) jvm_->DetachCurrentThread();
        return static_cast<double>(handle);
      });

  installFunction(
      "__RNPretextPrepareBatch",
      2,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throwJSError(runtime, "RNPretext: prepareBatch() requires an array of strings.");
        }

        std::vector<std::string> texts = parseTextArray(runtime, arguments[0]);
        StyleArgs style = parseStyle(runtime, arguments, 1, count);
        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNPretext: failed to access JNI environment.");

        jobjectArray textArray = makeJavaStringArray(env, texts);
        jlongArray handles = nullptr;

        withStyle(env, style, [&](jstring fontFamily, jstring fontWeight, jstring fontStyle, jstring textBreakStrategy) {
          handles = reinterpret_cast<jlongArray>(env->CallStaticObjectMethod(
              bindingsClass_,
              prepareBatchMethod_,
              textArray,
              fontFamily,
              style.fontSize,
              fontWeight,
              fontStyle,
              style.letterSpacing,
              style.lineHeight,
              style.allowFontScaling,
              style.includeFontPadding,
              style.tabularNumbers,
              textBreakStrategy));
        });

        env->DeleteLocalRef(textArray);
        clearPendingException(env, runtime, "RNPretext: native prepareBatch() failed.");
        std::vector<Handle> values = toHandleVector(env, handles);
        if (handles) env->DeleteLocalRef(handles);
        if (needsDetach) jvm_->DetachCurrentThread();
        return buildHandleArray(runtime, values);
      });

  installFunction(
      "__RNPretextRelease",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throwJSError(runtime, "RNPretext: release() requires a prepared text handle.");
        }

        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNPretext: failed to access JNI environment.");

        env->CallStaticVoidMethod(bindingsClass_, releaseMethod_, static_cast<jlong>(arguments[0].asNumber()));
        clearPendingException(env, runtime, "RNPretext: native release() failed.");
        if (needsDetach) jvm_->DetachCurrentThread();
        return Value::undefined();
      });

  installFunction(
      "__RNPretextReleaseMany",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throwJSError(runtime, "RNPretext: releaseMany() requires an array of handles.");
        }
        std::vector<Handle> handles = parseHandleArray(runtime, arguments[0]);
        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNPretext: failed to access JNI environment.");

        jlongArray array = makeJavaLongArray(env, handles);
        env->CallStaticVoidMethod(bindingsClass_, releaseManyMethod_, array);
        env->DeleteLocalRef(array);
        clearPendingException(env, runtime, "RNPretext: native releaseMany() failed.");
        if (needsDetach) jvm_->DetachCurrentThread();
        return Value::undefined();
      });

  installFunction(
      "__RNPretextMeasureWidth",
      2,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isString()) {
          throwJSError(runtime, "RNPretext: measureWidth() requires a text string.");
        }
        StyleArgs style = parseStyle(runtime, arguments, 1, count);
        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNPretext: failed to access JNI environment.");

        jstring text = env->NewStringUTF(arguments[0].asString(runtime).utf8(runtime).c_str());
        jdouble width = 0;

        withStyle(env, style, [&](jstring fontFamily, jstring fontWeight, jstring fontStyle, jstring textBreakStrategy) {
          width = env->CallStaticDoubleMethod(
              bindingsClass_,
              measureWidthMethod_,
              text,
              fontFamily,
              style.fontSize,
              fontWeight,
              fontStyle,
              style.letterSpacing,
              style.lineHeight,
              style.allowFontScaling,
              style.includeFontPadding,
              style.tabularNumbers,
              textBreakStrategy);
        });

        env->DeleteLocalRef(text);
        clearPendingException(env, runtime, "RNPretext: native measureWidth() failed.");
        if (needsDetach) jvm_->DetachCurrentThread();
        return width;
      });

  auto callPackedLayout =
      [&](Runtime& runtime,
          const char* errorMessage,
          jmethodID method,
          const StyleArgs* style,
          const std::vector<std::string>* texts,
          const std::vector<Handle>* handles,
          const LayoutArgs& layout,
          bool includeLines) -> Value {
        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNPretext: failed to access JNI environment.");

        jdoubleArray packed = nullptr;
        jstring ellipsize = toJString(env, layout.ellipsizeMode);

        if (texts != nullptr) {
          jobjectArray textArray = makeJavaStringArray(env, *texts);
          if (style == nullptr) {
            packed = reinterpret_cast<jdoubleArray>(
                env->CallStaticObjectMethod(bindingsClass_, method, textArray, layout.width, layout.maxLines, ellipsize));
          } else {
            withStyle(env, *style, [&](jstring fontFamily, jstring fontWeight, jstring fontStyle, jstring textBreakStrategy) {
              packed = reinterpret_cast<jdoubleArray>(env->CallStaticObjectMethod(
                  bindingsClass_,
                  method,
                  textArray,
                  fontFamily,
                  style->fontSize,
                  fontWeight,
                  fontStyle,
                  style->letterSpacing,
                  style->lineHeight,
                  style->allowFontScaling,
                  style->includeFontPadding,
                  style->tabularNumbers,
                  textBreakStrategy,
                  layout.width,
                  layout.maxLines,
                  ellipsize));
            });
          }
          env->DeleteLocalRef(textArray);
        } else if (handles != nullptr) {
          if (handles->size() == 1 && method != layoutBatchMethod_) {
            packed = reinterpret_cast<jdoubleArray>(
                env->CallStaticObjectMethod(bindingsClass_, method, static_cast<jlong>((*handles)[0]), layout.width, layout.maxLines, ellipsize));
          } else {
            jlongArray handleArray = makeJavaLongArray(env, *handles);
            packed = reinterpret_cast<jdoubleArray>(
                env->CallStaticObjectMethod(bindingsClass_, method, handleArray, layout.width, layout.maxLines, ellipsize));
            env->DeleteLocalRef(handleArray);
          }
        }

        if (ellipsize) env->DeleteLocalRef(ellipsize);
        clearPendingException(env, runtime, errorMessage);
        std::vector<double> values = toDoubleVector(env, packed);
        if (packed) env->DeleteLocalRef(packed);
        if (needsDetach) jvm_->DetachCurrentThread();

        if (values.size() < PACKED_LAYOUT_SIZE) {
          throwJSError(runtime, errorMessage);
        }

        if (includeLines) return buildLayoutLinesObject(runtime, values);
        if (method == measureBatchMethod_ || method == layoutBatchMethod_) return buildLayoutBatchArray(runtime, values);
        return buildLayoutObject(runtime, values, 0);
      };

  installFunction(
      "__RNPretextMeasure",
      3,
      [&](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isString()) {
          throwJSError(runtime, "RNPretext: measure() requires a text string.");
        }
        StyleArgs style = parseStyle(runtime, arguments, 1, count);
        LayoutArgs layout = parseLayout(runtime, arguments, 2, count);
        std::vector<std::string> texts = {arguments[0].asString(runtime).utf8(runtime)};
        return callPackedLayout(runtime, "RNPretext: native measure() failed.", measureMethod_, &style, &texts, nullptr, layout, false);
      });

  installFunction(
      "__RNPretextMeasureBatch",
      3,
      [&](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throwJSError(runtime, "RNPretext: measureBatch() requires an array of strings.");
        }
        StyleArgs style = parseStyle(runtime, arguments, 1, count);
        LayoutArgs layout = parseLayout(runtime, arguments, 2, count);
        std::vector<std::string> texts = parseTextArray(runtime, arguments[0]);
        return callPackedLayout(runtime, "RNPretext: native measureBatch() failed.", measureBatchMethod_, &style, &texts, nullptr, layout, false);
      });

  installFunction(
      "__RNPretextLayout",
      2,
      [&](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throwJSError(runtime, "RNPretext: layout() requires a prepared text handle.");
        }
        LayoutArgs layout = parseLayout(runtime, arguments, 1, count);
        std::vector<Handle> handles = {static_cast<Handle>(arguments[0].asNumber())};
        return callPackedLayout(runtime, "RNPretext: native layout() failed.", layoutMethod_, nullptr, nullptr, &handles, layout, false);
      });

  installFunction(
      "__RNPretextLayoutBatch",
      2,
      [&](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throwJSError(runtime, "RNPretext: layoutBatch() requires an array of handles.");
        }
        LayoutArgs layout = parseLayout(runtime, arguments, 1, count);
        std::vector<Handle> handles = parseHandleArray(runtime, arguments[0]);
        return callPackedLayout(runtime, "RNPretext: native layoutBatch() failed.", layoutBatchMethod_, nullptr, nullptr, &handles, layout, false);
      });

  installFunction(
      "__RNPretextLayoutNextLine",
      3,
      [&](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count < 3 || !arguments[0].isNumber() || !arguments[1].isNumber() || !arguments[2].isNumber()) {
          throwJSError(runtime, "RNPretext: layoutNextLine() requires a prepared text handle, start offset, and width.");
        }

        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNPretext: failed to access JNI environment.");

        jdoubleArray packed = reinterpret_cast<jdoubleArray>(env->CallStaticObjectMethod(
            bindingsClass_,
            layoutNextLineMethod_,
            static_cast<jlong>(arguments[0].asNumber()),
            static_cast<jint>(arguments[1].asNumber()),
            arguments[2].asNumber()));

        clearPendingException(env, runtime, "RNPretext: native layoutNextLine() failed.");
        std::vector<double> values = toDoubleVector(env, packed);
        if (packed) env->DeleteLocalRef(packed);
        if (needsDetach) jvm_->DetachCurrentThread();
        return buildNextLineObject(runtime, values);
      });

  installFunction(
      "__RNPretextLayoutLines",
      2,
      [&](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throwJSError(runtime, "RNPretext: layoutLines() requires a prepared text handle.");
        }
        LayoutArgs layout = parseLayout(runtime, arguments, 1, count);
        std::vector<Handle> handles = {static_cast<Handle>(arguments[0].asNumber())};
        return callPackedLayout(runtime, "RNPretext: native layoutLines() failed.", layoutLinesMethod_, nullptr, nullptr, &handles, layout, true);
      });
}

} // namespace rnpretext

extern "C" {
JNIEXPORT jboolean JNICALL
Java_com_rnpretext_RNPretextModule_nativeInstall(
    JNIEnv* env,
    jobject,
    jlong runtimePointer,
    jobject context) {
  auto runtime = reinterpret_cast<Runtime*>(runtimePointer);
  if (runtime == nullptr) return JNI_FALSE;

  try {
    rnpretext::install(*runtime, env, context);
    return JNI_TRUE;
  } catch (const std::exception& exception) {
    LOGE("Failed to install RNPretext: %s", exception.what());
    return JNI_FALSE;
  }
}

JNIEXPORT void JNICALL JNI_OnUnload(JavaVM* vm, void*) {
  JNIEnv* env = nullptr;
  if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) == JNI_OK && env != nullptr) {
    rnpretext::cleanup(env);
  }
}
}
