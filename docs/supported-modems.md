# Stock supported-modem inventory

Conclusion: [CONFIRMED] `/lib/modem_data/modem_list.json` contains 16 USB entries: ten Quectel entries mapped to `function_at_quectel`, one Huawei entry mapped to `function_at_huawei`, and five entries mapped to `function_at_common`.

Evidence: extracted JSON model table and generated configuration report.

Confidence: confirmed for declared support. A declaration does not prove every feature works at runtime.

Alternative explanations: additional devices could be recognized by separately installed packages or dynamically updated data.

How to verify dynamically: inspect the live model table and attach one representative from each function map.

| VID:PID | Declared model | Function map |
|---|---|---|
| `2c7c:0133` | RG650V | Quectel |
| `17cb:0304` | EM160R | Quectel |
| `17cb:0308` | RM520N | Quectel |
| `2c7c:0801` | RM520N | Quectel |
| `2c7c:0620` | EM160R | Quectel |
| `2c7c:030e` | EM05G | Quectel |
| `2c7c:030b` | EM060K/EG060K/EM120K/EG120K | Quectel |
| `2c7c:0306` | EP06 | Quectel |
| `2c7c:0125` | EC25 | Quectel |
| `05c6:9215` | EC20 | Quectel |
| `12d1:1506` | E3276 | Huawei |
| `19d2:fffe` | QD91F | common |
| `19d2:0167` | MF820B | common |
| `2357:9000` | MA260 | common |
| `1410:b001` | USB551L | common |
| `2c7c:0512` | EM12G | common |

Conclusion: [CONFIRMED] Neither `0e8d:7126`, `0e8d:7127`, `Fibocom`, nor `FM350` occurs in the stock model table.

Evidence: exact JSON content and global search.

Confidence: confirmed.

Alternative explanations: the kernel can enumerate a device even when the GL application table does not support it.

How to verify dynamically: attach FM350 and capture hotplug variables plus `cellular.status` events.
