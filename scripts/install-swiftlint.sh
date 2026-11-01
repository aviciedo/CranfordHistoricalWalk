#!/usr/bin/env bash
set -euo pipefail

# Official 0.65.1 release asset digests. Tool files stay in the ignored .build folder.
readonly swiftlint_version="0.65.1"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
tools_parent="$repo_root/.build/tools"
tool_dir="$tools_parent/swiftlint"

case "$(uname -s):$(uname -m)" in
  Darwin:*)
    artifact="portable_swiftlint.zip"
    expected_digest="c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0"
    ;;
  Linux:x86_64)
    artifact="swiftlint_linux_amd64.zip"
    expected_digest="caeed6f4a679c35539ffaf124f6c4ab4a8416917f7d8796279dc52b74026059d"
    ;;
  Linux:aarch64|Linux:arm64)
    artifact="swiftlint_linux_arm64.zip"
    expected_digest="9ffa52f478e6d8eb485d37d14715ffac90abc81c58f3370d598bf75be05605f8"
    ;;
  *)
    printf 'Unsupported SwiftLint host: %s %s\n' "$(uname -s)" "$(uname -m)" >&2
    exit 2
    ;;
esac

digest_of() {
  local result
  if command -v sha256sum >/dev/null 2>&1; then
    result="$(sha256sum "$1")"
  else
    result="$(shasum -a 256 "$1")"
  fi
  printf '%s\n' "${result%% *}"
}

mkdir -p "$tool_dir"
archive="$tools_parent/swiftlint-$swiftlint_version-$artifact"
if [[ ! -f "$archive" ]] || [[ "$(digest_of "$archive")" != "$expected_digest" ]]; then
  curl --fail --location --silent --show-error --retry 3 \
    "https://github.com/realm/SwiftLint/releases/download/$swiftlint_version/$artifact" \
    --output "$archive"
fi
if [[ "$(digest_of "$archive")" != "$expected_digest" ]]; then
  printf 'SwiftLint archive checksum mismatch; refusing to install.\n' >&2
  exit 1
fi

unzip -q -o "$archive" -d "$tool_dir"
chmod +x "$tool_dir/swiftlint"
installed_version="$("$tool_dir/swiftlint" version)"
if [[ "$installed_version" != "$swiftlint_version" ]]; then
  printf 'Expected SwiftLint %s, found %s\n' "$swiftlint_version" "$installed_version" >&2
  exit 1
fi
printf 'SwiftLint %s installed in %s\n' "$installed_version" "$tool_dir"
