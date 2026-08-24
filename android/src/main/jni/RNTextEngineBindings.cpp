#include "RNTextEngineBindings.h"

#include <android/log.h>
#include <cmath>
#include <limits>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#ifndef RNTEXTENGINE_HAS_WORKLETS
#define RNTEXTENGINE_HAS_WORKLETS 0
#endif

#if RNTEXTENGINE_HAS_WORKLETS
#include <worklets/Compat/StableApi.h>
#include <worklets/WorkletRuntime/WorkletRuntime.h>
#endif

using namespace facebook::jsi;

#define LOG_TAG "RNTextEngine"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace rntextengine {
namespace {

using Handle = jlong;

struct GlyphFieldMutableBuffer : public MutableBuffer {
  explicit GlyphFieldMutableBuffer(size_t size) : bytes(size) {}

  size_t size() const override {
    return bytes.size();
  }

  uint8_t *data() override {
    return bytes.data();
  }

  std::vector<uint8_t> bytes;
};

struct GlyphFieldBufferSet {
  std::shared_ptr<GlyphFieldMutableBuffer> glyphIndices;
  std::shared_ptr<GlyphFieldMutableBuffer> variantIndices;
};

struct Uint8ArrayView {
  const uint8_t* data = nullptr;
  size_t length = 0;
};

struct StyleArgs {
  bool allowFontScaling = false;
  bool includeFontPadding = true;
  bool tabularNumbers = false;
  double fontSize = std::numeric_limits<double>::quiet_NaN();
  double letterSpacing = std::numeric_limits<double>::quiet_NaN();
  double lineHeight = std::numeric_limits<double>::quiet_NaN();
  std::string color;
  std::string fontFamily;
  std::string fontStyle;
  std::string fontWeight;
  std::string textBreakStrategy;
};

struct RunStyleArgs {
  bool hasColor = false;
  bool hasFontFamily = false;
  bool hasFontSize = false;
  bool hasFontStyle = false;
  bool hasFontWeight = false;
  bool hasLetterSpacing = false;
  bool hasLineHeight = false;
  bool hasTabularNumbers = false;
  bool tabularNumbers = false;
  double fontSize = std::numeric_limits<double>::quiet_NaN();
  double letterSpacing = std::numeric_limits<double>::quiet_NaN();
  double lineHeight = std::numeric_limits<double>::quiet_NaN();
  std::string color;
  std::string fontFamily;
  std::string fontStyle;
  std::string fontWeight;
};

struct TextRunArgs {
  int end = 0;
  int start = 0;
  RunStyleArgs style;
};

struct FlattenedRuns {
  std::vector<int> counts;
  std::vector<int> ends;
  std::vector<int> masks;
  std::vector<int> starts;
  std::vector<bool> tabularNumbers;
  std::vector<double> fontSizes;
  std::vector<double> letterSpacings;
  std::vector<double> lineHeights;
  std::vector<std::string> colors;
  std::vector<std::string> fontFamilies;
  std::vector<std::string> fontStyles;
  std::vector<std::string> fontWeights;
};

struct LayoutArgs {
  bool anchorToCapHeight = false;
  double width = 0;
  int maxLines = 0;
  std::string ellipsizeMode;
};

struct GlyphFieldVariantArgs {
  std::string color;
  std::string fontStyle;
  std::string fontWeight;
};

struct GlyphFieldArgs {
  int columns = 0;
  double fontSize = std::numeric_limits<double>::quiet_NaN();
  std::string glyphPalette;
  double letterSpacing = std::numeric_limits<double>::quiet_NaN();
  double lineHeight = std::numeric_limits<double>::quiet_NaN();
  int rows = 0;
  std::string fontFamily;
  std::string textAlign;
  std::vector<GlyphFieldVariantArgs> variants;
};

JavaVM* jvm_ = nullptr;
jclass bindingsClass_ = nullptr;
jclass stringClass_ = nullptr;

jmethodID initializeMethod_ = nullptr;
jmethodID cleanupMethod_ = nullptr;
jmethodID currentFontScaleMultiplierMethod_ = nullptr;
jmethodID createGlyphFieldMethod_ = nullptr;
jmethodID getGlyphFieldCellCountMethod_ = nullptr;
jmethodID prepareMethod_ = nullptr;
jmethodID prepareWithRunsMethod_ = nullptr;
jmethodID prepareBatchMethod_ = nullptr;
jmethodID prepareBatchWithRunsMethod_ = nullptr;
jmethodID releaseMethod_ = nullptr;
jmethodID releaseGlyphFieldMethod_ = nullptr;
jmethodID releaseManyMethod_ = nullptr;
jmethodID attachGlyphFieldBuffersMethod_ = nullptr;
jmethodID commitGlyphFieldBuffersMethod_ = nullptr;
jmethodID updateGlyphFieldMethod_ = nullptr;
jmethodID updateGlyphFieldIndicesMethod_ = nullptr;
jmethodID measurePreparedWidthMethod_ = nullptr;
jmethodID measureWidthMethod_ = nullptr;
jmethodID measureWidthWithRunsMethod_ = nullptr;
jmethodID measureMethod_ = nullptr;
jmethodID measureWithRunsMethod_ = nullptr;
jmethodID measureBatchMethod_ = nullptr;
jmethodID measureBatchWithRunsMethod_ = nullptr;
jmethodID layoutMethod_ = nullptr;
jmethodID layoutBatchMethod_ = nullptr;
jmethodID layoutNextLineMethod_ = nullptr;
jmethodID layoutLinesMethod_ = nullptr;

constexpr int PACKED_LAYOUT_SIZE = 4;
constexpr int PACKED_LINE_SIZE = 4;
constexpr int RUN_STYLE_HAS_COLOR = 1 << 0;
constexpr int RUN_STYLE_HAS_FONT_FAMILY = 1 << 1;
constexpr int RUN_STYLE_HAS_FONT_SIZE = 1 << 2;
constexpr int RUN_STYLE_HAS_FONT_STYLE = 1 << 3;
constexpr int RUN_STYLE_HAS_FONT_WEIGHT = 1 << 4;
constexpr int RUN_STYLE_HAS_LETTER_SPACING = 1 << 5;
constexpr int RUN_STYLE_HAS_LINE_HEIGHT = 1 << 6;
constexpr int RUN_STYLE_HAS_TABULAR_NUMBERS = 1 << 7;
std::mutex glyphFieldBufferMutex_;
std::unordered_map<Handle, std::shared_ptr<GlyphFieldBufferSet>> glyphFieldBuffers_;

void throwJSError(Runtime& runtime, const char* message) {
  throw JSError(runtime, message);
}

void clearPendingException(JNIEnv* env, Runtime& runtime, const char* fallback) {
  if (!env->ExceptionCheck()) return;
  env->ExceptionDescribe();
  env->ExceptionClear();
  throwJSError(runtime, fallback);
}

bool clearPendingException(JNIEnv* env, const char* fallback) {
  if (!env->ExceptionCheck()) return false;
  env->ExceptionDescribe();
  env->ExceptionClear();
  LOGE("%s", fallback);
  return true;
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

  jclass localClass = env->FindClass("com/rntextengine/RNTextEngineBindings");
  bindingsClass_ = reinterpret_cast<jclass>(env->NewGlobalRef(localClass));
  env->DeleteLocalRef(localClass);

  jclass localStringClass = env->FindClass("java/lang/String");
  stringClass_ = reinterpret_cast<jclass>(env->NewGlobalRef(localStringClass));
  env->DeleteLocalRef(localStringClass);

  initializeMethod_ = env->GetStaticMethodID(bindingsClass_, "initialize", "(Lcom/facebook/react/bridge/ReactApplicationContext;)V");
  cleanupMethod_ = env->GetStaticMethodID(bindingsClass_, "cleanup", "()V");
  currentFontScaleMultiplierMethod_ = env->GetStaticMethodID(bindingsClass_, "currentFontScaleMultiplier", "()D");
  createGlyphFieldMethod_ = env->GetStaticMethodID(
      bindingsClass_,
      "createGlyphField",
      "(IILjava/lang/String;DLjava/lang/String;DDLjava/lang/String;[Ljava/lang/String;[Ljava/lang/String;[Ljava/lang/String;)J");
  getGlyphFieldCellCountMethod_ = env->GetStaticMethodID(bindingsClass_, "getGlyphFieldCellCount", "(J)I");
  prepareMethod_ = env->GetStaticMethodID(
      bindingsClass_,
      "prepare",
      "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;)J");
  prepareWithRunsMethod_ = env->GetStaticMethodID(
      bindingsClass_,
      "prepareWithRuns",
      "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;[I[I[I[Ljava/lang/String;[Ljava/lang/String;[D[Ljava/lang/String;[Ljava/lang/String;[D[D[Z)J");
  prepareBatchMethod_ = env->GetStaticMethodID(
      bindingsClass_,
      "prepareBatch",
      "([Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;)[J");
  prepareBatchWithRunsMethod_ = env->GetStaticMethodID(
      bindingsClass_,
      "prepareBatchWithRuns",
      "([Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;[I[I[I[I[Ljava/lang/String;[Ljava/lang/String;[D[Ljava/lang/String;[Ljava/lang/String;[D[D[Z)[J");
  releaseMethod_ = env->GetStaticMethodID(bindingsClass_, "release", "(J)V");
  releaseGlyphFieldMethod_ = env->GetStaticMethodID(bindingsClass_, "releaseGlyphField", "(J)V");
  releaseManyMethod_ = env->GetStaticMethodID(bindingsClass_, "releaseMany", "([J)V");
  attachGlyphFieldBuffersMethod_ =
      env->GetStaticMethodID(bindingsClass_, "attachGlyphFieldBuffers", "(JLjava/nio/ByteBuffer;Ljava/nio/ByteBuffer;)V");
  commitGlyphFieldBuffersMethod_ = env->GetStaticMethodID(bindingsClass_, "commitGlyphFieldBuffers", "(J)V");
  updateGlyphFieldMethod_ = env->GetStaticMethodID(bindingsClass_, "updateGlyphField", "(JLjava/lang/String;[B)V");
  updateGlyphFieldIndicesMethod_ = env->GetStaticMethodID(bindingsClass_, "updateGlyphFieldIndices", "(J[B[B)V");
  measurePreparedWidthMethod_ = env->GetStaticMethodID(bindingsClass_, "measurePreparedWidth", "(J)D");
  measureWidthMethod_ = env->GetStaticMethodID(
      bindingsClass_,
      "measureWidth",
      "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;)D");
  measureWidthWithRunsMethod_ = env->GetStaticMethodID(
      bindingsClass_,
      "measureWidthWithRuns",
      "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;[I[I[I[Ljava/lang/String;[Ljava/lang/String;[D[Ljava/lang/String;[Ljava/lang/String;[D[D[Z)D");
  measureMethod_ = env->GetStaticMethodID(
      bindingsClass_,
      "measure",
      "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;DILjava/lang/String;Z)[D");
  measureWithRunsMethod_ = env->GetStaticMethodID(
      bindingsClass_,
      "measureWithRuns",
      "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;DILjava/lang/String;Z[I[I[I[Ljava/lang/String;[Ljava/lang/String;[D[Ljava/lang/String;[Ljava/lang/String;[D[D[Z)[D");
  measureBatchMethod_ = env->GetStaticMethodID(
      bindingsClass_,
      "measureBatch",
      "([Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;DILjava/lang/String;Z)[D");
  measureBatchWithRunsMethod_ = env->GetStaticMethodID(
      bindingsClass_,
      "measureBatchWithRuns",
      "([Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;DILjava/lang/String;Z[I[I[I[I[Ljava/lang/String;[Ljava/lang/String;[D[Ljava/lang/String;[Ljava/lang/String;[D[D[Z)[D");
  layoutMethod_ = env->GetStaticMethodID(bindingsClass_, "layout", "(JDILjava/lang/String;Z)[D");
  layoutBatchMethod_ = env->GetStaticMethodID(bindingsClass_, "layoutBatch", "([JDILjava/lang/String;Z)[D");
  layoutNextLineMethod_ = env->GetStaticMethodID(bindingsClass_, "layoutNextLine", "(JIDZ)[D");
  layoutLinesMethod_ = env->GetStaticMethodID(bindingsClass_, "layoutLines", "(JDILjava/lang/String;Z)[D");

  if (context != nullptr) {
    env->CallStaticVoidMethod(bindingsClass_, initializeMethod_, context);
  }
}

std::shared_ptr<GlyphFieldBufferSet> getOrCreateGlyphFieldBuffers(Handle handle, size_t cellCount) {
  std::lock_guard<std::mutex> lock(glyphFieldBufferMutex_);
  auto iterator = glyphFieldBuffers_.find(handle);
  if (iterator != glyphFieldBuffers_.end()) {
    return iterator->second;
  }

  auto buffers = std::make_shared<GlyphFieldBufferSet>();
  buffers->glyphIndices = std::make_shared<GlyphFieldMutableBuffer>(cellCount);
  buffers->variantIndices = std::make_shared<GlyphFieldMutableBuffer>(cellCount);
  glyphFieldBuffers_.emplace(handle, buffers);
  return buffers;
}

std::shared_ptr<GlyphFieldBufferSet> getGlyphFieldBuffers(Runtime& runtime, Handle handle) {
  std::lock_guard<std::mutex> lock(glyphFieldBufferMutex_);
  auto iterator = glyphFieldBuffers_.find(handle);
  if (iterator == glyphFieldBuffers_.end()) {
    throwJSError(runtime, "RNTextEngine: attempted to use glyph field buffers before creating them.");
  }
  return iterator->second;
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
    Value value = object.getProperty(runtime, name);
    if (value.isBool()) target = value.getBool();
  };

  auto readNumber = [&](const char* name, double& target) {
    Value value = object.getProperty(runtime, name);
    if (value.isNumber()) target = value.asNumber();
  };

  auto readString = [&](const char* name, std::string& target) {
    Value value = object.getProperty(runtime, name);
    if (value.isString()) target = value.asString(runtime).utf8(runtime);
  };

  readBool("allowFontScaling", style.allowFontScaling);
  readBool("includeFontPadding", style.includeFontPadding);
  readBool("tabularNumbers", style.tabularNumbers);
  readString("color", style.color);
  readNumber("fontSize", style.fontSize);
  readNumber("letterSpacing", style.letterSpacing);
  readNumber("lineHeight", style.lineHeight);
  readString("fontFamily", style.fontFamily);
  readString("fontStyle", style.fontStyle);
  readString("fontWeight", style.fontWeight);
  readString("textBreakStrategy", style.textBreakStrategy);

  return style;
}

GlyphFieldArgs parseGlyphField(Runtime& runtime, const Value& value) {
  if (!value.isObject()) {
    throwJSError(runtime, "RNTextEngine: glyph field config must be an object.");
  }

  Object object = value.asObject(runtime);
  GlyphFieldArgs field;

  auto requireNumber = [&](const char* name, double& target) {
    if (!object.hasProperty(runtime, name)) {
      throwJSError(runtime, ("RNTextEngine: glyph field config must include `" + std::string(name) + "`.").c_str());
    }
    Value property = object.getProperty(runtime, name);
    if (!property.isNumber()) {
      throwJSError(runtime, ("RNTextEngine: glyph field `" + std::string(name) + "` must be numeric.").c_str());
    }
    target = property.asNumber();
  };

  double columns = 0;
  double rows = 0;
  requireNumber("columns", columns);
  requireNumber("rows", rows);
  requireNumber("fontSize", field.fontSize);
  requireNumber("lineHeight", field.lineHeight);

  field.columns = static_cast<int>(columns);
  field.rows = static_cast<int>(rows);
  if (field.columns <= 0 || field.rows <= 0) {
    throwJSError(runtime, "RNTextEngine: glyph field columns and rows must be positive.");
  }
  if (!(field.fontSize > 0) || !(field.lineHeight > 0)) {
    throwJSError(runtime, "RNTextEngine: glyph field fontSize and lineHeight must be positive.");
  }

  if (object.hasProperty(runtime, "fontFamily")) {
    Value fontFamily = object.getProperty(runtime, "fontFamily");
    if (!fontFamily.isString()) {
      throwJSError(runtime, "RNTextEngine: glyph field fontFamily must be a string.");
    }
    field.fontFamily = fontFamily.asString(runtime).utf8(runtime);
  }

  if (object.hasProperty(runtime, "glyphPalette")) {
    Value glyphPalette = object.getProperty(runtime, "glyphPalette");
    if (!glyphPalette.isString()) {
      throwJSError(runtime, "RNTextEngine: glyph field glyphPalette must be a string.");
    }
    field.glyphPalette = glyphPalette.asString(runtime).utf8(runtime);
  }

  if (object.hasProperty(runtime, "letterSpacing")) {
    Value letterSpacing = object.getProperty(runtime, "letterSpacing");
    if (!letterSpacing.isNumber()) {
      throwJSError(runtime, "RNTextEngine: glyph field letterSpacing must be numeric.");
    }
    field.letterSpacing = letterSpacing.asNumber();
  }

  if (object.hasProperty(runtime, "textAlign")) {
    Value textAlign = object.getProperty(runtime, "textAlign");
    if (!textAlign.isString()) {
      throwJSError(runtime, "RNTextEngine: glyph field textAlign must be a string.");
    }
    field.textAlign = textAlign.asString(runtime).utf8(runtime);
  }

  if (!object.hasProperty(runtime, "variants")) {
    throwJSError(runtime, "RNTextEngine: glyph field config must include variants.");
  }
  Value variantsValue = object.getProperty(runtime, "variants");
  if (!variantsValue.isObject() || !variantsValue.asObject(runtime).isArray(runtime)) {
    throwJSError(runtime, "RNTextEngine: glyph field variants must be an array.");
  }

  Array variantsArray = variantsValue.asObject(runtime).asArray(runtime);
  if (variantsArray.size(runtime) == 0 || variantsArray.size(runtime) > 255) {
    throwJSError(runtime, "RNTextEngine: glyph field variants must contain between 1 and 255 entries.");
  }

  field.variants.reserve(variantsArray.size(runtime));
  for (size_t index = 0; index < variantsArray.size(runtime); index++) {
    Value item = variantsArray.getValueAtIndex(runtime, index);
    if (!item.isObject()) {
      throwJSError(runtime, "RNTextEngine: each glyph field variant must be an object.");
    }

    Object variantObject = item.asObject(runtime);
    if (!variantObject.hasProperty(runtime, "color")) {
      throwJSError(runtime, "RNTextEngine: each glyph field variant must include a color.");
    }

    Value color = variantObject.getProperty(runtime, "color");
    if (!color.isString()) {
      throwJSError(runtime, "RNTextEngine: glyph field variant color must be a string.");
    }

    GlyphFieldVariantArgs variant;
    variant.color = color.asString(runtime).utf8(runtime);

    if (variantObject.hasProperty(runtime, "fontStyle")) {
      Value fontStyle = variantObject.getProperty(runtime, "fontStyle");
      if (!fontStyle.isString()) {
        throwJSError(runtime, "RNTextEngine: glyph field variant fontStyle must be a string.");
      }
      variant.fontStyle = fontStyle.asString(runtime).utf8(runtime);
    }

    if (variantObject.hasProperty(runtime, "fontWeight")) {
      Value fontWeight = variantObject.getProperty(runtime, "fontWeight");
      if (!fontWeight.isString()) {
        throwJSError(runtime, "RNTextEngine: glyph field variant fontWeight must be a string.");
      }
      variant.fontWeight = fontWeight.asString(runtime).utf8(runtime);
    }

    field.variants.push_back(std::move(variant));
  }

  return field;
}

RunStyleArgs parseRunStyle(Runtime& runtime, const Object& object) {
  RunStyleArgs style;

  auto readBool = [&](const char* name, bool& hasValue, bool& target) {
    Value value = object.getProperty(runtime, name);
    if (!value.isBool()) return;
    hasValue = true;
    target = value.getBool();
  };

  auto readNumber = [&](const char* name, bool& hasValue, double& target) {
    Value value = object.getProperty(runtime, name);
    if (!value.isNumber()) return;
    hasValue = true;
    target = value.asNumber();
  };

  auto readString = [&](const char* name, bool& hasValue, std::string& target) {
    Value value = object.getProperty(runtime, name);
    if (!value.isString()) return;
    hasValue = true;
    target = value.asString(runtime).utf8(runtime);
  };

  readString("color", style.hasColor, style.color);
  readString("fontFamily", style.hasFontFamily, style.fontFamily);
  readNumber("fontSize", style.hasFontSize, style.fontSize);
  readString("fontStyle", style.hasFontStyle, style.fontStyle);
  readString("fontWeight", style.hasFontWeight, style.fontWeight);
  readNumber("letterSpacing", style.hasLetterSpacing, style.letterSpacing);
  readNumber("lineHeight", style.hasLineHeight, style.lineHeight);
  readBool("tabularNumbers", style.hasTabularNumbers, style.tabularNumbers);

  return style;
}

int buildRunStyleMask(const RunStyleArgs& style) {
  int mask = 0;
  if (style.hasColor) mask |= RUN_STYLE_HAS_COLOR;
  if (style.hasFontFamily) mask |= RUN_STYLE_HAS_FONT_FAMILY;
  if (style.hasFontSize) mask |= RUN_STYLE_HAS_FONT_SIZE;
  if (style.hasFontStyle) mask |= RUN_STYLE_HAS_FONT_STYLE;
  if (style.hasFontWeight) mask |= RUN_STYLE_HAS_FONT_WEIGHT;
  if (style.hasLetterSpacing) mask |= RUN_STYLE_HAS_LETTER_SPACING;
  if (style.hasLineHeight) mask |= RUN_STYLE_HAS_LINE_HEIGHT;
  if (style.hasTabularNumbers) mask |= RUN_STYLE_HAS_TABULAR_NUMBERS;
  return mask;
}

std::vector<TextRunArgs> parseRuns(Runtime& runtime, const Value& value) {
  if (value.isUndefined() || value.isNull()) return {};
  if (!value.isObject() || !value.asObject(runtime).isArray(runtime)) {
    throwJSError(runtime, "RNTextEngine: text runs must be an array.");
  }

  Array array = value.asObject(runtime).asArray(runtime);
  std::vector<TextRunArgs> runs;
  runs.reserve(array.size(runtime));
  int previousEnd = 0;

  for (size_t index = 0; index < array.size(runtime); index++) {
    Value item = array.getValueAtIndex(runtime, index);
    if (!item.isObject()) {
      throwJSError(runtime, "RNTextEngine: each text run must be an object.");
    }

    Object runObject = item.asObject(runtime);
    Value startValue = runObject.getProperty(runtime, "start");
    Value endValue = runObject.getProperty(runtime, "end");
    if (!startValue.isNumber() || !endValue.isNumber()) {
      throwJSError(runtime, "RNTextEngine: text run start and end must be numbers.");
    }

    int start = static_cast<int>(startValue.asNumber());
    int end = static_cast<int>(endValue.asNumber());
    if (start < 0 || end <= start) {
      throwJSError(runtime, "RNTextEngine: text runs must have non-negative, increasing UTF-16 offsets.");
    }
    if (start < previousEnd) {
      throwJSError(runtime, "RNTextEngine: text runs must be sorted and non-overlapping.");
    }

    Value styleValue = runObject.getProperty(runtime, "style");
    if (!styleValue.isObject()) {
      throwJSError(runtime, "RNTextEngine: each text run style must be an object.");
    }

    RunStyleArgs style = parseRunStyle(runtime, styleValue.asObject(runtime));
    if (buildRunStyleMask(style) == 0) {
      throwJSError(runtime, "RNTextEngine: each text run must override at least one inline style field.");
    }

    TextRunArgs run;
    run.end = end;
    run.start = start;
    run.style = style;
    runs.push_back(run);
    previousEnd = end;
  }

  return runs;
}

std::vector<std::vector<TextRunArgs>> parseRunsByText(
    Runtime& runtime,
    const Value& value,
    const std::vector<std::string>& texts) {
  if (value.isUndefined() || value.isNull()) return {};
  if (!value.isObject() || !value.asObject(runtime).isArray(runtime)) {
    throwJSError(runtime, "RNTextEngine: batch text runs must be an array aligned with the batch text input.");
  }

  Array array = value.asObject(runtime).asArray(runtime);
  if (array.size(runtime) != texts.size()) {
    throwJSError(runtime, "RNTextEngine: batch text runs must align with the batch text input length.");
  }

  std::vector<std::vector<TextRunArgs>> runsByText;
  runsByText.reserve(texts.size());
  for (size_t index = 0; index < texts.size(); index++) {
    runsByText.push_back(parseRuns(runtime, array.getValueAtIndex(runtime, index)));
  }
  return runsByText;
}

bool hasAnyRuns(const std::vector<TextRunArgs>& runs) {
  return !runs.empty();
}

bool hasAnyRuns(const std::vector<std::vector<TextRunArgs>>& runsByText) {
  for (const auto& runs : runsByText) {
    if (!runs.empty()) return true;
  }
  return false;
}

void reserveFlattenedRuns(FlattenedRuns& flattened, size_t runCount) {
  flattened.starts.reserve(runCount);
  flattened.ends.reserve(runCount);
  flattened.masks.reserve(runCount);
  flattened.colors.reserve(runCount);
  flattened.fontFamilies.reserve(runCount);
  flattened.fontSizes.reserve(runCount);
  flattened.fontWeights.reserve(runCount);
  flattened.fontStyles.reserve(runCount);
  flattened.letterSpacings.reserve(runCount);
  flattened.lineHeights.reserve(runCount);
  flattened.tabularNumbers.reserve(runCount);
}

void appendFlattenedRun(FlattenedRuns& flattened, const TextRunArgs& run) {
  flattened.starts.push_back(run.start);
  flattened.ends.push_back(run.end);
  flattened.masks.push_back(buildRunStyleMask(run.style));
  flattened.colors.push_back(run.style.color);
  flattened.fontFamilies.push_back(run.style.fontFamily);
  flattened.fontSizes.push_back(run.style.fontSize);
  flattened.fontWeights.push_back(run.style.fontWeight);
  flattened.fontStyles.push_back(run.style.fontStyle);
  flattened.letterSpacings.push_back(run.style.letterSpacing);
  flattened.lineHeights.push_back(run.style.lineHeight);
  flattened.tabularNumbers.push_back(run.style.tabularNumbers);
}

FlattenedRuns flattenRuns(const std::vector<TextRunArgs>& runs) {
  FlattenedRuns flattened;
  reserveFlattenedRuns(flattened, runs.size());

  for (const TextRunArgs& run : runs) {
    appendFlattenedRun(flattened, run);
  }

  return flattened;
}

FlattenedRuns flattenRuns(const std::vector<std::vector<TextRunArgs>>& runsByText) {
  size_t runCount = 0;
  for (const auto& runs : runsByText) {
    runCount += runs.size();
  }

  FlattenedRuns flattened;
  flattened.counts.reserve(runsByText.size());
  reserveFlattenedRuns(flattened, runCount);

  for (const auto& runs : runsByText) {
    flattened.counts.push_back(static_cast<int>(runs.size()));
    for (const TextRunArgs& run : runs) {
      appendFlattenedRun(flattened, run);
    }
  }

  return flattened;
}

LayoutArgs parseLayout(Runtime& runtime, const Value* arguments, size_t index, size_t count) {
  if (index >= count || !arguments[index].isObject()) {
    throwJSError(runtime, "RNTextEngine: layout options must be an object.");
  }

  LayoutArgs layout;
  Object object = arguments[index].asObject(runtime);
  Value width = object.getProperty(runtime, "width");
  if (!width.isNumber()) {
    throwJSError(runtime, "RNTextEngine: layout width must be a number.");
  }
  layout.width = width.asNumber();

  Value maxLines = object.getProperty(runtime, "maxLines");
  if (maxLines.isNumber()) layout.maxLines = static_cast<int>(maxLines.asNumber());

  Value mode = object.getProperty(runtime, "ellipsizeMode");
  if (mode.isString()) layout.ellipsizeMode = mode.asString(runtime).utf8(runtime);

  Value anchorToCapHeight = object.getProperty(runtime, "anchorToCapHeight");
  if (anchorToCapHeight.isBool()) layout.anchorToCapHeight = anchorToCapHeight.getBool();

  return layout;
}

std::vector<std::string> parseTextArray(Runtime& runtime, const Value& value) {
  if (!value.isObject() || !value.asObject(runtime).isArray(runtime)) {
    throwJSError(runtime, "RNTextEngine: expected an array of strings.");
  }

  Array array = value.asObject(runtime).asArray(runtime);
  std::vector<std::string> texts;
  texts.reserve(array.size(runtime));

  for (size_t i = 0; i < array.size(runtime); i++) {
    Value item = array.getValueAtIndex(runtime, i);
    if (!item.isString()) {
      throwJSError(runtime, "RNTextEngine: batch text input must contain strings only.");
    }
    texts.push_back(item.asString(runtime).utf8(runtime));
  }

  return texts;
}

std::vector<Handle> parseHandleArray(Runtime& runtime, const Value& value) {
  if (!value.isObject() || !value.asObject(runtime).isArray(runtime)) {
    throwJSError(runtime, "RNTextEngine: expected an array of prepared text handles.");
  }

  Array array = value.asObject(runtime).asArray(runtime);
  std::vector<Handle> handles;
  handles.reserve(array.size(runtime));

  for (size_t i = 0; i < array.size(runtime); i++) {
    Value item = array.getValueAtIndex(runtime, i);
    if (!item.isNumber()) {
      throwJSError(runtime, "RNTextEngine: prepared text handles must be numeric.");
    }
    handles.push_back(static_cast<Handle>(item.asNumber()));
  }

  return handles;
}

Uint8ArrayView parseUint8Array(Runtime& runtime, const Value& value) {
  if (!value.isObject()) {
    throwJSError(runtime, "RNTextEngine: glyph field variantIndices must be a Uint8Array.");
  }

  Object object = value.asObject(runtime);
  if (!object.hasProperty(runtime, "buffer")) {
    throwJSError(runtime, "RNTextEngine: glyph field variantIndices must be a Uint8Array.");
  }

  Value bufferValue = object.getProperty(runtime, "buffer");
  Value byteOffsetValue = object.getProperty(runtime, "byteOffset");
  Value lengthValue = object.getProperty(runtime, "length");
  Value bytesPerElementValue = object.getProperty(runtime, "BYTES_PER_ELEMENT");
  if (!bufferValue.isObject() || !byteOffsetValue.isNumber() || !lengthValue.isNumber() || !bytesPerElementValue.isNumber()) {
    throwJSError(runtime, "RNTextEngine: glyph field variantIndices must be a Uint8Array.");
  }
  if (static_cast<int>(bytesPerElementValue.asNumber()) != 1) {
    throwJSError(runtime, "RNTextEngine: glyph field variantIndices must be a Uint8Array.");
  }

  Object bufferObject = bufferValue.asObject(runtime);
  if (!bufferObject.isArrayBuffer(runtime)) {
    throwJSError(runtime, "RNTextEngine: glyph field variantIndices must be backed by an ArrayBuffer.");
  }

  ArrayBuffer buffer = bufferObject.getArrayBuffer(runtime);
  size_t byteOffset = static_cast<size_t>(byteOffsetValue.asNumber());
  size_t length = static_cast<size_t>(lengthValue.asNumber());
  if (byteOffset + length > buffer.size(runtime)) {
    throwJSError(runtime, "RNTextEngine: glyph field variantIndices Uint8Array exceeded its ArrayBuffer bounds.");
  }

  return {.data = buffer.data(runtime) + byteOffset, .length = length};
}

Uint8ArrayView parseUint8Array(Runtime& runtime, const Value& value, size_t expectedLength) {
  Uint8ArrayView view = parseUint8Array(runtime, value);
  if (view.length != expectedLength) {
    throwJSError(runtime, "RNTextEngine: glyph field variantIndices length must match columns * rows.");
  }
  return view;
}

jobjectArray makeJavaStringArray(JNIEnv* env, const std::vector<std::string>& values) {
  jobjectArray array = env->NewObjectArray(static_cast<jsize>(values.size()), stringClass_, nullptr);
  for (size_t i = 0; i < values.size(); i++) {
    jstring item = env->NewStringUTF(values[i].c_str());
    env->SetObjectArrayElement(array, static_cast<jsize>(i), item);
    env->DeleteLocalRef(item);
  }
  return array;
}

jlongArray makeJavaLongArray(JNIEnv* env, const std::vector<Handle>& values) {
  jlongArray array = env->NewLongArray(static_cast<jsize>(values.size()));
  if (!values.empty()) env->SetLongArrayRegion(array, 0, static_cast<jsize>(values.size()), values.data());
  return array;
}

jintArray makeJavaIntArray(JNIEnv* env, const std::vector<int>& values) {
  jintArray array = env->NewIntArray(static_cast<jsize>(values.size()));
  if (!values.empty()) env->SetIntArrayRegion(array, 0, static_cast<jsize>(values.size()), values.data());
  return array;
}

jdoubleArray makeJavaDoubleArray(JNIEnv* env, const std::vector<double>& values) {
  jdoubleArray array = env->NewDoubleArray(static_cast<jsize>(values.size()));
  if (!values.empty()) env->SetDoubleArrayRegion(array, 0, static_cast<jsize>(values.size()), values.data());
  return array;
}

jbooleanArray makeJavaBooleanArray(JNIEnv* env, const std::vector<bool>& values) {
  jbooleanArray array = env->NewBooleanArray(static_cast<jsize>(values.size()));
  if (values.empty()) return array;

  std::vector<jboolean> data(values.size());
  for (size_t index = 0; index < values.size(); index++) {
    data[index] = values[index] ? JNI_TRUE : JNI_FALSE;
  }
  env->SetBooleanArrayRegion(array, 0, static_cast<jsize>(data.size()), data.data());
  return array;
}

jbyteArray makeJavaByteArray(JNIEnv* env, const Uint8ArrayView& values) {
  jbyteArray array = env->NewByteArray(static_cast<jsize>(values.length));
  if (values.length == 0) return array;

  env->SetByteArrayRegion(
      array,
      0,
      static_cast<jsize>(values.length),
      reinterpret_cast<const jbyte*>(values.data));
  return array;
}

jobjectArray makeJavaOptionalStringArray(JNIEnv* env, const std::vector<std::string>& values) {
  jobjectArray array = env->NewObjectArray(static_cast<jsize>(values.size()), stringClass_, nullptr);
  for (size_t i = 0; i < values.size(); i++) {
    if (values[i].empty()) continue;
    jstring item = env->NewStringUTF(values[i].c_str());
    env->SetObjectArrayElement(array, static_cast<jsize>(i), item);
    env->DeleteLocalRef(item);
  }
  return array;
}

std::vector<double> toDoubleVector(JNIEnv* env, jdoubleArray array) {
  if (array == nullptr) return {};
  jsize length = env->GetArrayLength(array);
  std::vector<double> values(length);
  env->GetDoubleArrayRegion(array, 0, length, values.data());
  return values;
}

bool readDoubleArray(JNIEnv* env, jdoubleArray array, double* values, jsize expectedLength) {
  if (array == nullptr || env->GetArrayLength(array) != expectedLength) return false;
  env->GetDoubleArrayRegion(array, 0, expectedLength, values);
  return true;
}

std::vector<Handle> toHandleVector(JNIEnv* env, jlongArray array) {
  if (array == nullptr) return {};
  jsize length = env->GetArrayLength(array);
  std::vector<Handle> values(length);
  env->GetLongArrayRegion(array, 0, length, values.data());
  return values;
}

Object buildLayoutObject(Runtime& runtime, const double* packed, size_t offset) {
  Object result(runtime);
  result.setProperty(runtime, "width", packed[offset + 0]);
  result.setProperty(runtime, "height", packed[offset + 1]);
  result.setProperty(runtime, "lineCount", packed[offset + 2]);
  result.setProperty(runtime, "lastLineWidth", packed[offset + 3]);
  return result;
}

Object buildLayoutObject(Runtime& runtime, const std::vector<double>& packed, size_t offset) {
  return buildLayoutObject(runtime, packed.data(), offset);
}

Value buildLayoutLinesObject(Runtime& runtime, const std::vector<double>& packed) {
  if (packed.size() < PACKED_LAYOUT_SIZE) {
    throwJSError(runtime, "RNTextEngine: native layoutLines() returned an invalid payload.");
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

Value buildNextLineObject(Runtime& runtime, const double* packed) {
  Object line(runtime);
  line.setProperty(runtime, "start", packed[0]);
  line.setProperty(runtime, "end", packed[1]);
  line.setProperty(runtime, "width", packed[2]);
  line.setProperty(runtime, "bottom", packed[3]);
  return line;
}

Array buildLayoutBatchArray(Runtime& runtime, const std::vector<double>& packed) {
  if (packed.size() % PACKED_LAYOUT_SIZE != 0) {
    throwJSError(runtime, "RNTextEngine: native batch layout returned an invalid payload.");
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

template <typename Fn>
void withStyle(JNIEnv* env, const StyleArgs& style, Fn&& fn) {
  jstring color = toJString(env, style.color);
  jstring fontFamily = toJString(env, style.fontFamily);
  jstring fontWeight = toJString(env, style.fontWeight);
  jstring fontStyle = toJString(env, style.fontStyle);
  jstring textBreakStrategy = toJString(env, style.textBreakStrategy);

  fn(color, fontFamily, fontWeight, fontStyle, textBreakStrategy);

  if (color) env->DeleteLocalRef(color);
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
  {
    std::lock_guard<std::mutex> lock(glyphFieldBufferMutex_);
    glyphFieldBuffers_.clear();
  }
  if (stringClass_ != nullptr) {
    env->DeleteGlobalRef(stringClass_);
    stringClass_ = nullptr;
  }
  env->DeleteGlobalRef(bindingsClass_);
  bindingsClass_ = nullptr;
}

double currentFontScaleMultiplier() {
  bool needsDetach = false;
  JNIEnv* env = getEnv(needsDetach);
  if (env == nullptr) return 1.0;

  initializeIfNeeded(env, nullptr);
  const jdouble multiplier =
      env->CallStaticDoubleMethod(bindingsClass_, currentFontScaleMultiplierMethod_);
  clearPendingException(
      env,
      "RNTextEngine: native font-scale multiplier lookup failed.");
  if (needsDetach) jvm_->DetachCurrentThread();
  return static_cast<double>(multiplier);
}

uint64_t prepareTextViewMeasurementHandle(
    const std::string& text,
    bool allowFontScaling,
    const std::string& fontFamily,
    double fontSize,
    const std::string& fontWeight,
    const std::string& fontStyle,
    double letterSpacing,
    double lineHeight,
    bool tabularNumbers,
    const TextViewMeasurementRuns& runs) {
  bool needsDetach = false;
  JNIEnv* env = getEnv(needsDetach);
  if (env == nullptr) return 0;

  initializeIfNeeded(env, nullptr);

  jstring textValue = env->NewStringUTF(text.c_str());
  jstring fontFamilyValue = toJString(env, fontFamily);
  jstring fontWeightValue = toJString(env, fontWeight);
  jstring fontStyleValue = toJString(env, fontStyle);

  jlong handle = 0;
  if (runs.starts.empty() || runs.ends.empty() || runs.styleMasks.empty()) {
    handle = env->CallStaticLongMethod(
        bindingsClass_,
        prepareMethod_,
        textValue,
        nullptr,
        fontFamilyValue,
        fontSize,
        fontWeightValue,
        fontStyleValue,
        letterSpacing,
        lineHeight,
        allowFontScaling,
        false,
        tabularNumbers,
        nullptr);
  } else {
    jintArray runStarts = makeJavaIntArray(env, runs.starts);
    jintArray runEnds = makeJavaIntArray(env, runs.ends);
    jintArray runMasks = makeJavaIntArray(env, runs.styleMasks);
    jobjectArray runColors = makeJavaOptionalStringArray(env, std::vector<std::string>(runs.starts.size()));
    jobjectArray runFontFamilies = makeJavaOptionalStringArray(env, runs.fontFamilies);
    jdoubleArray runFontSizes = makeJavaDoubleArray(env, runs.fontSizes);
    jobjectArray runFontWeights = makeJavaOptionalStringArray(env, runs.fontWeights);
    jobjectArray runFontStyles = makeJavaOptionalStringArray(env, runs.fontStyles);
    jdoubleArray runLetterSpacings = makeJavaDoubleArray(env, runs.letterSpacings);
    jdoubleArray runLineHeights = makeJavaDoubleArray(env, runs.lineHeights);
    jbooleanArray runTabularNumbers = makeJavaBooleanArray(env, runs.tabularNumbers);

    handle = env->CallStaticLongMethod(
        bindingsClass_,
        prepareWithRunsMethod_,
        textValue,
        nullptr,
        fontFamilyValue,
        fontSize,
        fontWeightValue,
        fontStyleValue,
        letterSpacing,
        lineHeight,
        allowFontScaling,
        false,
        tabularNumbers,
        nullptr,
        runStarts,
        runEnds,
        runMasks,
        runColors,
        runFontFamilies,
        runFontSizes,
        runFontWeights,
        runFontStyles,
        runLetterSpacings,
        runLineHeights,
        runTabularNumbers);

    env->DeleteLocalRef(runStarts);
    env->DeleteLocalRef(runEnds);
    env->DeleteLocalRef(runMasks);
    env->DeleteLocalRef(runColors);
    env->DeleteLocalRef(runFontFamilies);
    env->DeleteLocalRef(runFontSizes);
    env->DeleteLocalRef(runFontWeights);
    env->DeleteLocalRef(runFontStyles);
    env->DeleteLocalRef(runLetterSpacings);
    env->DeleteLocalRef(runLineHeights);
    env->DeleteLocalRef(runTabularNumbers);
  }

  clearPendingException(env, "RNTextEngine: native TextView measurement prepare() failed.");

  env->DeleteLocalRef(textValue);
  if (fontFamilyValue) env->DeleteLocalRef(fontFamilyValue);
  if (fontWeightValue) env->DeleteLocalRef(fontWeightValue);
  if (fontStyleValue) env->DeleteLocalRef(fontStyleValue);
  if (needsDetach) jvm_->DetachCurrentThread();
  return static_cast<uint64_t>(handle);
}

double measurePreparedTextMeasurementWidth(uint64_t handle) {
  bool needsDetach = false;
  JNIEnv* env = getEnv(needsDetach);
  if (env == nullptr) return 0;

  initializeIfNeeded(env, nullptr);
  jdouble width = env->CallStaticDoubleMethod(bindingsClass_, measurePreparedWidthMethod_, static_cast<jlong>(handle));
  clearPendingException(env, "RNTextEngine: native measurePreparedWidth() failed.");
  if (needsDetach) jvm_->DetachCurrentThread();
  return width;
}

PreparedTextLayoutMeasurement measurePreparedTextMeasurementLayout(
    uint64_t handle,
    double width,
    int maxLines,
    const std::string& ellipsizeMode,
    bool anchorToCapHeight) {
  bool needsDetach = false;
  JNIEnv* env = getEnv(needsDetach);
  if (env == nullptr) return {};

  initializeIfNeeded(env, nullptr);
  jstring ellipsizeModeValue = toJString(env, ellipsizeMode);
  jdoubleArray packed = reinterpret_cast<jdoubleArray>(env->CallStaticObjectMethod(
      bindingsClass_,
      layoutMethod_,
      static_cast<jlong>(handle),
      width,
      static_cast<jint>(maxLines),
      ellipsizeModeValue,
      anchorToCapHeight));

  clearPendingException(env, "RNTextEngine: native TextView measurement layout() failed.");
  std::vector<double> values = toDoubleVector(env, packed);

  if (ellipsizeModeValue) env->DeleteLocalRef(ellipsizeModeValue);
  if (packed) env->DeleteLocalRef(packed);
  if (needsDetach) jvm_->DetachCurrentThread();

  if (values.size() < PACKED_LAYOUT_SIZE) return {};
  return {.height = values[1], .width = values[0]};
}

void releasePreparedTextMeasurementHandle(uint64_t handle) {
  if (handle == 0) return;

  bool needsDetach = false;
  JNIEnv* env = getEnv(needsDetach);
  if (env == nullptr) return;

  initializeIfNeeded(env, nullptr);
  env->CallStaticVoidMethod(bindingsClass_, releaseMethod_, static_cast<jlong>(handle));
  clearPendingException(env, "RNTextEngine: native TextView measurement release() failed.");
  if (needsDetach) jvm_->DetachCurrentThread();
}

void install(Runtime& runtime) {
  if (bindingsClass_ == nullptr) {
    throwJSError(runtime, "RNTextEngine: native bindings must be initialized before installing additional runtimes.");
  }

  auto installFunction = [&](const char* name, unsigned int argCount, auto fn) {
    runtime.global().setProperty(
        runtime,
        name,
        Function::createFromHostFunction(runtime, PropNameID::forAscii(runtime, name), argCount, fn));
  };

#if RNTEXTENGINE_HAS_WORKLETS
  installFunction(
      "__RNTextEngineInstallWorkletRuntime",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isObject()) {
          throwJSError(
              runtime,
              "RNTextEngine: installWorkletRuntime() requires a WorkletRuntime.");
        }

        std::shared_ptr<worklets::WorkletRuntime> workletRuntime;
        try {
          Object runtimeObject = arguments[0].asObject(runtime);
          if (runtimeObject.isHostObject<worklets::WorkletRuntime>(runtime)) {
            workletRuntime = worklets::extractWorkletRuntime(runtime, arguments[0]);
          } else {
            workletRuntime = worklets::getWorkletRuntimeFromHolder(runtime, runtimeObject);
          }
        } catch (...) {
          throwJSError(
              runtime,
              "RNTextEngine: installWorkletRuntime() requires a WorkletRuntime.");
        }

        if (!workletRuntime) return Value(false);

        rntextengine::install(workletRuntime->getJSIRuntime());
        return Value(true);
      });
#endif

  installFunction(
      "__RNTextEngineCreateGlyphField",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throwJSError(runtime, "RNTextEngine: createGlyphField() requires a config object.");
        }

        GlyphFieldArgs field = parseGlyphField(runtime, arguments[0]);
        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNTextEngine: failed to access JNI environment.");

        jstring fontFamily = toJString(env, field.fontFamily);
        jstring glyphPalette = toJString(env, field.glyphPalette);
        jstring textAlign = toJString(env, field.textAlign);
        std::vector<std::string> colors;
        std::vector<std::string> fontWeights;
        std::vector<std::string> fontStyles;
        colors.reserve(field.variants.size());
        fontWeights.reserve(field.variants.size());
        fontStyles.reserve(field.variants.size());

        for (const GlyphFieldVariantArgs& variant : field.variants) {
          colors.push_back(variant.color);
          fontWeights.push_back(variant.fontWeight);
          fontStyles.push_back(variant.fontStyle);
        }

        jobjectArray variantColors = makeJavaStringArray(env, colors);
        jobjectArray variantFontWeights = makeJavaOptionalStringArray(env, fontWeights);
        jobjectArray variantFontStyles = makeJavaOptionalStringArray(env, fontStyles);
        jlong handle = env->CallStaticLongMethod(
            bindingsClass_,
            createGlyphFieldMethod_,
            field.columns,
            field.rows,
            fontFamily,
            field.fontSize,
            glyphPalette,
            std::isnan(field.letterSpacing) ? 0.0 : field.letterSpacing,
            field.lineHeight,
            textAlign,
            variantColors,
            variantFontWeights,
            variantFontStyles);

        if (fontFamily) env->DeleteLocalRef(fontFamily);
        if (glyphPalette) env->DeleteLocalRef(glyphPalette);
        if (textAlign) env->DeleteLocalRef(textAlign);
        env->DeleteLocalRef(variantColors);
        env->DeleteLocalRef(variantFontWeights);
        env->DeleteLocalRef(variantFontStyles);

        clearPendingException(env, runtime, "RNTextEngine: native createGlyphField() failed.");
        if (needsDetach) jvm_->DetachCurrentThread();
        return static_cast<double>(handle);
      });

  installFunction(
      "__RNTextEngineCreateGlyphFieldBuffers",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throwJSError(runtime, "RNTextEngine: createGlyphFieldBuffers() requires a glyph field handle.");
        }

        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNTextEngine: failed to access JNI environment.");

        Handle handle = static_cast<Handle>(arguments[0].asNumber());
        jint cellCount = env->CallStaticIntMethod(bindingsClass_, getGlyphFieldCellCountMethod_, static_cast<jlong>(handle));
        clearPendingException(env, runtime, "RNTextEngine: native getGlyphFieldCellCount() failed.");

        std::shared_ptr<GlyphFieldBufferSet> buffers = getOrCreateGlyphFieldBuffers(handle, static_cast<size_t>(cellCount));
        jobject glyphIndicesBuffer = env->NewDirectByteBuffer(buffers->glyphIndices->data(), cellCount);
        jobject variantIndicesBuffer = env->NewDirectByteBuffer(buffers->variantIndices->data(), cellCount);
        env->CallStaticVoidMethod(
            bindingsClass_,
            attachGlyphFieldBuffersMethod_,
            static_cast<jlong>(handle),
            glyphIndicesBuffer,
            variantIndicesBuffer);
        clearPendingException(env, runtime, "RNTextEngine: native attachGlyphFieldBuffers() failed.");

        Object result(runtime);
        result.setProperty(runtime, "glyphIndices", ArrayBuffer(runtime, buffers->glyphIndices));
        result.setProperty(runtime, "variantIndices", ArrayBuffer(runtime, buffers->variantIndices));

        env->DeleteLocalRef(glyphIndicesBuffer);
        env->DeleteLocalRef(variantIndicesBuffer);
        if (needsDetach) jvm_->DetachCurrentThread();
        return result;
      });

  installFunction(
      "__RNTextEngineCommitGlyphFieldBuffers",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throwJSError(runtime, "RNTextEngine: commitGlyphFieldBuffers() requires a glyph field handle.");
        }

        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNTextEngine: failed to access JNI environment.");

        jlong handle = static_cast<jlong>(arguments[0].asNumber());
        getGlyphFieldBuffers(runtime, static_cast<Handle>(handle));
        env->CallStaticVoidMethod(bindingsClass_, commitGlyphFieldBuffersMethod_, handle);
        clearPendingException(env, runtime, "RNTextEngine: native commitGlyphFieldBuffers() failed.");
        if (needsDetach) jvm_->DetachCurrentThread();
        return Value::undefined();
      });

  installFunction(
      "__RNTextEngineUpdateGlyphField",
      3,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count < 3 || !arguments[0].isNumber() || !arguments[1].isString()) {
          throwJSError(runtime, "RNTextEngine: updateGlyphField() requires a handle, glyph string, and Uint8Array.");
        }

        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNTextEngine: failed to access JNI environment.");

        jlong handle = static_cast<jlong>(arguments[0].asNumber());
        std::string glyphsValue = arguments[1].asString(runtime).utf8(runtime);
        Uint8ArrayView variantIndices = parseUint8Array(runtime, arguments[2], glyphsValue.size());
        jstring glyphs = env->NewStringUTF(glyphsValue.c_str());
        jbyteArray variantIndicesArray = makeJavaByteArray(env, variantIndices);

        env->CallStaticVoidMethod(bindingsClass_, updateGlyphFieldMethod_, handle, glyphs, variantIndicesArray);

        env->DeleteLocalRef(glyphs);
        env->DeleteLocalRef(variantIndicesArray);
        clearPendingException(env, runtime, "RNTextEngine: native updateGlyphField() failed.");
        if (needsDetach) jvm_->DetachCurrentThread();
        return Value::undefined();
      });

  installFunction(
      "__RNTextEngineUpdateGlyphFieldIndices",
      3,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count < 3 || !arguments[0].isNumber()) {
          throwJSError(runtime, "RNTextEngine: updateGlyphFieldIndices() requires a handle, glyphIndices Uint8Array, and Uint8Array.");
        }

        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNTextEngine: failed to access JNI environment.");

        jlong handle = static_cast<jlong>(arguments[0].asNumber());
        Uint8ArrayView glyphIndices = parseUint8Array(runtime, arguments[1]);
        Uint8ArrayView variantIndices = parseUint8Array(runtime, arguments[2], glyphIndices.length);
        jbyteArray glyphIndicesArray = makeJavaByteArray(env, glyphIndices);
        jbyteArray variantIndicesArray = makeJavaByteArray(env, variantIndices);

        env->CallStaticVoidMethod(bindingsClass_, updateGlyphFieldIndicesMethod_, handle, glyphIndicesArray, variantIndicesArray);

        env->DeleteLocalRef(glyphIndicesArray);
        env->DeleteLocalRef(variantIndicesArray);
        clearPendingException(env, runtime, "RNTextEngine: native updateGlyphFieldIndices() failed.");
        if (needsDetach) jvm_->DetachCurrentThread();
        return Value::undefined();
      });

  installFunction(
      "__RNTextEngineReleaseGlyphField",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throwJSError(runtime, "RNTextEngine: releaseGlyphField() requires a glyph field handle.");
        }

        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNTextEngine: failed to access JNI environment.");

        Handle handle = static_cast<Handle>(arguments[0].asNumber());
        env->CallStaticVoidMethod(bindingsClass_, releaseGlyphFieldMethod_, static_cast<jlong>(handle));
        {
          std::lock_guard<std::mutex> lock(glyphFieldBufferMutex_);
          glyphFieldBuffers_.erase(handle);
        }
        clearPendingException(env, runtime, "RNTextEngine: native releaseGlyphField() failed.");
        if (needsDetach) jvm_->DetachCurrentThread();
        return Value::undefined();
      });

  installFunction(
      "__RNTextEnginePrepare",
      3,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isString()) {
          throwJSError(runtime, "RNTextEngine: prepare() requires a text string.");
        }

        StyleArgs style = parseStyle(runtime, arguments, 1, count);
        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNTextEngine: failed to access JNI environment.");

        std::string textValue = arguments[0].asString(runtime).utf8(runtime);
        std::vector<TextRunArgs> runs =
            count > 2 ? parseRuns(runtime, arguments[2]) : std::vector<TextRunArgs> {};
        jstring text = env->NewStringUTF(textValue.c_str());
        jlong handle = 0;

        withStyle(env, style, [&](jstring color, jstring fontFamily, jstring fontWeight, jstring fontStyle, jstring textBreakStrategy) {
          if (runs.empty()) {
            handle = env->CallStaticLongMethod(
                bindingsClass_,
                prepareMethod_,
                text,
                color,
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
            return;
          }

          FlattenedRuns flattened = flattenRuns(runs);
          jintArray runStarts = makeJavaIntArray(env, flattened.starts);
          jintArray runEnds = makeJavaIntArray(env, flattened.ends);
          jintArray runMasks = makeJavaIntArray(env, flattened.masks);
          jobjectArray runColors = makeJavaOptionalStringArray(env, flattened.colors);
          jobjectArray runFontFamilies = makeJavaOptionalStringArray(env, flattened.fontFamilies);
          jdoubleArray runFontSizes = makeJavaDoubleArray(env, flattened.fontSizes);
          jobjectArray runFontWeights = makeJavaOptionalStringArray(env, flattened.fontWeights);
          jobjectArray runFontStyles = makeJavaOptionalStringArray(env, flattened.fontStyles);
          jdoubleArray runLetterSpacings = makeJavaDoubleArray(env, flattened.letterSpacings);
          jdoubleArray runLineHeights = makeJavaDoubleArray(env, flattened.lineHeights);
          jbooleanArray runTabularNumbers = makeJavaBooleanArray(env, flattened.tabularNumbers);

          handle = env->CallStaticLongMethod(
              bindingsClass_,
              prepareWithRunsMethod_,
              text,
              color,
              fontFamily,
              style.fontSize,
              fontWeight,
              fontStyle,
              style.letterSpacing,
              style.lineHeight,
              style.allowFontScaling,
              style.includeFontPadding,
              style.tabularNumbers,
              textBreakStrategy,
              runStarts,
              runEnds,
              runMasks,
              runColors,
              runFontFamilies,
              runFontSizes,
              runFontWeights,
              runFontStyles,
              runLetterSpacings,
              runLineHeights,
              runTabularNumbers);

          env->DeleteLocalRef(runStarts);
          env->DeleteLocalRef(runEnds);
          env->DeleteLocalRef(runMasks);
          env->DeleteLocalRef(runColors);
          env->DeleteLocalRef(runFontFamilies);
          env->DeleteLocalRef(runFontSizes);
          env->DeleteLocalRef(runFontWeights);
          env->DeleteLocalRef(runFontStyles);
          env->DeleteLocalRef(runLetterSpacings);
          env->DeleteLocalRef(runLineHeights);
          env->DeleteLocalRef(runTabularNumbers);
        });

        env->DeleteLocalRef(text);
        clearPendingException(env, runtime, "RNTextEngine: native prepare() failed.");
        if (needsDetach) jvm_->DetachCurrentThread();
        return static_cast<double>(handle);
      });

  installFunction(
      "__RNTextEnginePrepareBatch",
      3,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throwJSError(runtime, "RNTextEngine: prepareBatch() requires an array of strings.");
        }

        std::vector<std::string> texts = parseTextArray(runtime, arguments[0]);
        std::vector<std::vector<TextRunArgs>> runsByText =
            count > 2 ? parseRunsByText(runtime, arguments[2], texts) : std::vector<std::vector<TextRunArgs>> {};
        StyleArgs style = parseStyle(runtime, arguments, 1, count);
        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNTextEngine: failed to access JNI environment.");

        jobjectArray textArray = makeJavaStringArray(env, texts);
        jlongArray handles = nullptr;

        withStyle(env, style, [&](jstring color, jstring fontFamily, jstring fontWeight, jstring fontStyle, jstring textBreakStrategy) {
          if (runsByText.empty() || !hasAnyRuns(runsByText)) {
            handles = reinterpret_cast<jlongArray>(env->CallStaticObjectMethod(
                bindingsClass_,
                prepareBatchMethod_,
                textArray,
                color,
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
            return;
          }

          FlattenedRuns flattened = flattenRuns(runsByText);
          jintArray runCounts = makeJavaIntArray(env, flattened.counts);
          jintArray runStarts = makeJavaIntArray(env, flattened.starts);
          jintArray runEnds = makeJavaIntArray(env, flattened.ends);
          jintArray runMasks = makeJavaIntArray(env, flattened.masks);
          jobjectArray runColors = makeJavaOptionalStringArray(env, flattened.colors);
          jobjectArray runFontFamilies = makeJavaOptionalStringArray(env, flattened.fontFamilies);
          jdoubleArray runFontSizes = makeJavaDoubleArray(env, flattened.fontSizes);
          jobjectArray runFontWeights = makeJavaOptionalStringArray(env, flattened.fontWeights);
          jobjectArray runFontStyles = makeJavaOptionalStringArray(env, flattened.fontStyles);
          jdoubleArray runLetterSpacings = makeJavaDoubleArray(env, flattened.letterSpacings);
          jdoubleArray runLineHeights = makeJavaDoubleArray(env, flattened.lineHeights);
          jbooleanArray runTabularNumbers = makeJavaBooleanArray(env, flattened.tabularNumbers);

          handles = reinterpret_cast<jlongArray>(env->CallStaticObjectMethod(
              bindingsClass_,
              prepareBatchWithRunsMethod_,
              textArray,
              color,
              fontFamily,
              style.fontSize,
              fontWeight,
              fontStyle,
              style.letterSpacing,
              style.lineHeight,
              style.allowFontScaling,
              style.includeFontPadding,
              style.tabularNumbers,
              textBreakStrategy,
              runCounts,
              runStarts,
              runEnds,
              runMasks,
              runColors,
              runFontFamilies,
              runFontSizes,
              runFontWeights,
              runFontStyles,
              runLetterSpacings,
              runLineHeights,
              runTabularNumbers));

          env->DeleteLocalRef(runCounts);
          env->DeleteLocalRef(runStarts);
          env->DeleteLocalRef(runEnds);
          env->DeleteLocalRef(runMasks);
          env->DeleteLocalRef(runColors);
          env->DeleteLocalRef(runFontFamilies);
          env->DeleteLocalRef(runFontSizes);
          env->DeleteLocalRef(runFontWeights);
          env->DeleteLocalRef(runFontStyles);
          env->DeleteLocalRef(runLetterSpacings);
          env->DeleteLocalRef(runLineHeights);
          env->DeleteLocalRef(runTabularNumbers);
        });

        env->DeleteLocalRef(textArray);
        clearPendingException(env, runtime, "RNTextEngine: native prepareBatch() failed.");
        std::vector<Handle> values = toHandleVector(env, handles);
        if (handles) env->DeleteLocalRef(handles);
        if (needsDetach) jvm_->DetachCurrentThread();
        return buildHandleArray(runtime, values);
      });

  installFunction(
      "__RNTextEngineRelease",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throwJSError(runtime, "RNTextEngine: release() requires a prepared text handle.");
        }

        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNTextEngine: failed to access JNI environment.");

        env->CallStaticVoidMethod(bindingsClass_, releaseMethod_, static_cast<jlong>(arguments[0].asNumber()));
        clearPendingException(env, runtime, "RNTextEngine: native release() failed.");
        if (needsDetach) jvm_->DetachCurrentThread();
        return Value::undefined();
      });

  installFunction(
      "__RNTextEngineReleaseMany",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throwJSError(runtime, "RNTextEngine: releaseMany() requires an array of handles.");
        }
        std::vector<Handle> handles = parseHandleArray(runtime, arguments[0]);
        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNTextEngine: failed to access JNI environment.");

        jlongArray array = makeJavaLongArray(env, handles);
        env->CallStaticVoidMethod(bindingsClass_, releaseManyMethod_, array);
        env->DeleteLocalRef(array);
        clearPendingException(env, runtime, "RNTextEngine: native releaseMany() failed.");
        if (needsDetach) jvm_->DetachCurrentThread();
        return Value::undefined();
      });

  installFunction(
      "__RNTextEngineMeasureWidth",
      3,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isString()) {
          throwJSError(runtime, "RNTextEngine: measureWidth() requires a text string.");
        }
        StyleArgs style = parseStyle(runtime, arguments, 1, count);
        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNTextEngine: failed to access JNI environment.");

        std::string textValue = arguments[0].asString(runtime).utf8(runtime);
        std::vector<TextRunArgs> runs =
            count > 2 ? parseRuns(runtime, arguments[2]) : std::vector<TextRunArgs> {};
        jstring text = env->NewStringUTF(textValue.c_str());
        jdouble width = 0;

        withStyle(env, style, [&](jstring color, jstring fontFamily, jstring fontWeight, jstring fontStyle, jstring textBreakStrategy) {
          if (runs.empty()) {
            width = env->CallStaticDoubleMethod(
                bindingsClass_,
                measureWidthMethod_,
                text,
                color,
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
            return;
          }

          FlattenedRuns flattened = flattenRuns(runs);
          jintArray runStarts = makeJavaIntArray(env, flattened.starts);
          jintArray runEnds = makeJavaIntArray(env, flattened.ends);
          jintArray runMasks = makeJavaIntArray(env, flattened.masks);
          jobjectArray runColors = makeJavaOptionalStringArray(env, flattened.colors);
          jobjectArray runFontFamilies = makeJavaOptionalStringArray(env, flattened.fontFamilies);
          jdoubleArray runFontSizes = makeJavaDoubleArray(env, flattened.fontSizes);
          jobjectArray runFontWeights = makeJavaOptionalStringArray(env, flattened.fontWeights);
          jobjectArray runFontStyles = makeJavaOptionalStringArray(env, flattened.fontStyles);
          jdoubleArray runLetterSpacings = makeJavaDoubleArray(env, flattened.letterSpacings);
          jdoubleArray runLineHeights = makeJavaDoubleArray(env, flattened.lineHeights);
          jbooleanArray runTabularNumbers = makeJavaBooleanArray(env, flattened.tabularNumbers);

          width = env->CallStaticDoubleMethod(
              bindingsClass_,
              measureWidthWithRunsMethod_,
              text,
              color,
              fontFamily,
              style.fontSize,
              fontWeight,
              fontStyle,
              style.letterSpacing,
              style.lineHeight,
              style.allowFontScaling,
              style.includeFontPadding,
              style.tabularNumbers,
              textBreakStrategy,
              runStarts,
              runEnds,
              runMasks,
              runColors,
              runFontFamilies,
              runFontSizes,
              runFontWeights,
              runFontStyles,
              runLetterSpacings,
              runLineHeights,
              runTabularNumbers);

          env->DeleteLocalRef(runStarts);
          env->DeleteLocalRef(runEnds);
          env->DeleteLocalRef(runMasks);
          env->DeleteLocalRef(runColors);
          env->DeleteLocalRef(runFontFamilies);
          env->DeleteLocalRef(runFontSizes);
          env->DeleteLocalRef(runFontWeights);
          env->DeleteLocalRef(runFontStyles);
          env->DeleteLocalRef(runLetterSpacings);
          env->DeleteLocalRef(runLineHeights);
          env->DeleteLocalRef(runTabularNumbers);
        });

        env->DeleteLocalRef(text);
        clearPendingException(env, runtime, "RNTextEngine: native measureWidth() failed.");
        if (needsDetach) jvm_->DetachCurrentThread();
        return width;
      });

  auto callPackedLayout =
      [&](Runtime& runtime,
          const char* errorMessage,
          jmethodID method,
          const StyleArgs* style,
          const std::vector<std::string>* texts,
          const std::vector<TextRunArgs>* runs,
          const std::vector<std::vector<TextRunArgs>>* runsByText,
          const std::vector<Handle>* handles,
          const LayoutArgs& layout,
          bool includeLines) -> Value {
        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNTextEngine: failed to access JNI environment.");

        jdoubleArray packed = nullptr;
        jstring ellipsize = toJString(env, layout.ellipsizeMode);

        if (texts != nullptr) {
          bool isSingleTextCall = texts->size() == 1 && method != measureBatchMethod_ && method != measureBatchWithRunsMethod_;
          jobjectArray textArray = isSingleTextCall ? nullptr : makeJavaStringArray(env, *texts);
          auto makeSingleText = [&]() -> jstring {
            return env->NewStringUTF(texts->front().c_str());
          };
          if (style == nullptr) {
            if (isSingleTextCall) {
              jstring text = makeSingleText();
              packed = reinterpret_cast<jdoubleArray>(
                  env->CallStaticObjectMethod(
                      bindingsClass_,
                      method,
                      text,
                      layout.width,
                      layout.maxLines,
                      ellipsize,
                      layout.anchorToCapHeight));
              env->DeleteLocalRef(text);
            } else {
              packed = reinterpret_cast<jdoubleArray>(
                  env->CallStaticObjectMethod(
                      bindingsClass_,
                      method,
                      textArray,
                      layout.width,
                      layout.maxLines,
                      ellipsize,
                      layout.anchorToCapHeight));
            }
          } else if (runs != nullptr && !runs->empty()) {
            withStyle(env, *style, [&](jstring color, jstring fontFamily, jstring fontWeight, jstring fontStyle, jstring textBreakStrategy) {
              FlattenedRuns flattened = flattenRuns(*runs);
              jstring text = makeSingleText();
              jintArray runStarts = makeJavaIntArray(env, flattened.starts);
              jintArray runEnds = makeJavaIntArray(env, flattened.ends);
              jintArray runMasks = makeJavaIntArray(env, flattened.masks);
              jobjectArray runColors = makeJavaOptionalStringArray(env, flattened.colors);
              jobjectArray runFontFamilies = makeJavaOptionalStringArray(env, flattened.fontFamilies);
              jdoubleArray runFontSizes = makeJavaDoubleArray(env, flattened.fontSizes);
              jobjectArray runFontWeights = makeJavaOptionalStringArray(env, flattened.fontWeights);
              jobjectArray runFontStyles = makeJavaOptionalStringArray(env, flattened.fontStyles);
              jdoubleArray runLetterSpacings = makeJavaDoubleArray(env, flattened.letterSpacings);
              jdoubleArray runLineHeights = makeJavaDoubleArray(env, flattened.lineHeights);
              jbooleanArray runTabularNumbers = makeJavaBooleanArray(env, flattened.tabularNumbers);

              packed = reinterpret_cast<jdoubleArray>(env->CallStaticObjectMethod(
                  bindingsClass_,
                  measureWithRunsMethod_,
                  text,
                  color,
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
                  ellipsize,
                  layout.anchorToCapHeight,
                  runStarts,
                  runEnds,
                  runMasks,
                  runColors,
                  runFontFamilies,
                  runFontSizes,
                  runFontWeights,
                  runFontStyles,
                  runLetterSpacings,
                  runLineHeights,
                  runTabularNumbers));

              env->DeleteLocalRef(text);
              env->DeleteLocalRef(runStarts);
              env->DeleteLocalRef(runEnds);
              env->DeleteLocalRef(runMasks);
              env->DeleteLocalRef(runColors);
              env->DeleteLocalRef(runFontFamilies);
              env->DeleteLocalRef(runFontSizes);
              env->DeleteLocalRef(runFontWeights);
              env->DeleteLocalRef(runFontStyles);
              env->DeleteLocalRef(runLetterSpacings);
              env->DeleteLocalRef(runLineHeights);
              env->DeleteLocalRef(runTabularNumbers);
            });
          } else if (runsByText != nullptr && !runsByText->empty() && hasAnyRuns(*runsByText)) {
            withStyle(env, *style, [&](jstring color, jstring fontFamily, jstring fontWeight, jstring fontStyle, jstring textBreakStrategy) {
              FlattenedRuns flattened = flattenRuns(*runsByText);
              jintArray runCounts = makeJavaIntArray(env, flattened.counts);
              jintArray runStarts = makeJavaIntArray(env, flattened.starts);
              jintArray runEnds = makeJavaIntArray(env, flattened.ends);
              jintArray runMasks = makeJavaIntArray(env, flattened.masks);
              jobjectArray runColors = makeJavaOptionalStringArray(env, flattened.colors);
              jobjectArray runFontFamilies = makeJavaOptionalStringArray(env, flattened.fontFamilies);
              jdoubleArray runFontSizes = makeJavaDoubleArray(env, flattened.fontSizes);
              jobjectArray runFontWeights = makeJavaOptionalStringArray(env, flattened.fontWeights);
              jobjectArray runFontStyles = makeJavaOptionalStringArray(env, flattened.fontStyles);
              jdoubleArray runLetterSpacings = makeJavaDoubleArray(env, flattened.letterSpacings);
              jdoubleArray runLineHeights = makeJavaDoubleArray(env, flattened.lineHeights);
              jbooleanArray runTabularNumbers = makeJavaBooleanArray(env, flattened.tabularNumbers);

              packed = reinterpret_cast<jdoubleArray>(env->CallStaticObjectMethod(
                  bindingsClass_,
                  measureBatchWithRunsMethod_,
                  textArray,
                  color,
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
                  ellipsize,
                  layout.anchorToCapHeight,
                  runCounts,
                  runStarts,
                  runEnds,
                  runMasks,
                  runColors,
                  runFontFamilies,
                  runFontSizes,
                  runFontWeights,
                  runFontStyles,
                  runLetterSpacings,
                  runLineHeights,
                  runTabularNumbers));

              env->DeleteLocalRef(runCounts);
              env->DeleteLocalRef(runStarts);
              env->DeleteLocalRef(runEnds);
              env->DeleteLocalRef(runMasks);
              env->DeleteLocalRef(runColors);
              env->DeleteLocalRef(runFontFamilies);
              env->DeleteLocalRef(runFontSizes);
              env->DeleteLocalRef(runFontWeights);
              env->DeleteLocalRef(runFontStyles);
              env->DeleteLocalRef(runLetterSpacings);
              env->DeleteLocalRef(runLineHeights);
              env->DeleteLocalRef(runTabularNumbers);
            });
          } else {
            withStyle(env, *style, [&](jstring color, jstring fontFamily, jstring fontWeight, jstring fontStyle, jstring textBreakStrategy) {
              if (isSingleTextCall) {
                jstring text = makeSingleText();
                packed = reinterpret_cast<jdoubleArray>(env->CallStaticObjectMethod(
                    bindingsClass_,
                    method,
                    text,
                    color,
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
                    ellipsize,
                    layout.anchorToCapHeight));
                env->DeleteLocalRef(text);
              } else {
                packed = reinterpret_cast<jdoubleArray>(env->CallStaticObjectMethod(
                    bindingsClass_,
                    method,
                    textArray,
                    color,
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
                    ellipsize,
                    layout.anchorToCapHeight));
              }
            });
          }
          if (textArray) env->DeleteLocalRef(textArray);
        } else if (handles != nullptr) {
          if (handles->size() == 1 && method != layoutBatchMethod_) {
            packed = reinterpret_cast<jdoubleArray>(
                env->CallStaticObjectMethod(
                    bindingsClass_,
                    method,
                    static_cast<jlong>((*handles)[0]),
                    layout.width,
                    layout.maxLines,
                    ellipsize,
                    layout.anchorToCapHeight));
          } else {
            jlongArray handleArray = makeJavaLongArray(env, *handles);
            packed = reinterpret_cast<jdoubleArray>(
                env->CallStaticObjectMethod(
                    bindingsClass_,
                    method,
                    handleArray,
                    layout.width,
                    layout.maxLines,
                    ellipsize,
                    layout.anchorToCapHeight));
            env->DeleteLocalRef(handleArray);
          }
        }

        if (ellipsize) env->DeleteLocalRef(ellipsize);
        clearPendingException(env, runtime, errorMessage);

        if (includeLines || method == measureBatchMethod_ || method == layoutBatchMethod_) {
          std::vector<double> values = toDoubleVector(env, packed);
          if (packed) env->DeleteLocalRef(packed);
          if (needsDetach) jvm_->DetachCurrentThread();

          if (values.size() < PACKED_LAYOUT_SIZE) {
            throwJSError(runtime, errorMessage);
          }

          if (includeLines) return buildLayoutLinesObject(runtime, values);
          return buildLayoutBatchArray(runtime, values);
        }

        double values[PACKED_LAYOUT_SIZE];
        bool didReadValues = readDoubleArray(env, packed, values, PACKED_LAYOUT_SIZE);
        if (packed) env->DeleteLocalRef(packed);
        if (needsDetach) jvm_->DetachCurrentThread();

        if (!didReadValues) throwJSError(runtime, errorMessage);
        return buildLayoutObject(runtime, values, 0);
      };

  installFunction(
      "__RNTextEngineMeasure",
      4,
      [&](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isString()) {
          throwJSError(runtime, "RNTextEngine: measure() requires a text string.");
        }
        StyleArgs style = parseStyle(runtime, arguments, 1, count);
        LayoutArgs layout = parseLayout(runtime, arguments, 2, count);
        std::vector<std::string> texts = {arguments[0].asString(runtime).utf8(runtime)};
        std::vector<TextRunArgs> runs =
            count > 3 ? parseRuns(runtime, arguments[3]) : std::vector<TextRunArgs> {};
        return callPackedLayout(runtime, "RNTextEngine: native measure() failed.", measureMethod_, &style, &texts, &runs, nullptr, nullptr, layout, false);
      });

  installFunction(
      "__RNTextEngineMeasureBatch",
      4,
      [&](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throwJSError(runtime, "RNTextEngine: measureBatch() requires an array of strings.");
        }
        StyleArgs style = parseStyle(runtime, arguments, 1, count);
        LayoutArgs layout = parseLayout(runtime, arguments, 2, count);
        std::vector<std::string> texts = parseTextArray(runtime, arguments[0]);
        std::vector<std::vector<TextRunArgs>> runsByText =
            count > 3 ? parseRunsByText(runtime, arguments[3], texts) : std::vector<std::vector<TextRunArgs>> {};
        return callPackedLayout(runtime, "RNTextEngine: native measureBatch() failed.", measureBatchMethod_, &style, &texts, nullptr, &runsByText, nullptr, layout, false);
      });

  installFunction(
      "__RNTextEngineLayout",
      2,
      [&](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throwJSError(runtime, "RNTextEngine: layout() requires a prepared text handle.");
        }
        LayoutArgs layout = parseLayout(runtime, arguments, 1, count);
        std::vector<Handle> handles = {static_cast<Handle>(arguments[0].asNumber())};
        return callPackedLayout(runtime, "RNTextEngine: native layout() failed.", layoutMethod_, nullptr, nullptr, nullptr, nullptr, &handles, layout, false);
      });

  installFunction(
      "__RNTextEngineLayoutBatch",
      2,
      [&](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throwJSError(runtime, "RNTextEngine: layoutBatch() requires an array of handles.");
        }
        LayoutArgs layout = parseLayout(runtime, arguments, 1, count);
        std::vector<Handle> handles = parseHandleArray(runtime, arguments[0]);
        return callPackedLayout(runtime, "RNTextEngine: native layoutBatch() failed.", layoutBatchMethod_, nullptr, nullptr, nullptr, nullptr, &handles, layout, false);
      });

  installFunction(
      "__RNTextEngineLayoutNextLine",
      3,
      [&](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count < 3 || !arguments[0].isNumber() || !arguments[1].isNumber() || !arguments[2].isNumber()) {
          throwJSError(runtime, "RNTextEngine: layoutNextLine() requires a prepared text handle, start offset, and width.");
        }

        bool needsDetach = false;
        JNIEnv* env = getEnv(needsDetach);
        if (env == nullptr) throwJSError(runtime, "RNTextEngine: failed to access JNI environment.");

        jdoubleArray packed = reinterpret_cast<jdoubleArray>(env->CallStaticObjectMethod(
            bindingsClass_,
            layoutNextLineMethod_,
            static_cast<jlong>(arguments[0].asNumber()),
            static_cast<jint>(arguments[1].asNumber()),
            arguments[2].asNumber(),
            count > 3 && arguments[3].isBool() ? arguments[3].getBool() : false));

        clearPendingException(env, runtime, "RNTextEngine: native layoutNextLine() failed.");
        if (packed == nullptr) {
          if (needsDetach) jvm_->DetachCurrentThread();
          return Value::null();
        }

        double values[PACKED_LINE_SIZE];
        bool didReadValues = readDoubleArray(env, packed, values, PACKED_LINE_SIZE);
        if (packed) env->DeleteLocalRef(packed);
        if (needsDetach) jvm_->DetachCurrentThread();
        if (!didReadValues) {
          throwJSError(runtime, "RNTextEngine: native next-line layout returned an invalid payload.");
        }
        return buildNextLineObject(runtime, values);
      });

  installFunction(
      "__RNTextEngineLayoutLines",
      2,
      [&](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throwJSError(runtime, "RNTextEngine: layoutLines() requires a prepared text handle.");
        }
        LayoutArgs layout = parseLayout(runtime, arguments, 1, count);
        std::vector<Handle> handles = {static_cast<Handle>(arguments[0].asNumber())};
        return callPackedLayout(runtime, "RNTextEngine: native layoutLines() failed.", layoutLinesMethod_, nullptr, nullptr, nullptr, nullptr, &handles, layout, true);
      });
}

} // namespace rntextengine

extern "C" {
JNIEXPORT jboolean JNICALL
Java_com_rntextengine_RNTextEngineModule_nativeInstall(
    JNIEnv* env,
    jobject,
    jlong runtimePointer,
    jobject context) {
  auto runtime = reinterpret_cast<Runtime*>(runtimePointer);
  if (runtime == nullptr) return JNI_FALSE;

  try {
    rntextengine::initializeIfNeeded(env, context);
    rntextengine::install(*runtime);
    return JNI_TRUE;
  } catch (const std::exception& exception) {
    LOGE("Failed to install RNTextEngine: %s", exception.what());
    return JNI_FALSE;
  }
}

JNIEXPORT void JNICALL JNI_OnUnload(JavaVM* vm, void*) {
  JNIEnv* env = nullptr;
  if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) == JNI_OK && env != nullptr) {
    rntextengine::cleanup(env);
  }
}
}
