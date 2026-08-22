# GL-BE3600 and VOS 5G hardware evidence

## Scope and claim status

This document records the observed VOS 5G (`05c6:9064`) integration on one
GL.iNet GL-BE3600 (Slate 7). The VOS data session is **verified** on this exact
router and reported firmware version. The router is not listed as generally
**tested** because a stock-supported modem and the existing FM350-GL community
modem have not been exercised on it.

The device reported:

| Field | Observed value |
| --- | --- |
| Router | GL.iNet GL-BE3600 (Slate 7) |
| Board | `qcom,ipq5332-ap-mi04.1-c2` |
| GL.iNet version | `4.9.0 release2 build 1036` |
| Firmware date | `2026-06-23 21:10:38` |
| Embedded OpenWrt | `23.05-SNAPSHOT`, `ipq53xx/generic` |
| Kernel | `5.4.213` |
| Package manager | `opkg` |
| Package architecture | `aarch64_cortex-a53_neon-vfpv4` |
| Cellular stack | modern `gl_cellular_manager` |
| Modem | VOS 5G / SG500M2-X |
| USB ID | `05c6:9064` |
| Tested package | `0.2.14-1+vos5gqmi20260813.21` local hardware build |

The exact installed identifiers came from `/etc/glversion`,
`/etc/version.type`, `/etc/version.build`, and `/etc/version.date`. They match
the pinned GL.iNet 4.9.0 release reference
[`be3600-4.9.0_release2-1036-0623-1782222277.bin`](https://fw.gl-inet.com/firmware/be3600/release/be3600-4.9.0_release2-1036-0623-1782222277.bin),
SHA-256
`eaf2ec4abacc248f2145c1f2d243843aaaa20f5a0cb203b973a638ce23738d5b`.

## Observed stock failure

In the VOS factory USB composition, GL.iNet classified the device as Android
tethering/ECM. It did not expose the modem through the stock Cellular UI or
manage the cellular session through QMI. Selecting the verified QMI USB
composition produces `/dev/cdc-wdm0`, `qmi_wwan`, and `wwan0`, but the stock
model table and AT-port path did not describe this modem.

## Implementation boundary

The integration is restricted to USB ID `05c6:9064`:

- the model fragment selects the stock common function map and QMI protocol;
- `vos5g-qmi` selects verified USB configuration 1, binds interface 1.3 to
  `qmi_wwan`, binds interface 1.2 to `option`, releases VOS QCMAP ownership,
  and leaves GL.iNet's stock QMI dialer in control; concurrent callers
  (service start and USB bind events) serialize on one per-bus lock and
  block until the winning preparation finishes, a completed preparation is
  recorded against the current USB connection (kernel `devnum`) so repeated
  bind events do not repeat the QCMAP settle window, and the temporary WDS
  client ID is released even when disabling the leftover autoconnect fails;
- the AT wrapper resolves only the VOS interface 1.2 path and preloads a
  VOS-specific response normalizer;
- NAS `Get RF Band Information` and DSD `Get System Status` use temporary,
  independently allocated clients and never reuse the active WDS client;
  responses are accepted only when their service, client, transaction, and
  message identifiers match the request;
- the RPC result hook runs only after `get_network_info` identifies
  `05c6:9064`; other modem responses do not trigger its supplemental stock
  call and retain the original result;
- stopping the package does not attempt the unsafe software transition back
  to the factory ECM composition.

FM350 model fragments, GCOM scripts, XMM protocol code, network repair code,
and compatibility library are unchanged. The FM350 hotplug decision remains
on the original `PRODUCT=0e8d/7126/*` or `PRODUCT=0e8d/7127/*` path.

## Verified cases

The following behavior was observed on hardware:

- package installation through `opkg`;
- VOS detection in GL.iNet's stock Cellular UI rather than Tethering;
- QMI control through `/dev/cdc-wdm0` and data through `wwan0`;
- a working IPv4 data session and Internet traffic from the router and a Mac
  client connected to Slate 7 Wi-Fi;
- service restart without a router reboot or USB disconnect;
- physical VOS detach/attach recovery into USB configuration 1/QMI;
- physical Slate 7 power-cycle recovery into QMI and a working data session;
- stock online detection recovering an initially unusable session by
  redialling it;
- active NAS band `n71` and explicit DSD NR-SA service option, rendered as
  `SA n71` in `cell_info.mode`;
- 30-second band and system-mode cache refresh without a stuck QMI client;
- `wwan0` remaining `UP,LOWER_UP` and three of three Internet probes passing
  after the final local package upgrade;
- unchanged router boot ID across the final local package upgrade.

The local package and deployed runtime files were compared by SHA-256. The
package contained numeric `root:root` ownership; installed scripts were mode
`0755` and RPC data files were mode `0644`.

## Observed failure cases and limits

- Switching from QMI configuration 1 to factory ECM configuration 2 in
  software caused a USB gadget reset loop in both tested rollback sequences.
  That behavior was removed from the implementation. A physical modem power
  cycle remains the known factory-composition recovery path after removal.
- The first data session after one router reboot transmitted without useful
  receive traffic. GL.iNet's stock online detector redialled automatically;
  the replacement session passed ICMP and HTTPS checks.
- The VOS AT firmware returned `ERROR` for the tested vendor band-detail
  commands. Active band and SA/NSA status therefore come from read-only QMI
  NAS and DSD messages.
- VOS ownership preparation runs synchronously during service start. On a
  cold boot it can spend roughly 20 one-second settle iterations, in addition
  to bounded ADB calls, waiting for late QCMAP startup before stopping it.
  When a USB bind event starts that preparation first, service start blocks
  on the shared per-bus lock until it completes instead of continuing on an
  unverified success, so the stock dialer never starts mid-handoff.
- Linux exposes QMI control as one shared `/dev/cdc-wdm0` receive queue. The
  display watcher cannot coordinate with GL.iNet's proprietary QMI process,
  so exact band and SA/NSA values remain best-effort: polling is limited to
  once every 30 seconds, unmatched responses are skipped, every operation is
  bounded by a watchdog, and stale or missing cache data falls back to the
  stock technology label. This reduces but does not eliminate the possibility
  that another raw QMI reader consumes a response first.

## Incomplete hardware matrix

These cases remain **not tested** on GL-BE3600:

- a modem already supported by stock GL.iNet firmware;
- FM350-GL USB IDs `0e8d:7126` and `0e8d:7127`;
- the full web UI and mobile-app operation matrix;
- SIM absent, SIM PIN/PUK, registration denied, and operator scan cases;
- a live uninstall followed by verification of every restored stock path;

Consequently this evidence does not claim that GL-BE3600 supports FM350-GL or
every modem supported by the project.

## Reproducible package target

`make package-be3600` uses the checksum-pinned upstream OpenWrt 23.05.5
IPQ807x generic SDK:

- archive:
  `openwrt-sdk-23.05.5-ipq807x-generic_gcc-12.3.0_musl.Linux-x86_64.tar.xz`;
- SHA-256:
  `57c8a1d5586f1548ebe360d71a6dd9deec7833f5cb3e5b93d5a618c6da6e9399`;
- source:
  `https://downloads.openwrt.org/releases/23.05.5/targets/ipq807x/generic/`.

The SDK is a userspace ABI surrogate: upstream OpenWrt does not publish the
GL.iNet IPQ5332 firmware build tree. It supplies the ARMv8 Cortex-A53 compiler
and OpenWrt 23.05 musl userspace, while the package target emits GL.iNet's
observed `aarch64_cortex-a53_neon-vfpv4` package architecture. The package
must remain userspace-only; adding a kernel module requires the exact GL.iNet
source tree and configuration.

## Evidence privacy

IMEI, ICCID, IMSI, phone number, SIM credentials, device serial number, and
public IP addresses are intentionally omitted. USB IDs, firmware versions,
package versions, interface names, service names, and artifact hashes are
retained because they are required to reproduce the compatibility result.
