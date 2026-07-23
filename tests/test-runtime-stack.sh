#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
helper="$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/runtime-stack"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-runtime-stack.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/modern" "$tmp/legacy"
printf '%s\n' '{}' >"$tmp/modern/modem-list.json"
printf '%s\n' '#!/bin/sh' >"$tmp/modern/gl_cellular_manager"
printf '%s\n' '# modem functions' >"$tmp/legacy/modem.sh"
printf '%s\n' '#!/bin/sh' >"$tmp/legacy/modem"
chmod +x "$tmp/modern/gl_cellular_manager" "$tmp/legacy/modem"

test "$(
	MODERN_LIST="$tmp/modern/modem-list.json" \
	MODERN_INIT="$tmp/modern/gl_cellular_manager" \
	LEGACY_FUNCTIONS="$tmp/missing" \
	LEGACY_INIT="$tmp/missing" \
	"$helper"
)" = modern

test "$(
	MODERN_LIST="$tmp/missing" \
	MODERN_INIT="$tmp/missing" \
	LEGACY_FUNCTIONS="$tmp/legacy/modem.sh" \
	LEGACY_INIT="$tmp/legacy/modem" \
	"$helper"
)" = legacy

if MODERN_LIST="$tmp/missing" MODERN_INIT="$tmp/missing" \
	LEGACY_FUNCTIONS="$tmp/missing" LEGACY_INIT="$tmp/missing" \
	"$helper" >"$tmp/unsupported" 2>/dev/null; then
	echo 'Unsupported stack unexpectedly passed detection' >&2
	exit 1
fi
test "$(cat "$tmp/unsupported")" = unsupported
