local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

ns.SpecialBars = ns.SpecialBars or {}
local SB = ns.SpecialBars
local iconGroupState = SB.iconGroupState
local yoinkedBars    = SB.yoinkedBars
local ReturnFrame    = function(...) return SB.ReturnFrame(...) end

local function GetOrCreateIconFrame(iconKey)
    local name    = 'TUI_SpecialIcon_' .. iconKey
    local wrapper = _G[name] or CreateFrame('Frame', name, UIParent)
    wrapper:SetFrameStrata('MEDIUM')
    wrapper:SetFrameLevel(10)
    if not wrapper.fallback then
        wrapper.fallback = wrapper:CreateTexture(nil, 'ARTWORK')
        wrapper.fallback:SetAllPoints()
        wrapper.fallbackBorder = CreateFrame('Frame', nil, wrapper, 'BackdropTemplate')
        wrapper.fallbackBorder:SetAllPoints()
        wrapper.fallbackBorder:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
        wrapper.fallbackBorder:SetBackdropColor(0,0,0,0)
        wrapper.fallbackBorder:SetBackdropBorderColor(0,0,0,1)
        wrapper.fallback:Hide()
        wrapper.fallbackBorder:Hide()
    end
    if not wrapper.tuiBorder then
        local inner = CreateFrame('Frame', nil, wrapper, 'BackdropTemplate')
        inner:SetFrameLevel(12)
        inner:SetBackdrop({ bgFile = nil, edgeFile = E.media.blankTex, edgeSize = 1 })
        inner:SetBackdropColor(0, 0, 0, 0)
        inner:SetBackdropBorderColor(0, 0, 0, 1)
        inner:Hide()
        wrapper.tuiBorderInner = inner
        local bd = CreateFrame('Frame', nil, wrapper, 'BackdropTemplate')
        bd:SetFrameLevel(12)
        bd:SetBackdrop({ bgFile = nil, edgeFile = E.media.blankTex, edgeSize = 1 })
        bd:SetBackdropColor(0, 0, 0, 0)
        bd:SetBackdropBorderColor(0, 0, 0, 1)
        bd:Hide()
        wrapper.tuiBorder = bd
        local outer = CreateFrame('Frame', nil, wrapper, 'BackdropTemplate')
        outer:SetFrameLevel(12)
        outer:SetBackdrop({ bgFile = nil, edgeFile = E.media.blankTex, edgeSize = 1 })
        outer:SetBackdropColor(0, 0, 0, 0)
        outer:SetBackdropBorderColor(0, 0, 0, 1)
        outer:Hide()
        wrapper.tuiBorderOuter = outer
    end
    return wrapper
end

local _bdMain   = { bgFile = nil, edgeFile = nil, edgeSize = 1 }
local _bdInner  = { bgFile = nil, edgeFile = nil, edgeSize = 1 }
local _bdOuter  = { bgFile = nil, edgeFile = nil, edgeSize = 1 }

local function ApplyIconBorder(wrapper, db)
    local bd    = wrapper.tuiBorder
    local inner = wrapper.tuiBorderInner
    local outer = wrapper.tuiBorderOuter
    if not bd then return end

    if not db.showBorder then
        bd:Hide(); inner:Hide(); outer:Hide()
        return
    end

    local size   = db.borderSize  or 1
    local inset  = db.borderInset or 0
    local bc     = db.borderColor or { r=0, g=0, b=0, a=1 }
    local stroke = db.borderStroke

    _bdMain.edgeFile = E.media.blankTex
    _bdMain.edgeSize = size
    bd:SetBackdrop(nil)
    bd:SetBackdrop(_bdMain)
    bd:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
    bd:ClearAllPoints()
    bd:SetPoint('TOPLEFT',     wrapper, 'TOPLEFT',      inset, -inset)
    bd:SetPoint('BOTTOMRIGHT', wrapper, 'BOTTOMRIGHT', -inset,  inset)
    bd:Show()

    if stroke then
        _bdInner.edgeFile = E.media.blankTex
        _bdInner.edgeSize = 1
        inner:SetBackdrop(nil)
        inner:SetBackdrop(_bdInner)
        inner:SetBackdropBorderColor(0, 0, 0, 1)
        inner:ClearAllPoints()
        inner:SetPoint('TOPLEFT',     wrapper, 'TOPLEFT',      inset + size, -(inset + size))
        inner:SetPoint('BOTTOMRIGHT', wrapper, 'BOTTOMRIGHT', -(inset + size),  inset + size)
        inner:Show()
        _bdOuter.edgeFile = E.media.blankTex
        _bdOuter.edgeSize = 1
        outer:SetBackdrop(nil)
        outer:SetBackdrop(_bdOuter)
        outer:SetBackdropBorderColor(0, 0, 0, 1)
        outer:ClearAllPoints()
        outer:SetPoint('TOPLEFT',     wrapper, 'TOPLEFT',      inset - 1, -(inset - 1))
        outer:SetPoint('BOTTOMRIGHT', wrapper, 'BOTTOMRIGHT', -(inset - 1),  inset - 1)
        outer:Show()
    else
        inner:Hide()
        outer:Hide()
    end
end

local function StopAllGlows(frame)
    if not LCG or not frame then return end
    LCG.PixelGlow_Stop(frame, "tui")
    LCG.AutoCastGlow_Stop(frame, "tui")
    LCG.ButtonGlow_Stop(frame)
    LCG.ProcGlow_Stop(frame, "tui")
end

local _glowCol = { 1, 1, 0, 1 }
local _procGlowOpts = { color = nil, duration = 0.25, key = "tui" }

local function BuildGlowSig(db)
    if not db.showGlow then return nil end
    local gc = db.glowColor or { r=1, g=1, b=0, a=1 }
    local inside = db.glowInsideBorder and db.showBorder
    local thickness = inside and (db.borderSize or 1) or (db.glowThickness or 2)
    local s = strjoin("\a",
        db.glowType or "pixel",
        tostring(gc.r), tostring(gc.g),
        tostring(gc.b), tostring(gc.a),
        tostring(db.glowN         or 8),
        tostring(db.glowFrequency or 0.25),
        tostring(db.glowLength    or 10),
        tostring(thickness),
        tostring(db.glowXOffset   or 0),
        tostring(db.glowYOffset   or 0),
        tostring(inside or false))
    return s
end

local function ApplyIconGlow(wrapper, db)
    if not LCG then return end

    if not db.showGlow then
        if wrapper._tuiGlowSig then
            StopAllGlows(wrapper)
            if wrapper.tuiBorder then StopAllGlows(wrapper.tuiBorder) end
            wrapper._tuiGlowSig = nil
        end
        return
    end

    local target = wrapper
    if db.glowInsideBorder and db.showBorder and wrapper.tuiBorder then
        target = wrapper.tuiBorder
    end

    local sig = BuildGlowSig(db)
    if sig and sig == wrapper._tuiGlowSig then return end

    StopAllGlows(wrapper)
    if wrapper.tuiBorder then StopAllGlows(wrapper.tuiBorder) end

    local gc = db.glowColor or { r=1, g=1, b=0, a=1 }
    _glowCol[1] = gc.r; _glowCol[2] = gc.g; _glowCol[3] = gc.b; _glowCol[4] = gc.a
    local col = _glowCol
    local xOff = db.glowXOffset or 0
    local yOff = db.glowYOffset or 0
    local gtype = db.glowType or "pixel"
    local thickness = (db.glowInsideBorder and db.showBorder)
        and (db.borderSize or 1)
        or  (db.glowThickness or 2)

    if gtype == "pixel" then
        LCG.PixelGlow_Start(target, col,
            db.glowN or 8,
            db.glowFrequency or 0.25,
            db.glowLength or 10,
            thickness,
            xOff, yOff, false, "tui")
    elseif gtype == "autocast" then
        LCG.AutoCastGlow_Start(target, col,
            db.glowN or 8,
            db.glowFrequency or 0.25,
            thickness,
            xOff, yOff, "tui")
    elseif gtype == "button" then
        LCG.ButtonGlow_Start(target, col, db.glowFrequency or 0.25)
    elseif gtype == "proc" then
        _procGlowOpts.color    = col
        _procGlowOpts.duration = db.glowFrequency or 0.25
        LCG.ProcGlow_Start(target, _procGlowOpts)
    end

    wrapper._tuiGlowSig = sig
end

local function FindIconBySpell(spellID, forKey)
    if not spellID then return nil end
    local claimed = SB.RebuildClaimedIconFrames()
    if BuffIconCooldownViewer then
        local children, childCount = SB.GetChildrenReuseFind(BuffIconCooldownViewer)
        for i = 1, childCount do
            local child = children[i]
            local owner = claimed[child]
            if (not owner or owner == forKey) and SB.SafeMatch(child, spellID, false) then
                return child
            end
        end
    end
    for child in pairs(yoinkedBars) do
        local owner = claimed[child]
        if (not owner or owner == forKey) and SB.SafeMatch(child, spellID, false) then
            return child
        end
    end
    return nil
end

-- Saves CDM's original icon styling on first call so ReturnFrame can restore it.
local function StyleYoinkedIcon(childFrame, db)
    if not childFrame._tuiOrigStyle then
        local orig = {}
        if childFrame.Icon and childFrame.Icon.GetTexCoord then
            orig.iconTexCoords = { childFrame.Icon:GetTexCoord() }
        end
        if childFrame.Cooldown then
            orig.drawSwipe = childFrame.Cooldown:GetDrawSwipe()
            orig.drawEdge  = childFrame.Cooldown:GetDrawEdge()
            for i = 1, childFrame.Cooldown:GetNumRegions() do
                local r = select(i, childFrame.Cooldown:GetRegions())
                if r and r.GetObjectType and r:GetObjectType() == 'FontString' then
                    local f, s, o = r:GetFont()
                    orig.cdFont     = f
                    orig.cdFontSize = s
                    orig.cdFontOut  = o
                    orig.cdR, orig.cdG, orig.cdB = r:GetTextColor()
                    orig.cdShown = r:IsShown()
                    break
                end
            end
        end
        local app = childFrame.Applications
            and childFrame.Applications.Applications
            or  childFrame.Applications
        if app then
            local f, s, o = app:GetFont()
            orig.appFont     = f
            orig.appFontSize = s
            orig.appFontOut  = o
            orig.appR, orig.appG, orig.appB = app:GetTextColor()
            orig.appAlpha = app:GetAlpha()
        end
        childFrame._tuiOrigStyle = orig
    end

    if childFrame.Icon then
        childFrame.Icon:SetScale(1)
        local z = db.zoom or 0.1
        childFrame.Icon:SetTexCoord(z, 1-z, z, 1-z)
    end
    if childFrame.Cooldown then
        childFrame.Cooldown:SetDrawSwipe(db.showCooldown)
        childFrame.Cooldown:SetDrawEdge(false)

        if db.showDuration ~= false then
            local font = LSM:Fetch('font', db.durationFont or 'Expressway')
            local dc = db.durationColor
            local pt = db.durationPoint or 'CENTER'
            for i = 1, childFrame.Cooldown:GetNumRegions() do
                local r = select(i, childFrame.Cooldown:GetRegions())
                if r and r.GetObjectType and r:GetObjectType() == 'FontString' then
                    r:SetFont(font, db.durationFontSize or 14, db.durationFontOutline or 'OUTLINE')
                    if dc then r:SetTextColor(dc.r, dc.g, dc.b) end
                    r:ClearAllPoints()
                    r:SetPoint(pt, childFrame.Cooldown, pt, db.durationXOffset or 0, db.durationYOffset or 0)
                    r:Show()
                end
            end
        else
            for i = 1, childFrame.Cooldown:GetNumRegions() do
                local r = select(i, childFrame.Cooldown:GetRegions())
                if r and r.GetObjectType and r:GetObjectType() == 'FontString' then r:Hide() end
            end
        end
    end
    local app = childFrame.Applications and childFrame.Applications.Applications or childFrame.Applications
    if app then
        local stackFont = LSM:Fetch('font', db.stackFont or 'Expressway')
        app:SetFont(stackFont, db.stackFontSize or 14, db.stackFontOutline or 'OUTLINE')
        local sc = db.stackColor
        if sc then app:SetTextColor(sc.r, sc.g, sc.b) end
        local pt = db.stackPoint or 'BOTTOMRIGHT'
        app:ClearAllPoints()
        app:SetPoint(pt, childFrame, pt, db.stackXOffset or 0, db.stackYOffset or 0)
        if db.showStacks then app:SetAlpha(1) else app:SetAlpha(0) end
    end
end

local function ReleaseIcon(iconKey)
    local state = iconGroupState[iconKey]
    if not state then return end
    ReturnFrame(state.childFrame)
    if state.wrapper then
        local w = state.wrapper
        StopAllGlows(w)
        if w.tuiBorder then StopAllGlows(w.tuiBorder) end
        w._tuiGlowSig = nil
        w:Hide()
        if w.tuiBorder      then w.tuiBorder:Hide()      end
        if w.tuiBorderInner then w.tuiBorderInner:Hide() end
        if w.tuiBorderOuter then w.tuiBorderOuter:Hide() end
    end
    iconGroupState[iconKey] = nil
end

local UpdateIconSlot
UpdateIconSlot = function(iconKey)
    local db = SB.GetIconDB(iconKey)
    if not db.enabled or not db.spellID then ReleaseIcon(iconKey); return end

    local wrapper     = GetOrCreateIconFrame(iconKey)
    local anchorName  = (db.anchorMode ~= 'CUSTOM') and db.anchorMode or db.anchorFrame
    local anchorFrame = anchorName and _G[anchorName]

    local w = db.width  or 36
    local h = db.keepAspectRatio ~= false and w or (db.height or 36)
    wrapper:SetSize(w, h)

    if anchorFrame then
        wrapper:ClearAllPoints()
        wrapper:SetPoint(db.anchorPoint, anchorFrame, db.anchorRelativePoint, db.anchorXOffset, db.anchorYOffset)
    end

    local realFrame = FindIconBySpell(db.spellID, iconKey)
    local isActive  = realFrame and realFrame:IsShown()

    if isActive then
        if iconGroupState[iconKey] and iconGroupState[iconKey].childFrame ~= realFrame then
            ReturnFrame(iconGroupState[iconKey].childFrame)
        end
        local state = iconGroupState[iconKey]
        if not state then state = {}; iconGroupState[iconKey] = state end
        state.wrapper    = wrapper
        state.childFrame = realFrame
        state.w          = w
        state.h          = h

        realFrame._cdmOriginalParent = realFrame._cdmOriginalParent or realFrame:GetParent()
        if not realFrame._cdmOriginalW then
            realFrame._cdmOriginalW = realFrame:GetWidth()
            realFrame._cdmOriginalH = realFrame:GetHeight()
        end
        realFrame:SetParent(wrapper)
        realFrame:ClearAllPoints()
        realFrame:SetPoint('CENTER', wrapper, 'CENTER', 0, 0)
        realFrame:SetSize(w, h)
        yoinkedBars[realFrame] = true

        wrapper.fallback:Hide()
        wrapper.fallbackBorder:Hide()
        StyleYoinkedIcon(realFrame, db)
        ApplyIconBorder(wrapper, db)
        ApplyIconGlow(wrapper, db)
        wrapper:Show()
    else
        if iconGroupState[iconKey] and iconGroupState[iconKey].childFrame then
            ReturnFrame(iconGroupState[iconKey].childFrame)
        end
        local state = iconGroupState[iconKey]
        if not state then state = {}; iconGroupState[iconKey] = state end
        state.wrapper    = wrapper
        state.childFrame = nil
        state.w          = nil
        state.h          = nil

        if db.desaturateWhenInactive then
            local spellInfo = SB.GetRawSpellList()[db.spellID]
            if spellInfo then wrapper.fallback:SetTexture(spellInfo.icon) end
            local z = db.zoom or 0.1
            wrapper.fallback:SetTexCoord(z, 1-z, z, 1-z)
            wrapper.fallback:SetDesaturated(true)
            wrapper.fallback:Show()
            wrapper.fallbackBorder:Show()
            ApplyIconBorder(wrapper, db)
            -- Glow is an "active" indicator — never glow the desaturated fallback.
            StopAllGlows(wrapper)
            if wrapper.tuiBorder then StopAllGlows(wrapper.tuiBorder) end
            wrapper._tuiGlowSig = nil
            wrapper:Show()
        else
            wrapper.fallback:Hide()
            wrapper.fallbackBorder:Hide()
            if wrapper.tuiBorder      then wrapper.tuiBorder:Hide()      end
            if wrapper.tuiBorderInner then wrapper.tuiBorderInner:Hide() end
            if wrapper.tuiBorderOuter then wrapper.tuiBorderOuter:Hide() end
            StopAllGlows(wrapper)
            if wrapper.tuiBorder then StopAllGlows(wrapper.tuiBorder) end
            wrapper._tuiGlowSig = nil
            wrapper:Hide()
        end
    end
end

SB.UpdateIconSlot = UpdateIconSlot
SB.ReleaseIcon    = ReleaseIcon