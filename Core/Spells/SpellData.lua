local _, ns = ...

ns.ClassSpells = {
    WARRIOR = {
        class = {
            6673,   -- Battle Shout
            97462,  -- Rallying Cry
            23920,  -- Spell Reflection
            18499,  -- Berserker Rage
            107574, -- Avatar
            6552,   -- Pummel
            5246,   -- Intimidating Shout
            6544,   -- Heroic Leap
            386208, -- Defensive Stance
        },
        specs = {
            [71] = { 118038 },     -- Arms: Die by the Sword
            [72] = { 1719, 184364 }, -- Fury: Recklessness, Enraged Regeneration
            [73] = { 12975, 190456, 2565, 871 }, -- Protection: Last Stand, Ignore Pain, Shield Block, Shield Wall
        },
    },
    PALADIN = {
        class = {
            642,    -- Divine Shield
            498,    -- Divine Protection
            633,    -- Lay on Hands
            1022,   -- Blessing of Protection
            6940,   -- Blessing of Sacrifice
            1044,   -- Blessing of Freedom
            31884,  -- Avenging Wrath
            375576, -- Divine Toll
            853,    -- Hammer of Justice
            96231,  -- Rebuke
        },
        specs = {
            [65] = { 31821 },          -- Holy: Aura Mastery
            [66] = { 204018, 31850, 86659 }, -- Protection: Spellwarding, Ardent Defender, Guardian of Ancient Kings
            [70] = {},                 -- Retribution
        },
    },
    HUNTER = {
        class = {
            186265, -- Aspect of the Turtle
            109304, -- Exhilaration
            186257, -- Aspect of the Cheetah
            5384,   -- Feign Death
            34477,  -- Misdirection
            19577,  -- Intimidation
        },
        specs = {
            [253] = { 19574, 272678 }, -- Beast Mastery: Bestial Wrath, Primal Rage (pet)
            [254] = { 288613, 147362 }, -- Marksmanship: Trueshot, Counter Shot
            [255] = { 360952, 187707, 264735 }, -- Survival: Coordinated Assault, Muzzle, Survival of the Fittest
        },
    },
    ROGUE = {
        class = {
            31224,  -- Cloak of Shadows
            5277,   -- Evasion
            1856,   -- Vanish
            1966,   -- Feint
            185311, -- Crimson Vial
            1766,   -- Kick
            57934,  -- Tricks of the Trade
            2094,   -- Blind
            2983,   -- Sprint
        },
        specs = {
            [259] = {},               -- Assassination
            [260] = { 13750 },        -- Outlaw: Adrenaline Rush
            [261] = { 121471, 212283, 185313 }, -- Subtlety: Shadow Blades, Symbols of Death, Shadow Dance
        },
    },
    PRIEST = {
        class = {
            17,     -- Power Word: Shield
            19236,  -- Desperate Prayer
            10060,  -- Power Infusion
            586,    -- Fade
            32375,  -- Mass Dispel
            73325,  -- Leap of Faith
            8122,   -- Psychic Scream
            64843,  -- Divine Hymn
        },
        specs = {
            [256] = { 62618, 33206 }, -- Discipline: Power Word: Barrier, Pain Suppression
            [257] = { 47788 },        -- Holy: Guardian Spirit
            [258] = { 47585, 15286, 15487 }, -- Shadow: Dispersion, Vampiric Embrace, Silence
        },
    },
    DEATHKNIGHT = {
        class = {
            48707,  -- Anti-Magic Shell
            48792,  -- Icebound Fortitude
            49039,  -- Lichborne
            51052,  -- Anti-Magic Zone
            42650,  -- Army of the Dead
            61999,  -- Raise Ally
            49576,  -- Death Grip
            47528,  -- Mind Freeze
            48743, --  Death Pact
            327574, -- Sacrificial Pact
        },
        specs = {
            [250] = { 55233, 49028 }, -- Blood: Vampiric Blood, Dancing Rune Weapon
            [251] = { 51271 },        -- Frost: Pillar of Frost
            [252] = {},               -- Unholy
        },
    },
    SHAMAN = {
        class = {
            108271, -- Astral Shift
            2825,   -- Bloodlust
            32182,  -- Heroism
            192058, -- Capacitor Totem
            57994,  -- Wind Shear
            8143,   -- Tremor Totem
            198103, -- Earth Elemental
        },
        specs = {
            [262] = { 198067, 192249 }, -- Elemental: Fire Elemental, Storm Elemental
            [263] = { 51533 },          -- Enhancement: Feral Spirit
            [264] = { 108280, 98008, 79206, 974 }, -- Restoration: Healing Tide, Spirit Link, Spiritwalker's Grace, Earth Shield
        },
    },
    MAGE = {
        class = {
            45438,  -- Ice Block
            55342,  -- Mirror Image
            2139,   -- Counterspell
            30449,  -- Spellsteal
            80353,  -- Time Warp
            66,     -- Invisibility
            1953,   -- Blink
        },
        specs = {
            [62] = { 110959, 235450 }, -- Arcane: Greater Invisibility, Prismatic Barrier
            [63] = { 190319, 235313 }, -- Fire: Combustion, Blazing Barrier
            [64] = { 12472, 11426 },   -- Frost: Icy Veins, Ice Barrier
        },
    },
    WARLOCK = {
        class = {
            104773, -- Unending Resolve
            108416, -- Dark Pact
            20707,  -- Soulstone
            48020,  -- Demonic Circle: Teleport
            111771, -- Demonic Gateway
            710,    -- Banish
            5782,   -- Fear
            6789,   -- Mortal Coil
            5484,   -- Howl of Terror
        },
        specs = {
            [265] = {},               -- Affliction
            [266] = { 265187, 89766 }, -- Demonology: Summon Demonic Tyrant, Axe Toss (Felguard)
            [267] = { 1122 },         -- Destruction: Summon Infernal
        },
    },
    MONK = {
        class = {
            115203, -- Fortifying Brew
            119381, -- Leg Sweep
            116705, -- Spear Hand Strike
            116844, -- Ring of Peace
            101643, -- Transcendence
        },
        specs = {
            [268] = { 322507 },        -- Brewmaster: Celestial Brew
            [269] = { 122470, 137639, 123904 }, -- Windwalker: Touch of Karma, SEF, Invoke Xuen
            [270] = { 116849, 115310 }, -- Mistweaver: Life Cocoon, Revival
        },
    },
    DRUID = {
        class = {
            22812,  -- Barkskin
            108238, -- Renewal
            20484,  -- Rebirth
            29166,  -- Innervate
            106898, -- Stampeding Roar
            391528, -- Convoke the Spirits
        },
        specs = {
            [102] = { 194223, 78675 }, -- Balance: Celestial Alignment, Solar Beam
            [103] = { 106951, 106839 }, -- Feral: Berserk, Skull Bash
            [104] = { 61336, 22842, 192081 }, -- Guardian: Survival Instincts, Frenzied Regeneration, Ironfur
            [105] = {},                -- Restoration
        },
    },
    DEMONHUNTER = {
        class = {
            198589, -- Blur
            196718, -- Darkness
            179057, -- Chaos Nova
            183752, -- Disrupt
            188501, -- Spectral Sight
            217832, -- Imprison
            370965, -- The Hunt
        },
        specs = {
            [577] = { 191427 },        -- Havoc: Metamorphosis
            [581] = { 187827, 212084, 203720, 204021 }, -- Vengeance: Metamorphosis, Fel Devastation, Demon Spikes, Fiery Brand
        },
    },
    EVOKER = {
        class = {
            363916, -- Obsidian Scales
            374348, -- Renewing Blaze
            374227, -- Zephyr
            370665, -- Rescue
            351338, -- Quell
            374251, -- Cauterizing Flame
            364342, -- Blessing of the Bronze
        },
        specs = {
            [1467] = { 375087 },          -- Devastation: Dragonrage
            [1468] = { 370960, 363534, 370553 }, -- Preservation: Emerald Communion, Rewind, Tip the Scales
            [1473] = { 374968 },          -- Augmentation: Time Spiral
        },
    },
}

-- Class tab list
function ns.GetClassSpellList(classFile)
    local c = ns.ClassSpells[classFile]; if not c then return {} end
    local out, seen = {}, {}
    local function add(id) if id and not seen[id] then seen[id] = true; out[#out + 1] = id end end
    for _, id in ipairs(c.class or {}) do add(id) end
    for _, list in pairs(c.specs or {}) do for _, id in ipairs(list) do add(id) end end
    return out
end

-- Spec tab list
function ns.GetSpecSpellList(specID)
    local m = ns.SpecMeta and ns.SpecMeta(specID)
    local cf = m and m.classToken
    local c = cf and ns.ClassSpells[cf]; if not c then return {} end
    local out, seen = {}, {}
    local function add(id) if id and not seen[id] then seen[id] = true; out[#out + 1] = id end end
    for _, id in ipairs(c.class or {}) do add(id) end
    for _, id in ipairs((c.specs or {})[specID] or {}) do add(id) end
    return out
end

ns.Racials = {
    59752,   -- Will to Survive (Human)
    20594,   -- Stoneform (Dwarf)
    58984,   -- Shadowmeld (Night Elf)
    20589,   -- Escape Artist (Gnome)
    28880,   -- Gift of the Naaru (Draenei)
    68992,   -- Darkflight (Worgen)
    20572,   -- Blood Fury (Orc)
    7744,    -- Will of the Forsaken (Undead)
    20577.   -- Cannibalize (Undead)
    20549,   -- War Stomp (Tauren)
    26297,   -- Berserking (Troll)
    202719,  -- Arcane Torrent (Blood Elf)
    69070,   -- Rocket Jump (Goblin)
    69041,   -- Rocket Barrage (Goblin)
    256948,  -- Spatial Rift (Void Elf)
    255647,  -- Light's Judgment (Light Draenei)
    287712,  -- Haymaker (Kul Tiran)
    265221,  -- Fireblood (Red Dwarf)
    291944,  -- Regeneratin' (Zandalari)
    312411,  -- Bag of Tricks (Furry)
    312924,  -- Hyper Organic Light Originator (Mechagnome)
    107079,  -- Quaking Palm (Panda)
    368970,  -- Tail Swipe (Dragon)
    357214,  -- Wing Buffet (Dragon)
    436344,  -- Azerite Surge (Earthen)
    1237885, -- Thorn Bloom (Haranir)
    274738,  -- Ancestral Call (Mag'har Orc)
    255654,  -- Bull Rush (Highmountain Tauren)
    260364,  -- Arcane Pulse (Nightborne)
}
ns.RacialSet = {}
for _, id in ipairs(ns.Racials) do ns.RacialSet[id] = true end
