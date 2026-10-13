local _, ns = ...
local E = ns.E
local TUI = ns.TUI

-- ElvUI's Bar 2 is action page 2 (slots 13-24); Bar 13 is page 13 (slots
-- 145-156), the one Blizzard and EllesmereUI show as Action Bar 6. The shown
-- bar is a profile setting, WoW keeps the spells per spec and a key drives
-- one bar. A copy keeps its source, the keys follow the bar the profile shows.
local M = {}
ns.BarCopy = M

local COUNT = 12
M.ORDER = { "bar2", "bar13" }
M.BARS = {
    bar2  = { label = "Bar 2",  note = "action page 2",                       base = 12,  cmd = "ELVUIBAR2BUTTON" },
    bar13 = { label = "Bar 13", note = "Blizzard's and EllesmereUI's Bar 6", base = 144, cmd = "MULTIACTIONBAR5BUTTON" },
}
local BARS = M.BARS
local OTHER = { bar2 = "bar13", bar13 = "bar2" }
M.OTHER = OTHER

local function Say(msg) print("|cFF8080FFthingsUI|r Action Bars: " .. msg) end

local function DB()
    local db = E.db.thingsUI
    db.actionBarCopy = db.actionBarCopy or {}
    return db.actionBarCopy
end

local function IsSecret(v) return issecretvalue and issecretvalue(v) end

function M.Slot(key, i) return BARS[key].base + i end
local Slot = M.Slot

function M.IsShown(key)
    local b = E.db.actionbar and E.db.actionbar[key]
    return (b and b.enabled) and true or false
end

-- the one of the two the profile shows; nil when both or neither
function M.ShownBar()
    local a, b = M.IsShown("bar2"), M.IsShown("bar13")
    if a == b then return nil end
    return a and "bar2" or "bar13"
end

local function SameAction(a, b)
    local ta, ia = GetActionInfo(a)
    local tb, ib = GetActionInfo(b)
    if IsSecret(ta) or IsSecret(ia) or IsSecret(tb) or IsSecret(ib) then return false end
    return ta == tb and ia == ib
end

function M.CountSpells(key)
    local n = 0
    for i = 1, COUNT do
        if HasAction(Slot(key, i)) then n = n + 1 end
    end
    return n
end

function M.KeysOf(key, i) return { GetBindingKey(BARS[key].cmd .. i) } end

function M.CountKeys(key)
    local n = 0
    for i = 1, COUNT do n = n + #M.KeysOf(key, i) end
    return n
end

-- buttons of toKey that a copy from fromKey would change
function M.Changes(fromKey, toKey)
    local list = {}
    for i = 1, COUNT do
        if not SameAction(Slot(fromKey, i), Slot(toKey, i)) then list[#list + 1] = i end
    end
    return list
end

-- filled buttons of toKey a copy would replace or clear
function M.Lost(fromKey, toKey)
    local lost = 0
    for _, i in ipairs(M.Changes(fromKey, toKey)) do
        if HasAction(Slot(toKey, i)) then lost = lost + 1 end
    end
    return lost
end

-- ------------------------------------------------------------------ keys

local keysAtRegen
function M.MoveKeysTo(toKey)
    if InCombatLockdown() then keysAtRegen = toKey; return 0 end
    local from = OTHER[toKey]
    local moves = {}
    for i = 1, COUNT do
        for _, k in ipairs(M.KeysOf(from, i)) do moves[#moves + 1] = { k, BARS[toKey].cmd .. i } end
    end
    if #moves == 0 then return 0 end
    for _, m in ipairs(moves) do SetBinding(m[1], m[2]) end
    SaveBindings(GetCurrentBindingSet())
    return #moves
end

local function FollowKeys()
    if not DB().keysFollow then return 0, nil end
    local shown = M.ShownBar()
    if not shown then return 0, nil end
    return M.MoveKeysTo(shown), shown
end

function M.MoveKeys(toKey)
    if InCombatLockdown() then Say("not in combat."); return end
    Say(("moved %d keybind(s) to %s."):format(M.MoveKeysTo(toKey), BARS[toKey].label))
end

function M.AutoFollow()
    local n, shown = FollowKeys()
    if n > 0 then
        Say(("moved %d keybind(s) to %s, the bar this profile shows."):format(n, BARS[shown].label))
    end
end

-- ------------------------------------------------------------------ copy

-- auto: the per-spec fill, which only ever runs onto an empty bar
local function DoCopy(fromKey, toKey, auto)
    if InCombatLockdown() then Say("not in combat."); return end
    ClearCursor()
    for i = 1, COUNT do
        local s, d = Slot(fromKey, i), Slot(toKey, i)
        if not SameAction(s, d) then
            if HasAction(s) then
                -- true: a copy, the source keeps its action
                PickupAction(s, true)
                PlaceAction(d)
            elseif HasAction(d) then
                PickupAction(d)
            end
            -- only ever the target's old action or an undelivered copy
            ClearCursor()
        end
    end
    local keys = FollowKeys()
    -- the slots settle a moment later; report what actually arrived
    C_Timer.After(0.5, function()
        if InCombatLockdown() then return end
        local missed = M.Changes(fromKey, toKey)
        local msg
        if #missed == 0 and auto then
            msg = ("%s was empty on this spec: filled it from %s."):format(BARS[toKey].label, BARS[fromKey].label)
        elseif #missed == 0 then
            msg = ("copied %s onto %s for this spec."):format(BARS[fromKey].label, BARS[toKey].label)
        else
            msg = ("%d button(s) did not copy onto %s: %s."):format(#missed, BARS[toKey].label, table.concat(missed, ", "))
        end
        if keys > 0 then msg = msg .. (" %d keybind(s) moved to the shown bar."):format(keys) end
        Say(msg)
        ns.NotifyChange()
    end)
end

function M.Copy(fromKey, toKey)
    if InCombatLockdown() then Say("not in combat."); return end
    if #M.Changes(fromKey, toKey) == 0 then
        Say(BARS[toKey].label .. " already matches " .. BARS[fromKey].label .. ".")
        return
    end
    DoCopy(fromKey, toKey)
end

-- WoW keeps action bars per spec: a spec never set up still has its spells
-- on the other bar. Only ever fills a bar with nothing on it.
local fillAtRegen = false
function M.AutoFill()
    if not DB().autoFill then return end
    if InCombatLockdown() then fillAtRegen = true; return end
    fillAtRegen = false
    local shown = M.ShownBar()
    if not shown then return end
    local other = OTHER[shown]
    if M.CountSpells(shown) == 0 and M.CountSpells(other) > 0 then
        DoCopy(other, shown, true)
    end
end

-- a profile showing the other bar
function M.OnProfile()
    C_Timer.After(1, M.AutoFollow)
    C_Timer.After(2, M.AutoFill)
end

-- ---------------------------------------------------------------- wiring

local pending = false
local function RefreshOptions()
    if pending then return end
    pending = true
    C_Timer.After(0.2, function()
        pending = false
        local ACD = E.Libs and E.Libs.AceConfigDialog
        if ACD and ACD.OpenFrames and ACD.OpenFrames.ElvUI then ns.NotifyChange() end
    end)
end

local booted = false
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        if booted then return end
        booted = true
        C_Timer.After(3, M.AutoFollow)
        C_Timer.After(4, M.AutoFill)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- the new spec's action bars arrive a moment after the event
        if arg1 == "player" then C_Timer.After(2, M.AutoFill) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if fillAtRegen then M.AutoFill() end
        if keysAtRegen then
            local k = keysAtRegen
            keysAtRegen = nil
            M.MoveKeysTo(k)
        end
        RefreshOptions()
    elseif not InCombatLockdown() then
        -- action info can be secret in combat; the regen event catches up
        RefreshOptions()
    end
end)
