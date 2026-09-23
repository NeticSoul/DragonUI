-- ============================================================================
-- Spellbook reskin to retail style
-- ============================================================================

local addon = select(2, ...)
local L = addon.L

local SB = {}
SB.frame = nil
SB.minimized = true
SB.selected = 1
SB.userPickedCategory = false
SB.page = 1
SB.totalPages = 1
SB.search = ""
SB.hidePassives = false
SB.showRanks = false
SB.cards = {}
SB.headers = {}
SB.catTabs = {}
SB.elements = {}
SB._renderQueued = false
SB._rebindQueued = false
SB._widthQueued = false
SB._built = false

SB.MIN_W = 809
SB.FRAME_W = 1618
SB.FRAME_H = 883

local COG_SIZE, COG_RIGHT, COG_GAP = 20, 10, 10

local CHROME_T = 22
local PAGES_TOP = -56
local PAGES_BOT = 0
local BG_INSET_X = 0
local BG_TOP = -CHROME_T
local HEADER_H = 58
local BG_PAGE_TOP = PAGES_TOP - CHROME_T

local BG_DIR       = addon._dir .. "Spellbook\\"
local BG_LEFT      = "spellbook-background-evergreen-left"
local BG_RIGHT     = "spellbook-background-evergreen-right"
local BG_RIBBON    = "spellbook-background-evergreen-ribbon"
local BG_HEADER    = "spellbook-background-evergreen-header"
local BG_SHEET_ATLAS = "spellbook-background"

local CARD_W, CARD_H   = 216.667, 60
local CARD_XPAD        = 15
local CARD_YPAD        = 10
local GRID_COLS        = 3
local ICON             = 33.6
local ICON_BTN         = 40
local VIEW_W, VIEW_H   = 680, 620
local VIEW_TOP         = -122
local VIEW1_X          = 85
local VIEW2_X          = -50
local ROW_H            = CARD_H + CARD_YPAD
local SPAN_W           = GRID_COLS * CARD_W + (GRID_COLS - 1) * CARD_XPAD
local FONT_NAME_SIZE = 18
local FONT_SUB_SIZE = 13
local FONT_TAB_SIZE = 12
local FONT_TITLE_SIZE = 14
local FONT_PAGE_SIZE = 14
local rows = math.floor((VIEW_H + CARD_YPAD) / ROW_H)

addon.RefreshSpellbookScale = function(val)
  if type(val) == "number" and val > 0 then
    local db = addon:GetModuleConfig("spellbook")
    if db then db.scale = val end
  else
    local config = addon:GetModuleConfig("spellbook")
    val = (config and type(config.scale) == "number") and config.scale or 1
  end
  pcall(function() SB.frame:SetScale(val) end)
end

local BOOKTYPE_SPELL_ = BOOKTYPE_SPELL or "spell"
local BOOKTYPE_PET_   = BOOKTYPE_PET or "pet"

local function spellbookInk()
  if SPELLBOOK_FONT_COLOR and SPELLBOOK_FONT_COLOR.GetRGB then return SPELLBOOK_FONT_COLOR:GetRGB() end
  return 0.1804, 0.1059, 0.0588
end

local GOLD_S, SILVER_S, COPPER_S = GOLD_AMOUNT_SYMBOL or "g", SILVER_AMOUNT_SYMBOL or "s", COPPER_AMOUNT_SYMBOL or "c"
local function moneyString(cost)
  cost = cost or 0
  local g = math.floor(cost / 10000)
  local s = math.floor((cost % 10000) / 100)
  local c = cost % 100
  if g > 0 then return ("%d%s %d%s %d%s"):format(g, GOLD_S, s, SILVER_S, c, COPPER_S) end
  if s > 0 then return ("%d%s %d%s"):format(s, SILVER_S, c, COPPER_S) end
  return ("%d%s"):format(c, COPPER_S)
end

local TRAINEE_TEXT_R, TRAINEE_TEXT_G, TRAINEE_TEXT_B = 0.60, 0.52, 0.38
local TRAINEE_SUB_R,  TRAINEE_SUB_G,  TRAINEE_SUB_B  = 0.68, 0.61, 0.46
local TRAINEE_BORDER_R, TRAINEE_BORDER_G, TRAINEE_BORDER_B = 0.62, 0.56, 0.47

local function playerClassKey()
  local _, classFile = UnitClass("player")
  if not classFile then return nil end
  return classFile:lower()
end

local function isEnabled() return addon:IsModuleEnabled("spellbook") end

addon.SpellsByClass = addon.SpellsByClass or {}
local _pendingOverrides = {}

_G.AddOverriddenSpells = function(...)
  for i = 1, select("#", ...) do
    local chain = select(i, ...)
    if type(chain) == "table" then _pendingOverrides[#_pendingOverrides + 1] = chain end
  end
end

_G.DragonUI_RegisterClassSpells = function(class, spells)
  if type(class) ~= "string" or type(spells) ~= "table" then return end
  addon.SpellsByClass[class:lower()] = { spells = spells, overrides = _pendingOverrides }
  _pendingOverrides = {}
end

local function setBgTex(tex, atlas)
  if not tex then return end
  tex:set_atlas(atlas, false)
end

local function applyBgWidth()
  if not (SB.frame and SB.bgLeft) then return end
  if SB.bgRight  then if SB.minimized then SB.bgRight:Hide()  else SB.bgRight:Show()  end end
  if SB.bgRibbon then if SB.minimized then SB.bgRibbon:Hide() else SB.bgRibbon:Show() end end
  setBgTex(SB.bgLeft, SB.minimized and BG_RIGHT or BG_LEFT)
  SB.bgLeft:ClearAllPoints()
  if SB.minimized then
    SB.bgLeft:SetPoint("TOPLEFT", SB.frame, "TOPLEFT", BG_INSET_X, BG_PAGE_TOP)
    SB.bgLeft:SetPoint("BOTTOMRIGHT", SB.frame, "BOTTOMRIGHT", -BG_INSET_X, PAGES_BOT)
  else
    SB.bgLeft:SetPoint("TOPLEFT", SB.frame, "TOPLEFT", BG_INSET_X, BG_PAGE_TOP)
    SB.bgLeft:SetPoint("BOTTOMRIGHT", SB.frame, "BOTTOM", -1, PAGES_BOT)
  end
end

local function buildBackground()
  if SB.bgLeft or not SB.frame then return end
  SB.bgLeft = SB.frame:CreateTexture(nil, "BACKGROUND", nil, -2)
  setBgTex(SB.bgLeft, BG_LEFT)
  SB.bgLeft:SetPoint("TOPLEFT", SB.frame, "TOPLEFT", BG_INSET_X, BG_PAGE_TOP)
  SB.bgLeft:SetPoint("BOTTOMRIGHT", SB.frame, "BOTTOM", -1, PAGES_BOT)

  SB.bgRight = SB.frame:CreateTexture(nil, "BACKGROUND", nil, -2)
  setBgTex(SB.bgRight, BG_RIGHT)
  SB.bgRight:SetPoint("TOPLEFT", SB.frame, "TOP", 1, BG_PAGE_TOP)
  SB.bgRight:SetPoint("BOTTOMRIGHT", SB.frame, "BOTTOMRIGHT", -BG_INSET_X, PAGES_BOT)

  local RIBBON_W = 102
  local RIBBON_X = 28
  SB.bgRibbon = SB.frame:CreateTexture(nil, "OVERLAY", nil, -1)
  setBgTex(SB.bgRibbon, BG_RIBBON)
  SB.bgRibbon:SetSize(RIBBON_W, RIBBON_W * 557 / 102)
  SB.bgRibbon:SetPoint("TOP", SB.frame, "TOP", RIBBON_X, BG_PAGE_TOP)
  if SB.minimized then SB.bgRibbon:Hide() else SB.bgRibbon:Show() end

  SB.bgHeader = SB.frame:CreateTexture(nil, "BORDER", nil, 0)
  setBgTex(SB.bgHeader, BG_HEADER)
  SB.bgHeader:SetHeight(HEADER_H)
  SB.bgHeader:SetPoint("TOPLEFT", SB.frame, "TOPLEFT", 0, BG_TOP)
  SB.bgHeader:SetPoint("TOPRIGHT", SB.frame, "TOPRIGHT", 0, BG_TOP)
  applyBgWidth()
end

function SB._reapplyBg()
  if not SB.frame then return end
  setBgTex(SB.bgLeft,   SB.minimized and BG_RIGHT or BG_LEFT)
  setBgTex(SB.bgRight,  BG_RIGHT)
  setBgTex(SB.bgRibbon, BG_RIBBON)
  setBgTex(SB.bgHeader, BG_HEADER)
end

local function prewarmBackgroundBLP()
  if SB._bgPrewarmed then return end
  SB._bgPrewarmed = true
  local pw = CreateFrame("Frame", nil, UIParent)
  pw:SetFrameStrata("BACKGROUND"); pw:SetFrameLevel(1)
  pw:SetSize(8, 8)
  pw:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
  local t = pw:CreateTexture(nil, "BACKGROUND")
  t:SetAllPoints(pw)
  t:SetTexture(BG_DIR .. BG_SHEET_ATLAS)
  pw:Show()
  local n = 0
  pw:SetScript("OnUpdate", function(self, dt)
    n = n + dt
    if n >= 1.0 then
      self:SetScript("OnUpdate", nil)
      t:SetTexture(BG_DIR .. BG_SHEET_ATLAS)
    end
  end)
  SB._bgPrewarm = pw
end

local function buildChrome()
  local layout = NineSliceUtils and NineSliceUtils.GetLayout("PortraitFrameTemplate")
  if layout and SB.frame then NineSliceUtils.ApplyLayout(SB.frame, layout) end
  local bg = SB.frame:CreateTexture(nil, "BACKGROUND", nil, -6)
  bg:SetTexture(addon._dir .. "UI\\ui-background-rock", "REPEAT", "REPEAT")
  bg:SetHorizTile(true); bg:SetVertTile(true)
  bg:SetPoint("TOPLEFT", SB.frame, "TOPLEFT", 2, -21)
  bg:SetPoint("BOTTOMRIGHT", SB.frame, "BOTTOMRIGHT", -2, 2)
  local streaks = SB.frame:CreateTexture(nil, "BORDER")
  streaks:set_atlas("_UI-Frame-TopTileStreaks")
  streaks:SetHorizTile(true); streaks:SetHeight(43)
  streaks:SetPoint("TOPLEFT", SB.frame, "TOPLEFT", 6, -21)
  streaks:SetPoint("TOPRIGHT", SB.frame, "TOPRIGHT", -2, -21)

  local portrait = SB.frame:CreateTexture(nil, "ARTWORK")
  portrait:SetSize(58, 58)
  portrait:SetPoint("TOPLEFT", SB.frame, "TOPLEFT", -2, 6)
  local _, classFile = UnitClass("player")
  if classFile then
    if addon.UF and addon.UF.ApplyClassPortraitIcon then
      if addon.UF.ApplyClassPortraitIcon(portrait, classFile, true) then
        portrait:SetSize(52, 52)
        portrait:SetPoint("TOPLEFT", SB.frame, "TOPLEFT", 1, 3)
      end
    end
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if coords and not portrait:GetTexture() then
      portrait:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
      portrait:SetTexCoord(unpack(coords))
    end
  end

  local title = SB.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", SB.frame, "TOP", 0, -5)
  title:SetText(L["Spellbook"] or "Spellbook")
  local close = CreateFrame("Button", "DragonUISpellBookFrameClose", SB.frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", SB.frame, "TOPRIGHT", 1, 0)
  if addon.CharacterPanel and addon.CharacterPanel.ModernizeCloseButton then
    addon.CharacterPanel.ModernizeCloseButton(close, SB.frame, 1, 0)
  end
  SB.frame.CloseButton = close
end

local function buildMinimize()
  local f = SB.frame
  if not f then return end
  if f.minBtn then return f.minBtn end
  local b = CreateFrame("Button", "DragonUISpellBookMinimizeButton", f)
  b:SetSize(24, 24)
  if f.CloseButton then
    b:SetPoint("RIGHT", f.CloseButton, "LEFT", -2, 0)
  else
    b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -27, 0)
  end
  local baseLvl = (f.GetFrameLevel and f:GetFrameLevel()) or 1
  b:SetFrameLevel(baseLvl + 21)
  local nt = b:CreateTexture(nil, "ARTWORK"); nt:SetAllPoints(b); b:SetNormalTexture(nt)
  local pt = b:CreateTexture(nil, "ARTWORK"); pt:SetAllPoints(b); b:SetPushedTexture(pt)
  local ht = b:CreateTexture(nil, "HIGHLIGHT"); ht:SetAllPoints(b); b:SetHighlightTexture(ht)
  ht:set_atlas("redbutton-highlight", false)
  local function syncIcon()
    if SB.minimized then
      nt:set_atlas("redbutton-expand", false)
      pt:set_atlas("redbutton-expand-pressed", false)
    else
      nt:set_atlas("redbutton-condense", false)
      pt:set_atlas("redbutton-condense-pressed", false)
    end
  end
  b._syncIcon = syncIcon
  syncIcon()
  b:SetScript("OnClick", function() SB.SetMinimized(not SB.minimized) end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(SB.minimized and (L["Show second page"] or "Show second page") or (L["Show single page"] or "Show single page"))
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  f.minBtn = b
  SB.maxmin = b
  return b
end

local FONT_TAB_SIZE = 12

local function categoryTab(i)
  local t = SB.catTabs[i]
  if t then return t end
  t = CreateFrame("Button", "DragonUISpellBookTab" .. i, SB.frame, "CharacterFrameTabButtonTemplate")
  t:SetID(i)
  t:SetHeight(32)
  t:SetScript("OnClick", function(self)
    if PlaySound then PlaySound("igCharacterInfoTab") end
    SB.SelectCategory(self:GetID())
  end)
  if addon.CharacterPanel and addon.CharacterPanel.ReskinTab then
    addon.CharacterPanel.ReskinTab(t, true)
  end
  t._duiRelayout = function()
    if not SB.frame or not t:IsShown() then return end
    local prev
    for j, tab in ipairs(SB.catTabs) do
      if tab and tab:IsShown() then
        tab:ClearAllPoints()
        if prev then
          tab:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", 2, 0)
        else
          tab:SetPoint("BOTTOMLEFT", SB.frame, "TOPLEFT", 70, -(CHROME_T + HEADER_H))
        end
        prev = tab
      end
    end
  end
  SB.catTabs[i] = t
  return t
end

local function persistCogOptions()
  local cfg = addon:GetModuleConfig("spellbook")
  if cfg then
    cfg.showRanks = SB.showRanks
    cfg.hidePassives = SB.hidePassives
  end
end

local function buildSearch()
  if SB.searchBox then return SB.searchBox end
  local sb = CreateFrame("EditBox", "DragonUISpellBookSearchBox", SB.frame)
  sb:SetSize(170, 28)
  sb:SetPoint("TOPRIGHT", SB.frame, "TOPRIGHT", -(COG_RIGHT + COG_SIZE + COG_GAP), -(CHROME_T + 13))
  sb:SetAutoFocus(false)
  sb:SetFontObject(_G.ChatFontNormal or _G.GameFontHighlightSmall)
  sb:SetTextInsets(24, 6, 0, 0)
  sb:SetMaxLetters(40)
  sb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  sb:SetScript("OnEnterPressed",  function(self) self:ClearFocus() end)
  if sb.SetBackdrop then
    sb:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    sb:SetBackdropColor(0, 0, 0, 0.6)
    sb:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
  end
  local icon = sb:CreateTexture(nil, "OVERLAY")
  icon:SetSize(14, 14)
  icon:SetPoint("LEFT", sb, "LEFT", 6, 0)
  icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
  local ph = sb:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  ph:SetPoint("LEFT", sb, "LEFT", 24, 0)
  ph:SetText(_G.SEARCH or "Search")
  sb.placeholder = ph
  local function applyFilter()
    local q = (sb:GetText() or ""):lower()
    if q ~= SB.search then
      SB.search = q
      SB.page = 1
      SB.RenderCards()
    end
  end
  sb:SetScript("OnTextChanged", function(self)
    if sb.placeholder then
      if (self:GetText() or "") == "" then sb.placeholder:Show() else sb.placeholder:Hide() end
    end
    applyFilter()
  end)
  sb:SetScript("OnEditFocusGained", function() if sb.placeholder then sb.placeholder:Hide() end end)
  sb:SetScript("OnEditFocusLost", function(self)
    if sb.placeholder and (self:GetText() or "") == "" then sb.placeholder:Show() end
  end)
  SB.searchBox = sb

  local cog = CreateFrame("Button", "DragonUISpellBookSettings", SB.frame)
  cog:SetSize(COG_SIZE, COG_SIZE)
  cog:SetPoint("LEFT", sb, "RIGHT", COG_GAP, 0)
  cog:SetPoint("TOP", sb, "TOP", 0, -1)
  local gear = cog:CreateTexture(nil, "ARTWORK")
  gear:set_atlas("questlog-icon-setting", true)
  gear:SetPoint("CENTER", cog, "CENTER", 0, 0)
  local glow = cog:CreateTexture(nil, "HIGHLIGHT")
  glow:set_atlas("questlog-icon-setting", true)
  glow:SetPoint("CENTER", cog, "CENTER", 0, 0)
  glow:SetBlendMode("ADD")
  glow:SetAlpha(0.4)
  cog:SetScript("OnClick", function(self)
    addon.Menu.Open(self, {
      { text = L["Spellbook settings"], isTitle = true },
      {
        text = L["Show All Ranks"],
        checked = function() return SB.showRanks end,
        keepShown = true,
        func = function()
          SB.showRanks = not SB.showRanks
          SB.page = 1
          persistCogOptions()
          SB.RenderCards()
        end,
      },
      {
        text = L["Hide Passives"],
        checked = function() return SB.hidePassives end,
        keepShown = true,
        func = function()
          SB.hidePassives = not SB.hidePassives
          SB.page = 1
          persistCogOptions()
          SB.RenderCards()
        end,
      },
    })
  end)
  cog:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L["Spellbook settings"])
    GameTooltip:Show()
  end)
  cog:SetScript("OnLeave", function() GameTooltip:Hide() end)
  SB.settingsCog = cog

  return sb
end


local CORNER_COLS, CORNER_ROWS = 4, 2
local CORNER_DURATION = 0.25
local CORNER_L, CORNER_R = 0.000977, 0.586914
local CORNER_T, CORNER_B = 0.000977, 0.303711
local CORNER_FRAME_W = (CORNER_R - CORNER_L) / CORNER_COLS
local CORNER_FRAME_H = (CORNER_B - CORNER_T) / CORNER_ROWS

local function cornerFrameTexCoords(frame)
  local row = math.floor((frame - 1) / CORNER_COLS)
  local col = (frame - 1) % CORNER_COLS
  local l = CORNER_L + col * CORNER_FRAME_W
  local r = l + CORNER_FRAME_W
  local t = CORNER_T + row * CORNER_FRAME_H
  local b = t + CORNER_FRAME_H
  return l, r, t, b
end

local function buildCornerFlipbook()
  if SB.corner then return SB.corner end
  local drv = CreateFrame("Frame", nil, SB.frame)
  drv:SetSize(1, 1)
  drv:SetPoint("BOTTOMRIGHT", SB.frame, "BOTTOMRIGHT", 0, 0)
  drv:EnableMouse(false)
  local c = SB.frame:CreateTexture(nil, "BORDER", nil, 1)
  c:set_atlas("spellbook-corner-flipbook-evergreen", false)
  c:SetSize(150, 155)
  c:SetPoint("BOTTOMRIGHT", SB.frame, "BOTTOMRIGHT", -15, 6)
  c:SetTexCoord(cornerFrameTexCoords(1))
  c._frame = 1
  c._t = 0
  c:Show()
  c._driver = drv
  SB.corner = c
  return c
end

function SB._cornerPlay(corner, reverse)
  if not (corner and corner._driver) then return end
  local drv = corner._driver
  drv:SetScript("OnUpdate", nil)
  corner._dir = reverse and -1 or 1
  corner._t = 0
  if not reverse then
    corner._frame = 1
    corner:SetTexCoord(cornerFrameTexCoords(1))
    corner:Show()
  end
  local function stop(self)
    self:SetScript("OnUpdate", nil)
  end
  drv:SetScript("OnUpdate", function(self, dt)
    corner._t = corner._t + dt
    local per = CORNER_DURATION / (CORNER_COLS * CORNER_ROWS - 1)
    while corner._t >= per and corner._frame >= 1 and corner._frame <= CORNER_COLS * CORNER_ROWS do
      corner._t = corner._t - per
      local next = corner._frame + corner._dir
      if next < 1 or next > CORNER_COLS * CORNER_ROWS then
        stop(self)
        return
      end
      corner._frame = next
      corner:SetTexCoord(cornerFrameTexCoords(corner._frame))
    end
  end)
end

local cornerFlipbookPlay = SB._cornerPlay

local function buildPaging()
  if SB.paging then return SB.paging end
  local p = CreateFrame("Frame", "DragonUISpellBookPaging", SB.frame)
  p:SetSize(146, 32)
  p:SetPoint("BOTTOMRIGHT", SB.frame, "BOTTOMRIGHT", -90, 14)
  p.label = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  p.label:SetPoint("LEFT", 0, 0)
  p.label:SetTextColor(0, 0, 0)
  p.label:SetShadowColor(0, 0, 0, 0)
  do local f, _, g = p.label:GetFont(); if f and FONT_PAGE_SIZE > 0 then p.label:SetFont(f, FONT_PAGE_SIZE, g) end end
  local function pageButton(prefix, onClick)
    local b = CreateFrame("Button", nil, p)
    b:SetSize(32, 32)
    b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. prefix .. "Page-Up")
    b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. prefix .. "Page-Down")
    b:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. prefix .. "Page-Disabled")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b:SetScript("OnClick", onClick)
    return b
  end
  p.prev = pageButton("Prev", function() SB.SetPage(SB.page - 1) end)
  p.next = pageButton("Next", function() SB.SetPage(SB.page + 1) end)
  p.next:SetPoint("RIGHT", 0, 0)
  p.prev:SetPoint("RIGHT", p.next, "LEFT", -8, 0)
  local corner = buildCornerFlipbook()
  local function cornerEnter() if (SB.totalPages or 1) > 1 then cornerFlipbookPlay(corner, false) end end
  local function cornerLeave() if (SB.totalPages or 1) > 1 then cornerFlipbookPlay(corner, true) end end
  p.prev:SetScript("OnEnter", cornerEnter)
  p.prev:SetScript("OnLeave", cornerLeave)
  p.next:SetScript("OnEnter", cornerEnter)
  p.next:SetScript("OnLeave", cornerLeave)
  SB.paging = p
  return p
end

function SB.SetPage(n)
  local total = SB.totalPages or 1
  if n < 1 then n = 1 elseif n > total then n = total end
  if n == SB.page and SB.frame and SB.frame:IsShown() then return end
  SB.page = n
  SB.RenderCards()
end

local function buildCategories()
  local cats = {}
  local numTabs = (GetNumSpellTabs and GetNumSpellTabs()) or 0
  local general
  if numTabs >= 1 then
    local name, _, offset, numSlots = GetSpellTabInfo(1)
    general = { kind = "flat", label = name or (GENERAL or "General"),
                sections = { { offset = offset or 0, numSlots = numSlots or 0 } } }
  end
  local className = (UnitClass and UnitClass("player")) or "Class"
  local sections = {}
  if numTabs >= 2 then
    for i = 2, numTabs do
      local sName, _, offset, numSlots = GetSpellTabInfo(i)
      if numSlots and numSlots > 0 then
        sections[#sections + 1] = { title = sName, offset = offset, numSlots = numSlots }
      end
    end
  end
  if #sections > 0 then
    cats[#cats + 1] = { kind = "sectioned", label = className, sections = sections }
  end
  if general then cats[#cats + 1] = general end
  local numPet = (HasPetSpells and HasPetSpells()) or 0
  if numPet and numPet > 0 then
    cats[#cats + 1] = { kind = "pet", label = PET or "Pet", numSlots = numPet }
  end
  local key = playerClassKey()
  if key and addon.SpellsByClass and addon.SpellsByClass[key] then
    cats[#cats + 1] = { kind = "traineable", label = L["To Learn"] or "To Learn" }
  end
  SB.categories = cats
  return cats
end

local function catSlotCount(cat)
  if not cat then return 0 end
  if cat.kind == "pet" then return cat.numSlots or 0 end
  local total = 0
  for _, sec in ipairs(cat.sections or {}) do total = total + (sec.numSlots or 0) end
  return total
end

local function pickDefaultSelected(cats)
  for i, cat in ipairs(cats) do
    if catSlotCount(cat) > 0 then return i end
  end
  return 1
end

function SB.SelectCategory(index)
  SB.selected = index
  SB.userPickedCategory = true
  SB.page = 1
  SB.Refresh()
end

local function matchesSearch(name)
  if SB.search == "" then return true end
  return name ~= nil and name:lower():find(SB.search, 1, true) ~= nil
end

local function slotIcon(slot, bookType)
  if GetSpellTexture then return GetSpellTexture(slot, bookType) end
end

local function makeCardEntry(slot, bookType)
  local name, subName
  if GetSpellName then name, subName = GetSpellName(slot, bookType) end
  if not name or name == "" then return nil end
  return {
    kind = "card", slot = slot, bookType = bookType, name = name, subName = subName,
    passive = IsPassiveSpell and IsPassiveSpell(slot, bookType) or false,
    icon = slotIcon(slot, bookType),
  }
end

local function collapseRanks(list)
  local out, idxByName = {}, {}
  for _, e in ipairs(list) do
    local rank = tonumber((e.subName or ""):match("(%d+)"))
    local prev = rank and idxByName[e.name]
    if prev then
      if rank > (out[prev]._rank or 0) then e._rank = rank; out[prev] = e end
    else
      e._rank = rank
      out[#out + 1] = e
      if rank then idxByName[e.name] = #out end
    end
  end
  return out
end

local function addCards(els, offset, count, bookType)
  local list = {}
  for s = offset + 1, offset + count do
    local e = makeCardEntry(s, bookType)
    if e and matchesSearch(e.name) and not (SB.hidePassives and e.passive) then
      list[#list + 1] = e
    end
  end
  if not SB.showRanks then list = collapseRanks(list) end
  for _, e in ipairs(list) do els[#els + 1] = e end
  return #list
end

local function buildToLearn(els)
  local key = playerClassKey()
  local db = key and addon.SpellsByClass and addon.SpellsByClass[key]
  if not (db and db.spells) then return end
  local IsKnown = IsSpellKnown
  local faction = UnitFactionGroup and UnitFactionGroup("player") or ""
  local entries = {}
  for level, list in pairs(db.spells) do
    if type(list) == "table" then
      for _, rec in ipairs(list) do
        if rec and rec.id and (not rec.faction or rec.faction == faction) then
          if not (IsKnown and IsKnown(rec.id)) then
            local ok = true
            if rec.requiredIds then
              for _, rid in ipairs(rec.requiredIds) do
                if rid ~= rec.id and not (IsKnown and IsKnown(rid)) then ok = false break end
              end
            end
            if ok and rec.requiredTalentId and not (IsKnown and IsKnown(rec.requiredTalentId)) then
              ok = false
            end
            if ok then entries[#entries + 1] = { id = rec.id, level = level, cost = rec.cost or 0 } end
          end
        end
      end
    end
  end
  table.sort(entries, function(a, b)
    if a.level ~= b.level then return a.level < b.level end
    return a.id < b.id
  end)
  for _, e in ipairs(entries) do
    local name, rank, icon
    if GetSpellInfo then name, rank, icon = GetSpellInfo(e.id) end
    if not name then name = tostring(e.id) end
    if matchesSearch(name) then
      els[#els + 1] = { kind = "card", traineable = true, spellId = e.id, name = name,
                        rank = rank, icon = icon, level = e.level, cost = e.cost }
    end
  end
end

local function buildElements()
  local cats = SB.categories or buildCategories()
  if SB.selected > #cats then SB.selected = 1 end
  local cat = cats[SB.selected]
  local els = {}
  if cat then
    if cat.kind == "traineable" then
      buildToLearn(els)
    elseif cat.kind == "pet" then
      addCards(els, 0, cat.numSlots, BOOKTYPE_PET_)
    elseif cat.kind == "sectioned" then
      for _, sec in ipairs(cat.sections) do
        local headerIdx = #els + 1
        els[#els + 1] = { kind = "header", label = sec.title }
        if addCards(els, sec.offset, sec.numSlots, BOOKTYPE_SPELL_) == 0 then
          table.remove(els, headerIdx)
        end
      end
    else
      local sec = cat.sections[1]
      if sec then addCards(els, sec.offset, sec.numSlots, BOOKTYPE_SPELL_) end
    end
  end
  SB.elements = els
  return els
end

local function flowLayout(els)
  local R, p, r, c = rows, 0, 0, 0
  local function advance() r = r + 1; if r >= R then r = 0; p = p + 1 end end
  for _, e in ipairs(els) do
    if e.kind == "header" then
      if c > 0 then c = 0; advance() end
      e.p, e.r = p, r
      advance(); c = 0
    else
      e.p, e.r, e.c = p, r, c
      c = c + 1
      if c >= GRID_COLS then c = 0; advance() end
    end
  end
  local maxP = 0
  for _, e in ipairs(els) do if e.p and e.p > maxP then maxP = e.p end end
  SB.totalPages = math.max(1, math.ceil((maxP + 1) / (SB.minimized and 1 or 2)))
end

local function pagePoint(p, r, c)
  local y = VIEW_TOP - r * ROW_H
  if SB.minimized or (p % 2) == 0 then
    return "TOPLEFT", "TOPLEFT", VIEW1_X + (c or 0) * (CARD_W + CARD_XPAD), y
  else
    return "TOPLEFT", "TOPRIGHT", (VIEW2_X - VIEW_W) + (c or 0) * (CARD_W + CARD_XPAD), y
  end
end

local function createCard(i)
  local card = CreateFrame("Frame", "DragonUISpellBookCard" .. i, SB.frame)
  card:SetSize(CARD_W, CARD_H)

  card.Backplate = card:CreateTexture(nil, "BACKGROUND")
  card.Backplate:set_atlas("spellbook-item-backplate", true)
  card.Backplate:SetPoint("CENTER", 5, -5)
  card.Backplate:SetAlpha(0.25)

  local b = CreateFrame("Button", "DragonUISpellBookCard" .. i .. "Btn", card, "SecureActionButtonTemplate")
  b:SetAllPoints(card)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  card.Button = b

  b.IconSlot = CreateFrame("Frame", nil, b)
  b.IconSlot:SetSize(ICON_BTN, ICON_BTN)
  b.IconSlot:SetPoint("LEFT", b, "LEFT", 0, 0)

  b.Icon = b:CreateTexture(nil, "ARTWORK", nil, -1)
  b.Icon:SetSize(ICON, ICON)
  b.Icon:SetPoint("CENTER", b.IconSlot, "CENTER")
  b.Icon:SetTexCoord(0, 1, 0, 1)

  b.IconRound = b:CreateTexture(nil, "ARTWORK", nil, -1)
  b.IconRound:SetSize(ICON, ICON)
  b.IconRound:SetPoint("CENTER", b.IconSlot, "CENTER")
  b.IconRound:Hide()

  b.Border = b:CreateTexture(nil, "OVERLAY", nil, 1)
  b.Border:SetAllPoints(b.IconSlot)

  b.IconHighlight = b:CreateTexture(nil, "OVERLAY", nil, 2)
  b.IconHighlight:SetAllPoints(b.Border)
  b.IconHighlight:SetBlendMode("ADD")
  b.IconHighlight:SetAlpha(0.35)
  b.IconHighlight:Hide()

  card.Name = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
  card.Name:SetJustifyH("LEFT")
  card.Name:SetPoint("TOPLEFT", b.Border, "TOPRIGHT", 10, -1)
  card.Name:SetPoint("RIGHT", card, "RIGHT", -4, 0)
  if card.Name.SetWordWrap then card.Name:SetWordWrap(true) end
  if card.Name.SetMaxLines then card.Name:SetMaxLines(2) end
  card.Name:SetShadowColor(0, 0, 0, 0)
  do local f, _, g = card.Name:GetFont(); if f and FONT_NAME_SIZE > 0 then card.Name:SetFont(f, FONT_NAME_SIZE, g) end end

  card.SubName = card:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  card.SubName:SetJustifyH("LEFT")
  card.SubName:SetPoint("TOPLEFT", card.Name, "BOTTOMLEFT", 0, -2)
  card.SubName:SetPoint("RIGHT", card.Name, "RIGHT")
  card.SubName:SetTextColor(0.82, 0.74, 0.55)
  card.SubName:SetShadowColor(0, 0, 0, 0)
  do local f, _, g = card.SubName:GetFont(); if f and FONT_SUB_SIZE > 0 then card.SubName:SetFont(f, FONT_SUB_SIZE, g) end end

  local function cardEnter()
    local trainee = card.traineable
    card.Backplate:SetAlpha(trainee and 0.25 or 1)
    if trainee then
      GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
      local shown = false
      if card.spellId and GameTooltip.SetSpellByID then
        local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, card.spellId)
        shown = ok and GameTooltip:IsOwned(card) and (GameTooltip:NumLines() or 0) > 0
      end
      if not shown and card.spellId and GameTooltip.SetHyperlink and card.fallbackTipName then
        local link = ("|Hspell:%d|h[%s]|h"):format(card.spellId, card.fallbackTipName)
        local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
        shown = ok and GameTooltip:IsOwned(card) and (GameTooltip:NumLines() or 0) > 0
      end
      if not shown and card.fallbackTipName then
        GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
        GameTooltip:SetText(card.fallbackTipName, TRAINEE_TEXT_R, TRAINEE_TEXT_G, TRAINEE_TEXT_B, 1, true)
      end
      GameTooltip:AddDoubleLine(L["Requires Level"] or "Requires Level", tostring(card.level or 0))
      GameTooltip:AddDoubleLine(L["Training Cost"] or "Training Cost", moneyString(card.cost or 0))
      GameTooltip:Show()
      return
    end
    b.IconHighlight:SetAlpha(0.35); b.IconHighlight:Show()
    GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
    local shown = false
    if card.slot and GameTooltip.SetSpell then
      local ok = pcall(GameTooltip.SetSpell, GameTooltip, card.slot, card.bookType)
      shown = ok and GameTooltip:IsOwned(card) and (GameTooltip:NumLines() or 0) > 0
    end
    if not shown and card.fallbackTipName then
      GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
      GameTooltip:SetText(card.fallbackTipName, 1, 1, 1, 1, true)
      if card.fallbackTipSub and card.fallbackTipSub ~= "" then
        GameTooltip:AddLine(card.fallbackTipSub, 0.6, 0.6, 0.6, true)
      end
      GameTooltip:Show()
    end
  end
  local function cardLeave()
    if card:IsMouseOver() then return end
    b.IconHighlight:Hide(); b.IconHighlight:SetAlpha(0.35)
    card.Backplate:SetAlpha(card.traineable and 0.15 or 0.25)
    GameTooltip:Hide()
  end
  local function cardLeave()
    if card:IsMouseOver() then return end
    b.IconHighlight:Hide(); b.IconHighlight:SetAlpha(0.35)
    card.Backplate:SetAlpha(0.25)
    GameTooltip:Hide()
  end
  card:EnableMouse(true)
  card:SetScript("OnEnter", cardEnter)
  card:SetScript("OnLeave", cardLeave)
  b:SetScript("OnEnter", cardEnter)
  b:SetScript("OnLeave", cardLeave)

  local function cardPickup()
    if card.passive or card.traineable then return end
    if card.slot and PickupSpell then
      PickupSpell(card.slot, card.bookType)
    end
  end
  b:SetScript("OnDragStart", function() cardPickup() end)
  b:SetAttribute("shift-type*", "")
  b:SetAttribute("ctrl-type*", "")
  b:HookScript("OnClick", function(self, btn, down)
    if down or card.passive or card.traineable then return end
    if IsModifiedClick and IsModifiedClick("CHATLINK") then
      local link
      if card.slot then link = GetSpellLink and GetSpellLink(card.slot, card.bookType) end
      if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
    elseif IsModifiedClick and IsModifiedClick("PICKUPACTION") then
      cardPickup()
    end
  end)

  SB.cards[i] = card
  return card
end

local function createHeader(i)
  local h = CreateFrame("Frame", nil, SB.frame)
  h:SetSize(SPAN_W, 51)
  h.Plate = h:CreateTexture(nil, "BACKGROUND")
  h.Plate:set_atlas("spellbook-list-backplate", false)
  h.Plate:SetSize(416, 106)
  h.Plate:SetPoint("LEFT", h, "LEFT", -85, 10)
  h.Plate:SetAlpha(0.65)
  local ink = { spellbookInk() }
  h.Text = h:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
  h.Text:SetJustifyH("LEFT")
  h.Text:SetPoint("TOPLEFT", -8, 0)
  h.Text:SetPoint("BOTTOMRIGHT", -60, 0)
  h.Text:SetTextColor(ink[1], ink[2], ink[3])
  h.Border = h:CreateTexture(nil, "ARTWORK")
  h.Border:set_atlas("spellbook-divider", false)
  h.Border:SetHeight(11)
  h.Border:SetPoint("BOTTOMLEFT", -32, 0)
  h.Border:SetPoint("BOTTOMRIGHT", -60, 0)
  SB.headers[i] = h
  return h
end

local function applyTraineableVisual(card, e)
  card.slot, card.bookType = nil, nil
  card.passive = false
  card.traineable = true
  card.spellId = e.spellId
  local b = card.Button
  card.Name:SetText(e.name or "")
  card.level = e.level
  card.cost = e.cost
  local sub = { ("Level %d"):format(e.level or 0) }
  if e.rank and e.rank ~= "" then sub[#sub + 1] = e.rank end
  card.SubName:SetText(table.concat(sub, "  ·  "))
  card.tipName = e.name
  card.fallbackTipName = e.name
  card.fallbackTipSub = nil
  local ir, ig, ib = spellbookInk()
  card.Name:SetTextColor(ir, ig, ib)
  card.SubName:SetTextColor(ir, ig, ib)

  b.Icon:SetTexture(e.icon or "")
  b.Icon:SetDesaturated(true)
  b.Icon:SetAlpha(0.6)
  b.Icon:Show()
  if b.IconRound then b.IconRound:Hide() end
  b.Border:set_atlas("spellbook-item-iconframe", false)
  b.Border:ClearAllPoints()
  b.Border:SetPoint("TOPLEFT",     b.IconSlot, "TOPLEFT",     -11, 1)
  b.Border:SetPoint("BOTTOMRIGHT", b.IconSlot, "BOTTOMRIGHT", 1, -7)
  b.Border:SetVertexColor(TRAINEE_BORDER_R, TRAINEE_BORDER_G, TRAINEE_BORDER_B, 1)
  b.IconHighlight:Hide(); b.IconHighlight:SetAlpha(0.35)
  card.Backplate:SetAlpha(0.15)
  b:SetAttribute("type", nil); b:SetAttribute("spell", nil)
  b:SetAttribute("type2", nil); b:SetAttribute("macrotext2", nil)
end

local function applyCardVisual(card, e)
  if e.traineable then
    applyTraineableVisual(card, e)
    return
  end
  card.traineable = false
  card.spellId = nil
  card.slot, card.bookType = e.slot, e.bookType
  card.passive = e.passive and true or false
  local b = card.Button
  card.Name:SetText(e.name or "")
  card.SubName:SetText(e.subName or "NONE")
  card.tipName = e.name
  card.fallbackTipName = e.name
  card.fallbackTipSub = e.subName
  card.Backplate:SetAlpha(0.25)
  local ir, ig, ib = spellbookInk()
  card.Name:SetTextColor(ir, ig, ib)
  card.SubName:SetTextColor(ir, ig, ib)

  b.Icon:SetTexture(e.icon or "")
  b.Icon:SetDesaturated(false)
  b.Icon:SetAlpha(1)
  b.Icon:Show()
  if e.passive then
    b.Border:set_atlas("talents-node-circle-gray", false)
    b.Border:ClearAllPoints()
    b.Border:SetPoint("TOPLEFT",     b.IconSlot, "TOPLEFT",     0, 0)
    b.Border:SetPoint("BOTTOMRIGHT", b.IconSlot, "BOTTOMRIGHT", 0, 0)
    b.Border:SetVertexColor(1, 1, 1, 1)
    if b.IconRound and SetPortraitToTexture and e.icon and e.icon ~= "" then
      if pcall(SetPortraitToTexture, b.IconRound, e.icon) then
        b.IconRound:SetDesaturated(false)
        b.IconRound:SetAlpha(1)
        b.IconRound:Show()
        b.Icon:Hide()
      else
        b.IconRound:Hide()
        b.Icon:Show()
      end
    else
      b.Icon:Show()
    end
  else
    if b.IconRound then b.IconRound:Hide() end
    b.Border:set_atlas("spellbook-item-iconframe", false)
    b.Border:ClearAllPoints()
    b.Border:SetPoint("TOPLEFT",     b.IconSlot, "TOPLEFT",     -11, 1)
    b.Border:SetPoint("BOTTOMRIGHT", b.IconSlot, "BOTTOMRIGHT", 1, -7)
    b.Border:SetVertexColor(1, 1, 1, 1)
  end
  b.IconHighlight:set_atlas(e.passive and "spellbook-item-iconframe-passive-hover" or "spellbook-item-iconframe-hover", false)
  b.IconHighlight:Hide(); b.IconHighlight:SetAlpha(0.35)

  if e.passive then
    b:SetAttribute("type", nil); b:SetAttribute("spell", nil)
  else
    b:SetAttribute("type", "spell"); b:SetAttribute("spell", e.name or "")
  end
  if e.bookType == BOOKTYPE_PET_ and e.name and GetSpellAutocast then
    local allowed = GetSpellAutocast and GetSpellAutocast(e.slot, e.bookType)
    if allowed and e.name ~= "" then
      b:SetAttribute("type2", "macro")
      b:SetAttribute("macrotext2", "/petautocasttoggle " .. e.name)
    else
      b:SetAttribute("type2", ""); b:SetAttribute("macrotext2", nil)
    end
  else
    b:SetAttribute("type2", nil); b:SetAttribute("macrotext2", nil)
  end
end

function SB.RenderCards()
  buildElements()
  flowLayout(SB.elements)
  if SB.page > (SB.totalPages or 1) then SB.page = SB.totalPages or 1 end

  local curSpread = SB.page - 1
  local ci, hi = 0, 0
  for _, e in ipairs(SB.elements) do
    local onSpread = (math.floor((e.p or 0) / (SB.minimized and 1 or 2)) == curSpread)
    if e.kind == "card" then
      ci = ci + 1
      local card = SB.cards[ci] or createCard(ci)
      if onSpread then
        local pt, rp, x, y = pagePoint(e.p, e.r, e.c)
        card:ClearAllPoints(); card:SetPoint(pt, SB.frame, rp, x, y)
        applyCardVisual(card, e)
        card:Show()
      else
        card:Hide()
      end
    else
      hi = hi + 1
      local hd = SB.headers[hi] or createHeader(hi)
      if onSpread then
        local pt, rp, x, y = pagePoint(e.p, e.r, 0)
        hd:ClearAllPoints(); hd:SetPoint(pt, SB.frame, rp, x, y)
        hd.Text:SetText(e.label or "")
        hd:Show()
      else
        hd:Hide()
      end
    end
  end
  for i = ci + 1, #SB.cards   do SB.cards[i]:Hide()   end
  for i = hi + 1, #SB.headers do SB.headers[i]:Hide() end

  if SB.paging then
    SB.paging.label:SetText(("Page %d/%d"):format(SB.page, SB.totalPages or 1))
    if SB.paging.prev.SetEnabled then
      SB.paging.prev:SetEnabled(SB.page > 1)
      SB.paging.next:SetEnabled(SB.page < (SB.totalPages or 1))
    end
    SB.paging:Show()
    if SB.totalPages <= 1 then SB.paging:Hide() end
  end
end

local function ensureSecureToggle()
  if SB._secureToggle then return SB._secureToggle end
  local f = SB.frame
  if not f then return nil end
  local b = CreateFrame("Button", "DragonUISpellBookSecureToggle", UIParent, "SecureHandlerClickTemplate")
  b:SetFrameRef("frame", f)
  b:SetAttribute("_onclick", [=[
    local frame = self:GetFrameRef("frame")
    if frame:IsShown() then frame:Hide() else frame:Show() end
  ]=])
  if b.RegisterForClicks then b:RegisterForClicks("AnyUp") end
  SB._secureToggle = b
  return b
end

local function ensureSecureClose()
  if SB._secureClose then return SB._secureClose end
  local f = SB.frame
  if not f then return nil end
  local c = CreateFrame("Button", "DragonUISpellBookSecureClose", UIParent, "SecureHandlerClickTemplate")
  c:SetFrameRef("frame", f)
  c:SetAttribute("_onclick", [=[ self:GetFrameRef("frame"):Hide() ]=])
  if c.RegisterForClicks then c:RegisterForClicks("AnyUp") end
  if SecureHandlerWrapScript then
    SecureHandlerWrapScript(f, "OnShow", c, [=[
      control:SetBindingClick(true, "ESCAPE", "DragonUISpellBookSecureClose")
    ]=])
    SecureHandlerWrapScript(f, "OnHide", c, [=[
      control:ClearBindings()
    ]=])
  end
  SB._secureClose = c
  return c
end

local function applyKeyOverride()
  local b = ensureSecureToggle()
  if not (b and GetBindingKey and SetOverrideBindingClick) then return end
  SB._rebindQueued = false
  if ClearOverrideBindings then ClearOverrideBindings(b) end
  local function bind(binding)
    for _, k in ipairs({ GetBindingKey(binding) }) do
      if k then SetOverrideBindingClick(b, true, k, "DragonUISpellBookSecureToggle", "LeftButton") end
    end
  end
  bind("TOGGLESPELLBOOK")
  bind("TOGGLEPETBOOK")
end

local function installEvents()
  if SB._eventsInstalled then return end
  SB._eventsInstalled = true
  local ev = CreateFrame("Frame", "DragonUISpellBookEvents", UIParent)
  ev:RegisterEvent("UPDATE_BINDINGS")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:RegisterEvent("SPELLS_CHANGED")
  ev:SetScript("OnEvent", function(self, event)
    if event == "UPDATE_BINDINGS" then
      applyKeyOverride()
    elseif event == "PLAYER_REGEN_ENABLED" then
      if SB._rebindQueued then applyKeyOverride() end
      if SB._widthQueued then SB._widthQueued = false; SB.ApplyWidth() end
      if SB._renderQueued or (SB.frame and SB.frame:IsShown()) then
        SB._renderQueued = false
        SB.RenderCards()
      end
    elseif event == "SPELLS_CHANGED" then
      if SB.frame and SB.frame:IsShown() then
        SB.RenderCards()
      end
    end
  end)
end

function SB.Refresh()
  if not SB.frame then SB.ApplySpellbookSystem() end
  if not SB.frame then return end

  buildMinimize()
  buildPaging()
  buildSearch()

  local cats = buildCategories()
  if SB.selected > #cats then SB.selected = 1 end
  if not SB.userPickedCategory then SB.selected = pickDefaultSelected(cats) end

  local prev
  for i, cat in ipairs(cats) do
    local t = categoryTab(i)
    t:SetText(cat.label or "")
    if addon.CharacterPanel and addon.CharacterPanel.ReskinTab then
      addon.CharacterPanel.ReskinTab(t, true)
    end
    t:Show()
    prev = t
  end
  for i = #cats + 1, #SB.catTabs do SB.catTabs[i]:Hide() end
  local first = SB.catTabs[1]
  if first and first._duiRelayout then first._duiRelayout() end
  for i, cat in ipairs(cats) do
    local t = SB.catTabs[i]
    if t then
      if i == SB.selected then
        if PanelTemplates_SelectTab then PanelTemplates_SelectTab(t) end
      elseif PanelTemplates_DeselectTab then
        PanelTemplates_DeselectTab(t)
      end
    end
  end

  SB.RenderCards()
end

function SB.ApplySpellbookSystem()
  addon:Debug("[spellbook] ApplySpellbookSystem executed — module loaded")
  if not isEnabled() then return end
  local cfg = addon:GetModuleConfig("spellbook")
  if cfg and cfg.minimized ~= nil then SB.minimized = cfg.minimized and true or false end
  if cfg and cfg.showRanks ~= nil then SB.showRanks = cfg.showRanks == true end
  if cfg and cfg.hidePassives ~= nil then SB.hidePassives = cfg.hidePassives == true end
  if not SB.frame then
    SB.frame = CreateFrame("Frame", "DragonUISpellBookFrame", UIParent)
    SB.frame:SetFrameStrata("HIGH")
    SB.frame:SetToplevel(true)
    SB.frame:EnableMouse(true)
    SB.frame:EnableMouseWheel(true)
    SB.frame:SetMovable(true)
    SB.frame:SetClampedToScreen(true)
    SB.frame:RegisterForDrag("LeftButton")
    SB.frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    SB.frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    SB.frame:SetScript("OnMouseWheel", function(_, delta)
      if (SB.totalPages or 1) <= 1 then return end
      if delta < 0 then SB.SetPage(SB.page + 1) else SB.SetPage(SB.page - 1) end
    end)
    buildChrome()
    buildMinimize()
    buildBackground()
    prewarmBackgroundBLP()
    SB.frame:SetSize(SB.minimized and SB.MIN_W or SB.FRAME_W, SB.FRAME_H)
    SB.frame:SetPoint("CENTER", UIParent, "CENTER", 0, -60)
    tinsert(UISpecialFrames, "DragonUISpellBookFrame")
  end
  local scale = (cfg and type(cfg.scale) == "number" and cfg.scale > 0) and cfg.scale or 1
  SB.frame:SetScale(scale)
  local sbf = _G.SpellBookFrame
  if sbf then sbf:Hide() end
  if not SB._interceptInstalled then
    ToggleSpellBook = function() SB.Toggle() end
    SB._interceptInstalled = true
  end
  ensureSecureToggle()
  ensureSecureClose()
  applyKeyOverride()
  installEvents()
  SB.frame:SetScript("OnShow", function()
    local btn = _G.SpellbookMicroButton
    if btn and btn.SetButtonState then btn:SetButtonState("PUSHED", true) end
    if SB._reapplyBg then SB._reapplyBg() end
    if SB.frame and SB.frame:IsShown() then SB.Refresh() end
  end)
end

function SB.RestoreSpellbookSystem()
  if SB.frame then SB.frame:Hide() end
  local sbf = _G.SpellBookFrame
  if sbf then sbf:Show() end
end

function SB.RefreshSpellbook()
  if not isEnabled() then return end
  SB.ApplySpellbookSystem()
  if SB.frame and SB.frame:IsShown() then SB.Refresh() end
end

function SB.ApplyWidth()
  local f = SB.frame
  if not f then return end
  SB._widthQueued = false
  f:SetWidth(SB.minimized and SB.MIN_W or SB.FRAME_W)
  applyBgWidth()
  if f.minBtn and f.minBtn._syncIcon then f.minBtn._syncIcon() end
  if SB.frame:IsShown() then SB.RenderCards() end
end

function SB.SetMinimized(min)
  SB.minimized = min and true or false
  local cfg = addon:GetModuleConfig("spellbook")
  if cfg then cfg.minimized = SB.minimized end
  SB.ApplyWidth()
end

function SB.Toggle()
  if not isEnabled() then return end
  if SB.frame and SB.frame:IsShown() then
    SB.frame:Hide()
  else
    SB.ApplySpellbookSystem()
    if SB.frame then SB.frame:Show(); SB.Refresh() end
  end
end

function SB.Open()
  if not isEnabled() then return end
  SB.ApplySpellbookSystem()
  if SB.frame then SB.frame:Show(); SB.Refresh() end
end

addon:RegisterModule("spellbook", SB, L["Spellbook"], L["Learned spells book with categories, search, and filters."], { lifecyclePrefix = "Spellbook", loadOnce = true })
addon.RefreshSpellbookScale()
