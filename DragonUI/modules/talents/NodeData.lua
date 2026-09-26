-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
addon.TalentModule = addon.TalentModule or {}
local T = addon.TalentModule

-- Wrath's deepest tier (the 51-point talent); recomputed from live data for shallower custom trees.
T.CAPSTONE_TIER = 11

-- Exceptional talents are the active abilities, so they read as circles; the deepest row is enlarged.
function T.ResolveShape(info)
    if not info then return "square" end
    local isCapstoneTier = (info.tier or 0) >= T.CAPSTONE_TIER
    if info.isExceptional then
        return isCapstoneTier and "capstone" or "circle"
    end
    return isCapstoneTier and "capstonesquare" or "square"
end

T.SHAPE_ATLAS = {
    square         = "talents-node-square",
    circle         = "talents-node-circle",
    capstone       = "talents-node-apex-large",
    capstonesquare = "talents-node-square",
}
