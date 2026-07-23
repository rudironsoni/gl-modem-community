#!/bin/sh
set -eu

unset CDPATH

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
makefile="$repo_dir/package/gl-modem-community/Makefile"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-package-lifecycle.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/init.d"
: >"$tmp/lifecycle.log"

extract_hook() {
	hook=$1
	awk -v start="define Package/gl-modem-community/$hook" '
		$0 == start { capture = 1; next }
		capture && $0 == "endef" { exit }
		capture { print }
	' "$makefile" | sed 's/\$\$/\$/g' >"$tmp/$hook"
	test -s "$tmp/$hook"
	chmod +x "$tmp/$hook"
}

for service in gl_modem_community gl_cellular_manager; do
	cat >"$tmp/init.d/$service" <<'EOF'
#!/bin/sh
printf '%s %s\n' "${0##*/}" "$*" >>"${LIFECYCLE_TEST_LOG:?}"
EOF
	chmod +x "$tmp/init.d/$service"
done

extract_hook postinst
extract_hook prerm

IPKG_INSTROOT="$tmp/offline-root" \
GL_MODEM_COMMUNITY_INITD_ROOT="$tmp/init.d" \
LIFECYCLE_TEST_LOG="$tmp/lifecycle.log" \
	"$tmp/postinst"
test ! -s "$tmp/lifecycle.log"

IPKG_INSTROOT='' \
GL_MODEM_COMMUNITY_INITD_ROOT="$tmp/init.d" \
LIFECYCLE_TEST_LOG="$tmp/lifecycle.log" \
	"$tmp/postinst"
cat >"$tmp/expected-postinst" <<'EOF'
gl_modem_community enable
gl_modem_community restart
gl_cellular_manager restart
EOF
cmp "$tmp/expected-postinst" "$tmp/lifecycle.log"

: >"$tmp/lifecycle.log"
IPKG_INSTROOT='' \
GL_MODEM_COMMUNITY_INITD_ROOT="$tmp/init.d" \
LIFECYCLE_TEST_LOG="$tmp/lifecycle.log" \
	"$tmp/prerm"
cat >"$tmp/expected-prerm" <<'EOF'
gl_modem_community stop
gl_modem_community disable
gl_cellular_manager restart
EOF
cmp "$tmp/expected-prerm" "$tmp/lifecycle.log"
