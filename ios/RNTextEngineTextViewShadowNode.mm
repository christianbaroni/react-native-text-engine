#ifdef RCT_NEW_ARCH_ENABLED

#import "RNTextEngineTextViewShadowNode.h"

#import "RNTextEngineBindings.h"
#import "RNTextEngineColorUtils.h"
#import "RNTextEngineTextTransform.h"
#import <React/RCTConversions.h>

#import <react/renderer/core/conversions.h>

#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <string_view>
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

bool hasExactConstraint(Float minimum, Float maximum)
{
  return std::isfinite(minimum) && std::isfinite(maximum) &&
      minimum == maximum;
}

bool hasBoundedConstraint(Float maximum)
{
  return std::isfinite(maximum);
}

NSString *toNSString(const std::string &value)
{
  return value.empty() ? nil : [NSString stringWithUTF8String:value.c_str()];
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

} // namespace

namespace facebook::react {

RNTextEngineTextViewStateData RNTextEngineTextViewStateData::empty()
{
  return {};
}

#ifdef RN_SERIALIZABLE_STATE
RNTextEngineTextViewStateData::RNTextEngineTextViewStateData(
    const RNTextEngineTextViewStateData &previousState, folly::dynamic)
    : RNTextEngineTextViewStateData(previousState) {}
folly::dynamic RNTextEngineTextViewStateData::getDynamic() const { return folly::dynamic::object(); }
MapBuffer RNTextEngineTextViewStateData::getMapBuffer() const { return MapBufferBuilder().build(); }
#endif

struct RNTextEngineTextViewShadowNode::MeasurementCache {
  std::mutex mutex;
  std::shared_ptr<const RNTextEngineTextContent> content;
  RNTextEnginePreparedText *prepared{nil};
  double preferredWidth{-1};
  std::vector<CachedLayout> layouts;
  size_t nextLayout{0};
};

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
  if (hasSameTextContent(source)) {
    measurementCache_ = std::atomic_load(&source.measurementCache_);
  }
}

bool RNTextEngineTextViewShadowNode::hasSameTextContent(
    const RNTextEngineTextViewShadowNode &other, bool inherited) const
{
  const auto &props = getConcreteProps();
  const auto &previous = other.getConcreteProps();
  if (!RNTextEngineHasSameTextAttributes(props, previous, inherited)) return false;
  const auto &children = getChildren();
  const auto &previousChildren = other.getChildren();
  if (children.size() != previousChildren.size()) return false;
  for (size_t index = 0; index < children.size(); ++index) {
    if (children[index] == previousChildren[index]) continue;
    const auto *child = dynamic_cast<const RNTextEngineTextViewShadowNode *>(children[index].get());
    const auto *previousChild = dynamic_cast<const RNTextEngineTextViewShadowNode *>(previousChildren[index].get());
    if (child == nullptr || previousChild == nullptr || !child->hasSameTextContent(*previousChild, true)) return false;
  }
  return true;
}

ShadowNodeTraits RNTextEngineTextViewShadowNode::BaseTraits()
{
  auto traits = BaseShadowNode::BaseTraits();
  traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
  traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
  return traits;
}

Size RNTextEngineTextViewShadowNode::measureContent(
    const LayoutContext &layoutContext,
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
  auto &cache = ensureMeasurementCache();
  std::lock_guard<std::mutex> lock(cache.mutex);
  prepareMeasurementContent(cache, layoutContext.fontSizeMultiplier);

  const auto resolvePreferredWidth = [&]() -> Float {
    if (cache.preferredWidth < 0) {
      cache.preferredWidth = measurePreparedTextWidth(cache.prepared);
    }
    return static_cast<Float>(cache.preferredWidth);
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
      cache.layouts.begin(),
      cache.layouts.end(),
      [&](const CachedLayout &layout) {
        return layout.anchorToCapHeight == props.anchorToCapHeight &&
            layout.ellipsizeMode == ellipsizeMode &&
            layout.maxLines == maxLines &&
            layout.width == layoutWidth;
      });

  if (layoutIterator == cache.layouts.end()) {
    CachedLayout layout{
        .anchorToCapHeight = props.anchorToCapHeight,
        .ellipsizeMode = ellipsizeMode,
        .maxLines = maxLines,
        .width = layoutWidth,
        .measurement = measurePreparedTextLayout(
            cache.prepared,
            layoutWidth,
            maxLines,
            toNSString(ellipsizeMode),
            props.anchorToCapHeight),
    };
    // Keep recent constraints without tying their history to prepared-text lifetime.
    constexpr size_t capacity = 8;
    if (cache.layouts.size() < capacity) cache.layouts.push_back(std::move(layout));
    else cache.layouts[cache.nextLayout] = std::move(layout);
    layoutIterator = cache.layouts.begin() + cache.nextLayout;
    cache.nextLayout = (cache.nextLayout + 1) % capacity;
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
  auto &cache = ensureMeasurementCache();
  std::lock_guard<std::mutex> lock(cache.mutex);
  prepareMeasurementContent(cache, layoutContext.fontSizeMultiplier);
  if (getStateData().content != cache.content) {
    RNTextEngineTextViewStateData state;
    state.content = cache.content;
    setStateData(std::move(state));
  }
}

bool RNTextEngineTextViewShadowNode::shouldNewRevisionDirtyMeasurement(
    const ShadowNode &,
    const ShadowNodeFragment &fragment) const
{
  return fragmentHasProps(fragment) || fragmentHasChildren(fragment);
}

RNTextEngineTextViewShadowNode::MeasurementCache &
RNTextEngineTextViewShadowNode::ensureMeasurementCache() const
{
  std::call_once(measurementCacheInitialization_, [this] {
    if (measurementCache_ == nullptr) {
      std::atomic_store(&measurementCache_, std::make_shared<MeasurementCache>());
    }
  });
  return *measurementCache_;
}

void RNTextEngineTextViewShadowNode::prepareMeasurementContent(MeasurementCache &cache, CGFloat fontScale) const
{
  if (cache.content != nullptr && cache.content->fontScale == fontScale &&
      (cache.content->locale == nil || [cache.content->locale isEqual:NSLocale.currentLocale])) return;
  NSLocale *locale = NSLocale.currentLocale;

  auto content = std::make_shared<RNTextEngineTextContent>();
  content->props = std::static_pointer_cast<const RNTextEngineTextViewProps>(getProps());
  content->fontScale = fontScale;
  const auto &props = *content->props;
  const bool nested = !getChildren().empty();
  if (nested) {
    auto payload = resolvePayload(fontScale);
    if (payload.localized) content->locale = locale;
    content->nestedText = payload.text;
    content->nestedRuns = std::move(payload.runs);
  } else if (props.textTransform == "capitalize") {
    content->locale = locale;
  }
  const auto flatRuns = nested ? std::vector<RNTextEngineTextRun>{} : RNTextEngineTextRunsFromProps(props);
  CGFloat emptyLineHeight = 0;
  content->attributedText = RNTextEngineBuildAttributedText(
      nested ? content->nestedText : (toNSString(props.text) ?: @""),
      RNTextEngineTextAttributesFromProps(props, fontScale),
      nested ? content->nestedRuns : flatRuns,
      nested ? nil : toNSString(props.textTransform),
      nested,
      &emptyLineHeight);
  cache.prepared = prepareAttributedText(
      content->attributedText, emptyLineHeight, RNTextEngineTextResolveAlignment(toNSString(props.textAlign)));
  cache.content = std::move(content);
  cache.preferredWidth = -1;
  cache.layouts.clear();
  cache.nextLayout = 0;
}

RNTextEngineTextViewShadowNode::ResolvedPayload RNTextEngineTextViewShadowNode::resolvePayload(CGFloat fontScale) const
{
  const auto rootStyle = resolveNodeStyle(getConcreteProps(), nullptr);
  std::u16string text;
  std::vector<ResolvedSegment> segments;
  segments.reserve(8);
  const bool localized = appendNodePayload(*this, rootStyle, text, segments, fontScale);
  return buildPayloadFromSegments(text, segments, rootStyle, localized, fontScale);
}

bool RNTextEngineTextViewShadowNode::appendNodePayload(
    const RNTextEngineTextViewShadowNode &node,
    const ResolvedStyle &parentStyle,
    std::u16string &text,
    std::vector<ResolvedSegment> &segments,
    CGFloat fontScale) const
{
  const auto &props = node.getConcreteProps();
  const auto nodeStyle = resolveNodeStyle(props, &parentStyle);
  const auto localText = toUtf16(props.text);
  auto localRuns =
      resolveLocalRuns(props, nodeStyle, static_cast<int>(localText.size()));
  const auto transformed =
      resolveTransformedText(localText, nodeStyle.textTransform, std::move(localRuns));
  emitStyledText(transformed.first, nodeStyle, transformed.second, text, segments, fontScale);

  bool localized = nodeStyle.textTransform == "capitalize";
  for (const auto &child : node.getChildren()) {
    const auto *textChild =
        dynamic_cast<const RNTextEngineTextViewShadowNode *>(child.get());
    if (textChild == nullptr) {
      throwInvalidTextChild(*child);
    }

    localized |= appendNodePayload(*textChild, nodeStyle, text, segments, fontScale);
  }

  return localized;
}

void RNTextEngineTextViewShadowNode::emitStyledText(
    const std::u16string &text,
    const ResolvedStyle &baseStyle,
    const std::vector<ResolvedRun> &runs,
    std::u16string &textBuilder,
    std::vector<ResolvedSegment> &segments,
    CGFloat fontScale) const
{
  if (text.empty()) {
    return;
  }

  if (runs.empty()) {
    appendSegment(textBuilder, segments, text, baseStyle, fontScale);
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
          baseStyle, fontScale);
    }

    appendSegment(
        textBuilder,
        segments,
        text.substr(static_cast<size_t>(clampedStart), static_cast<size_t>(clampedEnd - clampedStart)),
        run.style, fontScale);
    cursor = clampedEnd;
  }

  if (cursor < static_cast<int>(text.size())) {
    appendSegment(textBuilder, segments, text.substr(static_cast<size_t>(cursor)), baseStyle, fontScale);
  }
}

void RNTextEngineTextViewShadowNode::appendSegment(
    std::u16string &textBuilder,
    std::vector<ResolvedSegment> &segments,
    const std::u16string &text,
    const ResolvedStyle &style,
    CGFloat fontScale) const
{
  if (text.empty()) {
    return;
  }
  const auto normalizedStyle = normalizePreparedStyle(style, fontScale);

  const auto start = static_cast<int>(textBuilder.size());
  textBuilder += text;
  const auto end = static_cast<int>(textBuilder.size());

  if (!segments.empty()) {
    auto &last = segments.back();
    if (last.end == start &&
        (last.style.color == normalizedStyle.color || [last.style.color isEqual:normalizedStyle.color]) &&
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
            .color = RCTUIColorFromSharedColor(props.color),
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

  if (props.color) next.color = RCTUIColorFromSharedColor(props.color);
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
RNTextEngineTextViewShadowNode::normalizePreparedStyle(const ResolvedStyle &style, CGFloat fontScale)
{
  if (!style.allowFontScaling) {
    return style;
  }

  auto normalized = style;
  normalized.fontSize = normalized.fontSize * fontScale;
  normalized.letterSpacing = normalized.letterSpacing * fontScale;
  if (normalized.lineHeight > 0) {
    normalized.lineHeight = normalized.lineHeight * fontScale;
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
      style.color = RNTextEngineResolveColorValue(toNSString(valueOrDefault(props.runColors, index, std::string{})));
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
  NSString *transformValue = toNSString(textTransform);
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
    bool localized,
    CGFloat fontScale) const
{
  const auto normalizedRootStyle = normalizePreparedStyle(rootStyle, fontScale);
  std::vector<RNTextEngineTextRun> runs;
  runs.reserve(segments.size());
  for (const auto &segment : segments) {
    RNTextEngineTextRunStyle style;
    bool overridden = false;
    if (segment.style.color != normalizedRootStyle.color && ![segment.style.color isEqual:normalizedRootStyle.color]) {
      style.color = segment.style.color;
      overridden = true;
    }
    if (segment.style.fontFamily != normalizedRootStyle.fontFamily) {
      style.fontFamily = toNSString(segment.style.fontFamily) ?: @"";
      overridden = true;
    }
    if (segment.style.fontSize != normalizedRootStyle.fontSize) {
      style.fontSize = segment.style.fontSize;
      overridden = true;
    }
    if (segment.style.fontStyle != normalizedRootStyle.fontStyle) {
      style.fontStyle = toNSString(segment.style.fontStyle) ?: @"";
      overridden = true;
    }
    if (segment.style.fontWeight != normalizedRootStyle.fontWeight) {
      style.fontWeight = toNSString(segment.style.fontWeight) ?: @"";
      overridden = true;
    }
    if (segment.style.letterSpacing != normalizedRootStyle.letterSpacing) {
      style.letterSpacing = segment.style.letterSpacing;
      overridden = true;
    }
    if (segment.style.lineHeight != normalizedRootStyle.lineHeight) {
      style.lineHeight = segment.style.lineHeight;
      overridden = true;
    }
    if (segment.style.tabularNumbers != normalizedRootStyle.tabularNumbers) {
      style.tabularNumbers = segment.style.tabularNumbers;
      overridden = true;
    }
    if (!overridden) continue;
    RNTextEngineTextRun run;
    run.start = segment.start;
    run.end = segment.end;
    run.style = style;
    runs.push_back(std::move(run));
  }
  return {.text = toNSString(text), .runs = std::move(runs), .localized = localized};
}

} // namespace facebook::react

#endif
