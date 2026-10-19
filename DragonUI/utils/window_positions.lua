-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
local addon = select(2, ...)
local Windows = { frames = {} }
addon.WindowPositions = Windows
local max, min = math.max, math.min

local function store()
    local profile = addon.db and addon.db.profile
    if not profile then return end
    if type(profile.windowPositions) ~= 'table' then profile.windowPositions = {} end
    return profile.windowPositions
end

local function keyFor(record)
    return type(record.key) == 'function' and record.key(record.frame) or record.key
end

local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < math.huge
end

local function blocked(frame)
    return InCombatLockdown() and frame:IsProtected()
end

local function ratio(frame)
    return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

function Windows:Save(frame)
    local record, positions = self.frames[frame], store()
    if not record or not positions then return end
    local x, y = frame:GetCenter()
    if not x or not y then return end
    local scale = ratio(frame)
    positions[keyFor(record)] = {
        x = max(0, min(1, x * scale / UIParent:GetWidth())),
        y = max(0, min(1, y * scale / UIParent:GetHeight())),
    }
end

-- Keep Blizzard's panel registration and close callbacks. Only a window the player
-- moved is restored after layout; no frame methods or UIPanel attributes are replaced.
function Windows:Restore(frame)
    local record, positions = self.frames[frame], store()
    if not record or record.dragging or record.restoring or not positions or blocked(frame)
        or not frame:IsShown() then return end
    local spot = positions[keyFor(record)]
    if type(spot) ~= 'table' or not finite(spot.x) or not finite(spot.y) then return end
    local scale = ratio(frame)
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local halfW, halfH = min(w / 2, frame:GetWidth() * scale / 2), min(h / 2, frame:GetHeight() * scale / 2)
    local x = max(halfW, min(w - halfW, spot.x * w))
    local y = max(halfH, min(h - halfH, spot.y * h))
    record.restoring = true
    frame:ClearAllPoints()
    frame:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', x / scale, y / scale)
    record.restoring = nil
end

function Windows:Reset(frame)
    if InCombatLockdown() then return false end
    local record, positions = self.frames[frame], store()
    if not record or not positions then return false end
    if record.dragging then record.stop() end
    positions[keyFor(record)] = nil
    frame:ClearAllPoints()
    for _, point in ipairs(record.defaults) do frame:SetPoint(unpack(point)) end
    if record.onReset then record.onReset() end
    if frame:IsShown() and UIPanelWindows[frame:GetName()] then UpdateUIPanelPositions(frame) end
    return true
end

function Windows:ResetAll()
    if InCombatLockdown() then
        addon:Print(addon.L['Cannot move frames during combat!'])
        return false
    end
    local positions = store()
    if not positions then return false end
    wipe(positions) -- Includes late-loaded windows and bag IDs not currently visible.
    for frame in pairs(self.frames) do self:Reset(frame) end
    return true
end

local function placeHandle(record, options)
    local parent, anchor = options.parent or record.frame, options.anchor or record.frame
    local handle = record.handle
    handle:SetParent(parent)
    handle:ClearAllPoints()
    handle:SetPoint('TOPLEFT', anchor, 'TOPLEFT', 40, -1)
    handle:SetPoint('TOPRIGHT', anchor, 'TOPRIGHT', -42, -1)
    handle:SetHeight(20)
    handle:SetFrameLevel(parent:GetFrameLevel() + 40)
end

function Windows:Register(frame, key, options)
    if not frame or InCombatLockdown() then return end
    options = options or {}
    if self.frames[frame] then
        if options.parent or options.anchor then placeHandle(self.frames[frame], options) end
        return
    end
    local record = { frame = frame, key = key, defaults = {}, onReset = options.onReset }
    for i = 1, frame:GetNumPoints() do record.defaults[i] = { frame:GetPoint(i) } end
    local originalStart, originalStop = frame:GetScript('OnDragStart'), frame:GetScript('OnDragStop')
    local function start()
        if InCombatLockdown() or record.dragging then return end
        record.dragging = true
        if originalStart then originalStart(frame) else frame:StartMoving() end
    end
    local function stop(save)
        if not record.dragging or blocked(frame) then return end
        if originalStop then originalStop(frame) end
        frame:StopMovingOrSizing()
        frame:SetUserPlaced(false) -- SavedVariables owns persistence, not layout-local.txt.
        record.dragging = nil
        if save ~= false then Windows:Save(frame) end
        Windows:Restore(frame)
    end
    record.stop = stop
    self.frames[frame] = record
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    -- Keep native drag state (spellbook/talent scaling and click catchers) working.
    frame:SetScript('OnDragStart', start)
    frame:SetScript('OnDragStop', function() stop() end)
    local handle = CreateFrame('Frame', nil, options.parent or frame)
    handle:EnableMouse(true)
    handle:RegisterForDrag('LeftButton')
    handle:SetScript('OnDragStart', start)
    handle:SetScript('OnDragStop', function() stop() end)
    handle:SetScript('OnMouseUp', function(_, button)
        stop()
        if button == 'RightButton' and IsAltKeyDown() then Windows:Reset(frame) end
    end)
    handle:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        GameTooltip:SetText(addon.L['Drag to move. Alt-right-click to reset this window.'])
        GameTooltip:Show()
    end)
    handle:SetScript('OnLeave', GameTooltip_Hide)
    record.handle = handle
    placeHandle(record, options)
    frame:HookScript('OnHide', function() stop() end)
    frame:HookScript('OnShow', function() Windows:Restore(frame) end)
    -- Other panels can re-anchor an already open window without firing OnShow.
    hooksecurefunc(frame, 'SetPoint', function() Windows:Restore(frame) end)
    self:Restore(frame)
end

local PANEL_NAMES = {
    'CharacterFrame', 'SpellBookFrame', 'PlayerTalentFrame', 'QuestLogFrame', 'QuestLogDetailFrame',
    'QuestFrame', 'GossipFrame', 'MerchantFrame', 'MailFrame', 'BankFrame', 'FriendsFrame',
    'TradeFrame', 'TradeSkillFrame', 'CraftFrame', 'ClassTrainerFrame', 'AuctionFrame',
    'GuildBankFrame', 'AchievementFrame', 'InspectFrame', 'DressUpFrame', 'TaxiFrame',
    'ItemTextFrame', 'PetStableFrame', 'LFDParentFrame', 'LFRParentFrame', 'PVPParentFrame',
    'MacroFrame', 'CalendarFrame', 'ItemSocketingFrame',
}

function Windows:Scan()
    if InCombatLockdown() then return end
    for _, name in ipairs(PANEL_NAMES) do
        local frame = _G[name]
        local professions = name == 'TradeSkillFrame' and addon.Professions and addon.Professions.Frame
        -- Wait until the professions chrome is built, otherwise use the stock title bar.
        if not (name == 'TradeSkillFrame' and addon.Professions and addon.Professions.active and (not professions or not professions.built)) then
            self:Register(frame, name, professions and professions.built and { parent = professions.chrome, anchor = professions.win } or nil)
        end
    end
    self:Register(_G.DragonUIGuildFrame, 'DragonUIGuildFrame')
    self:Register(_G.DragonUICollectionsFrame, 'DragonUICollectionsFrame')
    self:Register(_G.DragonUI_TalentFrame, 'DragonUI_TalentFrame', { onReset = function()
        local ns = addon.TalentModule and addon.TalentModule.ns
        if ns then ns.moved = false; ns.ApplyScale() end
    end })
    self:Register(_G.DragonUI_SpellbookFrame, 'DragonUI_SpellbookFrame', { onReset = function()
        local book = addon.SpellbookModule
        if book then book.position = nil; book.ApplyScale() end
    end })
    -- ContainerFrame numbers are pooled; the bag ID, not the frame name, owns its position.
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        self:Register(_G['ContainerFrame' .. i], function(frame) return 'bag:' .. frame:GetID() end)
    end
end

local events = CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN')
events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:RegisterEvent('DISPLAY_SIZE_CHANGED')
events:RegisterEvent('UI_SCALE_CHANGED')
local queued
local function refresh()
    queued = nil
    Windows:Scan()
    for frame, record in pairs(Windows.frames) do
        if record.dragging then record.stop() end
        Windows:Restore(frame)
    end
end
events:SetScript('OnEvent', function(_, event)
    if event == 'PLAYER_LOGIN' and addon.db and addon.db.RegisterCallback then
        local function profileChanged()
            if InCombatLockdown() then
                addon.CombatQueue:Add('window_profile', profileChanged)
                return
            end
            local positions = store()
            for frame, record in pairs(Windows.frames) do
                if record.dragging then record.stop(false) end
                if not positions[keyFor(record)] then Windows:Reset(frame) end
                Windows:Restore(frame)
            end
        end
        addon.db.RegisterCallback(Windows, 'OnProfileChanged', profileChanged)
        addon.db.RegisterCallback(Windows, 'OnProfileCopied', profileChanged)
        addon.db.RegisterCallback(Windows, 'OnProfileReset', profileChanged)
    end
    if not queued then queued = true; addon:After(0, refresh) end
end)
if ShowUIPanel then hooksecurefunc('ShowUIPanel', function(frame)
    Windows:Scan()
    Windows:Restore(frame)
end) end
