local addon, ns = ...
local E = ns.E
local TUI = ns.TUI

ns.CDMGlow = ns.CDMGlow or {}

local LCG
local VIEWERS = { EssentialCooldownViewer = true, UtilityCooldownViewer = true }
local state = setmetatable({}, { __mode = "k" })
local hooked = false

local function DB()
    local db = E.db.thingsUI and E.db.thingsUI.cdmIcons
    return db and db.glow
end

local function Lib()
    if not LCG then LCG = LibStub and LibStub("LibCustomGlow-1.0", true) end
    return LCG
end

local function ManagedChild(frame)
    local p = frame
    for _ = 1, 3 do
        p = p.GetParent and p:GetParent()
        if not p then return false end
        local n = p.GetName and p:GetName()
        if n and VIEWERS[n] then return true end
    end
    return false
end

local function GlowColor(g)
    if not g.useColor then return nil end
    local c = g.customColor or {}
    return { c.r or 1, c.g or 0.85, c.b or 0.1, c.a or 1 }
end

local function StopAll(frame)
    local lib = Lib()
    if not lib then return end
    lib.PixelGlow_Stop(frame)
    lib.AutoCastGlow_Stop(frame)
    lib.ButtonGlow_Stop(frame)
    lib.ProcGlow_Stop(frame)
end

local function ShowFX(frame)
    local g, lib = DB(), Lib()
    if not (g and lib) then return end
    local st = state[frame]
    if not st then st = {} state[frame] = st end
    local alert = frame.SpellActivationAlert
    if alert then
        alert:SetAlpha(0)
        st.nativeAlert = alert
    end
    local style = g.style or "pixel"
    if st.style and st.style ~= style then StopAll(frame) end
    st.style = style
    local color = GlowColor(g)
    local off = g.offset or 0
    if style == "autocast" then
        lib.AutoCastGlow_Start(frame, color, g.particles or 4, g.frequency or 0.125, g.scale or 1, off, off)
    elseif style == "proc" then
        lib.ProcGlow_Start(frame, { color = color, xOffset = off, yOffset = off })
    elseif style == "button" then
        lib.ButtonGlow_Start(frame, color, g.frequency or 0.125)
    else
        lib.PixelGlow_Start(frame, color, g.lines or 8, g.frequency or 0.25, nil, g.thickness or 2, off, off)
    end
    st.glowing = true
end

local function HideFX(frame)
    local st = state[frame]
    if not st then return end
    if st.nativeAlert then
        st.nativeAlert:SetAlpha(1)
        st.nativeAlert = nil
    end
    if st.glowing then
        StopAll(frame)
        st.glowing = false
    end
end

local function OnShowAlert(_, frame)
    local g = DB()
    if not (g and g.enabled) then return end
    if not (state[frame] or ManagedChild(frame)) then return end
    ShowFX(frame)
end

local function OnHideAlert(_, frame)
    if state[frame] then HideFX(frame) end
end

function TUI:UpdateCDMGlow()
    local g = DB()
    if not hooked and g and _G.ActionButtonSpellAlertManager then
        hooked = true
        hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", OnShowAlert)
        hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", OnHideAlert)
    end
    if g and g.enabled then
        for frame, st in pairs(state) do
            if st.glowing or st.nativeAlert then ShowFX(frame) end
        end
    else
        for frame in pairs(state) do HideFX(frame) end
    end
end
