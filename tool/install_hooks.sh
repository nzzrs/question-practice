#!/usr/bin/env sh
# Point Git at the tracked hooks so every push builds the debug APK locally.
set -eu

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

git config core.hooksPath tool/git-hooks
chmod +x tool/git-hooks/pre-push tool/build_debug_apk.sh
echo "Git hooks installed from tool/git-hooks."
echo "Every push now runs tool/build_debug_apk.sh first."
