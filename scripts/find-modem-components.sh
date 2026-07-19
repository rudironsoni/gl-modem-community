#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"

ROOT="$EXTRACT_DIR/rootfs"
test -d "$ROOT"
mkdir -p "$ANALYSIS_DIR/manifests" "$ANALYSIS_DIR/reports"
PATTERN='modem|cellular|sim|imei|iccid|signal|band|servingcell|qmi|mbim|ncm|rndis|wwan|ttyUSB|ttyACM|cdc-wdm|gl_modem|gl-modem|Fibocom|Quectel|Sierra|Telit|ZTE|FM350|RM500|RM520'

find "$ROOT" -print | grep -Ei "$PATTERN" | sed "s#^$ROOT##" | LC_ALL=C sort > "$ANALYSIS_DIR/manifests/modem-related-paths.txt"
in_container sh -c 'pattern=$1; grep -RInaE --binary-files=without-match "$pattern" /repo/extracted/rootfs 2>/dev/null | sed "s#/repo/extracted/rootfs##" | LC_ALL=C sort > /repo/analysis/manifests/modem-text-hits.txt || true' sh "$PATTERN"

for dir in etc/init.d etc/rc.d etc/config usr/libexec usr/share/rpcd usr/lib/rpcd usr/lib/lua usr/lib/ucode usr/share/ucode www etc/hotplug.d usr/lib/hotplug.d lib/netifd lib/functions; do
    if test -e "$ROOT/$dir"; then
        find "$ROOT/$dir" -print | sed "s#^$ROOT##"
    fi
done | LC_ALL=C sort -u > "$ANALYSIS_DIR/manifests/service-and-interface-paths.txt"
