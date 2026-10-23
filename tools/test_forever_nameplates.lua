-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
-- Offline, deliberately strict frame mock: Frames have no SetTexture method.
local checks = 0
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end
local common, frames, textures, fonts, bars = {}, {}, {}, {}, {}
local function lookup(kind, key)
    return common[key] or ((kind == "Frame" or kind == "StatusBar") and frames[key])
        or (kind == "Texture" and textures[key]) or (kind == "FontString" and fonts[key])
        or (kind == "StatusBar" and bars[key])
end
local function object(kind, parent)
    return setmetatable({ kind = kind, parent = parent, width = 100, height = 20,
        shown = true, alpha = 1, frameLevel = 1, points = {}, color = {1,1,1,1} },
        { __index = function(_, key) return lookup(kind, key) end })
end
function common:GetObjectType() return self.kind end
function common:GetParent() return self.parent end
function common:SetParent(parent) self.parent = parent end
function common:SetSize(w,h) assert(w >= 0 and h >= 0); self.width,self.height=w,h end
function common:GetSize() return self.width,self.height end
function common:SetWidth(w) self.width=w end
function common:SetHeight(h) self.height=h end
function common:GetWidth() return self.width end
function common:GetHeight() return self.height end
function common:SetPoint(...) self.points[#self.points+1]={...} end
function common:ClearAllPoints() self.points={} end
function common:SetAllPoints(target) self.allPoints=target end
function common:Show() self.shown=true end
function common:Hide() self.shown=false end
function common:IsShown() return self.shown end
function common:SetAlpha(a) self.alpha=a end
function common:GetAlpha() return self.alpha end
function common:GetEffectiveScale() return 1 end
function frames:CreateTexture() return object("Texture",self) end
function frames:CreateFontString() return object("FontString",self) end
function frames:SetFrameLevel(level) self.frameLevel=level end
function frames:GetFrameLevel() return self.frameLevel end
function frames:SetScript(event,fn) self[event]=fn end
function frames:RegisterEvent() end
function frames:SetOwner() end
function frames:EnableMouse(on) self.mouse=on end
function frames:IsMouseOver() return false end
function frames:GetScale() return 1 end
function frames:GetName() return nil end
function textures:SetTexture(path) self.texture=path end
function textures:GetTexture() return self.texture end
function textures:SetTexCoord(...) self.uv={...} end
function textures:SetVertexColor(...) self.color={...} end
function textures:SetBlendMode(mode) self.blend=mode end
function textures:SetDrawLayer(layer) self.layer=layer end
function textures:SetHorizTile() end
function textures:SetVertTile() end
function fonts:SetFont(path,size,flags) self.font={path,size,flags}; return true end
function fonts:GetFont() return unpack(self.font or {}) end
function fonts:SetText(text) self.text=text end
function fonts:GetText() return self.text end
function fonts:SetTextColor(...) self.color={...} end
function fonts:SetJustifyH(value) self.justify=value end
function fonts:SetWordWrap() end
function fonts:SetNonSpaceWrap() end
function fonts:SetShadowColor() end
function fonts:SetShadowOffset() end
function bars:SetStatusBarTexture(path)
    self.statusTexture=self.statusTexture or object("Texture",self)
    self.statusTexture:SetTexture(path)
end
function bars:GetStatusBarTexture() return self.statusTexture end
function bars:SetStatusBarColor(...) self.barColor={...} end
function bars:GetStatusBarColor() return unpack(self.barColor or {1,1,1,1}) end
function bars:SetMinMaxValues(lo,hi) self.lo,self.hi=lo,hi end
function bars:GetMinMaxValues() return self.lo or 0,self.hi or 100 end
function bars:SetValue(value) self.value=value end
function bars:GetValue() return self.value or 100 end

UIParent=object("Frame")
WorldFrame=object("Frame")
function CreateFrame(kind, name, parent) return object(kind == "GameTooltip" and "Frame" or kind,parent) end
function GetTime() return 100 end
function GetCVar() return "1920x1080" end
function UnitExists(unit) return unit == "target" end
function UnitLevel() return 80 end
function GetSpellInfo(id) return "Spell" .. tostring(id) end
function GetQuestDifficultyColor() return {r=1,g=0.8,b=0} end
function hooksecurefunc() end
function wipe(t) for key in pairs(t) do t[key]=nil end end

local cfg = {plateStyle="legacy", barWidth=173, barHeight=11, castBarHeight=9,
    fontSize=2, nameFont="primary", castBarGap=4, showLevelAlways=true,
    showCastBarSpellName=false, showPowerBar=true, showEliteIcon=true,
    castBarModernIconLeft=true, castBarModernIconBorder=true, healthTextPosition="afterName"}
local addon = {Nameplates={const={},module={plates={}},identity={},native_style={},threat={}}, Fonts={PRIMARY="Fonts\\FRIZQT__.TTF"}}
function addon:GetModuleConfig() return cfg end
local NP=addon.Nameplates
NP.abs,NP.min,NP.max=math.abs,math.min,math.max
local function load(path) assert(loadfile(TEST_ROOT.."/DragonUI/modules/nameplates/"..path))("DragonUI",addon) end
load("core/constants.lua")
load("core/atlas.lua")
load("core/forever_atlas.lua")
load("core/config.lua")
load("features/widgets.lua")
load("pipeline/discovery.lua")
load("features/castbar.lua")
load("pipeline/layout.lua")
load("pipeline/gather.lua")
load("features/forever.lua")
load("features/retail_chrome.lua")
NP.gather.IsHeadlineActive=function(pd) return pd.headline == true end
NP.gather.IsTotemIconOnlyActive=function(pd) return pd.totem == true end
NP.gather.IsFriendlyNameOnlyActive=function() return false end
NP.gather.IsFriendlyNPCNameOnlyActive=function() return false end
NP.identity.IsTargetPlateVisual=function(pd) return pd.target == true end
NP.identity.IsTargetPlate=NP.identity.IsTargetPlateVisual
NP.identity.IsMouseoverPlate=function() return false end
NP.identity.IsFocusPlate=function(pd) return pd.focus == true end
NP.identity.ResolvePlateUnit=function(pd) return pd.target and "target" or nil end
NP.identity.UpdatePlateUnitToken=function() return nil end
NP.native_style.IsBossLevel=function(level) return level == "??" or tonumber(level) == -1 end
NP.native_style.GetPlateReaction=function() return "HOSTILE","NPC" end
NP.native_style.GetBarMetrics=function() return NP.config.GetBarRefSize() end
NP.widgets.LayoutRaidMarker=function() end
NP.widgets.GetDebuffHostAnchor=function(pd) return pd.minaHp,0,2 end
NP.threat.GetAggroBarTint=function() return nil end

cfg.plateStyle="forever"
NP.config.ApplyPlateStyle("legacy")
check(cfg.barWidth==166 and cfg.barHeight==13 and cfg.castBarHeight==6,"Forever preset")
check(cfg.showCastBarSpellName and not cfg.showPowerBar and not cfg.showEliteIcon,"complete thin preset")
check(NP.config.IsRetailSkin() and NP.config.IsForeverSkin(),"style classification")
check(NP.config.GetCastFillTexture(false,false):find("Forever"),"original cast fill")
check(NP.config.GetCastFillTexture(false,true):find("uninterruptible"),"uninterruptible cast fill")
cfg.barWidth=185
NP.config.ApplyPlateStyle("forever")
check(cfg.barWidth==185,"reselect does not reset sizes")
cfg.plateStyle="legacy"
NP.config.ApplyPlateStyle("forever")
check(cfg.barWidth==173 and cfg.barHeight==11 and cfg.showPowerBar and cfg.showEliteIcon,"old layout restored")
check(cfg.showCastBarSpellName==false and cfg.castBarModernIconLeft==true,"false values restored")
cfg.plateStyle="forever"
NP.config.ApplyPlateStyle("legacy")
check(cfg.barWidth==185,"Forever custom size restored")

local tex=object("Texture")
NP.atlas.Apply(tex,"barBg")
check(tex.texture:find("Forever"),"Forever atlas dispatch")
local slice=NP.atlas.CreateSlice(UIParent)
NP.atlas.LayoutSlice(slice,"barBg",UIParent,148,16,2,3,6,6)
check(slice.keyed[5]=="forever_barBg","retail bake never replaces Forever art")
for _,fraction in ipairs({0,0.01,0.5,1}) do
    NP.atlas.LayoutSlice(slice,"barFill",UIParent,166*fraction,13)
    for i=1,9 do check(slice[i].width>=0 and slice[i].height>=0,"nonnegative fill geometry") end
end

local pd={plate=object("Frame"),minaHp=object("StatusBar"),minaPo=object("StatusBar"),
    minaCast=object("StatusBar"),plateName="Wolf",target=true,_shownAt=0}
pd.minaPo:Hide()
pd.minaHp:SetStatusBarTexture("native-fill")
pd.minaPo:SetStatusBarTexture("native-fill")
pd.minaCast.minaBg=object("Texture")
NP.widgets.Sync("RetailChrome",pd)
check(pd._retailBg.keyed[5]=="forever_barBg","original health border")
check(pd._retailSelected.shown,"target border shown")
pd.target=false;pd.focus=true
NP.widgets.Sync("RetailChrome",pd)
check(pd._retailSelected.shown and not pd._retailDeselected.shown,"focus is highlighted, not dimmed")
pd.focus=false
NP.widgets.Sync("RetailChrome",pd)
check(not pd._retailSelected.shown and pd._retailDeselected.shown,"non-target dim overlay")

NP.forever.SyncLevel(pd,nil,80,true,false)
local badge=pd._foreverLevel
check(badge:IsShown() and badge.text.text=="80","native level badge")
check(badge.bg.keyed[5]=="forever_levelBg","original level frame")
check(badge.parent==pd.minaHp,"badge inherits health-bar alpha and visibility")
NP.forever.SyncLevel(pd,nil,"??",true,true)
check(badge.skull:IsShown() and not badge.text:IsShown(),"boss skull replaces number")
NP.forever.SyncLevel(pd,nil,nil,true,false)
check(not badge:IsShown(),"unknown levels do not display stale numbers")
pd.headline=true
NP.forever.SyncLevel(pd,nil,80,true,false)
check(not badge:IsShown(),"headline hides badge")
pd.headline=false;pd.totem=true
NP.forever.SyncLevel(pd,nil,80,true,false)
check(not badge:IsShown(),"totem-only hides badge")
pd.totem=false;pd.target=true
NP.forever.SyncLevel(pd,"target",nil,true,false)
check(badge.text.text=="80" and badge.selected.shown,"verified target level and selected badge")

pd.minaName=object("FontString")
pd.minaNameRow=object("Frame")
pd.minaBossSkull=object("Texture")
NP.gather.SyncName(pd,"target")
check(pd.minaName.text=="Wolf","name carries no inline level")
check(badge:IsShown(),"name refresh syncs badge")
local spark=object("Frame");spark.tex=object("Texture")
NP.castbar.SizeCastSpark(spark,6)
check(spark.width==4 and spark.tex.texture:find("Forever"),"Forever cast spark")
check(NP.castbar.GetCastSpellIconSize(false)==10,"Forever icon sizing")
local shield=NP.castbar.CreateCastIconShield(pd.minaCast)
NP.castbar.LayoutCastIconShield(shield,tex,10,pd.minaCast)
check(shield.width==10 and shield.height==12,"new-frame shield layout is safe")
cfg.plateStyle="modern"
NP.config.ApplyPlateStyle("forever")
NP.widgets.Sync("RetailChrome",pd)
check(pd._retailBg.keyed[5]~="forever_barBg","modern chrome restored")
NP.forever.SyncLevel(pd,nil,80,true,false)
check(not badge:IsShown(),"leaving Forever hides badge")
NP.castbar.SizeCastSpark(spark,8)
check(not spark.tex.texture:find("Forever"),"modern spark restored")
check(not NP.config.GetCastFillTexture(false,false):find("Forever"),"modern cast texture restored")

cfg.plateStyle="forever"
NP.config.ApplyPlateStyle("modern")
local fresh={plate=object("Frame"),border=object("Texture"),plateName="Fresh Wolf",target=true,_shownAt=0}
NP.layout.EnsureMinaStack(fresh)
NP.layout.LayoutMinaStack(fresh)
NP.layout.LayoutCastBarStack(fresh)
check(fresh.minaCast:GetStatusBarTexture().texture:find("Forever"),"layout updates active cast skin")
NP.gather.SyncName(fresh,"target")
NP.widgets.Sync("RetailChrome",fresh)
check(fresh.minaHp.width==cfg.barWidth and fresh.minaHp.height==13,"full stack uses thin bar dimensions")
check(fresh.minaCast.height==6 and fresh.minaCast.minaCastIcon.width==10,"full cast layout")
check(fresh._foreverLevel:IsShown() and fresh.minaName.text=="Fresh Wolf","full stack level badge")
NP.forever.StylePartyCast(fresh.minaPartyCast,cfg.barWidth,6)
check(fresh.minaPartyCast._foreverCastFrame.shown,"group cast bars use original border")
cfg.plateStyle="legacy"
NP.config.ApplyPlateStyle("forever")
NP.layout.LayoutCastBarStack(fresh)
check(not fresh.minaCast:GetStatusBarTexture().texture:find("Forever"),"cast fill restored when leaving Forever")
NP.forever.StylePartyCast(fresh.minaPartyCast,cfg.barWidth,9)
NP.widgets.Sync("RetailChrome",fresh)
check(not fresh._foreverLevel:IsShown() and not fresh.minaPartyCast._foreverCastFrame.shown,"all Forever widgets hidden on Heritage switch")
check(fresh.minaHp.minaBr:IsShown(),"Heritage border restored")

cfg.plateStyle="forever"
NP.config.ApplyPlateStyle("legacy")
fresh.target=false;fresh.focus=false
fresh.levelText=object("FontString");fresh.levelText:SetText("77")
NP.gather.SyncName(fresh,nil)
check(fresh._foreverLevel.text.text=="77","off-target native levels work without modern unit tokens")
fresh.levelText:SetText("??")
NP.gather.SyncName(fresh,nil)
check(fresh._foreverLevel.skull:IsShown() and not fresh.minaBossSkull:IsShown(),"off-target boss skull only appears in badge")
fresh.levelText:SetText("");fresh.plateLevel=nil
NP.gather.SyncName(fresh,nil)
check(not fresh._foreverLevel:IsShown(),"empty native levels do not leak previous occupant's level")
print("Forever regression checks:",checks,"OK")
