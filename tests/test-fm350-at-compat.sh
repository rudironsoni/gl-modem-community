#!/bin/sh

set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm350-at-compat.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

cc -std=c11 -Wall -Wextra -Werror -DUNIT_TEST \
	"$repo_dir/tests/test-fm350-at-compat.c" \
	"$repo_dir/package/gl-modem-community/src/fm350_at_compat.c" \
	-o "$tmp/test-fm350-at-compat"
"$tmp/test-fm350-at-compat"

if [ "$(uname -s)" = Linux ]; then
	cc -std=c11 -Wall -Wextra -Werror -fPIC -shared \
		"$repo_dir/package/gl-modem-community/src/fm350_at_compat.c" \
		-o "$tmp/fm350-at-compat.so"
	cc -std=c11 -Wall -Wextra -Werror \
		"$repo_dir/tests/test-fm350-at-runtime.c" \
		-o "$tmp/test-fm350-at-runtime"
	: >"$tmp/ttyUSB3"
	at_port=$(cd "$tmp" && pwd -P)/ttyUSB3
	GL_MODEM_FM350_AT_PORT="$at_port" \
		LD_PRELOAD="$tmp/fm350-at-compat.so" \
		"$tmp/test-fm350-at-runtime" "$at_port"
fi
