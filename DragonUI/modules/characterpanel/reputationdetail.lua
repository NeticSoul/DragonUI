local addon = select(2, ...)
local CP = addon.CharacterPanel

-- The faction popup, framed the way retail frames it: DialogBorderTemplate, which is a nine-slice on
-- the DiamondMetal art. It used to wear DrawPaneBorder -- the INSET trim, a ribbon meant to recess a
-- pane inside a window, whose 6px bevels read as cut-off points on a floating dialog.
local DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background"
local DIALOG_INSET = 7

-- Every number below is ReputationDetailFrame's own, straight out of retail's XML.
local WIDTH, HEIGHT = 212, 203
local TITLE_X, TITLE_Y, TITLE_W = 20, -21, 160
-- Deliberately WIDER than the 212 frame: retail bleeds this art out over the dialog rail, which is
-- what gives the paper its recessed look. Cropping it to the frame is what flattened it here.
local PAPER_X, PAPER_Y, PAPER_W, PAPER_H = 11, -11, 260, 128
-- Both shipped rather than taken from the client: 3.3.5a serves DIFFERENT art at the divider path --
-- a ~200px visible region with gradient padding -- so the rule stops two thirds of the way across.
local DIVIDER = addon._dir .. "UI\\uidialog-divider"
-- One up from retail's -131: its line lives in the TOP half of a 32px canvas, and at -131 it leaves
-- a hairline of window showing between the paper's bottom edge and the rule.
local DIVIDER_X, DIVIDER_Y, DIVIDER_W, DIVIDER_H = 9, -130, 256, 32
local DESCRIPTION_RIGHT, DESCRIPTION_BOTTOM = -22, 75
-- retail ReputationFrame.xml:312 -- the bar hangs 5 clear of the text, not over it.
local SCROLLBAR_GAP = 5
local CHECK_SIZE = 26
local CHECK_ART_INSET = 2
local CHECK_X, CHECK_Y = 14, -143
-- Retail's own, verbatim. It tucks the X INSIDE the corner; an earlier attempt here pushed it out
-- by the 8 the rails were moved, on the theory that Blizzard wants it riding the corner ornament.
-- It does not -- the offset is negative precisely to keep the button within the frame.
local CLOSE_X, CLOSE_Y = -2, -2

local SWORDS = "Interface\\Buttons\\UI-CheckBox-SwordCheck"
local SWORD_SIZE, SWORD_X, SWORD_Y = 32, 3, -5

-- Drawn by us rather than salvaged: finding Blizzard's means region:GetTexture(), which is nil until
-- the frame has been drawn once, and this builds while the window has never been shown.
local PARCHMENT = addon._dir .. "CharacterPanel\\reputation-detailbg"

local function stripArt(frame)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then
            region:Hide()
            region.Show = region.Hide
        end
    end
end

-- Retail's minimal checkbox art swapped in place. Art only: the textures fill whatever size the
-- button already is, so no caller's geometry moves. `checked` overrides the tick, which is how the
-- at-war box keeps its swords while the rest get the plain mark.
function CP.SkinCheckbox(btn, checked)
    if not btn or btn._duiCheckbox then return end
    btn._duiCheckbox = true

    -- Inset rather than SetAllPoints: this art fills 27 of its 30px canvas where the classic box it
    -- replaces left a wide margin, so filling the button outright reads a size too big.
    local function dress(tex, atlas, add)
        if not tex or not tex.set_atlas then return end
        tex:set_atlas(atlas)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", btn, "TOPLEFT", CHECK_ART_INSET, -CHECK_ART_INSET)
        tex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -CHECK_ART_INSET, CHECK_ART_INSET)
        if add then tex:SetBlendMode("ADD") end
    end

    dress(btn:GetNormalTexture(), "checkbox-minimal")
    dress(btn:GetPushedTexture(), "checkbox-minimal")
    dress(btn:GetHighlightTexture(), "checkbox-minimal", true)
    if not checked then dress(btn:GetCheckedTexture(), "checkmark-minimal") end
    if btn.GetDisabledCheckedTexture then
        dress(btn:GetDisabledCheckedTexture(), "checkmark-minimal-disabled")
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

    -- DialogBorderTemplate's own ground, held 7px in so the metal rail sits on top of its edge.
    local ground = detail:CreateTexture(nil, "BACKGROUND", nil, -6)
    ground:SetTexture(DIALOG_BG, "REPEAT", "REPEAT")
    ground:SetHorizTile(true)
    ground:SetVertTile(true)
    ground:SetPoint("TOPLEFT", detail, "TOPLEFT", DIALOG_INSET, -DIALOG_INSET)
    ground:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -DIALOG_INSET, DIALOG_INSET)
    -- Published so the background setting reaches this window too; it shades with the panel.
    CP.DetailGround = ground

    -- ARTWORK on the window itself, not a child frame. A child draws above ALL of its parent's
    -- regions, so the paper would ride over the metal rails instead of running under them -- which
    -- is the whole point of cutting it wider than the frame.
    local sheet = detail:CreateTexture(nil, "ARTWORK")
    sheet:SetSize(PAPER_W, PAPER_H)
    sheet:SetPoint("TOPLEFT", detail, "TOPLEFT", PAPER_X, PAPER_Y)
    detail._duiSheet = sheet
    CP.DetailPaper = sheet

    local function dressPaper()
        local tex = detail._duiSheet
        if not tex then return end
        tex:SetTexture(PARCHMENT)
        tex:Show()
    end
    dressPaper()
    detail:HookScript("OnShow", function()
        dressPaper()
        CP.ApplyBodyBackground()
    end)
    CP.ApplyBodyBackground()

    -- Its own child frame, the way retail hangs DialogBorderTemplate off the window: that is what
    -- puts the rails above the paper without fighting draw layers.
    local border = CreateFrame("Frame", nil, detail)
    border:SetAllPoints(detail)
    border:SetFrameLevel(detail:GetFrameLevel() + 2)
    local layout = NineSliceUtils and NineSliceUtils.GetLayout("Dialog")
    if layout then NineSliceUtils.ApplyLayout(border, layout) end

    -- The rule under the paper, between it and the checkboxes.
    local divider = detail:CreateTexture(nil, "OVERLAY")
    divider:SetTexture(DIVIDER)
    divider:SetSize(DIVIDER_W, DIVIDER_H)
    divider:SetPoint("TOPLEFT", detail, "TOPLEFT", DIVIDER_X, DIVIDER_Y)

    -- Above the border frame: retail declares its CloseButton AFTER the Border, and the rails would
    -- otherwise be drawn over the one thing that has to stay clickable.
    local close = _G.ReputationDetailCloseButton
    CP.ModernizeCloseButton(close, detail, CLOSE_X, CLOSE_Y)
    if close then close:SetFrameLevel(border:GetFrameLevel() + 1) end

    CP.DETAIL_TEXT_COLOR = { 1, 1, 1 }

    -- Left aligned on the title line, not centred: retail hangs it at a fixed inset and lets it run.
    local name = _G.ReputationDetailFactionName
    if name then
        name:SetDrawLayer("ARTWORK")
        name:ClearAllPoints()
        name:SetPoint("TOPLEFT", detail, "TOPLEFT", TITLE_X, TITLE_Y)
        name:SetWidth(TITLE_W)
        name:SetJustifyH("LEFT")
    end

    -- Blizzard sizes this against its old parchment and its font is dark grey for it; over our well
    -- it has to be white, set on the string because the font object is shared.
    local description = _G.ReputationDetailFactionDescription
    if description then
        -- Retail scrolls this (ScrollingFontTemplate); a plain string just spills off the paper on
        -- the long lore texts. 3.3.5a has no WowScrollBox, so it is the stock scroll frame instead.
        local scroll = CreateFrame("ScrollFrame", "DragonUIReputationDetailScroll", detail,
                                   "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", name or detail, name and "BOTTOMLEFT" or "TOPLEFT", 0, -2)
        scroll:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", DESCRIPTION_RIGHT, DESCRIPTION_BOTTOM)
        scroll:SetFrameLevel(detail:GetFrameLevel() + 1)

        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(1, 1)
        scroll:SetScrollChild(content)

        description:SetParent(content)
        description:SetDrawLayer("ARTWORK")
        description:ClearAllPoints()
        description:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        description:SetJustifyH("LEFT")
        description:SetJustifyV("TOP")

        -- retail's hideIfUnscrollable: most faction blurbs fit, and a dead bar on every one of them
        -- is just clutter. 3.3.5a spells it this way, and only re-evaluates when asked.
        scroll.scrollBarHideable = true

        -- The string's height is only known once its text is set, and the child has to match it or
        -- there is nothing to scroll through.
        local function resize()
            local w = scroll:GetWidth() or 0
            if w <= 0 then return end
            description:SetWidth(w)
            content:SetSize(w, math.max(1, description:GetStringHeight() or 1))
            if ScrollFrame_OnScrollRangeChanged then ScrollFrame_OnScrollRangeChanged(scroll) end
        end
        scroll:HookScript("OnSizeChanged", resize)
        CP.UpdateDetailScroll = function() addon:After(0, resize) end
        resize()

        if CP.ReskinScrollBar then
            CP.ReskinScrollBar(scroll, scroll, 0, 0, 0)
            -- Re-anchored after the reskin: retail hangs the bar OUTSIDE the text, 5 to its right,
            -- where ReskinScrollBar's own inset would have laid it over the words.
            local bar = _G["DragonUIReputationDetailScrollScrollBar"]
            if bar then
                bar:ClearAllPoints()
                bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", SCROLLBAR_GAP, -1)
                bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", SCROLLBAR_GAP, 1)
            end
        end
    end

    -- Retail's arrangement, and the reason this looked wrong stacked: At War and Move to Inactive
    -- share a row, and only Show-on-main-screen drops below.
    local atWar = _G.ReputationDetailAtWarCheckBox
    local inactive = _G.ReputationDetailInactiveCheckBox
    local watched = _G.ReputationDetailMainScreenCheckBox
    if atWar and inactive and watched then
        for _, box in ipairs({ atWar, inactive, watched }) do
            box:SetSize(CHECK_SIZE, CHECK_SIZE)
            box:ClearAllPoints()
        end
        -- At War keeps its swords; the other two take the plain minimal tick.
        CP.SkinCheckbox(atWar, true)
        CP.SkinCheckbox(inactive)
        CP.SkinCheckbox(watched)
        atWar:SetPoint("TOPLEFT", detail, "TOPLEFT", CHECK_X, CHECK_Y)

        -- Crossed swords instead of a tick, at retail's own 32px over a 26px box. 3.3.5a declares
        -- this itself, but it is set here too so a client that does not still gets it.
        if atWar.SetCheckedTexture and not (atWar.GetCheckedTexture and atWar:GetCheckedTexture()) then
            atWar:SetCheckedTexture(SWORDS)
        end
        local swords = atWar.GetCheckedTexture and atWar:GetCheckedTexture()
        if swords then
            swords:SetTexture(SWORDS)
            swords:SetSize(SWORD_SIZE, SWORD_SIZE)
            swords:ClearAllPoints()
            swords:SetPoint("TOPLEFT", atWar, "TOPLEFT", SWORD_X, SWORD_Y)
        end

        local atWarLabel = _G.ReputationDetailAtWarCheckBoxText
        if atWarLabel then
            inactive:SetPoint("LEFT", atWarLabel, "RIGHT", 3, 0)
        else
            inactive:SetPoint("LEFT", atWar, "RIGHT", 80, 0)
        end
        watched:SetPoint("TOPLEFT", atWar, "BOTTOMLEFT", 0, 3)
    end
end

CP:RegisterBuilder("reputationdetail", build)
