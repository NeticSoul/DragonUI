local addon = select(2, ...)
local CP = addon.CharacterPanel

-- The faction popup, dressed with the rock ground and the gold pane trim. No nineslice: its metal
-- corners come in two sizes with no plain top-left, so every arrangement needed a flipped rect.
local ROCK = addon._dir .. "UI\\ui-background-rock"

local WIDTH, HEIGHT = 226, 240
-- The rim sits a pixel proud of what it frames, so the ground behind cannot show past it.
local TRIM_OUTSET = 1
local TITLE_H = 22
local MARGIN = 8
-- What the three stacked checkboxes need under the text.
local CHECKBOX_BLOCK = 84
local DESCRIPTION_INSET = 10
local DESCRIPTION_TOP = 12

-- Drawn by us rather than salvaged: finding Blizzard's means region:GetTexture(), which is nil until
-- the frame has been drawn once, and this builds while the window has never been shown.
local PARCHMENT = "Interface\\PaperDollInfoFrame\\UI-Character-Reputation-DetailBackground"
-- Cropped to the part of the sheet that actually carries paper. Order is left, right, top, bottom.
local PARCHMENT_CROP = { 0, 0.73, 0, 0.90 }

local function stripArt(frame)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then
            region:Hide()
            region.Show = region.Hide
        end
    end
end

local function build()
    local cf = _G.CharacterFrame
    local detail = _G.ReputationDetailFrame
    if not cf or not detail or detail._duiSkinned then return end
    detail._duiSkinned = true

    -- A Backdrop is not a region, so the sweep never reaches it.
    if detail.SetBackdrop then detail:SetBackdrop(nil) end
    stripArt(detail)

    detail:SetSize(WIDTH, HEIGHT)
    detail:ClearAllPoints()
    detail:SetPoint("TOPLEFT", cf, "TOPRIGHT", 4, -24)

    local ground = detail:CreateTexture(nil, "BACKGROUND", nil, -6)
    ground:SetTexture(ROCK, "REPEAT", "REPEAT")
    ground:SetHorizTile(true)
    ground:SetVertTile(true)
    ground:SetAllPoints(detail)
    -- Published so the background setting reaches this window too; it shades with the panel.
    CP.DetailGround = ground

    -- Both FRAMES with explicit levels rather than textures on the window: a child always draws
    -- above its parent's regions, which rules out the buried-parchment failures this went through.
    local textArea = CreateFrame("Frame", nil, detail)
    textArea:SetPoint("TOPLEFT", detail, "TOPLEFT", MARGIN, -(TITLE_H + MARGIN))
    textArea:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -MARGIN, CHECKBOX_BLOCK)

    local paper = CreateFrame("Frame", nil, detail)
    paper:SetFrameLevel(detail:GetFrameLevel() + 1)
    paper:SetPoint("TOPLEFT", textArea, "TOPLEFT", 0, 0)
    paper:SetPoint("BOTTOMRIGHT", textArea, "BOTTOMRIGHT", 0, 0)
    -- Above the paper, so the trim rims it and the description reads on it.
    textArea:SetFrameLevel(paper:GetFrameLevel() + 1)

    local sheet = paper:CreateTexture(nil, "BACKGROUND")
    sheet:SetAllPoints(paper)
    detail._duiSheet = sheet
    CP.DetailPaper = sheet

    local function dressPaper()
        local tex = detail._duiSheet
        if not tex then return end
        tex:SetTexture(PARCHMENT)
        tex:SetTexCoord(unpack(PARCHMENT_CROP))
        tex:Show()
    end
    dressPaper()
    detail:HookScript("OnShow", function()
        dressPaper()
        CP.ApplyBodyBackground()
    end)
    CP.ApplyBodyBackground()

    if CP.DrawPaneBorder then CP.DrawPaneBorder(detail, detail, TRIM_OUTSET) end

    -- Title band: a darker strip across the top, with the faction name on it.
    local band = detail:CreateTexture(nil, "BACKGROUND", nil, -5)
    band:SetTexture(0, 0, 0)
    band:SetAlpha(0.45)
    band:SetPoint("TOPLEFT", detail, "TOPLEFT", 3, -3)
    band:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -3, -3)
    band:SetHeight(TITLE_H)

    CP.ModernizeCloseButton(_G.ReputationDetailCloseButton, detail, -2, -2)

    CP.DETAIL_TEXT_COLOR = { 1, 1, 1 }

    if CP.DrawPaneBorder then CP.DrawPaneBorder(textArea, textArea, TRIM_OUTSET) end

    -- OVERLAY so the trim, which draws above the grounds, cannot paint over the text.
    local name = _G.ReputationDetailFactionName
    if name then
        name:SetDrawLayer("OVERLAY")
        name:ClearAllPoints()
        name:SetPoint("LEFT", detail, "LEFT", 10, 0)
        name:SetPoint("RIGHT", detail, "RIGHT", -26, 0)
        name:SetPoint("TOP", detail, "TOP", 0, -7)
        name:SetJustifyH("CENTER")
    end

    -- Blizzard sizes this against its old parchment and its font is dark grey for it; over our well
    -- it has to be white, set on the string because the font object is shared.
    local description = _G.ReputationDetailFactionDescription
    if description then
        description:SetParent(textArea)
        description:SetDrawLayer("OVERLAY")
        description:ClearAllPoints()
        description:SetPoint("TOPLEFT", textArea, "TOPLEFT", DESCRIPTION_INSET, -DESCRIPTION_TOP)
        description:SetPoint("TOPRIGHT", textArea, "TOPRIGHT", -DESCRIPTION_INSET, -DESCRIPTION_TOP)
        description:SetJustifyH("LEFT")
    end

    -- Hung off the text area's floor, so growing the window moves them as one block.
    local atWar = _G.ReputationDetailAtWarCheckBox
    local inactive = _G.ReputationDetailInactiveCheckBox
    local watched = _G.ReputationDetailMainScreenCheckBox
    if atWar and inactive and watched then
        atWar:ClearAllPoints()
        atWar:SetPoint("TOPLEFT", textArea, "BOTTOMLEFT", 0, -4)
        inactive:ClearAllPoints()
        inactive:SetPoint("TOPLEFT", atWar, "BOTTOMLEFT", 0, 2)
        watched:ClearAllPoints()
        watched:SetPoint("TOPLEFT", inactive, "BOTTOMLEFT", 0, 2)
    end
end

CP:RegisterBuilder("reputationdetail", build)
