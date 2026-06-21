local _, ns = ...
local E = ns.E

ns.TimersStandalone = ns.TimersStandalone or {}
local M = ns.TimersStandalone

local CreateFrame, GetTime, ipairs, pairs = CreateFrame, GetTime, ipairs, pairs

local state = {}

local function PlainName(timer)
    if timer.kind == "lust" then return "Hero / Lust" end
    if timer.kind == "spell" then
        return (C_Spell.GetSpellName and C_Spell.GetSpellName(timer.spellID)) or ("Spell " .. tostring(timer.spellID))
    end
    return (C_Item.GetItemInfo(timer.itemID)) or ("Item " .. tostring(timer.itemID))
end

local function PositionContainer(timer, c)
    local af = timer.anchorFrame or "UIParent"
    if af == "CUSTOM" then af = timer.anchorFrameCustom or "UIParent" end
    local target
    if af ~= "UIParent" then
        local SB = ns.SpecialBars
        target = (SB and SB.ResolveAnchorTarget and SB.ResolveAnchorTarget(af)) or _G[af]
    end
    c:ClearAllPoints()
    ns.Pixel.SetPoint(c, timer.anchorPoint or "CENTER", target or _G.UIParent,
        timer.anchorRelativePoint or "CENTER", timer.anchorXOffset or 0, timer.anchorYOffset or 0)
end

local function EnsureContainer(timer)
    local st = state[timer.id]
    if st and st.container then return st end
    st = st or {}
    state[timer.id] = st

    local size = timer.iconSize or 36
    local cname = "TUI_TimerStandalone" .. timer.id
    local c = CreateFrame("Frame", cname, _G.UIParent)
    c:SetSize(size, size)
    st.container = c
    PositionContainer(timer, c)

    st.btn = ns.TimersRender.CreateButton(c, cname .. "Icon", function() M.Refresh() end)
    st.btn:SetAllPoints(c)

    if not st.mover then
        local mname = "TUI_TimerStandaloneMover" .. timer.id
        st.mover = mname
        local ms = ns.MoverSync
        if ms and ms.CreateManaged then
            ms.CreateManaged(c, mname, "Timer: " .. PlainName(timer), {
                configString  = "thingsUI,modulesTab,timers,tmr" .. timer.id,
                shouldDisable = function()
                    local t = ns.Timers and ns.Timers.GetByID(timer.id)
                    return not (t and t.enabled and t.destination == "standalone")
                end,
                onSave = function(point, relPoint, x, y)
                    timer.anchorPoint = point
                    timer.anchorRelativePoint = relPoint
                    timer.anchorXOffset = x
                    timer.anchorYOffset = y
                    M.Refresh()
                    if ns.NotifyChange then ns.NotifyChange() end
                end,
            })
            if ms.Queue then ms.Queue() end
        end
    end
    return st
end

function M.Refresh()
    if not (ns.Timers and ns.TimersRender) then return end
    local now = GetTime()
    for _, timer in ipairs(ns.Timers.GetTimers()) do
        if timer.destination == "standalone" and timer.enabled then

            local st = EnsureContainer(timer)
            local size = timer.iconSize or 36
            ns.Pixel.SetSize(st.container, size, size)
            ns.Pixel.SetSize(st.btn, size, size)
            PositionContainer(timer, st.container)
            local idle = timer.showIdle and timer.kind ~= "lust"
            local show = idle or ns.TimersRender.TimerActive(timer, now) or (E and E.ConfigurationMode)
            if show then
                st.container:Show()
                ns.TimersRender.Update(st.btn, timer)

                if ns.CDMText and ns.CDMText.StyleChild then
                    ns.CDMText.StyleChild(st.btn, timer.text or { showCooldown = true })
                end
            else
                st.container:Hide()
            end
        elseif state[timer.id] and state[timer.id].container then
            state[timer.id].container:Hide()
        end
    end
    for id, st in pairs(state) do
        local t = ns.Timers.GetByID(id)
        local standalone = t and t.enabled and t.destination == "standalone"
        if not standalone and st.container then st.container:Hide() end
        if ns.MoverSync and ns.MoverSync.SetManagedEnabled then
            ns.MoverSync.SetManagedEnabled(st.mover, standalone)
        end
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
        for id, st in pairs(state) do
            local btn = st.btn
            if btn and btn:IsShown() then
                local t = ns.Timers and ns.Timers.GetByID(id)
                if t then ns.TimersRender.UpdateGlow(btn, t) end
            end
        end
    end)
end
