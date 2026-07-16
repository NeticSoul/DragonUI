--[[
================================================================================
DragonUI - English Locale (Default)
================================================================================
Base locale. All keys use `true` (the key itself is the display value).

When adding new strings:
1. Add L[<your key>] = true here
2. Use L["Your String"] in your code
3. Add translations to other locale files
================================================================================
]]

local L = LibStub("AceLocale-3.0"):NewLocale("DragonUI", "koKR")
if not L then return end

-- ============================================================================
-- CORE / GENERAL
-- ============================================================================

-- Combat lockdown messages
L["Cannot toggle editor mode during combat!"] = "ì „íˆ¬ ì¤‘ì—ëŠ” íŽ¸ì§‘ ëª¨ë“œë¥¼ ì—´ ìˆ˜ ì—†ìŠµë‹ˆë‹¤!"
L["Cannot reset positions during combat!"] = "ì „íˆ¬ ì¤‘ì—ëŠ” ìœ„ì¹˜ë¥¼ ì´ˆê¸°í™”í•  ìˆ˜ ì—†ìŠµë‹ˆë‹¤!"
L["Cannot toggle keybind mode during combat!"] = "ì „íˆ¬ ì¤‘ì—ëŠ” ë‹¨ì¶•í‚¤ ì„¤ì • ëª¨ë“œë¥¼ ì—´ ìˆ˜ ì—†ìŠµë‹ˆë‹¤!"
L["Cannot move frames during combat!"] = "ì „íˆ¬ ì¤‘ì—ëŠ” í”„ë ˆìž„ì„ ì´ë™í•  ìˆ˜ ì—†ìŠµë‹ˆë‹¤!"
L["Cannot open options in combat."] = "ì „íˆ¬ ì¤‘ì—ëŠ” ì˜µì…˜ì„ ì—´ ìˆ˜ ì—†ìŠµë‹ˆë‹¤."
L["Options panel not available. Try /reload."] = "ì˜µì…˜ íŒ¨ë„ì„ ì‚¬ìš©í•  ìˆ˜ ì—†ìŠµë‹ˆë‹¤. /reloadë¥¼ ì‹œë„í•˜ì„¸ìš”."

-- Module availability
L["Editor mode not available."] = "íŽ¸ì§‘ ëª¨ë“œë¥¼ ì‚¬ìš©í•  ìˆ˜ ì—†ìŠµë‹ˆë‹¤."
L["Keybind mode not available."] = "ë‹¨ì¶•í‚¤ ì„¤ì • ëª¨ë“œë¥¼ ì‚¬ìš©í•  ìˆ˜ ì—†ìŠµë‹ˆë‹¤."
L["Vehicle debug not available"] = "íƒˆê²ƒ ë””ë²„ê·¸ë¥¼ ì‚¬ìš©í•  ìˆ˜ ì—†ìŠµë‹ˆë‹¤."
L["KeyBinding module not available"] = "ë‹¨ì¶•í‚¤ ì„¤ì • ëª¨ë“ˆì„ ì‚¬ìš©í•  ìˆ˜ ì—†ìŠµë‹ˆë‹¤."
L["Unable to open configuration"] = "ì„¤ì •ì°½ì„ ì—´ ìˆ˜ ì—†ìŠµë‹ˆë‹¤."
L["Commands: /dragonui config, /dragonui edit"] = "ëª…ë ¹ì–´: /dragonui config, /dragonui edit"
L["Reset position: %s"] = "ìœ„ì¹˜ ì´ˆê¸°í™”: %s"
L["All positions reset to defaults"] = "ëª¨ë“  ìœ„ì¹˜ê°€ ê¸°ë³¸ê°’ìœ¼ë¡œ ì´ˆê¸°í™”ë˜ì—ˆìŠµë‹ˆë‹¤"
L["Editor mode enabled - Drag frames to reposition"] = "íŽ¸ì§‘ ëª¨ë“œ í™œì„±í™” - í”„ë ˆìž„ì„ ë“œëž˜ê·¸í•˜ì—¬ ìœ„ì¹˜ ë³€ê²½"
L["Editor mode disabled - Positions saved"] = "íŽ¸ì§‘ ëª¨ë“œ ë¹„í™œì„±í™” - ìœ„ì¹˜ê°€ ì €ìž¥ë˜ì—ˆìŠµë‹ˆë‹¤"
L["Minimap module restored to Blizzard defaults"] = "ë¯¸ë‹ˆë§µ ëª¨ë“ˆì´ ë¸”ë¦¬ìžë“œ ê¸°ë³¸ê°’ìœ¼ë¡œ ë³µì›ë˜ì—ˆìŠµë‹ˆë‹¤"
L["All action bar scales reset to default values"] = "ëª¨ë“  ì•¡ì…˜ë°” í¬ê¸°ê°€ ê¸°ë³¸ê°’ìœ¼ë¡œ ì´ˆê¸°í™”ë˜ì—ˆìŠµë‹ˆë‹¤"
L["Minimap position reset to default"] = "ë¯¸ë‹ˆë§µ ìœ„ì¹˜ê°€ ê¸°ë³¸ê°’ìœ¼ë¡œ ì´ˆê¸°í™”ë˜ì—ˆìŠµë‹ˆë‹¤"
L["Targeting: %s"] = "ëŒ€ìƒ ì§€ì •: %s"
L["XP: %d/%d"] = "XP: %d/%d"
L["GROUP %d"] = "ê·¸ë£¹ %d"
L["XP: "] = "XP: "
L["Remaining: "] = "ë‚¨ìŒ: "
L["Rested: "] = "íœ´ì‹: "

-- Errors
L["Error executing pending operation:"] = "ëŒ€ê¸° ì¤‘ì¸ ìž‘ì—… ì‹¤í–‰ ì˜¤ë¥˜:"
L["Error -- Addon 'DragonUI_Options' not found or is disabled."] = "ì˜¤ë¥˜ -- 'DragonUI_Options' ì• ë“œì˜¨ì„ ì°¾ì„ ìˆ˜ ì—†ê±°ë‚˜ ë¹„í™œì„±í™”ë˜ì–´ ìžˆìŠµë‹ˆë‹¤."

-- ============================================================================
-- SLASH COMMANDS / HELP
-- ============================================================================

L["Unknown command: "] = "ì•Œ ìˆ˜ ì—†ëŠ” ëª…ë ¹ì–´: "
L["=== DragonUI Commands ==="] = "=== DragonUI ëª…ë ¹ì–´ ==="
L["/dragonui or /dui - Open configuration"] = "/dragonui ë˜ëŠ” /dui - ì„¤ì •ì°½ ì—´ê¸°"
L["/dragonui config - Open configuration"] = "/dragonui config - ì„¤ì •ì°½ ì—´ê¸°"
L["/dragonui edit - Toggle editor mode (move UI elements)"] = "/dragonui edit - íŽ¸ì§‘ ëª¨ë“œ ì „í™˜ (UI ìš”ì†Œ ì´ë™)"
L["/dragonui reset - Reset all positions to defaults"] = "/dragonui reset - ëª¨ë“  ìœ„ì¹˜ë¥¼ ê¸°ë³¸ê°’ìœ¼ë¡œ ì´ˆê¸°í™”"
L["/dragonui reset <name> - Reset specific mover"] = "/dragonui reset <ì´ë¦„> - íŠ¹ì • ìš”ì†Œì˜ ìœ„ì¹˜ ì´ˆê¸°í™”"
L["/dragonui status - Show module status"] = "/dragonui status - ëª¨ë“ˆ ìƒíƒœ í‘œì‹œ"
L["/dragonui kb - Toggle keybind mode"] = "/dragonui kb - ë‹¨ì¶•í‚¤ ì„¤ì • ëª¨ë“œ ì „í™˜"
L["/dragonui version - Show version info"] = "/dragonui version - ë²„ì „ ì •ë³´ í‘œì‹œ"
L["/dragonui help - Show this help"] = "/dragonui help - ë„ì›€ë§ í‘œì‹œ"
L["/rl - Reload UI"] = "/rl - UI ìž¬ì„¤ì •(ë¦¬ë¡œë“œ)"

-- ============================================================================
-- STATUS DISPLAY
-- ============================================================================

L["=== DragonUI Status ==="] = "=== DragonUI ìƒíƒœ ==="
L["Detected Modules:"] = "ê°ì§€ëœ ëª¨ë“ˆ:"
L["Loaded"] = "ë¡œë“œë¨"
L["Not Loaded"] = "ë¡œë“œë˜ì§€ ì•ŠìŒ"
L["Target Frame"] = true
L["Focus Frame"] = true
L["Party Frames"] = true
L["Cooldowns"] = true
L["Registered Movers: "] = "ë“±ë¡ëœ ì´ë™ ì§€ì : "
L["Editable Frames: "] = "íŽ¸ì§‘ ê°€ëŠ¥í•œ í”„ë ˆìž„: "
L["DragonUI Version: "] = "DragonUI ë²„ì „: "
L["Use /dragonui edit to enter edit mode, then right-click frames to reset."] = "/dragonui editë¥¼ ìž…ë ¥í•˜ì—¬ íŽ¸ì§‘ ëª¨ë“œë¡œ ë“¤ì–´ê°„ ë’¤, í”„ë ˆìž„ì„ ìš°í´ë¦­í•˜ë©´ ìœ„ì¹˜ê°€ ì´ˆê¸°í™”ë©ë‹ˆë‹¤."

-- ============================================================================
-- EDITOR MODE
-- ============================================================================

L["Exit Edit Mode"] = "íŽ¸ì§‘ ëª¨ë“œ ì¢…ë£Œ"
L["Reset All Positions"] = "ëª¨ë“  ìœ„ì¹˜ ì´ˆê¸°í™”"
L["Are you sure you want to reset all interface elements to their default positions?"] = "ëª¨ë“  ì¸í„°íŽ˜ì´ìŠ¤ ìš”ì†Œë¥¼ ê¸°ë³¸ ìœ„ì¹˜ë¡œ ì´ˆê¸°í™”í•˜ì‹œê² ìŠµë‹ˆê¹Œ?"
L["Yes"] = "ì˜ˆ"
L["No"] = "ì•„ë‹ˆìš”"
L["UI elements have been repositioned. Reload UI to ensure all graphics display correctly?"] = "UI ìš”ì†Œì˜ ìœ„ì¹˜ê°€ ë³€ê²½ë˜ì—ˆìŠµë‹ˆë‹¤. ëª¨ë“  ê·¸ëž˜í”½ì´ ì˜¬ë°”ë¥´ê²Œ í‘œì‹œë˜ë„ë¡ UIë¥¼ ìž¬ì„¤ì •í•˜ì‹œê² ìŠµë‹ˆê¹Œ?"
L["Reload Now"] = "ì§€ê¸ˆ ìž¬ì„¤ì •"
L["Later"] = "ë‚˜ì¤‘ì—"

-- Position presets (edit mode)
L["Position Presets"] = "위치 프리셋"
L["Position Preset"] = "위치 프리셋"
L["Save"] = "저장"
L["Import"] = "가져오기"
L["Cancel"] = "취소"
L["Load"] = "불러오기"
L["Delete"] = "삭제"
L["Select All"] = "전체 선택"
L["Click to load"] = "클릭하여 불러오기"
L["No position presets saved yet."] = "저장된 위치 프리셋이 없습니다."
L["Load position preset '%s'? This will overwrite your current element positions."] = "'%s' 위치 프리셋을 불러올까요? 현재 요소 위치가 덮어씌워집니다."
L["Delete position preset '%s'? This cannot be undone."] = "'%s' 위치 프리셋을 삭제할까요? 이 작업은 취소할 수 없습니다."
L["Enter a name for the imported position preset:"] = "가져온 위치 프리셋의 이름을 입력하세요:"
L["Imported Position Preset"] = "가져온 위치 프리셋"
L["Position preset saved: "] = "위치 프리셋 저장됨: "
L["Position preset loaded: "] = "위치 프리셋 불러옴: "
L["Position preset deleted: "] = "위치 프리셋 삭제됨: "
L["Position preset imported: "] = "위치 프리셋 가져옴: "
L["Export Position Preset"] = "위치 프리셋 내보내기"
L["Import Position Preset"] = "위치 프리셋 가져오기"
L["Invalid position preset string."] = "유효하지 않은 위치 프리셋 문자열입니다."
L["Not a valid DragonUI position preset string."] = "유효한 DragonUI 위치 프리셋 문자열이 아닙니다."
L["Failed to export position preset."] = "위치 프리셋 내보내기에 실패했습니다."
L["Save New Preset"] = "새 프리셋 저장"
L["Load Preset"] = "프리셋 불러오기"
L["Delete Preset"] = "프리셋 삭제"
L["Export Preset"] = "프리셋 내보내기"
L["Import Preset"] = "프리셋 가져오기"

-- ============================================================================
-- KEYBINDING MODULE
-- ============================================================================

L["LibKeyBound-1.0 not found or failed to load:"] = "LibKeyBound-1.0ì„ ì°¾ì„ ìˆ˜ ì—†ê±°ë‚˜ ë¡œë“œì— ì‹¤íŒ¨í–ˆìŠµë‹ˆë‹¤:"
L["Commands:"] = "ëª…ë ¹ì–´:"
L["/dukb - Toggle keybinding mode"] = "/dukb - ë‹¨ì¶•í‚¤ ì„¤ì • ëª¨ë“œ ì „í™˜"
L["/dukb help - Show this help"] = "/dukb help - ë„ì›€ë§ í‘œì‹œ"
L["Module disabled."] = "ëª¨ë“ˆì´ ë¹„í™œì„±í™”ë˜ì—ˆìŠµë‹ˆë‹¤."
L["Keybinding mode activated. Hover over buttons and press keys to bind them."] = "ë‹¨ì¶•í‚¤ ì„¤ì • ëª¨ë“œê°€ í™œì„±í™”ë˜ì—ˆìŠµë‹ˆë‹¤. ë²„íŠ¼ ìœ„ì— ë§ˆìš°ìŠ¤ë¥¼ ì˜¬ë¦¬ê³  í‚¤ë¥¼ ëˆ„ë¥´ë©´ ì§€ì •ë©ë‹ˆë‹¤."
L["Keybinding mode deactivated."] = "ë‹¨ì¶•í‚¤ ì„¤ì • ëª¨ë“œê°€ ë¹„í™œì„±í™”ë˜ì—ˆìŠµë‹ˆë‹¤."

-- ============================================================================
-- GAME MENU
-- ============================================================================


-- ============================================================================
-- MINIMAP MODULE
-- ============================================================================

L["DragonUI: Minimap module restored to Blizzard defaults"] = "DragonUI: ë¯¸ë‹ˆë§µ ëª¨ë“ˆì´ ë¸”ë¦¬ìžë“œ ê¸°ë³¸ê°’ìœ¼ë¡œ ë³µêµ¬ë˜ì—ˆìŠµë‹ˆë‹¤."
L["Minimap Buttons"] = "ë¯¸ë‹ˆë§µ ë²„íŠ¼"
L["Minimap Buttons Collector"] = "ë¯¸ë‹ˆë§µ ë²„íŠ¼"
L["Left-click to show or hide minimap addon buttons."] = "ì¢Œí´ë¦­ìœ¼ë¡œ ë¯¸ë‹ˆë§µ ì• ë“œì˜¨ ë²„íŠ¼ì„ ì—½ë‹ˆë‹¤."
L["Right-click to open DragonUI settings."] = "ìš°í´ë¦­ìœ¼ë¡œ DragonUI ì„¤ì •ì„ ì—½ë‹ˆë‹¤."

-- ============================================================================
-- EDITOR MODE LABELS (displayed on mover overlays)
-- ============================================================================

L["MainBar"] = "ì£¼ ë‹¨ì¶•ë°”"
L["RightBar"] = "ìš°ì¸¡ ë‹¨ì¶•ë°”"
L["LeftBar"] = "ì¢Œì¸¡ ë‹¨ì¶•ë°”"
L["BottomBarLeft"] = "í•˜ë‹¨ ì¢Œì¸¡"
L["BottomBarRight"] = "í•˜ë‹¨ ìš°ì¸¡"
L["XPBar"] = "ê²½í—˜ì¹˜ ë°”"
L["RepBar"] = "í‰íŒ ë°”"
L["MinimapFrame"] = "ë¯¸ë‹ˆë§µ"
L["LFGFrame"] = "ë˜ì „ ì°¾ê¸°"
L["PlayerFrame"] = "í”Œë ˆì´ì–´"
L["ManaBar"] = "ë§ˆë‚˜ ë°”"
L["PetFrame"] = "ì†Œí™˜ìˆ˜"
L["ToF"] = "ì£¼ì‹œì˜ ëŒ€ìƒ"
L["tot"] = "ëŒ€ìƒì˜ ëŒ€ìƒ"
L["ToT"] = "ëŒ€ìƒì˜ ëŒ€ìƒ"
L["fot"] = "ì£¼ì‹œì˜ ëŒ€ìƒ"
L["PartyFrames"] = "íŒŒí‹°"
L["TargetFrame"] = "ëŒ€ìƒ"
L["FocusFrame"] = "ì£¼ì‹œ ëŒ€ìƒ"
L["TargetCastbar"] = "ëŒ€ìƒ ì‹œì „ë°”"
L["FocusCastbar"] = "ì£¼ì‹œ ëŒ€ìƒ ì‹œì „ë°”"
L["BagsBar"] = "ê°€ë°©"
L["MicroMenu"] = "ë§ˆì´í¬ë¡œ ë©”ë‰´"
L["VehicleExitOverlay"] = "íƒˆê²ƒ ë‚´ë¦¬ê¸°"
L["StanceOverlay"] = "íƒœì„¸ë°”"
L["petbar"] = "ì†Œí™˜ìˆ˜ë°”"
L["ExtraBar1"] = "추가 바"
L["boss"] = "ë³´ìŠ¤ í”„ë ˆìž„"
L["Boss Frames"] = "ë³´ìŠ¤ í”„ë ˆìž„"
L["Boss1Frame"] = "ë³´ìŠ¤ í”„ë ˆìž„"
L["Boss2Frame"] = "ë³´ìŠ¤ í”„ë ˆìž„"
L["Boss3Frame"] = "ë³´ìŠ¤ í”„ë ˆìž„"
L["Boss4Frame"] = "ë³´ìŠ¤ í”„ë ˆìž„"
L["TotemBarOverlay"] = "í† í…œ ë°”"
L["PlayerCastbar"] = "ì‹œì „ë°”"
L["TooltipWidget"] = "íˆ´íŒ"
L["Buff"] = "버프"
L["Debuffs"] = "디버프"
L["WeaponEnchants"] = "ë¬´ê¸° ê°•í™” íš¨ê³¼"
L["Loot Roll"] = "ì£¼ì‚¬ìœ„ êµ´ë¦¼"
L["Quest Tracker"] = "í€˜ìŠ¤íŠ¸ ì¶”ì ê¸°"

-- Mover tooltip strings
L["Drag to move"] = "ë“œëž˜ê·¸ ì´ë™"
L["Animated minimap border effects for DragonUI."] = "DragonUIìš© ì• ë‹ˆë©”ì´ì…˜ ë¯¸ë‹ˆë§µ í…Œë‘ë¦¬ íš¨ê³¼."
L["Click to reset"] = "클릭으로 초기화"
L["Right-click to reset"] = "ìš°í´ë¦­ìœ¼ë¡œ ì´ˆê¸°í™”"
L["Status Tooltip:"] = "ìƒíƒœ íˆ´íŒ:"
L["Top"] = "ìœ„"
L["Bottom"] = "ì•„ëž˜"
L["Left"] = "ì™¼ìª½"
L["Right"] = "ì˜¤ë¥¸ìª½"
L["Error Messages"] = "ì˜¤ë¥˜ ë©”ì‹œì§€"
L["ErrorMessages"] = "ì˜¤ë¥˜ ë©”ì‹œì§€"

-- Editor mode system messages
L["All editable frames shown for editing"] = "íŽ¸ì§‘ì„ ìœ„í•´ ëª¨ë“  í”„ë ˆìž„ì„ í‘œì‹œí•©ë‹ˆë‹¤."
L["All editable frames hidden, positions saved"] = "ëª¨ë“  í”„ë ˆìž„ì„ ìˆ¨ê¸°ê³  ìœ„ì¹˜ë¥¼ ì €ìž¥í–ˆìŠµë‹ˆë‹¤."

-- ============================================================================
-- COMPATIBILITY MODULE
-- ============================================================================

-- Conflict warning popup
L["DragonUI Conflict Warning"] = "DragonUI ì¶©ëŒ ê²½ê³ "
L["The addon |cFFFFFF00%s|r conflicts with DragonUI."] = "ì• ë“œì˜¨ |cFFFFFF00%s|r ì´(ê°€) DragonUIì™€ ì¶©ëŒí•©ë‹ˆë‹¤."
L["Reason:"] = "ì›ì¸:"
L["Disable the conflicting addon now?"] = "ì¶©ëŒí•˜ëŠ” ì• ë“œì˜¨ì„ ì§€ê¸ˆ ë¹„í™œì„±í™”í•˜ì‹œê² ìŠµë‹ˆê¹Œ?"
L["Keep Both"] = "ë‘˜ ë‹¤ ìœ ì§€"
L["DragonUI - D3D9Ex Warning"] = "DragonUI - D3D9Ex ê²½ê³ "
L["DragonUI detected that your client is using D3D9Ex."] = "DragonUIê°€ í´ë¼ì´ì–¸íŠ¸ê°€ D3D9Exë¥¼ ì‚¬ìš© ì¤‘ì¸ ê²ƒì„ ê°ì§€í–ˆìŠµë‹ˆë‹¤."
L["DragonUI's action bar system is not compatible with D3D9Ex."] = "DragonUIì˜ ì•¡ì…˜ë°” ì‹œìŠ¤í…œì€ D3D9Exì™€ í˜¸í™˜ë˜ì§€ ì•ŠìŠµë‹ˆë‹¤."
L["Some DragonUI action bar textures will be missing while this mode is active."] = "ì´ ëª¨ë“œê°€ í™œì„±í™”ëœ ë™ì•ˆ ì¼ë¶€ DragonUI ì•¡ì…˜ë°” í…ìŠ¤ì²˜ê°€ ë³´ì´ì§€ ì•ŠìŠµë‹ˆë‹¤."
L["If you want to disable this mode, open WTF\\Config.wtf."] = "ì´ ëª¨ë“œë¥¼ ë„ë ¤ë©´ WTF\\Config.wtf íŒŒì¼ì„ ì—¬ì„¸ìš”."
L["Delete this line:"] = "ì´ ì¤„ì„ ì‚­ì œí•˜ì„¸ìš”:"
L["Or replace it with:"] = "ë˜ëŠ” ì´ ì¤„ë¡œ ë°”ê¾¸ì„¸ìš”:"
L["Hide Gryphons"] = "ê·¸ë¦¬í•€ ìˆ¨ê¸°ê¸°"
L["Understood"] = "í™•ì¸"
L["DragonUI - UnitFrameLayers Detected"] = "DragonUI - UnitFrameLayers ê°ì§€ë¨"
L["DragonUI already includes Unit Frame Layers functionality (heal prediction, absorb shields, and animated health loss)."] = "DragonUIì—ëŠ” ì´ë¯¸ Unit Frame Layers ê¸°ëŠ¥(ì¹˜ìœ  ì˜ˆì¸¡, í¡ìˆ˜ ë³´í˜¸ë§‰, ì• ë‹ˆë©”ì´ì…˜ ì²´ë ¥ ì†ì‹¤)ì´ í¬í•¨ë˜ì–´ ìžˆìŠµë‹ˆë‹¤."
L["Choose how to resolve this overlap:"] = "ì´ ì¤‘ë³µì„ í•´ê²°í•  ë°©ë²•ì„ ì„ íƒí•˜ì„¸ìš”:"
L["Use DragonUI: disable external UnitFrameLayers and enable DragonUI layers."] = "DragonUI ì‚¬ìš©: ì™¸ë¶€ UnitFrameLayersë¥¼ ë„ê³  DragonUI ë ˆì´ì–´ë¥¼ ì¼­ë‹ˆë‹¤."
L["Disable Both: disable external UnitFrameLayers and keep DragonUI layers disabled."] = "ë‘˜ ë‹¤ ë¹„í™œì„±í™”: ì™¸ë¶€ UnitFrameLayersë¥¼ ë„ê³  DragonUI ë ˆì´ì–´ë„ ëˆ ìƒíƒœë¡œ ìœ ì§€í•©ë‹ˆë‹¤."
L["Use DragonUI"] = "DragonUI ì‚¬ìš©"
L["Disable Both"] = "ë‘˜ ë‹¤ ë¹„í™œì„±í™”"
L["Use DragonUI Unit Frame Layers"] = "DragonUI Unit Frame Layers ì‚¬ìš©"
L["Disable both Unit Frame Layers"] = "ë‘ Unit Frame Layers ëª¨ë‘ ë¹„í™œì„±í™”"
L["DragonUI - Party Frame Issue"] = true
L["You joined a party while in combat. Due to CompactRaidFrame taint issues, party frames may not display correctly."] = true
L["Reload the UI to fix party frame display?"] = true

-- Conflict reasons
L["Conflicts with DragonUI's custom unit frame textures and power bar system."] = "DragonUIì˜ ì‚¬ìš©ìž ì§€ì • ìœ ë‹› í”„ë ˆìž„ í…ìŠ¤ì²˜ ë° ìžì› ë°” ì‹œìŠ¤í…œê³¼ ì¶©ëŒí•©ë‹ˆë‹¤."
L["Known taint issues when manipulating party frames during combat. DragonUI provides automatic fixes."] = "ì „íˆ¬ ì¤‘ íŒŒí‹° í”„ë ˆìž„ ì¡°ìž‘ ì‹œ ì•Œë ¤ì§„ ì˜¤ì—¼ ë¬¸ì œê°€ ìžˆìŠµë‹ˆë‹¤. DragonUIê°€ ìžë™ ìˆ˜ì • ê¸°ëŠ¥ì„ ì œê³µí•©ë‹ˆë‹¤."
L["Resets minimap mask and blip textures. DragonUI re-applies its custom textures automatically."] = "ë¯¸ë‹ˆë§µ ë§ˆìŠ¤í¬ì™€ ë¸”ë¦½ í…ìŠ¤ì²˜ë¥¼ ì´ˆê¸°í™”í•©ë‹ˆë‹¤. DragonUIê°€ ì‚¬ìš©ìž ì§€ì • í…ìŠ¤ì²˜ë¥¼ ìžë™ìœ¼ë¡œ ë‹¤ì‹œ ì ìš©í•©ë‹ˆë‹¤."
L["SexyMap modifies the minimap borders, shape, and zone text which conflicts with DragonUI's minimap module."] = "SexyMapì´ ë¯¸ë‹ˆë§µ í…Œë‘ë¦¬, ëª¨ì–‘, ì§€ì—­ ì´ë¦„ í…ìŠ¤íŠ¸ë¥¼ ë³€ê²½í•˜ì—¬ DragonUIì˜ ë¯¸ë‹ˆë§µ ëª¨ë“ˆê³¼ ì¶©ëŒí•©ë‹ˆë‹¤."
L["Reads native nameplate alpha to identify the target's plate; conflicts with DragonUI's default anti-dim behavior."] = "네임플레이트의 기본 알파값으로 대상 플레이트를 식별합니다. DragonUI의 기본 밝기 유지(디밍 방지) 기능과 충돌합니다."
L["Parents its cooldown icons to the native health bar; conflicts with DragonUI's default health-bar hiding."] = "재사용 대기시간 아이콘을 기본 생명력 바에 연결합니다. DragonUI의 기본 생명력 바 숨김과 충돌합니다."

-- Nameplate addon compatibility popup
L["Detected |cFFFFFF00%s|r. Enable Nameplate Addon Compatibility so it works correctly?"] = "|cFFFFFF00%s|r 감지됨. 올바르게 작동하도록 네임플레이트 addon 호환성을 활성화하시겠습니까?"
L["Detected |cFFFFFF00%s|r. Enable Nameplate Health Bar Compatibility so it works correctly?"] = "|cFFFFFF00%s|r 감지됨. 올바르게 작동하도록 네임플레이트 생명력 바 호환성을 활성화하시겠습니까?"
L["Enable"] = "활성화"

-- SexyMap compatibility popup
L["DragonUI - SexyMap Detected"] = "DragonUI - SexyMap ê°ì§€ë¨"
L["Which minimap do you want to use?"] = "ì–´ë–¤ ë¯¸ë‹ˆë§µì„ ì‚¬ìš©í•˜ì‹œê² ìŠµë‹ˆê¹Œ?"
L["SexyMap"] = "SexyMap"
L["DragonUI"] = "DragonUI"
L["Hybrid"] = "í•˜ì´ë¸Œë¦¬ë“œ"
L["Recommended"] = "ê¶Œìž¥"

-- SexyMap options panel
L["SexyMap Compatibility"] = "SexyMap í˜¸í™˜ì„±"
L["Minimap Mode"] = "ë¯¸ë‹ˆë§µ ëª¨ë“œ"
L["Choose how DragonUI and SexyMap share the minimap."] = "DragonUIì™€ SexyMapì´ ë¯¸ë‹ˆë§µì„ ì–´ë–»ê²Œ í•¨ê»˜ ì‚¬ìš©í• ì§€ ì„ íƒí•˜ì„¸ìš”."
L["Requires UI reload to apply."] = "ì ìš©í•˜ë ¤ë©´ UI ìž¬ì‹¤í–‰ì´ í•„ìš”í•©ë‹ˆë‹¤."
L["Uses SexyMap for the minimap."] = "ë¯¸ë‹ˆë§µì— SexyMapì„ ì‚¬ìš©í•©ë‹ˆë‹¤."
L["Uses DragonUI for the minimap."] = "ë¯¸ë‹ˆë§µì— DragonUIë¥¼ ì‚¬ìš©í•©ë‹ˆë‹¤."
L["SexyMap visuals with DragonUI editor and positioning."] = "SexyMap ì™¸í˜•ì„ ì‚¬ìš©í•˜ë©´ì„œ DragonUI íŽ¸ì§‘ê¸°ì™€ ìœ„ì¹˜ ì¡°ì •ì„ ìœ ì§€í•©ë‹ˆë‹¤."
L["Minimap mode changed. Reload UI to apply?"] = "ë¯¸ë‹ˆë§µ ëª¨ë“œê°€ ë³€ê²½ë˜ì—ˆìŠµë‹ˆë‹¤. ì ìš©í•˜ë ¤ë©´ UIë¥¼ ìž¬ì‹¤í–‰í•˜ì‹œê² ìŠµë‹ˆê¹Œ?"

-- SexyMap slash commands
L["SexyMap compatibility mode has been reset. Reload UI to choose again."] = "SexyMap í˜¸í™˜ ëª¨ë“œê°€ ì´ˆê¸°í™”ë˜ì—ˆìŠµë‹ˆë‹¤. ë‹¤ì‹œ ì„ íƒí•˜ë ¤ë©´ UIë¥¼ ìž¬ì‹¤í–‰í•˜ì„¸ìš”."
L["Current SexyMap mode: |cFFFFFF00%s|r"] = "í˜„ìž¬ SexyMap ëª¨ë“œ: |cFFFFFF00%s|r"
L["No SexyMap mode selected (SexyMap not detected or not yet chosen)."] = "SexyMap ëª¨ë“œê°€ ì„ íƒë˜ì§€ ì•Šì•˜ìŠµë‹ˆë‹¤. (SexyMapì´ ê°ì§€ë˜ì§€ ì•Šì•˜ê±°ë‚˜ ì•„ì§ ì„ íƒë˜ì§€ ì•ŠìŒ)"
L["Show current SexyMap compatibility mode"] = "í˜„ìž¬ SexyMap í˜¸í™˜ ëª¨ë“œ í‘œì‹œ"
L["Reset SexyMap mode choice (re-prompts on reload)"] = "SexyMap ëª¨ë“œ ì„ íƒ ì´ˆê¸°í™” (ìž¬ì‹¤í–‰ ì‹œ ë‹¤ì‹œ ë¬»ê¸°)"
L["Loaded addons:"] = "ë¡œë“œëœ ì• ë“œì˜¨:"

-- ============================================================================
-- STATIC POPUPS (shared between modules)
-- ============================================================================

L["Changing this setting requires a UI reload to apply correctly."] = "ì´ ì„¤ì •ì„ ì˜¬ë°”ë¥´ê²Œ ì ìš©í•˜ë ¤ë©´ UIë¥¼ ìž¬ì„¤ì •í•´ì•¼ í•©ë‹ˆë‹¤."
L["Reload UI"] = "UI ìž¬ì„¤ì •"
L["Not Now"] = "ë‚˜ì¤‘ì—"
L["Disable"] = "ë¹„í™œì„±í™”"
L["Ignore"] = "ë¬´ì‹œ"
L["Skip"] = "ê±´ë„ˆë›°ê¸°"
L["The Blizzard option |cFFFFFF00Party/Arena Background|r is enabled. This conflicts with DragonUI's party frames."] = "ë¸”ë¦¬ìžë“œ ì˜µì…˜ |cFFFFFF00íŒŒí‹°/íˆ¬ê¸°ìž¥ ë°°ê²½|rì´ í™œì„±í™”ë˜ì–´ ìžˆìŠµë‹ˆë‹¤. DragonUI íŒŒí‹° í”„ë ˆìž„ê³¼ ì¶©ëŒí•©ë‹ˆë‹¤."
L["Disable it now?"] = "ì§€ê¸ˆ ë¹„í™œì„±í™”í•˜ì‹œê² ìŠµë‹ˆê¹Œ?"
L["Some interface settings are not configured optimally for DragonUI."] = "ì¼ë¶€ ì¸í„°íŽ˜ì´ìŠ¤ ì„¤ì •ì´ DragonUIì— ìµœì ìœ¼ë¡œ ë§žì¶°ì ¸ ìžˆì§€ ì•ŠìŠµë‹ˆë‹¤."
L["This includes settings that conflict with DragonUI and settings recommended for the best visual experience."] = "ì—¬ê¸°ì—ëŠ” DragonUIì™€ ì¶©ëŒí•˜ëŠ” ì„¤ì •ê³¼ ìµœìƒì˜ ì‹œê°ì  ê²½í—˜ì„ ìœ„í•´ ê¶Œìž¥ë˜ëŠ” ì„¤ì •ì´ í¬í•¨ë©ë‹ˆë‹¤."
L["Affected settings:"] = "ì˜í–¥ë°›ëŠ” ì„¤ì •:"
L["Some interface settings are not configured optimally for DragonUI. Do you want to fix them?"] = "ì¼ë¶€ ì¸í„°íŽ˜ì´ìŠ¤ ì„¤ì •ì´ DragonUIì— ìµœì ìœ¼ë¡œ ë§žì¶°ì ¸ ìžˆì§€ ì•ŠìŠµë‹ˆë‹¤. ì§€ê¸ˆ ìˆ˜ì •í•˜ì‹œê² ìŠµë‹ˆê¹Œ?"
L["Do you want to fix them now?"] = "ì§€ê¸ˆ ìˆ˜ì •í•˜ì‹œê² ìŠµë‹ˆê¹Œ?"
L["Party/Arena Background"] = "íŒŒí‹°/íˆ¬ê¸°ìž¥ ë°°ê²½"
L["Default Status Text"] = "ê¸°ë³¸ ìƒíƒœ í…ìŠ¤íŠ¸"
L["Conflict"] = "ì¶©ëŒ"
L["Recommended"] = "ê¶Œìž¥"

-- Bag Sort
L["Sort Bags"] = "ê°€ë°© ì •ë ¬"
L["Sort Bank"] = "ì€í–‰ ì •ë ¬"
L["Sort Items"] = "ì•„ì´í…œ ì •ë ¬"
L["Click to sort items by type, rarity, and name."] = "ìœ í˜•, í¬ê·€ë„, ì´ë¦„ìˆœìœ¼ë¡œ ì•„ì´í…œì„ ì •ë ¬í•˜ë ¤ë©´ í´ë¦­í•˜ì„¸ìš”."
L["Clear Locked Slots"] = "ìž ê¸´ ìŠ¬ë¡¯ ëª¨ë‘ í•´ì œ"
L["Click to clear all locked bag slots."] = "ìž ê¸´ ê°€ë°© ìŠ¬ë¡¯ì„ ëª¨ë‘ í•´ì œí•˜ë ¤ë©´ í´ë¦­í•˜ì„¸ìš”."
L["Alt+LeftClick any bag slot (item or empty) to lock or unlock it."] = "ê°€ë°© ìŠ¬ë¡¯(ì•„ì´í…œ ìžˆìŒ/ì—†ìŒ ë¬´ê´€)ì„ Alt+ì™¼ìª½ í´ë¦­í•˜ì—¬ ìž ê¸ˆ/ìž ê¸ˆ í•´ì œí•˜ì„¸ìš”."
L["Click the lock-clear button to remove all locked slots."] = "ìž ê¸ˆ í•´ì œ ë²„íŠ¼ì„ í´ë¦­í•˜ë©´ ìž ê¸´ ìŠ¬ë¡¯ì´ ëª¨ë‘ í•´ì œë©ë‹ˆë‹¤."
L["Hover an item or slot, then type /sortlock."] = "ì•„ì´í…œ ë˜ëŠ” ìŠ¬ë¡¯ì— ë§ˆìš°ìŠ¤ë¥¼ ì˜¬ë¦° ë’¤ /sortlock ì„ ìž…ë ¥í•˜ì„¸ìš”."
L["Slot locked (bag %d, slot %d)."] = "ìŠ¬ë¡¯ ìž ê¸ˆë¨ (ê°€ë°© %d, ìŠ¬ë¡¯ %d)."
L["Slot unlocked (bag %d, slot %d)."] = "ìŠ¬ë¡¯ ìž ê¸ˆ í•´ì œë¨ (ê°€ë°© %d, ìŠ¬ë¡¯ %d)."
L["You must be at the guild bank."] = "길드 은행에 있어야 합니다."
L["Could not determine the current guild bank tab."] = "현재 길드 은행 탭을 확인할 수 없습니다."
L["You need full deposit and withdraw access to this tab to sort it."] = "이 탭을 정렬하려면 예치 및 인출 권한이 모두 필요합니다."
L["This guild bank tab is already sorted!"] = "이 길드 은행 탭은 이미 정렬되어 있습니다!"
L["Sort this guild bank tab? Depending on your server, this may be logged and count against your guild's shared withdrawal allowance, the same as moving items by hand."] = "이 길드 은행 탭을 정렬하시겠습니까? 서버에 따라 직접 아이템을 옮기는 것과 마찬가지로 기록되거나 길드의 공유 인출 한도에 포함될 수 있습니다."
L["Sort"] = "정렬"
L["Click to sort items in the currently open guild bank tab."] = "현재 열려 있는 길드 은행 탭의 아이템을 정렬하려면 클릭하세요."
L["Never moves items between tabs."] = "탭 간에는 절대 아이템을 이동하지 않습니다."
L["Sort Guild Bank Tab"] = "길드 은행 탭 정렬"
L["Could not clear locks (config not ready)."] = "ìž ê¸ˆì„ í•´ì œí•  ìˆ˜ ì—†ìŠµë‹ˆë‹¤ (ì„¤ì •ì´ ì•„ì§ ì¤€ë¹„ë˜ì§€ ì•ŠìŒ)."
L["Cleared all sort-locked slots."] = "ì •ë ¬ ìž ê¸ˆ ìŠ¬ë¡¯ì „ ëª¨ë' ì§€í•´ì œí–ˆìŠµë‹ˆë‹¤."

-- Sell Scrap
L["Sell Scrap"] = "ê³*ì²* íŒë§¤"
L["Open a merchant window first to sell scrap items."] = "ê³*ì²*ì „ íŒë§¤í•˜ë ¤ë©´ ë¨¼ì €€ ìƒì ¸ ì°½ì „ ì—¬ì„¸ìš”."

-- Micromenu Latency
L["Network"] = "ë„¤íŠ¸ì›Œí¬"
L["Latency"] = "ì§€ì—° ì‹œê°„"

-- ============================================================================
-- STABILIZATION PATCH STRINGS
-- ============================================================================

L["/dragonui debug on|off|status - Toggle diagnostic logging"] = "/dragonui debug on|off|status - ì§„ë‹¨ ë¡œê·¸ ì „í™˜"
L["Usage: /dragonui debug on|off|status"] = "ì‚¬ìš©ë²•: /dragonui debug on|off|status"
L["Enable debug mode first with /dragonui debug on"] = "ë¨¼ì € /dragonui debug on ìœ¼ë¡œ ë””ë²„ê·¸ ëª¨ë“œë¥¼ í™œì„±í™”í•˜ì„¸ìš”"
L["Debug mode is %s"] = "ë””ë²„ê·¸ ëª¨ë“œëŠ” í˜„ìž¬ %s ìƒíƒœìž…ë‹ˆë‹¤"
L["Debug mode enabled"] = "ë””ë²„ê·¸ ëª¨ë“œê°€ í™œì„±í™”ë˜ì—ˆìŠµë‹ˆë‹¤"
L["Debug mode disabled"] = "ë””ë²„ê·¸ ëª¨ë“œê°€ ë¹„í™œì„±í™”ë˜ì—ˆìŠµë‹ˆë‹¤"
L["enabled"] = true
L["disabled"] = true
L["Enabled"] = "í™œì„±í™”ë¨"
L["Disabled"] = "ë¹„í™œì„±í™”ë¨"
L["Legacy refresh failed for"] = true
L["RegisterMover: name and parent are required"] = true
L["Bonus Action Button %d"] = true
L["Stance Button %d"] = true
L["Pet Action Button %d"] = true
L["Multicast Button %d"] = true
L["Totem Call Button"] = true
L["Totem Recall Button"] = true
L["Bottom Left Button"] = true
L["Bottom Right Button"] = true
L["Right Button"] = true
L["Left Button"] = true
L["Totem Bar"] = "í† í…œ ë°”"
L["Test Pet"] = true
L["=== TargetFrame children (depth 3) ==="] = true
L["=== FocusFrame children (depth 3) ==="] = true
L["BG texture not found"] = true
L["BG tinted RED"] = true
L["BG tinted GREEN"] = true
L["BG color reset"] = true
L["=== BANK SCAN DEBUG ==="] = true
L["=== BANK QUALITY DEBUG ==="] = true
L["Module enabled:"] = true
L["BankFrame exists:"] = true
L["BankFrame shown:"] = true
L["Usage: /dui shadowcolor red|green|reset|info"] = true
L["Usage: /dui shadowcrop <bottom_px> [right_px]"] = true
L["  e.g. /dui shadowcrop 90 - show top 90 of 128 px height"] = true
L["  e.g. /dui shadowcrop 90 200 - crop both bottom and right"] = true
L["  /dui shadowcrop reset - restore full texture"] = true
L["BG reset to 256x128 full texture"] = true
L["Crop applied: showing %dx%d of 256x128 (texcoord 0-%.3f, 0-%.3f)"] = true
L["Invalid values. Height 1-128, Width 1-256"] = true
L["=== TargetFrame elements (use /dui shadowtest N to toggle) ==="] = true
L["Total elements: %d"] = true
L["HIDDEN: %d. %s [%s]"] = true
L["SHOWN: %d. %s [%s]"] = true
L["Invalid element number. Use /dui shadowtest to list."] = true
L["DragonUI Compatibility:"] = true
L["Registered Modules:"] = "ë“±ë¡ëœ ëª¨ë“ˆ:"
L["No modules registered in ModuleRegistry"] = "ModuleRegistryì— ë“±ë¡ëœ ëª¨ë“ˆì´ ì—†ìŠµë‹ˆë‹¤"
L["load-once"] = "í•œ ë²ˆë§Œ ë¡œë“œ"
L["%s will disable after /reload because its secure hooks cannot be removed safely."] = "%s ëª¨ë“ˆì€ ì•ˆì „í•œ í›…ì„ ì•ˆì „í•˜ê²Œ ì œê±°í•  ìˆ˜ ì—†ì–´ /reload í›„ ë¹„í™œì„±í™”ë©ë‹ˆë‹¤."
L["%s uses permanent secure hooks and will fully disable after /reload."] = "%s ëª¨ë“ˆì€ ì˜êµ¬ì ì¸ ì•ˆì „ í›…ì„ ì‚¬ìš©í•˜ë¯€ë¡œ /reload í›„ ì™„ì „ížˆ ë¹„í™œì„±í™”ë©ë‹ˆë‹¤."
L["%s remains active until /reload because its secure hooks cannot be removed safely."] = "%s ëª¨ë“ˆì€ ì•ˆì „í•œ í›…ì„ ì•ˆì „í•˜ê²Œ ì œê±°í•  ìˆ˜ ì—†ì–´ /reload ì „ê¹Œì§€ í™œì„± ìƒíƒœë¥¼ ìœ ì§€í•©ë‹ˆë‹¤."
L["Cooldown Text"] = "ìž¬ì‚¬ìš© ëŒ€ê¸°ì‹œê°„ í…ìŠ¤íŠ¸"
L["Cooldown text on action buttons"] = "ì•¡ì…˜ ë²„íŠ¼ì˜ ìž¬ì‚¬ìš© ëŒ€ê¸°ì‹œê°„ í…ìŠ¤íŠ¸"
L["Cast Bar"] = "ì‹œì „ ë°”"
L["Custom player, target, and focus cast bars"] = "í”Œë ˆì´ì–´, ëŒ€ìƒ, ì£¼ì‹œ ëŒ€ìƒìš© ì‚¬ìš©ìž ì§€ì • ì‹œì „ ë°”"
L["Multicast"] = "ë©€í‹°ìºìŠ¤íŠ¸"
L["Shaman totem bar positioning and styling"] = "ì£¼ìˆ ì‚¬ í† í…œ ë°” ìœ„ì¹˜ ë° ìŠ¤íƒ€ì¼"
L["Player Frame"] = "í”Œë ˆì´ì–´ í”„ë ˆìž„"
L["Dragonflight-styled boss target frames"] = "Dragonflight ìŠ¤íƒ€ì¼ì˜ ìš°ë‘ë¨¸ë¦¬ ëŒ€ìƒ í”„ë ˆìž„"
L["Dragonflight-styled player unit frame"] = "Dragonflight ìŠ¤íƒ€ì¼ì˜ í”Œë ˆì´ì–´ ìœ ë‹› í”„ë ˆìž„"
L["ModuleRegistry:Register requires name and moduleTable"] = "ModuleRegistry:Registerì—ëŠ” nameê³¼ moduleTableì´ í•„ìš”í•©ë‹ˆë‹¤"
L["ModuleRegistry: Module already registered -"] = "ModuleRegistry: ì´ë¯¸ ë“±ë¡ëœ ëª¨ë“ˆ -"
L["ModuleRegistry: Registered module -"] = "ModuleRegistry: ë“±ë¡ëœ ëª¨ë“ˆ -"
L["order:"] = "ìˆœì„œ:"
L["ModuleRegistry: Refresh failed for"] = "ModuleRegistry: ìƒˆë¡œ ê³ ì¹¨ ì‹¤íŒ¨ ëŒ€ìƒ"
L["ModuleRegistry: Unknown module -"] = "ModuleRegistry: ì•Œ ìˆ˜ ì—†ëŠ” ëª¨ë“ˆ -"
L["ModuleRegistry: Enabled -"] = "ModuleRegistry: í™œì„±í™” -"
L["ModuleRegistry: Disabled -"] = "ModuleRegistry: ë¹„í™œì„±í™” -"
L["CombatQueue:Add requires id and func"] = "CombatQueue:Addì—ëŠ” idì™€ funcê°€ í•„ìš”í•©ë‹ˆë‹¤"
L["CombatQueue: Registered PLAYER_REGEN_ENABLED"] = "CombatQueue: PLAYER_REGEN_ENABLED ë“±ë¡ë¨"
L["CombatQueue: Queued operation -"] = "CombatQueue: ëŒ€ê¸°ì—´ì— ì¶”ê°€ëœ ìž‘ì—… -"
L["CombatQueue: Removed operation -"] = "CombatQueue: ì œê±°ëœ ìž‘ì—… -"
L["CombatQueue: Processing"] = "CombatQueue: ì²˜ë¦¬ ì¤‘"
L["queued operations"] = "ëŒ€ê¸° ì¤‘ì¸ ìž‘ì—…"
L["CombatQueue: Failed to execute"] = "CombatQueue: ì‹¤í–‰ ì‹¤íŒ¨"
L["CombatQueue: Executed -"] = "CombatQueue: ì‹¤í–‰ ì™„ë£Œ -"
L["CombatQueue: Unregistered PLAYER_REGEN_ENABLED"] = "CombatQueue: PLAYER_REGEN_ENABLED ë“±ë¡ í•´ì œë¨"
L["CombatQueue: Immediate execution failed -"] = "CombatQueue: ì¦‰ì‹œ ì‹¤í–‰ ì‹¤íŒ¨ -"

-- ============================================================================
-- RELEASE PREP STRINGS
-- ============================================================================

L["Buttons"] = "ë²„íŠ¼"
L["Action button styling and enhancements"] = "ì•¡ì…˜ ë²„íŠ¼ ìŠ¤íƒ€ì¼ ë° ê°œì„ "
L["Dark Mode"] = "ë‹¤í¬ ëª¨ë“œ"
L["Darken UI borders and chrome"] = "UI í…Œë‘ë¦¬ì™€ ìž¥ì‹ì„ ì–´ë‘¡ê²Œ í‘œì‹œ"
L["Item Quality"] = "ì•„ì´í…œ í’ˆì§ˆ"
L["Color item borders by quality in bags, character panel, bank, and merchant"] = "ê°€ë°©, ìºë¦­í„° ì°½, ì€í–‰, ìƒì¸ ì°½ì˜ ì•„ì´í…œ í…Œë‘ë¦¬ë¥¼ í’ˆì§ˆë³„ë¡œ í‘œì‹œ"
L["Key Binding"] = "í‚¤ ë°”ì¸ë”©"
L["LibKeyBound integration for intuitive keybinding"] = "ì§ê´€ì ì¸ í‚¤ ì„¤ì •ì„ ìœ„í•œ LibKeyBound í†µí•©"
L["Buff Frame"] = "ë²„í”„ í”„ë ˆìž„"
L["Custom buff frame styling, positioning and toggle button"] = "ë²„í”„ í”„ë ˆìž„ ì‚¬ìš©ìž ì§€ì • ìŠ¤íƒ€ì¼, ìœ„ì¹˜ ë° í† ê¸€ ë²„íŠ¼"
L["Chat Mods"] = "ì±„íŒ… ê¸°ëŠ¥"
L["Chat enhancements: hide buttons, editbox position, URL copy, chat copy, link hover, tell target"] = "ì±„íŒ… ê°œì„ : ë²„íŠ¼ ìˆ¨ê¹€, ìž…ë ¥ì°½ ìœ„ì¹˜, URL ë³µì‚¬, ì±„íŒ… ë³µì‚¬, ë§í¬ ë¯¸ë¦¬ë³´ê¸°, ëŒ€ìƒì—ê²Œ ê·“ì†ë§"
L["Bag Sort"] = "ê°€ë°© ì •ë ¬"
L["Sort bags and bank items with buttons"] = "ë²„íŠ¼ìœ¼ë¡œ ê°€ë°©ê³¼ ì€í–‰ ì•„ì´í…œ ì •ë ¬"
L["Bag Skin"] = "가방 스킨"
L["Retail-style skin for Blizzard bag windows"] = "블리자드 가방 창에 정식 서버 스타일 스킨 적용"
L["Combuctor"] = "Combuctor"
L["All-in-one bag replacement with filtering and search"] = "í•„í„°ì™€ ê²€ìƒ‰ ê¸°ëŠ¥ì´ ìžˆëŠ” ì˜¬ì¸ì› ê°€ë°© ëŒ€ì²´"
L["Stance Bar"] = "íƒœì„¸ ë°”"
L["Vehicle"] = "íƒˆê²ƒ"
L["Vehicle interface enhancements"] = "íƒˆê²ƒ ì¸í„°íŽ˜ì´ìŠ¤ ê°œì„ "
L["Pet Bar"] = "ì†Œí™˜ìˆ˜ ë°”"
L["Extra Bar"] = "추가 바"
L["A standalone action bar, independent of any class bonus bar"] = "클래스 보너스 바와 무관한 독립적인 액션 바"
L["Drag a spell, item or macro here."] = "여기에 주문, 아이템 또는 매크로를 끌어다 놓으세요."
L["Micro Menu"] = "ë§ˆì´í¬ë¡œ ë©”ë‰´"
L["Main Bars"] = "ì£¼ ì•¡ì…˜ë°”"
L["Main action bars, status bars, scaling and positioning"] = "ì£¼ ì•¡ì…˜ë°”, ìƒíƒœ ë°”, í¬ê¸° ë° ìœ„ì¹˜ ì¡°ì •"
L["Hide Blizzard"] = "ë¸”ë¦¬ìžë“œ ê¸°ë³¸ UI ìˆ¨ê¹€"
L["Hide default Blizzard UI elements"] = "ê¸°ë³¸ ë¸”ë¦¬ìžë“œ UI ìš”ì†Œ ìˆ¨ê¸°ê¸°"
L["Minimap"] = "ë¯¸ë‹ˆë§µ"
L["Custom minimap styling, positioning, tracking icons and calendar"] = "ì‚¬ìš©ìž ì§€ì • ë¯¸ë‹ˆë§µ ìŠ¤íƒ€ì¼, ìœ„ì¹˜, ì¶”ì  ì•„ì´ì½˜ ë° ë‹¬ë ¥"
L["Quest tracker positioning and styling"] = "í€˜ìŠ¤íŠ¸ ì¶”ì ê¸° ìœ„ì¹˜ ë° ìŠ¤íƒ€ì¼ ì„¤ì •"
L["Tooltip"] = "íˆ´íŒ"
L["Enhanced tooltip styling with class colors and health bars"] = "ì§ì—… ìƒ‰ìƒê³¼ ìƒëª…ë ¥ ë°”ê°€ ì ìš©ëœ í–¥ìƒëœ íˆ´íŒ ìŠ¤íƒ€ì¼"
L["Nameplates"] = "이름표"
L["Apply DragonUI nameplate styling."] = "DragonUI 스타일을 이름표에 적용합니다."
L["Unit Frame Layers"] = "ìœ ë‹› í”„ë ˆìž„ ë ˆì´ì–´"
L["Heal prediction, absorb shields, and animated health loss on unit frames"] = "ìœ ë‹› í”„ë ˆìž„ì˜ ì¹˜ìœ  ì˜ˆì¸¡, í¡ìˆ˜ ë³´í˜¸ë§‰ ë° ì• ë‹ˆë©”ì´ì…˜ ì²´ë ¥ ì†ì‹¤"
L["Stance/shapeshift bar positioning and styling"] = "íƒœì„¸/ë³€ì‹  ë°” ìœ„ì¹˜ ë° ìŠ¤íƒ€ì¼ ì„¤ì •"
L["Pet action bar positioning and styling"] = "ì†Œí™˜ìˆ˜ ì•¡ì…˜ ë°” ìœ„ì¹˜ ë° ìŠ¤íƒ€ì¼ ì„¤ì •"
L["Micro menu and bags system styling and positioning"] = "ë§ˆì´í¬ë¡œ ë©”ë‰´ ë° ê°€ë°© ì‹œìŠ¤í…œ ìŠ¤íƒ€ì¼/ìœ„ì¹˜ ì„¤ì •"
L["Sort complete."] = "ì •ë ¬ì´ ì™„ë£Œë˜ì—ˆìŠµë‹ˆë‹¤."
L["Sort already in progress."] = "ì •ë ¬ì´ ì´ë¯¸ ì§„í–‰ ì¤‘ìž…ë‹ˆë‹¤."
L["Bags already sorted!"] = "ê°€ë°©ì´ ì´ë¯¸ ì •ë ¬ë˜ì–´ ìžˆìŠµë‹ˆë‹¤!"
L["You must be at the bank."] = "ì€í–‰ì— ìžˆì–´ì•¼ í•©ë‹ˆë‹¤."
L["Bank already sorted!"] = "ì€í–‰ì´ ì´ë¯¸ ì •ë ¬ë˜ì–´ ìžˆìŠµë‹ˆë‹¤!"
L["Reputation: "] = "í‰íŒ: "
L["Error in SafeCall:"] = "SafeCall ì˜¤ë¥˜:"

L["Double-Click to Copy"] = "|cff33ff11ë”ë¸” í´ë¦­|rí•˜ì—¬ ë³µì‚¬"
L["Copy Text"] = "í…ìŠ¤íŠ¸ ë³µì‚¬"

-- Version Check Module
L["Version Check"] = "버전 확인"
L["Broadcast and detect addon version updates across group members"] = "그룹원 간 애드온 버전 업데이트를 감지하고 방송합니다"
