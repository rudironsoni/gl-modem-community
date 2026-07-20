#!/bin/sh
set -eu

unset CDPATH
REPO_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd)
CONFIG="$REPO_DIR/release-please-config.json"
MANIFEST="$REPO_DIR/.release-please-manifest.json"
PACKAGE_MAKEFILE="$REPO_DIR/package/gl-modem-community/Makefile"
WORKFLOW="$REPO_DIR/.github/workflows/release.yml"

jq -e '
  .["release-type"] == "simple" and
  .["include-component-in-tag"] == false and
  .["include-v-in-tag"] == true and
  .packages["."]["package-name"] == "gl-modem-community" and
  .packages["."]["extra-files"] == [
    {"type": "generic", "path": "package/gl-modem-community/Makefile"}
  ] and
  ([.["changelog-sections"][].type] | sort) ==
    (["build", "chore", "ci", "docs", "feat", "fix", "perf", "refactor", "revert", "style", "test"] | sort) and
  all(.["changelog-sections"][]; .hidden == false)
' "$CONFIG" >/dev/null

jq -e 'type == "object" and length == 0' "$MANIFEST" >/dev/null

test "$(grep -c '^# x-release-please-start-version$' "$PACKAGE_MAKEFILE")" -eq 1
test "$(grep -c '^# x-release-please-end$' "$PACKAGE_MAKEFILE")" -eq 1
test "$(sed -n 's/^PKG_VERSION:=//p' "$PACKAGE_MAKEFILE")" = "0.1.2"

test "$(grep -Ec 'uses: [^@]+@[0-9a-f]{40} # v[0-9]' "$WORKFLOW")" -eq 7
test "$(grep -Fc 'uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7.0.0' "$WORKFLOW")" -eq 3
grep -Fq 'uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0' "$WORKFLOW"
grep -Fq 'uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1' "$WORKFLOW"
grep -Fq 'uses: googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0' "$WORKFLOW"
grep -Fq 'uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c # v8.0.1' "$WORKFLOW"
if grep -Eq 'uses: [^@]+@v[0-9]' "$WORKFLOW"; then
	echo "release workflow contains a floating action tag" >&2
	exit 1
fi
