#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NODE_BINARY="${NODE_BINARY:-$(command -v node)}"
DESTINATION_ID="${IOS_DESTINATION_ID:-$(xcrun simctl list devices booted available | awk -F '[()]' '/iPhone/ { print $2; exit }')}"

if [[ -z "${DESTINATION_ID}" ]]; then
  echo "Boot an iOS simulator or set IOS_DESTINATION_ID to a simulator UDID." >&2
  exit 1
fi

cd "${ROOT_DIR}"
mkdir -p benchmarks/.results
RESULT_DIR="$(mktemp -d "${ROOT_DIR}/benchmarks/.results/ios-comparison-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"
export NODE_BINARY
export RCT_NEW_ARCH_ENABLED=1
"${NODE_BINARY}" benchmarks/report.mjs capture "${RESULT_DIR}"

XCODE_ARGS=(
  -workspace examples/ios/example.xcworkspace
  -scheme example
  -configuration Release
  -sdk iphonesimulator
  -destination "id=${DESTINATION_ID}"
  -derivedDataPath benchmarks/.results/derived-data
  -parallel-testing-enabled NO
  'GCC_PREPROCESSOR_DEFINITIONS=$(inherited) RCT_NEW_ARCH_ENABLED=1'
  -only-testing:exampleTests/RNTextEngineTextViewComparisonBenchmarks/testTextViewComparisonBenchmarks
)
xcodebuild build-for-testing "${XCODE_ARGS[@]}" 2>&1 | tee "${RESULT_DIR}/build.log"

for run in 1 2 3; do
  TEST_RUNNER_RNTE_BENCHMARK=1 TEST_RUNNER_RNTE_BENCHMARK_RUN="${run}" \
    xcodebuild test-without-building "${XCODE_ARGS[@]}" \
      -resultBundlePath "${RESULT_DIR}/run-${run}.xcresult" \
      2>&1 | tee "${RESULT_DIR}/run-${run}.log"
done

"${NODE_BINARY}" benchmarks/report.mjs write "${RESULT_DIR}"
