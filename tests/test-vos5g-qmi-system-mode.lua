local repo = assert(arg[1], "repository path is required")
local reader = repo ..
    "/package/gl-modem-community/files/usr/libexec/gl-modem-community/" ..
    "vos5g-qmi-system-mode"

local function le16(value)
    return string.char(value % 256, math.floor(value / 256) % 256)
end

local function le32(value)
    return le16(value % 65536) .. le16(math.floor(value / 65536) % 65536)
end

local function u16le(data, offset)
    local a, b = data:byte(offset, offset + 1)
    assert(b)
    return a + b * 256
end

local function tlv(kind, value)
    return string.char(kind) .. le16(#value) .. value
end

local result_tlv = tlv(0x02, le16(0) .. le16(0))

local function ctl_response(transaction, message, payload)
    local qmi = string.char(0x01, transaction) .. le16(message) ..
        le16(#payload) .. payload
    return string.char(0x01) .. le16(5 + #qmi) ..
        string.char(0x80, 0x00, 0x00) .. qmi
end

local function service_response(service, client, transaction, message, payload)
    local qmi = string.char(0x02) .. le16(transaction) .. le16(message) ..
        le16(#payload) .. payload
    return string.char(0x01) .. le16(5 + #qmi) ..
        string.char(0x80, service, client) .. qmi
end

local function run_case(rat, mask_high, expected)
    local client = 7
    local systems = string.char(1) .. le32(0) .. le32(rat) ..
        le32(0x1000) .. le32(mask_high)
    local reads = {
        ctl_response(0x71, 0x0022,
            result_tlv .. tlv(0x01, string.char(0x2a, client))),
        service_response(0x2a, client, 0x6251, 0x0024,
            result_tlv .. tlv(0x10, systems)),
        ctl_response(0x72, 0x0023, result_tlv),
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
    arg = { "/dev/fake" }
    io.write = function(...)
        for index = 1, select("#", ...) do
            output[#output + 1] = tostring(select(index, ...))
        end
    end
    local ok = pcall(dofile, reader)
    io.write = saved_write
    arg = saved_arg

    assert(closed, "QMI device was not closed")
    assert(#writes == 3, "temporary DSD client was not released")
    assert(writes[1]:byte(5) == 0 and u16le(writes[1], 9) == 0x0022,
        "invalid Allocate CID request")
    assert(writes[2]:byte(5) == 0x2a and writes[2]:byte(6) == client and
        u16le(writes[2], 10) == 0x0024, "invalid DSD System Status request")
    assert(writes[3]:byte(5) == 0 and u16le(writes[3], 9) == 0x0023,
        "invalid Release CID request")

    if expected then
        assert(ok, "valid DSD response was rejected")
        assert(table.concat(output) == expected .. "\n",
            "unexpected DSD mode output")
    else
        assert(not ok, "ambiguous or non-NR DSD response was accepted")
        assert(#output == 0, "failed DSD response produced output")
    end
end

run_case(6, 0x1200, "SA")
run_case(6, 0x0a00, "NSA")
run_case(6, 0x1a00, nil)
run_case(3, 0x0000, nil)

print("VOS 5G QMI DSD system-mode tests passed")
