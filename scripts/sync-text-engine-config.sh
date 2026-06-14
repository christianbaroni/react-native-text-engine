#!/bin/sh
set -e

NODE_BINARY="${NODE_BINARY:-node}"

if [ -n "${PROJECT_DIR:-}" ]; then
  IOS_ROOT="${PROJECT_DIR}"
elif [ -n "${PODS_ROOT:-}" ]; then
  IOS_ROOT="$(cd "${PODS_ROOT}/.." && pwd)"
else
  IOS_ROOT="$(pwd)"
fi

APP_ROOT="$(cd "${IOS_ROOT}/.." && pwd)"

if [ -d "${APP_ROOT}/node_modules/react-native-text-engine" ]; then
  PACKAGE_ROOT="$(cd "${APP_ROOT}/node_modules/react-native-text-engine" && pwd)"
elif [ -n "${PODS_TARGET_SRCROOT:-}" ]; then
  PACKAGE_ROOT="${PODS_TARGET_SRCROOT}"
else
  echo "RNTextEngine: unable to resolve the installed package root for config sync." >&2
  exit 1
fi

"${NODE_BINARY}" "${PACKAGE_ROOT}/scripts/sync-text-engine-config.mjs" \
  --app-root "${APP_ROOT}" \
  --package-root "${PACKAGE_ROOT}"
