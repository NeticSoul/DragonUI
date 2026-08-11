local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Blizzard's title dropdown chains off CharacterLevelText, which lands in the slot columns' band,
-- and retail has no such control: titles live in a sidebar pane instead.
local function hideDropdown()
    for _, name in ipairs({ "PlayerTitleFrame", "PlayerTitlePickerFrame" }) do
        local f = _G[name]
        if f and not f._duiHidden then
            f._duiHidden = true
            f:Hide()
            f:HookScript("OnShow", function(self) self:Hide() end)
        end
    end
end

local function build()
    if not _G.PlayerTitleFrame then return end
    hideDropdown()
end

CP.RefreshTitles = build

CP:RegisterBuilder("titles", build)
