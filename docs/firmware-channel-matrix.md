# GL-MT3000 firmware channel matrix

This repository supports the current head of each GL.iNet GL-MT3000 firmware
channel. A channel update is unverified until
`config/firmware-channels.json`, the package builds, and the hardware
acceptance matrix have been refreshed.

The release metadata comes from GL.iNet's official APIs:

- `https://firmware-api.gl-inet.com/cloud-api/model/info?model=mt3000`
- `https://firmware-api.gl-inet.com/cloud-api/model/info?model=mt3000-open`

The OpenWrt release, target, kernel, package manager, and cellular-stack
generation were read from the pinned firmware images. Run
`make verify-firmware-channels` to download the images, verify their hashes,
and reproduce those checks.

| Channel | GL.iNet release | Embedded OpenWrt | Kernel | Package manager | Cellular stack | Package target |
| --- | --- | --- | --- | --- | --- | --- |
| stable | 4.8.1 | `21.02-SNAPSHOT`, `mediatek/mt7981` | `5.4.211` | OPKG | Legacy `modem` stack | `make package-glinet21` |
| beta | 4.9.0 beta6 | `21.02-SNAPSHOT`, `mediatek/mt7981` | `5.4.211` | OPKG | Modern `gl_cellular_manager` | `make package-glinet21` |
| openwrt24 | 4.9.0 op24 beta1 | `24.10.4 r28959-29397011cc`, `mediatek/filogic` | `6.6.110` | OPKG | Modern `gl_cellular_manager` | `make package-opkg` |
| openwrt25 | 4.9.1 op25 beta3 | `25.12.5 r33051-f5dae5ece4`, `mediatek/filogic` | `6.12.94` | APK | Modern `gl_cellular_manager` | `make package` |

## Pinned firmware evidence

| Channel | Artifact | SHA-256 |
| --- | --- | --- |
| stable | [`mt3000-4.8.1-0819-1755615825.tar`](https://fw.gl-inet.com/firmware/mt3000/release/mt3000-4.8.1-0819-1755615825.tar) | `ee038ee0f399c1454cc660dd47811b44697f5304e0f61af145c7dca6817d0e5c` |
| beta | [`mt3000-4.9.0_beta6-1047-0703-1783066682.tar`](https://fw.gl-inet.com/firmware/mt3000/testing/mt3000-4.9.0_beta6-1047-0703-1783066682.tar) | `03a9ed1d99ca9728eca6042f06c56cea5df299cd1e168b5f9fb51663bda24a32` |
| openwrt24 | [`mt3000-op-4.9.0-op24_beta1-1015-0528-1779955715.bin`](https://fw.gl-inet.com/firmware/mt3000-open/testing/mt3000-op-4.9.0-op24_beta1-1015-0528-1779955715.bin) | `320902010e976ce82843b121569913c4b1b2727df3a6ffbd0b2390a828c1e750` |
| openwrt25 | [`mt3000-op-4.9.1-op25_beta3-1035-0721-1784638698.bin`](https://fw.gl-inet.com/firmware/mt3000-open/testing/mt3000-op-4.9.1-op25_beta3-1035-0721-1784638698.bin) | `5c15e3a5492c5ad5cb6015b200d18799b0d942ab7915e00eeeb60709495ab353` |

## Build boundary

The stable and beta package uses the OpenWrt 21.02.7 MediaTek `mt7622` SDK as
a userspace ABI surrogate. It matches the firmware's GCC 8.4, musl 1.1.24,
and `aarch64_cortex-a53` ABI. It is not the exact GL.iNet MT7981 build tree,
so this package must remain userspace-only. Adding a kernel module requires an
exact GL.iNet SDK or source tree.

The openwrt24 and openwrt25 packages use the exact upstream OpenWrt 24.10.4
and 25.12.5 Filogic SDK releases embedded by their current channel heads.

## Hardware status

Build and static compatibility checks do not prove a data session. Stable,
beta, and openwrt24 remain `[UNVERIFIED]` on hardware. Openwrt25 has verified
FM350-GL detection and UI visibility, but the complete data-session and
rollback matrix remains incomplete.

Do not mark a channel supported until installation, detection, web and mobile
API configuration, connect/disconnect, SIM and signal reporting, addressing,
route, DNS, sustained transfer, USB re-enumeration, reboot, removal rollback,
and a stock-modem regression all pass on that exact firmware head.
