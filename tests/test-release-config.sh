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

test "$(grep -Ec 'uses: [^@]+@[0-9a-f]{40} # v[0-9]' "$WORKFLOW")" -eq 5
if grep -Eq 'uses: [^@]+@v[0-9]' "$WORKFLOW"; then
	echo "release workflow contains a floating action tag" >&2
	exit 1
fi
