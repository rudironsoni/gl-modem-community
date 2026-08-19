#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
wrapper="$repo_dir/package/gl-modem-community/files/usr/share/gl-modem-community/rpc-wrappers/tethering.lua"
overlay="$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/tethering-overlay"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-tethering.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/sys/2-1" "$tmp/bin" "$tmp/rpc" "$tmp/runtime"
printf '%s\n' 0e8d >"$tmp/sys/2-1/idVendor"
printf '%s\n' 7127 >"$tmp/sys/2-1/idProduct"

cat >"$tmp/bin/fm350-port" <<'EOF'
#!/bin/sh
[ "$1" = data ]
printf '%s\n' eth2
EOF
chmod +x "$tmp/bin/fm350-port"

cat >"$tmp/rpc/tethering.stock.lua" <<'EOF'
return {
	get_status = function()
		return {
			devices = {
				{ device = "eth2", name = "fm350-rndis" },
				{ device = "eth1", name = "phone" },
			},
		}
	end,
	set_config = function(args)
		return { ok = true, proto = args and args.proto or "dhcp" }
	end,
	connect = function()
		return { connected = true }
	end,
	disconnect = function()
		return { connected = false }
	end,
}
EOF

lua_bin=
if command -v lua5.1 >/dev/null 2>&1; then
	lua_bin=lua5.1
elif command -v lua >/dev/null 2>&1; then
	lua_bin=lua
fi
[ -n "$lua_bin" ] || {
	echo 'lua5.1 is required for tethering overlay tests' >&2
	exit 1
}

if command -v luac5.1 >/dev/null 2>&1; then
	luac5.1 -p "$wrapper"
	luac5.1 -p "$tmp/rpc/tethering.stock.lua"
fi

cat >"$tmp/run.lua" <<EOF
local wrapper = assert(dofile("$wrapper"))
local status = wrapper.get_status()
assert(#status.devices == 1, "FM350 RNDIS must be filtered")
assert(status.devices[1].device == "eth1")
assert(wrapper.set_config({ proto = "static" }).proto == "static")
assert(wrapper.connect().connected == true)
assert(wrapper.disconnect().connected == false)
EOF

TETHERING_STOCK="$tmp/rpc/tethering.stock.lua" \
FM350_PORT_BIN="$tmp/bin/fm350-port" \
USB_DEVICES_ROOT="$tmp/sys" \
	"$lua_bin" "$tmp/run.lua"

: >"$tmp/mounts"
cat >"$tmp/bin/cp" <<'EOF'
#!/bin/sh
exec /bin/cp "$@"
EOF
cat >"$tmp/bin/mount" <<'EOF'
#!/bin/sh
printf 'none %s none rw 0 0\n' "$4" >>"${PROC_MOUNTS:?}"
EOF
cat >"$tmp/bin/umount" <<'EOF'
#!/bin/sh
awk -v target="$1" '$2 != target' "${PROC_MOUNTS:?}" >"${PROC_MOUNTS:?}.next"
mv "${PROC_MOUNTS:?}.next" "${PROC_MOUNTS:?}"
EOF
cat >"$tmp/bin/logger" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$tmp/bin/"*
printf '%s\n' 'stock-bytecode' >"$tmp/rpc/tethering"

STOCK_TETHERING="$tmp/rpc/tethering" \
RUNTIME_DIR="$tmp/runtime" \
STOCK_COPY="$tmp/runtime/tethering.stock" \
WRAPPER="$wrapper" \
PROC_MOUNTS="$tmp/mounts" \
CP_BIN="$tmp/bin/cp" \
MOUNT_BIN="$tmp/bin/mount" \
UMOUNT_BIN="$tmp/bin/umount" \
LOGGER_BIN="$tmp/bin/logger" \
	"$overlay" start
grep -F " $tmp/rpc/tethering " "$tmp/mounts" >/dev/null
test -f "$tmp/runtime/tethering.stock"
test "$(cat "$tmp/runtime/tethering.stock")" = stock-bytecode

STOCK_TETHERING="$tmp/rpc/tethering" \
RUNTIME_DIR="$tmp/runtime" \
STOCK_COPY="$tmp/runtime/tethering.stock" \
WRAPPER="$wrapper" \
PROC_MOUNTS="$tmp/mounts" \
CP_BIN="$tmp/bin/cp" \
MOUNT_BIN="$tmp/bin/mount" \
UMOUNT_BIN="$tmp/bin/umount" \
LOGGER_BIN="$tmp/bin/logger" \
	"$overlay" stop
test ! -s "$tmp/mounts"
test ! -e "$tmp/runtime/tethering.stock"
