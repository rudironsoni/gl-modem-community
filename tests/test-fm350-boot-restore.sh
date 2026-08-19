#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
helper="$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-boot-restore"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-boot-restore.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/sys/2-1" "$tmp/bin" "$tmp/uci-store"
printf '%s\n' 0e8d >"$tmp/sys/2-1/idVendor"
printf '%s\n' 7127 >"$tmp/sys/2-1/idProduct"
: >"$tmp/uci.log"
: >"$tmp/ubus.log"
: >"$tmp/ifup.log"

cp "$repo_dir/tests/lib/mock-uci.sh" "$tmp/bin/uci"
cat >"$tmp/bin/ubus" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${UBUS_TEST_LOG:?}"
if [ "${UBUS_UP:-1}" = 1 ]; then
	printf '%s\n' '{"up": true, "ipv4-address":[{"address":"10.20.30.2"}]}'
else
	printf '%s\n' '{"up": false}'
fi
EOF
cat >"$tmp/bin/logger" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${RESTORE_LOG:?}"
EOF
cat >"$tmp/bin/at" <<'EOF'
#!/bin/sh
printf '%s\n' '+GTDUALSIM: 0' 'OK'
EOF
cat >"$tmp/bin/ifup" <<'EOF'
#!/bin/sh
printf 'ifup %s\n' "$*" >>"${IFUP_LOG:?}"
EOF
cat >"$tmp/bin/ifdown" <<'EOF'
#!/bin/sh
printf 'ifdown %s\n' "$*" >>"${IFUP_LOG:?}"
EOF
cat >"$tmp/bin/ensure" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${ENSURE_LOG:?}"
EOF
chmod +x "$tmp/bin/"*
: >"$tmp/restore.log"
: >"$tmp/ensure.log"

run_restore() {
	USB_DEVICES_ROOT="$tmp/sys" \
	UCI_BIN="$tmp/bin/uci" \
	UBUS_BIN="$tmp/bin/ubus" \
	LOGGER_BIN="$tmp/bin/logger" \
	AT_BIN="$tmp/bin/at" \
	ENSURE_OPTION_IDS="$tmp/bin/ensure" \
	IFUP_BIN="$tmp/bin/ifup" \
	IFDOWN_BIN="$tmp/bin/ifdown" \
	STATE_CONFIG=gl_modem_community \
	CONNECT_HOLD=1 \
	RESTORE_RETRIES=1 \
	RESTORE_RETRY_DELAY=0 \
	UCI_TEST_STORE="$tmp/uci-store" \
	UCI_TEST_LOG="$tmp/uci.log" \
	UBUS_TEST_LOG="$tmp/ubus.log" \
	IFUP_LOG="$tmp/ifup.log" \
	RESTORE_LOG="$tmp/restore.log" \
	ENSURE_LOG="$tmp/ensure.log" \
	UBUS_UP="${UBUS_UP:-1}" \
		"$helper" "$@"
}

uci_get() {
	UCI_TEST_STORE="$tmp/uci-store" UCI_TEST_LOG="$tmp/uci.log" \
		"$tmp/bin/uci" -q get "$1"
}

uci_set() {
	UCI_TEST_STORE="$tmp/uci-store" UCI_TEST_LOG="$tmp/uci.log" \
		"$tmp/bin/uci" set "$1"
}

# No record means restore is a no-op.
run_restore restore
test ! -s "$tmp/ifup.log"
grep -F 'no restore record' "$tmp/restore.log" >/dev/null

uci_set network.modem_2_1_s1=interface
uci_set network.modem_2_1_s1.apn=internet.telekom
uci_set network.modem_2_1_s1.auth=PAP

run_restore persist-disconnect 2-1
test "$(uci_get gl_modem_community.restore.connected)" = 0
test "$(uci_get gl_modem_community.restore.slot)" = 1
test "$(uci_get gl_modem_community.restore.apn)" = internet.telekom

: >"$tmp/ifup.log"
: >"$tmp/restore.log"
run_restore restore
grep -F 'ifdown modem_2_1_s1' "$tmp/ifup.log" >/dev/null
! grep -F 'ifup ' "$tmp/ifup.log" >/dev/null

UBUS_UP=1 run_restore persist-if-online
test "$(uci_get gl_modem_community.restore.connected)" = 1

: >"$tmp/ifup.log"
: >"$tmp/restore.log"
run_restore restore
grep -F 'ifup modem_2_1_s1' "$tmp/ifup.log" >/dev/null
grep -F -- '--wait-ready' "$tmp/ensure.log" >/dev/null
