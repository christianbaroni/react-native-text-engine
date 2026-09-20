#pragma once

#ifdef RCT_NEW_ARCH_ENABLED

#import "RNTextEngineTextAttributes.h"

#import <react/renderer/components/RNTextEngineSpec/EventEmitters.h>
#import <react/renderer/components/RNTextEngineSpec/Props.h>
#import <react/renderer/components/view/ConcreteViewShadowNode.h>
#import <react/renderer/core/ConcreteComponentDescriptor.h>
#import <react/renderer/core/ConcreteState.h>
#import <react/renderer/core/LayoutConstraints.h>
#import <react/renderer/core/LayoutContext.h>

#ifdef RN_SERIALIZABLE_STATE
#include <folly/dynamic.h>
#include <react/renderer/mapbuffer/MapBufferBuilder.h>
#endif

#include <memory>
#include <mutex>
#include <string>
#include <vector>

namespace facebook::react {

extern const char RNTextEngineTextViewComponentName[];

struct RNTextEngineTextViewStateData final {
  std::shared_ptr<const RNTextEngineTextContent> content;

  static RNTextEngineTextViewStateData empty();

#ifdef RN_SERIALIZABLE_STATE
  RNTextEngineTextViewStateData() = default;
  RNTextEngineTextViewStateData(
      const RNTextEngineTextViewStateData &previousState,
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
      const ShadowNodeFragment &fragment,
      const ShadowNodeFamily::Shared &family,
      ShadowNodeTraits traits);

  RNTextEngineTextViewShadowNode(
      const ShadowNode &sourceShadowNode,
      const ShadowNodeFragment &fragment);

  static ShadowNodeTraits BaseTraits();

  Size measureContent(
      const LayoutContext &layoutContext,
      const LayoutConstraints &layoutConstraints) const override;

  void layout(LayoutContext layoutContext) override;

 protected:
  bool shouldNewRevisionDirtyMeasurement(
      const ShadowNode &sourceShadowNode,
      const ShadowNodeFragment &fragment) const override;

 private:
  struct CachedLayout {
    bool anchorToCapHeight{false};
    std::string ellipsizeMode{};
    int maxLines{0};
    double width{0};
    CGSize measurement{CGSizeZero};
  };

  struct ResolvedStyle {
    UIColor *color{nil};
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
    NSString *text{nil};
    std::vector<RNTextEngineTextRun> runs;
    bool localized{false};
  };

  struct MeasurementCache;
  MeasurementCache &ensureMeasurementCache() const;
  void prepareMeasurementContent(MeasurementCache &cache, CGFloat fontScale) const;
  bool hasSameTextContent(const RNTextEngineTextViewShadowNode &other, bool inherited = false) const;
  ResolvedPayload resolvePayload(CGFloat fontScale) const;
  bool appendNodePayload(
      const RNTextEngineTextViewShadowNode &node,
      const ResolvedStyle &parentStyle,
      std::u16string &text,
      std::vector<ResolvedSegment> &segments,
      CGFloat fontScale) const;
  void emitStyledText(
      const std::u16string &text,
      const ResolvedStyle &baseStyle,
      const std::vector<ResolvedRun> &runs,
      std::u16string &textBuilder,
      std::vector<ResolvedSegment> &segments,
      CGFloat fontScale) const;
  void appendSegment(
      std::u16string &textBuilder,
      std::vector<ResolvedSegment> &segments,
      const std::u16string &text,
      const ResolvedStyle &style,
      CGFloat fontScale) const;
  static ResolvedStyle normalizePreparedStyle(const ResolvedStyle &style, CGFloat fontScale);
  ResolvedStyle resolveNodeStyle(
      const RNTextEngineTextViewProps &props,
      const ResolvedStyle *parentStyle) const;
  std::vector<ResolvedRun> resolveLocalRuns(
      const RNTextEngineTextViewProps &props,
      const ResolvedStyle &baseStyle,
      int textLength) const;
  std::pair<std::u16string, std::vector<ResolvedRun>> resolveTransformedText(
      const std::u16string &text,
      const std::string &textTransform,
      std::vector<ResolvedRun> runs) const;

  ResolvedPayload buildPayloadFromSegments(
      const std::u16string &text,
      const std::vector<ResolvedSegment> &segments,
      const ResolvedStyle &rootStyle,
      bool localized,
      CGFloat fontScale) const;

  mutable std::shared_ptr<MeasurementCache> measurementCache_{};
  mutable std::once_flag measurementCacheInitialization_;
};

using RNTextEngineTextViewComponentDescriptor =
    ConcreteComponentDescriptor<RNTextEngineTextViewShadowNode>;

} // namespace facebook::react

#endif
