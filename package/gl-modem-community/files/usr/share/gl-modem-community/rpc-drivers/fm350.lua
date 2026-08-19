-- SPDX-License-Identifier: GPL-3.0-only
-- FM350 Cellular RPC for the stock 4.8.1/4.9.x internet page.

local AT_BIN = os.getenv("FM350_AT_BIN") or "/usr/libexec/gl-modem-community/fm350-at"
local PORT_BIN = os.getenv("FM350_PORT_BIN") or "/usr/libexec/gl-modem-community/fm350-port"
local USB_ROOT = os.getenv("USB_DEVICES_ROOT") or "/sys/bus/usb/devices"
local RESTORE_BIN = os.getenv("FM350_RESTORE_BIN") or "/usr/libexec/gl-modem-community/fm350-boot-restore"

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function shell_quote(s)
    return "'" .. tostring(s or ""):gsub("'", "'\\''") .. "'"
end

local function run(cmd)
    local pipe = io.popen(cmd .. " 2>/dev/null")
    if not pipe then return "" end
    local out = pipe:read("*a") or ""
    pipe:close()
    return out
end

local function at(bus, command)
    return run(shell_quote(AT_BIN) .. " " .. shell_quote(bus) .. " " .. shell_quote(command))
end

local function first_match(text, pattern)
    return trim(text:match(pattern) or "")
end

local function parse_cpin(text)
    local status = first_match(text, "%+CPIN:%s*([%w ]+)")
    if status == "" then return "UNKNOWN" end
    return status
end

local function parse_cops(text)
    local name, act = text:match('%+COPS:%s*%d+,%d+,"([^"]*)",(%d+)')
    if not name then
        name = text:match('%+COPS:%s*%d+,%d+,"([^"]*)"')
    end
    return trim(name or ""), tonumber(act or "")
end

local function gl_mode_from_cops(act)
    if act == 5 or act == 51 or act == 11 or act == 12 or act == 13 then
        return 5
    end
    if act == 4 or act == 41 or act == 7 or act == 10 then
        return 4
    end
    return act
end

-- Documented GTCCINFO record prefix:
--   field 1 = 1 serving, 2 neighbor
--   field 2 = RAT 4 LTE, 9 NR
-- Do not substring-match "NR"; section headings false-positive 5G.
local function radio_from_gtccinfo(text)
    local lte, nr = false, false
    for line in tostring(text or ""):gmatch("[^\r\n]+") do
        local serving, rat = line:match("^%s*(%d+)%s*,%s*(%d+)%s*,")
        if serving == "1" then
            if rat == "4" then lte = true end
            if rat == "9" then nr = true end
        end
    end
    if nr then
        return 5, "NR5G"
    end
    if lte then
        return 4, "LTE"
    end
    return nil
end

local function rsrp_to_bars(rsrp)
    local n = tonumber(rsrp)
    if not n then return 0 end
    if n >= -85 then return 4 end
    if n >= -95 then return 3 end
    if n >= -105 then return 2 end
    if n >= -115 then return 1 end
    return 0
end

local function parse_rsrp(text)
    return text:match("RSRP:?%s*([-%d]+)") or text:match("([-%d]+)dBm")
end

local function read_sys_id(bus, name)
    local path = USB_ROOT .. "/" .. tostring(bus) .. "/" .. name
    local fh = io.open(path, "r")
    if not fh then return "" end
    local value = trim(fh:read("*l") or "")
    fh:close()
    return value
end

local function usb_product(bus)
    return read_sys_id(bus, "idVendor"), read_sys_id(bus, "idProduct")
end

local function is_dual_slot(bus)
    local vid, pid = usb_product(bus)
    return vid == "0e8d" and pid == "7127"
end

local function parse_gtdualsim(text)
    local n = tostring(text or ""):match("%+GTDUALSIM:%s*(%d)")
    return tonumber(n)
end

local function modem_slot_to_gl(modem_slot)
    if modem_slot == 1 then return 2 end
    return 1
end

local function gl_slot_to_modem(gl_slot)
    local n = tonumber(gl_slot)
    if n == 2 then return 1 end
    return 0
end

local function active_slot_num(bus)
    if not is_dual_slot(bus) then return 1 end
    local modem_slot = parse_gtdualsim(at(bus, "AT+GTDUALSIM?"))
    if modem_slot == nil then return 1 end
    return modem_slot_to_gl(modem_slot)
end

local function section_for_slot(bus, slot)
    return "modem_" .. tostring(bus):gsub("[%.%-]", "_") .. "_s" .. tostring(slot)
end

local function section_for_bus(bus)
    return section_for_slot(bus, active_slot_num(bus))
end

local function uci_get(key)
    return trim(run("uci -q get " .. shell_quote(key)))
end

local function netifd_up(section)
    local out = run("ubus call network.interface." .. section .. " status")
    return out:find('"up":%s*true') ~= nil, out
end

local function ipv4_from_status(status)
    return first_match(status, '"address":%s*"([%d%.]+)"')
end

local function config_from_args(args)
    if type(args.config) == "table" then
        return args.config
    end
    return args
end

local function persist_disconnect(bus)
    if RESTORE_BIN == "" then return end
    run(shell_quote(RESTORE_BIN) .. " persist-disconnect " .. shell_quote(bus))
end

local function set_modem_slot(bus, gl_slot)
    if not is_dual_slot(bus) then return true end
    local modem_slot = gl_slot_to_modem(gl_slot)
    local out = at(bus, "AT+GTDUALSIM=" .. tostring(modem_slot))
    return out:find("OK") ~= nil or out:find("ERROR") == nil
end

local function collect_modem(bus)
    local ident = at(bus, "AT+CGMI")
    local model = at(bus, "AT+CGMM")
    local imei = first_match(at(bus, "AT+CGSN"), "(%d%d%d%d%d%d%d%d%d%d+)")
    local iccid = first_match(at(bus, "AT+ICCID"), "(%d%d%d%d%d%d%d%d%d%d+)")
    if iccid == "" then
        iccid = first_match(at(bus, "AT+CCID"), "(%d%d%d%d%d%d%d%d%d%d+)")
    end
    local imsi = first_match(at(bus, "AT+CIMI"), "(%d%d%d%d%d%d%d%d%d%d+)")
    local pin = parse_cpin(at(bus, "AT+CPIN?"))
    local carrier, act = parse_cops(at(bus, "AT+COPS?"))
    local cell = at(bus, "AT+GTCCINFO?")
    local mode, tech = radio_from_gtccinfo(cell)
    if not mode then
        mode = gl_mode_from_cops(act)
        if mode == 5 then
            tech = "NR5G"
        elseif mode == 4 then
            tech = "LTE"
        else
            tech = ""
        end
    end
    local rsrp = parse_rsrp(cell)
    local strength = rsrp_to_bars(rsrp)
    local at_port = trim(run(shell_quote(PORT_BIN) .. " at " .. shell_quote(bus)))
    local slot = active_slot_num(bus)
    local slots = is_dual_slot(bus) and 2 or 1
    local section = section_for_slot(bus, slot)
    local up, raw = netifd_up(section)
    local ip = ipv4_from_status(raw)
    local apn = uci_get("network." .. section .. ".apn")
    local proto = uci_get("network." .. section .. ".proto")
    if proto == "" then proto = "xmm" end
    local name = first_match(model, "([%w%-%._]+)")
    if name == "" or name == "OK" then name = "FM350-GL" end
    local vendor = first_match(ident, "([%w%. ]+)")
    if vendor == "" or vendor == "OK" then vendor = "fibocom" end

    local modem = {
        bus = bus,
        name = name,
        vendor = vendor,
        imei = imei,
        proto = proto,
        device = at_port,
        sim_slot_num = slots,
        simcard = {
            status = pin,
            iccid = iccid,
            imsi = imsi,
            carrier = carrier,
            active_sim = slot,
            signal = {
                mode = mode or 0,
                strength = strength,
                rsrp = tonumber(rsrp),
                technology = tech,
            },
        },
        network = {
            status = up and 1 or 0,
            connected = up,
            proto = proto,
            apn = apn,
            ipv4 = { ip = ip },
        },
    }
    return modem
end

local function get_info(args)
    local modem = collect_modem(args.bus)
    return {
        modems = { modem },
        simsStatus = {
            {
                type = 1,
                status = 2,
                bus = args.bus,
                slot = modem.simcard.active_sim,
                iccid = modem.simcard.iccid,
            },
        },
        offline_doc = false,
        apn_poll_support = false,
    }
end

local function get_status(args)
    local modem = collect_modem(args.bus)
    return {
        modems = { modem },
        simsStatus = {
            {
                type = 1,
                status = 2,
                bus = args.bus,
                slot = modem.simcard.active_sim,
                iccid = modem.simcard.iccid,
            },
        },
        new_sms_count = 0,
        passthrough = {},
    }
end

local function set_connect(args)
    local section = section_for_bus(args.bus)
    run("ifup " .. shell_quote(section))
    return { success = true }
end

local function disconnect(args)
    local section = section_for_bus(args.bus)
    run("ifdown " .. shell_quote(section))
    persist_disconnect(args.bus)
    return { success = true }
end

local function get_sim_config(args)
    local section = section_for_bus(args.bus)
    return {
        apn = uci_get("network." .. section .. ".apn"),
        ip_type = uci_get("network." .. section .. ".ip_type"),
        pdp = uci_get("network." .. section .. ".pdp"),
        proto = uci_get("network." .. section .. ".proto"),
        auth = uci_get("network." .. section .. ".auth"),
        username = uci_get("network." .. section .. ".username"),
        password = uci_get("network." .. section .. ".password"),
        device = trim(run(shell_quote(PORT_BIN) .. " at " .. shell_quote(args.bus))),
    }
end

local function get_slot_config(args)
    local slot = active_slot_num(args.bus)
    return {
        current_sim = tostring(slot),
        enable_switch = false,
        sim_slot_num = is_dual_slot(args.bus) and 2 or 1,
    }
end

local function set_slot_config(args)
    local current = args.current_sim
    if current ~= nil and current ~= "" then
        set_modem_slot(args.bus, current)
    end
    return { success = true, current_sim = tostring(active_slot_num(args.bus)) }
end

local function set_sim_config(args)
    if args.current_sim ~= nil and args.current_sim ~= "" then
        set_slot_config(args)
    end
    local cfg = config_from_args(args)
    local section = section_for_bus(args.bus)
    local map = {
        apn = cfg.apn,
        ip_type = cfg.ip_type,
        pdp = cfg.pdp or cfg.ip_type,
        auth = cfg.auth,
        username = cfg.username,
        password = cfg.password,
        proto = cfg.proto,
    }
    for option, value in pairs(map) do
        if value ~= nil and value ~= "" then
            run("uci set " .. shell_quote("network." .. section .. "." .. option .. "=" .. tostring(value)))
        end
    end
    run("uci commit network")
    run("ubus call network reload")
    return { success = true }
end

return {
    id = "fm350",
    usb_ids = {
        ["0e8d:7126"] = true,
        ["0e8d:7127"] = true,
    },
    methods = {
        get_info = get_info,
        get_status = get_status,
        set_connect = set_connect,
        disconnect = disconnect,
        get_sim_config = get_sim_config,
        set_sim_config = set_sim_config,
        get_slot_config = get_slot_config,
        set_slot_config = set_slot_config,
    },
}
