local addon, ns = ...

ns.AURA_COMMON = {
    10060,  -- Power Infusion
    406789, -- Spatial
    29166,  -- Innervate
    395152, -- Ebon Might
    410089, -- Prescience
    6940,   -- Blessing of Sacrifice
    1022,   -- Blessing of Protection
    1044,   -- Blessing of Freedom
    33206,  -- Pain Suppression
    47788,  -- Guardian Spirit
    102342, -- Ironbark
    116849, -- Life Cocoon
    357170, -- Time Dilation
}

ns.AURA_PRESETS = {
    {
        key = "externals", name = "Externals", kind = "HELPFUL", unit = "player", max = 10,
        spells = {
            6940,   -- Blessing of Sacrifice
            47788,  -- Guardian Spirit
            102342, -- Ironbark
            116849, -- Life Cocoon
            33206,  -- Pain Suppression
            357170, -- Time Dilation
            53480,  -- Roar of Sacrifice
            1022,   -- Blessing of Protection
            204018, -- Blessing of Spellwarding
        },
    },
    {
        key = "bloodlust", name = "Bloodlust", kind = "HELPFUL", unit = "player", max = 1,
        spells = {
            2825,    -- Bloodlust
            32182,   -- Heroism
            80353,   -- Time Warp
            390386,  -- Fury of the Aspects
            264667,  -- Primal Rage
            466904,  -- Fury of the Aspects
            1243972, -- Void-Touched Drums
        },
    },
    {
        key = "raiddefensives", name = "Raid Defensives", kind = "HELPFUL", unit = "player", max = 1,
        spells = {
            31821,  -- Aura Mastery
            97462,  -- Rally
            64901,  -- Symbol of Hope
            374227, -- Zephyr
            325174, -- SLT
            145629, -- AMZ
            209426, -- Darkness
        },
    },
    {
        key = "timespiral", name = "Time Spiral", kind = "HELPFUL", unit = "player", max = 1,
        spells = {
            375226, 375229, 375230, 375234, 375238, 375240,
            375252, 375253, 375254, 375255, 375256, 375257, 375258,
        },
    },
    {
        key = "movement", name = "Movement Speed", kind = "HELPFUL", unit = "player", max = 10,
        spells = {
            106898, -- Stampeding Roar
            68992,  -- Darkflight
            116841, -- Tiger's Lust
            192082, -- WRT
            406789, -- Spatial
            434029, -- Vampiric Speed
            115834, -- Shroud
            65081,  -- Body and Soul
            1044,   -- Blessing of Freedom
        },
    },
}
