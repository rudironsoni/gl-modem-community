#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
helper="$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/fm350-fcc-unlock"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-fcc.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/sys/2-1" "$tmp/bin" "$tmp/run"
printf '%s\n' 0e8d >"$tmp/sys/2-1/idVendor"
printf '%s\n' 7127 >"$tmp/sys/2-1/idProduct"
printf '%s\n' 1 >"$tmp/sys/2-1/authorized"

cat >"$tmp/bin/at" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${AT_TEST_LOG:?}"
case "$2" in
*GTFCCEFFSTATUS*)
	printf '%s\n' "${FCC_STATUS_REPLY:?}"
	;;
*GTFCCLOCKMODE=0*)
	printf '%s\n' OK
	;;
esac
EOF
cat >"$tmp/bin/logger" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$tmp/bin/sleep" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$tmp/bin/"*

export USB_DEVICES_ROOT="$tmp/sys"
export LEGACY_AT_BIN="$tmp/bin/at"
export LOGGER_BIN="$tmp/bin/logger"
export STAMP_DIR="$tmp/run"
export SLEEP_BIN="$tmp/bin/sleep"
export AT_TEST_LOG="$tmp/at.log"

: >"$tmp/at.log"
FCC_STATUS_REPLY='+GTFCCEFFSTATUS: 0,1
OK'
export FCC_STATUS_REPLY
"$helper"
if grep -F 'AT+GTFCCLOCKMODE=0' "$tmp/at.log" >/dev/null; then
	echo 'FCC unlock ran on an unlocked modem' >&2
	exit 1
fi
test "$(cat "$tmp/sys/2-1/authorized")" = 1

: >"$tmp/at.log"
FCC_STATUS_REPLY='+GTFCCEFFSTATUS: 2,0
OK'
export FCC_STATUS_REPLY
"$helper"
grep -F 'AT+GTFCCLOCKMODE=0' "$tmp/at.log" >/dev/null
test "$(cat "$tmp/sys/2-1/authorized")" = 1
test -e "$tmp/run/fcc-2-1"

: >"$tmp/at.log"
"$helper"
if grep -F 'AT+GTFCCLOCKMODE=0' "$tmp/at.log" >/dev/null; then
	echo 'FCC unlock looped after stamp' >&2
	exit 1
fi
