#!/bin/sh

set -eu

unset CDPATH

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
handler="$repo_dir/package/gl-modem-community/files/lib/netifd/proto/xmm.sh"

test "$(grep -c '^[[:space:]]*no_proto_task=1$' "$handler")" -eq 1
test "$(grep -F -c '[ "$profile" -eq 5 ] && profile=1' "$handler")" -eq 2

teardown=$(sed -n '/^proto_xmm_teardown()/,/^}/p' "$handler")
if printf '%s\n' "$teardown" | grep -q 'proto_send_update'; then
	echo "xmm teardown must not notify netifd after teardown has started" >&2
	exit 1
fi
