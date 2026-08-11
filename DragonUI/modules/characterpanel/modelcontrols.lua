local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Retail's model control strip: rotate, zoom and reset, faded in while the cursor is over it.
local BTN_SIZE = 29
local BTN_OVERLAP = 5
local GLYPH_SIZE = 17
local FADE_SECONDS = 0.15

local PLATE_SHEET = addon._dir .. "CharacterPanel\\commonbuttons"
local ICON_SHEET = addon._dir .. "CharacterPanel\\commonicons"

-- Model:SetPosition's first axis is depth; SetCamDistanceScale only arrives in Cataclysm. The clamp
-- has to straddle 0 or zoom-in silently stops working at the default position.
local ZOOM_STEP = 0.25
local ZOOM_MIN, ZOOM_MAX = -3, 3
local PAN_LIMIT = 1.5
local PAN_SPEED = 0.004
-- Model_OnLoad's own starting rotation, so reset returns to exactly Blizzard's default.
local DEFAULT_ROTATION = 0.61
-- Matches the collections model, so both windows spin at the same rate under the same drag.
local ROTATION_SPEED = 0.012

local bar, faded, controls, buttons

-- Draw order of the whole strip; the settings decide which of these actually stand.
local STRIP_ORDER = { "left", "right", "zoomOut", "zoomIn", "reset" }

local function position(model)
    if not model.GetPosition then return 0, 0, 0 end
    local ok, x, y, z = pcall(model.GetPosition, model)
    if not ok or not x then return 0, 0, 0 end
    return x, y or 0, z or 0
end

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

-- Read the live position: anything else that moves the model would leave our counter out of step.
local function applyZoom(model, delta)
    local x, y, z = position(model)
    pcall(model.SetPosition, model, clamp(x + delta, ZOOM_MIN, ZOOM_MAX), y, z)
end

local function applyPan(model, dy, dz)
    local x, y, z = position(model)
    pcall(model.SetPosition, model, x,
          clamp(y + dy, -PAN_LIMIT, PAN_LIMIT),
          clamp(z + dz, -PAN_LIMIT, PAN_LIMIT))
end

local function resetModel(model)
    if model.SetPosition then pcall(model.SetPosition, model, 0, 0, 0) end
    model.rotation = DEFAULT_ROTATION
    if model.SetRotation then pcall(model.SetRotation, model, DEFAULT_ROTATION) end
end

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

    -- OVERLAY, not ARTWORK: a button's normal texture also sits there and creation order decides,
    -- so the plate could end up in front of the glyph.
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

-- Hiding a rotate button between its down and its up swallows the up and leaves it latched PUSHED,
-- drawing the dark plate for good -- and fading the strip under a held button does exactly that.
local function releaseButtons()
    if not controls then return end
    for _, btn in ipairs(controls) do
        if btn:GetButtonState() == "PUSHED" then btn:SetButtonState("NORMAL") end
    end
end

-- Rebuilt rather than toggled button by button: the strip is centred on the model, so dropping one
-- has to re-measure the bar or whatever survives ends up sitting off-centre.
local function layoutControls()
    if not (bar and buttons) then return end
    local cfg = CP:Config()

    local order = {}
    if not cfg.hide_model_controls then
        for _, key in ipairs(STRIP_ORDER) do order[#order + 1] = buttons[key] end
    elseif cfg.model_controls_reset_only then
        order[1] = buttons.reset
    end

    local standing = {}
    for _, btn in ipairs(order) do standing[btn] = true end

    faded = {}
    for _, btn in ipairs(order) do
        if btn == buttons.left or btn == buttons.right then faded[#faded + 1] = btn end
    end
    controls = order

    for _, key in ipairs(STRIP_ORDER) do
        local btn = buttons[key]
        -- Unlatched first: hiding a button between its down and its up strands it PUSHED for good.
        if btn:GetButtonState() == "PUSHED" then btn:SetButtonState("NORMAL") end
    end

    -- The rotate pair are siblings of the strip and are shown only by the fade, so they stay down
    -- here; the strip's own children each carry their own shown flag through a parent Show.
    buttons.left:Hide()
    buttons.right:Hide()
    for _, key in ipairs({ "zoomOut", "zoomIn", "reset" }) do
        local btn = buttons[key]
        if standing[btn] then btn:Show() else btn:Hide() end
    end

    local step = BTN_SIZE - BTN_OVERLAP
    bar:SetWidth(math.max(1, step * (#order - 1) + BTN_SIZE))
    for i, btn in ipairs(order) do
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", bar, "LEFT", (i - 1) * step, 0)
    end
end

-- A plain alpha lerp; the rotate buttons are siblings, not children, so they fade alongside it.
-- Re-armed every call: the ticker dies with an ancestor, stranding any "already fading" flag.
local function startFade(target)
    if not bar then return end
    bar._duiTarget = target

    if target > 0 then
        releaseButtons()
        bar:Show()
        for _, btn in ipairs(faded) do btn:Show() end
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
        for _, btn in ipairs(faded) do btn:SetAlpha(current) end

        if current == goal then
            self:SetScript("OnUpdate", nil)
            if goal == 0 then
                self:Hide()
                for _, btn in ipairs(faded) do btn:Hide() end
            end
        end
    end)
end

-- Hooked, not set: the model's XML OnUpdate drives hold-to-rotate and its OnMouseUp is what lets an
-- item be dropped on the model. Driving the pan through either one wiped that behaviour.
local panner = CreateFrame("Frame")
panner:Hide()

local rotator = CreateFrame("Frame")
rotator:Hide()

local function wireDrag(model)
    if model._duiDragWired then return end
    model._duiDragWired = true

    -- The button state is polled, as Blizzard's own drag loops do: a release with the cursor off the
    -- model never delivers OnMouseUp here, and this frame outlives the panel, so it would never stop.
    panner:SetScript("OnUpdate", function(self)
        if not IsMouseButtonDown("RightButton") then self:Hide(); return end
        local cx, cy = GetCursorPosition()
        local dx, dy = cx - (self.x or cx), cy - (self.y or cy)
        self.x, self.y = cx, cy
        -- Screen x maps to the model's lateral axis, screen y to its vertical one.
        applyPan(model, dx * PAN_SPEED, dy * PAN_SPEED)
    end)

    -- Writes model.rotation, not just SetRotation: Model_OnUpdate reads that field to carry a held
    -- rotate button on, so a drag that skipped it would be snapped away by the next button press.
    rotator:SetScript("OnUpdate", function(self)
        if not IsMouseButtonDown("LeftButton") then self:Hide(); return end
        local cx = GetCursorPosition()
        model.rotation = (model.rotation or DEFAULT_ROTATION) + (cx - (self.x or cx)) * ROTATION_SPEED
        self.x = cx
        model:SetRotation(model.rotation)
    end)

    model:HookScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            rotator.x = GetCursorPosition()
            rotator:Show()
        elseif button == "RightButton" then
            panner.x, panner.y = GetCursorPosition()
            panner:Show()
        end
    end)
    -- The XML OnMouseUp still runs first, so dropping an item on the model still equips it.
    model:HookScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then rotator:Hide() end
        if button == "RightButton" then panner:Hide() end
    end)
end

local function build()
    local model = _G.CharacterModelFrame
    local left = _G.CharacterModelFrameRotateLeftButton
    local right = _G.CharacterModelFrameRotateRightButton
    if bar or not model or not left then return end

    bar = CreateFrame("Frame", "DragonUIModelControls", model)
    bar:SetHeight(BTN_SIZE)
    bar:SetPoint("TOP", model, "TOP", 0, -1)
    bar:SetAlpha(0)
    bar:Hide()

    -- Blizzard's rotate buttons stay parented to the model: their OnClick passes self:GetParent() to
    -- the rotation helper, so reparenting them makes model.rotation come back nil.
    styleButton(left, "common-icon-rotateright")
    styleButton(right, "common-icon-rotateleft")
    faded = { left, right }
    for _, btn in ipairs(faded) do
        -- Siblings of the strip, not children, and the strip has mouse enabled over the same area --
        -- so without an explicit level it swallows their clicks.
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

    local zoomIn = makeButton("DragonUIModelZoomIn", "common-icon-zoomin",
                              function() applyZoom(model, ZOOM_STEP) end)
    local zoomOut = makeButton("DragonUIModelZoomOut", "common-icon-zoomout",
                               function() applyZoom(model, -ZOOM_STEP) end)
    local reset = makeButton("DragonUIModelReset", "common-icon-undo",
                             function() resetModel(model) end)

    buttons = { left = left, right = right, zoomOut = zoomOut, zoomIn = zoomIn, reset = reset }
    layoutControls()

    -- Closing the panel kills the ticker mid-fade, so reset rather than reopen at a frozen alpha.
    bar:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        self:SetAlpha(0)
        self._duiTarget = 0
        for _, btn in ipairs(faded) do
            btn:SetAlpha(0)
            btn:Hide()
        end
        releaseButtons()
    end)

    model:EnableMouse(true)
    wireDrag(model)

    -- 3.3.5a has no Model_OnMouseWheel, so wheel-zoom is ours to wire.
    model:EnableMouseWheel(true)
    model:HookScript("OnMouseWheel", function(_, delta)
        applyZoom(model, delta * ZOOM_STEP)
    end)

    -- Revealed over the model OR the strip, so reaching for a button does not fade it out underneath.
    -- Nothing standing means nothing to reveal; drag-rotate and wheel-zoom are not buttons and stay.
    local function show()
        if not controls or #controls == 0 then return end
        startFade(1)
    end
    local function hide()
        if bar:IsMouseOver() or model:IsMouseOver() then return end
        startFade(0)
    end
    model:HookScript("OnEnter", show)
    model:HookScript("OnLeave", hide)
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", show)
    bar:SetScript("OnLeave", hide)
end

CP.BuildModelControls = build

-- Always put the strip away after a re-layout: its own OnHide resets the alphas and unlatches
-- anything left PUSHED, and the next hover brings back whichever buttons survived.
function CP.RefreshModelControls()
    if not bar then return end
    layoutControls()
    bar:Hide()
end

CP:RegisterBuilder("modelcontrols", build)
