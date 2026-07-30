local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const

-- Nameplates layout: mina stack, depth sort, stacking, clamp.
-- Cross-plate depth bands are managed here; visual alpha remains engine-owned.

NP.layout = NP.layout or {}

local RETAIL_STACK_YSPEED = 3
local RETAIL_STACK_DELTA = RETAIL_STACK_YSPEED
local RETAIL_STACK_RESET_FACTOR = 1
local RETAIL_STACK_RAISE_FACTOR = 1
local RETAIL_STACK_LOWER_FACTOR = 0.8
local DEPTH_SORT_INTERVAL = 0.05
-- Step must exceed max internal offset (incl. minaDebuffHost's own +1/+3
-- sub-levels below) to avoid interleaving adjacent plates.
local DEPTH_LEVEL_STEP = 16

-- Per-plate frame-level offsets within the visual band.
local LEVEL_OFFSETS = {
    minaHp = 1,
    minaPo = 1,
    minaCast = 2,
    minaPartyCast = 2,
    minaNameRow = 3,
    minaPoTextRow = 4,
    -- Reserved above every other sibling: ApplyDebuffIconFrameLevels stacks
    -- icon (+1) and text (+3) off this value, which must clear minaTarget.
    minaDebuffHost = 9,
    _comboHost = 5,
    -- Target highlight above bar chrome and overlays.
    minaTarget = 6,
}
local BGH_FRAME_OFFSET = 4

-- Reused across UpdateDepthOrdering ticks to avoid per-frame table churn at
-- 20 Hz; wiped at the start of each pass.
local depthOrdered = {}
local depthDepths = {}
local function DepthSortComparator(a, b)
    return (depthDepths[a] or 0) > (depthDepths[b] or 0)
end

local function SetDepthFrameLevel(plateData, frame, level)
    if not plateData or not frame or not frame.SetFrameLevel then return end
    local originalLevels = plateData._depthOriginalLevels
    if not originalLevels then
        originalLevels = setmetatable({}, { __mode = "k" })
        plateData._depthOriginalLevels = originalLevels
    end
    if originalLevels[frame] == nil and frame.GetFrameLevel then
        originalLevels[frame] = frame:GetFrameLevel()
    end
    -- SetFrameLevel re-layers the strata's frame list (real cost); skip it when
    -- the frame already sits at the target level. GetFrameLevel is a cheap getter.
    if not frame.GetFrameLevel or frame:GetFrameLevel() ~= level then
        frame:SetFrameLevel(level)
    end
    plateData._depthOrderingApplied = true
end

function NP.layout.RestorePlateDepthOrdering(plateData)
    if not plateData then return end
    local originalLevels = plateData._depthOriginalLevels
    if originalLevels then
        for frame, level in pairs(originalLevels) do
            if frame and frame.SetFrameLevel then
                frame:SetFrameLevel(level)
            end
        end
        plateData._depthOriginalLevels = nil
    end
    if plateData.minaDebuffHost
        and NP.auras and NP.auras.ApplyDebuffIconFrameLevels then
        NP.auras.ApplyDebuffIconFrameLevels(plateData.minaDebuffHost)
    end
    plateData._depthOrderingApplied = nil
    plateData._depthAppliedIndex = nil
    plateData._depthAppliedCfgRev = nil
end

local function RestoreDepthFrameLevels()
    for _, plateData in pairs(NP.module.plates) do
        NP.layout.RestorePlateDepthOrdering(plateData)
    end
end

function NP.layout.RestoreDepthOrdering()
    RestoreDepthFrameLevels()
    NP.module._depthOrderingApplied = nil
    NP.module._depthSortElapsed = 0
end

-- BattleGroundHealers compatibility

local BGH_ICON_ANCHORS = {
    left = { anchorPoint = "RIGHT", relativePoint = "LEFT" },
    top = { anchorPoint = "BOTTOM", relativePoint = "TOP" },
    right = { anchorPoint = "LEFT", relativePoint = "RIGHT" },
    bottom = { anchorPoint = "TOP", relativePoint = "BOTTOM" },
}

local function GetBGHIconAnchor(key)
    local anchorKey = key and string.lower(key) or "top"
    return BGH_ICON_ANCHORS[anchorKey] or BGH_ICON_ANCHORS.top
end

-- BGH 1.6.0 made SetBGHmark local, so the test preview drives the plate's own icon directly.
local BGH_TEST_TEXTURES = {
    Blizzlike = {
        Blue = "Interface\\AddOns\\BattleGroundHealers\\Artwork\\BlizzBlueIcon.tga",
        Red = "Interface\\AddOns\\BattleGroundHealers\\Artwork\\BlizzRedIcon.tga",
    },
    Minimalist = {
        Blue = "Interface\\AddOns\\BattleGroundHealers\\Artwork\\MiniBlueIcon.tga",
        Red = "Interface\\AddOns\\BattleGroundHealers\\Artwork\\MiniRedIcon.tga",
    },
}

local function GetBGHTestTexture(reaction)
    local settings = _G.BGHsettings
    local set = BGH_TEST_TEXTURES[settings and settings.iconStyle] or BGH_TEST_TEXTURES.Blizzlike
    local invert = settings and settings.iconInvertColor == 1
    if reaction == "ENEMY" then
        return invert and set.Blue or set.Red
    end
    return invert and set.Red or set.Blue
end

local function HideBGHTestIcon(bghFrame)
    if bghFrame and bghFrame.icon then
        bghFrame.icon:SetTexture(nil)
        bghFrame.icon:Hide()
    end
end

function NP.layout.SetBGHTestMark(name, reaction)
    if not name or name == "" then
        return
    end
    NP.module.bghTestMarks = NP.module.bghTestMarks or {}
    NP.module.bghTestMarks[name] = reaction
    for _, plateData in pairs(NP.module.plates) do
        local plate = plateData and plateData.plate
        local bghFrame = plate and plate.BGHframe
        if bghFrame and bghFrame.activeName == name then
            if reaction then
                NP.layout.ApplyBattleGroundHealersCompat(plateData)
            else
                HideBGHTestIcon(bghFrame)
            end
        end
    end
end

function NP.layout.ClearBGHTestMarks()
    local marks = NP.module.bghTestMarks
    if not marks then
        return
    end
    for _, plateData in pairs(NP.module.plates) do
        local plate = plateData and plateData.plate
        local bghFrame = plate and plate.BGHframe
        if bghFrame and bghFrame.activeName and marks[bghFrame.activeName] then
            HideBGHTestIcon(bghFrame)
        end
    end
    for name in pairs(marks) do
        marks[name] = nil
    end
end

function NP.layout.ApplyBattleGroundHealersCompat(plateData)
    if not plateData or not plateData.plate then
        return
    end

    local plate = plateData.plate
    local bghFrame = plate.BGHframe
    if not NP.config.IsBGHCompatEnabled() then
        if bghFrame and bghFrame.ModifyIcon then
            bghFrame:ModifyIcon()
        else
            plate.shouldModifyBGH = nil
        end
        plateData._bghCompatApplied = nil
        return
    end

    local cfg = NP.config.GetCfg()
    local anchor = GetBGHIconAnchor(cfg.bghIconAnchor)
    local iconSize = cfg.bghIconSize or 24
    local offsetX = cfg.bghIconOffsetX or 0
    local offsetY = cfg.bghIconOffsetY or 0
    local relativeFrame = plateData.minaNameRow or plateData.minaName or plate

    if bghFrame and bghFrame.ModifyIcon then
        bghFrame:ModifyIcon(
            true,
            plate,
            iconSize,
            anchor.anchorPoint,
            relativeFrame,
            anchor.relativePoint,
            offsetX,
            offsetY
        )
        if bghFrame.SetFrameLevel then
            local base = (plateData.visualRoot and plateData.visualRoot:GetFrameLevel())
                or (plate:GetFrameLevel() or 0)
            bghFrame:SetFrameLevel(base + BGH_FRAME_OFFSET)
        end
    else
        plate.shouldModifyBGH = {
            true,
            plate,
            iconSize,
            anchor.anchorPoint,
            relativeFrame,
            anchor.relativePoint,
            offsetX,
            offsetY,
        }
    end

    plateData._bghCompatApplied = true

    if cfg.bghTestMode and bghFrame and bghFrame.icon and bghFrame.activeName then
        local marks = NP.module.bghTestMarks
        local reaction = marks and marks[bghFrame.activeName]
        if reaction then
            bghFrame.icon:SetTexture(GetBGHTestTexture(reaction))
            bghFrame.icon:Show()
        end
    end
end

-- Depth sort (owns cross-plate frame-level bands)

function NP.layout.UpdateDepthOrdering(elapsed)
    local cfg = NP.config.GetCfg()
    if cfg.depthSortingEnabled == false then
        NP.module._depthSortElapsed = 0
        if NP.module._depthOrderingApplied then
            NP.layout.RestoreDepthOrdering()
        end
        return
    end
    NP.module._depthSortElapsed = (NP.module._depthSortElapsed or 0) + (elapsed or 0)
    if NP.module._depthSortElapsed < DEPTH_SORT_INTERVAL then
        return
    end
    NP.module._depthSortElapsed = 0

    local ordered = depthOrdered
    local depths = depthDepths
    wipe(ordered)
    wipe(depths)

    for _, plateData in pairs(NP.module.plates) do
        local plate = plateData and plateData.plate
        local visual = plateData and (plateData.visualRoot or plate)
        if plate and visual and plate.IsShown and plate:IsShown() and visual.GetEffectiveDepth then
            local depth = visual:GetEffectiveDepth()
            if depth and depth > 0 then
                -- Target sorts on top.
                if NP.identity.IsTargetPlateVisual(plateData) then
                    depth = -1
                end
                ordered[#ordered + 1] = plateData
                depths[plateData] = depth
            end
        end
    end

    table.sort(ordered, DepthSortComparator)

    local cfgRev = NP.module._cfgRev or 0
    for index = 1, #ordered do
        local plateData = ordered[index]
        local plate = plateData.plate
        local base = index * DEPTH_LEVEL_STEP
        -- Skip SetFrameLevel when depth band unchanged; _depthDirty/cfgRev force reapply.
        if plateData._depthAppliedIndex == index
            and plateData._depthAppliedCfgRev == cfgRev
            and not plateData._depthDirty then
            -- Sync BGHframe when attached mid-life.
            if plate and plate.BGHframe and plate.BGHframe.SetFrameLevel then
                SetDepthFrameLevel(plateData, plate.BGHframe, base + BGH_FRAME_OFFSET)
            end
        else
            plateData._depthAppliedIndex = index
            plateData._depthAppliedCfgRev = cfgRev
            plateData._depthDirty = nil
            if cfg.showClickbox == true and plate and plate.SetFrameLevel then
                SetDepthFrameLevel(plateData, plate, base + 1)
            elseif plateData._depthOriginalLevels and plateData._depthOriginalLevels[plate] ~= nil then
                plate:SetFrameLevel(plateData._depthOriginalLevels[plate])
                plateData._depthOriginalLevels[plate] = nil
            end
            if plateData.visualRoot and plateData.visualRoot.SetFrameLevel then
                SetDepthFrameLevel(plateData, plateData.visualRoot, base)
            end
            for key, offset in pairs(LEVEL_OFFSETS) do
                local frame = plateData[key]
                if frame and frame.SetFrameLevel then
                    SetDepthFrameLevel(plateData, frame, base + offset)
                end
            end
            -- Debuff icons are children of minaDebuffHost created after this point;
            -- re-level them so the cooldown swipe stays in the plate's band.
            if plateData.minaDebuffHost and NP.auras and NP.auras.ApplyDebuffIconFrameLevels then
                NP.auras.ApplyDebuffIconFrameLevels(plateData.minaDebuffHost)
            end
            if plate and plate.BGHframe and plate.BGHframe.SetFrameLevel then
                SetDepthFrameLevel(plateData, plate.BGHframe, base + BGH_FRAME_OFFSET)
            end
            if plateData.minaCastSpark and plateData.minaCastSpark.SetFrameLevel and plateData.minaCast then
                SetDepthFrameLevel(plateData, plateData.minaCastSpark,
                    (plateData.minaCast:GetFrameLevel() or (base + 2)) + 3)
            end
            if plateData.minaCast and plateData.minaCast.minaCastShield
                and plateData.minaCast.minaCastShield.SetFrameLevel then
                SetDepthFrameLevel(plateData, plateData.minaCast.minaCastShield,
                    (plateData.minaCast:GetFrameLevel() or (base + 2)) - 1)
            end
        end
        NP.module._depthOrderingApplied = true
    end
end

-- Visual alpha (engine-owned)

-- Hoisted for engine visual-alpha pass; row children inherit row alpha.
local VISUAL_ALPHA_FIELDS = {
    "minaNameRow",
    "minaHp",
    "minaPo",
    "minaTarget",
    "minaHpNum",
    "minaHpBarPct",
    "minaHpTextRow",
    "minaPoCur",
    "minaPoPct",
    "minaPoTextRow",
    "minaDebuffHost",
    "_comboHost",
    "_eliteIcon",
    "_totemIcon",
    "minaThreatTex",
}

local function KeepNameRowChildOpaque(fs)
    if fs and fs.SetAlpha then
        fs:SetAlpha(1)
    end
end

function NP.layout.SetPlateVisualAlpha(plateData, alpha)
    if not plateData then return end
    alpha = alpha or 1

    -- Compensate for plate native alpha: effective = native * frame.
    local nativeAlpha = plateData._nativeAlpha or 1.0
    if nativeAlpha < 0.01 then nativeAlpha = 1.0 end
    local compensatedAlpha = alpha / nativeAlpha
    if compensatedAlpha > 1.0 then compensatedAlpha = 1.0 end

    local last = plateData._lastAppliedVisualAlpha
    if not last or math.abs(last - compensatedAlpha) >= 0.005 then
        plateData._lastAppliedVisualAlpha = compensatedAlpha

        for i = 1, #VISUAL_ALPHA_FIELDS do
            local obj = plateData[VISUAL_ALPHA_FIELDS[i]]
            if obj and obj.SetAlpha then
                obj:SetAlpha(compensatedAlpha)
            end
        end
        KeepNameRowChildOpaque(plateData.minaName)
        KeepNameRowChildOpaque(plateData.minaHpPct)
        KeepNameRowChildOpaque(plateData.minaSubTitle)
        KeepNameRowChildOpaque(plateData.minaBossSkull)
    end

    -- Cast sync may reset bar alpha; re-apply after engine step 7.
    local cast = plateData.minaCast
    if cast and cast.SetAlpha and not cast._interruptFadeActive then
        local castAlpha = cast:GetAlpha() or 1
        if math.abs(castAlpha - compensatedAlpha) >= 0.005 then
            cast:SetAlpha(compensatedAlpha)
        end
    end
    local partyCast = plateData.minaPartyCast
    if partyCast and partyCast.SetAlpha and not partyCast._interruptFadeActive then
        local partyAlpha = partyCast:GetAlpha() or 1
        if math.abs(partyAlpha - compensatedAlpha) >= 0.005 then
            partyCast:SetAlpha(compensatedAlpha)
        end
    end
end

function NP.layout.HideMinaStack(plateData)
    if not plateData then return end
    local hideTargets = {
        plateData.minaNameRow,
        plateData.minaHp,
        plateData.minaPo,
        plateData.minaTarget,
        plateData.minaName,
        plateData.minaSubTitle,
        plateData.minaBossSkull,
        plateData.minaHpPct,
        plateData.minaHpNum,
        plateData.minaHpBarPct,
        plateData.minaHpTextRow,
        plateData.minaPoCur,
        plateData.minaPoPct,
        plateData.minaPoTextRow,
        plateData.minaDebuffHost,
        plateData._comboHost,
        plateData._eliteIcon,
        plateData._totemIcon,
        plateData.minaPartyCast,
        plateData.minaThreatTex,
    }
    for i = 1, #hideTargets do
        local obj = hideTargets[i]
        if obj and obj.Hide then
            obj:Hide()
        end
    end
    if plateData.minaCast and plateData.minaCast.Hide then
        plateData.minaCast:Hide()
    end
end

-- Retail plate scale

-- isTarget bool avoids per-frame context table allocation.
function NP.layout.ApplyRetailPlateScale(plateData, isTarget, cfg)
    cfg = cfg or NP.config.GetCfg()
    local scale = 1
    local targetScale = cfg.retailTargetScale or 1
    local friendlyScale = cfg.retailFriendlyScale or 1
    local reaction = NP.native_style.GetPlateReaction(plateData)
    local isFriendly = reaction == "FRIENDLY"

    if isFriendly then
        scale = scale * friendlyScale
    end
    if isTarget then
        scale = scale * targetScale
    end

    if not plateData or not plateData.plate then return end
    if plateData._retailScale == scale and plateData._pendingRetailScale == nil then return end
    NP.layout.SetRetailPlateScale(plateData, scale)
end

function NP.layout.SetRetailPlateScale(plateData, scale)
    if not plateData or not plateData.plate then return end
    scale = scale or 1
    if InCombatLockdown() then
        plateData._pendingRetailScale = scale
        NP.module._layoutPending = true
        return
    end
    plateData._pendingRetailScale = nil
    plateData._retailScale = (scale ~= 1) and scale or nil
    plateData.plate:SetScale(scale)
end

-- Runtime stacking and clamping

local function EnsureRetailStackState(plateData)
    NP.module._retailStackData = NP.module._retailStackData or setmetatable({}, { __mode = "k" })
    local data = NP.module._retailStackData[plateData]
    if not data then
        data = { position = 0, xpos = 0, ypos = 0 }
        NP.module._retailStackData[plateData] = data
    end
    return data
end

-- bossIcon IsShown() marks true worldboss (UnitClassification == "worldboss") only.
-- 3.3.5a has no separate dungeon-boss class; elite trash must not clamp as boss.
-- Boss detect: native bossIcon IsShown() and/or UnitLevel == -1 (independent of level display).
function NP.layout.PlateHasBossIcon(plateData)
    if not plateData then return false end
    local icon = plateData.bossIcon
    if icon and icon.IsShown and icon:IsShown() then
        return true
    end
    local unit = NP.identity and NP.identity.ResolvePlateCastUnit
        and NP.identity.ResolvePlateCastUnit(plateData)
    if unit and UnitExists(unit) and NP.native_style.IsBossLevel(UnitLevel(unit)) then
        return true
    end
    return false
end

local function PlateWantsClamp(plateData)
    if not plateData or not plateData.plate then
        return false
    end
    local reaction = NP.native_style.GetPlateReaction(plateData)
    if reaction == "FRIENDLY" then
        return false
    end
    if NP.module._clampTargetEnabled and NP.identity.IsTargetPlate(plateData) then
        return true
    end
    -- Boss clamp targets open-world worldboss; no in-instance gate.
    if NP.module._clampBossEnabled and NP.layout.PlateHasBossIcon(plateData) then
        return true
    end
    return false
end

-- Skip clamp writes when unchanged (SetClampRectInsets invalidates layout).
local function SetPlateClamp(plateData, plate, clamped, l, r, t, b)
    if plateData._clampAppliedState == clamped
        and plateData._clampAppliedL == l and plateData._clampAppliedR == r
        and plateData._clampAppliedT == t and plateData._clampAppliedB == b then
        return
    end
    plateData._clampAppliedState = clamped
    plateData._clampAppliedL, plateData._clampAppliedR = l, r
    plateData._clampAppliedT, plateData._clampAppliedB = t, b
    plate:SetClampedToScreen(clamped)
    plate:SetClampRectInsets(l, r, t, b)
end

-- Simple clamp (no retail stacking).
-- Reapply every frame: recycled frames do not preserve clamp state.
-- Bottom inset is anchor-relative, not screen pixels (plates sit in extended WorldFrame).
local function ApplySimpleClamp(plateData)
    local plate = plateData.plate
    if not plate or not plate.SetClampedToScreen or not plate.GetPoint then return end

    local want = PlateWantsClamp(plateData)
    plateData._clamped = want

    if want then
        local width, height = plate:GetSize()
        local _, _, _, _, y = plate:GetPoint(1)
        y = y or 0
        SetPlateClamp(plateData, plate, true,
            0.5 * width, -0.5 * width, NP.module._clampTopInset or 0, height - y)
    else
        SetPlateClamp(plateData, plate, false, 0, 0, 0, 0)
    end
end

local function ClearRetailStackingForPlate(plateData, data)
    if data then
        data.position = 0
        data.xpos = 0
        data.ypos = 0
    end
    if not plateData or not plateData._retailStackingApplied then
        return
    end
    local plate = plateData.plate
    if plate and plate.SetClampRectInsets and plate.SetClampedToScreen then
        SetPlateClamp(plateData, plate, false, 0, 0, 0, 0)
        plateData._clamped = nil
        plateData._retailStackingApplied = nil
    end
end

function NP.layout.ResetRetailStacking()
    if not NP.module._retailStackData then return end
    for plateData, data in pairs(NP.module._retailStackData) do
        ClearRetailStackingForPlate(plateData, data)
    end
end

function NP.layout.ShouldRunRetailStacking()
    if not NP.config.IsRetailBehavior() then
        return false
    end
    local cfg = NP.config.GetCfg()
    if cfg.retailStackingEnabled ~= true then
        return false
    end
    if cfg.retailStackingInInstance and not NP.module.inPvEInstance then
        return false
    end
    return true
end

-- Scratch tables for per-frame stacking passes.
local stackableScratch = {}
local activeStackableScratch = {}

local function UpdateRetailStacking()
    local cfg = NP.config.GetCfg()
    local baseScale = cfg.globalScale or 1
    local xspace = (cfg.retailStackingXSpace or 150) * baseScale
    local yspace = (cfg.retailStackingYSpace or 24) * baseScale
    local originY = cfg.retailStackingOriginY or 0
    local freezeMouseover = cfg.retailStackingFreezeMouseover == true
    local stackable = stackableScratch
    local activeStackable = activeStackableScratch
    wipe(stackable)
    wipe(activeStackable)

    for _, plateData in pairs(NP.module.plates) do
        local plate = plateData and plateData.plate
        local reaction = NP.native_style.GetPlateReaction(plateData)
        local isFriendly = reaction == "FRIENDLY"
        -- Non-friendly plates only.
        if plate and plate.IsShown and plate:IsShown() and not isFriendly then
            stackable[#stackable + 1] = plateData
            activeStackable[plateData] = true
            local state = EnsureRetailStackState(plateData)
            local _, _, _, x, y = plate:GetPoint(1)
            state.xpos = x or state.xpos or 0
            state.ypos = y or state.ypos or 0
        end
    end

    if NP.module._retailStackData then
        for plateData, data in pairs(NP.module._retailStackData) do
            if not activeStackable[plateData] then
                ClearRetailStackingForPlate(plateData, data)
            end
        end
    end

    for i = 1, #stackable do
        local plateData1 = stackable[i]
        local plate1 = plateData1.plate
        local state1 = EnsureRetailStackState(plateData1)
        local width, height = plate1:GetSize()

        local _, _, _, x1, y1 = plate1:GetPoint(1)
        if x1 then state1.xpos = x1 end
        if y1 then state1.ypos = y1 end

        local freeze = false
        if freezeMouseover then
            if plateData1.highlight and plateData1.highlight.IsShown and plateData1.highlight:IsShown() then
                freeze = true
            elseif plate1.IsMouseOver and plate1:IsMouseOver() then
                freeze = true
            end
        end

        if freeze then
            local cx, cy = plate1:GetCenter()
            if cx and cy then
                local newPos = cy - state1.ypos - originY + height * 0.5
                state1.position = newPos
                state1.xpos = cx
                local worldW = NP.module._worldFrameWidth or WorldFrame:GetWidth()
                local worldH = NP.module._worldFrameNativeHeight
                    or (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 768
                SetPlateClamp(plateData1, plate1, true,
                    -2 * worldW, worldW - cx - width * 0.5,
                    worldH - cy - height * 0.5, -2 * worldH)
                plateData1._retailStackingApplied = true
            end
        else
            local minDist = 1000
            local doReset = true

            for j = 1, #stackable do
                if i ~= j then
                    local plateData2 = stackable[j]
                    local state2 = EnsureRetailStackState(plateData2)
                    local xdiff = state1.xpos - state2.xpos
                    local ydiff = state1.ypos + state1.position - state2.ypos - state2.position
                    local ydiffOrigin = state1.ypos - state2.ypos - state2.position
                    if math.abs(xdiff) < xspace then
                        if ydiff >= 0 and math.abs(ydiff) < minDist then
                            minDist = math.abs(ydiff)
                        end
                        if math.abs(ydiffOrigin) < yspace then
                            doReset = false
                        end
                    end
                end
            end

            local oldPos = state1.position or 0
            local newPos = oldPos

            if oldPos >= RETAIL_STACK_DELTA and doReset then
                newPos = oldPos - math.exp(-10 / oldPos) * RETAIL_STACK_YSPEED * RETAIL_STACK_RESET_FACTOR
            elseif minDist < yspace then
                newPos = oldPos + math.exp(-minDist / yspace) * RETAIL_STACK_YSPEED * RETAIL_STACK_RAISE_FACTOR
            elseif oldPos >= RETAIL_STACK_DELTA and minDist > (yspace + RETAIL_STACK_DELTA) then
                newPos = oldPos - math.exp(-yspace / minDist) * RETAIL_STACK_YSPEED * RETAIL_STACK_LOWER_FACTOR
            end

            state1.position = newPos
            -- Clamp target/boss merged into stacking insets.
            if PlateWantsClamp(plateData1) then
                SetPlateClamp(plateData1, plate1, true, 0.5 * width, -0.5 * width,
                    NP.module._clampTopInset or 0, -state1.ypos - newPos - originY + height)
            else
                SetPlateClamp(plateData1, plate1, true, 0.5 * width, -0.5 * width,
                    -height, -state1.ypos - newPos - originY + height)
            end
            plateData1._retailStackingApplied = true
        end
    end
end

-- Per-frame stacking/clamp entry.
function NP.layout.UpdateStacking()
    if NP.layout.ShouldRunRetailStacking() then
        UpdateRetailStacking()
        return
    end
    NP.layout.ResetRetailStacking()
    if NP.module._clampTargetEnabled or NP.module._clampBossEnabled then
        for _, plateData in pairs(NP.module.plates) do
            local plate = plateData.plate
            if plate and plate.IsShown and plate:IsShown() then
                ApplySimpleClamp(plateData)
            end
        end
    else
        for _, plateData in pairs(NP.module.plates) do
            if plateData._clamped then
                ApplySimpleClamp(plateData)
            end
        end
    end
end

-- Fonts

-- Fallback chain in case fontPath's file is missing on disk (avoids "Font not set").
local function SafeSetFont(fs, path, size, flags)
    if not fs then return end
    flags = flags or ""
    if fs:SetFont(path, size, flags) then return end
    if STANDARD_TEXT_FONT and fs:SetFont(STANDARD_TEXT_FONT, size, flags) then return end
    fs:SetFont("Fonts\\FRIZQT__.TTF", size, flags)
end
NP.layout.SafeSetFont = SafeSetFont

function NP.layout.ApplyNameplateFonts(plateData)
    local nameSize, powerSize = NP.config.GetNameplateFontSizes()
    local fontPath = NP.config.GetNameplateFont()

    local function applyFont(fs, px)
        if not fs then return end
        SafeSetFont(fs, fontPath, px, "")
    end

    local cfg = NP.config.GetCfg()
    local hpNumSize = 7 + (cfg.healthNumberFontSize or 2)
    applyFont(plateData.minaName, nameSize)
    applyFont(plateData.minaHpPct, nameSize)
    applyFont(plateData.minaSubTitle, math.max(8, nameSize - 2))
    applyFont(plateData.minaHpNum, hpNumSize)
    applyFont(plateData.minaHpBarPct, hpNumSize)
    applyFont(plateData.minaPoCur, powerSize)
    applyFont(plateData.minaPoPct, powerSize)
    local cast = plateData.minaCast
    if cast and cast.minaCastSpellName then
        local fs = cast.minaCastSpellName
        SafeSetFont(fs, fontPath, cfg.castBarSpellNameFontSize or 9, "OUTLINE")
        local offX = cfg.castBarSpellNameOffsetX or 0
        local offY = cfg.castBarSpellNameOffsetY or 0
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", cast, "LEFT", 4 + offX, offY)
        fs:SetPoint("RIGHT", cast, "RIGHT", -4 + offX, offY)
    end

    local rowH = math.max(10, nameSize + 1)
    if plateData.minaName then
        plateData.minaName:SetHeight(rowH)
    end
    if plateData.minaHpPct then
        plateData.minaHpPct:SetHeight(rowH)
    end
    if plateData.minaNameRow then
        plateData.minaNameRow:SetHeight(rowH)
    end
end

-- Mina stack construction

-- Frame levels at creation; UpdateDepthOrdering rewrites thereafter.
local function ApplyCreationFrameLevels(plateData)
    if plateData._levelsApplied then return end
    local visualRoot = plateData.visualRoot
    if not visualRoot then return end
    local base = visualRoot:GetFrameLevel() or 0
    for key, offset in pairs(LEVEL_OFFSETS) do
        local frame = plateData[key]
        if frame and frame.SetFrameLevel then
            frame:SetFrameLevel(base + offset)
        end
    end
    plateData._levelsApplied = true
end

-- Skips redundant font/raid-marker re-apply; signature covers every input ReflowTopOverlays reads.
local function StyledChromeUnchanged(plateData)
    local cfgRev = NP.module._cfgRev or 0
    local comboVisible = (plateData._comboHost and plateData._comboHost.IsShown
        and plateData._comboHost:IsShown()) and true or false
    local headline = (NP.gather.IsHeadlineActive and NP.gather.IsHeadlineActive(plateData)) and true or false
    local reaction = NP.native_style.GetPlateReaction(plateData) or false

    if plateData._styledChromeCfgRev == cfgRev
        and plateData._styledChromeCombo == comboVisible
        and plateData._styledChromeHeadline == headline
        and plateData._styledChromeReaction == reaction then
        return true
    end

    plateData._styledChromeCfgRev = cfgRev
    plateData._styledChromeCombo = comboVisible
    plateData._styledChromeHeadline = headline
    plateData._styledChromeReaction = reaction
    return false
end

local function EnsureBossSkullTexture(plateData)
    if not plateData or not plateData.minaNameRow or plateData.minaBossSkull then
        return
    end
    local skull = plateData.minaNameRow:CreateTexture(nil, "OVERLAY")
    skull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    skull:Hide()
    plateData.minaBossSkull = skull
end

function NP.layout.EnsureMinaStack(plateData)
    local plate = plateData.plate
    if not plate then return end
    local baseW = plateData._clickboxBaseW or (plate.GetWidth and plate:GetWidth()) or 120
    local baseH = plateData._clickboxBaseH or (plate.GetHeight and plate:GetHeight()) or 20

    if not plateData.visualRoot then
        plateData.visualRoot = CreateFrame("Frame", nil, plate)
        plateData.visualRoot:SetPoint("TOP", plate, "TOP", 0, 0)
        plateData.visualRoot:SetSize(baseW, baseH)
    end
    local visualRoot = plateData.visualRoot

    if not plateData.minaNameRow then
        plateData.minaNameRow = CreateFrame("Frame", nil, visualRoot)
        plateData.minaNameRow:SetHeight(12)
    end
    EnsureBossSkullTexture(plateData)

    if not plateData.minaCast then
        plateData.minaCast = NP.castbar.CreateCastMinaBar(visualRoot, plateData)
        plateData.minaCast:Hide()
        -- New frame; mark depth dirty for next pass.
        plateData._depthDirty = true
    end

    if not plateData.minaPartyCast then
        plateData.minaPartyCast = NP.castbar.CreatePartyCastBar(visualRoot, plateData)
        plateData._depthDirty = true
    end

    if plateData.minaHp then
        ApplyCreationFrameLevels(plateData)
        if not StyledChromeUnchanged(plateData) then
            NP.widgets.LayoutRaidMarker(plateData)
            NP.layout.ApplyNameplateFonts(plateData)
        end
        return
    end

    plateData.minaHp = NP.discovery.CreateMinaBar(visualRoot, C.MINA_TEX .. "bar-fill", 1, 0.1, 0.1)
    plateData.minaPo = NP.discovery.CreateMinaBar(visualRoot, C.MINA_TEX .. "bar-fill", 0, 0.5, 1)
    plateData.minaPo:Hide()

    plateData.minaTarget = CreateFrame("Frame", nil, visualRoot)
    -- Visual only; no mouse capture.
    plateData.minaTarget:EnableMouse(false)
    local targetTex = plateData.minaTarget:CreateTexture(nil, "OVERLAY")
    targetTex:SetAllPoints(plateData.minaTarget)
    targetTex:SetTexture(C.MINA_TEX .. "bar-target")
    plateData.minaTarget.tex = targetTex

    plateData.minaTarget.arrowL = plateData.minaTarget:CreateTexture(nil, "ARTWORK")
    plateData.minaTarget.arrowL:SetTexture(C.MINA_TEX .. "arrowright")
    plateData.minaTarget.arrowL:SetSize(20, 20)
    plateData.minaTarget.arrowL:SetPoint("RIGHT", plateData.minaTarget, "LEFT", -2, 0)

    plateData.minaTarget.arrowR = plateData.minaTarget:CreateTexture(nil, "ARTWORK")
    plateData.minaTarget.arrowR:SetTexture(C.MINA_TEX .. "arrowleft")
    plateData.minaTarget.arrowR:SetSize(20, 20)
    plateData.minaTarget.arrowR:SetPoint("LEFT", plateData.minaTarget, "RIGHT", 2, 0)
    plateData.minaTarget:Hide()

    local fontPath = NP.config.GetNameplateFont()
    local nameSize = select(1, NP.config.GetNameplateFontSizes())

    plateData.minaName = plateData.minaNameRow:CreateFontString(nil, "OVERLAY")
    SafeSetFont(plateData.minaName, fontPath, nameSize, "")
    plateData.minaName:SetShadowOffset(1, -1)
    plateData.minaName:SetShadowColor(0, 0, 0, 1)
    plateData.minaName:SetJustifyH("LEFT")
    plateData.minaName:SetNonSpaceWrap(false)
    plateData.minaName:SetWordWrap(false)
    plateData.minaName:SetHeight(12)

    -- Headline-mode subtitle (guild / AFK for players, title for NPCs). Lives in
    -- minaNameRow so it inherits the row's visual alpha.
    plateData.minaSubTitle = plateData.minaNameRow:CreateFontString(nil, "OVERLAY")
    SafeSetFont(plateData.minaSubTitle, fontPath, math.max(8, nameSize - 2), "")
    plateData.minaSubTitle:SetShadowOffset(1, -1)
    plateData.minaSubTitle:SetShadowColor(0, 0, 0, 1)
    plateData.minaSubTitle:SetJustifyH("CENTER")
    plateData.minaSubTitle:SetNonSpaceWrap(false)
    plateData.minaSubTitle:SetWordWrap(false)
    plateData.minaSubTitle:SetTextColor(0.8, 0.8, 0.8)
    plateData.minaSubTitle:SetWidth(select(1, NP.config.GetBarRefSize()) * 2)
    plateData.minaSubTitle:SetPoint("TOP", plateData.minaName, "BOTTOM", 0, -1)
    plateData.minaSubTitle:Hide()

    plateData.minaHpPct = plateData.minaNameRow:CreateFontString(nil, "OVERLAY")
    SafeSetFont(plateData.minaHpPct, fontPath, nameSize, "")
    plateData.minaHpPct:SetShadowOffset(1, -1)
    plateData.minaHpPct:SetShadowColor(0, 0, 0, 1)
    plateData.minaHpPct:SetJustifyH("RIGHT")
    plateData.minaHpPct:SetNonSpaceWrap(false)
    plateData.minaHpPct:SetWordWrap(false)
    plateData.minaHpPct:SetHeight(12)

    plateData.minaHpNum = visualRoot:CreateFontString(nil, "OVERLAY")
    SafeSetFont(plateData.minaHpNum, fontPath, 9, "")
    plateData.minaHpNum:SetShadowOffset(1, -1)
    plateData.minaHpNum:SetShadowColor(0, 0, 0, 1)
    plateData.minaHpNum:SetJustifyH("LEFT")
    plateData.minaHpNum:SetNonSpaceWrap(false)
    plateData.minaHpNum:SetWordWrap(false)
    plateData.minaHpNum:Hide()

    plateData.minaHpBarPct = visualRoot:CreateFontString(nil, "OVERLAY")
    SafeSetFont(plateData.minaHpBarPct, fontPath, 9, "")
    plateData.minaHpBarPct:SetShadowOffset(1, -1)
    plateData.minaHpBarPct:SetShadowColor(0, 0, 0, 1)
    plateData.minaHpBarPct:SetJustifyH("RIGHT")
    plateData.minaHpBarPct:SetNonSpaceWrap(false)
    plateData.minaHpBarPct:SetWordWrap(false)
    plateData.minaHpBarPct:Hide()

    plateData.minaHpTextRow = CreateFrame("Frame", nil, visualRoot)
    plateData.minaHpTextRow:SetSize(1, 1)
    plateData.minaHpNum:SetParent(plateData.minaHpTextRow)
    plateData.minaHpBarPct:SetParent(plateData.minaHpTextRow)

    plateData.minaPoCur = visualRoot:CreateFontString(nil, "OVERLAY")
    SafeSetFont(plateData.minaPoCur, fontPath, 9, "")
    plateData.minaPoCur:SetShadowOffset(1, -1)
    plateData.minaPoCur:SetShadowColor(0, 0, 0, 1)
    plateData.minaPoCur:SetJustifyH("LEFT")

    plateData.minaPoPct = visualRoot:CreateFontString(nil, "OVERLAY")
    SafeSetFont(plateData.minaPoPct, fontPath, 9, "")
    plateData.minaPoPct:SetShadowOffset(1, -1)
    plateData.minaPoPct:SetShadowColor(0, 0, 0, 1)
    plateData.minaPoPct:SetJustifyH("RIGHT")

    plateData.minaPoTextRow = CreateFrame("Frame", nil, visualRoot)
    plateData.minaPoTextRow:SetSize(1, 1)
    plateData.minaPoCur:SetParent(plateData.minaPoTextRow)
    plateData.minaPoPct:SetParent(plateData.minaPoTextRow)

    plateData.minaThreatTex = visualRoot:CreateTexture(nil, "BACKGROUND")
    plateData.minaThreatTex:SetTexture(C.MINA_TEX .. "combat-glow")
    plateData.minaThreatTex:SetVertexColor(1, 0, 0, 1)
    plateData.minaThreatTex:SetBlendMode("ADD")
    plateData.minaThreatTex:Hide()

    plateData.minaDebuffHost = CreateFrame("Frame", nil, visualRoot)
    plateData.minaDebuffHost.icons = {}

    ApplyCreationFrameLevels(plateData)
    plateData._depthDirty = true
end

-- Elite icon Y: name row above bar, or overlay offset when name sits on bar.
function NP.layout.GetNameOverlayIconY()
    local cfg = NP.config.GetCfg()
    local base = (cfg.nameOverlayHealthBar == true) and (cfg.nameOverlayOffsetY or 0) or 14
    return base + (cfg.eliteIconOffsetY or 0)
end

function NP.layout.LayoutMinaStack(plateData)
    local border = plateData.border
    local hp = plateData.minaHp
    local po = plateData.minaPo
    local target = plateData.minaTarget
    if not border or not hp or not po then return end

    local visW, barH = NP.config.GetBarRefSize()
    local ox, oy = NP.config.GetStackOffset()
    local visualRoot = plateData.visualRoot or plateData.plate
    local plate = plateData.plate
    local cfg = NP.config.GetCfg()
    if visualRoot and visualRoot.SetPoint then
        visualRoot:ClearAllPoints()
        visualRoot:SetPoint("TOP", plate, "TOP", 0, 0)
    end

    hp:ClearAllPoints()
    hp:SetSize(visW, barH)
    hp:SetPoint("CENTER", visualRoot, "CENTER", ox, oy)
    if hp.minaBg then
        local bgTex = (cfg.healthBarBackground == "castbar") and "bar-bg" or "bar-bg-health"
        hp.minaBg:SetTexture(C.MINA_TEX .. bgTex)
    end

    po:ClearAllPoints()
    po:SetSize(visW, barH)
    local stackGap = NP.config.GetStackBarGap()
    po:SetPoint("TOP", hp, "BOTTOM", 0, -stackGap)
    if po.minaBg then
        local poBgTex = (cfg.powerBarBackground == "castbar") and "bar-bg" or "bar-bg-power"
        po.minaBg:SetTexture(C.MINA_TEX .. poBgTex)
    end

    if target then
        target:ClearAllPoints()
        target:SetSize(visW + 1, barH + 1)
        target:SetPoint("CENTER", hp, "CENTER", 0, 0)
        local arrowSize = math.max(barH * 2, 14)
        target.arrowL:SetSize(arrowSize, arrowSize)
        target.arrowR:SetSize(arrowSize, arrowSize)
    end

    if plateData.minaThreatTex then
        plateData.minaThreatTex:ClearAllPoints()
        plateData.minaThreatTex:SetPoint("TOPLEFT", hp, "TOPLEFT", -C.THREAT_GLOW_W, C.THREAT_GLOW_H + C.THREAT_GLOW_Y)
        plateData.minaThreatTex:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", C.THREAT_GLOW_W, -C.THREAT_GLOW_H + C.THREAT_GLOW_Y)
        plateData.minaThreatTex:SetDrawLayer("BACKGROUND", 1)
    end

    local nameOverlay = cfg.nameOverlayHealthBar == true
    local nameOverlayY = cfg.nameOverlayOffsetY or 0
    local padX = cfg.nameRowPaddingX or 0

    if plateData.minaNameRow then
        plateData.minaNameRow:ClearAllPoints()
        plateData.minaNameRow:SetHeight(math.max(10, barH + 2))
        if nameOverlay then
            plateData.minaNameRow:SetPoint("LEFT", hp, "LEFT", padX, nameOverlayY)
            plateData.minaNameRow:SetPoint("RIGHT", hp, "RIGHT", -padX, nameOverlayY)
        else
            plateData.minaNameRow:SetPoint("BOTTOMLEFT", hp, "TOPLEFT", padX, 3)
            plateData.minaNameRow:SetPoint("BOTTOMRIGHT", hp, "TOPRIGHT", -padX, 3)
        end
    end
    -- Child widths use row width minus padding.
    visW = visW - (padX * 2)

    if plateData.minaName and plateData.minaNameRow then
        if plateData.minaName.SetParent then
            plateData.minaName:SetParent(plateData.minaNameRow)
        end
        plateData.minaName:ClearAllPoints()
        -- Invalidate SyncName's center-anchor guard; this pass re-anchors it.
        plateData._nameCenteredWidth = nil
        if cfg.centerNameOnly then
            plateData.minaName:SetJustifyH("CENTER")
            plateData.minaName:SetPoint("CENTER", plateData.minaNameRow, "CENTER", 0, 0)
            plateData.minaName:SetWidth(visW)
            plateData._nameBossShift = nil
        else
            plateData.minaName:SetJustifyH("LEFT")
            plateData.minaName:SetPoint("LEFT", plateData.minaNameRow, "LEFT", 0, 0)
            plateData._nameBossShift = nil
            -- showHealthNumber moves the percent text into the bar, hiding minaHpPct here.
            local reserveForPct = cfg.showHealthPercent ~= false and cfg.showHealthNumber ~= true
            local nameWidth = reserveForPct and visW * 0.68 or visW
            plateData.minaName:SetWidth(nameWidth)
        end
    end
    if plateData.minaBossSkull and plateData.minaNameRow then
        local skullSize = 14
        plateData.minaBossSkull:SetSize(skullSize, skullSize)
        plateData.minaBossSkull:ClearAllPoints()
        plateData.minaBossSkull:SetPoint("LEFT", plateData.minaNameRow, "LEFT", 0, 0)
        plateData.minaBossSkull:Hide()
    end

    if plateData.minaHpPct and plateData.minaNameRow then
        if plateData.minaHpPct.SetParent then
            plateData.minaHpPct:SetParent(plateData.minaNameRow)
        end
        plateData.minaHpPct:ClearAllPoints()
        plateData.minaHpPct:SetPoint("RIGHT", plateData.minaNameRow, "RIGHT", 0, 0)
        plateData.minaHpPct:SetWidth(visW * 0.32)
    end

    if plateData.minaHpTextRow then
        plateData.minaHpTextRow:ClearAllPoints()
        plateData.minaHpTextRow:SetAllPoints(hp)
    end
    if plateData.minaHpNum then
        plateData.minaHpNum:ClearAllPoints()
        plateData.minaHpNum:SetPoint("LEFT", hp, "LEFT", 4, 0)
    end
    if plateData.minaHpBarPct then
        plateData.minaHpBarPct:ClearAllPoints()
        plateData.minaHpBarPct:SetPoint("RIGHT", hp, "RIGHT", -4, 0)
    end

    if plateData.minaPoTextRow then
        plateData.minaPoTextRow:ClearAllPoints()
        plateData.minaPoTextRow:SetAllPoints(po)
    end

    if plateData.minaPoCur then
        plateData.minaPoCur:ClearAllPoints()
        plateData.minaPoCur:SetPoint("LEFT", po, "LEFT", 4, 0)
    end

    if plateData.minaPoPct then
        plateData.minaPoPct:ClearAllPoints()
        plateData.minaPoPct:SetPoint("RIGHT", po, "RIGHT", -4, 0)
    end

    if plateData.minaDebuffHost then
        plateData.minaDebuffHost:ClearAllPoints()
        plateData.minaDebuffHost:SetSize(visW, 16)
        plateData.minaDebuffHost:SetPoint("BOTTOMLEFT", plateData.minaNameRow or plateData.minaName, "TOPLEFT",
            cfg.debuffOffsetX or 0, (C.DEBUFF_HOST_OFFSET_Y or 2) + (cfg.debuffOffsetY or 0))
    end

    NP.widgets.LayoutRaidMarker(plateData)
    NP.layout.ApplyNameplateFonts(plateData)
    NP.layout.ApplyBattleGroundHealersCompat(plateData)
    if NP.clickbox then
        NP.clickbox.ApplyPlateClickbox(plateData)
    end

    if cfg.showPartyRaidCastBars and plateData.minaPartyCast then
        NP.castbar.LayoutPartyCastBar(plateData)
    end
end

-- Cast bar stack layout

-- Power bar occupies a stack slot only while shown.
function NP.layout.GetCastStackAnchor(plateData)
    local hp = plateData and plateData.minaHp
    local po = plateData and plateData.minaPo
    if hp and po and NP.config.IsPowerShown(plateData) then
        return po
    end
    return hp or po
end

function NP.layout.RelayoutCastStack(plateData)
    if not plateData then return end
    NP.layout.LayoutCastBarStack(plateData)
end

function NP.layout.LayoutCastBarStack(plateData)
    local bar = plateData.minaCast
    local border = plateData.border
    local hp = plateData.minaHp
    if not border or not hp then return end

    local cfg = NP.config.GetCfg()
    local anchor = NP.layout.GetCastStackAnchor(plateData)
    if not anchor then return end

    local visW = select(1, NP.native_style.GetBarMetrics(border))
    local castH = select(1, NP.config.GetCastBarMetrics())
    local stackGap = NP.config.GetStackBarGap()

    if cfg.showCastBar ~= false and bar then
        bar:ClearAllPoints()
        bar:SetSize(visW, castH)
        bar:SetPoint("TOP", anchor, "BOTTOM", 0, -stackGap)

        local iconSize = NP.castbar.LayoutCastSpellIcon(bar.minaCastIcon, bar, bar._notInterruptible)
        if plateData.castBarIcon then
            plateData.castBarIcon:Hide()
        end

        local shield = plateData.castBarShield
        if shield then
            shield:ClearAllPoints()
            shield:SetSize(visW, castH)
            shield:SetPoint("CENTER", bar, "CENTER", 0, 0)
        end

        if bar.minaCastShield and bar.minaCastIcon and bar._notInterruptible then
            NP.castbar.LayoutCastIconShield(bar.minaCastShield, bar.minaCastIcon, iconSize, bar)
        end

        if bar.minaCastSpellName then
            if cfg.showCastBarSpellName ~= false and bar.spellName then
                bar.minaCastSpellName:SetText(bar.spellName)
                bar.minaCastSpellName:Show()
            else
                bar.minaCastSpellName:Hide()
            end
        end
    end

    if cfg.showPartyRaidCastBars and plateData.minaPartyCast then
        NP.castbar.LayoutPartyCastBar(plateData)
    end
end

-- Clickbox delegation

function NP.layout.FlushPendingPlateLayout()
    if InCombatLockdown() then
        return
    end

    NP.module._layoutPending = nil

    if NP.module._pendingWorldFrameExtend ~= nil then
        local extend = NP.module._pendingWorldFrameExtend
        NP.module._pendingWorldFrameExtend = nil
        NP.layout.UpdateWorldFrameHeight(extend)
    end

    if NP.clickbox then
        NP.clickbox.FlushPending()
    end

    for _, plateData in pairs(NP.module.plates) do
        if plateData._pendingRetailScale ~= nil then
            NP.layout.SetRetailPlateScale(plateData, plateData._pendingRetailScale)
        end
    end
end

-- WorldFrame height extension for clamp above screen bounds

local WORLD_FRAME_HEIGHT_MULT = 50
local WORLD_FRAME_HEIGHT_TOLERANCE = 1

-- GetSize() reflects real height; GetHeight may be overridden below.
local function GetActualWorldFrameHeight()
    local _, height = WorldFrame:GetSize()
    return height
end

-- ActionStatus is a WorldFrame child; pin it to UIParent so the clamp's stretch doesn't push it off-screen.
local function PinActionStatusToScreenCenter()
    local status = _G.ActionStatus
    if status and status.ClearAllPoints then
        status:ClearAllPoints()
        status:SetAllPoints(UIParent)
    end
end

local function CaptureWorldFrameState()
    if NP.module._worldFrameState then
        return NP.module._worldFrameState
    end
    local width, height = WorldFrame:GetSize()
    local state = {
        width = width,
        height = height,
        getHeight = WorldFrame.GetHeight,
        points = {},
    }
    local numPoints = WorldFrame.GetNumPoints and WorldFrame:GetNumPoints() or 0
    for i = 1, numPoints do
        state.points[i] = { WorldFrame:GetPoint(i) }
    end
    NP.module._worldFrameState = state
    NP.module._worldFrameWidth = width
    NP.module._worldFrameNativeHeight = height
    return state
end

local function RestoreWorldFrameState()
    local state = NP.module._worldFrameState
    if not state then
        NP.module._worldFrameExtended = nil
        return
    end
    WorldFrame.GetHeight = state.getHeight
    WorldFrame:ClearAllPoints()
    for i = 1, #state.points do
        WorldFrame:SetPoint(unpack(state.points[i], 1, 5))
    end
    if state.width then WorldFrame:SetWidth(state.width) end
    if state.height then WorldFrame:SetHeight(state.height) end
    NP.module._worldFrameExtended = nil
    NP.module._worldFrameState = nil
    NP.module._worldFrameWidth = nil
    NP.module._worldFrameNativeHeight = nil
end

-- Detect WorldFrame height drift and re-apply; do not trust cached intent alone.
function NP.layout.UpdateWorldFrameHeight(shouldExtend)
    if not WorldFrame or not WorldFrame.ClearAllPoints then
        return
    end

    local wantExtended = shouldExtend and true or false
    if not wantExtended then
        -- If DragonUI never extended WorldFrame, preserve the existing geometry.
        -- Otherwise restore the exact captured state.
        if NP.module._worldFrameState or NP.module._worldFrameExtended then
            RestoreWorldFrameState()
        end
        NP.module._pendingWorldFrameExtend = nil
        return
    end

    local state = CaptureWorldFrameState()
    local nativeHeight = state.height or 768
    local expectedHeight = nativeHeight * WORLD_FRAME_HEIGHT_MULT
    local actualHeight = GetActualWorldFrameHeight()
    local isExtended = NP.module._worldFrameExtended and true or false
    local drifted = actualHeight and math.abs(actualHeight - expectedHeight) > WORLD_FRAME_HEIGHT_TOLERANCE

    if wantExtended == isExtended and not drifted then
        return
    end

    -- Apply in combat; WorldFrame SetPoint/SetHeight are not protected.
    if drifted and addon.debugMode then
        print(string.format(
            "|cFFFFD700[DragonUI]|r WorldFrame height drifted (expected %d, was %s) — re-applying clamp extension.",
            expectedHeight, tostring(actualHeight)))
    end

    local width = state.width or WorldFrame:GetWidth()
    WorldFrame:ClearAllPoints()
    WorldFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
    WorldFrame:SetWidth(width)
    WorldFrame:SetHeight(expectedHeight)
    WorldFrame.GetHeight = function()
        return nativeHeight
    end
    PinActionStatusToScreenCenter()
    NP.module._worldFrameExtended = true

    NP.module._pendingWorldFrameExtend = nil
end

-- /dui npclamp diagnostic: clamp config, WorldFrame height, per-plate state.
function NP.layout.DebugPrintClampState()
    local cfg = NP.config.GetCfg()
    local wantExtended = (NP.module._clampTargetEnabled or NP.module._clampBossEnabled) and true or false
    local state = NP.module._worldFrameState
    local nativeHeight = (state and state.height) or NP.module._worldFrameNativeHeight
        or (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 768
    local expectedHeight = wantExtended and (nativeHeight * WORLD_FRAME_HEIGHT_MULT) or nativeHeight
    local actualHeight = GetActualWorldFrameHeight()
    local drifted = actualHeight and math.abs(actualHeight - expectedHeight) > WORLD_FRAME_HEIGHT_TOLERANCE

    print("|cFFFFD700[DragonUI nameplates clamp]|r")
    print(string.format("  cfg: clampTarget=%s clampBoss=%s clampTopInset=%s",
        tostring(cfg.clampTarget), tostring(cfg.clampBoss), tostring(cfg.clampTopInset)))
    print(string.format("  flags: _clampTargetEnabled=%s _clampBossEnabled=%s inPvEInstance=%s inArena=%s",
        tostring(NP.module._clampTargetEnabled), tostring(NP.module._clampBossEnabled),
        tostring(NP.module.inPvEInstance), tostring(NP.module.inArena)))
    print(string.format("  worldFrame: wantExtended=%s _worldFrameExtended=%s expectedHeight=%d actualHeight=%s %s",
        tostring(wantExtended), tostring(NP.module._worldFrameExtended), expectedHeight, tostring(actualHeight),
        drifted and "|cFFFF0000<<< DRIFTED>>>|r" or "(in sync)"))
    print(string.format("  pending: _pendingWorldFrameExtend=%s _layoutPending=%s InCombatLockdown=%s",
        tostring(NP.module._pendingWorldFrameExtend), tostring(NP.module._layoutPending), tostring(InCombatLockdown())))

    local targetPlate = NP.module.targetPlate
    if targetPlate and targetPlate.plate then
        local plate = targetPlate.plate
        local want = PlateWantsClamp(targetPlate)
        local left, right, top, bottom = plate.GetClampRectInsets and plate:GetClampRectInsets()
        local width, height = plate:GetSize()
        local _, _, _, x, y = plate:GetPoint(1)
        print(string.format(
            "  target plate: wants=%s _clamped=%s clampedToScreen=%s insets=(%s,%s,%s,%s) size=(%s,%s) pos=(%s,%s)",
            tostring(want), tostring(targetPlate._clamped),
            tostring(plate.IsClampedToScreen and plate:IsClampedToScreen()),
            tostring(left), tostring(right), tostring(top), tostring(bottom),
            tostring(width), tostring(height), tostring(x), tostring(y)))
    else
        print("  target plate: none")
    end

    print("  all visible plates (classification / boss-detect / want / clamped):")
    local shown = 0
    for _, pd in pairs(NP.module.plates) do
        local plate = pd and pd.plate
        if plate and plate.IsShown and plate:IsShown() then
            shown = shown + 1
            local nativeBoss = pd.bossIcon and pd.bossIcon.IsShown and pd.bossIcon:IsShown()
            print(string.format(
                "    %-20s class=%-7s nativeBossSkull=%s -> hasBossIcon=%s want=%s clamped=%s%s",
                tostring(pd.plateName or "?"),
                tostring(pd._plateClassification or "none"),
                tostring(nativeBoss),
                tostring(NP.layout.PlateHasBossIcon(pd)),
                tostring(PlateWantsClamp(pd)),
                tostring(pd._clamped),
                (NP.identity.IsTargetPlate(pd) and " <TARGET>" or "")))
        end
    end
    if shown == 0 then
        print("    (no visible plates)")
    end
end

if not NP.module._worldFrameRegenFrame then
    local regenFrame = CreateFrame("Frame")
    regenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    regenFrame:SetScript("OnEvent", function()
        if NP.module._pendingWorldFrameExtend ~= nil then
            NP.layout.FlushPendingPlateLayout()
        end
    end)
    NP.module._worldFrameRegenFrame = regenFrame
end
