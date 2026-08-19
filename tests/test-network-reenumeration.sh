#!/bin/sh
set -eu

unset CDPATH

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-network-reenumeration.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/bin" "$tmp/sys/1-1" "$tmp/uci-store"
printf '%s\n' 0e8d >"$tmp/sys/1-1/idVendor"
printf '%s\n' 7127 >"$tmp/sys/1-1/idProduct"
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
case "$*" in
	'-B 1-1 -U 1 AT AT+CGDCONT?'|'-B 2-1 -U 1 AT AT+CGDCONT?') ;;
	*) exit 1 ;;
esac
printf '%s\n' '+CGDCONT: 5,"IP","orangeworld","0.0.0.0",0,0' 'OK'
EOF
chmod +x "$tmp/bin/"*

run_repair() {
	USB_DEVICES_ROOT="$tmp/sys" \
	UCI_BIN="$tmp/bin/uci" \
	UBUS_BIN="$tmp/bin/ubus" \
	LOGGER_BIN="$tmp/bin/logger" \
	GL_MODEM_BIN="$tmp/bin/gl_modem" \
	UCI_TEST_STORE="$tmp/uci-store" \
	UCI_TEST_LOG="$tmp/uci.log" \
	UBUS_TEST_LOG="$tmp/ubus.log" \
	NETWORK_STATE_CONFIG=gl_modem_community \
	REPAIR_LOCK="$tmp/repair.lock" \
	FLOCK_BIN=true \
		"$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-network-repair" "$@"
}

uci_get() {
	UCI_TEST_STORE="$tmp/uci-store" UCI_TEST_LOG="$tmp/uci.log" \
		"$tmp/bin/uci" -q get "$1"
}

uci_set() {
	UCI_TEST_STORE="$tmp/uci-store" UCI_TEST_LOG="$tmp/uci.log" \
		"$tmp/bin/uci" set "$1"
}

run_repair
test "$(uci_get network.modem_1_1_s1.bus)" = 1-1
test "$(uci_get gl_modem_community.network_modem_1_1_s1.created)" = 1
test "$(uci_get network.modem_1_1_s2.proto)" = xmm

rm -rf "$tmp/sys/1-1"
mkdir -p "$tmp/sys/2-1"
printf '%s\n' 0e8d >"$tmp/sys/2-1/idVendor"
printf '%s\n' 7127 >"$tmp/sys/2-1/idProduct"

run_repair

test "$(uci_get network.modem_2_1_s1.bus)" = 2-1
test "$(uci_get gl_modem_community.network_modem_2_1_s1.created)" = 1
test "$(uci_get network.modem_2_1_s2.proto)" = xmm
if uci_get network.modem_1_1_s1 >/dev/null 2>&1; then
	echo "plugin-created stale modem_1_1_s1 survived FM350 re-enumeration" >&2
	exit 1
fi
if uci_get network.modem_1_1_s2 >/dev/null 2>&1; then
	echo "plugin-created stale modem_1_1_s2 survived FM350 re-enumeration" >&2
	exit 1
fi
if uci_get gl_modem_community.network_modem_1_1_s1 >/dev/null 2>&1; then
	echo "stale modem_1_1_s1 ownership survived FM350 re-enumeration" >&2
	exit 1
fi

: >"$tmp/uci.log"
run_repair || true
test ! -s "$tmp/uci.log"

run_repair --restore
rm -rf "$tmp/sys/2-1"
mkdir -p "$tmp/sys/1-1"
printf '%s\n' 0e8d >"$tmp/sys/1-1/idVendor"
printf '%s\n' 7127 >"$tmp/sys/1-1/idProduct"
uci_set network.modem_1_1_s1=interface
uci_set network.modem_1_1_s1.proto=qmi
uci_set network.modem_1_1_s1.bus=stock-bus
uci_set network.modem_1_1_s1.profile=9
uci_set network.modem_1_1_s1.ip_type=IPV4V6

run_repair
test "$(uci_get network.modem_1_1_s1.proto)" = xmm
test "$(uci_get network.modem_1_1_s1.bus)" = 1-1
test "$(uci_get network.modem_1_1_s1.profile)" = 5
test "$(uci_get gl_modem_community.network_modem_1_1_s1.created)" = 0

uci_set network.modem_1_1_s1.proto=custom
rm -rf "$tmp/sys/1-1"
mkdir -p "$tmp/sys/2-1"
printf '%s\n' 0e8d >"$tmp/sys/2-1/idVendor"
printf '%s\n' 7127 >"$tmp/sys/2-1/idProduct"
: >"$tmp/uci.log"

run_repair

test "$(uci_get network.modem_1_1_s1)" = interface
test "$(uci_get network.modem_1_1_s1.proto)" = custom
test "$(uci_get network.modem_1_1_s1.bus)" = stock-bus
test "$(uci_get network.modem_1_1_s1.profile)" = 9
test "$(uci_get network.modem_1_1_s1.ip_type)" = IPV4V6
if uci_get network.modem_1_1_s1.pdp >/dev/null 2>&1; then
	echo "plugin-created pdp survived stale stock-section reconciliation" >&2
	exit 1
fi
if uci_get gl_modem_community.network_modem_1_1_s1 >/dev/null 2>&1; then
	echo "stale stock-section ownership survived FM350 re-enumeration" >&2
	exit 1
fi
test "$(grep -Fxc 'commit gl_modem_community' "$tmp/uci.log")" -eq 1
test "$(grep -Fxc 'commit network' "$tmp/uci.log")" -eq 1
