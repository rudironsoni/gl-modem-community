#!/bin/sh

set -eu

unset CDPATH

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
handler="$repo_dir/package/gl-modem-community/files/lib/netifd/proto/xmm.sh"

test "$(grep -c '^[[:space:]]*no_proto_task=1$' "$handler")" -eq 1
grep -F 'GL_MODEM_BIN=${GL_MODEM_BIN:-gl_modem}' "$handler" >/dev/null
grep -F '"$GL_MODEM_BIN" -B "$bus" -U 1 AT "$command"' "$handler" >/dev/null
test "$(grep -F -c '[ "$profile" -eq 5 ] && profile=1' "$handler")" -eq 0

if grep -E 'gcom|DEVPORT=' "$handler" >/dev/null; then
	echo "xmm handler must not open the stock-owned AT port directly" >&2
	exit 1
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-xmm-proto.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
sed -n '/^run_stock_at()/,/^}/p' "$handler" >"$tmp/run-stock-at.sh"
cat >"$tmp/gl_modem" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >"${GL_MODEM_TEST_LOG:?}"
printf '%s\n' 'AT+CGPADDR=5' '+CGPADDR: 5,"10.21.90.110",""' 'OK'
EOF
chmod +x "$tmp/gl_modem"

. "$tmp/run-stock-at.sh"
GL_MODEM_BIN="$tmp/gl_modem"
GL_MODEM_TEST_LOG="$tmp/gl-modem.log"
export GL_MODEM_TEST_LOG
output=$(run_stock_at 2-1 address 'AT+CGPADDR=5')
[ "$(cat "$tmp/gl-modem.log")" = '-B 2-1 -U 1 AT AT+CGPADDR=5' ]
printf '%s\n' "$output" | grep -F '+CGPADDR: 5,"10.21.90.110",""' >/dev/null

teardown=$(sed -n '/^proto_xmm_teardown()/,/^}/p' "$handler")
if printf '%s\n' "$teardown" | grep -q 'proto_send_update'; then
	echo "xmm teardown must not notify netifd after teardown has started" >&2
	exit 1
fi
