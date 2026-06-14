#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DESTINATION_ID="${IOS_DESTINATION_ID:-$(xcrun simctl list devices booted available | awk -F '[()]' '/iPhone/ { print $2; exit }')}"
CONFIGURATION="${IOS_CONFIGURATION:-Debug}"

if [[ -z "${DESTINATION_ID}" ]]; then
  echo "No booted iOS simulator found. Boot a simulator or set IOS_DESTINATION_ID." >&2
  exit 1
fi

cd "${ROOT_DIR}"

xcodebuild test \
  -workspace examples/ios/example.xcworkspace \
  -scheme example \
  -configuration "${CONFIGURATION}" \
  -destination "id=${DESTINATION_ID}" \
  -only-testing:exampleTests/RNTextEnginePerformanceTests/testPreparedBatchCreateChatLifecycle \
  -only-testing:exampleTests/RNTextEnginePerformanceTests/testPreparedBatchLayoutReuseChat \
  -only-testing:exampleTests/RNTextEnginePerformanceTests/testPrepareInlineRunsLifecycle \
  -only-testing:exampleTests/RNTextEnginePerformanceTests/testOneShotMeasureBatchChat

xcodebuild test \
  -workspace examples/ios/example.xcworkspace \
  -scheme example \
  -configuration "${CONFIGURATION}" \
  -destination "id=${DESTINATION_ID}" \
  -only-testing:exampleTests/RNTextEnginePerformanceTests/testGlyphBufferCommitLowChurn \
  -only-testing:exampleTests/RNTextEnginePerformanceTests/testGlyphIndicesLowChurn \
  -only-testing:exampleTests/RNTextEnginePerformanceTests/testGlyphStringLowChurn \
  -only-testing:exampleTests/RNTextEnginePerformanceTests/testGlyphStringHighChurn \
  -only-testing:exampleTests/RNTextEnginePerformanceTests/testLayoutNextLineVariableWidthSequence \
  -only-testing:exampleTests/RNTextEnginePerformanceTests/testLayoutNextLineVariableWidthSequenceAnchoredToCapHeight
