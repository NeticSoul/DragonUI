SpellsByLevel = {
	[1] =	{
				{id =  1459, cost =     10},													-- Arcane Intellect (rank 1)
			},
	[4] =	{
				{id =   116, cost =    100},													-- Frostbolt (rank 1)
				{id =  5504, cost =    100},													-- Conjure Water (rank 1)
			},
	[6] =	{
				{id =  2136, cost =    100},													-- Fire Blast (rank 1)
				{id =   143, cost =    100, requiredIds = {133}},								-- Fireball (rank 2)
				{id =   587, cost =    100},													-- Conjure Food (rank 1)
			},
	[8] =	{
				{id =  5143, cost =    200},													-- Arcane Missiles (rank 1)
				{id =   205, cost =    200, requiredIds = {116}},								-- Frostbolt (rank 2)
				{id =   118, cost =    200},													-- Polymorph (rank 1)
			},
	[10] =	{
				{id =  7300, cost =    400, requiredIds = {168}},								-- Frost Armor (rank 2)
				{id =   122, cost =    400},													-- Frost Nova (rank 1)
				{id =  5505, cost =    400, requiredIds = {5504}},								-- Conjure Water (rank 2)
			},
	[12] =	{
				{id =   604, cost =    600},													-- Dampen Magic (rank 1)
				{id =   145, cost =    600, requiredIds = {143}},								-- Fireball (rank 3)
				{id =   130, cost =    600},													-- Slow Fall
				{id =   597, cost =    600, requiredIds = {587}},								-- Conjure Food (rank 2)
			},
	[14] =	{
				{id =  1449, cost =    900},													-- Arcane Explosion (rank 1)
				{id =  1460, cost =    900, requiredIds = {1459}},								-- Arcane Intellect (rank 2)
				{id =  2137, cost =    900, requiredIds = {2136}},								-- Fire Blast (rank 2)
				{id =   837, cost =    900, requiredIds = {205}},								-- Frostbolt (rank 3)
			},
	[16] =	{
				{id =  5144, cost =   1500, requiredIds = {5143}},								-- Arcane Missiles (rank 2)
				{id =  2120, cost =   1500},													-- Flamestrike (rank 1)
			},
	[18] =	{
				{id =  1008, cost =   1800},													-- Amplify Magic (rank 1)
				{id =  3140, cost =   1800, requiredIds = {145}},								-- Fireball (rank 4)
				{id =   475, cost =   1800},													-- Remove Curse
			},
	[20] =	{
				{id =  1953, cost =   2000},													-- Blink
				{id =    10, cost =   2000},													-- Blizzard (rank 1)
				{id = 12051, cost =   2000},													-- Evocation
				{id =   543, cost =   2000},													-- Fire Ward (rank 1)
				{id =  7301, cost =   2000, requiredIds = {7300}},								-- Frost Armor (rank 3)
				{id =  7322, cost =   2000, requiredIds = {837}},								-- Frostbolt (rank 4)
				{id =  1463, cost =   2000},													-- Mana Shield (rank 1)
				{id = 12824, cost =   2000, requiredIds = {118}},								-- Polymorph (rank 2)
				{id = 32271, cost =   2000, faction = "Alliance"},								-- Teleport: Exodar
				{id =  3562, cost =   2000, faction = "Alliance"},								-- Teleport: Ironforge
				{id =  3561, cost =   2000, faction = "Alliance"},								-- Teleport: Stormwind
				{id =  3567, cost =   2000, faction = "Horde"},									-- Teleport: Orgrimmar
				{id = 32272, cost =   2000, faction = "Horde"},									-- Teleport: Silvermoon
				{id =  3563, cost =   2000, faction = "Horde"},									-- Teleport: Undercity
				{id =  5506, cost =   2000, requiredIds = {5505}},								-- Conjure Water (rank 3)
			},
	[22] =	{
				{id =  8437, cost =   3000, requiredIds = {1449}},								-- Arcane Explosion (rank 2)
				{id =  2138, cost =   3000, requiredIds = {2137}},								-- Fire Blast (rank 3)
				{id =  6143, cost =   3000},													-- Frost Ward (rank 1)
				{id =  2948, cost =   3000},													-- Scorch (rank 1)
				{id =   990, cost =   3000, requiredIds = {597}},								-- Conjure Food (rank 3)
			},
	[24] =	{
				{id =  5145, cost =   4000, requiredIds = {5144}},								-- Arcane Missiles (rank 3)
				{id =  2139, cost =   4000},													-- Counterspell
				{id =  8450, cost =   4000, requiredIds = {604}},								-- Dampen Magic (rank 2)
				{id =  8400, cost =   4000, requiredIds = {3140}},								-- Fireball (rank 5)
				{id =  2121, cost =   4000, requiredIds = {2120}},								-- Flamestrike (rank 2)
				{id = 12505, cost =   1000, requiredIds = {11366}, requiredTalentId = 11366},	-- Pyroblast (rank 2)
			},
	[26] =	{
				{id =   120, cost =   5000},													-- Cone of Cold (rank 1)
				{id =   865, cost =   5000, requiredIds = {122}},								-- Frost Nova (rank 2)
				{id =  8406, cost =   5000, requiredIds = {7322}},								-- Frostbolt (rank 5)
			},
	[28] =	{
				{id =  1461, cost =   7000, requiredIds = {1460}},								-- Arcane Intellect (rank 3)
				{id =  6141, cost =   7000, requiredIds = {10}},								-- Blizzard (rank 2)
				{id =  8494, cost =   7000, requiredIds = {1463}},								-- Mana Shield (rank 2)
				{id =  8444, cost =   7000, requiredIds = {2948}},								-- Scorch (rank 2)
				{id =   759, cost =   7000},													-- Conjure Mana Gem (rank 1)
			},
	[30] =	{
				{id =  8455, cost =   8000, requiredIds = {1008}},								-- Amplify Magic (rank 2)
				{id =  8438, cost =   8000, requiredIds = {8437}},								-- Arcane Explosion (rank 3)
				{id =  8412, cost =   8000, requiredIds = {2138}},								-- Fire Blast (rank 4)
				{id =  8457, cost =   8000, requiredIds = {543}},								-- Fire Ward (rank 2)
				{id =  8401, cost =   8000, requiredIds = {8400}},								-- Fireball (rank 6)
				{id =  7302, cost =   8000},													-- Ice Armor (rank 1)
				{id = 45438, cost =   8000},													-- Ice Block
				{id = 12522, cost =    400, requiredIds = {12505}, requiredTalentId = 11366},	-- Pyroblast (rank 3)
				{id =  3565, cost =   8000, faction = "Alliance"},								-- Teleport: Darnassus
				{id =  3566, cost =   8000, faction = "Horde"},									-- Teleport: Thunder Bluff
				{id =  6127, cost =   8000, requiredIds = {5506}},								-- Conjure Water (rank 4)
			},
	[32] =	{
				{id =  8416, cost =  10000, requiredIds = {5145}},								-- Arcane Missiles (rank 4)
				{id =  8422, cost =  10000, requiredIds = {2121}},								-- Flamestrike (rank 3)
				{id =  8461, cost =  10000, requiredIds = {6143}},								-- Frost Ward (rank 2)
				{id =  8407, cost =  10000, requiredIds = {8406}},								-- Frostbolt (rank 6)
				{id =  6129, cost =  10000, requiredIds = {990}},								-- Conjure Food (rank 4)
			},
	[34] =	{
				{id =  8492, cost =  12000, requiredIds = {120}},								-- Cone of Cold (rank 2)
				{id =  6117, cost =  13000},													-- Mage Armor (rank 1)
				{id =  8445, cost =  12000, requiredIds = {8444}},								-- Scorch (rank 3)
			},
	[35] =	{
				{id = 49360, cost =  15000, faction = "Alliance"},								-- Portal: Theramore
				{id = 49359, cost =   2000, faction = "Alliance"},								-- Teleport: Theramore
				{id = 49361, cost =  15000, faction = "Horde"},									-- Portal: Stonard
				{id = 49358, cost =   2000, faction = "Horde"},									-- Teleport: Stonard
			},
	[36] =	{
				{id = 13018, cost =    400, requiredIds = {11113}, requiredTalentId = 11113},	-- Blast Wave (rank 2)
				{id =  8427, cost =  13000, requiredIds = {6141}},								-- Blizzard (rank 3)
				{id =  8451, cost =  13000, requiredIds = {8450}},								-- Dampen Magic (rank 3)
				{id =  8402, cost =  13000, requiredIds = {8401}},								-- Fireball (rank 7)
				{id =  8495, cost =  13000, requiredIds = {8494}},								-- Mana Shield (rank 3)
				{id = 12523, cost =    650, requiredIds = {12522}, requiredTalentId = 11366},	-- Pyroblast (rank 4)
			},
	[38] =	{
				{id =  8439, cost =  14000, requiredIds = {8438}},								-- Arcane Explosion (rank 4)
				{id =  8413, cost =  14000, requiredIds = {8412}},								-- Fire Blast (rank 5)
				{id =  8408, cost =  14000, requiredIds = {8407}},								-- Frostbolt (rank 7)
				{id =  3552, cost =  14000, requiredIds = {759}},								-- Conjure Mana Gem (rank 2)
			},
	[40] =	{
				{id =  8417, cost =  15000, requiredIds = {8416}},								-- Arcane Missiles (rank 5)
				{id =  8458, cost =  15000, requiredIds = {8457}},								-- Fire Ward (rank 3)
				{id =  8423, cost =  15000, requiredIds = {8422}},								-- Flamestrike (rank 4)
				{id =  6131, cost =  15000, requiredIds = {865}},								-- Frost Nova (rank 3)
				{id =  7320, cost =  15000, requiredIds = {7302}},								-- Ice Armor (rank 2)
				{id = 12825, cost =  15000, requiredIds = {12824}},								-- Polymorph (rank 3)
				{id = 32266, cost =  15000, faction = "Alliance"},								-- Portal: Exodar
				{id = 11416, cost =  15000, faction = "Alliance"},								-- Portal: Ironforge
				{id = 10059, cost =  15000, faction = "Alliance"},								-- Portal: Stormwind
				{id = 11417, cost =  15000, faction = "Horde"},									-- Portal: Orgrimmar
				{id = 32267, cost =  15000, faction = "Horde"},									-- Portal: Silvermoon
				{id = 11418, cost =  15000, faction = "Horde"},									-- Portal: Undercity
				{id =  8446, cost =  15000, requiredIds = {8445}},								-- Scorch (rank 4)
				{id = 10138, cost =  15000, requiredIds = {6127}},								-- Conjure Water (rank 5)
			},
	[42] =	{
				{id = 10169, cost =  18000, requiredIds = {8455}},								-- Amplify Magic (rank 3)
				{id = 10156, cost =  18000, requiredIds = {1461}},								-- Arcane Intellect (rank 4)
				{id = 10159, cost =  18000, requiredIds = {8492}},								-- Cone of Cold (rank 3)
				{id = 10148, cost =  18000, requiredIds = {8402}},								-- Fireball (rank 8)
				{id =  8462, cost =  18000, requiredIds = {8461}},								-- Frost Ward (rank 3)
				{id = 12524, cost =    900, requiredIds = {12523}, requiredTalentId = 11366},	-- Pyroblast (rank 5)
				{id = 10144, cost =  18000, requiredIds = {6129}},								-- Conjure Food (rank 5)
			},
	[44] =	{
				{id = 13019, cost =   1148, requiredIds = {13018}, requiredTalentId = 11113},	-- Blast Wave (rank 3)
				{id = 10185, cost =  23000, requiredIds = {8427}},								-- Blizzard (rank 4)
				{id = 10179, cost =  23000, requiredIds = {8408}},								-- Frostbolt (rank 8)
				{id = 10191, cost =  23000, requiredIds = {8495}},								-- Mana Shield (rank 4)
			},
	[46] =	{
				{id = 10201, cost =  26000, requiredIds = {8439}},								-- Arcane Explosion (rank 5)
				{id = 10197, cost =  26000, requiredIds = {8413}},								-- Fire Blast (rank 6)
				{id = 13031, cost =   1700, requiredIds = {11426}, requiredTalentId = 11426},	-- Ice Barrier (rank 2)
				{id = 22782, cost =   1400, requiredIds = {6117}},								-- Mage Armor (rank 2)
				{id = 10205, cost =  26000, requiredIds = {8446}},								-- Scorch (rank 5)
			},
	[48] =	{
				{id = 10211, cost =  28000, requiredIds = {8417}},								-- Arcane Missiles (rank 6)
				{id = 10173, cost =  28000, requiredIds = {8451}},								-- Dampen Magic (rank 4)
				{id = 10149, cost =  28000, requiredIds = {10148}},								-- Fireball (rank 9)
				{id = 10215, cost =  28000, requiredIds = {8423}},								-- Flamestrike (rank 5)
				{id = 12525, cost =   1400, requiredIds = {12524}, requiredTalentId = 11366},	-- Pyroblast (rank 6)
				{id = 10053, cost =  28000, requiredIds = {3552}},								-- Conjure Mana Gem (rank 3)
			},
	[50] =	{
				{id = 10160, cost =  32000, requiredIds = {10159}},								-- Cone of Cold (rank 4)
				{id = 10223, cost =  32000, requiredIds = {8458}},								-- Fire Ward (rank 4)
				{id = 10180, cost =  32000, requiredIds = {10179}},								-- Frostbolt (rank 9)
				{id = 10219, cost =  32000, requiredIds = {7320}},								-- Ice Armor (rank 3)
				{id = 11419, cost =  32000, faction = "Alliance"},								-- Portal: Darnassus
				{id = 11420, cost =  32000, faction = "Horde"},									-- Portal: Thunder Bluff
				{id = 10139, cost =  32000, requiredIds = {10138}},								-- Conjure Water (rank 6)
			},
	[52] =	{
				{id = 13020, cost =   1748, requiredIds = {13019}, requiredTalentId = 11113},	-- Blast Wave (rank 4)
				{id = 10186, cost =  35000, requiredIds = {10185}},								-- Blizzard (rank 5)
				{id = 10177, cost =  35000, requiredIds = {8462}},								-- Frost Ward (rank 4)
				{id = 13032, cost =   1748, requiredIds = {13031}, requiredTalentId = 11426},	-- Ice Barrier (rank 3)
				{id = 10192, cost =  35000, requiredIds = {10191}},								-- Mana Shield (rank 5)
				{id = 10206, cost =  35000, requiredIds = {10205}},								-- Scorch (rank 6)
				{id = 10145, cost =  35000, requiredIds = {10144}},								-- Conjure Food (rank 6)
			},
	[54] =	{
				{id = 10170, cost =  36000, requiredIds = {10169}},								-- Amplify Magic (rank 4)
				{id = 10202, cost =  36000, requiredIds = {10201}},								-- Arcane Explosion (rank 6)
				{id = 10199, cost =  36000, requiredIds = {10197}},								-- Fire Blast (rank 7)
				{id = 10150, cost =  36000, requiredIds = {10149}},								-- Fireball (rank 10)
				{id = 10230, cost =  36000, requiredIds = {6131}},								-- Frost Nova (rank 4)
				{id = 12526, cost =   1800, requiredIds = {12525}, requiredTalentId = 11366},	-- Pyroblast (rank 7)
			},
	[56] =	{
				{id = 23028, cost =  38000, requiredIds = {10157}},								-- Arcane Brilliance (rank 1)
				{id = 10157, cost =  38000, requiredIds = {10156}},								-- Arcane Intellect (rank 5)
				{id = 10212, cost =  38000, requiredIds = {10211}},								-- Arcane Missiles (rank 7)
				{id = 33041, cost =   1900, requiredIds = {31661}, requiredTalentId = 31661},	-- Dragon's Breath (rank 2)
				{id = 10216, cost =  38000, requiredIds = {10215}},								-- Flamestrike (rank 6)
				{id = 10181, cost =  38000, requiredIds = {10180}},								-- Frostbolt (rank 10)
			},
	[58] =	{
				{id = 10161, cost =  40000, requiredIds = {10160}},								-- Cone of Cold (rank 5)
				{id = 13033, cost =   2000, requiredIds = {13032}, requiredTalentId = 11426},	-- Ice Barrier (rank 4)
				{id = 22783, cost =  40000, requiredIds = {22782}},								-- Mage Armor (rank 3)
				{id = 10207, cost =  40000, requiredIds = {10206}},								-- Scorch (rank 7)
				{id = 10054, cost =  40000, requiredIds = {10053}},								-- Conjure Mana Gem (rank 4)
			},
	[60] =	{
				{id = 25345, cost =  42000, requiredIds = {10212}},								-- Arcane Missiles (rank 8)
				{id = 13021, cost =   2100, requiredIds = {13020}, requiredTalentId = 11113},	-- Blast Wave (rank 5)
				{id = 10187, cost =  42000, requiredIds = {10186}},								-- Blizzard (rank 6)
				{id = 10174, cost =  42000, requiredIds = {10173}},								-- Dampen Magic (rank 5)
				{id = 10225, cost =  42000, requiredIds = {10223}},								-- Fire Ward (rank 5)
				{id = 10151, cost =  42000, requiredIds = {10150}},								-- Fireball (rank 11)
				{id = 28609, cost =  42000, requiredIds = {10177}},								-- Frost Ward (rank 5)
				{id = 25304, cost =  42000, requiredIds = {10181}},								-- Frostbolt (rank 11)
				{id = 10220, cost =  42000, requiredIds = {10219}},								-- Ice Armor (rank 4)
				{id = 10193, cost =  42000, requiredIds = {10192}},								-- Mana Shield (rank 6)
				{id = 12826, cost =  42000, requiredIds = {12825}},								-- Polymorph (rank 4)
				{id = 18809, cost =   2100, requiredIds = {12526}, requiredTalentId = 11366},	-- Pyroblast (rank 8)
				{id = 33690, cost =  20000, faction = "Alliance"},								-- Teleport: Shattrath
				{id = 35715, cost =  20000, faction = "Horde"},									-- Teleport: Shattrath
				{id = 28612, cost =  42000, requiredIds = {10145}},								-- Conjure Food (rank 7)
				{id = 10140, cost =  42000, requiredIds = {10139}},								-- Conjure Water (rank 7)
			},
	[61] =	{
				{id = 27078, cost =  46000, requiredIds = {10199}},								-- Fire Blast (rank 8)
			},
	[62] =	{
				{id = 27080, cost =  51000, requiredIds = {10202}},								-- Arcane Explosion (rank 7)
				{id = 25306, cost =  42000, requiredIds = {10151}},								-- Fireball (rank 12)
				{id = 30482, cost =  51000},													-- Molten Armor (rank 1)
			},
	[63] =	{
				{id = 27130, cost =  57000, requiredIds = {10170}},								-- Amplify Magic (rank 5)
				{id = 27075, cost =  57000, requiredIds = {25345}},								-- Arcane Missiles (rank 9)
				{id = 27071, cost =  57000, requiredIds = {25304}},								-- Frostbolt (rank 12)
			},
	[64] =	{
				{id = 30451, cost =  63000},													-- Arcane Blast (rank 1)
				{id = 33042, cost =   2200, requiredIds = {33041}, requiredTalentId = 31661},	-- Dragon's Breath (rank 3)
				{id = 27086, cost =  63000, requiredIds = {10216}},								-- Flamestrike (rank 7)
				{id = 27134, cost =   2500, requiredIds = {13033}, requiredTalentId = 11426},	-- Ice Barrier (rank 5)
			},
	[65] =	{
				{id = 27133, cost =   3500, requiredIds = {13021}, requiredTalentId = 11113},	-- Blast Wave (rank 6)
				{id = 27087, cost =  70000, requiredIds = {10161}},								-- Cone of Cold (rank 6)
				{id = 33691, cost = 150000, faction = "Alliance"},								-- Portal: Shattrath
				{id = 35717, cost = 150000, faction = "Horde"},									-- Portal: Shattrath
				{id = 27073, cost =  70000, requiredIds = {10207}},								-- Scorch (rank 8)
				{id = 37420, cost =  70000, requiredIds = {10140}},								-- Conjure Water (rank 8)
			},
	[66] =	{
				{id = 27070, cost =  78000, requiredIds = {25306}},								-- Fireball (rank 13)
				{id = 30455, cost =  78000},													-- Ice Lance (rank 1)
				{id = 27132, cost =   3900, requiredIds = {18809}, requiredTalentId = 11366},	-- Pyroblast (rank 9)
			},
	[67] =	{
				{id = 33944, cost = 100000, requiredIds = {10174}},								-- Dampen Magic (rank 6)
				{id = 27088, cost =  87000, requiredIds = {10230}},								-- Frost Nova (rank 5)
			},
	[68] =	{
				{id = 27085, cost =  96000, requiredIds = {10187}},								-- Blizzard (rank 7)
				{id =    66, cost =  96000},													-- Invisibility
				{id = 27131, cost =  96000, requiredIds = {10193}},								-- Mana Shield (rank 7)
				{id = 27101, cost =  96000, requiredIds = {10054}},								-- Conjure Mana Gem (rank 5)
			},
	[69] =	{
				{id = 33946, cost = 110000, requiredIds = {27130}},								-- Amplify Magic (rank 6)
				{id = 38699, cost =  87000, requiredIds = {27075}},								-- Arcane Missiles (rank 10)
				{id = 27128, cost = 110000, requiredIds = {10225}},								-- Fire Ward (rank 6)
				{id = 27072, cost = 110000, requiredIds = {27071}},								-- Frostbolt (rank 13)
				{id = 27124, cost = 110000, requiredIds = {10220}},								-- Ice Armor (rank 5)
				{id = 27125, cost = 110000, requiredIds = {22783}},								-- Mage Armor (rank 4)
			},
	[70] =	{
				{id = 44780, cost =  10000, requiredIds = {44425}, requiredTalentId = 44425},	-- Arcane Barrage (rank 2)
				{id = 27127, cost = 100000, requiredIds = {27126,23028}},						-- Arcane Brilliance (rank 2)
				{id = 27082, cost = 120000, requiredIds = {27080}},								-- Arcane Explosion (rank 8)
				{id = 27126, cost = 120000, requiredIds = {10157}},								-- Arcane Intellect (rank 6)
				{id = 38704, cost = 100000, requiredIds = {38699}},								-- Arcane Missiles (rank 11)
				{id = 33933, cost =   6000, requiredIds = {27133}, requiredTalentId = 11113},	-- Blast Wave (rank 7)
				{id = 33043, cost =   2500, requiredIds = {33042}, requiredTalentId = 31661},	-- Dragon's Breath (rank 4)
				{id = 27079, cost = 120000, requiredIds = {27078}},								-- Fire Blast (rank 9)
				{id = 38692, cost = 150000, requiredIds = {27070}},								-- Fireball (rank 14)
				{id = 32796, cost = 120000, requiredIds = {28609}},								-- Frost Ward (rank 6)
				{id = 38697, cost = 150000, requiredIds = {27072}},								-- Frostbolt (rank 14)
				{id = 33405, cost =   6000, requiredIds = {27134}, requiredTalentId = 11426},	-- Ice Barrier (rank 6)
				{id = 55359, cost =   5000, requiredIds = {44457}, requiredTalentId = 44457},	-- Living Bomb (rank 2)
				{id = 33938, cost =   7500, requiredIds = {27132}, requiredTalentId = 11366},	-- Pyroblast (rank 10)
				{id = 43987, cost = 120000, requiredIds = {27090,33717}},						-- Ritual of Refreshments (rank 1)
				{id = 27074, cost = 120000, requiredIds = {27073}},								-- Scorch (rank 9)
				{id = 30449, cost = 120000},													-- Spellsteal
				{id = 33717, cost = 150000, requiredIds = {28612}},								-- Conjure Food (rank 8)
				{id = 27090, cost = 150000, requiredIds = {37420}},								-- Conjure Water (rank 9)
			},
	[71] =	{
				{id = 42894, cost = 150000, requiredIds = {30451}},								-- Arcane Blast (rank 2)
				{id = 43023, cost = 150000, requiredIds = {27125}},								-- Mage Armor (rank 5)
				{id = 43045, cost = 150000, requiredIds = {30482}},								-- Molten Armor (rank 2)
				{id = 53140, cost = 100000},													-- Teleport: Dalaran
			},
	[72] =	{
				{id = 42930, cost = 150000, requiredIds = {27087}},								-- Cone of Cold (rank 7)
				{id = 42925, cost = 150000, requiredIds = {27086}},								-- Flamestrike (rank 8)
				{id = 42913, cost = 150000, requiredIds = {30455}},								-- Ice Lance (rank 2)
			},
	[73] =	{
				{id = 43019, cost = 150000, requiredIds = {27131}},								-- Mana Shield (rank 8)
				{id = 42890, cost =   7500, requiredIds = {33938}, requiredTalentId = 11366},	-- Pyroblast (rank 11)
				{id = 42858, cost = 150000, requiredIds = {27074}},								-- Scorch (rank 10)
			},
	[74] =	{
				{id = 42939, cost = 150000, requiredIds = {27085}},								-- Blizzard (rank 8)
				{id = 42872, cost = 150000, requiredIds = {27079}},								-- Fire Blast (rank 10)
				{id = 42832, cost = 150000, requiredIds = {28692}},								-- Fireball (rank 15)
				{id = 53142, cost = 100000},													-- Portal: Dalaran
			},
	[75] =	{
				{id = 42843, cost = 150000, requiredIds = {38704}},								-- Arcane Missiles (rank 12)
				{id = 42944, cost =   7500, requiredIds = {33933}, requiredTalentId = 11113},	-- Blast Wave (rank 8)
				{id = 42949, cost =   7500, requiredIds = {33043}, requiredTalentId = 31661},	-- Dragon's Breath (rank 5)
				{id = 42917, cost = 150000, requiredIds = {27088}},								-- Frost Nova (rank 6)
				{id = 42841, cost = 150000, requiredIds = {38697}},								-- Frostbolt (rank 15)
				{id = 44614, cost = 150000},													-- Frostfire Bolt (rank 1)
				{id = 43038, cost =   7500, requiredIds = {33405}, requiredTalentId = 11426},	-- Ice Barrier (rank 7)
				{id = 42955, cost = 150000, requiredIds = {37420,33717}},						-- Conjure Refreshments (rank 1)
			},
	[76] =	{
				{id = 42896, cost = 150000, requiredIds = {42894}},								-- Arcane Blast (rank 3)
				{id = 42920, cost = 150000, requiredIds = {27082}},								-- Arcane Explosion (rank 9)
				{id = 43015, cost = 150000, requiredIds = {33944}},								-- Dampen Magic (rank 7)
			},
	[77] =	{
				{id = 43017, cost = 150000, requiredIds = {33946}},								-- Amplify Magic (rank 7)
				{id = 42891, cost =   7500, requiredIds = {42890}, requiredTalentId = 11366},	-- Pyroblast (rank 12)
				{id = 42985, cost = 150000, requiredIds = {27101}},								-- Conjure Mana Gem (rank 6)
			},
	[78] =	{
				{id = 43010, cost = 150000, requiredIds = {27128}},								-- Fire Ward (rank 7)
				{id = 42833, cost = 150000, requiredIds = {42832}},								-- Fireball (rank 16)
				{id = 42914, cost = 150000, requiredIds = {42913}},								-- Ice Lance (rank 3)
				{id = 42859, cost = 150000, requiredIds = {42858}},								-- Scorch (rank 11)
			},
	[79] =	{
				{id = 42846, cost = 150000, requiredIds = {42843}},								-- Arcane Missiles (rank 13)
				{id = 42931, cost = 150000, requiredIds = {42930}},								-- Cone of Cold (rank 8)
				{id = 42926, cost = 150000, requiredIds = {42925}},								-- Flamestrike (rank 9)
				{id = 43012, cost = 150000, requiredIds = {32796}},								-- Frost Ward (rank 7)
				{id = 42842, cost = 150000, requiredIds = {42841}},								-- Frostbolt (rank 16)
				{id = 43008, cost = 150000, requiredIds = {27124}},								-- Ice Armor (rank 6)
				{id = 43024, cost = 150000, requiredIds = {43023}},								-- Mage Armor (rank 6)
				{id = 43020, cost = 150000, requiredIds = {43019}},								-- Mana Shield (rank 9)
				{id = 43046, cost = 150000, requiredIds = {43045}},								-- Molten Armor (rank 3)
			},
	[80] =	{
				{id = 44781, cost =  15000, requiredIds = {44780}, requiredTalentId = 44425},	-- Arcane Barrage (rank 3)
				{id = 42897, cost = 150000, requiredIds = {42896}},								-- Arcane Blast (rank 4)
				{id = 43002, cost = 150000, requiredIds = {42995,27127}},						-- Arcane Brilliance (rank 3)
				{id = 42921, cost = 150000, requiredIds = {42920}},								-- Arcane Explosion (rank 10)
				{id = 42995, cost = 150000, requiredIds = {27126}},								-- Arcane Intellect (rank 7)
				{id = 42945, cost =   7500, requiredIds = {42944}, requiredTalentId = 11113},	-- Blast Wave (rank 9)
				{id = 42940, cost = 150000, requiredIds = {42939}},								-- Blizzard (rank 9)
				{id = 42950, cost =   7500, requiredIds = {42949}, requiredTalentId = 31661},	-- Dragon's Breath (rank 6)
				{id = 42873, cost = 150000, requiredIds = {42872}},								-- Fire Blast (rank 11)
				{id = 47610, cost = 150000, requiredIds = {44614}},								-- Frostfire Bolt (rank 2)
				{id = 43039, cost =   7500, requiredIds = {43038}, requiredTalentId = 11426},	-- Ice Barrier (rank 8)
				{id = 55360, cost =   7500, requiredIds = {55359}, requiredTalentId = 44457},	-- Living Bomb (rank 3)
				{id = 55342, cost = 150000},													-- Mirror Image
				{id = 58659, cost = 150000, requiredIds = {43987,42956}},						-- Ritual of Refreshments (rank 2)
				{id = 42956, cost = 150000, requiredIds = {42955}},								-- Conjure Refreshments (rank 2)
			},
}
DragonUI_RegisterClassSpells("Mage", SpellsByLevel)
