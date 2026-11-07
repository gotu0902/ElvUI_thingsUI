local _, ns = ...

ns.CDHelpers = ns.CDHelpers or {}
local H = ns.CDHelpers

local C_Spell, C_Item = C_Spell, C_Item

local function IsSecret(v)
    if issecretvalue and issecretvalue(v) then return true end
    return false
end
H.IsSecret = IsSecret

local function NotSecret(v)
    if issecretvalue and issecretvalue(v) then return false end
    return v ~= nil
end
H.NotSecret = NotSecret

-- one engine call into a reused table instead of select(i, frame:GetChildren()) per index
local function PackInto(out, ...)
    local n = select("#", ...)
    for i = 1, n do out[i] = (select(i, ...)) end
    for i = n + 1, #out do out[i] = nil end
    return n
end
function H.ChildrenInto(frame, out) return PackInto(out, frame:GetChildren()) end
function H.RegionsInto(frame, out) return PackInto(out, frame:GetRegions()) end

local desatCurve
local function GetDesatCurve()
    if desatCurve ~= nil then return desatCurve or nil end
    if not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step) then
        desatCurve = false; return nil
    end
    local c = C_CurveUtil.CreateCurve()
    if c then
        c:SetType(Enum.LuaCurveType.Step)
        c:AddPoint(0, 0)
        c:AddPoint(0.001, 1)
    end
    desatCurve = c or false
    return c
end
H.GetDesatCurve = GetDesatCurve

local function SetDesat(icon, v)
    if not icon then return end
    if icon.SetDesaturation then icon:SetDesaturation(v)
    elseif icon.SetDesaturated then icon:SetDesaturated(v > 0) end
end
H.SetDesat = SetDesat

local function SetCooldownFromDuration(cd, durationObject)
    if not (cd and durationObject) then return end
    if cd.SetCooldownFromDurationObject then
        cd:SetCooldownFromDurationObject(durationObject, true)
    end
end
H.SetCooldownFromDuration = SetCooldownFromDuration

-- an item's GCD reads as a short cooldown: keep its swipe, desaturate only past it (Blizzard CDM does the same)
local ITEM_GCD_MAX = 1.5
H.ITEM_GCD_MAX = ITEM_GCD_MAX
local function ItemCooldown(itemID)
    local start, dur = C_Item.GetItemCooldown(itemID)
    local active = (start and dur and dur > 0) or false
    return start, dur, active, active and dur > ITEM_GCD_MAX
end
H.ItemCooldown = ItemCooldown

local function ItemCooldownChanged(cd, active, start, dur)
    if not cd then return false end
    local oldStart, oldDur = cd:GetCooldownTimes()
    oldStart, oldDur = (tonumber(oldStart) or 0), (tonumber(oldDur) or 0)
    if active then
        if oldStart <= 0 or oldDur <= 0 then return true end
        local oldEnd = (oldStart + oldDur) / 1000
        local newEnd = (start or 0) + (dur or 0)
        return math.abs(oldEnd - newEnd) > 0.01
    end
    return oldStart > 0 and oldDur > 0
end
H.ItemCooldownChanged = ItemCooldownChanged

local function SpellDesat(btn, id)
    local icon = btn.icon
    if not icon then return end
    local curve = GetDesatCurve()
    local cd = C_Spell.GetSpellCooldown(id)
    if cd and cd.isOnGCD then SetDesat(icon, 0); return end
    local charges = C_Spell.GetSpellCharges(id)
    if charges and (charges.maxCharges or 0) > 1 then
        local cur = charges.currentCharges
        if not IsSecret(cur) then
            if (cur or 0) > 0 then SetDesat(icon, 0); return end
            local chargeDur = C_Spell.GetSpellChargeDuration and C_Spell.GetSpellChargeDuration(id)
            if chargeDur and curve and type(chargeDur.EvaluateRemainingDuration) == "function" then
                SetDesat(icon, chargeDur:EvaluateRemainingDuration(curve, 0))
            else SetDesat(icon, 0) end
            return
        end
    end
    local durObj = C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(id)
    if durObj and curve and type(durObj.EvaluateRemainingDuration) == "function" then
        SetDesat(icon, durObj:EvaluateRemainingDuration(curve, 0))
    else SetDesat(icon, 0) end
end
H.SpellDesat = SpellDesat

local function TimerActive(timer, now)
    local T = ns.Timers
    if T.GetActiveBuff(timer, now) then return true end
    if timer.trackCooldown == false then return false end
    if timer.kind == "item" and timer.itemID then
        return (select(4, ItemCooldown(timer.itemID)))
    elseif timer.kind == "spell" and timer.spellID then
        local durObj = C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(timer.spellID)
        local curve = GetDesatCurve()
        if durObj and curve and durObj.EvaluateRemainingDuration then
            return durObj:EvaluateRemainingDuration(curve, 0) > 0
        end
    end
    return false
end
H.TimerActive = TimerActive

-- ------------------------------------------------------------- can you cast it

-- Blizzard's tints on its own CDM icons
H.CAST_TINT = { noMana = { r = 0.5, g = 0.5, b = 1 }, unusable = { r = 0.4, g = 0.4, b = 0.4 } }

local castCache = {}
function H.ResetCastCache() wipe(castCache) end

local function Known(id) return C_SpellBook.IsSpellKnown(id) end

-- the spell you cast for this ID (highest known rank, else the known spell by name); false when you don't
function H.CastID(id)
    if not id then return false end
    local hit = castCache[id]
    if hit ~= nil then return hit end
    local best = false
    for _, r in ipairs(ns.SpellRanks(id) or {}) do
        if Known(r) then best = r end
    end
    if not best and Known(id) then best = id end
    if not best then
        local name = C_Spell.GetSpellName(id)
        local info = NotSecret(name) and C_Spell.GetSpellInfo(name)
        local kid = info and info.spellID
        if NotSecret(kid) and Known(kid) then best = kid end
    end
    castCache[id] = best
    return best
end

-- "noMana" / "unusable" / false (castable); nil when the game won't say
function H.CastState(id)
    local cid = H.CastID(id)
    if not cid then return false end
    local usable, noMana = C_Spell.IsSpellUsable(cid)
    if IsSecret(usable) or IsSecret(noMana) then return nil end
    if usable then return false end
    return noMana and "noMana" or "unusable"
end

-- Spell Editor (cooldowns) entries with a When You Can't Cast It look
local lookIDs
function H.InvalidateCastLooks() lookIDs = nil end
local function LookIDs()
    if lookIDs then return lookIDs end
    lookIDs = {}
    local E = ns.E
    local cdm = E and E.db and E.db.thingsUI and E.db.thingsUI.cdmIcons
    for id, o in pairs((cdm and cdm.perSpell) or {}) do
        if type(o) == "table" and (o.noMana or o.unusable) then lookIDs[id] = o end
    end
    return lookIDs
end
function H.AnyCastLook() return next(LookIDs()) ~= nil end

-- the look for a spell: its own entry, else one on another rank of it
function H.CastLook(id)
    if not id then return nil end
    local ids = LookIDs()
    if ids[id] then return ids[id] end
    for _, r in ipairs(ns.SpellRanks(id) or {}) do
        if ids[r] then return ids[r] end
    end
end

-- tell the hosts when a looked spell turns castable or not
local castFns, castLast = {}, {}
function H.OnCastChange(fn) castFns[#castFns + 1] = fn end
do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("SPELL_UPDATE_USABLE")
    ev:RegisterEvent("SPELLS_CHANGED")
    ev:SetScript("OnEvent", function(_, event)
        if event == "SPELLS_CHANGED" then wipe(castCache) end
        local changed = false
        for id in pairs(LookIDs()) do
            local st = H.CastState(id)
            if st ~= nil and st ~= castLast[id] then
                castLast[id] = st
                changed = true
            end
        end
        if changed then
            for i = 1, #castFns do castFns[i]() end
        end
    end)
end

-- one of our own buttons: the look for its spell's state, over the cooldown's own desaturation
function H.ApplyCastLook(btn, spellID)
    local look = H.CastLook(spellID)
    local st = false
    if look then
        st = H.CastState(spellID)
        if st == nil then st = btn._castSt or false end
    end
    btn._castSt = st
    local o = st and look[st]
    if type(o) ~= "table" then o = nil end
    local a = (o and o.alpha) or 1
    if a < 1 or btn._castA then
        btn:SetAlpha(a)
        btn._castA = (a < 1) or nil
    end
    local icon = btn.icon
    if not icon then return end
    if o and o.desat then SetDesat(icon, 1) end
    local tint = o and o.tint and (o.color or H.CAST_TINT[st])
    if tint then
        icon:SetVertexColor(tint.r, tint.g, tint.b)
    elseif btn._castTint then
        icon:SetVertexColor(1, 1, 1)
    end
    btn._castTint = tint and true or nil
end
