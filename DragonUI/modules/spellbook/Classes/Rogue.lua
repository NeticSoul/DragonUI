
local backstab =		{53,2589,2590,2591,8721,11279,11280,11281,25300,26863,48656,48657}
local kidneyShot =		{408,8643}
local garrote =			{703,8631,8632,8633,11289,11290,26839,26884,48675,48676}
local sinisterStrike =	{1752,1757,1758,1759,1760,8621,11293,11294,26861,26862,48637,48638}
local vanish =			{1856,1857,26889}
local rupture =			{1943,8639,8640,11273,11274,11275,26867,48671,48672}
local feint =			{1966,6768,8637,11303,25302,27448,48658,48659}
local sap =				{6770,2070,11297,51724}
local eviscerate =		{2098,6760,6761,6762,8623,8624,11299,11300,31016,26865,48667,48668}
local sprint =			{2983,8696,11305}
local sliceandDice =	{5171,6774}
local evasion =			{5277,26669}
local ambush =			{8676,8724,8725,11267,11268,11269,27441,48689,48690,48691}
local envenom =			{32645,32684,57992,57993}
local mutilate =		{1329,34411,34412,34413,48663,48666}

AddOverriddenSpells(backstab,kidneyShot,garrote,sinisterStrike,vanish,rupture,feint,sap,eviscerate,sprint,sliceandDice,evasion,ambush,envenom,mutilate)

SpellsByLevel = {
	[1] =	{
				{id =  1784, cost =     10},													--Stealth
			},
	[4] =	{
				{id =    53, cost =    100},													-- Backstab (rank 1)
				{id =   921, cost =    100},													-- Pick Pocket
			},
	[6] =	{
				{id =  1776, cost =    100},													-- Gouge
				{id =  1757, cost =    100, requiredIds = {1752}},								-- Sinister Strike (rank 2)
			},
	[8] =	{
				{id =  5277, cost =    200},													-- Evasion (rank 1)
				{id =  6760, cost =    200, requiredIds = {2098}},								-- Eviscerate (rank 2)
			},
	[10] =	{
				{id =  6770, cost =    300},													-- Sap (rank 1)
				{id =  5171, cost =    300},													-- Slice and Dice (rank 1)
				{id =  2983, cost =    300},													-- Sprint (rank 1)
			},
	[12] =	{
				{id =  2589, cost =    800, requiredIds = {53}},								-- Backstab (rank 2)
				{id =  1766, cost =    800},													-- Kick
				{id =  3127, cost =    800},													-- Parry
			},
	[14] =	{
				{id =  8647, cost =   1200},													-- Expose Armor
				{id =   703, cost =   1200},													-- Garrote (rank 1)
				{id =  1758, cost =   1200, requiredIds = {1757}},								-- Sinister Strike (rank 3)
			},
	[16] =	{
				{id =  6761, cost =   1800, requiredIds = {6760}},								-- Eviscerate (rank 3)
				{id =  1966, cost =   1800},													-- Feint (rank 1)
				{id =  1804, cost =   1800},													-- Pick Lock
			},
	[18] =	{
				{id =  8676, cost =   2900},													-- Ambush (rank 1)
			},
	[20] =	{
				{id =  2590, cost =   3000, requiredIds = {2589}},								-- Backstab (rank 3)
				{id = 51722, cost =   3000},													-- Dismantle
				{id =  1943, cost =   3000},													-- Rupture (rank 1)
			},
	[22] =	{
				{id =  1725, cost =   4000},													-- Distract
				{id =  8631, cost =   4000, requiredIds = {703}},								-- Garrote (rank 2)
				{id =  1759, cost =   4000, requiredIds = {1758}},								-- Sinister Strike (rank 4)
				{id =  1856, cost =   4000, requiredIds = {1784}},								-- Vanish (rank 1)
			},
	[24] =	{
				{id =  2836, cost =   5000},													-- Detect Traps
				{id =  6762, cost =   5000, requiredIds = {6761}},								-- Eviscerate (rank 4)
			},
	[26] =	{
				{id =  8724, cost =   6000, requiredIds = {8676}},								-- Ambush (rank 2)
				{id =  1833, cost =   6000},													-- Cheap Shot
			},
	[28] =	{
				{id =  2591, cost =   8000, requiredIds = {2590}},								-- Backstab (rank 4)
				{id =  6768, cost =   8000, requiredIds = {1966}},								-- Feint (rank 2)
				{id =  8639, cost =   8000, requiredIds = {1943}},								-- Rupture (rank 2)
				{id =  2070, cost =   8000, requiredIds = {6770}},								-- Sap (rank 2)
			},
	[30] =	{
				{id =  1842, cost =  10000, requiredIds = {2836}},								-- Disarm Trap
				{id =  8632, cost =  10000, requiredIds = {8631}},								-- Garrote (rank 3)
				{id =   408, cost =  10000},													-- Kidney Shot (rank 1)
				{id =  1760, cost =  10000, requiredIds = {1759}},								-- Sinister Strike (rank 5)
			},
	[32] =	{
				{id =  8623, cost =  12000, requiredIds = {6762}},								-- Eviscerate (rank 5)
			},
	[34] =	{
				{id =  8725, cost =  14000, requiredIds = {8724}},								-- Ambush (rank 3)
				{id =  2094, cost =  14000},													-- Blind
				{id =  8696, cost =  14000, requiredIds = {2983}},								-- Sprint (rank 2)
			},
	[36] =	{
				{id =  8721, cost =  16000, requiredIds = {2591}},								-- Backstab (rank 5)
				{id =  8640, cost =  16000, requiredIds = {8639}},								-- Rupture (rank 3)
			},
	[38] =	{
				{id =  8633, cost =  18000, requiredIds = {8632}},								-- Garrote (rank 4)
				{id =  8621, cost =  18000, requiredIds = {1760}},								-- Sinister Strike (rank 6)
			},
	[40] =	{
				{id =  8624, cost =  20000, requiredIds = {8623}},								-- Eviscerate (rank 6)
				{id =  8637, cost =  20000, requiredIds = {6768}},								-- Feint (rank 3)
				{id =  1860, cost =  20000},													-- Safe Fall
			},
	[42] =	{
				{id = 11267, cost =  27000, requiredIds = {8725}},								-- Ambush (rank 4)
				{id =  6774, cost =  27000, requiredIds = {5171}},								-- Slice and Dice (rank 2)
				{id =  1857, cost =  27000, requiredIds = {1856}},								-- Vanish (rank 2)
			},
	[44] =	{
				{id = 11279, cost =  29000, requiredIds = {8721}},								-- Backstab (rank 6)
				{id = 11273, cost =  29000, requiredIds = {8640}},								-- Rupture (rank 4)
			},
	[46] =	{
				{id = 11289, cost =  31000, requiredIds = {8633}},								-- Garrote (rank 5)
				{id = 17347, cost =    384, requiredIds = {16511}, requiredTalentId = 16511},	-- Hemorrhage (rank 2)
				{id = 11293, cost =  31000, requiredIds = {8621}},								-- Sinister Strike (rank 7)
			},
	[48] =	{
				{id = 11299, cost =  33000, requiredIds = {8624}},								-- Eviscerate (rank 7)
				{id = 11297, cost =  33000, requiredIds = {2070}},								-- Sap (rank 3)
			},
	[50] =	{
				{id = 11268, cost =  35000, requiredIds = {11267}},								-- Ambush (rank 5)
				{id = 26669, cost =  35000, requiredIds = {5277}},								-- Evasion (rank 2)
				{id =  8643, cost =  35000, requiredIds = {408}},								-- Kidney Shot (rank 2)
				{id = 34411, cost =   5500, requiredIds = {1329}, requiredTalentId = 1329},		-- Mutilate (rank 2)
			},
	[52] =	{
				{id = 11280, cost =  46000, requiredIds = {11279}},								-- Backstab (rank 7)
				{id = 11303, cost =  46000, requiredIds = {8637}},								-- Feint (rank 4)
				{id = 11274, cost =  46000, requiredIds = {11273}},								-- Rupture (rank 5)
			},
	[54] =	{
				{id = 11290, cost =  48000, requiredIds = {11289}},								-- Garrote (rank 6)
				{id = 11294, cost =  48000, requiredIds = {11293}},								-- Sinister Strike (rank 8)
			},
	[56] =	{
				{id = 11300, cost =  50000, requiredIds = {11299}},								-- Eviscerate (rank 8)
			},
	[58] =	{
				{id = 11269, cost =  52000, requiredIds = {11268}},								-- Ambush (rank 6)
				{id = 17348, cost =    650, requiredIds = {17347}, requiredTalentId = 16511},	-- Hemorrhage (rank 3)
				{id = 11305, cost =  52000, requiredIds = {8696}},								-- Sprint (rank 3)
			},
	[60] =	{
				{id = 11281, cost =  54000, requiredIds = {11280}},								-- Backstab (rank 8)
				{id = 25300, cost =  72000, requiredIds = {11281}},								-- Backstab (rank 9)
				{id = 31016, cost =  65000, requiredIds = {11300}},								-- Eviscerate (rank 9)
				{id = 25302, cost =  50000, requiredIds = {11303}},								-- Feint (rank 5)
				{id = 34412, cost =   6500, requiredIds = {34411}, requiredTalentId = 1329},	-- Mutilate (rank 3)
				{id = 11275, cost =  54000, requiredIds = {11274}},								-- Rupture (rank 6)
			},
	[61] =	{
				{id = 26839, cost =  50000, requiredIds = {11290}},								-- Garrote (rank 7)
			},
	[62] =	{
				{id = 32645, cost =  59000},													-- Envenom (rank 1)
				{id = 26861, cost =  50000, requiredIds = {11294}},								-- Sinister Strike (rank 9)
				{id = 26889, cost =  59000, requiredIds = {1857}},								-- Vanish (rank 3)
			},
	[64] =	{
				{id = 26679, cost =  72000},													-- Deadly Throw (rank 1)
				{id = 26865, cost = 140000, requiredIds = {31016}},								-- Eviscerate (rank 10)
				{id = 27448, cost =  72000, requiredIds = {25302}},								-- Feint (rank 6)
			},
	[66] =	{
				{id = 27441, cost =  80000, requiredIds = {11269}},								-- Ambush (rank 7)
				{id = 31224, cost =  89000},													-- Cloak of Shadows
			},
	[68] =	{
				{id = 26863, cost = 110000, requiredIds = {25300}},								-- Backstab (rank 10)
				{id = 26867, cost = 120000, requiredIds = {11275}},								-- Rupture (rank 7)
			},
	[69] =	{
				{id = 32684, cost = 100000, requiredIds = {32645}},								-- Envenom (rank 2)
			},
	[70] =	{
				{id = 48689, cost = 140000, requiredIds = {27441}},								-- Ambush (rank 8)
				{id = 48673, cost = 100000, requiredIds = {26679}},								-- Deadly Throw (rank 2)
				{id = 26884, cost = 100000, requiredIds = {26839}},								-- Garrote (rank 8)
				{id = 26864, cost =   2700, requiredIds = {17348}, requiredTalentId = 16511},	-- Hemorrhage (rank 4)
				{id = 34413, cost =   7500, requiredIds = {34412}, requiredTalentId = 1329},	-- Mutilate (rank 4)
				{id =  5938, cost = 100000},													-- Shiv
				{id = 26862, cost = 100000, requiredIds = {26861}},								-- Sinister Strike (rank 10)
			},
	[71] =	{
				{id = 51724, cost = 300000, requiredIds = {11297}},								-- Sap (rank 4)
			},
	[72] =	{
				{id = 48658, cost = 300000, requiredIds = {27448}},								-- Feint (rank 7)
			},
	[73] =	{
				{id = 48667, cost = 300000, requiredIds = {26865}},								-- Eviscerate (rank 11)
			},
	[74] =	{
				{id = 48656, cost = 300000, requiredIds = {26863}},								-- Backstab (rank 11)
				{id = 57992, cost = 300000, requiredIds = {32684}},								-- Envenom (rank 3)
				{id = 48671, cost = 300000, requiredIds = {26867}},								-- Rupture (rank 8)
			},
	[75] =	{
				{id = 48690, cost = 300000, requiredIds = {48689}},								-- Ambush (rank 9)
				{id = 48675, cost = 300000, requiredIds = {26884}},								-- Garrote (rank 9)
				{id = 48663, cost =  15000, requiredIds = {34413}, requiredTalentId = 1329},	-- Mutilate (rank 5)
				{id = 57934, cost = 300000},													-- Tricks of the Trade
			},
	[76] =	{
				{id = 48674, cost = 300000, requiredIds = {48673}},								-- Deadly Throw (rank 3)
				{id = 48637, cost = 300000, requiredIds = {26862}},								-- Sinister Strike (rank 11)
			},
	[78] =	{
				{id = 48659, cost = 300000, requiredIds = {48658}},								-- Feint (rank 8)
			},
	[79] =	{
				{id = 48668, cost = 300000, requiredIds = {48667}},								-- Eviscerate (rank 12)
				{id = 48672, cost = 300000, requiredIds = {48671}},								-- Rupture (rank 9)
			},
	[80] =	{
				{id = 48691, cost = 300000, requiredIds = {48690}},								-- Ambush (rank 10)
				{id = 48657, cost = 300000, requiredIds = {48656}},								-- Backstab (rank 12)
				{id = 57993, cost = 300000, requiredIds = {57992}},								-- Envenom (rank 4)
				{id = 51723, cost = 300000},													-- Fan of Knives
				{id = 48676, cost = 300000, requiredIds = {48675}},								-- Garrote (rank 10)
				{id = 48660, cost =  15000, requiredIds = {26864}, requiredTalentId = 16511},	-- Hemorrhage (rank 5)
				{id = 48666, cost =  15000, requiredIds = {48663}, requiredTalentId = 1329},	-- Mutilate (rank 6)
				{id = 48638, cost = 300000, requiredIds = {48637}},								-- Sinister Strike (rank 12)
			},
}
DragonUI_RegisterClassSpells("Rogue", SpellsByLevel)
