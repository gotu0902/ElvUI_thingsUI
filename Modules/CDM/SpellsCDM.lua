local _, ns = ...
local E = ns.E

-- Spell Editor spells the Cooldown Manager doesn't list, shown in Essential or Utility
ns.SpellsCDM = ns.SpellsCDM or {}
local M = ns.SpellsCDM
local H = ns.CDHelpers

local pairs, ipairs, wipe, tconcat, tsort = pairs, ipairs, wipe, table.concat, table.sort

local buttons   = {}
local synthetic = {}
local listFor   = { essential = {}, utility = {} }
local shown     = {}
local order     = {}
local lastSig   = ""

local function Store()
    local cdm = E.db and E.db.thingsUI and E.db.thingsUI.cdmIcons
    return cdm and cdm.perSpell or {}
end

local function EnsureButton(id)
    local btn = buttons[id]
    if not btn then
        btn = ns.TimersRender.CreateButton(_G.UIParent, "TUI_SpellCDM" .. id, function() M.RefreshCooldowns() end)
        buttons[id] = btn
    end
    return btn
end

-- the timer engine draws it: the cooldown of the rank you know, always shown
local function Synthetic(id, cast)
    local t = synthetic[id]
    if not t then
        t = { id = "spellcdm:" .. id, kind = "spell", showCDTimer = false, trackCooldown = true, showIdle = true }
        synthetic[id] = t
    end
    t.spellID = cast
    return t
end

local function CustomIcon(t, o)
    t.iconID = o.customIcon
    return t
end

function M.RefreshCooldowns()
    if not ns.TimersRender then return end
    for id, btn in pairs(buttons) do
        if btn:IsShown() and synthetic[id] then ns.TimersRender.Update(btn, synthetic[id]) end
    end
end

function M.Refresh()
    if not (ns.TimersRender and E.db and E.db.thingsUI) then return end
    wipe(listFor.essential)
    wipe(listFor.utility)
    wipe(shown)
    wipe(order)
    local store = Store()
    for id, o in pairs(store) do
        if type(o) == "table" and listFor[o.row] then order[#order + 1] = id end
    end
    tsort(order)
    local CI = ns.CDMIcons
    local sig = {}
    for _, id in ipairs(order) do
        local o = store[id]
        local cast = H.CastID(id)
        -- the CDM shows it after all: no second copy
        local native = cast and CI and CI.ChildForSpell and (CI.ChildForSpell(cast) or CI.ChildForSpell(id))
        -- Spell Editor > Show, like on the CDM's own frames
        local ruled = (o.visibility and not ns.Visibility.Shown(o.visibility))
            or (cast and o.cdState and CI and CI.CDStateHides and CI.CDStateHides(cast, o.cdState))
        if cast and not native and not ruled then
            local list = listFor[o.row]
            local btn = EnsureButton(id)
            local i = #list + 1
            btn.layoutIndex = (o.rowIndex or 30) - 0.4 + i * 0.001
            btn:Show()
            list[i] = btn
            shown[id] = true
            ns.TimersRender.Update(btn, CustomIcon(Synthetic(id, cast), o))
            sig[#sig + 1] = o.row .. ":" .. id .. ":" .. (o.rowIndex or 30)
        end
    end
    for id, btn in pairs(buttons) do
        if not shown[id] then btn:Hide(); btn.layoutIndex = nil end
    end

    local s = tconcat(sig, ",")
    if s ~= lastSig then
        lastSig = s
        if CI and CI.RefreshAll then CI.RefreshAll() end
        if ns.CDMText and ns.CDMText.RefreshAll then ns.CDMText.RefreshAll() end
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

local cdPending = false
local function ThrottledCooldowns()
    if cdPending or not next(shown) then return end
    cdPending = true
    C_Timer.After(0.1, function() cdPending = false; M.RefreshCooldowns() end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:RegisterEvent("SPELL_UPDATE_CHARGES")
ev:SetScript("OnEvent", function(_, event)
    if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
        ThrottledCooldowns()
    else
        C_Timer.After(0, M.Refresh)
    end
end)
H.OnCastChange(function() if next(shown) then M.RefreshCooldowns() end end)
ns.Visibility.OnChange(function() if next(order) then M.Refresh() end end)
