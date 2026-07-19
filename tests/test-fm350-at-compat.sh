#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname "$0")/.." && pwd)
test_bin=$(mktemp "${TMPDIR:-/tmp}/fm350-at-compat.XXXXXX")
trap 'rm -f "$test_bin"' EXIT HUP INT TERM

cc -std=c11 -Wall -Wextra -Werror -DUNIT_TEST \
	"$repo_dir/tests/test-fm350-at-compat.c" \
	"$repo_dir/package/gl-modem-community/src/fm350_at_compat.c" \
	-o "$test_bin"
"$test_bin"
