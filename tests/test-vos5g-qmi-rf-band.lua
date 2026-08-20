local repo = assert(arg[1], "repository path is required")
local reader = repo ..
    "/package/gl-modem-community/files/usr/libexec/gl-modem-community/" ..
    "vos5g-qmi-rf-band"

local function le16(value)
    return string.char(value % 256, math.floor(value / 256) % 256)
end

local function tlv(kind, value)
    return string.char(kind) .. le16(#value) .. value
end

local function response(client, transaction, message, payload)
    local qmi = string.char(0x02) .. le16(transaction) .. le16(message) ..
        le16(#payload) .. payload
    return string.char(0x01) .. le16(5 + #qmi) ..
        string.char(0x80, 0x03, client) .. qmi
end

local function extended_entry(radio, active_band)
    return string.char(radio) .. le16(active_band) .. string.rep("\0", 4)
end

local result_tlv = tlv(0x02, le16(0) .. le16(0))
local active_bands = string.char(2) ..
    extended_entry(12, 269) .. extended_entry(8, 121)
local reads = {
    response(9, 0x1111, 0x0020, result_tlv),
    response(7, 0x0051, 0x0031,
        result_tlv .. tlv(0x11, active_bands)),
}
local writes = {}
local closed = false
local handle = {
    write = function(_, data)
        writes[#writes + 1] = data
        return #data
    end,
    read = function()
        return table.remove(reads, 1)
    end,
    close = function() closed = true end,
}
package.preload.nixio = function()
    return {
        open = function(device, mode)
            assert(device == "/dev/fake" and mode == "r+")
            return handle
        end,
    }
end
package.loaded.nixio = nil

local saved_arg = arg
local saved_write = io.write
local output = {}
arg = { "/dev/fake", "7" }
io.write = function(...)
    for index = 1, select("#", ...) do
        output[#output + 1] = tostring(select(index, ...))
    end
end
local ok, message = pcall(dofile, reader)
io.write = saved_write
arg = saved_arg

assert(ok, message)
assert(closed, "QMI device was not closed")
assert(#writes == 1, "unexpected QMI request count")
assert(#reads == 0, "unmatched response was not skipped")
assert(table.concat(output) == "n78+B2\n", "unexpected active bands")

print("VOS 5G QMI RF-band tests passed")
