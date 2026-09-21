#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NODE_BINARY="${NODE_BINARY:-$(command -v node)}"
DESTINATION_ID="${IOS_DESTINATION_ID:-$(xcrun simctl list devices booted available | awk -F '[()]' '/iPhone/ { print $2; exit }')}"

if [[ -z "${DESTINATION_ID}" ]]; then
  echo "Boot an iOS simulator or set IOS_DESTINATION_ID to a simulator or device UDID." >&2
  exit 1
fi

cd "${ROOT_DIR}"
mkdir -p benchmarks/.results
RESULT_DIR="$(mktemp -d "${ROOT_DIR}/benchmarks/.results/ios-comparison-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"
export NODE_BINARY
export RCT_NEW_ARCH_ENABLED=1
"${NODE_BINARY}" --import jiti/register benchmarks/report.mts capture "${RESULT_DIR}"

XCODE_ARGS=(
  -workspace examples/ios/example.xcworkspace
  -scheme example
  -configuration Release
  -destination "id=${DESTINATION_ID}"
  -derivedDataPath benchmarks/.results/derived-data-memory
  -parallel-testing-enabled NO
  'GCC_PREPROCESSOR_DEFINITIONS=$(inherited) RCT_NEW_ARCH_ENABLED=1'
)
xcodebuild build-for-testing "${XCODE_ARGS[@]}" 2>&1 | tee "${RESULT_DIR}/build.log"

for run in 1 2 3; do
  if [[ "${BENCHMARK_MEMORY_ONLY:-0}" != 1 ]]; then
    TEST_RUNNER_RNTE_BENCHMARK=1 TEST_RUNNER_RNTE_BENCHMARK_RUN="${run}" \
      xcodebuild test-without-building "${XCODE_ARGS[@]}" \
        -only-testing:exampleTests/RNTextEngineTextViewComparisonBenchmarks/testTextViewComparisonBenchmarks \
        -resultBundlePath "${RESULT_DIR}/run-${run}.xcresult" \
        2>&1 | tee "${RESULT_DIR}/run-${run}.log"
  fi
  case "${run}" in
    1) IMPLEMENTATIONS=(rn textview preparedtextview) ;;
    2) IMPLEMENTATIONS=(textview preparedtextview rn) ;;
    3) IMPLEMENTATIONS=(preparedtextview rn textview) ;;
  esac
  for implementation in "${IMPLEMENTATIONS[@]}"; do
    TEST_RUNNER_RNTE_BENCHMARK=1 TEST_RUNNER_RNTE_BENCHMARK_RUN="${run}" TEST_RUNNER_RNTE_MEMORY_IMPLEMENTATION="${implementation}" \
      xcodebuild test-without-building "${XCODE_ARGS[@]}" \
        -only-testing:exampleTests/RNTextEngineTextViewComparisonBenchmarks/testTextViewMemory \
        -resultBundlePath "${RESULT_DIR}/memory-${run}-${implementation}.xcresult" \
        2>&1 | tee "${RESULT_DIR}/memory-${run}-${implementation}.log"
  done
done

if [[ "${BENCHMARK_MEMORY_ONLY:-0}" == 1 ]]; then
  "${NODE_BINARY}" --import jiti/register benchmarks/report.mts memory "${RESULT_DIR}" rn-text
else
  "${NODE_BINARY}" --import jiti/register benchmarks/report.mts write "${RESULT_DIR}"
fi
