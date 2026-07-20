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

mkdir -p "$tmp/sys/2-1" "$tmp/bin"
printf '%s\n' 0e8d >"$tmp/sys/2-1/idVendor"
printf '%s\n' 7127 >"$tmp/sys/2-1/idProduct"
printf '%s\n' absent >"$tmp/section-state"
printf '%s\n' none >"$tmp/proto-state"
: >"$tmp/bus-state"
: >"$tmp/profile-state"
: >"$tmp/pdp-state"

cat >"$tmp/bin/uci" <<'EOF'
#!/bin/sh
set -eu
log=${UCI_TEST_LOG:?}
section_state=${UCI_SECTION_STATE:?}
proto_state=${UCI_PROTO_STATE:?}
bus_state=${UCI_BUS_STATE:?}
profile_state=${UCI_PROFILE_STATE:?}
pdp_state=${UCI_PDP_STATE:?}

case "$*" in
	'-q get network.modem_2_1_s1')
		[ "$(cat "$section_state")" = present ]
		;;
	'-q get network.modem_2_1_s1.proto')
		cat "$proto_state"
		;;
	'-q get network.modem_2_1_s1.ip_type')
		printf '%s\n' IP
		;;
	'-q get network.modem_2_1_s1.bus')
		[ -s "$bus_state" ] && cat "$bus_state"
		;;
	'-q get network.modem_2_1_s1.profile')
		[ -s "$profile_state" ] && cat "$profile_state"
		;;
	'-q get network.modem_2_1_s1.pdp')
		[ -s "$pdp_state" ] && cat "$pdp_state"
		;;
	'set network.modem_2_1_s1.proto=xmm')
		printf '%s\n' xmm >"$proto_state"
		printf '%s\n' "$*" >>"$log"
		;;
	'set network.modem_2_1_s1.bus=2-1')
		printf '%s\n' 2-1 >"$bus_state"
		printf '%s\n' "$*" >>"$log"
		;;
	'set network.modem_2_1_s1.profile=5')
		printf '%s\n' 5 >"$profile_state"
		printf '%s\n' "$*" >>"$log"
		;;
	'set network.modem_2_1_s1.pdp=IP')
		printf '%s\n' IP >"$pdp_state"
		printf '%s\n' "$*" >>"$log"
		;;
	set*|commit*)
		printf '%s\n' "$*" >>"$log"
		;;
	*)
		exit 1
		;;
esac
EOF

cat >"$tmp/bin/ubus" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >>"${UBUS_TEST_LOG:?}"
EOF

cat >"$tmp/bin/logger" <<'EOF'
#!/bin/sh
exit 0
EOF

chmod +x "$tmp/bin/uci" "$tmp/bin/ubus" "$tmp/bin/logger"
export USB_DEVICES_ROOT="$tmp/sys"
export UCI_BIN="$tmp/bin/uci"
export UBUS_BIN="$tmp/bin/ubus"
export LOGGER_BIN="$tmp/bin/logger"
export UCI_TEST_LOG="$tmp/uci.log"
export UBUS_TEST_LOG="$tmp/ubus.log"
export UCI_SECTION_STATE="$tmp/section-state"
export UCI_PROTO_STATE="$tmp/proto-state"
export UCI_BUS_STATE="$tmp/bus-state"
export UCI_PROFILE_STATE="$tmp/profile-state"
export UCI_PDP_STATE="$tmp/pdp-state"
export REPAIR_INTERVAL=0.05

"$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-network-repair" --watch &
watch_pid=$!

sleep 0.1
printf '%s\n' present >"$tmp/section-state"

attempt=0
while [ "$attempt" -lt 40 ]; do
	[ -s "$tmp/ubus.log" ] && break
	attempt=$((attempt + 1))
	sleep 0.05
done

grep -Fx 'set network.modem_2_1_s1.proto=xmm' "$tmp/uci.log" >/dev/null
grep -Fx 'set network.modem_2_1_s1.bus=2-1' "$tmp/uci.log" >/dev/null
grep -Fx 'set network.modem_2_1_s1.profile=5' "$tmp/uci.log" >/dev/null
grep -Fx 'set network.modem_2_1_s1.pdp=IP' "$tmp/uci.log" >/dev/null
[ "$(grep -Fxc 'commit network' "$tmp/uci.log")" -eq 1 ]
[ "$(grep -Fxc 'call network reload' "$tmp/ubus.log")" -eq 1 ]
