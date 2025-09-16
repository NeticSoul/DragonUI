local addon = select(2,...);
local config = addon.config;

local pairs = pairs;
local gsub = string.gsub;
local UIParent = UIParent;
local hooksecurefunc = hooksecurefunc;
local _G = _G;

-- Table to store original Blizzard OnEnter/OnLeave handlers
local originalBlizzardHandlers = {}

-- const
local PERFORMANCEBAR_LOW_LATENCY = 300;
local PERFORMANCEBAR_MEDIUM_LATENCY = 600;

local MainMenuMicroButtonMixin = {};
local MainMenuBarBackpackButton = _G.MainMenuBarBackpackButton;
local HelpMicroButton = _G.HelpMicroButton;
local KeyRingButton = _G.KeyRingButton;

-- Variable to track if bag styling has been initialized
local bags_initialized = false

local bagslots = {
    _G.CharacterBag0Slot,
    _G.CharacterBag1Slot,
    _G.CharacterBag2Slot,
    _G.CharacterBag3Slot
};

-- Function to ensure loot animation always goes to main backpack when bags are collapsed
local function EnsureLootAnimationToMainBag()
	-- Simple approach: when bags are hidden, WoW should naturally redirect loot to main bag
	
end

-- Helper function to get bag collapse state (persistent in DB)
local function GetBagCollapseState()
	if addon.db and addon.db.profile and addon.db.profile.micromenu then
		return addon.db.profile.micromenu.bags_collapsed
	end
	return false -- Default to expanded
end

-- Helper function to set bag collapse state (persistent in DB)
local function SetBagCollapseState(collapsed)
	if addon.db and addon.db.profile and addon.db.profile.micromenu then
		addon.db.profile.micromenu.bags_collapsed = collapsed
	end
end

-- Micromenu Atlas coordinates from ultimaversion (uimicromenu2x.blp)
local MicromenuAtlas = {
	["UI-HUD-MicroMenu-Achievements-Disabled"] = {0.000976562, 0.0634766, 0.00195312, 0.162109},
	["UI-HUD-MicroMenu-Achievements-Down"] = {0.000976562, 0.0634766, 0.166016, 0.326172},
	["UI-HUD-MicroMenu-Achievements-Mouseover"] = {0.000976562, 0.0634766, 0.330078, 0.490234},
	["UI-HUD-MicroMenu-Achievements-Up"] = {0.000976562, 0.0634766, 0.494141, 0.654297},
	
	["UI-HUD-MicroMenu-Collections-Disabled"] = {0.0654297, 0.12793, 0.658203, 0.818359},
	["UI-HUD-MicroMenu-Collections-Down"] = {0.0654297, 0.12793, 0.822266, 0.982422},
	["UI-HUD-MicroMenu-Collections-Mouseover"] = {0.129883, 0.192383, 0.00195312, 0.162109},
	["UI-HUD-MicroMenu-Collections-Up"] = {0.129883, 0.192383, 0.166016, 0.326172},
	
	["UI-HUD-MicroMenu-GameMenu-Disabled"] = {0.129883, 0.192383, 0.330078, 0.490234},
	["UI-HUD-MicroMenu-GameMenu-Down"] = {0.129883, 0.192383, 0.494141, 0.654297},
	["UI-HUD-MicroMenu-GameMenu-Mouseover"] = {0.129883, 0.192383, 0.658203, 0.818359},
	["UI-HUD-MicroMenu-GameMenu-Up"] = {0.129883, 0.192383, 0.822266, 0.982422},
	
	["UI-HUD-MicroMenu-Groupfinder-Disabled"] = {0.194336, 0.256836, 0.00195312, 0.162109},
	["UI-HUD-MicroMenu-Groupfinder-Down"] = {0.194336, 0.256836, 0.166016, 0.326172},
	["UI-HUD-MicroMenu-Groupfinder-Mouseover"] = {0.194336, 0.256836, 0.330078, 0.490234},
	["UI-HUD-MicroMenu-Groupfinder-Up"] = {0.194336, 0.256836, 0.494141, 0.654297},
	
	["UI-HUD-MicroMenu-GuildCommunities-Disabled"] = {0.194336, 0.256836, 0.658203, 0.818359},
	["UI-HUD-MicroMenu-GuildCommunities-Down"] = {0.194336, 0.256836, 0.822266, 0.982422},
	["UI-HUD-MicroMenu-GuildCommunities-Mouseover"] = {0.258789, 0.321289, 0.658203, 0.818359},
	["UI-HUD-MicroMenu-GuildCommunities-Up"] = {0.258789, 0.321289, 0.822266, 0.982422},
	
	["UI-HUD-MicroMenu-Questlog-Disabled"] = {0.323242, 0.385742, 0.494141, 0.654297},
	["UI-HUD-MicroMenu-Questlog-Down"] = {0.323242, 0.385742, 0.658203, 0.818359},
	["UI-HUD-MicroMenu-Questlog-Mouseover"] = {0.323242, 0.385742, 0.822266, 0.982422},
	["UI-HUD-MicroMenu-Questlog-Up"] = {0.387695, 0.450195, 0.00195312, 0.162109},
	
	["UI-HUD-MicroMenu-SpecTalents-Disabled"] = {0.387695, 0.450195, 0.822266, 0.982422},
	["UI-HUD-MicroMenu-SpecTalents-Down"] = {0.452148, 0.514648, 0.00195312, 0.162109},
	["UI-HUD-MicroMenu-SpecTalents-Mouseover"] = {0.452148, 0.514648, 0.166016, 0.326172},
	["UI-HUD-MicroMenu-SpecTalents-Up"] = {0.452148, 0.514648, 0.330078, 0.490234},
	
	["UI-HUD-MicroMenu-SpellbookAbilities-Disabled"] = {0.452148, 0.514648, 0.494141, 0.654297},
	["UI-HUD-MicroMenu-SpellbookAbilities-Down"] = {0.452148, 0.514648, 0.658203, 0.818359},
	["UI-HUD-MicroMenu-SpellbookAbilities-Mouseover"] = {0.452148, 0.514648, 0.822266, 0.982422},
	["UI-HUD-MicroMenu-SpellbookAbilities-Up"] = {0.516602, 0.579102, 0.00195312, 0.162109},
	
	["UI-HUD-MicroMenu-Shop-Disabled"] = {0.387695, 0.450195, 0.166016, 0.326172},
	["UI-HUD-MicroMenu-Shop-Down"] = {0.387695, 0.450195, 0.494141, 0.654297},
	["UI-HUD-MicroMenu-Shop-Mouseover"] = {0.387695, 0.450195, 0.330078, 0.490234},
	["UI-HUD-MicroMenu-Shop-Up"] = {0.387695, 0.450195, 0.658203, 0.818359},
}

-- Helper function to map button names to atlas keys
local function GetAtlasKey(buttonName)
	local buttonMap = {
		character = nil, -- Will always use grayscale (no color version exists)
		spellbook = "UI-HUD-MicroMenu-SpellbookAbilities",
		talent = "UI-HUD-MicroMenu-SpecTalents", 
		achievement = "UI-HUD-MicroMenu-Achievements",
		questlog = "UI-HUD-MicroMenu-Questlog",
		socials = "UI-HUD-MicroMenu-GuildCommunities",
		lfd = "UI-HUD-MicroMenu-Groupfinder",
		collections = "UI-HUD-MicroMenu-Collections",
		pvp = nil, -- Special handling with micropvp texture
		mainmenu = "UI-HUD-MicroMenu-Shop", -- MainMenuMicroButton uses Shop icon
		help = "UI-HUD-MicroMenu-GameMenu", -- HelpMicroButton uses GameMenu icon
	}
	return buttonMap[buttonName]
end

-- Helper function to get texture coordinates for colored icons
local function GetColoredTextureCoords(buttonName, textureType)
	local atlasKey = GetAtlasKey(buttonName)
	if not atlasKey then return nil end -- Character button or unsupported
	
	local coordsKey = atlasKey .. "-" .. textureType
	local coords = MicromenuAtlas[coordsKey]
	if coords and type(coords) == "table" and #coords >= 4 then
		return coords
	end
	return nil -- Return nil if coordinates don't exist or are invalid
end

-- Special function to handle PVP button with faction-based micropvp texture
local function SetupPVPButton(button)
	local microTexture = 'Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\micropvp'
	local englishFaction, localizedFaction = UnitFactionGroup('player')
	
	-- Safety check: if faction is not available yet, use a default or skip
	if not englishFaction then
		-- Fallback to grayscale if faction is not determined yet
		local normalTexture = button:GetNormalTexture()
		local pushedTexture = button:GetPushedTexture()
		local disabledTexture = button:GetDisabledTexture()
		local highlightTexture = button:GetHighlightTexture()
		
		if normalTexture then normalTexture:set_atlas('ui-hud-micromenu-pvp-up-2x') end
		if pushedTexture then pushedTexture:set_atlas('ui-hud-micromenu-pvp-down-2x') end
		if disabledTexture then disabledTexture:set_atlas('ui-hud-micromenu-pvp-disabled-2x') end
		if highlightTexture then highlightTexture:set_atlas('ui-hud-micromenu-pvp-mouseover-2x') end
		return
	end
	
	local coords = {}
	if englishFaction == 'Alliance' then
		-- Alliance coordinates (left side of micropvp texture)
		coords = {0, 118 / 256, 0, 151 / 256}
	else
		-- Horde coordinates (right side of micropvp texture)  
		coords = {118 / 256, 236 / 256, 0, 151 / 256}
	end
	
	-- Apply the same coordinates to all states
	local normalTexture = button:GetNormalTexture()
	local pushedTexture = button:GetPushedTexture()
	local disabledTexture = button:GetDisabledTexture()
	local highlightTexture = button:GetHighlightTexture()
	
	-- Get button size for proper scaling
	local buttonWidth, buttonHeight = button:GetSize()
	
	if normalTexture then
		normalTexture:SetTexture(microTexture)
		normalTexture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		normalTexture:ClearAllPoints()
		normalTexture:SetPoint('CENTER', 0, 0)  -- FIXED: Force CENTER positioning
		normalTexture:SetSize(buttonWidth, buttonHeight)  -- FIXED: Set size manually for movement
	end
	
	if pushedTexture then
		pushedTexture:SetTexture(microTexture)
		pushedTexture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		pushedTexture:ClearAllPoints()
		pushedTexture:SetPoint('CENTER', 0, 0)  -- FIXED: Force CENTER positioning
		pushedTexture:SetSize(buttonWidth, buttonHeight)  -- FIXED: Set size manually for movement
	end
	
	-- For PVP disabled state: always use the same faction texture (never grayscale)
	-- WoW will automatically apply opacity when the button is disabled
	if disabledTexture then
		disabledTexture:SetTexture(microTexture)
		disabledTexture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		disabledTexture:ClearAllPoints()
		disabledTexture:SetPoint('CENTER', 0, 0)  -- FIXED: Force CENTER positioning
		disabledTexture:SetSize(buttonWidth, buttonHeight)  -- FIXED: Set size manually for movement
	end
	
	if highlightTexture then
		highlightTexture:SetTexture(microTexture)
		highlightTexture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		highlightTexture:ClearAllPoints()
		highlightTexture:SetPoint('CENTER', 0, 0)  -- FIXED: Force CENTER positioning
		highlightTexture:SetSize(buttonWidth, buttonHeight)  -- FIXED: Set size manually for movement
	end
	
	-- Add background for PVP button (corrected coordinates like ultimaversion)
	-- Only create if it doesn't exist to prevent duplication
	if not button.DragonUIBackground then
		local backgroundTexture = 'Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\uimicromenu2x'
		local dx, dy = -1, 1
		local offX, offY = button:GetPushedTextOffset()
		local sizeX, sizeY = button:GetSize()
		
		-- Background Normal (uses DOWN coords, fixed position) - like ultimaversion
		local bg = button:CreateTexture('DragonUIBackground', 'BACKGROUND')
		bg:SetTexture(backgroundTexture)
		bg:SetSize(sizeX, sizeY + 1)
		bg:SetTexCoord(0.0654297, 0.12793, 0.330078, 0.490234)  -- ButtonBG-Down (CORRECTED)
		bg:SetPoint('CENTER', dx, dy)
		button.DragonUIBackground = bg
		
		-- Background Pressed (uses UP coords, offset position) - like ultimaversion
		local bgPushed = button:CreateTexture('DragonUIBackgroundPushed', 'BACKGROUND')
		bgPushed:SetTexture(backgroundTexture)
		bgPushed:SetSize(sizeX, sizeY + 1)
		bgPushed:SetTexCoord(0.0654297, 0.12793, 0.494141, 0.654297)  -- ButtonBG-Up (CORRECTED)
		bgPushed:SetPoint('CENTER', dx + offX, dy + offY)
		bgPushed:Hide()
		button.DragonUIBackgroundPushed = bgPushed
		
		-- State management for background switching
		button.dragonUIState = {}
		button.dragonUIState.pushed = false
		
		-- Timer for state checking (same as other buttons)
		button.dragonUITimer = 0
		button.dragonUILastState = false
		
		button:SetScript('OnUpdate', function(self, elapsed)
			self.dragonUITimer = self.dragonUITimer + elapsed
			if self.dragonUITimer >= 0.1 then
				self.dragonUITimer = 0
				local currentState = self:GetButtonState() == "PUSHED"
				if currentState ~= self.dragonUILastState then
					self.dragonUILastState = currentState
					self.dragonUIState.pushed = currentState
					if self.HandleDragonUIState then
						self.HandleDragonUIState()
					end
				end
			end
		end)
	end
	
	-- CRITICAL: Always recreate HandleDragonUIState function (even on refresh)
	local dx, dy = -1, 1
	local offX, offY = button:GetPushedTextOffset()
	
	button.HandleDragonUIState = function()
		local state = button.dragonUIState
		if state and state.pushed then
			-- FIXED: PVP icon moves subtly with background when pressed (like Character button)
			local subtleOffX = offX * 0.3  -- Reduce movement to 30% of button offset
			local subtleOffY = offY * 0.3  -- Reduce movement to 30% of button offset
			-- Icon moves with background with 70% opacity for pressed effect
			if button:GetNormalTexture() then
				button:GetNormalTexture():ClearAllPoints()
				button:GetNormalTexture():SetPoint('CENTER', subtleOffX, subtleOffY)  -- FIXED: Back to CENTER
				button:GetNormalTexture():SetAlpha(0.7)  -- 70% opacity when pressed
			end
			if button:GetPushedTexture() then
				button:GetPushedTexture():ClearAllPoints()
				button:GetPushedTexture():SetPoint('CENTER', subtleOffX, subtleOffY)  -- FIXED: Back to CENTER
				button:GetPushedTexture():SetAlpha(0.7)
			end
			if button:GetHighlightTexture() then
				button:GetHighlightTexture():ClearAllPoints()
				button:GetHighlightTexture():SetPoint('CENTER', subtleOffX, subtleOffY)  -- FIXED: Back to CENTER
				button:GetHighlightTexture():SetAlpha(0.7)
			end
			-- Background pressed shows (with offset position)
			if button.DragonUIBackground then button.DragonUIBackground:Hide() end
			if button.DragonUIBackgroundPushed then button.DragonUIBackgroundPushed:Show() end
		else
			-- FIXED: Icon stays centered to background with full opacity (normal state)
			if button:GetNormalTexture() then
				button:GetNormalTexture():ClearAllPoints()
				button:GetNormalTexture():SetPoint('CENTER', 0, 0)  -- FIXED: Back to CENTER
				button:GetNormalTexture():SetAlpha(1.0)  -- 100% opacity when normal
			end
			if button:GetPushedTexture() then
				button:GetPushedTexture():ClearAllPoints()
				button:GetPushedTexture():SetPoint('CENTER', 0, 0)  -- FIXED: Back to CENTER
				button:GetPushedTexture():SetAlpha(1.0)
			end
			if button:GetHighlightTexture() then
				button:GetHighlightTexture():ClearAllPoints()
				button:GetHighlightTexture():SetPoint('CENTER', 0, 0)  -- FIXED: Back to CENTER
				button:GetHighlightTexture():SetAlpha(1.0)
			end
			-- Background normal shows (fixed position)
			if button.DragonUIBackground then button.DragonUIBackground:Show() end
			if button.DragonUIBackgroundPushed then button.DragonUIBackgroundPushed:Hide() end
		end
	end
	
	-- Initialize state if needed
	if not button.dragonUIState then
		button.dragonUIState = {}
		button.dragonUIState.pushed = false
	end
	
	-- Call the function to set initial state
	button.HandleDragonUIState()
end

-- Function to permanently hide unwanted background frames
-- This handles green borders/backgrounds that appear in some modified clients
-- Runs multiple times to ensure frames are caught when they're created
local function HideUnwantedBagFrames()
	-- Hide problematic frames in ALL secondary bags (CharacterBag0Slot, CharacterBag1Slot, etc.)
	-- Only skip processing the MainMenuBarBackpackButton (main bag)
	for i, bags in pairs(bagslots) do
		-- Process ALL secondary bag slots (CharacterBag0Slot through CharacterBag3Slot)
		local bagName = bags:GetName()
		
		-- Extended list of potential problem frames in modified clients
		local possibleFrames = {
			bagName .. "Background",
			bagName .. "Border", 
			bagName .. "Frame",
			bagName .. "Texture",
			bagName .. "Highlight",
			bagName .. "Glow",
			bagName .. "Green",
			bagName .. "NormalTexture2",
			bagName .. "IconBorder",
			bagName .. "Flash",
			bagName .. "NewItemTexture",
			bagName .. "Shine",
			bagName .. "NewItemGlow"
		}
		
		for _, frameName in pairs(possibleFrames) do
			local frame = _G[frameName]
			if frame and frame.Hide then
				frame:Hide()
				-- Also set alpha to 0 as additional insurance
				if frame.SetAlpha then
					frame:SetAlpha(0)
				end
			end
		end
		
		-- Hide problematic texture regions more aggressively
		local numRegions = bags:GetNumRegions()
		for j = 1, numRegions do
			local region = select(j, bags:GetRegions())
			if region and region:GetObjectType() == "Texture" then
				local texture = region:GetTexture()
				if texture then
					local textureLower = tostring(texture):lower()
					-- More comprehensive pattern matching for problem textures
					if textureLower:find("background") or 
					   textureLower:find("border") or
					   textureLower:find("frame") or
					   textureLower:find("highlight") or
					   textureLower:find("green") or
					   textureLower:find("glow") or
					   textureLower:find("flash") or
					   textureLower:find("shine") then
						region:Hide()
						if region.SetAlpha then
							region:SetAlpha(0)
						end
					end
				end
			end
		end
		
		-- Also check children frames that might be added later
		local children = {bags:GetChildren()}
		for _, child in pairs(children) do
			if child and child.Hide then
				local childName = child:GetName()
				if childName then
					local childNameLower = childName:lower()
					if childNameLower:find("green") or childNameLower:find("glow") or 
					   childNameLower:find("highlight") or childNameLower:find("flash") then
						child:Hide()
						if child.SetAlpha then
							child:SetAlpha(0)
						end
					end
				end
			end
		end
	end
	
	-- Handle KeyRing with the same aggressive approach
	if KeyRingButton then
		local keyRingName = KeyRingButton:GetName()
		local possibleFrames = {
			keyRingName .. "Background",
			keyRingName .. "Border", 
			keyRingName .. "Frame",
			keyRingName .. "Texture",
			keyRingName .. "Highlight",
			keyRingName .. "Glow",
			keyRingName .. "Green",
			keyRingName .. "NormalTexture2",
			keyRingName .. "IconBorder",
			keyRingName .. "Flash",
			keyRingName .. "Shine",
			keyRingName .. "NewItemGlow"
		}
		
		for _, frameName in pairs(possibleFrames) do
			local frame = _G[frameName]
			if frame and frame.Hide then
				frame:Hide()
				if frame.SetAlpha then
					frame:SetAlpha(0)
				end
			end
		end
		
		local numRegions = KeyRingButton:GetNumRegions()
		for j = 1, numRegions do
			local region = select(j, KeyRingButton:GetRegions())
			if region and region:GetObjectType() == "Texture" then
				local texture = region:GetTexture()
				if texture then
					local textureLower = tostring(texture):lower()
					if textureLower:find("background") or 
					   textureLower:find("border") or
					   textureLower:find("frame") or
					   textureLower:find("highlight") or
					   textureLower:find("green") or
					   textureLower:find("glow") or
					   textureLower:find("shine") then
						region:Hide()
						if region.SetAlpha then
							region:SetAlpha(0)
						end
					end
				end
			end
		end
		
		-- Check KeyRing children too
		local children = {KeyRingButton:GetChildren()}
		for _, child in pairs(children) do
			if child and child.Hide then
				local childName = child:GetName()
				if childName then
					local childNameLower = childName:lower()
					if childNameLower:find("green") or childNameLower:find("glow") or 
					   childNameLower:find("highlight") or childNameLower:find("flash") then
						child:Hide()
						if child.SetAlpha then
							child:SetAlpha(0)
						end
					end
				end
			end
		end
	end
end

-- Create a frame to handle delayed execution
local hideFramesScheduler = CreateFrame("Frame")
local hideFramesQueue = {}

local function ScheduleHideFrames(delay)
	local scheduleTime = GetTime() + (delay or 0)
	table.insert(hideFramesQueue, scheduleTime)
	
	if not hideFramesScheduler:GetScript("OnUpdate") then
		hideFramesScheduler:SetScript("OnUpdate", function(self)
			local currentTime = GetTime()
			local i = 1
			while i <= #hideFramesQueue do
				if currentTime >= hideFramesQueue[i] then
					HideUnwantedBagFrames()
					table.remove(hideFramesQueue, i)
				else
					i = i + 1
				end
			end
			
			-- Remove OnUpdate when queue is empty
			if #hideFramesQueue == 0 then
				self:SetScript("OnUpdate", nil)
			end
		end)
	end
end
local MICRO_BUTTONS = {
	_G.CharacterMicroButton,
	_G.SpellbookMicroButton,
	_G.TalentMicroButton,
	_G.AchievementMicroButton,
	_G.QuestLogMicroButton,
	_G.SocialsMicroButton,
	_G.LFDMicroButton,
	_G.CollectionsMicroButton,
	_G.PVPMicroButton,
	_G.MainMenuMicroButton,
	_G.HelpMicroButton,
};
-- Make pUiBagsBar globally accessible for refresh functions
_G.pUiBagsBar = CreateFrame(
	'Frame',
	'pUiBagsBar',
	UIParent
);
local pUiBagsBar = _G.pUiBagsBar;
-- Initial scale will be set when database is available
MainMenuBarBackpackButton:SetParent(pUiBagsBar);
KeyRingButton:SetParent(_G.CharacterBag3Slot);
function MainMenuMicroButtonMixin:bagbuttons_setup()
	-- Set up main backpack button
	MainMenuBarBackpackButton:SetSize(50, 50)
	MainMenuBarBackpackButton:SetNormalTexture(nil)
	MainMenuBarBackpackButton:SetPushedTexture(nil)
	MainMenuBarBackpackButton:SetHighlightTexture''
	MainMenuBarBackpackButton:SetCheckedTexture''
	MainMenuBarBackpackButton:GetHighlightTexture():set_atlas('bag-main-highlight-2x')
	MainMenuBarBackpackButton:GetCheckedTexture():set_atlas('bag-main-highlight-2x')
	MainMenuBarBackpackButtonIconTexture:set_atlas('bag-main-2x')
	-- Make bags independent from micromenu by anchoring to UIParent instead of HelpMicroButton
	-- Position will be set by RefreshBagsPosition() using database values
	-- Temporary position to avoid errors, will be overridden immediately
	MainMenuBarBackpackButton:SetClearPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT', 1, 41)
	MainMenuBarBackpackButton.SetPoint = addon._noop
	
	MainMenuBarBackpackButtonCount:SetClearPoint('CENTER', MainMenuBarBackpackButton, 'BOTTOM', 0, 14)
	CharacterBag0Slot:SetClearPoint('RIGHT', MainMenuBarBackpackButton, 'LEFT', -14, -2)
	
	-- Set up KeyRingButton
	KeyRingButton:SetSize(34, 34)
	KeyRingButton:SetClearPoint('RIGHT', CharacterBag3Slot, 'LEFT', -4, 0)
	KeyRingButton:SetNormalTexture''
	KeyRingButton:SetPushedTexture(nil)
	KeyRingButton:SetHighlightTexture''
	KeyRingButton:SetCheckedTexture''
	
	local highlight = KeyRingButton:GetHighlightTexture();
	highlight:SetAllPoints();
	highlight:SetBlendMode('ADD');
	highlight:SetAlpha(.4);
	highlight:set_atlas('bag-border-highlight-2x', true)
	KeyRingButton:GetNormalTexture():set_atlas('bag-reagent-border-2x')
	KeyRingButton:GetCheckedTexture():set_atlas('bag-border-highlight-2x', true)
	
	-- Set up KeyRing icon (cropped like other bags, with error protection)
	local keyringIcon = KeyRingButtonIconTexture
	if keyringIcon then
		keyringIcon:ClearAllPoints()
		keyringIcon:SetPoint('TOPRIGHT', KeyRingButton, 'TOPRIGHT', -5, -2.9);
		keyringIcon:SetPoint('BOTTOMLEFT', KeyRingButton, 'BOTTOMLEFT', 2.9, 5);
		pcall(function() keyringIcon:SetTexCoord(.08,.92,.08,.92) end) -- Protect against texture errors
	end
	
	-- Set up KeyRing count (centered like other bags)
	if KeyRingButtonCount then
		KeyRingButtonCount:SetClearPoint('CENTER', KeyRingButton, 'CENTER', 0, -10);
		KeyRingButtonCount:SetDrawLayer('OVERLAY')
	end

	local KEYRING_CONTAINER = -2
	local function SyncKeyRingButton()
		if KeyRingButton then
			-- In 3.3.5a, IsBagOpen(-2) returns nil/false if the keyring is not open
			KeyRingButton:SetChecked(IsBagOpen(KEYRING_CONTAINER) and true or false)
		end
	end

	-- If the keyring is explicitly toggled
	if ToggleKeyRing then
		hooksecurefunc("ToggleKeyRing", function()
			SyncKeyRingButton()
		end)
	end

	-- When bags are closed globally (X, ESC, CloseAll, etc.)
	if CloseAllBags then
		hooksecurefunc("CloseAllBags", function()
			if KeyRingButton then KeyRingButton:SetChecked(false) end
		end)
	end

	-- When a container frame disappears (closing via the X of individual pockets)
	if ContainerFrame_OnHide then
		hooksecurefunc("ContainerFrame_OnHide", function()
			SyncKeyRingButton()
		end)
	end

	for _,bags in pairs(bagslots) do
		bags:SetHighlightTexture''
		bags:SetCheckedTexture''
		bags:SetPushedTexture(nil)
		bags:SetNormalTexture''
		bags:SetSize(28, 28)

		-- Set up single round frame (not double)
		bags:GetCheckedTexture():set_atlas('bag-border-highlight-2x', true)
		bags:GetCheckedTexture():SetDrawLayer('OVERLAY', 7)
		
		local highlight = bags:GetHighlightTexture();
		highlight:SetAllPoints();
		highlight:SetBlendMode('ADD');
		highlight:SetAlpha(.4);
		highlight:set_atlas('bag-border-highlight-2x', true)

		-- Set up icon positioning (cropped, with error protection)
		local icon = _G[bags:GetName()..'IconTexture']
		if icon then
			icon:ClearAllPoints()
			icon:SetPoint('TOPRIGHT', bags, 'TOPRIGHT', -5, -2.9);
			icon:SetPoint('BOTTOMLEFT', bags, 'BOTTOMLEFT', 2.9, 5);
			pcall(function() icon:SetTexCoord(.08,.92,.08,.92) end) -- Protect against texture errors
		end
		
		-- Create border texture ONLY once (no duplication)
		if not bags.customBorder then
			bags.customBorder = bags:CreateTexture(nil, 'OVERLAY')
			bags.customBorder:SetPoint('CENTER')
			bags.customBorder:set_atlas('bag-border-2x', true)
		end
		
		local w, h = bags.customBorder:GetSize()
		if not bags.background then
			bags.background = bags:CreateTexture(nil, 'BACKGROUND')
			bags.background:SetSize(w, h)
			bags.background:SetPoint('CENTER')
			bags.background:SetTexture(addon._dir..'bagslots2x')
			bags.background:SetTexCoord(295/512, 356/512, 64/128, 125/128)
		end
		
		local count = _G[bags:GetName()..'Count']
		count:SetClearPoint('CENTER', 0, -10);
		count:SetDrawLayer('OVERLAY')
	end
	
	-- Setup completed
	
	-- Ensure loot animation always goes to main bag when bags are collapsed
	EnsureLootAnimationToMainBag()
	
	-- Hide unwanted frames permanently after setup
	HideUnwantedBagFrames()
	
	-- Schedule additional hiding attempts with delays to catch late-loading frames
	ScheduleHideFrames(0.5)  -- 0.5 seconds
	ScheduleHideFrames(1.0)  -- 1 second
	ScheduleHideFrames(2.0)  -- 2 seconds
end

-- Function to reposition bags without full refresh (for collapse/expand)
function MainMenuMicroButtonMixin:bagbuttons_reposition()
	-- Always position the main backpack correctly
	CharacterBag0Slot:SetClearPoint('RIGHT', MainMenuBarBackpackButton, 'LEFT', -14, -2)
	
	-- Handle secondary bags based on collapse state
	if not GetBagCollapseState() then
		-- Bags are expanded, position them normally and restore original size
		for i,bags in pairs(bagslots) do
			bags:Show() -- Ensure they're visible
			bags:SetAlpha(1) -- Ensure they're visible
			-- Restore frame level to ensure they are not behind the main bag
			bags:SetFrameLevel(MainMenuBarBackpackButton:GetFrameLevel())
			-- Restore original size when expanded
			bags:SetScale(1.0)
			bags:SetSize(28, 28)
			
			if i == 1 then
				-- CharacterBag0Slot is already positioned above
			elseif i == 2 then
				bags:SetClearPoint('RIGHT', CharacterBag0Slot, 'LEFT', -4, 0)
			elseif i == 3 then
				bags:SetClearPoint('RIGHT', CharacterBag1Slot, 'LEFT', -4, 0)
			elseif i == 4 then
				bags:SetClearPoint('RIGHT', CharacterBag2Slot, 'LEFT', -4, 0)
			end
		end
		
		-- Position KeyRing back to its normal position when expanded and restore size
		if KeyRingButton then
			KeyRingButton:SetClearPoint('RIGHT', CharacterBag3Slot, 'LEFT', -4, 0)
			KeyRingButton:SetFrameLevel(MainMenuBarBackpackButton:GetFrameLevel())
			KeyRingButton:SetScale(1.0)
			KeyRingButton:SetSize(34, 34)
		end
	else
		-- HIDDEN BEHIND MAIN BAG: Position them behind the main bag so they're invisible but active
		-- The main bag (50x50) will cover the secondary bags (28x28) completely
		for i,bags in pairs(bagslots) do
			bags:Show() -- Keep them visible to the system
			bags:SetAlpha(1) -- Keep them fully opaque for animation system
			bags:ClearAllPoints()
			-- Position exactly behind the main backpack button (center to center)
			bags:SetPoint('CENTER', MainMenuBarBackpackButton, 'CENTER', 0, 0)
			-- Set frame level lower so they appear behind the main bag
			bags:SetFrameLevel(MainMenuBarBackpackButton:GetFrameLevel() - 1)
		end
		
		-- Also hide KeyRing behind main bag when collapsed
		if KeyRingButton then
			KeyRingButton:ClearAllPoints()
			KeyRingButton:SetPoint('CENTER', MainMenuBarBackpackButton, 'CENTER', 0, 0)
			KeyRingButton:SetFrameLevel(MainMenuBarBackpackButton:GetFrameLevel() - 1)
		end
	end
end

-- Function to refresh bag button styling
function MainMenuMicroButtonMixin:bagbuttons_refresh()
	-- Set parent only once, safely
	if _G.pUiBagsBar then
		for _,bags in pairs(bagslots) do
			if bags:GetParent() ~= _G.pUiBagsBar then
				bags:SetParent(_G.pUiBagsBar);
			end
		end
	end
	
	-- Apply the bag style setup
	self:bagbuttons_setup();
	
	-- Ensure KeyRingButton is visible if player has keys
	if HasKey() then
		KeyRingButton:Show();
	else
		KeyRingButton:Hide();
	end
	
	-- Handle icon transparency for empty slots
	for _,bags in pairs(bagslots) do
		local icon = _G[bags:GetName()..'IconTexture']
		if icon then
			local empty = icon:GetTexture() == 'interface\\paperdoll\\UI-PaperDoll-Slot-Bag'
			if empty then
				icon:SetAlpha(0)
			else
				icon:SetAlpha(1)
			end
		end
	end
	
	-- Hide unwanted frames permanently on initialization
	HideUnwantedBagFrames()
	ScheduleHideFrames(0.3)
	ScheduleHideFrames(1.0)
end

addon.package:RegisterEvents(function(self, event)
	if event == 'BAG_UPDATE' then
		-- Only handle KeyRing visibility on bag updates
		if HasKey() then
			if not KeyRingButton:IsShown() then
				KeyRingButton:Show();
			end
		else
			if KeyRingButton:IsShown() then
				KeyRingButton:Hide();
			end
		end
		
		-- Also try to hide frames on bag updates (frames might be recreated)
		ScheduleHideFrames(0.1)
	end
end,
	'BAG_UPDATE'
);

-- Event to force bag icon updates and ensure visibility on login
addon.package:RegisterEvents(function(self, event)
	-- Force update bag icons after a short delay to ensure all systems are loaded
	local updateFrame = CreateFrame("Frame")
	local elapsed = 0
	updateFrame:SetScript("OnUpdate", function(self, dt)
		elapsed = elapsed + dt
		if elapsed >= 1 then -- 1 second delay
			self:SetScript("OnUpdate", nil) -- Remove the update script
			
			
			-- Force update all bag slot icons
			for i, bags in pairs(bagslots) do
				local icon = _G[bags:GetName()..'IconTexture']
				if icon then
					-- Force the bag slot to update its icon
					PaperDollItemSlotButton_Update(bags)
					
					-- Handle empty slot transparency
					local empty = icon:GetTexture() == 'interface\\paperdoll\\UI-PaperDoll-Slot-Bag'
					if empty then
						icon:SetAlpha(0)
					else
						icon:SetAlpha(1)
					end
				end
			end
			
			-- Force update KeyRing if it exists and player has keys
			if KeyRingButton and HasKey() then
				KeyRingButton:Show()
			end
			
			-- Additional cleanup after all icon updates
			ScheduleHideFrames(0.2)
			ScheduleHideFrames(0.5)
			
		end
	end)
end, 'PLAYER_ENTERING_WORLD');

-- Also register for BAG_UPDATE to handle changes
addon.package:RegisterEvents(function(self, event, bagID)
	if bagID then
		-- Update specific bag
		local bagSlot = bagslots[bagID + 1] -- bagID is 0-based, our array is 1-based
		if bagSlot then
			local icon = _G[bagSlot:GetName()..'IconTexture']
			if icon then
				local empty = icon:GetTexture() == 'interface\\paperdoll\\UI-PaperDoll-Slot-Bag'
				if empty then
					icon:SetAlpha(0)
				else
					icon:SetAlpha(1)
				end
			end
		end
	end
end, 'BAG_UPDATE');

-- Note: Initial bag setup is handled by PLAYER_ENTERING_WORLD event above
-- No need for immediate refresh here, as it causes unnecessary load-time work

do
	local arrow = CreateFrame('CheckButton', 'pUiArrowManager', MainMenuBarBackpackButton)
	addon.pUiArrowManager = arrow -- Make arrow accessible to the addon object
	arrow:SetSize(12, 18)
	arrow:SetPoint('RIGHT', MainMenuBarBackpackButton, 'LEFT', 0, -2) -- Modern style position
	arrow:SetNormalTexture''
	arrow:SetPushedTexture''
	arrow:SetHighlightTexture''
	arrow:RegisterForClicks('LeftButtonUp')

	local normal = arrow:GetNormalTexture()
	local pushed = arrow:GetPushedTexture()
	local highlight = arrow:GetHighlightTexture()

	arrow:SetScript('OnClick',function(self)
		local checked = self:GetChecked();
		if checked then
			normal:set_atlas('bag-arrow-2x')
			pushed:set_atlas('bag-arrow-2x')
			highlight:set_atlas('bag-arrow-2x')
			SetBagCollapseState(true)
			MainMenuMicroButtonMixin:bagbuttons_reposition()
		else
			normal:set_atlas('bag-arrow-invert-2x')
			pushed:set_atlas('bag-arrow-invert-2x')
			highlight:set_atlas('bag-arrow-invert-2x')
			SetBagCollapseState(false)
			MainMenuMicroButtonMixin:bagbuttons_reposition()
		end
	end)
end

hooksecurefunc('MiniMapLFG_UpdateIsShown',function()
	MiniMapLFGFrame:SetClearPoint('LEFT', _G.CharacterMicroButton, -32, 2)
	MiniMapLFGFrame:SetScale(1.6)
	MiniMapLFGFrameBorder:SetTexture(nil)
	MiniMapLFGFrame.eye.texture:SetTexture(addon._dir..'uigroupfinderflipbookeye.tga')
end)

MiniMapLFGFrame:SetScript('OnClick',function(self, button)
	local mode, submode = GetLFGMode();
	if ( button == "RightButton" or mode == "lfgparty" or mode == "abandonedInDungeon") then
		PlaySound("igMainMenuOpen");
		local yOffset;
		if ( mode == "queued" ) then
			MiniMapLFGFrameDropDown.point = "BOTTOMRIGHT";
			MiniMapLFGFrameDropDown.relativePoint = "TOPLEFT";
			yOffset = 105;
		else
			MiniMapLFGFrameDropDown.point = nil;
			MiniMapLFGFrameDropDown.relativePoint = nil;
			yOffset = 110;
		end
		ToggleDropDownMenu(1, nil, MiniMapLFGFrameDropDown, "MiniMapLFGFrame", -60, yOffset);
	elseif ( mode == "proposal" ) then
		if ( not LFDDungeonReadyPopup:IsShown() ) then
			PlaySound("igCharacterInfoTab");
			StaticPopupSpecial_Show(LFDDungeonReadyPopup);
		end
	elseif ( mode == "queued" or mode == "rolecheck" ) then
		ToggleLFDParentFrame();
	elseif ( mode == "listed" ) then
		ToggleLFRParentFrame();
	end
end)

LFDSearchStatus:SetParent(MinimapBackdrop)
LFDSearchStatus:SetClearPoint('TOPRIGHT', MinimapBackdrop, 'TOPLEFT')

hooksecurefunc('CharacterMicroButton_SetPushed',function()
	MicroButtonPortrait:SetTexCoord(0,0,0,0);
	MicroButtonPortrait:SetAlpha(0);
end)

hooksecurefunc('CharacterMicroButton_SetNormal',function()
	MicroButtonPortrait:SetTexCoord(0,0,0,0);
	MicroButtonPortrait:SetAlpha(0);
end)

-- Latency bar functions temporarily disabled
-- These functions create a custom latency/performance bar below the Help micro button
-- Disabled to avoid visual conflicts 

--[[
function MainMenuMicroButtonMixin:OnUpdate(elapsed)
	local _, _, latencyHome = GetNetStats();
	local latency = latencyHome;
	if ( latency > PERFORMANCEBAR_MEDIUM_LATENCY ) then
		self:SetStatusBarColor(1, 0, 0);
	elseif ( latency > PERFORMANCEBAR_LOW_LATENCY ) then
		self:SetStatusBarColor(1, 1, 0);
	else
		self:SetStatusBarColor(0, 1, 0);
	end
end

function MainMenuMicroButtonMixin:CreateBar()
	local latencybar = CreateFrame('Statusbar', nil, UIParent)
	latencybar:SetParent(HelpMicroButton)
	latencybar:SetSize(14, 39)
	latencybar:SetPoint('BOTTOM', HelpMicroButton, 'BOTTOM', 0, -4)
	latencybar:SetStatusBarTexture(addon._dir..'ui-mainmenubar-performancebar')
	latencybar:SetStatusBarColor(1, 1, 0)
	latencybar:GetStatusBarTexture():SetBlendMode('ADD')
	latencybar:GetStatusBarTexture():SetDrawLayer('OVERLAY')
	latencybar:SetScript('OnUpdate', MainMenuMicroButtonMixin.OnUpdate)
end
MainMenuMicroButtonMixin:CreateBar();
--]]

local function CaptureOriginalHandlers(button)
    local buttonName = button:GetName()
    if not originalBlizzardHandlers[buttonName] then
        originalBlizzardHandlers[buttonName] = {
            OnEnter = button:GetScript('OnEnter'),
            OnLeave = button:GetScript('OnLeave')
        }
    end
end

-- Function to restore original handlers after texture modifications
local function RestoreOriginalHandlers(button)
    local buttonName = button:GetName()
    local handlers = originalBlizzardHandlers[buttonName]
    if handlers then
        if handlers.OnEnter then
            button:SetScript('OnEnter', handlers.OnEnter)
        end
        if handlers.OnLeave then
            button:SetScript('OnLeave', handlers.OnLeave)
        end
    end
end

local function setupMicroButtons(xOffset)
    local buttonxOffset = 0
    
    -- Get current configuration mode (grayscale or normal)
    local useGrayscale = addon.db.profile.micromenu.grayscale_icons
    local configMode = useGrayscale and "grayscale" or "normal"
    local config = addon.db.profile.micromenu[configMode]
    
    -- Use configuration-specific values
    local menuScale = config.scale_menu
    local xPosition = xOffset + config.x_position
    local yPosition = config.y_position
    local iconSpacing = config.icon_spacing
    
    -- Reuse existing frame or create new one
    local menu = _G.pUiMicroMenu
    if not menu then
        menu = CreateFrame('Frame', 'pUiMicroMenu', UIParent)
    end
    menu:SetScale(menuScale)
    menu:SetSize(10, 10)
    menu:ClearAllPoints()
    menu:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMRIGHT', xPosition, yPosition)
    
    for _,button in pairs(MICRO_BUTTONS) do
        local buttonName = button:GetName():gsub('MicroButton', '')
        local name = string.lower(buttonName);

        -- NUEVO: Capturar handlers originales ANTES de cualquier modificación
        CaptureOriginalHandlers(button)

        -- Store current button state before texture changes (with protection)
        local wasEnabled = button.IsEnabled and button:IsEnabled() or true
        local wasVisible = button.IsVisible and button:IsVisible() or true

        button:texture_strip()

        CharacterMicroButton:SetDisabledTexture'' -- doesn't exist by default

        button:SetParent(menu)
        -- button:SetScale(1.4)
        -- Set button size based on icon mode (grayscale vs colored)
        if useGrayscale then
            button:SetSize(14, 19)  -- Original size for grayscale icons
        else
            button:SetSize(32, 40)  -- Proper size for colored icons (matches ultimaversion)
        end
        -- Clear any existing points and set new position with current spacing
        button:ClearAllPoints()
        button:SetPoint('BOTTOMLEFT', menu, 'BOTTOMRIGHT', buttonxOffset, 55)
        button.SetPoint = addon._noop
        button:SetHitRectInsets(0,0,0,0)
        
        -- Ensure button remains interactive (with protection)
        button:EnableMouse(true)
        if button.SetEnabled and wasEnabled then 
            button:SetEnabled(true) 
        end
        if wasVisible then button:Show() end

        -- Check if we should use grayscale or colored icons
        local isCharacterButton = (buttonName == "Character")
        local isPVPButton = (buttonName == "PVP")
        
        -- Character button always uses grayscale (no color version available)
        -- PVP button has special handling with micropvp texture
        -- Also fallback to grayscale if no color coordinates are found
        local upCoords = not isCharacterButton and not isPVPButton and GetColoredTextureCoords(name, "Up") or nil
        local shouldUseGrayscale = useGrayscale or (not isPVPButton and not upCoords and not isCharacterButton)
        
        if shouldUseGrayscale then
            -- Use grayscale atlas (current system)
            local normalTexture = button:GetNormalTexture()
            local pushedTexture = button:GetPushedTexture()
            local disabledTexture = button:GetDisabledTexture()
            local highlightTexture = button:GetHighlightTexture()
            
            if normalTexture then normalTexture:set_atlas('ui-hud-micromenu-'..name..'-up-2x') end
            if pushedTexture then pushedTexture:set_atlas('ui-hud-micromenu-'..name..'-down-2x') end
            if disabledTexture then disabledTexture:set_atlas('ui-hud-micromenu-'..name..'-disabled-2x') end
            if highlightTexture then highlightTexture:set_atlas('ui-hud-micromenu-'..name..'-mouseover-2x') end
        elseif isPVPButton then
            -- Special handling for PVP button with faction-based micropvp texture
            SetupPVPButton(button)
         elseif isCharacterButton then
            -- Special handling for Character button with portrait
            local microTexture = 'Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\uimicromenu2x'
            local dx, dy = -1, 1
            local offX, offY = button:GetPushedTextOffset()
            local sizeX, sizeY = button:GetSize()
            
            -- Create portrait texture (ARTWORK layer, above background)
            if not button.DragonUIPortrait then
                button.DragonUIPortrait = button:CreateTexture('DragonUIPortrait', 'ARTWORK')
            end
            local portrait = button.DragonUIPortrait
            local portraitSize = 22
            portrait:SetSize(portraitSize, portraitSize)
            portrait:SetPoint('CENTER', 0.5, -0.5)
            SetPortraitTexture(portrait, 'player')
            
            -- CUSTOM HIGHLIGHT: Create circular highlight overlay
            if not button.DragonUIPortraitHighlight then
                button.DragonUIPortraitHighlight = button:CreateTexture('DragonUIPortraitHighlight', 'OVERLAY')
            end
            local highlightOverlay = button.DragonUIPortraitHighlight
            highlightOverlay:SetSize(portraitSize, portraitSize)
            highlightOverlay:SetPoint('CENTER', 0.5, -0.5)
            SetPortraitTexture(highlightOverlay, 'player')
            highlightOverlay:SetVertexColor(1.5, 1.5, 1.5, 0.4)
            highlightOverlay:SetBlendMode('ADD')
            highlightOverlay:Hide()
            
            -- Setup mouseover events for custom highlight
            local originalOnEnter = button:GetScript('OnEnter')
            local originalOnLeave = button:GetScript('OnLeave')
            
            button:SetScript('OnEnter', function(self)
                if originalOnEnter then originalOnEnter(self) end
                if self.DragonUIPortraitHighlight then
                    self.DragonUIPortraitHighlight:Show()
                end
            end)
            
            button:SetScript('OnLeave', function(self)
                if originalOnLeave then originalOnLeave(self) end
                if self.DragonUIPortraitHighlight then
                    self.DragonUIPortraitHighlight:Hide()
                end
            end)
            
            -- Add background for Character button (ONLY CREATE ONCE)
            if not button.DragonUIBackground then
                -- Background Normal
                local bg = button:CreateTexture('DragonUIBackground', 'BACKGROUND')
                bg:SetTexture(microTexture)
                bg:SetSize(sizeX, sizeY + 1)
                bg:SetTexCoord(0.0654297, 0.12793, 0.330078, 0.490234)
                bg:SetPoint('CENTER', dx, dy)
                button.DragonUIBackground = bg
                
                -- Background Pressed
                local bgPushed = button:CreateTexture('DragonUIBackgroundPushed', 'BACKGROUND')
                bgPushed:SetTexture(microTexture)
                bgPushed:SetSize(sizeX, sizeY + 1)
                bgPushed:SetTexCoord(0.0654297, 0.12793, 0.494141, 0.654297)
                bgPushed:SetPoint('CENTER', dx + offX, dy + offY)
                bgPushed:Hide()
                button.DragonUIBackgroundPushed = bgPushed
                
                -- State management
                button.dragonUIState = { pushed = false }
                
                button.HandleDragonUIState = function()
                    local state = button.dragonUIState
                    if state.pushed then
                        local subtleOffX, subtleOffY = offX * 0.3, offY * 0.3
                        portrait:SetPoint('CENTER', 0.5 + subtleOffX, -0.5 + subtleOffY)
                        portrait:SetAlpha(0.7)
                        highlightOverlay:SetPoint('CENTER', 0.5 + subtleOffX, -0.5 + subtleOffY)
                        bg:Hide()
                        bgPushed:Show()
                    else
                        portrait:SetPoint('CENTER', 0.5, -0.5)
                        portrait:SetAlpha(1.0)
                        highlightOverlay:SetPoint('CENTER', 0.5, -0.5)
                        bg:Show()
                        bgPushed:Hide()
                    end
                end
                
                -- Register events and scripts
                button:RegisterEvent('UNIT_PORTRAIT_UPDATE')
                button:SetScript('OnEvent', function(self, event, unit)
                    if event == 'UNIT_PORTRAIT_UPDATE' and unit == 'player' then
                        SetPortraitTexture(self.DragonUIPortrait, 'player')
                        SetPortraitTexture(self.DragonUIPortraitHighlight, 'player')
                    end
                end)
                
                button.dragonUITimer = 0
                button.dragonUILastState = false
                button:SetScript('OnUpdate', function(self, elapsed)
                    self.dragonUITimer = self.dragonUITimer + elapsed
                    if self.dragonUITimer >= 0.1 then
                        self.dragonUITimer = 0
                        local currentState = self:GetButtonState() == "PUSHED"
                        if currentState ~= self.dragonUILastState then
                            self.dragonUILastState = currentState
                            self.dragonUIState.pushed = currentState
                            self.HandleDragonUIState()
                        end
                    end
                end)
                
                button.HandleDragonUIState()
            end
			
			
		else
            -- Use colored icons from uimicromenu2x.blp
            local microTexture = 'Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\uimicromenu2x'
            
            -- Get coordinates for each state
            local downCoords = GetColoredTextureCoords(name, "Down") 
            local disabledCoords = GetColoredTextureCoords(name, "Disabled")
            local mouseoverCoords = GetColoredTextureCoords(name, "Mouseover")
            
            -- Set textures and coordinates with fallback protection
            if upCoords and #upCoords >= 4 then
                button:GetNormalTexture():SetTexture(microTexture)
                button:GetNormalTexture():SetTexCoord(upCoords[1], upCoords[2], upCoords[3], upCoords[4])
            end
            
            if downCoords and #downCoords >= 4 then
                button:GetPushedTexture():SetTexture(microTexture)
                button:GetPushedTexture():SetTexCoord(downCoords[1], downCoords[2], downCoords[3], downCoords[4])
            elseif upCoords and #upCoords >= 4 then
                -- Fallback to up state if down doesn't exist
                button:GetPushedTexture():SetTexture(microTexture)
                button:GetPushedTexture():SetTexCoord(upCoords[1], upCoords[2], upCoords[3], upCoords[4])
            end
            
            -- For colored icons, use their proper disabled state from the atlas
            if disabledCoords and #disabledCoords >= 4 then
                button:GetDisabledTexture():SetTexture(microTexture)
                button:GetDisabledTexture():SetTexCoord(disabledCoords[1], disabledCoords[2], disabledCoords[3], disabledCoords[4])
            elseif upCoords and #upCoords >= 4 then
                -- Fallback to up state if disabled doesn't exist
                button:GetDisabledTexture():SetTexture(microTexture)
                button:GetDisabledTexture():SetTexCoord(upCoords[1], upCoords[2], upCoords[3], upCoords[4])
            end
            
            if mouseoverCoords and #mouseoverCoords >= 4 then
                button:GetHighlightTexture():SetTexture(microTexture)
                button:GetHighlightTexture():SetTexCoord(mouseoverCoords[1], mouseoverCoords[2], mouseoverCoords[3], mouseoverCoords[4])
            elseif upCoords and #upCoords >= 4 then
                -- Fallback to up state if mouseover doesn't exist
                button:GetHighlightTexture():SetTexture(microTexture)
                button:GetHighlightTexture():SetTexCoord(upCoords[1], upCoords[2], upCoords[3], upCoords[4])
            end
            
            -- SPECIAL HANDLING FOR MAINMENU BUTTON: Preserve game stats tooltip
            if buttonName == "MainMenu" then
                -- For MainMenuMicroButton, we must preserve the original handlers
                -- because they handle the game statistics tooltip display
                -- DON'T set new OnEnter/OnLeave - keep the originals completely intact
                
                -- Skip setting new handlers - the original ones are already captured
                -- and will be restored by RestoreOriginalHandlers() below
            end
            
            -- Add background for colored icons (same as PVP button)
            -- Only create if it doesn't exist to prevent duplication
            if not button.DragonUIBackground then
                local backgroundTexture = 'Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\uimicromenu2x'
                local dx, dy = -1, 1
                local offX, offY = button:GetPushedTextOffset()
                local sizeX, sizeY = button:GetSize()
                
                -- Background Normal (uses DOWN coords, fixed position) - like ultimaversion
                local bg = button:CreateTexture('DragonUIBackground', 'BACKGROUND')
                bg:SetTexture(backgroundTexture)
                bg:SetSize(sizeX, sizeY + 1)
                bg:SetTexCoord(0.0654297, 0.12793, 0.330078, 0.490234)  -- ButtonBG-Down (CORRECTED)
                bg:SetPoint('CENTER', dx, dy)
                button.DragonUIBackground = bg
                
                -- Background Pressed (uses UP coords, offset position) - like ultimaversion
                local bgPushed = button:CreateTexture('DragonUIBackgroundPushed', 'BACKGROUND')
                bgPushed:SetTexture(backgroundTexture)
                bgPushed:SetSize(sizeX, sizeY + 1)
                bgPushed:SetTexCoord(0.0654297, 0.12793, 0.494141, 0.654297)  -- ButtonBG-Up (CORRECTED)
                bgPushed:SetPoint('CENTER', dx + offX, dy + offY)
                bgPushed:Hide()
                button.DragonUIBackgroundPushed = bgPushed
                
            end
            
            -- State management for background switching
            button.dragonUIState = {}
            button.dragonUIState.pushed = false
            
            button.HandleDragonUIState = function()
                local state = button.dragonUIState
                if state.pushed then
                    button.DragonUIBackground:Hide()
                    button.DragonUIBackgroundPushed:Show()
                else
                    button.DragonUIBackground:Show()
                    button.DragonUIBackgroundPushed:Hide()
                end
            end
            button.HandleDragonUIState()
                
                -- Simple state management without hooks (WOTLK 3.3.5a compatible)
                -- We'll use a timer to check button state periodically
                button.dragonUITimer = 0
                button.dragonUILastState = false
                
                -- Create OnUpdate handler for state checking
                -- EXCEPTION: Do not apply this to MainMenu button to preserve its stats tooltip
                if buttonName ~= "MainMenu" then
                    button:SetScript('OnUpdate', function(self, elapsed)
                        self.dragonUITimer = self.dragonUITimer + elapsed
                        if self.dragonUITimer >= 0.1 then  -- Check every 0.1 seconds
                            self.dragonUITimer = 0
                            local currentState = self:GetButtonState() == "PUSHED"
                            if currentState ~= self.dragonUILastState then
                                self.dragonUILastState = currentState
                                self.dragonUIState.pushed = currentState
                                self.HandleDragonUIState()
                            end
                        end
                    end)
                end
            end
        
        -- Ensure highlight texture properties are properly set for interactivity
        local highlightTexture = button:GetHighlightTexture()
        if highlightTexture then
            highlightTexture:SetBlendMode('ADD')
            highlightTexture:SetAlpha(1) -- Ensure it's visible on hover
        end
        
        -- Restore button interactivity after texture changes (with protection)
        button:EnableMouse(true)
        if button.SetEnabled and wasEnabled then 
            button:SetEnabled(true) 
        end
        -- MODIFIED: Restore original handlers for all buttons EXCEPT CharacterMicroButton
        if buttonName ~= "Character" then
            RestoreOriginalHandlers(button)
        end
        

        buttonxOffset = buttonxOffset + iconSpacing
end

-- Function to update only button spacing without full setup
local function updateMicroButtonSpacing()
	if not _G.pUiMicroMenu then return end
	
	-- Get current configuration mode
	local useGrayscale = addon.db.profile.micromenu.grayscale_icons
	local configMode = useGrayscale and "grayscale" or "normal"
	local config = addon.db.profile.micromenu[configMode]
	local iconSpacing = config.icon_spacing
	
	-- Reposition all buttons with new spacing
	local buttonxOffset = 0
	for _,button in pairs(MICRO_BUTTONS) do
		button:ClearAllPoints()
		button:SetPoint('BOTTOMLEFT', _G.pUiMicroMenu, 'BOTTOMRIGHT', buttonxOffset, 55)
		buttonxOffset = buttonxOffset + iconSpacing
	end
end

-- Expose function for options to use
function addon.RefreshMicromenuSpacing()
	updateMicroButtonSpacing()
end

-- Function to update only micromenu position and scale (OPTIMIZED)
function addon.RefreshMicromenuPosition()
	if not _G.pUiMicroMenu then return end
	
	-- Get current configuration mode
	local useGrayscale = addon.db.profile.micromenu.grayscale_icons
	local configMode = useGrayscale and "grayscale" or "normal"
	local config = addon.db.profile.micromenu[configMode]
	
	-- Update position and scale of the container
	local microMenu = _G.pUiMicroMenu
	microMenu:SetScale(config.scale_menu);
	local xOffset = IsAddOnLoaded('ezCollections') and -180 or -166
	microMenu:ClearAllPoints();
	microMenu:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMRIGHT', 
		xOffset + config.x_position, 
		config.y_position);
	
	-- CRITICAL: Also update button spacing since scale/position affects button layout
	updateMicroButtonSpacing();
end


-- Function to update only bags position and scale
function addon.RefreshBagsPosition()
	-- Safety checks
	if not addon.db or not addon.db.profile or not addon.db.profile.bags then
		return
	end
	
	if not _G.pUiBagsBar then
		return
	end
	
	-- Get configuration
	local bagsConfig = addon.db.profile.bags
	
	-- Set the container scale (for consistency)
	_G.pUiBagsBar:SetScale(bagsConfig.scale)
	
	-- Move the main bag button directly with the user's offset values
	-- Temporarily restore SetPoint functionality
	local originalSetPoint = MainMenuBarBackpackButton.SetPoint
	if MainMenuBarBackpackButton.SetPoint == addon._noop then
		MainMenuBarBackpackButton.SetPoint = UIParent.SetPoint
	end
	
	-- Move the main bag button to the new position
	MainMenuBarBackpackButton:ClearAllPoints()
	MainMenuBarBackpackButton:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT', 
		bagsConfig.x_position, 
		bagsConfig.y_position)
	
	-- Restore the disabled SetPoint
	if originalSetPoint == addon._noop then
		MainMenuBarBackpackButton.SetPoint = originalSetPoint
	end
end


-- Function to update vehicle visibility for micromenu only
function addon.RefreshMicromenuVehicle()
	if not _G.pUiMicroMenu then return end
	
	if addon.db.profile.micromenu.hide_on_vehicle then
		RegisterStateDriver(_G.pUiMicroMenu, 'visibility', '[vehicleui] hide;show')
	else
		UnregisterStateDriver(_G.pUiMicroMenu, 'visibility')
	end
end


-- Function to update vehicle visibility for bags only
function addon.RefreshBagsVehicle()
	if not _G.pUiBagsBar then return end
	
	if addon.db.profile.micromenu.hide_on_vehicle then
		RegisterStateDriver(_G.pUiBagsBar, 'visibility', '[vehicleui] hide;show')
	else
		UnregisterStateDriver(_G.pUiBagsBar, 'visibility')
	end
end

-- Simple function to refresh only micromenu icons (for grayscale option)
function addon.RefreshMicromenuIcons()
end
end

addon.package:RegisterEvents(function()
    local xOffset
    if IsAddOnLoaded('ezCollections') then
        xOffset = -180
        _G.CollectionsMicroButton:UnregisterEvent('UPDATE_BINDINGS')
    else
        xOffset = -166
    end
    
    -- ELIMINADO: El posicionamiento inicial se delega a addon.RefreshBags()
    -- para evitar redundancia y asegurar la posición correcta.
    
    setupMicroButtons(xOffset);
    
    -- Initial bags setup with new configuration
    if addon.RefreshBags then
        addon.RefreshBags();
    end
end, 'PLAYER_LOGIN'
);

-- Complete refresh function for micromenu
function addon.RefreshMicromenu()
	-- Safety checks for database and frame availability
	if not addon.db or not addon.db.profile or not addon.db.profile.micromenu then
		return
	end
	
	if not _G.pUiMicroMenu then
		return
	end
	
	-- Get current configuration mode
	local useGrayscale = addon.db.profile.micromenu.grayscale_icons
	local configMode = useGrayscale and "grayscale" or "normal"
	local config = addon.db.profile.micromenu[configMode]
	
	-- Apply changes directly
	_G.pUiMicroMenu:SetScale(config.scale_menu)
	_G.pUiMicroMenu:ClearAllPoints()
	local xOffset = IsAddOnLoaded('ezCollections') and -180 or -166
	_G.pUiMicroMenu:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMRIGHT', 
		xOffset + config.x_position, 
		config.y_position)
	
	-- Update icons
	addon.RefreshMicromenuIcons()
	
	-- Update button spacing with proper SetPoint restoration
	local buttonxOffset = 0
	for _,button in pairs(MICRO_BUTTONS) do
		-- Temporarily restore SetPoint functionality
		local originalSetPoint = button.SetPoint
		if button.SetPoint == addon._noop then
			button.SetPoint = UIParent.SetPoint
		end
		
		-- Apply new spacing
		button:ClearAllPoints()
		button:SetPoint('BOTTOMLEFT', _G.pUiMicroMenu, 'BOTTOMRIGHT', buttonxOffset, 55)
		
		-- Restore disabled SetPoint
		if originalSetPoint == addon._noop then
			button.SetPoint = originalSetPoint
		end
		
		buttonxOffset = buttonxOffset + config.icon_spacing
	end
	
	-- Update vehicle visibility
	addon.RefreshMicromenuVehicle()
end

-- Separate refresh function for bags configuration changes
-- This function should ONLY handle bags, NOT micromenu
function addon.RefreshBags()
	if not _G.pUiBagsBar then return end
	
	-- FIRST: Update bags scale and position
	addon.RefreshBagsPosition();
	
	-- THEN: Refresh bag styling (without repositioning)
	if MainMenuMicroButtonMixin.bagbuttons_refresh then
		MainMenuMicroButtonMixin:bagbuttons_refresh();
	end
	
	-- DON'T call bagbuttons_reposition() here - it would undo our positioning
	
	-- Refresh the collapse arrow's state to match the database
	if addon.pUiArrowManager then
		local arrow = addon.pUiArrowManager
		local isCollapsed = GetBagCollapseState()
		local normal = arrow:GetNormalTexture()
		local pushed = arrow:GetPushedTexture()
		local highlight = arrow:GetHighlightTexture()

		if isCollapsed then
			normal:set_atlas('bag-arrow-2x')
			pushed:set_atlas('bag-arrow-2x')
			highlight:set_atlas('bag-arrow-2x')
			arrow:SetChecked(true)
		else
			normal:set_atlas('bag-arrow-invert-2x')
			pushed:set_atlas('bag-arrow-invert-2x')
			highlight:set_atlas('bag-arrow-invert-2x')
			arrow:SetChecked(nil)
		end
	end
	
	-- CRITICAL: Apply the saved collapse state to the actual bag positions
	-- This ensures bags are positioned correctly when loading the game
	MainMenuMicroButtonMixin:bagbuttons_reposition()
	
	-- Update vehicle visibility for bags
	addon.RefreshBagsVehicle();
end

-- Reanchor LFD (Looking For Dungeon) search status frame
local function ReanchorLFDStatus()
	if not LFDSearchStatus or not MiniMapLFGFrame then return end
	LFDSearchStatus:ClearAllPoints()
	LFDSearchStatus:SetPoint("BOTTOM", MiniMapLFGFrame, "TOP", 0, 30)
end

ReanchorLFDStatus()
hooksecurefunc("LFDSearchStatus_Update", ReanchorLFDStatus)

