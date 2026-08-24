#pragma once

#include <jni.h>
#include <jsi/jsi.h>
#include <string>
#include <vector>

namespace rntextengine {
struct TextViewMeasurementRuns {
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

struct PreparedTextLayoutMeasurement {
  double height{0};
  double width{0};
};

void cleanup(JNIEnv* env);
double currentFontScaleMultiplier();
void install(facebook::jsi::Runtime& runtime);
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
    const TextViewMeasurementRuns& runs);
double measurePreparedTextMeasurementWidth(uint64_t handle);
PreparedTextLayoutMeasurement measurePreparedTextMeasurementLayout(
    uint64_t handle,
    double width,
    int maxLines,
    const std::string& ellipsizeMode,
    bool anchorToCapHeight);
void releasePreparedTextMeasurementHandle(uint64_t handle);
} // namespace rntextengine
