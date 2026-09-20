#include "RNTextEngineTextViewShadowNode.h"

#include <fbjni/fbjni.h>
#include <jni.h>
#include <react/renderer/core/conversions.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <limits>
#include <stdexcept>
#include <string_view>
#include <unordered_map>
#include <utility>

namespace rntextengine {

namespace {

constexpr auto kPrepareTextViewSignature =
    "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;JZ)J";
constexpr auto kPrepareTextViewWithRunsSignature =
    "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;DLjava/lang/String;Ljava/lang/String;DDZZZLjava/lang/String;[I[I[I[Ljava/lang/String;[Ljava/lang/String;[D[Ljava/lang/String;[Ljava/lang/String;[D[D[ZJZ)J";
constexpr auto kTransformTextWithBoundariesSignature =
    "(Ljava/lang/String;Ljava/lang/String;[I)[Ljava/lang/Object;";

struct JavaBindings {
  jclass bindingsClass = nullptr;
  jclass stringClass = nullptr;
  jmethodID scaleTypographyValueMethod = nullptr;
  jmethodID textEnvironmentVersionMethod = nullptr;
  jmethodID prepareTextViewMethod = nullptr;
  jmethodID prepareTextViewWithRunsMethod = nullptr;
  jmethodID releaseMethod = nullptr;
  jmethodID measurePreparedWidthMethod = nullptr;
  jmethodID measureTextViewMethod = nullptr;
  jmethodID transformTextWithBoundariesMethod = nullptr;

  explicit JavaBindings(JNIEnv* env) {
    jclass localBindingsClass = env->FindClass("com/rntextengine/RNTextEngineBindings");
    bindingsClass = reinterpret_cast<jclass>(env->NewGlobalRef(localBindingsClass));
    env->DeleteLocalRef(localBindingsClass);

    jclass localStringClass = env->FindClass("java/lang/String");
    stringClass = reinterpret_cast<jclass>(env->NewGlobalRef(localStringClass));
    env->DeleteLocalRef(localStringClass);

    scaleTypographyValueMethod =
        env->GetStaticMethodID(bindingsClass, "scaleTypographyValue", "(D)D");
    textEnvironmentVersionMethod = env->GetStaticMethodID(bindingsClass, "textEnvironmentVersion", "()J");
    prepareTextViewMethod = env->GetStaticMethodID(
        bindingsClass,
        "prepareTextView",
        kPrepareTextViewSignature);
    prepareTextViewWithRunsMethod = env->GetStaticMethodID(
        bindingsClass,
        "prepareTextViewWithRuns",
        kPrepareTextViewWithRunsSignature);
    releaseMethod = env->GetStaticMethodID(bindingsClass, "release", "(J)V");
    measurePreparedWidthMethod = env->GetStaticMethodID(bindingsClass, "measurePreparedWidth", "(J)D");
    measureTextViewMethod = env->GetStaticMethodID(bindingsClass, "measureTextView", "(JDIIZ)J");
    transformTextWithBoundariesMethod = env->GetStaticMethodID(
        bindingsClass,
        "transformTextWithBoundaries",
        kTransformTextWithBoundariesSignature);
  }
};

const JavaBindings& getBindings(JNIEnv* env) {
  static const JavaBindings bindings(env);
  return bindings;
}

JavaVM* javaVm() {
  static JavaVM* const vm = [] {
    JavaVM* value = nullptr;
    facebook::jni::Environment::current()->GetJavaVM(&value);
    return value;
  }();
  return vm;
}

bool clearPendingException(JNIEnv* env, const char* fallback) {
  if (!env->ExceptionCheck()) return false;
  env->ExceptionDescribe();
  env->ExceptionClear();
  return true;
}

jstring toJString(const std::string& value) {
  return value.empty() ? nullptr : facebook::jni::make_jstring(value).release();
}

jintArray toIntArray(JNIEnv* env, const std::vector<int>& values) {
  if (values.empty()) return nullptr;

  auto array = env->NewIntArray(static_cast<jsize>(values.size()));
  env->SetIntArrayRegion(
      array,
      0,
      static_cast<jsize>(values.size()),
      reinterpret_cast<const jint*>(values.data()));
  return array;
}

jdoubleArray toDoubleArray(JNIEnv* env, const std::vector<double>& values) {
  if (values.empty()) return nullptr;

  auto array = env->NewDoubleArray(static_cast<jsize>(values.size()));
  env->SetDoubleArrayRegion(
      array,
      0,
      static_cast<jsize>(values.size()),
      reinterpret_cast<const jdouble*>(values.data()));
  return array;
}

jbooleanArray toBooleanArray(JNIEnv* env, const std::vector<bool>& values) {
  if (values.empty()) return nullptr;

  std::vector<jboolean> resolved(values.size());
  for (size_t index = 0; index < values.size(); index += 1) {
    resolved[index] = values[index] ? JNI_TRUE : JNI_FALSE;
  }

  auto array = env->NewBooleanArray(static_cast<jsize>(resolved.size()));
  env->SetBooleanArrayRegion(array, 0, static_cast<jsize>(resolved.size()), resolved.data());
  return array;
}

jobjectArray toStringArray(JNIEnv* env, const std::vector<std::string>& values) {
  if (values.empty()) return nullptr;

  auto array = env->NewObjectArray(static_cast<jsize>(values.size()), getBindings(env).stringClass, nullptr);
  for (size_t index = 0; index < values.size(); index += 1) {
    auto value = toJString(values[index]);
    env->SetObjectArrayElement(array, static_cast<jsize>(index), value);
    if (value != nullptr) env->DeleteLocalRef(value);
  }
  return array;
}

std::vector<int> toIntVector(JNIEnv* env, jintArray array) {
  if (array == nullptr) return {};

  auto size = static_cast<size_t>(env->GetArrayLength(array));
  std::vector<int> values(size);
  env->GetIntArrayRegion(array, 0, static_cast<jsize>(size), reinterpret_cast<jint*>(values.data()));
  return values;
}

void cleanupLocalRef(JNIEnv* env, jobject ref) {
  if (ref != nullptr) env->DeleteLocalRef(ref);
}

JNIEnv* getEnv(bool& needsDetach) {
  JNIEnv* env = nullptr;
  needsDetach = false;

  jint result = javaVm()->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
  if (result == JNI_EDETACHED) {
    if (javaVm()->AttachCurrentThread(&env, nullptr) != JNI_OK) return nullptr;
    needsDetach = true;
    return env;
  }

  return result == JNI_OK ? env : nullptr;
}

} // namespace

static double scaleTypographyValue(double value) {
  bool needsDetach = false;
  JNIEnv* env = getEnv(needsDetach);
  if (env == nullptr) {
    throw std::runtime_error("Unable to retrieve jni environment. Is the thread attached?");
  }
  const auto& bindings = getBindings(env);
  const auto scaledValue = env->CallStaticDoubleMethod(
      bindings.bindingsClass,
      bindings.scaleTypographyValueMethod,
      value);
  clearPendingException(
      env,
      "RNTextEngine: native typography conversion failed.");
  if (needsDetach) javaVm()->DetachCurrentThread();
  return static_cast<double>(scaledValue);
}

uint64_t prepareTextViewMeasurementHandle(
    const std::string& text,
    const std::string& textTransform,
    bool allowFontScaling,
    const std::string& fontFamily,
    double fontSize,
    const std::string& fontWeight,
    const std::string& fontStyle,
    double letterSpacing,
    double lineHeight,
    bool tabularNumbers,
    const TextViewMeasurementRuns& runs,
    uint64_t environmentVersion,
    bool hasNested) {
  bool needsDetach = false;
  JNIEnv* env = getEnv(needsDetach);
  if (env == nullptr) {
    throw std::runtime_error("Unable to retrieve jni environment. Is the thread attached?");
  }
  const auto& bindings = getBindings(env);

  auto textValue = facebook::jni::make_jstring(text).release();
  auto textTransformValue = toJString(textTransform);
  auto fontFamilyValue = toJString(fontFamily);
  auto fontWeightValue = toJString(fontWeight);
  auto fontStyleValue = toJString(fontStyle);

  jlong handle = 0;
  if (runs.starts.empty()) {
    handle = env->CallStaticLongMethod(
        bindings.bindingsClass,
        bindings.prepareTextViewMethod,
        textValue,
        textTransformValue,
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
        static_cast<jlong>(environmentVersion),
        static_cast<jboolean>(hasNested));
  } else {
    auto runStarts = toIntArray(env, runs.starts);
    auto runEnds = toIntArray(env, runs.ends);
    auto runStyleMasks = toIntArray(env, runs.styleMasks);
    auto runColors = toStringArray(env, runs.colors);
    auto runFontFamilies = toStringArray(env, runs.fontFamilies);
    auto runFontSizes = toDoubleArray(env, runs.fontSizes);
    auto runFontWeights = toStringArray(env, runs.fontWeights);
    auto runFontStyles = toStringArray(env, runs.fontStyles);
    auto runLetterSpacings = toDoubleArray(env, runs.letterSpacings);
    auto runLineHeights = toDoubleArray(env, runs.lineHeights);
    auto runTabularNumbers = toBooleanArray(env, runs.tabularNumbers);

    handle = env->CallStaticLongMethod(
        bindings.bindingsClass,
        bindings.prepareTextViewWithRunsMethod,
        textValue,
        textTransformValue,
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
        runStyleMasks,
        runColors,
        runFontFamilies,
        runFontSizes,
        runFontWeights,
        runFontStyles,
        runLetterSpacings,
        runLineHeights,
        runTabularNumbers,
        static_cast<jlong>(environmentVersion),
        static_cast<jboolean>(hasNested));

    cleanupLocalRef(env, runStarts);
    cleanupLocalRef(env, runEnds);
    cleanupLocalRef(env, runStyleMasks);
    cleanupLocalRef(env, runColors);
    cleanupLocalRef(env, runFontFamilies);
    cleanupLocalRef(env, runFontSizes);
    cleanupLocalRef(env, runFontWeights);
    cleanupLocalRef(env, runFontStyles);
    cleanupLocalRef(env, runLetterSpacings);
    cleanupLocalRef(env, runLineHeights);
    cleanupLocalRef(env, runTabularNumbers);
  }

  clearPendingException(env, "RNTextEngine: native TextView measurement prepare() failed.");

  cleanupLocalRef(env, textValue);
  cleanupLocalRef(env, textTransformValue);
  cleanupLocalRef(env, fontFamilyValue);
  cleanupLocalRef(env, fontWeightValue);
  cleanupLocalRef(env, fontStyleValue);
  if (needsDetach) javaVm()->DetachCurrentThread();

  return static_cast<uint64_t>(handle);
}

double measurePreparedTextMeasurementWidth(uint64_t handle) {
  bool needsDetach = false;
  JNIEnv* env = getEnv(needsDetach);
  if (env == nullptr) {
    throw std::runtime_error("Unable to retrieve jni environment. Is the thread attached?");
  }
  const auto& bindings = getBindings(env);
  auto width = env->CallStaticDoubleMethod(bindings.bindingsClass, bindings.measurePreparedWidthMethod, static_cast<jlong>(handle));
  clearPendingException(env, "RNTextEngine: native measurePreparedWidth() failed.");
  if (needsDetach) javaVm()->DetachCurrentThread();
  return width;
}

facebook::react::Size measurePreparedTextMeasurementLayout(
    uint64_t handle,
    double width,
    int maxLines,
    const std::string& ellipsizeMode,
    bool anchorToCapHeight) {
  bool needsDetach = false;
  JNIEnv* env = getEnv(needsDetach);
  if (env == nullptr) {
    throw std::runtime_error("Unable to retrieve jni environment. Is the thread attached?");
  }
  const auto& bindings = getBindings(env);
  jint truncation = 3;
  if (ellipsizeMode == "clip") truncation = 0;
  else if (ellipsizeMode == "head") truncation = 1;
  else if (ellipsizeMode == "middle") truncation = 2;

  const auto packed = env->CallStaticLongMethod(
      bindings.bindingsClass,
      bindings.measureTextViewMethod,
      static_cast<jlong>(handle),
      width,
      static_cast<jint>(maxLines),
      truncation,
      anchorToCapHeight);

  const bool failed = clearPendingException(env, "RNTextEngine: native TextView measurement failed.");
  if (needsDetach) javaVm()->DetachCurrentThread();
  return failed ? facebook::react::Size{} : facebook::react::yogaMeassureToSize(packed);
}

std::pair<std::string, std::vector<int>> transformTextWithBoundaries(
    const std::string& text,
    const std::string& textTransform,
    const std::vector<int>& boundaries) {
  if (text.empty() || textTransform.empty() || textTransform == "none") {
    return {text, boundaries};
  }

  bool needsDetach = false;
  JNIEnv* env = getEnv(needsDetach);
  if (env == nullptr) {
    throw std::runtime_error("Unable to retrieve jni environment. Is the thread attached?");
  }
  const auto& bindings = getBindings(env);

  auto textValue = facebook::jni::make_jstring(text).release();
  auto transformValue = toJString(textTransform);
  auto boundariesValue = toIntArray(env, boundaries);

  auto result = reinterpret_cast<jobjectArray>(env->CallStaticObjectMethod(
      bindings.bindingsClass,
      bindings.transformTextWithBoundariesMethod,
      textValue,
      transformValue,
      boundariesValue));

  const bool hasException = clearPendingException(env, "RNTextEngine: native transformTextWithBoundaries() failed.");
  cleanupLocalRef(env, textValue);
  cleanupLocalRef(env, transformValue);
  cleanupLocalRef(env, boundariesValue);

  if (hasException || result == nullptr) {
    cleanupLocalRef(env, result);
    if (needsDetach) javaVm()->DetachCurrentThread();
    return {text, boundaries};
  }

  auto transformedTextValue = reinterpret_cast<jstring>(env->GetObjectArrayElement(result, 0));
  auto mappedBoundariesValue = reinterpret_cast<jintArray>(env->GetObjectArrayElement(result, 1));

  std::string transformedText = text;
  if (transformedTextValue != nullptr) {
    transformedText = facebook::jni::wrap_alias(transformedTextValue)->toStdString();
  }

  auto mappedBoundaries = toIntVector(env, mappedBoundariesValue);
  if (mappedBoundaries.size() != boundaries.size()) {
    mappedBoundaries = boundaries;
  }

  cleanupLocalRef(env, transformedTextValue);
  cleanupLocalRef(env, mappedBoundariesValue);
  cleanupLocalRef(env, result);
  if (needsDetach) javaVm()->DetachCurrentThread();

  return {transformedText, mappedBoundaries};
}

void releasePreparedTextMeasurementHandle(uint64_t handle) {
  if (handle == 0) return;

  bool needsDetach = false;
  JNIEnv* env = getEnv(needsDetach);
  if (env == nullptr) {
    std::fputs(
        "RNTextEngine: native TextView measurement release() skipped because the thread could not attach to JNI.\n",
        stderr);
    return;
  }
  const auto& bindings = getBindings(env);
  env->CallStaticVoidMethod(bindings.bindingsClass, bindings.releaseMethod, static_cast<jlong>(handle));
  clearPendingException(env, "RNTextEngine: native TextView measurement release() failed.");
  if (needsDetach) javaVm()->DetachCurrentThread();
}

uint64_t textEnvironmentVersion() {
  facebook::jni::ThreadScope attached;
  auto* env = facebook::jni::Environment::current();
  const auto& bindings = getBindings(env);
  const auto version = env->CallStaticLongMethod(bindings.bindingsClass, bindings.textEnvironmentVersionMethod);
  facebook::jni::throwPendingJniExceptionAsCppException();
  return static_cast<uint64_t>(version);
}

PreparedTextHandle::~PreparedTextHandle() {
  releasePreparedTextMeasurementHandle(handle);
}

} // namespace rntextengine

namespace facebook::react {

namespace {

constexpr int kRunStyleHasColor = 1 << 0;
constexpr int kRunStyleHasFontFamily = 1 << 1;
constexpr int kRunStyleHasFontSize = 1 << 2;
constexpr int kRunStyleHasFontStyle = 1 << 3;
constexpr int kRunStyleHasFontWeight = 1 << 4;
constexpr int kRunStyleHasLetterSpacing = 1 << 5;
constexpr int kRunStyleHasLineHeight = 1 << 6;
constexpr int kRunStyleHasTabularNumbers = 1 << 7;


std::string colorString(const SharedColor& color) {
  if (!color) return {};
  char value[10];
  std::snprintf(value, sizeof(value), "#%08x", static_cast<uint32_t>(*color));
  return value;
}

bool hasExactConstraint(Float minimum, Float maximum) {
  return std::isfinite(minimum) && std::isfinite(maximum) &&
      minimum == maximum;
}

bool hasBoundedConstraint(Float maximum) {
  return std::isfinite(maximum);
}

double resolveFontSize(double fontSize) {
  return fontSize > 0 ? fontSize : 14.0;
}

double resolveLineHeight(double lineHeight) {
  return lineHeight > 0 ? lineHeight : std::numeric_limits<double>::quiet_NaN();
}

std::string resolveOptionalString(const std::string& value) {
  return value.empty() ? std::string{} : value;
}

int resolveRunCount(const RNTextEngineTextViewProps& props) {
  if (props.runStarts.empty() || props.runEnds.empty() || props.runStyleMasks.empty()) return 0;

  int runCount = props.runCount > 0 ? props.runCount : static_cast<int>(props.runStarts.size());
  runCount = std::min(runCount, static_cast<int>(props.runStarts.size()));
  runCount = std::min(runCount, static_cast<int>(props.runEnds.size()));
  runCount = std::min(runCount, static_cast<int>(props.runStyleMasks.size()));
  return std::max(runCount, 0);
}

template <typename T>
T valueOrDefault(const std::vector<T>& values, int index, const T& fallback) {
  return index < static_cast<int>(values.size()) ? values[index] : fallback;
}

bool usesIdentityTransform(std::string_view textTransform) {
  return textTransform.empty() || textTransform == "none";
}

[[noreturn]] void throwInvalidTextChild(const facebook::react::ShadowNode& child) {
  throw std::runtime_error(
      "RNTextEngine: TextView nested children must resolve to TextView nodes. Found `" +
      std::string(child.getComponentName()) + "`.");
}

bool isContinuationByte(uint8_t value) {
  return (value & 0xC0) == 0x80;
}

bool appendUtf8CodePoint(std::string& result, uint32_t codePoint) {
  if (codePoint <= 0x7F) {
    result.push_back(static_cast<char>(codePoint));
    return true;
  }

  if (codePoint <= 0x7FF) {
    result.push_back(static_cast<char>(0xC0 | (codePoint >> 6)));
    result.push_back(static_cast<char>(0x80 | (codePoint & 0x3F)));
    return true;
  }

  if (codePoint >= 0xD800 && codePoint <= 0xDFFF) {
    return false;
  }

  if (codePoint <= 0xFFFF) {
    result.push_back(static_cast<char>(0xE0 | (codePoint >> 12)));
    result.push_back(static_cast<char>(0x80 | ((codePoint >> 6) & 0x3F)));
    result.push_back(static_cast<char>(0x80 | (codePoint & 0x3F)));
    return true;
  }

  if (codePoint > 0x10FFFF) {
    return false;
  }

  result.push_back(static_cast<char>(0xF0 | (codePoint >> 18)));
  result.push_back(static_cast<char>(0x80 | ((codePoint >> 12) & 0x3F)));
  result.push_back(static_cast<char>(0x80 | ((codePoint >> 6) & 0x3F)));
  result.push_back(static_cast<char>(0x80 | (codePoint & 0x3F)));
  return true;
}

bool decodeUtf8CodePoint(
    std::string_view value,
    size_t& offset,
    uint32_t& codePoint) {
  if (offset >= value.size()) {
    return false;
  }

  const auto first = static_cast<uint8_t>(value[offset]);
  if (first <= 0x7F) {
    codePoint = first;
    offset += 1;
    return true;
  }

  if (first >= 0xC2 && first <= 0xDF) {
    if (offset + 1 >= value.size()) {
      return false;
    }
    const auto second = static_cast<uint8_t>(value[offset + 1]);
    if (!isContinuationByte(second)) {
      return false;
    }
    codePoint = ((first & 0x1F) << 6) | (second & 0x3F);
    offset += 2;
    return true;
  }

  if (first >= 0xE0 && first <= 0xEF) {
    if (offset + 2 >= value.size()) {
      return false;
    }
    const auto second = static_cast<uint8_t>(value[offset + 1]);
    const auto third = static_cast<uint8_t>(value[offset + 2]);
    const bool secondValid =
        isContinuationByte(second) &&
        (first != 0xE0 || second >= 0xA0) &&
        (first != 0xED || second <= 0x9F);
    if (!secondValid || !isContinuationByte(third)) {
      return false;
    }
    codePoint =
        ((first & 0x0F) << 12) |
        ((second & 0x3F) << 6) |
        (third & 0x3F);
    offset += 3;
    return true;
  }

  if (first >= 0xF0 && first <= 0xF4) {
    if (offset + 3 >= value.size()) {
      return false;
    }
    const auto second = static_cast<uint8_t>(value[offset + 1]);
    const auto third = static_cast<uint8_t>(value[offset + 2]);
    const auto fourth = static_cast<uint8_t>(value[offset + 3]);
    const bool secondValid =
        isContinuationByte(second) &&
        (first != 0xF0 || second >= 0x90) &&
        (first != 0xF4 || second <= 0x8F);
    if (!secondValid || !isContinuationByte(third) || !isContinuationByte(fourth)) {
      return false;
    }
    codePoint =
        ((first & 0x07) << 18) |
        ((second & 0x3F) << 12) |
        ((third & 0x3F) << 6) |
        (fourth & 0x3F);
    offset += 4;
    return true;
  }

  return false;
}

std::u16string utf8ToUtf16(const std::string& value) {
  if (value.empty()) {
    return {};
  }

  std::u16string result;
  result.reserve(value.size());

  size_t offset = 0;
  while (offset < value.size()) {
    uint32_t codePoint = 0;
    if (!decodeUtf8CodePoint(value, offset, codePoint)) {
      return {};
    }

    if (codePoint <= 0xFFFF) {
      result.push_back(static_cast<char16_t>(codePoint));
      continue;
    }

    codePoint -= 0x10000;
    result.push_back(static_cast<char16_t>(0xD800 + (codePoint >> 10)));
    result.push_back(static_cast<char16_t>(0xDC00 + (codePoint & 0x3FF)));
  }

  return result;
}

std::string utf16ToUtf8(const std::u16string& value) {
  if (value.empty()) {
    return {};
  }

  std::string result;
  result.reserve(value.size() * 3);

  size_t index = 0;
  while (index < value.size()) {
    const auto current = static_cast<uint32_t>(value[index++]);
    uint32_t codePoint = current;

    if (current >= 0xD800 && current <= 0xDBFF) {
      if (index >= value.size()) {
        return {};
      }
      const auto low = static_cast<uint32_t>(value[index]);
      if (low < 0xDC00 || low > 0xDFFF) {
        return {};
      }
      codePoint =
          0x10000 +
          ((current - 0xD800) << 10) +
          (low - 0xDC00);
      index += 1;
    } else if (current >= 0xDC00 && current <= 0xDFFF) {
      return {};
    }

    if (!appendUtf8CodePoint(result, codePoint)) {
      return {};
    }
  }

  return result;
}

} // namespace

#if defined(ANDROID) || defined(RN_SERIALIZABLE_STATE)
RNTextEngineTextViewStateData::RNTextEngineTextViewStateData(
    const RNTextEngineTextViewStateData& previousState,
    folly::dynamic)
    : RNTextEngineTextViewStateData(previousState) {}

folly::dynamic RNTextEngineTextViewStateData::getDynamic() const {
  return folly::dynamic::object();
}

MapBuffer RNTextEngineTextViewStateData::getMapBuffer() const {
  MapBufferBuilder builder(2);
  const auto handle = preparedText ? preparedText->handle : 0;
  builder.putInt(0, static_cast<int32_t>(handle));
  builder.putInt(1, static_cast<int32_t>(handle >> 32));
  return builder.build();
}
#endif

RNTextEngineTextViewShadowNode::RNTextEngineTextViewShadowNode(
    const ShadowNodeFragment& fragment,
    const ShadowNodeFamily::Shared& family,
    ShadowNodeTraits traits)
    : BaseShadowNode(fragment, family, traits) {}

RNTextEngineTextViewShadowNode::RNTextEngineTextViewShadowNode(
    const ShadowNode& sourceShadowNode,
    const ShadowNodeFragment& fragment)
    : BaseShadowNode(sourceShadowNode, fragment) {
  const auto& source = static_cast<const RNTextEngineTextViewShadowNode&>(sourceShadowNode);
  if (hasSameTextContent(source)) measurementCache_ = std::atomic_load(&source.measurementCache_);
}

bool RNTextEngineTextViewShadowNode::hasSameTextContent(
    const RNTextEngineTextViewShadowNode& source, bool asChild) const {
  const auto& previous = source.getConcreteProps();
  const auto& props = getConcreteProps();
  const bool sameProps = &props == &previous || (
      previous.text == props.text && previous.textTransform == props.textTransform &&
      previous.allowFontScaling == props.allowFontScaling &&
      previous.fontFamily == props.fontFamily && previous.fontSize == props.fontSize &&
      previous.fontStyle == props.fontStyle && previous.fontWeight == props.fontWeight &&
      previous.letterSpacing == props.letterSpacing && previous.lineHeight == props.lineHeight &&
      previous.tabularNumbers == props.tabularNumbers &&
      ((!asChild && getChildren().empty()) || previous.color == props.color) &&
      previous.runCount == props.runCount && previous.runStarts == props.runStarts &&
      previous.runEnds == props.runEnds && previous.runStyleMasks == props.runStyleMasks &&
      previous.runColors == props.runColors && previous.runFontFamilies == props.runFontFamilies &&
      previous.runFontSizes == props.runFontSizes && previous.runFontStyles == props.runFontStyles &&
      previous.runFontWeights == props.runFontWeights && previous.runLetterSpacings == props.runLetterSpacings &&
      previous.runLineHeights == props.runLineHeights && previous.runTabularNumbers == props.runTabularNumbers &&
      (!asChild || (previous.rnteHasAllowFontScaling == props.rnteHasAllowFontScaling &&
          previous.rnteHasLetterSpacing == props.rnteHasLetterSpacing &&
          previous.rnteHasTabularNumbers == props.rnteHasTabularNumbers)));
  if (!sameProps || getChildren().size() != source.getChildren().size()) return false;
  for (size_t index = 0; index < getChildren().size(); ++index) {
    const auto& child = getChildren()[index];
    const auto& previousChild = source.getChildren()[index];
    if (child == previousChild) continue;
    const auto* textChild = dynamic_cast<const RNTextEngineTextViewShadowNode*>(child.get());
    const auto* previousTextChild = dynamic_cast<const RNTextEngineTextViewShadowNode*>(previousChild.get());
    if (!textChild || !previousTextChild || !textChild->hasSameTextContent(*previousTextChild, true)) return false;
  }
  return true;
}

ShadowNodeTraits RNTextEngineTextViewShadowNode::BaseTraits() {
  auto traits = BaseShadowNode::BaseTraits();
  traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
  traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
  return traits;
}

Size RNTextEngineTextViewShadowNode::measureContent(
    const LayoutContext&,
    const LayoutConstraints& layoutConstraints) const {
  const auto hasExactWidth = hasExactConstraint(
      layoutConstraints.minimumSize.width, layoutConstraints.maximumSize.width);
  const auto hasExactHeight = hasExactConstraint(
      layoutConstraints.minimumSize.height, layoutConstraints.maximumSize.height);
  if (hasExactWidth && hasExactHeight) {
    return layoutConstraints.maximumSize;
  }

  const auto& props = getConcreteProps();
  auto& cache = ensureMeasurementCache();
  std::lock_guard<std::mutex> lock(cache.mutex);
  prepareMeasurementHandle(cache);
  const auto resolvePreferredWidth = [&]() -> Float {
    if (cache.preferredWidth < 0) {
      cache.preferredWidth =
          rntextengine::measurePreparedTextMeasurementWidth(cache.preparedText->handle);
    }
    return static_cast<Float>(cache.preferredWidth);
  };

  const auto hasBoundedWidth =
      hasBoundedConstraint(layoutConstraints.maximumSize.width);
  const auto constrainedWidth =
      hasBoundedWidth ? std::max(0.0f, layoutConstraints.maximumSize.width)
                      : resolvePreferredWidth();
  // AT_MOST must measure against the real width contract. Pre-shrinking through preferred width
  // can force premature ellipsis even when the text fits inside the bounded host.
  const auto layoutWidth =
      hasBoundedWidth ? constrainedWidth : resolvePreferredWidth();
  const auto maxLines = props.numberOfLines > 0 ? props.numberOfLines : 0;

  const auto ellipsizeMode = resolveOptionalString(props.ellipsizeMode);
  auto layoutIterator = std::find_if(
      cache.layouts.begin(),
      cache.layouts.end(),
      [&](const CachedLayout& layout) {
        return layout.anchorToCapHeight == props.anchorToCapHeight &&
            layout.ellipsizeMode == ellipsizeMode &&
            layout.maxLines == maxLines &&
            layout.width == layoutWidth;
      });

  if (layoutIterator == cache.layouts.end()) {
    cache.layouts.push_back({
        .anchorToCapHeight = props.anchorToCapHeight,
        .ellipsizeMode = ellipsizeMode,
        .maxLines = maxLines,
        .width = layoutWidth,
        .measurement =
            rntextengine::measurePreparedTextMeasurementLayout(
                cache.preparedText->handle,
                layoutWidth,
                maxLines,
                ellipsizeMode,
                props.anchorToCapHeight),
    });
    layoutIterator = std::prev(cache.layouts.end());
  }

  auto measuredWidth = layoutIterator->measurement.width;
  if (hasExactWidth) measuredWidth = layoutConstraints.maximumSize.width;
  else if (hasBoundedWidth) {
    measuredWidth =
        std::min(measuredWidth, layoutConstraints.maximumSize.width);
  }

  auto measuredHeight = layoutIterator->measurement.height;
  if (hasExactHeight) measuredHeight = layoutConstraints.maximumSize.height;
  else if (hasBoundedConstraint(layoutConstraints.maximumSize.height)) {
    measuredHeight =
        std::min(measuredHeight, layoutConstraints.maximumSize.height);
  }

  return layoutConstraints.clamp(
      {.width = measuredWidth, .height = measuredHeight});
}

void RNTextEngineTextViewShadowNode::layout(LayoutContext layoutContext) {
  BaseShadowNode::layout(layoutContext);
  auto& cache = ensureMeasurementCache();
  std::lock_guard<std::mutex> lock(cache.mutex);
  prepareMeasurementHandle(cache);
  if (getStateData().preparedText != cache.preparedText) {
    RNTextEngineTextViewStateData state;
    state.preparedText = cache.preparedText;
    setStateData(std::move(state));
  }
}

bool RNTextEngineTextViewShadowNode::shouldNewRevisionDirtyMeasurement(
    const ShadowNode&,
    const ShadowNodeFragment& fragment) const {
  return fragment.props != ShadowNodeFragment::propsPlaceholder() ||
      &fragment.children != &ShadowNodeFragment::childrenPlaceholder();
}

RNTextEngineTextViewShadowNode::MeasurementCache&
RNTextEngineTextViewShadowNode::ensureMeasurementCache() const {
  std::call_once(measurementCacheInitialization_, [this] {
    if (measurementCache_ == nullptr) {
      std::atomic_store(&measurementCache_, std::make_shared<MeasurementCache>());
    }
  });
  return *measurementCache_;
}

void RNTextEngineTextViewShadowNode::prepareMeasurementHandle(MeasurementCache& cache) const {
  const auto environmentVersion = rntextengine::textEnvironmentVersion();
  if (cache.environmentVersion != environmentVersion) {
    cache.preparedText.reset();
    cache.layouts.clear();
    cache.preferredWidth = -1;
    cache.environmentVersion = environmentVersion;
  }
  if (cache.preparedText) return;

  const auto& props = getConcreteProps();
  uint64_t handle;
  if (getChildren().empty()) {
    handle = rntextengine::prepareTextViewMeasurementHandle(
        props.text,
        resolveOptionalString(props.textTransform),
        props.allowFontScaling,
        resolveOptionalString(props.fontFamily),
        resolveFontSize(props.fontSize),
        resolveOptionalString(props.fontWeight),
        resolveOptionalString(props.fontStyle),
        props.letterSpacing,
        resolveLineHeight(props.lineHeight),
        props.tabularNumbers,
        buildRuns(),
        environmentVersion);
  } else {
    const auto payload = resolvePayload();
    const auto rootStyle = normalizePreparedStyle(resolveNodeStyle(props, nullptr));
    handle = rntextengine::prepareTextViewMeasurementHandle(
        payload.text,
        std::string{},
        false,
        rootStyle.fontFamily,
        rootStyle.fontSize,
        rootStyle.fontWeight,
        rootStyle.fontStyle,
        rootStyle.letterSpacing,
        resolveLineHeight(rootStyle.lineHeight),
        rootStyle.tabularNumbers,
        payload.runs,
        environmentVersion,
        true);
  }
  cache.preparedText = std::make_shared<const rntextengine::PreparedTextHandle>(handle);
}

rntextengine::TextViewMeasurementRuns
RNTextEngineTextViewShadowNode::buildRuns() const {
  const auto& props = getConcreteProps();
  const auto runCount = resolveRunCount(props);

  rntextengine::TextViewMeasurementRuns runs;
  runs.starts.reserve(runCount);
  runs.ends.reserve(runCount);
  runs.styleMasks.reserve(runCount);
  runs.colors.reserve(runCount);
  runs.fontFamilies.reserve(runCount);
  runs.fontSizes.reserve(runCount);
  runs.fontStyles.reserve(runCount);
  runs.fontWeights.reserve(runCount);
  runs.letterSpacings.reserve(runCount);
  runs.lineHeights.reserve(runCount);
  runs.tabularNumbers.reserve(runCount);

  for (int index = 0; index < runCount; index += 1) {
    runs.starts.push_back(
        static_cast<int>(valueOrDefault(props.runStarts, index, 0.0)));
    runs.ends.push_back(
        static_cast<int>(valueOrDefault(props.runEnds, index, 0.0)));
    runs.styleMasks.push_back(
        static_cast<int>(valueOrDefault(props.runStyleMasks, index, 0.0)));
    runs.colors.push_back(valueOrDefault(props.runColors, index, std::string{}));
    runs.fontFamilies.push_back(valueOrDefault(
        props.runFontFamilies, index, std::string{}));
    runs.fontSizes.push_back(valueOrDefault(props.runFontSizes, index, 0.0));
    runs.fontStyles.push_back(valueOrDefault(
        props.runFontStyles, index, std::string{}));
    runs.fontWeights.push_back(valueOrDefault(
        props.runFontWeights, index, std::string{}));
    runs.letterSpacings.push_back(
        valueOrDefault(props.runLetterSpacings, index, 0.0));
    runs.lineHeights.push_back(
        valueOrDefault(props.runLineHeights, index, 0.0));
    runs.tabularNumbers.push_back(valueOrDefault(
        props.runTabularNumbers, index, false));
  }

  return runs;
}

RNTextEngineTextViewShadowNode::ResolvedPayload
RNTextEngineTextViewShadowNode::resolvePayload() const {
  const auto rootStyle = resolveNodeStyle(getConcreteProps(), nullptr);
  std::u16string textBuilder;
  std::vector<ResolvedSegment> segments;
  segments.reserve(8);

  appendNodePayload(*this, rootStyle, textBuilder, segments);
  return buildPayloadFromSegments(textBuilder, segments, rootStyle);
}

void RNTextEngineTextViewShadowNode::appendNodePayload(
    const RNTextEngineTextViewShadowNode& node,
    const ResolvedStyle& parentStyle,
    std::u16string& text,
    std::vector<ResolvedSegment>& segments) const {
  const auto& props = node.getConcreteProps();
  const auto nodeStyle = resolveNodeStyle(props, &parentStyle);
  const auto localText = utf8ToUtf16(props.text);
  auto localRuns = resolveLocalRuns(props, nodeStyle, static_cast<int>(localText.size()));
  const auto transformed =
      resolveTransformedText(localText, nodeStyle.textTransform, std::move(localRuns));
  emitStyledText(transformed.first, nodeStyle, transformed.second, text, segments);

  for (const auto& child : node.getChildren()) {
    const auto* textChild = dynamic_cast<const RNTextEngineTextViewShadowNode*>(child.get());
    if (textChild == nullptr) {
      throwInvalidTextChild(*child);
    }

    appendNodePayload(*textChild, nodeStyle, text, segments);
  }
}

void RNTextEngineTextViewShadowNode::emitStyledText(
    const std::u16string& text,
    const ResolvedStyle& baseStyle,
    const std::vector<ResolvedRun>& runs,
    std::u16string& textBuilder,
    std::vector<ResolvedSegment>& segments) const {
  if (text.empty()) {
    return;
  }

  if (runs.empty()) {
    appendSegment(textBuilder, segments, text, baseStyle);
    return;
  }

  int cursor = 0;
  for (const auto& run : runs) {
    const auto clampedStart = std::clamp(run.start, 0, static_cast<int>(text.size()));
    const auto clampedEnd = std::clamp(run.end, 0, static_cast<int>(text.size()));
    if (clampedEnd <= clampedStart) {
      continue;
    }

    if (clampedStart > cursor) {
      appendSegment(
          textBuilder,
          segments,
          text.substr(static_cast<size_t>(cursor), static_cast<size_t>(clampedStart - cursor)),
          baseStyle);
    }

    appendSegment(
        textBuilder,
        segments,
        text.substr(
            static_cast<size_t>(clampedStart),
            static_cast<size_t>(clampedEnd - clampedStart)),
        run.style);
    cursor = clampedEnd;
  }

  if (cursor < static_cast<int>(text.size())) {
    appendSegment(
        textBuilder,
        segments,
        text.substr(static_cast<size_t>(cursor)),
        baseStyle);
  }
}

void RNTextEngineTextViewShadowNode::appendSegment(
    std::u16string& textBuilder,
    std::vector<ResolvedSegment>& segments,
    const std::u16string& text,
    const ResolvedStyle& style) const {
  if (text.empty()) {
    return;
  }
  const auto normalizedStyle = normalizePreparedStyle(style);

  const auto start = static_cast<int>(textBuilder.size());
  textBuilder += text;
  const auto end = static_cast<int>(textBuilder.size());

  if (!segments.empty()) {
    auto& last = segments.back();
    if (last.end == start && last.style.color == normalizedStyle.color &&
        last.style.fontFamily == normalizedStyle.fontFamily &&
        last.style.fontSize == normalizedStyle.fontSize &&
        last.style.fontStyle == normalizedStyle.fontStyle &&
        last.style.fontWeight == normalizedStyle.fontWeight &&
        last.style.letterSpacing == normalizedStyle.letterSpacing &&
        last.style.lineHeight == normalizedStyle.lineHeight &&
        last.style.tabularNumbers == normalizedStyle.tabularNumbers) {
      last.end = end;
      return;
    }
  }

  segments.push_back({.start = start, .end = end, .style = normalizedStyle});
}

RNTextEngineTextViewShadowNode::ResolvedStyle
RNTextEngineTextViewShadowNode::resolveNodeStyle(
    const RNTextEngineTextViewProps& props,
    const ResolvedStyle* parentStyle) const {
  ResolvedStyle next = parentStyle == nullptr
      ? ResolvedStyle{
            .color = colorString(props.color),
            .fontFamily = props.fontFamily,
            .fontSize = props.fontSize > 0 ? props.fontSize : 14.0,
            .fontStyle = props.fontStyle,
            .fontWeight = props.fontWeight,
            .letterSpacing = props.letterSpacing,
            .lineHeight = props.lineHeight,
            .tabularNumbers = props.tabularNumbers,
            .textTransform = props.textTransform,
            .allowFontScaling = props.allowFontScaling,
        }
      : *parentStyle;

  if (props.color) next.color = colorString(props.color);
  if (!props.fontFamily.empty()) next.fontFamily = props.fontFamily;
  if (props.fontSize > 0) next.fontSize = props.fontSize;
  if (!props.fontStyle.empty()) next.fontStyle = props.fontStyle;
  if (!props.fontWeight.empty()) next.fontWeight = props.fontWeight;
  if (parentStyle == nullptr || props.rnteHasLetterSpacing) {
    next.letterSpacing = props.letterSpacing;
  }
  if (props.lineHeight > 0) next.lineHeight = props.lineHeight;
  if (parentStyle == nullptr || props.rnteHasTabularNumbers) {
    next.tabularNumbers = props.tabularNumbers;
  }
  if (!props.textTransform.empty()) next.textTransform = props.textTransform;
  if (parentStyle == nullptr || props.rnteHasAllowFontScaling) {
    next.allowFontScaling = props.allowFontScaling;
  }
  return next;
}

RNTextEngineTextViewShadowNode::ResolvedStyle
RNTextEngineTextViewShadowNode::normalizePreparedStyle(const ResolvedStyle& style) {
  if (!style.allowFontScaling) {
    return style;
  }

  auto normalized = style;
  normalized.fontSize = rntextengine::scaleTypographyValue(normalized.fontSize);
  normalized.letterSpacing = rntextengine::scaleTypographyValue(normalized.letterSpacing);
  if (normalized.lineHeight > 0) {
    normalized.lineHeight = rntextengine::scaleTypographyValue(normalized.lineHeight);
  }
  normalized.allowFontScaling = false;
  return normalized;
}

std::vector<RNTextEngineTextViewShadowNode::ResolvedRun>
RNTextEngineTextViewShadowNode::resolveLocalRuns(
    const RNTextEngineTextViewProps& props,
    const ResolvedStyle& baseStyle,
    int textLength) const {
  const auto runCount = resolveRunCount(props);
  if (runCount == 0) {
    return {};
  }

  std::vector<ResolvedRun> runs;
  runs.reserve(static_cast<size_t>(runCount));
  int previousEnd = 0;

  for (int index = 0; index < runCount; index += 1) {
    const auto start = static_cast<int>(valueOrDefault(props.runStarts, index, 0.0));
    const auto end = static_cast<int>(valueOrDefault(props.runEnds, index, 0.0));
    const auto styleMask = static_cast<int>(valueOrDefault(props.runStyleMasks, index, 0.0));
    if (styleMask == 0 || start < previousEnd || start < 0 || end <= start || end > textLength) {
      continue;
    }

    auto style = baseStyle;
    if (styleMask & kRunStyleHasColor) {
      style.color = valueOrDefault(props.runColors, index, std::string{});
    }
    if (styleMask & kRunStyleHasFontFamily) {
      style.fontFamily = valueOrDefault(props.runFontFamilies, index, std::string{});
    }
    if (styleMask & kRunStyleHasFontSize) {
      style.fontSize = valueOrDefault(props.runFontSizes, index, 0.0);
    }
    if (styleMask & kRunStyleHasFontStyle) {
      style.fontStyle = valueOrDefault(props.runFontStyles, index, std::string{});
    }
    if (styleMask & kRunStyleHasFontWeight) {
      style.fontWeight = valueOrDefault(props.runFontWeights, index, std::string{});
    }
    if (styleMask & kRunStyleHasLetterSpacing) {
      style.letterSpacing = valueOrDefault(props.runLetterSpacings, index, 0.0);
    }
    if (styleMask & kRunStyleHasLineHeight) {
      style.lineHeight = valueOrDefault(props.runLineHeights, index, 0.0);
    }
    if (styleMask & kRunStyleHasTabularNumbers) {
      style.tabularNumbers = valueOrDefault(props.runTabularNumbers, index, false);
    }

    runs.push_back({.start = start, .end = end, .style = style});
    previousEnd = end;
  }

  return runs;
}

std::pair<std::u16string, std::vector<RNTextEngineTextViewShadowNode::ResolvedRun>>
RNTextEngineTextViewShadowNode::resolveTransformedText(
    const std::u16string& text,
    const std::string& textTransform,
    std::vector<ResolvedRun> runs) const {
  if (text.empty() || usesIdentityTransform(textTransform)) {
    return {text, std::move(runs)};
  }

  const auto utf8Text = utf16ToUtf8(text);
  if (runs.empty()) {
    const auto transformed =
        rntextengine::transformTextWithBoundaries(utf8Text, textTransform, {});
    return {utf8ToUtf16(transformed.first), std::move(runs)};
  }

  std::vector<int> boundaries;
  boundaries.reserve(runs.size() * 2);
  for (const auto& run : runs) {
    boundaries.push_back(run.start);
    boundaries.push_back(run.end);
  }

  auto transformed =
      rntextengine::transformTextWithBoundaries(utf8Text, textTransform, boundaries);
  if (transformed.second.empty()) {
    return {utf8ToUtf16(transformed.first), std::move(runs)};
  }

  std::unordered_map<int, int> mapped;
  mapped.reserve(boundaries.size());
  for (size_t index = 0; index < boundaries.size(); index += 1) {
    mapped[boundaries[index]] = transformed.second[index];
  }

  for (auto& run : runs) {
    if (const auto start = mapped.find(run.start); start != mapped.end()) {
      run.start = start->second;
    }
    if (const auto end = mapped.find(run.end); end != mapped.end()) {
      run.end = end->second;
    }
  }

  return {utf8ToUtf16(transformed.first), std::move(runs)};
}

RNTextEngineTextViewShadowNode::ResolvedPayload
RNTextEngineTextViewShadowNode::buildPayloadFromSegments(
    const std::u16string& text,
    const std::vector<ResolvedSegment>& segments,
    const ResolvedStyle& rootStyle) const {
  const auto normalizedRootStyle = normalizePreparedStyle(rootStyle);
  ResolvedPayload payload;
  payload.text = utf16ToUtf8(text);
  for (const auto& segment : segments) {
    int styleMask = 0;
    if (segment.style.color != normalizedRootStyle.color) styleMask |= kRunStyleHasColor;
    if (segment.style.fontFamily != normalizedRootStyle.fontFamily) styleMask |= kRunStyleHasFontFamily;
    if (segment.style.fontSize != normalizedRootStyle.fontSize) styleMask |= kRunStyleHasFontSize;
    if (segment.style.fontStyle != normalizedRootStyle.fontStyle) styleMask |= kRunStyleHasFontStyle;
    if (segment.style.fontWeight != normalizedRootStyle.fontWeight) styleMask |= kRunStyleHasFontWeight;
    if (segment.style.letterSpacing != normalizedRootStyle.letterSpacing) styleMask |= kRunStyleHasLetterSpacing;
    if (segment.style.lineHeight != normalizedRootStyle.lineHeight) styleMask |= kRunStyleHasLineHeight;
    if (segment.style.tabularNumbers != normalizedRootStyle.tabularNumbers) styleMask |= kRunStyleHasTabularNumbers;

    if (styleMask == 0) {
      continue;
    }

    payload.runs.starts.push_back(segment.start);
    payload.runs.ends.push_back(segment.end);
    payload.runs.styleMasks.push_back(styleMask);
    payload.runs.colors.push_back(segment.style.color);
    payload.runs.fontFamilies.push_back(segment.style.fontFamily);
    payload.runs.fontSizes.push_back(segment.style.fontSize);
    payload.runs.fontWeights.push_back(segment.style.fontWeight);
    payload.runs.fontStyles.push_back(segment.style.fontStyle);
    payload.runs.letterSpacings.push_back(segment.style.letterSpacing);
    payload.runs.lineHeights.push_back(segment.style.lineHeight);
    payload.runs.tabularNumbers.push_back(segment.style.tabularNumbers);
  }

  return payload;
}

} // namespace facebook::react
