#!/bin/sh
set -eu

unset CDPATH

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-service-lifecycle.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/bin" "$tmp/runtime"
: >"$tmp/mounts"
: >"$tmp/mount.log"
: >"$tmp/merge.log"
: >"$tmp/repair.log"
printf '%s\n' '{"modems":[]}' >"$tmp/modem-list.json"
printf '%s\n' '#!/bin/sh' >"$tmp/modem_AT"
printf '%s\n' '#!/bin/sh' >"$tmp/modem_AT-wrapper"

cat >"$tmp/bin/cp" <<'EOF'
#!/bin/sh
exec /bin/cp "$@"
EOF

cat >"$tmp/bin/mount" <<'EOF'
#!/bin/sh
set -eu
printf 'mount %s\n' "$*" >>"${MOUNT_TEST_LOG:?}"
target=$4
[ "$target" != "${MOUNT_FAIL_TARGET:-}" ] || exit 1
printf 'none %s none rw 0 0\n' "$target" >>"${PROC_MOUNTS:?}"
EOF

cat >"$tmp/bin/umount" <<'EOF'
#!/bin/sh
set -eu
printf 'umount %s\n' "$*" >>"${MOUNT_TEST_LOG:?}"
target=$1
awk -v target="$target" '$2 != target' "${PROC_MOUNTS:?}" >"${PROC_MOUNTS:?}.next"
mv "${PROC_MOUNTS:?}.next" "${PROC_MOUNTS:?}"
EOF

cat >"$tmp/bin/merge-models" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >>"${MERGE_TEST_LOG:?}"
[ "${MERGE_SHOULD_FAIL:-0}" != 1 ] || exit 1
printf '%s\n' '{"modems":[]}' >"$3"
EOF

cat >"$tmp/bin/network-repair" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${REPAIR_TEST_LOG:?}"
EOF

chmod +x "$tmp/bin/"*

config_load() { :; }
config_get_bool() { eval "$1=1"; }
procd_open_instance() { :; }
procd_set_param() { :; }
procd_close_instance() { :; }

RUNTIME_DIR="$tmp/runtime"
STOCK_LIST="$tmp/modem-list.json"
MERGED_LIST="$tmp/runtime/modem-list.json"
MODEM_AT="$tmp/modem_AT"
STOCK_MODEM_AT="$tmp/runtime/modem_AT.stock"
MODEM_AT_WRAPPER="$tmp/modem_AT-wrapper"
NETWORK_REPAIR="$tmp/bin/network-repair"
MERGE_MODELS="$tmp/bin/merge-models"
PROC_MOUNTS="$tmp/mounts"
CP_BIN="$tmp/bin/cp"
MOUNT_BIN="$tmp/bin/mount"
UMOUNT_BIN="$tmp/bin/umount"
MOUNT_TEST_LOG="$tmp/mount.log"
MERGE_TEST_LOG="$tmp/merge.log"
REPAIR_TEST_LOG="$tmp/repair.log"
MERGE_SHOULD_FAIL=1
export RUNTIME_DIR STOCK_LIST MERGED_LIST MODEM_AT STOCK_MODEM_AT
export MODEM_AT_WRAPPER NETWORK_REPAIR MERGE_MODELS PROC_MOUNTS
export CP_BIN MOUNT_BIN UMOUNT_BIN MOUNT_TEST_LOG MERGE_TEST_LOG REPAIR_TEST_LOG
export MERGE_SHOULD_FAIL

# shellcheck disable=SC1090
. "$repo_dir/package/gl-modem-community/files/etc/init.d/gl_modem_community"

if start_service; then
	echo "start_service unexpectedly succeeded when model merge failed" >&2
	exit 1
fi

test ! -s "$tmp/mounts"
test ! -s "$tmp/mount.log"
test -s "$tmp/merge.log"
test ! -s "$tmp/repair.log"

: >"$tmp/mounts"
: >"$tmp/mount.log"
: >"$tmp/merge.log"
MERGE_SHOULD_FAIL=0
MOUNT_FAIL_TARGET=$STOCK_LIST
export MERGE_SHOULD_FAIL MOUNT_FAIL_TARGET

if start_service; then
	echo "start_service unexpectedly succeeded when model bind mount failed" >&2
	exit 1
fi

test ! -s "$tmp/mounts"
grep -Fx "mount -o bind $MODEM_AT_WRAPPER $MODEM_AT" "$tmp/mount.log" >/dev/null
grep -Fx "mount -o bind $MERGED_LIST $STOCK_LIST" "$tmp/mount.log" >/dev/null
grep -Fx "umount $MODEM_AT" "$tmp/mount.log" >/dev/null

: >"$tmp/mounts"
: >"$tmp/mount.log"
: >"$tmp/merge.log"
: >"$tmp/repair.log"
MOUNT_FAIL_TARGET=
export MOUNT_FAIL_TARGET

start_service
stop_service

test ! -s "$tmp/mounts"
grep -Fx -- '--restore' "$tmp/repair.log" >/dev/null
grep -Fx "umount $STOCK_LIST" "$tmp/mount.log" >/dev/null
grep -Fx "umount $MODEM_AT" "$tmp/mount.log" >/dev/null
