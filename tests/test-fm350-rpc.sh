#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
modem="$repo_dir/package/gl-modem-community/files/usr/lib/oui-httpd/rpc/modem"
driver="$repo_dir/package/gl-modem-community/files/usr/share/gl-modem-community/rpc-drivers/fm350.lua"

grep -F '"get_info", "get_status"' "$modem" >/dev/null
grep -F 'find_fm350_bus' "$modem" >/dev/null
grep -F 'get_info = get_info' "$driver" >/dev/null
grep -F 'get_status = get_status' "$driver" >/dev/null
grep -F 'set_connect = set_connect' "$driver" >/dev/null
grep -F 'get_sim_config = get_sim_config' "$driver" >/dev/null
grep -F 'modems =' "$driver" >/dev/null

if command -v luac5.1 >/dev/null 2>&1; then
	luac5.1 -p "$modem"
	luac5.1 -p "$driver"
fi
