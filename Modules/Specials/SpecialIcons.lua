local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

ns.SpecialBars = ns.SpecialBars or {}
local SB = ns.SpecialBars
local iconGroupState = SB.iconGroupState

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
        if ns.AuraLane and ns.AuraLane.NoSnap then ns.AuraLane.NoSnap(wrapper.fallback) end
        wrapper.fallback:SetAllPoints()
        wrapper.fallbackBorder = CreateFrame('Frame', nil, wrapper, 'BackdropTemplate')
        wrapper.fallbackBorder:SetAllPoints()
        wrapper.fallbackBorder:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
        wrapper.fallbackBorder:SetBackdropColor(0,0,0,0)
        wrapper.fallbackBorder:SetBackdropBorderColor(0,0,0,1)
        wrapper.fallback:Hide()
        wrapper.fallbackBorder:Hide()
    end
    return wrapper
end

local function ApplyIconBorder(wrapper, db)
    local AL = ns.AuraLane
    local host = wrapper.tuiBorderHost
    if not db.showBorder or not (AL and AL.EdgeRing) then
        if host then host:Hide() end
        return
    end

    local size = db.borderSize or 1
    if db.glowBorderStroke and db.showGlow and AL.MapGlowStyle(db.glowType) == "pixel" then size = db.glowThickness or size end
    local inset = db.borderInset or 0
    local bc    = db.borderColor or { r=0, g=0, b=0, a=1 }

    if not host then
        host = CreateFrame('Frame', nil, wrapper)
        host:SetAllPoints(wrapper)
        host:SetFrameLevel(12)
        host.main = {}
        for i = 1, 4 do
            host.main[i] = host:CreateTexture(nil, 'OVERLAY')
        end
        wrapper.tuiBorderHost = host
    end
    host:Show()
    AL.EdgeRing(host, host.main, size, inset, bc)
end

local function ComputeIconTexCoord(db)
    local z = db.zoom or 0.1
    local w = db.width or 36
    local h = (db.keepAspectRatio ~= false) and w or (db.height or 36)

    if db.customGroup and ns.CustomGroups and ns.CustomGroups.GroupByID then
        local g = ns.CustomGroups.GroupByID(db.customGroup)
        if g then
            z = tonumber(g.iconZoom) or 0
            w = g.iconWidth or g.iconSize or 36
            h = (g.squareIcon ~= false) and w or (g.iconHeight or w)
        end
    end
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

SB.ComputeIconTexCoord = ComputeIconTexCoord

local function HideWrapperVisuals(wrapper)
    wrapper.fallback:Hide()
    wrapper.fallbackBorder:Hide()
    if wrapper.tuiBorderHost then wrapper.tuiBorderHost:Hide() end
end

local function ReleaseIcon(iconKey)
    local wrapper = _G["TUI_SpecialIcon_" .. iconKey]
    if wrapper then
        if ns.SpecialAura then ns.SpecialAura.Detach(wrapper, iconKey) end
        HideWrapperVisuals(wrapper)
        wrapper:Hide()
    end
    iconGroupState[iconKey] = nil

    local moverName = "TUI_SpecialIconMover_" .. iconKey
    if E and E.CreatedMovers and E.CreatedMovers[moverName] and E.DisableMover then
        E:DisableMover(moverName)
    end
end

local function UpdateIconSlot(iconKey)
    local db = SB.GetIconDB(iconKey)
    if not db or not db.enabled or not db.spellID then
        ReleaseIcon(iconKey)
        if db and db.customGroup and ns.CustomGroups and ns.CustomGroups.QueueLayout then
            ns.CustomGroups.QueueLayout()
        end
        return
    end

    local group = db.customGroup and ns.CustomGroups and ns.CustomGroups.GroupByID(db.customGroup)
    if group and not group.enabled then group = nil end

    if group then
        ReleaseIcon(iconKey)
        if ns.CustomGroups and ns.CustomGroups.QueueLayout then
            ns.CustomGroups.QueueLayout()
        end
        return
    end

    local wrapper   = GetOrCreateIconFrame(iconKey)
    local Pixel     = ns.Pixel
    local moverName = "TUI_SpecialIconMover_" .. iconKey

    local anchorName  = (db.anchorMode ~= 'CUSTOM') and db.anchorMode or db.anchorFrame
    local anchorFrame = SB.ResolveAnchorTarget(anchorName)

    local w = db.width  or 36
    local h = db.keepAspectRatio ~= false and w or (db.height or 36)
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
            Pixel.SetPoint(mover, point, anchorFrame, relPoint, x, y)

            local anchorHasName = anchorFrame.GetName and anchorFrame:GetName()
            if E.SaveMoverPosition and anchorHasName then
                E:SaveMoverPosition(moverName)
            end
        end
    end

    local state = iconGroupState[iconKey]
    if not state then state = {}; iconGroupState[iconKey] = state end
    state.wrapper = wrapper

    local test = ns.CustomGroups and ns.CustomGroups.testMode
    if test or db.desaturateWhenInactive then
        local raw = SB.GetRawSpellList and SB.GetRawSpellList()[db.spellID]
        local tex = raw and raw.icon
        if not tex then
            local si = SB.GetCachedSpellInfo and SB.GetCachedSpellInfo(db.spellID)
            tex = si and si.iconID
        end
        if tex then wrapper.fallback:SetTexture(tex) end
        wrapper.fallback:SetTexCoord(ComputeIconTexCoord(db))
        wrapper.fallback:SetDesaturated(not test)
        wrapper.fallback:Show()
        wrapper.fallbackBorder:Show()
        ApplyIconBorder(wrapper, db)
    else
        HideWrapperVisuals(wrapper)
    end

    local TM = ns.Timers
    if db.totemTimer and db.spellID and TM and TM.RegisterTotemSpell then
        TM.RegisterTotemSpell(db.spellID)
        if not SB._totemCB and TM.AddTotemCallback then
            SB._totemCB = true
            TM.AddTotemCallback(function()
                local T = ns.TUI
                if T and T.UpdateSpecialBars then T:UpdateSpecialBars() end
            end)
        end
        local start, dur = TM.GetTotemState(db.spellID)
        if start then
            local raw = SB.GetRawSpellList and SB.GetRawSpellList()[db.spellID]
            local ttex = (raw and raw.icon) or (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(db.spellID))
            if ttex then wrapper.fallback:SetTexture(ttex) end
            wrapper.fallback:SetTexCoord(ComputeIconTexCoord(db))
            wrapper.fallback:SetDesaturated(false)
            wrapper.fallback:Show()
            wrapper.fallbackBorder:Show()
            ApplyIconBorder(wrapper, db)
            if not wrapper.totemCD then
                wrapper.totemCD = CreateFrame("Cooldown", nil, wrapper, "CooldownFrameTemplate")
                wrapper.totemCD:SetAllPoints(wrapper)
                wrapper.totemCD:SetHideCountdownNumbers(not (db.showDuration ~= false))
            end
            wrapper.totemCD:SetCooldown(start, dur)
            local fs = SB.CooldownText and SB.CooldownText(wrapper.totemCD)
            if fs then
                local LSM = ns.LSM
                E:SetFont(fs, LSM and LSM:Fetch("font", db.durationFont or "Expressway"),
                    db.durationFontSize or 14, db.durationFontOutline or "OUTLINE")
                local dc = db.durationColor
                if dc then fs:SetTextColor(dc.r or 1, dc.g or 1, dc.b or 1) end
                fs:ClearAllPoints()
                fs:SetPoint(db.durationPoint or "CENTER", wrapper.totemCD, db.durationPoint or "CENTER",
                    db.durationXOffset or 0, db.durationYOffset or 0)
            end
            wrapper.totemCD:Show()
        elseif wrapper.totemCD then
            wrapper.totemCD:Clear()
            wrapper.totemCD:Hide()
        end
    elseif wrapper.totemCD then
        wrapper.totemCD:Hide()
    end

    local AL = ns.AuraLane
    if AL and AL.GlowOptsFor then
        local fx = (test and db.showGlow) and AL.GlowOptsFor(nil, { iconDB = db }) or nil
        if fx or wrapper._tuiTestFXR then
            wrapper._tuiTestFXR = wrapper._tuiTestFXR or {}
            fx = fx or {}
            fx.w, fx.h = w, h
            fx.anchor = wrapper.fallback
            AL.ApplyButtonFX(wrapper, wrapper._tuiTestFXR, fx)
        end
    end
    wrapper:Show()

    if ns.SpecialAura then ns.SpecialAura.AttachIcon(wrapper, iconKey, db, w, h) end
end

SB.UpdateIconSlot = UpdateIconSlot
SB.ReleaseIcon    = ReleaseIcon
