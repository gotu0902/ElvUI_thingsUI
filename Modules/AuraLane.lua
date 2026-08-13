local addon, ns = ...
local TUI = ns.TUI
local E, L, V, P, G = unpack(ElvUI)
local LSM = E.Libs and E.Libs.LSM

local A = {}
ns.AuraLane = A

local lanes = {}
local pendingSync = false
local Teardown

local FLOW_UP, FLOW_DOWN, FLOW_LEFT, FLOW_RIGHT
local AXIS_V, AXIS_H

local function Ready()
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end
    if not (AnchorUtil and AnchorUtil.FlowLayoutAxis and AnchorUtil.FlowDirection) then return false end
    FLOW_UP, FLOW_DOWN = AnchorUtil.FlowDirection.Up, AnchorUtil.FlowDirection.Down
    FLOW_LEFT, FLOW_RIGHT = AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Right
    AXIS_V, AXIS_H = AnchorUtil.FlowLayoutAxis.Vertical, AnchorUtil.FlowLayoutAxis.Horizontal
    return true
end

A.Ready = Ready

function A.DB(group)
    group.auras = group.auras or {}
    return group.auras
end

function A.SpellList(def)
    local out = {}
    for id in pairs((def and def.spells) or {}) do
        local n = tonumber(id)
        if n then out[#out + 1] = n end
    end
    table.sort(out)
    return out
end

function A.SpellListUnique(def)
    local out, seen = {}, {}
    for _, id in ipairs(A.SpellList(def)) do
        local nm = (C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or id
        if not seen[nm] then
            seen[nm] = true
            out[#out + 1] = id
        end
    end
    return out
end

function A.Entries(group)
    if not group then return {} end
    local out = {}

    local order = group.scopeOrder or { "global", "class", "spec" }
    for si, scope in ipairs(order) do
        local root = ns.CustomGroups.GetScopeRoot(group, scope, nil, false)
        for uid, def in pairs((root and root.auras) or {}) do
            if def.enabled ~= false and next(def.spells or {}) then
                out[#out + 1] = {
                    key = ("TUIAura%d_%s_%s"):format(group.id or 0, scope,
                        tostring(uid):gsub("[^%w]", "")),
                    def = def,
                    rank = si * 100000 + (def.layoutIndex or 999),
                }
            end
        end
    end

    local SB = ns.SpecialBars
    if SB and SB.GetIconCount and SB.GetIconDB then
        local siSpec = 3
        for i, s in ipairs(order) do
            if s == "spec" then siSpec = i break end
        end
        for i = 1, SB.GetIconCount() do
            local ikey = "icon" .. i
            local idb = SB.GetIconDB(ikey)
            if idb and idb.enabled and idb.spellID and idb.customGroup == group.id then
                local spells = (ns.SpecialAura and ns.SpecialAura.ExpandSpellIDs
                    and ns.SpecialAura.ExpandSpellIDs(idb.spellID)) or { [idb.spellID] = true }
                out[#out + 1] = {
                    key = ("TUIAura%d_si_%s"):format(group.id or 0, ikey),
                    def = { spells = spells, max = 1, iconDB = idb },
                    rank = siSpec * 100000 + (idb.customGroupOrder or 20000),
                }
            end
        end
    end

    table.sort(out, function(x, y)
        if x.rank ~= y.rank then return x.rank < y.rank end
        return x.key < y.key
    end)
    return out
end

function A.HasSets(group)
    return #A.Entries(group) > 0
end

local playerAssistOK = true

function A.PlayerAssistOK()
    return playerAssistOK
end

local function SideVisOK(unit, pureHarm, hasHarm)
    if unit == "player" then
        return pureHarm or playerAssistOK
    end

    local assist = (UnitExists(unit) and UnitCanAssist("player", unit)) and true or false
    if not pureHarm and not assist then return false end
    if hasHarm and assist then return false end
    return true
end

local function LaneVisOK(lane)
    return SideVisOK(lane.unit or "player", lane.pureHarmful, lane.hasHarmful)
end

local function LaneVisOKT(lane)
    if not lane.unitT then return false end
    return SideVisOK(lane.unitT, lane.pureHarmfulT, lane.hasHarmfulT)
end

local durFormatter
local function Formatter()
    if durFormatter then return durFormatter end
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return nil end
    durFormatter = C_StringUtil.CreateNumericRuleFormatter()
    durFormatter:SetBreakpoints({
        {
            threshold = 60,
            rounding = Enum.NumericRuleFormatRounding.Down,
            format = "%dm",
            components = { { div = 60, step = 1, rounding = Enum.NumericRuleFormatRounding.Down } },
        },
        { threshold = 0, step = 1, rounding = Enum.NumericRuleFormatRounding.Up, format = "%d" },
    })
    return durFormatter
end

A.DurFormatter = Formatter

local colourCache = {}
local function ThresholdColour(group)
    local t = group.auras or {}
    if t.colorThreshold == false then return nil end
    local sec = math.min(math.max(tonumber(t.thresholdSeconds) or 3, 0.1), 59.9)
    local c = t.thresholdColor or { r = 1, g = 0.3, b = 0.3 }
    local n = (group.text and group.text.cooldownColor) or { r = 1, g = 1, b = 1 }
    local key = ("%d:%.1f:%.2f,%.2f,%.2f:%.2f,%.2f,%.2f")
        :format(group.id or 0, sec, c.r, c.g, c.b, n.r, n.g, n.b)
    local hit = colourCache[key]
    if hit then return hit end
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve) then return nil end
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0, CreateColor(c.r, c.g, c.b, 1))
    curve:AddPoint(sec, CreateColor(n.r, n.g, n.b, 1))
    hit = { curve = curve, property = Enum.DurationTextBindingProperty.RemainingDuration }
    colourCache[key] = hit
    return hit
end

local sourceOK
function A.CanShowSource(button)
    if sourceOK == nil and button then
        sourceOK = type(button.SetSourceName) == "function"
            and type(button.ClearSourceName) == "function"
    end
    return sourceOK == true
end

function A.SourceProbed()
    return sourceOK ~= nil
end

local pandemicOK
function A.CanPandemic(button)
    if pandemicOK == nil and button then
        pandemicOK = type(button.AddPandemicRegion) == "function"
    end
    return pandemicOK == true
end

function A.MapGlowStyle(v)
    if v == "pulse" or v == "proc" or v == "ants" or v == "pixel" then return v end
    if v == "button" then return "proc" end
    return "pulse"
end

local RING_BLACK = {}
local function EdgeRing(host, texs, size, inset, c)
    for _, tex in ipairs(texs) do
        tex:SetColorTexture(c.r or 0, c.g or 0, c.b or 0, c.a or 1)
        tex:ClearAllPoints()
        tex:Show()
    end
    texs[1]:SetPoint("TOPLEFT", host, "TOPLEFT", inset, -inset)
    texs[1]:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", -inset, -inset - size)
    texs[2]:SetPoint("TOPLEFT", host, "BOTTOMLEFT", inset, inset + size)
    texs[2]:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -inset, inset)
    texs[3]:SetPoint("TOPLEFT", host, "TOPLEFT", inset, -inset)
    texs[3]:SetPoint("BOTTOMRIGHT", host, "BOTTOMLEFT", inset + size, inset)
    texs[4]:SetPoint("TOPLEFT", host, "TOPRIGHT", -inset - size, -inset)
    texs[4]:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -inset, inset)
end
A.EdgeRing = EdgeRing

local function LayoutRing(g, th)
    for i = 1, 4 do
        g.tex[i]:ClearAllPoints()
        g.tex[i]:Show()
    end
    g.tex[1]:SetPoint("BOTTOMLEFT", g, "TOPLEFT", -th, 0)
    g.tex[1]:SetPoint("TOPRIGHT", g, "TOPRIGHT", th, th)
    g.tex[2]:SetPoint("TOPLEFT", g, "BOTTOMLEFT", -th, 0)
    g.tex[2]:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", th, -th)
    g.tex[3]:SetPoint("TOPRIGHT", g, "TOPLEFT", 0, 0)
    g.tex[3]:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", -th, 0)
    g.tex[4]:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
    g.tex[4]:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", th, 0)
end

function A.ApplyButtonFX(button, r, opts)
    local style = opts.style
    local gc = opts.color

    -- own pixel impl (LCG's pooled frames may not anchor to aura buttons):
    -- Path-animated dots orbit the full perimeter, no Lua per frame
    if style == "pixel" then
        local px = r.glowPixel
        if not px then
            px = CreateFrame("Frame", nil, button)
            px:SetAllPoints(button)
            px.tex = {}
            r.glowPixel = px
        end
        local th = math.max(1, opts.thickness or 2)
        local N = math.min(12, math.max(1, opts.lines or 8))
        local T = math.min(6, math.max(1, opts.length or 3))
        -- 1px inside the icon edge by default; the Offset knob pushes outward
        local off = (opts.offset or 0) - (th / 2 + 1)
        local w = math.max(8, (opts.w or 36) + 2 * off)
        local h = math.max(8, (opts.h or 36) + 2 * off)
        local c = gc or {}
        local P = 2 * (w + h)
        local function posAt(d)
            d = d % P
            if d < w then return d, 0 end
            d = d - w
            if d < h then return w, -d end
            d = d - h
            if d < w then return w - d, -h end
            d = d - w
            return 0, -(h - d)
        end
        local dur = 1 / math.max(0.05, opts.frequency or 0.25)

        -- one shared corner-snapped waypoint ring; every dot starts on a ring
        -- index so trains are index-locked (never drift) and all turn 90deg
        -- exactly at the corners, head first, tail following
        local edges = { w, h, w, h }
        local counts, total = {}, 0
        for e = 1, 4 do
            counts[e] = math.max(1, math.floor(edges[e] / (th + 1) + 0.5))
            total = total + counts[e]
        end
        while total > 64 do
            local bi = 1
            for e = 2, 4 do if counts[e] > counts[bi] then bi = e end end
            counts[bi] = counts[bi] - 1
            total = total - 1
        end
        local pts, base = { 0 }, 0
        for e = 1, 4 do
            for k = 1, counts[e] do
                pts[#pts + 1] = base + edges[e] * k / counts[e]
            end
            base = base + edges[e]
        end
        pts[#pts] = nil
        local RM = #pts

        local sig = table.concat({ w, h, th, dur, N, T, off, RM }, ":")
        local idx = 0
        for i = 1, N do
            local headIdx = math.floor((i - 1) * RM / N + 0.5)
            for j = 0, T - 1 do
                idx = idx + 1
                local t = px.tex[idx]
                if t and (not t.path or #t.cps ~= RM) then
                    t.anim:Stop()
                    t:Hide()
                    t = nil
                end
                if not t then
                    t = px:CreateTexture(nil, "OVERLAY", nil, 7)
                    local ag = t:CreateAnimationGroup()
                    ag:SetLooping("REPEAT")
                    local path = ag:CreateAnimation("Path")
                    path:SetCurveType("NONE")
                    t.cps = {}
                    for k = 1, RM do
                        local cp = path:CreateControlPoint()
                        cp:SetOrder(k)
                        t.cps[k] = cp
                    end
                    t.anim, t.path = ag, path
                    px.tex[idx] = t
                end
                t:SetColorTexture(c.r or 1, c.g or 1, c.b or 0.25, c.a or 1)
                t:SetSize(th + 1, th + 1)
                if t._sig ~= sig then
                    t._sig = sig
                    t.anim:Stop()
                    local s = ((headIdx - j) % RM) + 1
                    local d0 = pts[s]
                    local x0, y0 = posAt(d0)
                    t:ClearAllPoints()
                    t:SetPoint("CENTER", px, "TOPLEFT", x0 - off, y0 + off)
                    for k = 1, RM do
                        local rel
                        if k == RM then
                            rel = P
                        else
                            rel = (pts[((s - 1 + k) % RM) + 1] - d0) % P
                        end
                        local xk, yk = posAt(d0 + rel)
                        t.cps[k]:SetOffset(xk - x0, yk - y0)
                    end
                    t.path:SetDuration(dur)
                end
                t:Show()
            end
        end
        for k = idx + 1, #px.tex do
            px.tex[k].anim:Stop()
            px.tex[k]:Hide()
        end
        px:Show()
        for k = 1, idx do
            if not px.tex[k].anim:IsPlaying() then px.tex[k].anim:Play() end
        end
    elseif r.glowPixel then
        for _, t in ipairs(r.glowPixel.tex) do t.anim:Stop() end
        r.glowPixel:Hide()
    end

    if style == "pulse" then
        local g = r.glow
        if not g then
            g = CreateFrame("Frame", nil, button)
            g:SetAllPoints(button)
            g.tex = {}
            for i = 1, 4 do g.tex[i] = g:CreateTexture(nil, "OVERLAY", nil, 7) end
            local ag = g:CreateAnimationGroup()
            ag:SetLooping("BOUNCE")
            local a = ag:CreateAnimation("Alpha")
            a:SetFromAlpha(1)
            a:SetToAlpha(0.25)
            a:SetDuration(0.5)
            g.anim = ag
            r.glow = g
        end
        local c = gc or {}
        for i = 1, 4 do
            g.tex[i]:SetColorTexture(c.r or 1, c.g or 1, c.b or 0.25, c.a or 1)
        end
        LayoutRing(g, opts.thickness or 2)
        g:Show()
        if not g.anim:IsPlaying() then g.anim:Play() end
    elseif r.glow then
        r.glow.anim:Stop()
        r.glow:Hide()
    end

    if style == "proc" then
        local p = r.glowProc
        if not p then
            p = CreateFrame("Frame", nil, button)
            p:SetPoint("CENTER", button, "CENTER", 0, 0)
            p.tex = p:CreateTexture(nil, "OVERLAY", nil, 7)
            p.tex:SetAllPoints(p)
            p.tex:SetAtlas("UI-HUD-ActionBar-Proc-Loop-Flipbook")
            local ag = p.tex:CreateAnimationGroup()
            ag:SetLooping("REPEAT")
            local fb = ag:CreateAnimation("FlipBook")
            fb:SetDuration(1)
            fb:SetFlipBookRows(6)
            fb:SetFlipBookColumns(5)
            fb:SetFlipBookFrames(30)
            p.anim = ag
            r.glowProc = p
        end
        p:SetSize((opts.w or 36) * 1.4, (opts.h or 36) * 1.4)
        if gc then p.tex:SetVertexColor(gc.r or 1, gc.g or 1, gc.b or 1, gc.a or 1)
        else p.tex:SetVertexColor(1, 1, 1, 1) end
        p:Show()
        if not p.anim:IsPlaying() then p.anim:Play() end
    elseif r.glowProc then
        r.glowProc.anim:Stop()
        r.glowProc:Hide()
    end

    if style == "ants" then
        local n = r.glowAnts
        if not n then
            n = CreateFrame("Frame", nil, button)
            n:SetPoint("CENTER", button, "CENTER", 0, 0)
            n.tex = n:CreateTexture(nil, "OVERLAY", nil, 7)
            n.tex:SetAllPoints(n)
            n.tex:SetTexture("Interface\\SpellActivationOverlay\\IconAlertAnts")
            local ag = n.tex:CreateAnimationGroup()
            ag:SetLooping("REPEAT")
            local fb = ag:CreateAnimation("FlipBook")
            fb:SetDuration(0.3)
            fb:SetFlipBookRows(5)
            fb:SetFlipBookColumns(5)
            fb:SetFlipBookFrames(22)
            fb:SetFlipBookFrameWidth(48)
            fb:SetFlipBookFrameHeight(48)
            n.anim = ag
            r.glowAnts = n
        end
        n:SetSize((opts.w or 36) * 1.25, (opts.h or 36) * 1.25)
        if gc then
            n.tex:SetDesaturated(true)
            n.tex:SetVertexColor(gc.r or 1, gc.g or 1, gc.b or 1, gc.a or 1)
        else
            n.tex:SetDesaturated(false)
            n.tex:SetVertexColor(1, 1, 1, 1)
        end
        n:Show()
        if not n.anim:IsPlaying() then n.anim:Play() end
    elseif r.glowAnts then
        r.glowAnts.anim:Stop()
        r.glowAnts:Hide()
    end

    local wantPand = opts.pandemic and A.CanPandemic(button) or false
    if wantPand and not r.pand then
        local pd = CreateFrame("Frame", nil, button)
        pd:SetAllPoints(button)
        pd:SetFrameLevel(button:GetFrameLevel() + 4)
        pd.tex = {}
        for i = 1, 4 do pd.tex[i] = pd:CreateTexture(nil, "OVERLAY", nil, 6) end
        r.pand = pd
        button:AddPandemicRegion(pd)
    end
    if r.pand then
        local pc = opts.pandemicColor or { r = 1, g = 0.35, b = 0.1 }
        for i = 1, 4 do
            r.pand.tex[i]:SetColorTexture(pc.r or 1, pc.g or 0.35, pc.b or 0.1, pc.a or 1)
        end
        LayoutRing(r.pand, 2)
        r.pand:SetAlpha(wantPand and 1 or 0)
    end
end

local function Font(name, size, outline)
    local path = (LSM and LSM:Fetch("font", name or "Expressway")) or STANDARD_TEXT_FONT
    return path, size, outline
end

local function StyleButton(button, group, lane)
    local S = lane.slot
    if not S then return end
    button:SetSize(S.iw, S.ih)

    local r = lane.regions[button]
    if not r then
        r = {}
        r.icon = button:CreateTexture(nil, "ARTWORK")
        r.icon:SetAllPoints(button)
        button:SetIcon(r.icon)
        r.overlay = CreateFrame("Frame", nil, button)
        r.overlay:SetAllPoints(button)
        lane.regions[button] = r
    end
    r.overlay:SetFrameLevel(button:GetFrameLevel() + 3)
    ns.CustomGroups.ApplyIconSkin(button, r.icon, S.crop, S.skin)

    local key = lane.keyByButton[button]
    local def = key and lane.defByKey[key]

    local idb = def and def.iconDB
    local au = group.auras or {}

    local t = S.text or group.text or {}
    if idb and idb.overrideGroupText then
        t = {
            showCooldown = idb.showDuration ~= false,
            cooldownFont = idb.durationFont,
            cooldownFontSize = idb.durationFontSize,
            cooldownFontOutline = idb.durationFontOutline,
            cooldownColor = idb.durationColor,
            cooldownPoint = idb.durationPoint,
            cooldownXOffset = idb.durationXOffset,
            cooldownYOffset = idb.durationYOffset,
            showStacks = idb.showStacks and true or false,
            stacksFont = idb.stackFont,
            stacksFontSize = idb.stackFontSize,
            stacksFontOutline = idb.stackFontOutline,
            stacksColor = idb.stackColor,
            stacksPoint = idb.stackPoint,
            stacksXOffset = idb.stackXOffset,
            stacksYOffset = idb.stackYOffset,
        }
    end

    local bShow, bSize, bInset, bColor, bStroke = group.showBorder,
        group.borderSize or 1, group.borderInset or 0, group.borderColor, group.borderStroke
    if idb and idb.showBorder then
        bShow, bSize, bInset, bColor, bStroke = true,
            idb.borderSize or 1, idb.borderInset or 0, idb.borderColor, idb.borderStroke
    end

    if bShow then
        if not r.border then
            r.border = {}
            for i = 1, 4 do r.border[i] = button:CreateTexture(nil, "OVERLAY") end
        end
        EdgeRing(button, r.border, bSize, bInset, bColor or RING_BLACK)
    elseif r.border then
        for _, tex in ipairs(r.border) do tex:Hide() end
    end
    if bShow and bStroke then
        if not r.borderIn then
            r.borderIn, r.borderOut = {}, {}
            for i = 1, 4 do
                r.borderIn[i] = button:CreateTexture(nil, "OVERLAY")
                r.borderOut[i] = button:CreateTexture(nil, "OVERLAY")
            end
        end
        EdgeRing(button, r.borderIn, 1, bInset + bSize, RING_BLACK)
        EdgeRing(button, r.borderOut, 1, bInset - 1, RING_BLACK)
    elseif r.borderIn then
        for i = 1, 4 do r.borderIn[i]:Hide() r.borderOut[i]:Hide() end
    end

    if t.showCooldown ~= false then
        r.duration = r.duration or r.overlay:CreateFontString(nil, "OVERLAY")
        r.duration:ClearAllPoints()
        r.duration:SetPoint(t.cooldownPoint or "CENTER", button, t.cooldownPoint or "CENTER",
            t.cooldownXOffset or 0, t.cooldownYOffset or 0)
        E:SetFont(r.duration, Font(t.cooldownFont, t.cooldownFontSize or 16, t.cooldownFontOutline or "OUTLINE"))
        local cc = t.cooldownColor or {}
        r.duration:SetTextColor(cc.r or 1, cc.g or 1, cc.b or 1)
        r.duration:Show()
        button:SetDurationText(r.duration, { textFormatter = Formatter(), textColor = ThresholdColour(group) })
    else
        button:ClearDurationText()
        if r.duration then r.duration:SetText("") r.duration:Hide() end
    end

    if t.showStacks ~= false then
        r.count = r.count or r.overlay:CreateFontString(nil, "OVERLAY")
        r.count:ClearAllPoints()
        r.count:SetPoint(t.stacksPoint or "TOP", button, t.stacksPoint or "TOP",
            t.stacksXOffset or 0, t.stacksYOffset or 7)
        E:SetFont(r.count, Font(t.stacksFont, t.stacksFontSize or 11, t.stacksFontOutline or "OUTLINE"))
        local nc = t.stacksColor or {}
        r.count:SetTextColor(nc.r or 0, nc.g or 1, nc.b or 0)
        r.count:Show()
        button:SetApplicationCount(r.count, {})
    else
        button:ClearApplicationCount()
        if r.count then r.count:SetText("") r.count:Hide() end
    end

    local swipeOn = au.swipe ~= false
    local swipeRev = au.swipeInverse and true or false

    if swipeOn then
        if not r.cd then
            r.cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            r.cd:SetAllPoints(r.icon)
            r.cd:SetFrameLevel(button:GetFrameLevel() + 1)
            r.cd:SetDrawEdge(false)
            r.cd:SetHideCountdownNumbers(true)
        end
        r.cd:SetReverse(swipeRev)
        r.cd:Show()
        button:SetDurationCooldown(r.cd)
    else
        button:ClearDurationCooldown()
        if r.cd then r.cd:Hide() end
    end

    local style, gColor, gTh, gSrc
    if idb then
        if idb.showGlow then
            style = A.MapGlowStyle(idb.glowType)
            gColor = idb.glowColor
            gTh = idb.glowThickness
            gSrc = idb
        end
    elseif def and def.showGlow then
        style = def.glowStyle or "pulse"
        gColor = def.glowColor
        gTh = def.glowThickness
        gSrc = def
    end
    A.ApplyButtonFX(button, r, {
        style = style, color = gColor, thickness = gTh,
        lines = gSrc and gSrc.glowLines, length = gSrc and gSrc.glowLength,
        offset = gSrc and gSrc.glowOffset, frequency = gSrc and gSrc.glowSpeed,
        w = S.iw, h = S.ih,
        pandemic = (idb and idb.showPandemic) or (def and def.showPandemic) or false,
        pandemicColor = def and def.pandemicColor,
    })

    if def and def.showSource and A.CanShowSource(button) then
        r.source = r.source or r.overlay:CreateFontString(nil, "OVERLAY")
        r.source:ClearAllPoints()
        r.source:SetPoint(def.sourcePoint or "TOP", button, def.sourcePoint or "TOP",
            def.sourceXOffset or 0, def.sourceYOffset or 10)
        E:SetFont(r.source, Font(t.countFont, def.sourceFontSize or t.countFontSize or 12,
            t.countFontOutline or "OUTLINE"))
        local sc = def.sourceColor or {}
        r.source:SetTextColor(sc.r or 1, sc.g or 1, sc.b or 1)
        r.source:Show()
        button:SetSourceName(r.source, {})
        if button.SetSourceNameShortened then
            button:SetSourceNameShortened(def.sourceShortened ~= false)
        end
    else
        if A.CanShowSource(button) then button:ClearSourceName() end
        if r.source then r.source:SetText("") r.source:Hide() end
    end

    button:SetMouseMotionEnabled(au.tooltips and true or false)
end

local function LaneFor(group, frame)
    local lane = lanes[group.id]
    if lane then
        if lane.frame ~= frame then
            lane.tail:SetParent(frame)
            lane.container:SetParent(frame)
            if lane.containerT then lane.containerT:SetParent(frame) end
            lane.frame = frame
        end
        return lane
    end
    local tail = CreateFrame("Frame", "TUI_CustomGroup" .. group.id .. "_AuraTail", frame)
    local container = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
    lane = { frame = frame, tail = tail, container = container,
             regions = {}, keys = {}, defByKey = {}, keyByButton = {} }
    lanes[group.id] = lane
    return lane
end

local function FlowFor(S)
    if S.horizontal then
        return AXIS_H,
            (S.alongSign == 1) and FLOW_RIGHT or FLOW_LEFT,
            (S.crossSign == 1) and FLOW_UP or FLOW_DOWN
    end
    return AXIS_V,
        (S.crossSign == 1) and FLOW_RIGHT or FLOW_LEFT,
        (S.alongSign == 1) and FLOW_UP or FLOW_DOWN
end

local function ApplyFlowTo(container, S, entries, anchor, hDir, vDir)
    local total = 0
    for _, e in ipairs(entries) do total = total + math.max(1, e.def.max or 1) end
    local perLine = (S.perLine > 0) and S.perLine or math.max(total, 1)

    container:SetFlowLayoutAxis(S.horizontal and AXIS_H or AXIS_V)
    container:SetFlowLayoutAnchorPoint(anchor)
    container:SetFlowLayoutGrowthDirection(hDir, vDir)
    container:SetFlowLayoutMaximumLineSize(perLine * S.alongDim + (perLine - 1) * S.sp)

    if container.SetFlowLayoutPadding then
        container:SetFlowLayoutPadding(0, 0, 0, 0)
    end
end

local function ApplyFlow(lane, group, entries)
    local S = lane.slot
    local _, hDir, vDir = FlowFor(S)

    local anchor = S.pt
    if S.center then
        anchor = ((vDir == FLOW_UP) and "BOTTOM" or "TOP")
            .. ((hDir == FLOW_LEFT) and "RIGHT" or "LEFT")
    end

    ApplyFlowTo(lane.container, S, entries, anchor, hDir, vDir)
    return hDir, vDir
end

local function AttachSideFor(group, S)
    local side = group.attachSide
    if side and side ~= "AUTO" then return side end
    if S.horizontal then
        return (S.alongSign == 1) and "RIGHT" or "LEFT"
    end
    return (S.alongSign == 1) and "TOP" or "BOTTOM"
end

local function AttachLayout(side, sp, hDir, vDir, centered)
    local tH, tV = hDir, vDir
    local tPt, cPt, ox, oy
    if side == "TOP" then
        tV = FLOW_UP
        local h = (hDir == FLOW_LEFT) and "RIGHT" or "LEFT"
        tPt, cPt, ox, oy = "BOTTOM" .. h, "TOP" .. h, 0, sp
        if centered then tPt, cPt = "BOTTOM", "TOP" end
    elseif side == "BOTTOM" then
        tV = FLOW_DOWN
        local h = (hDir == FLOW_LEFT) and "RIGHT" or "LEFT"
        tPt, cPt, ox, oy = "TOP" .. h, "BOTTOM" .. h, 0, -sp
        if centered then tPt, cPt = "TOP", "BOTTOM" end
    elseif side == "LEFT" then
        tH = FLOW_LEFT
        local v = (vDir == FLOW_UP) and "BOTTOM" or "TOP"
        tPt, cPt, ox, oy = v .. "RIGHT", v .. "LEFT", -sp, 0
        if centered then tPt, cPt = "RIGHT", "LEFT" end
    else
        tH = FLOW_RIGHT
        local v = (vDir == FLOW_UP) and "BOTTOM" or "TOP"
        tPt, cPt, ox, oy = v .. "LEFT", v .. "RIGHT", sp, 0
        if centered then tPt, cPt = "LEFT", "RIGHT" end
    end
    local flowAnchor = tPt
    if centered then
        flowAnchor = ((tV == FLOW_UP) and "BOTTOM" or "TOP")
            .. ((tH == FLOW_LEFT) and "RIGHT" or "LEFT")
    end
    return tPt, cPt, ox, oy, tH, tV, flowAnchor
end

local function SortFor(def)
    local SM, SD = _G.AuraContainerSortMethod, _G.AuraContainerSortDirection
    if not (SM and SD) then return nil, nil end
    local mode = def.sort or "instance"
    if mode == "short" then return SM.ExpirationOnly, SD.Normal end
    if mode == "long" then return SM.ExpirationOnly, SD.Reverse end
    if mode == "new" then return SM.AuraInstanceIDOnly, SD.Reverse end
    return SM.AuraInstanceIDOnly, SD.Normal
end

A.SortFor = SortFor

local function ApplyEntry(lane, group, entry, ord, c)
    c = c or lane.container
    local key, def = entry.key, entry.def
    local prev = lane.keys[key]
    if prev and prev ~= true and prev ~= c then prev:SetAuraGroupMaxFrameCount(key, 0) end
    local filter
    if def.kind == "HARMFUL" then
        filter = "HARMFUL|PLAYER"
    else
        filter = def.onlyMine and "HELPFUL|PLAYER" or "HELPFUL"
    end

    local map = {}
    for id in pairs(def.spells or {}) do
        local n = tonumber(id)
        if n then map[n] = true end
    end

    local layout = {
        elementWidth = lane.slot.iw,
        elementHeight = lane.slot.ih,
        elementSpacing = lane.slot.sp,
        lineSpacing = lane.slot.sp,
        layoutIndex = ord,
    }
    local sortMethod, sortDir = SortFor(def)
    local maxCount = math.max(1, def.max or 1)

    lane.defByKey[key] = def
    if c:HasAuraGroup(key) then
        c:SetAuraGroupMaxFrameCount(key, maxCount)
        c:SetAuraGroupFilterString(key, filter)
        c:SetAuraGroupCandidateFilters(key, { includeSpellIDs = map })
        c:SetAuraGroupLayout(key, layout)
        if sortMethod then c:SetAuraGroupSortMethod(key, sortMethod, sortDir) end
    else
        c:AddAuraGroup(key, filter, {
            maxFrameCount = maxCount,
            sortMethod = sortMethod,
            sortDirection = sortDir,
            candidateFilters = { includeSpellIDs = map },
            layout = layout,
            initializeFrame = function(button)
                lane.keyByButton[button] = key
                StyleButton(button, lane.group or group, lane)
            end,
        })
    end
    lane.keys[key] = c
end

function Teardown(groupID)
    local lane = lanes[groupID]
    if not lane then return end
    if InCombatLockdown() then pendingSync = true return end
    for key, owner in pairs(lane.keys) do
        if owner == true then owner = lane.container end
        owner:SetAuraGroupMaxFrameCount(key, 0)
    end
    lane.container:Hide()
    if lane.containerT then lane.containerT:Hide() end
    lane.tail:Hide()
end

function A.Sync(group, frame)
    if not (group and frame and frame._tuiSlot) then return end
    if ns.CustomGroups.testMode then
        local lane = lanes[group.id]
        if lane then
            lane.container:Hide()
            if lane.containerT then lane.containerT:Hide() end
        end
        return
    end
    if InCombatLockdown() then
        if lanes[group.id] or A.HasSets(group) then pendingSync = true end
        return
    end

    local entries = A.Entries(group)
    if #entries == 0 then
        local lane = lanes[group.id]
        if lane then
            for key, owner in pairs(lane.keys) do
                if owner == true then owner = lane.container end
                owner:SetAuraGroupMaxFrameCount(key, 0)
            end
            lane.container:Hide()
            if lane.containerT then lane.containerT:Hide() end
        end
        return
    end
    if not Ready() then return end

    local au0 = group.auras or {}
    local sortMode = au0.sortMode or "manual"
    if sortMode ~= "manual" then
        local altU
        for _, e in ipairs(entries) do
            local u = e.def.unit
            if u and u ~= "player" then altU = altU or u break end
        end
        local buckets = {
            { tag = "H",  kind = nil,       unit = nil,  spells = {}, any = false },
            { tag = "D",  kind = "HARMFUL", unit = nil,  spells = {}, any = false },
            { tag = "HT", kind = nil,       unit = altU, spells = {}, any = false },
            { tag = "DT", kind = "HARMFUL", unit = altU, spells = {}, any = false },
        }
        for _, e in ipairs(entries) do
            local d = e.def
            local isAlt = altU ~= nil and d.unit == altU
            local b
            if d.kind == "HARMFUL" then b = isAlt and buckets[4] or buckets[2]
            else b = isAlt and buckets[3] or buckets[1] end
            b.any = true
            for id in pairs(d.spells or {}) do b.spells[id] = true end
        end
        local cap = tonumber(group.maxIcons) or 0
        local maxN = (cap > 0) and cap or 40
        local merged = {}
        for i, b in ipairs(buckets) do
            if b.any then
                merged[#merged + 1] = {
                    key = ("TUIAura%d_merged%s"):format(group.id or 0, b.tag),
                    def = { spells = b.spells, max = maxN, sort = sortMode, kind = b.kind, unit = b.unit },
                    rank = i,
                }
            end
        end
        if au0.sortGlow then
            for _, m in ipairs(merged) do
                m.def.showGlow = true
                m.def.glowStyle = au0.sortGlowStyle or "pulse"
                m.def.glowColor = au0.sortGlowColor
                m.def.glowThickness = au0.sortGlowThickness
                m.def.glowLines = au0.sortGlowLines
                m.def.glowLength = au0.sortGlowLength
                m.def.glowOffset = au0.sortGlowOffset
                m.def.glowSpeed = au0.sortGlowSpeed
            end
        end
        entries = merged
    end

    local lane = LaneFor(group, frame)
    lane.group = group
    lane.slot = frame._tuiSlot
    local S = lane.slot

    local slotIndex = ns.CustomGroups.NextFreeSlot(group, frame)
    local pt, tx, ty = ns.CustomGroups.SlotPoint(frame, slotIndex)
    lane.tail:ClearAllPoints()
    ns.Pixel.SetSize(lane.tail, S.iw, S.ih)
    ns.Pixel.SetPoint(lane.tail, pt, frame, pt, tx, ty)
    lane.tail:Show()

    local mainEntries, altEntries, altUnit = {}, {}, nil
    for _, e in ipairs(entries) do
        local u = e.def.unit
        if u and u ~= "player" then altUnit = altUnit or u end
    end
    for _, e in ipairs(entries) do
        if altUnit and e.def.unit == altUnit then
            altEntries[#altEntries + 1] = e
        else
            mainEntries[#mainEntries + 1] = e
        end
    end
    local split = #mainEntries > 0 and #altEntries > 0
    if not split then
        mainEntries, altEntries, altUnit = entries, {}, nil
    end

    local unit = "player"
    local hasPlayerSide = false
    for _, e in ipairs(mainEntries) do
        local u = e.def.unit
        if not u or u == "player" then hasPlayerSide = true break end
    end
    if not hasPlayerSide then
        for _, e in ipairs(mainEntries) do
            if e.def.unit then unit = e.def.unit break end
        end
    end

    lane.container:ClearAllPoints()
    lane.container:SetSize(S.iw, S.ih)
    lane.container:SetPoint(S.pt, lane.tail, S.pt, 0, 0)
    lane.container:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")

    local hDir, vDir = ApplyFlow(lane, group, mainEntries)

    if split and not lane.containerT then
        lane.containerT = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
    end
    local cT = lane.containerT
    if split then
        local side = AttachSideFor(group, S)
        local tPt, cPt, ox, oy, tH, tV, tAnchor = AttachLayout(side, S.sp, hDir, vDir, S.center)
        cT:ClearAllPoints()
        cT:SetSize(S.iw, S.ih)
        cT:SetPoint(tPt, lane.container, cPt, ox, oy)
        cT:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
        ApplyFlowTo(cT, S, altEntries, tAnchor, tH, tV)
    end

    local wanted = {}
    for i, entry in ipairs(mainEntries) do
        ApplyEntry(lane, group, entry, i, lane.container)
        wanted[entry.key] = true
    end
    for i, entry in ipairs(altEntries) do
        ApplyEntry(lane, group, entry, i, cT)
        wanted[entry.key] = true
    end
    for key, owner in pairs(lane.keys) do
        if not wanted[key] then
            if owner == true then owner = lane.container end
            owner:SetAuraGroupMaxFrameCount(key, 0)
        end
    end

    if lane.unit ~= unit then
        lane.container:SetUnit(unit)
        lane.unit = unit
        if lane.container.UpdateAllAuras then lane.container:UpdateAllAuras() end
    end
    if split and lane.unitT ~= altUnit then
        cT:SetUnit(altUnit)
        lane.unitT = altUnit
        if cT.UpdateAllAuras then cT:UpdateAllAuras() end
    end
    if not split then lane.unitT = nil end

    local function Flags(list)
        local pure, has = true, false
        for _, entry in ipairs(list) do
            if entry.def.kind == "HARMFUL" then has = true else pure = false end
        end
        return pure, has
    end
    lane.pureHarmful, lane.hasHarmful = Flags(mainEntries)
    lane.pureHarmfulT, lane.hasHarmfulT = Flags(altEntries)

    for button in pairs(lane.regions) do
        -- pool buttons are access-restricted while their aura is secret;
        -- the combat-lockdown flag can lag that window
        if not pcall(StyleButton, button, group, lane) then pendingSync = true end
    end
    lane.container:SetShown(LaneVisOK(lane))
    if cT then cT:SetShown(split and LaneVisOKT(lane) or false) end
end

function A.Release(groupID)
    Teardown(groupID)
end

function A.ReparseAll()
    for _, lane in pairs(lanes) do
        if lane.container.UpdateAllAuras then lane.container:UpdateAllAuras() end
        if lane.containerT and lane.containerT.UpdateAllAuras then lane.containerT:UpdateAllAuras() end
    end
end

local function RefreshHelpfulVis()
    if not (ns.CustomGroups and ns.CustomGroups.testMode) then
        for _, lane in pairs(lanes) do
            lane.container:SetShown(LaneVisOK(lane))
            if lane.containerT then lane.containerT:SetShown(LaneVisOKT(lane)) end
        end
    end
    if ns.SpecialAura and ns.SpecialAura.RefreshVisibility then ns.SpecialAura.RefreshVisibility() end
    if ns.CustomBars and ns.CustomBars.RefreshVisibility then ns.CustomBars.RefreshVisibility() end
end

local function ReparseEverything()
    A.ReparseAll()
    if ns.SpecialAura and ns.SpecialAura.ReparseAll then ns.SpecialAura.ReparseAll() end
    if ns.CustomBars and ns.CustomBars.ReparseAll then ns.CustomBars.ReparseAll() end
end

local assistTicker
local function CheckPlayerAssist()
    local ok = not not UnitCanAssist("player", "player")
    if ok ~= playerAssistOK then
        playerAssistOK = ok
        RefreshHelpfulVis()
        if ok then ReparseEverything() end
    end
    if not ok then
        if not assistTicker then assistTicker = C_Timer.NewTicker(1, CheckPlayerAssist) end
    elseif assistTicker then
        assistTicker:Cancel()
        assistTicker = nil
    end
end

local function ReparseSoon()
    local function sweep()
        CheckPlayerAssist()
        A.ReparseAll()
    end
    C_Timer.After(0.1, sweep)
    C_Timer.After(2, sweep)
    C_Timer.After(5, sweep)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_FOCUS_CHANGED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("CINEMATIC_STOP")
ev:RegisterEvent("STOP_MOVIE")
ev:RegisterUnitEvent("UNIT_PET", "player")
ev:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
ev:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
ev:RegisterUnitEvent("UNIT_FLAGS", "player")
ev:RegisterEvent("PLAYER_CONTROL_LOST")
ev:RegisterEvent("PLAYER_CONTROL_GAINED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" or event == "CINEMATIC_STOP" or event == "STOP_MOVIE" then
        ReparseSoon()
        return
    end
    if event == "UNIT_EXITED_VEHICLE" or event == "PLAYER_CONTROL_GAINED" then
        CheckPlayerAssist()
        C_Timer.After(0.5, ReparseEverything)
        return
    end
    if event == "UNIT_ENTERED_VEHICLE" or event == "PLAYER_CONTROL_LOST" or event == "UNIT_FLAGS" then
        CheckPlayerAssist()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if not pendingSync then return end
        pendingSync = false
        if TUI and TUI.UpdateCustomGroups then TUI:UpdateCustomGroups() end
        return
    end

    local want = (event == "PLAYER_FOCUS_CHANGED") and "focus"
        or (event == "UNIT_PET") and "pet" or "target"
    for _, lane in pairs(lanes) do
        if lane.unit == want then
            if not (ns.CustomGroups and ns.CustomGroups.testMode) then
                lane.container:SetShown(LaneVisOK(lane))
            end
            lane.container:SetUnit(want)
            if lane.container.UpdateAllAuras then lane.container:UpdateAllAuras() end
        end
        if lane.unitT == want and lane.containerT then
            if not (ns.CustomGroups and ns.CustomGroups.testMode) then
                lane.containerT:SetShown(LaneVisOKT(lane))
            end
            lane.containerT:SetUnit(want)
            if lane.containerT.UpdateAllAuras then lane.containerT:UpdateAllAuras() end
        end
    end
end)
