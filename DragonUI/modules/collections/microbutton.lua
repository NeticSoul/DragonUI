-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- micromenu.lua captures MICRO_BUTTONS in a file-scope local, so a button that does not exist by
-- the time it loads can never join the strip -- hence at load, before it, not at PLAYER_LOGIN.
if _G.CollectionsMicroButton then return end

local ICON = addon._dir .. "Micromenu\\uimicromenu2x"

local btn = CreateFrame("Button", "CollectionsMicroButton", UIParent)
btn:SetSize(32, 40)
btn:SetPoint("CENTER")
btn:Hide()

-- setupMicroButtons re-points all four; they only have to exist for its getters to return one.
btn:SetNormalTexture(ICON)
btn:SetPushedTexture(ICON)
btn:SetDisabledTexture(ICON)
btn:SetHighlightTexture(ICON)
btn:GetHighlightTexture():SetBlendMode("ADD")

btn:RegisterForClicks("LeftButtonUp")
btn:SetScript("OnClick", function()
    if addon.ToggleCollections then addon.ToggleCollections() end
end)
-- What MainMenuBarMicroButton's own OnEnter does: it is what puts every other micro menu tooltip at
-- the default anchor and prints the second line in NORMAL_FONT_COLOR.
btn.tooltipText = addon.L["Pets & Mounts"]
btn.newbieText = addon.L["The mounts and pets you have collected."]
btn:SetScript("OnEnter", function(self)
    GameTooltip_AddNewbieTip(self, self.tooltipText, 1.0, 1.0, 1.0, self.newbieText)
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
