local _, ns = ...

-- WoW Forever only (TOC). Spell and item IDs from its 1.60.1.70790 DB2 tables (wago.tools).
ns.FV = {}
local FV = ns.FV

-- every rank of a spell, one per line: same name on the same class or pet skill line
FV.RANKS = {
    { 19434, 20900, 20901, 20902, 20903, 20904 }, -- Aimed Shot
    { 8676, 8724, 8725, 11267, 11268, 11269 }, -- Ambush
    { 1008, 8455, 10169, 10170 }, -- Amplify Magic
    { 409324, 409333, 409337 }, -- Ancestral Guidance
    { 2008, 20609, 20610, 20776, 20777 }, -- Ancestral Spirit
    { 400574, 1239696, 1239697, 1239699, 1239700 }, -- Arcane Blast
    { 1449, 8437, 8438, 8439, 10201, 10202 }, -- Arcane Explosion
    { 1459, 1460, 1461, 10156, 10157 }, -- Arcane Intellect
    { 5143, 5144, 5145, 8416, 8417, 10211, 10212, 25345 }, -- Arcane Missiles
    { 24493, 24497, 24500, 24501 }, -- Arcane Resistance
    { 24495, 24508, 24509, 24510 }, -- Arcane Resistance
    { 3044, 14281, 14282, 14283, 14284, 14285, 14286, 14287 }, -- Arcane Shot
    { 1326079, 1326080, 1326081, 1326082 }, -- Arcane Wrath
    { 13161, 1299445, 1299446, 1299447 }, -- Aspect of the Beast
    { 13165, 14318, 14319, 14320, 14321, 14322, 25296 }, -- Aspect of the Hawk
    { 20043, 20190 }, -- Aspect of the Wild
    { 53, 2589, 2590, 2591, 8721, 11279, 11280, 11281, 25300 }, -- Backstab
    { 980, 1014, 6217, 11711, 11712, 11713 }, -- Bane of Agony
    { 710, 18647 }, -- Banish
    { 5211, 6798, 8983 }, -- Bash
    { 5242, 6192, 6673, 11549, 11550, 11551, 25289 }, -- Battle Shout
    { 17253, 17255, 17256, 17257, 17258, 17259, 17260, 17261 }, -- Bite
    { 17254, 17262, 17263, 17264, 17265, 17266, 17267, 17268 }, -- Bite
    { 3674, 14296 }, -- Black Arrow
    { 6896, 17461 }, -- Black Ram
    { 15268, 15323, 15324, 15325, 15326 }, -- Blackout
    { 11113, 13018, 13019, 13020, 13021 }, -- Blast Wave
    { 27811, 27813 }, -- Blessed Recovery
    { 19740, 19834, 19835, 19836, 19837, 19838, 25291 }, -- Blessing of Might
    { 1022, 5599, 10278 }, -- Blessing of Protection
    { 6940, 20729 }, -- Blessing of Sacrifice
    { 19742, 19850, 19852, 19853, 19854, 25290 }, -- Blessing of Wisdom
    { 10, 6141, 8427, 10185, 10186, 10187 }, -- Blizzard
    { 6307, 7804, 7805, 11766, 11767 }, -- Blood Pact
    { 23881, 23892, 23893, 23894 }, -- Bloodthirst
    { 1064, 10622, 10623 }, -- Chain Heal
    { 421, 930, 2860, 10605, 408479, 408481, 408482, 408484 }, -- Chain Lightning
    { 100, 6178, 11578 }, -- Charge
    { 7370, 26184, 26185, 26186, 26202, 28343 }, -- Charge
    { 7371, 26177, 26178, 26179, 26201, 27685 }, -- Charge
    { 12695, 12696 }, -- Charge Rage Bonus Effect
    { 1277331, 1277332, 1277333, 1277334, 1277335 }, -- Chastise
    { 1082, 3029, 5201, 9849, 9850 }, -- Claw
    { 2975, 2976, 2977, 2980, 2981, 2982, 3666, 3667 }, -- Claw
    { 3009, 3010, 16827, 16828, 16829, 16830, 16831, 16832 }, -- Claw
    { 845, 7369, 11608, 11609, 20569 }, -- Cleave
    { 120, 8492, 10159, 10160, 10161 }, -- Cone of Cold
    { 17962, 18930, 18931, 18932, 1293817, 1293818 }, -- Conflagrate
    { 587, 597, 990, 6129, 10144, 10145, 28612 }, -- Conjure Food
    { 5504, 5505, 5506, 6127, 10138, 10139, 10140, 468766 }, -- Conjure Water
    { 20116, 20922, 20923, 20924, 26573 }, -- Consecration
    { 17767, 17850, 17851, 17852, 17853, 17854 }, -- Consume Shadows
    { 1277462, 1277634, 1277638, 1277639, 1277640 }, -- Contingency Plan
    { 172, 6222, 6223, 7648, 11671, 11672, 25311 }, -- Corruption
    { 19306, 20909, 20910, 1242634 }, -- Counterattack
    { 1742, 1753, 1754, 1755, 1756, 16697 }, -- Cower
    { 1747, 1748, 1749, 1750, 1751, 16698 }, -- Cower
    { 8998, 9000, 9892 }, -- Cower
    { 6366, 17951, 17952, 17953 }, -- Create Firestone
    { 5699, 6201, 6202, 11729, 11730 }, -- Create Healthstone
    { 693, 20752, 20755, 20756, 20757 }, -- Create Soulstone
    { 2362, 17727, 17728 }, -- Create Spellstone
    { 704, 7658, 7659, 11717 }, -- Curse of Recklessness
    { 440892, 1311676, 1311677, 1311680 }, -- Curse of the Elements
    { 1714, 11719 }, -- Curse of Tongues
    { 702, 1108, 6205, 7646, 11707, 11708 }, -- Curse of Weakness
    { 604, 8450, 8451, 10173, 10174 }, -- Dampen Magic
    { 1277324, 1277325, 1277326, 1277327, 1277328 }, -- Dark Sacrifice
    { 1850, 9821 }, -- Dash
    { 23099, 23109, 23110 }, -- Dash
    { 23100, 23111, 23112 }, -- Dash
    { 6789, 17925, 17926 }, -- Death Coil
    { 1316709, 1325756, 1325757, 1325758 }, -- Death Mark
    { 706, 1086, 11733, 11734, 11735 }, -- Demon Armor
    { 687, 696 }, -- Demon Skin
    { 99, 1735, 9490, 9747, 9898 }, -- Demoralizing Roar
    { 24423, 24577, 24578, 24579 }, -- Demoralizing Screech
    { 24424, 24580, 24581, 24582 }, -- Demoralizing Screech
    { 1160, 6190, 11554, 11555, 11556 }, -- Demoralizing Shout
    { 13908, 19236, 19238, 19240, 19241, 19242, 19243 }, -- Desperate Prayer
    { 132, 2970, 11743 }, -- Detect Invisibility
    { 465, 643, 1032, 10290, 10291, 10292, 10293 }, -- Devotion Aura
    { 19505, 19731, 19734, 19736 }, -- Devour Magic
    { 19658, 19732, 19733, 19735 }, -- Devour Magic Effect
    { 2944, 19276, 19277, 19278, 19279, 19280 }, -- Devouring Plague
    { 781, 14272, 14273 }, -- Disengage
    { 1264758, 1264927, 1264929, 1264930, 1264933 }, -- Dismember
    { 1264937, 1264939, 1264970, 1264971, 1264972 }, -- Dismember
    { 527, 988 }, -- Dispel Magic
    { 14274, 15629, 15630, 15631, 15632, 20736 }, -- Distracting Shot
    { 23145, 23147, 23148 }, -- Dive
    { 23146, 23149, 23150 }, -- Dive
    { 1277370, 1277371, 1277372, 1277374, 1277376, 1277377, 1277378 }, -- Divine Grace
    { 498, 5573 }, -- Divine Protection
    { 642, 1020 }, -- Divine Shield
    { 14752, 14818, 14819, 27841 }, -- Divine Spirit
    { 461607, 1237632 }, -- Divine Steed
    { 407778, 407784 }, -- Divine Storm
    { 689, 699, 709, 7651, 11699, 11700 }, -- Drain Life
    { 403677, 403685, 403686, 403687, 403688, 403689 }, -- Drain Life
    { 5138, 6226, 11703, 11704 }, -- Drain Mana
    { 1120, 8288, 8289, 11675 }, -- Drain Soul
    { 1265899, 1265901, 1265902, 1265903, 1265904 }, -- Dust Cloud
    { 1265907, 1265908, 1265909, 1265911, 1265913 }, -- Dust Cloud
    { 408514, 408519 }, -- Earth Shield
    { 8042, 8044, 8045, 8046, 10412, 10413, 10414 }, -- Earth Shock
    { 30160, 30165 }, -- Elemental Devastation
    { 16259, 16295 }, -- Enhancing Totems
    { 339, 1062, 5195, 5196, 9852, 9853 }, -- Entangling Roots
    { 19184, 19185 }, -- Entrapment
    { 2098, 6760, 6761, 6762, 8623, 8624, 11299, 11300, 31016 }, -- Eviscerate
    { 5308, 20647, 20658, 20660, 20661, 20662 }, -- Execute
    { 879, 5614, 5615, 10312, 10313, 10314 }, -- Exorcism
    { 415068, 415069, 415070, 415071, 415072, 415073 }, -- Exorcism
    { 13812, 13813, 14314, 14315, 14316, 14317 }, -- Explosive Trap
    { 8647, 8649, 8650, 11197, 11198 }, -- Expose Armor
    { 9799, 25997 }, -- Eye for an Eye
    { 586, 9578, 9579, 9592, 10941, 10942 }, -- Fade
    { 770, 778, 9749, 9907 }, -- Faerie Fire
    { 5782, 6213, 6215 }, -- Fear
    { 13896, 19271, 19273, 19274, 19275 }, -- Feedback
    { 1966, 6768, 8637, 11303, 25302 }, -- Feint
    { 16858, 16859, 16860, 16861, 16862 }, -- Feral Aggression
    { 22568, 22827, 22828, 22829, 31018, 1328618 }, -- Ferocious Bite
    { 2136, 2137, 2138, 8412, 8413, 10197, 10199, 400616, 400618, 400619, 400620, 400621, 400622, 400623 }, -- Fire Blast
    { 408341, 408342, 408343, 408344, 408345 }, -- Fire Nova
    { 23992, 24439, 24444, 24445 }, -- Fire Resistance
    { 24440, 24441, 24463, 24464 }, -- Fire Resistance
    { 19891, 19899, 19900 }, -- Fire Resistance Aura
    { 8184, 10537, 10538 }, -- Fire Resistance Totem
    { 2947, 8316, 8317, 11770, 11771 }, -- Fire Shield
    { 543, 8457, 8458, 10223, 10225 }, -- Fire Ward
    { 133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151, 25306 }, -- Fireball
    { 3110, 7799, 7800, 7801, 7802, 11762, 11763 }, -- Firebolt
    { 13707, 13966, 13967, 13968, 13969 }, -- Fist Weapon Specialization
    { 8050, 8052, 8053, 10447, 10448, 29228 }, -- Flame Shock
    { 2120, 2121, 8422, 8423, 10215, 10216 }, -- Flamestrike
    { 8227, 8249, 10526, 16387 }, -- Flametongue Totem
    { 8024, 8027, 8030, 16339, 16341, 16342 }, -- Flametongue Weapon
    { 2061, 9472, 9473, 9474, 10915, 10916, 10917 }, -- Flash Heal
    { 19750, 19939, 19940, 19941, 19942, 19943, 19993, 412020, 1313342, 1313343, 1313344, 1313345, 1313346 }, -- Flash of Light
    { 17458, 463005 }, -- Fluorescent Green Mechanostrider
    { 12319, 12966 }, -- Flurry
    { 18544, 18547, 18548, 18549, 18550 }, -- Force of Will
    { 1499, 14310, 14311 }, -- Freezing Trap
    { 22842, 22845 }, -- Frenzied Regeneration
    { 168, 7300, 7301 }, -- Frost Armor
    { 122, 865, 6131, 10230 }, -- Frost Nova
    { 24446, 24447, 24448, 24449 }, -- Frost Resistance
    { 24475, 24476, 24477, 24478 }, -- Frost Resistance
    { 19888, 19897, 19898 }, -- Frost Resistance Aura
    { 8181, 10478, 10479 }, -- Frost Resistance Totem
    { 8056, 8058, 10472, 10473 }, -- Frost Shock
    { 6143, 8461, 8462, 10177, 28609 }, -- Frost Ward
    { 11071, 12494 }, -- Frostbite
    { 116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304 }, -- Frostbolt
    { 8033, 8038, 10456, 16355, 16356 }, -- Frostbrand Weapon
    { 401502, 1237312, 1237313 }, -- Frostfire Bolt
    { 440802, 440809 }, -- Frozen Orb
    { 24597, 24603, 24604, 24605 }, -- Furious Howl
    { 24599, 24607, 24608, 24609 }, -- Furious Howl
    { 703, 8631, 8632, 8633, 11289, 11290 }, -- Garrote
    { 21849, 21850 }, -- Gift of the Wild
    { 16060, 436329, 463006 }, -- Golden Sabercat
    { 1776, 1777, 8629, 11285, 11286 }, -- Gouge
    { 8835, 10627, 25359 }, -- Grace of Air Totem
    { 4187, 4188, 4189, 4190, 4191, 4192, 4193, 4194, 5041, 5042 }, -- Great Stamina
    { 4195, 4196, 4197, 4198, 4199, 4200, 4201, 4202, 5048, 5049 }, -- Great Stamina
    { 25782, 25916 }, -- Greater Blessing of Might
    { 25894, 25918 }, -- Greater Blessing of Wisdom
    { 2060, 10963, 10964, 10965, 25314 }, -- Greater Heal
    { 15780, 17453 }, -- Green Mechanostrider
    { 1853, 14922, 14923, 14924, 14925, 14926, 14927 }, -- Growl
    { 2649, 14916, 14917, 14918, 14919, 14920, 14921 }, -- Growl
    { 13706, 13709, 13960 }, -- Hack and Slash
    { 853, 5588, 5589, 10308 }, -- Hammer of Justice
    { 24239, 24274, 24275 }, -- Hammer of Wrath
    { 1715, 7372, 7373 }, -- Hamstring
    { 23163, 23166, 23167 }, -- Harass
    { 2054, 2055, 6063, 6064 }, -- Heal
    { 29189, 29191 }, -- Healing Grace
    { 415236, 415242 }, -- Healing Rain
    { 5394, 6375, 6377, 10462, 10463 }, -- Healing Stream Totem
    { 5185, 5186, 5187, 5188, 5189, 6778, 8903, 9758, 9888, 9889, 25297 }, -- Healing Touch
    { 331, 332, 547, 913, 939, 959, 8005, 10395, 10396, 25357 }, -- Healing Wave
    { 755, 3698, 3699, 3700, 11693, 11694, 11695 }, -- Health Funnel
    { 1949, 11683, 11684 }, -- Hellfire
    { 5857, 11681, 11682 }, -- Hellfire Effect
    { 78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286 }, -- Heroic Strike
    { 9035, 19281, 19282, 19283, 19284, 19285 }, -- Hex of Weakness
    { 2637, 18657, 18658 }, -- Hibernate
    { 14914, 15261, 15262, 15263, 15264, 15265, 15266, 15267 }, -- Holy Fire
    { 635, 639, 647, 1026, 1042, 3472, 10328, 10329, 19968, 19980, 19981, 19982, 25292, 1313348, 1313349, 1313350, 1313351, 1313352 }, -- Holy Light
    { 15237, 15430, 15431, 23455, 23458, 23459, 27799, 27800, 27801, 27803, 27804, 27805 }, -- Holy Nova
    { 20925, 20927, 20928, 1239570 }, -- Holy Shield
    { 20473, 20929, 20930, 25902, 25903, 25911, 25912, 25913, 25914, 1311606 }, -- Holy Shock
    { 678, 679, 680, 1866, 2495, 5569, 10332, 10333 }, -- Holy Strike
    { 2812, 10318 }, -- Holy Wrath
    { 5484, 17928 }, -- Howl of Terror
    { 19151, 19152, 19153 }, -- Humanoid Slaying
    { 1130, 14323, 14324, 14325 }, -- Hunter's Mark
    { 16914, 17401, 17402 }, -- Hurricane
    { 7302, 7320, 10219, 10220 }, -- Ice Armor
    { 11426, 13031, 13032, 13033 }, -- Ice Barrier
    { 400640, 1240044, 1240045, 1240046, 1240047, 1312002 }, -- Ice Lance
    { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 }, -- Immolate
    { 13795, 13797, 14298, 14299, 14300, 14301, 14302, 14303, 14304, 14305 }, -- Immolation Trap
    { 11103, 12355 }, -- Impact
    { 12318, 12857, 12858, 12860, 12861 }, -- Improved Battle Shout
    { 20042, 20045, 20046, 20047, 20048 }, -- Improved Blessing of Might
    { 20244, 20245 }, -- Improved Blessing of Wisdom
    { 12327, 12886 }, -- Improved Challenging Shout
    { 18310, 18311, 18312, 18313 }, -- Improved Curse of Exhaustion
    { 18179, 18180, 18181 }, -- Improved Curse of Weakness
    { 12324, 12876, 12877, 12878, 12879 }, -- Improved Demoralizing Shout
    { 17079, 17082 }, -- Improved Enrage
    { 19557, 19558 }, -- Improved Eyes of the Beast
    { 19286, 19287 }, -- Improved Feign Death
    { 18126, 18127 }, -- Improved Firebolt
    { 18767, 18768 }, -- Improved Firestone
    { 20249, 20250, 20251 }, -- Improved Flash of Light
    { 18692, 18693 }, -- Improved Healthstone
    { 17815, 17833, 17834, 17835, 17836 }, -- Improved Immolate
    { 19870, 19871 }, -- Improved Intimidating Shout
    { 18128, 18129 }, -- Improved Lash of Pain
    { 17050, 17051, 17053, 17054, 17055 }, -- Improved Mark of the Wild
    { 19572, 24406 }, -- Improved Mend Pet
    { 12290, 12963 }, -- Improved Overpower
    { 14749, 14767 }, -- Improved Power Word: Fortitude
    { 12288, 12707, 12708 }, -- Improved Pummel
    { 20091, 20092 }, -- Improved Retribution Aura
    { 14076, 14094, 14095 }, -- Improved Sap
    { 20335, 20336, 20337 }, -- Improved Seal of the Crusader
    { 12307, 12944, 12945 }, -- Improved Shield Block
    { 18774, 18775 }, -- Improved Spellstone
    { 18821, 18822, 18823, 18824, 18825 }, -- Improved Subjugate Demon
    { 12302, 12765 }, -- Improved Taunt
    { 16836, 16839, 16840 }, -- Improved Thorns
    { 29192, 29193 }, -- Improved Weapon Totems
    { 412758, 1293812, 1293813 }, -- Incinerate
    { 13976, 13977 }, -- Initiative
    { 588, 602, 1006, 7128, 10951, 10952 }, -- Inner Fire
    { 5570, 24974, 24975, 24976, 24977 }, -- Insect Swarm
    { 20252, 20616, 20617 }, -- Intercept
    { 19577, 24394 }, -- Intimidation
    { 426241, 426245, 426246, 426247, 426331 }, -- Invocation
    { 10795, 17450, 436289 }, -- Ivory Raptor
    { 20425, 20467, 20961, 20962, 20963, 20964, 20965, 20966, 20967, 20968 }, -- Judgement of Command
    { 20183, 20411, 20412, 20413, 20414 }, -- Judgement of Fury
    { 20185, 20344, 20345, 20346 }, -- Judgement of Light
    { 20187, 20280, 20281, 20282, 20283, 20284, 20285, 20286 }, -- Judgement of Righteousness
    { 20188, 20300, 20301, 20302, 20303 }, -- Judgement of the Crusader
    { 20186, 20354, 20355 }, -- Judgement of Wisdom
    { 1766, 1767, 1768, 1769 }, -- Kick
    { 408, 8643 }, -- Kidney Shot
    { 24118, 24119, 24120, 1299332 }, -- Lacerate
    { 414644, 414647, 1235826, 1235827, 1328616, 1328617 }, -- Lacerate
    { 7814, 7815, 7816, 11778, 11779, 11780 }, -- Lash of Pain
    { 12975, 12976 }, -- Last Stand
    { 20359, 20360, 20361 }, -- Lasting Judgement
    { 444678, 444681 }, -- Lava Breath
    { 444680, 444682 }, -- Lava Breath
    { 633, 2800, 10310 }, -- Lay on Hands
    { 2050, 2052, 2053 }, -- Lesser Heal
    { 8004, 8008, 8010, 10466, 10467, 10468 }, -- Lesser Healing Wave
    { 1454, 1455, 1456, 11687, 11688, 11689 }, -- Life Tap
    { 408124, 408245 }, -- Lifebloom
    { 1310911, 1311590, 1311595 }, -- Light's Vigil
    { 403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208, 408439, 408440, 408441, 408442, 408443, 408472, 408473, 408474, 408475, 408477 }, -- Lightning Bolt
    { 24844, 25008, 25009, 25010, 25011, 25012 }, -- Lightning Breath
    { 24845, 25013, 25014, 25015, 25016, 25017 }, -- Lightning Breath
    { 16166, 16579, 16580, 16581, 16582 }, -- Lightning Mastery
    { 324, 325, 905, 945, 8134, 10431, 10432, 26363, 26364, 26365, 26366, 26367, 26369, 26370 }, -- Lightning Shield
    { 724, 27870, 27871 }, -- Lightwell
    { 7001, 27873, 27874 }, -- Lightwell Renew
    { 400613, 400614 }, -- Living Bomb
    { 401556, 401558 }, -- Living Flame
    { 6117, 22782, 22783 }, -- Mage Armor
    { 29441, 29442 }, -- Magic Absorption
    { 8190, 10585, 10586, 10587 }, -- Magma Totem
    { 8129, 8131, 10874, 10875, 10876 }, -- Mana Burn
    { 1463, 8494, 8495, 10191, 10192, 10193 }, -- Mana Shield
    { 5675, 10495, 10496, 10497 }, -- Mana Spring Totem
    { 16190, 17354, 17359, 1325256 }, -- Mana Tide Totem
    { 1126, 5232, 5234, 6756, 8907, 9884, 9885 }, -- Mark of the Wild
    { 23759, 23760, 23761, 23762, 23785 }, -- Master Demonologist
    { 29074, 29077 }, -- Master of Elements
    { 6807, 6808, 6809, 8972, 9745, 9880, 9881 }, -- Maul
    { 19381, 19382, 19383, 19384, 19385 }, -- Melee Specialization
    { 136, 3111, 3661, 3662, 13542, 13543, 13544 }, -- Mend Pet
    { 8092, 8102, 8103, 8104, 8105, 8106, 10945, 10946, 10947 }, -- Mind Blast
    { 605, 10911, 10912 }, -- Mind Control
    { 15407, 17311, 17312, 17313, 17314, 18807 }, -- Mind Flay
    { 413259, 413260 }, -- Mind Sear
    { 453, 8192, 10953 }, -- Mind Soothe
    { 2096, 10909 }, -- Mind Vision
    { 1265054, 1265055, 1265056, 1265057, 1265058 }, -- Mine!
    { 1265059, 1265060, 1265061, 1265062, 1265064 }, -- Mine!
    { 694, 7400, 7402, 20559, 20560 }, -- Mocking Blow
    { 1495, 14269, 14270, 14271 }, -- Mongoose Bite
    { 24294, 24295 }, -- Monster Slaying
    { 8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835 }, -- Moonfire
    { 12294, 21551, 21552, 21553 }, -- Mortal Strike
    { 436288, 463007 }, -- Mottled Blood Raptor
    { 399956, 399960, 399961, 1241582, 1241584, 1241585, 1241586, 1241588, 1241590 }, -- Mutilate
    { 24545, 24549, 24550, 24551, 24552, 24553, 24554, 24555, 24629, 24630 }, -- Natural Armor
    { 24547, 24556, 24557, 24558, 24559, 24560, 24561, 24562, 24631, 24632 }, -- Natural Armor
    { 16902, 16903, 16904, 16905, 16906 }, -- Natural Weapons
    { 24492, 24502, 24503, 24504 }, -- Nature Resistance
    { 24494, 24511, 24512, 24513 }, -- Nature Resistance
    { 10595, 10600, 10601 }, -- Nature Resistance Totem
    { 16689, 16810, 16811, 16812, 16813, 17329 }, -- Nature's Grasp
    { 16180, 16196, 16198 }, -- Nature's Guidance
    { 7384, 7887, 11584, 11585 }, -- Overpower
    { 471, 16082 }, -- Palomino Stallion
    { 402174, 402284, 402289, 1240720, 1240721, 1240723, 1240724, 1240727, 1240730, 1316991, 1316993, 1316995 }, -- Penance
    { 6311, 6314, 6315, 6316, 6317 }, -- Pet Aggression
    { 6280, 6281, 6282, 6283, 6286 }, -- Pet Hardiness
    { 6328, 6331, 6332, 6333, 6334 }, -- Pet Recovery
    { 6443, 6444, 6445, 6446, 6447 }, -- Pet Resistance
    { 1264735, 1264736, 1264739, 1264741, 1264742 }, -- Pinch
    { 1264745, 1264749, 1264750, 1264751, 1264752 }, -- Pinch
    { 425012, 425013 }, -- Poisoned Knife
    { 118, 12824, 12825, 12826, 28271, 28272 }, -- Polymorph
    { 9005, 9823, 9827 }, -- Pounce
    { 9007, 9824, 9826 }, -- Pounce Bleed
    { 1243, 1244, 1245, 2791, 10937, 10938 }, -- Power Word: Fortitude
    { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901 }, -- Power Word: Shield
    { 21562, 21564 }, -- Prayer of Fortitude
    { 596, 996, 10960, 10961, 25316 }, -- Prayer of Healing
    { 401859, 401863, 1240826, 1240827 }, -- Prayer of Mending
    { 407995, 1238069, 1238070 }, -- Primal Bite
    { 5215, 6783, 9913 }, -- Prowl
    { 24450, 24452, 24453 }, -- Prowl
    { 24451, 24454, 24455 }, -- Prowl
    { 8122, 8124, 10888, 10890 }, -- Psychic Scream
    { 6552, 6554 }, -- Pummel
    { 370, 8012 }, -- Purge
    { 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809 }, -- Pyroblast
    { 5740, 6219, 11677, 11678 }, -- Rain of Fire
    { 1822, 1823, 1824, 9904 }, -- Rake
    { 2973, 14260, 14261, 14262, 14263, 14264, 14265, 14266, 409691, 409693, 409748, 409750, 409751, 409752, 409754, 409755, 415335, 415336, 415337, 415338, 415340, 415341, 415342, 415343 }, -- Raptor Strike
    { 6785, 6787, 9866, 9867 }, -- Ravage
    { 20484, 20739, 20742, 20747, 20748 }, -- Rebirth
    { 579, 16080 }, -- Red Wolf
    { 7328, 10322, 10324, 20772, 20773 }, -- Redemption
    { 8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858 }, -- Regrowth
    { 20608, 21169 }, -- Reincarnation
    { 25675, 25858, 25859, 434508 }, -- Reindeer
    { 774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299 }, -- Rejuvenation
    { 772, 6546, 6547, 6548, 11572, 11573, 11574 }, -- Rend
    { 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315, 425268, 425269, 425270, 425271, 425272, 425273, 425274, 425275, 425276, 425277 }, -- Renew
    { 2006, 2010, 10880, 10881, 20770 }, -- Resurrection
    { 7294, 10298, 10299, 10300, 10301 }, -- Retribution Aura
    { 6572, 6574, 7379, 11600, 11601, 25288 }, -- Revenge
    { 437138, 1237948, 1237949, 1237950, 1237951 }, -- Revive
    { 25780, 407627 }, -- Righteous Fury
    { 1079, 9492, 9493, 9752, 9894, 9896 }, -- Rip
    { 408521, 1239242, 1239243 }, -- Riptide
    { 8017, 8018, 8019, 10399, 16314, 16315, 16316 }, -- Rockbiter Weapon
    { 1943, 8639, 8640, 11273, 11274, 11275 }, -- Rupture
    { 7812, 19438, 19440, 19441, 19442, 19443 }, -- Sacrifice
    { 2070, 6770, 11297 }, -- Sap
    { 1265065, 1265066, 1265067, 1265068, 1265069 }, -- Savage Rend
    { 1265831, 1265833, 1265834, 1265835, 1265836 }, -- Savage Rend
    { 1513, 14326, 14327 }, -- Scare Beast
    { 2948, 8444, 8445, 8446, 10205, 10206, 10207 }, -- Scorch
    { 24583, 24586, 24587, 24640 }, -- Scorpid Poison
    { 24584, 24588, 24589, 24641 }, -- Scorpid Poison
    { 20375, 20915, 20918, 20919, 20920 }, -- Seal of Command
    { 20163, 20419, 20421, 20422, 20423, 1311649, 1311656 }, -- Seal of Fury
    { 20165, 20347, 20348, 20349 }, -- Seal of Light
    { 407798, 407799 }, -- Seal of Martyrdom
    { 20154, 20287, 20288, 20289, 20290, 20291, 20292, 20293, 21084 }, -- Seal of Righteousness
    { 20162, 20305, 20306, 20307, 20308, 21082 }, -- Seal of the Crusader
    { 20166, 20356, 20357 }, -- Seal of Wisdom
    { 5676, 17919, 17920, 17921, 17922, 17923 }, -- Searing Pain
    { 3599, 6363, 6364, 6365, 10437, 10438 }, -- Searing Totem
    { 1978, 13549, 13550, 13551, 13552, 13553, 13554, 13555, 25295, 425728, 425729, 425730, 425732, 425733, 425734, 425735, 425736, 425737 }, -- Serpent Sting
    { 9484, 9485, 10955 }, -- Shackle Undead
    { 686, 695, 705, 1088, 1106, 7641, 11659, 11660, 11661, 25307 }, -- Shadow Bolt
    { 403835, 403839, 403840, 403841, 403842, 403843, 403844, 403848, 403851, 403852 }, -- Shadow Cleave
    { 976, 10957, 10958 }, -- Shadow Protection
    { 24488, 24505, 24506, 24507 }, -- Shadow Resistance
    { 24490, 24514, 24515, 24516 }, -- Shadow Resistance
    { 19876, 19895, 19896 }, -- Shadow Resistance Aura
    { 6229, 11739, 11740, 28610 }, -- Shadow Ward
    { 401955, 1309595, 1309633, 1309635, 1309636 }, -- Shadow Word: Death
    { 589, 594, 970, 992, 2767, 10892, 10893, 10894 }, -- Shadow Word: Pain
    { 17877, 18867, 18868, 18869, 18870, 18871 }, -- Shadowburn
    { 426320, 426325 }, -- Shadowflame
    { 18137, 19308, 19309, 19310, 19311, 19312, 28377, 28378, 28379, 28380, 28381, 28382 }, -- Shadowguard
    { 1329283, 1329549 }, -- Shank
    { 72, 1671, 1672 }, -- Shield Bash
    { 23922, 23923, 23924, 23925 }, -- Shield Slam
    { 16253, 16298, 16299, 16300, 16301 }, -- Shield Specialization
    { 20148, 20149, 20150 }, -- Shield Specialization
    { 5221, 6800, 8992, 9829, 9830 }, -- Shred
    { 1752, 1757, 1758, 1759, 1760, 8621, 11293, 11294 }, -- Sinister Strike
    { 18265, 18879, 18880, 18881 }, -- Siphon Life
    { 1464, 8820, 11604, 11605, 1240193 }, -- Slam
    { 5171, 6774 }, -- Slice and Dice
    { 585, 591, 598, 984, 1004, 6060, 10933, 10934 }, -- Smite
    { 1310687, 1310785, 1310786 }, -- Sniper Shot
    { 1264478, 1264479, 1264480, 1264481, 1264482 }, -- Sonic Blast
    { 2908, 8955, 9901 }, -- Soothe Animal
    { 6360, 7813, 11784, 11785 }, -- Soothing Kiss
    { 6353, 17924 }, -- Soul Fire
    { 19244, 19647 }, -- Spell Lock
    { 19578, 24529, 1310725 }, -- Spirit Bond
    { 2983, 8696, 11305 }, -- Sprint
    { 439748, 439753, 439756 }, -- Starfall
    { 2912, 8949, 8950, 8951, 9875, 9876, 25298 }, -- Starfire
    { 10797, 19296, 19299, 19302, 19303, 19304, 19305 }, -- Starshards
    { 1784, 1785, 1786, 1787 }, -- Stealth
    { 5730, 6390, 6391, 6392, 10427, 10428 }, -- Stoneclaw Totem
    { 8071, 8154, 8155, 10406, 10407, 10408 }, -- Stoneskin Totem
    { 8075, 8160, 8161, 10442, 25361 }, -- Strength of Earth Totem
    { 1098, 11725, 11726 }, -- Subjugate Demon
    { 17735, 17750, 17751, 17752 }, -- Suffering
    { 25863, 26655 }, -- Summon Black Qiraji Battle Tank
    { 473858, 473859, 473860 }, -- Summon Dark Blue Qiraji Battle Tank
    { 17708, 1310329 }, -- Summon Diablo
    { 1217150, 1217151, 1217152 }, -- Summon Flawless Blue Qiraji Battle Tank
    { 1217146, 1217147, 1217148 }, -- Summon Flawless Green Qiraji Battle Tank
    { 1217154, 1217155, 1217156 }, -- Summon Flawless Red Qiraji Battle Tank
    { 1217142, 1217143, 1217144 }, -- Summon Flawless Yellow Qiraji Battle Tank
    { 1293241, 1293525, 1293526, 1293527 }, -- Summon Hawk
    { 26533, 26541 }, -- Summon Helper
    { 1250013, 1250014, 1250015, 1250016 }, -- Summon Lashling
    { 473869, 473870, 473871 }, -- Summon Light Blue Qiraji Battle Tank
    { 473848, 473853, 473855 }, -- Summon Light Green Qiraji Battle Tank
    { 473874, 473875, 473877 }, -- Summon Orange Qiraji Battle Tank
    { 17707, 1310331 }, -- Summon Panda
    { 370637, 381598 }, -- Summon Skeletal Steed
    { 473882, 473886, 473887 }, -- Summon Twilight Qiraji Battle Tank
    { 13819, 1279399 }, -- Summon Warhorse
    { 17709, 1310330 }, -- Summon Zergling
    { 7386, 7405, 8380, 11596, 11597 }, -- Sunder Armor
    { 414684, 414687, 414689 }, -- Sunfire
    { 12292, 12723 }, -- Sweeping Strikes
    { 769, 779, 780, 9754, 9908, 411128 }, -- Swipe
    { 1264494, 1264497, 1264498, 1264501, 1264502 }, -- Swipe
    { 1264727, 1264729, 1264730, 1264731, 1264732 }, -- Swipe
    { 19478, 19655, 19656, 19660 }, -- Tainted Blood
    { 1515, 13481, 13535 }, -- Tame Beast
    { 7000, 8875, 17206, 17208, 17209, 17210, 17211, 17212, 17214, 17215, 17216, 17217, 17218, 17219, 17220, 17221, 17222, 17223, 19580, 19581, 19582, 19589, 19591, 20782, 20784, 409365, 444831 }, -- Tamed Pet Passive (DND)
    { 18727, 18728, 18729, 18730, 18735, 18736, 18737, 18738, 18739, 18740, 18741, 18742, 19007, 412729 }, -- Tamed Pet Passive (DND)
    { 1265038, 1265039, 1265040, 1265041, 1265042 }, -- Tendon Rip
    { 1265043, 1265045, 1265046, 1265047, 1265048 }, -- Tendon Rip
    { 467, 782, 1075, 8914, 9756, 9910 }, -- Thorns
    { 6343, 8198, 8204, 8205, 11580, 11581 }, -- Thunder Clap
    { 26090, 26187, 26188, 1264455 }, -- Thunderstomp
    { 26094, 26189, 26190, 1264456 }, -- Thunderstomp
    { 5217, 417045 }, -- Tiger's Fury
    { 3716, 7809, 7810, 7811, 11774, 11775 }, -- Torment
    { 2652, 2943, 19249, 19251, 19252, 19253, 19254, 19261, 19262, 19264, 19265, 19266 }, -- Touch of Weakness
    { 740, 8918, 9862, 9863 }, -- Tranquility
    { 19506, 20905, 20906, 1299346, 1299348 }, -- Trueshot Aura
    { 2878, 5627, 10326 }, -- Turn Undead
    { 12322, 12964 }, -- Unbridled Wrath
    { 1856, 1857 }, -- Vanish
    { 67, 9452 }, -- Vindication
    { 3034, 14279, 14280 }, -- Viper Sting
    { 1510, 14294, 14295 }, -- Volley
    { 29082, 29084, 29086, 29087, 29088 }, -- Weapon Mastery
    { 12281, 12284, 12700 }, -- Weaponmaster
    { 1265843, 1265878, 1265880, 1265881, 1265883 }, -- Web
    { 1265887, 1265888, 1265890, 1265891, 1265892 }, -- Web
    { 468, 16083 }, -- White Stallion
    { 408120, 1238214, 1238215 }, -- Wild Growth
    { 8512, 10613, 10614 }, -- Windfury Totem
    { 8232, 8235, 10486, 16362 }, -- Windfury Weapon
    { 15107, 15111, 15112 }, -- Windwall Totem
    { 2974, 14267, 14268 }, -- Wing Clip
    { 5176, 5177, 5178, 5179, 5180, 6780, 8905, 9912 }, -- Wrath
}

-- [1] = spell, [2] = cooldown; node = only with the talent, roles = the roles that use it
FV.KICKS = {
    DRUID = { { 410176, 10 }, { 1238122, 15, node = true } }, -- Skull Bash, Feral Charge
    MAGE = { { 2139, 30 } }, -- Counterspell
    PALADIN = { { 425609, 15 } }, -- Rebuke
    PRIEST = { { 15487, 45, node = true } }, -- Silence
    ROGUE = { { 1766, 10 } }, -- Kick
    SHAMAN = { { 8042, 6 } }, -- Earth Shock
    WARRIOR = { { 6552, 10, roles = { DAMAGER = true, HEALER = true } }, { 72, 12 } }, -- Pummel, Shield Bash
}
FV.SPELL_LOCK_CD = 30

-- class, kick, seconds left
FV.KICK_PREVIEW = {
    { "WARRIOR", 6552, 0 },
    { "MAGE", 2139, 9 },
    { "ROGUE", 1766, 0 },
    { "SHAMAN", 8042, 4 },
    { "PALADIN", 425609, 12 },
}

-- a slot shows the best one owned, first first
FV.POTION_GROUPS = {
    { 19013, 19012, 9421, 19011, 19010, 5510, 19009, 19008, 5509, 19007, 19006, 5511, 19005, 19004, 5512 }, -- Healthstone
    { 13446, 223913, 3928, 288896, 1710, 223914, 287977, 929, 858, 287967, 118, 287966 }, -- Healing Potion
    { 13444, 13443, 288897, 6149, 3827, 3385, 287969, 2455, 287968 }, -- Mana Potion
    { 18253, 2456 }, -- Rejuvenation Potion
    { 13442, 5633, 5631 }, -- Rage Potion
}
FV.CURATED_ITEMS = {
    5512, 13446, 13444, 18253, 13442, 5634, 3387, 2459, 9030, 13455, 20520, 12662,
}

-- preview icons of the Blizzard aura filters
FV.FILTER_SAMPLES = { BIG_DEFENSIVE = 642, EXTERNAL_DEFENSIVE = 1022, IMPORTANT = 10060 }

ns.Racials = {
    1259718, -- Will to Survive (Human)
    20600,   -- Perception (Human)
    20594,   -- Stoneform (Dwarf)
    20580,   -- Shadowmeld (Night Elf)
    1259799, -- Elune's Light (Night Elf)
    20589,   -- Escape Artist (Gnome)
    1259812, -- Eureka! (Gnome)
    1259813, -- Eureka! (Gnome)
    1259817, -- Eureka! (Gnome)
    1259821, -- Eureka! (Gnome)
    1259823, -- Eureka! (Gnome)
    20572,   -- Blood Fury (Orc)
    1299026, -- Shatter Curse (Orc)
    7744,    -- Will of the Forsaken (Undead)
    20577,   -- Cannibalize (Undead)
    20549,   -- War Stomp (Tauren)
    20554,   -- Berserking (Troll)
    1260270, -- Rapid Regeneration (Troll)
    1259705, -- Read Leyline (Skyborne)
    1259686, -- Skysight (Skyborne)
    1259416, -- Walk on Air (Skyborne)
}
ns.RacialSet = {}
for _, id in ipairs(ns.Racials) do ns.RacialSet[id] = true end

ns.AURA_COMMON = {
    10060,  -- Power Infusion
    29166,  -- Innervate
    6940,   -- Blessing of Sacrifice
    1022,   -- Blessing of Protection
    1044,   -- Blessing of Freedom
    402004, -- Pain Suppression
    6346,   -- Fear Ward
}

ns.AURA_PRESETS = {
    {
        key = "defensives", name = "Defensives", kind = "HELPFUL", unit = "player", max = 10,
        filter = "BIG_DEFENSIVE", spells = {},
    },
    {
        key = "externals", name = "Externals", kind = "HELPFUL", unit = "player", max = 10,
        spells = {
            6940,   -- Blessing of Sacrifice
            1022,   -- Blessing of Protection
            402004, -- Pain Suppression
            6346,   -- Fear Ward
        },
    },
    {
        key = "movement", name = "Movement Speed", kind = "HELPFUL", unit = "player", max = 10,
        spells = {
            1044,   -- Blessing of Freedom
            13159,  -- Aspect of the Pack
            5118,   -- Aspect of the Cheetah
            2983,   -- Sprint
            1850,   -- Dash
        },
    },
    {
        key = "drink", name = "Drink", kind = "HELPFUL", unit = "player", max = 1,
        spells = {
            430,    -- Drink
            431,    -- Drink
            432,    -- Drink
            1133,   -- Drink
            1135,   -- Drink
            1137,   -- Drink
            10250,  -- Drink
            22734,  -- Drink
            24355,  -- Drink
            25696,  -- Drink
            26261,  -- Drink
            26402,  -- Drink
            26473,  -- Drink
            26475,  -- Drink
            29007,  -- Drink
            167152, -- Refreshment
            446714, -- Drink
            468767, -- Drink
        },
    },
}

-- one spec per class here: the whole list sits on the class
ns.ClassSpells = {
    WARRIOR = {
        class = {
            6673,    -- Battle Shout
            871,     -- Shield Wall
            1719,    -- Recklessness
            20230,   -- Retaliation
            12975,   -- Last Stand
            12328,   -- Death Wish
            18499,   -- Berserker Rage
            2687,    -- Bloodrage
            5246,    -- Intimidating Shout
            426490,  -- Rallying Cry
            6552,    -- Pummel
            72,      -- Shield Bash
            100,     -- Charge
            20252,   -- Intercept
            2565,    -- Shield Block
            1161,    -- Challenging Shout
        },
        specs = {},
    },
    PALADIN = {
        class = {
            642,     -- Divine Shield
            498,     -- Divine Protection
            633,     -- Lay on Hands
            1022,    -- Blessing of Protection
            6940,    -- Blessing of Sacrifice
            1044,    -- Blessing of Freedom
            407788,  -- Avenging Wrath
            853,     -- Hammer of Justice
            425609,  -- Rebuke
            20216,   -- Divine Favor
            20473,   -- Holy Shock
            20066,   -- Repentance
            19752,   -- Divine Intervention
        },
        specs = {},
    },
    HUNTER = {
        class = {
            3045,    -- Rapid Fire
            19574,   -- Bestial Wrath
            409379,  -- Kill Command
            19263,   -- Deterrence
            5384,    -- Feign Death
            781,     -- Disengage
            5118,    -- Aspect of the Cheetah
            13159,   -- Aspect of the Pack
            1499,    -- Freezing Trap
            19503,   -- Scatter Shot
        },
        specs = {},
    },
    ROGUE = {
        class = {
            5277,    -- Evasion
            2983,    -- Sprint
            1856,    -- Vanish
            1766,    -- Kick
            408,     -- Kidney Shot
            2094,    -- Blind
            1776,    -- Gouge
            14177,   -- Cold Blood
            13750,   -- Adrenaline Rush
            13877,   -- Blade Flurry
            14185,   -- Preparation
        },
        specs = {},
    },
    PRIEST = {
        class = {
            10060,   -- Power Infusion
            402004,  -- Pain Suppression
            6346,    -- Fear Ward
            8122,    -- Psychic Scream
            14751,   -- Inner Focus
            15487,   -- Silence
            13908,   -- Desperate Prayer
            401977,  -- Shadowfiend
            425294,  -- Dispersion
            425207,  -- Power Word: Barrier
        },
        specs = {},
    },
    SHAMAN = {
        class = {
            8042,    -- Earth Shock
            16190,   -- Mana Tide Totem
            16188,   -- Nature's Swiftness
            409324,  -- Ancestral Guidance
            8177,    -- Grounding Totem
            2645,    -- Ghost Wolf
            408521,  -- Riptide
        },
        specs = {},
    },
    MAGE = {
        class = {
            2139,    -- Counterspell
            11958,   -- Ice Block
            122,     -- Frost Nova
            1953,    -- Blink
            12042,   -- Arcane Power
            12043,   -- Presence of Mind
            11129,   -- Combustion
            425121,  -- Icy Veins
            12472,   -- Cold Snap
            12051,   -- Evocation
            11426,   -- Ice Barrier
        },
        specs = {},
    },
    WARLOCK = {
        class = {
            6789,    -- Death Coil
            5484,    -- Howl of Terror
            18288,   -- Amplify Curse
            403789,  -- Metamorphosis
            425463,  -- Demonic Grace
            19647,   -- Spell Lock
        },
        specs = {},
    },
    DRUID = {
        class = {
            22812,   -- Barkskin
            29166,   -- Innervate
            740,     -- Tranquility
            1850,    -- Dash
            22842,   -- Frenzied Regeneration
            5211,    -- Bash
            17116,   -- Nature's Swiftness
            18562,   -- Swiftmend
            410176,  -- Skull Bash
            1238122, -- Feral Charge
            408024,  -- Survival Instincts
            417141,  -- Berserk
            5217,    -- Tiger's Fury
            439748,  -- Starfall
            5209,    -- Challenging Roar
        },
        specs = {},
    },
}
