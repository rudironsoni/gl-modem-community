-- SPDX-License-Identifier: GPL-3.0-only
-- FM350 Cellular RPC for the stock 4.8.1/4.9.x internet page.

local AT_BIN = "/usr/libexec/gl-modem-community/fm350-at"
local PORT_BIN = "/usr/libexec/gl-modem-community/fm350-port"

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

local function radio_from_gtccinfo(text)
    if text:find("NR", 1, true) then return 13, "NR5G" end
    if text:find("LTE", 1, true) or text:find("E%-UTRAN", 1, true) then
        return 7, "LTE"
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

local function section_for_bus(bus)
    return "modem_" .. tostring(bus):gsub("[%.%-]", "_") .. "_s1"
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
        mode = act
        if act == 13 then
            tech = "NR5G"
        elseif act == 7 then
            tech = "LTE"
        else
            tech = ""
        end
    end
    local rsrp = parse_rsrp(cell)
    local strength = rsrp_to_bars(rsrp)
    local at_port = trim(run(shell_quote(PORT_BIN) .. " at " .. shell_quote(bus)))
    local section = section_for_bus(bus)
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
        sim_slot_num = 1,
        simcard = {
            status = pin,
            iccid = iccid,
            imsi = imsi,
            carrier = carrier,
            active_sim = 1,
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
                slot = 1,
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
                slot = 1,
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

local function set_sim_config(args)
    local section = section_for_bus(args.bus)
    local map = {
        apn = args.apn,
        ip_type = args.ip_type,
        pdp = args.pdp or args.ip_type,
        auth = args.auth,
        username = args.username,
        password = args.password,
        proto = args.proto,
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
    },
}
