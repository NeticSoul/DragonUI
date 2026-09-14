-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon.TalentModule then addon.TalentModule = {} end
local T = addon.TalentModule

T.CAPSTONE_TIER = 11

function T.ResolveShape(info)
    if not info then return "square" end
    local isCapstoneTier = (info.tier or 0) >= T.CAPSTONE_TIER
    if info.isExceptional then
        if isCapstoneTier then return "capstone" end
        return "circle"
    end
    if isCapstoneTier then return "capstonesquare" end
    return "square"
end

T.SHAPE_ATLAS = {
    square         = "talents-node-square",
    circle         = "talents-node-circle",
    capstone       = "talents-node-square",
    capstonesquare = "talents-node-square",
}
