#!/usr/bin/env bash
# Run on a Mac with Xcode and XcodeGen. No API keys or signing team are required.
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo "An iOS build requires macOS with Xcode. This machine cannot verify it." >&2
  exit 1
fi

for tool in xcodebuild xcrun xcodegen; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool. See README.md for Mac setup." >&2
    exit 1
  fi
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
xcrun --sdk iphonesimulator --show-sdk-version

run_dir="$repo_root/.build/ios-verification/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$run_dir"
echo "Build results: $run_dir"
if [[ -e "$repo_root/.git" ]] && git rev-parse --verify HEAD >/dev/null 2>&1; then
  git rev-parse HEAD > "$run_dir/commit.txt"
  git status --short > "$run_dir/working-tree.txt"
else
  echo "Source archive: Git revision metadata is unavailable." > "$run_dir/commit.txt"
fi

# The generated project and build results are gitignored.
xcodegen generate --spec project.yml

xcodebuild \
  -project CranfordHistoricalAR.xcodeproj \
  -scheme CranfordHistoricalAR -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$run_dir/device" \
  -resultBundlePath "$run_dir/device.xcresult" \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tee "$run_dir/device.log"

xcodebuild \
  -project CranfordHistoricalAR.xcodeproj \
  -scheme CranfordHistoricalAR -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$run_dir/simulator" \
  -resultBundlePath "$run_dir/simulator.xcresult" \
  CODE_SIGNING_ALLOWED=NO build-for-testing 2>&1 | tee "$run_dir/simulator.log"

echo "Device build and simulator test compilation succeeded."
echo "Tests were not executed. Signing and installation on an iPhone still need verification."
