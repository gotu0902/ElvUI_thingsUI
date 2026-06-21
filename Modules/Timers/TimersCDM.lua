local _, ns = ...

ns.TimersCDM = ns.TimersCDM or {}
local M = ns.TimersCDM

local ipairs, pairs, wipe, tconcat = ipairs, pairs, wipe, table.concat

local buttons = {}
local listFor = { essential = {}, utility = {} }
local lastSig = ""

local function EnsureButton(timer)
    local btn = buttons[timer.id]
    if not btn then
        btn = ns.TimersRender.CreateButton(_G.UIParent, "TUI_TimerCDM" .. timer.id, function() M.Refresh() end)
        buttons[timer.id] = btn
    end
    return btn
end

function M.Refresh()
    if not (ns.Timers and ns.TimersRender) then return end
    wipe(listFor.essential)
    wipe(listFor.utility)
    local sig = {}
    for _, timer in ipairs(ns.Timers.GetTimers()) do
        local key = timer.destination
        if timer.enabled and (key == "essential" or key == "utility") then
            local btn = EnsureButton(timer)
            local list = listFor[key]
            local i = #list + 1
            btn.layoutIndex = 100000 + i
            btn:Show()
            list[i] = btn
            ns.TimersRender.Update(btn, timer)
            sig[#sig + 1] = key .. ":" .. timer.id
        else
            local btn = buttons[timer.id]
            if btn then btn:Hide(); btn.layoutIndex = nil end
        end
    end

    for id, btn in pairs(buttons) do
        local t = ns.Timers.GetByID(id)
        if not (t and t.enabled and (t.destination == "essential" or t.destination == "utility")) then
            btn:Hide(); btn.layoutIndex = nil
        end
    end

    local s = tconcat(sig, ",")
    if s ~= lastSig then
        lastSig = s
        if ns.CDMIcons and ns.CDMIcons.RefreshAll then ns.CDMIcons.RefreshAll() end

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

if ns.Timers and ns.Timers.AddHostRefresh then
    ns.Timers.AddHostRefresh(M.Refresh)
end
if ns.Timers and ns.Timers.AddHostRepaint then
    ns.Timers.AddHostRepaint(M.Refresh)
end

if ns.TimersRender and ns.TimersRender.RegisterGlowHost then
    ns.TimersRender.RegisterGlowHost(function()
        for id, btn in pairs(buttons) do
            if btn:IsShown() then
                local t = ns.Timers and ns.Timers.GetByID(id)
                if t then ns.TimersRender.UpdateGlow(btn, t) end
            end
        end
    end)
end
