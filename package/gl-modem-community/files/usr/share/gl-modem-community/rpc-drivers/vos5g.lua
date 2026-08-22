-- SPDX-License-Identifier: GPL-3.0-only
-- Fill the stock network-info display field that is absent from the VOS 5G
-- QMI response. Dialing and all other network data remain stock-owned.

local usb_ids = {
    ["05c6:9064"] = true,
}

local mode_for_technology = {
    [2] = "2G",
    [3] = "3G",
    [4] = "LTE",
    [5] = "NR",
    [41] = "LTE",
    [51] = "NR",
}

local function valid_nr_mode(mode)
    return mode == "SA" or mode == "NSA"
end

local function format_mode(mode, band, nr_mode)
    local has_band = type(band) == "string" and band ~= ""
    if not has_band then
        return mode == "NR" and valid_nr_mode(nr_mode) and nr_mode or mode
    end

    -- RF Band Information can contain both the NR carrier and its LTE anchor.
    -- DSD supplies SA/NSA independently; band membership never infers it.
    if band:match("^n%d") or band:match("%+n%d") then
        mode = valid_nr_mode(nr_mode) and nr_mode or "NR"
    elseif band:match("^B%d") then
        mode = "LTE"
    end
    return mode .. " " .. band
end

local function key_for(bus, slot)
    if type(bus) ~= "string" then return nil end
    return bus .. "\0" .. tostring(slot or "")
end

local function matches_network_info(method, _, result, context)
    if method ~= "get_network_info" or type(result) ~= "table" or
        type(result.networks) ~= "table" or type(context) ~= "table" or
        type(context.usb_id_for_bus) ~= "function" then
        return false
    end
    for _, network in ipairs(result.networks) do
        if type(network) == "table" and
            usb_ids[context.usb_id_for_bus(network.bus)] then
            return true
        end
    end
    return false
end

local function get_network_info(_, result, context)
    if type(result) ~= "table" or type(result.networks) ~= "table" then
        return result
    end
    if type(context) ~= "table" or type(context.usb_id_for_bus) ~= "function" or
        type(context.vendor_results) ~= "table" then
        return result
    end

    local sim_result = context.vendor_results.get_sim_status
    if type(sim_result) ~= "table" or type(sim_result.sims) ~= "table" then
        return result
    end

    local sims = {}
    for _, sim in ipairs(sim_result.sims) do
        if type(sim) == "table" then
            local key = key_for(sim.bus, sim.slot)
            if key then sims[key] = sim end
        end
    end

    for _, network in ipairs(result.networks) do
        if type(network) == "table" and
            usb_ids[context.usb_id_for_bus(network.bus)] then
            local sim = sims[key_for(network.bus, network.slot)]
            local mode = sim and mode_for_technology[tonumber(sim.technology)]
            local band = type(context.band_for_bus) == "function" and
                context.band_for_bus(network.bus) or nil
            local nr_mode = type(context.nr_mode_for_bus) == "function" and
                context.nr_mode_for_bus(network.bus) or nil
            local cell_info = network.cell_info
            local has_mode = type(cell_info) == "table" and
                type(cell_info.mode) == "string" and cell_info.mode ~= ""
            if mode and not has_mode then
                if type(cell_info) ~= "table" then
                    cell_info = {}
                    network.cell_info = cell_info
                end
                cell_info.mode = format_mode(mode, band, nr_mode)
            end
        end
    end

    return result
end

return {
    id = "vos5g",
    usb_ids = usb_ids,
    methods = {},
    result_matches = matches_network_info,
    result_dependencies = {
        get_network_info = { "get_sim_status" },
    },
    result_methods = {
        get_network_info = get_network_info,
    },
}
