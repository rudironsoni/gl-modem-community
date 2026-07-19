# Package inventory

Conclusion: [CONFIRMED] This OpenWrt 25 image uses APK package metadata, not an installed opkg database.

Evidence: `analysis/manifests/apk-installed.txt`, `apk-package-list-files.txt`, and `opkg-metadata-paths.txt`.

Confidence: confirmed.

Alternative explanations: opkg-compatible helper files may exist, but installed ownership is recoverable from APK metadata.

How to verify dynamically: `apk list --installed` on hardware and compare it with the static manifest.

Relevant packages include `gl-sdk4-cellular` `26.163.12373~1111f6a-r1`, `gl-oui-rpc` `26.183.46097~2cb0a09-r1`, and `comgt` `0.32-r36`. Installed kernel support includes `kmod-usb-acm`, `kmod-usb-serial-option`, `kmod-usb-net-rndis`, `qmi_wwan`, `cdc_ncm`, `cdc_ether`, and `usb_wwan`.

Conclusion: [CONFIRMED] The image contains neither `cdc_mbim.ko`, an `mtk_t7xx` module, nor an installed MBIM userspace stack.

Evidence: filesystem and package manifests.

Confidence: confirmed for this extracted image.

Alternative explanations: a separately installed package or different USB composition could add MBIM later.

How to verify dynamically: `apk list --installed | grep -Ei 'mbim|t7xx'` and `find /lib/modules -iname '*mbim*' -o -iname '*t7xx*'`.
