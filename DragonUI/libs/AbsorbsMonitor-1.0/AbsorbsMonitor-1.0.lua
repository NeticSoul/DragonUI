------------------------------------------------------------------------
--
-- AbsorbsMonitor
--
-- Copyright (C) 2010  Philipp Schmidt
--
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to:
--
-- Free Software Foundation, Inc.,
-- 51 Franklin Street, Fifth Floor,
-- Boston, MA  02110-1301, USA.
--
--
------------------------------------------------------------------------



local AM_Public, upgraded = LibStub:NewLibrary("AbsorbsMonitor-1.0", 90004);

if(not AM_Public) then return; end

local AM_Core;



---------------------
-- Install/Upgrade --
---------------------

-- We have to upgrade from a previous version
if(upgraded) then
	AM_Core = AM_Public.Core;
	
	-- Since we have to keep the data structures intact, we will wipe all data.
	-- Note that we wipe it instead of just replacing the tables with empty ones.
	-- That way we don't leak the memory used by the previous version.
	-- The only thing we want to keep is the callback registry
	if(AM_Public.Enabled) then
		AM_Core.Disable();
	end
	
-- This is the first loading of this library. We install everything that is stable across
-- multiple library versions: callbacks, event handling and other libraries
-- This code has to stay stable in its result across library versions!
else
	AM_Public.Core = {Callbacks = LibStub:GetLibrary("CallbackHandler-1.0"):New(AM_Public), Events = {}};
	AM_Core = AM_Public.Core;
	
	local frame = CreateFrame("Frame", "AbsMon_Events");
	local events = AM_Core.Events;
	
	frame:SetScript("OnEvent",
		function(self, event, ...)
			events[event](...);
		end	
	);
	
	AM_Core.Frame = frame;
	
	LibStub("AceComm-3.0"):Embed(AM_Core);
	LibStub("AceTimer-3.0"):Embed(AM_Core);
	LibStub("AceSerializer-3.0"):Embed(AM_Core);
end



---------------------
-- Local Variables --
---------------------

local AM_Callbacks = AM_Core.Callbacks;
local AM_Events = AM_Core.Events;

local playerGUID;
local playerClass;

-- Specifies the channel any AddOn message should be
-- sent to, nil if silent
-- Can also be used to get the last known party state
local curChatChannel = nil;

-- Always hold the timestamp from the last COMBAT_LOG_EVENT_UNFILTERED fired
local lastCombatLogEvent = 0.0;

-- Table of all active absorb effects indexed by GUID and then spellId
-- at spellId == -1 there is a numeric entry with the total remaining value,
-- at spellId == -2 there is a numeric entry with the total quality (that is, the minimal quality)
-- The priority is also in this table for performance reasons during sort
-- [GUID] = { [spellId] = {spellId, priority, remainingValue, maxValue, quality, durationTimerHandle, extra} }
-- Shortcut to AM_Core.activeEffects.bySpell
local activeEffectsBySpell;

-- Table of all active absorb effects indexed by GUID and then a list in the order in which
-- they will be used
-- Shortcut to AM_Core.activeEffects.byPriority
local activeEffectsByPriority;

-- Table of all active area absorb effects indexed by triggerGUID
-- same format as an entry in activeEffectsBySpell with two extra fields at the end
-- {..., triggerGUID, refcount}
-- Note that in this approach, a trigger can have only one absorb effect up at the same time.
-- This should be a reasonable assumption for quite some time, considering only Anti-Magic Zone
-- and (soon) Power Word: Barrier use this feature anyway
-- Shortcut to AM_Core.activeEffects.Area
local activeAreaEffects;

-- Table of current unit charges
-- A charge is a variant value a custom trigger can put on any unit with a limited lifetime
-- It is organized as a (very simple) queue (FIFO) for use with Divine Aegis e.g. to save the
-- critical heal value and then apply it on the aura gain or with Val'anyr.
-- [GUID] = { [spellId] = { charge1, charge2, ... } }
-- Shortcut to AM_Core.activeCharges
local activeCharges;

-- Table of known spells that cause an absorb effects
-- priority: active effects above 2 are neither used in total value nor displayed (e.g. Anti-Magic Shell)
-- [spellId] = {priority, duration, createFunc, hitFunc}
-- Shortcut to AM_Core.EffectInfo
local Effects;

-- Table of spells that cause an area effect
-- [spellId (trigger)] = spellId (absorb effect)
-- Shortcut to AM_Core.AreaTriggers
local AreaTriggers;

-- Table of additional callbacks on combat log events for proc-based and other non-generic absorb effects.
-- Shortcuts to entries of AM_Core.CombatTriggers
local CombatTriggersOnHeal;
local CombatTriggersOnHealCrit;
local CombatTriggersOnAuraApplied;
local CombatTriggersOnAuraRemoved;

-- Table of all unit stats relevant to absorb effects like attack power and spell power
-- (mastery rating later on)
-- [GUID] = { class, AttackPower, SpellPower, quality }
-- Shortcut to AM_Core.UnitStats
local UnitStats;

-- Table of all scaling factors to absorb effects like talents, items, set boni, buffs
-- If there is no mechanism in Cataclysm to obtain the correct absorb amount by any effect
-- this entries are meant to be distributed among a group, raid, etc
-- [GUID] = { [scaling_Name] = scaling_Value }
-- A numerical scaling_name above 10 should ONLY be used if it is the spellId of the affected effect,
-- since it is sometimes used as a very quick way to check for a unit's class
-- Scaling factors that are only relevant to the local user like priest talents and do not
-- need to be distributed but are needed for calculation of the public one's are private ones,
-- found at index -1
-- Shortcuts to AM_Core.Scaling and its entries
local Scaling;
local privateScaling;
local playerScaling;

-- Class-specific callbacks
local OnEnableClass = {};
local OnScalingDecode = setmetatable({}, {
	__index = function(table, class)
		return table.DEFAULT;
	end
}); 

-- Shortcut to the most important core functions
local ApplySingularEffect;
local ApplyAreaEffect;
local CreateAreaTrigger;
local HitUnit;
local RemoveActiveEffect;

-- Constants
local LOW_VALUE_TOLERANCE = 50;
local ZONE_MODIFIER = 1; -- "constant"



----------------------
-- Helper functions --
----------------------

local CommStatsCooldown = false;
local function ClearCommStatsCooldown()
	CommStatsCooldown = false;
end

local CommScalingCooldown = false;
local function ClearCommScalingCooldown()
	CommScalingCooldown = false;
end

local function DeepTableCopy(src)
	local dest = {};
	
	for k, v in pairs(src) do
		if(type(k) == "table") then
			k = DeepTableCopy(k);
		end
		
		if(type(v) == "table") then
			v = DeepTableCopy(v);
		end
		
		dest[k] = v;
	end
	
	setmetatable(dest, getmetatable(src));
	
	return dest;
end

local function SortEffects(a, b)
	if(a[2] == b[2]) then
		return (a[3] < b[3]);
	else
		return (a[2] > b[2]);
	end
end

-- Tries to get a working unitId
local function GetUnitId(guid, name)
	if(UnitGUID(name)) then
		return name;
	end
	
	if(UnitGUID("target") == guid) then
		return "target";
	elseif(UnitGUID("focus") == guid) then
		return "focus";
	end
	
	return nil;
end

-- Tries to get a working unitId and calls the given UnitXXX() function
local function UnitCall_bySearch(func, guid, name)
	local result = func(name);
	
	if(not result) then	
		if(UnitGUID("target") == guid) then
			result = func("target");
		elseif(UnitGUID("focus") == guid) then
			result = func("focus");
		end
	end	
	
	return result;
end



--------------------
-- Core functions --
--------------------

function AM_Core.Enable()
	local _
	_, playerClass = UnitClass("player");
	playerGUID = UnitGUID("player");

	AM_Core.activeEffects = {bySpell = {}, byPriority = {}, Area = {}};
	
	activeEffectsBySpell = AM_Core.activeEffects.bySpell;
	activeEffectsByPriority = AM_Core.activeEffects.byPriority;
	activeAreaEffects = AM_Core.activeEffects.Area;
	
	AM_Core.activeCharges = {};
	activeCharges = AM_Core.activeCharges;
	
	Effects = AM_Core.Effects;
	AreaTriggers = AM_Core.AreaTriggers;	

	CombatTriggersOnHeal = AM_Core.CombatTriggers.OnHeal;
	CombatTriggersOnHealCrit = AM_Core.CombatTriggers.OnHealCrit;
	CombatTriggersOnAuraApplied = AM_Core.CombatTriggers.OnAuraApplied;
	CombatTriggersOnAuraRemoved = AM_Core.CombatTriggers.OnAuraRemoved;
	
	AM_Core.UnitStats = {[playerGUID] = {playerClass, 0, 0, 1.0}};
	UnitStats = AM_Core.UnitStats;
	
	AM_Core.Scaling = {[-1] = {}, [playerGUID] = {}}	
	Scaling = AM_Core.Scaling;
	
	playerScaling = Scaling[playerGUID];
	privateScaling = Scaling[-1];
	
	AM_Core.RegisterEvent("ZONE_CHANGED_NEW_AREA");
	AM_Core.RegisterEvent("ZONE_CHANGED_INDOORS");
	AM_Core.RegisterEvent("UNIT_AURA");
	AM_Core.RegisterEvent("UPDATE_BATTLEFIELD_STATUS");
	AM_Events.ZONE_CHANGED_NEW_AREA();

	if(playerClass == "DEATHKNIGHT") then
		AM_Core.RegisterEvent("UNIT_ATTACK_POWER");
		
	elseif(playerClass == "DRUID") then
		AM_Core.RegisterEvent("UNIT_ATTACK_POWER");
		
	elseif(playerClass == "MAGE") then
		AM_Core.RegisterEvent("PLAYER_DAMAGE_DONE_MODS");
		
	elseif(playerClass == "PALADIN") then
		AM_Core.RegisterEvent("PLAYER_DAMAGE_DONE_MODS");
		
	elseif(playerClass == "PRIEST") then
		AM_Core.RegisterEvent("PLAYER_DAMAGE_DONE_MODS");
		
	elseif(playerClass == "WARLOCK") then
		AM_Core.RegisterEvent("PLAYER_DAMAGE_DONE_MODS");
	end
	
	AM_Events.STATS_CHANGED();
			
	-- This has to happen before class init, else we get no initial scaling broadcast
	if(not AM_Core.Silent) then
		AM_Core.SetVerbose();
	end
			
	--AM_Core:EnableEffects();
	
	if(OnEnableClass[playerClass]) then
		OnEnableClass[playerClass]();
	end
	
	if(AM_Events.PLAYER_LEVEL_UP) then
		AM_Core.RegisterEvent("PLAYER_LEVEL_UP");
	end
	
	if(AM_Events.PLAYER_TALENT_UPDATE) then
		AM_Core.RegisterEvent("PLAYER_TALENT_UPDATE");
	end
	
	if(AM_Events.GLYPH_UPDATED) then
		AM_Core.RegisterEvent("GLYPH_UPDATED");
	end
	
	if(AM_Events.PLAYER_EQUIPMENT_CHANGED) then
		AM_Core.RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	end
	
	AM_Core:ScheduleRepeatingTimer(AM_Events.OnPeriodicBroadcast, 300);
	
	AM_Core:RegisterComm("Absorbs_UnitStats", AM_Events.OnUnitStatsReceived);
	AM_Core:RegisterComm("Absorbs_Scaling", AM_Events.OnScalingReceived);	
		
	if(not AM_Public.Passive) then
		AM_Core:SetActive();
	end
	
	AM_Public.Enabled = true;
end

-- These function has to clear any memory this version of the library may
-- have accumulated. It will be called in case this library version gets
-- replaced by a new one
function AM_Core.Disable()	
	for guid, effects in pairs(activeEffectsBySpell) do
		AM_Callbacks:Fire("UnitCleared", guid);
	end
	
	wipe(AM_Core.activeEffects);
	wipe(AM_Core.activeCharges);
	
	wipe(AM_Core.Effects);
	wipe(AM_Core.CombatTriggers);
	wipe(AM_Core.AreaTriggers);
	
	wipe(AM_Core.UnitStats);
	wipe(AM_Core.Scaling);
	
	wipe(AM_Core.Events);
	AM_Core.Frame:UnregisterAllEvents();
	
	AM_Core:UnregisterAllComm();
	AM_Core:CancelAllTimers();
	
	AM_Public.Enabled = false;
	
	collectgarbage("collect");
end

function AM_Core.RegisterEvent(name)
	AM_Core.Frame:RegisterEvent(name);
end

function AM_Core.UnregisterEvent(name)
	AM_Core.Frame:UnregisterEvent(name);
end

function AM_Core.Print(str)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AbsMon|r: "..str)
end

function AM_Core.ApplySingularEffect(sourceGUID, sourceName, destGUID, destName, spellId)
	local destEffects = activeEffectsBySpell[destGUID];
	local effectInfo = Effects[spellId];
	local effectEntry;
	
	local value, quality, extra = effectInfo[3](sourceGUID, sourceName, destGUID, destName, spellId, destEffects);
	
	if(value == nil) then return; end
	
	-- No entry yet for this unit
	if(not destEffects) then
		effectEntry = {spellId, effectInfo[1], value, value, quality, 0, extra};
		
		destEffects = {[-1] = 0, [-2] = 1.0, [spellId] = effectEntry};
		
		activeEffectsBySpell[destGUID] = destEffects
		activeEffectsByPriority[destGUID] = {effectEntry};
		
		AM_Callbacks:Fire("EffectApplied", sourceGUID, sourceName, destGUID, destName, spellId, value, quality, effectInfo[2]);
	
	-- Not this specific effect yet
	elseif(not destEffects[spellId]) then	
		effectEntry = {spellId, effectInfo[1], value, value, quality, 0, extra};
				
		destEffects[spellId] = effectEntry;
	
		tinsert(activeEffectsByPriority[destGUID], effectEntry);
		sort(activeEffectsByPriority[destGUID], SortEffects);
		
		AM_Callbacks:Fire("EffectApplied", sourceGUID, sourceName, destGUID, destName, spellId, value, quality, effectInfo[2]);
	
	-- Effect exists already
	else	
		effectEntry = destEffects[spellId];
		local prevAmount = effectEntry[3];
	
		effectEntry[3] = value;
		effectEntry[4] = value;
		effectEntry[5] = quality;
		effectEntry[7] = extra;
		
		sort(activeEffectsByPriority[destGUID], SortEffects);
	
		AM_Callbacks:Fire("EffectUpdated", destGUID, spellId, value, quality, effectInfo[2]);
	
		-- Adjust value in case this is a visible absorb to get the difference
		value = value - prevAmount;
		
		-- Cancel the exting duration timeout timer
		AM_Core:CancelTimer(effectEntry[6], true);
	end
	
	if(quality < destEffects[-2]) then
		destEffects[-2] = quality;
	end	
	
	if(effectInfo[1] < 2) then
		destEffects[-1] = destEffects[-1] + value;
	
		AM_Callbacks:Fire("UnitUpdated", destGUID, destEffects[-1], destEffects[-2]);
	end
	
	if(effectInfo[2]) then
		-- We add a 5s grace period for latency and all kind of stuff
		-- This duration timeout should only be needed if the unit moved out of combat log
		-- reporting range anyway
		effectEntry[6] = AM_Core:ScheduleTimer(AM_Events.OnSingularTimeout, effectInfo[2] + 5, {destGUID, spellId});
	else
		effectEntry[6] = AM_Core:ScheduleRepeatingTimer(AM_Events.OnSingularActivityCheck, 8, {destGUID, spellId});
	end
	
	--AM_Core.Print("Applied buff effect "..spellId.." (priority: "..effectInfo[1]..") on "..destGUID.." for "..value..", new total: "..activeEffectsBySpell[destGUID][-1].." ("..#(activeEffectsByPriority[destGUID])..")");
end

function AM_Core.ApplyAreaEffect(triggerGUID, triggerName, destGUID, destName, spellId)	
	if(not activeAreaEffects[triggerGUID]) then
		return ApplySingularEffect(triggerGUID, triggerName, destGUID, destName, 0);
	end
	
	local effectEntry = activeAreaEffects[triggerGUID];			
	local destEffects = activeEffectsBySpell[destGUID];
	
	if(not destEffects) then
		-- Quality of 1.1 to enforce message
		destEffects = {[-1] = 0, [-2] = 1.1};
	
		activeEffectsBySpell[destGUID] = destEffects;
		activeEffectsByPriority[destGUID] = {};
		
	-- At the moment it is impossible for such an effect to be refreshed
	-- Since it is created by a summoned unit radiating it, it either
	-- gets removed/reapplied or removed/applied by a different unit.					
	elseif(destEffects[spellId]) then		
		--error("Called ApplyAreaEffect on refreshed aura");
		return;
	end
	
	destEffects[spellId] = effectEntry;				
	effectEntry[9] = effectEntry[9] + 1; -- increase refcount
	
	-- While we keep the trigger itself as a normal afflicted unit to keep
	-- track when the area effect breaks, we do not broadcast it nor have to
	-- keep a sorted priority list
	if(triggerGUID ~= destGUID) then
		tinsert(activeEffectsByPriority[destGUID], effectEntry);
		sort(activeEffectsByPriority[destGUID], SortEffects);		
	
		-- Note that we CANNOT use nil as an amount, since external addons can rely on this value being non-nil
		-- for sorting. We're using -1 here that usually represents infinite values
		AM_Callbacks:Fire("EffectApplied", triggerGUID, triggerName, destGUID, destName, spellId, -1, effectEntry[5], nil);
		
		-- Update quality if needed
		if(effectEntry[5] < destEffects[-2]) then
			destEffects[-2] = effectEntry[5];
		
			AM_Callbacks:Fire("UnitUpdated", destGUID, destEffects[-1], destEffects[-2]);
		end
	end
	
	--AM_Core.Print("Applied area effect "..spellId.." (priority: "..effectData[1]..") on "..destGUID.." for "..value..", new total: "..activeEffectsBySpell[destGUID][-1].." ("..#(activeEffectsByPriority[destGUID])..")");
end

function AM_Core.CreateAreaTrigger(sourceGUID, sourceName, triggerGUID, triggerName, spellId)
	if(activeAreaEffects[triggerGUID]) then
		--error("Trying to create new area trigger on existing one, triggerGUID: "..triggerGUID..", existing spellId: "..activeAreaEffects[triggerGUID][1]);
		return;
	end		

	local effectInfo = Effects[spellId];
	
	local value, quality, extra = effectInfo[3](sourceGUID, sourceName, triggerGUID, triggerName, spellId, nil);
			
	if(value == nil) then return; end
	
	--AM_Core.Print("Creating area tigger "..triggerGUID.."/"..triggerName.." from "..sourceName.." with spellId "..spellId.." for "..value.."/"..quality);	
	
	local effectEntry = {spellId, -1 * effectInfo[1], value, value, quality, 0, extra, triggerGUID, 0};
	effectEntry[6] = AM_Core:ScheduleTimer(AM_Events.OnAreaTimeout, effectInfo[2] + 5, effectEntry);
	
	activeAreaEffects[triggerGUID] = effectEntry;
	
	AM_Callbacks:Fire("AreaCreated", sourceGUID, sourceName, triggerGUID, spellId, value, quality);
end

local AM_Fire = AM_Callbacks.Fire;
function AM_Core.HitUnit(guid, absorbedTotal, overkill, spellSchool)
	local guidEffects = activeEffectsBySpell[guid];

	if(not guidEffects) then return; end
	
	local absorbedRemaining = absorbedTotal;
	
	local absorbed = 0;
	local keepEffect, visibleAbsorb = false, false;
	local i = 1;
	local effectEntry;
	
	-- This loop lasts as long as there is still an absorb value that
	-- no effect could account for, but it will break once the list of
	-- available effects got used completely.
	while(absorbedRemaining > 0) do
		effectEntry = activeEffectsByPriority[guid][i];
		
		-- Sometimes there can be holes in this list since we don't re-sort
		-- after removing an effect
		if(effectEntry == nil) then break; end
		
		-- Only absorb effects with exactly zero are ignored, negative ones
		-- are treated as infinite (that is, no addon should display their value)
		if(effectEntry[3] ~= 0) then
			-- Hit the abosrb effect
			absorbed, keepEffect = Effects[effectEntry[1]][4](effectEntry, absorbedRemaining, overkill, spellSchool);
			
			if(absorbed > 0) then
				-- Reduce the value of this effect and the remaining absorb value
				-- to be accounted for
				effectEntry[3] = effectEntry[3] - absorbed;
				absorbedRemaining = absorbedRemaining - absorbed;

				if(effectEntry[8]) then
					AM_Fire(AM_Callbacks, "AreaUpdated", effectEntry[8], effectEntry[3]);
				
					--AM_Core.Print("Hit area effect #"..i..", absorbed "..absorbed.." (keep: "..tostring(keepEffect).."), remaining: "..absorbedRemaining.." - unit: "..effectEntry[3].."/"..activeEffectsBySpell[guid][-1]);				
				else				
					-- If it should be visible (priority < 2), correct the total value
					if(effectEntry[2] < 2) then
						guidEffects[-1] = guidEffects[-1] - absorbed;
				
						-- Shows us that at least one visible effect got hit
						visibleAbsorb = true;
					end
					
					AM_Fire(AM_Callbacks, "EffectUpdated", guid, effectEntry[1], effectEntry[3]);
					
					--AM_Core.Print("Hit effect #"..i..", absorbed "..absorbed.." (keep: "..tostring(keepEffect).."), remaining: "..absorbedRemaining.." - total: "..guidEffects[-1]);
				end						
			end
			
			-- If the hit-function told us to remove the effect, do so
			-- Note that only RemoveActiveEffect is allowed to remove it from the
			-- list, we just set the value to zero, so it gets ignored on any hit.
			-- This is do not come into any desync issues with the events, and to
			-- keep the proper clean-up code in one place
			if(not keepEffect) then				
				effectEntry[3] = 0;
			end
		end
			
		i = i + 1;
	end	
	
	-- There are two possibilities when things are going wrong
	-- 
	--	a)	we guessed an absorb value too high, in that case it will
	--		automatically be corrected when it breaks
	--
	--	b)	we guessed an absorb value too low, so we end up with an
	--		amount to absorb when all effects seem to be gone
	--		(absorbedRemaining > 0)
	--		Note that we cannot rely on SPELL_AURA_REMOVED to check this,
	--		since it may happen completely out of order, but it will
	--		clear this unit soon or did so already.
	--		we reduce the quality to zero, since any absorb now happening
	--		cannot be accounted for.
	--		Since we may have rounding --errors from scanning the spellbook
	--		and calculating the value thereafter (does Blizzard round on
	--		EVERY step?!?), we accept a small threshold
	if(absorbedRemaining > LOW_VALUE_TOLERANCE) then
		guidEffects[-1] = guidEffects[-1] - absorbedRemaining;
		guidEffects[-2] = 0.0;
		visibleAbsorb = true;
	end
	
	if(visibleAbsorb) then
		AM_Fire(AM_Core, "UnitUpdated", guid, guidEffects[-1], guidEffects[-2]);
	end	
end

-- Note that this method should NOT be called on non-existing effects or units
-- There are no exist checks within it.
function AM_Core.RemoveActiveEffect(guid, spellId)
	local guidEffects = activeEffectsBySpell[guid];
	local effectEntry = guidEffects[spellId];
	
	--AM_Core.Print("Removing absorb effect "..spellId.." on "..guid.." with "..guidEffects[spellId][3].." left, total: "..guidEffects[-1].." ("..#(activeEffectsByPriority[guid])..")");
			
	-- This is a shared effect with a triggerGUID
	if(effectEntry[8]) then
		effectEntry[9] = effectEntry[9] - 1;
		
		if(guid ~= effectEntry[8]) then
			AM_Callbacks:Fire("EffectRemoved", guid, spellId);
		end
		
		if(effectEntry[9] == 0) then
			if(effectEntry[6]) then
				AM_Core:CancelTimer(effectEntry[6], true);
			end
			
			AM_Callbacks:Fire("AreaCleared", effectEntry[8]);
		end	
	
	else
		if(effectEntry[2] < 2) then
			guidEffects[-1] = guidEffects[-1] - effectEntry[3];		
			
			AM_Callbacks:Fire("UnitUpdated", guid, guidEffects[-1], guidEffects[-2]);
		end
	
		AM_Core:CancelTimer(effectEntry[6], true);
		
		AM_Callbacks:Fire("EffectRemoved", guid, spellId);	
	end		
	
	if(#(activeEffectsByPriority[guid]) == 1) then		
		activeEffectsBySpell[guid] = nil;
		activeEffectsByPriority[guid] = nil;
				
		AM_Callbacks:Fire("UnitCleared", guid);
	else
		guidEffects[spellId] = nil;
		
		for k, v in pairs(activeEffectsByPriority[guid]) do
			if(v[1] == spellId) then
				tremove(activeEffectsByPriority[guid], k);
				
				break;
			end
		end
	end
end

-- This is uses a _very_ simple queue implementation with tinsert and tremove.
-- It will not scale very well for large values, but we're talking of a maximum
-- of ~3 entries per GUID at any given time. A proper implementation
-- with linked list would probably not be any faster.
function AM_Core.PushCharge(guid, spellId, amount, lifetime)
	local guidCharges = activeCharges[guid];

	if(not guidCharges) then
		activeCharges[guid] = { [spellId] = {lastCombatLogEvent + lifetime, amount} };
		
	elseif(not guidCharges[spellId]) then
		guidCharges[spellId] = {lastCombatLogEvent + lifetime, amount};
	
	else
		tinsert(guidCharges[spellId], lastCombatLogEvent + lifetime);
		tinsert(guidCharges[spellId], amount);
	end
end

function AM_Core.PopCharge(guid, spellId)
	local guidCharges = activeCharges[guid];
	
	if(guidCharges) then
		local queue = activeCharges[guid][spellId];
		
		-- For some weird reason, it will fail (true even on empty array)
		-- if checked for queue[1] ?!?
		if(queue and queue[2]) then
			local chargeAmount;
			local chargeExpire;			
		
			-- This loop will not be able to run infinitely
			while(true) do
				-- In this order we might save one table reshuffle
				chargeAmount = tremove(queue, 2);
				
				if(not chargeAmount) then return 0; end
				
				chargeExpire = tremove(queue, 1);
			
				if(chargeExpire > lastCombatLogEvent) then
					return chargeAmount;
				end
			end
		end
	end
	
	return 0;
end

function AM_Core.AddCombatTrigger(target, event, func)
	local eventTriggers = AM_Core.CombatTriggers[event];
	local oldTrigger = eventTriggers[target];

	if(not oldTrigger) then
		eventTriggers[target] = func;
		
	else
		local listIndex = target.."_list";
		local funcList = eventTriggers[listIndex];
		
		-- There is already a list of callbacks, so we just add this one
		if(funcList) then
			for k, v in pairs(funcList) do
				if(v == func) then
					return;
				end
			end
		
			tinsert(funcList, func);
			
		-- We used a direct call so far, create a list and set up a handler
		else
			if(oldTrigger == func) then
				return;
			end
		
			funcList = {oldTrigger, func};			
			eventTriggers[listIndex] = funcList;
			
			local handler = function(...)
				for k, v in pairs(funcList) do
					v(...);
				end
			end
			
			eventTriggers[target] = handler;
		end		
	end
end

function AM_Core.RemoveCombatTrigger(target, event, func)
	local eventTriggers = AM_Core.CombatTriggers[event];
	
	local listIndex = target.."_list";
	local funcList = eventTriggers[listIndex];
	
	-- We have a list of callbacks, reduce if possible
	if(funcList) then
		if(#funcList == 2) then
			eventTriggers[target] = (funcList[1] == func) and funcList[2] or funcList[1];
			eventTriggers[listIndex] = nil;
		else
			-- ATTENTION: We have to keep the table in place
			-- because the handler references this table
			
			local old_funcList = DeepTableCopy(funcList);
			wipe(funcList);
			
			for k, v in pairs(old_funcList) do
				if(v ~= func) then				
					tinsert(funcList, v);
				end
			end
		end
	
	-- It was a direct call anyway
	else
		eventTriggers[target] = nil;
	end	
end

local lastAP, lastSP = 0, 0;
function AM_Core.SendUnitStats()
	if(curChatChannel) then
		local curAP, curSP = UnitStats[playerGUID][2], UnitStats[playerGUID][3];
		
		if( (curAP ~= lastAP) or (curSP ~= lastSP) ) then
			AM_Core:SendCommMessage("Absorbs_UnitStats", AM_Core:Serialize(playerGUID, playerClass, curAP, curSP), curChatChannel);
			
			lastAP, lastSP = curAP, curSP;
			
			CommStatsCooldown = true;
			AM_Core:ScheduleTimer(ClearCommStatsCooldown, 15);
		end				
	end
end

function AM_Core.SendScaling()
	if(curChatChannel) then	
		AM_Core:SendCommMessage("Absorbs_Scaling", AM_Core:Serialize(playerGUID, playerClass, AM_Events.OnScalingEncode()), curChatChannel);
		
		CommScalingCooldown = true;
		AM_Core:ScheduleTimer(ClearCommScalingCooldown, 30);
	end
end

-- An extension of AceTimer to schedule a one-shot timer that will not
-- be scheduled twice if scheduled again before it's fired.
local activeTimers = {};
function AM_Core:ScheduleUniqueTimer(id, callback, delay, arg)
	if(not activeTimers[id]) then
		self:ScheduleTimer(
			function()
				callback(arg);
				activeTimers[id] = nil;
			end, delay);
			
		activeTimers[id] = 1;
	end
end

function AM_Core.SetActive()
	AM_Core.RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");	
	
	AM_Public.Passive = false;
end

function AM_Core.SetPassive()
	AM_Core.UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	
	AM_Public.Passive = true;
end

function AM_Core.SetVerbose()
	AM_Core.RegisterEvent("PARTY_MEMBERS_CHANGED");
	AM_Core.RegisterEvent("RAID_ROSTER_UPDATE");
	
	AM_Public.Silent = false;
	
	AM_Events.GROUPING_CHANGED();
end

function AM_Core.SetSilent()
	AM_Core.UnregisterEvent("PARTY_MEMBERS_CHANGED");
	AM_Core.UnregisterEvent("RAID_ROSTER_UPDATE");
	
	AM_Public.Silent = true;
	
	curChatChannel = nil;
end

ApplySingularEffect = AM_Core.ApplySingularEffect;
ApplyAreaEffect = AM_Core.ApplyAreaEffect;
CreateAreaTrigger = AM_Core.CreateAreaTrigger;
HitUnit = AM_Core.HitUnit;
RemoveActiveEffect = AM_Core.RemoveActiveEffect;



---------------------
-- Event functions --
---------------------

function AM_Events.PLAYER_ENTERING_WORLD()
	if(not GetTalentInfo(1, 1)) then
		AM_Core.RegisterEvent("PLAYER_ALIVE");
	else
		AM_Core.Available = true;
	
		AM_Core.Enable();
	end
	
	AM_Core.UnregisterEvent("PLAYER_ENTERING_WORLD");
end

function AM_Events.PLAYER_ALIVE()
	AM_Core.Available = true;
	
	AM_Core.Enable();
	
	AM_Core.UnregisterEvent("PLAYER_ALIVE");
end

function AM_Events.COMBAT_LOG_EVENT_UNFILTERED(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)
	lastCombatLogEvent = timestamp;

	if(type == "SWING_DAMAGE") then
		local amount, overkill, school, resisted, blocked, absorbed = select(1, ...);
			
		if(not absorbed) then return; end
		
		HitUnit(destGUID, absorbed, amount, SCHOOL_MASK_PHYSICAL);
		
	elseif(type == "RANGE_DAMAGE" or type == "SPELL_DAMAGE" or type == "SPELL_PERIODIC_DAMAGE") then
		local spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed = select(1, ...);
		
		if(not absorbed) then return; end
		
		HitUnit(destGUID, absorbed, amount, spellSchool);		
		
	elseif(type == "SWING_MISSED") then
		local missType, amountMissed = select(1, ...);
		
		if(missType ~= "ABSORB") then return; end	
		
		HitUnit(destGUID, amountMissed, 0, SCHOOL_MASK_PHYSICAL);
		
	elseif(type == "RANGE_MISSED" or type == "SPELL_MISSED" or type == "SPELL_PERIODIC_MISSED") then
		local spellId, spellName, spellSchool, missType, amountMissed = select(1, ...);
			
		if(missType ~= "ABSORB") then return; end
		
		HitUnit(destGUID, amountMissed, 0, spellSchool);
		
	elseif(type == "SPELL_HEAL") then
		local spellId, spellName, spellSchool, amount, overhealing, absorb, critical = select(1, ...);		
		
		if(CombatTriggersOnHeal[sourceGUID]) then
			CombatTriggersOnHeal[sourceGUID](sourceGUID, sourceName, destGUID, destName, spellId, amount, overhealing);
		end
		
		if(critical and CombatTriggersOnHealCrit[sourceGUID]) then				
			CombatTriggersOnHealCrit[sourceGUID](sourceGUID, sourceName, destGUID, destName, spellId, amount, overhealing);
		end
	elseif(type == "SPELL_AURA_APPLIED") then
		local spellId, spellName = select(1, ...);
		
		if(Effects[spellId]) then
			if(Effects[spellId][1] > 0) then
				ApplySingularEffect(sourceGUID, sourceName, destGUID, destName, spellId);
			else
				ApplyAreaEffect(sourceGUID, sourceName, destGUID, destName, spellId);
			end
		end
		
		if(CombatTriggersOnAuraApplied[spellId]) then
			CombatTriggersOnAuraApplied[spellId](sourceGUID, sourceName, destGUID, destName, spellId);
		end
		
	elseif(type == "SPELL_AURA_REFRESH") then
		local spellId, spellName = select(1, ...);
		
		if(Effects[spellId]) then
			if(Effects[spellId][1] > 0) then
				ApplySingularEffect(sourceGUID, sourceName, destGUID, destName, spellId);
			else
				ApplyAreaEffect(sourceGUID, sourceName, destGUID, destName, spellId);
			end
		end
		
		if(CombatTriggersOnAuraApplied[spellId]) then
			CombatTriggersOnAuraApplied[spellId](sourceGUID, sourceName, destGUID, destName, spellId);
		end
				
	elseif(type == "SPELL_AURA_REMOVED") then
		local spellId = select(1, ...);			
		
		if(Effects[spellId]) then
			if(activeEffectsBySpell[destGUID] and activeEffectsBySpell[destGUID][spellId]) then
				RemoveActiveEffect(destGUID, spellId);
			end
		end
		
		if(CombatTriggersOnAuraRemoved[spellId]) then
			CombatTriggersOnAuraRemoved[spellId](sourceGUID, sourceName, destGUID, destName, spellId);
		end
		
	elseif(type == "SPELL_SUMMON") then
		local spellId = select(1, ...);
		
		if(AreaTriggers[spellId]) then
			CreateAreaTrigger(sourceGUID, sourceName, destGUID, destName, AreaTriggers[spellId]);
		end
		
		--CombatTriggers(spellId.."_OnSummon"](sourceGUID, sourceName, destGUID, destName, spellId);
	end
end

function AM_Events.GROUPING_CHANGED()
	-- Note that the order here is VERY important
	if(UnitInBattleground("player")) then	
		curChatChannel = "BATTLEGROUND";
	elseif(UnitInRaid("player")) then
		curChatChannel = "RAID";
	elseif(GetNumPartyMembers() > 0) then
		curChatChannel = "PARTY";
	else
		curChatChannel = nil;
	end
end

local iccBuffModifier = {
	-- Hellscream's Warsong
	[73816] = 1.05, [73818] = 1.10, [73819] = 1.15,
	[73820] = 1.20, [73821] = 1.25, [73822] = 1.30,
	-- Strength of Wrynn
	[73762] = 1.05, [73824] = 1.10, [73825] = 1.15,
	[73826] = 1.20, [73827] = 1.25, [73828] = 1.30,
};
local iccWrynnName = GetSpellInfo(73828);
local iccHellscreamName = GetSpellInfo(73822);

-- Firelord's Demise (Molten Core). Rank->% confirmed: lowest spell ID = 5%,
-- highest = 20%, +5% per rank.
local mcBuffModifier = {
	[500316] = 1.05, [500317] = 1.10, [500318] = 1.15, [500319] = 1.20,
};
local mcBuffName = GetSpellInfo(500319);

-- Zul'Aman zone buff. Rank->% is EXTRAPOLATED from Molten Core's pattern
-- (+5% per rank, lowest ID = lowest %) - not independently confirmed, and
-- this has one more rank than MC (5 vs 4), so the 25% top end is a guess.
-- Verify in-game and adjust if wrong.
local zaBuffModifier = {
	[500324] = 1.05, [500325] = 1.10, [500326] = 1.15, [500327] = 1.20, [500328] = 1.25,
};
local zaBuffName = GetSpellInfo(500328);

-- Gruul's Lair zone buff. Spell ID range (500329-500333) is extrapolated
-- from ZA's 5-ID block size, NOT confirmed in-game - verify these IDs
-- actually exist before trusting this table.
local gruulBuffModifier = {
	[500329] = 1.05, [500330] = 1.10, [500331] = 1.15, [500332] = 1.20, [500333] = 1.25,
};
local gruulBuffName = GetSpellInfo(500333);

-- Keys are WorldMapArea.dbc IDs +1: GetCurrentMapAreaID() returns dbcID + 1
-- (FrameXML does GetCurrentMapAreaID() - 1 before SetMapByID). Verified in
-- the dbc: ICC 604, Wintergrasp 501, MoltenCore 696, GruulsLair 776,
-- ZulAman 781; the last three only exist on clients with backported maps.
local zoneBuffData = {
	[605] = { name = iccWrynnName, altName = iccHellscreamName, modifier = iccBuffModifier }, -- Icecrown Citadel
	[697] = { name = mcBuffName, modifier = mcBuffModifier }, -- Molten Core (unverified)
	[782] = { name = zaBuffName, modifier = zaBuffModifier }, -- Zul'Aman (unverified)
	[777] = { name = gruulBuffName, modifier = gruulBuffModifier }, -- Gruul's Lair (unverified)
};

local function UpdateZoneBuffModifier(mapID)
	local data = zoneBuffData[mapID];

	-- data.name is nil when the client lacks the spell, and UnitBuff(unit, nil) errors.
	if(not (data and data.name)) then
		ZONE_MODIFIER = 1;
		return;
	end

	local _, _, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", data.name);
	if(not spellID and data.altName) then
		_, _, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", data.altName);
	end

	ZONE_MODIFIER = spellID and data.modifier[spellID] or 1;
end

local function UpdateZoneModifier()
	if(UnitInBattleground("player")) then
		ZONE_MODIFIER = 0.9;
	elseif(IsActiveBattlefieldArena()) then
		ZONE_MODIFIER = 0.9;
	else
		local mapID = GetCurrentMapAreaID()
		if(mapID == 502) then -- Wintergrasp
			ZONE_MODIFIER = 0.9;
		elseif(zoneBuffData[mapID]) then
			UpdateZoneBuffModifier(mapID);
		else
			ZONE_MODIFIER = 1;
		end
	end
end

-- Battlefield status and zone buffs both reach the client after this fires, so re-check shortly after.
function AM_Events.ZONE_CHANGED_NEW_AREA()
	UpdateZoneModifier();

	AM_Core:ScheduleUniqueTimer("zone_modifier", UpdateZoneModifier, 2);
end
AM_Events.ZONE_CHANGED_INDOORS = AM_Events.ZONE_CHANGED_NEW_AREA;
AM_Events.UPDATE_BATTLEFIELD_STATUS = UpdateZoneModifier;

-- The raid leader can toggle a zone buff off mid-run, which fires no zone event.
function AM_Events.UNIT_AURA(unit)
	if(unit == "player") then
		local mapID = GetCurrentMapAreaID();
		if(zoneBuffData[mapID]) then
			UpdateZoneBuffModifier(mapID);
		end
	end
end

function AM_Events.STATS_CHANGED()
	local baseAP, plusAP, minusAP = UnitAttackPower("player");

	UnitStats[playerGUID][2] = baseAP + plusAP - minusAP;
	-- TODO: What about spell power ~= healing spell power?
	UnitStats[playerGUID][3] = GetSpellBonusHealing();

	if(curChatChannel) then
		AM_Core:ScheduleUniqueTimer("comm_stats", AM_Core.SendUnitStats, CommStatsCooldown and 15 or 5);
	end
end

function AM_Events.OnUnitStatsReceived(prefix, text, distribution, target)
	if(not text) then return; end

	local success, guid, class, ap, sp = AM_Core:Deserialize(text);

	if(not(success and guid and class and ap and sp)) then return; end

	if(guid == playerGUID) then return; end

	if(not UnitStats[guid]) then
		UnitStats[guid] = {class, ap, sp, 1.0};
	else
		UnitStats[guid][2] = ap;
		UnitStats[guid][3] = sp;
		UnitStats[guid][4] = 1.0;
	end
end

function AM_Events.OnScalingEncode()
	return Scaling[playerGUID];
end

function OnScalingDecode.DEFAULT(guid, guidScaling)
	Scaling[guid] = guidScaling;
end

function AM_Events.OnScalingReceived(prefix, text, distribution, target)
	if(not text) then return; end

	local success, guid, class, inScaling = AM_Core:Deserialize(text);

	if(not(success and guid and class and inScaling)) then return; end

	if(guid == playerGUID) then return; end

	(OnScalingDecode[class])(guid, inScaling);
end

function AM_Events.OnPeriodicBroadcast()
	if(not curChatChannel) then return; end

	local playerStats = UnitStats[playerGUID];
	local playerScaling = Scaling[playerGUID];

	if(not CommStatsCooldown) then
		AM_Core:ScheduleUniqueTimer("comm_stats", AM_Core.SendUnitStats, 5);
	end

	if(not CommScalingCooldown) then
		AM_Core:ScheduleUniqueTimer("comm_scaling", AM_Core.SendScaling, 5);
	end
end

function AM_Events.OnSingularTimeout(args)
	local guid, spellId = args[1], args[2];

	if(activeEffectsBySpell[guid] and activeEffectsBySpell[guid][spellId]) then
		RemoveActiveEffect(guid, spellId);
	end
end

function AM_Events.OnSingularActivityCheck(args)
	local guid, spellId = args[1], args[2];

	if(activeEffectsBySpell[guid] and activeEffectsBySpell[guid][spellId]) then
		local _, _, _, _, _, name = GetPlayerInfoByGUID(guid);

		-- We cannot track whether it's still on, remove it
		if(not name) then
			AM_Core:CancelTimer(activeEffectsBySpell[guid][spellId][6]);

			RemoveActiveEffect(guid, spellId);

			return
		end

		local stillActive = false;

		for i=1, 40 do
			local _, _, _, _, _, _, _, _, _, _, buffId = UnitBuff(name, i);

			if(not buffId) then break; end

			if(buffId == spellId) then
				stillActive = true;

				break;
			end
		end

		if(not stillActive) then
			AM_Core:CancelTimer(activeEffectsBySpell[guid][spellId][6]);

			RemoveActiveEffect(guid, spellId);
		end
	else
		-- Make sure to remove the timer
		AM_Core:CancelTimer(activeEffectsBySpell[guid][spellId][6]);
	end
end

-- This should be called in even less cases than the normal timeout
function AM_Events.OnAreaTimeout(areaEntry)
	-- Disable the timer handle entry already
	areaEntry[6] = nil;

	for guid, guidEffects in pairs(activeEffectsBySpell) do
		if(areaEntry[9] == 0) then return; end

		for spellId, effectEntry in pairs(guidEffects) do
			if(effectEntry == areaEntry) then
				RemoveActiveEffect(guid, spellId);
			end
		end
	end

	-- We're only here if we didn't reduce the refcount to zero
	----error("Positive refcount "..areaEntry[9].." remained for area effect "..areaEntry[1].." by trigger "..areaEntry[8]);
end

-- Map client events to our callbacks
AM_Events.PARTY_MEMBERS_CHANGED = AM_Events.GROUPING_CHANGED;
AM_Events.RAID_ROSTER_UPDATE = AM_Events.GROUPING_CHANGED;
AM_Events.PLAYER_DAMAGE_DONE_MODS = AM_Events.STATS_CHANGED;
AM_Events.UNIT_ATTACK_POWER = AM_Events.STATS_CHANGED;



----------------------
-- Public functions --
----------------------

function AM_Public.RegisterEffectCallbacks(self, funcApplied, funcUpdated, funcRemoved)
	AM_Public.RegisterCallback(self, "EffectApplied", funcApplied);
	AM_Public.RegisterCallback(self, "EffectUpdated", funcUpdated or funcApplied);
	AM_Public.RegisterCallback(self, "EffectRemoved", funcRemoved or funcApplied);
end

function AM_Public.RegisterUnitCallbacks(self, funcUpdated, funcCleared)
	AM_Public.RegisterCallback(self, "UnitUpdated", funcUpdated);
	AM_Public.RegisterCallback(self, "UnitCleared", funcCleared or funcUpdated);
end

function AM_Public.RegisterAreaCallbacks(self, funcCreated, funcUpdated, funcCleared)
	AM_Public.RegisterCallback(self, "AreaCreated", funcCreated);
	AM_Public.RegisterCallback(self, "AreaUpdated", funcUpdated or funcCreated);
	AM_Public.RegisterCallback(self, "AreaCleared", funcCleared or funcCreated);
end

function AM_Public.GetLowValueTolerance()
	return LOW_VALUE_TOLERANCE;
end

function AM_Public.SetLowValueTolerance(value)
	LOW_VALUE_TOLERANCE = tonumber(value);
end

function AM_Public.PrintProfiling()
	if(GetCVar("scriptProfile") ~= "1") then
		AM_Core.Print("CPU profiling disabled");
		return;
	end

	UpdateAddOnCPUUsage();
	UpdateAddOnMemoryUsage();

	AM_Core.Print("Mem: "..format("%.3f", GetAddOnMemoryUsage("AbsorbsMonitor")).." kB");
	AM_Core.Print("Time: "..format("%.3f", GetAddOnCPUUsage("AbsorbsMonitor")).." ms");
	AM_Core.Print("--- critical code paths (all times in ms) ---");

	local funcTable;

	funcTable = {
		["ApplySingularEffect"] = ApplySingularEffect,
		["HitUnit"] = HitUnit,
		["RemoveActiveEffect"] = RemoveActiveEffect,
		["OnCombatLogEvent"] = OnCombatLogEvent,
		["SortEffects"] = SortEffects,
	};

	local v_type;
	local time_self, time_combined, count;

	for k, v in pairs(funcTable) do
		v_type = type(v);

		if(v_type == "function") then
			time_self, count = GetFunctionCPUUsage(v, false);
			time_combined = GetFunctionCPUUsage(v, true);

			AM_Core.Print(k.." (#"..count.."): "..format("%.4f", time_self).." / "..format("%.4f", time_combined));
		end
	end
end

function AM_Public.Unit_Total(guid)
	local guidEffects = activeEffectsBySpell and activeEffectsBySpell[guid];

	return (guidEffects and guidEffects[-1] or 0);
end

function AM_Public.Unit_Effect(guid, spellId)
	local guidEffects = activeEffectsBySpell[guid];

	if(guidEffects) then
		if(guidEffects[spellId]) then
			return guidEffects[spellId][3];
		end
	end

	return 0;
end

function AM_Public.Unit_Stats(guid, missingQuality)
	local guidStats = UnitStats[guid];

	if(guidStats) then
		return guidStats[2] or 0, guidStats[3] or 0, guidStats[4] or missingQuality;
	else
		return 0, 0, missingQuality;
	end
end

function AM_Public.Unit_Scaling(guid, defaultScaling, defaultQuality)
	local guidScaling = Scaling[guid];

	if(guidScaling) then
		return guidScaling, 1.0;
	else
		return defaultScaling, defaultQuality;
	end
end

-- Optimized method to save one function call on creation, since a lot of spells
-- actually require stats and scaling
function AM_Public.Unit_StatsAndScaling(guid, missingQuality, defaultScaling, defaultQuality)
	local guidStats = UnitStats[guid];
	local guidScaling = Scaling[guid];

	if(guidStats) then
		-- Attack power, spell power, quality
		if(guidScaling) then
			return guidStats[2] or 0, guidStats[3] or 0, guidStats[4] or missingQuality, guidScaling, 1.0;
		else
			return guidStats[2] or 0, guidStats[3] or 0, guidStats[4] or missingQuality, defaultScaling, defaultQuality;
		end
	else
		if(guidScaling) then
			return 0, 0, missingQuality, guidScaling, 1.0;
		else
			return 0, 0, missingQuality, defaultScaling, defaultQuality;
		end
	end
end

function AM_Public.Unit_EffectsMap(guid)
	return activeEffectsBySpell[guid];
end

function AM_Public.Unit_EffectsList(guid)
	return activeEffectsByPriority[guid];
end

function AM_Public.ScheduleScalingBroadcast()
	if(curChatChannel) then
		AM_Core:ScheduleUniqueTimer("comm_scaling", AM_Core.SendScaling, CommScalingCooldown and 30 or 5);
	end
end

function AM_Public.Test()
	ApplySingularEffect("0x0", "source", "0x1a", "dest A", 27779);
	ApplySingularEffect("0x0", "source", "0x1a", "dest A", 48066);
	ApplySingularEffect("0x0", "source", "0x1b", "dest B", 31771);
	ApplySingularEffect("0x0", "source", "0x1b", "dest B", 57350);
	ApplySingularEffect("0x0", "source", "0x1c", "dest C", 48066);
	ApplySingularEffect("0x0", "source", "0x1c", "dest C", 28810);
end



------------------------------
-- Generic Effect functions --
------------------------------

local PushCharge = AM_Core.PushCharge;
local PopCharge = AM_Core.PopCharge;
local Unit_Stats = AM_Public.Unit_Stats;
local Unit_Scaling = AM_Public.Unit_Scaling;
local Unit_StatsAndScaling = AM_Public.Unit_StatsAndScaling;

--- Generic Create function (only for documentary purposes)
-- @param	sourceGUID			guid of the originating unit
-- @param	sourceName			name of the originating unit
-- @param	destGUID			guid of the affected unit
-- @param	destName			name of the affected unit
-- @param	spellId				the spellId of this absorb effect
-- @param	destEffects			activeEffectsBySpell[destGUID]
-- @return	total value of this absorb effect
-- @return	quality (that is accuracy) of this value
local function generic_Create(sourceGUID, sourceName, destGUID, destName, spellId, destEffects)
end

-- Generic Create function for constant effects pulled from a table
-- Expects the table at effect[5] indexed by spellId with base values
local function generic_ConstantByTable_Create(sourceGUID, sourceName, destGUID, destName, spellId, destEffects)
	return Effects[spellId][5][spellId], 1.0;
end

-- Generic Create function for effects simply scaling with spellpower and a fixed
-- coefficient.
-- Expects at effect[5] a table indexed by spellId with the base values and at
-- effect[6] the spellpower coefficient
local function generic_SpellScalingByTable_Create(sourceGUID, sourceName, destGUID, destName, spellId, destEffects)
	local effectInfo = Effects[spellId];
	local _, sp, quality = Unit_Stats(sourceGUID, 0.1);

	return floor(effectInfo[5][spellId] + (sp * effectInfo[6])), quality;
end

--- Generic Hit function suitable for most absorb effects
-- Note that this function is only responsible for determining the amount this
-- particular absorb effect will take, NOT to handle its consequences like updating
-- the data structures
-- @param	effectEntry			activeEffectsBySpell[guid][spellId]
-- @param	absorbedRemaining	absorb value left to be accounted for on this unit
-- @param	overkill			amount of damage done on top of the absorb
-- @param	spellSchool			spell school for this hit
-- @return	absorb value this effect can account fors
-- @return	whether this absorb was broken by this hit
local function generic_Hit(effectEntry, absorbedRemaining, overkill, spellSchool)
	if(absorbedRemaining > effectEntry[3]) then
		-- dirty but efficient
		absorbedRemaining = effectEntry[3];
		overkill = 1;
	end

	return absorbedRemaining, (overkill == 0);
end



---------------------------
-- Effects: Death Knight --
---------------------------

local deathknight_MS_Ranks = {[0] = 0, [1] = 0.08, [2] = 0.16, [3] = 0.25};

-- Public Scaling: { [MagicSuppression] }
local deathknight_defaultScaling = {0};


local function deathknight_AntiMagicShell_Create(sourceGUID, sourceName, destGUID, destName, spellId, destEffects)
	local maxHealth = UnitCall_bySearch(UnitHealthMax, destGUID, destName);

	if(maxHealth == 0) then
		return 0, 0.0;
	end

	local sourceScaling, quality = Unit_Scaling(sourceGUID, deathknight_defaultScaling, 0.5);

	return floor(maxHealth * 0.5), quality, (0.75 + sourceScaling[1]);
end

local function deathknight_AntiMagicShell_Hit(effectEntry, absorbedRemaining, overkill, spellSchool)
	-- TODO: what happens to mixed school attacks?
	if(spellSchool == SCHOOL_MASK_PHYSICAL) then
		return 0, true;
	end

	local maxAbsorb = floor((absorbedRemaining + overkill) * effectEntry[7]);

	if(effectEntry[3] < maxAbsorb) then
		return effectEntry[3], false;
	else
		return maxAbsorb, true;
	end
end

local function deathknight_AntiMagicZone_Create(sourceGUID, sourceName, destGUID, destName, spellId, destEffects)
	local ap, _, quality = Unit_Stats(sourceGUID, 0.3);

	return (10000 + 2 * ap), quality;
end

local function deathknight_AntiMagicZone_Hit(effectEntry, absorbedRemaining, overkill, spellSchool)
	-- TODO: what happens to mixed school attacks?
	if(spellSchool == SCHOOL_MASK_PHYSICAL) then
		return 0, true;
	end

	local maxAbsorb = floor((absorbedRemaining + overkill) * 0.75);

	if(effectEntry[3] < maxAbsorb) then
		return effectEntry[3], false;
	else
		return maxAbsorb, true;
	end
end

local function deathknight_OnTalentUpdate()
	-- Magic Suppression
	local _, _, _, _, t = GetTalentInfo(3, 18);

	playerScaling[1] = deathknight_MS_Ranks[t];

	AM_Public.ScheduleScalingBroadcast();
end

function OnEnableClass.DEATHKNIGHT()
	AM_Events.PLAYER_TALENT_UPDATE = deathknight_OnTalentUpdate;

	deathknight_OnTalentUpdate();
end



--------------------
-- Effects: Druid --
--------------------

local function druid_SavageDefense_Create(sourceGUID, sourceName, destGUID, destName, spellId, destEffects)
	local ap, _, quality = Unit_Stats(sourceGUID, 0.0);

	return floor(ap * 0.25), quality;
end

local function druid_SavageDefense_Hit(effectEntry, absorbedRemaining, overkill, spellSchool)
	-- TODO: what happens to mixed school attacks?
	if(spellSchool == SCHOOL_MASK_PHYSICAL) then
		return min(effectEntry[3], absorbedRemaining), false;
	else
		return 0, true;
	end
end



-------------------
-- Effects: Mage --
-------------------

-- Table for base values of
-- Fire Ward, Frost Ward, Ice Barrier, Mana Shield
-- TODO: base leveling increase
local mage_Absorb_Spells = {
	-- Fire Ward
	[543] = 165,
	[8457] = 290,
	[8458] = 470,
	[10223] = 675,
	[10225] = 875,
	[27218] = 1125,
	[43010] = 1950,

	-- Frost Ward
	[6143] = 165,
	[8461] = 290,
	[8462] = 470,
	[10177] = 675,
	[28609] = 875,
	[32796] = 1125,
	[43012] = 1950,

	-- Ice Barrier
	[11426] = 438,
	[13031] = 549,
	[13032] = 678,
	[13033] = 818,
	[27134] = 925,
	[33405] = 1075,
	[43038] = 2800,
	[43039] = 3300,

	-- Mana Shield
	[1463] = 120,
	[8494] = 210,
	[8495] = 300,
	[10191] = 390,
	[10192] = 480,
	[10193] = 570,
	[27131] = 715,
	[43019] = 1080,
	[43020] = 1330,
};

-- Public Scaling: { [GlyphOfIceBarrier] }
local mage_defaultScaling = {1.0};


-- No Downranking support here
local function mage_IceBarrier_Create(sourceGUID, sourceName, destGUID, destName, spellId, destEffects)
	local _, sp, quality1, sourceScaling, quality2 = Unit_StatsAndScaling(sourceGUID, 0.3, mage_defaultScaling, 0.4);

	return floor((mage_Absorb_Spells[spellId] + (sp * 0.8068)) * sourceScaling[1]), math.min(quality1, quality2);
end

local function mage_FireWard_Hit(effectEntry, absorbedRemaining, overkill, spellSchool)
	if(spellSchool ~= SCHOOL_MASK_FIRE) then
		return 0, true;
	end

	return generic_Hit(effectEntry, absorbedRemaining, overkill, spellSchool);
end

local function mage_FrostWard_Hit(effectEntry, absorbedRemaining, overkill, spellSchool)
	if(spellSchool ~= SCHOOL_MASK_FROST) then
		return 0, true;
	end

	return generic_Hit(effectEntry, absorbedRemaining, overkill, spellSchool);
end

local function mage_OnGlyphUpdated()
	local glyphSpellId;

	playerScaling[1] = 1.0;

	for i = 1, 6 do
		_, _, glyphSpellId = GetGlyphSocketInfo(i);

		-- Glyph of Ice Barrier
		if(glyphSpellId and glyphSpellId == 63095) then
			playerScaling[1] = 1.3;

			break;
		end
	end

	AM_Public.ScheduleScalingBroadcast();
end

function OnEnableClass.MAGE()
	AM_Events.GLYPH_UPDATED = mage_OnGlyphUpdated;

	mage_OnGlyphUpdated();
end



----------------------
-- Effects: Paladin --
----------------------

-- Public Scaling: { [DivineGuardian] }
local paladin_defaultScaling = {1.0};


-- The base value is always 500
local function paladin_SacredShield_Create(sourceGUID, sourceName, destGUID, destName, spellId, destEffects)
	local _, sp, quality1, sourceScaling, quality2 = Unit_StatsAndScaling(sourceGUID, 0.1, paladin_defaultScaling, 0.2);
	
	-- Fallback defaults when target/caster stats are unknown
	sp = sp or 0;
	quality1 = quality1 or 0.1;
	quality2 = quality2 or 0.2;
	sourceScaling = sourceScaling or {1.0};

	return floor((500 + (sp * 0.75)) * (sourceScaling[1] or 1.0) * ZONE_MODIFIER), math.min(quality1, quality2);
end

local function paladin_OnTalentUpdate()
	-- No need to do it before
	if(UnitLevel("player") < 80) then return; end

	-- Divine Guardian
	local _, _, _, _, t = GetTalentInfo(2, 9);

	playerScaling[1] = 1 + (t * 0.1);

	AM_Public.ScheduleScalingBroadcast();
end

function OnEnableClass.PALADIN()
	AM_Events.PLAYER_TALENT_UPDATE = paladin_OnTalentUpdate;

	paladin_OnTalentUpdate();
end



---------------------
-- Effects: Priest --
---------------------

PRIEST_DIVINEAEGIS_SPELLID = 47753;

-- [rank] = {spellId, level, baseValue, incValue, maxLevel}
local priest_PWS_Ranks = {
	[1] = {17, 6, 44, 4, 11},
	[2] = {592, 12, 88, 6, 17},
	[3] = {600, 18, 158, 8, 23},
	[4] = {3747, 24, 234, 10, 29},
	[5] = {6065, 30, 301, 11, 35},
	[6] = {6066, 36, 381, 13, 41},
	[7] = {10898, 42, 484, 15, 47},
	[8] = {10899, 48, 605, 17, 53},
	[9] = {10900, 54, 763, 19, 59},
	[10] = {10901, 60, 942, 21, 65},
	[11] = {25217, 65, 1125, 18, 69},
	[12] = {25218, 70, 1265, 20, 74},
	[13] = {48065, 75, 1920, 30, 79},
	[14] = {48066, 80, 2230, 0, 84}
};

-- Public Scaling:
--   Power Word: Shield: [spellId] = {base, spFactor}
--   Divine Aegis: [47753] = healFactor
local priest_defaultScaling = {[PRIEST_DIVINEAEGIS_SPELLID] = 0};

do
	for k, v in pairs(priest_PWS_Ranks) do
		priest_defaultScaling[v[1]] = {v[3], 0.8068};
	end
end

-- Private Scaling
--   Talents: "TwinDisc", "ImpPWS", "FocusedPower", "DivineAegis", "BorrowedTime", "SpiritualHealing"
--	 Gear: "4pcRaid9", "4pcRaid10"
--   Computed: base, sp, DA


local function priest_PowerWordShield_Create(sourceGUID, sourceName, destGUID, destName, spellId, destEffects)
	local _, sp, quality1, sourceScaling, quality2 = Unit_StatsAndScaling(sourceGUID, 0.1, priest_defaultScaling, 0.1);

	local scaleData = sourceScaling[spellId] or priest_defaultScaling[spellId];
	if(scaleData) then
		return floor((scaleData[1] + sp * scaleData[2]) * ZONE_MODIFIER), math.min(quality1, quality2);
	end
end

local function priest_PowerWordBarrier_Create(sourceGUID, sourceName, destGUID, destName, spellId, destEffects)
	return 0, 0.0;
end

local function priest_PowerWordBarrier_Hit(effectEntry, absorbedRemaining, overkill, spellSchool)
	return 0, false;
end

local function priest_DivineAegis_Create(sourceGUID, sourceName, destGUID, destName, spellId, destEffects)
	local existing = 0;

	if(destEffects and destEffects[spellId]) then
		existing = destEffects[spellId][3];
	end

	local charge = PopCharge(destGUID, spellId);

	if(charge == 0) then
		return existing, 0.0;
	end

	local destLevel = UnitCall_bySearch(UnitLevel, destGUID, destName);
	local quality = 1.0;

	if(destLevel == 0) then
		destLevel = 80;
		quality = 0.4;
	end

	return min(destLevel * 125, existing + charge), quality;
end

-- I officially HATE Divine Aegis (and Val'anyr for that matter) from now.
-- After extensive testing and parsing/filtering a few hours of combat log, I found the following facts:
-- 	* In MOST cases, every critical heal will trigger an AURA_APPLIED/AURA_REFRESHED event, even on multiple crits on
--    one penance and with both AURA events being triggered after all critical heals. In rare cases, there is only one...
--	* If on your side the aura get removed before the next one is applied (double penance crit, both critical heals
--    are first in your combat log), then AURA_APPLIED -> AURA_REMOVED by damage -> AURA_APPLIED for 2nd crit
--	* There are occasions where 2 Discipline priests apply two Divine Aegis auras. In general, the source of Divine Aegis
--    is completely fucked up in those cases. If two priests channel penance at the same time, both crit, you can never say
--    who will get the AURA_APPLIED event credited (yes, I found both the first-hitting priest as well as the second-hitting
--    priest there!) and who the following AURA_REFRESHED events
local function priest_DivineAegis_OnHealCrit(sourceGUID, sourceName, destGUID, destName, spellId, amount)
	-- We can do a direct access to Scaling here, since the callback is only in place if it was present
	-- in the first place

	PushCharge(destGUID, PRIEST_DIVINEAEGIS_SPELLID, floor(amount * Scaling[sourceGUID][PRIEST_DIVINEAEGIS_SPELLID]), 5.0);
end

local function priest_ApplyScaling(guid, level, baseFactor, spFactor, daFactor)
	local guidScaling;

	--AbsorbsMonitor:Print("Applying for "..guid.." ("..level..") with factors: "..baseFactor.." / "..spFactor.." / "..daFactor);

	if(not Scaling[guid]) then
		guidScaling = {};
		Scaling[guid] = guidScaling;
	else
		guidScaling = Scaling[guid];
	end

	guidScaling[PRIEST_DIVINEAEGIS_SPELLID] = daFactor;

	if(daFactor > 0) then
		AM_Core.AddCombatTrigger(guid, "OnHealCrit", priest_DivineAegis_OnHealCrit);
	else
		AM_Core.RemoveCombatTrigger(guid, "OnHealCrit", priest_DivineAegis_OnHealCrit);
	end

	local rankValue, rankSP;

	for k, v in pairs(priest_PWS_Ranks) do
		if(v[2] <= level) then
			if(level == 80) then
				rankValue = v[3] + v[4];
			else
				-- TODO
				rankValue = v[3];
			end

			--https://github.com/TrinityCore/TrinityCore/blob/3.3.5/src/server/game/Entities/Unit/Unit.cpp#L2326
			local downCoeff = 1
			if(level > v[5]) then
				downCoeff = max(0, min(1, (22 + v[5] - level)/20))
			end
			rankSP = spFactor * downCoeff;
			
			guidScaling[v[1]] = {rankValue * baseFactor, rankSP};
		end
	end
end

local function priest_UpdatePlayerScaling()
	-- Spiritual Healing shares no bit with PW:S's spell class mask, so it never scales the shield.
	privateScaling.base = (1.0 + (privateScaling["TwinDisc"] * 0.01)) *
	(1.0 + (privateScaling["FocusedPower"] * 0.02)) *
	(1.0 + ((privateScaling["ImpPWS"] + privateScaling["4pcRaid10"]) * 0.05));

	privateScaling.sp = (0.8068 + (privateScaling["BorrowedTime"] * 0.08)) *
	(1.0 + (privateScaling["TwinDisc"] * 0.01)) *
	(1 + (privateScaling["FocusedPower"] * 0.02)) *
	(1.0 + ((privateScaling["ImpPWS"] + privateScaling["4pcRaid10"]) * 0.05));
	
	privateScaling.DA = (privateScaling["DivineAegis"] * 0.1) * (1 + (privateScaling["4pcRaid9"] * 0.03));

	priest_ApplyScaling(playerGUID, UnitLevel("player"), privateScaling.base, privateScaling.sp, privateScaling.DA);
	
	AM_Public.ScheduleScalingBroadcast();	
end

local function priest_ScanTalents()
	-- Twin Disciplines
	local _, _, _, _, t = GetTalentInfo(1, 2);
	privateScaling["TwinDisc"] = t;
	
	-- Improved Power Word: Shield
	local _, _, _, _, t = GetTalentInfo(1, 9);
	privateScaling["ImpPWS"] = t;
	
	-- Focused Power
	local _, _, _, _, t = GetTalentInfo(1, 16);
	privateScaling["FocusedPower"] = t;
	
	-- Divine Aegis
	local _, _, _, _, t = GetTalentInfo(1, 24);		
	privateScaling["DivineAegis"] = t;
	
	-- Borrowed Time
	local _, _, _, _, t = GetTalentInfo(1, 27);
	privateScaling["BorrowedTime"] = t;
	
	-- Spiritual Healing
	local _, _, _, _, t = GetTalentInfo(2, 16);
	privateScaling["SpiritualHealing"] = t;
end

local function priest_ScanEquipment()
	local n = 0;
	
	-- Crimson Acolyte Raiment's 4-piece Bonus
	if(IsEquippedItem(50765) or IsEquippedItem(51178) or IsEquippedItem(51261))		then n = 1; end
	if(IsEquippedItem(50767) or IsEquippedItem(51175) or IsEquippedItem(51264))		then n = n + 1; end
	if(IsEquippedItem(50768) or IsEquippedItem(51176) or IsEquippedItem(51263)) 	then n = n + 1; end
	if(IsEquippedItem(50766) or IsEquippedItem(51179) or IsEquippedItem(51260)) 	then n = n + 1; end
	if(IsEquippedItem(50769) or IsEquippedItem(51177) or IsEquippedItem(51262)) 	then n = n + 1; end
	
	if(n >= 4) then
		privateScaling["4pcRaid10"] = 1;
		
		 -- no way to have 4pcRaid9 now
		privateScaling["4pcRaid9"] = 0;		
		return;
	else
		privateScaling["4pcRaid10"] = 0;
	end
	
	n = 0;
	
	-- Velen's/Zabra's Raiment 4-piece Bonus
	
	-- UnitFactionGroup's first return value is NOT localized
	if(UnitFactionGroup("player") == "Alliance") then
		if(IsEquippedItem(47914) or IsEquippedItem(47984) or IsEquippedItem(48035))		then n = 1; end
		if(IsEquippedItem(47981) or IsEquippedItem(47987) or IsEquippedItem(48029))		then n = n + 1; end
		if(IsEquippedItem(47936) or IsEquippedItem(47986) or IsEquippedItem(48031)) 	then n = n + 1; end
		if(IsEquippedItem(47982) or IsEquippedItem(47983) or IsEquippedItem(48037)) 	then n = n + 1; end
		if(IsEquippedItem(47980) or IsEquippedItem(47985) or IsEquippedItem(48033)) 	then n = n + 1; end
	else
		if(IsEquippedItem(48068) or IsEquippedItem(48065) or IsEquippedItem(48058)) 	then n = 1; end
		if(IsEquippedItem(48071) or IsEquippedItem(48062) or IsEquippedItem(48061))		then n = n + 1; end
		if(IsEquippedItem(48070) or IsEquippedItem(48063) or IsEquippedItem(48060)) 	then n = n + 1; end
		if(IsEquippedItem(48067) or IsEquippedItem(48066) or IsEquippedItem(48057)) 	then n = n + 1; end
		if(IsEquippedItem(48069) or IsEquippedItem(48064) or IsEquippedItem(48059)) 	then n = n + 1; end	
	end
	
	if(n >= 4) then
		privateScaling["4pcRaid9"] = 1;
	else
		privateScaling["4pcRaid9"] = 0;
	end
end

local function priest_OnLevelUp()
	priest_UpdatePlayerScaling();
end

local function priest_OnTalentUpdate()
	priest_ScanTalents();
	priest_UpdatePlayerScaling();
end

local function priest_OnEquipmentChangedDelayed()
	priest_ScanEquipment();	
	priest_UpdatePlayerScaling();
end

local function priest_OnEquipmentChanged()
	AM_Core:ScheduleUniqueTimer("priest_equip", priest_OnEquipmentChangedDelayed, 0.7);
end

local function priest_OnScalingEncode()
	return {UnitLevel("player"), privateScaling.base, privateScaling.sp, privateScaling.DA};
end

function OnScalingDecode.PRIEST(guid, in_guidScaling)	
	if(#in_guidScaling ~= 4) then return; end

	priest_ApplyScaling(guid, unpack(in_guidScaling));
end

function OnEnableClass.PRIEST()
	AM_Events.PLAYER_LEVEL_UP = priest_OnLevelUp;
	AM_Events.PLAYER_TALENT_UPDATE = priest_OnTalentUpdate;
	AM_Events.PLAYER_EQUIPMENT_CHANGED = priest_OnEquipmentChanged;	
	
	AM_Events.OnScalingEncode = priest_OnScalingEncode;
	
	priest_ScanTalents();
	priest_ScanEquipment();
		
	priest_UpdatePlayerScaling();
end



---------------------
-- Effects: Shaman --
---------------------

-- Public Scaling: { [AstralShift] }
-- We default to 0.3, because quite frankly nobody will use less points except while leveling
local shaman_defaultScaling = {0.3};


local function shaman_AstralShift_Create(sourceGUID, sourceName, destGUID, destName, spellId, destEffects)
	local sourceScaling, quality = Unit_Scaling(sourceGUID, shaman_defaultScaling, 0.7);
	
	return -1, quality, sourceScaling[1];
end

local function shaman_AstralShift_Hit(effectEntry, absorbedRemaining, overkill, spellSchool)
	local total = absorbedRemaining + overkill;

	return floor(total * effectEntry[7]), true;
end

local function shaman_OnTalentUpdate()
	-- Astral Shift
	local _, _, _, _, t = GetTalentInfo(1, 21);
	
	playerScaling[1] = t * 0.1;
	
	AM_Public.ScheduleScalingBroadcast();
end

function OnEnableClass.SHAMAN()
	AM_Events.PLAYER_TALENT_UPDATE = shaman_OnTalentUpdate;
		
	shaman_OnTalentUpdate();
end



----------------------
-- Effects: Warlock --
----------------------

-- TODO: base leveling increase
local warlock_Sacrifice_Spells = {
	[7812] = 305,
	[19438] = 510,
	[19440] = 770,
	[19441] = 1095,
	[19442] = 1470,
	[19443] = 1905,
	[27273] = 2855,
	[47985] = 6750,
	--[47986] = 8350,
	-- There is a new rank of Sacrifice at 79, so it scales by 15 to 80
	[47986] = 8365,
}

local warlock_ShadowWard_Spells = {
	[6229] = 290,
	[11739] = 470,
	[11740] = 675,
	[28610] = 875,
	[47890] = 2750,
	[47891] = 3300,
};

-- Public Scaling: { [DemonicBrutality] }
local warlock_defaultScaling = {1.0};


-- No downranking support here
local function warlock_Sacrifice_Create(sourceGUID, sourceName, destGUID, destName, spellId, destEffects)
	-- Note that the source is the voidwalker, so dest is the warlock!
	local sourceScaling, quality = Unit_Scaling(destGUID, warlock_defaultScaling, 0.4);

	return floor(warlock_Sacrifice_Spells[spellId] * sourceScaling[1]), quality;
end

local function warlock_ShadowWard_Hit(effectEntry, absorbedRemaining, overkill, spellSchool)
	if(spellSchool ~= SCHOOL_MASK_SHADOW) then
		return 0, true;
	end
	
	return generic_Hit(effectEntry, absorbedRemaining, overkill, spellSchool);
end

local function warlock_OnTalentUpdate()
	-- Demonic Brutality
	local _, _, _, _, t = GetTalentInfo(2, 6);
	
	playerScaling[1] = 1 + (t * 0.1);
	
	AM_Public.ScheduleScalingBroadcast();	
end

function OnEnableClass.WARLOCK()
	AM_Events.PLAYER_TALENT_UPDATE = warlock_OnTalentUpdate;
	
	warlock_OnTalentUpdate();
end



--------------------
-- Effects: Items --
--------------------

local function items_EssenceOfGossamer_Hit(effectEntry)
	if(effectEntry[3] < 140) then
		return effectEntry[3], false;
	else
		return 140, true;
	end
end

local function items_ArgussianCompass_Hit(effectEntry)
	if(effectEntry[3] < 68) then
		return effectEntry[3], false;
	else
		return 68, true;
	end
end

local function items_Valanyr_OnAuraApplied(sourceGUID, sourceName, destGUID, destName, spellId)
	AM_Core.AddCombatTrigger(sourceGUID, "OnHeal", items_Valanyr_OnHeal);
end

local function items_Valanyr_OnAuraRemoved(sourceGUID, sourceName, destGUID, destName, spellId)
	AM_Core.RemoveCombatTrigger(sourceGUID, "OnHeal", items_Valanyr_OnHeal);
end

local function items_Valanyr_Create(sourceGUID, sourceName, destGUID, destName, spellId, destEffects)
	local existing = 0;
	
	if(destEffects and destEffects[spellId]) then
		existing = destEffects[spellId][3];
	end

	local charge = PopCharge(destGUID, spellId);
	
	if(charge == 0) then
		return existing, 0.0;
	end
		
	-- According to the blue post explaining the Val'anyr effect on introduction, all units are
	-- contributing to the same bubble with a cap of 20.000
	return min(20000, existing + charge), 1.0;
end

local function items_Valanyr_OnHeal(sourceGUID, sourceName, destGUID, destName, spellId, amount)
	PushCharge(destGUID, 64413, floor(amount * 0.15), 5.0);
end

local function items_Stoicism_Create(sourceGUID, sourceName, destGUID, destName, spellId, destEffects)
	local maxHealth = UnitCall_bySearch(UnitHealthMax, destGUID, destName);
	
	if(maxHealth == 0) then
		return 0, 0.0;
	end
	
	return floor(maxHealth * 0.2), 1.0;	
end



-----------------
-- Data Tables --
-----------------

local mage_FireWard_Entry = {2.0, 30, generic_SpellScalingByTable_Create, mage_FireWard_Hit, mage_Absorb_Spells, 0.8068};
local mage_FrostWard_Entry = {2.0, 30, generic_SpellScalingByTable_Create, mage_FrostWard_Hit, mage_Absorb_Spells, 0.8068};
local mage_IceBarrier_Entry = {1.0, 60, mage_IceBarrier_Create, generic_Hit};
local mage_ManaShield_Entry = {1.0, 60, generic_SpellScalingByTable_Create, generic_Hit, mage_Absorb_Spells, 0.8053};

local priest_PWS_Entry = {1.0, 30, priest_PowerWordShield_Create, generic_Hit};	

local warlock_Sacrifice_Entry = {1.0, 30, generic_ConstantByTable_Create, generic_Hit, warlock_Sacrifice_Spells};
local warlock_ShadowWard_Entry = {2.0, 30, generic_SpellScalingByTable_Create, warlock_ShadowWard_Hit, warlock_ShadowWard_Spells, 0.8068};


-- INCOMPLETE
-- This table gets a lot smaller in Cataclysm
AM_Core.Effects = {
	-- Unknown Effect
	-- This is used when a known effect is applied, but it is impossible to properly account for it,
	-- for example if an AREA effect is applied with an unknown trigger
	[0] = {1.0, 0, function() return 0, 0.0; end, nil};
	
	-- DEATH KNIGHT	
	-- Anti-Magic Shell
	[48707] = {3.0, 5, deathknight_AntiMagicShell_Create, deathknight_AntiMagicShell_Hit},
	-- Anti-Magic Zone
	[50461] = {-3.0, 10, deathknight_AntiMagicZone_Create, deathknight_AntiMagicZone_Hit},
		
	-- DRUID
	-- Savage Defense
	[62606] = {1.1, 10, druid_SavageDefense_Create, druid_SavageDefense_Hit},
	
	-- MAGE
	-- Fire Ward
	[543] = mage_FireWard_Entry,
	[8457] = mage_FireWard_Entry,
	[8458] = mage_FireWard_Entry,
	[10223] = mage_FireWard_Entry,
	[10225] = mage_FireWard_Entry,
	[27218] = mage_FireWard_Entry,
	[43010] = mage_FireWard_Entry,
	-- Frost Ward
	[6143] = mage_FrostWard_Entry,
	[8461] = mage_FrostWard_Entry,
	[8462] = mage_FrostWard_Entry,
	[10177] = mage_FrostWard_Entry,
	[28609] = mage_FrostWard_Entry,
	[32796] = mage_FrostWard_Entry,
	[43012] = mage_FrostWard_Entry,
	-- Ice Barrier
	[11426] = mage_IceBarrier_Entry,
	[13031] = mage_IceBarrier_Entry,
	[13032] = mage_IceBarrier_Entry,
	[13033] = mage_IceBarrier_Entry,
	[27134] = mage_IceBarrier_Entry,
	[33405] = mage_IceBarrier_Entry,
	[43038] = mage_IceBarrier_Entry,
	[43039] = mage_IceBarrier_Entry,			
	-- Mana Shield
	[1463] = mage_ManaShield_Entry,
	[8494] = mage_ManaShield_Entry,
	[8495] = mage_ManaShield_Entry,
	[10191] = mage_ManaShield_Entry,
	[10192] = mage_ManaShield_Entry,
	[10193] = mage_ManaShield_Entry,
	[27131] = mage_ManaShield_Entry,
	[43019] = mage_ManaShield_Entry,
	[43020] = mage_ManaShield_Entry,		
	
	-- PALADIN
	-- Sacred Shield
	[58597] = {1.0, 6, paladin_SacredShield_Create, generic_Hit},
	-- Ardent Defender
	
	-- PRIEST	
	-- Power Word: Shield
	[17] 	= priest_PWS_Entry,
	[592]	= priest_PWS_Entry,
	[600] 	= priest_PWS_Entry,
	[3747] 	= priest_PWS_Entry,
	[6065] 	= priest_PWS_Entry,
	[10898] = priest_PWS_Entry,
	[10899] = priest_PWS_Entry,
	[10900] = priest_PWS_Entry,
	[10901] = priest_PWS_Entry,
	[25217] = priest_PWS_Entry,
	[25218] = priest_PWS_Entry,
	[48065] = priest_PWS_Entry,
	[48066] = priest_PWS_Entry,
	-- Divine Aegis
	[47753] = {1.0, 12, priest_DivineAegis_Create, generic_Hit},
	-- Power Word: Barrier
	[81781] = {-1.0, 25, priest_PowerWordBarrier_Create, priest_PowerWordBarrier_Hit},
	
	-- ROGUE
	-- Cheat Death
	--   No clue how it works technically (does it still uses an absorb?)
	--   While there is no absorb value to watch for, it would screw our
	--   numbers on other effects.
	
	-- SHAMAN
	-- Astral Shift
	[52179] = {2.5, nil, shaman_AstralShift_Create, shaman_AstralShift_Hit},
	-- Glyph of Stoneclaw Totem
	--   This absorb effect cannot be supported without heavy exceptional
	--   handling, because it is neither applied by SPELL_AURA_APPLIED or
	--   nor removed by SPELL_AURA_REMOVED - but only an UNIT_AURA event is
	--   fired on gain/loss. The gain can actually be detected by the cast 
	--   of Stoneclaw Totem (and knowledge about the glyphs), but not if it
	--   breaks prematurely, making looping through all buffs needed everytime
	--	 it could be active and UNIT_AURA is fired. At least the amount would
	--	 be constant for every rank.
	--   The normal totem absorb effect could be tracked with more ease, but still
	--   there is no proper removal event, so it would rely on zombified absorb
	--   effects until the totem drops. Maybe later. (What about totem GUIDs?)
	-- [55277] = {1.0, shaman_GlyphStoneclawTotem_Create, generic_Hit},
	
	-- WARLOCK
	-- Sacrifice
	[7812] = warlock_Sacrifice_Entry,
	[19438] = warlock_Sacrifice_Entry,
	[19440] = warlock_Sacrifice_Entry,
	[19441] = warlock_Sacrifice_Entry,
	[19442] = warlock_Sacrifice_Entry,
	[19443] = warlock_Sacrifice_Entry,
	[27273] = warlock_Sacrifice_Entry,
	[47985] = warlock_Sacrifice_Entry,
	[47986] = warlock_Sacrifice_Entry,
	-- Shadow Ward
	[6229] = warlock_ShadowWard_Entry,
	[11739] = warlock_ShadowWard_Entry,
	[11740] = warlock_ShadowWard_Entry,
	[28610] = warlock_ShadowWard_Entry,
	[47890] = warlock_ShadowWard_Entry,
	[47891] = warlock_ShadowWard_Entry,

	-- ITEMS	
	-- Val'anyr (spellId of the created absorb effect)
	[64413] = {1.0, 8, items_Valanyr_Create, generic_Hit},
	-- Essence of Gossamer
	[60218] = {5.0, 10, function() return 4000, 1.0; end, items_EssenceOfGossamer_Hit},
	-- Corroded Skeleton Key
	[71586] = {1.0, 10, function() return 6400, 1.0; end, generic_Hit},
	-- Phaseshift Bulwark
	[36481] = {1.0, 4, function() return 100000, 1.0; end, generic_Hit},
	-- Darkmoon Card: Illusion
	[57350] = {1.0, 6, function() return 1500, 1.0; end, generic_Hit},
	-- Mark of the Dragon Lord
	[17252] = {1.0, 1800, function() return 500, 1.0; end, generic_Hit},
	-- The Burrower's Shell
	[29506] = {1.0, 20, function() return 900, 1.0; end, generic_Hit},
	-- Arena Grand Master (mean value of 1000)
	[23506] = {1.0, 20, function() return 1000, 0.5; end, generic_Hit},
	-- Argussian Compass
	[39228] = {5.0, 20, function() return 1150, 1.0; end, items_ArgussianCompass_Hit},
	-- Runed Fungalcap
	[31771] = {1.0, 20, function() return 440, 1.0; end, generic_Hit},
	-- Truesilver Champion
	[9800] = {1.0, 60, function() return 175, 1.0; end, generic_Hit},
	-- Gnomish Harm Prevention Belt
	[13234] = {1.0, 600, function() return 500, 1.0; end, generic_Hit},
	-- Nigh Invulnerability Belt
	[30458] = {1.0, 8, function() return 4000, 1.0; end, generic_Hit},
	-- Divine Protection (Priest Dungeon Set 1/2 4pc bonus)
	[27779] = {1.0, 30, function() return 350, 1.0; end, generic_Hit},
	-- Armor of Faith (Priest Raid Set 3 4pc bonus)
	[28810] = {1.0, 30, function() return 500, 1.0; end, generic_Hit},
	-- Lesser Ward of Shielding
	[29674] = {1.0, nil, function() return 1000, 1.0; end, generic_Hit},
	-- Greater Ward of Shielding
	[29719] = {1.0, nil, function() return 4000, 1.0; end, generic_Hit},
	-- Stoicism (Warrior Raid Set 10 4pc bonus)
	[70845] = {1.0, 10, items_Stoicism_Create, generic_Hit},
	
	
	-- Scarab Brooch
	--   This trinket is a bit more problematic, because it creates non-stacking
	--   shields, having always the strongest up. The question is now, what happens
	--   if a previously stronger shield gets hit and reduced below a might-be-created
	--   shield coming from a following heal? It also seems like only a certain
	--   set of healing spells attribute to bubbles
};


AM_Core.AreaTriggers = {
	-- Anti-Magic Zone
	[51052] = 50461,
	
	-- Power Word: Barrier
	[62618] = 81781,
};


AM_Core.CombatTriggers = {	
	OnAuraApplied = {
		[64411] = items_Valanyr_OnAuraApplied,
	},
	
	OnAuraRemoved = {
		[64411] = items_Valanyr_OnAuraRemoved,
	},
	
	OnHeal = {
	},
	
	OnHealCrit = {
	}
};



----------------
-- Initialize --
----------------

if(not AM_Core.Available) then
	AM_Core.RegisterEvent("PLAYER_ENTERING_WORLD");
else
	AM_Core.Enable();
end



------------------------
-- Callback Reference --
------------------------

-- EffectApplied
-- (sourceGUID, sourceName, destGUID, destName, spellId, value, quality, duration)
-- The effect-individual messages get sent on visible and non-visible effects

-- EffectUpdated
-- (guid, spellId, value, [duration, only if refreshed])

-- EffectRemoved
-- (guid, spellId)

-- Whenever the unit that radiates an AREA effect is created (visible/non-visible)
-- Note that the actual effect on the unit that absorbs damage casues an
-- EffectApplied/EffectRemoved message, but not EffectUpdated (instead AreaUpdated)
-- The rationale behind this is performance, since we cannot update every unit afflicted
-- by the area effect on every hit. Therefore, we have the shared entry in the activeEffects
-- table of each unit, and will handle it the same way when exporting - separately from each
-- others.

-- AreaCreated
-- (sourceGUID, sourceName, triggerGUID, spellId, value, quality)

-- AreaUpdated
-- (triggerGUID, value)

-- AreaCleared
-- (triggerGUID)

-- UnitUpdated
-- (guid, value, quality)
-- Only for VISIBLE changes on the total amount

-- UnitCleared
-- (guid)
-- Everytime a unit gets cleared from all absorb effects (quality reset)
-- including non-visible effects
