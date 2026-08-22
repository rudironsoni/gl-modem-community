#!/bin/sh
set -eu

unset CDPATH
repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
root_makefile=$repo_dir/Makefile
package_makefile=$repo_dir/package/gl-modem-community/Makefile
common_makefile=$repo_dir/Makefile.common
ci=$repo_dir/.github/workflows/ci.yml
release=$repo_dir/.github/workflows/release.yml
readme=$repo_dir/README.md
evidence=$repo_dir/docs/gl-be3600-vos5g.md

grep -Fq 'package-be3600: SDK_NAME = openwrt-sdk-23.05.5-ipq807x-generic_gcc-12.3.0_musl.Linux-x86_64.tar.xz' "$root_makefile"
grep -Fq 'package-be3600: SDK_SHA256 = 57c8a1d5586f1548ebe360d71a6dd9deec7833f5cb3e5b93d5a618c6da6e9399' "$root_makefile"
grep -Fq 'package-be3600: PACKAGE_MAKE_ARGS = BE3600_BUILD=1' "$root_makefile"
grep -Fq 'package package-opkg package-be3600:' "$root_makefile"

for makefile in "$package_makefile" "$common_makefile"; do
	grep -Fq 'ifneq ($(BE3600_BUILD),)' "$makefile"
	grep -Fq 'PKGARCH:=aarch64_cortex-a53_neon-vfpv4' "$makefile"
done

grep -Fq 'kind: ipk-be3600' "$ci"
grep -Fq 'target: package-be3600' "$ci"
grep -Fq 'gl-be3600-4.9_aarch64_cortex-a53_neon-vfpv4.ipk' "$release"
grep -Fq 'feed/23.05-be3600' "$release"
grep -Fq 'feed/23.05-be3600' "$readme"
grep -Fq 'Dedicated target uses the pinned OpenWrt 23.05.5 IPQ807x userspace ABI surrogate' "$readme"
! grep -Fq 'CI verification pending' "$readme"

grep -Fq 'GL.iNet version | `4.9.0 release2 build 1036`' "$evidence"
grep -Fq 'Firmware date | `2026-06-23 21:10:38`' "$evidence"
grep -Fq 'USB ID | `05c6:9064`' "$evidence"
grep -Fq 'FM350-GL USB IDs `0e8d:7126` and `0e8d:7127`' "$evidence"
grep -Fq 'remain **not tested** on GL-BE3600' "$evidence"
