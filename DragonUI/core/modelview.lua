-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- No camera API on 3.3.5a, and GetPosition reads the pre-reload value, so the view is write-only.

local DEFAULT_FACING = 0.61
-- Half the subject's own height in offset units, measured in-client: a scale is anchored on its
-- feet, and a player model stands some seven times what a creature one does.
addon.ModelPivot = { player = 0.9, creature = 0.15 }
-- Multiplicative, so a notch feels the same at any size; a linear step crawls once zoomed out.
local ZOOM_STEP, ZOOM_MIN, ZOOM_MAX = 1.15, 0.5, 3
local PAN_LIMIT, PAN_SPEED = 1.2, 0.011
local ROTATE_SPEED = 0.012
-- The swap lands several frames after the call returns, so the view is re-asserted across a window.
local SETTLE_SECONDS = 1

local function clamp(value, low, high)
    if value < low then return low elseif value > high then return high end
    return value
end

local function view(model)
    local state = model._duiView
    if not state then
        state = { zoom = 1, panH = 0, panV = 0, pivot = 0 }
        model._duiView = state
    end
    return state
end

-- The subject grows with the zoom while an offset stays worth the same pixels, so the travel needed
-- to reach its edge grows with it.
local function clampPan(state)
    local limit = PAN_LIMIT * state.zoom
    state.panH = clamp(state.panH, -limit, limit)
    state.panV = clamp(state.panV, -limit, limit)
end

local function apply(model)
    local state = view(model)
    pcall(model.SetModelScale, model, state.zoom)
    -- SetPosition is (depth, horizontal, vertical); a scale is anchored on the subject's own feet.
    pcall(model.SetPosition, model, 0, state.panH,
          state.panV - state.pivot * (state.zoom - 1))
    -- Re-issued unconditionally, as Blizzard's own Model_OnUpdate does every frame a button is held.
    pcall(model.SetRotation, model, model.rotation or DEFAULT_FACING)
end

-- A reload re-fits the model and folds whatever scale it finds into the fit, shrinking the baseline.
local function neutralise(model)
    local state = view(model)
    state.zoom, state.panH, state.panV = 1, 0, 0
    pcall(model.SetModelScale, model, 1)
    pcall(model.SetPosition, model, 0, 0, 0)
end

function addon:ApplyModelView(model)
    apply(model)
end

function addon:ZoomModelView(model, notches)
    local state = view(model)
    state.zoom = clamp(state.zoom * (ZOOM_STEP ^ notches), ZOOM_MIN, ZOOM_MAX)
    clampPan(state)
    apply(model)
end

-- Raw cursor pixels: an offset is worth the same pixels at every zoom, so the rate is flat.
function addon:PanModelView(model, dx, dy)
    local state = view(model)
    state.panH, state.panV = state.panH + dx * PAN_SPEED, state.panV + dy * PAN_SPEED
    clampPan(state)
    apply(model)
end

function addon:ResetModelView(model)
    local state = view(model)
    state.zoom, state.panH, state.panV = 1, 0, 0
    apply(model)
end

function addon:ResetModelRotation(model, facing)
    model.rotation = facing or DEFAULT_FACING
    apply(model)
end

-- Every update starts the view clean. Carrying a zoom across one means the client's re-fit folds it
-- into the baseline, and every way of dodging that costs more than it buys.
local function watchReloads(model)
    if model._duiReloadWatch then return end

    local watch = CreateFrame("Frame", nil, model)
    watch:Hide()
    watch:SetScript("OnUpdate", function(self, elapsed)
        self.left = self.left - elapsed
        apply(model)
        if self.left <= 0 then self:Hide() end
    end)
    model._duiReloadWatch = watch

    local function arm()
        watch.left = SETTLE_SECONDS
        watch:Show()
    end

    -- The fold happens INSIDE the reload call and hooksecurefunc only runs after it, so the fit is
    -- redone rather than dodged -- but only for a dirty view, as SetUnit fires on every loading screen.
    local function refit(method, arg)
        if model._duiRefitting then return end
        local state = view(model)
        if state.zoom ~= 1 or state.panH ~= 0 or state.panV ~= 0 then
            neutralise(model)
            model._duiRefitting = true
            pcall(model[method], model, arg)
            model._duiRefitting = nil
        end
        arm()
    end

    for _, method in ipairs({ "SetUnit", "RefreshUnit", "SetCreature", "SetModel" }) do
        if model[method] then
            hooksecurefunc(model, method, function(_, arg) refit(method, arg) end)
        end
    end

    -- Neutralised on the way out, so the re-fit a tab switch triggers never sees a stale zoom.
    model:HookScript("OnHide", function() neutralise(model) end)
    model:HookScript("OnShow", function() neutralise(model); arm() end)
end

local function cursor(model)
    local scale = model:GetEffectiveScale()
    if not scale or scale <= 0 then scale = 1 end
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

-- opts.hook keeps whatever scripts the frame already has; the paperdoll needs it to stay droppable.
function addon:WireModelView(model, opts)
    if not model then return end
    opts = opts or {}
    watchReloads(model)

    -- Half the subject's own height in offset units, so it belongs to the model, not to this file.
    -- Taken on any call, not just the first: the strip builders wire a model their caller already did.
    local state = view(model)
    state.pivot = opts.pivot or state.pivot or 0

    if model._duiViewWired then return end
    model._duiViewWired = true

    model.rotation = model.rotation or DEFAULT_FACING

    -- Polled, not taken from OnMouseUp: releasing with the cursor off the model never delivers it.
    local rotator = CreateFrame("Frame", nil, model)
    rotator:Hide()
    rotator:SetScript("OnUpdate", function(self)
        if not IsMouseButtonDown("LeftButton") then self:Hide(); return end
        local x = cursor(model)
        -- Writes model.rotation too: Model_OnUpdate reads it to carry a held rotate button on.
        model.rotation = (model.rotation or DEFAULT_FACING) + (x - (self.x or x)) * ROTATE_SPEED
        self.x = x
        apply(model)
    end)

    local panner = CreateFrame("Frame", nil, model)
    panner:Hide()
    panner:SetScript("OnUpdate", function(self)
        if not IsMouseButtonDown("RightButton") then self:Hide(); return end
        local x, y = cursor(model)
        local dx, dy = x - (self.x or x), y - (self.y or y)
        self.x, self.y = x, y
        addon:PanModelView(model, dx, dy)
    end)

    local function onDown(_, button)
        if button == "LeftButton" then
            rotator.x = cursor(model)
            rotator:Show()
        elseif button == "RightButton" then
            panner.x, panner.y = cursor(model)
            panner:Show()
        elseif button == "MiddleButton" then
            -- The one control every surface gets for free; not all of them carry a reset button.
            addon:ResetModelView(model)
            addon:ResetModelRotation(model, opts.facing)
        end
    end

    -- Only the ticker whose own button came up: a middle tap mid-drag would otherwise end the drag.
    local function onUp(_, button)
        if button == nil or button == "LeftButton" then rotator:Hide() end
        if button == nil or button == "RightButton" then panner:Hide() end
    end

    local function onWheel(_, delta) addon:ZoomModelView(model, delta) end

    model:EnableMouse(true)
    model:EnableMouseWheel(true)

    -- Captured before hooking: this is what equips an item dropped on the paperdoll.
    local native = model:GetScript("OnMouseUp")

    if opts.hook then
        model:HookScript("OnMouseDown", onDown)
        model:HookScript("OnMouseUp", onUp)
        model:HookScript("OnMouseWheel", onWheel)
    else
        model:SetScript("OnMouseDown", onDown)
        model:SetScript("OnMouseUp", onUp)
        model:SetScript("OnMouseWheel", onWheel)
    end
    model:HookScript("OnHide", onUp)

    model._duiViewInput = { down = onDown, up = onUp, wheel = onWheel, native = native }
end

-- Anything drawn over a model swallows its input, so overlays hand the gestures back to it.
function addon:ForwardModelInput(frame, model, exceptLeft)
    local input = model and model._duiViewInput
    if not (frame and input) then return end

    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:HookScript("OnMouseDown", function(_, button)
        if exceptLeft and button == "LeftButton" then return end
        input.down(model, button)
    end)
    frame:HookScript("OnMouseUp", function(_, button)
        if exceptLeft and button == "LeftButton" then return end
        input.up(model, button)
        if input.native then input.native(model, button) end
    end)
    frame:HookScript("OnMouseWheel", function(_, delta) input.wheel(model, delta) end)
end
