#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if ! adb devices | awk 'NR > 1 && $2 == "device" { found = 1 } END { exit found ? 0 : 1 }'; then
  echo "No Android device or emulator is connected. Start one before running Android performance benchmarks." >&2
  exit 1
fi

mkdir -p "${ROOT_DIR}/benchmarks/.results"
RESULT_DIR="$(mktemp -d "${ROOT_DIR}/benchmarks/.results/android-calibration-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"
cd "${ROOT_DIR}/examples/android"
./gradlew :react-native-text-engine:connectedReleaseAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.rntextengine.RNTextEnginePerformanceBenchmark \
  2>&1 | tee "${RESULT_DIR}/gradle.log"
