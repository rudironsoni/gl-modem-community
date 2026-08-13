#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
wrapper=$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/modem_AT-wrapper
tmp=$(mktemp -d "${TMPDIR:-/tmp}/vos5g-modem-at-wrapper.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/sys/devices/2-1" "$tmp/sys/devices/2-1:1.2/ttyUSB7" \
	"$tmp/sys/devices/3-1" "$tmp/sys/devices/4-1" "$tmp/bin"
printf '%s\n' 05c6 >"$tmp/sys/devices/2-1/idVendor"
printf '%s\n' 9064 >"$tmp/sys/devices/2-1/idProduct"
printf '%s\n' 1234 >"$tmp/sys/devices/3-1/idVendor"
printf '%s\n' 5678 >"$tmp/sys/devices/3-1/idProduct"
printf '%s\n' 0e8d >"$tmp/sys/devices/4-1/idVendor"
printf '%s\n' 7126 >"$tmp/sys/devices/4-1/idProduct"

cat >"$tmp/stock" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >"$TEST_ARGS"
printf '%s\n' "${GL_MODEM_VOS5G_AT_PORT:-}" >"$TEST_PORT"
printf '%s\n' "${GL_MODEM_FM350_AT_PORT:-}" >"$TEST_FM350_PORT"
printf '%s\n' "${LD_PRELOAD:-}" >"$TEST_PRELOAD"
EOF
cat >"$tmp/bin/logger" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$tmp/stock" "$tmp/bin/logger"

PATH=$tmp/bin:$PATH SYS_USB=$tmp/sys STOCK_MODEM_AT=$tmp/stock \
	VOS5G_COMPAT=$tmp/vos5g-at-compat.so TEST_ARGS=$tmp/args \
	TEST_PORT=$tmp/port TEST_FM350_PORT=$tmp/fm350-port \
	TEST_PRELOAD=$tmp/preload \
	"$wrapper" -B 2-1 -P -O2
test "$(cat "$tmp/args")" = '-B 2-1 -P /dev/ttyUSB7 -O2'
test "$(cat "$tmp/port")" = /dev/ttyUSB7
test "$(cat "$tmp/preload")" = "$tmp/vos5g-at-compat.so"

# The pre-existing FM350 branch must keep the original arguments, port
# environment and compatibility preload while the VOS branch sits beside it.
PATH=$tmp/bin:$PATH SYS_USB=$tmp/sys STOCK_MODEM_AT=$tmp/stock \
	FM350_COMPAT=$tmp/fm350-at-compat.so TEST_ARGS=$tmp/args \
	TEST_PORT=$tmp/port TEST_FM350_PORT=$tmp/fm350-port \
	TEST_PRELOAD=$tmp/preload \
	"$wrapper" -B 4-1 -P /dev/ttyUSB4 -O2
test "$(cat "$tmp/args")" = '-B 4-1 -P /dev/ttyUSB4 -O2'
test "$(cat "$tmp/fm350-port")" = /dev/ttyUSB4
test "$(cat "$tmp/preload")" = "$tmp/fm350-at-compat.so"

PATH=$tmp/bin:$PATH SYS_USB=$tmp/sys STOCK_MODEM_AT=$tmp/stock \
	TEST_ARGS=$tmp/args TEST_PORT=$tmp/port TEST_PRELOAD=$tmp/preload \
	TEST_FM350_PORT=$tmp/fm350-port \
	"$wrapper" -B 3-1 -P /dev/ttyUSB9 -O9
test "$(cat "$tmp/args")" = '-B 3-1 -P /dev/ttyUSB9 -O9'
test -z "$(cat "$tmp/port")"
test -z "$(cat "$tmp/preload")"
