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

cat >"$tmp/bin/runtime-stack" <<'EOF'
#!/bin/sh
printf '%s\n' "${STACK_TEST_VALUE:-modern}"
EOF

cat >"$tmp/bin/legacy-bus" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${LEGACY_BUS_TEST_LOG:?}"
EOF

cat >"$tmp/bin/ensure-option-ids" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${ENSURE_OPTION_IDS_TEST_LOG:?}"
EOF

cat >"$tmp/bin/vos5g-qmi" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${VOS5G_QMI_TEST_LOG:?}"
exit "${VOS5G_QMI_TEST_STATUS:-0}"
EOF

cat >"$tmp/bin/vos5g-band-monitor" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${VOS5G_BAND_MONITOR_TEST_LOG:?}"
EOF

chmod +x "$tmp/bin/"*

config_load() { :; }
config_get_bool() { eval "$1=1"; }
procd_open_instance() { :; }
procd_set_param() { :; }
procd_close_instance() { :; }

RUNTIME_DIR="$tmp/runtime"
STACK_FILE="$tmp/runtime/stack"
RUNTIME_STACK="$tmp/bin/runtime-stack"
LEGACY_BUS="$tmp/bin/legacy-bus"
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
LEGACY_BUS_TEST_LOG="$tmp/legacy-bus.log"
MERGE_SHOULD_FAIL=1
export RUNTIME_DIR STACK_FILE RUNTIME_STACK LEGACY_BUS
export STOCK_LIST MERGED_LIST MODEM_AT STOCK_MODEM_AT
export MODEM_AT_WRAPPER NETWORK_REPAIR MERGE_MODELS PROC_MOUNTS
export CP_BIN MOUNT_BIN UMOUNT_BIN MOUNT_TEST_LOG MERGE_TEST_LOG REPAIR_TEST_LOG
export LEGACY_BUS_TEST_LOG
ENSURE_OPTION_IDS="$tmp/bin/ensure-option-ids"
ENSURE_OPTION_IDS_TEST_LOG="$tmp/ensure-option-ids.log"
export ENSURE_OPTION_IDS ENSURE_OPTION_IDS_TEST_LOG
VOS5G_QMI="$tmp/bin/vos5g-qmi"
VOS5G_QMI_TEST_LOG="$tmp/vos5g-qmi.log"
export VOS5G_QMI VOS5G_QMI_TEST_LOG
VOS5G_BAND_MONITOR="$tmp/bin/vos5g-band-monitor"
VOS5G_BAND_MONITOR_TEST_LOG="$tmp/vos5g-band-monitor.log"
export VOS5G_BAND_MONITOR VOS5G_BAND_MONITOR_TEST_LOG
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
: >"$tmp/vos5g-qmi.log"
: >"$tmp/vos5g-band-monitor.log"
MOUNT_FAIL_TARGET=
export MOUNT_FAIL_TARGET

start_service
stop_service

test ! -s "$tmp/mounts"
grep -Fx -- '--restore' "$tmp/repair.log" >/dev/null
grep -Fx "umount $STOCK_LIST" "$tmp/mount.log" >/dev/null
grep -Fx "umount $MODEM_AT" "$tmp/mount.log" >/dev/null
cat >"$tmp/expected-vos5g-qmi" <<'EOF'
prepare
EOF
cmp "$tmp/expected-vos5g-qmi" "$tmp/vos5g-qmi.log"
grep -Fx refresh "$tmp/vos5g-band-monitor.log" >/dev/null

# VOS display preparation is optional and must not take down the stock modem
# service or start the watcher when the helper reports a failure.
: >"$tmp/vos5g-qmi.log"
: >"$tmp/vos5g-band-monitor.log"
VOS5G_QMI_TEST_STATUS=1
export VOS5G_QMI_TEST_STATUS
start_service
test ! -s "$tmp/vos5g-band-monitor.log"
stop_service
unset VOS5G_QMI_TEST_STATUS

# A service restart must preserve VOS QMI ownership.  Restoring ECM here
# starts QCMAP and races the immediately following prepare operation.
: >"$tmp/vos5g-qmi.log"
start_service
stop_service
start_service
cat >"$tmp/expected-vos5g-qmi" <<'EOF'
prepare
prepare
EOF
cmp "$tmp/expected-vos5g-qmi" "$tmp/vos5g-qmi.log"
