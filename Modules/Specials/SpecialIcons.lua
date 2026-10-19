local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

ns.SpecialBars = ns.SpecialBars or {}
local SB = ns.SpecialBars
local iconGroupState = SB.iconGroupState

-- icons shown in a CDM row: CDMIcons folds them into that viewer's grid,
-- ordered by layoutIndex between Blizzard's own (1..N)
local CDM_VIEWER = { essential = "EssentialCooldownViewer", utility = "UtilityCooldownViewer" }
local cdmRowOf = {}

local function RowIconSize(row)
    local proxy = ns.CDMIcons and ns.CDMIcons.ProxyForName and ns.CDMIcons.ProxyForName(CDM_VIEWER[row])
    local vdb = E.db.thingsUI.cdmIcons and E.db.thingsUI.cdmIcons[row]
    local w = (proxy and proxy._tuiLastIconW) or (vdb and vdb.overrideSize and vdb.iconWidth) or 36
    local h = (proxy and proxy._tuiLastIconH)
        or (vdb and vdb.overrideSize and (vdb.lockAspect and w or vdb.iconHeight)) or w
    return w, h
end

-- an icon in a CDM row takes the row's text unless it overrides it, like a grouped one
function SB.IconTextDB(db)
    local row = db and db.cdmRow and not db.overrideGroupText and db.cdmRow
    local cdm = row and E.db.thingsUI.cdmIcons
    local vt = cdm and cdm[row] and cdm[row].text
    if not vt then return db end
    return setmetatable({
        showDuration = vt.showCooldown ~= false,
        durationFont = vt.cooldownFont, durationFontSize = vt.cooldownFontSize,
        durationFontOutline = vt.cooldownFontOutline, durationColor = vt.cooldownColor,
        durationPoint = vt.cooldownPoint, durationXOffset = vt.cooldownXOffset,
        durationYOffset = vt.cooldownYOffset,
        showStacks = vt.showStacks ~= false,
        stackFont = vt.stacksFont, stackFontSize = vt.stacksFontSize,
        stackFontOutline = vt.stacksFontOutline, stackColor = vt.stacksColor,
        stackPoint = vt.stacksPoint, stackXOffset = vt.stacksXOffset, stackYOffset = vt.stacksYOffset,
    }, { __index = db })
end

function SB.GetInlineIconsFor(viewer)
    local name = viewer and viewer:GetName()
    local out
    for key, row in pairs(cdmRowOf) do
        local wrapper = CDM_VIEWER[row] == name and _G["TUI_SpecialIcon_" .. key]
        if wrapper and wrapper:IsShown() then
            out = out or {}
            out[#out + 1] = wrapper
        end
    end
    return out
end

-- every aura a special icon or bar shows: the CDM buff copy is a duplicate
function SB.AuraSet()
    local set = {}
    local SA = ns.SpecialAura
    local function add(db)
        if not (db and db.enabled and db.spellID) or db.totemTimer then return end
        set[db.spellID] = true
        local ex = SA and SA.ExpandSpellIDs and SA.ExpandSpellIDs(db.spellID)
        for id in pairs(ex or {}) do set[id] = true end
    end
    for i = 1, (SB.GetIconCount and SB.GetIconCount() or 0) do add(SB.GetIconDB("icon" .. i)) end
    for i = 1, (SB.GetBarCount and SB.GetBarCount() or 0) do add(SB.GetBarDB("bar" .. i)) end
    return set
end

local lastAuraSig
function SB.NotifyAuraSet()
    local keys = {}
    for id in pairs(SB.AuraSet()) do keys[#keys + 1] = id end
    table.sort(keys)
    local sig = table.concat(keys, ",")
    if sig == lastAuraSig then return end
    lastAuraSig = sig
    if ns.CDMIcons and ns.CDMIcons.QueuePassiveRebuild then ns.CDMIcons.QueuePassiveRebuild() end
end

local lastRowSig, rowCheckQueued = nil, false
local function RowCheck()
    rowCheckQueued = false
    local keys = {}
    for key, row in pairs(cdmRowOf) do
        local w = _G["TUI_SpecialIcon_" .. key]
        keys[#keys + 1] = key .. ":" .. row .. ":" .. tostring(w and w.layoutIndex) .. ":" .. tostring(w and w:IsShown())
    end
    table.sort(keys)
    local sig = table.concat(keys, ",")
    if sig == lastRowSig then return end
    lastRowSig = sig
    if ns.CDMIcons and ns.CDMIcons.QueuePassiveRebuild then ns.CDMIcons.QueuePassiveRebuild() end
    if ns.CDMIcons and ns.CDMIcons.RefreshAll then ns.CDMIcons.RefreshAll() end
end
local function QueueRowCheck()
    if rowCheckQueued then return end
    rowCheckQueued = true
    C_Timer.After(0, RowCheck)
end

-- visibility rules for standalone and row icons; a grouped icon follows its group's
local function VisibleNow(db)
    return (ns.CustomGroups and ns.CustomGroups.testMode) or ns.Visibility.Shown(db.visibility)
end

function SB.RefreshIconVisibility()
    local changed = false
    for i = 1, (SB.GetIconCount and SB.GetIconCount() or 0) do
        local key = "icon" .. i
        local db = SB.GetIconDB(key)
        local wrapper = _G["TUI_SpecialIcon_" .. key]
        local g = db and db.customGroup and ns.CustomGroups and ns.CustomGroups.GroupByID
            and ns.CustomGroups.GroupByID(db.customGroup)
        if wrapper and db and db.enabled and db.spellID and not (g and g.enabled) then
            local want = VisibleNow(db) and true or false
            if wrapper:IsShown() ~= want then wrapper:SetShown(want); changed = true end
        end
    end
    if changed then QueueRowCheck() end
end
ns.Visibility.OnChange(function() SB.RefreshIconVisibility() end)

local _iconMoverCreated = {}
local function EnsureIconMover(wrapper, iconKey, displayName)
    if _iconMoverCreated[iconKey] then return end
    local ms = ns.MoverSync
    if not (ms and ms.CreateManaged) then return end
    ms.CreateManaged(wrapper, "TUI_SpecialIconMover_" .. iconKey, displayName or ("Aura Icon " .. iconKey), {
        configString  = "thingsUI,modulesTab,specialIcons,iconsTab," .. iconKey .. "Group,anchorGroup",
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
        onNudge = function(dx, dy)
            ms.ShiftOffsets(SB.GetIconDB(iconKey), dx, dy)
            TUI:QueueSpecialBarsUpdate()
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
    local inset = (db.borderInset or 0) - size
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

    if db.cdmRow and CDM_VIEWER[db.cdmRow] then
        local vdb = E.db.thingsUI.cdmIcons and E.db.thingsUI.cdmIcons[db.cdmRow]
        z = tonumber(vdb and vdb.iconZoom) or 0
        w, h = RowIconSize(db.cdmRow)
    elseif db.customGroup and ns.CustomGroups and ns.CustomGroups.GroupByID then
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

-- options preview: sample duration and stacks in the icon's real text style (row text unless overridden)
local function PreviewText(wrapper, db, test)
    local p = wrapper._tuiPrevText
    if not test then
        if p then p.layer:Hide() end
        return
    end
    if not p then
        p = { layer = CreateFrame("Frame", nil, wrapper) }
        p.layer:SetAllPoints(wrapper)
        p.dur = p.layer:CreateFontString(nil, "OVERLAY")
        p.count = p.layer:CreateFontString(nil, "OVERLAY")
        wrapper._tuiPrevText = p
    end
    p.layer:SetFrameLevel(wrapper:GetFrameLevel() + 10)
    p.layer:Show()
    local tx = SB.IconTextDB(db)
    local function stamp(fs, shown, font, size, outline, color, point, x, y, text)
        if not shown then fs:Hide() return end
        E:SetFont(fs, ns.LSM:Fetch("font", font or "Expressway"), size or 14, outline or "OUTLINE")
        ns.TextColor(fs, color)
        fs:ClearAllPoints()
        fs:SetPoint(point, wrapper, point, x or 0, y or 0)
        fs:SetText(text)
        fs:Show()
    end
    stamp(p.dur, tx.showDuration ~= false, tx.durationFont, tx.durationFontSize, tx.durationFontOutline,
        tx.durationColor, tx.durationPoint or "CENTER", tx.durationXOffset, tx.durationYOffset, "12")
    stamp(p.count, tx.showStacks, tx.stackFont, tx.stackFontSize, tx.stackFontOutline,
        tx.stackColor, tx.stackPoint or "BOTTOMRIGHT", tx.stackXOffset, tx.stackYOffset, "3")
end

local function ReleaseIcon(iconKey)
    local wrapper = _G["TUI_SpecialIcon_" .. iconKey]
    if wrapper then
        if ns.SpecialAura then ns.SpecialAura.Detach(wrapper, iconKey) end
        HideWrapperVisuals(wrapper)
        wrapper:Hide()
    end
    iconGroupState[iconKey] = nil
    if cdmRowOf[iconKey] then
        cdmRowOf[iconKey] = nil
        QueueRowCheck()
    end

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
    local row = db.cdmRow and CDM_VIEWER[db.cdmRow] and db.cdmRow

    local anchorName  = (db.anchorMode ~= 'CUSTOM') and db.anchorMode or db.anchorFrame
    local anchorFrame = not row and SB.ResolveAnchorTarget(anchorName)

    local w, h
    if row then
        -- the viewer's layout places it by its center; Blizzard's skinned icons
        -- draw their 1px border outside the cell, ours draws inside: grow by it
        local pad = ns.CDM_SPACING_INSET or 2
        w, h = RowIconSize(row)
        w, h = w + pad, h + pad
        Pixel.SetSize(wrapper, w, h)
        wrapper._tuiOwnSize = true
        wrapper.layoutIndex = (db.cdmIndex or 30) - 0.5
        cdmRowOf[iconKey] = row
        QueueRowCheck()
        if E and E.CreatedMovers and E.CreatedMovers[moverName] and E.DisableMover then
            E:DisableMover(moverName)
        end
    else
        if cdmRowOf[iconKey] then
            cdmRowOf[iconKey] = nil
            wrapper.layoutIndex = nil
            QueueRowCheck()
        end
        wrapper._tuiOwnSize = nil
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
        local label = "Aura Icon " .. iconNum
        if anchorFrame and db.anchorMode and db.anchorMode ~= "UIParent" then
            label = label .. "\n|cFF888888(Anchored to: " .. (db.anchorMode or "?") .. ")|r"
        end
        EnsureIconMover(wrapper, iconKey, label)

        if E and E.DisabledMovers and E.DisabledMovers[moverName] and E.EnableMover then
            E:EnableMover(moverName)
        end
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
    -- a row keeps its cell: idle shows the spell greyed out, like a cooldown
    if test or db.desaturateWhenInactive or row then
        local raw = SB.GetRawSpellList and SB.GetRawSpellList()[db.spellID]
        local tex = db.customIcon or (raw and raw.icon)
        if not tex then
            local si = SB.GetCachedSpellInfo and SB.GetCachedSpellInfo(db.spellID)
            tex = si and si.iconID
        end
        if tex then wrapper.fallback:SetTexture(tex) end
        wrapper.fallback:SetTexCoord(ComputeIconTexCoord(db))
        wrapper.fallback:SetDesaturated(not test)
        wrapper.fallback:Show()
        wrapper.fallbackBorder:SetShown(not db.showBorder)
        ApplyIconBorder(wrapper, db)
    else
        HideWrapperVisuals(wrapper)
    end
    PreviewText(wrapper, db, test)

    local TM = ns.Timers
    if db.totemTimer and db.spellID and TM and TM.RegisterTotemSpell then
        TM.RegisterTotemSpell(db.spellID)
        if not SB._totemCB and TM.AddTotemCallback then
            SB._totemCB = true
            TM.AddTotemCallback(function() if SB.OnTotemChange then SB.OnTotemChange() end end)
        end
        local start, dur = TM.GetTotemState(db.spellID)
        if start then
            local raw = SB.GetRawSpellList and SB.GetRawSpellList()[db.spellID]
            local ttex = db.customIcon or (raw and raw.icon) or (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(db.spellID))
            if ttex then wrapper.fallback:SetTexture(ttex) end
            wrapper.fallback:SetTexCoord(ComputeIconTexCoord(db))
            wrapper.fallback:SetDesaturated(false)
            wrapper.fallback:Show()
            wrapper.fallbackBorder:SetShown(not db.showBorder)
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
                local tx = SB.IconTextDB(db)
                E:SetFont(fs, LSM and LSM:Fetch("font", tx.durationFont or "Expressway"),
                    tx.durationFontSize or 14, tx.durationFontOutline or "OUTLINE")
                local dc = tx.durationColor
                if dc then fs:SetTextColor(dc.r or 1, dc.g or 1, dc.b or 1) end
                fs:ClearAllPoints()
                fs:SetPoint(tx.durationPoint or "CENTER", wrapper.totemCD, tx.durationPoint or "CENTER",
                    tx.durationXOffset or 0, tx.durationYOffset or 0)
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
    wrapper:SetShown(VisibleNow(db) and true or false)

    if ns.SpecialAura then ns.SpecialAura.AttachIcon(wrapper, iconKey, db, w, h) end
end

SB.UpdateIconSlot = UpdateIconSlot
SB.ReleaseIcon    = ReleaseIcon
