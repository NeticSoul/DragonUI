-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- 3.3.5a has no camera API, so moving the model or scaling it is the whole toolbox.

local ROTATION_SPEED = 0.012
local PAN_LIMIT, PAN_SPEED = 1.5, 0.004
local DEPTH_STEP, DEPTH_MIN, DEPTH_MAX = 0.25, -3, 3
-- Multiplicative, so a notch feels the same at any size; a linear step crawls once zoomed out.
local SCALE_STEP, SCALE_MIN, SCALE_MAX = 1.12, 0.35, 4
-- Model_OnLoad's own starting rotation, so a reset returns to exactly Blizzard's default.
local DEFAULT_ROTATION = 0.61
-- How long a reload is watched for; the swap itself can land several frames after the call.
local SETTLE_SECONDS = 1
local EPSILON = 0.0001

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

-- Offsets from an origin, never absolute: a reload re-frames the render but leaves GetPosition on the
-- old value, and the engine moves by the difference from THAT, so a forced zero overshoots outward.
local function view(model)
    local v = model._duiView
    if not v then
        v = { depth = 0, scale = 1, y = 0, z = 0, ox = 0, oy = 0, oz = 0, oscale = 1 }
        model._duiView = v
    end
    return v
end

local function targets(v)
    return v.ox + v.depth, v.oy + v.y, v.oz + v.z
end

local function apply(model)
    local v = view(model)
    pcall(model.SetPosition, model, targets(v))
    if v.scaled and model.SetModelScale then
        pcall(model.SetModelScale, model, v.oscale * v.scale)
    end
end

-- Adopt whatever the model currently reads as the new zero point, rather than writing a zero of ours.
local function rebase(model)
    local v = view(model)
    local ok, x, y, z = pcall(model.GetPosition, model)
    if ok and x then v.ox, v.oy, v.oz = x, y or 0, z or 0 end
    if model.GetModelScale then
        local sok, s = pcall(model.GetModelScale, model)
        if sok and s and s > 0 then v.oscale = s end
    end
    v.depth, v.scale, v.y, v.z = 0, 1, 0, 0
end

function addon:ResetModelView(model)
    local v = view(model)
    v.depth, v.scale, v.y, v.z = 0, 1, 0, 0
    apply(model)
end

-- A world-space push, not a move along the line of sight, so the anchor slides off centre.
function addon:ZoomModelDepth(model, notches)
    local v = view(model)
    v.depth = clamp(v.depth + notches * DEPTH_STEP, DEPTH_MIN, DEPTH_MAX)
    apply(model)
end

-- A scale pins the model's origin, so it magnifies the same at any framing distance.
function addon:ZoomModelScale(model, notches)
    local v = view(model)
    v.scale = clamp(v.scale * (SCALE_STEP ^ notches), SCALE_MIN, SCALE_MAX)
    apply(model)
end

function addon:PanModelView(model, dy, dz)
    local v = view(model)
    v.y = clamp(v.y + dy, -PAN_LIMIT, PAN_LIMIT)
    v.z = clamp(v.z + dz, -PAN_LIMIT, PAN_LIMIT)
    apply(model)
end

function addon:ResetModelRotation(model)
    model.rotation = DEFAULT_ROTATION
    if model.SetRotation then pcall(model.SetRotation, model, DEFAULT_ROTATION) end
end

function addon:TrackModelReloads(model)
    if model._duiReloadTracked then return end
    model._duiReloadTracked = true
    rebase(model)

    -- The reload is asynchronous, so the value can still move after the call returns. Rebased only
    -- when it moved on its own, which is what keeps this from wiping a zoom made in the meantime.
    local settle = CreateFrame("Frame")
    settle:Hide()
    settle:SetScript("OnUpdate", function(self, elapsed)
        self.left = (self.left or 0) - elapsed
        if self.left <= 0 then self:Hide(); return end

        local v = view(model)
        local ok, x, y, z = pcall(model.GetPosition, model)
        if not (ok and x) then return end
        local tx, ty, tz = targets(v)
        if math.abs(x - tx) > EPSILON or math.abs((y or 0) - ty) > EPSILON
            or math.abs((z or 0) - tz) > EPSILON then
            rebase(model)
        end
    end)

    local function onReload()
        rebase(model)
        settle.left = SETTLE_SECONDS
        settle:Show()
    end

    for _, method in ipairs({ "SetUnit", "RefreshUnit", "SetCreature", "SetModel" }) do
        if model[method] then hooksecurefunc(model, method, onReload) end
    end
end

-- opts.scale picks scale zoom over depth; opts.hook keeps whatever scripts the frame already has.
function addon:WireModelView(model, opts)
    if not model or model._duiViewWired then return end
    model._duiViewWired = true
    opts = opts or {}
    view(model).scaled = opts.scale and true or false

    -- Polled, not taken from OnMouseUp: releasing with the cursor off the model never delivers it.
    local rotator = CreateFrame("Frame", nil, model)
    rotator:Hide()
    rotator:SetScript("OnUpdate", function(self)
        if not IsMouseButtonDown("LeftButton") then self:Hide(); return end
        local x = GetCursorPosition()
        -- Writes model.rotation too: Model_OnUpdate reads it to carry a held rotate button on.
        model.rotation = (model.rotation or DEFAULT_ROTATION) + (x - (self.x or x)) * ROTATION_SPEED
        self.x = x
        model:SetRotation(model.rotation)
    end)

    local panner = CreateFrame("Frame", nil, model)
    panner:Hide()
    panner:SetScript("OnUpdate", function(self)
        if not IsMouseButtonDown("RightButton") then self:Hide(); return end
        local cx, cy = GetCursorPosition()
        local dx, dy = cx - (self.x or cx), cy - (self.y or cy)
        self.x, self.y = cx, cy
        -- Screen x maps to the model's lateral axis, screen y to its vertical one.
        addon:PanModelView(model, dx * PAN_SPEED, dy * PAN_SPEED)
    end)

    local function onDown(_, button)
        if button == "LeftButton" then
            rotator.x = GetCursorPosition()
            rotator:Show()
        elseif button == "RightButton" then
            panner.x, panner.y = GetCursorPosition()
            panner:Show()
        end
    end

    -- Per button, so tapping one mid-drag with the other does not cancel it; OnHide stops both.
    local function onUp(_, button)
        if button ~= "RightButton" then rotator:Hide() end
        if button ~= "LeftButton" then panner:Hide() end
    end

    local zoom = opts.scale and addon.ZoomModelScale or addon.ZoomModelDepth
    local function onWheel(_, delta) zoom(addon, model, delta) end

    model:EnableMouse(true)
    model:EnableMouseWheel(true)

    -- Hooked on the paperdoll: its XML OnMouseUp is what lets an item be dropped onto the model.
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

    addon:TrackModelReloads(model)
end
