# GL-MT3000 FM350 observation, 2026-07-19

Source: runtime logs supplied by Rudi from stock GL.iNet `4.9.1-op25` with `gl-modem-community` `0.1.0-r1` and later `0.1.1-r1` installed.

Conclusion: [CONFIRMED] The initial package model definition selected the wrong serial-device family. The FM350 enumerated as RNDIS plus seven `option` serial ports, while the package declared `ttyACM` offset `0`.

Evidence:

```text
usb 2-1: new SuperSpeed USB device number 2 using xhci-mtk
rndis_host 2-1:1.0 eth2: register 'rndis_host' ... RNDIS device, 00:00:11:12:13:14
option 2-1:1.2 ... attached to ttyUSB0
option 2-1:1.3 ... attached to ttyUSB1
option 2-1:1.4 ... attached to ttyUSB2
option 2-1:1.6 ... attached to ttyUSB3
option 2-1:1.7 ... attached to ttyUSB4
option 2-1:1.8 ... attached to ttyUSB5
option 2-1:1.9 ... attached to ttyUSB6
modem_AT: Bus: 2-1, AT port: -O0 at_offset:-1
cellular_manage: No modem found for bus: 2-1
cellular_manage: modem AT process on bus 2-1 is not ready
```

Confidence: confirmed.

Alternative explanations: later initialization can still fail after correcting the AT port. This observation isolates the first failure and does not prove the remainder of the stock common parser.

How to verify dynamically: install `0.1.1-r1`, reboot with FM350 attached, and confirm `modem_AT` reports the product-specific `ttyUSB` AT offset rather than `at_offset:-1`.

Conclusion: [CONFIRMED] The RNDIS interface was separately claimed by GL tethering while cellular initialization failed. The `xmm` interface entered a restart loop and its teardown AT command returned `ERROR` because setup never completed.

Evidence: `eth2` was registered by `rndis_host`; netifd brought up `tethering`; `wwan` repeatedly transitioned down/setup; `fm350-disconnect.gcom returned ERROR` repeated.

Confidence: high.

Alternative explanations: the exact reason for any failure after corrected port selection remains unverified.

How to verify dynamically: compare `cellular.modem info/status`, `network.interface.wwan`, `network.interface.tethering`, and AT-stage logs after installing `0.1.1-r1`.

Conclusion: [CONFIRMED] Version `0.1.1-r1` fixed admission and AT-port selection. The stock backend detected the SIM even though the UI reported otherwise.

Evidence:

```text
modem_AT: Bus: 2-1, AT port: /dev/ttyUSB3 at_offset:3
cellular_manage: Executing dial connect, initiated by SIM INSERT (bus: 2-1, slot: 1 ...)
cellular_manage: ICCID <redacted> already exists and synced
cellular_manage: try normal PLMN match [mcc+mnc:21403] ... imsi[<redacted>]
```

Confidence: confirmed.

Alternative explanations: the UI can still display an absent or unavailable SIM when a later status poll fails. The logs prove backend reads, not a stable frontend status schema.

How to verify dynamically: capture `ubus call cellular.sim info` and `ubus call cellular.sim status` while the UI reports no SIM, with ICCID and IMSI redacted before publication.

Conclusion: [CONFIRMED] The stock generic modem function map cannot complete FM350 PDP setup. It queries undefined CIDs, attempts APN setup, then fails its minimum-function transition and never obtains an active PDP address.

Evidence:

```text
common_get_pdp: cid 5 not found
Failed to obtain APN, executing APN setup operation
Failed to set min function to module (retry 1/3)
Failed to get pdp state form module (retry 3/3)
get_v4_info failed, bus=2-1 slot=1
```

Static evidence identifies the common-map commands as `AT+CGDCONT?`, `AT+CGDCONT=<cid>,...`, `AT+CFUN=0`, `AT+CFUN=1`, `AT+CGACT?`, and `AT+CGACT=<state>,<cid>`. Public modemfeed's FM350 path writes `CGDCONT` directly and does not perform the stock `CFUN=0` transition.

Confidence: high. The failing stage is confirmed; attributing it specifically to FM350 rejection of `CFUN=0` remains [INFERENCE] until the translated runtime is observed.

Alternative explanations: `CGDCONT?` response formatting may also be incompatible, or a subsequent `xmm` netifd handoff may fail after PDP activation.

How to verify dynamically: install `0.1.2-r1`, confirm the FM350-only `modem_AT` compatibility wrapper is active, then check whether `common_get_pdp: cid ... not found` disappears and whether `CGACT`/`CGPADDR` reaches an address.
