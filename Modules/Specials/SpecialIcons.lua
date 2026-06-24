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

local _iconMoverCreated = {}
local function EnsureIconMover(wrapper, iconKey, displayName)
    if _iconMoverCreated[iconKey] then return end
    local ms = ns.MoverSync
    if not (ms and ms.CreateManaged) then return end
    ms.CreateManaged(wrapper, "TUI_SpecialIconMover_" .. iconKey, displayName or ("Special Icon " .. iconKey), {
        configString  = "thingsUI,modulesTab,specialIcons," .. iconKey .. "Group,anchorGroup",
        shouldDisable = function() return not (E.db.thingsUI and E.db.thingsUI.specialBars) end,
        onSave = function(point, relPoint, x, y)
            local db = SB.GetIconDB(iconKey)
            if not db then return end
            db.anchorPoint = point
            db.anchorRelativePoint = relPoint
            db.anchorXOffset = x
            db.anchorYOffset = y
            ns.NotifyChange()
        end,
    })
    _iconMoverCreated[iconKey] = true
end

local function HideIconMover(iconKey)
    local wrapper = _G["TUI_SpecialIcon_" .. iconKey]
    if ns.MoverSync and ns.MoverSync.RemoveManaged then
        ns.MoverSync.RemoveManaged("TUI_SpecialIconMover_" .. iconKey, wrapper)
    elseif wrapper then
        wrapper:Hide()
    end
end
SB.HideIconMover = HideIconMover

local function GetOrCreateIconFrame(iconKey)
    local name    = 'TUI_SpecialIcon_' .. iconKey
    local wrapper = _G[name] or CreateFrame('Frame', name, UIParent)
    local db = SB.GetIconDB(iconKey)
    wrapper:SetFrameStrata((db and db.frameStrata) or 'MEDIUM')
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

local function BuildGlowSig(db, borderDB)
    if not db.showGlow then return nil end
    borderDB = borderDB or db
    local gc = db.glowColor or { r=1, g=1, b=0, a=1 }
    local inside = db.glowInsideBorder and borderDB.showBorder
    local thickness = inside and (borderDB.borderSize or 1) or (db.glowThickness or 2)
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

local function ApplyIconGlow(wrapper, db, borderDB)
    if not LCG then return end
    borderDB = borderDB or db

    if not db.showGlow then
        if wrapper._tuiGlowSig then
            StopAllGlows(wrapper)
            if wrapper.tuiBorder then StopAllGlows(wrapper.tuiBorder) end
            wrapper._tuiGlowSig = nil
        end
        return
    end

    local target = wrapper
    if db.glowInsideBorder and borderDB.showBorder and wrapper.tuiBorder then
        target = wrapper.tuiBorder
    end

    local sig = BuildGlowSig(db, borderDB)
    if sig and sig == wrapper._tuiGlowSig then return end

    StopAllGlows(wrapper)
    if wrapper.tuiBorder then StopAllGlows(wrapper.tuiBorder) end

    local gc = db.glowColor or { r=1, g=1, b=0, a=1 }
    _glowCol[1] = gc.r; _glowCol[2] = gc.g; _glowCol[3] = gc.b; _glowCol[4] = gc.a
    local col = _glowCol
    local xOff = db.glowXOffset or 0
    local yOff = db.glowYOffset or 0
    local gtype = db.glowType or "pixel"
    local thickness = (db.glowInsideBorder and borderDB.showBorder)
        and (borderDB.borderSize or 1)
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

local function ComputeIconTexCoord(db)
    local z = db.zoom or 0.1
    local w = db.width or 36
    local h = (db.keepAspectRatio ~= false) and w or (db.height or 36)
    if db.iconLockAspectRatio ~= false and w > 0 and h > 0 then
        local base = 1 - z * 2
        local xCrop, yCrop = base, base
        local ratio = w / h
        if ratio > 1 then yCrop = xCrop / ratio
        elseif ratio < 1 then xCrop = yCrop * ratio end
        local left = (1 - xCrop) / 2
        local top  = (1 - yCrop) / 2
        return left, 1 - left, top, 1 - top
    end
    return z, 1 - z, z, 1 - z
end

local function StyleYoinkedIcon(childFrame, db, gtext)
    if not childFrame._tuiOrigStyle then
        local orig = {}
        if childFrame.Icon and childFrame.Icon.GetTexCoord then
            orig.iconTexCoords = { childFrame.Icon:GetTexCoord() }
            if childFrame.Icon.GetScale then orig.iconScale = childFrame.Icon:GetScale() end
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

                    if r.GetNumPoints and r:GetNumPoints() > 0 then
                        local pt, rel, rp, px, py = r:GetPoint()
                        if pt and not (issecretvalue(pt) or issecretvalue(rp) or issecretvalue(px) or issecretvalue(py)) then
                            orig.cdPoint = { p = pt, rel = rel, rp = rp, x = px or 0, y = py or 0 }
                        end
                    end
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
            if app.GetNumPoints and app:GetNumPoints() > 0 then
                local pt, rel, rp, px, py = app:GetPoint()
                if pt and not (issecretvalue(pt) or issecretvalue(rp) or issecretvalue(px) or issecretvalue(py)) then
                    orig.appPoint = { p = pt, rel = rel, rp = rp, x = px or 0, y = py or 0 }
                end
            end
        end
        childFrame._tuiOrigStyle = orig
    end

    if childFrame.Icon then
        childFrame.Icon:SetScale(1)
        local l, r, t, b = ComputeIconTexCoord(db)
        childFrame._tuiTexCoord = { l, r, t, b }
        childFrame.Icon:SetTexCoord(l, r, t, b)
    end
    if childFrame.Cooldown then
        childFrame.Cooldown:SetDrawSwipe(db.showCooldown)
        childFrame.Cooldown:SetDrawEdge(false)
        if ns.CDMText and ns.CDMText.ReleaseFromElvUICooldown then
            ns.CDMText.ReleaseFromElvUICooldown(childFrame.Cooldown)
        end

        local dFont, dSize, dOut, dColor, dPt, dX, dY, dShow
        if gtext then
            dFont, dSize, dOut = gtext.cooldownFont, gtext.cooldownFontSize, gtext.cooldownFontOutline
            dColor, dPt, dX, dY = gtext.cooldownColor, gtext.cooldownPoint, gtext.cooldownXOffset, gtext.cooldownYOffset
            dShow = gtext.showCooldown ~= false
        else
            dFont, dSize, dOut = db.durationFont, db.durationFontSize, db.durationFontOutline
            dColor, dPt, dX, dY = db.durationColor, db.durationPoint, db.durationXOffset, db.durationYOffset
            dShow = db.showDuration ~= false
        end
        if dShow then
            local font = LSM:Fetch('font', dFont or 'Expressway')
            local pt = dPt or 'CENTER'
            for i = 1, childFrame.Cooldown:GetNumRegions() do
                local r = select(i, childFrame.Cooldown:GetRegions())
                if r and r.GetObjectType and r:GetObjectType() == 'FontString' then
                    E:SetFont(r, font, dSize or 14, dOut or 'OUTLINE')
                    if dColor then r:SetTextColor(dColor.r, dColor.g, dColor.b) end
                    r:ClearAllPoints()
                    r:SetPoint(pt, childFrame.Cooldown, pt, dX or 0, dY or 0)
                    r:SetAlpha(1)
                end
            end
        else
            for i = 1, childFrame.Cooldown:GetNumRegions() do
                local r = select(i, childFrame.Cooldown:GetRegions())
                if r and r.GetObjectType and r:GetObjectType() == 'FontString' then r:SetAlpha(0) end
            end
        end
    end
    local app = childFrame.Applications and childFrame.Applications.Applications or childFrame.Applications
    if app then
        local sFont, sSize, sOut, sColor, sPt, sX, sY, sShow
        if gtext then
            sFont, sSize, sOut = gtext.stacksFont, gtext.stacksFontSize, gtext.stacksFontOutline
            sColor, sPt, sX, sY = gtext.stacksColor, gtext.stacksPoint, gtext.stacksXOffset, gtext.stacksYOffset
            sShow = gtext.showStacks ~= false
        else
            sFont, sSize, sOut = db.stackFont, db.stackFontSize, db.stackFontOutline
            sColor, sPt, sX, sY = db.stackColor, db.stackPoint, db.stackXOffset, db.stackYOffset
            sShow = db.showStacks
        end
        E:SetFont(app, LSM:Fetch('font', sFont or 'Expressway'), sSize or 14, sOut or 'OUTLINE')
        if sColor then app:SetTextColor(sColor.r, sColor.g, sColor.b) end
        local pt = sPt or 'BOTTOMRIGHT'
        app:ClearAllPoints()
        app:SetPoint(pt, childFrame, pt, sX or 0, sY or 0)
        app:SetAlpha(sShow and 1 or 0)
    end
end

local function ReleaseIcon(iconKey)
    local state = iconGroupState[iconKey]
    if state then
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

    local moverName = "TUI_SpecialIconMover_" .. iconKey
    if E and E.CreatedMovers and E.CreatedMovers[moverName] and E.DisableMover then
        E:DisableMover(moverName)
    end
end

local function ReapplyHeldSize(child)
    if not yoinkedBars[child] then return end
    local tw, th = child._tuiSpecialW, child._tuiSpecialH
    if not tw then return end
    local cw, ch = child:GetSize()
    if math.abs((cw or 0) - tw) > 0.5 or math.abs((ch or 0) - th) > 0.5 then
        UIParent.SetSize(child, tw, th)
    end
end

local function ReapplyHeldTex(child)
    local icon = child.Icon
    if not icon or icon._tuiTexing or not yoinkedBars[child] then return end
    local tc = child._tuiTexCoord
    if not tc then return end
    if math.abs(((select(1, icon:GetTexCoord())) or 0) - tc[1]) > 0.001 then
        icon._tuiTexing = true
        icon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        icon._tuiTexing = nil
    end
end

local function ReapplyHeldDesat(child, desaturated)
    local icon = child.Icon
    if not desaturated or not icon or icon._tuiDesatGuard or not yoinkedBars[child] then return end
    icon._tuiDesatGuard = true
    icon:SetDesaturated(false)
    icon._tuiDesatGuard = nil
end

local function ReapplyHeldIcon(child)
    if not yoinkedBars[child] then return end
    local key = child._tuiSpecialIconKey
    local wrapper = key and _G['TUI_SpecialIcon_' .. key]
    if not wrapper then return end

    UIParent.SetFrameStrata(child, wrapper:GetFrameStrata())
    UIParent.SetFrameLevel(child, wrapper:GetFrameLevel() + 1)
    UIParent.ClearAllPoints(child)
    UIParent.SetPoint(child, 'CENTER', wrapper, 'CENTER', 0, 0)
    if child._tuiSpecialW then UIParent.SetSize(child, child._tuiSpecialW, child._tuiSpecialH) end
    ReapplyHeldTex(child)
end

local UpdateIconSlot
UpdateIconSlot = function(iconKey)
    local db = SB.GetIconDB(iconKey)
    if not db.enabled or not db.spellID then
        ReleaseIcon(iconKey)
        if db.customGroup and ns.CustomGroups and ns.CustomGroups.QueueLayout then
            ns.CustomGroups.QueueLayout()
        end
        return
    end

    local wrapper   = GetOrCreateIconFrame(iconKey)
    local Pixel     = ns.Pixel
    local moverName = "TUI_SpecialIconMover_" .. iconKey

    local group = db.customGroup and ns.CustomGroups and ns.CustomGroups.GroupByID(db.customGroup)
    if group and not group.enabled then group = nil end
    local borderDB = db
    if group and not db.showBorder then borderDB = group end
    local gtext = (group and not db.overrideGroupText) and group.text or nil

    local w, h
    if group then
        local iw = group.iconWidth or group.iconSize or 36
        w = iw
        h = (group.squareIcon ~= false) and iw or (group.iconHeight or iw)
        Pixel.SetSize(wrapper, w, h)
        if E and E.CreatedMovers and E.CreatedMovers[moverName] and E.DisableMover then
            E:DisableMover(moverName)
        end
    else
        local anchorName  = (db.anchorMode ~= 'CUSTOM') and db.anchorMode or db.anchorFrame
        local anchorFrame = SB.ResolveAnchorTarget(anchorName)

        w = db.width  or 36
        h = db.keepAspectRatio ~= false and w or (db.height or 36)
        Pixel.SetSize(wrapper, w, h)

        wrapper:ClearAllPoints()
        if anchorFrame then
            Pixel.SetPoint(wrapper, db.anchorPoint or "CENTER", anchorFrame, db.anchorRelativePoint or "CENTER", db.anchorXOffset or 0, db.anchorYOffset or 0)
        else
            Pixel.SetPoint(wrapper, "CENTER", UIParent, "CENTER", db.anchorXOffset or 0, db.anchorYOffset or 0)
        end

        local iconNum = iconKey:match("(%d+)$") or ""
        local label = "Special Icon " .. iconNum
        if anchorFrame and db.anchorMode and db.anchorMode ~= "UIParent" then
            label = label .. "\n|cFF888888(Anchored to: " .. (db.anchorMode or "?") .. ")|r"
        end
        EnsureIconMover(wrapper, iconKey, label)

        if E and E.DisabledMovers and E.DisabledMovers[moverName] and E.EnableMover then
            E:EnableMover(moverName)
        end

        local mover = _G[moverName]
        if mover and anchorFrame then
            local point = db.anchorPoint or "CENTER"
            local relPoint = db.anchorRelativePoint or "CENTER"
            local x, y = db.anchorXOffset or 0, db.anchorYOffset or 0
            local cp, crf, crp, cx, cy = mover:GetPoint()

            local same = cp == point and crp == relPoint
                and crf == anchorFrame
                and cx and math.abs(cx - x) < 0.5
                and cy and math.abs(cy - y) < 0.5
            if not same then
                mover:ClearAllPoints()
                mover:SetPoint(point, anchorFrame, relPoint, x, y)

                local anchorHasName = anchorFrame.GetName and anchorFrame:GetName()
                if E.SaveMoverPosition and anchorHasName then
                    E:SaveMoverPosition(moverName)
                end
            end
        end
    end

    local st = iconGroupState[iconKey]
    local held = st and st.childFrame

    if held and not InCombatLockdown() and not SB.SafeMatch(held, db.spellID, false) then
        ReturnFrame(held); held = nil
        if st then st.childFrame = nil end
    end
    local viewerFrame = FindIconBySpell(db.spellID, iconKey)

    if held and viewerFrame and viewerFrame ~= held and not held:IsShown() then
        ReturnFrame(held); held = nil
        if st then st.childFrame = nil end
    end
    local realFrame = held or viewerFrame
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

        if not realFrame._cdmOriginalStrata then
            realFrame._cdmOriginalStrata = realFrame:GetFrameStrata()
            realFrame._cdmOriginalLevel  = realFrame:GetFrameLevel()
        end

        realFrame._tuiSpecialW, realFrame._tuiSpecialH = w, h
        if not realFrame._tuiHooksInstalled then
            realFrame._tuiHooksInstalled = true

            hooksecurefunc(realFrame, 'SetSize',   ReapplyHeldSize)
            hooksecurefunc(realFrame, 'SetWidth',  ReapplyHeldSize)
            hooksecurefunc(realFrame, 'SetHeight', ReapplyHeldSize)
            local icon = realFrame.Icon
            if icon then
                hooksecurefunc(icon, 'SetTexCoord', function() ReapplyHeldTex(realFrame) end)
                hooksecurefunc(icon, 'SetTexture',  function() ReapplyHeldTex(realFrame) end)
                if icon.SetDesaturated then
                    hooksecurefunc(icon, 'SetDesaturated', function(_, d) ReapplyHeldDesat(realFrame, d) end)
                end
            end

            realFrame:HookScript('OnShow', ReapplyHeldIcon)
        end

        local newlyYoinked = not realFrame._tuiYoinkActive
        realFrame._tuiYoinkActive = true
        yoinkedBars[realFrame] = true
        UIParent.SetFrameStrata(realFrame, wrapper:GetFrameStrata())
        UIParent.SetFrameLevel(realFrame, wrapper:GetFrameLevel() + 1)
        UIParent.ClearAllPoints(realFrame)
        UIParent.SetPoint(realFrame, 'CENTER', wrapper, 'CENTER', 0, 0)
        UIParent.SetSize(realFrame, w, h)

        wrapper.fallback:Hide()
        wrapper.fallbackBorder:Hide()
        StyleYoinkedIcon(realFrame, db, gtext)
        ApplyIconBorder(wrapper, borderDB)
        ApplyIconGlow(wrapper, db, borderDB)
        wrapper:Show()

        if newlyYoinked and C_Timer and C_Timer.After then
            if ns.CDMIcons and ns.CDMIcons.RefreshAll then C_Timer.After(0, ns.CDMIcons.RefreshAll) end
            C_Timer.After(0.1, function()
                local st = iconGroupState[iconKey]
                if st and st.wrapper then st.wrapper._tuiGlowSig = nil end
                UpdateIconSlot(iconKey)
            end)
        end
    else

        local state = iconGroupState[iconKey]
        if not state then state = {}; iconGroupState[iconKey] = state end
        state.wrapper    = wrapper

        if db.desaturateWhenInactive then
            local spellInfo = SB.GetRawSpellList()[db.spellID]
            if spellInfo then wrapper.fallback:SetTexture(spellInfo.icon) end
            wrapper.fallback:SetTexCoord(ComputeIconTexCoord(db))
            wrapper.fallback:SetDesaturated(true)
            wrapper.fallback:Show()
            wrapper.fallbackBorder:Show()
            ApplyIconBorder(wrapper, borderDB)
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

    if group and ns.CustomGroups and ns.CustomGroups.QueueLayout then
        local shownNow = wrapper:IsShown()
        if wrapper._tuiLaidShown ~= shownNow then
            wrapper._tuiLaidShown = shownNow
            ns.CustomGroups.QueueLayout()
        end
    end
end

SB.UpdateIconSlot = UpdateIconSlot
SB.ReleaseIcon    = ReleaseIcon