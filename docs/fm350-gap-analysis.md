# FM350-GL gap analysis

Rudi reports that `xmm-modem` from `koshev-msk/modemfeed` operates his FM350 on vanilla OpenWrt 25. [UNVERIFIED] This task did not reproduce that result or run hardware.

| Concern | Stock expectation | FM350 public evidence | Gap layer | Status |
|---|---|---|---|---|
| USB ID | table match before event | `0e8d:7126`, `0e8d:7127` | model allowlist | confirmed gap |
| Kernel serial | USB serial/ACM | `option`, ACM; stock option table contains both IDs | enumeration | likely present, runtime unverified |
| AT port | table tty offset/function map | USB interface 04 or 06 by product | port discovery | package implementation, unverified |
| Manufacturer/model | common/Quectel/Huawei parser | Fibocom/FM350 responses | vendor identification | no Fibocom map |
| Basic identity/SIM | generic 3GPP | `CGMI`, `CGMM`, `CGMR`, `CIMI`, `ICCID`, `CGSN` | parser compatibility | likely partial |
| Registration/signal | generic plus vendor metrics | `COPS`, `CEREG`, `CGREG`, `CESQ` | response parser | partial, unverified |
| Serving cell/CA/temp | mainly Quectel branches | `GTCCINFO`, `GTCAINFO`, `GTSENRDTEMP` | AT/parser mismatch | confirmed missing handler |
| APN/connect | stock libcm protocols | `CGAUTH`, `CGDCONT`, `CGACT`, `CGPADDR`, `GTDNS` | netifd/state machine | supplied `xmm` path |
| Data interface | qcm/qmi/ncm/common | RNDIS/NCM-style direct IP | interface/addressing | package configurable, unverified |
| Band/mode/locking | `QCFG`, `QNWPREFCFG`, `QNWLOCK` | Fibocom GT family required | AT/parser mismatch | confirmed incompatibility |
| MBIM | no installed stock MBIM stack | not required by proven `xmm` path | protocol | intentionally out of scope |
| UI schema | generic core plus advanced branches | core values can map; advanced absent | frontend/capability | partial display expected |

Conclusion: [CONFIRMED] FM350 is stopped first at USB hotplug detection. `/etc/hotplug.d/usb/30_modem` only calls `cellular.status get_event` for a VID/PID in `modem_list.json`.

Evidence: hotplug script and model table.

Confidence: confirmed.

Alternative explanations: another service could independently discover the modem, but no such stock path was identified.

How to verify dynamically: `ubus monitor` during attach before and after only extending the table.

Conclusion: [INFERENCE] After adding the two IDs with `function_at_common`, FM350 should reach the generic GL modem path, but complete initialization and parsing are not proven.

Evidence: common function map exists, generic commands overlap with public FM350 commands, and kernel option data includes both IDs.

Confidence: medium.

Alternative explanations: tty selection, response formatting, IP type, or a later model check can still fail.

How to verify dynamically: run the staged tests in `validation-plan.md` and compare with an official common-map modem.

Conclusion: [CONFIRMED] A model-table addition alone cannot provide advanced Fibocom functionality because the backend's advanced code is Quectel-specific and no Fibocom GT parser exists.

Evidence: function-map assignments and AT catalog.

Confidence: high.

Alternative explanations: basic UI operation may not require advanced fields.

How to verify dynamically: exercise cell, band, lock, temperature, and 5G SA/NSA UI paths while logging AT traffic and JSON responses.
