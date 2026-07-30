local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const

-- Nameplates discovery: Blizzard plate detection and chrome suppression.

NP.discovery = NP.discovery or {}

local function ResolvePlateFrames(frame)
    return NP.native_style.ResolvePlateFrames(frame)
end

-- True if a plate region carries the native nameplate border/flash marker texture.
local function RegionMatchesNameplateMarker(region)
    if not region or not region.GetObjectType or region:GetObjectType() ~= "Texture" then
        return false
    end
    local tex = region.GetTexture and region:GetTexture()
    if NP.native_style.TextureMatches(tex, C.MARKER_BORDER, "Nameplate%-Border") then
        return true
    end
    return NP.native_style.TextureMatches(tex, C.MARKER_FLASH, "TargetingFrame%-Flash")
end

function NP.discovery.IsBlizzardNameplate(frame)
    local plateRoot = ResolvePlateFrames(frame)
    if not plateRoot or not plateRoot.GetRegions then
        return false
    end
    local region1, region2 = plateRoot:GetRegions()
    return RegionMatchesNameplateMarker(region1) or RegionMatchesNameplateMarker(region2)
end

function NP.discovery.ExtractBlizzardPlateParts(frame)
    local plateRoot, widgetHost = ResolvePlateFrames(frame)
    if not plateRoot or not widgetHost then
        return nil
    end

    local healthBar, castBar = widgetHost:GetChildren()

    if not castBar or (castBar.GetObjectType and castBar:GetObjectType() ~= "StatusBar") then
        castBar = nil
        if plateRoot.GetNumChildren then
            for i = 1, plateRoot:GetNumChildren() do
                local child = select(i, plateRoot:GetChildren())
                if child and child ~= healthBar and child.GetObjectType
                    and child:GetObjectType() == "StatusBar" then
                    castBar = child
                    break
                end
            end
        end
    end

    local threat, border, castBarBorder, castBarShield, castBarIcon, highlight,
        ogNameText, levelText, bossIcon, raidIcon, eliteIcon = plateRoot:GetRegions()

    if not castBar and plateRoot.GetChildren then
        castBar = select(2, plateRoot:GetChildren())
    end

    return {
        plate = plateRoot,
        widgetHost = widgetHost,
        healthBar = healthBar,
        castBar = castBar,
        threat = threat,
        border = border,
        castBarBorder = castBarBorder,
        castBarShield = castBarShield,
        castBarIcon = castBarIcon,
        highlight = highlight,
        ogNameText = ogNameText,
        levelText = levelText,
        bossIcon = bossIcon,
        raidIcon = raidIcon,
        eliteIcon = eliteIcon,
    }
end

-- Cache negative IsBlizzardNameplate results (weak keys; skips repeat scans).
NP.discovery.RejectedWorldChildren = NP.discovery.RejectedWorldChildren
    or setmetatable({}, { __mode = "k" })

-- Reused scan scratch tables (4 Hz); consumed synchronously, never retained.
local scratchChildren = {}
local scratchOut = {}

-- Copy GetChildren varargs into reused table (one fetch, no re-query per index).
local function FillVararg(t, ...)
    local n = select("#", ...)
    for i = 1, n do
        t[i] = select(i, ...)
    end
    return n
end

function NP.discovery.EnumerateBlizzardNameplates()
    local out = scratchOut
    wipe(out)
    local rejected = NP.discovery.RejectedWorldChildren
    -- Capture WorldFrame children once (O(n²) if re-fetched per iteration at 4 Hz).
    wipe(scratchChildren)
    local count = FillVararg(scratchChildren, NP.WorldGetChildren(WorldFrame))
    local registered = NP.module.plates
    for i = 1, count do
        local child = scratchChildren[i]
        if child and not rejected[child] then
            -- Known plates skip parts extraction (4 Hz scan + child-count changes).
            local known = registered[child.RealPlate or child]
            if known and known.plate then
                out[known.plate] = known
            else
                local frameName = child:GetName()
                if frameName and C.EXCLUDED_FRAME_NAMES[frameName] then
                    rejected[child] = true
                elseif NP.discovery.IsBlizzardNameplate(child) then
                    local parts = NP.discovery.ExtractBlizzardPlateParts(child)
                    if parts and parts.plate and parts.healthBar and parts.border then
                        out[parts.plate] = parts
                    end
                else
                    rejected[child] = true
                end
            end
        end
    end
    return out
end

-- Plate name helpers

function NP.discovery.GetPlateName(plateData)
    if plateData.ogNameText and plateData.ogNameText.GetText then
        local text = plateData.ogNameText:GetText()
        if text and text ~= "" then
            -- Keep the native string intact for display. StripRealm is only for
            -- matching UnitName/CLEU (Name-Realm); applying it here truncates
            -- hyphenated NPC names like "Blood-Queen Lana'thel" → "Blood".
            return text
        end
    end
    return plateData.plateName
end

function NP.discovery.FormatPlateName(plateData, unit, levelOverride)
    local name = plateData.plateName or "?"
    local level, color
    if levelOverride ~= nil then
        level = levelOverride
        local num = tonumber(level)
        if num then
            color = GetQuestDifficultyColor(num)
        else
            color = { r = 1, g = 0, b = 0 }
        end
    elseif unit and UnitExists(unit) then
        level = UnitLevel(unit)
        if level then
            color = GetQuestDifficultyColor(level)
            if NP.native_style.IsBossLevel(level) then
                color = { r = 1, g = 0, b = 0 }
            end
        end
    end
    if not level then
        return name
    end
    if NP.native_style.IsBossLevel(level) then
        -- Boss skull uses dedicated texture in gather/layout.
        return name
    end
    local cfg = NP.config.GetCfg()
    local fmt = cfg.levelTextFormat or "brackets"
    local levelText
    if fmt == "parentheses" then
        levelText = "(" .. tostring(level) .. ")"
    elseif fmt == "plain" then
        levelText = tostring(level)
    else
        levelText = "[" .. tostring(level) .. "]"
    end
    return string.format("|cff%02x%02x%02x%s|r %s",
        color.r * 255, color.g * 255, color.b * 255, levelText, name)
end

-- Bar builder helpers

function NP.discovery.ApplyBarMask(bar)
    local tex = bar and bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if tex and tex.SetMask then
        tex:SetMask(C.MINA_TEX .. "bar-mask")
        if tex.SetHorizTile then
            tex:SetHorizTile(false)
        end
    end
end

function NP.discovery.AttachBarBorder(bar)
    if bar.minaBr then
        return bar.minaBr
    end
    local br = CreateFrame("Frame", nil, bar)
    br:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
    br:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
    br:SetFrameLevel(bar:GetFrameLevel() + 2)
    local tex = br:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(br)
    tex:SetTexture(C.MINA_TEX .. "bar-border")
    tex:SetVertexColor(0.5, 0.5, 0.5)
    bar.minaBr = br
    return br
end

function NP.discovery.CreateMinaBar(parent, fillTex, r, g, b)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(fillTex)
    bar:SetStatusBarColor(r, g, b, 1)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(100)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture(C.MINA_TEX .. "bar-bg")
    bar.minaBg = bg

    NP.discovery.AttachBarBorder(bar)
    NP.discovery.ApplyBarMask(bar)
    return bar
end

-- Native chrome suppression
-- Keep FontStrings on the plate (BGH/compat scan GetRegions + GetText).
-- Wipe via SetWidth(0.001)+SetAlpha(0); client re-Shows on hover so we reassert.

local function SuppressNativeFontString(fs, alphaOnly)
    if not fs then
        return
    end
    fs._duiChromeActive = true
    fs._duiAlphaOnly = alphaOnly and true or false
    if fs.SetWidth then
        if fs._duiOrigWidth == nil and fs.GetWidth then
            local w = fs:GetWidth()
            if w and w > 0.01 then
                fs._duiOrigWidth = w
            end
        end
        -- ReassertHotChrome hits this every frame on target/mouseover.
        if not fs.GetWidth or fs:GetWidth() > 0.01 then
            fs:SetWidth(0.001)
        end
    end
    if fs.SetAlpha and (not fs.GetAlpha or fs:GetAlpha() ~= 0) then
        fs:SetAlpha(0)
    end
    if not alphaOnly and fs.IsShown and fs:IsShown() then
        fs:Hide()
    end
    if not fs._duiChromeHooked and fs.HookScript then
        fs._duiChromeHooked = true
        fs:HookScript("OnShow", function(self)
            if not self._duiChromeActive then
                return
            end
            if self.SetWidth then
                self:SetWidth(0.001)
            end
            if self.SetAlpha then
                self:SetAlpha(0)
            end
            if not self._duiAlphaOnly then
                self:Hide()
            end
        end)
    end
end

local function RestoreNativeFontString(fs, _parent)
    if not fs then
        return
    end
    fs._duiChromeActive = nil
    fs._duiAlphaOnly = nil
    if fs.SetWidth and fs._duiOrigWidth then
        fs:SetWidth(fs._duiOrigWidth)
    end
    fs._duiOrigWidth = nil
    if fs.SetAlpha then
        fs:SetAlpha(1)
    end
    if fs.Show then
        fs:Show()
    end
end

-- Cheap per-frame stomp; client undoes Hide/alpha/width on hover without a reliable event.
function NP.discovery.ReassertNativeFontChrome(plateData)
    if not plateData then
        return
    end
    local function reassert(fs)
        if not fs or not fs._duiChromeActive then
            return
        end
        if fs.SetWidth and (not fs.GetWidth or fs:GetWidth() > 0.01) then
            fs:SetWidth(0.001)
        end
        if fs.SetAlpha and (not fs.GetAlpha or fs:GetAlpha() ~= 0) then
            fs:SetAlpha(0)
        end
        if not fs._duiAlphaOnly and fs.Hide and fs.IsShown and fs:IsShown() then
            fs:Hide()
        end
    end
    reassert(plateData.ogNameText)
    reassert(plateData.levelText)
end

function NP.discovery.HideCastChrome(plateData)
    for _, key in ipairs({ "castBarBorder", "castBarShield", "castBarIcon" }) do
        local region = plateData[key]
        if region and region.Hide then
            region:Hide()
        end
    end
    if plateData.minaCastSpark and plateData.minaCastSpark.Hide then
        plateData.minaCastSpark:Hide()
    end
end

function NP.discovery.SuppressNativeChrome(plateData)
    NP.native_style.NoteNativePlateClassification(plateData)
    -- Some external addons identify nameplates by native border texture / IsShown().
    local alphaOnlyChrome = (NP.config.IsBattleGroundHealersLoaded and NP.config.IsBattleGroundHealersLoaded())
        or (NP.config.IsPlateAlphaCompatEnabled and NP.config.IsPlateAlphaCompatEnabled())
    -- Cached for ReassertHotChrome, which re-suppresses every frame without recomputing cfg/IsAddOnLoaded.
    plateData._alphaOnlyChrome = alphaOnlyChrome
    if alphaOnlyChrome then
        if plateData.border and plateData.border.SetAlpha then
            plateData.border:SetAlpha(0)
        end
    else
        NP.native_style.HideRegion(plateData.border)
    end
    local cfg = NP.config.GetCfg()
    -- bossIcon: alpha-only (never Hide); IsShown() drives boss clamp detection.
    NP.native_style.SuppressNativePlateIcon(plateData.bossIcon)
    if cfg.showEliteIcon ~= false then
        NP.native_style.SuppressNativePlateIcon(plateData.eliteIcon)
    end

    -- Collapse threat texcoords to hide glow; keep IsShown/GetVertexColor for aggro data.
    local threat = plateData.threat
    if threat and threat.SetTexCoord then
        threat:SetTexCoord(0, 0, 0, 0)
    end

    -- Custom castbar replaces native cast visuals while active.
    NP.discovery.HideCastChrome(plateData)

    SuppressNativeFontString(plateData.ogNameText, alphaOnlyChrome)

    local lvlText = plateData.levelText
    if lvlText then
        local lvlCfg = NP.config.GetCfg()
        -- Instant native-level snapshot applies in every mode, including centered names.
        if lvlCfg.showLevelAlways then
            plateData.plateLevel = nil
            plateData._plateLevelName = nil
            if lvlText.GetText then
                local raw = lvlText:GetText()
                if plateData.bossIcon and plateData.bossIcon.IsShown and plateData.bossIcon:IsShown() then
                    -- Boss plates may have empty native level text.
                    plateData.plateLevel = "??"
                    plateData._plateLevelName = plateData.plateName
                elseif raw and raw ~= "" then
                    plateData.plateLevel = raw
                    plateData._plateLevelName = plateData.plateName
                else
                    plateData.plateLevel = nil
                end
            end
        else
            plateData.plateLevel = nil
            plateData._plateLevelName = nil
        end
        SuppressNativeFontString(lvlText, alphaOnlyChrome)
    end

    local highlight = plateData.highlight
    if highlight then
        if highlight.SetAlpha then
            highlight:SetAlpha(0)
        end
    end

    NP.native_style.NeutralizeStatusBarVisual(plateData.healthBar)
    NP.native_style.HideRegion(plateData.castBarBorder)
end

-- Client keeps re-showing native name/bar on hover/target on its own; stomp it every frame here.
function NP.discovery.ReassertHotChrome(plateData)
    SuppressNativeFontString(plateData.ogNameText, plateData._alphaOnlyChrome)
    NP.native_style.NeutralizeStatusBarVisual(plateData.healthBar)
end

function NP.discovery.RestoreNativeChrome(plateData)
    if not plateData then return end
    local plate = plateData.plate
    local showElite = NP.config.GetCfg().showEliteIcon ~= false
    if plateData.border and plateData.border.Show then
        if plateData.border.SetAlpha then
            plateData.border:SetAlpha(1)
        end
        plateData.border:Show()
    end
    if plateData.healthBar then
        NP.native_style.RestoreStatusBarVisual(plateData.healthBar)
        if plateData.healthBar.Show then plateData.healthBar:Show() end
    end
    if plateData.castBar then
        if plateData.castBar.SetAlpha then plateData.castBar:SetAlpha(1) end
        if plateData.castBar.Show then plateData.castBar:Show() end
    end
    if plateData.castBarBorder and plateData.castBarBorder.Show then
        plateData.castBarBorder:Show()
    end
    if plateData.castBarShield and plateData.castBarShield.Show then
        plateData.castBarShield:Show()
    end
    if plateData.castBarIcon and plateData.castBarIcon.Show then
        if plateData.castBarIcon.SetAlpha then plateData.castBarIcon:SetAlpha(1) end
        plateData.castBarIcon:Show()
    end
    if plateData.castBar and plateData.castBar.GetNumRegions and plateData.castBar.GetRegions then
        local statusTex = plateData.castBar.GetStatusBarTexture
            and plateData.castBar:GetStatusBarTexture() or nil
        for i = 1, plateData.castBar:GetNumRegions() do
            local region = select(i, plateData.castBar:GetRegions())
            if region and region ~= statusTex
                and region.GetObjectType and region:GetObjectType() == "Texture" then
                if region.SetAlpha then region:SetAlpha(1) end
                if region.Show then region:Show() end
            end
        end
    end
    if plateData.highlight then
        if plateData.highlight.SetAlpha then plateData.highlight:SetAlpha(1) end
    end
    RestoreNativeFontString(plateData.ogNameText, plate)
    if plateData.ogNameText and plateData.ogNameText.SetText and plateData.plateName then
        plateData.ogNameText:SetText(plateData.plateName)
    end
    RestoreNativeFontString(plateData.levelText, plate)
    if NP.widgets and NP.widgets.RestoreNativeRaidIcon then
        NP.widgets.RestoreNativeRaidIcon(plateData)
    end
    if showElite then
        -- SuppressNativePlateIcon left alpha at 0; Show alone is not enough.
        if plateData.eliteIcon then
            if plateData.eliteIcon.SetAlpha then plateData.eliteIcon:SetAlpha(1) end
            if plateData.eliteIcon.Show then plateData.eliteIcon:Show() end
        end
        if plateData.bossIcon then
            if plateData.bossIcon.SetAlpha then plateData.bossIcon:SetAlpha(1) end
            if plateData.bossIcon.Show then plateData.bossIcon:Show() end
        end
    else
        NP.native_style.HideRegion(plateData.bossIcon)
        NP.native_style.HideRegion(plateData.eliteIcon)
    end
    if plateData.threat then
        if plateData.threat.SetTexCoord then
            plateData.threat:SetTexCoord(0, 1, 0, 1)
        end
        if plateData.threat.SetAlpha then
            plateData.threat:SetAlpha(1)
        end
        if plateData.threat.Show then
            plateData.threat:Show()
        end
    end
end
