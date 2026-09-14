-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon.TalentModule then addon.TalentModule = {} end
local T = addon.TalentModule

local function BuildWarmodeButton(f)
    if f._warmmodeBtn then return end
    f._warmmodeBtn = true

    local btnSize = 64
    local btn = CreateFrame("Button", "DragonUI_WarmodeButton", f)
    btn:SetSize(btnSize, btnSize)
    btn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",
        -(T.FRAME.CHROME_R or 0) - 19, (T.FRAME.CHROME_B or 0) + 9)
    btn:SetFrameLevel(f:GetFrameLevel() + 2)

    btn.ring = btn:CreateTexture(nil, "ARTWORK")
    btn.ring:set_atlas("pvptalents-warmode-ring", false)
    btn.ring:SetPoint("CENTER")
    btn.ring:SetSize(btnSize, btnSize)
    btn.ring:Show()

    btn.ringDisabled = btn:CreateTexture(nil, "ARTWORK")
    btn.ringDisabled:set_atlas("pvptalents-warmode-ring-disabled", false)
    btn.ringDisabled:SetPoint("CENTER")
    btn.ringDisabled:SetSize(btnSize, btnSize)
    btn.ringDisabled:Hide()

    btn.glow = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    btn.glow:set_atlas("pvptalents-warmode-glow", false)
    btn.glow:SetPoint("CENTER")
    btn.glow:SetSize(btnSize, btnSize)
    btn.glow:SetBlendMode("ADD")
    btn.glow:Hide()

    btn.iconOrb = btn:CreateTexture(nil, "ARTWORK", nil, -1)
    btn.iconOrb:set_atlas("pvptalents-warmode-orb", false)
    btn.iconOrb:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.iconOrb:SetSize(btnSize * 0.75, btnSize * 0.75)

    btn.firecover = btn:CreateTexture(nil, "ARTWORK", nil, -2)
    btn.firecover:set_atlas("pvptalents-warmode-firecover", false)
    btn.firecover:SetPoint("CENTER")
    btn.firecover:SetSize(btnSize, btnSize)

    btn:SetScript("OnClick", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        btn._pvpOn = not (btn._pvpOn or false)
        TogglePVP()
        if T.RefreshWarmodeButton then T.RefreshWarmodeButton() end
        if addon and addon.After then
            addon:After(0.3, function() if T.RefreshWarmodeButton then T.RefreshWarmodeButton() end end)
            addon:After(0.6, function() if T.RefreshWarmodeButton then T.RefreshWarmodeButton() end end)
        end
    end)

    btn:SetScript("OnEnter", function(self)
        if self.IsEnabled and not self:IsEnabled() then return end
        if btn.glow then btn.glow:Show() end
    end)
    f:HookScript("OnShow", function()
        if T.RefreshWarmodeButton then pcall(T.RefreshWarmodeButton) end
        if addon and addon.After then
            addon:After(0.1, function() if T.RefreshWarmodeButton then pcall(T.RefreshWarmodeButton) end end)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if btn.glow then btn.glow:Hide(); end
    end)

    function T.RefreshWarmodeButton()
        if not btn or not btn.ring then return end
        local enabled = btn._pvpOn or (IsPvPEnabled and IsPvPEnabled()) or false
        local canToggle = not (InCombatLockdown and InCombatLockdown())
        if btn.ring then
            btn.ring:set_atlas(enabled and "pvptalents-warmode-ring-disabled" or "pvptalents-warmode-ring", false)
            btn.ring:Show()
        end
        if btn.ringDisabled then btn.ringDisabled:Hide() end
        if btn.firecover then
            if enabled and canToggle then btn.firecover:Show() else btn.firecover:Hide() end
        end
        if btn.glow then btn.glow:Hide() end
        if btn.iconOrb then btn.iconOrb:Show() end
        local swordAtlas = enabled and "pvptalents-warmode-swords-disabled" or "pvptalents-warmode-swords"
        if not btn.iconSwords then
            if btn:IsVisible() then
                btn.iconSwords = btn:CreateTexture(nil, "ARTWORK", nil, 2)
                btn.iconSwords:SetPoint("CENTER", btn, "CENTER", 0, 0)
                btn.iconSwords:SetSize(35, 35)
                btn.iconSwords:set_atlas(swordAtlas, false)
                btn.iconSwords:Show()
                btn._swordAtlas = swordAtlas
            end
        elseif btn._swordAtlas ~= swordAtlas then
            btn.iconSwords:Hide()
            btn.iconSwords:set_atlas(swordAtlas, false)
            btn.iconSwords:Show()
            btn._swordAtlas = swordAtlas
        end
        if btn.SetEnabled then btn:SetEnabled(canToggle) end
    end

    btn._pvpOn = (IsPvPEnabled and IsPvPEnabled()) or false
    T.RefreshWarmodeButton()
    T._refreshWarmodeBtn = T.RefreshWarmodeButton
end

local function ShowWarmodeGrid()
    local grid = _G["DragonUI_WarmodeGrid"]
    if grid then
        grid:SetShown(not grid:IsShown())
        return
    end

    grid = CreateFrame("Frame", "DragonUI_WarmodeGrid", UIParent)
    grid:SetSize(660, 360)
    grid:SetPoint("CENTER")
    grid:SetFrameStrata("DIALOG")
    grid:SetFrameLevel(10)
    grid:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2, bgAlpha = 0.85})
    grid:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    grid:SetBackdropBorderColor(1, 0.8, 0.2, 1)
    grid:SetMovable(true)
    grid:EnableMouse(true)
    grid:RegisterForDrag("LeftButton")
    grid:SetScript("OnDragStart", function(self) self:StartMoving() end)
    grid:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    grid:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then self:Hide() end
    end)

    local title = grid:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", grid, "TOP", 0, -8)
    title:SetText("Warmode textures grid - click: hide | drag: move")

    local cells = {
        { name = "ring",          atlas = "pvptalents-warmode-ring" },
        { name = "ring-disabled", atlas = "pvptalents-warmode-ring-disabled" },
        { name = "glow",          atlas = "pvptalents-warmode-glow" },
        { name = "orb",           atlas = "pvptalents-warmode-orb" },
        { name = "firecover",     atlas = "pvptalents-warmode-firecover" },
        { name = "swords",        atlas = "pvptalents-warmode-swords" },
        { name = "swords-disabled", atlas = "pvptalents-warmode-swords-disabled" },
    }

    local cols = 4
    local cellW, cellH, gap = 150, 100, 10
    for i, cell in ipairs(cells) do
        local slot = CreateFrame("Frame", nil, grid)
        slot:SetSize(cellW, cellH)
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        slot:SetPoint("TOPLEFT", grid, "TOPLEFT",
            12 + col * (cellW + gap), -30 - row * (cellH + gap))

        local tex = slot:CreateTexture(nil, "ARTWORK")
        tex:set_atlas(cell.atlas, true)
        tex:SetPoint("CENTER", slot, "CENTER", 0, -6)

        local label = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("BOTTOM", slot, "BOTTOM", 0, 2)
        label:SetText(cell.name)

        if cell.name:find("sword") then
            slot:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 2, bgAlpha = 0})
            slot:SetBackdropBorderColor(1, 0, 0, 1)
        end
    end

    local sheet = grid:CreateTexture(nil, "ARTWORK")
    sheet:SetTexture(addon.atlasinfo["pvptalents-warmode-swords"][1])
    sheet:SetTexCoord(0, 1, 0, 1)
    sheet:SetSize(528, 264)
    sheet:SetPoint("BOTTOM", grid, "BOTTOM", 0, 14)

    grid:Show()
end

SlashCmdList["GRIDWARMODE"] = ShowWarmodeGrid
SLASH_GRIDWARMODE1 = "/gridwarmode"

T.BuildWarmodeButton = BuildWarmodeButton
return BuildWarmodeButton
