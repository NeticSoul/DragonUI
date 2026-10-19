-- Run from the repository root with Lua 5.1.
local made, timers, callbacks = {}, {}, {}
local combat, alt = false, false
local methods = {}
function InCombatLockdown() return combat end
function IsAltKeyDown() return alt end
function wipe(t) for k in pairs(t) do t[k] = nil end end
function methods:GetName() return self.name end
function methods:GetID() return self.id or 0 end
function methods:IsProtected() return self.protected end
function methods:GetScale() return self.scale or 1 end
function methods:GetEffectiveScale() return self:GetScale() * (self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:GetWidth() return self.width or 400 end
function methods:GetHeight() return self.height or 300 end
function methods:GetCenter() return self.x or 500, self.y or 400 end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetFrameLevel(n) self.level = n end
function methods:SetHeight(n) self.height = n end
function methods:SetParent(p) self.parent = p end
function methods:SetMovable(v) self.movable = v end
function methods:SetClampedToScreen(v) self.clamped = v end
function methods:EnableMouse() end
function methods:RegisterForDrag() end
function methods:RegisterEvent() end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event, fn)
    local previous = self.scripts[event]
    self.scripts[event] = function(...)
        if previous then previous(...) end
        fn(...)
    end
end
function methods:GetNumPoints() return self.point and 1 or 0 end
function methods:GetPoint() return unpack(self.point) end
function methods:ClearAllPoints()
    assert(not (combat and self.protected), 'Protected position changed in combat')
    self.point = nil
end
function methods:SetPoint(point, relative, relativePoint, x, y)
    assert(not (combat and self.protected), 'Protected position changed in combat')
    self.point = {point,relative,relativePoint,x,y}
    if relative == UIParent then
        local scale = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local ox, oy = 0, 0
        if relativePoint == 'CENTER' then ox, oy = UIParent.width / 2, UIParent.height / 2 end
        if relativePoint == 'TOPLEFT' then oy = UIParent.height end
        self.x, self.y = ox / scale + x, oy / scale + y
    end
end
function methods:StartMoving() assert(not combat); self.moving = true end
function methods:StopMovingOrSizing() assert(not (combat and self.protected)); self.moving = false end
function methods:SetUserPlaced(v) self.userPlaced = v end
function methods:IsShown() return self.shown end
function methods:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function CreateFrame(_, name, parent)
    local frame = setmetatable({name=name,parent=parent,scripts={},shown=false}, {__index=methods})
    made[#made+1] = frame
    if name then _G[name] = frame end
    return frame
end
function hooksecurefunc(target, key, fn)
    if type(target) == 'string' then fn, key, target = key, target, _G end
    local original = target[key]
    target[key] = function(...)
        local result = {original(...)}
        fn(...)
        return unpack(result)
    end
end
local function flush() while #timers > 0 do table.remove(timers,1)() end end
UIParent = CreateFrame('Frame','UIParent'); UIParent.width, UIParent.height = 1000, 800
UIPanelWindows = {CharacterFrame={area='left'}}
local panelUpdates, shows, hides, nativeStarts, nativeStops = 0,0,0,0,0
function UpdateUIPanelPositions() panelUpdates = panelUpdates + 1 end
function ShowUIPanel(frame) frame:Show() end
GameTooltip = {SetOwner=function() end,SetText=function() end,Show=function() end}
function GameTooltip_Hide() end
local addon = { db={profile={}}, L=setmetatable({}, {__index=function(_,key) return key end}),
    After=function(_,_,fn) timers[#timers+1]=fn end, Print=function() end,
    CombatQueue={Add=function(_,_,fn) timers[#timers+1]=fn end} }
function addon.db.RegisterCallback(_, event, fn) callbacks[event] = fn end
assert(loadfile('DragonUI/utils/window_positions.lua'))('DragonUI',addon)
local windows = addon.WindowPositions
local events = made[#made]
local f = CreateFrame('Frame','CharacterFrame',UIParent)
f:SetPoint('CENTER',UIParent,'CENTER',0,0)
f:SetScript('OnShow',function() shows=shows+1 end)
f:SetScript('OnHide',function() hides=hides+1 end)
f:SetScript('OnDragStart',function(self) nativeStarts=nativeStarts+1; self:StartMoving() end)
f:SetScript('OnDragStop',function(self) nativeStops=nativeStops+1; self:StopMovingOrSizing() end)
windows:Register(f,'CharacterFrame')
f:Show(); assert(shows==1 and not addon.db.profile.windowPositions.CharacterFrame)
local record = windows.frames[f]
record.handle.scripts.OnDragStart(); assert(f.moving and nativeStarts==1)
f.x,f.y = 700,450
record.handle.scripts.OnDragStop()
assert(not f.moving and nativeStops==1 and not f.userPlaced)
assert(addon.db.profile.windowPositions.CharacterFrame.x==0.7)
f:SetPoint('CENTER',UIParent,'CENTER',-300,-200)
assert(f.x==700 and f.y==450,'Panel layout overwrote saved placement')
f:Hide(); f:Show(); assert(hides==1 and shows==2 and f.x==700)
-- Recreated frames read saved positions, including when the frame or UI is scaled.
local recreated = CreateFrame('Frame',nil,UIParent); recreated.scale=0.5; recreated:Show()
recreated:SetPoint('CENTER',UIParent,'CENTER',0,0)
windows:Register(recreated,'CharacterFrame')
assert(recreated.x==1400 and recreated.y==900,'Effective scale was not accounted for')
UIParent.width,UIParent.height=600,400
windows:Restore(f)
assert(f.x<=400 and f.y<=250,'Changed resolution left a window off-screen')
UIParent.width,UIParent.height=1000,800
windows:Restore(f); assert(f.x==700 and f.y==450)
-- Combat never installs or moves protected frames; deferred drops finish after combat.
f.protected=true; combat=true
record.handle.scripts.OnDragStart(); assert(not record.dragging)
f.x=600; windows:Restore(f); assert(f.x==600)
local late=CreateFrame('Frame','AuctionFrame',UIParent)
windows:Register(late,'AuctionFrame'); assert(not windows.frames[late])
combat=false; record.handle.scripts.OnDragStart(); f.x=620
combat=true; record.handle.scripts.OnDragStop(); assert(record.dragging)
combat=false; events.scripts.OnEvent(events,'PLAYER_REGEN_ENABLED'); flush()
assert(not record.dragging and windows.frames[late] and f.x==620)
-- Right-click reset preserves normal panel close/show callbacks and panel registration.
alt=true; record.handle.scripts.OnMouseUp(nil,'RightButton'); alt=false
assert(not addon.db.profile.windowPositions.CharacterFrame and panelUpdates==1)
assert(UIPanelWindows.CharacterFrame and shows==2 and hides==1)
-- Native pooled bags own positions by bag ID even when frames are reused.
local bag=CreateFrame('Frame',nil,UIParent); bag:SetPoint('CENTER',UIParent,'CENTER',0,0); bag:Show()
windows:Register(bag,function(frame) return 'bag:'..frame:GetID() end)
local bagRecord=windows.frames[bag]
bagRecord.handle.scripts.OnDragStart(); bag.x=250; bagRecord.handle.scripts.OnDragStop()
bag.id=1; bag:SetPoint('CENTER',UIParent,'CENTER',0,0)
assert(bag.x==500,'New pooled bag inherited a previous bag position')
bagRecord.handle.scripts.OnDragStart(); bag.x=750; bagRecord.handle.scripts.OnDragStop()
bag.id=0; bag:SetPoint('CENTER',UIParent,'CENTER',0,0); assert(bag.x==250)
-- Professions can replace an early stock handle with their scaled chrome anchor.
local chrome=CreateFrame('Frame',nil,f)
windows:Register(f,'CharacterFrame',{parent=chrome,anchor=chrome})
assert(record.handle.parent==chrome and record.handle.point[2]==chrome)
-- Profiles with no saved positions restore defaults without copying the old placement.
events.scripts.OnEvent(events,'PLAYER_LOGIN'); flush()
addon.db.profile={windowPositions={NotLoadedYet={x=0.2,y=0.3}}}
callbacks.OnProfileChanged()
assert(f.x==500 and bag.x==500 and not addon.db.profile.windowPositions.CharacterFrame)
windows:ResetAll(); assert(next(addon.db.profile.windowPositions)==nil)
combat=true; assert(not windows:ResetAll()); combat=false
print('windows: dragging, persistence, layout hooks, scaling/clamping, combat, pooled bags, profiles and reset passed')
