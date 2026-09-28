-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local NP = addon.Nameplates

-- Nameplates widget registry.

NP.widgets = NP.widgets or {}

NP.widgets.Registry = NP.widgets.Registry or {}

function NP.widgets.Register(name, widget)
    if not name or not widget then return end
    NP.widgets.Registry[name] = widget
end

function NP.widgets.Get(name)
    if not name then return nil end
    return NP.widgets.Registry[name]
end

function NP.widgets.Hide(name, plateData, context, state)
    local widget = NP.widgets.Get(name)
    if widget and widget.Hide then
        widget.Hide(plateData, context, state)
    end
end

function NP.widgets.Sync(name, plateData, context, state)
    local widget = NP.widgets.Get(name)
    if not widget then return end

    -- Totem icon-only hides other widgets; Totem is exempt.
    if name ~= "Totem" and NP.gather and NP.gather.IsTotemIconOnlyActive
        and NP.gather.IsTotemIconOnlyActive(plateData) then
        NP.widgets.Hide(name, plateData, context, state)
        return
    end

    if widget.ShouldShow and widget.ShouldShow(plateData, context, state) == false then
        NP.widgets.Hide(name, plateData, context, state)
        return
    end

    if widget.Ensure then
        local ok = widget.Ensure(plateData, context, state)
        if ok == false then
            NP.widgets.Hide(name, plateData, context, state)
            return
        end
    end

    if widget.Layout then
        local ok = widget.Layout(plateData, context, state)
        if ok == false then
            NP.widgets.Hide(name, plateData, context, state)
            return
        end
    end

    if widget.Sync then
        widget.Sync(plateData, context, state)
    end
end

function NP.widgets.SyncList(widgetNames, plateData, context, state)
    if not widgetNames then return end
    for i = 1, #widgetNames do
        NP.widgets.Sync(widgetNames[i], plateData, context, state)
    end
end
