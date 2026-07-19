-- SPDX-License-Identifier: GPL-3.0-only
-- The FM350 currently uses the stock function_at_common RPC behavior. This
-- module establishes the community-driver boundary without claiming advanced
-- operations that have not been reproduced on the target firmware.
return {
    id = "fm350",
    usb_ids = {
        ["0e8d:7126"] = true,
        ["0e8d:7127"] = true,
    },
    methods = {},
}
