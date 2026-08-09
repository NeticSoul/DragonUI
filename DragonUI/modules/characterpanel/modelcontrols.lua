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

local bar, faded, controls

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

    model:HookScript("OnMouseDown", function(_, button)
        if button ~= "RightButton" then return end
        panner.x, panner.y = GetCursorPosition()
        panner:Show()
    end)
    model:HookScript("OnMouseUp", function(_, button)
        if button ~= "RightButton" then return end
        panner:Hide()
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

    local order = { left, right, zoomOut, zoomIn, reset }
    controls = order
    local step = BTN_SIZE - BTN_OVERLAP
    bar:SetWidth(step * (#order - 1) + BTN_SIZE)

    for i, btn in ipairs(order) do
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", bar, "LEFT", (i - 1) * step, 0)
    end

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
    local function show() startFade(1) end
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

CP:RegisterBuilder("modelcontrols", build)
