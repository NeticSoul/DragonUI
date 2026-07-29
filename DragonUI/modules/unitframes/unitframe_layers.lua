local addon = select(2, ...);
local _G = getfenv(0);

-- ============================================================================
-- UNITFRAME LAYERS MODULE FOR DRAGONUI
-- ============================================================================
-- Adds heal prediction bars, absorb shields, animated health loss, and mana
-- cost prediction to all unit frames. Ported from UnitFrameLayers addon.
-- ============================================================================

-- Module state tracking
local UnitFrameLayersModule = {
	initialized = false,
	applied = false,
	originalStates = {},
	registeredEvents = {},
	hooks = {},
	stateDrivers = {},
	frames = {},           -- Tracks frames we've initialized
}

-- Register with ModuleRegistry
if addon.RegisterModule then
	addon:RegisterModule("unitframe_layers", UnitFrameLayersModule,
		(addon.L and addon.L["Unit Frame Layers"]) or "Unit Frame Layers",
		(addon.L and addon.L["Heal prediction, absorb shields, and animated health loss on unit frames"]) or "Heal prediction, absorb shields, and animated health loss on unit frames")
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local function GetModuleConfig()
	return addon:GetModuleConfig("unitframe_layers")
end

local function IsModuleEnabled()
	return addon:IsModuleEnabled("unitframe_layers")
end

local function IsMissingHealthEnabled()
	local cfg = GetModuleConfig();
	return cfg and cfg.missing_health == true
end

-- Missing health should only apply to friendly non-pet units.
local function ShouldShowMissingHealthForUnit(unit)
	if not unit or not UnitExists(unit) then
		return false
	end

	if unit == "pet" or unit:match("^partypet%d+$") or unit:match("^raidpet%d+$") then
		return false
	end

	if UnitCanAttack("player", unit) then
		return false
	end

	return true
end

-- Export so text_system can hide health text when missing-health mode is active.
addon.UFL_ShouldShowMissingHealthForUnit = ShouldShowMissingHealthForUnit;

-- ============================================================================
-- LIBRARY REFERENCES
-- ============================================================================

local LibAbsorb, HealComm;

local function EnsureLibs()
	if not LibAbsorb then
		LibAbsorb = LibStub and LibStub:GetLibrary("AbsorbsMonitor-1.0", true);
	end
	if not HealComm then
		HealComm = LibStub and LibStub:GetLibrary("LibHealComm-4.0", true);
	end
end

-- ============================================================================
-- UNIT DATA HELPERS
-- ============================================================================

local function UFL_UnitGetIncomingHeals(unit, healer)
	if not (unit and HealComm) then return end
	if healer then
		return HealComm:GetCasterHealAmount(UnitGUID(healer), HealComm.CASTED_HEALS, GetTime() + 5);
	else
		return HealComm:GetHealAmount(UnitGUID(unit), HealComm.ALL_HEALS, GetTime() + 5);
	end
end

local function UFL_UnitGetTotalAbsorbs(unit)
	if not (unit and LibAbsorb) then return end
	return LibAbsorb.Unit_Total(UnitGUID(unit));
end

-- Export for AnimatedHealthLossMixin
addon.UFL_UnitGetTotalAbsorbs = UFL_UnitGetTotalAbsorbs;

-- ============================================================================
-- POWER BAR COLOR SETUP
-- ============================================================================

local FULL_POWER_ANIM_POWER_TYPES = {
	["RAGE"] = true,
	["ENERGY"] = true,
}

-- ============================================================================
-- CORE BAR UPDATE FUNCTIONS
-- ============================================================================

-- DragonUI party frames draw their own visible bars over the (hidden) native ones.
-- Anchor/size overlays on the visible bar; other frames have no DragonUI_* bar so this
-- falls back to the native bar (a no-op for them). Data (unit/OnUpdate) stays on native.
local function UFL_VisualHealthBar(frame)
	return frame.DragonUI_HealthBar or frame.healthbar;
end
local function UFL_VisualManaBar(frame)
	return frame.DragonUI_ManaBar or frame.manabar;
end

local function UnitFrameUtil_UpdateFillBarBase(frame, realbar, previousTexture, bar, amount, barOffsetXPercent)
	if ( amount == 0 ) then
		bar:Hide();
		if ( bar.overlay ) then
			bar.overlay:Hide();
		end
		return previousTexture;
	end
	local barOffsetX = 0;
	if ( barOffsetXPercent ) then
		local realbarSizeX = realbar:GetWidth();
		barOffsetX = realbarSizeX * barOffsetXPercent;
	end
	bar:SetPoint("TOPLEFT", previousTexture, "TOPRIGHT", barOffsetX, 0);
	bar:SetPoint("BOTTOMLEFT", previousTexture, "BOTTOMRIGHT", barOffsetX, 0);
	local totalWidth, totalHeight = realbar:GetSize();
	local _, totalMax = realbar:GetMinMaxValues();
	if ( not totalMax or totalMax <= 0 ) then
		bar:Hide();
		if ( bar.overlay ) then
			bar.overlay:Hide();
		end
		return previousTexture;
	end
	local barSize = (amount / totalMax) * totalWidth;
	bar:SetWidth(barSize);
	bar:Show();
	if ( bar.overlay ) then
		local tileSize = bar.overlay.tileSize or 1;
		if ( tileSize <= 0 ) then
			tileSize = 1;
		end
		local texRight = barSize / tileSize;
		local texBottom = totalHeight / tileSize;
		if ( texRight < 0 ) then texRight = 0 end
		if ( texRight > 1 ) then texRight = 1 end
		if ( texBottom < 0 ) then texBottom = 0 end
		if ( texBottom > 1 ) then texBottom = 1 end
		bar.overlay:SetTexCoord(0, texRight, 0, texBottom);
		bar.overlay:Show();
	end
	return bar;
end

local function UnitFrameUtil_UpdateFillBar(frame, previousTexture, bar, amount, barOffsetXPercent)
	return UnitFrameUtil_UpdateFillBarBase(frame, UFL_VisualHealthBar(frame), previousTexture, bar, amount, barOffsetXPercent);
end

local function UnitFrameUtil_UpdateManaFillBar(frame, previousTexture, bar, amount, barOffsetXPercent)
	return UnitFrameUtil_UpdateFillBarBase(frame, UFL_VisualManaBar(frame), previousTexture, bar, amount, barOffsetXPercent);
end

-- ============================================================================
-- HEAL PREDICTION BAR UPDATE
-- ============================================================================

local MAX_INCOMING_HEAL_OVERFLOW = 1.0;

local function UnitFrameHealPredictionBars_Update(frame)
	if ( not frame.myHealPredictionBar ) then return end
	local _, maxHealth = frame.healthbar:GetMinMaxValues();
	local health = frame.healthbar:GetValue();
	if ( maxHealth <= 0 ) then return end

	-- Missing health deficit text
	-- Coordinate with the text system to avoid overlap:
	--   "both" mode: LEFT=percent, RIGHT=numeric are used → slot missingHealthText into CENTER (always hidden in "both")
	--   other modes: CENTER is used → slot into RIGHT (always free in non-both modes)
	if frame.missingHealthText then
		local missing = maxHealth - health;
		if IsMissingHealthEnabled() and ShouldShowMissingHealthForUnit(frame.unit) and missing > 0 then
			-- Determine text format for this frame from the text system config
			local frameTypeKey = frame.unit;
			if frameTypeKey and frameTypeKey:match("^party%d") then frameTypeKey = "party"; end
			local textCfg = addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe[frameTypeKey];
			local textFormat = textCfg and textCfg.textFormat or "both";

			-- Reanchor only when the format changes (avoid per-frame ClearAllPoints churn)
			local uflData = frame.__DragonUI_UFL;
			if not uflData or uflData.missingHealthFormat ~= textFormat then
				frame.missingHealthText:ClearAllPoints();
				if textFormat == "both" then
					-- CENTER is free in "both" mode (text system uses left+right, not center)
					frame.missingHealthText:SetPoint("CENTER", UFL_VisualHealthBar(frame), "CENTER", 0, 0);
					frame.missingHealthText:SetJustifyH("CENTER");
				else
					-- RIGHT is free in all non-both modes (text system uses center only)
					frame.missingHealthText:SetPoint("RIGHT", UFL_VisualHealthBar(frame), "RIGHT", -4, 0);
					frame.missingHealthText:SetJustifyH("RIGHT");
				end
				if uflData then uflData.missingHealthFormat = textFormat; end
			end

			local abbrev = addon.TextSystem and addon.TextSystem.AbbreviateLargeNumbers;
			local missingStr = abbrev and abbrev(missing) or tostring(missing);
			frame.missingHealthText:SetText("-" .. missingStr);
			frame.missingHealthText:Show();
		else
			frame.missingHealthText:Hide();
		end
	end

	local myIncomingHeal = UFL_UnitGetIncomingHeals(frame.unit, "player") or 0;
	local allIncomingHeal = UFL_UnitGetIncomingHeals(frame.unit) or 0;
	local totalAbsorb = UFL_UnitGetTotalAbsorbs(frame.unit) or 0;
	local myCurrentHealAbsorb = 0;

	if ( frame.healAbsorbBar ) then
		myCurrentHealAbsorb = 0; -- No heal absorb in WotLK
		if ( health < myCurrentHealAbsorb ) then
			frame.overHealAbsorbGlow:Show();
			myCurrentHealAbsorb = health;
		else
			frame.overHealAbsorbGlow:Hide();
		end
	end

	if ( health - myCurrentHealAbsorb + allIncomingHeal > maxHealth * MAX_INCOMING_HEAL_OVERFLOW ) then
		allIncomingHeal = maxHealth * MAX_INCOMING_HEAL_OVERFLOW - health + myCurrentHealAbsorb;
	end

	local otherIncomingHeal = 0;
	if ( allIncomingHeal >= myIncomingHeal ) then
		otherIncomingHeal = allIncomingHeal - myIncomingHeal;
	else
		myIncomingHeal = allIncomingHeal;
	end

	local overAbsorb = false;
	if ( health - myCurrentHealAbsorb + allIncomingHeal + totalAbsorb >= maxHealth or health + totalAbsorb >= maxHealth ) then
		if ( totalAbsorb > 0 ) then
			overAbsorb = true;
		end
		if ( allIncomingHeal > myCurrentHealAbsorb ) then
			totalAbsorb = max(0, maxHealth - (health - myCurrentHealAbsorb + allIncomingHeal));
		else
			totalAbsorb = max(0, maxHealth - health);
		end
	end

	if ( overAbsorb ) then
		frame.overAbsorbGlow:Show();
	else
		frame.overAbsorbGlow:Hide();
	end

	local healthTexture = UFL_VisualHealthBar(frame):GetStatusBarTexture();
	local myCurrentHealAbsorbPercent = 0;
	local healAbsorbTexture = nil;

	if ( frame.healAbsorbBar ) then
		myCurrentHealAbsorbPercent = myCurrentHealAbsorb / maxHealth;
		if ( myCurrentHealAbsorb > allIncomingHeal ) then
			local shownHealAbsorb = myCurrentHealAbsorb - allIncomingHeal;
			healAbsorbTexture = UnitFrameUtil_UpdateFillBar(frame, healthTexture, frame.healAbsorbBar, shownHealAbsorb, -(shownHealAbsorb / maxHealth));
			if ( allIncomingHeal > 0 ) then
				frame.healAbsorbBarLeftShadow:Hide();
			else
				frame.healAbsorbBarLeftShadow:SetPoint("TOPLEFT", healAbsorbTexture, "TOPLEFT", 0, 0);
				frame.healAbsorbBarLeftShadow:SetPoint("BOTTOMLEFT", healAbsorbTexture, "BOTTOMLEFT", 0, 0);
				frame.healAbsorbBarLeftShadow:Show();
			end
			if ( totalAbsorb > 0 ) then
				frame.healAbsorbBarRightShadow:SetPoint("TOPLEFT", healAbsorbTexture, "TOPRIGHT", -8, 0);
				frame.healAbsorbBarRightShadow:SetPoint("BOTTOMLEFT", healAbsorbTexture, "BOTTOMRIGHT", -8, 0);
				frame.healAbsorbBarRightShadow:Show();
			else
				frame.healAbsorbBarRightShadow:Hide();
			end
		else
			frame.healAbsorbBar:Hide();
			frame.healAbsorbBarLeftShadow:Hide();
			frame.healAbsorbBarRightShadow:Hide();
		end
	end

	local incomingHealTexture = UnitFrameUtil_UpdateFillBar(frame, healthTexture, frame.myHealPredictionBar, myIncomingHeal, -myCurrentHealAbsorbPercent);
	if (myIncomingHeal > 0) then
		incomingHealTexture = UnitFrameUtil_UpdateFillBar(frame, incomingHealTexture, frame.otherHealPredictionBar, otherIncomingHeal);
	else
		incomingHealTexture = UnitFrameUtil_UpdateFillBar(frame, healthTexture, frame.otherHealPredictionBar, otherIncomingHeal, -myCurrentHealAbsorbPercent);
	end

	local appendTexture = healAbsorbTexture or incomingHealTexture;
	UnitFrameUtil_UpdateFillBar(frame, appendTexture, frame.totalAbsorbBar, totalAbsorb);
end

local function UnitFrameHealPredictionBars_UpdateMax(self)
	if ( not self.myHealPredictionBar ) then return end
	UnitFrameHealPredictionBars_Update(self);
end

-- ============================================================================
-- MANA COST PREDICTION
-- ============================================================================

local function UnitFrameManaCostPredictionBars_Update(frame, isStarting, startTime, endTime, name)
	if (not frame.manabar or not frame.myManaCostPredictionBar) then return end
	local cost = 0;
	if (not isStarting or startTime == endTime) then
		local currentSpell = UnitCastingInfo(frame.unit);
		if (currentSpell and frame.predictedPowerCost) then
			cost = frame.predictedPowerCost;
		else
			frame.predictedPowerCost = nil;
		end
	else
		local costTable;
		if frame.unit == "player" then
			costTable = addon.UFL_GetSpellPowerCost and addon.UFL_GetSpellPowerCost(name) or {};
		else
			costTable = addon.UFL_GetSpellPowerCostForUnit and addon.UFL_GetSpellPowerCostForUnit(name, frame.unit) or {};
		end
		for _, costInfo in pairs(costTable) do
			if (costInfo.type == frame.manabar.powerType) then
				cost = costInfo.cost;
				break;
			end
		end
		frame.predictedPowerCost = cost;
	end
	local manaBarTexture = UFL_VisualManaBar(frame):GetStatusBarTexture();
	if _G.UnitFrameManaBar_Update then
		_G.UnitFrameManaBar_Update(frame.manabar, frame.unit);
	end
	UnitFrameUtil_UpdateManaFillBar(frame, manaBarTexture, frame.myManaCostPredictionBar, cost);
end

-- NOTE: UnitFrameHealthBar_OnUpdate and UnitFrameManaBar_OnUpdate are now
-- overridden as global functions in ApplyUnitFrameLayersSystem() rather than
-- being local functions, so they automatically apply to all Blizzard bars.

-- ============================================================================
-- LIBRARY CALLBACK HANDLER
-- ============================================================================

local function LibEventCallback(self, event, ...)
	local arg1, arg2, arg3, arg4, arg5 = ...;
	if ( not self.unit ) then return end

	local unitGUID = UnitGUID(self.unit);
	if not unitGUID then return end

	-- HealComm heal events: (casterGUID, spellID, bitType, endTime, ...targets) → arg5=first target
	-- Must be checked BEFORE arg1 because for self-casts arg1 (caster) == arg5 (target) == unitGUID,
	-- and arg1 matching would incorrectly route to the AbsorbsMonitor branch.
	if ( event == "HealComm_HealStarted" or event == "HealComm_HealUpdated"
		or event == "HealComm_HealDelayed" or event == "HealComm_HealStopped" ) then
		if ( arg5 == unitGUID ) then
			UnitFrameHealPredictionBars_Update(self);
		end

	-- AbsorbsMonitor events: EffectApplied(srcGUID, srcName, dstGUID, ...) → arg3=dstGUID
	elseif ( event == "EffectApplied" and arg3 == unitGUID ) then
		UnitFrameHealPredictionBars_Update(self);

	-- Remaining events where arg1=guid: AbsorbsMonitor + HealComm_ModifierChanged/GUIDDisappeared
	elseif ( arg1 == unitGUID ) then
		UnitFrameHealPredictionBars_Update(self);
	end
end

local function UnitFrame_RegisterCallback(self)
	-- Register each library independently so one failing doesn't block the other
	if LibAbsorb and LibAbsorb.RegisterCallback then
		LibAbsorb.RegisterCallback(self, "EffectApplied", LibEventCallback, self);
		LibAbsorb.RegisterCallback(self, "EffectUpdated", LibEventCallback, self);
		LibAbsorb.RegisterCallback(self, "EffectRemoved", LibEventCallback, self);
		LibAbsorb.RegisterCallback(self, "UnitUpdated", LibEventCallback, self);
		LibAbsorb.RegisterCallback(self, "UnitCleared", LibEventCallback, self);
		LibAbsorb.RegisterCallback(self, "AreaCreated", LibEventCallback, self);
		LibAbsorb.RegisterCallback(self, "AreaCleared", LibEventCallback, self);
	end

	if HealComm and HealComm.RegisterCallback then
		HealComm.RegisterCallback(self, "HealComm_HealStarted", LibEventCallback, self);
		HealComm.RegisterCallback(self, "HealComm_HealUpdated", LibEventCallback, self);
		HealComm.RegisterCallback(self, "HealComm_HealDelayed", LibEventCallback, self);
		HealComm.RegisterCallback(self, "HealComm_HealStopped", LibEventCallback, self);
		HealComm.RegisterCallback(self, "HealComm_ModifierChanged", LibEventCallback, self);
		HealComm.RegisterCallback(self, "HealComm_GUIDDisappeared", LibEventCallback, self);
	end
end

local function UnitFrame_UnregisterCallback(self)
	if LibAbsorb and LibAbsorb.UnregisterCallback then
		pcall(LibAbsorb.UnregisterCallback, self, "EffectApplied");
		pcall(LibAbsorb.UnregisterCallback, self, "EffectUpdated");
		pcall(LibAbsorb.UnregisterCallback, self, "EffectRemoved");
		pcall(LibAbsorb.UnregisterCallback, self, "UnitUpdated");
		pcall(LibAbsorb.UnregisterCallback, self, "UnitCleared");
		pcall(LibAbsorb.UnregisterCallback, self, "AreaCreated");
		pcall(LibAbsorb.UnregisterCallback, self, "AreaCleared");
	end
	if HealComm and HealComm.UnregisterCallback then
		pcall(HealComm.UnregisterCallback, self, "HealComm_HealStarted");
		pcall(HealComm.UnregisterCallback, self, "HealComm_HealUpdated");
		pcall(HealComm.UnregisterCallback, self, "HealComm_HealDelayed");
		pcall(HealComm.UnregisterCallback, self, "HealComm_HealStopped");
		pcall(HealComm.UnregisterCallback, self, "HealComm_ModifierChanged");
		pcall(HealComm.UnregisterCallback, self, "HealComm_GUIDDisappeared");
	end
end

-- ============================================================================
-- FRAME INITIALIZATION
-- ============================================================================

local function UnitFrameLayer_Initialize(self, myHealPredictionBar, otherHealPredictionBar, totalAbsorbBar,
	totalAbsorbBarOverlay, overAbsorbGlow, overHealAbsorbGlow, healAbsorbBar,
	healAbsorbBarLeftShadow, healAbsorbBarRightShadow, myManaCostPredictionBar)
	if not (self and self.healthbar and myHealPredictionBar and otherHealPredictionBar and totalAbsorbBar
		and totalAbsorbBarOverlay and overAbsorbGlow and overHealAbsorbGlow and healAbsorbBar
		and healAbsorbBarLeftShadow and healAbsorbBarRightShadow and myManaCostPredictionBar) then
		return
	end

	self.myHealPredictionBar = myHealPredictionBar;
	self.otherHealPredictionBar = otherHealPredictionBar;
	self.totalAbsorbBar = totalAbsorbBar;
	self.totalAbsorbBarOverlay = totalAbsorbBarOverlay;
	self.overAbsorbGlow = overAbsorbGlow;
	self.overHealAbsorbGlow = overHealAbsorbGlow;
	self.healAbsorbBar = healAbsorbBar;
	self.healAbsorbBarLeftShadow = healAbsorbBarLeftShadow;
	self.healAbsorbBarRightShadow = healAbsorbBarRightShadow;
	self.myManaCostPredictionBar = myManaCostPredictionBar;

	-- Mana cost prediction for player and target (best-effort for target).
	if ( self.unit == "player" or self.unit == "target" ) then
		self.myManaCostPredictionBar:ClearAllPoints();
		self:RegisterEvent("UNIT_SPELLCAST_START");
		self:RegisterEvent("UNIT_SPELLCAST_STOP");
		self:RegisterEvent("UNIT_SPELLCAST_FAILED");
		self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
	else
		self.myManaCostPredictionBar:Hide();
	end

	self.myHealPredictionBar:ClearAllPoints();
	self.otherHealPredictionBar:ClearAllPoints();
	self.totalAbsorbBar:ClearAllPoints();

	self.totalAbsorbBar.overlay = self.totalAbsorbBarOverlay;
	self.totalAbsorbBarOverlay:SetAllPoints(self.totalAbsorbBar);
	self.totalAbsorbBarOverlay.tileSize = 32;
	local isSmallCompanionFrame = (self == _G.TargetFrameToT or self == _G.FocusFrameToT);
	local absorbFrame = self.totalAbsorbBar and self.totalAbsorbBar:GetParent();
	local overAbsorbFrame = self.overAbsorbGlow and self.overAbsorbGlow:GetParent();
	if isSmallCompanionFrame then
		if absorbFrame and self.healthbar then
			absorbFrame:SetFrameStrata(self.healthbar:GetFrameStrata());
			absorbFrame:SetFrameLevel(self.healthbar:GetFrameLevel() + 1);
		end
		if overAbsorbFrame and self.healthbar then
			overAbsorbFrame:SetFrameStrata(self.healthbar:GetFrameStrata());
			overAbsorbFrame:SetFrameLevel(self.healthbar:GetFrameLevel() + 4);
		end
		self.totalAbsorbBar:SetDrawLayer("ARTWORK", 0);
		self.totalAbsorbBarOverlay:SetDrawLayer("OVERLAY", 0);
		self.overAbsorbGlow:SetDrawLayer("OVERLAY", 2);
	else
		self.totalAbsorbBar:SetDrawLayer("ARTWORK", 0);
		self.totalAbsorbBarOverlay:SetDrawLayer("OVERLAY", 1);
	end

	self.overAbsorbGlow:ClearAllPoints();
	self.overAbsorbGlow:SetWidth(16);
	self.overAbsorbGlow:SetPoint("TOPLEFT", UFL_VisualHealthBar(self), "TOPRIGHT", -7, 0);
	self.overAbsorbGlow:SetPoint("BOTTOMLEFT", UFL_VisualHealthBar(self), "BOTTOMRIGHT", -7, 0);

	self.healAbsorbBar:ClearAllPoints();
	self.healAbsorbBar:SetTexture("Interface\\RaidFrame\\Absorb-Fill", true, true);

	self.overHealAbsorbGlow:ClearAllPoints();
	self.overHealAbsorbGlow:SetPoint("BOTTOMRIGHT", UFL_VisualHealthBar(self), "BOTTOMLEFT", 7, 0);
	self.overHealAbsorbGlow:SetPoint("TOPRIGHT", UFL_VisualHealthBar(self), "TOPLEFT", 7, 0);

	self.healAbsorbBarLeftShadow:ClearAllPoints();
	self.healAbsorbBarRightShadow:ClearAllPoints();

	self:RegisterEvent("UNIT_MAXHEALTH");
	addon.RegisterUnitEventSafe(self, "UNIT_AURA", self.unit);
	EnsureLibs();
	UnitFrame_RegisterCallback(self);

	-- Player-specific features
	local moduleConfig = GetModuleConfig();
	if ( self.unit == "player" ) then
		-- Animated health loss
		if moduleConfig and moduleConfig.animated_loss ~= false then
			self.PlayerFrameHealthBarAnimatedLoss = CreateFrame("StatusBar", nil, self, "DragonUI_PlayerFrameHealthBarAnimatedLossTemplate");
			self.PlayerFrameHealthBarAnimatedLoss:SetUnitHealthBar("player", self.healthbar);
			self.PlayerFrameHealthBarAnimatedLoss:SetFrameLevel(self.healthbar:GetFrameLevel() - 1);
		end

		-- Builder/Spender feedback frames (driven by the global UnitFrameManaBar_OnUpdate override)
		if moduleConfig and moduleConfig.builder_spender and self.manabar then
			self.manabar.FeedbackFrame = CreateFrame("Frame", nil, self.manabar, "DragonUI_BuilderSpenderFrame");
			self.manabar.FeedbackFrame:SetAllPoints();
			self.manabar.FeedbackFrame:SetFrameLevel(self:GetParent():GetFrameLevel() + 2);

			self.manabar.FullPowerFrame = CreateFrame("Frame", nil, self.manabar, "DragonUI_FullPowerFrameTemplate");

			local powerType, powerToken = UnitPowerType(self.unit);
			local colorSource = PowerBarColor;
			local info = nil;
			if colorSource then
				info = (powerToken and colorSource[powerToken])
					or (powerType and colorSource[powerType])
					or colorSource["MANA"];
			end
			if not info then
				info = { r = 1, g = 1, b = 1 };
			end
			local fullPowerAnim = FULL_POWER_ANIM_POWER_TYPES[powerToken]
				or FULL_POWER_ANIM_POWER_TYPES[powerType]
				or info.fullPowerAnim;

			if self.manabar.FeedbackFrame.Initialize then
				self.manabar.FeedbackFrame:Initialize(info, self.unit, powerType or 0);
			end
			if self.manabar.FullPowerFrame and self.manabar.FullPowerFrame.Initialize then
				self.manabar.FullPowerFrame:Initialize(fullPowerAnim and true or false);
			end
		end
	end

	-- Missing health deficit text
	if not self.missingHealthText then
		self.missingHealthText = UFL_VisualHealthBar(self):CreateFontString(nil, "OVERLAY", "TextStatusBarText");
		self.missingHealthText:SetPoint("RIGHT", UFL_VisualHealthBar(self), "RIGHT", -4, 0);
		self.missingHealthText:SetJustifyH("RIGHT");
		self.missingHealthText:SetTextColor(1, 0.3, 0.3);
		self.missingHealthText:Hide();
	end

	-- Force bars to use global OnUpdate handlers so prediction/loss logic updates
	-- continuously even when other modules reset scripts on the statusbars.
	self.__DragonUI_UFL = self.__DragonUI_UFL or {};
	self.__DragonUI_UFL.initialized = true;
	if self.healthbar then
		if self.__DragonUI_UFL.origHealthOnUpdate == nil then
			self.__DragonUI_UFL.origHealthOnUpdate = self.healthbar:GetScript("OnUpdate");
		end
		self.healthbar:SetScript("OnUpdate", _G.UnitFrameHealthBar_OnUpdate);
	end
	if self.manabar then
		if self.__DragonUI_UFL.origManaOnUpdate == nil then
			self.__DragonUI_UFL.origManaOnUpdate = self.manabar:GetScript("OnUpdate");
		end
		self.manabar:SetScript("OnUpdate", _G.UnitFrameManaBar_OnUpdate);
	end

	-- Track this frame
	UnitFrameLayersModule.frames[self:GetName() or tostring(self)] = self;

	UnitFrameHealPredictionBars_Update(self);
end

local function InitializeSingleUnitFrame(frame)
	if not (frame and frame.GetName) then
		return
	end

	if frame.__DragonUI_UFL and frame.__DragonUI_UFL.initialized then
		return
	end

	local frameName = frame:GetName();
	if not frameName then
		return
	end

	-- Some frames (notably party frames) expose bars as named globals instead of
	-- frame.healthbar/frame.manabar fields.
	if not frame.healthbar then
		frame.healthbar = _G[frameName .. "HealthBar"];
	end
	if not frame.manabar then
		frame.manabar = _G[frameName .. "ManaBar"];
	end

	if not frame.unit then
		local partyIndex = frameName:match("^PartyMemberFrame(%d+)$");
		local partyPetIndex = frameName:match("^PartyMemberFrame(%d+)PetFrame$");
		if partyIndex then
			frame.unit = "party" .. partyIndex;
		elseif partyPetIndex then
			frame.unit = "partypet" .. partyPetIndex;
		end
	end

	if not (frame.healthbar and frame.unit) then
		return
	end

	if not frame.myHealPredictionBar then
		CreateFrame("Frame", nil, frame, "DragonUI_StatusBarHealPredictionTemplate");
	end

	UnitFrameLayer_Initialize(frame,
		_G[frameName .. "FrameMyHealPredictionBar"],
		_G[frameName .. "FrameOtherHealPredictionBar"],
		_G[frameName .. "TotalAbsorbBar"],
		_G[frameName .. "TotalAbsorbBarOverlay"],
		_G[frameName .. "FrameOverAbsorbGlow"],
		_G[frameName .. "OverHealAbsorbGlow"],
		_G[frameName .. "HealAbsorbBar"],
		_G[frameName .. "HealAbsorbBarLeftShadow"],
		_G[frameName .. "HealAbsorbBarRightShadow"],
		_G[frameName .. "FrameManaCostPredictionBar"]
	);
end

local function InitializeExistingUnitFrames()
	-- Named Blizzard frames we support in 3.3.5a.
	local candidates = {
		_G.PlayerFrame,
		_G.TargetFrame,
		_G.FocusFrame,
		_G.PetFrame,
		_G.TargetFrameToT,
		_G.FocusFrameToT,
	};

	for i = 1, 4 do
		table.insert(candidates, _G["PartyMemberFrame" .. i]);
		table.insert(candidates, _G["PartyMemberFrame" .. i .. "PetFrame"]);
	end

	for _, frame in ipairs(candidates) do
		InitializeSingleUnitFrame(frame);
	end
end

-- ============================================================================
-- APPLY / RESTORE SYSTEM
-- ============================================================================

-- Save Blizzard originals for safe override/restore
local orig_UnitFrameHealthBar_OnUpdate = _G.UnitFrameHealthBar_OnUpdate;
local orig_UnitFrameManaBar_OnUpdate = _G.UnitFrameManaBar_OnUpdate;

local function ApplyUnitFrameLayersSystem()
	if UnitFrameLayersModule.applied then return end
	EnsureLibs();

	-- Do NOT replace the global Blizzard secure functions
	-- UnitFrameHealthBar_OnUpdate / UnitFrameManaBar_OnUpdate. Reassigning
	-- these tainted them, which then propagated into protected paths used
	-- by PartyMemberFrame (HealthBar/ManaBar :Show()) and the global
	-- UnitFrameHealthBar_OnUpdate symbol itself, producing the taint log
	-- entries `Global variable UnitFrameHealthBar_OnUpdate tainted` and
	-- `Action blocked: PartyMemberFrameNHealthBar:Show()` during combat.
	-- Instead, hook the globals additively. Blizzard's original handles
	-- self:SetValue(currValue) / self.currValue / TextStatusBar_UpdateTextString;
	-- we only need to drive the animated loss bar and heal prediction
	-- overlay on top of that. Track the previous value per bar via a side
	-- table so we can still feed the AnimatedLossBar both old and new values
	-- without rewriting the secure function.
	if orig_UnitFrameHealthBar_OnUpdate and not UnitFrameLayersModule.hooks["UnitFrameHealthBar_OnUpdate_override"] then
		local lastHealthValue = {};
		hooksecurefunc("UnitFrameHealthBar_OnUpdate", function(self)
			if not IsModuleEnabled() then return end
			if self.disconnected or self.lockValues then return end
			local unit = self.unit;
			if not unit then return end
			if self.ignoreNoUnit and not UnitGUID(unit) then return end

			local currValue = UnitHealth(unit);
			local prev = lastHealthValue[self];
			if prev == nil then
				-- First hook pass for a bar: seed with current/cached value so
				-- AnimatedLossBar math never receives nil previousHealth.
				prev = self.currValue or currValue;
				lastHealthValue[self] = prev;
			end
			local animatedLossBar = self.AnimatedLossBar;
			if prev ~= currValue then
				if animatedLossBar then
					animatedLossBar:UpdateHealth(currValue, prev);
				end
				if UnitFrameHealPredictionBars_Update then
					UnitFrameHealPredictionBars_Update(self:GetParent());
				end
				lastHealthValue[self] = currValue;
			end
			if animatedLossBar then
				animatedLossBar:UpdateLossAnimation(currValue);
			end
		end);
		UnitFrameLayersModule.hooks["UnitFrameHealthBar_OnUpdate_override"] = true;
	end

	-- Same rationale for the mana bar OnUpdate global.
	-- The DragonUI extras here (FeedbackFrame / FullPowerFrame animations
	-- and predicted-cost rendering) only need to read state and call
	-- additive methods; they do not need to take over Blizzard's value
	-- propagation. Use an additive hook to avoid tainting the global.
	if orig_UnitFrameManaBar_OnUpdate and not UnitFrameLayersModule.hooks["UnitFrameManaBar_OnUpdate_override"] then
		local lastPowerValue = {};
		hooksecurefunc("UnitFrameManaBar_OnUpdate", function(self)
			if not IsModuleEnabled() then return end
			if self.disconnected or self.lockValues then return end
			local unit = self.unit;
			if not unit then return end
			if self.ignoreNoUnit and not UnitGUID(unit) then return end

			local parent = self:GetParent();
			local predictedCost = parent and parent.predictedPowerCost;
			local currValue = UnitPower(unit, self.powerType);
			if predictedCost then
				currValue = currValue - (addon.UFL_Round or math.floor)(predictedCost);
			end

			-- Keep pre-cost visualization behavior from the old override:
			-- the mana bar value tracks the predicted post-cast amount so
			-- cost prediction direction stays consistent with DragonUI's
			-- original look.
			if self:GetValue() ~= currValue or self.forceUpdate then
				self.forceUpdate = nil;
				self:SetValue(currValue);
				self.currValue = currValue;
				TextStatusBar_UpdateTextString(self);
			end

			local prev = lastPowerValue[self];
			if prev ~= currValue then
				if self.FeedbackFrame then
					local oldValue = prev or 0;
					local maxValue = self.FeedbackFrame.maxValue;
					if maxValue and maxValue ~= 0 and math.abs(currValue - oldValue) / maxValue > 0.1 then
						self.FeedbackFrame:StartFeedbackAnim(oldValue, currValue);
					end
				end
				if self.FullPowerFrame and self.FullPowerFrame.active then
					self.FullPowerFrame:StartAnimIfFull(prev or 0, currValue);
				end
				lastPowerValue[self] = currValue;
			end
		end);
		UnitFrameLayersModule.hooks["UnitFrameManaBar_OnUpdate_override"] = true;
	end

	-- Hook UnitFrameHealthBar_Update (Blizzard global)
	if _G.UnitFrameHealthBar_Update and not UnitFrameLayersModule.hooks["UnitFrameHealthBar_Update"] then
		hooksecurefunc("UnitFrameHealthBar_Update", function(statusbar, unit)
			if not IsModuleEnabled() then return end
			if statusbar.AnimatedLossBar then
				statusbar.AnimatedLossBar:UpdateHealthMinMax();
			end
			UnitFrameHealPredictionBars_Update(statusbar:GetParent());
		end);
		UnitFrameLayersModule.hooks["UnitFrameHealthBar_Update"] = true;
	end

	-- Hook UnitFrame_Update (Blizzard global)
	if _G.UnitFrame_Update and not UnitFrameLayersModule.hooks["UnitFrame_Update"] then
		hooksecurefunc("UnitFrame_Update", function(self, isParty)
			if not IsModuleEnabled() then return end
			UnitFrameHealPredictionBars_UpdateMax(self);
			UnitFrameHealPredictionBars_Update(self);
			UnitFrameManaCostPredictionBars_Update(self);
		end);
		UnitFrameLayersModule.hooks["UnitFrame_Update"] = true;
	end

	-- Hook UnitFrameManaBar_Update for predicted power cost display
	if _G.UnitFrameManaBar_Update and not UnitFrameLayersModule.hooks["UnitFrameManaBar_Update"] then
		hooksecurefunc("UnitFrameManaBar_Update", function(statusbar, unit)
			if not IsModuleEnabled() then return end
			if not statusbar or statusbar.lockValues then return end
			-- Update FullPowerFrame max value if present
			if statusbar.FullPowerFrame and unit then
				local maxValue = UnitPowerMax(unit, statusbar.powerType);
				if maxValue and maxValue > 0 then
					statusbar.FullPowerFrame:SetMaxValue(maxValue);
				end
			end
		end);
		UnitFrameLayersModule.hooks["UnitFrameManaBar_Update"] = true;
	end

	-- Hook UnitFrame_OnEvent (main entry point — initializes prediction bars on first event)
	if _G.UnitFrame_OnEvent and not UnitFrameLayersModule.hooks["UnitFrame_OnEvent"] then
		hooksecurefunc("UnitFrame_OnEvent", function(self, event, ...)
			if not IsModuleEnabled() then return end

			if ( not self.__DragonUI_UFL or not self.__DragonUI_UFL.initialized ) then
				-- Create the heal prediction template on this frame
				InitializeSingleUnitFrame(self);
			end

			UnitFrameHealPredictionBars_Update(self);

			if ( event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_STOP"
				or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_SUCCEEDED" ) then
				local unit = ...;
				if ( unit and self.unit and UnitIsUnit(unit, self.unit) ) then
					local name, text, texture, startTime, endTime = UnitCastingInfo(unit);
					UnitFrameManaCostPredictionBars_Update(self, event == "UNIT_SPELLCAST_START", startTime, endTime, name);
				end
			end
		end);
		UnitFrameLayersModule.hooks["UnitFrame_OnEvent"] = true;
	end

	-- Reload-safe bootstrap: initialize currently existing frames immediately,
	-- instead of waiting for a future UnitFrame_OnEvent call.
	InitializeExistingUnitFrames();

	UnitFrameLayersModule.applied = true;
	UnitFrameLayersModule.initialized = true;
end

local function HideFrameChildren(frame)
	-- Hide all prediction bar children
	local bars = {
		"myHealPredictionBar", "otherHealPredictionBar", "totalAbsorbBar",
		"totalAbsorbBarOverlay", "overAbsorbGlow", "overHealAbsorbGlow",
		"healAbsorbBar", "healAbsorbBarLeftShadow", "healAbsorbBarRightShadow",
		"myManaCostPredictionBar",
	};
	for _, key in ipairs(bars) do
		if frame[key] and frame[key].Hide then
			frame[key]:Hide();
		end
	end
	-- Hide missing health text
	if frame.missingHealthText then
		frame.missingHealthText:Hide();
	end
	-- Hide animated loss bar
	if frame.PlayerFrameHealthBarAnimatedLoss then
		frame.PlayerFrameHealthBarAnimatedLoss:CancelAnimation();
		frame.PlayerFrameHealthBarAnimatedLoss:Hide();
	end
end

local function RestoreUnitFrameLayersSystem()
	if not UnitFrameLayersModule.applied then return end

	-- Restore original global functions
	if orig_UnitFrameHealthBar_OnUpdate and UnitFrameLayersModule.hooks["UnitFrameHealthBar_OnUpdate_override"] then
		_G.UnitFrameHealthBar_OnUpdate = orig_UnitFrameHealthBar_OnUpdate;
	end
	if orig_UnitFrameManaBar_OnUpdate and UnitFrameLayersModule.hooks["UnitFrameManaBar_OnUpdate_override"] then
		_G.UnitFrameManaBar_OnUpdate = orig_UnitFrameManaBar_OnUpdate;
	end

	-- Hide all prediction bars on tracked frames
	for _, frame in pairs(UnitFrameLayersModule.frames) do
		if frame then
			HideFrameChildren(frame);
			UnitFrame_UnregisterCallback(frame);
			if frame.__DragonUI_UFL then
				if frame.healthbar then
					frame.healthbar:SetScript("OnUpdate", frame.__DragonUI_UFL.origHealthOnUpdate);
				end
				if frame.manabar then
					frame.manabar:SetScript("OnUpdate", frame.__DragonUI_UFL.origManaOnUpdate);
				end
			end
		end
	end

	-- Note: hooksecurefunc cannot be unhooked, but the IsModuleEnabled() guard
	-- inside each hook will prevent any work from being done when disabled.

	UnitFrameLayersModule.applied = false;
end

-- Public API for options panel
addon.RefreshUnitFrameLayers = function()
	if IsModuleEnabled() then
		ApplyUnitFrameLayersSystem();
	else
		RestoreUnitFrameLayersSystem();
	end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local initFrame = CreateFrame("Frame");
initFrame:RegisterEvent("PLAYER_LOGIN");
initFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		if IsModuleEnabled() then
			ApplyUnitFrameLayersSystem();
		end
		self:UnregisterEvent("PLAYER_LOGIN");
	end
end);

-- ============================================================================
-- DIAGNOSTIC COMMAND: /dragonui ufl
-- ============================================================================

addon.DiagnoseUnitFrameLayers = function()
	local P = function(msg) print("|cFF00FF00[DragonUI UFL]|r " .. msg) end
	local OK = "|cFF00FF00OK|r"
	local FAIL = "|cFFFF0000FAIL|r"
	local WARN = "|cFFFFFF00WARN|r"

	P("=== UnitFrameLayers Diagnostic ===")

	-- 1. Module state
	local cfg = GetModuleConfig()
	P("Module enabled: " .. (IsModuleEnabled() and OK or FAIL))
	P("Module applied: " .. (UnitFrameLayersModule.applied and OK or FAIL))
	P("Module initialized: " .. (UnitFrameLayersModule.initialized and OK or FAIL))
	P("Config table: " .. (cfg and OK or FAIL))
	if cfg then
		P("  animated_loss: " .. tostring(cfg.animated_loss))
		P("  builder_spender: " .. tostring(cfg.builder_spender))
	end

	-- 2. Libraries
	EnsureLibs()
	P("LibHealComm-4.0: " .. (HealComm and OK or FAIL))
	P("AbsorbsMonitor-1.0: " .. (LibAbsorb and OK or FAIL))
	if HealComm then
		P("  HealComm.ALL_HEALS: " .. tostring(HealComm.ALL_HEALS))
		P("  HealComm.CASTED_HEALS: " .. tostring(HealComm.CASTED_HEALS))
		P("  HealComm.HOT_HEALS: " .. tostring(HealComm.HOT_HEALS))
	end

	-- 3. Hooks installed
	P("Hooks:")
	for k, v in pairs(UnitFrameLayersModule.hooks) do
		P("  " .. k .. ": " .. tostring(v))
	end

	-- 4. Tracked frames
	local frameCount = 0
	for name, frame in pairs(UnitFrameLayersModule.frames) do
		frameCount = frameCount + 1
		P("Frame: " .. tostring(name))
		P("  unit: " .. tostring(frame.unit))
		P("  myHealPredictionBar: " .. (frame.myHealPredictionBar and OK or FAIL))
		P("  otherHealPredictionBar: " .. (frame.otherHealPredictionBar and OK or FAIL))
		P("  totalAbsorbBar: " .. (frame.totalAbsorbBar and OK or FAIL))
		P("  overAbsorbGlow: " .. (frame.overAbsorbGlow and OK or FAIL))
		P("  healAbsorbBar: " .. (frame.healAbsorbBar and OK or FAIL))
		P("  myManaCostPredictionBar: " .. (frame.myManaCostPredictionBar and OK or FAIL))
		if frame.PlayerFrameHealthBarAnimatedLoss then
			P("  AnimatedLossBar: " .. OK)
		end

		-- Check OnUpdate scripts
		if frame.healthbar then
			local onUpdate = frame.healthbar:GetScript("OnUpdate")
			local isOverridden = (onUpdate == _G.UnitFrameHealthBar_OnUpdate)
			P("  healthbar OnUpdate is UFL override: " .. (isOverridden and OK or FAIL))
		end

		-- Check registered events
		local hasAura = frame:IsEventRegistered("UNIT_AURA")
		local hasMaxHP = frame:IsEventRegistered("UNIT_MAXHEALTH")
		P("  UNIT_AURA registered: " .. (hasAura and OK or (FAIL .. " (HoT/absorb updates need this!)")))
		P("  UNIT_MAXHEALTH registered: " .. (hasMaxHP and OK or FAIL))

		-- Live data
		if frame.unit and UnitExists(frame.unit) then
			local myHeal = UFL_UnitGetIncomingHeals(frame.unit, "player") or 0
			local allHeal = UFL_UnitGetIncomingHeals(frame.unit) or 0
			local absorb = UFL_UnitGetTotalAbsorbs(frame.unit) or 0
			local _, maxHP = frame.healthbar:GetMinMaxValues()
			local hp = frame.healthbar:GetValue()
			P("  Health: " .. tostring(hp) .. " / " .. tostring(maxHP))
			P("  myIncomingHeal (CASTED): " .. tostring(myHeal))
			P("  allIncomingHeal (ALL): " .. tostring(allHeal))
			P("  HoT amount (all-my): " .. tostring(allHeal - myHeal))
			P("  totalAbsorb: " .. tostring(absorb))

			-- Visibility check
			if frame.myHealPredictionBar then
				P("  myHealBar visible: " .. (frame.myHealPredictionBar:IsShown() and "YES" or "no"))
			end
			if frame.otherHealPredictionBar then
				P("  otherHealBar visible: " .. (frame.otherHealPredictionBar:IsShown() and "YES" or "no"))
			end
			if frame.totalAbsorbBar then
				P("  absorbBar visible: " .. (frame.totalAbsorbBar:IsShown() and "YES" or "no"))
			end
		end
	end
	P("Total tracked frames: " .. frameCount)

	-- 5. Global function override check
	P("Global UnitFrameHealthBar_OnUpdate overridden: " .. (UnitFrameLayersModule.hooks["UnitFrameHealthBar_OnUpdate_override"] and OK or FAIL))
	P("Global UnitFrameManaBar_OnUpdate overridden: " .. (UnitFrameLayersModule.hooks["UnitFrameManaBar_OnUpdate_override"] and OK or FAIL))

	P("=== End Diagnostic ===")
	P("Tip: Cast a HoT or apply a shield, then run /dragonui ufl again to see live data.")
end
