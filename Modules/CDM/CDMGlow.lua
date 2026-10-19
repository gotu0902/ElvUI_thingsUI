local addon, ns = ...
local E = ns.E
local TUI = ns.TUI

ns.CDMGlow = ns.CDMGlow or {}

local LCG
local VIEWERS = { EssentialCooldownViewer = true, UtilityCooldownViewer = true }
-- Spell Editor "Always" / "While Shown" glows, buffs included
local SYNC_VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer" }
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

-- Spell Editor settings of a CDM frame
local function Override(frame)
    local get = ns.CDMIcons and ns.CDMIcons.SpellSettings
    return get and get(frame)
end

local function GlowColor(g, o)
    local oc = o and o.glowColor
    if oc then return { oc.r or 1, oc.g or 1, oc.b or 1, 1 } end
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

local function ShowFX(frame, o)
    local g, lib = DB(), Lib()
    if not (g and lib) then return end
    local st = state[frame]
    if not st then st = {} state[frame] = st end
    local alert = frame.SpellActivationAlert
    if alert then
        alert:SetAlpha(0)
        st.nativeAlert = alert
    end
    -- a Spell Editor spell with its own style wins over Layout > Glow
    local fx = (o and o.glowFX) or g
    local style = fx.style or "pixel"
    if st.style and st.style ~= style then StopAll(frame) end
    st.style = style
    local color = GlowColor(g, o)
    local off = fx.offset or 0
    if style == "autocast" then
        lib.AutoCastGlow_Start(frame, color, fx.particles or 4, fx.frequency or 0.125, fx.scale or 1, off, off)
    elseif style == "proc" then
        lib.ProcGlow_Start(frame, { color = color, xOffset = off, yOffset = off })
    elseif style == "button" then
        lib.ButtonGlow_Start(frame, color, fx.frequency or 0.125)
    else
        lib.PixelGlow_Start(frame, color, fx.lines or 8, fx.frequency or 0.25, nil, fx.thickness or 2, off, off)
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
    local st = state[frame]
    if not st then st = {} state[frame] = st end
    st.proc = true
    local o = Override(frame)
    if o and o.glow == "never" then
        -- the proc stays dark; HideFX gives the native alert back
        local alert = frame.SpellActivationAlert
        if alert then
            alert:SetAlpha(0)
            st.nativeAlert = alert
        end
        return
    end
    if not st.always then ShowFX(frame, o) end
end

local function OnHideAlert(_, frame)
    local st = state[frame]
    if not st then return end
    st.proc = nil
    -- an Always glow outlives the proc
    if st.always then
        if st.nativeAlert then st.nativeAlert:SetAlpha(1); st.nativeAlert = nil end
        return
    end
    HideFX(frame)
end

local preview = false

-- Always glow from the Spell Editor, re-checked on every CDM layout pass; while the
-- options preview runs, a spell with its own glow color shows it too
function ns.CDMGlow.Sync(frame)
    local g = DB()
    local o = Override(frame)
    -- a buff only glows While Shown; its own color alone previews nothing
    local buff = frame:GetParent() == _G.BuffIconCooldownViewer
    local want = g and g.enabled and o
        and (o.glow == "always" or (preview and not buff and o.glow ~= "never" and o.glowColor ~= nil))
    local st = state[frame]
    if want then
        if not st then st = {} state[frame] = st end
        local c, fx = o.glowColor, o.glowFX
        local sig = (c and (("%s,%s,%s"):format(c.r, c.g, c.b)) or "")
            .. (fx and ("|%s,%s,%s,%s,%s,%s,%s"):format(tostring(fx.style), tostring(fx.lines), tostring(fx.thickness),
                tostring(fx.particles), tostring(fx.scale), tostring(fx.frequency), tostring(fx.offset)) or "")
        if not st.always or st.alwaysSig ~= sig then
            st.always, st.alwaysSig = true, sig
            ShowFX(frame, o)
        end
    elseif st and st.always then
        st.always, st.alwaysSig = nil, nil
        if st.proc and o and o.glow == "never" then
            StopAll(frame)
            st.glowing = false
        elseif st.proc then
            ShowFX(frame, o)
        else
            HideFX(frame)
        end
    end
end

function ns.CDMGlow.SetPreview(on)
    on = on and true or false
    if preview == on then return end
    preview = on
    TUI:UpdateCDMGlow()
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
            if st.glowing or st.nativeAlert then
                local o = Override(frame)
                if o and o.glow == "never" and not st.always then
                    if st.glowing then StopAll(frame); st.glowing = false end
                else
                    ShowFX(frame, o)
                end
            end
        end
    else
        for frame, st in pairs(state) do
            st.always, st.alwaysSig = nil, nil
            HideFX(frame)
        end
    end
    -- Always glows for frames that never procced yet
    for _, name in ipairs(SYNC_VIEWERS) do
        local v = _G[name]
        if v then
            for _, c in ipairs({ v:GetChildren() }) do
                if c.cooldownInfo then ns.CDMGlow.Sync(c) end
            end
        end
    end
end
