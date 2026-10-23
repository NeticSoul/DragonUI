-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local NP = addon.Nameplates
local A = NP.atlas
NP.forever = {}
local F = NP.forever

function F.HideLevel(plateData)
    if plateData and plateData._foreverLevel then
        plateData._foreverLevel:Hide()
    end
end

-- Only known native levels or verified unit tokens are used. Off-target NPCs
-- must not inherit the target's level, nor the previous occupant's cached text.
function F.SyncLevel(plateData, unit, fallback, wanted, boss)
    if not NP.config.IsForeverSkin() or not wanted
        or NP.gather.IsHeadlineActive(plateData)
        or NP.gather.IsTotemIconOnlyActive(plateData) then
        F.HideLevel(plateData)
        return
    end
    local hp = plateData.minaHp
    if not hp then return end
    local level = unit and UnitExists(unit) and UnitLevel(unit) or fallback
    level = tonumber(level)
    if not boss and not level then
        F.HideLevel(plateData)
        return
    end
    local frame = plateData._foreverLevel
    if not frame then
        frame = CreateFrame("Frame", nil, hp)
        frame:SetFrameLevel(hp:GetFrameLevel() + 1)
        frame:EnableMouse(false)
        frame.bg = A.CreateSlice(frame, "BACKGROUND")
        frame.selected = A.CreateSlice(frame, "OVERLAY")
        frame.text = frame:CreateFontString(nil, "OVERLAY")
        frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.skull = frame:CreateTexture(nil, "OVERLAY")
        frame.skull:SetPoint("CENTER", frame, "CENTER", 0, 0)
        plateData._foreverLevel = frame
    end
    local _, h = NP.config.GetBarRefSize()
    local scale = h / 13
    local w, fh = 28 * scale, h + 5 * scale
    local signature = h .. ":" .. tostring(NP.module._cfgRev)
    if frame._layoutSignature ~= signature then
        frame._layoutSignature = signature
        frame:SetSize(w, fh)
        frame:ClearAllPoints()
        frame:SetPoint("LEFT", hp, "RIGHT", 5 * scale, 0.5 * scale)
        A.LayoutSlice(frame.bg, "levelBg", frame, w, fh, 0, 0, 0, 0)
        A.ShowSlice(frame.bg)
        A.LayoutSlice(frame.selected, "levelSelected", frame, w, fh, 3 * scale, 3 * scale, 3 * scale, 4 * scale)
        A.Apply(frame.skull, "levelSkull")
        -- The cell is 26 logical pixels with the glyph inset; 21 keeps the skull at
        -- the size the original badge paints instead of the too-small 16.
        frame.skull:SetSize(21 * scale, 21 * scale)
        NP.layout.SafeSetFont(frame.text, NP.config.GetNameplateFont(), math.max(8, 10 * scale), "OUTLINE")
    end
    local target = NP.identity.IsTargetPlateVisual(plateData)
    local focus = NP.identity.IsFocusPlate(plateData)
    local cfg = NP.config.GetCfg()
    if (target or focus) and cfg.retailSelectionBorder ~= false and cfg.showTargetHighlight ~= false then
        A.SetSliceVertexColor(frame.selected, 1, target and 1 or 0.49, target and 1 or 0.039, 1)
        A.ShowSlice(frame.selected)
    else
        A.HideSlice(frame.selected)
    end
    if boss or (level and level <= 0) then
        frame.text:Hide()
        frame.skull:Show()
    else
        if frame._lastLevel ~= level then
            frame._lastLevel = level
            frame.text:SetText(tostring(level))
        end
        -- Player level can change without changing this unit's level.
        local color = GetQuestDifficultyColor(level)
        frame.text:SetTextColor(color.r, color.g, color.b)
        frame.text:Show()
        frame.skull:Hide()
    end
    frame:Show()
end

-- Called from the identity transition; only the Forever skin paints focus.
function F.OnFocusChanged(oldFocus, newFocus)
    if not NP.config.IsForeverSkin() then return end
    if oldFocus then NP.gather.RefreshPlateTargetState(oldFocus, "forever_focus_changed") end
    if newFocus then NP.gather.RefreshPlateTargetState(newFocus, "forever_focus_changed") end
end

-- Party/raid cast bars have a separate frame but share the same original art.
function F.SyncCastFillStyle(bar)
    local style = NP.config.GetCfg().plateStyle
    local previous = bar._plateArtStyle
    if previous == style then return end
    bar._plateArtStyle = style
    -- Also update a combat-log-monitored cast which is already in progress;
    -- those skip the normal cast setup during an options refresh.
    if style == "forever" or previous == "forever" then
        bar:SetStatusBarTexture(NP.config.GetCastFillTexture(bar.channelingEx, bar._notInterruptible, bar._interrupted))
        bar:SetStatusBarColor(1, 1, 1, 1)
        if bar.InvalidateTextureCache then bar:InvalidateTextureCache() end
        if bar.UpdateTextureClipping then
            local lo, hi = bar:GetMinMaxValues()
            local value = bar:GetValue()
            bar:UpdateTextureClipping(hi > lo and (value - lo) / (hi - lo) or 0, bar.channelingEx)
        end
    end
end

function F.StylePartyCast(bar, width, height)
    if not NP.config.IsForeverSkin() then
        if bar._foreverCastFrame then
            A.HideSlice(bar._foreverCastFrame)
            if bar.minaBr then bar.minaBr:Show() end
            if bar.minaBg then
                bar.minaBg:SetTexture(NP.const.MINA_TEX .. "bar-bg")
                bar.minaBg:SetTexCoord(0, 1, 0, 1)
            end
        end
        return
    end
    bar._foreverCastFrame = bar._foreverCastFrame or A.CreateSlice(bar, "ARTWORK")
    local margin = 2 * math.min(1, height / 6)
    A.LayoutSlice(bar._foreverCastFrame, "castFrame", bar, width, height, margin, margin, margin, margin)
    A.ShowSlice(bar._foreverCastFrame)
    if bar.minaBr then bar.minaBr:Hide() end
    if bar.minaBg then A.Apply(bar.minaBg, "castBg") end
end
