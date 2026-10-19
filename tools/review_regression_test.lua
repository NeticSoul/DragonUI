-- Run from the repository root with Lua 5.1. Mocks exercise server acknowledgements and failures.
strmatch = string.match
local function loadAddon(path, addon) assert(loadfile(path))('DragonUI', addon) end
local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}; for k, v in pairs(value) do result[k] = copy(v) end; return result
end
function wipe(t) for k in pairs(t) do t[k] = nil end; return t end
function strtrim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end
local function upvalue(fn, name)
    for i = 1, 100 do
        local key, value = debug.getupvalue(fn, i)
        if not key then break end
        if key == name then return value end
    end
    error('Missing test entry point: ' .. name)
end
local function frames()
    local made = {}
    function CreateFrame()
        local f = { scripts = {}, events = {} }
        function f:SetScript(k, fn) self.scripts[k] = fn end
        function f:RegisterEvent(k) self.events[k] = true end
        function f:UnregisterAllEvents() wipe(self.events) end
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false end
        function f:IsShown() return self.shown end
        made[#made + 1] = f
        return f
    end
    return made
end
local L = setmetatable({}, { __index = function(_, k) return k end })

-- Validate actual exported/imported payloads, not just a synthetic validation helper.
assert(loadfile('DragonUI/libs/LibStub/LibStub.lua'))()
assert(loadfile('DragonUI/libs/AceSerializer-3.0/AceSerializer-3.0.lua'))()
assert(loadfile('DragonUI/libs/LibDeflate/LibDeflate.lua'))()
StaticPopupDialogs = {}
local addon = { L = L, DeepCopy = copy, EditableFrames = {} }
loadAddon('DragonUI/database.lua', addon)
addon.db = { profile = copy(addon.defaults.profile) }
loadAddon('DragonUI/core/position_presets.lua', addon)
local presets = addon.PositionPresets
local original = presets:Snapshot()
assert(presets:ValidateSnapshot(original), 'Real default positions must remain compatible')
local serializer = {}; LibStub('AceSerializer-3.0'):Embed(serializer)
local deflate = LibStub('LibDeflate')
local function code(data)
    return '!DUIPP1!' .. deflate:EncodeForPrint(deflate:CompressDeflate(serializer:Serialize(data)))
end
assert(presets:ImportFromString(code(original)))
local oldX = addon.db.profile.questtracker.x
local invalid = {
    { version = 1, questtracker = { x = 5 }, unitframe = { tot = true } },
    { version = 1, questtracker = { anchor = 'WRONG' } },
    { version = 1, widgets = { target = { posX = 'bad' } } },
    { version = 1, castbar = { target = { anchorFrame = 'MissingFrame' } } },
    { version = 1, additional = { stance = { manual_position = 1 } } },
    { version = 1, questtracker = { x = math.huge } },
    { version = 1, questtracker = { x = 0/0 } },
}
for _, data in ipairs(invalid) do
    assert(not presets:Restore(data))
    assert(addon.db.profile.questtracker.x == oldX, 'Invalid restore mutated the profile')
end
assert(not presets:ImportFromString(code(invalid[1])), 'Malformed nested import accepted')
local combat = true
function InCombatLockdown() return combat end
addon.db.profile.positionPresets = { test = { data = { version = 1, questtracker = { x = 55 } } } }
assert(not presets:Load('test'))
assert(addon.db.profile.questtracker.x == oldX, 'Combat load mutated positions')
combat = false
local profile = addon.db.profile
presets.Apply = function() error('simulated frame failure') end
presets.ApplyStoredPositions = function() return true end
assert(not presets:Load('test'))
assert(addon.db.profile == profile and profile.questtracker.x == oldX, 'Failed apply did not roll back')
print('presets: default round trip, malformed imports, no partial writes, combat and rollback passed')

-- Vendor calls may succeed in Lua while being rejected by the server.
local made = frames()
local timers, messages, bag, money, requests = {}, {}, {}, 0, 0
local mode, repairs = 'delayed', 0
MerchantFrame = { selectedTab = 1, IsShown = function() return true end }
NUM_BAG_SLOTS = 0
function GetContainerNumSlots() return 5 end
function GetContainerItemLink(_, slot) return bag[slot] and bag[slot].link end
function GetContainerItemInfo(_, slot)
    local item = bag[slot]; if item then return nil, item.count, item.locked end
end
function GetItemInfo(link)
    local price = 100
    if link:find('item:999',1,true) then price = nil end
    if link:find('item:888',1,true) then price = 0 end
    return nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,price
end
function GetMoney() return money end
function GetMoneyString(n) return tostring(n) end
local grey = '|cff9d9d9d|Hitem:1|h[Junk]|h|r'
function UseContainerItem(_, slot)
    requests = requests + 1
    if mode == 'delayed' then
        timers[#timers + 1] = function()
            local item = bag[slot]; money = money + item.count * 100; bag[slot] = nil
        end
    elseif mode == 'removed-unpaid' then bag[slot] = nil end
end
local function flush()
    local count = 0
    while #timers > 0 do
        count = count + 1; assert(count < 500, 'unbounded vendor polling')
        table.remove(timers, 1)()
    end
end
addon = { merchantParts = { localized = function(s) return s end },
    After = function(_, _, fn) timers[#timers + 1] = fn end,
    Print = function(_, text) messages[#messages + 1] = text end }
loadAddon('DragonUI/modules/merchant/sell_junk.lua', addon)
local sell = addon.merchantParts.sellEveryJunkItem
bag = { {link=grey,count=3}, {link=grey,count=2,locked=true},
    {link=grey:gsub('item:1','item:999'),count=1}, {link=grey:gsub('item:1','item:888'),count=1} }
local complete = false
assert(sell(function() complete = true end))
assert(not sell(), 'Parallel sale started')
assert(#messages == 0 and not complete, 'Sale counted before acknowledgement')
flush()
assert(requests == 1 and money == 300 and #messages == 1 and complete)
assert(messages[1] == 'Sold 3 junk item(s) for 300.')
for _, failure in ipairs({'rejected','removed-unpaid'}) do
    mode, requests, messages = failure, 0, {}
    bag = { {link=grey,count=3} }
    assert(sell()); flush()
    assert(requests == 1 and #messages == 1 and messages[1]:find('could not be confirmed',1,true), 'Unconfirmed sale counted or notice missing')
end
-- One failed/uncertain stack must not suppress the rest, including when money is spent concurrently.
local originalUse = UseContainerItem
for _, outcome in ipairs({'rejected', 'spent-payment'}) do
    mode, requests, messages = 'delayed', 0, {}
    bag = { {link=grey,count=3}, {link=grey,count=1} }
    money = 0
    function UseContainerItem(bagID, slot)
        if slot == 1 then
            requests = requests + 1
            if outcome == 'spent-payment' then bag[slot] = nil end -- payment is immediately spent on repairs
        else originalUse(bagID, slot) end
    end
    assert(sell()); flush()
    assert(requests == 2 and bag[2] == nil, 'Uncertain stack abandoned the remaining queue')
    assert(#messages == 2 and messages[1] == 'Sold 1 junk item(s) for 100.'
        and messages[2]:find('could not be confirmed',1,true), 'Mixed confirmation totals were wrong')
end
UseContainerItem = originalUse
mode, requests, messages = 'delayed', 0, {}
bag = { {link=grey,count=3} }
assert(sell()); made[1].scripts.OnEvent(made[1], 'MERCHANT_CLOSED')
-- A late payment may still arrive, but must not restart a previous merchant session.
flush(); assert(requests == 1 and #messages == 0)
-- Auto-repair waits for completed sales and does not act after a visit closes.
local finish
addon.merchantParts.sellEveryJunkItem = function(callback) finish = callback; return true end
function addon:IsModuleEnabled() return true end
function addon:GetModuleConfig() return { autoSellJunk=true, autoRepair=true } end
function CanMerchantRepair() return true end
function GetRepairAllCost() return 50, true end
function RepairAllItems() repairs = repairs + 1 end
loadAddon('DragonUI/modules/merchant/auto_services.lua', addon)
local services = made[2]
services.scripts.OnEvent(services,'MERCHANT_SHOW'); assert(repairs == 0)
finish(); assert(repairs == 1)
services.scripts.OnEvent(services,'MERCHANT_SHOW')
services.scripts.OnEvent(services,'MERCHANT_CLOSED'); finish(); assert(repairs == 1)
timers = {}
print('merchant: delayed payment, locked items, rejected sales, close cancellation and repair sequencing passed')

-- Load the whole mail module; reach its existing Open All closure without exporting test-only APIs.
made = frames()
addon = { L=L, _dir='', IsModuleEnabled=function() return true end }
local letters, takes = {}, {}
ERR_INV_FULL, ERR_ITEM_MAX_COUNT, ERR_TOO_MUCH_GOLD = 'full','unique','gold cap'
MailFrame = { IsShown=function() return true end }
function GetInboxNumItems() return #letters, #letters end
function GetInboxHeaderInfo(i)
    local m = letters[i]; if not m then return end
    return nil,nil,'Sender'..i,'Subject'..i,m.money or 0,m.cod or 0,nil,m.item and 1 or 0,true,nil,nil,nil,m.gm
end
function GetInboxItem(i, slot) if slot == 1 then return letters[i] and letters[i].item end end
function GetInboxText() end
function GetContainerNumFreeSlots() return 0, 0 end
function CheckInbox() end
local looter
function TakeInboxItem(i)
    takes[i] = (takes[i] or 0) + 1
    if letters[i].error then looter.scripts.OnEvent(looter,'UI_ERROR_MESSAGE',letters[i].error)
    else letters[i].item = nil end
end
function TakeInboxMoney(i) letters[i].money = 0; takes.money = (takes.money or 0) + 1 end
loadAddon('DragonUI/modules/mail.lua', addon)
looter = made[1]
local start = upvalue(upvalue(addon.ApplyMailSystem,'buildMailFrame'),'StartOpenAll')
letters = { {money=50}, {item='Fits partial stack'}, {item='Fits herb bag'},
    {item='Cannot fit',error=ERR_INV_FULL}, {item='COD',cod=100}, {item='GM',gm=true} }
start()
for i=1,100 do if looter.shown then looter.scripts.OnUpdate(looter,0.1) end end
assert(not looter.shown)
assert(not letters[2].item and not letters[3].item and letters[4].item)
assert(letters[1].money == 0 and takes.money == 1 and takes[4] == 1)
assert(not takes[5] and not takes[6], 'COD or GM mail touched')
letters, takes = { {item='Unique',error=ERR_ITEM_MAX_COUNT}, {item='Delayed'} }, {}
letters[2].error = 'unhandled error'
start()
for i=1,100 do if looter.shown then looter.scripts.OnUpdate(looter,0.1) end end
assert(takes[2] == 1 and takes[1] == 1, 'Timed-out or unique attachment retried')
letters, takes = { {item='Close pending',error='unhandled error'} }, {}
start(); looter.scripts.OnUpdate(looter,0.1)
looter.scripts.OnEvent(looter,'MAIL_CLOSED')
assert(not looter.shown and takes[1] == 1)
print('mail: full bags, stack/specialty acceptance, capacity errors, COD/GM skips, timeout and close passed')
