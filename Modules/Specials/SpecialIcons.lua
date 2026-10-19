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
-- icons on top of a cooldown: the spell they sit on, and the row of the frame they cover
local overOf = {}
-- Only When Missing icons (standalone or in a row): shown while their aura is down
local missingOf = {}
local missingUp = {}
local lastGroupedSig
local overRow = setmetatable({}, { __mode = "k" })

local function AuraIDsFor(db)
    local SA = ns.SpecialAura
    return (SA and SA.ExpandSpellIDs and SA.ExpandSpellIDs(db.spellID)) or { [db.spellID] = true }
end

local function RowOf(db)
    if db.cdmRow and CDM_VIEWER[db.cdmRow] then return db.cdmRow end
    return overRow[db]
end

-- a CDM cell is its art plus ElvUI's 1px ring outside; our border's outside part takes that room
local function RowPad(db)
    local pad = ns.CDM_SPACING_INSET or 2
    if not db.showBorder then return pad end
    local bs = db.borderSize or 1
    local AL = ns.AuraLane
    if db.glowBorderStroke and db.showGlow and AL and AL.MapGlowStyle(db.glowType) == "pixel" then
        bs = db.glowThickness or bs
    end
    -- a stroke adds a line outside the border
    return pad - 2 * math.max(0, bs - (db.borderInset or 0) + (db.borderStroke and 1 or 0))
end

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
    local row = db and not db.overrideGroupText and RowOf(db)
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
        -- Only When Missing icons follow RefreshMissing
        if wrapper and db and db.enabled and db.spellID and not (g and g.enabled) and not db.showMissing then
            local want = (VisibleNow(db) and (not overOf[key] or wrapper._overChild)) and true or false
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
    wrapper:SetFrameLevel((db and db.frameLevel) or 10)
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
    AL.StrokeRing(host, host, size, inset, db.borderStroke)
end

local function ComputeIconTexCoord(db)
    local z = db.zoom or 0.1
    local w = db.width or 36
    local h = (db.keepAspectRatio ~= false) and w or (db.height or 36)

    local row = RowOf(db)
    if row then
        local vdb = E.db.thingsUI.cdmIcons and E.db.thingsUI.cdmIcons[row]
        z = tonumber(vdb and vdb.iconZoom) or 0
        w, h = RowIconSize(row)
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
    missingOf[iconKey] = nil
    if overOf[iconKey] then
        overOf[iconKey] = nil
        if wrapper then
            wrapper._overChild = nil
            if wrapper.overCD then wrapper.overCD:Clear(); wrapper.overCD:Hide() end
        end
        SB.WatchOverSpells()
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
    local over = not row and db.overSpell or nil

    local anchorName  = (db.anchorMode ~= 'CUSTOM') and db.anchorMode or db.anchorFrame
    local anchorFrame = not row and not over and SB.ResolveAnchorTarget(anchorName)

    local w, h
    if row then
        -- the viewer's layout places it by its center; Blizzard's skinned icons
        -- draw their 1px border outside the cell, ours draws inside: grow by it
        local pad = RowPad(db)
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
    elseif over then
        if cdmRowOf[iconKey] then
            cdmRowOf[iconKey] = nil
            wrapper.layoutIndex = nil
            QueueRowCheck()
        end
        wrapper._tuiOwnSize = nil
        if overOf[iconKey] ~= over then
            overOf[iconKey] = over
            SB.WatchOverSpells()
        end
        w, h = SB.PlaceOver(iconKey, wrapper, db)
        if E and E.CreatedMovers and E.CreatedMovers[moverName] and E.DisableMover then
            E:DisableMover(moverName)
        end
    else
        if cdmRowOf[iconKey] then
            cdmRowOf[iconKey] = nil
            wrapper.layoutIndex = nil
            QueueRowCheck()
        end
        if overOf[iconKey] then
            overOf[iconKey] = nil
            wrapper._overChild = nil
            if wrapper.overCD then wrapper.overCD:Hide() end
            SB.WatchOverSpells()
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
    local missing = db.showMissing and not over or nil
    missingOf[iconKey] = missing and db.spellID or nil
    -- a row keeps its cell: idle shows the spell greyed out, like a cooldown; on top of
    -- a cooldown the cooldown itself is what shows while idle
    if test or missing or ((db.desaturateWhenInactive or row) and not over) then
        local raw = SB.GetRawSpellList and SB.GetRawSpellList()[db.spellID]
        local tex = db.customIcon or (raw and raw.icon)
        if not tex then
            local si = SB.GetCachedSpellInfo and SB.GetCachedSpellInfo(db.spellID)
            tex = si and si.iconID
        end
        if tex then wrapper.fallback:SetTexture(tex) end
        wrapper.fallback:SetTexCoord(ComputeIconTexCoord(db))
        wrapper.fallback:SetDesaturated((not test) and ((not missing) or (db.missingDesat and true or false)))
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
    if missing then
        -- no aura engine here: the CDM says when it's up
        if ns.SpecialAura then ns.SpecialAura.Detach(wrapper, iconKey) end
        wrapper:SetShown((VisibleNow(db) and (test or not SB.MissingUp(db))) and true or false)
        SB.WatchOverSpells()
        return
    end
    wrapper:SetShown((VisibleNow(db) and (not over or wrapper._overChild or test)) and true or false)
    if over then SB.UpdateOverCD(iconKey) end

    if ns.SpecialAura then ns.SpecialAura.AttachIcon(wrapper, iconKey, db, w, h) end
end

-- ------------------------------------------------------- only when missing

local AuraIDs = AuraIDsFor

-- out of combat every aura is plain: for those the CDM doesn't track
local function PlainUp(db, ids)
    local kind = db.auraKind
    if kind ~= "HARMFUL" then
        for id in pairs(ids) do
            if C_UnitAuras.GetPlayerAuraBySpellID(id) then return true end
        end
    end
    if kind ~= "HELPFUL" and UnitExists("target") then
        for i = 1, 40 do
            local a = C_UnitAuras.GetAuraDataByIndex("target", i, "HARMFUL|PLAYER")
            if not a then break end
            if ids[a.spellId] then return true end
        end
    end
    return false
end

-- whether an Only When Missing icon's aura is up; in combat an untracked one keeps its last answer
function SB.MissingUp(db)
    local ids = AuraIDs(db)
    local up = ns.CDMIcons and ns.CDMIcons.AuraUp and ns.CDMIcons.AuraUp(ids)
    if up == nil then
        if InCombatLockdown() then return missingUp[db.spellID] or false end
        up = PlainUp(db, ids)
    end
    missingUp[db.spellID] = up
    return up
end

-- does the CDM follow this aura (it has to, to work in combat)
function SB.MissingTracked(db)
    return (ns.CDMIcons and ns.CDMIcons.AuraUp and ns.CDMIcons.AuraUp(AuraIDs(db))) ~= nil
end

function SB.RefreshMissing()
    local test = ns.CustomGroups and ns.CustomGroups.testMode
    local rows = false
    for key in pairs(missingOf) do
        local wrapper = _G["TUI_SpecialIcon_" .. key]
        local db = SB.GetIconDB(key)
        if wrapper and db and db.showMissing then
            local want = (VisibleNow(db) and (test or not SB.MissingUp(db))) and true or false
            if wrapper:IsShown() ~= want then
                wrapper:SetShown(want)
                if cdmRowOf[key] then rows = true end
            end
        end
    end
    if rows then QueueRowCheck() end
    -- grouped ones are slots in their group's grid: re-lay it when one flips
    local sig = {}
    for i = 1, (SB.GetIconCount and SB.GetIconCount() or 0) do
        local d = SB.GetIconDB("icon" .. i)
        if d and d.enabled and d.showMissing and d.customGroup and d.spellID then
            sig[#sig + 1] = d.spellID .. (SB.MissingUp(d) and "+" or "-")
                .. (ns.Visibility.Shown(d.visibility) and "v" or "h")
        end
    end
    local s = table.concat(sig, ",")
    local CG = ns.CustomGroups
    if s ~= lastGroupedSig and CG and CG.QueueLayout then
        lastGroupedSig = s
        CG.QueueLayout(false)
    end
end

function SB.AnyGroupedMissing()
    for i = 1, (SB.GetIconCount and SB.GetIconCount() or 0) do
        local d = SB.GetIconDB("icon" .. i)
        if d and d.enabled and d.showMissing and d.customGroup then return true end
    end
    return false
end

do
    local queued = false
    local function Flush() queued = false; SB.RefreshMissing() end
    local function Queue()
        if queued then return end
        queued = true
        C_Timer.After(0, Flush)
    end
    SB.QueueRefreshMissing = Queue
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterUnitEvent("UNIT_AURA", "player", "target")
    ev:SetScript("OnEvent", function(_, event)
        -- in combat the CDM's own signal drives it
        if event == "UNIT_AURA" and InCombatLockdown() then return end
        if next(missingOf) or SB.AnyGroupedMissing() then Queue() end
    end)
    if ns.CDMIcons and ns.CDMIcons.OnAuraState then
        ns.CDMIcons.OnAuraState(function() if next(missingOf) or SB.AnyGroupedMissing() then Queue() end end)
    end
    ns.Visibility.OnChange(function() if next(missingOf) or SB.AnyGroupedMissing() then Queue() end end)
end

-- ------------------------------------------------- on top of a cooldown

-- the cooldown frames that report aura on/off for us
function SB.WatchOverSpells()
    local set = {}
    for _, sid in pairs(overOf) do set[sid] = true end
    for i = 1, (SB.GetIconCount and SB.GetIconCount() or 0) do
        local d = SB.GetIconDB("icon" .. i)
        if d and d.enabled and d.showMissing and d.spellID then
            for id in pairs(AuraIDsFor(d)) do set[id] = true end
        end
    end
    if ns.CDMIcons and ns.CDMIcons.WatchAuraState then ns.CDMIcons.WatchAuraState(set) end
end

-- the frame Blizzard draws the spell in now: same center, its cell size
function SB.PlaceOver(iconKey, wrapper, db)
    local child, row = ns.CDMIcons and ns.CDMIcons.ChildForSpell and ns.CDMIcons.ChildForSpell(db.overSpell)
    wrapper._overChild = child
    if not child then
        overRow[db] = nil
        return wrapper:GetWidth() or 36, wrapper:GetHeight() or 36
    end
    overRow[db] = row
    local pad = RowPad(db)
    local w, h = RowIconSize(row)
    w, h = w + pad, h + pad
    ns.Pixel.SetSize(wrapper, w, h)
    wrapper:ClearAllPoints()
    wrapper:SetPoint("CENTER", child, "CENTER")
    wrapper:SetFrameStrata(child:GetFrameStrata())
    wrapper:SetFrameLevel(child:GetFrameLevel() + 20)
    wrapper._overSize = w .. ":" .. h
    return w, h
end

local function OverCDFrame(wrapper)
    local cd = wrapper.overCD
    if cd then return cd end
    cd = CreateFrame("Cooldown", nil, wrapper, "CooldownFrameTemplate")
    cd:SetAllPoints(wrapper)
    cd:SetDrawSwipe(false)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    cd:SetHideCountdownNumbers(false)
    local AL = ns.AuraLane
    local f = AL and AL.DurFormatter()
    if f and cd.SetCountdownFormatter then cd:SetCountdownFormatter(f) end
    wrapper.overCD = cd
    return cd
end

local function StyleOverText(cd, db)
    local fs = SB.CooldownText and SB.CooldownText(cd)
    if not fs then return false end
    local o = db.overCD or {}
    local tx = SB.IconTextDB(db)
    local LSM = ns.LSM
    E:SetFont(fs, LSM and LSM:Fetch("font", tx.durationFont or "Expressway"), o.size or 12, tx.durationFontOutline or "OUTLINE")
    ns.TextColor(fs, o.color or { r = 1, g = 1, b = 1 })
    fs:ClearAllPoints()
    fs:SetPoint(o.point or "TOPRIGHT", cd, o.point or "TOPRIGHT", o.x or 0, o.y or 0)
    return true
end

-- the spell's own cooldown on top, while its frame shows the aura
function SB.UpdateOverCD(iconKey)
    local wrapper = _G["TUI_SpecialIcon_" .. iconKey]
    local spell = overOf[iconKey]
    local db = spell and SB.GetIconDB(iconKey)
    local o = db and db.overCD
    if not (wrapper and o and o.show) then
        if wrapper and wrapper.overCD then wrapper.overCD:Clear(); wrapper.overCD:Hide() end
        return
    end
    local cd = OverCDFrame(wrapper)
    cd:SetFrameLevel(wrapper:GetFrameLevel() + 40)
    local test = ns.CustomGroups and ns.CustomGroups.testMode
    local child = wrapper._overChild
    if not (test or (child and ns.CDMIcons.ChildAuraActive(child))) then
        cd:Clear()
        cd:Hide()
        return
    end
    cd:Show()
    if test then
        cd:SetCooldown(GetTime() - 2, 6)
    else
        local info = C_Spell.GetSpellCooldown(spell)
        local dur = C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(spell)
        -- the GCD is not the spell's cooldown
        if dur and not (info and info.isOnGCD) then ns.CDHelpers.SetCooldownFromDuration(cd, dur) else cd:Clear() end
    end
    if not cd._styled or cd._styledFor ~= db then cd._styled = StyleOverText(cd, db); cd._styledFor = db end
end

function SB.RestyleOverCD(iconKey)
    local w = _G["TUI_SpecialIcon_" .. iconKey]
    if w and w.overCD then w.overCD._styled = nil end
    SB.UpdateOverCD(iconKey)
end

-- frames move and get re-used: follow them, repaint what changed (and re-ask missing auras)
function SB.RefreshOverIcons()
    if SB.QueueRefreshMissing and (next(missingOf) or SB.AnyGroupedMissing()) then SB.QueueRefreshMissing() end
    for key in pairs(overOf) do
        local wrapper = _G["TUI_SpecialIcon_" .. key]
        local db = SB.GetIconDB(key)
        if wrapper and db and db.overSpell then
            local before, size = wrapper._overChild, wrapper._overSize
            SB.PlaceOver(key, wrapper, db)
            if wrapper._overChild ~= before or wrapper._overSize ~= size then
                -- the aura engine resizes out of combat
                if TUI.QueueSpecialBarsUpdate then TUI:QueueSpecialBarsUpdate() end
            end
            wrapper:SetShown((VisibleNow(db) and wrapper._overChild) and true or false)
            SB.UpdateOverCD(key)
        end
    end
end

do
    local queued = false
    local function Flush()
        queued = false
        for key in pairs(overOf) do SB.UpdateOverCD(key) end
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    ev:SetScript("OnEvent", function()
        if queued or not next(overOf) then return end
        queued = true
        C_Timer.After(0, Flush)
    end)
    if ns.CDMIcons and ns.CDMIcons.OnAuraState then
        ns.CDMIcons.OnAuraState(function(child)
            for key in pairs(overOf) do
                local wrapper = _G["TUI_SpecialIcon_" .. key]
                if wrapper and wrapper._overChild == child then SB.UpdateOverCD(key) end
            end
        end)
    end
end

SB.UpdateIconSlot = UpdateIconSlot
SB.ReleaseIcon    = ReleaseIcon
