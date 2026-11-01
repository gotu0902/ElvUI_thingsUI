local _, ns = ...

-- 12.1.5 values; check each season (kicks, cooldowns, the talents that change them)
local KD = {}
ns.KickData = KD

local function Specs(...)
    local t = {}
    for i = 1, select("#", ...) do t[select(i, ...)] = true end
    return t
end

-- [1] = spell, [2] = cooldown; first one fits a member of unknown spec; node = a read tree without it has no kick
local BY_CLASS = {
    DEATHKNIGHT = { { 47528, 15, node = true } },
    DEMONHUNTER = { { 183752, 15 } },
    DRUID = {
        { 106839, 15, specs = Specs(103, 104), node = true },
        { 78675, 60, specs = Specs(102), node = true },
    },
    EVOKER = { { 351338, 20, specs = Specs(1467, 1473), node = true } },
    HUNTER = {
        { 147362, 24, specs = Specs(253, 254), node = true },
        { 187707, 15, specs = Specs(255), node = true },
    },
    MAGE = { { 2139, 25 } },
    MONK = { { 116705, 15, specs = Specs(268, 269), node = true } },
    PALADIN = { { 96231, 15, specs = Specs(66, 70), node = true } },
    PRIEST = { { 15487, 30, specs = Specs(258) } },
    ROGUE = { { 1766, 15 } },
    SHAMAN = { { 57994, 12, node = true } },
    WARRIOR = { { 6552, 15 } },
}

local SPELL_LOCK, AXE_TOSS, SACRIFICE_LOCK = 19647, 89766, 132409
local GRIMOIRE_OF_SACRIFICE = 108503
local CD = { [SPELL_LOCK] = 24, [AXE_TOSS] = 30, [SACRIFICE_LOCK] = 24 }

-- the demon out, by creature ID
KD.DEMONS = { [417] = SPELL_LOCK, [17252] = AXE_TOSS, [58965] = AXE_TOSS, [110397] = AXE_TOSS }

-- the meter keeps these under the demon, not its warlock
local ON_DEMON = { [SPELL_LOCK] = true, [AXE_TOSS] = true }

-- pct and flat apply to every use, landed only after a kick that stopped a cast
local MOD = {
    [2139] = { talent = 382297, flat = -5 },     -- Quick Witted
    [6552] = { talent = 391271, pct = -10 },     -- Honed Reflexes
    [47528] = { talent = 378848, landed = -3 },  -- Coldthirst
    [78675] = { talent = 202918, landed = -15 }, -- Light of the Sun
    [57994] = { spec = 264, flat = 18 },         -- Restoration
}

-- the healing spec a healer of unknown spec is read as
local HEALER_SPEC = { DRUID = 105, EVOKER = 1468, MONK = 270, PALADIN = 65, PRIEST = 257, SHAMAN = 264 }

-- spells a talent read looks for
KD.TALENTS = { [GRIMOIRE_OF_SACRIFICE] = true }

-- what a cast of yours or your demon's counts as: the demon commands are the spells in your book
local CASTS = { [119910] = SPELL_LOCK, [119914] = AXE_TOSS, [SPELL_LOCK] = SPELL_LOCK,
    [AXE_TOSS] = AXE_TOSS, [SACRIFICE_LOCK] = SACRIFICE_LOCK }

for _, list in pairs(BY_CLASS) do
    for _, k in ipairs(list) do
        CD[k[1]] = k[2]
        CASTS[k[1]] = k[1]
        if k.node then KD.TALENTS[k[1]] = true end
    end
end
for _, m in pairs(MOD) do
    if m.talent then KD.TALENTS[m.talent] = true end
end

function KD.CastKick(spellID) return CASTS[spellID] end
function KD.OnDemon(spellID) return ON_DEMON[spellID] or false end

-- the member's kick and the spec it was read for; talents nil = tree not read, demon = the kick of the demon out
function KD.Pick(class, spec, role, talents, demon)
    if not spec and role == "HEALER" then spec = HEALER_SPEC[class] end
    if class == "WARLOCK" then
        if demon then return demon, spec end
        if talents and talents[GRIMOIRE_OF_SACRIFICE] then return SACRIFICE_LOCK, spec end
        return (spec == 266) and AXE_TOSS or SPELL_LOCK, spec
    end
    for _, k in ipairs(BY_CLASS[class] or {}) do
        local specOK = not (spec and k.specs) or k.specs[spec]
        local nodeOK = not (k.node and talents) or talents[k[1]]
        if specOK and nodeOK then return k[1], spec end
    end
    return nil, spec
end

-- cooldown, and the cooldown after a kick that landed
function KD.Cooldown(spellID, spec, talents)
    local cd = CD[spellID]
    if not cd then return nil end
    local landed = 0
    local m = MOD[spellID]
    if m and ((m.talent and talents and talents[m.talent]) or (m.spec and m.spec == spec)) then
        cd = cd * (1 + (m.pct or 0) / 100) + (m.flat or 0)
        landed = m.landed or 0
    end
    return cd, cd + landed
end
