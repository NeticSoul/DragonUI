-- ============================================================================
-- DragonUI - Atlas Definitions (Legacy)
-- Texture atlas lookup table mapping sprite names to texture coordinates.
-- ============================================================================

local addon = select(2,...);
local assets = addon._dir;
local unpack = unpack;
local uiactionbar = assets..'ActionBars\\uiactionbar';
local uiexperiencebar = assets..'XP\\uiexperiencebar';
local uimicromenu2x = assets..'Micromenu\\Atlas\\uimicromenu2x';
local collapse = assets..'Micromenu\\uicollapsebutton';
local bagmain2x = assets..'Bags\\bagslots2x';
local uiactionbar2x_ = assets..'ActionBars\\uiactionbar2x_';
local uiactionbar2x_new = assets..'ActionBars\\uiactionbar2x_new';
local uiactionbar2x_flying = assets..'ActionBars\\uiactionbar2x_flying';
local uiactionbarvertical = assets..'ActionBars\\uiactionbarvertical';
local uiactionbarvertical2x = assets..'ActionBars\\uiactionbarvertical2x';

-- These three were byte-identical copies of the aliases above under a second naming scheme.
local rui_ActionBarHorizontal = uiactionbar2x_new;
local rui_ActionBarVertical = uiactionbarvertical2x;
local rui_BagSlots = bagmain2x;
local rui_BagSlotsKey = 'Interface\\AddOns\\DragonUI\\Textures\\UI\\BagSlotsKey.blp';
local rui_Battlefield = 'Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\uibattlefieldicon.tga';
local rui_Calendar = 'Interface\\AddOns\\DragonUI\\Textures\\Minimap\\Calendar.blp';
local rui_CastingBar = 'Interface\\AddOns\\DragonUI\\Textures\\UI\\CastingBar.blp';
local rui_CollapseButton = 'Interface\\AddOns\\DragonUI\\Textures\\UI\\CollapseButton.blp';
local rui_ExperienceBar = uiexperiencebar;
local rui_GuildBanner = 'Interface\\AddOns\\DragonUI\\Textures\\Minimap\\GuildBanner.BLP';
local rui_LFGRole = 'Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Player\\LFGRoleIcons.blp';
local rui_MicroMenu = 'Interface\\AddOns\\DragonUI\\Textures\\UI\\MicroMenu.blp';
local rui_Minimap = 'Interface\\AddOns\\DragonUI\\Textures\\UI\\Minimap.blp';
local rui_QuestTracker = 'Interface\\AddOns\\DragonUI\\Textures\\UI\\QuestTracker.BLP';
local rui_UnitFrame = 'Interface\\AddOns\\DragonUI\\Textures\\UI\\UnitFrame.blp';
local rui_FrameMetal = assets..'UI\\uiframemetal2x';
local rui_FrameInner = assets..'UI\\uiframeinner';
local rui_Inner = assets..'UI\\uiframe-inner';
local rui_Collapse = assets..'CharacterPanel\\collapsebuttons';
local rui_Dropdown = assets..'UI\\dropdownbutton';
local rui_Checkbox = assets..'UI\\checkbox-minimal';
local rui_Diamond = assets..'UI\\uiframe-diamondmetal';
local rui_DiamondEdges = assets..'UI\\uiframe-diamondmetal-edges';
local rui_InnerV = assets..'UI\\uiframe-inner-vertical';
local rui_FrameMetalH = assets..'UI\\uiframemetalhorizontal2x';
local rui_FrameMetalV = assets..'UI\\uiframemetalvertical2x';
local rui_CharPanelBg = assets..'CharacterPanel\\characterpanelbackground';
local rui_CharInfoA = assets..'CharacterPanel\\characterinfoclasses-a';
-- The PvP faction rings that frame the rank insignia, cut out of the retail honor sheet: 50x52 of
-- art on a 64x64 canvas, which is why the texcoords stop short of 1.
local rui_RingAlliance = assets..'CharacterPanel\\ring-alliance';
local rui_RingHorde = assets..'CharacterPanel\\ring-horde';
local rui_RingNeutral = assets..'CharacterPanel\\ring-neutral';
local rui_CharInfoB = assets..'CharacterPanel\\characterinfoclasses-b';
local rui_Scrollbar = assets..'CharacterPanel\\scrollbar';
local rui_ScrollbarMid = assets..'CharacterPanel\\scrollbarmiddle';
local rui_CommonButtons = assets..'CharacterPanel\\commonbuttons';
local rui_CommonIcons = assets..'CharacterPanel\\commonicons';
local rui_ListExpand = assets..'CharacterPanel\\listexpand';

addon.atlasinfo = {
	['_ui-hud-actionbar-divider-top'] = { uiactionbar2x_, 10, 10, 421/512, 445/512, 833/2048, 861/2048 },
	['_ui-hud-actionbar-divider-bottom'] = { uiactionbar2x_, 10, 10, 395/512, 419/512, 833/2048, 863/2048 },
	['_ui-hud-actionbar-divider-center'] = { uiactionbar2x_, 8, 20, 0, 32/512, 179/2048, 207/2048, false, true },

	['ui-hud-actionbar-gryphon-left'] = { uiactionbar2x_, 92, 92, 1/512, 357/512, 209/2048, 543/2048 },
	['ui-hud-actionbar-gryphon-right'] = { uiactionbar2x_, 92, 92, 1/512, 357/512, 545/2048, 879/2048 },
	['ui-hud-actionbar-gryphon-flying-left'] = { uiactionbar2x_flying, 80, 103, 1/256, 158/256, 149/2048, 342/2048 },
	['ui-hud-actionbar-gryphon-flying-right'] = { uiactionbar2x_flying, 80, 103, 1/256, 157/256, 539/2048, 732/2048 },
	['ui-hud-actionbar-gryphon-thick-left'] = { uiactionbar2x_new, 104.5, 96, 1/512, 357/512, 209/2048, 543/2048 },
	['ui-hud-actionbar-gryphon-thick-right'] = { uiactionbar2x_new, 104.5, 96, 1/512, 357/512, 545/2048, 879/2048 },
	['ui-hud-actionbar-wyvern-thick-left'] = { uiactionbar2x_new, 104.5, 96, 1/512, 357/512, 881/2048, 1215/2048 },
	['ui-hud-actionbar-wyvern-thick-right'] = { uiactionbar2x_new, 104.5, 96, 1/512, 357/512, 1217/2048, 1551/2048 },

	['ui-hud-experiencebar'] = { assets..'ActionBars\\mainmenubar', 537, 14, 0.1123046875, 0.646484375, 0.18798828125, 0.24951171875 },
	['ui-hud-experiencebar-round'] = { uiexperiencebar, 537, 18, 1/2048, 572/2048, 1/64, 18/64 },
	['ui-hud-experiencebar-background'] = { uiexperiencebar, 530, 10, 0.00088878125, 570/2048, 20/64, 29/64 },
	['ui-hud-experiencebar-frame-pip'] = { uiexperiencebar, 10, 14, 588/2048, 598/2048, 45/64, 59/64 },
	['ui-hud-experiencebar-frame-pip-mouseover'] = { uiexperiencebar, 10, 14, 574/2048, 586/2048, 45/64, 59/64 },
	['ui-hud-experiencebar-fill'] = { uiexperiencebar, nil, nil, 1/2048, 564/2048, 31/64, 40/64 },
	['ui-hud-experiencebar-fill-rested'] = { uiexperiencebar, nil, nil, 574/2048, 1136/2048, 34/64, 43/64 },
	['ui-hud-experiencebar-fill-prediction']  = { uiexperiencebar, nil, nil, 574/2048, 1136/2048, 1/64, 10/64 },
	['ui-hud-experiencebar-fill-reputation-faction-yellow'] = { uiexperiencebar, nil, nil, 1139/2048, 1700/2048, 23/64, 32/64 },

	['ui-hud-actionbar-pageuparrow-normal'] = { uiactionbar2x_, 14, 12, 359/512, 393/512, 833/2048, 861/2048 },
	['ui-hud-actionbar-pageuparrow-pushed'] = { uiactionbar2x_, 14, 12, 453/512, 487/512, 679/2048, 707/2048 },
	['ui-hud-actionbar-pageuparrow-highlight'] = { uiactionbar2x_, 14, 12, 453/512, 487/512, 709/2048, 737/2048 },
	['ui-hud-actionbar-pagedownarrow-normal'] = { uiactionbar2x_, 14, 12, 463/512, 497/512, 605/2048, 633/2048 },
	['ui-hud-actionbar-pagedownarrow-pushed'] = { uiactionbar2x_, 14, 12, 463/512, 497/512, 545/2048, 573/2048 },
	['ui-hud-actionbar-pagedownarrow-highlight'] = { uiactionbar2x_, 14, 12, 463/512, 497/512, 575/2048, 603/2048 },
	
	['ui-hud-actionbar-iconframe'] = { uiactionbar2x_new, 64, 64, 359/512, 451/512, 649/2048, 739/2048 },
	-- ['ui-hud-actionbar-iconframe'] = { uiactionbar2x_, 46, 45, 359/512, 461/512, 441/2048, 543/2048 },
	['_ui-hud-actionbar-iconborder-checked'] = { uiactionbar2x_new, 64, 64, 359/512, 451/512, 881/2048, 971/2048 },
	-- ['_ui-hud-actionbar-iconborder-pushed'] = { uiactionbar2x, 64, 64, 0.7041015625, 0.8779296875, 0.32153320312, 0.36450195313 },
	['_ui-hud-actionbar-iconborder-pushed'] = { uiactionbar2x_new, 64, 64, 359/512, 451/512, 881/2048, 971/2048 },
	-- ['_ui-hud-actionbar-iconborder-highlight'] = { uiactionbar2x, 64, 64, 0.7119140625, 0.8623046875, 0.44262695312, 0.48022460938 },
	['_ui-hud-actionbar-iconborder-highlight'] = { uiactionbar2x_new, 64, 64, 359/512, 451/512, 1065/2048, 1155/2048 },
	-- ['_ui-hud-actionbar-iconframe-background'] = { uiactionbar2x, 64, 64, 0.7060546875, 0.8193359375, 0.51538085937, 0.54467773438 },
	['ui-hud-actionbar-iconframe-flyoutbordershadow'] = { uiactionbar2x_new, 52, 52, 359/512, 463/512, 335/2048, 439/2048 },
	['ui-hud-actionbar-iconframe-flash'] = { uiactionbar2x_new, 64, 64, 359/512, 451/512, 973/2048, 1063/2048 },
	['ui-hud-actionbar-iconframe-slot'] = { uiactionbar2x_new, 64, 64, 359/512, 487/512, 209/2048, 333/2048 },
	
	['ui-hud-micromenu-achievement-disabled-2x'] = { uimicromenu2x, nil, nil, 201/256, 239/256, 109/512, 161/512 },
	['ui-hud-micromenu-achievement-down-2x'] = { uimicromenu2x, nil, nil, 161/256, 199/256, 55/512, 107/512 },
	['ui-hud-micromenu-achievement-mouseover-2x'] = { uimicromenu2x, nil, nil, 201/256, 239/256, 55/512, 107/512 },
	['ui-hud-micromenu-achievement-up-2x'] = { uimicromenu2x, nil, nil, 161/256, 199/256, 109/512, 161/512 },
	['ui-hud-micromenu-pvp-disabled-2x'] = { uimicromenu2x, nil, nil, 81/256, 119/256, 163/512, 215/512 },
	['ui-hud-micromenu-pvp-down-2x'] = { uimicromenu2x, nil, nil, 201/256, 239/256, 163/512, 215/512 },
	['ui-hud-micromenu-pvp-mouseover-2x'] = { uimicromenu2x, nil, nil, 161/256, 199/256, 163/512, 215/512 },
	['ui-hud-micromenu-pvp-up-2x'] = { uimicromenu2x, nil, nil, 1/256, 39/256, 271/512, 323/512 },
	['ui-hud-micromenu-character-disabled-2x'] = { uimicromenu2x, nil, nil, 1/256, 39/256, 217/512, 269/512 },
	['ui-hud-micromenu-character-down-2x'] = { uimicromenu2x, nil, nil, 121/256, 159/256, 163/512, 215/512 },
	['ui-hud-micromenu-character-mouseover-2x'] = { uimicromenu2x, nil, nil, 81/256, 119/256, 217/512, 269/512 },
	['ui-hud-micromenu-character-up-2x'] = { uimicromenu2x, nil, nil, 1/256, 39/256, 325/512, 377/512 },
	['ui-hud-micromenu-collections-disabled-2x'] = { uimicromenu2x, nil, nil, 121/256, 159/256, 1/512, 53/512 },
	['ui-hud-micromenu-collections-down-2x'] = { uimicromenu2x, nil, nil,1/256, 39/256, 379/512, 431/512 },
	['ui-hud-micromenu-collections-mouseover-2x'] = { uimicromenu2x, nil, nil, 1/256, 39/256, 433/512, 485/512 },
	['ui-hud-micromenu-collections-up-2x'] = { uimicromenu2x, nil, nil,	41/256, 79/256,	163/512, 215/512 },
	-- ['ui-hud-micromenu-communities-icon-notification-2x'] = { uimicromenu2x, nil, nil, 1/256, 21/256, 487/512, 509/512 },
	['ui-hud-micromenu-help-disabled-2x'] = { uimicromenu2x, nil, nil, 41/256, 79/256, 217/512, 269/512 },
	['ui-hud-micromenu-help-down-2x'] = { uimicromenu2x, nil, nil, 121/256, 159/256, 217/512, 269/512 },
	['ui-hud-micromenu-help-mouseover-2x'] = { uimicromenu2x, nil, nil, 161/256, 199/256, 217/512, 269/512 },
	['ui-hud-micromenu-help-up-2x'] = { uimicromenu2x, nil, nil, 201/256, 239/256, 217/512, 269/512 },
	['ui-hud-micromenu-lfd-disabled-2x'] = { uimicromenu2x, nil, nil, 41/256, 79/256, 271/512, 323/512 },
	['ui-hud-micromenu-lfd-down-2x'] = { uimicromenu2x, nil, nil, 81/256, 119/256, 109/512, 161/512 },
	['ui-hud-micromenu-lfd-mouseover-2x'] = { uimicromenu2x, nil, nil, 41/256, 79/256, 109/512, 161/512 },
	['ui-hud-micromenu-lfd-up-2x'] = { uimicromenu2x, nil, nil, 1/256, 39/256, 163/512, 215/512 },
	['ui-hud-micromenu-socials-disabled-2x'] = { uimicromenu2x, nil, nil, 201/256, 239/256, 1/512, 53/512 },
	['ui-hud-micromenu-socials-down-2x'] = { uimicromenu2x, nil, nil, 1/256, 39/256, 1/512, 53/512 },
	['ui-hud-micromenu-socials-mouseover-2x'] = { uimicromenu2x, nil, nil, 41/256, 79/256, 1/512, 53/512 },
	['ui-hud-micromenu-socials-up-2x'] = { uimicromenu2x, nil, nil, 41/256, 79/256,55/512,	107/512 },
	-- ['ui-hud-micromenu-highlightalert-2x'] = { uimicromenu2x, nil, nil, 121/256, 187/256, 379/512, 459/512 },
	['ui-hud-micromenu-questlog-disabled-2x'] = { uimicromenu2x, nil, nil, 41/256, 79/256, 379/512, 431/512 },
	['ui-hud-micromenu-questlog-down-2x'] = { uimicromenu2x, nil, nil, 121/256, 159/256, 271/512, 323/512 },
	['ui-hud-micromenu-questlog-mouseover-2x'] = { uimicromenu2x, nil, nil, 41/256, 79/256,	433/512, 485/512 },
	['ui-hud-micromenu-questlog-up-2x'] = { uimicromenu2x, nil, nil, 201/256, 239/256, 271/512, 323/512 },
	['ui-hud-micromenu-mainmenu-disabled-2x'] = { uimicromenu2x, nil, nil, 41/256, 79/256, 325/512, 377/512 },
	['ui-hud-micromenu-mainmenu-mouseover-2x'] = { uimicromenu2x, nil, nil, 121/256, 159/256, 325/512, 377/512 },
	['ui-hud-micromenu-mainmenu-down-2x'] = { uimicromenu2x, nil, nil, 161/256, 199/256, 271/512, 323/512 },
	['ui-hud-micromenu-mainmenu-up-2x'] = { uimicromenu2x, nil, nil, 1/256, 39/256, 109/512, 161/512 },
	['ui-hud-micromenu-talent-disabled-2x'] = { uimicromenu2x, nil, nil, 81/256, 119/256, 55/512, 107/512 },
	['ui-hud-micromenu-talent-down-2x'] = { uimicromenu2x, nil, nil, 81/256, 119/256, 271/512, 323/512 },
	['ui-hud-micromenu-talent-mouseover-2x'] = { uimicromenu2x, nil, nil, 81/256, 119/256, 1/512, 53/512 },
	['ui-hud-micromenu-talent-up-2x'] = { uimicromenu2x, nil, nil, 161/256, 199/256, 1/512, 53/512 },
	['ui-hud-micromenu-spellbook-disabled-2x'] = { uimicromenu2x, nil, nil, 1/256, 39/256, 55/512, 107/512 },
	['ui-hud-micromenu-spellbook-down-2x'] = { uimicromenu2x, nil, nil, 81/256, 119/256, 433/512, 485/512 },
	['ui-hud-micromenu-spellbook-mouseover-2x'] = { uimicromenu2x, nil, nil, 189/256, 227/256, 433/512, 485/512 },
	['ui-hud-micromenu-spellbook-up-2x'] = { uimicromenu2x, nil, nil, 121/256, 159/256, 55/512, 107/512 },
	
	['bag-main-2x'] = { bagmain2x, nil, nil, 1/512, 97/512,	1/128, 97/128 },
	['bag-main-highlight-2x'] = { bagmain2x, nil, nil, 99/512, 195/512, 1/128, 97/128 },
	['bag-arrow-2x'] = { bagmain2x, nil, nil, 484/512, 504/512, 1/128, 33/128 },
	['bag-arrow-invert-2x'] = { collapse, nil, nil, 8/32, 28/32, 32/64, 62/64 },
	-- ['bag-reagent-border-2x'] = { bagmain2x, nil, nil, 358/512, 419/512, 64/128, 125/128 },
	['bag-border-2x'] = { bagmain2x, 34, 34, 295/512, 356/512, 1/128, 62/128 },
	['bag-border-empty-2x'] = { bagmain2x, 34, 34, 295/512, 356/512, 64/128, 125/128 },
	['bag-border-highlight-2x'] = { bagmain2x, 40, 40, 358/512, 419/512, 1/128, 62/128 },
	['bag-reagent-border-empty-2x'] = { bagmain2x, 34, 34, 421/512, 482/512, 1/128, 62/128 },
	['bag-reagent-border-2x'] = { assets..'Bags\\bagslots2key.tga', nil, nil, 3/128, 63/128, 64/128, 125/128 },
	
	-- NineSlice
	['ui-hud-actionbar-frame-nineslice-cornerbottomleft'] = { uiactionbar2x_, 20, 20, 465/512, 499/512, 383/2048, 429/2048 },
	['ui-hud-actionbar-frame-nineslice-cornerbottomright'] = { uiactionbar2x_, 20, 20, 465/512, 509/512, 335/2048, 381/2048 },
	['ui-hud-actionbar-frame-nineslice-cornertopleft'] = { uiactionbar2x_, 20, 20, 463/512, 497/512, 475/2048, 507/2048 },
	['ui-hud-actionbar-frame-nineslice-cornertopright'] = { uiactionbar2x_, 20, 20, 463/512, 507/512, 441/2048, 473/2048 },
	['_ui-hud-actionbar-frame-nineslice-edgetop'] = { uiactionbar2x_, 506, 20, 0, 32/512, 145/2048, 177/2048, true, false },
	['_ui-hud-actionbar-frame-nineslice-edgebottom'] = { uiactionbar2x_, 506, 20, 0, 32/512, 97/2048, 143/2048, true, false },
	['!ui-hud-actionbar-frame-nineslice-edgeleft'] = { uiactionbarvertical2x, 20, 20, 143/256, 177/256, 0, 32/64, false, true },
	['!ui-hud-actionbar-frame-nineslice-edgeright'] = { uiactionbarvertical2x, 20, 20, 97/256, 141/256, 0, 32/64, false, true },
	['ui-hud-actionbar-frame-nineslice-center'] = { uiactionbar2x_, 0, 0 },
	
	-- NineSlice background
	['ui-hud-actionbar-frame-background-nineslice-center'] = { uiactionbar, 506, 20, 0, 16/256, 123/1024, 134/1024, true, false },
	['ui-hud-actionbar-frame-background-nineslice-cornerbottomleft'] = { uiactionbar, 20, 20, 229/256, 240/256, 444/1024, 456/1024 },
	['ui-hud-actionbar-frame-background-nineslice-cornerbottomright'] = { uiactionbar, 20, 20, 229/256, 240/256, 458/1024, 470/1024 },
	['ui-hud-actionbar-frame-background-nineslice-cornertopleft'] = { uiactionbar, 20, 20, 242/256, 253/256, 444/1024, 455/1024 },
	['ui-hud-actionbar-frame-background-nineslice-cornertopright'] = { uiactionbar, 20, 20, 242/256, 253/256, 457/1024, 468/1024 },
	['_ui-hud-actionbar-frame-background-nineslice-edgebottom'] = { uiactionbar, 506, 20, 0, 16/256, 109/1024, 121/1024, true, false },
	['_ui-hud-actionbar-frame-background-nineslice-edgetop'] = { uiactionbar, 506, 20, 0, 16/256, 123/1024, 134/1024, true, false },
	['!ui-hud-actionbar-frame-background-nineslice-edgeleft'] = { uiactionbarvertical, 20, 20, 107/256, 118/256, 0, 16/32, false, true },
	['!ui-hud-actionbar-frame-background-nineslice-edgeright'] = { uiactionbarvertical, 20, 20, 120/256, 131/256, 0, 16/32, false, true },
	
	-- ThreeSlice Divider
	['!ui-hud-actionbar-frame-divider-threeslice-center'] = { uiactionbarvertical2x, 14, 18, 179/256, 203/256, 0, 32/64 },
	['ui-hud-actionbar-frame-divider-threeslice-edgebottom'] = { uiactionbar2x_, 14, 12, 395/512, 419/512, 833/2048, 863/2048 },
	['ui-hud-actionbar-frame-divider-threeslice-edgetop'] = { uiactionbar2x_, 14, 12, 421/512, 445/512, 833/2048, 861/2048 },
	['Minimap-GuildBanner-Normal'] = { rui_GuildBanner, 67, 69, 1/256, 68/256, 76/256, 145/256 },
	['Minimap-GuildBanner-Heroic'] = { rui_GuildBanner, 66, 69, 75/256, 141/256, 76/256, 145/256 },
	['QuestTracker-Header'] = { rui_QuestTracker, 560, 70, 11/1024, 571/1024, 247/512, 317/512 },
	['QuestTracker-Collapse'] = { rui_QuestTracker, 18, 19, 951/1024, 987/1024, 59/512, 97/512 },
	['QuestTracker-Collapse-Pressed'] = { rui_QuestTracker, 18, 19, 905/1024, 941/1024, 121/512, 159/512 },
	['QuestTracker-Expand'] = { rui_QuestTracker, 18, 19, 905/1024, 941/1024, 161/512, 199/512 },
	['QuestTracker-Expand-Pressed'] = { rui_QuestTracker, 18, 19, 905/1024, 941/1024, 201/512, 239/512 },
	['QuestTracker-Red-Highlight'] = { rui_QuestTracker, 18, 19, 943/1024, 979/1024, 161/512, 199/512 },
	['LFGRole-Tank'] = { rui_LFGRole, 18, 17, 35/256, 53/256, 0/256, 17/256 },
	['LFGRole-Healer'] = { rui_LFGRole, 17, 18, 18/256, 35/256, 0/256, 18/256 },
	['LFGRole-Damage'] = { rui_LFGRole, 17, 17, 0/256, 17/256, 0/256, 17/256 },
	['TargetFrame-TextureFrame-Normal'] = { rui_UnitFrame, 210, 89, 423/1024, 633/1024, 0/512, 89/512 },
	['TargetFrame-TextureFrame-Vehicle'] = { rui_UnitFrame, 210, 90, 636/1024, 846/1024, 91/512, 181/512 },
	['TargetFrame-TextureFrame-Elite'] = { rui_UnitFrame, 210, 89, 211/1024, 421/1024, 0/512, 89/512 },
	['TargetFrame-TextureFrame-Rare'] = { rui_UnitFrame, 209, 89, 0/1024, 209/1024, 0/512, 89/512 },
	['TargetFrame-TextureFrame-RareElite'] = { rui_UnitFrame, 222, 90, 0/1024, 222/1024, 91/512, 181/512 },
	['TargetFrame-StatusBar-Health'] = { rui_UnitFrame, 125, 22, 3/1024, 128/1024, 459/512, 481/512 },
	['TargetFrame-StatusBar-Mana'] = { rui_UnitFrame, 134, 12, 130/1024, 264/1024, 459/512, 471/512 },
	['TargetFrame-Status'] = { rui_UnitFrame, 209, 90, 0/1024, 209/1024, 275/512, 365/512 },
	['TargetFrame-Flash'] = { rui_UnitFrame, 211, 90, 211/1024, 422/1024, 275/512, 365/512 },
	['TargetFrame-HighLevelIcon'] = { rui_UnitFrame, 10, 13, 252/1024, 262/1024, 490/512, 503/512 },
	['PlayerFrame-TextureFrame-Normal'] = { rui_UnitFrame, 210, 90, 423/1024, 633/1024, 91/512, 181/512 },
	['PlayerFrame-TextureFrame-Vehicle'] = { rui_UnitFrame, 209, 89, 636/1024, 845/1024, 0/512, 89/512 },
	['PlayerFrame-StatusBar-Health'] = { rui_UnitFrame, 125, 22, 3/1024, 128/1024, 483/512, 505/512 },
	['PlayerFrame-StatusBar-Mana'] = { rui_UnitFrame, 126, 11, 130/1024, 256/1024, 474/512, 485/512 },
	['PlayerFrame-Flash'] = { rui_UnitFrame, 209, 89, 212/1024, 421/1024, 184/512, 273/512 },
	['PlayerFrame-Status'] = { rui_UnitFrame, 209, 89, 0/1024, 209/1024, 184/512, 273/512 },
	['PlayerFrame-GroupIndicator'] = { rui_UnitFrame, 72, 14, 131/1024, 203/1024, 491/512, 505/512 },
	['PlayerFrame-AttackIcon'] = { rui_UnitFrame, 19, 14, 269/1024, 288/1024, 490/512, 504/512 },
	['PartyFrame-TextureFrame-Normal'] = { rui_UnitFrame, 120, 47, 848/1024, 968/1024, 0/512, 47/512 },
	['PartyFrame-StatusBar-Health'] = { rui_UnitFrame, 71, 11, 259/1024, 330/1024, 474/512, 485/512 },
	['PartyFrame-StatusBar-Mana'] = { rui_UnitFrame, 74, 9, 267/1024, 341/1024, 460/512, 469/512 },
	['PartyFrame-Flash'] = { rui_UnitFrame, 120, 47, 848/1024, 968/1024, 50/512, 97/512 },
	['PartyFrame-Status'] = { rui_UnitFrame, 120, -37, 848/1024, 968/1024, 184/512, 147/512 },
	['CastingBar-Background'] = { rui_CastingBar, 417, 27, 0/512, 417/512, 95/256, 122/256 },
	['CastingBar-Border'] = { rui_CastingBar, 423, 27, 0/512, 423/512, 63/256, 90/256 },
	['CastingBar-MainBackground'] = { rui_CastingBar, 419, 56, 0/512, 419/512, 0/256, 56/256 },
	['CastingBar-StatusBar-Casting'] = { rui_CastingBar, 418, 21, 0/512, 418/512, 149/256, 170/256 },
	['CastingBar-StatusBar-Channeling'] = { rui_CastingBar, 417, 22, 0/512, 417/512, 124/256, 146/256 },
	['CastingBar-StatusBar-Failed'] = { rui_CastingBar, 417, 23, 0/512, 417/512, 173/256, 196/256 },
	['CastingBar-Spark'] = { rui_CastingBar, 7, 53, 423/512, 430/512, 97/256, 150/256 },
	['CastingBar-BorderShield'] = { rui_CastingBar, 72, 86, 437/512, 509/512, 1/256, 87/256 },
	['CollapseButton-Left'] = { rui_CollapseButton, 18, 31, 4/64, 22/64, 0/64, 31/64 },
	['CollapseButton-Right'] = { rui_CollapseButton, 17, 31, 5/64, 22/64, 31/64, 62/64 },
	['CollapseButton-Up'] = { rui_CollapseButton, 32, 17, 31/64, 63/64, 10/64, 27/64 },
	['CollapseButton-Down'] = { rui_CollapseButton, 31, 17, 31/64, 62/64, 37/64, 54/64 },
	['Minimap-Border'] = { rui_Minimap, 438, 446, 0/512, 438/512, 60/1024, 506/1024 },
	['Minimap-Border-Top'] = { rui_Minimap, 255, 27, 105/512, 360/512, 609/1024, 636/1024 },
	['Minimap-Mail-Normal'] = { rui_Minimap, 38, 27, 42/512, 80/512, 521/1024, 548/1024 },
	['Minimap-Mail-Highlight'] = { rui_Minimap, 38, 27, 1/512, 39/512, 521/1024, 548/1024 },
	['Minimap-Calendar-Normal'] = { rui_Calendar, 21, 19, 47/256, 68/256, 1/256, 20/256 },
	['Minimap-Calendar-Highlight'] = { rui_Calendar, 21, 19, 24/256, 45/256, 1/256, 20/256 },
	['Minimap-Calendar-Pushed'] = { rui_Calendar, 21, 19, 1/256, 22/256, 1/256, 20/256 },
	['Minimap-Tracking-Background'] = { rui_Minimap, 39, 38, 441/512, 480/512, 402/1024, 440/1024 },
	['Minimap-Tracking-Normal'] = { rui_Minimap, 30, 28, 149/512, 179/512, 520/1024, 548/1024 },
	['Minimap-Tracking-Highlight'] = { rui_Minimap, 30, 28, 117/512, 147/512, 520/1024, 548/1024 },
	['Minimap-Tracking-Pushed'] = { rui_Minimap, 32, 30, 83/512, 115/512, 520/1024, 550/1024 },
	['Minimap-ZoomIn-Normal'] = { rui_Minimap, 34, 34, 1/512, 35/512, 552/1024, 586/1024 },
	['Minimap-ZoomIn-Highlight'] = { rui_Minimap, 34, 34, 1/512, 35/512, 624/1024, 658/1024 },
	['Minimap-ZoomIn-Pushed'] = { rui_Minimap, 34, 34, 1/512, 35/512, 588/1024, 622/1024 },
	['Minimap-ZoomOut-Normal'] = { rui_Minimap, 34, 18, 181/512, 215/512, 520/1024, 538/1024 },
	['Minimap-ZoomOut-Highlight'] = { rui_Minimap, 34, 18, 253/512, 287/512, 520/1024, 538/1024 },
	['Minimap-ZoomOut-Pushed'] = { rui_Minimap, 34, 18, 217/512, 251/512, 520/1024, 538/1024 },
	['Minimap-Calendar-1-Normal'] = { rui_Calendar, 21, 19, 47/256, 68/256, 1/256, 20/256 },
	['Minimap-Calendar-1-Highlight'] = { rui_Calendar, 21, 19, 24/256, 45/256, 1/256, 20/256 },
	['Minimap-Calendar-1-Pushed'] = { rui_Calendar, 21, 19, 1/256, 22/256, 1/256, 20/256 },
	['Minimap-Calendar-2-Normal'] = { rui_Calendar, 21, 19, 93/256, 114/256, 43/256, 62/256 },
	['Minimap-Calendar-2-Highlight'] = { rui_Calendar, 21, 19, 70/256, 91/256, 43/256, 62/256 },
	['Minimap-Calendar-2-Pushed'] = { rui_Calendar, 21, 19, 47/256, 68/256, 43/256, 62/256 },
	['Minimap-Calendar-3-Normal'] = { rui_Calendar, 21, 19, 70/256, 91/256, 85/256, 104/256 },
	['Minimap-Calendar-3-Highlight'] = { rui_Calendar, 21, 19, 47/256, 68/256, 232/256, 251/256 },
	['Minimap-Calendar-3-Pushed'] = { rui_Calendar, 21, 19, 47/256, 68/256, 211/256, 230/256 },
	['Minimap-Calendar-4-Normal'] = { rui_Calendar, 21, 19, 70/256, 91/256, 127/256, 146/256 },
	['Minimap-Calendar-4-Highlight'] = { rui_Calendar, 21, 19, 70/256, 91/256, 106/256, 125/256 },
	['Minimap-Calendar-4-Pushed'] = { rui_Calendar, 21, 19, 231/256, 252/256, 85/256, 104/256 },
	['Minimap-Calendar-5-Normal'] = { rui_Calendar, 21, 19, 70/256, 91/256, 190/256, 209/256 },
	['Minimap-Calendar-5-Highlight'] = { rui_Calendar, 21, 19, 70/256, 91/256, 169/256, 188/256 },
	['Minimap-Calendar-5-Pushed'] = { rui_Calendar, 21, 19, 70/256, 91/256, 148/256, 167/256 },
	['Minimap-Calendar-6-Normal'] = { rui_Calendar, 21, 19, 93/256, 114/256, 106/256, 125/256 },
	['Minimap-Calendar-6-Highlight'] = { rui_Calendar, 21, 19, 70/256, 91/256, 232/256, 251/256 },
	['Minimap-Calendar-6-Pushed'] = { rui_Calendar, 21, 19, 70/256, 91/256, 211/256, 230/256 },
	['Minimap-Calendar-7-Normal'] = { rui_Calendar, 21, 19, 162/256, 183/256, 106/256, 125/256 },
	['Minimap-Calendar-7-Highlight'] = { rui_Calendar, 21, 19, 139/256, 160/256, 106/256, 125/256 },
	['Minimap-Calendar-7-Pushed'] = { rui_Calendar, 21, 19, 116/256, 137/256, 106/256, 125/256 },
	['Minimap-Calendar-8-Normal'] = { rui_Calendar, 21, 19, 231/256, 252/256, 106/256, 125/256 },
	['Minimap-Calendar-8-Highlight'] = { rui_Calendar, 21, 19, 208/256, 229/256, 106/256, 125/256 },
	['Minimap-Calendar-8-Pushed'] = { rui_Calendar, 21, 19, 185/256, 206/256, 106/256, 125/256 },
	['Minimap-Calendar-9-Normal'] = { rui_Calendar, 21, 19, 93/256, 114/256, 169/256, 188/256 },
	['Minimap-Calendar-9-Highlight'] = { rui_Calendar, 21, 19, 93/256, 114/256, 169/256, 188/256 },
	['Minimap-Calendar-9-Pushed'] = { rui_Calendar, 21, 19, 93/256, 114/256, 127/256, 146/256 },
	['Minimap-Calendar-10-Normal'] = { rui_Calendar, 21, 19, 116/256, 137/256, 1/256, 20/256 },
	['Minimap-Calendar-10-Highlight'] = { rui_Calendar, 21, 19, 93/256, 114/256, 1/256, 20/256 },
	['Minimap-Calendar-10-Pushed'] = { rui_Calendar, 21, 19, 70/256, 91/256, 1/256, 20/256 },
	['Minimap-Calendar-11-Normal'] = { rui_Calendar, 21, 19, 185/256, 206/256, 1/256, 20/256 },
	['Minimap-Calendar-11-Highlight'] = { rui_Calendar, 21, 19, 162/256, 183/256, 1/256, 20/256 },
	['Minimap-Calendar-11-Pushed'] = { rui_Calendar, 21, 19, 139/256, 160/256, 1/256, 20/256 },
	['Minimap-Calendar-12-Normal'] = { rui_Calendar, 21, 19, 1/256, 22/256, 22/256, 41/256 },
	['Minimap-Calendar-12-Highlight'] = { rui_Calendar, 21, 19, 231/256, 252/256, 1/256, 20/256 },
	['Minimap-Calendar-12-Pushed'] = { rui_Calendar, 21, 19, 208/256, 229/256, 1/256, 20/256 },
	['Minimap-Calendar-13-Normal'] = { rui_Calendar, 21, 19, 70/256, 91/256, 22/256, 41/256 },
	['Minimap-Calendar-13-Highlight'] = { rui_Calendar, 21, 19, 47/256, 68/256, 22/256, 41/256 },
	['Minimap-Calendar-13-Pushed'] = { rui_Calendar, 21, 19, 24/256, 45/256, 22/256, 41/256 },
	['Minimap-Calendar-14-Normal'] = { rui_Calendar, 21, 19, 139/256, 160/256, 22/256, 41/256 },
	['Minimap-Calendar-14-Highlight'] = { rui_Calendar, 21, 19, 116/256, 137/256, 22/256, 41/256 },
	['Minimap-Calendar-14-Pushed'] = { rui_Calendar, 21, 19, 93/256, 114/256, 22/256, 41/256 },
	['Minimap-Calendar-15-Normal'] = { rui_Calendar, 21, 19, 208/256, 229/256, 22/256, 41/256 },
	['Minimap-Calendar-15-Highlight'] = { rui_Calendar, 21, 19, 185/256, 206/256, 22/256, 41/256 },
	['Minimap-Calendar-15-Pushed'] = { rui_Calendar, 21, 19, 162/256, 183/256, 22/256, 41/256 },
	['Minimap-Calendar-16-Normal'] = { rui_Calendar, 21, 19, 1/256, 22/256, 64/256, 83/256 },
	['Minimap-Calendar-16-Highlight'] = { rui_Calendar, 21, 19, 1/256, 22/256, 43/256, 62/256 },
	['Minimap-Calendar-16-Pushed'] = { rui_Calendar, 21, 19, 231/256, 252/256, 22/256, 41/256 },
	['Minimap-Calendar-17-Normal'] = { rui_Calendar, 21, 19, 1/256, 22/256, 127/256, 146/256 },
	['Minimap-Calendar-17-Highlight'] = { rui_Calendar, 21, 19, 1/256, 22/256, 106/256, 125/256 },
	['Minimap-Calendar-17-Pushed'] = { rui_Calendar, 21, 19, 1/256, 22/256, 85/256, 104/256 },
	['Minimap-Calendar-18-Normal'] = { rui_Calendar, 21, 19, 1/256, 22/256, 190/256, 209/256 },
	['Minimap-Calendar-18-Highlight'] = { rui_Calendar, 21, 19, 1/256, 22/256, 169/256, 188/256 },
	['Minimap-Calendar-18-Pushed'] = { rui_Calendar, 21, 19, 1/256, 22/256, 148/256, 167/256 },
	['Minimap-Calendar-19-Normal'] = { rui_Calendar, 21, 19, 24/256, 45/256, 43/256, 62/256 },
	['Minimap-Calendar-19-Highlight'] = { rui_Calendar, 21, 19, 1/256, 22/256, 232/256, 251/256 },
	['Minimap-Calendar-19-Pushed'] = { rui_Calendar, 21, 19, 1/256, 22/256, 211/256, 230/256 },
	['Minimap-Calendar-20-Normal'] = { rui_Calendar, 21, 19, 162/256, 183/256, 43/256, 62/256 },
	['Minimap-Calendar-20-Highlight'] = { rui_Calendar, 21, 19, 139/256, 160/256, 43/256, 62/256 },
	['Minimap-Calendar-20-Pushed'] = { rui_Calendar, 21, 19, 116/256, 137/256, 43/256, 62/256 },
	['Minimap-Calendar-21-Normal'] = { rui_Calendar, 21, 19, 231/256, 252/256, 43/256, 62/256 },
	['Minimap-Calendar-21-Highlight'] = { rui_Calendar, 21, 19, 208/256, 229/256, 43/256, 62/256 },
	['Minimap-Calendar-21-Pushed'] = { rui_Calendar, 21, 19, 185/256, 206/256, 43/256, 62/256 },
	['Minimap-Calendar-22-Normal'] = { rui_Calendar, 21, 19, 24/256, 45/256, 106/256, 125/256 },
	['Minimap-Calendar-22-Highlight'] = { rui_Calendar, 21, 19, 24/256, 45/256, 85/256, 104/256 },
	['Minimap-Calendar-22-Pushed'] = { rui_Calendar, 21, 19, 24/256, 45/256, 64/256, 83/256 },
	['Minimap-Calendar-23-Normal'] = { rui_Calendar, 21, 19, 24/256, 45/256, 169/256, 188/256 },
	['Minimap-Calendar-23-Highlight'] = { rui_Calendar, 21, 19, 24/256, 45/256, 148/256, 167/256 },
	['Minimap-Calendar-23-Pushed'] = { rui_Calendar, 21, 19, 24/256, 45/256, 127/256, 146/256 },
	['Minimap-Calendar-24-Normal'] = { rui_Calendar, 21, 19, 24/256, 45/256, 232/256, 251/256 },
	['Minimap-Calendar-24-Highlight'] = { rui_Calendar, 21, 19, 24/256, 45/256, 211/256, 230/256 },
	['Minimap-Calendar-24-Pushed'] = { rui_Calendar, 21, 19, 24/256, 45/256, 190/256, 209/256 },
	['Minimap-Calendar-25-Normal'] = { rui_Calendar, 21, 19, 93/256, 114/256, 64/256, 83/256 },
	['Minimap-Calendar-25-Highlight'] = { rui_Calendar, 21, 19, 70/256, 91/256, 64/256, 83/256 },
	['Minimap-Calendar-25-Pushed'] = { rui_Calendar, 21, 19, 47/256, 68/256, 64/256, 83/256 },
	['Minimap-Calendar-26-Normal'] = { rui_Calendar, 21, 19, 162/256, 183/256, 64/256, 83/256 },
	['Minimap-Calendar-26-Highlight'] = { rui_Calendar, 21, 19, 139/256, 160/256, 64/256, 83/256 },
	['Minimap-Calendar-26-Pushed'] = { rui_Calendar, 21, 19, 116/256, 137/256, 64/256, 83/256 },
	['Minimap-Calendar-27-Normal'] = { rui_Calendar, 21, 19, 231/256, 252/256, 64/256, 83/256 },
	['Minimap-Calendar-27-Highlight'] = { rui_Calendar, 21, 19, 208/256, 229/256, 64/256, 83/256 },
	['Minimap-Calendar-27-Pushed'] = { rui_Calendar, 21, 19, 185/256, 206/256, 64/256, 83/256 },
	['Minimap-Calendar-28-Normal'] = { rui_Calendar, 21, 19, 47/256, 68/256, 127/256, 146/256 },
	['Minimap-Calendar-28-Highlight'] = { rui_Calendar, 21, 19, 47/256, 68/256, 106/256, 125/256 },
	['Minimap-Calendar-28-Pushed'] = { rui_Calendar, 21, 19, 47/256, 68/256, 85/256, 104/256 },
	['Minimap-Calendar-29-Normal'] = { rui_Calendar, 21, 19, 47/256, 68/256, 190/256, 209/256 },
	['Minimap-Calendar-29-Highlight'] = { rui_Calendar, 21, 19, 47/256, 68/256, 169/256, 188/256 },
	['Minimap-Calendar-29-Pushed'] = { rui_Calendar, 21, 19, 47/256, 68/256, 148/256, 167/256 },
	['Minimap-Calendar-30-Normal'] = { rui_Calendar, 21, 19, 139/256, 160/256, 85/256, 104/256 },
	['Minimap-Calendar-30-Highlight'] = { rui_Calendar, 21, 19, 116/256, 137/256, 85/256, 104/256 },
	['Minimap-Calendar-30-Pushed'] = { rui_Calendar, 21, 19, 93/256, 114/256, 85/256, 104/256 },
	['Minimap-Calendar-31-Normal'] = { rui_Calendar, 21, 19, 208/256, 229/256, 85/256, 104/256 },
	['Minimap-Calendar-31-Highlight'] = { rui_Calendar, 21, 19, 185/256, 206/256, 85/256, 104/256 },
	['Minimap-Calendar-31-Pushed'] = { rui_Calendar, 21, 19, 162/256, 183/256, 85/256, 104/256 },
	['ActionBar-LeftCap-Alliance'] = { rui_ActionBarHorizontal, 356, 334, 1/512, 357/512, 209/2048, 543/2048 },
	['ActionBar-RightCap-Alliance'] = { rui_ActionBarHorizontal, 356, 334, 1/512, 357/512, 545/2048, 879/2048 },
	['ActionBar-LeftCap-Horde'] = { rui_ActionBarHorizontal, 356, 334, 1/512, 357/512, 881/2048, 1215/2048 },
	['ActionBar-RightCap-Horde'] = { rui_ActionBarHorizontal, 356, 334, 1/512, 357/512, 1217/2048, 1551/2048 },
	['ActionBar-ButtonUp-Normal'] = { rui_ActionBarHorizontal, 34, 28, 359/512, 393/512, 833/2048, 861/2048 },
	['ActionBar-ButtonUp-Highlight'] = { rui_ActionBarHorizontal, 34, 28, 453/512, 487/512, 709/2048, 737/2048 },
	['ActionBar-ButtonUp-Pushed'] = { rui_ActionBarHorizontal, 34, 28, 453/512, 487/512, 679/2048, 707/2048 },
	['ActionBar-ButtonDown-Normal'] = { rui_ActionBarHorizontal, 34, 28, 463/512, 497/512, 605/2048, 633/2048 },
	['ActionBar-ButtonDown-Highlight'] = { rui_ActionBarHorizontal, 34, 28, 463/512, 497/512, 575/2048, 603/2048 },
	['ActionBar-ButtonDown-Pushed'] = { rui_ActionBarHorizontal, 34, 28, 463/512, 497/512, 545/2048, 573/2048 },
	['ActionBar-ActionButton-Highlight'] = { rui_ActionBarHorizontal, 92, 90, 359/512, 451/512, 1065/2048, 1155/2048 },
	['ActionBar-ActionButton-Pushed'] = { rui_ActionBarHorizontal, 92, 90, 359/512, 451/512, 881/2048, 971/2048 },
	['ActionBar-ActionButton-Flash'] = { rui_ActionBarHorizontal, 92, 90, 359/512, 451/512, 973/2048, 1063/2048 },
	['ActionBar-ActionButton-Border'] = { rui_ActionBarHorizontal, 92, 90, 359/512, 451/512, 649/2048, 739/2048 },
	['ActionBar-ActionButton-Background'] = { rui_ActionBarHorizontal, 128, 124, 359/512, 487/512, 209/2048, 333/2048 },
	['ExperienceBar-Background'] = { rui_ExperienceBar, 569.99911121875, 9, 0.00088878125/2048, 570/2048, 20/64, 29/64 },
	['ExperienceBar-Border'] = { rui_ExperienceBar, 571, 17, 1/2048, 572/2048, 1/64, 18/64 },
	['BagsBar-SlotButton-Highlight'] = { rui_BagSlots, 61, 61, 358/512, 419/512, 1/128, 62/128 },
	['BagsBar-SlotButton-Border'] = { rui_BagSlots, 61, 61, 295/512, 356/512, 1/128, 62/128 },
	['BagsBar-KeySlot-Normal'] = { rui_BagSlotsKey, 60, 61, 3/128, 63/128, 64/128, 125/128 },
	['BagsBar-MainSlot-Normal'] = { rui_BagSlots, 96, 96, 1/512, 97/512, 1/128, 97/128 },
	['BagsBar-MainSlot-Highlight'] = { rui_BagSlots, 96, 96, 99/512, 195/512, 1/128, 97/128 },
	['MicroMenu-Spellbook-Normal'] = { rui_MicroMenu, 51, 70, 389/512, 440/512, 312/512, 382/512 },
	['MicroMenu-Spellbook-Highlight'] = { rui_MicroMenu, 51, 70, 334/512, 385/512, 312/512, 382/512 },
	['MicroMenu-Spellbook-Pushed'] = { rui_MicroMenu, 51, 70, 280/512, 331/512, 312/512, 382/512 },
	['MicroMenu-Talent-Normal'] = { rui_MicroMenu, 51, 70, 170/512, 221/512, 312/512, 382/512 },
	['MicroMenu-Talent-Highlight'] = { rui_MicroMenu, 51, 70, 116/512, 167/512, 312/512, 382/512 },
	['MicroMenu-Talent-Pushed'] = { rui_MicroMenu, 51, 70, 63/512, 114/512, 312/512, 382/512 },
	['MicroMenu-Talent-Disabled'] = { rui_MicroMenu, 51, 70, 6/512, 57/512, 312/512, 382/512 },
	['MicroMenu-LFD-Normal'] = { rui_MicroMenu, 51, 71, 387/512, 438/512, 158/512, 229/512 },
	['MicroMenu-LFD-Highlight'] = { rui_MicroMenu, 51, 71, 331/512, 382/512, 158/512, 229/512 },
	['MicroMenu-LFD-Pushed'] = { rui_MicroMenu, 51, 71, 277/512, 328/512, 158/512, 229/512 },
	['MicroMenu-LFD-Disabled'] = { rui_MicroMenu, 51, 71, 222/512, 273/512, 158/512, 229/512 },
	['MicroMenu-MainMenu-Normal'] = { rui_MicroMenu, 51, 70, 387/512, 438/512, 235/512, 305/512 },
	['MicroMenu-MainMenu-Highlight'] = { rui_MicroMenu, 51, 70, 278/512, 329/512, 235/512, 305/512 },
	['MicroMenu-MainMenu-Pushed'] = { rui_MicroMenu, 50, 70, 333/512, 383/512, 235/512, 305/512 },
	['MicroMenu-Help-Normal'] = { rui_MicroMenu, 50, 70, 169/512, 219/512, 158/512, 228/512 },
	['MicroMenu-Help-Highlight'] = { rui_MicroMenu, 51, 70, 115/512, 166/512, 158/512, 228/512 },
	['MicroMenu-Help-Pushed'] = { rui_MicroMenu, 51, 70, 60/512, 111/512, 158/512, 228/512 },
	['MicroMenu-Socials-Normal'] = { rui_MicroMenu, 51, 70, 169/512, 220/512, 235/512, 305/512 },
	['MicroMenu-Socials-Highlight'] = { rui_MicroMenu, 51, 70, 115/512, 166/512, 235/512, 305/512 },
	['MicroMenu-Socials-Pushed'] = { rui_MicroMenu, 51, 70, 61/512, 112/512, 235/512, 305/512 },
	['MicroMenu-Achievement-Normal'] = { rui_MicroMenu, 50, 70, 383/512, 433/512, 4/512, 74/512 },
	['MicroMenu-Achievement-Highlight'] = { rui_MicroMenu, 51, 70, 329/512, 380/512, 4/512, 74/512 },
	['MicroMenu-Achievement-Pushed'] = { rui_MicroMenu, 51, 70, 274/512, 325/512, 4/512, 74/512 },
	['MicroMenu-Achievement-Disabled'] = { rui_MicroMenu, 51, 70, 220/512, 271/512, 4/512, 74/512 },
	['MicroMenu-QuestLog-Normal'] = { rui_MicroMenu, 51, 70, 166/512, 217/512, 4/512, 74/512 },
	['MicroMenu-QuestLog-Highlight'] = { rui_MicroMenu, 52, 70, 112/512, 164/512, 4/512, 74/512 },
	['MicroMenu-QuestLog-Pushed'] = { rui_MicroMenu, 51, 70, 58/512, 109/512, 4/512, 74/512 },
	['MicroMenu-QuestLog-Disabled'] = { rui_MicroMenu, 51, 70, 4/512, 55/512, 4/512, 74/512 },
	['MicroMenu-Empty'] = { rui_MicroMenu, 51, 69, 384/512, 435/512, 82/512, 151/512 },
	['ActionMainBar-TopLeft'] = { rui_ActionBarHorizontal, 36, 33, 464/512, 500/512, 475/2048, 508/2048 },
	['ActionMainBar-TopRight'] = { rui_ActionBarHorizontal, 36, 31, 461/512, 497/512, 442/2048, 473/2048 },
	['ActionMainBar-BottomLeft'] = { rui_ActionBarHorizontal, 36, 32, 466/512, 502/512, 388/2048, 420/2048 },
	['ActionMainBar-BottomRight'] = { rui_ActionBarHorizontal, 35, 33, 464/512, 499/512, 339/2048, 372/2048 },
	['ActionMainBar-Top'] = { rui_ActionBarHorizontal, 20, 9, 445/512, 465/512, 145/2048, 154/2048 },
	['ActionMainBar-Bottom'] = { rui_ActionBarHorizontal, 20, 7, 445/512, 465/512, 145/2048, 152/2048 },
	['ActionMainBar-Left'] = { rui_ActionBarVertical, 7, 12, 144/256, 151/256, 22/64, 34/64 },
	['ActionMainBar-Right'] = { rui_ActionBarVertical, 6, 12, 144/256, 150/256, 22/64, 34/64 },
	['ActionMainBar-GapDown'] = { rui_ActionBarHorizontal, 19, 33, 396/512, 415/512, 831/2048, 864/2048 },
	['ActionMainBar-GapUp'] = { rui_ActionBarHorizontal, 19, 30, 422/512, 441/512, 831/2048, 861/2048 },
	['ActionMainBar-GapCenter'] = { rui_ActionBarVertical, 9, 12, 143/256, 152/256, 22/64, 34/64 },
	['Minimap-PVP-alliance-Normal'] = { rui_Battlefield, 54, 53, 72/256, 126/256, 5/64, 58/64 },
	['Minimap-PVP-alliance-Pushed'] = { rui_Battlefield, 54, 53, 17/256, 71/256, 5/64, 58/64 },
	['Minimap-PVP-horde-Normal'] = { rui_Battlefield, 54, 53, 181/256, 235/256, 5/64, 58/64 },
	['Minimap-PVP-horde-Pushed'] = { rui_Battlefield, 55, 53, 127/256, 182/256, 5/64, 58/64 },

	-- UI-Frame-Metal: retail's PortraitFrameTemplate chrome. Texcoords match bagster's
	-- in-game-verified values against these same three sheets.
	['UI-Frame-PortraitMetal-CornerTopLeft'] = { rui_FrameMetal, 75, 75, 0.00195312, 0.294922, 0.298828, 0.591797 },
	['UI-Frame-Metal-CornerTopRight'] = { rui_FrameMetal, 75, 75, 0.298828, 0.591797, 0.00195312, 0.294922 },
	-- Same corner without the portrait cutout. Measured off the sheet, its rail sits 12px in from
	-- the piece's left edge exactly like CornerBottomLeft and EdgeLeft, so it drops into the same
	-- left column; mirroring CornerTopRight instead would land the rail 10.5px off (right-side
	-- art carries only 1.5px of padding).
	['UI-Frame-Metal-CornerTopLeft'] = { rui_FrameMetal, 75, 75, 0.00195312, 0.294922, 0.00195312, 0.294922 },
	-- The worn streak band retail tiles across the body just under a window's title bar.
	['_UI-Frame-TopTileStreaks'] = { rui_FrameInner, 256, 43, 0, 1, 0.007812, 0.343750 },

	-- UI-Frame-Inner: retail's InsetFrameTemplate trim, 6px corners over 3px tiles. Rects come from
	-- UiTextureAtlasMember, so these are the client's own numbers, not a fit to substitute art. The
	-- horizontal pair rides the sheet the streaks already come from -- same file, atlas 950.
	['UI-Frame-InnerTopLeft'] = { rui_Inner, 6, 6, 97/128, 103/128, 71/128, 77/128 },
	['UI-Frame-InnerTopRight'] = { rui_Inner, 6, 6, 105/128, 111/128, 71/128, 77/128 },
	['UI-Frame-InnerBotLeftCorner'] = { rui_Inner, 6, 6, 81/128, 87/128, 71/128, 77/128 },
	['UI-Frame-InnerBotRight'] = { rui_Inner, 6, 6, 89/128, 95/128, 71/128, 77/128 },
	['!UI-Frame-InnerLeftTile'] = { rui_InnerV, 3, 256, 31/64, 34/64, 0, 1, false, true },
	['!UI-Frame-InnerRightTile'] = { rui_InnerV, 3, 256, 36/64, 39/64, 0, 1, false, true },
	['_UI-Frame-InnerTopTile'] = { rui_FrameInner, 256, 3, 0, 1, 116/128, 119/128, true, false },
	['_UI-Frame-InnerBotTile'] = { rui_FrameInner, 256, 3, 0, 1, 111/128, 114/128, true, false },

	-- The collapse box retail's ReputationSubHeaderTemplate wears, cut out of its 2048x1024 sheet:
	-- four 22px icons are not worth shipping 8MB for.
	['campaign_headericon_closed'] = { rui_Collapse, 22, 22, 0/128, 22/128, 0/32, 22/32 },
	['campaign_headericon_closedpressed'] = { rui_Collapse, 22, 22, 32/128, 54/128, 0/32, 22/32 },
	['campaign_headericon_open'] = { rui_Collapse, 22, 22, 64/128, 86/128, 0/32, 22/32 },
	['campaign_headericon_openpressed'] = { rui_Collapse, 22, 22, 96/128, 118/128, 0/32, 22/32 },

	-- What WowStyle1FilterDropdownMixin actually asks for. Not the a-button, which is the arrow in
	-- its own box: this is the whole control, gold chevron already part of the art. Retail swaps the
	-- WHOLE texture per state rather than washing a highlight over it, so all six ship.
	['common-dropdown-b-button'] = { rui_Dropdown, 97, 26, 0/128, 97/128, 0/256, 26/256 },
	['common-dropdown-b-button-hover'] = { rui_Dropdown, 97, 26, 0/128, 97/128, 26/256, 52/256 },
	['common-dropdown-b-button-pressed'] = { rui_Dropdown, 97, 26, 0/128, 97/128, 52/256, 78/256 },
	['common-dropdown-b-button-pressedhover'] = { rui_Dropdown, 97, 26, 0/128, 97/128, 78/256, 104/256 },
	['common-dropdown-b-button-open'] = { rui_Dropdown, 97, 26, 0/128, 97/128, 104/256, 130/256 },
	['common-dropdown-b-button-disabled'] = { rui_Dropdown, 97, 26, 0/128, 97/128, 130/256, 156/256 },

	-- WowStyle1DropdownTemplate's pair, which is what Reputation and Currency wear -- NOT the
	-- b-button above, that one is the filter dropdown the mount journal uses.
	['common-dropdown-textholder'] = { rui_Dropdown, 54, 41, 0/128, 54/128, 160/256, 201/256 },
	-- Cut in three because the source is a 54x41 rounded rect with a 12px bevel: stretched whole to a
	-- row it smears the corners sideways and squashes the bevel. Only the flat middle may stretch.
	['common-dropdown-textholder-left'] = { rui_Dropdown, 18, 41, 0/128, 18/128, 160/256, 201/256 },
	['common-dropdown-textholder-center'] = { rui_Dropdown, 18, 41, 18/128, 36/128, 160/256, 201/256 },
	['common-dropdown-textholder-right'] = { rui_Dropdown, 18, 41, 36/128, 54/128, 160/256, 201/256 },
	-- Six states, because WowStyle1DropdownMixin:GetArrowAtlas swaps the WHOLE arrow per state
	-- rather than washing a highlight over it.
	['common-dropdown-a-button'] = { rui_Dropdown, 27, 27, 0/128, 27/128, 202/256, 229/256 },
	['common-dropdown-a-button-hover'] = { rui_Dropdown, 27, 27, 28/128, 55/128, 202/256, 229/256 },
	['common-dropdown-a-button-pressed'] = { rui_Dropdown, 27, 27, 56/128, 83/128, 202/256, 229/256 },
	['common-dropdown-a-button-pressedhover'] = { rui_Dropdown, 27, 27, 84/128, 111/128, 202/256, 229/256 },
	['common-dropdown-a-button-open'] = { rui_Dropdown, 27, 27, 0/128, 27/128, 229/256, 256/256 },
	['common-dropdown-a-button-disabled'] = { rui_Dropdown, 27, 27, 28/128, 55/128, 229/256, 256/256 },

	-- Retail's MinimalCheckboxTemplate art. No modern SWORD exists anywhere in the atlas, so the
	-- at-war box keeps the client's classic UI-CheckBox-SwordCheck over this modern square.
	['checkbox-minimal'] = { rui_Checkbox, 30, 29, 1/64, 31/64, 1/64, 30/64 },
	['checkmark-minimal'] = { rui_Checkbox, 30, 29, 1/64, 31/64, 32/64, 61/64 },
	['checkmark-minimal-disabled'] = { rui_Checkbox, 30, 29, 33/64, 63/64, 1/64, 30/64 },

	-- UI-Frame-DiamondMetal: the dialog nine-slice retail frames its popups with. Rects come from
	-- UiTextureAtlasMember, which only lists the 2x cut, so the pieces draw at their 64px override.
	['UI-Frame-DiamondMetal-CornerTopLeft'] = { rui_Diamond, 64, 64, 1/256, 129/256, 521/1024, 649/1024 },
	['UI-Frame-DiamondMetal-CornerTopRight'] = { rui_Diamond, 64, 64, 1/256, 129/256, 651/1024, 779/1024 },
	['UI-Frame-DiamondMetal-CornerBottomLeft'] = { rui_Diamond, 64, 64, 1/256, 129/256, 261/1024, 389/1024 },
	['UI-Frame-DiamondMetal-CornerBottomRight'] = { rui_Diamond, 64, 64, 1/256, 129/256, 391/1024, 519/1024 },
	['_UI-Frame-DiamondMetal-EdgeTop'] = { rui_Diamond, 64, 64, 0, 128/256, 131/1024, 259/1024, true, false },
	['_UI-Frame-DiamondMetal-EdgeBottom'] = { rui_Diamond, 64, 64, 0, 128/256, 1/1024, 129/1024, true, false },
	['!UI-Frame-DiamondMetal-EdgeLeft'] = { rui_DiamondEdges, 64, 64, 1/512, 129/512, 0, 1, false, true },
	['!UI-Frame-DiamondMetal-EdgeRight'] = { rui_DiamondEdges, 64, 64, 131/512, 259/512, 0, 1, false, true },
	-- The sheet's top corners are 75px and its bottom pair 32px, so a frame built from both joins two
	-- widths down each side. These are the bottom corners flipped vertically: a matching 32px set.
	['UI-Frame-Metal-CornerTopLeft-Thin'] = { rui_FrameMetal, 32, 32, 0.298828, 0.423828, 0.423828, 0.298828 },
	['UI-Frame-Metal-CornerTopRight-Thin'] = { rui_FrameMetal, 32, 32, 0.427734, 0.552734, 0.423828, 0.298828 },
	['UI-Frame-Metal-CornerBottomLeft'] = { rui_FrameMetal, 32, 32, 0.298828, 0.423828, 0.298828, 0.423828 },
	['UI-Frame-Metal-CornerBottomRight'] = { rui_FrameMetal, 32, 32, 0.427734, 0.552734, 0.298828, 0.423828 },
	['_UI-Frame-Metal-EdgeTop'] = { rui_FrameMetalH, 32, 75, 0, 1, 0.00390625, 0.589844 },
	['_UI-Frame-Metal-EdgeBottom'] = { rui_FrameMetalH, 16, 32, 0, 0.5, 0.597656, 0.847656 },
	['!UI-Frame-Metal-EdgeLeft'] = { rui_FrameMetalV, 75, 16, 0.00195312, 0.294922, 0, 1 },
	['!UI-Frame-Metal-EdgeRight'] = { rui_FrameMetalV, 75, 16, 0.298828, 0.591797, 0, 1 },

	-- Character panel interior. Rects lifted from retail's atlas table for these sheets.
	['character-panel-background'] = { rui_CharPanelBg, 450, 420, 0.000977, 0.440430, 0.001953, 0.822266 },
	['UI-Character-Info-Title'] = { rui_CharInfoA, 196, 40, 0.000977, 0.192383, 0.698242, 0.737305 },
	['UI-Character-Info-Line-Bounce'] = { rui_CharInfoA, 157, 19, 0.000977, 0.154297, 0.769531, 0.788086 },

	-- Per-class stats-pane backdrops. The two sheets split the class roster; Wrath uses 10 of them.
	['ui-character-info-mage-bg'] = { rui_CharInfoA, 197, 355, 0.000977, 0.193359, 0.000977, 0.347656 },
	['ui-character-info-paladin-bg'] = { rui_CharInfoA, 197, 355, 0.195312, 0.387695, 0.000977, 0.347656 },
	['ui-character-info-rogue-bg'] = { rui_CharInfoA, 197, 355, 0.389648, 0.582031, 0.000977, 0.347656 },
	['ui-character-info-warlock-bg'] = { rui_CharInfoA, 197, 355, 0.583984, 0.776367, 0.000977, 0.347656 },
	['ui-character-info-warrior-bg'] = { rui_CharInfoA, 197, 355, 0.778320, 0.970703, 0.000977, 0.347656 },
	['ui-character-info-priest-bg'] = { rui_CharInfoA, 197, 355, 0.195312, 0.387695, 0.349609, 0.696289 },
	['ui-character-info-shaman-bg'] = { rui_CharInfoA, 197, 355, 0.389648, 0.582031, 0.349609, 0.696289 },
	['ui-character-info-deathknight-bg'] = { rui_CharInfoB, 197, 355, 0.000977, 0.193359, 0.001953, 0.695312 },
	['ui-character-info-druid-bg'] = { rui_CharInfoB, 197, 355, 0.389648, 0.582031, 0.001953, 0.695312 },
	['ui-character-info-hunter-bg'] = { rui_CharInfoB, 197, 355, 0.583984, 0.776367, 0.001953, 0.695312 },

	-- Retail's minimal scrollbar (the "small" family: 8px slider, 8x8 caps, 17x11 arrows).
	['minimal-scrollbar-track-top'] = { rui_Scrollbar, 8, 8, 0.625, 0.75, 0.84375, 0.96875 },
	['minimal-scrollbar-track-bottom'] = { rui_Scrollbar, 8, 8, 0.625, 0.75, 0.6875, 0.8125 },
	['!minimal-scrollbar-track-middle'] = { rui_ScrollbarMid, 8, 1, 0.015625, 0.140625, 0, 0.000977 },
	['minimal-scrollbar-thumb-top'] = { rui_Scrollbar, 8, 8, 0.3125, 0.4375, 0.84375, 0.96875 },
	['minimal-scrollbar-thumb-bottom'] = { rui_Scrollbar, 8, 8, 0.609375, 0.734375, 0.484375, 0.609375 },
	['minimal-scrollbar-thumb-middle'] = { rui_ScrollbarMid, 8, 715, 0.484375, 0.609375, 0.000977, 0.699219 },
	['minimal-scrollbar-arrow-top'] = { rui_Scrollbar, 17, 11, 0.015625, 0.28125, 0.484375, 0.65625 },
	['minimal-scrollbar-arrow-bottom'] = { rui_Scrollbar, 17, 11, 0.015625, 0.28125, 0.28125, 0.453125 },

	-- Retail's square button face and its icon glyphs, used by the model rotate controls.
	['common-button-square-gray-up'] = { rui_CommonButtons, 42, 42, 0.000977, 0.250977, 0.536133, 0.786133 },
	['common-button-square-gray-down'] = { rui_CommonButtons, 42, 42, 0.000977, 0.250977, 0.284180, 0.534180 },
	['common-icon-rotateleft'] = { rui_CommonIcons, 20, 20, 0.126465, 0.175293, 0.756836, 0.854492 },
	['common-icon-rotateright'] = { rui_CommonIcons, 20, 20, 0.126465, 0.175293, 0.856445, 0.954102 },
	['common-icon-zoomin'] = { rui_CommonIcons, 25, 25, 0.504395, 0.629395, 0.000977, 0.250977 },
	['common-icon-zoomout'] = { rui_CommonIcons, 25, 25, 0.756348, 0.881348, 0.000977, 0.250977 },
	['common-icon-undo'] = { rui_CommonIcons, 25, 25, 0.378418, 0.503418, 0.252930, 0.502930 },
	['honorsystem-portrait-alliance'] = { rui_RingAlliance, 50, 52, 0, 0.78125, 0, 0.8125 },
	['honorsystem-portrait-horde'] = { rui_RingHorde, 50, 52, 0, 0.78125, 0, 0.8125 },
	['honorsystem-portrait-neutral'] = { rui_RingNeutral, 50, 52, 0, 0.78125, 0, 0.8125 },

	['common-icon-checkmark'] = { rui_CommonIcons, 25, 25, 0.000488, 0.125488, 0.504883, 0.754883 },
	['common-icon-checkmark-yellow'] = { rui_CommonIcons, 25, 25, 0.126465, 0.251465, 0.000977, 0.250977 },
	['common-icon-delete'] = { rui_CommonIcons, 20, 20, 0.000488, 0.049316, 0.756836, 0.854492 },

	-- Collapsible list headers: a 3-piece bar whose right cap doubles as the expand chevron.
	['options_listexpand_left'] = { rui_ListExpand, 12, 26, 0.007812, 0.101562, 0.656250, 0.859375 },
	['_options_listexpand_middle'] = { rui_ListExpand, 1, 26, 0.000000, 0.007812, 0.218750, 0.421875 },
	['options_listexpand_right'] = { rui_ListExpand, 28, 26, 0.007812, 0.226562, 0.437500, 0.640625 },
	['options_listexpand_right_expanded'] = { rui_ListExpand, 28, 26, 0.242188, 0.460938, 0.437500, 0.640625 },
};

local C_Texture = {};
local CONST_ATLAS_TEXTUREPATH	= 1
local CONST_ATLAS_WIDTH			= 2
local CONST_ATLAS_HEIGHT		= 3
local CONST_ATLAS_LEFT			= 4
local CONST_ATLAS_RIGHT			= 5
local CONST_ATLAS_TOP			= 6
local CONST_ATLAS_BOTTOM		= 7
local CONST_ATLAS_TILESHORIZ	= 8
local CONST_ATLAS_TILESVERT		= 9

function C_Texture.GetAtlasInfo(atlas)
	assert(atlas, 'C_Texture.GetAtlasInfo: atlas must be specified');
	assert(addon.atlasinfo[atlas], 'C_Texture.GetAtlasInfo: atlas [ '..atlas..' ] does not exist');

	local atlas = addon.atlasinfo[atlas];
	local AtlasInfo = {};

	AtlasInfo.filename 			= atlas[CONST_ATLAS_TEXTUREPATH];
	AtlasInfo.width 			= atlas[CONST_ATLAS_WIDTH];
	AtlasInfo.height 			= atlas[CONST_ATLAS_HEIGHT];
	AtlasInfo.leftTexCoord 		= atlas[CONST_ATLAS_LEFT];
	AtlasInfo.rightTexCoord 	= atlas[CONST_ATLAS_RIGHT];
	AtlasInfo.topTexCoord 		= atlas[CONST_ATLAS_TOP];
	AtlasInfo.bottomTexCoord 	= atlas[CONST_ATLAS_BOTTOM];
	AtlasInfo.tilesHorizontally = atlas[CONST_ATLAS_TILESHORIZ];
	AtlasInfo.tilesVertically 	= atlas[CONST_ATLAS_TILESVERT];

	return AtlasInfo;
end

function C_Texture.GetFinalNameFromTextureKit(fmt, textureKits)
	if type(textureKits) == 'table' then
		return fmt:format(unpack(textureKits));
	else
		return fmt:format(textureKits);
	end
end
addon.c_texture = C_Texture;