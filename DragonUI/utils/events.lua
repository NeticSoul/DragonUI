-- ============================================================================
-- DragonUI - Event Package System
-- Centralized event registration and dispatch for addon subsystems.
-- ============================================================================

local addon = select(2, ...)

local type, select, error, tostring = type, select, error, tostring

local subscribers = {}

local function dispatch(frame, event, ...)
	local queue = subscribers[event]
	if queue then
		-- The bound is fixed up front: callbacks added mid-dispatch wait for the next occurrence.
		for slot = 1, #queue do
			queue[slot](frame, event, ...)
		end
	end
end

local hub = CreateFrame("Frame")
hub:SetScript("OnEvent", dispatch)

local eventPackage = { events = hub, fire_event = dispatch }
addon.package = eventPackage

local function isSubscribed(queue, callback)
	for slot = 1, #queue do
		if queue[slot] == callback then
			return true
		end
	end
	return false
end

function eventPackage:RegisterEvents(callback, ...)
	if type(callback) ~= "function" then
		error("RegisterEvents: callback must be a function, got " .. type(callback), 2)
	end
	for position = 1, select("#", ...) do
		local event = select(position, ...)
		if type(event) ~= "string" then
			error(("RegisterEvents: event #%d is %s, expected a string"):format(position, tostring(event)), 2)
		end
		local queue = subscribers[event]
		if not queue then
			queue = {}
			subscribers[event] = queue
		end
		if not isSubscribed(queue, callback) then
			queue[#queue + 1] = callback
			hub:RegisterEvent(event)
		end
	end
end