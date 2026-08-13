-- SPDX-License-Identifier: GPL-3.0-only
-- Add VOS 5G state to the stock GL.iNet cellular websocket provider.

local cjson = require "cjson"
local stock = dofile("/var/run/gl-modem-community/cellular.stock.lua")
local state_path = "/var/run/gl-modem-community/vos5g-state.json"
local M = {}

local function read_state()
    local file = io.open(state_path, "r")
    if not file then return nil end
    local body = file:read("*a")
    file:close()
    local ok, state = pcall(cjson.decode, body)
    if not ok or type(state) ~= "table" or state.present ~= true then
        return nil
    end
    return state
end

local function merge(method, collection, state_key)
    local response = stock[method]() or {}
    local entries = response[collection]
    if type(entries) ~= "table" then entries = {} end

    local state = read_state()
    local item = state and state[state_key]
    if type(item) ~= "table" or type(item.bus) ~= "string" then
        response[collection] = entries
        return response
    end

    local filtered = {}
    for _, existing in ipairs(entries) do
        if type(existing) ~= "table" or existing.bus ~= item.bus then
            filtered[#filtered + 1] = existing
        end
    end
    filtered[#filtered + 1] = item
    response[collection] = filtered
    return response
end

function M.modems_status()
    return merge("modems_status", "modems", "modem_status")
end

function M.modems_info()
    return merge("modems_info", "modems", "modem_info")
end

function M.sims_status()
    return merge("sims_status", "sims", "sim_status")
end

function M.sims_info()
    return merge("sims_info", "sims", "sim_info")
end

function M.networks_status()
    return merge("networks_status", "networks", "network_status")
end

function M.networks_info()
    return merge("networks_info", "networks", "network_info")
end

return M
