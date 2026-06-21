local _, ns = ...
local E = ns.E
local TUI = ns.TUI

ns.RacialsCDM = ns.RacialsCDM or {}
local M = ns.RacialsCDM

local ipairs, pairs, wipe, tconcat = ipairs, pairs, wipe, table.concat

local buttons   = {}                               -- [spellID] = our button
local synthetic = {}                               -- [spellID] = reused synthetic timer
local listFor   = { essential = {}, utility = {} } -- per-viewer shown buttons (layoutIndex)
local lastSig   = ""

local function DB() return E.db and E.db.thingsUI and E.db.thingsUI.racialsCDM end

local function EnsureButton(spellID)
    local btn = buttons[spellID]
    if not btn then
        btn = ns.TimersRender.CreateButton(_G.UIParent, "TUI_RacialCDM" .. spellID,
            function() M.RefreshCooldowns() end)
        buttons[spellID] = btn
    end
    return btn
end

-- A fake "timer" so TimersRender.Update renders the racial's spell cooldown + desat for us.
local function SyntheticTimer(spellID)
    local t = synthetic[spellID]
    if not t then
        t = { id = "racial:" .. spellID, kind = "spell", spellID = spellID,
              showCDTimer = false, trackCooldown = true, showIdle = true }
        synthetic[spellID] = t
    end
    return t
end

-- DYNAMIC: Essential if it has room (native icon count < threshold), else Utility.
local function ResolveDynamic()
    local ev = _G.EssentialCooldownViewer
    local native = 0
    if ev then
        for i = 1, ev:GetNumChildren() do
            local c = select(i, ev:GetChildren())
            if c and c:IsShown() and c.GetCooldownID then native = native + 1 end
        end
    end
    local threshold = (DB() and DB().dynamicThreshold) or 8
    return (native >= threshold) and "utility" or "essential"
end

local function HasRacial(spellID)
    local CG = ns.CustomGroups
    if CG and CG.PlayerHasRacial then return CG.PlayerHasRacial(spellID) end
    return true
end

-- Cheap re-render of the shown buttons (cooldown swirl + desat) - no re-fold.
function M.RefreshCooldowns()
    if not ns.TimersRender then return end
    for spellID, btn in pairs(buttons) do
        if btn:IsShown() then ns.TimersRender.Update(btn, SyntheticTimer(spellID)) end
    end
end

-- Full layout: which racials show, in which viewer; re-fold only when the SET changes.
function M.Refresh()
    if not (ns.TimersRender and DB()) then return end
    wipe(listFor.essential)
    wipe(listFor.utility)
    local dest = DB().dest or {}
    local sig = {}
    for _, spellID in ipairs(ns.Racials or {}) do
        local d = dest[spellID]
        if d and d ~= "off" and HasRacial(spellID) then
            local key = (d == "dynamic") and ResolveDynamic() or d
            local list = listFor[key]
            if list then
                local btn = EnsureButton(spellID)
                local i = #list + 1
                btn.layoutIndex = 90000 + i   -- END, after native icons but before Timers (100000)
                btn:Show()
                list[i] = btn
                ns.TimersRender.Update(btn, SyntheticTimer(spellID))
                sig[#sig + 1] = key .. ":" .. spellID
            end
        else
            local btn = buttons[spellID]
            if btn then btn:Hide(); btn.layoutIndex = nil end
        end
    end
    local s = tconcat(sig, ",")
    if s ~= lastSig then
        lastSig = s
        if ns.CDMIcons and ns.CDMIcons.RefreshAll then ns.CDMIcons.RefreshAll() end
        if ns.CDMText and ns.CDMText.RefreshAll then ns.CDMText.RefreshAll() end
        -- A racial joining/leaving resizes the viewer
        C_Timer.After(0, function()
            if ns.EssentialMover and ns.EssentialMover.Apply then ns.EssentialMover.Apply() end
            if ns.BarSetup and ns.BarSetup.ApplyStack then ns.BarSetup.ApplyStack() end
            if ns.TUI and ns.TUI.UpdateClusterPositioning then ns.TUI:UpdateClusterPositioning() end
            if ns.MoverSync and ns.MoverSync.Queue then ns.MoverSync.Queue() end
        end)
    end
end

function M.GetInlineButtonsFor(viewer)
    if viewer == _G.EssentialCooldownViewer then
        return (#listFor.essential > 0) and listFor.essential or nil
    elseif viewer == _G.UtilityCooldownViewer then
        return (#listFor.utility > 0) and listFor.utility or nil
    end
end

function TUI:UpdateRacialsCDM() M.Refresh() end

local cdPending = false
local function ThrottledCooldowns()
    if cdPending then return end
    cdPending = true
    C_Timer.After(0.1, function() cdPending = false; M.RefreshCooldowns() end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:SetScript("OnEvent", function(_, event)
    if event == "SPELL_UPDATE_COOLDOWN" then ThrottledCooldowns() else M.Refresh() end
end)
