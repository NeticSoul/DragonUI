-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Switches what the InsetRight shows for each sidebar tab. Loaded after the panes it drives so
-- their accessors exist.

local STATS, TITLES, EQUIPMENT = 1, 2, 3
local MARBLE = addon._dir .. "UI\\ui-background-marble"

-- Retail's InsetRight is an InsetFrameTemplate: tiled marble under its rim, darker than the body.
local function paneMarble(inset)
    if not inset._duiMarble then
        local bg = inset:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(MARBLE, "REPEAT", "REPEAT")
        bg:SetHorizTile(true)
        bg:SetVertTile(true)
        bg:SetAllPoints(inset)
        inset._duiMarble = bg
    end
    return inset._duiMarble
end

function CP.ShowSidebarPane(index)
    local cf = _G.CharacterFrame
    if not cf or not cf.InsetRight then return end

    -- The stats tab keeps the body showing through, behind its class crest.
    paneMarble(cf.InsetRight):SetShownCompat(index ~= STATS)

    local stats = CP._sidebar
    local titles = CP.TitlesPane and CP.TitlesPane()
    local equipment = CP.EquipmentPane and CP.EquipmentPane()

    if stats then stats:SetShownCompat(index == STATS) end
    if titles then titles:SetShownCompat(index == TITLES) end
    if equipment then equipment:SetShownCompat(index == EQUIPMENT) end

    if index == TITLES and CP.RefreshTitlesPane then CP.RefreshTitlesPane() end
    if index == STATS and CP.RefreshSidebar then CP.RefreshSidebar() end
    if index == EQUIPMENT and CP.RefreshEquipmentPane then CP.RefreshEquipmentPane() end

    -- Right after a tab-switch Show(), self-queried width here can still lag the old tab's -- redo next frame.
    addon:After(0, function()
        if index == TITLES and CP.RefreshTitlesPane then CP.RefreshTitlesPane() end
        if index == EQUIPMENT and CP.RefreshEquipmentPane then CP.RefreshEquipmentPane() end
    end)
end

CP.PANE_EQUIPMENT = EQUIPMENT
