-- Run from the repository root with Lua 5.1. Mocks Blizzard_BindingUI's frame and list APIs.
function wipe(t) for k in pairs(t) do t[k] = nil end; return t end
strsub = string.sub
SEARCH = 'Search'
NOT_BOUND = 'Not Bound'
NORMAL_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE = '', ''
KEY_BINDINGS_DISPLAYED, KEY_BINDING_HEIGHT = 3, 25

local function widget()
    local w = { scripts = {}, hooks = {}, points = {} }
    function w:SetScript(k, fn) self.scripts[k] = fn end
    function w:HookScript(k, fn) self.hooks[k] = fn end
    function w:RegisterEvent() end
    function w:Show() self.shown = true end
    function w:Hide() self.shown = false end
    function w:IsShown() return self.shown end
    function w:SetText(t) self.text = t end
    function w:GetText() return self.text or '' end
    function w:SetAlpha(a) self.alpha = a end
    function w:LockHighlight() self.locked = true end
    function w:UnlockHighlight() self.locked = false end
    function w:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function w:ClearAllPoints() wipe(self.points) end
    function w:SetSize() end
    function w:SetAutoFocus() end
    function w:SetTextInsets() end
    function w:SetFrameLevel() end
    function w:GetFrameLevel() return 1 end
    function w:SetJustifyH(j) self.justify = j end
    function w:SetTexture(t) self.texture = t end
    function w:ClearFocus() self.focused = false end
    function w:CreateTexture() return widget() end
    function w:CreateFontString() return widget() end
    function w:SetValue(v) self.value = v end
    function w:Enable() self.enabled = true end
    function w:Disable() self.enabled = false end
    return w
end
local created = {}
function CreateFrame(kind, name)
    local w = widget()
    created[#created + 1] = w
    if name then _G[name] = w end
    return w
end

-- Blizzard's window, 3 visible rows, and a 7-entry binding list under two headers.
KeyBindingFrame = widget()
KeyBindingFrame.mode = 1
KeyBindingFrameOutputText = widget()
KeyBindingFrameUnbindButton = widget()
KeyBindingFrameScrollFrame = widget()
KeyBindingFrameScrollFrameScrollBar = widget()
for i = 1, KEY_BINDINGS_DISPLAYED do
    _G['KeyBindingFrameBinding' .. i] = widget()
    for _, part in ipairs({ 'Key1Button', 'Key2Button', 'Description', 'Header' }) do
        _G['KeyBindingFrameBinding' .. i .. part] = widget()
    end
end
local bindings = {
    { 'HEADER_MOVEMENT' },
    { 'MOVEFORWARD', 'W', 'UP' },
    { 'STRAFELEFT', 'Q' },
    { 'STRAFERIGHT', 'E' },
    { 'HEADER_CHAT' },
    { 'OPENCHAT', 'ENTER' },
    { 'REPLY', 'R', 'SHIFT-F' },
}
BINDING_HEADER_MOVEMENT, BINDING_HEADER_CHAT = 'Movement Keys', 'Chat Functions'
local names = { MOVEFORWARD = 'Move Forward', STRAFELEFT = 'Strafe Left', STRAFERIGHT = 'Strafe Right', OPENCHAT = 'Open Chat', REPLY = 'Reply' }
local keys = { W = 'W', UP = 'Up Arrow', Q = 'Q', E = 'E', ENTER = 'Enter', R = 'R', ['SHIFT-F'] = 'Shift-F' }
function GetNumBindings() return #bindings end
function GetBinding(i) return bindings[i][1], bindings[i][2], bindings[i][3] end
function GetBindingText(value, prefix)
    if prefix == 'KEY_' then return keys[value] or value end
    return names[value] or value
end
local offset, scrollTotal = 0, nil
function FauxScrollFrame_GetOffset() return offset end
function FauxScrollFrame_SetOffset(_, o) offset = o end
function FauxScrollFrame_Update(_, total) scrollTotal = total end
function KeyBindingFrame_UpdateUnbindKey() end
function KeyBindingFrame_SetSelected(v) KeyBindingFrame.selected = v end
local stockCalls = 0
function KeyBindingFrame_Update() stockCalls = stockCalls + 1 end

local addon = { _dir = 'Interface\\AddOns\\DragonUI\\Textures\\' }
assert(loadfile('DragonUI/modules/keybinding_search.lua'))('DragonUI', addon)
local box = DragonUIKeyBindingSearchBox
assert(box, 'Search box not created when the binding UI is already loaded')
assert(KeyBindingFrameOutputText.points[1][2] == box, 'Status text not moved beside the box')

local function rowNames()
    local out = {}
    for i = 1, KEY_BINDINGS_DISPLAYED do
        local row = _G['KeyBindingFrameBinding' .. i]
        if row.shown then
            local header = _G['KeyBindingFrameBinding' .. i .. 'Header']
            out[#out + 1] = header.shown and header.text or _G['KeyBindingFrameBinding' .. i .. 'Description'].text
        end
    end
    return table.concat(out, '|')
end
local function type(text)
    box.text = text
    box.scripts.OnTextChanged(box)
end

-- Empty query: Blizzard's own update draws the list, untouched.
KeyBindingFrame_Update()
assert(stockCalls == 1, 'Empty query should use the stock update')

-- Command-name filter keeps the header of each matching row and drops empty sections.
type('strafe')
assert(rowNames() == 'Movement Keys|Strafe Left|Strafe Right', rowNames())
assert(scrollTotal == 3, 'Scroll range must be the filtered count, got ' .. tostring(scrollTotal))
assert(stockCalls == 1, 'Filtered query must not call the stock update')

-- Key-name filter, with the display name and the raw binding both searchable.
type('shift-f')
assert(rowNames() == 'Chat Functions|Reply', rowNames())
type('up arrow')
assert(rowNames() == 'Movement Keys|Move Forward', rowNames())

-- Every word must match; case does not matter.
type('Strafe LEFT')
assert(rowNames() == 'Movement Keys|Strafe Left', rowNames())
type('strafe chat')
assert(rowNames() == '', 'No row matches both words: ' .. rowNames())
assert(scrollTotal == 0)

-- Scrolling walks the filtered list, and a new query starts at the top.
type('e')
offset = 3
KeyBindingFrame_Update()
assert(rowNames() == 'Strafe Right|Chat Functions|Open Chat', rowNames())
type('st')
assert(offset == 0 and KeyBindingFrameScrollFrameScrollBar.value == 0, 'Query change should scroll to the top')

-- Selected row keeps its locked highlight through the filter.
KeyBindingFrame.selected, KeyBindingFrame.keyID = 'STRAFERIGHT', 2
KeyBindingFrame_Update()
assert(_G['KeyBindingFrameBinding3Key2Button'].locked and not _G['KeyBindingFrameBinding2Key2Button'].locked)

-- Focusing the box drops a selected binding so typed keys are not bound.
KeyBindingFrame.buttonPressed = _G['KeyBindingFrameBinding3Key2Button']
KeyBindingFrameOutputText.text = 'Press a key'
box.scripts.OnEditFocusGained(box)
assert(KeyBindingFrame.selected == nil and KeyBindingFrameOutputText.text == '' and not KeyBindingFrame.buttonPressed.locked)

-- Closing the window clears the search so the next opening shows everything.
KeyBindingFrame.hooks.OnHide()
assert(box.text == '' and box.focused == false)
KeyBindingFrame_Update()
assert(stockCalls >= 2, 'Cleared query should return to the stock update')

-- Escape clears and unfocuses; Enter only unfocuses.
type('reply'); box.scripts.OnEscapePressed(box); assert(box.text == '')
type('reply'); box.scripts.OnEnterPressed(box); assert(box.text == 'reply' and box.focused == false)

print('keybinding search: filter by name and key, headers, scrolling, selection, focus and reset passed')
