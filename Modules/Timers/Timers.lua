local _, ns = ...
local E = ns.E

ns.Timers = ns.Timers or {}
local M = ns.Timers

local GetTime, InCombatLockdown = GetTime, InCombatLockdown
local C_Item, C_Spell, C_TooltipInfo = C_Item, C_Spell, C_TooltipInfo
local ipairs, wipe, tonumber, select = ipairs, wipe, tonumber, select

local lastCastStart = {}
local durationCache = {}
local triggerMap    = {}
local trackedItems  = {}

local hostRefreshers = {}
function M.AddHostRefresh(fn)
    if type(fn) == "function" then hostRefreshers[#hostRefreshers + 1] = fn end
end
local function FireHosts()
    for i = 1, #hostRefreshers do hostRefreshers[i]() end
end

local hostRepainters = {}
function M.AddHostRepaint(fn)
    if type(fn) == "function" then hostRepainters[#hostRepainters + 1] = fn end
end
local function FireRepaint()
    for i = 1, #hostRepainters do hostRepainters[i]() end
end

local function DB()
    return E.db and E.db.thingsUI and E.db.thingsUI.timers
end

M.DefaultTimer = ns.Defaults.Timer

function M.GetTimers()
    local db = DB()
    return db and db.list or {}
end

function M.GetByID(id)
    for _, t in ipairs(M.GetTimers()) do
        if t.id == id then return t end
    end
end


function M.FindItemTimer(itemID, dest)
    if not itemID then return end
    local CG = ns.CustomGroups
    local gi = CG and CG.POTION_OF and CG.POTION_OF[itemID]   -- potion rank-group, if any
    for _, t in ipairs(M.GetTimers()) do
        if t.kind == "item" and t.destination == dest then
            if t.itemID == itemID then return t end
            if gi and CG.POTION_OF[t.itemID] == gi then return t end  -- any rank of the same potion
        end
    end
end

function M.AddTimer(kind, idValue)
    local db = DB(); if not db then return end
    local t = M.DefaultTimer(db.nextID)
    t.kind = kind
    if kind == "item" then t.itemID = tonumber(idValue) else t.spellID = tonumber(idValue) end
    t.order = #db.list + 1
    db.nextID = db.nextID + 1
    db.list[#db.list + 1] = t
    M.Update()
    return t
end

function M.RemoveTimer(index)
    local db = DB(); if not db or not db.list[index] then return end
    table.remove(db.list, index)
    M.Update()
end

function M.GetTriggerSpellID(timer)
    if timer.kind == "spell" then return timer.spellID end
    if timer.kind == "item" and timer.itemID then
        return select(2, C_Item.GetItemSpell(timer.itemID))
    end
end

function M.GetAllTriggerSpellIDs(timer)
    local out = {}
    if timer.kind == "spell" then
        if timer.spellID then out[1] = timer.spellID end
        return out
    end
    if timer.kind ~= "item" or not timer.itemID then return out end
    local CG = ns.CustomGroups
    local gi = CG and CG.POTION_OF and CG.POTION_OF[timer.itemID]
    local ids = (gi and CG.POTION_GROUPS and CG.POTION_GROUPS[gi]) or { timer.itemID }
    for _, iid in ipairs(ids) do
        local sid = select(2, C_Item.GetItemSpell(iid))
        if sid then out[#out + 1] = sid end
    end
    return out
end

function M.GetTexture(timer)
    if timer.kind == "lust" then
        return C_Spell.GetSpellTexture((M.PlayerLustID and M.PlayerLustID()) or 2825)
    elseif timer.kind == "spell" and timer.spellID then
        return C_Spell.GetSpellTexture(timer.spellID)
    elseif timer.kind == "item" and timer.itemID then
        return (select(10, C_Item.GetItemInfo(timer.itemID))) or C_Item.GetItemIconByID(timer.itemID)
    end
end


local function ParseDurationFromText(text)
    if type(text) ~= "string" then return end
    local lower = text:lower()
    local n, unit = lower:match("for%s+(%d+%.?%d*)%s*(%a+)")
    if n then
        if unit:find("^min") then return tonumber(n) * 60 end
        if unit:find("^sec") then return tonumber(n) end
    end

    local before = lower:match("^(.-)cooldown") or lower
    n = before:match("(%d+%.?%d*)%s*sec")
    if n then return tonumber(n) end
    n = before:match("(%d+%.?%d*)%s*min")
    if n then return tonumber(n) * 60 end
end

local function TooltipDuration(timer)
    local data
    if timer.kind == "item" and timer.itemID and C_TooltipInfo and C_TooltipInfo.GetItemByID then
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(timer.itemID) end
        data = C_TooltipInfo.GetItemByID(timer.itemID)
    elseif timer.kind == "spell" and timer.spellID and C_TooltipInfo and C_TooltipInfo.GetSpellByID then
        data = C_TooltipInfo.GetSpellByID(timer.spellID)
    end
    if not data or not data.lines then return end
    for _, line in ipairs(data.lines) do
        local d = ParseDurationFromText(line.leftText)
        if d and d > 0 then return d end
    end
end

function M.GetDuration(timer)
    if not timer.durationAuto then
        return timer.duration
    end
    local id = timer.id
    if not durationCache[id] then
        local d = TooltipDuration(timer)
        if d then durationCache[id] = d end
    end
    return durationCache[id] or timer.duration  -- still nil -> manual fallback
end

local LOCKOUT_IDS = { 57724, 57723, 80354, 264689, 390435 } -- Sated/Exhaustion/Temporal Displacement/Fatigued/Exhaustion
local LUST_CLASS  = { SHAMAN = 2825, MAGE = 80353, EVOKER = 390386, HUNTER = 272678 }
local LUST_BUFF_DURATION = 40

local function IsSecret(v)
    return v ~= nil and type(issecretvalue) == "function" and issecretvalue(v)
end

function M.PlayerLustID()
    local _, cf = UnitClass("player")
    return LUST_CLASS[cf]
end

local function PlayerAura(spellID)
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return end
    return C_UnitAuras.GetPlayerAuraBySpellID(spellID)
end

local function FindAura(ids)
    for _, sid in ipairs(ids) do
        local a = PlayerAura(sid)
        if a then return sid, a end
    end
end

local lustState = { active = false, start = 0 }
local sawSated = false

function M.GetLustState(now)
    if not lustState.active then return nil end
    now = now or GetTime()
    local elapsed = now - lustState.start
    if elapsed >= 0 and elapsed < LUST_BUFF_DURATION then
        return "buff", lustState.start, LUST_BUFF_DURATION
    end
    return nil
end

local function UpdateLustState()
    local prevPhase = M.GetLustState()
    local _, aura = FindAura(LOCKOUT_IDS)
    local present = aura ~= nil
    if present and not lustState.active then

        local exp, dur = aura.expirationTime, aura.duration
        if exp and dur and not IsSecret(exp) and not IsSecret(dur) and dur > 0 then
            local s = exp - dur
            if GetTime() - s < LUST_BUFF_DURATION then lustState.start, lustState.active = s, true end
        elseif not sawSated then
            lustState.start, lustState.active = GetTime(), true
        end
    end
    sawSated = present
    if lustState.active and (GetTime() - lustState.start) >= LUST_BUFF_DURATION then
        lustState.active = false
    end
    if M.GetLustState() ~= prevPhase then FireHosts() end
end

local lustPoll = CreateFrame("Frame")
local lustAcc = 0
lustPoll:Hide()
lustPoll:SetScript("OnUpdate", function(_, e)
    lustAcc = lustAcc + e
    if lustAcc < 0.3 then return end
    lustAcc = 0
    UpdateLustState()
end)

local function UpdateLustPoller()
    local on = false
    for _, t in ipairs(M.GetTimers()) do
        if t.kind == "lust" and t.enabled then on = true; break end
    end
    if on then lustPoll:Show() else lustPoll:Hide(); lustState.active = false end
end

function M.EnsureLustTimer()
    local db = DB(); if not db then return end
    for _, t in ipairs(db.list) do if t.kind == "lust" then return t end end
    local t = M.DefaultTimer(db.nextID)
    t.kind, t.builtin, t.enabled, t.order = "lust", true, false, 0
    db.nextID = db.nextID + 1
    table.insert(db.list, 1, t)
    return t
end

function M.Rebuild()
    wipe(triggerMap)
    wipe(durationCache)
    wipe(trackedItems)
    for _, timer in ipairs(M.GetTimers()) do
        if timer.enabled then
            for _, sid in ipairs(M.GetAllTriggerSpellIDs(timer)) do
                local t = triggerMap[sid]
                if not t then t = {}; triggerMap[sid] = t end
                t[#t + 1] = timer.id
            end

            if timer.kind == "item" and timer.itemID then
                trackedItems[timer.itemID] = true
                if timer.durationAuto then
                    if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(timer.itemID) end
                    M.GetDuration(timer)
                end
            end
        end
    end
    UpdateLustPoller()
    if ns.TimersRender and ns.TimersRender.SetGlowActive then
        local wantGlow = false
        for _, timer in ipairs(M.GetTimers()) do
            if timer.enabled and timer.glowReadyInCombat then wantGlow = true; break end
        end
        ns.TimersRender.SetGlowActive(wantGlow and InCombatLockdown())
    end
end

function M.GetActiveBuff(timer, now)
    now = now or GetTime()
    local start = lastCastStart[timer.id]
    if not start then return end
    local dur = M.GetDuration(timer)
    if not dur or dur <= 0 then return end
    if start + dur > now then
        return start, dur
    end
    lastCastStart[timer.id] = nil
end

function M.IsInCombat()
    return InCombatLockdown() and true or false
end

local cdRepaintQueued = false
local function QueueCDRepaint()
    if cdRepaintQueued then return end
    cdRepaintQueued = true
    C_Timer.After(0, function() cdRepaintQueued = false; FireRepaint() end)
end

local ev = CreateFrame("Frame")
ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:SetScript("OnEvent", function(_, event, a1, a2, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local ids = triggerMap[spellID]
        if ids then
            local now = GetTime()
            for i = 1, #ids do lastCastStart[ids[i]] = now end
            FireHosts()   -- relayout: a buff just started
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if a1 and trackedItems[a1] then FireHosts() end
    elseif event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
        QueueCDRepaint()
    else
        if event == "PLAYER_ENTERING_WORLD" then M.EnsureLustTimer() end
        M.Rebuild()
        FireHosts()
    end
end)

function M.Update()
    M.Rebuild()
    if M._rebuildOptions then M._rebuildOptions() end
    FireHosts()
end

-- /tuitimer tester or fallback, prob delete later
SLASH_TUITIMER1 = "/tuitimer"
SlashCmdList["TUITIMER"] = function(msg)
    local w = {}
    for word in msg:gmatch("%S+") do w[#w + 1] = word end
    local verb = (w[1] or ""):lower()
    local P = function(s) print("|cFF8080FFTimers|r " .. s) end

    if verb == "groups" then
        local groups = ns.CustomGroups and ns.CustomGroups.GetGroups and ns.CustomGroups.GetGroups() or {}
        P("custom groups:")
        for _, g in ipairs(groups) do
            print(("  id %d  %s%s"):format(g.id, g.name or "?", g.enabled and "" or " |cFFFF6060(disabled)|r"))
        end
    elseif verb == "add" then
        local kind, idValue, dest, dur = (w[2] or ""):lower(), tonumber(w[3]), tonumber(w[4]), tonumber(w[5])
        if (kind == "item" or kind == "spell") and idValue and dest then
            local t = M.AddTimer(kind, idValue)
            if t then
                t.destination = dest
                if dur then t.durationAuto = false; t.duration = dur end
                M.Update()
                P(("added %s %d -> group %d (timer id %d, dur=%s)"):format(kind, idValue, dest, t.id, tostring(M.GetDuration(t))))
            end
        else
            P("usage: /tuitimer add item|spell <id> <customGroupID> [seconds]")
        end
    elseif verb == "list" then
        for _, t in ipairs(M.GetTimers()) do
            print(("  id %d  %s %s  dur=%s  dest=%s"):format(
                t.id, t.kind, tostring(t.itemID or t.spellID), tostring(M.GetDuration(t)), tostring(t.destination)))
        end
    elseif verb == "clear" then
        local db = DB()
        if db then wipe(db.list); db.nextID = 1; M.Update(); P("cleared") end
    else
        P("/tuitimer groups | add item|spell <id> <groupID> [seconds] | list | clear")
    end
end
