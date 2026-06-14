#ifdef RCT_NEW_ARCH_ENABLED

#import "RNTextEngineTextViewShadowNode.h"

#import "RNTextEngineBindings.h"
#import "RNTextEngineTextTransform.h"
#import <React/RCTUtils.h>

#import <react/renderer/core/conversions.h>
#import <react/utils/FloatComparison.h>

#include <algorithm>
#include <cmath>
#include <functional>
#include <limits>
#include <stdexcept>
#include <string_view>
#include <type_traits>
#include <unordered_map>
#include <utility>

using namespace facebook::react;
using namespace rntextengine;

namespace {

constexpr int kRunStyleHasColor = 1 << 0;
constexpr int kRunStyleHasFontFamily = 1 << 1;
constexpr int kRunStyleHasFontSize = 1 << 2;
constexpr int kRunStyleHasFontStyle = 1 << 3;
constexpr int kRunStyleHasFontWeight = 1 << 4;
constexpr int kRunStyleHasLetterSpacing = 1 << 5;
constexpr int kRunStyleHasLineHeight = 1 << 6;
constexpr int kRunStyleHasTabularNumbers = 1 << 7;

#ifdef RN_SERIALIZABLE_STATE
constexpr MapBuffer::Key kStateHasNested = 1;
constexpr MapBuffer::Key kStateHash = 2;
constexpr MapBuffer::Key kStateText = 3;
constexpr MapBuffer::Key kStateRunStarts = 4;
constexpr MapBuffer::Key kStateRunEnds = 5;
constexpr MapBuffer::Key kStateRunStyleMasks = 6;
constexpr MapBuffer::Key kStateRunColors = 7;
constexpr MapBuffer::Key kStateRunFontFamilies = 8;
constexpr MapBuffer::Key kStateRunFontSizes = 9;
constexpr MapBuffer::Key kStateRunFontWeights = 10;
constexpr MapBuffer::Key kStateRunFontStyles = 11;
constexpr MapBuffer::Key kStateRunLetterSpacings = 12;
constexpr MapBuffer::Key kStateRunLineHeights = 13;
constexpr MapBuffer::Key kStateRunTabularNumbers = 14;
constexpr MapBuffer::Key kArrayLength = 0;
#endif

bool hasExactConstraint(Float minimum, Float maximum)
{
  return std::isfinite(minimum) && std::isfinite(maximum) &&
      floatEquality(minimum, maximum);
}

bool hasBoundedConstraint(Float maximum)
{
  return std::isfinite(maximum);
}

CGFloat resolveFontSize(double fontSize)
{
  return fontSize > 0 ? fontSize : 14;
}

CGFloat resolveLineHeight(double lineHeight)
{
  return lineHeight > 0 ? lineHeight : 0;
}

NSString *toNSString(const std::string &value)
{
  return value.empty() ? nil : [NSString stringWithUTF8String:value.c_str()];
}

NSString *toNSStringNilIfEmpty(const std::string &value)
{
  return value.empty() ? nil : toNSString(value);
}

std::string fromNSString(NSString *value)
{
  return value != nil ? std::string(value.UTF8String ?: "") : std::string{};
}

std::u16string toUtf16String(NSString *value)
{
  if (value == nil || value.length == 0) {
    return {};
  }

  std::u16string result(value.length, 0);
  [value getCharacters:reinterpret_cast<unichar *>(result.data())
                 range:NSMakeRange(0, value.length)];
  return result;
}

std::u16string toUtf16(const std::string &value)
{
  return toUtf16String(toNSString(value));
}

NSString *toNSString(const std::u16string &value)
{
  if (value.empty()) {
    return @"";
  }

  return [[NSString alloc] initWithCharacters:reinterpret_cast<const unichar *>(value.data())
                                       length:value.size()];
}

std::string toUtf8(const std::u16string &value)
{
  return fromNSString(toNSString(value));
}

bool usesIdentityTransform(std::string_view textTransform)
{
  return textTransform.empty() || textTransform == "none";
}

[[noreturn]] void throwInvalidTextChild(const ShadowNode &child)
{
  throw std::runtime_error(
      "RNTextEngine: TextView nested children must resolve to TextView nodes. Found `" +
      std::string(child.getComponentName()) + "`.");
}

bool fragmentHasProps(const ShadowNodeFragment &fragment)
{
  return fragment.props != ShadowNodeFragment::propsPlaceholder();
}

bool fragmentHasChildren(const ShadowNodeFragment &fragment)
{
  return &fragment.children != &ShadowNodeFragment::childrenPlaceholder();
}

double resolveTypographyValue(double value, bool allowFontScaling)
{
  return allowFontScaling ? value * RCTFontSizeMultiplier() : value;
}

int resolveRunCount(const RNTextEngineTextViewProps &props)
{
  if (props.runStarts.empty() || props.runEnds.empty() || props.runStyleMasks.empty()) {
    return 0;
  }

  int runCount = props.runCount > 0 ? props.runCount : static_cast<int>(props.runStarts.size());
  runCount = std::min(runCount, static_cast<int>(props.runStarts.size()));
  runCount = std::min(runCount, static_cast<int>(props.runEnds.size()));
  runCount = std::min(runCount, static_cast<int>(props.runStyleMasks.size()));
  return std::max(runCount, 0);
}

template <typename T>
T valueOrDefault(const std::vector<T> &values, int index, const T &fallback)
{
  return index < static_cast<int>(values.size()) ? values[index] : fallback;
}

template <typename T>
void hashCombine(int64_t &hash, const T &value)
{
  hash = (hash * 31) + static_cast<int64_t>(std::hash<T>{}(value));
}

template <typename T>
void hashVector(int64_t &hash, const std::vector<T> &values)
{
  hashCombine(hash, values.size());
  for (const auto &value : values) {
    hashCombine(hash, value);
  }
}

void hashVector(int64_t &hash, const std::vector<bool> &values)
{
  hashCombine(hash, values.size());
  for (bool value : values) {
    hashCombine(hash, value);
  }
}

NSArray<NSNumber *> *toIntArray(const std::vector<int> &values)
{
  if (values.empty()) return nil;
  NSMutableArray<NSNumber *> *array = [NSMutableArray arrayWithCapacity:values.size()];
  for (int value : values) {
    [array addObject:@(value)];
  }
  return array;
}

NSArray<NSNumber *> *toIntArrayFromDoubleVector(const std::vector<double> &values, int count)
{
  if (count <= 0) return nil;
  NSMutableArray<NSNumber *> *array = [NSMutableArray arrayWithCapacity:count];
  for (int index = 0; index < count; index += 1) {
    [array addObject:@(static_cast<int>(valueOrDefault(values, index, 0.0)))];
  }
  return array;
}

NSArray<NSNumber *> *toDoubleArray(const std::vector<double> &values)
{
  if (values.empty()) return nil;
  NSMutableArray<NSNumber *> *array = [NSMutableArray arrayWithCapacity:values.size()];
  for (double value : values) {
    [array addObject:@(value)];
  }
  return array;
}

NSArray<NSNumber *> *toDoubleArray(const std::vector<double> &values, int count)
{
  if (count <= 0) return nil;
  NSMutableArray<NSNumber *> *array = [NSMutableArray arrayWithCapacity:count];
  for (int index = 0; index < count; index += 1) {
    [array addObject:@(valueOrDefault(values, index, 0.0))];
  }
  return array;
}

NSArray<NSString *> *toStringArray(const std::vector<std::string> &values)
{
  if (values.empty()) return nil;
  NSMutableArray<NSString *> *array = [NSMutableArray arrayWithCapacity:values.size()];
  for (const auto &value : values) {
    [array addObject:toNSString(value) ?: @""];
  }
  return array;
}

NSArray<NSString *> *toStringArray(const std::vector<std::string> &values, int count)
{
  if (count <= 0) return nil;
  NSMutableArray<NSString *> *array = [NSMutableArray arrayWithCapacity:count];
  for (int index = 0; index < count; index += 1) {
    [array addObject:toNSString(valueOrDefault(values, index, std::string{})) ?: @""];
  }
  return array;
}

NSArray<NSNumber *> *toBoolArray(const std::vector<bool> &values)
{
  if (values.empty()) return nil;
  NSMutableArray<NSNumber *> *array = [NSMutableArray arrayWithCapacity:values.size()];
  for (bool value : values) {
    [array addObject:@(value)];
  }
  return array;
}

NSArray<NSNumber *> *toBoolArray(const std::vector<bool> &values, int count)
{
  if (count <= 0) return nil;
  NSMutableArray<NSNumber *> *array = [NSMutableArray arrayWithCapacity:count];
  for (int index = 0; index < count; index += 1) {
    [array addObject:@(valueOrDefault(values, index, false))];
  }
  return array;
}

#ifdef RN_SERIALIZABLE_STATE
MapBuffer buildIntArrayMapBuffer(const std::vector<int> &values)
{
  MapBufferBuilder builder(static_cast<uint32_t>(values.size() + 1));
  builder.putInt(kArrayLength, static_cast<int>(values.size()));
  for (size_t index = 0; index < values.size(); index += 1) {
    builder.putInt(static_cast<MapBuffer::Key>(index + 1), values[index]);
  }
  return builder.build();
}

MapBuffer buildDoubleArrayMapBuffer(const std::vector<double> &values)
{
  MapBufferBuilder builder(static_cast<uint32_t>(values.size() + 1));
  builder.putInt(kArrayLength, static_cast<int>(values.size()));
  for (size_t index = 0; index < values.size(); index += 1) {
    builder.putDouble(static_cast<MapBuffer::Key>(index + 1), values[index]);
  }
  return builder.build();
}

MapBuffer buildStringArrayMapBuffer(const std::vector<std::string> &values)
{
  MapBufferBuilder builder(static_cast<uint32_t>(values.size() + 1));
  builder.putInt(kArrayLength, static_cast<int>(values.size()));
  for (size_t index = 0; index < values.size(); index += 1) {
    builder.putString(static_cast<MapBuffer::Key>(index + 1), values[index]);
  }
  return builder.build();
}

MapBuffer buildBoolArrayMapBuffer(const std::vector<bool> &values)
{
  MapBufferBuilder builder(static_cast<uint32_t>(values.size() + 1));
  builder.putInt(kArrayLength, static_cast<int>(values.size()));
  for (size_t index = 0; index < values.size(); index += 1) {
    builder.putBool(static_cast<MapBuffer::Key>(index + 1), values[index]);
  }
  return builder.build();
}

template <typename T>
std::vector<T> vectorFromDynamicArray(const folly::dynamic *value)
{
  if (value == nullptr || !value->isArray()) return {};

  std::vector<T> result;
  result.reserve(value->size());
  for (const auto &item : *value) {
    if constexpr (std::is_same_v<T, int>) {
      if (!item.isNumber()) return {};
      result.push_back(static_cast<int>(item.asInt()));
    } else if constexpr (std::is_same_v<T, double>) {
      if (!item.isNumber()) return {};
      result.push_back(item.asDouble());
    } else if constexpr (std::is_same_v<T, bool>) {
      if (!item.isBool()) return {};
      result.push_back(item.getBool());
    } else {
      if (!item.isString()) return {};
      result.emplace_back(item.getString());
    }
  }

  return result;
}
#endif

} // namespace

namespace facebook::react {

RNTextEngineTextViewStateData RNTextEngineTextViewStateData::empty()
{
  return {};
}

#ifdef RN_SERIALIZABLE_STATE
RNTextEngineTextViewStateData::RNTextEngineTextViewStateData(
    const RNTextEngineTextViewStateData &previousState,
    folly::dynamic data)
    : RNTextEngineTextViewStateData(previousState)
{
  if (!data.isObject()) return;

  if (const auto *value = data.get_ptr("hasNested"); value != nullptr && value->isBool()) {
    hasNested = value->getBool();
  }
  if (const auto *value = data.get_ptr("hash"); value != nullptr && value->isNumber()) {
    hash = static_cast<int64_t>(value->asInt());
  }
  if (const auto *value = data.get_ptr("text"); value != nullptr && value->isString()) {
    text = value->getString();
  }

  if (const auto *value = data.get_ptr("runStarts")) runStarts = vectorFromDynamicArray<int>(value);
  if (const auto *value = data.get_ptr("runEnds")) runEnds = vectorFromDynamicArray<int>(value);
  if (const auto *value = data.get_ptr("runStyleMasks")) runStyleMasks = vectorFromDynamicArray<int>(value);
  if (const auto *value = data.get_ptr("runColors")) runColors = vectorFromDynamicArray<std::string>(value);
  if (const auto *value = data.get_ptr("runFontFamilies")) runFontFamilies = vectorFromDynamicArray<std::string>(value);
  if (const auto *value = data.get_ptr("runFontSizes")) runFontSizes = vectorFromDynamicArray<double>(value);
  if (const auto *value = data.get_ptr("runFontWeights")) runFontWeights = vectorFromDynamicArray<std::string>(value);
  if (const auto *value = data.get_ptr("runFontStyles")) runFontStyles = vectorFromDynamicArray<std::string>(value);
  if (const auto *value = data.get_ptr("runLetterSpacings")) runLetterSpacings = vectorFromDynamicArray<double>(value);
  if (const auto *value = data.get_ptr("runLineHeights")) runLineHeights = vectorFromDynamicArray<double>(value);
  if (const auto *value = data.get_ptr("runTabularNumbers")) runTabularNumbers = vectorFromDynamicArray<bool>(value);
}

folly::dynamic RNTextEngineTextViewStateData::getDynamic() const
{
  folly::dynamic dynamic = folly::dynamic::object();
  dynamic["hasNested"] = hasNested;
  dynamic["hash"] = hash;
  dynamic["text"] = text;
  dynamic["runStarts"] = toDynamic(runStarts);
  dynamic["runEnds"] = toDynamic(runEnds);
  dynamic["runStyleMasks"] = toDynamic(runStyleMasks);
  dynamic["runColors"] = toDynamic(runColors);
  dynamic["runFontFamilies"] = toDynamic(runFontFamilies);
  dynamic["runFontSizes"] = toDynamic(runFontSizes);
  dynamic["runFontWeights"] = toDynamic(runFontWeights);
  dynamic["runFontStyles"] = toDynamic(runFontStyles);
  dynamic["runLetterSpacings"] = toDynamic(runLetterSpacings);
  dynamic["runLineHeights"] = toDynamic(runLineHeights);
  dynamic["runTabularNumbers"] = toDynamic(runTabularNumbers);
  return dynamic;
}

MapBuffer RNTextEngineTextViewStateData::getMapBuffer() const
{
  MapBufferBuilder builder(14);
  builder.putBool(kStateHasNested, hasNested);
  builder.putLong(kStateHash, hash);
  builder.putString(kStateText, text);
  builder.putMapBuffer(kStateRunStarts, buildIntArrayMapBuffer(runStarts));
  builder.putMapBuffer(kStateRunEnds, buildIntArrayMapBuffer(runEnds));
  builder.putMapBuffer(kStateRunStyleMasks, buildIntArrayMapBuffer(runStyleMasks));
  builder.putMapBuffer(kStateRunColors, buildStringArrayMapBuffer(runColors));
  builder.putMapBuffer(kStateRunFontFamilies, buildStringArrayMapBuffer(runFontFamilies));
  builder.putMapBuffer(kStateRunFontSizes, buildDoubleArrayMapBuffer(runFontSizes));
  builder.putMapBuffer(kStateRunFontWeights, buildStringArrayMapBuffer(runFontWeights));
  builder.putMapBuffer(kStateRunFontStyles, buildStringArrayMapBuffer(runFontStyles));
  builder.putMapBuffer(kStateRunLetterSpacings, buildDoubleArrayMapBuffer(runLetterSpacings));
  builder.putMapBuffer(kStateRunLineHeights, buildDoubleArrayMapBuffer(runLineHeights));
  builder.putMapBuffer(kStateRunTabularNumbers, buildBoolArrayMapBuffer(runTabularNumbers));
  return builder.build();
}
#endif

RNTextEngineTextViewShadowNode::RNTextEngineTextViewShadowNode(
    const ShadowNodeFragment &fragment,
    const ShadowNodeFamily::Shared &family,
    ShadowNodeTraits traits)
    : BaseShadowNode(fragment, family, traits)
{
}

RNTextEngineTextViewShadowNode::RNTextEngineTextViewShadowNode(
    const ShadowNode &sourceShadowNode,
    const ShadowNodeFragment &fragment)
    : BaseShadowNode(sourceShadowNode, fragment)
{
  const auto &source = static_cast<const RNTextEngineTextViewShadowNode &>(sourceShadowNode);
  if (!fragmentHasProps(fragment) && !fragmentHasChildren(fragment)) {
    measurementCache_ = source.measurementCache_;
    resolvedPayload_ = source.resolvedPayload_;
    hasPublishedNestedPayload_ = source.hasPublishedNestedPayload_;
    lastPublishedNestedHash_ = source.lastPublishedNestedHash_;
  }
}

ShadowNodeTraits RNTextEngineTextViewShadowNode::BaseTraits()
{
  auto traits = BaseShadowNode::BaseTraits();
  traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
  traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
  return traits;
}

Size RNTextEngineTextViewShadowNode::measureContent(
    const LayoutContext &,
    const LayoutConstraints &layoutConstraints) const
{
  const auto hasExactWidth = hasExactConstraint(
      layoutConstraints.minimumSize.width, layoutConstraints.maximumSize.width);
  const auto hasExactHeight = hasExactConstraint(
      layoutConstraints.minimumSize.height, layoutConstraints.maximumSize.height);
  if (hasExactWidth && hasExactHeight) {
    return layoutConstraints.maximumSize;
  }

  const auto &props = getConcreteProps();
  auto cache = ensureMeasurementCache();

  const auto resolvePreferredWidth = [&]() -> Float {
    if (cache->preferredWidth < 0) {
      cache->preferredWidth = measurePreparedTextWidthForHandle(cache->handle);
    }
    return static_cast<Float>(cache->preferredWidth);
  };

  const auto hasBoundedWidth =
      hasBoundedConstraint(layoutConstraints.maximumSize.width);
  const auto constrainedWidth =
      hasBoundedWidth ? std::max<Float>(0, layoutConstraints.maximumSize.width)
                      : resolvePreferredWidth();
  // AT_MOST must measure against the real width contract. Pre-shrinking through preferred width
  // can force premature ellipsis even when the text fits inside the bounded host.
  const auto layoutWidth =
      hasBoundedWidth ? constrainedWidth : resolvePreferredWidth();

  const auto maxLines = props.numberOfLines > 0 ? props.numberOfLines : 0;
  const auto ellipsizeMode = props.ellipsizeMode;

  auto layoutIterator = std::find_if(
      cache->layouts.begin(),
      cache->layouts.end(),
      [&](const CachedLayout &layout) {
        return layout.anchorToCapHeight == props.anchorToCapHeight &&
            layout.ellipsizeMode == ellipsizeMode &&
            layout.maxLines == maxLines &&
            floatEquality(static_cast<Float>(layout.width), layoutWidth);
      });

  if (layoutIterator == cache->layouts.end()) {
    cache->layouts.push_back({
        .anchorToCapHeight = props.anchorToCapHeight,
        .ellipsizeMode = ellipsizeMode,
        .maxLines = maxLines,
        .width = layoutWidth,
        .measurement = measurePreparedTextLayoutForHandle(
            cache->handle,
            layoutWidth,
            maxLines,
            toNSString(ellipsizeMode),
            props.anchorToCapHeight),
    });
    layoutIterator = std::prev(cache->layouts.end());
  }

  auto measuredWidth = static_cast<Float>(layoutIterator->measurement.width);
  if (hasExactWidth) measuredWidth = layoutConstraints.maximumSize.width;
  else if (hasBoundedWidth) {
    measuredWidth = std::min(measuredWidth, layoutConstraints.maximumSize.width);
  }

  auto measuredHeight = static_cast<Float>(layoutIterator->measurement.height);
  if (hasExactHeight) measuredHeight = layoutConstraints.maximumSize.height;
  else if (hasBoundedConstraint(layoutConstraints.maximumSize.height)) {
    measuredHeight = std::min(measuredHeight, layoutConstraints.maximumSize.height);
  }

  return layoutConstraints.clamp(
      {.width = measuredWidth, .height = measuredHeight});
}

void RNTextEngineTextViewShadowNode::layout(LayoutContext layoutContext)
{
  BaseShadowNode::layout(layoutContext);
  publishStateIfNeeded(resolvePayload());
}

bool RNTextEngineTextViewShadowNode::shouldNewRevisionDirtyMeasurement(
    const ShadowNode &,
    const ShadowNodeFragment &fragment) const
{
  return fragmentHasProps(fragment) || fragmentHasChildren(fragment);
}

std::shared_ptr<RNTextEngineTextViewShadowNode::MeasurementCache>
RNTextEngineTextViewShadowNode::ensureMeasurementCache() const
{
  if (measurementCache_ != nullptr) return measurementCache_;

  const auto &props = getConcreteProps();
  const auto payload = resolvePayload();
  const bool useNestedPayload = payload.hasNested;
  const int runCount = resolveRunCount(props);

  measurementCache_ = std::make_shared<MeasurementCache>();

  if (!useNestedPayload) {
    measurementCache_->handle = createPreparedTextHandleForTextView(
        toNSString(props.text) ?: @"",
        props.allowFontScaling,
        toNSStringNilIfEmpty(props.fontFamily),
        resolveFontSize(props.fontSize),
        toNSStringNilIfEmpty(props.fontWeight),
        toNSStringNilIfEmpty(props.fontStyle),
        props.letterSpacing,
        resolveLineHeight(props.lineHeight),
        props.tabularNumbers,
        toNSStringNilIfEmpty(props.textTransform),
        toIntArrayFromDoubleVector(props.runStarts, runCount),
        toIntArrayFromDoubleVector(props.runEnds, runCount),
        toIntArrayFromDoubleVector(props.runStyleMasks, runCount),
        toStringArray(props.runFontFamilies, runCount),
        toDoubleArray(props.runFontSizes, runCount),
        toStringArray(props.runFontStyles, runCount),
        toStringArray(props.runFontWeights, runCount),
        toDoubleArray(props.runLetterSpacings, runCount),
        toDoubleArray(props.runLineHeights, runCount),
        toBoolArray(props.runTabularNumbers, runCount));
    return measurementCache_;
  }

  const auto rootStyle = normalizePreparedStyle(resolveNodeStyle(props, nullptr));
  measurementCache_->handle = createPreparedTextHandleForTextView(
      toNSString(payload.text) ?: @"",
      NO,
      toNSStringNilIfEmpty(rootStyle.fontFamily),
      rootStyle.fontSize,
      toNSStringNilIfEmpty(rootStyle.fontWeight),
      toNSStringNilIfEmpty(rootStyle.fontStyle),
      rootStyle.letterSpacing,
      rootStyle.lineHeight,
      rootStyle.tabularNumbers,
      nil,
      toIntArray(payload.runStarts),
      toIntArray(payload.runEnds),
      toIntArray(payload.runStyleMasks),
      toStringArray(payload.runFontFamilies),
      toDoubleArray(payload.runFontSizes),
      toStringArray(payload.runFontStyles),
      toStringArray(payload.runFontWeights),
      toDoubleArray(payload.runLetterSpacings),
      toDoubleArray(payload.runLineHeights),
      toBoolArray(payload.runTabularNumbers));
  return measurementCache_;
}

RNTextEngineTextViewShadowNode::ResolvedPayload
RNTextEngineTextViewShadowNode::resolvePayload() const
{
  if (resolvedPayload_.has_value()) {
    return *resolvedPayload_;
  }

  if (getChildren().empty()) {
    resolvedPayload_ = ResolvedPayload{};
    return *resolvedPayload_;
  }

  if (!hasValidatedNestedTextChildren(*this)) {
    resolvedPayload_ = ResolvedPayload{};
    return *resolvedPayload_;
  }

  const auto rootStyle = resolveNodeStyle(getConcreteProps(), nullptr);
  std::u16string textBuilder;
  std::vector<ResolvedSegment> segments;
  segments.reserve(8);
  const bool hasNested = appendNodePayload(*this, rootStyle, textBuilder, segments);
  resolvedPayload_ =
      buildPayloadFromSegments(textBuilder, segments, rootStyle, hasNested);
  return *resolvedPayload_;
}

bool RNTextEngineTextViewShadowNode::hasValidatedNestedTextChildren(
    const RNTextEngineTextViewShadowNode &node) const
{
  bool hasNested = false;
  for (const auto &child : node.getChildren()) {
    const auto *textChild =
        dynamic_cast<const RNTextEngineTextViewShadowNode *>(child.get());
    if (textChild == nullptr) {
      throwInvalidTextChild(*child);
    }
    hasNested = true;
  }
  return hasNested;
}

bool RNTextEngineTextViewShadowNode::appendNodePayload(
    const RNTextEngineTextViewShadowNode &node,
    const ResolvedStyle &parentStyle,
    std::u16string &text,
    std::vector<ResolvedSegment> &segments) const
{
  const auto &props = node.getConcreteProps();
  const auto nodeStyle = resolveNodeStyle(props, &parentStyle);
  const auto localText = toUtf16(props.text);
  auto localRuns =
      resolveLocalRuns(props, nodeStyle, static_cast<int>(localText.size()));
  const auto transformed =
      resolveTransformedText(localText, nodeStyle.textTransform, std::move(localRuns));
  emitStyledText(transformed.first, nodeStyle, transformed.second, text, segments);

  bool hasNested = false;
  for (const auto &child : node.getChildren()) {
    const auto *textChild =
        dynamic_cast<const RNTextEngineTextViewShadowNode *>(child.get());
    if (textChild == nullptr) {
      throwInvalidTextChild(*child);
    }

    hasNested = true;
    appendNodePayload(*textChild, nodeStyle, text, segments);
  }

  return hasNested;
}

void RNTextEngineTextViewShadowNode::emitStyledText(
    const std::u16string &text,
    const ResolvedStyle &baseStyle,
    const std::vector<ResolvedRun> &runs,
    std::u16string &textBuilder,
    std::vector<ResolvedSegment> &segments) const
{
  if (text.empty()) {
    return;
  }

  if (runs.empty()) {
    appendSegment(textBuilder, segments, text, baseStyle);
    return;
  }

  int cursor = 0;
  for (const auto &run : runs) {
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
        text.substr(static_cast<size_t>(clampedStart), static_cast<size_t>(clampedEnd - clampedStart)),
        run.style);
    cursor = clampedEnd;
  }

  if (cursor < static_cast<int>(text.size())) {
    appendSegment(textBuilder, segments, text.substr(static_cast<size_t>(cursor)), baseStyle);
  }
}

void RNTextEngineTextViewShadowNode::appendSegment(
    std::u16string &textBuilder,
    std::vector<ResolvedSegment> &segments,
    const std::u16string &text,
    const ResolvedStyle &style) const
{
  if (text.empty()) {
    return;
  }
  const auto normalizedStyle = normalizePreparedStyle(style);

  const auto start = static_cast<int>(textBuilder.size());
  textBuilder += text;
  const auto end = static_cast<int>(textBuilder.size());

  if (!segments.empty()) {
    auto &last = segments.back();
    if (last.end == start &&
        last.style.color == normalizedStyle.color &&
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
    const RNTextEngineTextViewProps &props,
    const ResolvedStyle *parentStyle) const
{
  ResolvedStyle next = parentStyle == nullptr
      ? ResolvedStyle{
            .color = props.color ? props.color.toString() : std::string{},
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

  if (props.color) next.color = props.color.toString();
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
RNTextEngineTextViewShadowNode::normalizePreparedStyle(const ResolvedStyle &style)
{
  if (!style.allowFontScaling) {
    return style;
  }

  auto normalized = style;
  normalized.fontSize = resolveTypographyValue(normalized.fontSize, true);
  normalized.letterSpacing = resolveTypographyValue(normalized.letterSpacing, true);
  if (normalized.lineHeight > 0) {
    normalized.lineHeight = resolveTypographyValue(normalized.lineHeight, true);
  }
  normalized.allowFontScaling = false;
  return normalized;
}

std::vector<RNTextEngineTextViewShadowNode::ResolvedRun>
RNTextEngineTextViewShadowNode::resolveLocalRuns(
    const RNTextEngineTextViewProps &props,
    const ResolvedStyle &baseStyle,
    int textLength) const
{
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
    if (styleMask == 0 || start < previousEnd || start < 0 || end <= start ||
        end > textLength) {
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
    const std::u16string &text,
    const std::string &textTransform,
    std::vector<ResolvedRun> runs) const
{
  if (text.empty() || usesIdentityTransform(textTransform)) {
    return {text, std::move(runs)};
  }

  NSString *textValue = toNSString(text);
  NSString *transformValue = toNSStringNilIfEmpty(textTransform);
  if (runs.empty()) {
    return {toUtf16String(RNTextEngineApplyTextTransform(textValue, transformValue)), std::move(runs)};
  }

  NSMutableArray<NSNumber *> *runStarts = [NSMutableArray arrayWithCapacity:runs.size()];
  NSMutableArray<NSNumber *> *runEnds = [NSMutableArray arrayWithCapacity:runs.size()];
  for (const auto &run : runs) {
    [runStarts addObject:@(run.start)];
    [runEnds addObject:@(run.end)];
  }

  RNTextEngineTextTransformResult *transformed =
      RNTextEngineTransformText(textValue, transformValue, runStarts, runEnds);
  if (transformed.runStarts.count == runs.size() &&
      transformed.runEnds.count == runs.size()) {
    for (size_t index = 0; index < runs.size(); index += 1) {
      runs[index].start = transformed.runStarts[index].intValue;
      runs[index].end = transformed.runEnds[index].intValue;
    }
  }

  return {toUtf16String(transformed.text), std::move(runs)};
}

RNTextEngineTextViewShadowNode::ResolvedPayload
RNTextEngineTextViewShadowNode::buildPayloadFromSegments(
    const std::u16string &text,
    const std::vector<ResolvedSegment> &segments,
    const ResolvedStyle &rootStyle,
    bool hasNested) const
{
  const auto normalizedRootStyle = normalizePreparedStyle(rootStyle);
  ResolvedPayload payload;
  payload.hasNested = hasNested;
  if (!hasNested) {
    return payload;
  }

  payload.text = toUtf8(text);
  if (segments.empty()) {
    hashCombine(payload.hash, payload.text);
    return payload;
  }

  for (const auto &segment : segments) {
    int styleMask = 0;

    if (segment.style.color != normalizedRootStyle.color) {
      styleMask |= kRunStyleHasColor;
    }
    if (segment.style.fontFamily != normalizedRootStyle.fontFamily) {
      styleMask |= kRunStyleHasFontFamily;
    }
    if (segment.style.fontSize != normalizedRootStyle.fontSize) {
      styleMask |= kRunStyleHasFontSize;
    }
    if (segment.style.fontStyle != normalizedRootStyle.fontStyle) {
      styleMask |= kRunStyleHasFontStyle;
    }
    if (segment.style.fontWeight != normalizedRootStyle.fontWeight) {
      styleMask |= kRunStyleHasFontWeight;
    }
    if (segment.style.letterSpacing != normalizedRootStyle.letterSpacing) {
      styleMask |= kRunStyleHasLetterSpacing;
    }
    if (segment.style.lineHeight != normalizedRootStyle.lineHeight) {
      styleMask |= kRunStyleHasLineHeight;
    }
    if (segment.style.tabularNumbers != normalizedRootStyle.tabularNumbers) {
      styleMask |= kRunStyleHasTabularNumbers;
    }

    if (styleMask == 0) {
      continue;
    }

    payload.runStarts.push_back(segment.start);
    payload.runEnds.push_back(segment.end);
    payload.runStyleMasks.push_back(styleMask);
    payload.runColors.push_back(segment.style.color);
    payload.runFontFamilies.push_back(segment.style.fontFamily);
    payload.runFontSizes.push_back(segment.style.fontSize);
    payload.runFontWeights.push_back(segment.style.fontWeight);
    payload.runFontStyles.push_back(segment.style.fontStyle);
    payload.runLetterSpacings.push_back(segment.style.letterSpacing);
    payload.runLineHeights.push_back(segment.style.lineHeight);
    payload.runTabularNumbers.push_back(segment.style.tabularNumbers);
  }

  int64_t hash = 17;
  hashCombine(hash, payload.text);
  hashVector(hash, payload.runStarts);
  hashVector(hash, payload.runEnds);
  hashVector(hash, payload.runStyleMasks);
  hashVector(hash, payload.runColors);
  hashVector(hash, payload.runFontFamilies);
  hashVector(hash, payload.runFontSizes);
  hashVector(hash, payload.runFontWeights);
  hashVector(hash, payload.runFontStyles);
  hashVector(hash, payload.runLetterSpacings);
  hashVector(hash, payload.runLineHeights);
  hashVector(hash, payload.runTabularNumbers);
  payload.hash = hash;

  return payload;
}

void RNTextEngineTextViewShadowNode::publishStateIfNeeded(const ResolvedPayload &payload)
{
  if (!payload.hasNested) {
    if (!hasPublishedNestedPayload_) {
      return;
    }

    setStateData(RNTextEngineTextViewStateData::empty());
    hasPublishedNestedPayload_ = false;
    return;
  }

  if (hasPublishedNestedPayload_ && lastPublishedNestedHash_ == payload.hash) {
    return;
  }

  RNTextEngineTextViewStateData state;
  state.hasNested = true;
  state.hash = payload.hash;
  state.text = payload.text;
  state.runStarts = payload.runStarts;
  state.runEnds = payload.runEnds;
  state.runStyleMasks = payload.runStyleMasks;
  state.runColors = payload.runColors;
  state.runFontFamilies = payload.runFontFamilies;
  state.runFontSizes = payload.runFontSizes;
  state.runFontWeights = payload.runFontWeights;
  state.runFontStyles = payload.runFontStyles;
  state.runLetterSpacings = payload.runLetterSpacings;
  state.runLineHeights = payload.runLineHeights;
  state.runTabularNumbers = payload.runTabularNumbers;

  setStateData(std::move(state));
  hasPublishedNestedPayload_ = true;
  lastPublishedNestedHash_ = payload.hash;
}

RNTextEngineTextViewShadowNode::MeasurementCache::~MeasurementCache()
{
  releasePreparedTextHandle(handle);
}

} // namespace facebook::react

#endif
