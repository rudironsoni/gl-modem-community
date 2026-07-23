#!/bin/sh
set -eu

unset CDPATH

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-network-ownership.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

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
[ "${GL_MODEM_SHOULD_FAIL:-0}" != 1 ] || exit 1
[ "$*" = "-B 2-1 -U 1 AT AT+CGDCONT?" ]
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
	GL_MODEM_SHOULD_FAIL="${GL_MODEM_SHOULD_FAIL:-0}" \
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

GL_MODEM_SHOULD_FAIL=1
export GL_MODEM_SHOULD_FAIL
run_repair || true
if uci_get network.modem_2_1_s1 >/dev/null 2>&1; then
	echo "network section was created without readable modem context" >&2
	exit 1
fi
if uci_get gl_modem_community.network_modem_2_1_s1 >/dev/null 2>&1; then
	echo "ownership record was created without readable modem context" >&2
	exit 1
fi

GL_MODEM_SHOULD_FAIL=0
export GL_MODEM_SHOULD_FAIL
run_repair

test "$(uci_get network.modem_2_1_s1)" = interface
test "$(uci_get network.modem_2_1_s1.proto)" = xmm
test "$(uci_get gl_modem_community.network_modem_2_1_s1)" = network_state
test "$(uci_get gl_modem_community.network_modem_2_1_s1.created)" = 1

run_repair --restore

if uci_get network.modem_2_1_s1 >/dev/null 2>&1; then
	echo "plugin-created network section remained after restore" >&2
	exit 1
fi
if uci_get gl_modem_community.network_modem_2_1_s1 >/dev/null 2>&1; then
	echo "ownership record remained after restore" >&2
	exit 1
fi

uci_set network.modem_2_1_s1=interface
uci_set network.modem_2_1_s1.proto=qmi
uci_set network.modem_2_1_s1.bus=stock-bus
uci_set network.modem_2_1_s1.profile=9
uci_set network.modem_2_1_s1.ip_type=IPV4V6

run_repair
test "$(uci_get network.modem_2_1_s1.proto)" = xmm
test "$(uci_get network.modem_2_1_s1.bus)" = 2-1
test "$(uci_get network.modem_2_1_s1.profile)" = 5
test "$(uci_get network.modem_2_1_s1.pdp)" = IPV4V6

# A user or stock service changed proto after the plugin applied it. Restore
# releases ownership instead of overwriting that newer value.
uci_set network.modem_2_1_s1.proto=custom
run_repair --restore

test "$(uci_get network.modem_2_1_s1)" = interface
test "$(uci_get network.modem_2_1_s1.proto)" = custom
test "$(uci_get network.modem_2_1_s1.bus)" = stock-bus
test "$(uci_get network.modem_2_1_s1.profile)" = 9
if uci_get network.modem_2_1_s1.pdp >/dev/null 2>&1; then
	echo "plugin-created pdp option remained after restore" >&2
	exit 1
fi
if uci_get gl_modem_community.network_modem_2_1_s1 >/dev/null 2>&1; then
	echo "ownership record remained after releasing user-modified state" >&2
	exit 1
fi
