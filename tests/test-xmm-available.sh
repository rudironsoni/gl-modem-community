#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
helper="$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-network-repair"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-xmm-avail.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/sys/2-1" "$tmp/bin" "$tmp/uci-store"
printf '%s\n' 0e8d >"$tmp/sys/2-1/idVendor"
printf '%s\n' 7127 >"$tmp/sys/2-1/idProduct"
printf '%s\n' xmm >"$tmp/uci-store/network.modem_2_1_s1.proto"

cp "$repo_dir/tests/lib/mock-uci.sh" "$tmp/bin/uci"
cat >"$tmp/bin/ubus" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${UBUS_TEST_LOG:?}"
EOF
cat >"$tmp/bin/logger" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$tmp/bin/port" <<'EOF'
#!/bin/sh
if [ "${PORT_READY:-1}" = 1 ]; then
	exit 0
fi
exit 1
EOF
chmod +x "$tmp/bin/"*

export USB_DEVICES_ROOT="$tmp/sys"
export UCI_BIN="$tmp/bin/uci"
export UBUS_BIN="$tmp/bin/ubus"
export LOGGER_BIN="$tmp/bin/logger"
export FM350_PORT_BIN="$tmp/bin/port"
export UCI_TEST_STORE="$tmp/uci-store"
export UCI_TEST_LOG="$tmp/uci.log"
export UBUS_TEST_LOG="$tmp/ubus.log"
: >"$tmp/ubus.log"

PORT_READY=1 "$helper" --available
grep -F 'call network.interface notify_proto' "$tmp/ubus.log" >/dev/null

: >"$tmp/ubus.log"
PORT_READY=0 "$helper" --available
if grep -F 'notify_proto' "$tmp/ubus.log" >/dev/null; then
	echo 'availability restored without a ready port' >&2
	exit 1
fi
