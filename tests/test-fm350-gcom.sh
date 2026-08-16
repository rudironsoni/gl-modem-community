#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
script="$repo_dir/package/gl-modem-community/files/etc/gcom/fm350-at.gcom"

if grep -F 'get 5 "" $s' "$script" >/dev/null; then
	echo 'fm350-at.gcom still uses the full 5s get timeout' >&2
	exit 1
fi
grep -F 'get 2 "^m" $s' "$script" >/dev/null
grep -F 'if $s = "OK" goto done' "$script" >/dev/null
grep -F 'if $s = "ERROR" goto done' "$script" >/dev/null
