local addon, ns = ...
local A = ns.AuraLane

function A.MapGlowStyle(v)
    if v == "pulse" or v == "proc" or v == "ants" or v == "pixel" then return v end
    if v == "button" then return "proc" end
    return "pulse"
end

function A.GlowOptsFor(group, def)
    local idb = def and def.iconDB
    local style, gColor, gTh, gSrc
    if idb then
        if idb.showGlow then
            style = A.MapGlowStyle(idb.glowType)
            gColor = idb.glowColor
            gTh = idb.glowThickness
            gSrc = idb
        end
    elseif def then
        local SBm = ns.SpecialBars
        local st = def.styleName and SBm and SBm.Styles and SBm.Styles.Get("icons", def.styleName)
        if st then
            if st.showGlow then
                style = A.MapGlowStyle(st.glowType)
                gColor = st.glowColor
                gTh = st.glowThickness
                gSrc = st
            end
        elseif def.showGlow then
            style = def.glowStyle or "pulse"
            gColor = def.glowColor
            gTh = def.glowThickness
            gSrc = def
        end
    end
    if not style then return nil end
    local bOn
    if idb then bOn = idb.showBorder
    elseif gSrc ~= def then bOn = gSrc.showBorder
    else bOn = group and group.showBorder end
    local outline = (gSrc.glowBorderStroke and bOn) and true or false
    return {
        style = style, color = gColor, thickness = gTh, outline = outline,
        lines = gSrc.glowLines, length = gSrc.glowLength,
        offset = gSrc.glowOffset, frequency = gSrc.glowSpeed,
    }
end

function A.SortGlowOptsFor(group)
    local au = group and group.auras
    if au and au.sortStyle then return A.GlowOptsFor(group, { styleName = au.sortStyle }) end
    if not (au and au.sortGlow) then return nil end
    return A.GlowOptsFor(group, {
        showGlow = true,
        glowStyle = au.sortGlowStyle or "pulse",
        glowColor = au.sortGlowColor,
        glowThickness = au.sortGlowThickness,
        glowLines = au.sortGlowLines,
        glowLength = au.sortGlowLength,
        glowOffset = au.sortGlowOffset,
        glowSpeed = au.sortGlowSpeed,
        glowBorderStroke = au.sortGlowBorderStroke,
    })
end

local RING_BLACK = {}
local function NoSnap(tex)
    if tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
end
A.NoSnap = NoSnap

local function EdgeRing(host, texs, size, inset, c)
    for _, tex in ipairs(texs) do
        NoSnap(tex)
        tex:SetColorTexture(c.r or 0, c.g or 0, c.b or 0, c.a or 1)
        tex:ClearAllPoints()
        tex:Show()
    end
    local P = ns.Pixel.SetPoint
    P(texs[1], "TOPLEFT", host, "TOPLEFT", inset, -inset)
    P(texs[1], "BOTTOMRIGHT", host, "TOPRIGHT", -inset, -inset - size)
    P(texs[2], "TOPLEFT", host, "BOTTOMLEFT", inset, inset + size)
    P(texs[2], "BOTTOMRIGHT", host, "BOTTOMRIGHT", -inset, inset)
    P(texs[3], "TOPLEFT", host, "TOPLEFT", inset, -inset)
    P(texs[3], "BOTTOMRIGHT", host, "BOTTOMLEFT", inset + size, inset)
    P(texs[4], "TOPLEFT", host, "TOPRIGHT", -inset - size, -inset)
    P(texs[4], "BOTTOMRIGHT", host, "BOTTOMRIGHT", -inset, inset)
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

-- 12.1.5: an aura button plays a registered animation group itself while the aura shows
-- (pandemic slot: inside the pandemic window) and stops it afterwards, so pooled hidden
-- buttons animate nothing. A registered group is locked (no new animations, no progress
-- queries): a changed look gets a fresh group. Previews play their groups by hand.
local armed = setmetatable({}, { __mode = "k" })
local playing = setmetatable({}, { __mode = "k" })

local function CanArm(opts)
    local o = opts.animOwner
    if not o then return false end
    if opts.animSlot == "pandemic" then return o.AddPandemicActiveAnimation ~= nil end
    return o.AddAuraShownAnimation ~= nil
end

local function Run(ag, opts)
    if CanArm(opts) then
        if armed[ag] then return end
        local o, slot = opts.animOwner, opts.animSlot or "shown"
        if slot == "pandemic" then o:AddPandemicActiveAnimation(ag) else o:AddAuraShownAnimation(ag) end
        armed[ag] = { owner = o, slot = slot }
    elseif not playing[ag] then
        ag:Play()
        playing[ag] = true
    end
end

local function Halt(ag)
    local a = armed[ag]
    if a then
        if a.slot == "pandemic" then a.owner:RemovePandemicActiveAnimation(ag)
        else a.owner:RemoveAuraShownAnimation(ag) end
        armed[ag] = nil
    end
    playing[ag] = nil
    ag:Stop()
end

-- while a slider drags, an aura button's locked groups wait for the release: a fresh
-- group per step would pile up. Redrawn then in a pcall: an aura button showing a
-- secret aura denies addon access and the next restyle picks it up instead.
local deferred, deferTicker = {}, nil
local DrawGlow
local function DeferRedraw(parent, r, opts)
    deferred[r] = { parent = parent, opts = opts }
    if deferTicker then return end
    deferTicker = C_Timer.NewTicker(0.2, function()
        if IsMouseButtonDown("LeftButton") then return end
        deferTicker:Cancel()
        deferTicker = nil
        local todo = deferred
        deferred = {}
        for rr, d in pairs(todo) do pcall(DrawGlow, d.parent, rr, d.opts) end
    end)
end

-- Pixel glow: each runner is a line travelling the border that turns the corners
-- (shrinks into one while the next side's line grows out of it), all animation
-- groups, no OnUpdate. Each runner's chain starts at its own spot on the lap
-- (Play offsets don't stagger reliably) and ends exactly where it began.
local SIDES = {
    { point = "TOPLEFT",     horiz = true,  dx = 1,  dy = 0,  into = "RIGHT",  from = "LEFT" },
    { point = "TOPRIGHT",    horiz = false, dx = 0,  dy = -1, into = "BOTTOM", from = "TOP" },
    { point = "BOTTOMRIGHT", horiz = true,  dx = -1, dy = 0,  into = "LEFT",   from = "RIGHT" },
    { point = "BOTTOMLEFT",  horiz = false, dx = 0,  dy = 1,  into = "TOP",    from = "BOTTOM" },
}

local function AxisScale(side, v)
    if side.horiz then return v, 1 end
    return 1, v
end

local function LayoutRunner(px, run, w, h, th, L, freq, d0)
    local ag = run.ag
    if ag then
        if armed[ag] then
            Halt(ag)
            ag = nil
        else
            Halt(ag)
            -- animations can't be deleted one by one: empty the group (or start a new one)
            if ag.RemoveAnimations then ag:RemoveAnimations() else ag = nil end
        end
    end
    if not ag then
        ag = px:CreateAnimationGroup()
        ag:SetLooping("REPEAT")
        run.ag = ag
    end
    local P = 2 * (w + h)
    local travel = { math.max(w - L, 0), math.max(h - L, 0), math.max(w - L, 0), math.max(h - L, 0) }
    local function dur(dist) return math.max(0.001, dist / P / freq) end

    local used, order = 0, 0
    -- a line on a side, pushed `along` px from the side's starting corner
    local function Line(si, along, visible)
        used = used + 1
        local t = run.lines[used]
        if not t then
            t = px:CreateTexture(nil, "OVERLAY", nil, 7)
            NoSnap(t)
            run.lines[used] = t
        end
        local side = SIDES[si]
        t:ClearAllPoints()
        t:SetPoint(side.point, px, side.point, side.dx * along, side.dy * along)
        if side.horiz then t:SetSize(L, th) else t:SetSize(th, L) end
        t:SetAlpha(visible and 1 or 0)
        t:Show()
        return t
    end
    local function Straight(si, line, p0, p1)
        order = order + 1
        local dist = (p1 - p0) * travel[si]
        if dist <= 0 then return end
        local side = SIDES[si]
        local mv = ag:CreateAnimation("Translation")
        mv:SetTarget(line)
        mv:SetOrder(order)
        mv:SetOffset(side.dx * dist, side.dy * dist)
        mv:SetDuration(dur(dist))
    end
    -- turning from side si into the next: q0..q1 of the corner's length
    local function Corner(si, line, q0, q1, startsVisible)
        order = order + 1
        local ni = si % 4 + 1
        local side, nextSide = SIDES[si], SIDES[ni]
        local cd = dur((q1 - q0) * L)
        local shrink = ag:CreateAnimation("Scale")
        shrink:SetTarget(line)
        shrink:SetOrder(order)
        shrink:SetOrigin(side.into, 0, 0)
        shrink:SetScaleFrom(AxisScale(side, math.max(1 - q0, 0.001)))
        shrink:SetScaleTo(AxisScale(side, math.max(1 - q1, 0.001)))
        shrink:SetDuration(cd)
        local nextLine = Line(ni, 0, startsVisible)
        if not startsVisible then
            local show = ag:CreateAnimation("Alpha")
            show:SetTarget(nextLine)
            show:SetOrder(order)
            show:SetFromAlpha(0)
            show:SetToAlpha(1)
            show:SetDuration(0.001)
        end
        local grow = ag:CreateAnimation("Scale")
        grow:SetTarget(nextLine)
        grow:SetOrder(order)
        grow:SetOrigin(nextSide.from, 0, 0)
        grow:SetScaleFrom(AxisScale(nextSide, math.max(q0, 0.001)))
        grow:SetScaleTo(AxisScale(nextSide, math.max(q1, 0.001)))
        grow:SetDuration(cd)
        return nextLine, ni
    end

    -- where on the lap this runner starts: along side k, or turning corner k
    local d, k0, kind, prog = d0 % P, 1, "straight", 0
    for k = 1, 4 do
        if d < travel[k] then k0, kind, prog = k, "straight", d / travel[k] break end
        d = d - travel[k]
        if d < L then k0, kind, prog = k, "corner", d / L break end
        d = d - L
    end

    local si, line = k0, nil
    if kind == "straight" then
        line = Line(si, prog * travel[si], true)
        Straight(si, line, prog, 1)
        for lap = 1, 4 do
            line, si = Corner(si, line, 0, 1)
            if lap < 4 then Straight(si, line, 0, 1) end
        end
        if prog > 0 then Straight(si, line, 0, prog) end
    else
        line = Line(si, travel[si], true)
        -- already mid-turn when the lap starts: both halves show from the first frame
        line, si = Corner(si, line, prog, 1, true)
        for lap = 1, 4 do
            Straight(si, line, 0, 1)
            line, si = Corner(si, line, 0, lap < 4 and 1 or prog)
        end
    end
    for k = used + 1, #run.lines do run.lines[k]:Hide() end
end

-- the glow styles, drawn into parent: an aura button, or its pandemic region
DrawGlow = function(parent, r, opts)
    local style = opts.style
    local gc = opts.color

    if style == "pixel" then
        local px = r.glowPixel
        if not px then
            px = CreateFrame("Frame", nil, parent)
            px.runners = {}
            r.glowPixel = px
        end
        px:SetFrameLevel(parent:GetFrameLevel() + 2)

        local off = opts.offset or 0
        local anchorTo = opts.anchor or parent
        px:ClearAllPoints()
        px:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", -off, off)
        px:SetPoint("BOTTOMRIGHT", anchorTo, "BOTTOMRIGHT", off, -off)

        local th = math.max(1, math.floor((opts.thickness or 2) + 0.5))
        local N = math.min(12, math.max(1, opts.lines or 8))
        local Lv = math.min(6, math.max(1, opts.length or 3))
        local w = math.max(8, (opts.w or 36) + 2 * off)
        local h = math.max(8, (opts.h or 36) + 2 * off)
        local L = math.floor((w + h) * 0.05 * Lv + 0.5)
        L = math.max(2, math.min(L, math.min(w, h)))
        local freq = math.max(0.05, opts.frequency or 0.25)
        local c = gc or {}

        if opts.outline then
            if not px.band then
                px.band = {}
                for k = 1, 4 do
                    px.band[k] = px:CreateTexture(nil, "ARTWORK", nil, 6)
                end
            end
            EdgeRing(px, px.band, th + 1, 0, { r = 0.1, g = 0.1, b = 0.1, a = 0.8 })
        elseif px.band then
            for k = 1, 4 do px.band[k]:Hide() end
        end

        local sig = table.concat({ w, h, th, L, freq, N }, ":")
        local dragging = CanArm(opts) and IsMouseButtonDown and IsMouseButtonDown("LeftButton")
        local deferred
        for k = 1, N do
            local run = px.runners[k]
            if not run then
                run = { lines = {} }
                px.runners[k] = run
            end
            if run.sig ~= sig then
                if dragging and run.ag and armed[run.ag] then
                    deferred = true
                else
                    -- every runner walks the same lap, starting 1/N of it apart
                    LayoutRunner(px, run, w, h, th, L, freq, 2 * (w + h) * (k - 1) / N)
                    run.sig = sig
                end
            end
            for _, t in ipairs(run.lines) do
                t:SetColorTexture(c.r or 0.95, c.g or 0.95, c.b or 0.32, c.a or 1)
            end
            if run.ag then Run(run.ag, opts) end
        end
        for k = N + 1, #px.runners do
            local run = px.runners[k]
            if run.ag then Halt(run.ag) end
            for _, t in ipairs(run.lines) do t:Hide() end
        end
        px:Show()
        if deferred then DeferRedraw(parent, r, opts) end
    elseif r.glowPixel then
        local px = r.glowPixel
        for _, run in ipairs(px.runners) do
            if run.ag then Halt(run.ag) end
        end
        px:Hide()
    end

    if style == "pulse" then
        local g = r.glow
        if not g then
            g = CreateFrame("Frame", nil, parent)
            g:SetAllPoints(parent)
            g.tex = {}
            for i = 1, 4 do g.tex[i] = g:CreateTexture(nil, "OVERLAY", nil, 7) NoSnap(g.tex[i]) end
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
        g:SetFrameLevel(parent:GetFrameLevel() + 2)
        g:Show()
        Run(g.anim, opts)
    elseif r.glow then
        Halt(r.glow.anim)
        r.glow:Hide()
    end

    if style == "proc" then
        local p = r.glowProc
        if not p then
            p = CreateFrame("Frame", nil, parent)
            p:SetPoint("CENTER", parent, "CENTER", 0, 0)
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
        p:SetFrameLevel(parent:GetFrameLevel() + 2)
        p:Show()
        Run(p.anim, opts)
    elseif r.glowProc then
        Halt(r.glowProc.anim)
        r.glowProc:Hide()
    end

    if style == "ants" then
        local n = r.glowAnts
        if not n then
            n = CreateFrame("Frame", nil, parent)
            n:SetPoint("CENTER", parent, "CENTER", 0, 0)
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
        n:SetFrameLevel(parent:GetFrameLevel() + 2)
        n:Show()
        Run(n.anim, opts)
    elseif r.glowAnts then
        Halt(r.glowAnts.anim)
        r.glowAnts:Hide()
    end
end

local PAND_DEFAULT = { r = 1, g = 0.35, b = 0.1 }

-- an Aura Icon's, style's or group entry's pandemic look, onto glow opts
function A.PandemicLook(fx, src)
    if not src then return fx end
    fx.pandemicStyle = src.pandemicStyle
    fx.pandemicColor = src.pandemicColor
    fx.pandemicThickness = src.pandemicThickness
    fx.pandemicStroke = src.pandemicBorderStroke
    fx.pandemicLines = src.pandemicLines
    fx.pandemicLength = src.pandemicLength
    fx.pandemicOffset = src.pandemicOffset
    fx.pandemicSpeed = src.pandemicSpeed
    return fx
end

local STROKE_BLACK = { r = 0, g = 0, b = 0, a = 1 }

-- black lines inside and outside a border ring drawn by EdgeRing(host, _, size, inset)
function A.StrokeRing(host, store, size, inset, on)
    if not on then
        if store.sIn then for i = 1, 4 do store.sIn[i]:Hide(); store.sOut[i]:Hide() end end
        return
    end
    if not store.sIn then
        store.sIn, store.sOut = {}, {}
        for i = 1, 4 do
            store.sIn[i] = host:CreateTexture(nil, "OVERLAY", nil, 7)
            store.sOut[i] = host:CreateTexture(nil, "OVERLAY", nil, 7)
        end
    end
    EdgeRing(host, store.sIn, 1, inset + size, STROKE_BLACK)
    EdgeRing(host, store.sOut, 1, inset - 1, STROKE_BLACK)
end

-- the pandemic border reaches th out of the button
local function PandemicStroke(pd, th)
    A.StrokeRing(pd, pd, th or 0, -(th or 0), th ~= nil)
end

function A.ApplyButtonFX(button, r, opts)
    -- a real aura button runs its glow animations itself (previews don't have that hook)
    local owner = button.AddAuraShownAnimation and button or nil
    opts.animOwner, opts.animSlot = owner, nil
    DrawGlow(button, r, opts)

    -- the pandemic region is shown by the aura engine only inside the pandemic window
    local wantPand = opts.pandemic and A.CanPandemic(button) or false
    if wantPand and not r.pand then
        local pd = CreateFrame("Frame", nil, button)
        pd:SetAllPoints(button)
        pd:SetFrameLevel(button:GetFrameLevel() + 4)
        pd.tex = {}
        for i = 1, 4 do pd.tex[i] = pd:CreateTexture(nil, "OVERLAY", nil, 6) NoSnap(pd.tex[i]) end
        r.pand = pd
        r.pandFX = {}
        button:AddPandemicRegion(pd)
    end
    if r.pand then
        local pc = opts.pandemicColor or PAND_DEFAULT
        local ps = wantPand and opts.pandemicStyle or nil
        if ps and ps ~= "border" then
            for i = 1, 4 do r.pand.tex[i]:Hide() end
            PandemicStroke(r.pand, nil)
        else
            ps = nil
            local th = opts.pandemicThickness or 2
            for i = 1, 4 do
                r.pand.tex[i]:SetColorTexture(pc.r or 1, pc.g or 0.35, pc.b or 0.1, pc.a or 1)
            end
            LayoutRing(r.pand, th)
            PandemicStroke(r.pand, (wantPand and opts.pandemicStroke) and th or nil)
        end
        -- the same styles as Glow While Active, played by the engine only inside the pandemic window
        DrawGlow(r.pand, r.pandFX, { style = ps, color = pc, w = opts.w, h = opts.h, anchor = opts.anchor,
            thickness = opts.pandemicThickness, lines = opts.pandemicLines, length = opts.pandemicLength,
            offset = opts.pandemicOffset, frequency = opts.pandemicSpeed, outline = opts.pandemicStroke,
            animOwner = owner, animSlot = "pandemic" })
        r.pand:SetAlpha(wantPand and 1 or 0)
    end
end
