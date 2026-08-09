local addon = select(2, ...)
local CP = addon.CharacterPanel

local MODEL_W, MODEL_H = 231, 320

-- Blizzard's own DressUpTexturePath applies this same fallback: the 3.3.5a client ships no
-- Gnome or Troll backdrop art.
local RACE_FALLBACK = { GNOME = "Dwarf", TROLL = "Orc" }

local function raceKey()
    local _, fileName = UnitRace("player")
    if not fileName then return "ORC" end
    local upper = strupper(fileName)
    return strupper(RACE_FALLBACK[upper] or fileName)
end

local function racePath()
    local _, fileName = UnitRace("player")
    if not fileName then return "Interface\\DressUpFrame\\DressUpBackground-Orc" end
    local upper = strupper(fileName)
    fileName = RACE_FALLBACK[upper] or fileName
    return "Interface\\DressUpFrame\\DressUpBackground-" .. fileName
end

-- Retail's own per-race dimming: the backdrops differ in brightness, so one flat value washes out
-- the pale ones. Keyed off the RESOLVED race, so a Gnome drawn on Dwarf art gets Dwarf's value.
local RACE_OVERLAY_ALPHA = {
    BLOODELF = 0.8, NIGHTELF = 0.6, SCOURGE = 0.3,
    TROLL = 0.6, ORC = 0.6, WORGEN = 0.5, GOBLIN = 0.6,
}
local OVERLAY_ALPHA_DEFAULT = 0.7

local function resizeModel()
    local model = _G.CharacterModelFrame
    local cf = _G.CharacterFrame
    if not model or not cf or not cf.Inset or model._duiResized then return end
    model._duiResized = true

    model:SetSize(MODEL_W, MODEL_H)
    model:ClearAllPoints()
    -- Retail puts it at (52,-66) of the frame; the Inset starts at (4,-60), so that is (48,-6) here.
    model:SetPoint("TOPLEFT", cf.Inset, "TOPLEFT", 48, -6)
end

-- Cropped to the viewport: 245 + 75 = 320, the model's exact height. Retail runs the bottom pair
-- their full 128, which made the strip under the model depend on that overhang drawing.
local BOTTOM_CROP = 75 / 128
local QUARTERS = {
    { key = "TopLeft", suffix = 1, w = 212, h = 245, tc = { 0.171875, 1, 0.0392156862745098, 1 },
      point = "TOPLEFT", rel = "TOPLEFT" },
    { key = "TopRight", suffix = 2, w = 19, h = 245, tc = { 0, 0.296875, 0.0392156862745098, 1 },
      point = "TOPLEFT", rel = "TOPRIGHT" },
    { key = "BotLeft", suffix = 3, w = 212, h = 75, tc = { 0.171875, 1, 0, BOTTOM_CROP },
      point = "TOPLEFT", rel = "BOTTOMLEFT" },
    { key = "BotRight", suffix = 4, w = 19, h = 75, tc = { 0, 0.296875, 0, BOTTOM_CROP },
      point = "TOPLEFT", rel = "BOTTOMRIGHT" },
}

-- The race backdrops are strongly coloured and the model reads as a cutout pasted on them. Retail
-- desaturates then dims under black, so the character is the only colour in the viewport.
local function overlayAlpha()
    return RACE_OVERLAY_ALPHA[raceKey()] or OVERLAY_ALPHA_DEFAULT
end

local function buildBackground()
    local model = _G.CharacterModelFrame
    if not model or model._duiRaceBg then return end
    model._duiRaceBg = {}

    local topLeft
    for _, q in ipairs(QUARTERS) do
        local tex = model:CreateTexture(nil, "BACKGROUND")
        tex:SetSize(q.w, q.h)
        tex:SetTexCoord(unpack(q.tc))
        if q.key == "TopLeft" then
            tex:SetPoint(q.point, model, q.rel, 0, 0)
            topLeft = tex
        else
            tex:SetPoint(q.point, topLeft, q.rel, 0, 0)
        end
        model._duiRaceBg[q.suffix] = tex
    end

    -- Bounded by the MODEL, not the backdrop grid: the grid runs 53px past the viewport, and
    -- measuring up from its floor left the two edges a pixel apart. BORDER is retail's layer.
    local overlay = model:CreateTexture(nil, "BORDER")
    overlay:SetTexture(0, 0, 0)
    overlay:SetPoint("TOPLEFT", model._duiRaceBg[1], "TOPLEFT", 0, 0)
    overlay:SetPoint("BOTTOMRIGHT", model, "BOTTOMRIGHT", 0, 0)
    model._duiRaceBgOverlay = overlay
end

local function applyRaceBackground()
    local model = _G.CharacterModelFrame
    if not model or not model._duiRaceBg then return end

    -- Read plainly, never as `~= false`: Config() falls back to an empty table before the database
    -- is up, and under that idiom a missing value would read as ENABLED.
    local grey = CP:Config().grey_model_backdrop and true or false
    local base = racePath()
    for suffix, tex in pairs(model._duiRaceBg) do
        tex:SetTexture(base .. suffix)
        tex:SetDesaturated(grey)
    end
    if model._duiRaceBgOverlay then
        model._duiRaceBgOverlay:SetAlpha(grey and overlayAlpha() or 0)
    end
end

CP.ApplyModelBackdrop = applyRaceBackground

local function build()
    resizeModel()
    buildBackground()
    applyRaceBackground()
end

CP.RefreshRaceBackground = applyRaceBackground

CP:RegisterBuilder("model", build)
