#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
view="$repo_dir/package/gl-modem-community/files/www/views/gl-sdk4-ui-esim.common.js"
init="$repo_dir/package/gl-modem-community/files/etc/init.d/gl_modem_community"
nginx="$repo_dir/package/gl-modem-community/files/usr/share/gl-modem-community/nginx/gl-modem-community-esim.conf"
makefile="$repo_dir/package/gl-modem-community/Makefile"

grep -F 'render: function (h)' "$view" >/dev/null
! grep -F 'template:' "$view" >/dev/null
grep -F 'esim-management-wrapper' "$view" >/dev/null
grep -F '/sdk/v1' "$view" >/dev/null
grep -F 'location /sdk/v1' "$nginx" >/dev/null
grep -F 'gl-conf.d' "$init" >/dev/null
grep -F 'install_esim_nginx' "$init" >/dev/null
grep -F 'remove_esim_nginx' "$init" >/dev/null
grep -F 'port_3456_busy' "$init" >/dev/null
! grep -F '/etc/nginx/conf.d/gl-modem-community-esim.conf' "$makefile" >/dev/null
grep -F 'nginx/gl-modem-community-esim.conf' "$makefile" >/dev/null
grep -F 'esim-http/sdk/v1' "$makefile" >/dev/null

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-esim-http.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/runtime" "$tmp/nginx" "$tmp/http"
: >"$tmp/mounts"
printf '%s\n' '{"modems":[]}' >"$tmp/modem-list.json"
printf '%s\n' '#!/bin/sh' >"$tmp/modem_AT"
printf '%s\n' '#!/bin/sh' >"$tmp/modem_AT-wrapper"

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
cat >"$tmp/bin/merge-models" <<'EOF'
#!/bin/sh
printf '%s\n' '{"modems":[]}' >"$3"
EOF
cat >"$tmp/bin/network-repair" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$tmp/bin/runtime-stack" <<'EOF'
#!/bin/sh
printf '%s\n' modern
EOF
cat >"$tmp/bin/legacy-bus" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$tmp/bin/ensure-option-ids" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$tmp/bin/tethering-overlay" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${TETHER_LOG:?}"
EOF
cat >"$tmp/bin/boot-restore" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$tmp/bin/nginx" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${NGINX_LOG:?}"
EOF
cat >"$tmp/bin/uhttpd" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$tmp/bin/"* "$tmp/modem_AT" "$tmp/modem_AT-wrapper"
: >"$tmp/nginx.log"
: >"$tmp/tether.log"

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
ENSURE_OPTION_IDS="$tmp/bin/ensure-option-ids"
TETHERING_OVERLAY="$tmp/bin/tethering-overlay"
BOOT_RESTORE="$tmp/bin/boot-restore"
ESIM_HTTP_ROOT="$tmp/http"
ESIM_NGINX_SRC="$nginx"
ESIM_NGINX_DST="$tmp/nginx/gl-modem-community-esim.conf"
NGINX_BIN="$tmp/bin/nginx"
UHTTPD_BIN="$tmp/bin/uhttpd"
PROC_MOUNTS="$tmp/mounts"
PROC_NET_TCP="$tmp/empty-tcp"
CP_BIN="$tmp/bin/cp"
MOUNT_BIN="$tmp/bin/mount"
UMOUNT_BIN="$tmp/bin/umount"
LOGGER_BIN=true
TETHER_LOG="$tmp/tether.log"
NGINX_LOG="$tmp/nginx.log"
export RUNTIME_DIR STACK_FILE RUNTIME_STACK LEGACY_BUS STOCK_LIST MERGED_LIST
export MODEM_AT STOCK_MODEM_AT MODEM_AT_WRAPPER NETWORK_REPAIR MERGE_MODELS
export ENSURE_OPTION_IDS TETHERING_OVERLAY BOOT_RESTORE ESIM_HTTP_ROOT
export ESIM_NGINX_SRC ESIM_NGINX_DST NGINX_BIN UHTTPD_BIN PROC_MOUNTS PROC_NET_TCP
export CP_BIN MOUNT_BIN UMOUNT_BIN LOGGER_BIN TETHER_LOG NGINX_LOG

# shellcheck disable=SC1090
. "$init"

start_service
test -f "$ESIM_NGINX_DST"
grep -Fx -- '-t' "$tmp/nginx.log" >/dev/null
grep -Fx -- '-s reload' "$tmp/nginx.log" >/dev/null
grep -Fx -- 'start' "$tmp/tether.log" >/dev/null

stop_service
test ! -e "$ESIM_NGINX_DST"
grep -Fx -- 'stop' "$tmp/tether.log" >/dev/null
