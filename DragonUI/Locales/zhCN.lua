--[[
================================================================================
DragonUI - 简体中文本地化文件
================================================================================
主插件本地化：命令、弹窗、编辑模式标签、调试提示等。

新增字符串时：
1. 在 enUS.lua 中新增键
2. 在代码中使用 L["你的字符串"]
3. 在此文件中补充翻译
================================================================================
]]

local L = LibStub("AceLocale-3.0"):NewLocale("DragonUI", "zhCN")
if not L then return end

-- ============================================================================
-- 核心 / 通用
-- ============================================================================

L["Cannot toggle editor mode during combat!"] = "战斗中无法切换编辑模式！"
L["Cannot reset positions during combat!"] = "战斗中无法重置位置！"
L["Cannot toggle keybind mode during combat!"] = "战斗中无法切换按键绑定模式！"
L["Cannot move frames during combat!"] = "战斗中无法移动框体！"
L["Cannot open options in combat."] = "战斗中无法打开选项。"
L["Options panel not available. Try /reload."] = "选项面板不可用，请尝试 /reload。"

L["Editor mode not available."] = "编辑模式不可用。"
L["Keybind mode not available."] = "按键绑定模式不可用。"
L["Vehicle debug not available"] = "载具调试不可用"
L["KeyBinding module not available"] = "按键绑定模块不可用"
L["Unable to open configuration"] = "无法打开配置"
L["Commands: /dragonui config, /dragonui edit"] = "命令：/dragonui config，/dragonui edit"
L["Reset position: %s"] = "已重置位置：%s"
L["All positions reset to defaults"] = "所有位置已重置为默认值"
L["Editor mode enabled - Drag frames to reposition"] = "编辑模式已启用 - 拖动框体以重新定位"
L["Editor mode disabled - Positions saved"] = "编辑模式已关闭 - 位置已保存"
L["Minimap module restored to Blizzard defaults"] = "小地图模块已恢复为暴雪默认设置"
L["All action bar scales reset to default values"] = "所有动作条缩放已重置为默认值"
L["Minimap position reset to default"] = "小地图位置已重置为默认值"
L["Targeting: %s"] = "目标：%s"
L["XP: %d/%d"] = "经验值：%d/%d"
L["GROUP %d"] = "第 %d 队"
L["XP: "] = "经验值："
L["Remaining: "] = "剩余："
L["Rested: "] = "休息："

L["Error executing pending operation:"] = "执行待处理操作时出错："
L["Error -- Addon 'DragonUI_Options' not found or is disabled."] = "错误：插件 'DragonUI_Options' 未找到或已被禁用。"

-- ============================================================================
-- 斜杠命令 / 帮助
-- ============================================================================

L["Unknown command: "] = "未知命令："
L["=== DragonUI Commands ==="] = "=== DragonUI 命令 ==="
L["/dragonui or /dui - Open configuration"] = "/dragonui 或 /dui - 打开配置"
L["/dragonui config - Open configuration"] = "/dragonui config - 打开配置"
L["/dragonui edit - Toggle editor mode (move UI elements)"] = "/dragonui edit - 切换编辑模式（移动界面元素）"
L["/dragonui reset - Reset all positions to defaults"] = "/dragonui reset - 重置所有位置为默认值"
L["/dragonui reset <name> - Reset specific mover"] = "/dragonui reset <name> - 重置指定移动器"
L["/dragonui status - Show module status"] = "/dragonui status - 显示模块状态"
L["/dragonui kb - Toggle keybind mode"] = "/dragonui kb - 切换按键绑定模式"
L["/dragonui version - Show version info"] = "/dragonui version - 显示版本信息"
L["/dragonui help - Show this help"] = "/dragonui help - 显示此帮助"
L["/rl - Reload UI"] = "/rl - 重新加载界面"

-- ============================================================================
-- 状态显示
-- ============================================================================

L["=== DragonUI Status ==="] = "=== DragonUI 状态 ==="
L["Detected Modules:"] = "检测到的模块："
L["Loaded"] = "已加载"
L["Not Loaded"] = "未加载"
L["Target Frame"] = "目标框架"
L["Focus Frame"] = "焦点框架"
L["Party Frames"] = "小队框架"
L["Cooldowns"] = "冷却计时"
L["Registered Movers: "] = "已注册移动器："
L["Editable Frames: "] = "可编辑框体："
L["DragonUI Version: "] = "DragonUI 版本："
L["Use /dragonui edit to enter edit mode, then right-click frames to reset."] = "使用 /dragonui edit 进入编辑模式，然后右键点击框体以重置。"

-- ============================================================================
-- 编辑模式
-- ============================================================================

L["Exit Edit Mode"] = "退出编辑模式"
L["Reset All Positions"] = "重置所有位置"
L["Are you sure you want to reset all interface elements to their default positions?"] = "你确定要将所有界面元素重置到默认位置吗？"
L["Yes"] = "是"
L["No"] = "否"
L["UI elements have been repositioned. Reload UI to ensure all graphics display correctly?"] = "界面元素已重新定位。是否重新加载界面以确保所有图形正确显示？"
L["Reload Now"] = "立即重载"
L["Later"] = "稍后"

-- Position presets (edit mode)
L["Position Presets"] = "位置预设"
L["Position Preset"] = "位置预设"
L["Save"] = "保存"
L["Import"] = "导入"
L["Cancel"] = "取消"
L["Load"] = "加载"
L["Delete"] = "删除"
L["Select All"] = "全选"
L["Click to load"] = "点击加载"
L["No position presets saved yet."] = "尚未保存位置预设。"
L["Load position preset '%s'? This will overwrite your current element positions."] = "加载预设 '%s'？这将覆盖当前元素位置。"
L["Delete position preset '%s'? This cannot be undone."] = "删除预设 '%s'？此操作无法撤销。"
L["Enter a name for the imported position preset:"] = "输入导入预设的名称："
L["Imported Position Preset"] = "导入的预设"
L["Position preset saved: "] = "位置预设已保存："
L["Position preset loaded: "] = "位置预设已加载："
L["Position preset deleted: "] = "位置预设已删除："
L["Position preset imported: "] = "位置预设已导入："
L["Export Position Preset"] = "导出位置预设"
L["Import Position Preset"] = "导入位置预设"
L["Invalid position preset string."] = "无效的位置预设字符串。"
L["Not a valid DragonUI position preset string."] = "不是有效的 DragonUI 位置预设字符串。"
L["Failed to export position preset."] = "导出位置预设失败。"
L["Save New Preset"] = "保存新预设"
L["Load Preset"] = "加载预设"
L["Delete Preset"] = "删除预设"
L["Export Preset"] = "导出预设"
L["Import Preset"] = "导入预设"

-- ============================================================================
-- 按键绑定模块
-- ============================================================================

L["LibKeyBound-1.0 not found or failed to load:"] = "未找到 LibKeyBound-1.0 或其加载失败："
L["Commands:"] = "命令："
L["/dukb - Toggle keybinding mode"] = "/dukb - 切换按键绑定模式"
L["/dukb help - Show this help"] = "/dukb help - 显示此帮助"
L["Module disabled."] = "模块已禁用。"
L["Keybinding mode activated. Hover over buttons and press keys to bind them."] = "按键绑定模式已激活。将鼠标悬停在按钮上并按下按键即可绑定。"
L["Keybinding mode deactivated."] = "按键绑定模式已停用。"

-- ============================================================================
-- 游戏菜单
-- ============================================================================

L["DragonUI"] = "DragonUI"

-- ============================================================================
-- 小地图模块
-- ============================================================================

L["DragonUI: Minimap module restored to Blizzard defaults"] = "DragonUI：小地图模块已恢复为暴雪默认设置"
L["Minimap Buttons"] = "小地图按钮"
L["Minimap Buttons Collector"] = "小地图按钮"
L["Left-click to show or hide minimap addon buttons."] = "左键打开小地图按钮。"
L["Right-click to open DragonUI settings."] = "右键打开 DragonUI 设置。"

-- ============================================================================
-- 编辑模式标签
-- ============================================================================

L["MainBar"] = "主动作条"
L["RightBar"] = "右侧动作条"
L["LeftBar"] = "左侧动作条"
L["BottomBarLeft"] = "左下动作条"
L["BottomBarRight"] = "右下动作条"
L["XPBar"] = "经验条"
L["RepBar"] = "声望条"
L["MinimapFrame"] = "小地图"
L["LFGFrame"] = "地下城查找器"
L["PlayerFrame"] = "玩家"
L["ManaBar"] = "法力条"
L["PetFrame"] = "宠物"
L["ToT"] = "目标的目标"
L["ToF"] = "焦点的目标"
L["tot"] = "目标的目标"
L["fot"] = "焦点的目标"
L["PartyFrames"] = "小队"
L["TargetFrame"] = "目标"
L["FocusFrame"] = "焦点"
L["BagsBar"] = "背包"
L["MicroMenu"] = "微型菜单"
L["VehicleExitOverlay"] = "离开载具"
L["StanceOverlay"] = "姿态条"
L["petbar"] = "宠物动作条"
L["ExtraBar1"] = "额外栏"
L["boss"] = "首领框架"
L["Boss Frames"] = "首领框架"
L["Boss1Frame"] = "首领框架"
L["Boss2Frame"] = "首领框架"
L["Boss3Frame"] = "首领框架"
L["Boss4Frame"] = "首领框架"
L["TotemBarOverlay"] = "图腾条"
L["PlayerCastbar"] = "施法条"
L["TargetCastbar"] = "目标施法条"
L["FocusCastbar"] = "焦点施法条"
L["TooltipWidget"] = "鼠标提示"
L["Buff"] = "增益"
L["Debuffs"] = "减益"
L["WeaponEnchants"] = "武器附魔"
L["Loot Roll"] = "拾取掷骰"
L["Quest Tracker"] = "任务追踪"

L["Drag to move"] = "拖动以移动"
L["Animated minimap border effects for DragonUI."] = "DragonUI 的小地图动画边框效果。"
L["Click to reset"] = "点击重置"
L["Right-click to reset"] = "右键重置"
L["Status Tooltip:"] = "状态提示："
L["Top"] = "上"
L["Bottom"] = "下"
L["Left"] = "左"
L["Right"] = "右"
L["Error Messages"] = "错误消息"
L["ErrorMessages"] = "错误消息"

L["All editable frames shown for editing"] = "已显示所有可编辑框体以供编辑"
L["All editable frames hidden, positions saved"] = "所有可编辑框体已隐藏，位置已保存"

-- ============================================================================
-- 兼容性模块
-- ============================================================================

L["DragonUI Conflict Warning"] = "DragonUI 冲突警告"
L["The addon |cFFFFFF00%s|r conflicts with DragonUI."] = "插件 |cFFFFFF00%s|r 与 DragonUI 冲突。"
L["Reason:"] = "原因："
L["Disable the conflicting addon now?"] = "现在禁用冲突插件吗？"
L["Disable"] = "禁用"
L["Keep Both"] = "保留两者"
L["DragonUI - D3D9Ex Warning"] = "DragonUI - D3D9Ex 警告"
L["DragonUI detected that your client is using D3D9Ex."] = "DragonUI 检测到你的客户端正在使用 D3D9Ex。"
L["DragonUI's action bar system is not compatible with D3D9Ex."] = "DragonUI 的动作条系统与 D3D9Ex 不兼容。"
L["Some DragonUI action bar textures will be missing while this mode is active."] = "启用此模式后，部分 DragonUI 动作条纹理将不会显示。"
L["If you want to disable this mode, open WTF\\Config.wtf."] = "如果你想关闭此模式，请打开 WTF\\Config.wtf。"
L["Delete this line:"] = "删除这一行："
L["Or replace it with:"] = "或改成这一行："
L["Hide Gryphons"] = "隐藏狮鹫"
L["Understood"] = "知道了"
L["DragonUI - UnitFrameLayers Detected"] = "DragonUI - 检测到 UnitFrameLayers"
L["DragonUI already includes Unit Frame Layers functionality (heal prediction, absorb shields, and animated health loss)."] = "DragonUI 已内置单位框架层功能（治疗预估、吸收护盾和动态掉血效果）。"
L["Choose how to resolve this overlap:"] = "请选择如何处理此功能重叠："
L["Use DragonUI: disable external UnitFrameLayers and enable DragonUI layers."] = "使用 DragonUI：禁用外部 UnitFrameLayers，并启用 DragonUI 的框架层。"
L["Disable Both: disable external UnitFrameLayers and keep DragonUI layers disabled."] = "全部禁用：禁用外部 UnitFrameLayers，并保持 DragonUI 的框架层关闭。"
L["Use DragonUI"] = "使用 DragonUI"
L["Disable Both"] = "全部禁用"
L["Use DragonUI Unit Frame Layers"] = "使用 DragonUI 单位框架层"
L["Disable both Unit Frame Layers"] = "同时禁用两个单位框架层"

L["Conflicts with DragonUI's custom unit frame textures and power bar system."] = "与 DragonUI 的自定义单位框架纹理和能量条系统冲突。"
L["Resets minimap mask and blip textures. DragonUI re-applies its custom textures automatically."] = "会重置小地图遮罩和图标纹理。DragonUI 会自动重新应用自定义纹理。"
L["SexyMap modifies the minimap borders, shape, and zone text which conflicts with DragonUI's minimap module."] = "SexyMap 会修改小地图边框、形状和区域文字，这与 DragonUI 的小地图模块冲突。"
L["Reads native nameplate alpha to identify the target's plate; conflicts with DragonUI's default anti-dim behavior."] = "通过姓名板的原生透明度来识别目标姓名板，与 DragonUI 默认的防变暗行为冲突。"
L["Parents its cooldown icons to the native health bar; conflicts with DragonUI's default health-bar hiding."] = "将其冷却图标挂到原生生命条上；与 DragonUI 默认隐藏该生命条的行为冲突。"

L["Detected |cFFFFFF00%s|r. Enable Nameplate Addon Compatibility so it works correctly?"] = "检测到 |cFFFFFF00%s|r。是否启用姓名板插件兼容模式以使其正常工作？"
L["Detected |cFFFFFF00%s|r. Enable Nameplate Health Bar Compatibility so it works correctly?"] = "检测到 |cFFFFFF00%s|r。是否启用姓名板生命条兼容模式以使其正常工作？"
L["Enable"] = "启用"

L["DragonUI - SexyMap Detected"] = "DragonUI - 检测到 SexyMap"
L["Which minimap do you want to use?"] = "你想使用哪种小地图？"
L["SexyMap"] = "SexyMap"
L["DragonUI"] = "DragonUI"
L["Hybrid"] = "混合"
L["Recommended"] = "推荐"

L["SexyMap Compatibility"] = "SexyMap 兼容性"
L["Minimap Mode"] = "小地图模式"
L["Choose how DragonUI and SexyMap share the minimap."] = "选择 DragonUI 与 SexyMap 如何共享小地图。"
L["Requires UI reload to apply."] = "需要重新加载界面才能生效。"
L["Uses SexyMap for the minimap."] = "小地图使用 SexyMap。"
L["Uses DragonUI for the minimap."] = "小地图使用 DragonUI。"
L["SexyMap visuals with DragonUI editor and positioning."] = "使用 SexyMap 的外观，同时保留 DragonUI 的编辑与定位功能。"
L["Minimap mode changed. Reload UI to apply?"] = "小地图模式已更改。是否重新加载界面以应用？"

L["SexyMap compatibility mode has been reset. Reload UI to choose again."] = "SexyMap 兼容模式已重置。重新加载界面后可重新选择。"
L["Current SexyMap mode: |cFFFFFF00%s|r"] = "当前 SexyMap 模式：|cFFFFFF00%s|r"
L["No SexyMap mode selected (SexyMap not detected or not yet chosen)."] = "尚未选择 SexyMap 模式（未检测到 SexyMap，或尚未做出选择）。"
L["Show current SexyMap compatibility mode"] = "显示当前 SexyMap 兼容模式"
L["Reset SexyMap mode choice (re-prompts on reload)"] = "重置 SexyMap 模式选择（重载后会再次提示）"
L["Loaded addons:"] = "已加载插件："

-- ============================================================================
-- 静态弹窗
-- ============================================================================

L["Changing this setting requires a UI reload to apply correctly."] = "更改此设置需要重新加载界面才能正确生效。"
L["Reload UI"] = "重新加载界面"
L["Not Now"] = "暂不"
L["Disable"] = "禁用"
L["Ignore"] = "忽略"
L["Skip"] = "跳过"
L["The Blizzard option |cFFFFFF00Party/Arena Background|r is enabled. This conflicts with DragonUI's party frames."] = "暴雪选项 |cFFFFFF00Party/Arena Background|r 已启用。这与 DragonUI 的小队框架冲突。"
L["Disable it now?"] = "现在禁用它吗？"
L["Some interface settings are not configured optimally for DragonUI."] = "某些界面设置并未针对 DragonUI 进行最佳配置。"
L["This includes settings that conflict with DragonUI and settings recommended for the best visual experience."] = "其中包括与 DragonUI 冲突的设置，以及为获得最佳视觉体验所推荐的设置。"
L["Affected settings:"] = "受影响的设置："
L["Some interface settings are not configured optimally for DragonUI. Do you want to fix them?"] = "某些界面设置未针对 DragonUI 进行最佳配置。要修复它们吗？"
L["Do you want to fix them now?"] = "现在要修复吗？"
L["Party/Arena Background"] = "小队/竞技场背景"
L["Default Status Text"] = "默认状态文字"
L["Conflict"] = "冲突"
L["Recommended"] = "推荐"

-- ============================================================================
-- 背包整理
-- ============================================================================

L["Sort Bags"] = "整理背包"
L["Sort Bank"] = "整理银行"
L["Sort Items"] = "整理物品"
L["Click to sort items by type, rarity, and name."] = "点击按类型、品质和名称整理物品。"
L["Clear Locked Slots"] = "清除锁定格子"
L["Click to clear all locked bag slots."] = "点击清除所有已锁定的背包格子。"
L["Alt+LeftClick any bag slot (item or empty) to lock or unlock it."] = "对任意背包格子（有物品或空格）按 Alt+左键 可锁定或解锁。"
L["Click the lock-clear button to remove all locked slots."] = "点击清锁按钮以移除所有锁定格子。"
L["Hover an item or slot, then type /sortlock."] = "将鼠标悬停在物品或格子上，然后输入 /sortlock。"
L["Slot locked (bag %d, slot %d)."] = "格子已锁定（背包 %d，槽位 %d）。"
L["Slot unlocked (bag %d, slot %d)."] = "格子已解锁（背包 %d，槽位 %d）。"
L["Could not clear locks (config not ready)."] = "无法清除锁定（配置尚未就绪）。"
L["Cleared all sort-locked slots."] = "已清除所有整理锁定格子。"

-- Sell Scrap
L["Sell Scrap"] = "出售垃圾"
L["Open a merchant window first to sell scrap items."] = "请先打开商人窗口再出售垃圾物品。"

-- Guild Bank Sort
L["You must be at the guild bank."] = "你必须在公会银行。"
L["Could not determine the current guild bank tab."] = "无法确定当前的公会银行页签。"
L["You need full deposit and withdraw access to this tab to sort it."] = "你需要拥有该页签的完整存取权限才能整理它。"
L["This guild bank tab is already sorted!"] = "该公会银行页签已经整理好了！"
L["Sort this guild bank tab? Depending on your server, this may be logged and count against your guild's shared withdrawal allowance, the same as moving items by hand."] = "整理这个公会银行页签？根据你的服务器不同，这可能会被记录，并计入你公会共享的提取额度，和手动移动物品一样。"
L["Sort"] = "整理"
L["Click to sort items in the currently open guild bank tab."] = "点击整理当前打开的公会银行页签中的物品。"
L["Never moves items between tabs."] = "永远不会跨页签移动物品。"
L["Sort Guild Bank Tab"] = "整理公会银行页签"

-- ============================================================================
-- 微型菜单延迟提示
-- ============================================================================

L["Network"] = "网络"
L["Latency"] = "延迟"

-- ============================================================================
-- 稳定性补丁字符串
-- ============================================================================

L["/dragonui debug on|off|status - Toggle diagnostic logging"] = "/dragonui debug on|off|status - 切换诊断日志"
L["Usage: /dragonui debug on|off|status"] = "用法：/dragonui debug on|off|status"
L["Enable debug mode first with /dragonui debug on"] = "请先使用 /dragonui debug on 开启调试模式"
L["Debug mode is %s"] = "调试模式当前为 %s"
L["Debug mode enabled"] = "调试模式已开启"
L["Debug mode disabled"] = "调试模式已关闭"
L["enabled"] = "已开启"
L["disabled"] = "已关闭"
L["Enabled"] = "已启用"
L["Disabled"] = "已禁用"
L["Legacy refresh failed for"] = "旧版刷新失败："
L["RegisterMover: name and parent are required"] = "RegisterMover：必须提供 name 和 parent"
L["Bonus Action Button %d"] = "奖励动作按钮 %d"
L["Stance Button %d"] = "姿态按钮 %d"
L["Pet Action Button %d"] = "宠物动作按钮 %d"
L["Multicast Button %d"] = "多施法按钮 %d"
L["Totem Call Button"] = "图腾调用按钮"
L["Totem Recall Button"] = "图腾召回按钮"
L["Bottom Left Button"] = "左下按钮"
L["Bottom Right Button"] = "右下按钮"
L["Right Button"] = "右侧按钮"
L["Left Button"] = "左侧按钮"
L["Totem Bar"] = "图腾条"
L["Test Pet"] = "测试宠物"
L["=== TargetFrame children (depth 3) ==="] = "=== TargetFrame 子元素（深度 3）==="
L["=== FocusFrame children (depth 3) ==="] = "=== FocusFrame 子元素（深度 3）==="
L["BG texture not found"] = "未找到背景纹理"
L["BG tinted RED"] = "背景已着色为红色"
L["BG tinted GREEN"] = "背景已着色为绿色"
L["BG color reset"] = "背景颜色已重置"
L["=== BANK SCAN DEBUG ==="] = "=== 银行扫描调试 ==="
L["=== BANK QUALITY DEBUG ==="] = "=== 银行品质调试 ==="
L["Module enabled:"] = "模块已启用："
L["BankFrame exists:"] = "BankFrame 存在："
L["BankFrame shown:"] = "BankFrame 已显示："
L["Usage: /dui shadowcolor red|green|reset|info"] = "用法：/dui shadowcolor red|green|reset|info"
L["Usage: /dui shadowcrop <bottom_px> [right_px]"] = "用法：/dui shadowcrop <bottom_px> [right_px]"
L["  e.g. /dui shadowcrop 90 - show top 90 of 128 px height"] = "  例如：/dui shadowcrop 90 - 显示 128 像素高度中的顶部 90 像素"
L["  e.g. /dui shadowcrop 90 200 - crop both bottom and right"] = "  例如：/dui shadowcrop 90 200 - 同时裁掉底部和右侧"
L["  /dui shadowcrop reset - restore full texture"] = "  /dui shadowcrop reset - 恢复完整纹理"
L["BG reset to 256x128 full texture"] = "背景已重置为 256x128 完整纹理"
L["Crop applied: showing %dx%d of 256x128 (texcoord 0-%.3f, 0-%.3f)"] = "已应用裁切：显示 256x128 中的 %dx%d（纹理坐标 0-%.3f，0-%.3f）"
L["Invalid values. Height 1-128, Width 1-256"] = "数值无效。高度范围 1-128，宽度范围 1-256"
L["=== TargetFrame elements (use /dui shadowtest N to toggle) ==="] = "=== TargetFrame 元素列表（使用 /dui shadowtest N 切换）==="
L["Total elements: %d"] = "元素总数：%d"
L["HIDDEN: %d. %s [%s]"] = "已隐藏：%d. %s [%s]"
L["SHOWN: %d. %s [%s]"] = "已显示：%d. %s [%s]"
L["Invalid element number. Use /dui shadowtest to list."] = "元素编号无效。使用 /dui shadowtest 查看列表。"
L["DragonUI Compatibility:"] = "DragonUI 兼容性："
L["Registered Modules:"] = "已注册模块："
L["No modules registered in ModuleRegistry"] = "ModuleRegistry 中没有已注册模块"
L["load-once"] = "仅加载一次"
L["%s will disable after /reload because its secure hooks cannot be removed safely."] = "%s 将在 /reload 后禁用，因为它的安全钩子无法安全移除。"
L["%s uses permanent secure hooks and will fully disable after /reload."] = "%s 使用永久安全钩子，将在 /reload 后完全禁用。"
L["%s remains active until /reload because its secure hooks cannot be removed safely."] = "%s 会持续启用到 /reload 为止，因为它的安全钩子无法安全移除。"
L["Cooldown Text"] = "冷却文字"
L["Cooldown text on action buttons"] = "动作按钮上的冷却文字"
L["Cast Bar"] = "施法条"
L["Custom player, target, and focus cast bars"] = "自定义玩家、目标和焦点施法条"
L["Multicast"] = "多施法"
L["Shaman totem bar positioning and styling"] = "萨满图腾条的位置与样式"
L["Player Frame"] = "玩家框架"
L["Dragonflight-styled boss target frames"] = "巨龙时代风格的首领目标框架"
L["Dragonflight-styled player unit frame"] = "巨龙时代风格的玩家单位框架"
L["ModuleRegistry:Register requires name and moduleTable"] = "ModuleRegistry:Register 需要 name 和 moduleTable"
L["ModuleRegistry: Module already registered -"] = "ModuleRegistry：模块已注册 -"
L["ModuleRegistry: Registered module -"] = "ModuleRegistry：已注册模块 -"
L["order:"] = "顺序："
L["ModuleRegistry: Refresh failed for"] = "ModuleRegistry：刷新失败："
L["ModuleRegistry: Unknown module -"] = "ModuleRegistry：未知模块 -"
L["ModuleRegistry: Enabled -"] = "ModuleRegistry：已启用 -"
L["ModuleRegistry: Disabled -"] = "ModuleRegistry：已禁用 -"
L["CombatQueue:Add requires id and func"] = "CombatQueue:Add 需要 id 和 func"
L["CombatQueue: Registered PLAYER_REGEN_ENABLED"] = "CombatQueue：已注册 PLAYER_REGEN_ENABLED"
L["CombatQueue: Queued operation -"] = "CombatQueue：已加入队列 -"
L["CombatQueue: Removed operation -"] = "CombatQueue：已移除操作 -"
L["CombatQueue: Processing"] = "CombatQueue：处理中"
L["queued operations"] = "个排队操作"
L["CombatQueue: Failed to execute"] = "CombatQueue：执行失败"
L["CombatQueue: Executed -"] = "CombatQueue：已执行 -"
L["CombatQueue: Unregistered PLAYER_REGEN_ENABLED"] = "CombatQueue：已取消注册 PLAYER_REGEN_ENABLED"
L["CombatQueue: Immediate execution failed -"] = "CombatQueue：立即执行失败 -"
L["UFL diagnostic not available"] = "UFL 诊断不可用"
L["Rect: left=%.1f bottom=%.1f w=%.1f h=%.1f"] = "矩形：left=%.1f bottom=%.1f w=%.1f h=%.1f"
L["Point1: %s -> %s %s (%.1f, %.1f)"] = "锚点1：%s -> %s %s (%.1f, %.1f)"
L["NumPoints: %d"] = "锚点数量：%d"
L["TexCoord: %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f"] = "纹理坐标：%.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f"
L["(unnamed)"] = "（未命名）"
L["(unnamed_frame)"] = "（未命名框体）"
L["SHOWN"] = "已显示"
L["hidden"] = "已隐藏"
L["VISIBLE"] = "可见"
L["invisible"] = "不可见"
L["VIS"] = "可见"
L["inv"] = "隐"

-- ============================================================================
-- 发布补全字符串
-- ============================================================================

L["Buttons"] = "按钮"
L["Action button styling and enhancements"] = "动作按钮样式与增强"
L["Equipment"] = "装备"
L["Usable"] = "消耗品"
L["Normal"] = "普通"
L["Trade"] = "专业背包"
L["Target & Focus Aura Customization"] = "目标和焦点光环自定义"
L["Customize target/focus aura icons and timers."] = "自定义目标和焦点光环的图标与计时文字。"
L["Dark Mode"] = "暗色模式"
L["Darken UI borders and chrome"] = "加深界面边框与装饰"
L["Item Quality"] = "物品品质"
L["Color item borders by quality in bags, character panel, bank, and merchant"] = "在背包、角色面板、银行和商人界面中按品质为物品边框着色"
-- Item Level
L["Item Level"] = "物品等级"
L["Show item level on gear icons in bags, character panel, bank, and more"] = "在背包、角色面板、银行等界面的装备图标上显示物品等级"
L["Item Level: %d"] = "物品等级：%d"

L["Key Binding"] = "按键绑定"
L["LibKeyBound integration for intuitive keybinding"] = "集成 LibKeyBound，提供直观的按键绑定"
L["Buff Frame"] = "增益框体"
L["Custom buff frame styling, positioning and toggle button"] = "自定义增益框体样式、位置和切换按钮"
L["Chat Mods"] = "聊天增强"
L["Chat enhancements: hide buttons, editbox position, URL copy, chat copy, link hover, tell target"] = "聊天增强：隐藏按钮、输入框位置、URL 复制、聊天复制、链接悬停和密语目标"
L["Bag Sort"] = "背包整理"
L["Sort bags and bank items with buttons"] = "使用按钮整理背包和银行物品"
L["Bag Skin"] = "背包皮肤"
L["Retail-style skin for Blizzard bag windows"] = "暴雪背包窗口的正式服风格皮肤"
L["Bagster"] = "Bagster"
L["All-in-one bag replacement with filtering and search"] = "带筛选和搜索的一体化背包替换"
L["Stance Bar"] = "姿态条"
L["Vehicle"] = "载具"
L["Vehicle interface enhancements"] = "载具界面增强"
L["Pet Bar"] = "宠物动作条"
L["Extra Bar"] = "额外栏"
L["A standalone action bar, independent of any class bonus bar"] = "一个独立的动作条，不依赖于任何职业特殊条"
L["Drag a spell, item or macro here."] = "将法术、物品或宏拖到这里。"
L["Micro Menu"] = "微型菜单"
L["Main Bars"] = "主动作条"
L["Main action bars, status bars, scaling and positioning"] = "主动作条、状态条、缩放与定位"
L["Hide Blizzard"] = "隐藏暴雪界面"
L["Hide default Blizzard UI elements"] = "隐藏默认暴雪界面元素"
L["Minimap"] = "小地图"
L["Custom minimap styling, positioning, tracking icons and calendar"] = "自定义小地图样式、位置、追踪图标与日历"
L["Quest tracker positioning and styling"] = "任务追踪器位置与样式"
L["Tooltip"] = "鼠标提示"
L["Enhanced tooltip styling with class colors and health bars"] = "带职业颜色和生命条的增强鼠标提示样式"
L["Nameplates"] = "姓名板"
L["Apply DragonUI nameplate styling."] = "将 DragonUI 样式应用于姓名板。"
L["Unit Frame Layers"] = "单位框架层"
L["Heal prediction, absorb shields, and animated health loss on unit frames"] = "单位框架上的治疗预估、吸收护盾与动态掉血效果"
L["Stance/shapeshift bar positioning and styling"] = "姿态/变形条的位置与样式"
L["Pet action bar positioning and styling"] = "宠物动作条的位置与样式"
L["Micro menu and bags system styling and positioning"] = "微型菜单和背包系统的样式与定位"
L["%s's Inventory"] = "%s的背包"
L["%s's Bank"] = "%s的银行"
L["Inventory"] = "背包"
L["Bank"] = "银行"
L["Bags"] = "背包"
L["|cff00ff00Left-Click|r to toggle bag display"] = "|cff00ff00左键点击|r切换背包栏显示"
L["|cff00ff00Right-Click|r to toggle inventory"] = "|cff00ff00右键点击|r切换背包"
L["|cff00ff00Right-Click|r to toggle bank"] = "|cff00ff00右键点击|r切换银行"
L["|cff00ff00Drag|r to move"] = "|cff00ff00拖动|r以移动"
L["|cff00ff00Alt+Right-Click|r to reset position"] = "|cff00ff00Alt+右键点击|r重置位置"
L["Toggle Inventory"] = "切换背包"
L["Toggle Bank"] = "切换银行"
L["|cff00ff00Left-Click|r to show this bag's items"] = "|cff00ff00左键点击|r显示此背包物品"
L["|cff00ff00Left-Click|r to hide this bag's items"] = "|cff00ff00左键点击|r隐藏此背包物品"
L["|cff00ff00Drag|r to move this bag"] = "|cff00ff00拖动|r以移动此背包"
L["Sort complete."] = "整理完成。"
L["Sort already in progress."] = "正在整理中。"
L["Bags already sorted!"] = "背包已经整理好了！"
L["You must be at the bank."] = "你必须在银行处。"
L["Bank already sorted!"] = "银行已经整理好了！"
L["Reputation: "] = "声望："
L["Error in SafeCall:"] = "SafeCall 出错："

L["Double-Click to Copy"] = "双击复制"
L["Copy Text"] = "复制文本"
L["URL"] = "URL"

-- Version Check Module
L["Version Check"] = "版本检查"
L["Broadcast and detect addon version updates across group members"] = "检测队伍成员间插件版本更新，通过广播和接收版本信息"

-- Quest nameplate icons wizard (Questie coexistence)
L["Quest Icons on Nameplates"] = "姓名板任务图标"
L["Which quest icons do you want on your nameplates?"] = "你想在姓名板上显示哪种任务图标？"
L["Kill"] = "击杀"
L["Loot"] = "拾取"
L['Pointer mode (just "!")'] = '指针模式（仅"!"）'
L["Use Questie"] = "使用 Questie"
L["Applying quest icon settings needs a UI reload."] = "应用任务图标设置需要重载界面。"
L["Reload"] = "重载"
