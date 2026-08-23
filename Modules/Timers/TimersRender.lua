local _, ns = ...
local E = ns.E

ns.TimersRender = ns.TimersRender or {}
local R = ns.TimersRender

local CreateFrame, GetTime, C_Spell, C_Item = CreateFrame, GetTime, C_Spell, C_Item

local H = ns.CDHelpers
local SetCooldownObj      = H.SetCooldownFromDuration
local SetDesat            = H.SetDesat
local ItemCooldownChanged = H.ItemCooldownChanged
local SpellDesat          = H.SpellDesat
local TimerActive         = H.TimerActive
R.TimerActive = TimerActive

local STYLE_MAP = { pixel = "pixel", autocast = "ants", proc = "proc", button = "proc", pulse = "pulse" }
local _stopOpts = {}

local function FXStore(btn)
    local r = btn._tuiFX
    if not r then r = {}; btn._tuiFX = r end
    return r
end

local function GlowActiveNow(timer)
    local T = ns.Timers
    return T.GetActiveBuff and T.GetActiveBuff(timer, GetTime()) ~= nil
end

function R.UpdateGlow(btn, timer)
    local A = ns.AuraLane
    if not (A and A.ApplyButtonFX and btn) then return end
    local stOpts
    if timer and timer.styleName and A.GlowOptsFor then
        stOpts = A.GlowOptsFor(nil, { styleName = timer.styleName })
    end
    local ready
    if timer and (timer.glowReadyInCombat or stOpts) then
        if ns.CustomGroups and ns.CustomGroups.testMode then
            ready = true
        else
            local mode = timer.glowWhen or "active"
            if mode == "active" then
                ready = GlowActiveNow(timer)
            else
                ready = ns.Timers.IsInCombat() and not TimerActive(timer, GetTime())
            end
        end
    end
    if not ready then
        if btn._glowSig then
            btn._glowSig = nil
            A.ApplyButtonFX(btn, FXStore(btn), _stopOpts)
        end
        return
    end
    if timer.styleName then
        -- style owns the glow look
        if not stOpts then
            if btn._glowSig then
                btn._glowSig = nil
                A.ApplyButtonFX(btn, FXStore(btn), _stopOpts)
            end
            return
        end
        local w = math.floor((btn:GetWidth() or 36) + 0.5)
        local h = math.floor((btn:GetHeight() or 36) + 0.5)
        stOpts.w, stOpts.h = w, h
        local c = stOpts.color or {}
        local sig = table.concat({ "st", timer.styleName, stOpts.style or "",
            c.r or 1, c.g or 1, c.b or 0, stOpts.thickness or 0,
            stOpts.outline and 1 or 0, w, h }, "|")
        if btn._glowSig == sig then return end
        btn._glowSig = sig
        A.ApplyButtonFX(btn, FXStore(btn), stOpts)
        return
    end
    local style = STYLE_MAP[timer.glowType or "pixel"] or "pixel"
    local gc = timer.glowColor
    local th = timer.glowThickness or 2
    local n = math.min(12, timer.glowN or 8)
    local freq = math.abs(timer.glowFrequency or 0.25)
    local len = math.min(6, timer.glowLength or 3)
    local off = timer.glowOffset or 0
    local w = math.floor((btn:GetWidth() or 36) + 0.5)
    local h = math.floor((btn:GetHeight() or 36) + 0.5)
    local outline = timer.glowBorderStroke and true or false
    local sig = table.concat({ style, gc and gc.r or 1, gc and gc.g or 1, gc and gc.b or 0,
        n, freq, len, th, off, outline and 1 or 0, w, h }, "|")
    if btn._glowSig == sig then return end
    btn._glowSig = sig
    A.ApplyButtonFX(btn, FXStore(btn), {
        style = style, color = gc, thickness = th, outline = outline,
        lines = n, length = len, offset = off, frequency = freq, w = w, h = h,
    })
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
    if btn.cooldown and btn.cooldown.SetReverse then
        btn.cooldown:SetReverse(false)
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
