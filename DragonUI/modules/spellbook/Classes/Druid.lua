
local demoralizingRoar =		{99,1735,9490,9747,9898,26998,48559,48560}
local swipe =					{779,780,769,9754,9908,26997,48561,48562}
local rip =						{1079,9492,9493,9752,9894,9896,27008,49799,49800}
local claw =					{1082,3029,5201,9849,9850,27000,48569,48570}
local rake =					{1822,1823,1824,9904,27003,48573,48574}
local dash =					{1850,9821,33357}
local bash =					{5211,6798,8983}
local tigersFury =				{5217,6793,9845,9846,50212,502113}
local shred =					{5221,6800,8992,9829,9830,27001,27002,48571,48572}
local ravage =					{6785,6787,9866,9867,27005,48578,48579}
local maul =					{6807,6808,6809,8972,9745,9880,9881,26996,48479,48480}
local cower =					{8998,9000,9892,31709,27004,48575}
local pounce =					{9005,9823,9827,27006,49803}
local ferociousBite =			{22568,22827,22828,22829,31018,24248,48576,48577}
local mangleCat =				{33876,33982,33983,48565,48566}
local mangleBear =				{33878,33986,33987,48563,48564}

AddOverriddenSpells(demoralizingRoar,swipe,rip,claw,rake,dash,bash,tigersFury,shred,ravage,maul,cower,pounce,ferociousBite,mangleCat,mangleBear)

SpellsByLevel = {
	[1] =	{
				{id =  1126, cost =     10},													-- Mark of the Wild (rank 1)
			},
	[4] =	{
				{id =  8921, cost =    100},													-- Moonfire (rank 1)
				{id =   774, cost =    100},													-- Rejuvenation (rank 1)
			},
	[6] =	{
				{id =   467, cost =    100},													-- Thorns (rank 1)
				{id =  5177, cost =    100, requiredIds = {5176}},								-- Wrath (rank 2)
			},
	[8] =	{
				{id =   339, cost =    200},													-- Entangling Roots (rank 1)
				{id =  5186, cost =    200, requiredIds = {5185}},								-- Healing Touch (rank 2)
			},
	[10] =	{
				{id =    99, cost =    300, requiredIds = {5487}},								-- Demoralizing Roar (rank 1)
				{id =  5232, cost =    300, requiredIds = {1126}},								-- Mark of the Wild (rank 2)
				{id =  8924, cost =    300, requiredIds = {8921}},								-- Moonfire (rank 2)
				{id = 16689, cost =    300, requiredIds = {339}},								-- Nature's Grasp (rank 1)
				{id =  1058, cost =    300, requiredIds = {774}},								-- Rejuvenation (rank 2)
			},
	[12] =	{
				{id =  5229, cost =    800, requiredIds = {5487}},								-- Enrage
				{id =  8936, cost =    800},													-- Regrowth (rank 1)
				{id = 50769, cost =    800},													-- Revive (rank 1)
			},
	[14] =	{
				{id =  5211, cost =    900, requiredIds = {5487}},								-- Bash (rank 1)
				{id =  5187, cost =    900, requiredIds = {5186}},								-- Healing Touch (rank 3)
				{id =   782, cost =    900, requiredIds = {467}},								-- Thorns (rank 2)
				{id =  5178, cost =    900, requiredIds = {5177}},								-- Wrath (rank 3)
			},
	[16] =	{
				{id =  1066, cost =    900},													-- Aquatic Form
				{id =  8925, cost =   1800, requiredIds = {8924}},								-- Moonfire (rank 3)
				{id =  1430, cost =   1800, requiredIds = {1058}},								-- Rejuvenation (rank 3)
				{id =   779, cost =   1800, requiredIds = {5487}},								-- Swipe (Bear) (rank 1)
				{id =   783, cost =   6000},													-- Travel Form
			},
	[18] =	{
				{id =  1062, cost =   1900, requiredIds = {339}},								-- Entangling Roots (rank 2)
				{id =   770, cost =   1900},													-- Faerie Fire
				{id = 16857, cost =   1900},													-- Faerie Fire (Feral)
				{id =  2637, cost =   1900},													-- Hibernate (rank 1)
				{id =  6808, cost =   1900, requiredIds = {6807}},								-- Maul (rank 2)
				{id = 16810, cost =   1900, requiredIds = {16689,1062}},						-- Nature's Grasp (rank 2)
				{id =  8938, cost =   1900, requiredIds = {8936}},								-- Regrowth (rank 2)
			},
	[20] =	{
				{id =   768, cost =   2000},													-- Cat Form
				{id =  1082, cost =   2000, requiredIds = {768}},								-- Claw (rank 1)
				{id =  1735, cost =   2000, requiredIds = {99}},								-- Demoralizing Roar (rank 2)
				{id =  5188, cost =   2000, requiredIds = {5187}},								-- Healing Touch (rank 4)
				{id =  6756, cost =   2000, requiredIds = {5232}},								-- Mark of the Wild (rank 3)
				{id =  5215, cost =   2000, requiredIds = {768}},								-- Prowl
				{id = 20484, cost =   2000},													-- Rebirth (rank 1)
				{id =  1079, cost =   2000, requiredIds = {768}},								-- Rip (rank 1)
				{id =  2912, cost =   2000},													-- Starfire (rank 1)
			},
	[22] =	{
				{id =  8926, cost =   3000, requiredIds = {8925}},								-- Moonfire (rank 4)
				{id =  2090, cost =   3000, requiredIds = {1430}},								-- Rejuvenation (rank 4)
				{id =  5221, cost =   3000, requiredIds = {768}},								-- Shred (rank 1)
				{id =  2908, cost =   3000},													-- Soothe Animal (rank 1)
				{id =  5179, cost =   3000, requiredIds = {5178}},								-- Wrath (rank 4)
			},
	[24] =	{
				{id =  1822, cost =   4000, requiredIds = {768}},								-- Rake (rank 1)
				{id =  8939, cost =   4000, requiredIds = {8938}},								-- Regrowth (rank 3)
				{id =  2782, cost =   4000},													-- Remove Curse
				{id = 50768, cost =   4000, requiredIds = {50769}},								-- Revive (rank 2)
				{id =   780, cost =   4000, requiredIds = {779}},								-- Swipe (Bear) (rank 2)
				{id =  1075, cost =   4000, requiredIds = {782}},								-- Thorns (rank 3)
				{id =  5217, cost =   4000, requiredIds = {768}},								-- Tiger's Fury (rank 1)
			},
	[26] =	{
				{id =  2893, cost =   4500},													-- Abolish Poison
				{id =  1850, cost =   4500, requiredIds = {768}},								-- Dash (rank 1)
				{id =  5189, cost =   4500, requiredIds = {5188}},								-- Healing Touch (rank 5)
				{id =  6809, cost =   4500, requiredIds = {6808}},								-- Maul (rank 3)
				{id =  8949, cost =   4500, requiredIds = {2912}},								-- Starfire (rank 2)
			},
	[28] =	{
				{id =  5209, cost =   5000, requiredIds = {5487}},								-- Challenging Roar
				{id =  3029, cost =   5000, requiredIds = {1082}},								-- Claw (rank 2)
				{id =  8998, cost =   5000, requiredIds = {768}},								-- Cower (rank 1)
				{id =  5195, cost =   5000, requiredIds = {1062}},								-- Entangling Roots (rank 3)
				{id =  8927, cost =   5000, requiredIds = {8926}},								-- Moonfire (rank 5)
				{id = 16811, cost =   5000, requiredIds = {16810,5195}},						-- Nature's Grasp (rank 3)
				{id =  2091, cost =   5000, requiredIds = {2090}},								-- Rejuvenation (rank 5)
				{id =  9492, cost =   5000, requiredIds = {1079}},								-- Rip (rank 2)
			},
	[30] =	{
				{id =  6798, cost =   6000, requiredIds = {5211}},								-- Bash (rank 2)
				{id = 24974, cost =   6000, requiredIds = {5570}, requiredTalentId = 5570},		-- Insect Swarm (rank 2)
				{id =  5234, cost =   6000, requiredIds = {6756}},								-- Mark of the Wild (rank 4)
				{id = 20739, cost =   6000, requiredIds = {20484}},								-- Rebirth (rank 2)
				{id =  8940, cost =   6000, requiredIds = {8939}},								-- Regrowth (rank 4)
				{id =  6800, cost =   6000, requiredIds = {5221}},								-- Shred (rank 2)
				{id =   740, cost =   6000},													-- Tranquility (rank 1)
				{id =  5180, cost =   6000, requiredIds = {5179}},								-- Wrath (rank 5)
			},
	[32] =	{
				{id =  9490, cost =   8000, requiredIds = {1735}},								-- Demoralizing Roar (rank 3)
				{id = 22568, cost =   8000, requiredIds = {768}},								-- Ferocious Bite (rank 1)
				{id =  6778, cost =   8000, requiredIds = {5189}},								-- Healing Touch (rank 6)
				{id =  6785, cost =   8000, requiredIds = {768}},								-- Ravage (rank 1)
				{id =  5225, cost =   8000, requiredIds = {768}},								-- Track Humanoids
			},
	[34] =	{
				{id =  8972, cost =  10000, requiredIds = {6809}},								-- Maul (rank 4)
				{id =  8928, cost =  10000, requiredIds = {8927}},								-- Moonfire (rank 6)
				{id =  1823, cost =  10000, requiredIds = {1822}},								-- Rake (rank 2)
				{id =  3627, cost =  10000, requiredIds = {2091}},								-- Rejuvenation (rank 6)
				{id =  8950, cost =  10000, requiredIds = {8949}},								-- Starfire (rank 3)
				{id =   769, cost =  10000, requiredIds = {780}},								-- Swipe (Bear) (rank 3)
				{id =  8914, cost =  10000, requiredIds = {1075}},								-- Thorns (rank 4)
			},
	[36] =	{
				{id = 22842, cost =  11000, requiredIds = {5487}},								-- Frenzied Regeneration
				{id =  9005, cost =  11000, requiredIds = {768}},								-- Pounce (rank 1)
				{id =  8941, cost =  11000, requiredIds = {8940}},								-- Regrowth (rank 5)
				{id = 50767, cost =  11000, requiredIds = {50768}},								-- Revive (rank 3)
				{id =  9493, cost =  11000, requiredIds = {9492}},								-- Rip (rank 3)
				{id =  6793, cost =  11000, requiredIds = {5217}},								-- Tiger's Fury (rank 2)
			},
	[38] =	{
				{id =  5201, cost =  12000, requiredIds = {3029}},								-- Claw (rank 3)
				{id =  5196, cost =  12000, requiredIds = {5195}},								-- Entangling Roots (rank 4)
				{id =  8903, cost =  12000, requiredIds = {6778}},								-- Healing Touch (rank 7)
				{id = 18657, cost =  12000, requiredIds = {2637}},								-- Hibernate (rank 2)
				{id = 16812, cost =  12000, requiredIds = {16811,5196}},						-- Nature's Grasp (rank 4)
				{id =  8992, cost =  12000, requiredIds = {6800}},								-- Shred (rank 3)
				{id =  8955, cost =  12000, requiredIds = {2908}},								-- Soothe Animal (rank 2)
				{id =  6780, cost =  12000, requiredIds = {5180}},								-- Wrath (rank 6)
			},
	[40] =	{
				{id =  9000, cost =  14000, requiredIds = {8998}},								-- Cower (rank 2)
				{id =  9634, cost =  14000, requiredIds = {5487}},								-- Dire Bear Form
				{id = 20719, cost =  14000, requiredIds = {768}},								-- Feline Grace
				{id = 22827, cost =  14000, requiredIds = {22568}},								-- Ferocious Bite (rank 2)
				{id = 16914, cost =  14000},													-- Hurricane (rank 1)
				{id = 29166, cost =  14000},													-- Innervate
				{id = 24975, cost =  14000, requiredIds = {24974}, requiredTalentId = 5570},	-- Insect Swarm (rank 3)
				{id =  8907, cost =  14000, requiredIds = {5234}},								-- Mark of the Wild (rank 5)
				{id =  8929, cost =  14000, requiredIds = {8928}},								-- Moonfire (rank 7)
				{id = 20742, cost =  14000, requiredIds = {20739}},								-- Rebirth (rank 3)
				{id =  8910, cost =  14000, requiredIds = {3627}},								-- Rejuvenation (rank 7)
				{id = 62600, cost =   4500, requiredIds = {5487}},								-- Savage Defense
				{id =  8918, cost =  14000, requiredIds = {740}},								-- Tranquility (rank 2)
			},
	[42] =	{
				{id =  9747, cost =  16000, requiredIds = {9490}},								-- Demoralizing Roar (rank 4)
				{id =  9745, cost =  16000, requiredIds = {8972}},								-- Maul (rank 5)
				{id =  6787, cost =  16000, requiredIds = {6785}},								-- Ravage (rank 2)
				{id =  9750, cost =  16000, requiredIds = {8941}},								-- Regrowth (rank 6)
				{id =  8951, cost =  16000, requiredIds = {8950}},								-- Starfire (rank 4)
			},
	[44] =	{
				{id = 22812, cost =  18000},													-- Barkskin
				{id =  9758, cost =  18000, requiredIds = {8903}},								-- Healing Touch (rank 8)
				{id =  1824, cost =  18000, requiredIds = {1823}},								-- Rake (rank 3)
				{id =  9752, cost =  18000, requiredIds = {9493}},								-- Rip (rank 4)
				{id =  9754, cost =  18000, requiredIds = {769}},								-- Swipe (Bear) (rank 4)
				{id =  9756, cost =  18000, requiredIds = {8914}},								-- Thorns (rank 5)
			},
	[46] =	{
				{id =  8983, cost =  20000, requiredIds = {6798}},								-- Bash (rank 3)
				{id =  9821, cost =  20000, requiredIds = {1850}},								-- Dash (rank 2)
				{id =  9833, cost =  20000, requiredIds = {8929}},								-- Moonfire (rank 8)
				{id =  9823, cost =  20000, requiredIds = {9005}},								-- Pounce (rank 2)
				{id =  9839, cost =  20000, requiredIds = {8910}},								-- Rejuvenation (rank 8)
				{id =  9829, cost =  20000, requiredIds = {8992}},								-- Shred (rank 4)
				{id =  8905, cost =  20000, requiredIds = {6780}},								-- Wrath (rank 7)
			},
	[48] =	{
				{id =  9849, cost =  22000, requiredIds = {5201}},								-- Claw (rank 4)
				{id =  9852, cost =  22000, requiredIds = {5196}},								-- Entangling Roots (rank 5)
				{id = 22828, cost =  22000, requiredIds = {22827}},								-- Ferocious Bite (rank 3)
				{id = 16813, cost =  22000, requiredIds = {16812,9852}},						-- Nature's Grasp (rank 5)
				{id =  9856, cost =  22000, requiredIds = {9750}},								-- Regrowth (rank 7)
				{id = 50766, cost =  22000, requiredIds = {50767}},								-- Revive (rank 4)
				{id =  9845, cost =  22000, requiredIds = {6793}},								-- Tiger's Fury (rank 3)
			},
	[50] =	{
				{id = 21849, cost =  23000, requiredIds = {9884}},								-- Gift of the Wild (rank 1)
				{id =  9888, cost =  23000, requiredIds = {9758}},								-- Healing Touch (rank 9)
				{id = 17401, cost =  23000, requiredIds = {16914}},								-- Hurricane (rank 2)
				{id = 24976, cost =  12000, requiredIds = {24975}, requiredTalentId = 5570},	-- Insect Swarm (rank 4)
				{id =  9884, cost =  23000, requiredIds = {8907}},								-- Mark of the Wild (rank 6)
				{id =  9880, cost =  23000, requiredIds = {9745}},								-- Maul (rank 6)
				{id =  9866, cost =  23000, requiredIds = {6787}},								-- Ravage (rank 3)
				{id = 20747, cost =  23000, requiredIds = {20742}},								-- Rebirth (rank 4)
				{id =  9875, cost =  23000, requiredIds = {8951}},								-- Starfire (rank 5)
				{id =  9862, cost =  23000, requiredIds = {8918}},								-- Tranquility (rank 3)
			},
	[52] =	{
				{id =  9892, cost =  26000, requiredIds = {9000}},								-- Cower (rank 3)
				{id =  9898, cost =  26000, requiredIds = {9747}},								-- Demoralizing Roar (rank 5)
				{id =  9834, cost =  26000, requiredIds = {9833}},								-- Moonfire (rank 9)
				{id =  9840, cost =  26000, requiredIds = {9839}},								-- Rejuvenation (rank 9)
				{id =  9894, cost =  26000, requiredIds = {9752}},								-- Rip (rank 5)
			},
	[54] =	{
				{id =  9904, cost =  28000, requiredIds = {1824}},								-- Rake (rank 4)
				{id =  9857, cost =  28000, requiredIds = {9856}},								-- Regrowth (rank 8)
				{id =  9830, cost =  28000, requiredIds = {9829}},								-- Shred (rank 5)
				{id =  9901, cost =  28000, requiredIds = {8955}},								-- Soothe Animal (rank 3)
				{id =  9908, cost =  28000, requiredIds = {9754}},								-- Swipe (Bear) (rank 5)
				{id =  9910, cost =  28000, requiredIds = {9756}},								-- Thorns (rank 6)
				{id =  9912, cost =  28000, requiredIds = {8905}},								-- Wrath (rank 8)
			},
	[56] =	{
				{id = 22829, cost =  30000, requiredIds = {22828}},								-- Ferocious Bite (rank 4)
				{id =  9889, cost =  30000, requiredIds = {9888}},								-- Healing Touch (rank 10)
				{id =  9827, cost =  30000, requiredIds = {9823}},								-- Pounce (rank 3)
			},
	[58] =	{
				{id =  9850, cost =  32000, requiredIds = {9849}},								-- Claw (rank 5)
				{id =  9853, cost =  32000, requiredIds = {9852}},								-- Entangling Roots (rank 6)
				{id = 18658, cost =  32000, requiredIds = {18657}},								-- Hibernate (rank 3)
				{id = 33986, cost =   1700, requiredIds = {33878}, requiredTalentId = 33917},	-- Mangle (Bear) (rank 2)
				{id = 33982, cost =   1700, requiredIds = {33876}, requiredTalentId = 33917},	-- Mangle (Cat) (rank 2)
				{id =  9881, cost =  32000, requiredIds = {9880}},								-- Maul (rank 7)
				{id =  9835, cost =  32000, requiredIds = {9834}},								-- Moonfire (rank 10)
				{id = 17329, cost =  32000, requiredIds = {16813,9853}},						-- Nature's Grasp (rank 6)
				{id =  9867, cost =  32000, requiredIds = {9866}},								-- Ravage (rank 4)
				{id =  9841, cost =  32000, requiredIds = {9840}},								-- Rejuvenation (rank 10)
				{id =  9876, cost =  32000, requiredIds = {9875}},								-- Starfire (rank 6)
			},
	[60] =	{
				{id = 31709, cost =  34000, requiredIds = {9892}},								-- Cower (rank 4)
				{id = 31018, cost =  30000, requiredIds = {22829}},								-- Ferocious Bite (rank 5)
				{id = 33943, cost =  34000},													-- Flight Form
				{id = 21850, cost =  34000, requiredIds = {21849,9885}},						-- Gift of the Wild (rank 2)
				{id = 25297, cost =  34000, requiredIds = {9889}},								-- Healing Touch (rank 11)
				{id = 17402, cost =  34000, requiredIds = {17401}},								-- Hurricane (rank 3)
				{id = 24977, cost =  34000, requiredIds = {24976}, requiredTalentId = 5570},	-- Insect Swarm (rank 5)
				{id =  9885, cost =  34000, requiredIds = {9884}},								-- Mark of the Wild (rank 7)
				{id = 20748, cost =  34000, requiredIds = {20747}},								-- Rebirth (rank 5)
				{id =  9858, cost =  34000, requiredIds = {9857}},								-- Regrowth (rank 9)
				{id = 25299, cost =  34000, requiredIds = {9841}},								-- Rejuvenation (rank 11)
				{id = 50765, cost =  34000, requiredIds = {50766}},								-- Revive (rank 5)
				{id =  9896, cost =  34000, requiredIds = {9894}},								-- Rip (rank 6)
				{id = 25298, cost =  34000, requiredIds = {9876}},								-- Starfire (rank 7)
				{id =  9846, cost =  34000, requiredIds = {9845}},								-- Tiger's Fury (rank 4)
				{id =  9863, cost =  34000, requiredIds = {9862}},								-- Tranquility (rank 4)
				{id = 53223, cost =    600, requiredIds = {50516}, requiredTalentId = 50516},	-- Typhoon (rank 2)
			},
	[61] =	{
				{id = 27001, cost =  39000, requiredIds = {9830}},								-- Shred (rank 6)
				{id = 26984, cost =  39000, requiredIds = {9912}},								-- Wrath (rank 9)
			},
	[62] =	{
				{id = 26998, cost =  43000, requiredIds = {9898}},								-- Demoralizing Roar (rank 6)
				{id = 26978, cost =  43000, requiredIds = {25297}},								-- Healing Touch (rank 12)
				{id = 22570, cost =  43000},													-- Maim (rank 1)
			},
	[63] =	{
				{id = 24248, cost =  48000, requiredIds = {31018}},								-- Ferocious Bite (rank 6)
				{id = 26987, cost =  48000, requiredIds = {9835}},								-- Moonfire (rank 11)
				{id = 26981, cost =  48000, requiredIds = {25299}},								-- Rejuvenation (rank 12)
			},
	[64] =	{
				{id = 33763, cost =  53000},													-- Lifebloom (rank 1)
				{id = 27003, cost =  53000, requiredIds = {9904}},								-- Rake (rank 5)
				{id = 26997, cost =  53000, requiredIds = {9908}},								-- Swipe (Bear) (rank 6)
				{id = 26992, cost =  53000, requiredIds = {9910}},								-- Thorns (rank 7)
			},
	[65] =	{
				{id = 33357, cost =  59000, requiredIds = {9821}},								-- Dash (rank 3)
				{id = 26980, cost =  59000, requiredIds = {9858}},								-- Regrowth (rank 10)
			},
	[66] =	{
				{id = 33745, cost =  66000},													-- Lacerate (rank 1)
				{id = 27006, cost =  66000, requiredIds = {9827}},								-- Pounce (rank 4)
				{id = 27005, cost =  66000, requiredIds = {9867}},								-- Ravage (rank 5)
			},
	[67] =	{
				{id = 27000, cost =  73000, requiredIds = {9850}},								-- Claw (rank 6)
				{id = 26996, cost =  73000, requiredIds = {9881}},								-- Maul (rank 8)
				{id = 27008, cost =  73000, requiredIds = {9896}},								-- Rip (rank 7)
				{id = 26986, cost =  73000, requiredIds = {25298}},								-- Starfire (rank 8)
			},
	[68] =	{
				{id = 26989, cost =  81000, requiredIds = {9853}},								-- Entangling Roots (rank 7)
				{id = 33987, cost =   1900, requiredIds = {33986}, requiredTalentId = 33917},	-- Mangle (Bear) (rank 3)
				{id = 33983, cost =   1700, requiredIds = {33982}, requiredTalentId = 33917},	-- Mangle (Cat) (rank 3)
				{id = 27009, cost =  81000, requiredIds = {17329,26989}},						-- Nature's Grasp (rank 7)
			},
	[69] =	{
				{id = 27004, cost =  90000, requiredIds = {31709}},								-- Cower (rank 5)
				{id = 26979, cost =  90000, requiredIds = {26978}},								-- Healing Touch (rank 13)
				{id = 26994, cost =  90000, requiredIds = {20748}},								-- Rebirth (rank 6)
				{id = 26982, cost =  90000, requiredIds = {26981}},								-- Rejuvenation (rank 13)
				{id = 50764, cost =  90000, requiredIds = {50765}},								-- Revive (rank 6)
				{id = 26985, cost =  90000, requiredIds = {26984}},								-- Wrath (rank 10)
			},
	[70] =	{
				{id = 33786, cost = 100000},													-- Cyclone
				{id = 26991, cost = 100000, requiredIds = {21850,26990}},						-- Gift of the Wild (rank 3)
				{id = 27012, cost = 100000, requiredIds = {17402}},								-- Hurricane (rank 4)
				{id = 27013, cost = 200000, requiredIds = {24977}, requiredTalentId = 5570},	-- Insect Swarm (rank 6)
				{id = 26990, cost = 100000, requiredIds = {9885}},								-- Mark of the Wild (rank 8)
				{id = 26988, cost = 100000, requiredIds = {26987}},								-- Moonfire (rank 12)
				{id = 27002, cost = 100000, requiredIds = {27001}},								-- Shred (rank 7)
				{id = 26995, cost = 100000, requiredIds = {9901}},								-- Soothe Animal (rank 4)
				{id = 53199, cost =  10000, requiredIds = {48505}, requiredTalentId = 48505},	-- Starfall (rank 2)
				{id = 40120, cost = 200000, requiredIds = {33943}},								-- Swift Flight Form
				{id = 26983, cost = 100000, requiredIds = {9863}},								-- Tranquility (rank 5)
				{id = 53225, cost =   1700, requiredIds = {53223}, requiredTalentId = 50516},	-- Typhoon (rank 3)
				{id = 53248, cost =   1700, requiredIds = {48438}, requiredTalentId = 48438},	-- Wild Growth (rank 2)
			},
	[71] =	{
				{id = 48559, cost = 200000, requiredIds = {26998}},								-- Demoralizing Roar (rank 7)
				{id = 48442, cost = 200000, requiredIds = {26980}},								-- Regrowth (rank 11)
				{id = 49799, cost = 200000, requiredIds = {27008}},								-- Rip (rank 8)
				{id = 62078, cost = 200000},													-- Swipe (Cat) (rank 1)
				{id = 50212, cost = 200000, requiredIds = {9846}},								-- Tiger's Fury (rank 5)
			},
	[72] =	{
				{id = 48576, cost = 200000, requiredIds = {24248}},								-- Ferocious Bite (rank 7)
				{id = 48450, cost = 200000, requiredIds = {33763}},								-- Lifebloom (rank 2)
				{id = 48573, cost = 200000, requiredIds = {27003}},								-- Rake (rank 6)
				{id = 48464, cost = 200000, requiredIds = {26986}},								-- Starfire (rank 9)
				{id = 48561, cost = 200000, requiredIds = {26997}},								-- Swipe (Bear) (rank 7)
			},
	[73] =	{
				{id = 48569, cost = 200000, requiredIds = {27000}},								-- Claw (rank 7)
				{id = 48567, cost = 200000, requiredIds = {33745}},								-- Lacerate (rank 2)
				{id = 48479, cost = 200000, requiredIds = {26996}},								-- Maul (rank 9)
				{id = 48578, cost = 200000, requiredIds = {27005}},								-- Ravage (rank 6)
			},
	[74] =	{
				{id = 48377, cost = 200000, requiredIds = {26979}},								-- Healing Touch (rank 14)
				{id = 49802, cost = 200000, requiredIds = {22570}},								-- Maim (rank 1)
				{id = 53307, cost = 200000, requiredIds = {26992}},								-- Thorns (rank 8)
				{id = 48459, cost = 200000, requiredIds = {26985}},								-- Wrath (rank 11)
			},
	[75] =	{
				{id = 48563, cost =  10000, requiredIds = {33987}, requiredTalentId = 33917},	-- Mangle (Bear) (rank 4)
				{id = 48565, cost =  10000, requiredIds = {33983}, requiredTalentId = 33917},	-- Mangle (Cat) (rank 4)
				{id = 48462, cost = 200000, requiredIds = {26988}},								-- Moonfire (rank 13)
				{id = 48440, cost = 200000, requiredIds = {26982}},								-- Rejuvenation (rank 14)
				{id = 52610, cost = 200000},													-- Savage Roar (rank 1)
				{id = 48571, cost = 200000, requiredIds = {27002}},								-- Shred (rank 8)
				{id = 53200, cost =  10000, requiredIds = {53199}, requiredTalentId = 48505},	-- Starfall (rank 3)
				{id = 48446, cost = 200000, requiredIds = {26983}},								-- Tranquility (rank 6)
				{id = 53226, cost =  10000, requiredIds = {53225}, requiredTalentId = 50516},	-- Typhoon (rank 4)
				{id = 53249, cost =  10000, requiredIds = {53248}, requiredTalentId = 48438},	-- Wild Growth (rank 3)
			},
	[76] =	{
				{id = 48575, cost = 200000, requiredIds = {27004}},								-- Cower (rank 6)
			},
	[77] =	{
				{id = 48560, cost = 200000, requiredIds = {48559}},								-- Demoralizing Roar (rank 8)
				{id = 49803, cost = 200000, requiredIds = {27006}},								-- Pounce (rank 5)
				{id = 48443, cost = 200000, requiredIds = {48442}},								-- Regrowth (rank 12)
				{id = 48562, cost = 200000, requiredIds = {48561}},								-- Swipe (Bear) (rank 8)
			},
	[78] =	{
				{id = 53308, cost = 200000, requiredIds = {26989}},								-- Entangling Roots (rank 8)
				{id = 48577, cost = 200000, requiredIds = {48576}},								-- Ferocious Bite (rank 8)
				{id = 53312, cost = 200000, requiredIds = {27009,53308}},						-- Nature's Grasp (rank 8)
				{id = 48574, cost = 200000, requiredIds = {48573}},								-- Rake (rank 7)
				{id = 48465, cost = 200000, requiredIds = {48464}},								-- Starfire (rank 10)
			},
	[79] =	{
				{id = 48570, cost = 200000, requiredIds = {48569}},								-- Claw (rank 8)
				{id = 48378, cost = 200000, requiredIds = {48377}},								-- Healing Touch (rank 15)
				{id = 48480, cost = 200000, requiredIds = {48479}},								-- Maul (rank 10)
				{id = 48579, cost = 200000, requiredIds = {48578}},								-- Ravage (rank 7)
				{id = 48477, cost = 200000, requiredIds = {26994}},								-- Rebirth (rank 7)
				{id = 50213, cost = 200000, requiredIds = {50212}},								-- Tiger's Fury (rank 6)
				{id = 48461, cost = 200000, requiredIds = {48459}},								-- Wrath (rank 12)
			},
	[80] =	{
				{id = 48470, cost = 200000, requiredIds = {48469,26991}},						-- Gift of the Wild (rank 4)
				{id = 48467, cost = 200000, requiredIds = {27012}},								-- Hurricane (rank 5)
				{id = 48468, cost = 200000, requiredIds = {27013}, requiredTalentId = 5570},	-- Insect Swarm (rank 7)
				{id = 48568, cost = 200000, requiredIds = {48567}},								-- Lacerate (rank 3)
				{id = 48451, cost = 200000, requiredIds = {48450}},								-- Lifebloom (rank 3)
				{id = 48564, cost =  10000, requiredIds = {48563}, requiredTalentId = 33917},	-- Mangle (Bear) (rank 5)
				{id = 48566, cost =  10000, requiredIds = {48565}, requiredTalentId = 33917},	-- Mangle (Cat) (rank 5)
				{id = 48469, cost = 200000, requiredIds = {26990}},								-- Mark of the Wild (rank 9)
				{id = 48463, cost = 200000, requiredIds = {48462}},								-- Moonfire (rank 14)
				{id = 50464, cost = 200000},													-- Nourish (rank 1)
				{id = 48441, cost = 200000, requiredIds = {48440}},								-- Rejuvenation (rank 15)
				{id = 50763, cost = 200000, requiredIds = {50764}},								-- Revive (rank 7)
				{id = 49800, cost = 200000, requiredIds = {49799}},								-- Rip (rank 9)
				{id = 48572, cost = 200000, requiredIds = {48571}},								-- Shred (rank 9)
				{id = 53201, cost =  10000, requiredIds = {53200}, requiredTalentId = 48505},	-- Starfall (rank 4)
				{id = 48447, cost = 200000, requiredIds = {48446}},								-- Tranquility (rank 7)
				{id = 61384, cost =  10000, requiredIds = {53226}, requiredTalentId = 50516},	-- Typhoon (rank 5)
				{id = 53251, cost =  10000, requiredIds = {53249}, requiredTalentId = 48438},	-- Wild Growth (rank 4)
			},
}
DragonUI_RegisterClassSpells("Druid", SpellsByLevel)
