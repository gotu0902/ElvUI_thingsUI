local _, ns = ...
local E = ns.E
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

ns.TimersRender = ns.TimersRender or {}
local R = ns.TimersRender

local CreateFrame, GetTime, C_Spell, C_Item = CreateFrame, GetTime, C_Spell, C_Item

local function SetCooldownObj(cd, durationObject)
    if not (cd and durationObject) then return end
    if cd.SetCooldownFromDurationObject then
        cd:SetCooldownFromDurationObject(durationObject, true)
    end
end

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

local function IsSecret(v)
    return v ~= nil and type(issecretvalue) == "function" and issecretvalue(v)
end

local function SetDesat(icon, v)
    if not icon then return end
    if icon.SetDesaturation then icon:SetDesaturation(v)
    elseif icon.SetDesaturated then icon:SetDesaturated(v > 0) end
end

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

local function TimerActive(timer, now)
    local T = ns.Timers
    if timer.kind == "lust" then return (T.GetLustState(now)) ~= nil end
    if T.GetActiveBuff(timer, now) then return true end
    if timer.trackCooldown == false then return false end  -- buff-only timer: ignore the CD phase
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
R.TimerActive = TimerActive

local GLOW_KEY = "tuiTimer"
local _glowCol = { 1, 1, 0, 1 }
local _procOpts = { color = _glowCol, duration = 0.25, key = GLOW_KEY }

local function StopGlow(btn)
    if not LCG then return end
    LCG.PixelGlow_Stop(btn, GLOW_KEY)
    LCG.AutoCastGlow_Stop(btn, GLOW_KEY)
    LCG.ButtonGlow_Stop(btn)
    LCG.ProcGlow_Stop(btn, GLOW_KEY)
end

local function GlowActiveNow(timer)
    local T = ns.Timers
    if timer.kind == "lust" then return T.GetLustState and T.GetLustState() ~= nil end
    return T.GetActiveBuff and T.GetActiveBuff(timer, GetTime()) ~= nil
end

function R.UpdateGlow(btn, timer)
    if not (LCG and btn) then return end
    local ready
    if timer and timer.glowReadyInCombat then
        local mode = (timer.kind == "lust") and "active" or (timer.glowWhen or "active")
        if mode == "active" then
            ready = GlowActiveNow(timer)
        else
            ready = ns.Timers.IsInCombat() and not TimerActive(timer, GetTime())
        end
    end
    if not ready then
        if btn._glowSig then btn._glowSig = nil; StopGlow(btn) end
        return
    end
    local gc = timer.glowColor or _glowCol
    local r, g, b, a = gc.r or 1, gc.g or 1, gc.b or 0, gc.a or 1
    local gtype = timer.glowType or "pixel"
    local n, freq, len = timer.glowN or 8, timer.glowFrequency or 0.25, timer.glowLength or 10
    local th, xo, yo = timer.glowThickness or 2, timer.glowXOffset or 0, timer.glowYOffset or 0
    local sig = table.concat({ gtype, r, g, b, n, freq, len, th, xo, yo }, "|")
    if btn._glowSig == sig then return end
    StopGlow(btn)
    btn._glowSig = sig
    _glowCol[1], _glowCol[2], _glowCol[3], _glowCol[4] = r, g, b, a
    if gtype == "autocast" then
        LCG.AutoCastGlow_Start(btn, _glowCol, n, freq, th, xo, yo, GLOW_KEY)
    elseif gtype == "proc" then
        _procOpts.color, _procOpts.duration = _glowCol, freq
        LCG.ProcGlow_Start(btn, _procOpts)
    elseif gtype == "button" then
        LCG.ButtonGlow_Start(btn, _glowCol)
    else
        LCG.PixelGlow_Start(btn, _glowCol, n, freq, len, th, xo, yo, false, GLOW_KEY)
    end
end
local UpdateGlow = R.UpdateGlow

local glowHosts = {}
function R.RegisterGlowHost(fn) if type(fn) == "function" then glowHosts[#glowHosts + 1] = fn end end

local glowTicker, glowAccum = CreateFrame("Frame"), 0
glowTicker:Hide()
function R.SetGlowActive(active) glowTicker:SetShown(active and true or false) end
glowTicker:SetScript("OnUpdate", function(_, elapsed)
    glowAccum = glowAccum + elapsed
    if glowAccum < 0.15 then return end
    glowAccum = 0
    if not InCombatLockdown() then return end
    for i = 1, #glowHosts do glowHosts[i]() end
end)

local LSM = E and E.Libs and E.Libs.LSM
local function StyleCount(btn, tc)
    local sig = (tc.countFont or "") .. "|" .. (tc.countFontSize or 12) .. "|"
        .. (tc.countFontOutline or "") .. "|" .. (tc.countPoint or "") .. "|"
        .. (tc.countXOffset or 0) .. "|" .. (tc.countYOffset or 0)
    if btn._countSig ~= sig then
        btn._countSig = sig
        local font = (LSM and LSM:Fetch("font", tc.countFont or "Expressway")) or STANDARD_TEXT_FONT
        E:SetFont(btn.count, font, tc.countFontSize or 12, tc.countFontOutline or "OUTLINE")
        local pt = tc.countPoint or "BOTTOMRIGHT"
        btn.count:ClearAllPoints()
        btn.count:SetPoint(pt, btn, pt, tc.countXOffset or 0, tc.countYOffset or 0)
    end
    local cc = tc.countColor or {}
    btn.count:SetTextColor(cc.r or 1, cc.g or 1, cc.b or 1)
end

local function UpdateItemCount(btn, timer)
    if not btn.count then return end
    local tc = timer.text
    if timer.kind == "item" and timer.itemID and tc and tc.showCount and timer.showIdle then
        local n = C_Item.GetItemCount(timer.itemID, false, true)  -- include charges
        btn.count:SetText((n and n > 0) and tostring(n) or "")
        StyleCount(btn, tc)
        btn.count:Show()
    else
        btn.count:SetText("")
        btn.count:Hide()
    end
end

function R.Update(btn, timer)
    if not (btn and timer) then return end
    local T = ns.Timers
    if btn.icon then
        local tex = T.GetTexture(timer)

        if tex and btn._tex ~= tex then btn.icon:SetTexture(tex); btn._tex = tex end
    end
    local now = GetTime()

    if timer.kind == "lust" then
        local phase, start, dur = T.GetLustState(now)
        if phase == "buff" then
            if ItemCooldownChanged(btn.cooldown, true, start, dur) then btn.cooldown:SetCooldown(start, dur) end
        else
            if ItemCooldownChanged(btn.cooldown, false) then btn.cooldown:Clear() end
        end
        SetDesat(btn.icon, 0)
        UpdateGlow(btn, timer, now)
        return
    end

    local bStart, bDur = T.GetActiveBuff(timer, now)
    if bStart and timer.showCDTimer then
        if ItemCooldownChanged(btn.cooldown, true, bStart, bDur) then btn.cooldown:SetCooldown(bStart, bDur) end
        SetDesat(btn.icon, 0)
    elseif timer.trackCooldown == false then

        if ItemCooldownChanged(btn.cooldown, false) then btn.cooldown:Clear() end
        SetDesat(btn.icon, 0)
    elseif timer.kind == "item" and timer.itemID then
        local start, dur = C_Item.GetItemCooldown(timer.itemID)
        local active = (start and dur and dur > 0) or false
        if active then
            if ItemCooldownChanged(btn.cooldown, true, start, dur) then btn.cooldown:SetCooldown(start, dur) end
            SetDesat(btn.icon, 1)
        else
            if ItemCooldownChanged(btn.cooldown, false, start, dur) then btn.cooldown:Clear() end
            SetDesat(btn.icon, 0)
        end
    elseif timer.kind == "spell" and timer.spellID then
        SetCooldownObj(btn.cooldown, C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(timer.spellID))
        SpellDesat(btn, timer.spellID)
    else
        btn.cooldown:Clear()
        SetDesat(btn.icon, 0)
    end
    UpdateItemCount(btn, timer)
    UpdateGlow(btn, timer, now)
end

function R.CreateButton(parent, name, onDone)
    local btn = CreateFrame("Button", name, parent)
    btn:EnableMouse(false)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    btn.icon = icon
    btn.Icon = icon 
    local cd = CreateFrame("Cooldown", name and (name .. "CD"), btn, "CooldownFrameTemplate")
    cd:SetAllPoints(btn)
    cd:EnableMouse(false)
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
    btn.cooldown = cd
    btn.Cooldown = cd

    local count = btn:CreateFontString(nil, "OVERLAY")
    count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    count:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    count:Hide()
    btn.count = count
    if onDone then cd:SetScript("OnCooldownDone", onDone) end
    local S = E.GetModule and E:GetModule("Skins", true)
    if S and S.HandleIcon and icon then S:HandleIcon(icon, true) end
    return btn
end
