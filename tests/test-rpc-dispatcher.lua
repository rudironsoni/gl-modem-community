local repo = assert(arg[1], "repository path is required")
local sysfs_root = assert(os.getenv("GL_MODEM_COMMUNITY_SYSFS_USB_ROOT"),
    "test sysfs root is required")
local runtime_dir = assert(os.getenv("GL_MODEM_COMMUNITY_RUNTIME_DIR"),
    "test runtime dir is required")
local rpc_driver_dir = assert(os.getenv("GL_MODEM_COMMUNITY_RPC_DRIVER_DIR"),
    "test RPC driver directory is required")

assert(os.execute("mkdir -p " .. sysfs_root .. "/2-1 " .. runtime_dir) == 0)
local vendor = assert(io.open(sysfs_root .. "/2-1/idVendor", "w"))
vendor:write("05c6\n")
vendor:close()
local product = assert(io.open(sysfs_root .. "/2-1/idProduct", "w"))
product:write("9064\n")
product:close()
local band = assert(io.open(runtime_dir .. "/vos5g-band-2-1", "w"))
band:write("n78+B2\n")
band:close()
local nr_mode = assert(io.open(runtime_dir .. "/vos5g-mode-2-1", "w"))
nr_mode:write("NSA\n")
nr_mode:close()

local fixtures = {
    get_network_info = {
        ret = 0,
        resp = "Success",
        networks = {
            { bus = "2-1", slot = "1", ipv4 = { ip = "192.0.2.2" } },
        },
    },
    get_sim_status = {
        sims = {
            { bus = "2-1", slot = "1", technology = 5 },
        },
    },
    send_at_command = { ret = 0, resp = "OK" },
}
local calls = {}

local test_open = io.open
package.preload["nixio.fs"] = function()
    local driver_names = { "fm350.lua", "vos5g.lua" }
    return {
        dir = function(path)
            if path ~= rpc_driver_dir then return nil end
            local index = 0
            return function()
                index = index + 1
                return driver_names[index]
            end
        end,
        readfile = function(path)
            local file = test_open(path, "r")
            if not file then return nil end
            local value = file:read("*a")
            file:close()
            return value
        end,
        stat = function(path)
            local file = test_open(path, "r")
            if not file then return nil end
            file:close()
            return { mtime = os.time() }
        end,
    }
end

package.preload.cjson = function()
    return {
        null = {},
        encode = function(request) return request.method end,
        decode = function(payload) return assert(fixtures[payload]) end,
    }
end

ngx = {
    HTTP_OK = 200,
    HTTP_POST = 2,
    location = {
        capture = function(_, request)
            calls[#calls + 1] = request.body
            return { status = 200, body = "0 " .. request.body }
        end,
    },
}

local dispatcher_path = repo ..
    "/package/gl-modem-community/files/usr/lib/oui-httpd/rpc/modem"
local methods = assert(dofile(dispatcher_path))
local result = methods.get_network_info({})
assert(result.networks[1].cell_info.mode == "NSA n78+B2")
assert(result.networks[1].ipv4.ip == "192.0.2.2")
assert(#calls == 2 and calls[1] == "get_network_info" and
    calls[2] == "get_sim_status")

assert(os.execute("mkdir -p " .. sysfs_root .. "/3-1") == 0)
local other_vendor = assert(io.open(sysfs_root .. "/3-1/idVendor", "w"))
other_vendor:write("0e8d\n")
other_vendor:close()
local other_product = assert(io.open(sysfs_root .. "/3-1/idProduct", "w"))
other_product:write("7126\n")
other_product:close()
fixtures.get_network_info.networks = {
    { bus = "3-1", slot = "1", ipv4 = { ip = "198.51.100.2" } },
}
local non_vos = methods.get_network_info({})
assert(non_vos.networks[1].cell_info == nil)
assert(non_vos.networks[1].ipv4.ip == "198.51.100.2")
assert(#calls == 3 and calls[3] == "get_network_info",
    "non-VOS network info must not trigger supplemental RPC calls")

local fallback = methods.send_at_command({ bus = "not-a-usb-bus" })
assert(fallback == fixtures.send_at_command)
assert(calls[4] == "send_at_command")

local original_getenv = os.getenv
local original_open = io.open
local original_popen = io.popen
local original_nixio_preload = package.preload["nixio.fs"]
local original_nixio_loaded = package.loaded["nixio.fs"]
os.getenv = nil
io.open = nil
io.popen = nil
package.loaded["nixio.fs"] = nil
package.preload["nixio.fs"] = function()
    error("nixio.fs intentionally unavailable")
end
local sandboxed = assert(loadfile(dispatcher_path))
local ok, sandbox_methods = pcall(sandboxed)
local call_ok, sandbox_result
if ok then
    call_ok, sandbox_result = pcall(sandbox_methods.send_at_command, {})
end
os.getenv = original_getenv
io.open = original_open
io.popen = original_popen
package.preload["nixio.fs"] = original_nixio_preload
package.loaded["nixio.fs"] = original_nixio_loaded
assert(ok and type(sandbox_methods) == "table",
    "dispatcher failed without nixio.fs in the restricted OUI runtime")
assert(call_ok and sandbox_result == fixtures.send_at_command,
    "stock dispatch failed without nixio.fs and restricted io functions")

print("RPC dispatcher stock-result tests passed")
