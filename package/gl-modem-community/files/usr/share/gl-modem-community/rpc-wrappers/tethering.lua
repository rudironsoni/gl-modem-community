-- SPDX-License-Identifier: GPL-3.0-only
-- Runtime wrapper around the exact stock tethering RPC.
-- Delegates every method and filters FM350 RNDIS from get_status.

local STOCK = os.getenv("TETHERING_STOCK") or "/var/run/gl-modem-community/tethering.stock"
local PORT_BIN = os.getenv("FM350_PORT_BIN") or "/usr/libexec/gl-modem-community/fm350-port"
local USB_ROOT = os.getenv("USB_DEVICES_ROOT") or "/sys/bus/usb/devices"

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function read_id(path)
    local fh = io.open(path, "r")
    if not fh then return "" end
    local value = trim(fh:read("*l") or "")
    fh:close()
    return value
end

local function list_dir(dir)
    local names = {}
    local pipe = io.popen("ls -1 " .. dir .. " 2>/dev/null")
    if not pipe then return names end
    for name in pipe:lines() do
        names[#names + 1] = name
    end
    pipe:close()
    return names
end

local function fm350_data_ifaces()
    local drop = {}
    for _, name in ipairs(list_dir(USB_ROOT)) do
        local base = USB_ROOT .. "/" .. name
        if read_id(base .. "/idVendor") == "0e8d" then
            local pid = read_id(base .. "/idProduct")
            if pid == "7126" or pid == "7127" then
                local pipe = io.popen(PORT_BIN .. " data " .. name .. " 2>/dev/null")
                if pipe then
                    local iface = trim(pipe:read("*l") or "")
                    pipe:close()
                    if iface ~= "" then
                        drop[iface] = true
                    end
                end
            end
        end
    end
    return drop
end

local function filter_status(result)
    if type(result) ~= "table" or type(result.devices) ~= "table" then
        return result
    end
    local drop = fm350_data_ifaces()
    local kept = {}
    for _, dev in ipairs(result.devices) do
        if type(dev) ~= "table" or not drop[dev.device] then
            kept[#kept + 1] = dev
        end
    end
    result.devices = kept
    return result
end

local chunk, load_err = loadfile(STOCK)
if not chunk then
    error(load_err or ("unable to load stock tethering from " .. STOCK))
end
local stock = chunk()
if type(stock) ~= "table" then
    error("stock tethering module did not return a table")
end

local wrapper = {}
for key, value in pairs(stock) do
    wrapper[key] = value
end
if type(stock.get_status) == "function" then
    wrapper.get_status = function(args)
        return filter_status(stock.get_status(args))
    end
end
return wrapper
