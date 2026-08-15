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
    elseif def and def.showGlow then
        style = def.glowStyle or "pulse"
        gColor = def.glowColor
        gTh = def.glowThickness
        gSrc = def
    end
    if not style then return nil end
    local bOn = (idb and idb.showBorder) or (not idb and group and group.showBorder)
    local outline = (gSrc.glowBorderStroke and bOn) and true or false
    return {
        style = style, color = gColor, thickness = gTh, outline = outline,
        lines = gSrc.glowLines, length = gSrc.glowLength,
        offset = gSrc.glowOffset, frequency = gSrc.glowSpeed,
    }
end

function A.SortGlowOptsFor(group)
    local au = group and group.auras
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

function A.ApplyButtonFX(button, r, opts)
    local style = opts.style
    local gc = opts.color

    if style == "pixel" then
        local px = r.glowPixel
        if not px then
            px = CreateFrame("Frame", nil, button)
            px.strips = {}
            r.glowPixel = px
        end
        if px.lines then
            for _, t in ipairs(px.lines) do t:Hide() end
            px.lines = nil
            if px.bg then px.bg:Hide() end
        end
        px:SetFrameLevel(button:GetFrameLevel() + 2)

        local off = opts.offset or 0
        local anchorTo = opts.anchor or button
        px:ClearAllPoints()
        -- x bias user-calibrated: whole ring 0.1 left, right edge 0.1 further in
        px:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", -off, off)
        px:SetPoint("BOTTOMRIGHT", anchorTo, "BOTTOMRIGHT", off - 1.5, -off)

        local th = math.max(1, math.floor((opts.thickness or 2) + 0.5))
        local N = math.min(12, math.max(1, opts.lines or 8))
        local Lv = math.min(6, math.max(1, opts.length or 3))
        local w = math.max(8, (opts.w or 36) + 2 * off)
        local h = math.max(8, (opts.h or 36) + 2 * off)
        local L = math.floor((w + h) * 0.05 * Lv + 0.5)
        L = math.max(2, math.min(L, math.min(w, h)))
        local P = 2 * (w + h)
        local spacing = math.max(L + 2, math.floor(P / N + 0.5))
        local dur = spacing / (P * math.max(0.05, opts.frequency or 0.25))
        local c = gc or {}
        local sig = table.concat({ w, h, th, L, spacing, dur }, ":")

        if opts.outline then
            if not px.band then
                px.band = {}
                for i = 1, 4 do
                    px.band[i] = px:CreateTexture(nil, "ARTWORK", nil, 6)
                end
            end
            EdgeRing(px, px.band, th + 1, 0, { r = 0.1, g = 0.1, b = 0.1, a = 0.8 })
        elseif px.band then
            for i = 1, 4 do px.band[i]:Hide() end
        end

        local defs = {
            { a1 = "TOPLEFT",     a2 = "TOPRIGHT",    sw = w,  sh = th, dx = 1,  dy = 0,  start = 0 },
            { a1 = "TOPRIGHT",    a2 = "BOTTOMRIGHT", sw = th, sh = h,  dx = 0,  dy = -1, start = w },
            { a1 = "BOTTOMRIGHT", a2 = "BOTTOMLEFT",  sw = w,  sh = th, dx = -1, dy = 0,  start = w + h },
            { a1 = "BOTTOMLEFT",  a2 = "TOPLEFT",     sw = th, sh = h,  dx = 0,  dy = 1,  start = 2 * w + h },
        }
        for e = 1, 4 do
            local d = defs[e]
            local strip = px.strips[e]
            if not strip then
                strip = CreateFrame("Frame", nil, px)
                strip:SetClipsChildren(true)
                strip.tex = {}
                px.strips[e] = strip
            end
            if strip._model ~= 2 then
                if strip.anim then strip.anim:Stop() end
                for _, t in ipairs(strip.tex) do t:Hide() if t.bg then t.bg:Hide() end end
                strip.tex = {}
                strip.anim = strip:CreateAnimationGroup()
                strip.anim:SetLooping("REPEAT")
                strip._model = 2
            end
            strip:ClearAllPoints()
            strip:SetPoint(d.a1, px, d.a1, 0, 0)
            strip:SetPoint(d.a2, px, d.a2, 0, 0)
            strip:SetSize(d.sw, d.sh)
            strip:SetFrameLevel(px:GetFrameLevel() + 1)
            strip:Show()

            local horiz = d.dy == 0
            local stripLen = horiz and d.sw or d.sh
            local phase = (-d.start) % spacing
            local cnt = math.ceil(stripLen / spacing) + 2
            local restart = false
            for k = 1, cnt do
                local t = strip.tex[k]
                if not t then
                    t = strip:CreateTexture(nil, "OVERLAY", nil, 7)
                    NoSnap(t)
                    t.move = strip.anim:CreateAnimation("Translation")
                    t.move:SetTarget(t)
                    strip.tex[k] = t
                end
                t:SetColorTexture(c.r or 0.95, c.g or 0.95, c.b or 0.32, c.a or 1)
                if t._sig ~= sig then
                    t._sig = sig
                    restart = true
                    t:ClearAllPoints()
                    local d0 = (k - 2) * spacing + phase
                    if horiz then
                        t:SetSize(L, th)
                        if d.dx > 0 then
                            t:SetPoint("LEFT", strip, "LEFT", d0, 0)
                        else
                            t:SetPoint("RIGHT", strip, "RIGHT", -d0, 0)
                        end
                    else
                        t:SetSize(th, L)
                        if d.dy < 0 then
                            t:SetPoint("TOP", strip, "TOP", 0, -d0)
                        else
                            t:SetPoint("BOTTOM", strip, "BOTTOM", 0, d0)
                        end
                    end
                    t.move:SetOffset(spacing * d.dx, spacing * d.dy)
                    t.move:SetDuration(dur)
                end
                t:Show()
            end
            for k = cnt + 1, #strip.tex do
                local t = strip.tex[k]
                t:Hide()
                if t.move then t.move:SetOffset(spacing * d.dx, spacing * d.dy) t.move:SetDuration(dur) t._sig = nil end
            end
            if restart then strip.anim:Stop() end
            if not strip.anim:IsPlaying() then strip.anim:Play() end
        end
        px:Show()
    elseif r.glowPixel then
        local px = r.glowPixel
        if px.strips then
            for _, strip in ipairs(px.strips) do
                if strip.anim then strip.anim:Stop() end
            end
        end
        px:Hide()
    end

    if style == "pulse" then
        local g = r.glow
        if not g then
            g = CreateFrame("Frame", nil, button)
            g:SetAllPoints(button)
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
        g:SetFrameLevel(button:GetFrameLevel() + 2)
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
        p:SetFrameLevel(button:GetFrameLevel() + 2)
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
        n:SetFrameLevel(button:GetFrameLevel() + 2)
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
        for i = 1, 4 do pd.tex[i] = pd:CreateTexture(nil, "OVERLAY", nil, 6) NoSnap(pd.tex[i]) end
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
