-- Run with Lua 5.1 from the repository root.
local addon = {}
local frame = {}
function frame:RegisterEvent() end
function frame:SetScript() end
function CreateFrame() return frame end
assert(loadfile('DragonUI/modules/achievement_rewards.lua'))('DragonUI', addon)
assert(loadfile('DragonUI/modules/achievement_search.lua'))('DragonUI', addon)
local match = addon.AchievementSearchMatches
assert(match({id=2136, name='Glory of the Hero', reward='Red Proto-Drake'}, 'MOUNTS'))
assert(match({id=2136, name='Glory of the Hero', reward='Red Proto-Drake'}, 'mount red'))
assert(not match({id=99999, name='Mount Collector', description='Collect mounts'}, 'mounts'))
assert(not match({id=2136, name='Glory of the Hero'}, 'pets'))
assert(match({id=1250}, 'pets'))
assert(match({id=3478}, 'pet title'))
assert(match({id=9300}, 'mount'))
assert(not match({id=9215, name='Owl Be Seeing You'}, 'mounts'))
assert(match({id=45}, 'tabards'))
assert(not match({id=2136, name='Glory'}, 'mount blue'))
assert(match({id=13, reward='[A reward]'}, '[a')) -- literal punctuation
assert(match({id=13}, '   '))
-- Category lists expose one tier. Both earlier and later tiers must be searchable.
function GetCategoryList() return {1,2} end
function GetCategoryNumAchievements() return 1 end
local names = {[100]='First', [101]='Second', [102]='Third'}
function GetAchievementInfo(id, index)
    if index then return 101 end
    return id, names[id], 10, false, nil,nil,nil, 'Description', 0, 'icon', 'Reward'
end
function GetPreviousAchievement(id) return ({[101]=100,[102]=101})[id] end
function GetNextAchievement(id) return ({[100]=101,[101]=102})[id] end
local result = addon.CollectSearchAchievements()
assert(#result == 3)
local found = {}; for _, row in ipairs(result) do found[row.id] = true end
assert(found[100] and found[101] and found[102])
print('achievement search: reward filters, literal text and progressive chains passed')
-- Instantiate and operate the panel through a small Wrath-style frame mock.
local frames = {}
local methods = {}
local function noop() end
for _, name in ipairs({'SetSize','SetPoint','SetFrameLevel','SetBackdrop','SetBackdropColor','EnableMouse','SetAutoFocus','SetWidth','SetJustifyH','SetHighlightTexture','SetTexture','SetFocus','ClearFocus','RegisterEvent','SetOwner','AddLine'}) do methods[name] = noop end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:HookScript(event, fn) self.scripts[event] = fn end
function methods:GetFrameLevel() return 1 end
function methods:SetText(text) self.text = text; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
function methods:GetText() return self.text or '' end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:IsShown() return self.shown end
function methods:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function CreateFrame(kind, name, parent, template)
    local f = setmetatable({scripts={},kind=kind,parent=parent}, {__index=methods})
    frames[#frames+1] = f
    return f
end
function methods:CreateFontString() return CreateFrame('FontString') end
function methods:CreateTexture() return CreateFrame('Texture') end
addon.ForeverUI = {
    CreateButton = function(parent, text, width, height)
        local b = CreateFrame('Button', nil, parent); b:SetText(text); return b
    end,
    CreateInnerFrame = function(parent) return CreateFrame('Frame', nil, parent) end,
    SkinEditBox = function() end,
}
AchievementFrame = CreateFrame('Frame')
GameTooltip = CreateFrame('Tooltip')
local selected
function AchievementFrame_SelectAchievement(id) selected = id end
assert(loadfile('DragonUI/modules/achievement_search.lua'))('DragonUI', addon)
local search, input, back
for _, f in ipairs(frames) do
    if f.text == 'Search' then search = f end
    if f.kind == 'EditBox' then input = f end
    if f.text == 'Back' then back = f end
end
assert(search and input and back)
search.scripts.OnClick(search)
input:SetText('second')
local hits = {}
for _, f in ipairs(frames) do if f.entry and f.shown then hits[#hits+1] = f end end
assert(#hits == 1 and hits[1].entry.id == 101)
hits[1].scripts.OnClick(hits[1])
assert(selected == 101 and not back.parent:IsShown())
search.scripts.OnClick(search)
input:SetText('mounts')
for _, f in ipairs(frames) do if f.entry then assert(not f.shown) end end
AchievementFrame:Hide()
assert(not back.parent:IsShown())
print('achievement search: panel creation, editing, selection, empty results and parent hide passed')
