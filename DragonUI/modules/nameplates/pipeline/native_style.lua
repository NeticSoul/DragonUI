local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const
local abs = NP.abs

-- Nameplates native_style: classification, bar color, helpers.

NP.native_style = NP.native_style or {}

local RareEntryCache = {}

function NP.native_style.StripRealm(name)
    if not name or name == "" then
        return nil
    end
    return name:match("^([^%-]+)") or name
end

-- Boss level marker: numeric -1, or the "??"/"-1" text shown on boss plates.
function NP.native_style.IsBossLevel(value)
    if value == nil then
        return false
    end
    if type(value) == "number" then
        return value == -1
    end
    local s = tostring(value)
    return s == "??" or s == "-1"
end

function NP.native_style.TextureMatches(tex, exactPath, partialKey)
    if not tex or type(tex) ~= "string" then
        return false
    end
    if tex == exactPath then
        return true
    end
    return string.find(tex, partialKey, 1, true) ~= nil
end

function NP.native_style.ResolvePlateFrames(frame)
    if not frame then
        return nil, nil
    end
    if frame.RealPlate then
        return frame.RealPlate, frame
    end
    if frame.VirtualPlate then
        return frame, frame.VirtualPlate
    end
    return frame, frame
end

-- Callers consume only visW (select(1, ...)); xShift/scale kept for arity.
function NP.native_style.GetBarMetrics(border)
    local refW, refH = NP.config.GetBarRefSize()
    return refW, refH, 0, 1
end

function NP.native_style.HideRegion(tex)
    if tex and tex.Hide then
        -- Do not clear native texture; HookScript is irreversible on recycled plates.
        if tex.SetAlpha then
            tex:SetAlpha(0)
        end
        tex:Hide()
    end
end

function NP.native_style.NeutralizeStatusBarVisual(bar)
    if not bar then
        return
    end
    -- Alpha suppression is reversible; replacing the status-bar texture is not.
    if bar.SetAlpha then
        bar:SetAlpha(0)
    end
end

-- Elite/rare classification

local NpcRareRanks = addon.NpcRareRanks

local function TexCoordNear(v, ref, eps)
    return math.abs(v - ref) <= (eps or C.TEX_COORD_EPS)
end

local function TexCoordsRoughlyMatch(left, right, top, bottom, ref)
    return TexCoordNear(left, ref[1]) and TexCoordNear(right, ref[2])
        and TexCoordNear(top, ref[3]) and TexCoordNear(bottom, ref[4])
end

local function ClassificationFromIconTexCoords(left, right, top, bottom)
    if not left then
        return nil
    end
    for key, ref in pairs(C.PLATE_CLASS_TEXCOORDS) do
        if TexCoordsRoughlyMatch(left, right, top, bottom, ref) then
            if key == "rare" or key == "rareelite" then
                return "rare"
            end
            return "elite"
        end
    end
    return nil
end

local function ParseNpcCreatureId(guid)
    if not guid or type(guid) ~= "string" then
        return nil
    end
    return tonumber(guid:sub(9, 12), 16)
end

-- Shared so the castbar pet filter can match summons by language-independent
-- creature entry id instead of localized names.
NP.native_style.ParseNpcCreatureId = ParseNpcCreatureId

local function RememberRareEntry(unit)
    if not unit or not UnitExists(unit) then
        return
    end
    local c = UnitClassification(unit)
    if c ~= "rare" and c ~= "rareelite" then
        return
    end
    local entry = ParseNpcCreatureId(UnitGUID(unit))
    if entry then
        RareEntryCache[entry] = true
    end
end

local function LookupRareClassification(plateData)
    if not NpcRareRanks then
        return nil
    end
    local guid = NP.state.GetPlateGUID(plateData)
    if guid then
        local entry = ParseNpcCreatureId(guid)
        if entry then
            if RareEntryCache[entry] or NpcRareRanks:IsRareEntry(entry) then
                return "rare"
            end
            -- Entry confirmed not rare: trust the id over the name, since
            -- two unrelated NPCs can share a localized display string.
            return nil
        end
    end
    local name = plateData.plateName
    if not name and plateData.ogNameText and plateData.ogNameText.GetText then
        name = plateData.ogNameText:GetText()
    end
    if not name then
        return nil
    end
    -- Level is readable pre-target (unlike GUID), so it disambiguates the
    -- known name collisions in NameLevelHints (npc_rare_ranks.lua).
    local level
    local levelText = plateData.levelText
    if levelText and levelText.GetText then
        level = tonumber(levelText:GetText())
    end
    if NpcRareRanks:IsRareName(name, level) then
        return "rare"
    end
    return nil
end

function NP.native_style.NativePlateIconActive(tex)
    if not tex or not tex.IsShown or not tex:IsShown() then
        return false
    end
    if tex.GetTexture then
        local path = tex:GetTexture()
        return path ~= nil and path ~= ""
    end
    return true
end

local function NativeTextureClassification(tex)
    if not tex or not tex.IsShown or not tex:IsShown() then
        return nil
    end
    if tex.GetTexture then
        local path = tex:GetTexture()
        if not path or path == "" then
            return nil
        end
        local lower = string.lower(tostring(path))
        if string.find(lower, "rare", 1, true) then
            return "rare"
        end
    end
    if tex.GetTexCoord then
        local left, right, top, bottom = tex:GetTexCoord()
        local fromCoords = ClassificationFromIconTexCoords(left, right, top, bottom)
        if fromCoords then
            return fromCoords
        end
    end
    if NP.native_style.NativePlateIconActive(tex) then
        return "elite"
    end
    return nil
end

local function CaptureNativePlateClassification(plateData)
    if not plateData then
        return nil
    end
    local eliteC = NativeTextureClassification(plateData.eliteIcon)
    local bossC = NativeTextureClassification(plateData.bossIcon)
    if eliteC == "rare" or bossC == "rare" then
        return "rare"
    end
    if eliteC == "elite" or bossC == "elite" then
        return "elite"
    end
    return nil
end

function NP.native_style.NoteNativePlateClassification(plateData)
    if not plateData then
        return
    end
    plateData._plateClassification = CaptureNativePlateClassification(plateData)
end

function NP.native_style.ResetPlateEliteIfIdentityChanged(plateData, freshName)
    if not plateData or not freshName then
        return
    end
    if plateData._eliteIdentityName and plateData._eliteIdentityName ~= freshName then
        plateData._plateClassification = nil
        if plateData._eliteIcon then
            plateData._eliteIcon:Hide()
        end
    end
    plateData._eliteIdentityName = freshName
end

function NP.native_style.SuppressNativePlateIcon(tex)
    if not tex then
        return
    end
    if tex.SetAlpha then
        tex:SetAlpha(0)
    end
end

local function ClassificationFromUnit(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end
    local c = UnitClassification(unit)
    if c == "rare" or c == "rareelite" then
        return "rare"
    end
    if c == "elite" or c == "worldboss" then
        return "elite"
    end
    return nil
end

function NP.native_style.ResolvePlateClassification(plateData, unit)
    local fromUnit
    if unit and UnitExists(unit) then
        fromUnit = ClassificationFromUnit(unit)
        if fromUnit == "rare" then
            RememberRareEntry(unit)
            return "rare"
        end
    end
    local native = plateData._plateClassification
    if native == "rare" then
        return "rare"
    end
    -- Not yet confirmed rare: consult the database, since many dungeon/world
    -- rares are only ever reported as "elite" by the game's own API.
    if LookupRareClassification(plateData) == "rare" then
        return "rare"
    end
    return fromUnit or native
end

function NP.native_style.ClassKeyFromBarColor(r, g, b)
    return C.CLASS_BY_BAR_COLOR[math.floor(r * 10 + g * 100 + b)]
end

-- Reaction and unit type from health bar color.
function NP.native_style.GetPlateReaction(plateData)
    local r, g, b = plateData.barR, plateData.barG, plateData.barB
    if not r then
        return nil, nil
    end
    if r < 0.01 and b < 0.01 and g > 0.99 then
        return "FRIENDLY", "NPC"
    elseif r < 0.01 and b > 0.99 and g < 0.01 then
        return "FRIENDLY", "PLAYER"
    elseif r > 0.99 and b < 0.01 and g > 0.99 then
        return "NEUTRAL", "NPC"
    elseif r > 0.99 and b < 0.01 and g < 0.01 then
        return "HOSTILE", "NPC"
    end
    return "HOSTILE", "PLAYER"
end

-- Raid icon texcoord → icon name.
local RaidIconCoordinate = {
    [0] = { [0] = "STAR", [0.25] = "MOON" },
    [0.25] = { [0] = "CIRCLE", [0.25] = "SQUARE" },
    [0.5] = { [0] = "DIAMOND", [0.25] = "CROSS" },
    [0.75] = { [0] = "TRIANGLE", [0.25] = "SKULL" },
}

function NP.native_style.GetPlateRaidIconName(plateData)
    local icon = plateData and plateData.raidIcon
    if not icon or not icon.IsShown or not icon:IsShown() or not icon.GetTexCoord then
        return nil
    end
    local ux, uy = icon:GetTexCoord()
    local row = RaidIconCoordinate[ux]
    return row and row[uy] or nil
end

function NP.native_style.CaptureBarColor(plateData)
    local bar = plateData.healthBar
    if not bar or not bar.GetStatusBarColor then
        return
    end
    local r, g, b = bar:GetStatusBarColor()
    -- Bar-color change busts headline/totem gate memos.
    if (r ~= plateData.barR or g ~= plateData.barG or b ~= plateData.barB)
        and NP.gather and NP.gather.InvalidatePlateGates then
        NP.gather.InvalidatePlateGates(plateData)
    end
    plateData.barR, plateData.barG, plateData.barB = r, g, b
    plateData.classKey = NP.native_style.ClassKeyFromBarColor(r, g, b)
    if addon.debugMode then
        print(string.format("|cFFFFFF00[DUI nameplate debug]|r CaptureBarColor name=%s r=%.3f g=%.3f b=%.3f classKey=%s",
            tostring(plateData.plateName), r, g, b, tostring(plateData.classKey)))
    end
end
