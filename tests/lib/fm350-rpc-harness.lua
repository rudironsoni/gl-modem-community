-- SPDX-License-Identifier: GPL-3.0-only
-- Offline harness for fm350.lua RPC fixtures.

local driver_path = assert(os.getenv("FM350_DRIVER"))
local fixture_dir = assert(os.getenv("FM350_FIXTURE_DIR"))
local usb_root = os.getenv("USB_DEVICES_ROOT") or ""
local expect = assert(os.getenv("FM350_EXPECT"))

local replies = {}
local at_log = {}

local function read_file(path)
    local fh = io.open(path, "r")
    if not fh then return "" end
    local data = fh:read("*a") or ""
    fh:close()
    return data
end

local function load_reply(name)
    if replies[name] then return replies[name] end
    replies[name] = read_file(fixture_dir .. "/" .. name .. ".txt")
    return replies[name]
end

local orig_popen = io.popen
io.popen = function(cmd)
    cmd = tostring(cmd or "")
    local at = cmd:match("AT%+([%w?]+)")
    if cmd:find("fm350%-at", 1, true) or cmd:find("AT+", 1, true) then
        at_log[#at_log + 1] = cmd
        local body = ""
        if cmd:find("GTCCINFO", 1, true) then
            body = load_reply(os.getenv("FM350_GTCCINFO") or "gtccinfo-lte")
        elseif cmd:find("GTDUALSIM?", 1, true) then
            body = load_reply("gtdualsim-query")
        elseif cmd:find("GTDUALSIM=", 1, true) then
            body = "OK\n"
        elseif cmd:find("CGMI", 1, true) then
            body = "fibocom\nOK\n"
        elseif cmd:find("CGMM", 1, true) then
            body = "FM350-GL\nOK\n"
        elseif cmd:find("CGSN", 1, true) then
            body = "123456789012345\nOK\n"
        elseif cmd:find("ICCID", 1, true) or cmd:find("CCID", 1, true) then
            body = "+ICCID: 8903302340000000001\nOK\n"
        elseif cmd:find("CIMI", 1, true) then
            body = "262011234567890\nOK\n"
        elseif cmd:find("CPIN", 1, true) then
            body = "+CPIN: READY\nOK\n"
        elseif cmd:find("COPS", 1, true) then
            body = load_reply(os.getenv("FM350_COPS") or "cops-lte")
        end
        return {
            read = function() return body end,
            close = function() return true end,
        }
    end
    if cmd:find("fm350%-port", 1, true) then
        return {
            read = function() return "/dev/ttyUSB4\n" end,
            close = function() return true end,
        }
    end
    if cmd:find("uci %-q get", 1, true) then
        local key = cmd:match("uci %-q get '([^']+)'") or ""
        local value = ""
        if key:find("%.apn$") then value = "internet.telekom" end
        if key:find("%.auth$") then value = "PAP" end
        if key:find("%.username$") then value = "telekom" end
        if key:find("%.password$") then value = "secret" end
        if key:find("%.proto$") then value = "xmm" end
        if key:find("%.ip_type$") then value = "IP" end
        return {
            read = function() return value .. "\n" end,
            close = function() return true end,
        }
    end
    if cmd:find("ubus call network.interface", 1, true) then
        return {
            read = function() return '{"up": true, "ipv4-address":[{"address":"10.0.0.2"}]}\n' end,
            close = function() return true end,
        }
    end
    if cmd:find("uci set", 1, true) or cmd:find("uci commit", 1, true) or cmd:find("ifup", 1, true) or cmd:find("ifdown", 1, true) or cmd:find("fm350%-boot%-restore", 1, true) then
        at_log[#at_log + 1] = cmd
        return {
            read = function() return "" end,
            close = function() return true end,
        }
    end
    return orig_popen(cmd)
end

local driver = assert(dofile(driver_path))
assert(driver.usb_ids["0e8d:7127"])
assert(type(driver.methods.get_slot_config) == "function")
assert(type(driver.methods.set_slot_config) == "function")

local function check(cond, msg)
    if not cond then
        io.stderr:write(msg .. "\n")
        os.exit(1)
    end
end

if expect == "lte-mode" then
    local status = driver.methods.get_status({ bus = "2-1" })
    check(status.modems[1].simcard.signal.mode == 4, "LTE serving cell must map to GL mode 4")
    check(status.modems[1].sim_slot_num == 2, "0e8d:7127 must advertise two slots")
    check(status.modems[1].simcard.active_sim == 2, "GTDUALSIM 1 must map to GL slot 2")
elseif expect == "nsa-mode" then
    local status = driver.methods.get_status({ bus = "2-1" })
    check(status.modems[1].simcard.signal.mode == 5, "LTE+NR serving cells must map to GL mode 5")
elseif expect == "sa-mode" then
    local status = driver.methods.get_status({ bus = "2-1" })
    check(status.modems[1].simcard.signal.mode == 5, "NR-only serving cell must map to GL mode 5")
elseif expect == "cops-fallback" then
    local status = driver.methods.get_status({ bus = "2-1" })
    check(status.modems[1].simcard.signal.mode == 5, "COPS 13 fallback must translate to GL mode 5")
elseif expect == "set-sim-nested" then
    local result = driver.methods.set_sim_config({
        bus = "2-1",
        iccid = "8903302340000000001",
        config = {
            apn = "globaldata",
            auth = "NONE",
            username = "",
            password = "",
        },
    })
    check(result.success == true, "set_sim_config must accept nested config")
    local saw = false
    for _, cmd in ipairs(at_log) do
        if cmd:find("network.modem_2_1_s2.apn=globaldata", 1, true) then
            saw = true
        end
        if cmd:find("secret", 1, true) and cmd:find("set_sim_config", 1, true) then
            check(false, "unexpected secret leak")
        end
    end
    check(saw, "nested APN must be written to the active slot section")
elseif expect == "set-slot" then
    local result = driver.methods.set_slot_config({
        bus = "2-1",
        enable_switch = false,
        current_sim = "1",
    })
    check(result.success == true, "set_slot_config must succeed")
    local saw = false
    for _, cmd in ipairs(at_log) do
        if cmd:find("AT+GTDUALSIM=0", 1, true) then
            saw = true
        end
    end
    check(saw, "GL slot 1 must send AT+GTDUALSIM=0")
else
    check(false, "unknown expect " .. expect)
end
