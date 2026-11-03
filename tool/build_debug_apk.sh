#!/usr/bin/env sh
# Build a debug APK on this machine. Fails when the build fails.
set -eu

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is not on PATH; cannot build the debug APK." >&2
  exit 1
fi

echo "Building the debug APK..."
flutter build apk --debug

apk="build/app/outputs/flutter-apk/app-debug.apk"
if [ ! -f "$apk" ]; then
  echo "The debug APK was not produced at $apk." >&2
  exit 1
fi

echo "Debug APK ready: $repo_root/$apk"
