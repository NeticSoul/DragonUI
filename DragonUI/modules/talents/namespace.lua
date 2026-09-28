-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local TM = addon.TalentModule or {}
addon.TalentModule = TM
TM.ns = TM.ns or {}
local ns = TM.ns
local L = addon.L
local GetNumTalentGroups = _G.GetNumTalentGroups

if TM.initialized == nil then TM.initialized = false end
if TM.applied == nil then TM.applied = false end

if addon.RegisterModule then
    addon:RegisterModule("talents", TM, L["Talents"], L["Retail-style talent window"],
        { lifecyclePrefix = "Talent", loadOnce = true })
end

-- Window geometry in window units; the trees draw at TREE_SCALE of these.
ns.WIDTH = 1120
ns.TOP_BAND = 46
ns.FOOTER_H = 80
ns.ART_TOP = 22
ns.TAB_ROW = 34
ns.TREE_SCALE = 0.95

-- Integer form of 46 + 0.95 * (70 + 46d) + 88, rounded, so x87 single precision cannot tip a .5.
function ns.WindowHeight(depth)
    return math.floor((4020 + 874 * depth) / 20)
end

ns.depth = 11
ns.viewGroup = 1
ns.query = ""
ns.undo = {}

function ns.Profile()
    local profile = addon.db and addon.db.profile
    if not profile then return {} end
    profile.talents = profile.talents or {}
    return profile.talents
end

function ns.PlayerClass()
    return select(2, UnitClass("player"))
end

function ns.PlayerGroups()
    return GetNumTalentGroups(false, false) or 1
end

function ns.ActiveGroup()
    return GetActiveTalentGroup(false, false) or 1
end

function ns.PetHasTalents()
    return (GetNumTalentGroups(false, true) or 0) > 0
end

function ns.PetView()
    return ns.inspectUnit == nil and ns.wantPet and ns.PetHasTalents() or false
end

function ns.GlyphView()
    return ns.inspectUnit == nil and ns.glyphPage or false
end

function ns.Browsing()
    return ns.inspectUnit == nil and not ns.PetView() and not ns.GlyphView()
        and ns.viewGroup ~= ns.ActiveGroup()
end

function ns.LiveMode()
    return ns.inspectUnit == nil and not ns.GlyphView() and not ns.Browsing()
end

-- Everything the talent API needs to address what is on screen right now.
function ns.ViewContext()
    local ctx = {}
    if ns.inspectUnit then
        ctx.inspect, ctx.pet = true, false
        ctx.group = GetActiveTalentGroup(true, false) or 1
    elseif ns.PetView() then
        ctx.inspect, ctx.pet = false, true
        ctx.group = GetActiveTalentGroup(false, true) or 1
    else
        ctx.inspect, ctx.pet = false, false
        ctx.group = ns.viewGroup
    end
    ctx.editable = not ctx.inspect and (ctx.pet or ctx.group == ns.ActiveGroup())
    ctx.preview = ctx.editable and GetCVarBool("previewTalents") and true or false
    return ctx
end

function ns.StagedPoints(ctx)
    if not ctx.preview then return 0 end
    return GetGroupPreviewTalentPointsSpent(ctx.pet, ctx.group) or 0
end

function ns.UnspentPoints(ctx)
    if not ctx.editable then return 0 end
    return GetUnspentTalentPoints(false, ctx.pet, ctx.group) or 0
end

local TONES = {
    info = { 1, 0.82, 0 },
    error = { 1, 0.3, 0.3 },
    ok = { 0.2, 1, 0.2 },
    match = { 0.8, 0.8, 0.2 },
    ask = { 0.8, 0.8, 0.8 },
    gate = { 1, 0.1, 0.1 },
}

function ns.Notify(text, tone)
    local rgb = TONES[tone or "info"] or TONES.info
    UIErrorsFrame:AddMessage(text, rgb[1], rgb[2], rgb[3], 1.0)
end

local hub, listeners

local function dispatch(_, event, ...)
    local list = listeners[event]
    if not list then return end
    for i = 1, #list do
        list[i](event, ...)
    end
end

function ns.Listen(event, handler)
    if not hub then
        hub, listeners = CreateFrame("Frame"), {}
        hub:SetScript("OnEvent", dispatch)
    end
    local list = listeners[event]
    if not list then
        list = {}
        listeners[event] = list
        hub:RegisterEvent(event)
    end
    list[#list + 1] = handler
end

-- Shared popup plumbing; flags: "dead" = usable while dead, "solo" = exclusive.
function ns.DefinePopup(key, text, accept, decline, extra, flags)
    local dialog = extra or {}
    dialog.text, dialog.button1, dialog.button2 = text, accept, decline
    dialog.timeout, dialog.hideOnEscape = 0, 1
    flags = flags or ""
    if flags:find("dead", 1, true) then dialog.whileDead = 1 end
    if flags:find("solo", 1, true) then dialog.exclusive = 1 end
    StaticPopupDialogs[key] = dialog
    return dialog
end

-- Each extra argument is one tooltip line: { text, r, g, b, wrap }.
function ns.Tip(owner, anchor, ...)
    local tip = GameTooltip
    tip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    for position = 1, select("#", ...) do
        local line = select(position, ...)
        if line then tip:AddLine(line[1], line[2], line[3], line[4], line[5]) end
    end
    tip:Show()
end

function ns.TitledTip(owner, title, detail)
    ns.Tip(owner, nil, { title, 1, 1, 1 }, detail and { detail, 0.8, 0.8, 0.8, true } or nil)
end

-- The spec rename cog and the glyph options cog share one look.
function ns.MakeCog(parent, frameName)
    local gear = CreateFrame("Button", frameName, parent)
    gear:SetWidth(18)
    gear:SetHeight(18)
    for _, layer in ipairs({ "ARTWORK", "HIGHLIGHT" }) do
        local art = gear:CreateTexture(nil, layer)
        art:SetAtlasTexture("questlog-icon-setting", true)
        art:SetPoint("CENTER", gear, "CENTER", 0, 0)
        if layer == "HIGHLIGHT" then
            art:SetBlendMode("ADD")
            art:SetAlpha(0.4)
        end
    end
    gear:SetScript("OnLeave", GameTooltip_Hide)
    return gear
end

function ns.PopupEdit(dialog)
    local wide = dialog.wideEditBox
    if wide and wide:IsShown() then return wide end
    return dialog.editBox
end

-- Enter in a popup's edit box runs the same accept path as button 1, then closes.
function ns.EnterAccepts(editBox, data)
    local dialog = editBox:GetParent()
    local info = StaticPopupDialogs[dialog.which]
    if info and info.OnAccept then info.OnAccept(dialog, data) end
    dialog:Hide()
end

function ns.EscapeCloses(editBox)
    editBox:GetParent():Hide()
end

function ns.Call(name, ...)
    local fn = ns[name]
    if fn then return fn(...) end
end

function ns.Refresh()
    if not TM.applied or not ns.win then return end
    if ns.win:IsShown() then ns.Repaint() end
end

function ns.Repaint()
    local win = ns.win
    if not win or not win:IsShown() then return end
    if ns.GlyphView() then
        ns.Call("PaintGlyphs")
    elseif ns.edit then
        ns.Call("PaintEditor")
    else
        ns.Call("PaintLive")
    end
    ns.Call("RefreshTabs")
    ns.Call("UpdateFooter")
end
