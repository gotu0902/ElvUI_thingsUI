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

local function ComputeIconTexCoord(db)
    local z = db.zoom or 0.1
    local w = db.width or 36
    local h = (db.keepAspectRatio ~= false) and w or (db.height or 36)
    -- inside a custom group the neighbours' crop wins, not the icon's own
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
    if wrapper.tuiBorder      then wrapper.tuiBorder:Hide()      end
    if wrapper.tuiBorderInner then wrapper.tuiBorderInner:Hide() end
    if wrapper.tuiBorderOuter then wrapper.tuiBorderOuter:Hide() end
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
            mover:SetPoint(point, anchorFrame, relPoint, x, y)

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
    wrapper:Show()

    if ns.SpecialAura then ns.SpecialAura.AttachIcon(wrapper, iconKey, db, w, h) end
end

SB.UpdateIconSlot = UpdateIconSlot
SB.ReleaseIcon    = ReleaseIcon
