#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# FM350 behavior is based on modemfeed xmm-modem 0.1.7-r1 at commit
# 528e0dfc4ad1cc813e39eb1ca04794a539e894e2, with error handling,
# port discovery, configurable addressing, and teardown corrected here.

. /lib/functions.sh
. ../netifd-proto.sh

GL_MODEM_BIN=${GL_MODEM_BIN:-gl_modem}
LEGACY_AT_BIN=${LEGACY_AT_BIN:-/usr/libexec/gl-modem-community/fm350-at}
RUNTIME_STACK_FILE=${RUNTIME_STACK_FILE:-/var/run/gl-modem-community/stack}
init_proto "$@"

proto_xmm_init_config() {
	no_device=1
	no_proto_task=1
	available=1
	proto_config_add_string "device:device"
	proto_config_add_string "bus"
	proto_config_add_string "apn"
	proto_config_add_string "pdp"
	proto_config_add_string "pincode"
	proto_config_add_string "username"
	proto_config_add_string "password"
	proto_config_add_string "auth"
	proto_config_add_int "profile"
	proto_config_add_int "delay"
	proto_config_add_int "maxfail"
	proto_config_add_int "ip4prefix"
	proto_config_add_string "gateway"
	proto_config_add_boolean "disable_arp"
	proto_config_add_defaults
}

read_usb_id() {
	local tty=${1##*/} path
	path=$(readlink -f "/sys/class/tty/$tty/device") || return 1
	while [ "$path" != "/" ]; do
		if [ -r "$path/idVendor" ] && [ -r "$path/idProduct" ]; then
			VID=$(cat "$path/idVendor")
			PID=$(cat "$path/idProduct")
			USB_PATH=$path
			return 0
		fi
		path=${path%/*}
	done
	return 1
}

discover_at_port() {
	local bus=$1 expected dev iface path real cursor
	case "$(cat "/sys/bus/usb/devices/$bus/idProduct" 2>/dev/null)" in
		7126) expected=04 ;;
		7127) expected=06 ;;
		*) return 1 ;;
	esac
	for path in /sys/class/tty/ttyACM*/device /sys/class/tty/ttyUSB*/device; do
		[ -e "$path" ] || continue
		real=$(readlink -f "$path")
		cursor=$real
		iface=
		while [ "$cursor" != / ]; do
			if [ -r "$cursor/bInterfaceNumber" ]; then iface=$(cat "$cursor/bInterfaceNumber"); break; fi
			cursor=${cursor%/*}
		done
		case "$real" in
			*/$bus/*) ;;
			*) continue ;;
		esac
		[ "$iface" = "$expected" ] || continue
		dev=${path#/sys/class/tty/}
		printf '/dev/%s\n' "${dev%%/*}"
		return 0
	done
	return 1
}

discover_data_iface() {
	local candidate
	for candidate in "$USB_PATH"/*/net/* "$USB_PATH"/net/*; do
		[ -e "$candidate" ] || continue
		basename "$candidate"
		return 0
	done
	return 1
}

run_stock_at() {
	local bus=$1 stage=$2 command=$3 output
	if [ "$(cat "$RUNTIME_STACK_FILE" 2>/dev/null || true)" = legacy ]; then
		output=$("$LEGACY_AT_BIN" "$bus" "$command" 2>&1)
	else
		output=$("$GL_MODEM_BIN" -B "$bus" -U 1 AT "$command" 2>&1)
	fi || {
		logger -t gl-modem-community "FM350 AT transport failed stage=$stage bus=$bus"
		return 1
	}
	case "$output" in
		*ERROR*|'')
			logger -t gl-modem-community "FM350 stock AT command failed stage=$stage bus=$bus"
			return 1
			;;
		*OK*) ;;
		*)
			logger -t gl-modem-community "FM350 stock AT response incomplete stage=$stage bus=$bus"
			return 1
			;;
	esac
	printf '%s\n' "$output"
}

proto_xmm_setup() {
	local interface=$1 device bus apn pdp pincode username password auth profile delay maxfail
	local ip4prefix gateway disable_arp metric defaultroute peerdns DEVICE VID PID USB_PATH ifname
	local attempt address_attempt auth_num data dns ip4addr nameserver network
	json_get_vars device bus apn pdp pincode username password auth profile delay maxfail ip4prefix gateway disable_arp metric defaultroute peerdns

	profile=${profile:-1}
	# Keep GL.iNet's logical CID 5. The stock modem_AT compatibility wrapper
	# translates it to the FM350 data context CID 1 on the shared AT socket.
	delay=${delay:-5}
	maxfail=${maxfail:-5}
	ip4prefix=${ip4prefix:-24}
	disable_arp=${disable_arp:-1}
	pdp=$(printf '%s' "${pdp:-IP}" | tr '[:lower:]' '[:upper:]')
	case "$pdp" in IP|IPV6|IPV4V6) ;; *) pdp=IP ;; esac
	sleep "$delay"

	if [ -z "$device" ] && [ -n "$bus" ]; then device=$(discover_at_port "$bus") || true; fi
	[ -n "$device" ] || { proto_notify_error "$interface" NO_PORT_FOUND; proto_set_available "$interface" 0; return 1; }
	DEVICE=$device
	read_usb_id "$DEVICE" || { proto_notify_error "$interface" NO_DEVICE_FOUND; return 1; }
	case "$VID:$PID" in 0e8d:7126|0e8d:7127) ;; *) proto_notify_error "$interface" NO_DEVICE_SUPPORT; return 1 ;; esac
	ifname=$(discover_data_iface) || { proto_notify_error "$interface" NO_IFACE; return 1; }
	logger -t gl-modem-community "FM350 setup bus=${bus:-unknown} at=$DEVICE data=$ifname"

	attempt=1
	while [ "$attempt" -le "$maxfail" ]; do
		run_stock_at "$bus" probe AT >/dev/null && break
		[ "$attempt" -eq "$maxfail" ] && { proto_notify_error "$interface" NO_PORT_ANSWER; return 1; }
		attempt=$((attempt + 1))
		sleep 3
	done

	if [ -n "$pincode" ]; then
		run_stock_at "$bus" pin "AT+CPIN=\"$pincode\"" >/dev/null || { proto_notify_error "$interface" PIN_FAILED; return 1; }
	fi
	if [ -n "$username" ] && [ -n "$password" ]; then
		case "$auth" in pap) auth_num=1 ;; chap) auth_num=2 ;; *) auth_num=0 ;; esac
		run_stock_at "$bus" auth "AT+CGAUTH=$profile,$auth_num,\"$username\",\"$password\"" >/dev/null || { proto_notify_error "$interface" AUTH_FAILED; return 1; }
	fi

	run_stock_at "$bus" cmee 'AT+CMEE=2' >/dev/null || { proto_notify_error "$interface" CONNECT_FAILED; return 1; }
	run_stock_at "$bus" ipv6-format 'AT+CGPIAF=1,0,0,0' >/dev/null || { proto_notify_error "$interface" CONNECT_FAILED; return 1; }
	run_stock_at "$bus" context "AT+CGDCONT=$profile,\"$pdp\",\"${apn:-}\"" >/dev/null || { proto_notify_error "$interface" CONNECT_FAILED; return 1; }
	run_stock_at "$bus" activate "AT+CGACT=1,$profile" >/dev/null || {
		proto_notify_error "$interface" CONNECT_FAILED
		return 1
	}
	address_attempt=1
	while [ "$address_attempt" -le "$maxfail" ]; do
		data=$(run_stock_at "$bus" address "AT+CGPADDR=$profile" || true)
		ip4addr=$(printf '%s\n' "$data" | awk -F'[:,]' '/^\+CGPADDR:/{gsub(/["\r ]/,"",$3); print $3; exit}')
		[ -n "$ip4addr" ] && break
		address_attempt=$((address_attempt + 1))
		sleep 3
	done
	[ -n "$ip4addr" ] || { proto_notify_error "$interface" CONFIGURE_FAILED; return 1; }
	dns=$(run_stock_at "$bus" dns "AT+GTDNS=$profile") || { proto_notify_error "$interface" CONFIGURE_FAILED; return 1; }
	data=$(printf '%s\n%s\n' "$data" "$dns")
	nameserver=$(printf '%s\n' "$data" | awk -F'[:,]' '/^\+GTDNS:/{for(i=3;i<=NF;i++){gsub(/["\r ]/,"",$i); if($i!="" && $i!="0.0.0.0") print $i}}')

	proto_init_update "$ifname" 1
	proto_set_keep 1
	[ "$disable_arp" -eq 1 ] && ip link set dev "$ifname" arp off
	case "$pdp" in IP|IPV4V6)
		[ -n "$ip4addr" ] && [ "$ip4addr" != "0.0.0.0" ] || { proto_notify_error "$interface" CONFIGURE_FAILED; return 1; }
		proto_add_ipv4_address "$ip4addr" "$ip4prefix"
		if [ -z "$gateway" ]; then gateway=$(printf '%s' "$ip4addr" | awk -F. '{print $1"."$2"."$3".1"}'); fi
		[ "${defaultroute:-1}" -eq 0 ] || proto_add_ipv4_route 0.0.0.0 0 "$gateway" "$ip4addr"
	;; esac
	if [ "${peerdns:-1}" -ne 0 ]; then
		for network in $nameserver; do proto_add_dns_server "$network"; done
	fi
	proto_send_update "$interface"

	case "$pdp" in IPV6|IPV4V6)
		json_init
		json_add_string name "${interface}_6"
		json_add_string ifname "@$interface"
		json_add_string proto dhcpv6
		json_add_boolean extendprefix 1
		ubus call network add_dynamic "$(json_dump)"
	;; esac
}

proto_xmm_teardown() {
	local interface=$1 bus profile
	json_get_vars bus profile
	profile=${profile:-1}
	[ -n "$bus" ] && run_stock_at "$bus" deactivate "AT+CGACT=0,$profile" >/dev/null 2>&1 || true
}

add_protocol xmm
