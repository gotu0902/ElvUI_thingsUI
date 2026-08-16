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

function M.DropLustTimers()
    local db = DB()
    if not (db and db.list) then return end
    for i = #db.list, 1, -1 do
        if db.list[i].kind == "lust" then table.remove(db.list, i) end
    end
end

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
    local ov = tonumber(timer.iconID)
    if ov and ov > 0 then
        return (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(ov)) or ov
    end
    if timer.kind == "spell" and timer.spellID then
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
    local db = DB()
    local sid = timer.kind == "spell" and timer.spellID
    local learned = sid and db and db.totemLearn and db.totemLearn[sid]
    if learned then return learned end
    local id = timer.id
    if not durationCache[id] then
        local d = TooltipDuration(timer)
        if d then durationCache[id] = d end
    end
    return durationCache[id] or timer.duration  -- still nil -> manual fallback
end

local totemSlot = {}
local totemSpells = {}
local totemCast = {}
local totemCastList = {}
local totemCallbacks = {}
local issecret = issecretvalue

function M.RegisterTotemSpell(sid)
    if sid then totemSpells[sid] = true end
end

function M.AddTotemCallback(fn)
    if type(fn) == "function" then totemCallbacks[#totemCallbacks + 1] = fn end
end

local function FireTotem()
    for i = 1, #totemCallbacks do totemCallbacks[i]() end
end

function M.GetTotemState(sid)
    local start = totemCast[sid]
    local dur = M.GetLearnedDuration(sid)
    if start and dur and dur > 0 and start + dur > GetTime() then return start, dur end
end

function M.GetTotemCasts(sid)
    local list = totemCastList[sid]
    local dur = M.GetLearnedDuration(sid)
    if not (list and dur and dur > 0) then return nil end
    local now = GetTime()
    for i = #list, 1, -1 do
        if list[i] + dur <= now then table.remove(list, i) end
    end
    return list, dur
end

local ttDur = {}
function M.GetLearnedDuration(sid)
    local db = DB()
    local learned = db and db.totemLearn and db.totemLearn[sid]
    if learned then return learned end
    if not ttDur[sid] then
        ttDur[sid] = TooltipDuration({ kind = "spell", spellID = sid })
    end
    return ttDur[sid]
end

function M.TotemUpdate(slot)
    local db = DB(); if not db then return end
    if not InCombatLockdown() then
        for sid, s in pairs(totemSlot) do
            if s == slot then
                totemCast[sid] = nil
                totemCastList[sid] = nil
                local ids = triggerMap[sid]
                if ids then for i = 1, #ids do lastCastStart[ids[i]] = nil end end
            end
        end
        for s = 1, 4 do
            local have, _, start, dur, _, _, sid = GetTotemInfo(s)
            if not (issecret and (issecret(have) or issecret(sid))) and have and sid then
                db.totemLearn = db.totemLearn or {}
                db.totemLearn[sid] = dur
                totemSlot[sid] = s
                totemCast[sid] = start
                local ids = triggerMap[sid]
                if ids then
                    for i = 1, #ids do lastCastStart[ids[i]] = start end
                end
            end
        end
        FireHosts()
        FireTotem()
        return
    end
    if issecret and issecret(slot) then return end
    for sid, s in pairs(totemSlot) do
        if s == slot then
            local now = GetTime()
            local st0 = totemCast[sid]
            if st0 and (now - st0) > 0.5 then totemCast[sid] = nil; totemCastList[sid] = nil end
            local ids = triggerMap[sid]
            if ids then
                for i = 1, #ids do
                    local tid = ids[i]
                    local st = lastCastStart[tid]
                    if st and (now - st) > 0.5 then lastCastStart[tid] = nil end
                end
            end
            FireHosts()
            FireTotem()
        end
    end
end

function M.IsActive(timer)
    if not (timer and timer.enabled) then return false end
    local req = tonumber(timer.talentSpellID)
    if req and req > 0 and not IsPlayerSpell(req) then return false end
    return true
end

function M.Rebuild()
    wipe(triggerMap)
    wipe(durationCache)
    wipe(trackedItems)
    for _, timer in ipairs(M.GetTimers()) do
        if M.IsActive(timer) then
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
    if ns.TimersRender and ns.TimersRender.SetGlowActive then
        local wantGlow = false
        for _, timer in ipairs(M.GetTimers()) do
            if M.IsActive(timer) and timer.glowReadyInCombat then wantGlow = true; break end
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
ev:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
ev:RegisterEvent("TRAIT_CONFIG_UPDATED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:RegisterEvent("PLAYER_TOTEM_UPDATE")
ev:SetScript("OnEvent", function(_, event, a1, a2, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if totemSpells[spellID] then
            local now = GetTime()
            totemCast[spellID] = now
            local list = totemCastList[spellID]
            if not list then list = {}; totemCastList[spellID] = list end
            list[#list + 1] = now
            local dur = M.GetLearnedDuration(spellID)
            if dur and dur > 0 then
                C_Timer.After(dur + 0.1, function()
                    if totemCast[spellID] == now then
                        totemCast[spellID] = nil
                        FireTotem()
                    end
                end)
            end
            FireTotem()
        end
        local ids = triggerMap[spellID]
        if ids then
            local now = GetTime()
            for i = 1, #ids do
                local tid = ids[i]
                lastCastStart[tid] = now
                local timer
                for _, t in ipairs(M.GetTimers()) do
                    if t.id == tid then timer = t; break end
                end
                local dur = timer and M.GetDuration(timer)
                if dur and dur > 0 then
                    C_Timer.After(dur + 0.1, function()
                        if lastCastStart[tid] == now then
                            lastCastStart[tid] = nil
                            FireHosts()
                        end
                    end)
                end
            end
            FireHosts()   -- relayout: a buff just started
        end
    elseif event == "PLAYER_TOTEM_UPDATE" then
        M.TotemUpdate(a1)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if a1 and trackedItems[a1] then FireHosts() end
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        if not a1 or triggerMap[a1] then QueueCDRepaint() end
    elseif event == "BAG_UPDATE_COOLDOWN" then
        if next(trackedItems) then QueueCDRepaint() end
    else
        if event == "PLAYER_ENTERING_WORLD" then M.DropLustTimers() end
        M.Rebuild()
        FireHosts()
    end
end)

function M.Update()
    M.Rebuild()
    if M._rebuildOptions then M._rebuildOptions() end
    FireHosts()
end

