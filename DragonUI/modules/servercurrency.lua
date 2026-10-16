-- Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- Currencies a server keeps for the player outside the bags (an account-wide balance, say). They
-- are not items the character carries, so Blizzard's currency list never sees them; a server
-- module whispers them to the player as addon messages instead:
--
--   server -> client   S:<itemID>:<count>:<section>:<name>   set one, listed under heading <section>
--                      D:<itemID>                            drop one
--   client -> server   HELLO                                 send every one again
--
-- HELLO goes out on the first PLAYER_ENTERING_WORLD of each UI load, login and /reload alike.
-- The item id gives a row its icon, tooltip and chat link; <name> stands in until the item is in
-- the cache.
-- The Currency tab (characterpanel/currencypane.lua) and the Bagster token bar read them from here.

local PREFIX = "DUI_CURRENCY"

local SC = {}
addon.ServerCurrency = SC

-- In the order they first arrived: { itemID, count, section, name }
local rows = {}
local listeners = {}

local function changed()
    for _, fn in ipairs(listeners) do fn() end
end

local function find(itemID)
    for i, row in ipairs(rows) do
        if row.itemID == itemID then return i, row end
    end
end

-- `fn` runs whenever a row arrives, changes, goes, or is ticked for the backpack.
function SC.OnChange(fn)
    listeners[#listeners + 1] = fn
end

function SC.Rows()
    return rows
end

function SC.Name(row)
    return GetItemInfo(row.itemID) or row.name
end

-- GetItemIcon reads Item.dbc, so it answers even for an item the client has not cached yet.
function SC.Icon(row)
    return GetItemIcon(row.itemID)
end

-- Ticked for the backpack: account-wide, like the balances these usually are.
function SC.IsWatched(itemID)
    local store = addon.db and addon.db.global and addon.db.global.serverCurrencyWatched
    return store and store[itemID] and true or false
end

function SC.SetWatched(itemID, watched)
    local store = addon.db and addon.db.global and addon.db.global.serverCurrencyWatched
    if not store then return end
    store[itemID] = watched and true or nil
    changed()
end

-- The rows ticked for the backpack, in list order.
function SC.Watched()
    local list = {}
    for _, row in ipairs(rows) do
        if SC.IsWatched(row.itemID) then list[#list + 1] = row end
    end
    return list
end

local function onMessage(msg)
    local itemID, count, section, name = msg:match("^S:(%d+):(%d+):([^:]*):(.*)$")
    if itemID then
        itemID = tonumber(itemID)
        local _, row = find(itemID)
        if not row then
            row = { itemID = itemID }
            rows[#rows + 1] = row
        end
        row.count, row.section, row.name = tonumber(count), section, name
        changed()
        return
    end

    itemID = tonumber(msg:match("^D:(%d+)$"))
    local index = itemID and find(itemID)
    if index then
        table.remove(rows, index)
        changed()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent", function(_, event, prefix, msg, channel, sender)
    if event == "PLAYER_ENTERING_WORLD" then
        events:UnregisterEvent("PLAYER_ENTERING_WORLD")
        SendAddonMessage(PREFIX, "HELLO", "WHISPER", UnitName("player"))
    elseif prefix == PREFIX and channel == "WHISPER" and sender == UnitName("player") then
        onMessage(msg)
    end
end)
