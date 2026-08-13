#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/vos5g-at-compat.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

cc -std=c11 -Wall -Wextra -Werror -DUNIT_TEST \
	"$repo_dir/tests/test-vos5g-at-compat.c" \
	"$repo_dir/package/gl-modem-community/src/vos5g_at_compat.c" \
	-o "$tmp/test-vos5g-at-compat"
"$tmp/test-vos5g-at-compat"

if [ "$(uname -s)" = Linux ]; then
	cc -std=c11 -Wall -Wextra -Werror -fPIC -shared \
		"$repo_dir/package/gl-modem-community/src/vos5g_at_compat.c" \
		-o "$tmp/vos5g-at-compat.so"
	cc -std=c11 -Wall -Wextra -Werror \
		"$repo_dir/tests/test-vos5g-at-runtime.c" \
		-o "$tmp/test-vos5g-at-runtime"
	: >"$tmp/ttyUSB2"
	at_port=$(cd "$tmp" && pwd -P)/ttyUSB2
	GL_MODEM_VOS5G_AT_PORT="$at_port" \
		LD_PRELOAD="$tmp/vos5g-at-compat.so" \
		"$tmp/test-vos5g-at-runtime" "$at_port"
fi
