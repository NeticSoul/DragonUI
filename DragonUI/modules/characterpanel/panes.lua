local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Switches what the InsetRight shows for each sidebar tab. Loaded after the panes it drives so
-- their accessors exist.

local STATS, TITLES, EQUIPMENT = 1, 2, 3

function CP.ShowSidebarPane(index)
    local cf = _G.CharacterFrame
    if not cf or not cf.InsetRight then return end

    local stats = CP._sidebar
    local titles = CP.TitlesPane and CP.TitlesPane()
    local equipment = CP.EquipmentPane and CP.EquipmentPane()

    if stats then stats:SetShownReq(index == STATS) end
    if titles then titles:SetShownReq(index == TITLES) end
    if equipment then equipment:SetShownReq(index == EQUIPMENT) end

    if index == TITLES and CP.RefreshTitlesPane then CP.RefreshTitlesPane() end
    if index == STATS and CP.RefreshSidebar then CP.RefreshSidebar() end
    if index == EQUIPMENT and CP.RefreshEquipmentPane then CP.RefreshEquipmentPane() end

    -- Right after a tab-switch Show(), self-queried width here can still lag the old tab's -- redo next frame.
    addon:After(0, function()
        if index == TITLES and CP.RefreshTitlesPane then CP.RefreshTitlesPane() end
        if index == EQUIPMENT and CP.RefreshEquipmentPane then CP.RefreshEquipmentPane() end
    end)
end

CP.PANE_STATS, CP.PANE_TITLES, CP.PANE_EQUIPMENT = STATS, TITLES, EQUIPMENT
