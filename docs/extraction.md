# Reproducible extraction

Conclusion: [CONFIRMED] The outer image is an OpenWrt sysupgrade tar containing `CONTROL`, a 5,305,224-byte ARM64 FIT kernel, and a 71,297,024-byte SquashFS 4 root filesystem compressed with XZ.

Evidence: `analysis/reports/outer-tar-list.txt`, `analysis/reports/fit-list.txt`, `analysis/reports/binwalk.txt`, and `scripts/extract-firmware.sh`.

Confidence: confirmed.

Alternative explanations: `binwalk` alone can misidentify nested data, so the extraction script independently uses `tar`, `dumpimage`, and `unsquashfs`.

How to verify dynamically: `make tools extract`; inspect `work/extracted/sysupgrade-glinet_gl-mt3000/` and `work/rootfs/`.

The root reports OpenWrt `25.12.5 r33051-f5dae5ece4`, target `mediatek/filogic`, package architecture `aarch64_cortex-a53`, kernel `6.12.94`, APK metadata, BusyBox/procd, and GL.iNet packages.

[BLOCKED] macOS cannot recreate the SquashFS character device `dev/console`. The script preserves the complete extraction tar in ignored storage and creates an inspection root without `/dev/*`. The failure and fallback are recorded in `analysis/reports/extraction-failures.md`. A Linux case-sensitive temporary filesystem is used so `xt_DSCP.ko` and `xt_dscp.ko` remain distinct.
