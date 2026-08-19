#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
menu="$repo_dir/package/gl-modem-community/files/usr/share/gl-modem-community/menu.d/esim.json"
view="$repo_dir/package/gl-modem-community/files/www/views/gl-sdk4-ui-esim.common.js"
init="$repo_dir/package/gl-modem-community/files/etc/init.d/gl_modem_community"

command -v jq >/dev/null 2>&1
jq -e '.view == "esim"' "$menu" >/dev/null
jq -e '.parent == "applications"' "$menu" >/dev/null
grep -F 'module.exports=' "$view" >/dev/null
grep -F 'render: function (h)' "$view" >/dev/null
! grep -F 'template:' "$view" >/dev/null
grep -F 'esim-management-wrapper' "$view" >/dev/null
grep -F 'esim-info-wrapper' "$view" >/dev/null
grep -F 'esim-profile-wrapper' "$view" >/dev/null
grep -F 'add-profile-btn' "$view" >/dev/null
grep -F 'POST' "$view" >/dev/null
grep -F '/sdk/v1' "$view" >/dev/null
grep -F 'install_legacy_esim_menu' "$init" >/dev/null
grep -F 'start_legacy()' "$init" >/dev/null
# Modern start must not install the extra 4.8.1 menu.
! awk '/^start_modern\(\)/,/^}$/' "$init" | grep -F install_legacy_esim_menu >/dev/null
