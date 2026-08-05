local addon = select(2, ...)

-- Nameplates namespace and module bootstrap.

addon.Nameplates = addon.Nameplates or {}
local NP = addon.Nameplates

NP.module = NP.module or {
    initialized = false,
    applied = false,
    plates = {},
    scannerFrame = nil,
    eventFrame = nil,
    scanElapsed = 0,
    lastChildCount = 0,
    _opacityEnabled = false,
    _opacityValue = 0.5,
    targetPlate = nil,
    targetGUID = nil,
    focusPlate = nil,
    focusGUID = nil,
    mouseoverPlate = nil,
    mouseoverGUID = nil,
    comboTargetPlate = nil,
    inArena = false,
    partyTokenByName = {},
    arenaTokenByName = {},
}

if addon.RegisterModule then
    addon:RegisterModule("nameplates", NP.module,
        addon.L["Nameplates"],
        (addon.L and addon.L["Apply DragonUI nameplate styling."]) or "Custom health stack on 30300 Blizzard nameplates")
end
