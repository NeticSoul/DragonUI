-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local TM = addon.TalentModule
local ns = TM.ns
local L = addon.L

local floor, max, min, format = math.floor, math.max, math.min, string.format

local dropdown

-- Dropdown button ---------------------------------------------------------------------------------

-- Textholder atlas cut at 16/14/16/18 px and drawn at 0.8; 3.3.5a has no slice-margin API.
local SLICE_U = { 0, 0.125, 0.296875, 0.421875 }
local SLICE_V = { 0.625, 0.6796875, 0.71484375, 0.78515625 }
local EDGE_X = { { "LEFT", -6.4 }, { "LEFT", 6.4 }, { "RIGHT", -6.4 }, { "RIGHT", 6.4 } }
local EDGE_Y = { { "TOP", 5.6 }, { "TOP", -5.6 }, { "BOTTOM", 7.2 }, { "BOTTOM", -7.2 } }

local function dressHolder(button)
    local sheet = addon.atlasinfo["common-dropdown-textholder"][1]
    for row = 1, 3 do
        for col = 1, 3 do
            local piece = button:CreateTexture(nil, "BACKGROUND")
            piece:SetTexture(sheet)
            piece:SetTexCoord(SLICE_U[col], SLICE_U[col + 1], SLICE_V[row], SLICE_V[row + 1])
            local x1, y1, x2, y2 = EDGE_X[col], EDGE_Y[row], EDGE_X[col + 1], EDGE_Y[row + 1]
            piece:SetPoint("TOPLEFT", button, y1[1] .. x1[1], x1[2], y1[2])
            piece:SetPoint("BOTTOMRIGHT", button, y2[1] .. x2[1], x2[2], y2[2])
        end
    end
end

local function arrowState(button)
    if addon.Menu and addon.Menu.IsOpenFor(button) then return "-open" end
    if button.pressed then return button.hovered and "-pressedhover" or "-pressed" end
    if button.hovered then return "-hover" end
    return ""
end

local function syncArrow(button)
    local state = arrowState(button)
    if state == button.arrowState then return end
    button.arrowState = state
    button.arrow:SetAtlasTexture("common-dropdown-a-button" .. state)
    button.arrow:SetSize(21.6, 21.6)
end

function ns.SetDropdownLabel(text)
    if dropdown then dropdown.label:SetText(text or L["Talent Builds"]) end
end

-- Menu entries ------------------------------------------------------------------------------------

local function codeFor(build)
    return TM.EncodeBuildCode(ns.PlayerClass(), build.name, build.ranks, build.reqLevel)
end
ns.CodeFor = codeFor

local function shareEntries(build)
    return {
        { text = L["Post link in chat"], func = function() ns.Call("PostLink", build) end },
        { text = GUILD, disabled = not IsInGuild(), func = function() ns.Call("ShareToGuild", build) end },
        {
            text = L["Copy code"],
            func = function() StaticPopup_Show("DUI_TALENT_EXPORT", nil, nil, codeFor(build)) end,
        },
    }
end

local function buildDetail(build)
    local spread = {}
    for tab = 1, 3 do spread[tab] = ns.TreePoints(build, tab) end
    local level = ns.BuildLevel(build)
    return table.concat(spread, "/") .. "   " .. LEVEL .. " " .. level
end

local function perBuildEntries(build)
    return {
        { text = L["Load onto character"], func = function() ns.LoadOntoCharacter(build) end },
        { text = L["Edit"], func = function() ns.EnterEditor(build) end },
        { text = L["Rename"], func = function() ns.RenameBuild(build) end },
        { text = L["Share"], menu = function() return shareEntries(build) end },
        {
            text = DELETE,
            func = function() StaticPopup_Show("DUI_TALENT_DELETE_BUILD", build.name or "?", nil, build) end,
        },
    }
end

local function levelLabel(build)
    local level, automatic = ns.BuildLevel(build)
    local text = format(L["Level Required: %d"], level)
    if automatic then text = text .. " " .. L["(auto)"] end
    return text
end

local function rootEntries()
    local menu = {}
    local function add(entry) menu[#menu + 1] = entry end
    local editing = ns.edit

    if editing then
        add({ text = format(L["Editing: %s"], editing.name or "?"), isTitle = true })
        add({ text = SAVE, func = function() ns.SaveBuild(editing) end })
        add({
            text = levelLabel(editing),
            func = function() StaticPopup_Show("DUI_TALENT_BUILD_LEVEL", ns.LevelCap(), nil, editing) end,
        })
        add({ text = L["Exit Editor"], func = function() ns.RequestExitEditor() end })
        add({ isDivider = true })
    end

    add({ text = L["Talent Builds"], isTitle = true })
    add({ text = L["New build"], func = function() ns.NewBuild(false) end })
    add({ text = L["New build from current talents"], func = function() ns.NewBuild(true) end })

    local stored = ns.OwnBuilds()
    if #stored > 0 then
        add({ isDivider = true })
        for _, build in ipairs(stored) do
            add({
                text = build.name or "?",
                detail = buildDetail(build),
                menu = function() return perBuildEntries(build) end,
            })
        end
    end

    add({ isDivider = true })
    add({ text = L["Import code…"], func = function() StaticPopup_Show("DUI_TALENT_IMPORT") end })

    if editing then
        add({ text = L["Load onto character"], func = function() ns.LoadOntoCharacter(editing) end })
        add({ text = L["Share"], menu = function() return shareEntries(editing) end })
    end
    return menu
end

-- Construction ------------------------------------------------------------------------------------

function ns.BuildDropdown(footer)
    local button = CreateFrame("Button", "DragonUI_TalentLoadoutDropdown", footer)
    button:SetSize(200, 24)
    dressHolder(button)

    local arrow = button:CreateTexture(nil, "ARTWORK")
    arrow:SetPoint("RIGHT", button, "RIGHT", 0.8, -2.4)
    button.arrow = arrow
    syncArrow(button)

    local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetJustifyH("LEFT")
    label:SetPoint("LEFT", button, "LEFT", 8, 0)
    label:SetPoint("RIGHT", arrow, "LEFT", -2, 0)
    label:SetText(L["Talent Builds"])
    button.label = label

    button:SetScript("OnEnter", function(self)
        self.hovered = true
        syncArrow(self)
        ns.TitledTip(self, L["Talent Builds"], L["Design and save builds offline — no points needed."])
    end)
    button:SetScript("OnLeave", function(self)
        self.hovered = false
        syncArrow(self)
        GameTooltip_Hide()
    end)
    button:SetScript("OnMouseDown", function(self)
        self.pressed = true
        syncArrow(self)
    end)
    -- A frame later, once the menu's own shown state has settled after the click.
    button:SetScript("OnMouseUp", function(self)
        addon:After(0, function()
            self.pressed = false
            syncArrow(self)
        end)
    end)
    button:SetScript("OnClick", function(self)
        GameTooltip_Hide()
        addon.Menu.Open(self, rootEntries())
        PlaySound("igMainMenuOptionCheckBoxOn")
        syncArrow(self)
    end)
    button:SetScript("OnHide", function() addon.Menu.Close() end)
    -- The menu closes itself on outside clicks without telling us, so the arrow polls.
    button:SetScript("OnUpdate", syncArrow)

    dropdown = button
    return button
end

-- Popups ------------------------------------------------------------------------------------------

local function applyLevel(self, build)
    if not build then return end
    local typed = ns.Trim(ns.PopupEdit(self):GetText() or "")
    if typed == "" then
        build.reqLevel = nil
    else
        local number = tonumber(typed)
        if not number then return end
        local floorLevel = max(10, ns.BuildPoints(build) + 9)
        local level = min(ns.LevelCap(), max(floorLevel, floor(number)))
        if level ~= number then ns.Notify(format(L["Level clamped to %d (build size / level cap)."], level)) end
        build.reqLevel = level
    end
    if ns.edit == build then ns.Repaint() end
end

ns.DefinePopup("DUI_TALENT_BUILD_LEVEL",
    L["Level required for this build (10-%d).\nLeave blank for automatic (grows with the build)."],
    OKAY, CANCEL, {
        hasEditBox = 1,
        maxLetters = 3,
        OnShow = function(dialog, build)
            local edit = ns.PopupEdit(dialog)
            edit:SetText(build and build.reqLevel and tostring(build.reqLevel) or "")
            edit:HighlightText()
            edit:SetFocus()
        end,
        OnAccept = applyLevel,
        EditBoxOnEnterPressed = ns.EnterAccepts,
        EditBoxOnEscapePressed = ns.EscapeCloses,
    }, "dead")

local function importCode(self)
    local decoded = TM.DecodeBuildCode(ns.PopupEdit(self):GetText() or "")
    if not decoded then
        ns.Notify(format(L["Talent import: %s"], L["couldn't read a talent code"]), "error")
        return
    end
    local record, own = ns.KeepBuild(decoded)
    if record and own then ns.EnterEditor(record) end
end

ns.DefinePopup("DUI_TALENT_IMPORT", L["Paste a DragonUI talent code:"], L["Import"], CANCEL, {
    hasEditBox = 1,
    hasWideEditBox = 1,
    maxLetters = 0,
    OnShow = function(dialog)
        local edit = ns.PopupEdit(dialog)
        edit:SetText("")
        edit:SetFocus()
    end,
    OnAccept = importCode,
    EditBoxOnEnterPressed = ns.EnterAccepts,
    EditBoxOnEscapePressed = ns.EscapeCloses,
}, "dead")

ns.DefinePopup("DUI_TALENT_EXPORT", L["Talent build code (Ctrl+C to copy):"], CLOSE, nil, {
    hasEditBox = 1,
    hasWideEditBox = 1,
    maxLetters = 0,
    OnShow = function(dialog, code)
        local edit = ns.PopupEdit(dialog)
        edit:SetText(code or "")
        edit:HighlightText()
        edit:SetFocus()
    end,
    EditBoxOnEnterPressed = ns.EscapeCloses,
    EditBoxOnEscapePressed = ns.EscapeCloses,
}, "dead")

ns.DefinePopup("DUI_TALENT_DELETE_BUILD", L["Delete loadout '%s'? This cannot be undone."], DELETE, CANCEL, {
    OnAccept = function(_, build)
        if not build then return end
        if ns.edit == build then ns.ExitEditor() end
        ns.ForgetBuild(build)
    end,
}, "dead")
