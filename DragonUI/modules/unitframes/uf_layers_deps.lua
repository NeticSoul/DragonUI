-- ============================================================================
-- UNITFRAME LAYERS DEPENDENCIES
-- Merged from UnitFrameLayers/Dependence/ (MathUtil, Mixin, GetSpellPowerCost,
-- AnimatedHealthLossMixin, BuilderSpenderFrame) — scoped to DragonUI namespace.
-- ============================================================================
local addon = select(2, ...);

-- ============================================================================
-- MATH UTILITIES (from MathUtil.lua)
-- ============================================================================

local function Lerp(startValue, endValue, amount)
	return (1 - amount) * startValue + amount * endValue;
end

local function Clamp(value, min, max)
	if value > max then
		return max;
	elseif value < min then
		return min;
	end
	return value;
end

local function Saturate(value)
	return Clamp(value, 0.0, 1.0);
end

local function Round(value)
	if value < 0.0 then
		return math.ceil(value - .5);
	end
	return math.floor(value + .5);
end

-- Export to addon namespace for use in unitframe_layers.lua
addon.UFL_Lerp = Lerp;
addon.UFL_Clamp = Clamp;
addon.UFL_Saturate = Saturate;
addon.UFL_Round = Round;

-- ============================================================================
-- MIXIN UTILITY (from Mixin.lua)
-- ============================================================================

function DragonUI_Mixin(object, ...)
	for i = 1, select("#", ...) do
		local mixin = select(i, ...);
		for k, v in pairs(mixin) do
			object[k] = v;
		end
	end
	return object;
end

-- ============================================================================
-- GET SPELL POWER COST (from GetSpellPowerCost.lua)
-- ============================================================================

local BaseMana = {
	["DRUID"] = {
		50, 50, 50, 50, 50, 50, 50, 120, 134, 149, 165, 182, 200, 219, 239, 260, 282, 305, 329, 354,
		380, 392, 420, 449, 479, 509, 524, 554, 614, 629, 659, 689, 704, 734, 749, 779, 809, 824, 854,
		854, 869, 899, 914, 944, 959, 989, 1004, 1019, 1049, 1064, 1079, 1109, 1124, 1139, 1154, 1169, 1199, 1214, 1229, 1244,
		1359, 1469, 1582, 1694, 1807, 1919, 2032, 2145, 2257, 2370, 2482, 2595, 2708, 2820, 2933, 3045, 3158, 3270, 3383, 3496
	},
	["HUNTER"] = {
		65, 65, 65, 98, 98, 98, 98, 166, 166, 166, 166, 166, 166, 298, 298, 298, 298, 298, 298, 298,
		298, 298, 298, 298, 298, 298, 298, 298, 298, 298, 298, 298, 298, 298, 298, 298, 298, 298, 1075, 1075,
		1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075,
		1075, 2053, 2053, 2053, 2053, 2053, 2053, 2053, 2053, 3383, 3383, 3716, 3716, 3716, 3716, 3716, 3716, 3716, 3716, 5046
	},
	["MAGE"] = {
		100, 110, 110, 110, 121, 121, 121, 121, 121, 196, 215, 215, 215, 263, 271, 295, 305, 331, 343, 371,
		385, 415, 431, 431, 431, 515, 515, 556, 592, 613, 634, 634, 634, 712, 733, 733, 733, 811, 811, 853,
		853, 853, 916, 916, 916, 916, 916, 1021, 1021, 1021, 1021, 1090, 1090, 1117, 1138, 1138, 1138, 1138, 1138, 1213,
		1213, 1213, 1521, 1521, 1521, 1521, 1932, 2035, 2035, 2241, 2343, 2625, 2625, 2625, 2625, 2625, 2625, 3063, 3063, 3268
	},
	["PALADIN"] = {
		60, 64, 84, 90, 112, 120, 129, 154, 165, 192, 205, 219, 249, 265, 282, 315, 334, 354, 390, 412,
		435, 459, 499, 525, 552, 579, 621, 648, 675, 702, 729, 756, 798, 825, 852, 879, 906, 933, 960, 987,
		1014, 1041, 1068, 1110, 1137, 1164, 1176, 1203, 1230, 1257, 1284, 1311, 1338, 1365, 1392, 1419, 1446, 1458, 1485, 1512,
		1656, 1800, 1944, 2088, 2232, 2377, 2521, 2665, 2809, 2953, 3097, 3241, 3385, 3529, 3673, 3817, 3962, 4106, 4250, 4394
	},
	["PRIEST"] = {
		110, 119, 119, 119, 119, 119, 164, 164, 164, 164, 164, 164, 164, 164, 164, 164, 164, 164, 164, 164,
		164, 164, 164, 480, 480, 530, 530, 530, 530, 530, 530, 530, 530, 530, 530, 530, 530, 530, 530, 911,
		911, 911, 911, 911, 911, 911, 911, 911, 911, 911, 911, 911, 911, 911, 911, 911, 911, 911, 911, 911,
		911, 911, 911, 911, 911, 911, 911, 911, 911, 2620, 2620, 2868, 2868, 2868, 3242, 3242, 3242, 3242, 3242, 3863
	},
	["SHAMAN"] = {
		55, 55, 55, 55, 55, 55, 121, 121, 121, 175, 190, 206, 223, 241, 260, 280, 301, 323, 346, 370,
		395, 421, 448, 476, 505, 535, 566, 598, 631, 665, 699, 733, 767, 786, 820, 854, 888, 922, 941, 975,
		1009, 1028, 1062, 1096, 1115, 1149, 1183, 1202, 1236, 1255, 1289, 1313, 1342, 1376, 1395, 1414, 1448, 1467, 1501, 1520,
		1664, 1808, 1951, 2095, 2239, 2383, 2572, 2670, 2814, 2958, 3102, 3246, 3389, 3533, 3677, 3821, 3965, 4108, 4252, 4396
	},
	["WARLOCK"] = {
		90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90,
		90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90,
		90, 965, 965, 1022, 1022, 1022, 1022, 1022, 1022, 1022, 1022, 1022, 1022, 1022, 1022, 1022, 1022, 1022, 1022, 1522,
		1522, 1522, 1522, 1522, 1522, 1522, 1522, 1522, 1522, 2871, 2871, 2871, 2871, 2871, 2871, 2871, 2871, 2871, 2871, 3856
	},
};

local function UFL_UnitBaseMana(unit)
	local _, class = UnitClass(unit);
	local level = UnitLevel(unit);
	if ( not BaseMana[class] or level > 80 ) then
		return;
	end
	return BaseMana[class][level];
end

-- Spell cost data per class (percentages of base mana)
local DATACLASS_BY_ID = {
	["DRUID"] = {
		[48461] = { {type=0, name="MANA", cost=0.11, minCost=0.11, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48463] = { {type=0, name="MANA", cost=0.21, minCost=0.21, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[53308] = { {type=0, name="MANA", cost=0.07, minCost=0.07, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[33786] = { {type=0, name="MANA", cost=0.08, minCost=0.08, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48467] = { {type=0, name="MANA", cost=0.81, minCost=0.81, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[18658] = { {type=0, name="MANA", cost=0.07, minCost=0.07, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48465] = { {type=0, name="MANA", cost=0.16, minCost=0.16, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[26995] = { {type=0, name="MANA", cost=0.06, minCost=0.06, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48443] = { {type=0, name="MANA", cost=0.29, minCost=0.29, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[50464] = { {type=0, name="MANA", cost=0.18, minCost=0.18, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48447] = { {type=0, name="MANA", cost=0.7, minCost=0.7, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[50763] = { {type=0, name="MANA", cost=0.72, minCost=0.72, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
	},
	["HUNTER"] = {
		[49052] = { {type=0, name="MANA", cost=0.05, minCost=0.05, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[1002] = { {type=0, name="MANA", cost=0.01, minCost=0.01, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[14327] = { {type=0, name="MANA", cost=0.02, minCost=0.02, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[1515] = { {type=0, name="MANA", cost=0.48, minCost=0.48, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
	},
	["MAGE"] = {
		[42842] = { {type=0, name="MANA", cost=0.11, minCost=0.11, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[47610] = { {type=0, name="MANA", cost=0.14, minCost=0.14, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[42926] = { {type=0, name="MANA", cost=0.3, minCost=0.3, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[42859] = { {type=0, name="MANA", cost=0.08, minCost=0.08, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[58659] = { {type=0, name="MANA", cost=0.8, minCost=0.8, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[11420] = { {type=0, name="MANA", cost=0.18, minCost=0.18, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[53142] = { {type=0, name="MANA", cost=0.18, minCost=0.18, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[49361] = { {type=0, name="MANA", cost=0.18, minCost=0.18, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[32267] = { {type=0, name="MANA", cost=0.18, minCost=0.18, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[11417] = { {type=0, name="MANA", cost=0.18, minCost=0.18, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[11418] = { {type=0, name="MANA", cost=0.18, minCost=0.18, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[35717] = { {type=0, name="MANA", cost=0.18, minCost=0.18, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[12826] = { {type=0, name="MANA", cost=0.07, minCost=0.07, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[27090] = { {type=0, name="MANA", cost=0.4, minCost=0.4, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[33717] = { {type=0, name="MANA", cost=0.4, minCost=0.4, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[42985] = { {type=0, name="MANA", cost=0.75, minCost=0.75, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[42956] = { {type=0, name="MANA", cost=0.4, minCost=0.4, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[3566] = { {type=0, name="MANA", cost=0.08, minCost=0.08, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[53140] = { {type=0, name="MANA", cost=0.08, minCost=0.08, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[49358] = { {type=0, name="MANA", cost=0.08, minCost=0.08, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[32272] = { {type=0, name="MANA", cost=0.08, minCost=0.08, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[3567] = { {type=0, name="MANA", cost=0.08, minCost=0.08, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[3563] = { {type=0, name="MANA", cost=0.08, minCost=0.08, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[35715] = { {type=0, name="MANA", cost=0.08, minCost=0.08, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[42897] = { {type=0, name="MANA", cost=0.07, minCost=0.07, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
	},
	["PALADIN"] = {
		[10326] = { {type=0, name="MANA", cost=0.09, minCost=0.09, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48785] = { {type=0, name="MANA", cost=0.07, minCost=0.07, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48782] = { {type=0, name="MANA", cost=0.29, minCost=0.29, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48801] = { {type=0, name="MANA", cost=0.08, minCost=0.08, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48950] = { {type=0, name="MANA", cost=0.64, minCost=0.64, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
	},
	["PRIEST"] = {
		[10955] = { {type=0, name="MANA", cost=0.9, minCost=0.9, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[32375] = { {type=0, name="MANA", cost=0.33, minCost=0.33, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[8129] = { {type=0, name="MANA", cost=0.14, minCost=0.14, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[64843] = { {type=0, name="MANA", cost=0.63, minCost=0.63, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48071] = { {type=0, name="MANA", cost=0.18, minCost=0.18, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[6064] = { {type=0, name="MANA", cost=0.32, minCost=0.32, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48123] = { {type=0, name="MANA", cost=0.15, minCost=0.15, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48063] = { {type=0, name="MANA", cost=0.32, minCost=0.32, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48171] = { {type=0, name="MANA", cost=0.6, minCost=0.6, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[2053] = { {type=0, name="MANA", cost=0.27, minCost=0.27, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48072] = { {type=0, name="MANA", cost=0.48, minCost=0.48, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48120] = { {type=0, name="MANA", cost=0.27, minCost=0.27, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48135] = { {type=0, name="MANA", cost=0.11, minCost=0.11, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[53023] = { {type=0, name="MANA", cost=0.28, minCost=0.28, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48127] = { {type=0, name="MANA", cost=0.17, minCost=0.17, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[605] = { {type=0, name="MANA", cost=0.12, minCost=0.12, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[34914] = { {type=0, name="MANA", cost=0.16, minCost=0.16, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
	},
	["SHAMAN"] = {
		[49273] = { {type=0, name="MANA", cost=0.25, minCost=0.25, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[49277] = { {type=0, name="MANA", cost=0.72, minCost=0.72, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[49276] = { {type=0, name="MANA", cost=0.15, minCost=0.15, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[55459] = { {type=0, name="MANA", cost=0.19, minCost=0.19, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[556] = { {type=0, name="MANA", cost=0.05, minCost=0.05, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[6196] = { {type=0, name="MANA", cost=0.03, minCost=0.03, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[60043] = { {type=0, name="MANA", cost=0.1, minCost=0.1, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[49238] = { {type=0, name="MANA", cost=0.1, minCost=0.1, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[49271] = { {type=0, name="MANA", cost=0.26, minCost=0.26, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[51514] = { {type=0, name="MANA", cost=0.03, minCost=0.03, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
	},
	["WARLOCK"] = {
		[18647] = { {type=0, name="MANA", cost=0.08, minCost=0.08, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48018] = { {type=0, name="MANA", cost=0.15, minCost=0.15, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[126] = { {type=0, name="MANA", cost=0.04, minCost=0.04, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[61191] = { {type=0, name="MANA", cost=0.27, minCost=0.27, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[688] = { {type=0, name="MANA", cost=0.64, minCost=0.64, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[697] = { {type=0, name="MANA", cost=0.8, minCost=0.8, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[47878] = { {type=0, name="MANA", cost=0.53, minCost=0.53, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[60220] = { {type=0, name="MANA", cost=0.54, minCost=0.54, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[58887] = { {type=0, name="MANA", cost=0.8, minCost=0.8, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[47888] = { {type=0, name="MANA", cost=0.45, minCost=0.45, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[47884] = { {type=0, name="MANA", cost=0.68, minCost=0.68, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[17928] = { {type=0, name="MANA", cost=0.08, minCost=0.08, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[47836] = { {type=0, name="MANA", cost=0.34, minCost=0.34, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[6215] = { {type=0, name="MANA", cost=0.12, minCost=0.12, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[47825] = { {type=0, name="MANA", cost=0.09, minCost=0.09, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[47815] = { {type=0, name="MANA", cost=0.08, minCost=0.08, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[47827] = { {type=0, name="MANA", cost=0.2, minCost=0.2, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[47811] = { {type=0, name="MANA", cost=0.17, minCost=0.17, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[47838] = { {type=0, name="MANA", cost=0.14, minCost=0.14, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[47809] = { {type=0, name="MANA", cost=0.17, minCost=0.17, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[59172] = { {type=0, name="MANA", cost=0.07, minCost=0.07, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[48181] = { {type=0, name="MANA", cost=0.12, minCost=0.12, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
		[30108] = { {type=0, name="MANA", cost=0.15, minCost=0.15, costPercent=0, costPerSec=0, hasRequiredAura=false, requiredAuraID=0} },
	},
};

-- GetSpellInfo returns nil for IDs absent from the client's DBC; a nil key here would abort the whole chunk.
local DATACLASS = {};
for class, spells in pairs(DATACLASS_BY_ID) do
	local byName = {};
	for spellID, costTable in pairs(spells) do
		local spellName = GetSpellInfo(spellID);
		if spellName and spellName ~= "" then
			byName[spellName] = costTable;
		end
	end
	DATACLASS[class] = byName;
end

local SPCTable = {};

local function initialization_CostTable()
	local _, class = UnitClass("player");
	local baseMana = UFL_UnitBaseMana("player") or 1;
	if ( not DATACLASS[class] ) then return end
	for spellName, costTable in pairs(DATACLASS[class]) do
		for key, costInfo in pairs(costTable) do
			SPCTable[spellName] = SPCTable[spellName] or {};
			SPCTable[spellName][key] = {
				type = costInfo.type,
				name = costInfo.name,
				cost = costInfo.cost * baseMana,
				minCost = costInfo.minCost * baseMana,
				costPercent = costInfo.costPercent,
				hasRequiredAura = costInfo.hasRequiredAura,
				requiredAuraID = costInfo.requiredAuraID,
			};
		end
	end
end

initialization_CostTable();

-- Scoped GetSpellPowerCost (not global)
local function UFL_GetSpellPowerCost(spellName)
	return SPCTable[spellName] or {};
end

addon.UFL_GetSpellPowerCost = UFL_GetSpellPowerCost;

-- Best-effort cost lookup for non-player units (e.g. target) using the same
-- static class spell tables, scaled by that unit's base mana.
local function UFL_GetSpellPowerCostForUnit(spellName, unit)
	if not spellName or not unit then
		return {};
	end

	local _, class = UnitClass(unit);
	local level = UnitLevel(unit);
	if not class or not DATACLASS[class] or not level or level < 1 then
		return {};
	end
	if level > 80 then
		level = 80;
	end

	local classSpells = DATACLASS[class];
	local rawCostTable = classSpells and classSpells[spellName];
	if not rawCostTable then
		return {};
	end

	local baseMana = BaseMana[class] and BaseMana[class][level];
	if not baseMana or baseMana <= 0 then
		return {};
	end

	local scaled = {};
	for key, costInfo in pairs(rawCostTable) do
		scaled[key] = {
			type = costInfo.type,
			name = costInfo.name,
			cost = (costInfo.cost or 0) * baseMana,
			minCost = (costInfo.minCost or 0) * baseMana,
			costPercent = costInfo.costPercent,
			hasRequiredAura = costInfo.hasRequiredAura,
			requiredAuraID = costInfo.requiredAuraID,
		};
	end

	return scaled;
end

addon.UFL_GetSpellPowerCostForUnit = UFL_GetSpellPowerCostForUnit;

local SPCHandler = CreateFrame("Frame");
SPCHandler:RegisterEvent("PLAYER_LEVEL_UP");
SPCHandler:SetScript("OnEvent", function()
	initialization_CostTable();
end);

-- ============================================================================
-- ANIMATED HEALTH LOSS MIXIN (from AnimatedHealthLossMixin.lua)
-- ============================================================================

DragonUI_AnimatedHealthLossMixin = {};

function DragonUI_AnimatedHealthLossMixin:OnLoad()
	self:SetStatusBarColor(1, 0, 0, 1);
	self:SetDuration(.25);
	self:SetStartDelay(.1);
	self:SetPauseDelay(.05);
	self:SetPostponeDelay(.05);
end

function DragonUI_AnimatedHealthLossMixin:SetDuration(duration)
	self.animationDuration = duration or 0;
end

function DragonUI_AnimatedHealthLossMixin:SetStartDelay(delay)
	self.animationStartDelay = delay or 0;
end

function DragonUI_AnimatedHealthLossMixin:SetPauseDelay(delay)
	self.animationPauseDelay = delay or 0;
end

function DragonUI_AnimatedHealthLossMixin:SetPostponeDelay(delay)
	self.animationPostponeDelay = delay or 0;
end

function DragonUI_AnimatedHealthLossMixin:SetUnitHealthBar(unit, healthBar)
	if self.unit ~= unit then
		healthBar.AnimatedLossBar = self;
		self.unit = unit;
		self:SetAllPoints(healthBar);
		self:UpdateHealthMinMax();
	end
end

function DragonUI_AnimatedHealthLossMixin:UpdateHealthMinMax()
	local maxValue = UnitHealthMax(self.unit);
	self:SetMinMaxValues(0, maxValue);
end

function DragonUI_AnimatedHealthLossMixin:GetHealthLossAnimationData(currentHealth, previousHealth)
	if self.animationStartTime then
		local totalElapsedTime = GetTime() - self.animationStartTime;
		if totalElapsedTime > 0 then
			local animCompletePercent = totalElapsedTime / self.animationDuration;
			if animCompletePercent < 1 and previousHealth > currentHealth then
				local healthDelta = previousHealth - currentHealth;
				local animatedLossAmount = previousHealth - (animCompletePercent * healthDelta);
				return animatedLossAmount, animCompletePercent;
			end
		else
			return previousHealth, 0;
		end
	end
	return 0, 1;
end

function DragonUI_AnimatedHealthLossMixin:CancelAnimation()
	self:Hide();
	self.animationStartTime = nil;
	self.animationCompletePercent = nil;
end

function DragonUI_AnimatedHealthLossMixin:BeginAnimation(value)
	self.animationStartValue = value;
	self.animationStartTime = GetTime() + self.animationStartDelay;
	self.animationCompletePercent = 0;
	self:Show();
	self:SetValue(self.animationStartValue);
end

function DragonUI_AnimatedHealthLossMixin:PostponeStartTime()
	self.animationStartTime = self.animationStartTime + self.animationPostponeDelay;
end

function DragonUI_AnimatedHealthLossMixin:UpdateHealth(currentHealth, previousHealth)
	local delta = currentHealth - previousHealth;
	local hasLoss = delta < 0;
	local hasBegun = self.animationStartTime ~= nil;
	local isAnimating = hasBegun and self.animationCompletePercent > 0;
	if hasLoss and not hasBegun then
		self:BeginAnimation(previousHealth);
	elseif hasLoss and hasBegun and not isAnimating then
		self:PostponeStartTime();
	elseif hasLoss and isAnimating then
		self.animationStartValue = self:GetHealthLossAnimationData(previousHealth, self.animationStartValue);
		self.animationStartTime = GetTime() + self.animationPauseDelay;
	elseif not hasLoss and hasBegun and currentHealth >= self.animationStartValue then
		self:CancelAnimation();
	end
end

function DragonUI_AnimatedHealthLossMixin:UpdateLossAnimation(currentHealth)
	local totalAbsorb = addon.UFL_UnitGetTotalAbsorbs and addon.UFL_UnitGetTotalAbsorbs(self.unit) or 0;
	if totalAbsorb > 0 then
		self:CancelAnimation();
	end
	if self.animationStartTime then
		local animationValue, animationCompletePercent = self:GetHealthLossAnimationData(currentHealth, self.animationStartValue);
		self.animationCompletePercent = animationCompletePercent;
		if animationCompletePercent >= 1 then
			self:CancelAnimation();
		else
			self:SetValue(animationValue);
		end
	end
end

-- ============================================================================
-- BUILDER/SPENDER MIXIN (from BuilderSpenderFrame.lua)
-- ============================================================================

DragonUI_BuilderSpender = {};

function DragonUI_BuilderSpender:OnLoad()
	self.initialized = false;
end

function DragonUI_BuilderSpender:Initialize(textureInfo, unit, powerType)
	if (textureInfo.atlas) then
		self.BarTexture:SetAtlas(textureInfo.atlas, false);
	else
		self.BarTexture:SetVertexColor(textureInfo.r, textureInfo.g, textureInfo.b);
	end
	local height = self:GetHeight();
	self.BarTexture:SetHeight(height);
	self.LossGlowTexture:SetHeight(height);
	self.GainGlowTexture:SetHeight(height);
	self.unit = unit;
	self.powerType = powerType;
	self.maxValue = UnitPowerMax(unit, powerType);
	self.initialized = true;
end

local function BuilderSpender_OnUpdateFeedbackGain(self)
	local timeEnd = 0.5;
	local timeElapsed = GetTime() - self.animGainStartTime;
	if ( timeElapsed > timeEnd ) then
		self:EndFeedbackGain();
	else
		local currValue = UnitPower(self.unit, self.powerType);
		if ( currValue > self.newValue ) then
			self.newValue = currValue;
		end
		local timeElapsedPercent = timeElapsed / timeEnd;
		local currentValue = self.oldValue + (self.newValue - self.oldValue) * timeElapsedPercent;
		local maxValue = self.maxValue;
		if maxValue <= 0 then maxValue = 1 end
		local leftPosition = currentValue / maxValue * self:GetParent():GetWidth();
		local width = (self.newValue - currentValue) / maxValue * self:GetWidth();
		if (width < 0.5) then
			self.GainGlowTexture:Hide();
			self.updatingGain = false;
			return;
		end
		local texMinX = Clamp(currentValue / maxValue, 0, 1.0);
		local texMaxX = Clamp(self.newValue / maxValue, 0, 1.0);
		self.GainGlowTexture:ClearAllPoints();
		self.GainGlowTexture:SetPoint("TOPLEFT", leftPosition, 0);
		self.GainGlowTexture:SetHeight(self:GetHeight());
		self.GainGlowTexture:SetWidth(width);
		self.GainGlowTexture:SetTexCoord(texMinX, texMaxX, 0, 1);
		self.GainGlowTexture:Show();
	end
end

local function BuilderSpender_OnUpdateFeedbackLoss(self)
	local timeGlowFade = 0.25;
	local timeBarFade = 0.4;
	local timeEnd = 0.6;
	local timeElapsed = GetTime() - self.animLossStartTime;
	if ( timeElapsed > timeEnd ) then
		self:EndFeedbackLoss();
	else
		local glowAlpha, barAlpha;
		if ( timeElapsed < timeGlowFade ) then
			glowAlpha = Lerp(0, 0.75, timeElapsed / timeGlowFade);
		else
			glowAlpha = Lerp(0.75, 0, (timeElapsed - timeGlowFade) / (timeEnd - timeGlowFade));
		end
		self.LossGlowTexture:SetAlpha(glowAlpha);
		if ( timeElapsed < timeBarFade ) then
			barAlpha = 1;
		else
			barAlpha = Lerp(1, 0, (timeElapsed - timeBarFade) / (timeEnd - timeBarFade));
		end
		self.BarTexture:SetAlpha(barAlpha);
	end
end

local function BuilderSpender_OnUpdateFeedback(self)
	if ( self.updatingGain ) then
		BuilderSpender_OnUpdateFeedbackGain(self);
	end
	if ( self.updatingLoss ) then
		BuilderSpender_OnUpdateFeedbackLoss(self);
	end
	if ( not self.updatingGain and not self.updatingLoss ) then
		self:SetScript("OnUpdate", nil);
	end
end

function DragonUI_BuilderSpender:EndFeedbackGain()
	self.GainGlowTexture:Hide();
	self.updatingGain = false;
end

function DragonUI_BuilderSpender:EndFeedbackLoss()
	self.LossGlowTexture:Hide();
	self.BarTexture:Hide();
	self.updatingLoss = false;
end

function DragonUI_BuilderSpender:StartFeedbackAnim(oldValue, newValue)
	if (not self.initialized) then return end
	oldValue = Clamp(oldValue, 0, self.maxValue);
	newValue = math.max(newValue, 0);
	if ( newValue > oldValue ) then -- Gaining power
		self.updatingGain = true;
		self:SetScript("OnUpdate", BuilderSpender_OnUpdateFeedback);
		self.oldValue = oldValue;
		self.newValue = newValue;
		self.animGainStartTime = GetTime();
	elseif ( newValue < oldValue ) then -- Losing power
		local glowTexture = self.LossGlowTexture;
		local barTexture = self.BarTexture;
		local maxValue = self.maxValue;
		local leftPosition = newValue / maxValue * self:GetWidth();
		local width = (oldValue - newValue) / maxValue * self:GetWidth();
		local texMinX = newValue / maxValue;
		local texMaxX = oldValue / maxValue;
		local height = self:GetHeight();
		glowTexture:ClearAllPoints();
		glowTexture:SetPoint("TOPLEFT", leftPosition, 0);
		glowTexture:SetHeight(height);
		glowTexture:SetWidth(width);
		glowTexture:SetTexCoord(texMinX, texMaxX, 0, 1);
		glowTexture:Show();
		glowTexture:SetAlpha(0);
		barTexture:ClearAllPoints();
		barTexture:SetPoint("TOPLEFT", leftPosition, 0);
		barTexture:SetHeight(height);
		barTexture:SetWidth(width);
		barTexture:SetTexCoord(texMinX, texMaxX, 0, 1);
		barTexture:Show();
		barTexture:SetAlpha(1);
		self.updatingLoss = true;
		self:SetScript("OnUpdate", BuilderSpender_OnUpdateFeedback);
		self.animLossStartTime = GetTime();
	end
end

function DragonUI_BuilderSpender:StopFeedbackAnim()
	if self.updatingGain then
		self:EndFeedbackGain();
	elseif self.updatingLoss then
		self:EndFeedbackLoss();
	end
end

-- ============================================================================
-- FULL RESOURCE PULSE (from BuilderSpenderFrame.lua)
-- ============================================================================

DragonUI_FullResourcePulse = {};

function DragonUI_FullResourcePulse:Initialize(active)
	self.active = active;
	if ( active ) then
		self:RegisterEvent("PLAYER_REGEN_ENABLED");
		self:SetScript("OnEvent", function(s, event)
			if ( event == "PLAYER_REGEN_ENABLED" ) then
				if ( s.SpikeFrame.SpikeAnim:IsPlaying() or s.PulseFrame.PulseAnim:IsPlaying() ) then
					if s.FadeoutAnim then s.FadeoutAnim:Play() end
				end
			end
		end);
	else
		self:UnregisterEvent("PLAYER_REGEN_ENABLED");
		self:SetScript("OnEvent", nil);
	end
end

function DragonUI_FullResourcePulse:SetMaxValue(maxValue)
	self.maxValue = maxValue;
end

function DragonUI_FullResourcePulse:StartAnimIfFull(oldValue, newValue)
	if ( newValue == self.maxValue and UnitAffectingCombat("player") ) then
		if ( (self.FadeoutAnim and self.FadeoutAnim:IsPlaying()) or not self.PulseFrame.PulseAnim:IsPlaying() ) then
			self.SpikeFrame.BigSpikeGlow:SetAlpha(1);
			self.SpikeFrame.AlertSpikeStay:SetAlpha(1);
			self.SpikeFrame.BigSpikeGlow:Show();
			self.SpikeFrame.AlertSpikeStay:Show();
			self.SpikeFrame.SpikeAnim:Play();
		end
		if self.FadeoutAnim then self.FadeoutAnim:Stop() end
		self:SetAlpha(1);
		self.PulseFrame.PulseAnim:Play();
	elseif ( oldValue == self.maxValue and (self.PulseFrame.PulseAnim:IsPlaying() or self.SpikeFrame.SpikeAnim:IsPlaying()) ) then
		if self.FadeoutAnim then self.FadeoutAnim:Play() end
	end
end

function DragonUI_FullResourcePulse:RemoveAnims()
	self:SetAlpha(0);
	self.PulseFrame.PulseAnim:Stop();
	self.SpikeFrame.SpikeAnim:Stop();
end
