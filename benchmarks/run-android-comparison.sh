#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NODE_BINARY="${NODE_BINARY:-$(command -v node)}"
if [[ -z "${ANDROID_SERIAL:-}" ]]; then
  DEVICES=($(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }'))
  if [[ ${#DEVICES[@]} -ne 1 ]]; then
    echo "Connect one Android device, or set ANDROID_SERIAL to select one." >&2
    exit 1
  fi
  export ANDROID_SERIAL="${DEVICES[0]}"
fi
export NODE_BINARY
ABI="$(adb shell getprop ro.product.cpu.abi | tr -d '\r')"
case "${ABI}" in
  arm64-v8a|armeabi-v7a|x86|x86_64) ;;
  *) echo "Unsupported Android ABI: ${ABI}" >&2; exit 1 ;;
esac

cd "${ROOT_DIR}"
mkdir -p benchmarks/.results
RESULT_DIR="$(mktemp -d "${ROOT_DIR}/benchmarks/.results/android-comparison-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"
"${NODE_BINARY}" benchmarks/report.mjs capture "${RESULT_DIR}" android
(
  cd examples/android
  ./gradlew :react-native-text-engine:assembleReleaseAndroidTest \
    -PrnteNativeTests=true "-PreactNativeArchitectures=${ABI}"
) 2>&1 | tee "${RESULT_DIR}/build.log"
"${NODE_BINARY}" benchmarks/report.mjs artifact "${RESULT_DIR}" \
  android/build/outputs/apk/androidTest/release/react-native-text-engine-release-androidTest.apk
adb install -r -t "${RESULT_DIR}/benchmark.apk" | tee "${RESULT_DIR}/install.log"
adb shell cmd package compile -m speed -f com.rntextengine.test | tee "${RESULT_DIR}/compilation.log"
if ! grep -qx 'Success' "${RESULT_DIR}/compilation.log"; then
  echo "Android ahead-of-time compilation failed." >&2
  exit 1
fi

for run in 1 2 3; do
  MODES=(prepared default)
  if [[ ${run} -eq 2 ]]; then MODES=(default prepared); fi
  for mode in "${MODES[@]}"; do
    PREPARED=false
    if [[ "${mode}" == prepared ]]; then PREPARED=true; fi
    IMPLEMENTATIONS=(rn textview)
    if [[ ${run} -eq 2 ]]; then IMPLEMENTATIONS=(textview rn); fi
    for implementation in "${IMPLEMENTATIONS[@]}"; do
      adb shell am force-stop com.rntextengine.test
      adb shell am instrument -w -r \
        -e class com.rntextengine.RNTextEngineTextComparisonBenchmark#compareTextLayout \
        -e rnteComparison true -e rnteRun "${run}" -e rntePreparedTextLayout "${PREPARED}" \
        -e rnteImplementation "${implementation}" \
        com.rntextengine.test/androidx.test.runner.AndroidJUnitRunner \
        2>&1 | tee "${RESULT_DIR}/run-${run}-${mode}-${implementation}.log"
      grep -qx 'OK (1 test)' "${RESULT_DIR}/run-${run}-${mode}-${implementation}.log"
      grep -qx 'INSTRUMENTATION_CODE: -1' "${RESULT_DIR}/run-${run}-${mode}-${implementation}.log"
    done
  done
done
"${NODE_BINARY}" benchmarks/report.mjs write "${RESULT_DIR}"
