#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-network-repair.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/sys/2-1" "$tmp/bin"
printf '%s\n' 0e8d >"$tmp/sys/2-1/idVendor"
printf '%s\n' 7127 >"$tmp/sys/2-1/idProduct"

cat >"$tmp/bin/uci" <<'EOF'
#!/bin/sh
set -eu
log=${UCI_TEST_LOG:?}
case "$*" in
  '-q get network.modem_2_1_s1') exit 0 ;;
  '-q get network.modem_2_1_s1.proto') printf '%s\n' none ;;
  '-q get network.modem_2_1_s1.ip_type') printf '%s\n' IP ;;
  '-q get network.modem_2_1_s1.bus'|'-q get network.modem_2_1_s1.profile'|'-q get network.modem_2_1_s1.pdp') exit 1 ;;
  set*|commit*) printf '%s\n' "$*" >>"$log" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/uci"

export USB_DEVICES_ROOT="$tmp/sys"
export UCI_BIN="$tmp/bin/uci"
export UCI_TEST_LOG="$tmp/uci.log"
logger() { :; }

. "$repo_dir/package/gl-modem-community/files/etc/init.d/gl_modem_community"
repair_fm350_network

grep -Fx 'set network.modem_2_1_s1.proto=xmm' "$tmp/uci.log" >/dev/null
grep -Fx 'set network.modem_2_1_s1.bus=2-1' "$tmp/uci.log" >/dev/null
grep -Fx 'set network.modem_2_1_s1.profile=5' "$tmp/uci.log" >/dev/null
grep -Fx 'set network.modem_2_1_s1.pdp=IP' "$tmp/uci.log" >/dev/null
test "$(grep -c '^commit network$' "$tmp/uci.log")" -eq 1
