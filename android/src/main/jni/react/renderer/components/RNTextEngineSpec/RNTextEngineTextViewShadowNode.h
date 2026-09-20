#pragma once

#include <react/renderer/components/RNTextEngineSpec/EventEmitters.h>
#include <react/renderer/components/RNTextEngineSpec/Props.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>
#include <react/renderer/core/ConcreteState.h>
#include <react/renderer/core/LayoutConstraints.h>
#include <react/renderer/core/LayoutContext.h>

#if defined(ANDROID) || defined(RN_SERIALIZABLE_STATE)
#include <folly/dynamic.h>
#include <react/renderer/mapbuffer/MapBufferBuilder.h>
#endif

#include <cstdint>
#include <limits>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

namespace rntextengine {

struct TextViewMeasurementRuns {
  std::vector<std::string> colors;
  std::vector<int> ends;
  std::vector<std::string> fontFamilies;
  std::vector<double> fontSizes;
  std::vector<std::string> fontStyles;
  std::vector<std::string> fontWeights;
  std::vector<double> letterSpacings;
  std::vector<double> lineHeights;
  std::vector<int> starts;
  std::vector<int> styleMasks;
  std::vector<bool> tabularNumbers;
};

uint64_t textEnvironmentVersion();
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
    bool hasNested = false);
double measurePreparedTextMeasurementWidth(uint64_t handle);
facebook::react::Size measurePreparedTextMeasurementLayout(
    uint64_t handle,
    double width,
    int maxLines,
    const std::string& ellipsizeMode,
    bool anchorToCapHeight);
void releasePreparedTextMeasurementHandle(uint64_t handle);

struct PreparedTextHandle {
  explicit PreparedTextHandle(uint64_t value) : handle(value) {}
  ~PreparedTextHandle();
  const uint64_t handle;
};

} // namespace rntextengine

namespace facebook::react {

extern const char RNTextEngineTextViewComponentName[];

struct RNTextEngineTextViewStateData final {
  std::shared_ptr<const rntextengine::PreparedTextHandle> preparedText{};

#if defined(ANDROID) || defined(RN_SERIALIZABLE_STATE)
  RNTextEngineTextViewStateData() = default;
  RNTextEngineTextViewStateData(
      const RNTextEngineTextViewStateData& previousState,
      folly::dynamic data);
  folly::dynamic getDynamic() const;
  MapBuffer getMapBuffer() const;
#endif
};

class RNTextEngineTextViewShadowNode final : public ConcreteViewShadowNode<
                                                 RNTextEngineTextViewComponentName,
                                                 RNTextEngineTextViewProps,
                                                 RNTextEngineTextViewEventEmitter,
                                                 RNTextEngineTextViewStateData> {
 public:
  using BaseShadowNode = ConcreteViewShadowNode<
      RNTextEngineTextViewComponentName,
      RNTextEngineTextViewProps,
      RNTextEngineTextViewEventEmitter,
      RNTextEngineTextViewStateData>;
  using ConcreteState = facebook::react::ConcreteState<RNTextEngineTextViewStateData>;

  using BaseShadowNode::BaseShadowNode;

  RNTextEngineTextViewShadowNode(
      const ShadowNodeFragment& fragment,
      const ShadowNodeFamily::Shared& family,
      ShadowNodeTraits traits);

  RNTextEngineTextViewShadowNode(
      const ShadowNode& sourceShadowNode,
      const ShadowNodeFragment& fragment);

  static ShadowNodeTraits BaseTraits();

  Size measureContent(
      const LayoutContext& layoutContext,
      const LayoutConstraints& layoutConstraints) const override;

  void layout(LayoutContext layoutContext) override;

 protected:
  virtual bool shouldNewRevisionDirtyMeasurement(
      const ShadowNode& sourceShadowNode,
      const ShadowNodeFragment& fragment) const final;

 private:
  struct CachedLayout {
    bool anchorToCapHeight{false};
    std::string ellipsizeMode{};
    int maxLines{0};
    double width{0};
    Size measurement{};
  };

  struct ResolvedStyle {
    std::string color{};
    std::string fontFamily{};
    double fontSize{14.0};
    std::string fontStyle{};
    std::string fontWeight{};
    double letterSpacing{0.0};
    double lineHeight{0.0};
    bool tabularNumbers{false};
    std::string textTransform{};
    bool allowFontScaling{false};
  };

  struct ResolvedRun {
    int start{0};
    int end{0};
    ResolvedStyle style{};
  };

  struct ResolvedSegment {
    int start{0};
    int end{0};
    ResolvedStyle style{};
  };

  struct ResolvedPayload {
    std::string text;
    rntextengine::TextViewMeasurementRuns runs;
  };

  struct MeasurementCache {
    std::mutex mutex;
    uint64_t environmentVersion{0};
    std::shared_ptr<const rntextengine::PreparedTextHandle> preparedText;
    double preferredWidth{-1};
    std::vector<CachedLayout> layouts{};
  };

  bool hasSameTextContent(const RNTextEngineTextViewShadowNode& source, bool asChild = false) const;
  MeasurementCache& ensureMeasurementCache() const;
  void prepareMeasurementHandle(MeasurementCache& cache) const;
  rntextengine::TextViewMeasurementRuns buildRuns() const;

  ResolvedPayload resolvePayload() const;
  void appendNodePayload(
      const RNTextEngineTextViewShadowNode& node,
      const ResolvedStyle& parentStyle,
      std::u16string& text,
      std::vector<ResolvedSegment>& segments) const;
  void emitStyledText(
      const std::u16string& text,
      const ResolvedStyle& baseStyle,
      const std::vector<ResolvedRun>& runs,
      std::u16string& textBuilder,
      std::vector<ResolvedSegment>& segments) const;
  void appendSegment(
      std::u16string& textBuilder,
      std::vector<ResolvedSegment>& segments,
      const std::u16string& text,
      const ResolvedStyle& style) const;
  static ResolvedStyle normalizePreparedStyle(const ResolvedStyle& style);
  ResolvedStyle resolveNodeStyle(
      const RNTextEngineTextViewProps& props,
      const ResolvedStyle* parentStyle) const;
  std::vector<ResolvedRun> resolveLocalRuns(
      const RNTextEngineTextViewProps& props,
      const ResolvedStyle& baseStyle,
      int textLength) const;
  std::pair<std::u16string, std::vector<ResolvedRun>> resolveTransformedText(
      const std::u16string& text,
      const std::string& textTransform,
      std::vector<ResolvedRun> runs) const;

  ResolvedPayload buildPayloadFromSegments(
      const std::u16string& text,
      const std::vector<ResolvedSegment>& segments,
      const ResolvedStyle& rootStyle) const;

  mutable std::shared_ptr<MeasurementCache> measurementCache_{};
  mutable std::once_flag measurementCacheInitialization_;
};

} // namespace facebook::react
