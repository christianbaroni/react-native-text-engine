#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DESTINATION_ID="${IOS_DESTINATION_ID:-$(xcrun simctl list devices booted available | awk -F '[()]' '/iPhone/ { print $2; exit }')}"
CONFIGURATION="${IOS_CONFIGURATION:-Release}"
export NODE_BINARY="${NODE_BINARY:-$(command -v node)}"
export TEST_RUNNER_RNTE_BENCHMARK=1

if [[ -z "${DESTINATION_ID}" ]]; then
  echo "No booted iOS simulator found. Boot a simulator or set IOS_DESTINATION_ID." >&2
  exit 1
fi

cd "${ROOT_DIR}"
mkdir -p benchmarks/.results
RESULT_DIR="$(mktemp -d "${ROOT_DIR}/benchmarks/.results/ios-calibration-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"

"${NODE_BINARY}" --import jiti/register benchmarks/report.mts capture "${RESULT_DIR}"
XCODE_ARGS=(
  -workspace examples/ios/example.xcworkspace -scheme example -configuration "${CONFIGURATION}"
  -sdk iphonesimulator -destination "id=${DESTINATION_ID}" -parallel-testing-enabled NO
  -derivedDataPath benchmarks/.results/derived-data-memory
)
xcodebuild build-for-testing "${XCODE_ARGS[@]}" 2>&1 | tee "${RESULT_DIR}/build.log"
if [[ "${BENCHMARK_MEMORY_ONLY:-0}" != 1 ]]; then
  xcodebuild test-without-building "${XCODE_ARGS[@]}" \
    -only-testing:exampleTests/RNTextEnginePerformanceTests/testPreparedBatchCreateChatLifecycle \
    -only-testing:exampleTests/RNTextEnginePerformanceTests/testPreparedBatchLayoutReuseChat \
    -only-testing:exampleTests/RNTextEnginePerformanceTests/testPrepareInlineRunsLifecycle \
    -only-testing:exampleTests/RNTextEnginePerformanceTests/testOneShotMeasureBatchChat \
    2>&1 | tee "${RESULT_DIR}/prepared-text.log"
  xcodebuild test-without-building "${XCODE_ARGS[@]}" \
    -only-testing:exampleTests/RNTextEnginePerformanceTests/testGlyphBufferCommitLowChurn \
    -only-testing:exampleTests/RNTextEnginePerformanceTests/testGlyphIndicesLowChurn \
    -only-testing:exampleTests/RNTextEnginePerformanceTests/testGlyphStringLowChurn \
    -only-testing:exampleTests/RNTextEnginePerformanceTests/testGlyphStringHighChurn \
    -only-testing:exampleTests/RNTextEnginePerformanceTests/testLayoutNextLineVariableWidthSequence \
    -only-testing:exampleTests/RNTextEnginePerformanceTests/testLayoutNextLineVariableWidthSequenceAnchoredToCapHeight \
    2>&1 | tee "${RESULT_DIR}/glyph-flow.log"
fi
for run in 1 2 3; do
  TEST_RUNNER_RNTE_BENCHMARK_RUN="${run}" xcodebuild test-without-building "${XCODE_ARGS[@]}" \
    -only-testing:exampleTests/RNTextEnginePerformanceTests/testMemoryFootprint \
    -resultBundlePath "${RESULT_DIR}/memory-${run}.xcresult" 2>&1 | tee "${RESULT_DIR}/memory-${run}.log"
done
if [[ "${CONFIGURATION}" == Release ]]; then
  "${NODE_BINARY}" --import jiti/register benchmarks/report.mts memory "${RESULT_DIR}" library
fi
