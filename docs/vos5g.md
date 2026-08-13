# VOS 5G adapter

## Scope

This adapter targets a VOS 5G/MV31-W device observed as USB `05c6:9064` on a GL.iNet GL-BE3600 (Slate 7), stock admin panel 4.9.0, OpenWrt 23.05-SNAPSHOT/QSDK, kernel 5.4.213.

The hardware has three USB configurations:

1. vendor DIAG, ADB, MODEM, and QMI/RMNET functions;
2. ECM;
3. MBIM.

Only configuration 2 ECM is used by the default adapter. Configuration 1 enumerated `cdc-wdm0` and `wwan0` with `qmi_wwan` during a controlled probe, but a sustained direct QMI data session has not been validated. Configuration 3 has not been validated on GL-BE3600.

## Why the adapter injects status

In ECM mode the VOS is a self-contained router. GL.iNet correctly treats `usb0` as Tethering, but its stock Cellular manager has no modem control channel and therefore cannot populate the six Cellular websocket collections.

`vos5g-state-poller` reads the existing netifd connection plus the authenticated VOS management API. The websocket wrapper removes only the incomplete entry with the same USB bus and appends one supported external modem (`type: 1`). All other stock entries and functions are returned unchanged.

The six injected collections are:

- `cellular.modems_info` and `cellular.modems_status`;
- `cellular.sims_info` and `cellular.sims_status`;
- `cellular.networks_info` and `cellular.networks_status`.

The RPC dispatcher selects `vos5g.lua` only for `05c6:9064`. Unimplemented methods fall through to GL.iNet's stock modem backend.

## Credentials and API boundary

The adapter does not contain a VOS password. A local UCI password is converted at runtime by `vos5g-xxtea`, which reproduces the public web UI's XXTEA login encoding. The poller stores the session token and cookie only under `/var/run/gl-modem-community` and removes them when the service stops.

TLS verification is disabled for the VOS management request because the device uses its local self-signed certificate at `192.168.225.1`. Requests stay on the directly attached ECM subnet.

## Confirmed hardware behavior

The GL-BE3600 run confirmed:

- ECM remained online on `usb0` while state was sampled and the wrapper was mounted;
- VOS firmware `RXMG1.20.00.326_0R19` returned live NR band/channel and signal;
- the firmware can return a non-numeric marker in the inactive LTE signal field, which the adapter normalizes to zero;
- the observed firmware returned MCC/MNC labels in reverse for Canadian PLMN `302-220`, which the adapter normalizes;
- the stock page displayed the VOS card and read `sp.telus.com` in its SIM settings dialog;
- stopping/unmounting the wrapper restored the original stock file while Tethering stayed online;
- the Cellular Disconnect action set the network state to disconnected while preserving cached SIM and operator state;
- the Cellular Connect action restored ECM DHCP address `192.168.225.47`, gateway `192.168.225.1`, and an interface-bound three-packet connectivity check with no loss;
- a network-selected band change after reconnect was reflected in the stock card on the next poll.

SIM identifiers, phone number, and login material are intentionally absent from repository evidence.

## Remaining work

- validate package installation rather than the equivalent temporary file layout;
- validate router reboot and USB replug on a packaged build;
- implement and test direct QMI connect/disconnect before advertising configuration 1 as a data mode;
- validate MBIM on GL-BE3600 or another GL.iNet target;
- verify the same API field behavior on other VOS firmware versions and operators;
- regression-test another stock-supported USB modem while the wrapper is active.
