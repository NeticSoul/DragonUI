-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Retail's model control strip: rotate, zoom and reset, faded in while the cursor is over it.
local BTN_SIZE = 29
local BTN_OVERLAP = 5
local GLYPH_SIZE = 17
local FADE_SECONDS = 0.15

local PLATE_SHEET = addon._dir .. "CharacterPanel\\commonbuttons"
local ICON_SHEET = addon._dir .. "CharacterPanel\\commonicons"

-- Radians per second while a rotate button is held; roughly a full turn in four seconds.
local ROTATE_PER_SECOND = 1.6
-- A tap can begin and end inside one frame, so it is worth this much of a hold on its own.
local TAP_SECONDS = 0.02

-- Draw order of the strip; the settings decide which of these actually stand.
local STRIP_ORDER = { "left", "right", "zoomOut", "zoomIn", "reset" }

local bar, standing, buttons

-- Square plate, centred glyph, additive glow of that glyph on hover -- how retail lights these.
local function styleButton(btn, glyph)
    if btn._duiGlyph then return end
    btn:SetSize(BTN_SIZE, BTN_SIZE)

    -- A plain Button has no normal or pushed texture, so they must exist before they can be skinned.
    if not btn:GetNormalTexture() then btn:SetNormalTexture(PLATE_SHEET) end
    if not btn:GetPushedTexture() then btn:SetPushedTexture(PLATE_SHEET) end

    -- Pinned below the glyph explicitly rather than trusting the widget's default layer.
    local normal = btn:GetNormalTexture()
    normal:set_atlas("common-button-square-gray-up")
    normal:SetDrawLayer("BORDER")
    normal:ClearAllPoints()
    normal:SetAllPoints(btn)

    local pushed = btn:GetPushedTexture()
    pushed:set_atlas("common-button-square-gray-down")
    pushed:SetDrawLayer("BORDER")
    pushed:ClearAllPoints()
    pushed:SetAllPoints(btn)

    -- OVERLAY, not ARTWORK: a button's normal texture sits there too and creation order decides.
    local icon = btn:CreateTexture(nil, "OVERLAY")
    icon:set_atlas(glyph)
    icon:SetSize(GLYPH_SIZE, GLYPH_SIZE)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn._duiGlyph = icon

    if not btn:GetHighlightTexture() then btn:SetHighlightTexture(ICON_SHEET) end
    local hl = btn:GetHighlightTexture()
    hl:set_atlas(glyph)
    hl:ClearAllPoints()
    hl:SetAllPoints(icon)
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.45)
end

CP.StyleModelButton = styleButton

-- Blizzard's rotate buttons stay parented to the model: their OnClick passes self:GetParent() on.
local function isSibling(btn)
    return btn:GetParent() ~= bar
end

local function eachButton(fn)
    for _, key in ipairs(STRIP_ORDER) do
        local btn = buttons[key]
        if btn then fn(btn) end
    end
end

-- Hiding a button between its down and its up strands it latched PUSHED, drawing the dark plate.
local function releaseButtons()
    eachButton(function(btn)
        if btn:GetButtonState() == "PUSHED" then btn:SetButtonState("NORMAL") end
    end)
end

-- Rebuilt, not toggled: the strip is centred on the model, so dropping one has to re-measure it.
local function layoutStrip()
    if not (bar and buttons) then return end
    local cfg = CP:Config()

    local order = {}
    if not cfg.hide_model_controls then
        for _, key in ipairs(STRIP_ORDER) do order[#order + 1] = buttons[key] end
    elseif cfg.model_controls_reset_only then
        order[1] = buttons.reset
    end

    releaseButtons()

    -- Everything down first: a sibling dropped from the standing set has nothing left to hide it.
    eachButton(function(btn)
        btn:Hide()
        if isSibling(btn) then btn:SetAlpha(0) end
    end)
    for _, btn in ipairs(order) do
        if not isSibling(btn) then btn:Show() end
    end
    standing = order

    local step = BTN_SIZE - BTN_OVERLAP
    bar:SetWidth(math.max(1, step * (#order - 1) + BTN_SIZE))
    for i, btn in ipairs(order) do
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", bar, "LEFT", (i - 1) * step, 0)
    end
end

-- A plain alpha lerp, re-armed every call: the ticker dies with an ancestor, stranding any flag.
local function fadeStrip(target)
    if target > 0 and #standing == 0 then return end
    bar._duiTarget = target

    if target > 0 then
        -- Not while a button is held: moving off one onto the model re-fires this and stops the spin.
        if not IsMouseButtonDown("LeftButton") then releaseButtons() end
        bar:Show()
        for _, btn in ipairs(standing) do
            if isSibling(btn) then btn:Show() end
        end
    end

    bar:SetScript("OnUpdate", function(self, elapsed)
        local current = self:GetAlpha()
        local goal = self._duiTarget
        local step = elapsed / FADE_SECONDS
        if current < goal then
            current = math.min(goal, current + step)
        else
            current = math.max(goal, current - step)
        end

        self:SetAlpha(current)
        for _, btn in ipairs(standing) do
            if isSibling(btn) then btn:SetAlpha(current) end
        end

        if current == goal then
            self:SetScript("OnUpdate", nil)
            if goal == 0 then
                self:Hide()
                for _, btn in ipairs(standing) do
                    if isSibling(btn) then btn:Hide() end
                end
            end
        end
    end)
end

local function build()
    local model = _G.CharacterModelFrame
    local left = _G.CharacterModelFrameRotateLeftButton
    local right = _G.CharacterModelFrameRotateRightButton
    if not model or not left then return end
    -- Re-enabled without a reload: the strip outlived Restore, so stand it back up.
    if bar then return layoutStrip() end

    bar = CreateFrame("Frame", "DragonUIModelControls", model)
    bar:SetHeight(BTN_SIZE)
    bar:SetPoint("TOP", model, "TOP", 0, -1)
    bar:SetAlpha(0)
    bar:Hide()
    standing = {}

    styleButton(left, "common-icon-rotateright")
    styleButton(right, "common-icon-rotateleft")
    for _, btn in ipairs({ left, right }) do
        -- Siblings, with the strip mouse-enabled over the same area, so they need an explicit level.
        btn:SetFrameLevel(bar:GetFrameLevel() + 1)
        btn:SetAlpha(0)
        btn:Hide()
    end

    local function makeButton(name, glyph, onClick)
        local btn = CreateFrame("Button", name, bar)
        styleButton(btn, glyph)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    buttons = {
        left = left,
        right = right,
        zoomOut = makeButton("DragonUIModelZoomOut", "common-icon-zoomout",
                             function() addon:ZoomModelView(model, -1) end),
        zoomIn = makeButton("DragonUIModelZoomIn", "common-icon-zoomin",
                            function() addon:ZoomModelView(model, 1) end),
        reset = makeButton("DragonUIModelReset", "common-icon-undo", function()
            addon:ResetModelView(model)
            addon:ResetModelRotation(model)
        end),
    }

    -- Hooked, not set: the model's XML OnMouseUp is what lets an item be dropped onto it to equip.
    addon:WireModelView(model, { hook = true, pivot = addon.ModelPivot.player })
    layoutStrip()

    -- Revealed over the model, the strip OR a button: the buttons take the mouse focus, so without
    -- them the cursor can leave through one and strand the strip lit.
    local function show() fadeStrip(1) end
    local function hide()
        if bar:IsMouseOver() or model:IsMouseOver() then return end
        fadeStrip(0)
    end
    model:HookScript("OnEnter", show)
    model:HookScript("OnLeave", hide)
    bar:EnableMouse(true)
    bar:HookScript("OnEnter", show)
    bar:HookScript("OnLeave", hide)
    eachButton(function(btn)
        btn:HookScript("OnEnter", show)
        btn:HookScript("OnLeave", hide)
    end)

    -- The strip and its buttons lie across the model, so the gestures they cover are handed back.
    addon:ForwardModelInput(bar, model)
    eachButton(function(btn) addon:ForwardModelInput(btn, model, true) end)

    -- Closing the panel kills the ticker mid-fade, so reset rather than reopen at a frozen alpha.
    bar:HookScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        self:SetAlpha(0)
        self._duiTarget = 0
        for _, btn in ipairs(standing) do
            if isSibling(btn) then
                btn:SetAlpha(0)
                btn:Hide()
            end
        end
        releaseButtons()
    end)
end

CP.BuildModelControls = build

function CP.RefreshModelControls()
    if not bar then return end
    layoutStrip()
    bar:Hide()
end

-- Emptied, not just hidden: the model keeps its OnEnter hook for the session, and the fade only
-- stands down a strip with nothing standing.
function CP.RestoreModelControls()
    if not bar then return end
    bar:SetScript("OnUpdate", nil)
    bar:Hide()
    eachButton(function(btn) btn:Hide() end)
    standing = {}

    local model = _G.CharacterModelFrame
    if model then addon:ResetModelView(model) end
    for _, btn in ipairs({ buttons.left, buttons.right }) do
        btn:SetAlpha(1)
        btn:Show()
    end
end

-- Rotate only, and always on: this pane has no room for a hover strip and no zoom buttons to hide.
-- Hold-to-rotate lives in Model_OnUpdate, which finds its buttons by GLOBAL NAME, so never ours.
function CP.WirePetModelControls(model)
    if not model or model._duiPetControls then return end
    model._duiPetControls = true
    addon:ResetModelRotation(model)
    addon:WireModelView(model, { pivot = addon.ModelPivot.creature })

    local strip = CreateFrame("Frame", nil, model)
    strip:SetHeight(BTN_SIZE)
    strip:SetPoint("BOTTOM", model, "BOTTOM", 0, 2)

    local spinner = CreateFrame("Frame", nil, model)
    spinner:Hide()
    spinner:SetScript("OnUpdate", function(self, elapsed)
        model.rotation = (model.rotation or 0) + self.step * elapsed
        addon:ApplyModelView(model)
    end)
    model:HookScript("OnHide", function() spinner:Hide() end)

    local order = {}
    local function add(glyph, step)
        local btn = CreateFrame("Button", nil, strip)
        styleButton(btn, glyph)
        btn:SetScript("OnMouseDown", function(_, button)
            if button ~= "LeftButton" then return end
            -- One step up front, so a click that ends before the next frame still turns it.
            model.rotation = (model.rotation or 0) + step * TAP_SECONDS
            addon:ApplyModelView(model)
            spinner.step = step
            spinner:Show()
        end)
        -- Also on leave: releasing off the button never delivers OnMouseUp, and it would spin on.
        btn:SetScript("OnMouseUp", function() spinner:Hide() end)
        btn:SetScript("OnLeave", function() spinner:Hide() end)
        addon:ForwardModelInput(btn, model, true)
        order[#order + 1] = btn
    end

    add("common-icon-rotateright", -ROTATE_PER_SECOND)
    add("common-icon-rotateleft", ROTATE_PER_SECOND)

    local step = BTN_SIZE - BTN_OVERLAP
    strip:SetWidth(step * (#order - 1) + BTN_SIZE)
    for i, btn in ipairs(order) do
        btn:SetPoint("LEFT", strip, "LEFT", (i - 1) * step, 0)
    end
    return strip
end

CP:RegisterBuilder("modelcontrols", build)
