#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if ! adb devices | awk 'NR > 1 && $2 == "device" { found = 1 } END { exit found ? 0 : 1 }'; then
  echo "No Android device or emulator is connected. Start one before running Android performance benchmarks." >&2
  exit 1
fi

cd "${ROOT_DIR}/examples/android"
./gradlew :react-native-text-engine:connectedReleaseAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.rntextengine.RNTextEnginePerformanceBenchmark
