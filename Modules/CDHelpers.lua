local _, ns = ...

ns.CDHelpers = ns.CDHelpers or {}
local H = ns.CDHelpers

local C_Spell, C_Item = C_Spell, C_Item

local function IsSecret(v)
    return v ~= nil and type(issecretvalue) == "function" and issecretvalue(v)
end
H.IsSecret = IsSecret

local function NotSecret(v)
    return v ~= nil and not (issecretvalue and issecretvalue(v))
end
H.NotSecret = NotSecret

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
    if timer.kind == "lust" then return (T.GetLustState(now)) ~= nil end
    if T.GetActiveBuff(timer, now) then return true end
    if timer.trackCooldown == false then return false end
    if timer.kind == "item" and timer.itemID then
        local _, dur = C_Item.GetItemCooldown(timer.itemID)
        return (dur or 0) > 0
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
