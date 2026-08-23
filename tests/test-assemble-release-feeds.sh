#!/bin/sh
set -eu

unset CDPATH
REPO_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-feed-assembly.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

version=1.2.3
assets="$tmp/assets"
feed="$tmp/feed"
mkdir -p "$assets"

apk="gl-modem-community-${version}-r1.apk"
ipk24="gl-modem-community_${version}-r1_all.ipk"
ipk21="gl-modem-community_${version}-1_glinet-21.02_all.ipk"

printf 'apk\n' >"$assets/$apk"
printf 'index\n' >"$assets/packages.adb"
printf 'ipk24\n' >"$assets/$ipk24"
printf 'ipk21\n' >"$assets/$ipk21"

sh "$REPO_DIR/tools/assemble-release-feeds" "$version" "$assets" "$feed"

apk_dir="$feed/releases/25.12/packages/aarch64_cortex-a53/packages"
ipk24_dir="$feed/releases/24.10/packages/aarch64_cortex-a53/packages"
ipk21_dir="$feed/releases/21.02/packages/aarch64_cortex-a53/packages"
ipk21_neon_dir="$feed/releases/21.02/packages/aarch64_cortex-a53_neon-vfpv4/packages"

cmp "$assets/$apk" "$apk_dir/$apk"
cmp "$assets/packages.adb" "$apk_dir/packages.adb"
cmp "$assets/$ipk24" "$ipk24_dir/$ipk24"

# Every 21.02 architecture directory carries a byte-identical copy of the
# same architecture-independent package.
cmp "$assets/$ipk21" "$ipk21_dir/$ipk21"
cmp "$assets/$ipk21" "$ipk21_neon_dir/$ipk21"

hash24=$(sha256sum "$assets/$ipk24" | awk '{print $1}')
hash21=$(sha256sum "$assets/$ipk21" | awk '{print $1}')
grep -Fqx "Version: ${version}-r1" "$ipk24_dir/Packages"
grep -Fqx "SHA256sum: $hash24" "$ipk24_dir/Packages"
grep -Fqx 'Architecture: all' "$ipk24_dir/Packages"
grep -Fqx 'Depends: comgt, flock, jq, kmod-usb-acm, kmod-usb-serial-option, kmod-usb-net-rndis' \
	"$ipk24_dir/Packages"
for dir in "$ipk21_dir" "$ipk21_neon_dir"; do
	grep -Fqx "Version: ${version}-1" "$dir/Packages"
	grep -Fqx "SHA256sum: $hash21" "$dir/Packages"
	grep -Fqx 'Architecture: all' "$dir/Packages"
	grep -Fqx "Filename: $ipk21" "$dir/Packages"
done

# The deprecated legacy channel directories stay published for one release
# overlap with the same artifacts and indexes.
cmp "$assets/$apk" "$feed/25.12/$apk"
cmp "$assets/packages.adb" "$feed/25.12/packages.adb"
cmp "$assets/$ipk24" "$feed/24.10/$ipk24"
cmp "$assets/$ipk21" "$feed/21.02/$ipk21"
grep -Fqx "Version: ${version}-r1" "$feed/24.10/Packages"
grep -Fqx "Version: ${version}-1" "$feed/21.02/Packages"

for path in \
	"$feed/index.html" \
	"$feed/releases/index.html" \
	"$feed/releases/25.12/index.html" \
	"$apk_dir/index.html" \
	"$ipk24_dir/index.html" \
	"$ipk24_dir/Packages.gz" \
	"$ipk21_dir/index.html" \
	"$ipk21_dir/Packages.gz" \
	"$ipk21_neon_dir/index.html" \
	"$ipk21_neon_dir/Packages.gz" \
	"$feed/25.12/index.html" \
	"$feed/24.10/index.html" \
	"$feed/24.10/Packages.gz" \
	"$feed/21.02/index.html" \
	"$feed/21.02/Packages.gz"
do
	test -s "$path"
done

# Unsigned assembly must not publish signatures or keys.
if find "$feed" -name 'Packages.sig' -o -name '*.pub' | grep -q .; then
	echo 'Unsigned assembly must not emit signatures or keys' >&2
	exit 1
fi

# With a signing key every Packages index gets a detached usign signature and
# the public key is published per release under its lowercase key id.
mkdir -p "$tmp/bin"
cat >"$tmp/bin/usign" <<'EOF'
#!/bin/sh
case "$1" in
-F) printf 'AB12CD34EF567890\n' ;;
-S)
	msg=; out=
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-m) msg=$2; shift 2 ;;
		-x) out=$2; shift 2 ;;
		*) shift ;;
		esac
	done
	printf 'signed:%s\n' "$msg" >"$out"
	;;
*) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/usign"
printf 'sec\n' >"$tmp/usign.sec"
printf 'untrusted comment: test key\nRWRTESTKEY\n' >"$tmp/usign.pub"

USIGN_BIN="$tmp/bin/usign" \
USIGN_SEC_FILE="$tmp/usign.sec" \
USIGN_PUB_FILE="$tmp/usign.pub" \
	sh "$REPO_DIR/tools/assemble-release-feeds" "$version" "$assets" "$feed"

for dir in "$ipk24_dir" "$ipk21_dir" "$ipk21_neon_dir" "$feed/24.10" "$feed/21.02"; do
	test -s "$dir/Packages.sig"
done
cmp "$tmp/usign.pub" "$feed/releases/24.10/ab12cd34ef567890.pub"
cmp "$tmp/usign.pub" "$feed/releases/21.02/ab12cd34ef567890.pub"

# The APK release publishes no usign key; its trust root is the apk key.
if find "$feed/releases/25.12" -name '*.pub' | grep -q .; then
	echo 'The APK release must not publish a usign key' >&2
	exit 1
fi

# A signing request without the public key fails closed.
if USIGN_BIN="$tmp/bin/usign" \
	USIGN_SEC_FILE="$tmp/usign.sec" \
	USIGN_PUB_FILE="$tmp/missing.pub" \
	sh "$REPO_DIR/tools/assemble-release-feeds" "$version" "$assets" "$feed" 2>/dev/null; then
	echo 'Signing without a public key must fail' >&2
	exit 1
fi
