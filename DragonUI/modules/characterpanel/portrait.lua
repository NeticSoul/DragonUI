local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Blizzard's portrait is 60x60 at TOPLEFT(7,-6) for the wooden frame; retail's is 62x62 at
-- TOPLEFT(-5,7), which is where the ring baked into our top-left chrome corner sits.
local PORTRAIT_SIZE = 62
local PORTRAIT_X, PORTRAIT_Y = -5, 7

-- 3.3.5a has no mask textures, so SQUARE art has to shrink until its corners clear the circular
-- cutout. Blizzard's UI-Classes-Circles is exempt: that art is already circular.
local SQUARE_INSET = 3

local function applySquareArt(p, cf)
    p:SetSize(PORTRAIT_SIZE - SQUARE_INSET * 2, PORTRAIT_SIZE - SQUARE_INSET * 2)
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", cf, "TOPLEFT", PORTRAIT_X + SQUARE_INSET, PORTRAIT_Y - SQUARE_INSET)
end

local function applyGeometry()
    local p = _G.CharacterFramePortrait
    local cf = _G.CharacterFrame
    if not p or not cf or p._duiGeometry then return end
    p._duiGeometry = true

    p:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", cf, "TOPLEFT", PORTRAIT_X, PORTRAIT_Y)
end

local function setClassPortrait()
    local p = _G.CharacterFramePortrait
    local cf = _G.CharacterFrame
    if not p or not cf then return end
    local _, classFile = UnitClass("player")
    if not classFile then return end

    -- DragonUI's HD class icons are square art, so they need the same inset as the face.
    if addon.UF and addon.UF.ApplyClassPortraitIcon then
        if addon.UF.ApplyClassPortraitIcon(p, classFile, true) then
            applySquareArt(p, cf)
            p._duiMode = "class"
            return
        end
    end

    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if not coords then return end
    p:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", cf, "TOPLEFT", PORTRAIT_X, PORTRAIT_Y)
    p:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    p:SetTexCoord(unpack(coords))
    p._duiMode = "class"
end

local function setFacePortrait()
    local p = _G.CharacterFramePortrait
    local cf = _G.CharacterFrame
    if not p or not cf then return end
    -- The class icon leaves a sub-rect texcoord behind; SetPortraitTexture does not reset it,
    -- so the face would render sampled down to a sliver.
    p:SetTexCoord(0, 1, 0, 1)
    applySquareArt(p, cf)
    if SetPortraitTexture then SetPortraitTexture(p, "player") end
    p._duiMode = "face"
end

local function reapply()
    if CP:Config().class_portrait then setClassPortrait() else setFacePortrait() end
end

CP.UpdatePortrait = reapply

-- DISPLAY_SIZE_CHANGED drives Blizzard back through its own portrait setup without going through
-- CharacterFrame_OnEvent, so the hook below never saw it and the class icon reverted to the face.
local events = CreateFrame("Frame")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:RegisterEvent("UNIT_PORTRAIT_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_PORTRAIT_UPDATE" and unit ~= "player" then return end
    reapply()
end)

local eventHooked

local function build()
    local cf = _G.CharacterFrame
    if not cf then return end

    applyGeometry()

    if not cf._duiPortraitWired then
        cf._duiPortraitWired = true
        cf:HookScript("OnShow", reapply)
    end
    -- Blizzard re-runs SetPortraitTexture on UNIT_PORTRAIT_UPDATE, wiping the class icon.
    if _G.CharacterFrame_OnEvent and not eventHooked then
        eventHooked = true
        hooksecurefunc("CharacterFrame_OnEvent", reapply)
    end

    reapply()
end

CP:RegisterBuilder("portrait", build)
