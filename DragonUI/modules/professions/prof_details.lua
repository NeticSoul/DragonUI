-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local P = addon.Professions
local L = addon.L
local Art, Model = P.Art, P.Model
local Details = { slotBorders = {} }
P.Details = Details

local CARD_X, CARD_Y = 311, -72
local CARD_INSET = 4
local FORM_X, FORM_Y, FORM_W, FORM_H = 16, -22, 316, 440
local REAGENT_W = 150
local BAR_FILL_W = 441

local outputFont = CreateFont("DragonUI_ProfessionsOutputFont")
outputFont:CopyFontObject(GameFontNormal)
do
    local path, _, flags = GameFontNormal:GetFont()
    outputFont:SetFont(path, 14, flags)
end

local function buildRankBar(craft, win)
    -- ProfessionsRankBarTemplate is 18 high and its 29-high art hangs from the top; the link button anchors to the 18.
    local bar = CreateFrame("Frame", nil, craft)
    bar:SetSize(453, 18)
    bar:SetPoint("TOPLEFT", win, "TOPLEFT", 110, -40)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    Art.Set(bg, "rankbar-bg", true)
    bg:SetPoint("TOPLEFT")
    -- The crafting page's bar has no overrides: mask = 453 x progress over the Fill at (5, -3).
    bar.fx = P.Fill.Create(bar, 453, 0, 18)
    bar.fx:SetPoint("TOPLEFT", bar, "TOPLEFT", 5, -3)
    -- Forever's border is the top sublevel of the fill's layer; here it needs a frame over the fill stack.
    local top = CreateFrame("Frame", nil, bar)
    top:SetAllPoints()
    top:SetFrameLevel(bar.fx:GetFrameLevel() + 1)
    local border = top:CreateTexture(nil, "ARTWORK")
    Art.Set(border, "rankbar-border", true)
    border:SetPoint("TOPLEFT")
    bar.rank = Art.RankText(top)
    bar.rank:SetCenter(bar, "TOPLEFT", 5 + BAR_FILL_W / 2, -12)
    Details.rankBar = bar
end

-- Forever's ProfessionsLinkButtonMixin: the tertiary square fills the 23 x 23 button and the 25 x 25 icon spills over it.
local function skinLinkButton(button)
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
        local stock = button[get](button)
        if stock then stock:SetTexture(nil) end
    end
    local square = button:CreateTexture(nil, "BACKGROUND")
    square:SetAllPoints()
    local over, down = false, false
    local function refresh()
        Art.Set(square, (over and down) and "link-pressed" or over and "link-hover" or "link-normal")
    end
    refresh()
    button:HookScript("OnEnter", function() over = true refresh() end)
    button:HookScript("OnLeave", function() over, down = false, false refresh() end)
    button:HookScript("OnMouseDown", function(_, mouse) down = mouse == "LeftButton" refresh() end)
    button:HookScript("OnMouseUp", function() down = false refresh() end)
    local icon = button:CreateTexture(nil, "OVERLAY")
    Art.Set(icon, "link-icon", true)
    icon:SetPoint("CENTER")
    button:SetSize(23, 23)
end

-- CircularGiantItemButtonMixin: auctionhouse-itemicon-border-<quality>; c60 only re-skins the common one (ring-frame).
local OUTPUT_RINGS = { [0] = "ring-gray", [2] = "ring-green", [3] = "ring-blue", [4] = "ring-purple", [5] = "ring-orange" }

-- Offsets put each ring on the icon's edge: the quality frames' art carries a bottom-right shadow the bronze lacks.
local SLOT_FRAMES = { [2] = "slot-frame-green", [3] = "slot-frame-blue", [4] = "slot-frame-epic", [5] = "slot-frame-legendary" }
-- 3.3.5a icons carry a grey bevel that would show as a second border inside the frame.
local ICON_CROP = 0.08

local function placeSlotBorder(border, icon, quality)
    local art = SLOT_FRAMES[quality]
    Art.Set(border, art or "square-frame")
    border:ClearAllPoints()
    if art then
        border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1.5, 1.5)
        border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 3.5, -3.5)
    else
        border:SetPoint("TOPLEFT", icon, "TOPLEFT", -6.5, 5.5)
        border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 5.5, -6.5)
    end
end

-- 36, centred on the stock 39: the frames' rings sit 1 inside a 39 icon and its colour bled out.
local function slotBorder(button, icon)
    -- Below the template's ARTWORK Count: a wide "18 /4" reaches the frame's metal.
    local border = button:CreateTexture(nil, "BORDER")
    border.icon = icon
    icon:SetSize(36, 36)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1.5, -1.5)
    icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    placeSlotBorder(border, icon)
    return border
end

local function refreshSlotBorders()
    local index = GetTradeSkillSelectionIndex()
    for i, border in ipairs(Details.slotBorders) do
        local link = index and index > 0 and GetTradeSkillReagentItemLink(index, i)
        placeSlotBorder(border, border.icon, link and select(3, GetItemInfo(link)))
    end
end

-- ProfessionsFavoriteButtonMixin: the star after the recipe name, gold when it is a favourite.
local function refreshFavorite()
    local star = Details.favorite
    local index = GetTradeSkillSelectionIndex()
    local name, kind = GetTradeSkillInfo(index or 0)
    local shown = name ~= nil and kind ~= "header" and Model.CanFavorite()
    star:SetShownCompat(shown)
    if not shown then return end
    local on = Model.IsFavorite(name)
    star.on, star.recipe = on, name
    Art.Set(star.normal, on and "favorite" or "favorite-off")
    Art.Set(star.lit, on and "favorite" or "favorite-off")
    star.lit:SetAlpha(on and 0.2 or 0.4)
    local label = TradeSkillSkillName
    star:ClearAllPoints()
    star:SetPoint("LEFT", label, "LEFT", math.min(label:GetStringWidth(), label:GetWidth()) + 4, 1)
end

local function favoriteTooltip(star)
    GameTooltip:SetOwner(star, "ANCHOR_RIGHT")
    GameTooltip:SetText(star.on and L["Remove Favorite"] or L["Set Favorite"], 1, 1, 1)
    GameTooltip:Show()
end

local function buildFavorite(child)
    local star = CreateFrame("Button", nil, child)
    star:SetSize(20, 18)
    star.normal = star:CreateTexture(nil, "ARTWORK")
    star.normal:SetAllPoints()
    star.lit = star:CreateTexture(nil, "HIGHLIGHT")
    star.lit:SetAllPoints()
    star.lit:SetBlendMode("ADD")
    star:SetScript("OnClick", function(self)
        Model.SetFavorite(self.recipe, not self.on)
        PlaySound("igMainMenuOptionCheckBoxOn")
        favoriteTooltip(self)
    end)
    star:SetScript("OnEnter", favoriteTooltip)
    star:SetScript("OnLeave", function() GameTooltip:Hide() end)
    star:Hide()
    Details.favorite = star
end

local function layoutForm(craft, win)
    local scroll = P.Frame.Adopt(TradeSkillDetailScrollFrame, craft, "TOPLEFT", win, "TOPLEFT", CARD_X + FORM_X, CARD_Y + FORM_Y)
    scroll:SetSize(FORM_W, FORM_H)
    for _, part in ipairs({ "Top", "Bottom" }) do
        local region = _G["TradeSkillDetailScrollFrame" .. part]
        if region then region:Hide() end
    end
    -- Its OnValueChanged scrolls its parent, so it stays put; the form fits, it only has to stay out of sight.
    local bar = TradeSkillDetailScrollFrameScrollBar
    bar:SetAlpha(0)
    bar:EnableMouse(false)
    for _, part in ipairs({ "ScrollUpButton", "ScrollDownButton" }) do
        local button = _G[bar:GetName() .. part]
        if button then button:EnableMouse(false) end
    end
    local child = TradeSkillDetailScrollChildFrame
    child:SetSize(FORM_W, FORM_H)
    for _, region in ipairs({ child:GetRegions() }) do
        if region:GetObjectType() == "Texture" then region:Hide() end
    end

    local icon = TradeSkillSkillIcon
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", child, "TOPLEFT", 12, -11)
    icon:SetSize(53, 53)
    -- CircularGiantItemButtonTemplate: a round icon at 45, so every edge stays under Profession-Ring-Frame's metal.
    Details.outputRound = icon:CreateTexture(nil, "BACKGROUND")
    Details.outputRound:SetSize(45, 45)
    Details.outputRound:SetPoint("CENTER")
    Details.outputBorder = icon:CreateTexture(nil, "BORDER")
    Art.Set(Details.outputBorder, "ring-frame", true)
    Details.outputBorder:SetPoint("CENTER")
    -- ProfessionsOutputButtonTemplate: the count over the ring at the 47 button's corner, on a soft shadow.
    local count = TradeSkillSkillIconCount
    count:SetDrawLayer("OVERLAY")
    count:SetFontObject(NumberFontNormalLarge)
    count:ClearAllPoints()
    count:SetPoint("BOTTOM", icon, "CENTER", 19.5, -22.5)
    Details.countShadow = icon:CreateTexture(nil, "ARTWORK")
    Art.Set(Details.countShadow, "count-shadow")
    Details.countShadow:SetAlpha(0.8)
    Details.countShadow:SetPoint("TOPLEFT", count, "TOPLEFT", -10, 10)
    Details.countShadow:SetPoint("BOTTOMRIGHT", count, "BOTTOMRIGHT", 10, -10)

    TradeSkillSkillName:ClearAllPoints()
    TradeSkillSkillName:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -2)
    TradeSkillSkillName:SetWidth(FORM_W - 12 - 53 - 14 - 4)
    TradeSkillSkillName:SetFontObject(outputFont)
    TradeSkillRequirementText:SetWidth(170)

    TradeSkillDescription:ClearAllPoints()
    TradeSkillDescription:SetPoint("TOPLEFT", child, "TOPLEFT", 12, -76)
    TradeSkillDescription:SetWidth(FORM_W - 24)

    for i = 1, MAX_TRADE_SKILL_REAGENTS or 8 do
        local reagent = _G["TradeSkillReagent" .. i]
        local name = reagent:GetName()
        reagent:SetWidth(REAGENT_W)
        reagent:ClearAllPoints()
        if i == 1 then
            reagent:SetPoint("TOPLEFT", TradeSkillReagentLabel, "BOTTOMLEFT", -2, -3)
        elseif i % 2 == 1 then
            reagent:SetPoint("TOPLEFT", _G["TradeSkillReagent" .. (i - 2)], "BOTTOMLEFT", 0, -2)
        else
            reagent:SetPoint("LEFT", _G["TradeSkillReagent" .. (i - 1)], "RIGHT", 0, 0)
        end
        local frameArt = _G[name .. "NameFrame"]
        if frameArt then frameArt:Hide() end
        local iconTex = _G[name .. "IconTexture"]
        local text = _G[name .. "Name"]
        text:ClearAllPoints()
        text:SetPoint("LEFT", iconTex, "RIGHT", 6, 0)
        text:SetWidth(REAGENT_W - 39 - 6 - 2)
        Details.slotBorders[i] = slotBorder(reagent, iconTex)
    end
    buildFavorite(child)
end

local function layoutCreateControls(craft, win)
    local F = P.Frame
    local createAll = F.Adopt(TradeSkillCreateAllButton, craft, "BOTTOMLEFT", win, "BOTTOMRIGHT", -362, 7)
    createAll:SetSize(80, 22)
    addon.ForeverUI.SkinButton(createAll)

    F.Adopt(TradeSkillDecrementButton, craft, "BOTTOMLEFT", win, "BOTTOMRIGHT", -185, 8)
    TradeSkillInputBox:SetParent(craft)
    TradeSkillInputBox:SetWidth(32)
    addon.ForeverUI.SkinEditBox(TradeSkillInputBox, { height = 20 })
    TradeSkillInputBox:SetJustifyH("CENTER")
    F.Adopt(TradeSkillIncrementButton, craft, "LEFT", TradeSkillInputBox, "RIGHT", 2, 0)

    local create = F.Adopt(TradeSkillCreateButton, craft, "BOTTOMRIGHT", win, "BOTTOMRIGHT", -9, 7)
    create:SetSize(80, 22)
    addon.ForeverUI.SkinButton(create)
end

function Details.Build()
    local craft, win = P.Frame.craft, P.Frame.win

    local size = P.Atlas["card-base"]
    Details.card = CreateFrame("Frame", nil, craft)
    Details.card:SetPoint("TOPLEFT", win, "TOPLEFT", CARD_X, CARD_Y)
    Details.card:SetSize(size[2], size[3])
    -- The insideframe's outer units are a fading shadow: the parchment ends under its opaque line instead.
    Details.cardBase = craft:CreateTexture(nil, "BACKGROUND")
    Details.cardBase:SetPoint("TOPLEFT", Details.card, "TOPLEFT", CARD_INSET, -CARD_INSET)
    Art.SetInset(Details.cardBase, "card-base", CARD_INSET)
    local at = P.ArtLayout.cardDraw
    Details.cardDraw = craft:CreateTexture(nil, "BORDER")
    Details.cardDraw:SetPoint("TOPLEFT", Details.card, "TOPLEFT", at[1], at[2])
    Details.cardDraw:Hide()
    Details.cardDrawRoom = { size[2] - CARD_INSET - at[1], size[3] - CARD_INSET + at[2] }
    -- The schematic form's common-insideframe, nine-sliced over the card.
    Details.cardFrame = Art.NineSlice(craft, "ARTWORK", "insideframe", 53)
    Art.PlaceNineSlice(Details.cardFrame, Details.card, 53)
    -- A profession with no card art at all: its own icon, toned like the card drawings, takes the drawing's place.
    Details.cardIcon = craft:CreateTexture(nil, "BORDER")
    Details.cardIcon:SetSize(96, 96)
    Details.cardIcon:SetPoint("TOPLEFT", Details.card, "TOPLEFT", 132, -300)
    Details.cardIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    Details.cardIcon:SetDesaturated(true)
    Details.cardIcon:SetVertexColor(0.85, 0.7, 0.5)
    Details.cardIcon:SetAlpha(0.35)
    Details.cardIcon:Hide()

    buildRankBar(craft, win)
    local link = P.Frame.Adopt(TradeSkillLinkButton, craft, "LEFT", Details.rankBar, "RIGHT", -2, -4)
    skinLinkButton(link)

    layoutForm(craft, win)
    layoutCreateControls(craft, win)
end

function Details.RefreshRank()
    if not Details.rankBar then return end
    local name, rank, maxRank = Model.Rank()
    local entry = P.Professions.EntryForLine(name)
    -- CanShowBar in Forever: Runeforging has no rank to show (always 1/1).
    local shown = not (entry and entry.key == "Runeforging")
    Details.rankBar:SetShownCompat(shown)
    if not shown then return end
    local ratio = maxRank > 0 and math.min(rank / maxRank, 1) or 0
    P.Fill.Update(Details.rankBar.fx, entry and entry.key, ratio, maxRank > 0 and rank >= maxRank)
    -- TRADESKILL_NAME_RANK in Forever: the profession's name before its rank.
    Details.rankBar.rank:Set(string.format("%s %d", name or "", rank), maxRank)
end

function Details.RefreshCard()
    if not Details.card then return end
    local entry = P.Professions.EntryForLine(Model.Rank())
    local key = entry and entry.key
    local drawing = Art.CardDrawing(key)
    if drawing then Art.SetClipped(Details.cardDraw, drawing, Details.cardDrawRoom[1], Details.cardDrawRoom[2]) end
    Details.cardDraw:SetShownCompat(drawing ~= nil)
    if Art.CardNeedsIcon(key) and entry then
        Details.cardIcon:SetTexture(select(3, GetSpellInfo(entry.ranks[1])))
        Details.cardIcon:Show()
    else
        Details.cardIcon:Hide()
    end
end

-- With every header collapsed Blizzard selects no recipe and leaves the icon empty; Forever hides the form then.
function Details.RefreshOutput()
    if not Details.outputBorder then return end
    local normal = TradeSkillSkillIcon:GetNormalTexture()
    local path = normal and normal:GetTexture()
    -- Blizzard keeps writing the square icon here; the round copy is what shows.
    if normal then normal:SetAlpha(0) end
    if path and path ~= Details.outputPath then
        SetPortraitToTexture(Details.outputRound, path)
        Details.outputRound:SetTexCoord(0.078125, 0.921875, 0.078125, 0.921875)
    end
    Details.outputPath = path
    Details.outputRound:SetShownCompat(path and true or false)
    Details.outputBorder:SetShownCompat(path and true or false)
    if path then
        -- Forever reads quality 0 when a recipe makes no item (enchants), so those get the grey ring.
        local link = GetTradeSkillItemLink(GetTradeSkillSelectionIndex())
        local quality = 0
        if link and link:find("item:", 1, true) then quality = select(3, GetItemInfo(link)) or 1 end
        local ring = OUTPUT_RINGS[quality]
        Art.Set(Details.outputBorder, ring or "ring-frame", true)
        -- The zoomed circle reaches r = size / 1.69 on the diagonals; the quality rings go see-through past 26.5.
        Details.outputRound:SetSize(ring and 43 or 45, ring and 43 or 45)
    end
    local count = TradeSkillSkillIconCount:GetText()
    Details.countShadow:SetShownCompat(path ~= nil and count ~= nil and count ~= "")
    -- ValidateControls in Forever: no recipe, no craft controls. SetSelection re-shows all but Create for a recipe.
    if path then
        TradeSkillCreateButton:Show()
        -- PROFESSIONS_CREATE_ALL_FORMAT, fitted like BigRedThreeSliceButtonTemplate (30 of padding).
        local _, _, available = GetTradeSkillInfo(GetTradeSkillSelectionIndex())
        local createAll = TradeSkillCreateAllButton
        createAll:SetText(string.format("%s [%d]", CREATE_ALL, available or 0))
        createAll:SetWidth(math.max(80, createAll:GetTextWidth() + 30))
    else
        for _, control in ipairs({ TradeSkillCreateButton, TradeSkillCreateAllButton, TradeSkillInputBox,
                                   TradeSkillDecrementButton, TradeSkillIncrementButton }) do
            control:Hide()
        end
    end
end

P.On("Built", Details.Build)
P.On("Update", Details.RefreshRank)
P.On("Update", Details.RefreshOutput)
P.On("Selection", Details.RefreshOutput)
P.On("Update", refreshSlotBorders)
P.On("Selection", refreshSlotBorders)
P.On("Update", refreshFavorite)
P.On("Selection", refreshFavorite)
P.On("FavoritesChanged", refreshFavorite)
P.On("ProfessionChanged", Details.RefreshCard)
