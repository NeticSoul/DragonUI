local addon = select(2, ...)
local CP = addon.CharacterPanel

-- `/dui cp` — dumps what the panel actually measures at runtime, so layout can be corrected
-- against real numbers instead of arithmetic done against the XML.

local function fmt(n)
    if type(n) ~= "number" then return "nil" end
    return string.format("%.1f", n)
end

local function describe(label, frame)
    if not frame then
        addon:Print(string.format("|cffff5555%-26s MISSING|r", label))
        return
    end

    local shown = frame:IsShown() and (frame:IsVisible() and "vis" or "shown") or "hidden"
    local level = frame.GetFrameLevel and frame:GetFrameLevel() or "-"
    addon:Print(string.format("|cffffd100%-26s|r %sx%s  lvl=%s  %s",
        label, fmt(frame:GetWidth()), fmt(frame:GetHeight()), tostring(level), shown))

    if frame.GetNumPoints and frame:GetNumPoints() > 0 then
        for i = 1, frame:GetNumPoints() do
            local point, rel, relPoint, x, y = frame:GetPoint(i)
            local relName = rel and (rel.GetName and rel:GetName() or "<anon>") or "UIParent"
            addon:Print(string.format("      %s -> %s.%s (%s, %s)",
                point, relName, relPoint or "?", fmt(x), fmt(y)))
        end
    end
end

-- Offsets relative to the Inset are what every layout constant in this module is expressed in,
-- so report them directly rather than making them be derived from screen coordinates by hand.
local function relativeToInset(label, frame)
    local cf = _G.CharacterFrame
    local inset = cf and cf.Inset
    if not inset or not frame or not frame:GetLeft() or not inset:GetLeft() then return end
    addon:Print(string.format("      inset-relative: left=%s top=%s right=%s bottom=%s",
        fmt(frame:GetLeft() - inset:GetLeft()),
        fmt(inset:GetTop() - frame:GetTop()),
        fmt(inset:GetRight() - frame:GetRight()),
        fmt(frame:GetBottom() - inset:GetBottom())))
end

local function dump()
    local cf = _G.CharacterFrame
    if not cf then
        addon:Print(addon.L["CharacterFrame does not exist."])
        return
    end
    if not cf:IsShown() then
        addon:Print("|cffff5555" .. addon.L["Open the character panel first: sizes are meaningless while hidden."] .. "|r")
        return
    end

    addon:Print("|cff00ff00=== DragonUI Character Panel ===|r")
    addon:Print(string.format("active tab: %s   scale: %s",
        CP.ActiveTabName and CP.ActiveTabName() or "?", fmt(cf:GetEffectiveScale())))

    describe("CharacterFrame", cf)
    describe("Inset", cf.Inset)
    describe("InsetRight", cf.InsetRight)

    -- Report whichever tab is up, not just PaperDoll, so the list tabs can be diagnosed too.
    local active = CP.ActiveTabName and CP.ActiveTabName()
    if active and active ~= "PaperDollFrame" then
        describe(active, _G[active])
        addon:Print("|cff00ff00" .. addon.L["(paperdoll-only rows below are skipped on this tab)"] .. "|r")
        return
    end

    describe("PaperDollFrame", _G.PaperDollFrame)
    describe("CharacterModelFrame", _G.CharacterModelFrame)
    relativeToInset("model", _G.CharacterModelFrame)

    addon:Print("|cff00ff00--- slots ---|r")
    for _, name in ipairs({ "CharacterHeadSlot", "CharacterWristSlot", "CharacterHandsSlot",
                            "CharacterTrinket1Slot", "CharacterMainHandSlot",
                            "CharacterRangedSlot", "CharacterAmmoSlot" }) do
        describe(name, _G[name])
        relativeToInset(name, _G[name])
    end

    -- The weapon row overlapping the model's lower edge is by design; the inner border cutting
    -- through the row is not, so report both spans together.
    local inset, model, mh = cf.Inset, _G.CharacterModelFrame, _G.CharacterMainHandSlot
    if inset and model and mh and inset:GetBottom() then
        addon:Print(string.format("|cff00ff00--- vertical spans (above inset floor) ---|r"))
        addon:Print(string.format("      model bottom=%s   weapon row=%s..%s   border pieces=%d",
            fmt(model:GetBottom() - inset:GetBottom()),
            fmt(mh:GetBottom() - inset:GetBottom()),
            fmt(mh:GetTop() - inset:GetBottom()),
            CP.InnerBorderPieces and #CP.InnerBorderPieces or 0))
    end

    addon:Print("|cff00ff00--- sidebar ---|r")
    describe("StatsPane", _G.DragonUICharacterStatsPane)
    describe("StatsScroll", _G.DragonUICharacterStatsScroll)
    describe("StatRow (base1)", _G.DragonUIStatBase1)

    addon:Print("|cff00ff00--- name block ---|r")
    local guildName, guildRank = GetGuildInfo("player")
    local guildFS = _G.CharacterGuildText
    addon:Print(string.format("      guild api: %s / %s", tostring(guildName), tostring(guildRank)))
    addon:Print(string.format("      CharacterGuildText: %s  text=%q",
        guildFS and (guildFS:IsShown() and "shown" or "hidden") or "MISSING",
        guildFS and guildFS:GetText() or ""))
    local levelFS = _G.CharacterLevelText
    addon:Print(string.format("      CharacterLevelText: %s", levelFS and levelFS:GetText() or "MISSING"))

    addon:Print("|cff00ff00--- chrome ---|r")
    describe("Portrait", _G.CharacterFramePortrait)
    describe("CloseButton", _G.CharacterFrameCloseButton)
    describe("Tab1", _G.CharacterFrameTab1)
    describe("Tab5", _G.CharacterFrameTab5)
    addon:Print(string.format("tab strip right edge (inset-relative): %s",
        fmt(CP.TabStripRight and CP.TabStripRight())))
end

CP.Dump = dump
addon.DumpCharacterPanel = dump

local CONTROL_NAMES = {
    "CharacterModelFrameRotateLeftButton", "CharacterModelFrameRotateRightButton",
    "DragonUIModelZoomOut", "DragonUIModelZoomIn", "DragonUIModelReset",
}

-- Where a texture actually lands, measured against the Inset floor. Identical-looking state with a
-- different result means the difference is in geometry, not in the texture's own fields.
local function describeRect(tex)
    local inset = _G.CharacterFrame and _G.CharacterFrame.Inset
    if not inset or not inset:GetBottom() or not tex:GetBottom() then
        addon:Print("          rect: |cffff5555unresolved|r")
        return
    end
    addon:Print(string.format("          rect: %sx%s  top=%s bottom=%s (above inset floor)",
        fmt(tex:GetWidth()), fmt(tex:GetHeight()),
        fmt(tex:GetTop() - inset:GetBottom()), fmt(tex:GetBottom() - inset:GetBottom())))
end

local function describeTexture(label, tex)
    if not tex then
        addon:Print(string.format("        %-9s |cffff5555MISSING|r", label))
        return
    end
    local r, g, b = tex:GetVertexColor()
    local path = tex:GetTexture()
    if path then path = path:match("[^\\]+$") or path else path = "nil" end
    local function coord(n) return type(n) == "number" and string.format("%.4f", n) or "nil" end
    local ulx, uly, _, _, _, _, lrx, lry = tex:GetTexCoord()
    addon:Print(string.format("        %-9s %s a=%s rgb=%s/%s/%s layer=%s coord=%s,%s..%s,%s %s",
        label, path, fmt(tex:GetAlpha()), fmt(r), fmt(g), fmt(b),
        tostring(tex.GetDrawLayer and tex:GetDrawLayer() or "?"),
        coord(ulx), coord(uly), coord(lrx), coord(lry), tex:IsShown() and "shown" or "hidden"))
end

-- The strip only exists while the cursor is over the model, so this reports what the buttons
-- actually resolved to at that moment rather than what they were built with.
local function dumpControls()
    addon:Print("|cff00ff00=== model controls ===|r")

    local bar = _G.DragonUIModelControls
    if not bar then
        addon:Print("|cffff5555DragonUIModelControls MISSING|r")
        return
    end
    local model = _G.CharacterModelFrame
    addon:Print(string.format("strip: %s alpha=%s   model alpha=%s   cursor over model=%s",
        bar:IsShown() and (bar:IsVisible() and "vis" or "shown") or "hidden",
        fmt(bar:GetAlpha()), model and fmt(model:GetAlpha()) or "?",
        tostring(model and model:IsMouseOver())))

    for _, name in ipairs(CONTROL_NAMES) do
        local btn = _G[name]
        if not btn then
            addon:Print(string.format("|cffff5555%-38s MISSING|r", name))
        else
            addon:Print(string.format("|cffffd100%-38s|r %s alpha=%s state=%s enabled=%s",
                name,
                btn:IsShown() and (btn:IsVisible() and "vis" or "shown") or "hidden",
                fmt(btn:GetAlpha()), tostring(btn:GetButtonState()),
                tostring(btn:IsEnabled())))
            describeTexture("normal", btn:GetNormalTexture())
            describeTexture("pushed", btn:GetPushedTexture())
            describeTexture("highlight", btn:GetHighlightTexture())
            describeTexture("glyph", btn._duiGlyph)
        end
    end
end

CP.DumpControls = dumpControls

-- Everything stacked in the strip under the model, which renders dark on some loads and light on
-- others. Frame level decides across frames, draw layer within one, so both are reported.
local function dumpGrounds()
    local cf = _G.CharacterFrame
    if not cf then addon:Print("|cffff5555CharacterFrame MISSING|r"); return end
    local model = _G.CharacterModelFrame

    addon:Print("|cff00ff00=== panel grounds ===|r")
    addon:Print(string.format("levels: frame=%s inset=%s paperdoll=%s model=%s",
        tostring(cf:GetFrameLevel()),
        cf.Inset and tostring(cf.Inset:GetFrameLevel()) or "-",
        _G.PaperDollFrame and tostring(_G.PaperDollFrame:GetFrameLevel()) or "-",
        model and tostring(model:GetFrameLevel()) or "-"))

    addon:Print(string.format("dark_background=%s  grey_model_backdrop=%s",
        tostring(CP:Config().dark_background), tostring(CP:Config().grey_model_backdrop)))

    -- Walk the WHOLE tree rather than a list chosen up front: seven hand-picked dumps came back
    -- identical while the strip rendered differently, so the culprit was never on the list.
    addon:Print("|cff00ff00--- everything painting the strip ---|r")

    local floor = cf.Inset and cf.Inset:GetBottom()
    local ceiling = model and model:GetBottom()
    local insetLeft = cf.Inset and cf.Inset:GetLeft()
    local insetRight = cf.Inset and cf.Inset:GetRight()
    if not floor or not ceiling or not insetLeft or not insetRight then
        addon:Print("|cffff5555strip bounds unresolved|r")
        return
    end

    local hits, seen = 0, {}
    local function walk(frame, label, depth)
        if not frame or depth > 6 or seen[frame] then return end
        seen[frame] = true
        if frame.IsVisible and not frame:IsVisible() then return end

        if frame.GetRegions then
            for _, region in ipairs({ frame:GetRegions() }) do
                if region.GetObjectType and region:GetObjectType() == "Texture"
                    and region:IsVisible() and (region:GetAlpha() or 0) > 0.01 then
                    local top, bottom = region:GetTop(), region:GetBottom()
                    local left, right = region:GetLeft(), region:GetRight()
                    -- Inside the strip on BOTH axes. Testing only the vertical bounds listed the
                    -- whole sidebar, which shares the same rows of screen but none of the space.
                    if top and bottom and left and right
                        and bottom < ceiling - 1 and top > floor + 1
                        and left < insetRight - 1 and right > insetLeft + 1
                        and (region:GetWidth() or 0) > 60 then
                        local path = region:GetTexture()
                        hits = hits + 1
                        addon:Print(string.format("  %s <%s> %s a=%s",
                            label, tostring(frame.GetFrameLevel and frame:GetFrameLevel() or "?"),
                            tostring(path and path:match("[^\\]+$") or path), fmt(region:GetAlpha())))
                    end
                end
            end
        end

        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do
                walk(child, (child.GetName and child:GetName()) or (label .. ".?"), depth + 1)
            end
        end
    end

    walk(cf, "CharacterFrame", 0)
    if hits == 0 then addon:Print("  |cffff5555nothing found painting it|r") end
end

function addon.DumpPanelGrounds()
    local ok, err = pcall(dumpGrounds)
    if not ok then addon:Print(addon.L["Ground dump failed: "] .. tostring(err)) end
end

-- Delayed so the cursor can be parked on the model: typing the command necessarily moves it away.
function addon.DumpModelControls()
    addon:Print("|cff00ff00" .. addon.L["Put the cursor on the 3D model, capturing in 5 seconds."] .. "|r")
    addon:After(5, function()
        local ok, err = pcall(dumpControls)
        if not ok then addon:Print(addon.L["Model control dump failed: "] .. tostring(err)) end
    end)
end
