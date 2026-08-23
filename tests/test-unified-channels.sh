#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
root_makefile=$repo_dir/Makefile
package_makefile=$repo_dir/package/gl-modem-community/Makefile
common_makefile=$repo_dir/Makefile.common
feed_assembler=$repo_dir/tools/assemble-release-feeds
feed_indexer=$repo_dir/tools/generate-feed-index
wrapper=$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/modem_AT-wrapper
vos5g_qmi=$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/vos5g-qmi
vos5g_monitor=$repo_dir/package/gl-modem-community/files/usr/libexec/gl-modem-community/vos5g-band-monitor
ci=$repo_dir/.github/workflows/ci.yml
release=$repo_dir/.github/workflows/release.yml
readme=$repo_dir/README.md

# One architecture-independent package per OS version; no per-router build
# variants remain anywhere.
for makefile in "$package_makefile" "$common_makefile"; do
	grep -Fq 'PKGARCH:=all' "$makefile"
	! grep -Fq 'BE3600_BUILD' "$makefile"
	! grep -Fq 'neon-vfpv4' "$makefile"
done
! grep -Fq 'package-be3600' "$root_makefile"
! grep -Fq 'BE3600_BUILD' "$root_makefile"
grep -Fq 'PACKAGE_ASSET = gl-modem-community_$(PACKAGE_VERSION)-r$(PACKAGE_RELEASE)_all.ipk' "$root_makefile"
grep -Fq 'PACKAGE_ASSET = gl-modem-community_$(PACKAGE_VERSION)-$(PACKAGE_RELEASE)_glinet-21.02_all.ipk' "$root_makefile"

# VOS 5G tooling is a runtime check, not a hard dependency.
! grep -Fq 'adb' "$package_makefile"
! grep -Fq 'uqmi' "$package_makefile"
grep -Fq 'vos5g_tools_ready' "$vos5g_qmi"
grep -Fq 'vos5g_tools_ready || return 0' "$vos5g_qmi"
grep -Fq 'opkg install adb uqmi' "$vos5g_qmi"
grep -Fq 'vos5g_tools_ready' "$vos5g_monitor"
grep -Fq 'vos5g_tools_ready || return 1' "$vos5g_monitor"

# The aarch64 compat shims are preloaded only where they can run.
grep -Fq 'preload_supported()' "$wrapper"
grep -Fq '[ "$machine" = aarch64 ] && [ -f "$1" ]' "$wrapper"
grep -Fq 'machine=${GL_MODEM_MACHINE:-$(uname -m)}' "$wrapper"

# CI builds exactly the three OS-version channels.
grep -Fq 'kind: apk' "$ci"
grep -Fq 'kind: ipk' "$ci"
grep -Fq 'kind: ipk-glinet21' "$ci"
! grep -Fq 'ipk-be3600' "$ci"
! grep -Fq '23.05' "$ci"
grep -Fq '_all.ipk' "$ci"

# The published feed has no router-specific channel left. The README may
# mention the retired channel in the migration note but must not configure it
# as a feed source.
! grep -Fq '23.05-be3600' "$release"
! grep -Fq 'be3600' "$release"
! grep -Eq 'src/gz.*23\.05-be3600' "$readme"
! grep -Fq '23.05-be3600' "$feed_assembler"
! grep -Fq '23.05-be3600' "$feed_indexer"
! grep -Fq '23.05-be3600' "$root_makefile"

# The feed assembler publishes the standard layout with the same single
# package in every architecture directory of a release.
grep -Fq "ARCHS_2102='aarch64_cortex-a53 aarch64_cortex-a53_neon-vfpv4'" "$feed_assembler"
grep -Fq "ARCHS_2410='aarch64_cortex-a53'" "$feed_assembler"
grep -Fq "ARCHS_2512='aarch64_cortex-a53'" "$feed_assembler"
grep -Fq 'releases/21.02' "$feed_assembler"
grep -Fq 'releases/24.10' "$feed_assembler"
grep -Fq 'releases/25.12' "$feed_assembler"
grep -Fq "printf 'Architecture: all" "$feed_assembler"
