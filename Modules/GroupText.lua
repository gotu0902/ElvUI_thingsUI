local _, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM
local H = ns.CDHelpers

-- Groups - Text: lines built from a format like "[name] [cd]". Auras ride the
-- Groups - Bars aura engine (the aura button fills [name] [cd] [stacks] itself,
-- secret or not); cooldowns are own lines over a hidden Cooldown frame whose
-- countdown is [cd], shown while the spell is on cooldown (alpha from the
-- engine's curve: the remaining time is secret in combat and never compared).

ns.GroupText = ns.GroupText or {}
local M = ns.GroupText

M.DEFAULT_FORMAT = "[name] [cd]"

-- [charges] is [stacks] on a cooldown line
local TOKENS = { name = "name", cd = "cd", stacks = "stacks", charges = "stacks" }

local parsed = {}
-- "[name] - [cd]" -> { {tok="name"}, {text=" - "}, {tok="cd"} }; unknown [words] stay text
function M.Parse(fmt)
    if not fmt or fmt == "" then fmt = M.DEFAULT_FORMAT end
    local p = parsed[fmt]
    if p then return p end
    p = {}
    local pos = 1
    for s, word, e in fmt:gmatch("()%[(%a+)%]()") do
        local tok = TOKENS[word:lower()]
        if tok then
            if s > pos then p[#p + 1] = { text = fmt:sub(pos, s - 1) } end
            p[#p + 1] = { tok = tok }
            pos = e
        end
    end
    if pos <= #fmt then p[#p + 1] = { text = fmt:sub(pos) } end
    parsed[fmt] = p
    return p
end

function M.FormatFor(group, def)
    local f = def and def.format
    if f and f ~= "" then return f end
    return group.format or M.DEFAULT_FORMAT
end

local COLOR_KEY = { name = "nameColor", cd = "durationColor", stacks = "stackColor" }
local WHITE = { r = 1, g = 1, b = 1 }

local function StyleSeg(fs, group, tok)
    E:SetFont(fs, LSM:Fetch("font", group.font or "Expressway"), group.fontSize or 14, group.fontOutline or "OUTLINE")
    ns.TextColor(fs, group[COLOR_KEY[tok] or "textColor"] or WHITE)
    fs:SetWordWrap(false)
end

-- UPPERCASE keeps color codes working
local function Upper(str)
    return (str:upper():gsub("|C(%x%x%x%x%x%x%x%x)", "|c%1"):gsub("|R", "|r"):gsub("|N", "|n"))
end
local function Cased(group, str)
    if str and group.textCase == "upper" then return Upper(str) end
    return str
end

local measure
local function Measure(group, str)
    measure = measure or UIParent:CreateFontString(nil, "OVERLAY")
    E:SetFont(measure, LSM:Fetch("font", group.font or "Expressway"), group.fontSize or 14, group.fontOutline or "OUTLINE")
    measure:SetText(str)
    return measure:GetStringWidth()
end

-- edge spaces become gaps: a piece's width may leave them out
local spaceW = {}
local function SpaceWidth(group)
    local key = (group.font or "") .. ":" .. (group.fontSize or 14) .. ":" .. (group.fontOutline or "")
    local w = spaceW[key]
    if w then return w end
    w = math.max(1, Measure(group, "x x") - Measure(group, "xx"))
    spaceW[key] = w
    return w
end

local function Literal(fs, text, sw, group)
    local l, body, t = text:match("^( *)(.-)( *)$")
    fs:SetText(Cased(group, body))
    fs._gapL, fs._gapR = #l * sw, #t * sw
end

-- _estW: a width guess for text the game writes (its real width can be secret)
local function NoGap(fs) fs._gapL, fs._gapR, fs._estW = 0, 0, nil end

-- the n-th own piece of a line
local function Piece(store, parent, n)
    local fs = store[n]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY")
        store[n] = fs
    end
    return fs
end

local function HideFrom(store, n)
    for i = n, #store do
        store[i]:SetText("")
        store[i]:Hide()
    end
end

-- side by side from the group's edge (or around its middle); each piece sizes to its own text
local function Chain(list, host, justify, width)
    local right = justify == "RIGHT"
    local x0 = 0
    if justify == "CENTER" then
        local total = 0
        for _, fs in ipairs(list) do
            total = total + (fs._estW or fs:GetStringWidth()) + (fs._gapL or 0) + (fs._gapR or 0)
        end
        x0 = math.max(0, ((width or 0) - total) / 2)
    end
    local n, prev = #list, nil
    for k = 1, n do
        local fs = list[right and (n - k + 1) or k]
        fs:ClearAllPoints()
        if right then
            if prev then fs:SetPoint("RIGHT", prev, "LEFT", -((fs._gapR or 0) + (prev._gapL or 0)), 0)
            else fs:SetPoint("RIGHT", host, "RIGHT", -(fs._gapR or 0), 0) end
        else
            if prev then fs:SetPoint("LEFT", prev, "RIGHT", (prev._gapR or 0) + (fs._gapL or 0), 0)
            else fs:SetPoint("LEFT", host, "LEFT", x0 + (fs._gapL or 0), 0) end
        end
        prev = fs
    end
end

-- --------------------------------------------------------------- auras

local spellNameOK
local function CanSpellName(button)
    if spellNameOK == nil then spellNameOK = type(button.SetSpellName) == "function" end
    return spellNameOK
end

-- one aura line; the button writes the tokens, also while its aura is secret
function M.StyleAura(button, r, group, def, w, h, staticName, single)
    if button:IsForbidden() then return end
    button:SetSize(w, h)
    local p = M.Parse(M.FormatFor(group, def))
    local has = {}
    for _, seg in ipairs(p) do
        if seg.tok then has[seg.tok] = true end
    end
    -- the game's own name can't be upper-cased: one known spell uses its name instead
    local ownName = not CanSpellName(button) or (group.textCase == "upper" and single and staticName)
    -- unbind first: a cleared binding blanks its old piece
    if (not has.name or ownName) and CanSpellName(button) and button.ClearSpellName then button:ClearSpellName() end
    if not has.cd then button:ClearDurationText() end
    if not has.stacks then button:ClearApplicationCount() end

    r.segs = r.segs or {}
    local sw = SpaceWidth(group)
    local list, bound = {}, {}
    for i, seg in ipairs(p) do
        local fs = Piece(r.segs, button, i)
        StyleSeg(fs, group, seg.tok)
        NoGap(fs)
        local tok = seg.tok
        if tok == "name" and not bound.name then
            bound.name = true
            if ownName then
                fs:SetText(Cased(group, staticName or ""))
            else
                button:SetSpellName(fs)
                fs._estW = Measure(group, staticName or "")
            end
        elseif tok == "cd" and not bound.cd then
            bound.cd = true
            local AL = ns.AuraLane
            button:SetDurationText(fs, { textFormatter = AL and AL.DurFormatter() or nil })
            fs._estW = Measure(group, "00")
        elseif tok == "stacks" and not bound.stacks then
            bound.stacks = true
            button:SetApplicationCount(fs, {})
            fs._estW = Measure(group, "0")
        elseif tok then
            fs:SetText("")
        else
            Literal(fs, seg.text, sw, group)
        end
        fs:Show()
        list[#list + 1] = fs
    end
    HideFrom(r.segs, #p + 1)
    Chain(list, button, group.justify, w)
    button:SetMouseMotionEnabled(true)
end

-- ------------------------------------------------------------ cooldowns

local active = {}
local onCurve, offCurve

-- 1 while on cooldown / 1 while ready
local function Curves()
    if onCurve ~= nil then return onCurve, offCurve end
    onCurve = H.GetDesatCurve() or false
    offCurve = false
    if onCurve and C_CurveUtil and C_CurveUtil.CreateCurve then
        local c = C_CurveUtil.CreateCurve()
        c:SetType(Enum.LuaCurveType.Step)
        c:AddPoint(0, 1)
        c:AddPoint(0.001, 0)
        offCurve = c
    end
    return onCurve, offCurve
end

local function CountdownText(cd)
    local SB = ns.SpecialBars
    return SB and SB.CooldownText and SB.CooldownText(cd)
end

local Rebuild, QueueRelayout

function M.UpdateLine(L)
    local id = L.spellID
    if not id then return end
    if L.needCD and CountdownText(L.cd) then Rebuild(L) end
    if L.test then return end
    local info = C_Spell.GetSpellCooldown(id)
    local dur = C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(id)
    -- the spell's own isActive is plain in combat: a hidden line leaves the stack
    local CI = ns.CDMIcons
    local onCD = CI and CI.OnRealCD and CI.OnRealCD(id)
    local on, off = Curves()
    if onCD ~= nil then
        if onCD and dur then H.SetCooldownFromDuration(L.cd, dur) else L.cd:Clear() end
        L.main:SetAlpha((onCD or L.keep) and 1 or 0)
        L.ready:SetAlpha((L.readyOn and not onCD) and 1 or 0)
        local shown = (onCD or L.keep or L.readyOn) and true or false
        if L.shown ~= shown then
            L.shown = shown
            if L.st then QueueRelayout(L.st) end
        end
    -- the GCD is not this spell's cooldown
    elseif not (dur and on) or (info and info.isOnGCD) then
        L.cd:Clear()
        L.main:SetAlpha(L.keep and 1 or 0)
        L.ready:SetAlpha(L.readyOn and 1 or 0)
    else
        H.SetCooldownFromDuration(L.cd, dur)
        L.main:SetAlpha(L.keep and 1 or dur:EvaluateRemainingDuration(on, 0))
        if L.readyOn and off then L.ready:SetAlpha(dur:EvaluateRemainingDuration(off, 1)) else L.ready:SetAlpha(0) end
    end
    if onCD == nil and L.shown ~= true then
        L.shown = true
        if L.st then QueueRelayout(L.st) end
    end
    if L.charges[1] then
        local ch = C_Spell.GetSpellCharges(id)
        local v = ch and ch.currentCharges
        -- a secret count goes straight to the text, never tested
        if not (issecretvalue and issecretvalue(v)) then v = v or "" end
        for _, fs in ipairs(L.charges) do fs:SetText(v) end
    end
end

local function NewLine(host)
    local L = CreateFrame("Frame", nil, host)
    L.main = CreateFrame("Frame", nil, L)
    L.main:SetAllPoints()
    L.ready = CreateFrame("Frame", nil, L)
    L.ready:SetAllPoints()
    L.cd = CreateFrame("Cooldown", nil, L.main, "CooldownFrameTemplate")
    L.cd:SetDrawSwipe(false)
    L.cd:SetDrawEdge(false)
    L.cd:SetDrawBling(false)
    L.cd:SetHideCountdownNumbers(false)
    L.cd:SetScript("OnCooldownDone", function() M.UpdateLine(L) end)
    local AL = ns.AuraLane
    local f = AL and AL.DurFormatter()
    if f and L.cd.SetCountdownFormatter then L.cd:SetCountdownFormatter(f) end
    L.mainSegs, L.readySegs, L.charges = {}, {}, {}
    return L
end

-- one format onto a cooldown line part; [cd] is the Cooldown's own countdown
local function BuildCD(L, frame, store, fmt, group, withCD)
    local name = Cased(group, C_Spell.GetSpellName(L.spellID) or "")
    local list, n, cdUsed = {}, 0, false
    local sw = SpaceWidth(group)
    if withCD then L.needCD = nil end
    for _, seg in ipairs(M.Parse(fmt)) do
        local fs
        if seg.tok == "cd" and withCD and not cdUsed then
            cdUsed = true
            fs = CountdownText(L.cd)
            if fs then
                StyleSeg(fs, group, "cd")
                NoGap(fs)
                fs._estW = Measure(group, "00")
            else
                L.needCD = true
            end
        else
            n = n + 1
            fs = Piece(store, frame, n)
            StyleSeg(fs, group, seg.tok)
            NoGap(fs)
            if seg.tok == "name" then
                fs:SetText(name)
            elseif seg.tok == "stacks" then
                fs:SetText("")
                if L.hasCharges then
                    L.charges[#L.charges + 1] = fs
                    fs._estW = Measure(group, "0")
                end
            elseif seg.tok then
                fs:SetText("")
            else
                Literal(fs, seg.text, sw, group)
            end
            fs:Show()
        end
        if fs then list[#list + 1] = fs end
    end
    HideFrom(store, n + 1)
    Chain(list, frame, group.justify, L.W)
end

Rebuild = function(L)
    wipe(L.charges)
    BuildCD(L, L.main, L.mainSegs, L.fmt, L.group, true)
    BuildCD(L, L.ready, L.readySegs, L.group.readyFormat or "", L.group, false)
end

-- the shown lines stacked from the top (or bottom); the aura lines follow right after
local function Layout(st)
    local group = st.group
    if not (group and st.cdHost) then return 0 end
    local Hh = st.effH or group.height or 16
    local sp = group.spacing or 2
    local up = group.growth == "UP"
    local n = 0
    for _, L in ipairs(st.cdLines or {}) do
        if L.spellID and (L.test or L.shown ~= false) then
            local y = n * (Hh + sp)
            L:ClearAllPoints()
            if up then L:SetPoint("BOTTOMLEFT", st.cdHost, "BOTTOMLEFT", 0, y)
            else L:SetPoint("TOPLEFT", st.cdHost, "TOPLEFT", 0, -y) end
            L:Show()
            n = n + 1
        else
            L:Hide()
        end
    end
    local cdH = n * (Hh + sp)
    if st.clip then
        local pt = up and "BOTTOMLEFT" or "TOPLEFT"
        st.clip:ClearAllPoints()
        st.clip:SetPoint(pt, st.frame, pt, 0, up and cdH or -cdH)
    end
    return cdH
end

do
    local pending, queued = {}, false
    local function Flush()
        queued = false
        for st in pairs(pending) do
            pending[st] = nil
            Layout(st)
        end
    end
    QueueRelayout = function(st)
        pending[st] = true
        if queued then return end
        queued = true
        C_Timer.After(0, Flush)
    end
end

local events
local function Events()
    if events then return end
    events = CreateFrame("Frame")
    local queued = false
    local function Flush()
        queued = false
        for L in pairs(active) do
            local host = L:GetParent()
            if host and host:IsVisible() then M.UpdateLine(L) end
        end
    end
    events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    events:RegisterEvent("SPELL_UPDATE_CHARGES")
    events:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    events:RegisterEvent("TRAIT_CONFIG_UPDATED")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
            -- the spells this character knows decide the lines
            if TUI.QueueCustomBarsUpdate then TUI:QueueCustomBarsUpdate() end
            return
        end
        if queued or not next(active) then return end
        queued = true
        C_Timer.After(0, Flush)
    end)
end

local function Known(id)
    return IsPlayerSpell(id) or (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id)) or false
end

-- this character's cooldown lines from the group's list; returns the space they take
function M.SyncCooldowns(st, group, W, Hh, test)
    st.cdLines = st.cdLines or {}
    if not st.cdHost then
        st.cdHost = CreateFrame("Frame", nil, st.frame)
        st.cdHost:SetAllPoints(st.frame)
    end
    local list = {}
    if group.enabled ~= false then
        for _, c in ipairs(group.cooldowns or {}) do
            if c.id and c.enabled ~= false and (test or Known(c.id)) then list[#list + 1] = c end
        end
    end
    local mode = group.cdReady or "hide"
    for i, c in ipairs(list) do
        local L = st.cdLines[i]
        if not L then
            L = NewLine(st.cdHost)
            st.cdLines[i] = L
        end
        L:SetSize(W, Hh)
        L.W = W
        L.st = st
        L.cd:SetSize(Hh, Hh)
        L.cd:ClearAllPoints()
        L.cd:SetPoint("LEFT", L, "LEFT")
        L.spellID = c.id
        L.keep = mode == "keep"
        L.readyOn = mode == "text"
        local ch = C_Spell.GetSpellCharges(c.id)
        local mx = ch and ch.maxCharges
        if not (issecretvalue and issecretvalue(mx)) then L.hasCharges = (mx or 0) > 1 end
        -- the countdown text exists once the frame has counted once
        if not CountdownText(L.cd) then
            L.cd:SetCooldown(GetTime(), 1)
            L.cd:Clear()
        end
        L.group, L.fmt = group, M.FormatFor(group, c)
        Rebuild(L)
        L.test = test or nil
        if test then
            L.cd:SetCooldown(GetTime() - 3, 15)
            L.main:SetAlpha(1)
            L.ready:SetAlpha(0)
            for _, fs in ipairs(L.charges) do fs:SetText("2") end
        end
        active[L] = true
        if not test then M.UpdateLine(L) end
    end
    for i = #list + 1, #st.cdLines do
        local L = st.cdLines[i]
        L.spellID = nil
        L.test = nil
        L.cd:Clear()
        L:Hide()
        active[L] = nil
    end
    if #list > 0 then Events() end
    st.cdHost:SetShown(group.enabled ~= false and (test or ns.Visibility.Shown(group.visibility)))
    return Layout(st)
end

-- a group's lines repaint after it shows again
function M.UpdateLines(st)
    for _, L in ipairs(st.cdLines or {}) do
        if L.spellID then M.UpdateLine(L) end
    end
end

-- ------------------------------------------------------------- preview

-- stand-in aura lines; true while previews are on
function M.RenderTest(st, group, offset, entries, spellList)
    local pool = st.textTest
    if not (ns.CustomGroups and ns.CustomGroups.testMode) then
        if pool then for _, f in ipairs(pool) do f:Hide() end end
        return false
    end
    st.textTest = pool or {}
    pool = st.textTest
    local W = st.effW or group.width or 200
    local Hh = st.effH or group.height or 16
    local sp = group.spacing or 2
    local up = group.growth == "UP"
    local cap = tonumber(group.maxBars) or 0
    local idx = 0
    for _, e in ipairs(entries) do
        local spells = spellList(e.def)
        local n = math.max(1, e.def.max or 1)
        if #spells > 1 then n = math.min(n, #spells) end
        for k = 1, n do
            if cap > 0 and idx >= cap then break end
            idx = idx + 1
            local f = pool[idx]
            if not f then
                f = CreateFrame("Frame", nil, st.frame)
                f.segs = {}
                pool[idx] = f
            end
            f:SetSize(W, Hh)
            f:ClearAllPoints()
            local y = offset + (idx - 1) * (Hh + sp)
            if up then f:SetPoint("BOTTOMLEFT", st.frame, "BOTTOMLEFT", 0, y)
            else f:SetPoint("TOPLEFT", st.frame, "TOPLEFT", 0, -y) end
            local sid = spells[((k - 1) % math.max(1, #spells)) + 1]
            local nm = Cased(group, (sid and C_Spell.GetSpellName and C_Spell.GetSpellName(sid)) or "Buff")
            local list = {}
            local p = M.Parse(M.FormatFor(group, e.def))
            local sw = SpaceWidth(group)
            for i, seg in ipairs(p) do
                local fs = Piece(f.segs, f, i)
                StyleSeg(fs, group, seg.tok)
                NoGap(fs)
                if seg.tok then
                    fs:SetText((seg.tok == "name" and nm) or (seg.tok == "cd" and "12") or "3")
                else
                    Literal(fs, seg.text, sw, group)
                end
                fs:Show()
                list[#list + 1] = fs
            end
            HideFrom(f.segs, #p + 1)
            Chain(list, f, group.justify, W)
            f:Show()
        end
    end
    for k = idx + 1, #pool do pool[k]:Hide() end
    return true
end
