-- SPDX-License-Identifier: GPL-3.0-only
-- GL GUI RPC hooks for VOS 5G USB composition 05c6:9064.

local cjson = require "cjson"
local state_path = "/var/run/gl-modem-community/vos5g-state.json"
local control = "/usr/libexec/gl-modem-community/vos5g-control"

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function run(action)
    local pipe = io.popen(control .. " " .. shell_quote(action) .. " 2>/dev/null")
    if not pipe then return -32603 end
    local body = pipe:read("*a")
    local ok_close = pipe:close()
    if not ok_close then return -32603 end
    if body == "" then return {} end
    local ok, value = pcall(cjson.decode, body)
    return ok and value or -32603
end

local function read_state()
    local file = io.open(state_path, "r")
    if not file then return {} end
    local body = file:read("*a")
    file:close()
    local ok, value = pcall(cjson.decode, body)
    return ok and value or {}
end

local function active_state()
    local state = read_state()
    if state.present ~= true then return nil end
    return state
end

local function get_sim_config()
    local state = active_state()
    if not state then return nil end
    local sim = type(state.sim_status) == "table" and state.sim_status or {}
    return {
        apn = sim.apn or "",
        username = "",
        password = "",
        auth = "NONE",
        ip_type = 0,
        network_mode = "AUTO",
        roaming = true,
        protocol = state.mode or "ecm",
        device = type(state.network_info) == "table" and state.network_info.network_interface or "usb0",
    }
end

local function set_sim_config(args)
    local state = active_state()
    if not state then return nil end
    args = type(args) == "table" and args or {}
    local sim = type(state.sim_status) == "table" and state.sim_status or {}
    if type(args.apn) == "string" and args.apn ~= (sim.apn or "") then
        -- Writing the VOS profile also changes its self-managed PDP session.
        -- Keep this initial driver read-only instead of silently accepting a
        -- setting that only changed the GL.iNet side.
        return -32602
    end
    return {}
end

local function get_profile_list(args)
    if not active_state() then return nil end
    args = type(args) == "table" and args or {}
    return {
        active_slots = args.active_slots or {},
        custom_profiles = {},
    }
end

return {
    id = "vos5g",
    usb_ids = {
        ["05c6:9064"] = true,
    },
    methods = {
        set_connect = function()
            if not active_state() then return nil end
            return run("connect")
        end,
        disconnect = function()
            if not active_state() then return nil end
            return run("disconnect")
        end,
        get_sim_config = get_sim_config,
        set_sim_config = set_sim_config,
        get_profile_list = get_profile_list,
        get_slot_failover_config = function()
            if not active_state() then return nil end
            return { enable_switch = false, current_sim = 1, slot_type = {} }
        end,
    },
}
