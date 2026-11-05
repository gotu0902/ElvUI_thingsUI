local _, ns = ...
local KD = ns.KickData

-- In a key nothing names a kicker, but the meter counts Interrupts per member. A longer list of
-- kicked spells names them; anyone else gets a gate packet, their hidden count before and after
-- the update, and KickBars shows the kick only where it rose. Runs only between Start and Stop.
local M = {}
ns.KickEngine = M

local DM = C_DamageMeter
local INT = Enum.DamageMeterType and Enum.DamageMeterType.Interrupts
local DMG = Enum.DamageMeterType and Enum.DamageMeterType.DamageDone
local CUR = Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current
local ALL = Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Overall
local INSPECT_CFG = Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID or -1

local UNITS = { "player", "party1", "party2", "party3", "party4" }
local PET = { player = "pet", party1 = "partypet1", party2 = "partypet2", party3 = "partypet3", party4 = "partypet4" }
M.UNITS = UNITS

local OWN_WINDOW = 1    -- a landed kick this soon after your cast is yours
local SLACK = 1.5       -- how far a timed cooldown may be off before it rules a member out
local INSPECT_WAIT, INSPECT_RETRY, INSPECT_FRESH, INSPECT_TRIES = 3, 10, 60, 3

local members = {}      -- unit -> { guid, class, role, spec, talents, demon, kick, cd, landed, shortest, downAt, downFor, sureT }
local handlers
local active = false
local evt
local stats = { updates = 0, sure = 0, gates = 0 }

local function Secret(v) return issecretvalue and issecretvalue(v) or false end

local function Plain(v)
    if type(v) == "string" and not Secret(v) and v ~= "" then return v end
end

local function Fire(name, ...)
    local fn = handlers and handlers[name]
    if fn then fn(...) end
end

local function StartCd(m, start, dur)
    if not dur then return end
    m.downAt, m.downFor = start, dur
    Fire("cooldown", m.unit, start, dur)
end

local function Resolve(m)
    local kick, spec, cd, landed, shortest
    if m.class then
        kick, spec = KD.Pick(m.class, m.spec, m.role, m.talents, m.demon)
        if kick then
            cd, landed = KD.Cooldown(kick, spec, m.talents)
            shortest = select(2, KD.Cooldown(kick, spec, KD.TALENTS))
        end
    end
    local changed = m.kick ~= kick or m.cd ~= cd or m.landed ~= landed
    m.kick, m.cd, m.landed, m.shortest = kick, cd, landed, shortest
    return changed
end

local function DemonKick(unit)
    local pet = PET[unit]
    if not (pet and UnitExists(pet)) then return nil end
    local g = Plain(UnitGUID(pet))
    local npc = g and tonumber(g:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    return npc and KD.DEMONS[npc]
end

local function RefreshPlayer(m)
    local idx = C_SpecializationInfo.GetSpecialization()
    local id = idx and C_SpecializationInfo.GetSpecializationInfo(idx)
    m.spec = (id and id ~= 0) and id or nil
    m.talents = wipe(m.talents or {})
    for sid in pairs(KD.TALENTS) do
        if IsPlayerSpell(sid) then m.talents[sid] = true end
    end
    m.demon = DemonKick("player")
    return Resolve(m)
end

-- ---------------------------------------------------------------- inspect

local queue, queued = {}, {}
local readUnit, readGUID
local waiting = false
local NextRead

local function KeyRunning()
    local R, T = C_RestrictedActions, Enum.AddOnRestrictionType
    return (R and R.IsAddOnRestrictionActive and T and T.ChallengeMode and R.IsAddOnRestrictionActive(T.ChallengeMode)) or false
end

-- the game's own inspect window or talent view is up: that inspect is the player's
local function WindowUp()
    if InspectFrame and InspectFrame:IsShown() then return true end
    local ps = PlayerSpellsFrame
    return (ps and ps.IsInspecting and ps:IsInspecting()) and true or false
end

local function ReadTree()
    if not C_Traits.HasValidInspectData() then return nil end
    local info = C_Traits.GetConfigInfo(INSPECT_CFG)
    if not (info and info.treeIDs) then return nil end
    local set, any = {}, false
    for _, tree in ipairs(info.treeIDs) do
        for _, nodeID in ipairs(C_Traits.GetTreeNodes(tree) or {}) do
            local node = C_Traits.GetNodeInfo(INSPECT_CFG, nodeID)
            local chosen = node and node.activeEntry
            if chosen and (node.activeRank or 0) > 0 then
                any = true
                local entry = C_Traits.GetEntryInfo(INSPECT_CFG, chosen.entryID)
                local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
                if def and def.spellID and KD.TALENTS[def.spellID] then set[def.spellID] = true end
            end
        end
    end
    -- a tree with nothing active wasn't really read
    return any and set or nil
end

local function ReadLater(delay)
    if waiting then return end
    waiting = true
    C_Timer.After(delay, function()
        waiting = false
        if active then NextRead() end
    end)
end

local function ReadDone()
    readUnit, readGUID = nil, nil
    if evt then evt:UnregisterEvent("INSPECT_READY") end
    if not WindowUp() then ClearInspectPlayer() end
end

local function OnInspect(guid)
    if not readUnit or Secret(guid) or guid ~= readGUID then return end
    local unit = readUnit
    local m = members[unit]
    if m and m.guid == guid then
        local spec = C_SpecializationInfo.GetInspectSpecialization(unit)
        if type(spec) == "number" and not Secret(spec) and spec > 0 then m.spec, m.specRead = spec, true end
        local talents = ReadTree()
        if talents then m.talents, m.readAt, m.tries = talents, GetTime(), nil end
        if Resolve(m) then Fire("roster") end
    end
    ReadDone()
    queued[unit] = nil
    NextRead()
end

local function ReadTimedOut(guid)
    if not (readUnit and readGUID == guid) then return end
    local unit = readUnit
    ReadDone()
    local m = members[unit]
    local tries = ((m and m.tries) or 0) + 1
    if m then m.tries = tries end
    if tries < INSPECT_TRIES then queue[#queue + 1] = unit else queued[unit] = nil end
    ReadLater(INSPECT_RETRY)
end

NextRead = function()
    if not active or readUnit or #queue == 0 then return end
    if InCombatLockdown() or KeyRunning() or WindowUp() then
        ReadLater(INSPECT_RETRY)
        return
    end
    for i = #queue, 1, -1 do
        local unit = queue[i]
        local m = members[unit]
        if not (m and m.guid and UnitIsConnected(unit)) then
            table.remove(queue, i)
            queued[unit] = nil
        elseif CanInspect(unit) then
            table.remove(queue, i)
            readUnit, readGUID = unit, m.guid
            evt:RegisterEvent("INSPECT_READY")
            NotifyInspect(unit)
            local guid = m.guid
            C_Timer.After(INSPECT_WAIT, function() ReadTimedOut(guid) end)
            return
        end
    end
    -- whoever is left is out of range
    if #queue > 0 then ReadLater(INSPECT_RETRY) end
end

local function AskRead(unit, renew)
    if queued[unit] then
        if not renew then return end
        for _, u in ipairs(queue) do
            if u == unit then return end
        end
    end
    queued[unit] = true
    queue[#queue + 1] = unit
    NextRead()
end

-- a talent swap before the key
local function ReReadStale()
    if KeyRunning() then return end
    local now = GetTime()
    for i = 2, #UNITS do
        local m = members[UNITS[i]]
        if m and m.guid and (not m.readAt or now - m.readAt >= INSPECT_FRESH) then AskRead(UNITS[i]) end
    end
end

-- ---------------------------------------------------------------- roster

local function IsPlayer(unit)
    local v = UnitIsPlayer(unit)
    return Secret(v) or v
end

local function SyncRoster()
    local changed = false
    for _, unit in ipairs(UNITS) do
        local m = members[unit]
        if not m then
            m = { unit = unit }
            members[unit] = m
        end
        if UnitExists(unit) and (unit == "player" or IsPlayer(unit)) then
            local guid = Plain(UnitGUID(unit))
            if guid and guid ~= m.guid then
                wipe(m)
                m.unit, m.guid = unit, guid
                changed = true
                if unit ~= "player" then AskRead(unit, true) end
            end
            -- a hidden read keeps the last plain one: a new occupant wiped it above
            local _, class = UnitClass(unit)
            m.class = Plain(class) or m.class
            m.role = Plain(UnitGroupRolesAssigned(unit)) or m.role
            if m.class == "WARLOCK" then m.demon = DemonKick(unit) end
            if unit == "player" then
                if RefreshPlayer(m) then changed = true end
            elseif Resolve(m) then
                changed = true
            end
        elseif m.guid then
            wipe(m)
            m.unit = unit
            changed = true
        end
    end
    if changed then Fire("roster") end
end

-- a member an inspect never reached: the meter's rows name their spec once combat ends
local function LearnSpecs()
    if InCombatLockdown() then return end
    local ok, s = pcall(DM.GetCombatSessionFromType, ALL, DMG)
    local list = ok and type(s) == "table" and not Secret(s) and s.combatSources
    if type(list) ~= "table" or Secret(list) then return end
    local changed = false
    for _, r in ipairs(list) do
        if type(r) == "table" and not Secret(r) then
            local guid, icon = Plain(r.sourceGUID), r.specIconID
            if guid and type(icon) == "number" and not Secret(icon) then
                for i = 2, #UNITS do
                    local m = members[UNITS[i]]
                    if m and m.guid == guid and not m.specRead then
                        for _, rec in ipairs(ns.AllSpecs()) do
                            if rec.classToken == m.class and rec.icon == icon and m.spec ~= rec.id then
                                m.spec = rec.id
                                if Resolve(m) then changed = true end
                            end
                        end
                    end
                end
            end
        end
    end
    if changed then Fire("roster") end
end

-- ---------------------------------------------------------------- the meter

-- by GUID, party slots close up: entries in each member's kicked-spell list, their count (hidden in combat)
local curN, curA, prevN, prevA = {}, {}, {}, {}
local readT = -1
local session
local ownT, ownDone = -1, true
local gateList = {}

local function Source(guid)
    local ok, src = pcall(DM.GetCombatSessionSourceFromType, CUR, INT, guid)
    if not ok or type(src) ~= "table" or Secret(src) then return nil end
    local spells = src.combatSpells
    if type(spells) ~= "table" or Secret(spells) then return nil end
    return #spells, src.totalAmount
end

-- the one warlock row with no spec: a demon the meter gives no source of its own
local function DemonRow()
    local ok, s = pcall(DM.GetCombatSessionFromType, CUR, INT)
    local list = ok and type(s) == "table" and not Secret(s) and s.combatSources
    if type(list) ~= "table" or Secret(list) then return nil end
    local amount, n = nil, 0
    for _, r in ipairs(list) do
        if type(r) == "table" and not Secret(r) and not Secret(r.classFilename) and not Secret(r.specIconID)
            and r.classFilename == "WARLOCK" and r.specIconID == nil then
            n = n + 1
            amount = r.totalAmount
        end
    end
    if n == 1 then return amount end
end

local function ReadCounts()
    wipe(curN)
    wipe(curA)
    local lost, demons = nil, 0
    for i = 2, #UNITS do
        local u = UNITS[i]
        local m = members[u]
        if m and m.guid and m.kick then
            local n, a
            if KD.OnDemon(m.kick) then
                demons = demons + 1
                local pet = UnitExists(PET[u]) and Plain(UnitGUID(PET[u]))
                if pet then n, a = Source(pet) end
                if not n or n == 0 then n, a, lost = nil, nil, u end
            else
                n, a = Source(m.guid)
            end
            if n then curN[m.guid], curA[m.guid] = n, a end
        end
    end
    if lost and demons == 1 then
        local a = DemonRow()
        -- a row exists once its source has kicked
        if type(a) == "number" then curN[members[lost].guid], curA[members[lost].guid] = 1, a end
    end
    -- a failed read keeps the last count: neither a new fight nor a kick
    for i = 2, #UNITS do
        local g = members[UNITS[i]] and members[UNITS[i]].guid
        if g and curN[g] == nil and prevN[g] ~= nil then curN[g], curA[g] = prevN[g], prevA[g] end
    end
end

local function SessionID()
    local ok, s = pcall(DM.GetCombatSessionFromType, CUR, INT)
    if not ok or type(s) ~= "table" or Secret(s) then return nil end
    local id = s.sessionID
    if type(id) == "number" and not Secret(id) then return id end
end

local function Compare()
    local fell, rose = false, false
    for i = 2, #UNITS do
        local g = members[UNITS[i]] and members[UNITS[i]].guid
        if g then
            local c, p = curN[g] or 0, prevN[g] or 0
            if c < p then fell = true elseif c > p then rose = true end
        end
    end
    return fell, rose
end

local function Adopt()
    prevN, curN = curN, prevN
    prevA, curA = curA, prevA
end

-- a new fight restarts the counts: they're the baseline, or its first kicks read as nothing new
local function Rebase(force)
    if not force and GetTime() == readT then return end
    local sid = SessionID()
    if not force and sid and sid == session then return end
    ReadCounts()
    if not force and not sid then
        -- the ID is hidden in combat: a rise is a kick whose own update reads it this frame
        local fell, rose = Compare()
        if rose and not fell then return end
    end
    Adopt()
    session = sid
end

local function StillDown(m, T)
    local cd = m.talents and m.landed or m.shortest
    return (m.sureT and cd and T - m.sureT < cd - SLACK) and true or false
end

local function OnMeter()
    local T = GetTime()
    if T == readT then return end
    readT = T
    stats.updates = stats.updates + 1
    ReadCounts()
    if Compare() then
        wipe(prevN)
        wipe(prevA)
    end
    session = SessionID() or session
    wipe(gateList)
    for i = 2, #UNITS do
        local u = UNITS[i]
        local m = members[u]
        if m and m.guid and m.kick then
            local g = m.guid
            local n, p = curN[g] or 0, prevN[g] or 0
            if n > p then
                stats.sure = stats.sure + 1
                m.sureT = T
                StartCd(m, T, m.landed)
            elseif n >= 1 and p >= 1 and type(prevA[g]) == "number" and type(curA[g]) == "number"
                and not StillDown(m, T) then
                gateList[#gateList + 1] = u
            end
        end
    end
    local me = members.player
    if me and not ownDone and T - ownT <= OWN_WINDOW then
        ownDone = true
        if me.landed ~= me.cd then StartCd(me, ownT, me.landed) end
    end
    if #gateList > 0 then
        stats.gates = stats.gates + 1
        Fire("gate", T, gateList, prevA, curA)
    end
    Adopt()
end

local function OnOwnCast(spellID)
    if Secret(spellID) then return end
    local kick = KD.CastKick(spellID)
    local m = members.player
    if not (kick and m and m.guid) then return end
    if m.kick ~= kick then
        m.kick = kick
        m.cd, m.landed = KD.Cooldown(kick, m.spec, m.talents)
        Fire("roster")
    end
    ownT, ownDone = GetTime(), false
    StartCd(m, ownT, m.cd)
end

-- ---------------------------------------------------------------- events

local EVENTS = {
    "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_RESET",
    "GROUP_ROSTER_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED", "SPELLS_CHANGED",
    "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_REGEN_ENABLED", "CHALLENGE_MODE_START", "PLAYER_ENTERING_WORLD",
}

local rosterQueued = false
local function QueueRoster()
    if rosterQueued then return end
    rosterQueued = true
    C_Timer.After(0, function()
        rosterQueued = false
        if not active then return end
        SyncRoster()
        LearnSpecs()
    end)
end

local function OnEvent(_, event, a1, a2, a3)
    if event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        if a1 == INT then OnMeter() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnOwnCast(a3)
    elseif event == "DAMAGE_METER_CURRENT_SESSION_UPDATED" then
        Rebase()
    elseif event == "DAMAGE_METER_RESET" then
        Rebase(true)
    elseif event == "GROUP_ROSTER_UPDATE" then
        QueueRoster()
    elseif event == "UNIT_PET" then
        local m = members[a1]
        if m and m.class == "WARLOCK" then
            m.demon = DemonKick(a1)
            if Resolve(m) then Fire("roster") end
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local m = a1 and members[a1]
        if a1 == "player" then
            if m and RefreshPlayer(m) then Fire("roster") end
        elseif m and m.guid then
            m.spec, m.specRead, m.talents, m.readAt = nil, nil, nil, nil
            if Resolve(m) then Fire("roster") end
            AskRead(a1)
        end
    elseif event == "TRAIT_CONFIG_UPDATED" or event == "SPELLS_CHANGED" then
        if members.player and RefreshPlayer(members.player) then Fire("roster") end
    elseif event == "INSPECT_READY" then
        OnInspect(a1)
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
        local T = Enum.AddOnRestrictionType
        if T and a1 == T.Combat and a2 == (Enum.AddOnRestrictionState and Enum.AddOnRestrictionState.Inactive or 0) then
            LearnSpecs()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        LearnSpecs()
        ReReadStale()
        NextRead()
    elseif event == "CHALLENGE_MODE_START" then
        -- the last chance before the key locks inspects
        ReReadStale()
        NextRead()
    elseif event == "PLAYER_ENTERING_WORLD" then
        for _, m in pairs(members) do
            m.downAt, m.downFor, m.sureT = nil, nil, nil
        end
        ownDone = true
        SyncRoster()
        Rebase(true)
        ReReadStale()
        Fire("roster")
    end
end

function M.Start(h)
    handlers = h
    if active or not (DM and INT and CUR) then return end
    active = true
    if not evt then
        evt = CreateFrame("Frame")
        evt:SetScript("OnEvent", OnEvent)
    end
    for _, e in ipairs(EVENTS) do evt:RegisterEvent(e) end
    evt:RegisterUnitEvent("UNIT_PET", "player", "party1", "party2", "party3", "party4")
    evt:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
    readT = -1
    SyncRoster()
    Rebase(true)
    LearnSpecs()
    ReReadStale()
    NextRead()
end

function M.Stop()
    handlers = nil
    if not active then return end
    active = false
    evt:UnregisterAllEvents()
    if readUnit then ReadDone() end
    wipe(queue)
    wipe(queued)
    wipe(members)
    wipe(prevN)
    wipe(prevA)
    session = nil
    ownDone = true
end

function M.Member(unit) return members[unit] end

function M.Cooldown(unit)
    local m = members[unit]
    if m and m.downAt and m.downAt + m.downFor > GetTime() then return m.downAt, m.downFor end
end

ns.SlashCommand("kick", function()
    local P = function(s) print("|cFF8080FFthingsUI|r " .. s) end
    if not active then
        P("Kick Tracker isn't running (off, or its Visibility rules say no).")
        return
    end
    P(("meter updates %d | named %d | gated %d | key %s"):format(stats.updates, stats.sure, stats.gates, tostring(KeyRunning())))
    for _, u in ipairs(UNITS) do
        local m = members[u]
        if m and m.guid then
            local nm = m.kick and C_Spell.GetSpellName(m.kick)
            P(("%s %s spec %s: %s %s s (landed %s), talents %s, list %s"):format(u, tostring(m.class), tostring(m.spec),
                tostring(nm), tostring(m.cd), tostring(m.landed), m.talents and "read" or "NOT read", tostring(prevN[m.guid])))
        end
    end
end)
