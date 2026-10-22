local _, ns = ...
local TUI = ns.TUI
local E   = ns.E
local Pixel = ns.Pixel

ns.CDMIcons = ns.CDMIcons or {}
ns.CDM_SPACING_INSET = ns.CDM_SPACING_INSET or 2
local M = ns.CDMIcons

local H = ns.CDHelpers
local IsSecret      = H.IsSecret
local NotSecret     = H.NotSecret
local GetDesatCurve = H.GetDesatCurve
local SetDesat      = H.SetDesat

local VIEWERS = {
    EssentialCooldownViewer = "essential",
    UtilityCooldownViewer   = "utility",
    BuffIconCooldownViewer  = "buffIcon",
}

-- pandemic window: Blizzard's frame, hidden, or a thingsUI glow (CDM > Layout > Aura Overlay)
local function PandemicMode(cdm)
    return (cdm and (cdm.pandemicMode or (cdm.hidePandemic and "hide"))) or "blizzard"
end

local function GlowLib() return LibStub and LibStub("LibCustomGlow-1.0", true) end

local pandemicGlow = setmetatable({}, { __mode = "k" })

local function StopPandemicGlow(child)
    local h = pandemicGlow[child] and child._tuiPandemicFX
    pandemicGlow[child] = nil
    local lib = GlowLib()
    if not (h and lib) then return end
    lib.PixelGlow_Stop(h)
    lib.AutoCastGlow_Stop(h)
    lib.ProcGlow_Stop(h)
    lib.ButtonGlow_Stop(h)
end

-- on a holder of its own, so it never shares LibCustomGlow's slot with the proc glow
local function StartPandemicGlow(child, cdm, o)
    local lib = GlowLib()
    if not lib then return end
    local h = child._tuiPandemicFX
    if not h then
        h = CreateFrame("Frame", nil, child)
        h:SetAllPoints(child)
        child._tuiPandemicFX = h
    end
    h:SetFrameLevel(child:GetFrameLevel() + 5)
    -- a Spell Editor spell's own look and color win over Layout > Aura Overlay
    local fx = (o and o.pandemicFX) or cdm.pandemicFX or {}
    local style = fx.style or "pixel"
    if pandemicGlow[child] and pandemicGlow[child] ~= style then StopPandemicGlow(child) end
    local c = (o and o.pandemicColor) or cdm.pandemicColor
    local color = c and { c.r or 1, c.g or 1, c.b or 1, 1 } or nil
    local off = fx.offset or 0
    if style == "autocast" then
        lib.AutoCastGlow_Start(h, color, fx.particles or 4, fx.frequency or 0.125, fx.scale or 1, off, off)
    elseif style == "proc" then
        lib.ProcGlow_Start(h, { color = color, xOffset = off, yOffset = off })
    elseif style == "button" then
        lib.ButtonGlow_Start(h, color, fx.frequency or 0.125)
    else
        lib.PixelGlow_Start(h, color, fx.lines or 8, fx.frequency or 0.25, nil, fx.thickness or 2, off, off)
    end
    pandemicGlow[child] = style
end

local function ClearPandemic(child)
    if not child then return end
    local p = child.PandemicIcon
    if not p then StopPandemicGlow(child) return end
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    local o = M.SpellSettings and M.SpellSettings(child)
    local mode = (o and o.pandemicMode) or PandemicMode(cdm)
    -- the frame is pooled: always set it, another icon may have hidden it
    p:SetAlpha(mode == "blizzard" and 1 or 0)
    if mode == "custom" then StartPandemicGlow(child, cdm or {}, o) else StopPandemicGlow(child) end
end

function M.ClearPandemicAll()
    for name in pairs(VIEWERS) do
        local v = _G[name]
        if v and v.GetItemFrames then
            for _, child in ipairs(v:GetItemFrames() or {}) do
                ClearPandemic(child)
            end
        end
    end
end

local VIEWER_BY_KEY = {
    essential = "EssentialCooldownViewer",
    utility   = "UtilityCooldownViewer",
    buffIcon  = "BuffIconCooldownViewer",
}

local overflowOut = {}
-- any Spell Editor Show rule set (visibility / cooldown state)
local anySpellRule, anyCDState = false, false

-- the viewer an icon shows in: an overflowed one sits in its target row
function M.ShownIn(child)
    for name, list in pairs(overflowOut) do
        for i = 1, #list do
            if list[i] == child then return name end
        end
    end
    local p = child:GetParent()
    return p and p.GetName and p:GetName()
end

local hookedViewers = {}
local hookedChildren = {}
local applyingChild  = {}
local pendingViewers = {}
local passiveHidden  = {}
local passiveDirty   = false
local pendingFrame   = CreateFrame("Frame")
local QueueLayout
local LayoutViewer

local proxies = {}
local function GetProxy(viewer)
    if not viewer then return nil end
    local name = viewer:GetName()
    local p = proxies[name]
    if not p then
        p = CreateFrame("Frame", "TUI_CDMProxy_" .. name, _G.UIParent)
        p:SetSize(1, 1)
        p:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
        proxies[name] = p
    end
    return p
end
M.GetProxy = GetProxy

function M.ProxyForName(name)
    if name and VIEWERS[name] then
        local v = _G[name]
        if v then return GetProxy(v) end
    end
    return nil
end

local GROWTH = {
    CENTERED_H = { axis = "H", pin = "CENTER", stepX =  1, stepY = -1 },
    CENTERED_V = { axis = "V", pin = "CENTER", stepX =  1, stepY = -1 },
    RIGHT      = { axis = "H", pin = "LEFT",   stepX =  1, stepY = -1 },
    LEFT       = { axis = "H", pin = "RIGHT",  stepX = -1, stepY = -1 },
    DOWN       = { axis = "V", pin = "TOP",    stepX =  1, stepY = -1 },
    UP         = { axis = "V", pin = "BOTTOM", stepX =  1, stepY =  1 },
}

local function GetViewerDB(viewerName)
    local key = VIEWERS[viewerName]
    if not key then return nil end
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    return cdm and cdm[key]
end

local function GetIconSize(vdb)
    if not vdb or not vdb.overrideSize then return nil, nil end
    local w = vdb.iconWidth or 36
    local h = vdb.lockAspect and w or (vdb.iconHeight or w)
    return w, h
end

local collectKids = {}
local function CollectAndHook(viewer, out, hookFn)
    for i = #out, 1, -1 do out[i] = nil end
    local kids = collectKids
    for i = 1, H.ChildrenInto(viewer, kids) do
        local c = kids[i]
        if c and c.GetCooldownID then
            if hookFn then hookFn(c, viewer) end

            if c:IsShown() and not (ns.yoinkedBars and ns.yoinkedBars[c]) and not passiveHidden[c] then
                out[#out + 1] = c
            end
        end
    end
    return out
end

local passiveMouse = {}
local pendingMouse = {}

local function SetChildMouse(child, on)
    if InCombatLockdown() then
        pendingMouse[child] = on
    else
        pendingMouse[child] = nil
        child:EnableMouse(on)
    end
end

local function ApplyPassiveState(child, hide)
    if hide then
        if not passiveHidden[child] then
            passiveHidden[child] = true
            passiveMouse[child] = child:IsMouseEnabled() and true or false
            child:SetAlpha(0)
            SetChildMouse(child, false)
        end
    elseif passiveHidden[child] then
        passiveHidden[child] = nil
        child:SetAlpha(1)
        SetChildMouse(child, passiveMouse[child] ~= false)
        passiveMouse[child] = nil
    end
end

local function PlainID(v)
    if IsSecret(v) then return nil end
    return v
end

-- a buff's own ids and the ones CDM links to it, against the auras we already show
-- a filter collection's token (set key) -> the client's test for one spell
local TOKEN_TEST = {
    BIG_DEFENSIVE      = C_UnitAuras and C_UnitAuras.AuraIsBigDefensive,
    EXTERNAL_DEFENSIVE = C_Spell and C_Spell.IsExternalDefensive,
    IMPORTANT          = C_Spell and C_Spell.IsSpellImportant,
    CROWD_CONTROL      = C_Spell and C_Spell.IsSpellCrowdControl,
}

local function AuraDup(info, sid, base, set)
    if (sid and set[sid]) or (base and set[base]) then return true end
    if sid then
        for token, test in pairs(TOKEN_TEST) do
            if set[token] then
                local r = test(sid)
                if NotSecret(r) and r then return true end
            end
        end
    end
    local linked = info and info.linkedSpellIDs
    if type(linked) == "table" and not IsSecret(linked) then
        for _, lid in ipairs(linked) do
            local id = PlainID(lid)
            if id and set[id] then return true end
        end
    end
    return false
end

-- shared with BuffBars, which lays out the bar row itself
local auraDupSet, auraDupSig
local function SetAuraDupSet(set)
    local keys = {}
    for id in pairs(set or {}) do keys[#keys + 1] = tostring(id) end
    table.sort(keys)
    local sig = table.concat(keys, ",")
    auraDupSet = set
    if sig ~= auraDupSig then
        auraDupSig = sig
        if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
    end
end

-- the spell a CDM frame shows right now (Blizzard re-uses frames across spells)
function M.ChildSpell(child)
    local info = child and child.cooldownInfo
    if not info then return nil end
    local base = PlainID(info.spellID)
    local sid = PlainID(info.overrideTooltipSpellID) or PlainID(info.overrideSpellID) or base
    return sid, base
end

-- Spell Editor settings for a CDM frame, or nil
function M.SpellSettings(child)
    local cdm = E.db.thingsUI.cdmIcons
    local buff = child and child.GetParent and child:GetParent() == _G.BuffIconCooldownViewer
    local ps
    if cdm then
        if buff then ps = cdm.perBuff else ps = cdm.perSpell end
    end
    if not (ps and next(ps)) then return nil end
    local sid, base = M.ChildSpell(child)
    return (sid and ps[sid]) or (base and ps[base]) or nil
end

-- Hide Aura Overlay for this frame: its Spell Editor choice, else Settings
local function WantsOverlayHidden(child)
    local o = M.SpellSettings(child)
    if o and o.auraOverlay then return o.auraOverlay == "hide" end
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    return (cdm and cdm.hideAuraOverlay) and true or false
end

-- Spell Editor custom icon. RefreshSpellTexture is Blizzard's only writer of the icon,
-- so a per-frame post-hook re-stamps after every repaint; no hooks until one is set
local anyCustomIcon = false
local iconHooked = setmetatable({}, { __mode = "k" })
local iconStamped = setmetatable({}, { __mode = "k" })

function M.ApplyCustomIcon(child, fromHook)
    if not (anyCustomIcon or iconStamped[child]) then return end
    local tex = child.Icon
    if not (tex and tex.SetTexture) then return end
    if not iconHooked[child] and child.RefreshSpellTexture then
        iconHooked[child] = true
        hooksecurefunc(child, "RefreshSpellTexture", function(self) M.ApplyCustomIcon(self, true) end)
    end
    local o = M.SpellSettings(child)
    local ci = o and o.customIcon
    if ci then
        tex:SetTexture(ci)
        iconStamped[child] = true
    elseif iconStamped[child] then
        -- inside the hook Blizzard has just painted the real one
        if fromHook then iconStamped[child] = nil return end
        local sid = M.ChildSpell(child)
        local real = sid and C_Spell.GetSpellTexture(sid)
        if real then
            tex:SetTexture(real)
            iconStamped[child] = nil
        end
    end
end

function M.RefreshCustomIcons()
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    anyCustomIcon = false
    for _, k in ipairs({ "perSpell", "perBuff" }) do
        for _, e in pairs((cdm and cdm[k]) or {}) do
            if type(e) == "table" and e.customIcon then anyCustomIcon = true break end
        end
    end
    for _, name in ipairs({ "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer" }) do
        local v = _G[name]
        if v then
            for _, c in ipairs({ v:GetChildren() }) do
                if c.cooldownInfo then M.ApplyCustomIcon(c) end
            end
        end
    end
end

function M.IsAuraDuplicate(child)
    local info = auraDupSet and child and child.cooldownInfo
    if not info then return false end
    local base = PlainID(info.spellID)
    local sid = PlainID(info.overrideTooltipSpellID) or PlainID(info.overrideSpellID) or base
    return AuraDup(info, sid, base, auraDupSet)
end

local function RebuildPassiveCache()
    local inCombat = InCombatLockdown()
    passiveDirty = inCombat
    if not inCombat then
        for c, want in pairs(pendingMouse) do
            pendingMouse[c] = nil
            if c.EnableMouse then c:EnableMouse(want) end
        end
    end
    local changed = false
    -- shown by a custom group: the CDM copy is a duplicate
    local CG = ns.CustomGroups
    local cdm = E.db.thingsUI.cdmIcons
    local dupSpells, dupTrinkets, dupAuras
    if cdm and cdm.hideGroupedDuplicates ~= false then
        if CG and CG.ShownSets then dupSpells, dupTrinkets, dupAuras = CG.ShownSets() end
        local CBm = ns.ChargeBar
        local cbRaw, cbLive
        if CBm and CBm.TrackedSpells then cbRaw, cbLive = CBm.TrackedSpells() end
        if cbRaw then
            dupSpells = dupSpells or {}
            dupSpells[cbRaw] = true
            if cbLive then dupSpells[cbLive] = true end
        end
        dupAuras = dupAuras or {}
        if ns.SpecialBars and ns.SpecialBars.AuraSet then
            for id in pairs(ns.SpecialBars.AuraSet()) do dupAuras[id] = true end
        end
    end
    SetAuraDupSet(dupAuras)
    for name in pairs(VIEWERS) do
        local viewer = _G[name]
        local vdb = GetViewerDB(name)
        local isBuff = VIEWERS[name] == "buffIcon"
        if viewer and vdb then
            local wantHide = vdb.hidePassive and C_Spell and C_Spell.IsSpellPassive
            local kids = { viewer:GetChildren() }
            for i = 1, #kids do
                local c = kids[i]
                if c and c.GetCooldownID
                    and not (ns.yoinkedBars and ns.yoinkedBars[c])
                    and not c._tuiSpecialBarKey and not c._tuiSpecialIconKey then
                    local info = c.cooldownInfo
                    local base = info and PlainID(info.spellID) or nil
                    local sid = info and (PlainID(info.overrideTooltipSpellID)
                        or PlainID(info.overrideSpellID) or base) or nil
                    if base and C_Spell.GetOverrideSpell then
                        local live = PlainID(C_Spell.GetOverrideSpell(base))
                        if live and live ~= 0 and live ~= base then sid = live end
                    end
                    local hide
                    if not wantHide then
                        hide = false
                    elseif sid then
                        local p = C_Spell.IsSpellPassive(sid)
                        if NotSecret(p) then
                            hide = p == true
                        elseif not inCombat then
                            hide = false
                        end
                    end
                    if sid and not hide and ns.RacialsCDM and ns.RacialsCDM.ShouldHideNativeSpell
                        and ns.RacialsCDM.ShouldHideNativeSpell(sid) then
                        hide = true
                    end
                    if not hide and not isBuff and dupSpells and sid and (dupSpells[sid] or (base and dupSpells[base])) then
                        hide = true
                    end
                    if not hide and isBuff and dupAuras and AuraDup(info, sid, base, dupAuras) then
                        hide = true
                    end
                    -- Spell Editor Show: out of the row while its rules say no
                    if not hide and (anySpellRule or anyCDState) then
                        local o = M.SpellSettings(c)
                        if o and o.visibility and not ns.Visibility.Shown(o.visibility) then hide = true end
                        if not hide and o and o.cdState and sid and M.CDStateHides(sid, o.cdState) then hide = true end
                    end
                    local slot = info and PlainID(info.equipSlot)
                    if slot then
                        local bl = cdm and cdm.trinketBlacklist
                        local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)
                        local ent = itemID and bl and bl[itemID]
                        if ent == true then ent = { use = true, buff = true } end
                        -- a slot moved to a group or drawn by TrinketsCDM: its cooldown shows there
                        local moved = not isBuff and ((dupTrinkets and dupTrinkets[slot])
                            or (ns.TrinketsCDM and ns.TrinketsCDM.ShowsSlot(slot)))
                        local listed = ent and ((isBuff and ent.buff) or (not isBuff and ent.use))
                        hide = (moved or listed) and true or false
                    end
                    if hide ~= nil then
                        if (passiveHidden[c] and true or false) ~= hide then changed = true end
                        ApplyPassiveState(c, hide)
                    end
                end
            end
        end
    end
    if changed then
        M.Invalidate()
        for name in pairs(VIEWERS) do QueueLayout(_G[name]) end
    end
end

local passiveQueued = false
M.RebuildPassiveCache = RebuildPassiveCache
local function QueuePassiveRebuild()
    if passiveQueued then return end
    passiveQueued = true
    C_Timer.After(0.1, function()
        passiveQueued = false
        M.RebuildPassiveCache()
    end)
end

function M.IsPassiveHidden(child) return passiveHidden[child] == true end

-- Spell Editor Show rules. Both take a frame out of its row and the rest closes up:
-- visibility from plain state, the cooldown from the spell's own isActive (plain in
-- combat, like EUI's Shift Icons reads it), the GCD left out
local cdOn = {}

function M.RefreshSpellRules()
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    anySpellRule, anyCDState = false, false
    for _, store in ipairs({ cdm and cdm.perSpell or {}, cdm and cdm.perBuff or {} }) do
        for _, o in pairs(store) do
            if type(o) == "table" then
                if o.visibility and o.visibility.enabled then anySpellRule = true end
                if o.cdState then anyCDState = true end
            end
        end
    end
    wipe(cdOn)
    QueuePassiveRebuild()
    -- the same rules hold where a group shows the spell
    local CG = ns.CustomGroups
    if CG and CG.QueueLayout then CG.QueueLayout(false) end
end

-- on its own cooldown (not the GCD); nil when the game won't say
local function OnRealCD(sid)
    local info = C_Spell.GetSpellCooldown(sid)
    if not info then return false end
    local a, g = info.isActive, info.isOnGCD
    if issecretvalue and (issecretvalue(a) or issecretvalue(g)) then return nil end
    return (a and not g) and true or false
end

M.OnRealCD = OnRealCD

-- whether a Show > Cooldown rule hides the spell right now
function M.CDStateHides(sid, mode)
    local on = OnRealCD(sid)
    if on == nil then return false end
    if mode == "cooldown" then return not on end
    return on
end

-- a ruled spell flipped: rows and groups lay out again
function M.CheckCDStates()
    if not anyCDState then return end
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    local changed = false
    for id, o in pairs((cdm and cdm.perSpell) or {}) do
        if type(o) == "table" and o.cdState then
            local on = OnRealCD(id)
            if on ~= nil and cdOn[id] ~= on then
                cdOn[id] = on
                changed = true
            end
        end
    end
    if changed then
        QueuePassiveRebuild()
        local CG = ns.CustomGroups
        if CG and CG.QueueLayout then CG.QueueLayout(false) end
    end
end

-- a spell's Spell Editor entry (or the one of what it turns into right now)
function M.SpellRuleFor(id)
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    local ps = cdm and cdm.perSpell
    if not (ps and id) then return nil end
    if ps[id] then return ps[id] end
    local live = C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(id)
    return live and ps[live] or nil
end

function M.HasSpellRules() return anySpellRule end

do
    local queued = false
    local function Flush() queued = false; M.CheckCDStates() end
    M.QueueCheckCDStates = function()
        if queued or not anyCDState then return end
        queued = true
        C_Timer.After(0, Flush)
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    ev:RegisterEvent("SPELL_UPDATE_CHARGES")
    ev:SetScript("OnEvent", M.QueueCheckCDStates)
    ns.Visibility.OnChange(function() if anySpellRule then QueuePassiveRebuild() end end)
end

-- whether the CDM shows one of these auras as up: Buff Icons/Bars items (their own
-- isActive, plain in combat) or a cooldown's aura state; nil when the CDM doesn't track it
local buffKids = {}
local activeHooked = setmetatable({}, { __mode = "k" })
local function HookActive(c)
    if activeHooked[c] or type(c.OnActiveStateChanged) ~= "function" then return end
    activeHooked[c] = true
    hooksecurefunc(c, "OnActiveStateChanged", function() M.FireAuraState(c) end)
end

function M.AuraUp(ids)
    local tracked = false
    for _, name in ipairs({ "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
        local v = _G[name]
        if v then
            for i = 1, H.ChildrenInto(v, buffKids) do
                local c = buffKids[i]
                if c and c.cooldownInfo then
                    HookActive(c)
                    local sid, base = M.ChildSpell(c)
                    if (sid and ids[sid]) or (base and ids[base]) then
                        tracked = true
                        local a = c.isActive
                        if not (issecretvalue and issecretvalue(a)) and a then return true end
                    end
                end
            end
        end
    end
    for _, name in ipairs({ "EssentialCooldownViewer", "UtilityCooldownViewer" }) do
        local v = _G[name]
        if v then
            for i = 1, H.ChildrenInto(v, buffKids) do
                local c = buffKids[i]
                if c and c.cooldownInfo then
                    local sid, base = M.ChildSpell(c)
                    if (sid and ids[sid]) or (base and ids[base]) then
                        tracked = true
                        if M.ChildAuraActive(c) then return true end
                    end
                end
            end
        end
    end
    if tracked then return false end
end

-- the Essential/Utility frame showing a spell now, and the row it shows in
local spellKids = {}
function M.ChildForSpell(spellID)
    for _, name in ipairs({ "EssentialCooldownViewer", "UtilityCooldownViewer" }) do
        local v = _G[name]
        if v then
            for i = 1, H.ChildrenInto(v, spellKids) do
                local c = spellKids[i]
                if c and c.cooldownInfo and c:IsShown() and not passiveHidden[c] then
                    local sid, base = M.ChildSpell(c)
                    if sid == spellID or base == spellID then
                        return c, (M.ShownIn(c) == "UtilityCooldownViewer") and "utility" or "essential"
                    end
                end
            end
        end
    end
end

-- the trinket in this slot is on the Trinkets blacklist for its cooldown (or buff)
function M.TrinketHidden(slot, buff)
    local bl = E.db.thingsUI.cdmIcons and E.db.thingsUI.cdmIcons.trinketBlacklist
    local itemID = bl and GetInventoryItemID("player", slot)
    local ent = itemID and bl[itemID]
    if ent == true then return true end
    return (ent and ((buff and ent.buff) or (not buff and ent.use))) and true or false
end
M.QueuePassiveRebuild = function() QueuePassiveRebuild() end

local dataRefreshQueued = false
local function OnViewerDataRefresh()
    if dataRefreshQueued then return end
    dataRefreshQueued = true
    C_Timer.After(0, function()
        dataRefreshQueued = false
        M.RebuildPassiveCache()
        for name in pairs(VIEWERS) do QueueLayout(_G[name]) end
    end)
end

local function ByLayoutIndex(a, b)
    return (a.layoutIndex or math.huge) < (b.layoutIndex or math.huge)
end

local function SortByCooldownID(children)
    table.sort(children, ByLayoutIndex)
end

local cdmRebuilding = false
local rebuildFinish
local lastSpec

local function ReapplyChildAnchor(child)
    if cdmRebuilding then return end
    if applyingChild[child] then return end

    if ns.yoinkedBars and ns.yoinkedBars[child] then return end
    local a = child._tuiAnchor
    if not a or not a.relative then
        local viewer = child._tuiViewer
        if viewer then viewer._tuiLayoutSig = nil; LayoutViewer(viewer) end
        return
    end
    applyingChild[child] = true
    child:ClearAllPoints()
    child:SetPoint(a.point, a.relative, a.relativePoint, a.x, a.y)
    applyingChild[child] = nil
end

local function OnChildAuraChanged(child)
    local viewer = child._tuiViewer
    if viewer then QueueLayout(viewer) end
end

local OVERLAY_ATLAS   = "UI-HUD-CoolDownManager-IconOverlay"
local OVERLAY_TEX_ID  = 6707800
local applyingOverlay = {}

local function OverlayEligible(child)
    if not child then return false end
    if ns.yoinkedBars and ns.yoinkedBars[child] then return false end
    local v = child._tuiViewer
    if not v or (v ~= _G.EssentialCooldownViewer and v ~= _G.UtilityCooldownViewer) then return false end
    local info = child.cooldownInfo
    if not info then return false end
    if type(child.GetEquipSlot) == "function" then
        local slot = child:GetEquipSlot()
        if not (issecretvalue and issecretvalue(slot)) and slot then return "equip" end
    end
    local sid = PlainID(info.overrideSpellID) or PlainID(info.spellID)
    if not (type(sid) == "number" and sid > 0) then return false end
    return "spell"
end

local SWIPE_TEX = "Interface\\Buttons\\WHITE8X8"

local function SetCDFromDur(cd, durObj)
    if not (cd and cd.SetCooldownFromDurationObject and durObj) then return false end
    if pcall(cd.SetCooldownFromDurationObject, cd, durObj, false) then return true end
    return pcall(cd.SetCooldownFromDurationObject, cd, durObj)
end

local overlayRegions = setmetatable({}, { __mode = "k" })

local function StripOverlayTextures(frame)
    local list = overlayRegions[frame]
    if not list then
        list = {}
        local clean = true
        for _, r in ipairs({ frame:GetRegions() }) do
            if r.IsObjectType and r:IsObjectType("Texture") then
                local a = r.GetAtlas and r:GetAtlas()
                local t = r.GetTexture and r:GetTexture()
                if IsSecret(a) or IsSecret(t) then clean = false end
                if (NotSecret(a) and a == OVERLAY_ATLAS) or (NotSecret(t) and t == OVERLAY_TEX_ID) then
                    list[#list + 1] = r
                end
            end
        end
        -- template regions never change; only a fully readable scan is kept
        if clean then overlayRegions[frame] = list end
    end
    for i = 1, #list do
        local r = list[i]
        r:SetAlpha(0); r:Hide()
    end
end

local function WantsChargeSwipe(child)
    local o = M.SpellSettings(child)
    local v = o and o.chargeSwipe
    if v then return v == "show" end
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    return not (cdm and cdm.chargeSwipe == false)
end

local function HasCharges(child)
    return child.HasVisualDataSource_Charges and child:HasVisualDataSource_Charges() and true or false
end

local function ApplyCooldownStyle(cd)
    if cd.SetDrawSwipe          then cd:SetDrawSwipe(true) end
    if cd.SetDrawEdge           then cd:SetDrawEdge(false) end
    if cd.SetDrawBling          then cd:SetDrawBling(true) end
    if cd.SetReverse            then cd:SetReverse(false) end
    if cd.SetSwipeColor         then cd:SetSwipeColor(0, 0, 0, 0.8) end
    if cd.SetSwipeTexture       then cd:SetSwipeTexture(SWIPE_TEX) end
    if cd.SetUseAuraDisplayTime then cd:SetUseAuraDisplayTime(false) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
end

-- the value the last full pass painted, reused by a desaturation write in the same frame
local lastDesat   = setmetatable({}, { __mode = "k" })
local lastDesatAt = setmetatable({}, { __mode = "k" })

local function PutDesat(icon, v)
    if not icon then return end
    SetDesat(icon, v)
    lastDesat[icon], lastDesatAt[icon] = v, GetTime()
end

local function UpdateIconDesat(icon, cdInfo, durObj, hasCharge)
    if not icon then return end
    if cdInfo and NotSecret(cdInfo.isOnGCD) and cdInfo.isOnGCD then PutDesat(icon, 0); return end
    if durObj and not hasCharge and type(durObj.EvaluateRemainingDuration) == "function" then
        local curve = GetDesatCurve()
        if curve then PutDesat(icon, durObj:EvaluateRemainingDuration(curve, 0) or 0)
        else PutDesat(icon, 0) end
        return
    end
    PutDesat(icon, 0)
end

local function ApplyAuraState(child, cd, spellID)
    local cdInfo    = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spellID)
    local durObj    = C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(spellID)
    local hasCharge = type(child.HasVisualDataSource_Charges) == "function" and not not child:HasVisualDataSource_Charges()
    local chargeDur = hasCharge and C_Spell.GetSpellChargeDuration and C_Spell.GetSpellChargeDuration(spellID)

    UpdateIconDesat(child.Icon, cdInfo, durObj, hasCharge)

    local applied
    if hasCharge and chargeDur then applied = SetCDFromDur(cd, chargeDur)
    elseif not hasCharge and durObj then applied = SetCDFromDur(cd, durObj) end
    if applied then return end

    if cdInfo and NotSecret(cdInfo.isOnGCD) and cdInfo.isOnGCD then
        if cd.Clear then cd:Clear() end
    elseif cdInfo and NotSecret(cdInfo.startTime) and NotSecret(cdInfo.duration) and C_DurationUtil and C_DurationUtil.CreateDuration then
        local fb = C_DurationUtil.CreateDuration()
        if fb and fb.SetTimeFromStart then fb:SetTimeFromStart(cdInfo.startTime, cdInfo.duration); SetCDFromDur(cd, fb) end
    elseif cd.Clear then cd:Clear() end
end

local function EnforceSpellTexture(child)
    if not WantsOverlayHidden(child) then return end
    local cvs = _G.CooldownViewerSettings
    if cvs and cvs:IsShown() then return end
    if OverlayEligible(child) ~= "spell" then return end
    local info = child.cooldownInfo
    local base = info and PlainID(info.spellID) or nil
    if not (type(base) == "number" and base > 0) then return end
    -- the spell's art, or its Spell Editor custom icon
    local o = M.SpellSettings(child)
    local tex = (o and o.customIcon) or (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(base))
    local icon = child.Icon
    if not (tex and icon and icon.SetTexture) then return end
    local cur = icon:GetTexture()
    if NotSecret(cur) and cur == tex then return end
    icon:SetTexture(tex)
    local tc = child._tuiZoomCoord
    if tc and icon.SetTexCoord then icon:SetTexCoord(tc[1], tc[2], tc[3], tc[4]) end
end

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
local overrideGlow = {}
local childAuraOn  = {}

local function StopOverrideGlow(child)
    if not overrideGlow[child] then return end
    overrideGlow[child] = nil
    if LCG then LCG.ProcGlow_Stop(child, "tuiOverrideGlow") end
end

local function UpdateOverrideGlow(child)
    if not (LCG and IsSpellOverlayed) then return end
    if not childAuraOn[child] then StopOverrideGlow(child) return end
    local info = child.cooldownInfo
    local base = info and PlainID(info.spellID) or nil
    local live
    if type(base) == "number" and base > 0 and C_Spell.GetOverrideSpell then
        live = PlainID(C_Spell.GetOverrideSpell(base))
        if live == 0 or live == base then live = nil end
    end
    if not live then StopOverrideGlow(child) return end
    local o = IsSpellOverlayed(live)
    if not NotSecret(o) then return end
    if o == true then
        if not overrideGlow[child] then
            overrideGlow[child] = true
            LCG.ProcGlow_Start(child, { key = "tuiOverrideGlow" })
        end
    else
        StopOverrideGlow(child)
    end
end

local function OverlayActive(child)
    if not WantsOverlayHidden(child) then return false end
    local cvs = _G.CooldownViewerSettings
    if cvs and cvs:IsShown() then return false end
    return OverlayEligible(child)
end

local function ProcessCooldownFrame(child)
    local cd = child.Cooldown
    -- our own writes below re-enter through the hooks
    if not cd or applyingOverlay[cd] then return end
    local kind = OverlayActive(child)
    if not kind then return end
    if kind == "spell" then
        EnforceSpellTexture(child)
        UpdateOverrideGlow(child)
    end

    applyingOverlay[cd] = true
    StripOverlayTextures(child)
    ApplyCooldownStyle(cd)
    -- Recharge Swipe: Edge Only keeps Blizzard's look for a charge spell
    if kind == "spell" and HasCharges(child) and not WantsChargeSwipe(child) then
        cd:SetDrawSwipe(false)
        cd:SetDrawEdge(true)
    end
    if kind == "equip" then
        local slot = child:GetEquipSlot()
        local start, dur, _, gcd
        if not (issecretvalue and issecretvalue(slot)) and slot and GetInventoryItemCooldown then
            start, dur, _, gcd = GetInventoryItemCooldown("player", slot)
        end
        if start and dur and dur > 0 then
            cd:SetCooldown(start, dur)
            PutDesat(child.Icon, (gcd or dur <= H.ITEM_GCD_MAX) and 0 or 1)
        else
            if cd.Clear then cd:Clear() end
            PutDesat(child.Icon, 0)
        end
    else
        local info = child.cooldownInfo
        local spellID = info and (PlainID(info.overrideSpellID) or PlainID(info.spellID)) or nil
        if spellID and type(spellID) == "number" and spellID > 0 and C_Spell then
            ApplyAuraState(child, cd, spellID)
        else
            if cd.Clear then cd:Clear() end
            PutDesat(child.Icon, 0)
        end
    end
    applyingOverlay[cd] = nil
end

local function HideAuraOverlay(child)
    ProcessCooldownFrame(child)
end

-- Blizzard writes the swipe color right before its SetCooldown/Clear, which runs the full pass
local function ReassertSwipe(child)
    local cd = child.Cooldown
    if not cd or applyingOverlay[cd] or not OverlayActive(child) then return end
    applyingOverlay[cd] = true
    cd:SetSwipeColor(0, 0, 0, 0.8)
    applyingOverlay[cd] = nil
end

local function ReassertDesat(child)
    local cd = child.Cooldown
    if not cd or applyingOverlay[cd] then return end
    local icon = child.Icon
    if icon and lastDesatAt[icon] == GetTime() then
        if not OverlayActive(child) then return end
        applyingOverlay[cd] = true
        SetDesat(icon, lastDesat[icon])
        applyingOverlay[cd] = nil
        return
    end
    ProcessCooldownFrame(child)
end

-- Essential/Utility swipe while a spell's aura runs: Blizzard sets ITEM_AURA_COLOR first on
-- every repaint, so a post-hook restyles it right there (not while the overlay is hidden)
local swipeRev = setmetatable({}, { __mode = "k" })
local swipeHooked = setmetatable({}, { __mode = "k" })

local function StyleAuraSwipe(child)
    local cd = child.Cooldown
    if not cd or applyingOverlay[cd] then return end
    -- a buff icon is always its aura; its direction is the layout pass's (Invert Swipe)
    local buff = child:GetParent() == _G.BuffIconCooldownViewer
    local consts = _G.CooldownViewerConstants
    local aura = buff or (consts and child.cooldownSwipeColor == consts.ITEM_AURA_COLOR)
    -- the common plain-cooldown repaint: nothing to do unless we reversed it before
    if not aura and not swipeRev[cd] then return end
    if OverlayActive(child) then return end
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    local o = M.SpellSettings(child)
    local c = aura and ((o and o.swipeColor) or (not buff and cdm and cdm.auraSwipeColor))
    if c then
        applyingOverlay[cd] = true
        cd:SetSwipeColor(c.r or 1, c.g or 1, c.b or 1, c.a or 0.6)
        applyingOverlay[cd] = nil
    end
    if buff then return end
    local r = o and o.swipeReverse
    local rev = aura and (r == "on" or (r == nil and cdm and cdm.auraSwipeReverse)) and true or false
    if (swipeRev[cd] or false) ~= rev then
        cd:SetReverse(rev)
        swipeRev[cd] = rev or nil
    end
end

-- whether a cooldown frame shows its spell's aura right now (Blizzard's own field, plain in combat)
function M.ChildAuraActive(child)
    local consts = _G.CooldownViewerConstants
    return (consts and child and child.cooldownSwipeColor == consts.ITEM_AURA_COLOR) and true or false
end

-- spells whose frame reports aura on/off (an Aura Icon sits on top of them)
local auraWatch, auraListeners = {}, {}
local auraOn = setmetatable({}, { __mode = "k" })
function M.WatchAuraState(set) auraWatch = set or {} end
function M.OnAuraState(fn) auraListeners[#auraListeners + 1] = fn end
function M.FireAuraState(c)
    for i = 1, #auraListeners do auraListeners[i](c) end
end

local function NoteAuraState(child)
    if not next(auraWatch) then return end
    local on = M.ChildAuraActive(child)
    if auraOn[child] == on then return end
    auraOn[child] = on
    for i = 1, #auraListeners do auraListeners[i](child, on) end
end

local function EnsureSwipeHook(child)
    local cd = child.Cooldown
    if not cd or swipeHooked[cd] or not cd.SetSwipeColor then return end
    swipeHooked[cd] = true
    hooksecurefunc(cd, "SetSwipeColor", function()
        StyleAuraSwipe(child)
        NoteAuraState(child)
        if anyCDState then M.QueueCheckCDStates() end
    end)
end

-- Blizzard draws a charge spell that still has a charge as a bare edge while it recharges
-- (swipe off); the full swipe comes back unless Settings or the Spell Editor say no
local chargeHooked = setmetatable({}, { __mode = "k" })
local forcingSwipe = setmetatable({}, { __mode = "k" })

local function EnsureChargeHook(child)
    local cd = child.Cooldown
    if not cd or chargeHooked[cd] or not cd.SetDrawSwipe then return end
    chargeHooked[cd] = true
    hooksecurefunc(cd, "SetDrawSwipe", function(_, show)
        if show or forcingSwipe[cd] or applyingOverlay[cd] then return end
        if not HasCharges(child) or not WantsChargeSwipe(child) then return end
        forcingSwipe[cd] = true
        cd:SetDrawSwipe(true)
        forcingSwipe[cd] = nil
    end)
end

local function EnsureOverlayHooks(child)
    local cd = child and child.Cooldown
    if not cd or cd._tuiOverlayHooked then return end
    if not OverlayEligible(child) then return end
    cd._tuiOverlayHooked = true
    if not child._tuiTexHooked and type(child.RefreshSpellTexture) == "function" then
        child._tuiTexHooked = true
        hooksecurefunc(child, "RefreshSpellTexture", EnforceSpellTexture)
    end
    local function reapply() ProcessCooldownFrame(child) end
    hooksecurefunc(cd, "SetCooldown", reapply)
    if cd.SetCooldownFromDurationObject then hooksecurefunc(cd, "SetCooldownFromDurationObject", reapply) end
    if cd.Clear then hooksecurefunc(cd, "Clear", reapply) end
    if cd.SetSwipeColor then hooksecurefunc(cd, "SetSwipeColor", function() ReassertSwipe(child) end) end
    local icon = child.Icon
    if icon and not icon._tuiOverlayHooked then
        icon._tuiOverlayHooked = true
        local desat = function() ReassertDesat(child) end
        if icon.SetDesaturated  then hooksecurefunc(icon, "SetDesaturated",  desat) end
        if icon.SetDesaturation then hooksecurefunc(icon, "SetDesaturation", desat) end
    end
end

local function HookChild(child, viewer)
    if hookedChildren[child] then return end
    hookedChildren[child] = true
    child._tuiViewer = viewer
    ClearPandemic(child)
    if type(child.ShowPandemicStateFrame) == "function" then
        hooksecurefunc(child, "ShowPandemicStateFrame", ClearPandemic)
    end
    if type(child.HidePandemicStateFrame) == "function" then
        hooksecurefunc(child, "HidePandemicStateFrame", StopPandemicGlow)
    end
    hooksecurefunc(child, "SetPoint",        ReapplyChildAnchor)
    hooksecurefunc(child, "ClearAllPoints", ReapplyChildAnchor)
    hooksecurefunc(child, "Hide", OnChildAuraChanged)
    hooksecurefunc(child, "SetShown", OnChildAuraChanged)

    if type(child.OnAuraInstanceInfoSet) == "function" then
        hooksecurefunc(child, "OnAuraInstanceInfoSet", function(self)
            childAuraOn[self] = true
            ClearPandemic(self)
            OnChildAuraChanged(self)
        end)
    end
    if type(child.OnAuraInstanceInfoCleared) == "function" then
        hooksecurefunc(child, "OnAuraInstanceInfoCleared", function(self)
            childAuraOn[self] = nil
            StopOverrideGlow(self)
            OnChildAuraChanged(self)
        end)
    end

    local db = child.DebuffBorder
    if db and not db._tuiAuraHooked and type(db.UpdateFromAuraData) == "function" then
        db._tuiAuraHooked = true
        hooksecurefunc(db, "UpdateFromAuraData", function(self)
            local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
            if cdm and cdm.hideAuraBorder then self:SetAlpha(0) end
        end)
    end

    EnsureOverlayHooks(child)
end

local hookedViewerAnchors = {}
local applyingViewerAnchor = {}

local function ResolveViewerAnchorTarget(viewerName, vdb)
    local targetFrameName = vdb.anchorFrame
    if viewerName == "BuffIconCooldownViewer" and targetFrameName == "BARSETUP_TOP" then
        local bs = ns.BarSetup
        if bs and bs.GetTopmostBarFrame then
            local top = bs.GetTopmostBarFrame()
            if top then return top end
        end

        local setup = bs and bs.GetActiveSetup and bs.GetActiveSetup()
        return setup and _G[setup.anchorFrame or ""] or nil
    end
    local target = _G[targetFrameName or ""]

    if targetFrameName == "ElvUF_Player_CastBar" and target and target.Holder then
        return target.Holder
    end
    return target
end

local function AnchorRequired(viewerName, vdb)
    if not vdb then return false end
    if viewerName == "BuffIconCooldownViewer" then return true end
    return vdb.anchorEnabled == true
end

local function ReapplyViewerAnchor(viewer)
    local proxy = GetProxy(viewer)
    if applyingViewerAnchor[proxy] then return end
    local viewerName = viewer:GetName()
    local vdb = GetViewerDB(viewerName)

    if not AnchorRequired(viewerName, vdb) then return end

    local target = ResolveViewerAnchorTarget(viewerName, vdb)
    if not target then return end
    local tname = target.GetName and target:GetName()
    if tname and VIEWERS[tname] then target = GetProxy(target) end

    local point, relPoint = vdb.anchorPoint or "CENTER", vdb.anchorRelativePoint or "CENTER"
    local x, y = vdb.anchorXOffset or 0, vdb.anchorYOffset or 0
    -- re-anchoring an unchanged proxy only makes the engine re-place every icon on it
    if proxy:GetNumPoints() == 1 then
        local p, rel, rp, px, py = proxy:GetPoint(1)
        if p == point and rel == target and rp == relPoint and NotSecret(px) and NotSecret(py)
            and math.abs(px - x) < 0.01 and math.abs(py - y) < 0.01 then
            return
        end
    end

    applyingViewerAnchor[proxy] = true
    proxy:ClearAllPoints()
    proxy:SetPoint(point, target, relPoint, x, y)
    applyingViewerAnchor[proxy] = nil
end

local function HookViewerAnchor(viewer)
    if hookedViewerAnchors[viewer] then return end
    hookedViewerAnchors[viewer] = true

    hooksecurefunc(viewer, "SetPoint", function(self)
        if applyingViewerAnchor[self] then return end
        local name = self:GetName()

        if not AnchorRequired(name, GetViewerDB(name)) then return end
        QueueLayout(self)
    end)
    hooksecurefunc(viewer, "ClearAllPoints", function(self)
        if applyingViewerAnchor[self] then return end
        local name = self:GetName()
        if not AnchorRequired(name, GetViewerDB(name)) then return end
        QueueLayout(self)
    end)
end


local function ComputeLayoutSig(visible, vdb)
    local sig = #visible
    for i = 1, #visible do
        local c = visible[i]
        local id = c.cooldownID or 0
        if type(id) ~= "number" then id = 0 end
        sig = sig + id * i + (c.layoutIndex or 0) * 17
    end
    sig = sig
        + (vdb.iconWidth or 36) * 1000003
        + (vdb.iconHeight or 36) * 503
        + math.floor((vdb.spacing or 0) * 100) * 31
        + (vdb.iconsPerRow or 20) * 41
        + (vdb.maxIcons or 0) * 4099
        + ((vdb.overflowPlacement == "START") and 8191 or 0)
        + math.floor((vdb.iconZoom or 0) * 1000) * 7
        + (vdb.iconLockAspectRatio ~= false and 1 or 0) * 13
        + (vdb.lockAspect and 1 or 0) * 113
        + (vdb.overrideSize and 1 or 0) * 211
        + (vdb.elbowEnabled and 1 or 0) * 65521
        + (vdb.elbowAfter or 0) * 1543
        + (vdb.invertSwipe and 1 or 0) * 379
    local g = vdb.growthDirection
    if g then for i = 1, #g do sig = sig + g:byte(i) * i end end
    local eb = vdb.elbowDirection
    if eb then for i = 1, #eb do sig = sig + eb:byte(i) * i * 3 end end
    if vdb.wrapDirection == "UP" or vdb.wrapDirection == "LEFT" then sig = sig + 307 end
    return sig
end

local ELBOW_STEP = {
    UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 },
}

local function ElbowCell(i, elbowAt, growth, step)
    if i <= elbowAt then
        if growth.axis == "V" then return 0, (i - 1) * growth.stepY end
        return (i - 1) * growth.stepX, 0
    end
    local j = i - elbowAt
    if growth.axis == "V" then
        return j * step[1], (elbowAt - 1) * growth.stepY
    end
    return (elbowAt - 1) * growth.stepX, j * step[2]
end

local function EnsureFlowTail(proxy, viewerName)
    if not proxy._tuiFlowTail then
        proxy._tuiFlowTail = CreateFrame("Frame", "TUI_CDMFlowTail_" .. viewerName, proxy)
    end
    return proxy._tuiFlowTail
end

function M.FlowTailForName(name)
    if name and VIEWERS[name] then
        local v = _G[name]
        if v then return EnsureFlowTail(GetProxy(v), name) end
    end
    return nil
end

local function _cornerXY(point, w, h)
    local dx = point:find("RIGHT") and w or (point:find("LEFT") and 0 or w * 0.5)
    local dy = point:find("BOTTOM") and -h or (point:find("TOP") and 0 or -h * 0.5)
    return dx, dy
end

local function ProxyOwnedByThingsUI(viewer, vdb)
    if viewer:GetName() == "EssentialCooldownViewer" then
        local edb = E.db.thingsUI and E.db.thingsUI.essentialMover
        return (edb and edb.enabled) and true or false
    end
    return AnchorRequired(viewer:GetName(), vdb)
end

local function MirrorProxyToViewer(proxy, viewer)
    local fl, fb = viewer:GetLeft(), viewer:GetBottom()
    if not fl or not fb then return end
    local pl, pb = proxy:GetLeft(), proxy:GetBottom()
    if pl and pb and NotSecret(fl) and NotSecret(fb) and NotSecret(pl) and NotSecret(pb)
        and math.abs(pl - fl) < 0.01 and math.abs(pb - fb) < 0.01 then
        return
    end
    proxy:ClearAllPoints()
    proxy:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", fl, fb)
end

local barRestackPending
local function NotifyClusterWidthChanged()
    if barRestackPending then return end
    barRestackPending = true
    C_Timer.After(0, function()
        barRestackPending = nil
        if InCombatLockdown() then return end
        if ns.BarSetup and ns.BarSetup.ResetWidthCache and ns.BarSetup.ApplyStack then
            ns.BarSetup.ResetWidthCache()
            ns.BarSetup.ApplyStack()
        end
    end)
end

LayoutViewer = function(viewer)

    if cdmRebuilding then return end
    -- Edit Mode: step aside only while the viewers can be dragged (lock off)
    local emm = _G.EditModeManagerFrame
    if emm and emm:IsShown() and not (ns.EditModeLock and ns.EditModeLock.IsLocked()) then return end
    local vdb = GetViewerDB(viewer:GetName())
    if not vdb then return end

    HookViewerAnchor(viewer)
    ReapplyViewerAnchor(viewer)

    viewer._tuiVisible = viewer._tuiVisible or {}
    local visible = CollectAndHook(viewer, viewer._tuiVisible, HookChild)
    local TM = ns.TimersCDM
    if TM and TM.GetInlineButtonsFor then
        local tmb = TM.GetInlineButtonsFor(viewer)
        if tmb then for i = 1, #tmb do visible[#visible + 1] = tmb[i] end end
    end
    local RC = ns.RacialsCDM
    if RC and RC.GetInlineButtonsFor then
        local rcb = RC.GetInlineButtonsFor(viewer)
        if rcb then for i = 1, #rcb do visible[#visible + 1] = rcb[i] end end
    end
    local TR = ns.TrinketsCDM
    if TR and TR.GetInlineButtonsFor then
        local trb = TR.GetInlineButtonsFor(viewer)
        if trb then for i = 1, #trb do visible[#visible + 1] = trb[i] end end
    end
    local SBI = ns.SpecialBars
    if SBI and SBI.GetInlineIconsFor then
        local sib = SBI.GetInlineIconsFor(viewer)
        if sib then for i = 1, #sib do visible[#visible + 1] = sib[i] end end
    end

    SortByCooldownID(visible)

    local myName = viewer:GetName()
    local cap = tonumber(vdb.maxIcons) or 0
    local targetKey = vdb.overflowTarget
    local targetName = targetKey and targetKey ~= "" and VIEWER_BY_KEY[targetKey] or nil
    if targetName == myName then targetName = nil end

    local moved
    if cap > 0 and targetName and #visible > cap then
        moved = {}
        for i = cap + 1, #visible do moved[#moved + 1] = visible[i] end
        for i = #visible, cap + 1, -1 do visible[i] = nil end
        moved._from = myName
        moved._placement = vdb.overflowPlacement
    end

    local prev, prevName
    for name, list in pairs(overflowOut) do
        if list._from == myName then prev, prevName = list, name end
    end

    local changed = false
    if prevName ~= targetName or (prev == nil) ~= (moved == nil) then
        changed = true
    elseif prev and moved then
        if #prev ~= #moved then
            changed = true
        else
            for i = 1, #moved do
                if prev[i] ~= moved[i] then changed = true break end
            end
        end
    end

    if changed then
        if prevName then overflowOut[prevName] = nil end
        local dirty = _G[prevName or ""]
        if dirty then dirty._tuiLayoutSig = nil; QueueLayout(dirty) end
        -- text follows the row an icon shows in
        if ns.CDMText and ns.CDMText.QueueRefresh then ns.CDMText.QueueRefresh() end
    end
    if moved then
        overflowOut[targetName] = moved
        local needTarget = changed
        if not needTarget then
            local tv = _G[targetName]
            local tproxy = tv and GetProxy(tv)
            for i = 1, #moved do
                local a = moved[i]._tuiAnchor
                if not a or a.relative ~= tproxy then needTarget = true break end
            end
        end
        if needTarget then
            local tv = _G[targetName]
            if tv then tv._tuiLayoutSig = nil; QueueLayout(tv) end
        end
    end

    local incoming = overflowOut[myName]
    if incoming then
        if incoming._placement == "START" then
            for i = #incoming, 1, -1 do table.insert(visible, 1, incoming[i]) end
        else
            for i = 1, #incoming do visible[#visible + 1] = incoming[i] end
        end
    end

    if #visible == 0 then
        local proxy = GetProxy(viewer)
        local tail = EnsureFlowTail(proxy, viewer:GetName())
        local sizeW, sizeH = GetIconSize(vdb)
        local w = sizeW or proxy._tuiLastIconW or 36
        local h = sizeH or proxy._tuiLastIconH or 36
        local pin = vdb.anchorPoint or "CENTER"
        Pixel.SetSize(proxy, w, h)
        if viewer == _G.EssentialCooldownViewer then NotifyClusterWidthChanged() end
        local dx, dy = _cornerXY(pin, w, h)
        tail:SetSize(w, h)
        tail:ClearAllPoints()
        tail:SetPoint("CENTER", proxy, pin, w / 2 - dx, -h / 2 - dy)
        if proxy._tuiLastIconW ~= w or proxy._tuiLastIconH ~= h then
            proxy._tuiLastIconW, proxy._tuiLastIconH = w, h
            local T = ns.TUI
            if T and T.UpdateCustomGroups then T:UpdateCustomGroups() end
            if T and T.QueueSpecialBarsUpdate then T:QueueSpecialBarsUpdate() end
        end
        viewer._tuiLayoutSig = nil
        return
    end

    local sig = ComputeLayoutSig(visible, vdb)
    if viewer._tuiLayoutSig == sig then
        local proxy = GetProxy(viewer)
        local vscale = (viewer:GetEffectiveScale() or 1) / (_G.UIParent:GetEffectiveScale() or 1)
        if math.abs((proxy:GetScale() or 1) - vscale) > 0.001 then proxy:SetScale(vscale) end
        if not ProxyOwnedByThingsUI(viewer, vdb) then
            MirrorProxyToViewer(proxy, viewer)
        end
        return
    end
    viewer._tuiLayoutSig = sig

    local cdmRoot = E.db.thingsUI and E.db.thingsUI.cdmIcons
    if cdmRoot and cdmRoot.hideAuraBorder then
        for i = 1, #visible do
            local b = visible[i].DebuffBorder
            if b then b:SetAlpha(0) end
        end
    end
    local buffViewer = VIEWERS[myName] == "buffIcon"
    local swipeStyled = not buffViewer and cdmRoot and (cdmRoot.auraSwipeColor or cdmRoot.auraSwipeReverse)
    for i = 1, #visible do
        local c = visible[i]
        if not buffViewer then EnsureChargeHook(c) end
        if WantsOverlayHidden(c) then EnsureOverlayHooks(c); HideAuraOverlay(c) end
        local o = M.SpellSettings(c)
        if swipeStyled or swipeHooked[c.Cooldown] or (o and (o.swipeColor or o.swipeReverse)) then
            EnsureSwipeHook(c); StyleAuraSwipe(c)
        end
        if next(auraWatch) then
            local sid, base = M.ChildSpell(c)
            if (sid and auraWatch[sid]) or (base and auraWatch[base]) then EnsureSwipeHook(c); NoteAuraState(c) end
        end
        if anyCDState and o and o.cdState then EnsureSwipeHook(c) end
    end
    -- per-spell glow and text follow the spell, not the re-used frame
    local glowSync = ns.CDMGlow and ns.CDMGlow.Sync
    local textSync = ns.CDMText and ns.CDMText.SyncChild
    for i = 1, #visible do
        local c = visible[i]
        if c.cooldownInfo then
            if glowSync then glowSync(c) end
            if textSync then textSync(c, myName) end
            M.ApplyCustomIcon(c)
        end
    end

    local sizeW, sizeH = GetIconSize(vdb)
    if sizeW and sizeH then
        for i = 1, #visible do
            local c = visible[i]
            local cw, ch = c:GetSize()
            if not c._tuiOwnSize and (math.abs((cw or 0) - sizeW) > 0.5 or math.abs((ch or 0) - sizeH) > 0.5) then
                Pixel.SetSize(c, sizeW, sizeH)
            end
        end
    end
    
    if VIEWERS[viewer:GetName()] == "buffIcon" then
        for i = 1, #visible do
            local c = visible[i]
            local cd = c.Cooldown
            if cd and cd.SetReverse then
                local o = M.SpellSettings(c)
                local r = o and o.invertSwipe
                cd:SetReverse((r == "on" or (r == nil and vdb.invertSwipe)) and true or false)
            end
        end
    end

    -- the cell size comes from a real icon, never from one that sizes itself
    local sample = visible[1]
    for i = 1, #visible do
        if not visible[i]._tuiOwnSize then sample = visible[i] break end
    end

    local zoom = tonumber(vdb.iconZoom) or 0
    local lockTex = vdb.iconLockAspectRatio ~= false
    if zoom > 0 or lockTex then
        local frameW = sizeW or (sample and sample:GetWidth() or 0)
        local frameH = sizeH or (sample and sample:GetHeight() or 0)

        local left, right, top, bottom
        if lockTex and frameW > 0 and frameH > 0 then
            local base = 1 - zoom * 2
            local xCrop, yCrop = base, base
            local ratio = frameW / frameH
            if ratio > 1 then yCrop = xCrop / ratio
            elseif ratio < 1 then xCrop = yCrop * ratio end
            left = (1 - xCrop) / 2; right = 1 - left
            top  = (1 - yCrop) / 2; bottom = 1 - top
        else
            left, right, top, bottom = zoom, 1 - zoom, zoom, 1 - zoom
        end
        for i = 1, #visible do
            local c = visible[i]
            local tex = c.Icon
            if tex and tex.SetTexCoord then
                tex:SetTexCoord(left, right, top, bottom)
                local tc = c._tuiZoomCoord
                if not tc then tc = {}; c._tuiZoomCoord = tc end
                tc[1], tc[2], tc[3], tc[4] = left, right, top, bottom
            end
        end
    end

    local iconW = (sizeW) or sample:GetWidth() or 36
    local iconH = (sizeH) or sample:GetHeight() or 36
    local spacing  = (vdb.spacing or 0) + (ns.CDM_SPACING_INSET or 2)
    local growth   = GROWTH[vdb.growthDirection] or GROWTH.CENTERED_H
    local perLine  = math.max(1, vdb.iconsPerRow or 20)
    local anchorPin = vdb.anchorPoint or "CENTER"
    local count    = #visible

    local elbowStep
    if vdb.elbowEnabled then
        local vertical = (growth.axis == "V")
        local step = ELBOW_STEP[vdb.elbowDirection]
        local fits = step and ((vertical and step[1] ~= 0) or (not vertical and step[2] ~= 0))
        elbowStep = fits and step or (vertical and ELBOW_STEP.LEFT or ELBOW_STEP.DOWN)
    end
    local elbowAt = elbowStep and math.max(1, vdb.elbowAfter or 10) or nil
    if elbowAt and count <= elbowAt then elbowStep, elbowAt = nil, nil end

    local cols, rows
    if elbowStep then
        if growth.axis == "V" then cols, rows = 1, math.min(elbowAt, count)
        else                       cols, rows = math.min(elbowAt, count), 1 end
    elseif growth.axis == "V" then
        rows = math.min(perLine, count)
        cols = math.ceil(count / perLine)
    else
        cols = math.min(perLine, count)
        rows = math.ceil(count / perLine)
    end

    local stepX  = (iconW + spacing) * growth.stepX
    local stepY  = (iconH + spacing) * growth.stepY
    local totalW = cols * iconW + math.max(0, cols - 1) * spacing
    local totalH = rows * iconH + math.max(0, rows - 1) * spacing

    local startX, startY
    if growth.pin == "CENTER" then
        startX = -((cols - 1) * (iconW + spacing)) / 2
        startY =  ((rows - 1) * (iconH + spacing)) / 2
    elseif growth.pin == "LEFT" then
        startX = iconW / 2
        startY = ((rows - 1) * (iconH + spacing)) / 2
    elseif growth.pin == "RIGHT" then
        startX = -iconW / 2
        startY = ((rows - 1) * (iconH + spacing)) / 2
    elseif growth.pin == "TOP" then
        startX = -((cols - 1) * (iconW + spacing)) / 2
        startY = -iconH / 2
    elseif growth.pin == "BOTTOM" then
        startX = -((cols - 1) * (iconW + spacing)) / 2
        startY = iconH / 2
    end

    local proxy = GetProxy(viewer)
    local cellW = iconW + spacing
    local cellH = iconH + spacing
    local centered = (growth.pin == "CENTER")
    local wrapDir = vdb.wrapDirection
    local wrapFlip = (growth.axis == "H" and wrapDir == "UP")
        or (growth.axis == "V" and wrapDir == "LEFT")
    for i = 1, count do
        local child = visible[i]
        local ancX, ancY = _cornerXY(anchorPin, totalW, totalH)
        local ax, ay

        if elbowStep then
            local cx, cy = ElbowCell(i, elbowAt, growth, elbowStep)
            ax = iconW / 2 + cx * cellW - ancX
            ay = -iconH / 2 + cy * cellH - ancY
        else
        local col, row, lineLen
        if growth.axis == "V" then
            col = math.floor((i - 1) / perLine)
            row = (i - 1) % perLine
            lineLen = math.min(perLine, count - col * perLine)
        else
            row = math.floor((i - 1) / perLine)
            col = (i - 1) % perLine
            lineLen = math.min(perLine, count - row * perLine)
        end
        if wrapFlip then
            if growth.axis == "V" then col = cols - 1 - col else row = rows - 1 - row end
        end

        local x, y
        if centered and growth.axis == "V" then
            x = startX + col * stepX
            y = ((lineLen - 1) / 2 - row) * cellH
        elseif centered then
            x = (col - (lineLen - 1) / 2) * cellW
            y = startY + row * stepY
        else
            x = startX + col * stepX
            y = startY + row * stepY
        end

        local pinX, pinY = _cornerXY(growth.pin, totalW, totalH)
        ax, ay = pinX + x - ancX, pinY + y - ancY
        end

        child._tuiAnchor = child._tuiAnchor or {}
        child._tuiAnchor.point         = "CENTER"
        child._tuiAnchor.relative      = proxy
        child._tuiAnchor.relativePoint = anchorPin
        child._tuiAnchor.x             = ax
        child._tuiAnchor.y             = ay
        applyingChild[child] = true
        child:ClearAllPoints()
        child:SetPoint("CENTER", proxy, anchorPin, ax, ay)
        applyingChild[child] = nil
    end

    do
        local tail = EnsureFlowTail(proxy, viewer:GetName())
        local ti, total = count + 1, count + 1
        local ax, ay
        if elbowStep then
            local cx, cy = ElbowCell(ti, elbowAt, growth, elbowStep)
            local ancX, ancY = _cornerXY(anchorPin, totalW, totalH)
            ax = iconW / 2 + cx * cellW - ancX
            ay = -iconH / 2 + cy * cellH - ancY
        else
            local col, row, lineLen
            if growth.axis == "V" then
                col = math.floor((ti - 1) / perLine)
                row = (ti - 1) % perLine
                lineLen = math.min(perLine, total - col * perLine)
            else
                row = math.floor((ti - 1) / perLine)
                col = (ti - 1) % perLine
                lineLen = math.min(perLine, total - row * perLine)
            end
            local x, y
            if centered and growth.axis == "V" then
                x = startX + col * stepX
                y = ((lineLen - 1) / 2 - row) * cellH
            elseif centered then
                x = (col - (lineLen - 1) / 2) * cellW
                y = startY + row * stepY
            else
                x = startX + col * stepX
                y = startY + row * stepY
            end
            local pinX, pinY = _cornerXY(growth.pin, totalW, totalH)
            local ancX, ancY = _cornerXY(anchorPin, totalW, totalH)
            ax, ay = pinX + x - ancX, pinY + y - ancY
        end
        tail:SetSize(iconW, iconH)
        tail:ClearAllPoints()
        tail:SetPoint("CENTER", proxy, anchorPin, ax, ay)
        tail:Show()
        if proxy._tuiLastIconW ~= iconW or proxy._tuiLastIconH ~= iconH then
            proxy._tuiLastIconW, proxy._tuiLastIconH = iconW, iconH
            local T = ns.TUI
            if T and T.UpdateCustomGroups then T:UpdateCustomGroups() end
            if T and T.QueueSpecialBarsUpdate then T:QueueSpecialBarsUpdate() end
        end
    end

    local vscale = (viewer:GetEffectiveScale() or 1) / (_G.UIParent:GetEffectiveScale() or 1)
    if math.abs((proxy:GetScale() or 1) - vscale) > 0.001 then proxy:SetScale(vscale) end
    if math.abs((proxy:GetWidth() or 0) - totalW) > 0.5
       or math.abs((proxy:GetHeight() or 0) - totalH) > 0.5 then
        Pixel.SetSize(proxy, totalW, totalH)
        if viewer == _G.EssentialCooldownViewer then NotifyClusterWidthChanged() end
    end

    if not ProxyOwnedByThingsUI(viewer, vdb) then
        MirrorProxyToViewer(proxy, viewer)
    end
end

local function FlushPending(self)
    self:SetScript("OnUpdate", nil)
    if not M.LayoutViewer then M.LayoutViewer = LayoutViewer end
    for viewer in pairs(pendingViewers) do
        pendingViewers[viewer] = nil
        M.LayoutViewer(viewer)
    end
    -- Aura Icons on top of a cooldown follow its frame
    local SB = ns.SpecialBars
    if SB and SB.RefreshOverIcons then SB.RefreshOverIcons() end
end

QueueLayout = function(viewer)
    if not viewer or pendingViewers[viewer] then return end
    pendingViewers[viewer] = true
    pendingFrame:SetScript("OnUpdate", FlushPending)
end

local function HookViewer(name)
    if hookedViewers[name] then return end
    local viewer = _G[name]
    if not viewer or type(viewer.RefreshLayout) ~= "function" then return false end
    hookedViewers[name] = true
    if type(viewer.RefreshData) == "function" then
        hooksecurefunc(viewer, "RefreshData", OnViewerDataRefresh)
    end
    ns.ViewerHooks.On(viewer, "RefreshLayout", "CDMIcons", function(v)
        if rebuildFinish then
            local f = rebuildFinish
            rebuildFinish = nil
            C_Timer.After(0.1, f)
        end
        QueueLayout(v)
    end)

    if type(viewer.OnAcquireItemFrame) == "function" then
        hooksecurefunc(viewer, "OnAcquireItemFrame", function(self, itemFrame)
            HookChild(itemFrame, self)
            itemFrame._tuiViewer = self
            itemFrame._tuiAnchor = nil
            childAuraOn[itemFrame] = nil
            ClearPandemic(itemFrame)
            StopOverrideGlow(itemFrame)
            ApplyPassiveState(itemFrame, false)
            passiveMouse[itemFrame] = nil
            self._tuiLayoutSig = nil
            QueueLayout(self)
            QueuePassiveRebuild()
        end)
    end
    QueueLayout(viewer)
    return true
end

local function RelayoutAllForced()
    M.Invalidate()
    for name in pairs(VIEWERS) do QueueLayout(_G[name]) end
end

local function RelayoutAllForcedStaggered()
    RelayoutAllForced()
    C_Timer.After(0.05, RelayoutAllForced)
    C_Timer.After(0.20, RelayoutAllForced)
end

local emmHooked, cvsHooked = false, false
local function HookEditModeExit()
    if not emmHooked then
        local emm = _G.EditModeManagerFrame
        if emm then
            emmHooked = true
            if type(emm.EnterEditMode) == "function" then
                hooksecurefunc(emm, "EnterEditMode", RelayoutAllForcedStaggered)
            end
            hooksecurefunc(emm, "ExitEditMode", RelayoutAllForcedStaggered)
        end
    end
    if not cvsHooked then
        local cvs = _G.CooldownViewerSettings
        if cvs and cvs.HookScript then
            cvsHooked = true
            cvs:HookScript("OnShow", RelayoutAllForcedStaggered)
            cvs:HookScript("OnHide", RelayoutAllForcedStaggered)
        end
    end
end

function M.IsRebuilding() return cdmRebuilding end

function M.Invalidate()
    for name in pairs(VIEWERS) do
        local v = _G[name]
        if v then v._tuiLayoutSig = nil end
    end
end

local utilityMoverCreated = false
local function EnsureUtilityMover()
    if utilityMoverCreated then return end
    local v = _G.UtilityCooldownViewer
    local ms = ns.MoverSync
    if not (v and ms and ms.CreateManaged) then return end
    utilityMoverCreated = true
    ms.CreateManaged(GetProxy(v), "TUI_UtilityMover", "Utility Cooldowns", {
        configString      = "thingsUI,modulesTab,cdm,layoutTab,utilityTab",
        ignoreSizeChanged = true,
        shouldDisable = function()
            local vdb = GetViewerDB("UtilityCooldownViewer")
            return not (vdb and vdb.anchorEnabled)
        end,
        onSave = function(point, relPoint, x, y)
            local vdb = GetViewerDB("UtilityCooldownViewer")
            if not vdb then return end
            vdb.anchorPoint = point
            vdb.anchorRelativePoint = relPoint
            vdb.anchorXOffset = x
            vdb.anchorYOffset = y
            QueueLayout(_G.UtilityCooldownViewer)
            ns.NotifyChange()
        end,
        onNudge = function(dx, dy)
            local vdb = GetViewerDB("UtilityCooldownViewer")
            if not vdb then return end
            vdb.anchorXOffset = (vdb.anchorXOffset or 0) + dx
            vdb.anchorYOffset = (vdb.anchorYOffset or 0) + dy
            QueueLayout(_G.UtilityCooldownViewer)
            ns.NotifyChange()
        end,
    })
end

local HEAL_VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer" }
local function HealViewerVisibility()
    if Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.SpecAgnosticEssential then return end
    if InCombatLockdown() then return end
    for _, name in ipairs(HEAL_VIEWERS) do
        local v = _G[name]
        if v and not v:IsShown() and type(v.UpdateShownState) == "function" then
            v:UpdateShownState()
        end
    end
end

function M.RefreshAllSoft()
    HookEditModeExit()
    EnsureUtilityMover()
    HealViewerVisibility()
    for c in pairs(overrideGlow) do
        if not WantsOverlayHidden(c) then StopOverrideGlow(c) end
    end
    for name in pairs(VIEWERS) do
        HookViewer(name)
        QueueLayout(_G[name])
    end
    QueuePassiveRebuild()
    if ns.MoverSync and ns.MoverSync.Queue then ns.MoverSync.Queue() end
end

function M.RefreshAll()
    M.Invalidate()
    M.RefreshAllSoft()
end

function TUI:UpdateCDMIcons()
    M.RefreshSpellRules()
    M.RefreshCustomIcons()
    M.RefreshAll()
    if ns.EssentialMover and ns.EssentialMover.OnGrowthDirectionChanged then
        ns.EssentialMover.OnGrowthDirectionChanged()
    end
end

function M.MaybeAutoEnableCDM()
    if InCombatLockdown() then return end
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    if not cdm then return end
    local auto = cdm.autoEnableCDM
    local gdb = _G.thingsUIGlobalDB
    local guid = UnitGUID and UnitGUID("player")
    if not (gdb and guid) then return end

    local skins = E.private and E.private.skins and E.private.skins.blizzard
    if auto and skins and not skins.cooldownManager then
        gdb.cdmSkinEnabled = gdb.cdmSkinEnabled or {}
        if not gdb.cdmSkinEnabled[guid] then
            gdb.cdmSkinEnabled[guid] = true
            skins.cooldownManager = true
            print("|cFF8080FFthingsUI|r enabled the ElvUI Cooldown Manager skin (required). |cFFFFFF00Reload to apply.|r")
            if E.StaticPopup_Show then E:StaticPopup_Show("PRIVATE_RL") end
        end
    end

    if GetCVarBool and GetCVarBool("cooldownViewerEnabled") then return end
    if not (C_CooldownViewer and C_CooldownViewer.IsCooldownViewerAvailable
            and C_CooldownViewer.IsCooldownViewerAvailable()) then return end
    -- auto-enable keeps it on; without it, say once per character why the rows are empty
    if not auto then
        gdb.cdmOffNotice = gdb.cdmOffNotice or {}
        if gdb.cdmOffNotice[guid] then return end
        gdb.cdmOffNotice[guid] = true
        print("|cFF8080FFthingsUI|r: the Cooldown Manager is turned off (Options > Gameplay Enhancements), so the CDM rows stay empty. Turn it on there, or tick Auto-enable Cooldown Manager in thingsUI > CDM > Settings.")
        return
    end
    pcall(SetCVar, "cooldownViewerEnabled", "1")
    print("|cFF8080FFthingsUI|r turned the Cooldown Manager on (Options > Gameplay Enhancements). To keep it off, untick Auto-enable Cooldown Manager in thingsUI > CDM > Settings.")
    for _, t in ipairs({ 0.5, 1.0, 2.0 }) do C_Timer.After(t, M.RefreshAll) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("SPELLS_CHANGED")
f:RegisterEvent("TRAIT_CONFIG_UPDATED")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
if C_EventUtils and C_EventUtils.IsEventValid
    and C_EventUtils.IsEventValid("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED") then
    f:RegisterEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED")
end
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        if arg1 == 13 or arg1 == 14 then
            QueuePassiveRebuild()
            if ns.CustomGroups and ns.CustomGroups.QueueLayout then ns.CustomGroups.QueueLayout() end
        end
        return
    end
    if event == "SPELLS_CHANGED" or event == "TRAIT_CONFIG_UPDATED"
        or event == "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED" then
        QueuePassiveRebuild()
        return
    end

    M.MaybeAutoEnableCDM()
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        local spec = GetSpecialization and GetSpecialization()
        if lastSpec ~= nil and spec ~= lastSpec then
            cdmRebuilding = true
            local function finish()
                if not cdmRebuilding then return end
                cdmRebuilding = false
                RelayoutAllForcedStaggered()
                M.RefreshAll()
                if TUI.UpdateClusterPositioning then TUI:UpdateClusterPositioning() end
                if TUI.UpdateBuffBars then TUI:UpdateBuffBars() end
            end
            rebuildFinish = finish
            C_Timer.After(2.5, function()
                if rebuildFinish == finish then rebuildFinish = nil end
                finish()
            end)
        end
        lastSpec = spec
        C_Timer.After(0.5, M.RefreshAll)
        for _, t in ipairs({ 1.0, 2.0, 4.0 }) do C_Timer.After(t, M.RefreshAllSoft) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if passiveDirty then QueuePassiveRebuild() end
        M.RefreshAll()
        for _, t in ipairs({ 0.5, 1.0, 2.0, 4.0 }) do C_Timer.After(t, M.RefreshAllSoft) end
    else
        local spec = GetSpecialization and GetSpecialization()
        if spec ~= nil then lastSpec = spec end
        M.RefreshAll()
        for _, t in ipairs({ 0.5, 1.0, 2.0, 4.0 }) do C_Timer.After(t, M.RefreshAllSoft) end
    end
end)

local function DumpVal(v)
    if issecretvalue and issecretvalue(v) then return "secret" end
    return tostring(v)
end

ns.SlashCommand("cdm", function()
    local emm = _G.EditModeManagerFrame
    local cvs = _G.CooldownViewerSettings
    print(("|cFF8080FFtuicdm|r editmode=%s cvs=%s rebuilding=%s"):format(
        tostring(emm and emm:IsShown()), tostring(cvs and cvs:IsShown()), tostring(M.IsRebuilding())))
    local specIdx = GetSpecialization and GetSpecialization()
    local sid, sname
    if specIdx and GetSpecializationInfo then sid, sname = GetSpecializationInfo(specIdx) end
    print(("  spec idx=%s id=%s %s"):format(tostring(specIdx), tostring(sid), tostring(sname)))
    local cat = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.Essential
    if cat and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet then
        local set = C_CooldownViewer.GetCooldownViewerCategorySet(cat)
        local names = {}
        for i = 1, math.min(6, set and #set or 0) do
            local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(set[i])
            local sp = info and info.spellID
            if sp and not (issecretvalue and issecretvalue(sp)) then
                local nm = C_Spell.GetSpellName and C_Spell.GetSpellName(sp)
                names[#names + 1] = tostring(nm or sp)
            else
                names[#names + 1] = "?"
            end
        end
        print("  essential C-side: " .. ((#names > 0) and table.concat(names, ", ") or "EMPTY"))
    end
    for name in pairs(VIEWERS) do
        local v = _G[name]
        if v then
            local vdb = GetViewerDB(name)
            local proxy = GetProxy(v)
            local kids = { v:GetChildren() }
            local shown, withCID = 0, 0
            for i = 1, #kids do
                local c = kids[i]
                if c:IsShown() then shown = shown + 1 end
                if c.GetCooldownID then withCID = withCID + 1 end
            end
            local buf = {}
            local vis = CollectAndHook(v, buf, HookChild)
            print(("  |cFFFFD27F%s|r shown=%s kids=%d shownKids=%d cid=%d visible=%d"):format(
                name, tostring(v:IsShown()), #kids, shown, withCID, #vis))
            print(("    viewer %dx%d @(%d,%d)  proxy %dx%d @(%s,%s) scale=%.2f"):format(
                math.floor(v:GetWidth() or 0), math.floor(v:GetHeight() or 0),
                math.floor(v:GetLeft() or 0), math.floor(v:GetBottom() or 0),
                math.floor(proxy:GetWidth() or 0), math.floor(proxy:GetHeight() or 0),
                tostring(proxy:GetLeft() and math.floor(proxy:GetLeft())),
                tostring(proxy:GetBottom() and math.floor(proxy:GetBottom())),
                proxy:GetScale() or 1))
            print(("    vdb grow=%s perRow=%s icon=%sx%s sig=%s"):format(
                tostring(vdb and vdb.growthDirection), tostring(vdb and vdb.iconsPerRow),
                tostring(vdb and vdb.iconWidth), tostring(vdb and vdb.iconHeight),
                tostring(v._tuiLayoutSig)))
            local c1 = vis[1]
            if c1 then
                local pt, rel, rp, x, y = c1:GetPoint()
                print(("    child1 cid=%s %dx%d pt=%s rel=%s(%s) x=%s y=%s"):format(
                    DumpVal(c1.cooldownID), math.floor(c1:GetWidth() or 0), math.floor(c1:GetHeight() or 0),
                    tostring(pt), tostring(rel and rel.GetName and rel:GetName() or rel), tostring(rp),
                    DumpVal(x), DumpVal(y)))
            end
            for _, c in ipairs(vis) do
                local slot
                if type(c.GetEquipSlot) == "function" then
                    slot = c:GetEquipSlot()
                    if issecretvalue and issecretvalue(slot) then slot = "secret" end
                end
                if slot then
                    local info = c.cooldownInfo
                    local cd = c.Cooldown
                    local s, d
                    if cd and cd.GetCooldownTimes then s, d = cd:GetCooldownTimes() end
                    local uadt
                    if cd and cd.GetUseAuraDisplayTime then uadt = cd:GetUseAuraDisplayTime() end
                    print(("    TRINKET slot=%s cid=%s info=%s sid=%s hooked=%s txtCfg=%s uadt=%s cdShown=%s times=%s/%s alpha=%s"):format(
                        DumpVal(slot),
                        DumpVal(c.GetCooldownID and c:GetCooldownID() or nil),
                        tostring(info ~= nil),
                        DumpVal(info and info.spellID),
                        tostring(cd and cd._tuiOverlayHooked or false),
                        tostring(c._tuiTextConfig ~= nil),
                        DumpVal(uadt),
                        tostring(cd and cd:IsShown()),
                        DumpVal(s), DumpVal(d),
                        DumpVal(c.GetAlpha and c:GetAlpha() or nil)))
                end
            end
        end
    end
    if GetInventoryItemCooldown then
        for _, slot in ipairs({ 13, 14 }) do
            local s, d, en = GetInventoryItemCooldown("player", slot)
            print(("  inv slot %d item=%s start=%s dur=%s enable=%s"):format(
                slot, tostring(GetInventoryItemID and GetInventoryItemID("player", slot)),
                DumpVal(s), DumpVal(d), DumpVal(en)))
        end
    end
end)
