local repo = assert(arg[1], "repository path is required")
local driver_path = repo ..
    "/package/gl-modem-community/files/usr/share/gl-modem-community/rpc-drivers/vos5g.lua"
local driver = assert(dofile(driver_path))
local handler = assert(driver.result_methods.get_network_info)

local function check(condition, message)
    if not condition then error(message, 2) end
end

local usb_ids = {
    ["2-1"] = "05c6:9064",
    ["3-1"] = "2c7c:0801",
}

local sim_result = {
    sims = {
        { bus = "2-1", slot = "1", technology = 5 },
        { bus = "2-1", slot = "2", technology = 41 },
    },
}
local context = {
    usb_id_for_bus = function(bus) return usb_ids[bus] end,
    vendor_results = { get_sim_status = sim_result },
}

local result = {
    ret = 0,
    resp = "Success",
    networks = {
        { bus = "2-1", slot = "1", ipv4 = { ip = "192.0.2.2" } },
        { bus = "2-1", slot = "2", cell_info = {} },
        { bus = "3-1", slot = "1" },
    },
}
local transformed = handler({}, result, context)
check(transformed == result, "handler must preserve the stock result object")
check(result.networks[1].cell_info.mode == "NR", "NR mode was not filled")
check(result.networks[2].cell_info.mode == "LTE", "LTE mode was not filled")
check(result.networks[3].cell_info == nil, "non-VOS network was modified")
check(result.networks[1].ipv4.ip == "192.0.2.2", "stock network data was modified")
check(result.ret == 0 and result.resp == "Success", "stock result metadata was modified")

result.networks[1].cell_info.mode = "NR5G-SA"
handler({}, result, context)
check(result.networks[1].cell_info.mode == "NR5G-SA", "stock mode was overwritten")

local non_vos = { networks = { { bus = "3-1", slot = "1" } } }
handler({}, non_vos, context)
check(non_vos.networks[1].cell_info == nil, "non-VOS result was modified")

local unknown_context = {
    usb_id_for_bus = context.usb_id_for_bus,
    vendor_results = {
        get_sim_status = {
            sims = { { bus = "2-1", slot = "1", technology = 99 } },
        },
    },
}
local unknown = { networks = { { bus = "2-1", slot = "1" } } }
handler({}, unknown, unknown_context)
check(unknown.networks[1].cell_info == nil, "unknown technology was guessed")

local band_context = {
    usb_id_for_bus = context.usb_id_for_bus,
    band_for_bus = function(bus)
        check(bus == "2-1", "unexpected band cache bus")
        return "n78+B2"
    end,
    vendor_results = { get_sim_status = sim_result },
}
local band_result = { networks = { { bus = "2-1", slot = "1" } } }
handler({}, band_result, band_context)
check(band_result.networks[1].cell_info.mode == "NR n78+B2",
    "active bands were not appended to the data mode")

local nsa_context = {
    usb_id_for_bus = context.usb_id_for_bus,
    band_for_bus = function() return "n78+B2" end,
    nr_mode_for_bus = function() return "NSA" end,
    vendor_results = { get_sim_status = sim_result },
}
local nsa_result = { networks = { { bus = "2-1", slot = "1" } } }
handler({}, nsa_result, nsa_context)
check(nsa_result.networks[1].cell_info.mode == "NSA n78+B2",
    "explicit DSD NSA mode was not combined with the active bands")

local sa_only_context = {
    usb_id_for_bus = context.usb_id_for_bus,
    nr_mode_for_bus = function() return "SA" end,
    vendor_results = { get_sim_status = sim_result },
}
local sa_only_result = { networks = { { bus = "2-1", slot = "1" } } }
handler({}, sa_only_result, sa_only_context)
check(sa_only_result.networks[1].cell_info.mode == "SA",
    "explicit DSD SA mode was not used without a band cache")

local lte_context = {
    usb_id_for_bus = context.usb_id_for_bus,
    band_for_bus = function() return "B2+B66" end,
    nr_mode_for_bus = function() return "SA" end,
    vendor_results = { get_sim_status = sim_result },
}
local lte_result = { networks = { { bus = "2-1", slot = "1" } } }
handler({}, lte_result, lte_context)
check(lte_result.networks[1].cell_info.mode == "LTE B2+B66",
    "LTE-only active bands did not select the LTE label")

print("VOS 5G RPC result handler tests passed")
