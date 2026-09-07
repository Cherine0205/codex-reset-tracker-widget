#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-run}"
case "$MODE" in run|--verify|--debug|--logs|--telemetry|--build) ;; *) echo "Usage: $0 [--build|--verify|--debug|--logs|--telemetry]"; exit 2;; esac
if [[ "$MODE" != "--build" ]]; then pkill -x CodexReset >/dev/null 2>&1 || true; fi
xcodebuild -project CodexReset.xcodeproj -scheme CodexReset -configuration Debug -derivedDataPath build build
APP="$PWD/build/Build/Products/Debug/CodexReset.app"
if [[ "$MODE" == "--build" ]]; then exit 0; fi
# WidgetKit can retain the previous extension executable across app rebuilds.
# Stop only this app's extension so the reload request launches the new binary.
pkill -x CodexResetWidget >/dev/null 2>&1 || true
if [[ "$MODE" == "--debug" ]]; then exec lldb -- "$APP/Contents/MacOS/CodexReset"; fi
open "$APP"
case "$MODE" in
  --verify) sleep 2; pgrep -x CodexReset >/dev/null; echo "CodexReset is running." ;;
  --logs|--telemetry) /usr/bin/log stream --info --style compact --predicate 'process == "CodexReset" OR process == "CodexResetWidget"' ;;
esac
