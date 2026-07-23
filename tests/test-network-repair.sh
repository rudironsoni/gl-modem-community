#!/bin/sh
set -eu

unset CDPATH

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-network-repair.XXXXXX")
watch_pid=

cleanup() {
	[ -z "$watch_pid" ] || kill "$watch_pid" 2>/dev/null || true
	rm -rf "$tmp"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$tmp/sys/2-1" "$tmp/bin" "$tmp/uci-store"
printf '%s\n' 0e8d >"$tmp/sys/2-1/idVendor"
printf '%s\n' 7127 >"$tmp/sys/2-1/idProduct"
: >"$tmp/uci.log"
: >"$tmp/ubus.log"

cp "$repo_dir/tests/lib/mock-uci.sh" "$tmp/bin/uci"
cat >"$tmp/bin/ubus" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${UBUS_TEST_LOG:?}"
EOF
cat >"$tmp/bin/logger" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$tmp/bin/gl_modem" <<'EOF'
#!/bin/sh
set -eu
[ "$*" = "-B 2-1 -U 1 AT AT+CGDCONT?" ]
printf '%s\n' '+CGDCONT: 5,"IP","orangeworld","0.0.0.0",0,0' 'OK'
EOF
chmod +x "$tmp/bin/"*

export USB_DEVICES_ROOT="$tmp/sys"
export UCI_BIN="$tmp/bin/uci"
export UBUS_BIN="$tmp/bin/ubus"
export LOGGER_BIN="$tmp/bin/logger"
export GL_MODEM_BIN="$tmp/bin/gl_modem"
export FLOCK_BIN=true
export NETWORK_STATE_CONFIG=gl_modem_community
export REPAIR_LOCK="$tmp/repair.lock"
export REPAIR_INTERVAL=0.05
export UCI_TEST_STORE="$tmp/uci-store"
export UCI_TEST_LOG="$tmp/uci.log"
export UBUS_TEST_LOG="$tmp/ubus.log"

"$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-network-repair" --watch &
watch_pid=$!

attempt=0
while [ "$attempt" -lt 40 ]; do
	[ -s "$tmp/ubus.log" ] && break
	attempt=$((attempt + 1))
	sleep 0.05
done
sleep 0.15
kill "$watch_pid" 2>/dev/null || true
wait "$watch_pid" 2>/dev/null || true
watch_pid=

uci_get() {
	"$tmp/bin/uci" -q get "$1"
}

test "$(uci_get network.modem_2_1_s1)" = interface
test "$(uci_get network.modem_2_1_s1.apn_use)" = 5
test "$(uci_get network.modem_2_1_s1.apn)" = orangeworld
test "$(uci_get network.modem_2_1_s1.ip_type)" = IP
test "$(uci_get network.modem_2_1_s1.proto)" = xmm
test "$(uci_get network.modem_2_1_s1.bus)" = 2-1
test "$(uci_get network.modem_2_1_s1.profile)" = 5
test "$(uci_get network.modem_2_1_s1.pdp)" = IP
test "$(grep -Fxc 'commit gl_modem_community' "$tmp/uci.log")" -eq 1
test "$(grep -Fxc 'commit network' "$tmp/uci.log")" -eq 1
test "$(grep -Fxc 'call network reload' "$tmp/ubus.log")" -eq 1
