local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM

ns.SpecialAura = ns.SpecialAura or {}
local SA = ns.SpecialAura
local SB = ns.SpecialBars

local CAT_BUFF = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBuff
local CAT_BAR  = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBar

local DIR_REMAINING = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime

local attached = {}
local pending = false

local function PlainID(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local expandCache = {}
local provisional = {}

function SA.InvalidateSpellExpansion()
    wipe(expandCache)
    wipe(provisional)
end

function SA.ExpandSpellIDs(spellID)
    if not spellID then return nil end
    local hit = expandCache[spellID]
    if hit then return hit end
    local map = { [spellID] = true }
    local base = SB.GetBaseSpellID and SB.GetBaseSpellID(spellID)
    if base then map[base] = true end
    -- a patch can re-ID a buff (12.1.5: Lifebloom 1227806 lost its link to the 33763 HoT),
    -- so a tracked row with the same name counts too
    local myName = PlainID(C_Spell.GetSpellName(spellID))
    local row = {}
    local function consider(info)
        if not info then return end
        wipe(row)
        local o = PlainID(info.overrideSpellID)
        local s = PlainID(info.spellID)
        if o then row[#row + 1] = o end
        if s then row[#row + 1] = s end
        if info.linkedSpellIDs then
            for _, lid in ipairs(info.linkedSpellIDs) do
                local pl = PlainID(lid)
                if pl then row[#row + 1] = pl end
            end
        end
        local match = false
        for _, id in ipairs(row) do
            if id == spellID or id == base then match = true break end
        end
        if not match and myName then
            match = (s and PlainID(C_Spell.GetSpellName(s)) == myName)
                or (o and PlainID(C_Spell.GetSpellName(o)) == myName) or false
        end
        if match then
            for _, id in ipairs(row) do map[id] = true end
        end
    end
    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet then
        for _, cat in ipairs({ CAT_BUFF, CAT_BAR }) do
            local ids = cat and C_CooldownViewer.GetCooldownViewerCategorySet(cat, true)
            for _, cdID in ipairs(ids or {}) do consider(C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)) end
        end
    end
    -- those sets are Blizzard's defaults; a buff the layout moved in lives in the viewers
    for _, name in ipairs({ "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
        local v = _G[name]
        if v then
            for _, c in ipairs({ v:GetChildren() }) do consider(c.cooldownInfo) end
        end
    end
    -- a CDM entry can carry another ID than the aura it tracks: the spell you know by
    -- that name, and what each ID resolves to while its aura is up (Lifebloom 1227806 -> 33763)
    if myName then
        local known = C_Spell.GetSpellInfo(myName)
        local kid = known and PlainID(known.spellID)
        if kid then map[kid] = true end
    end
    if not InCombatLockdown() then
        local ids = {}
        for id in pairs(map) do ids[#ids + 1] = id end
        for _, id in ipairs(ids) do
            -- restricted auras make the lookup throw
            local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
            local aid = ok and aura and PlainID(aura.spellId)
            if aid then map[aid] = true end
        end
    end
    -- in combat some IDs read as secrets: keep it for now, rebuild once combat ends
    expandCache[spellID] = map
    if InCombatLockdown() then provisional[spellID] = true end
    return map
end

local function EnsureContainer(wrapper, field)
    local c = wrapper[field]
    if not c then
        c = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
        c._tuiRegions = {}
        wrapper[field] = c
        if not wrapper._tuiAuraVisHooked then
            wrapper._tuiAuraVisHooked = true
            wrapper:HookScript("OnHide", function(w)
                if w._tuiAuraP and w._tuiAuraP:GetParent() ~= w then w._tuiAuraP:Hide() end
                if w._tuiAuraT and w._tuiAuraT:GetParent() ~= w then w._tuiAuraT:Hide() end
            end)
            wrapper:HookScript("OnShow", function()
                if TUI and TUI.QueueSpecialBarsUpdate then TUI:QueueSpecialBarsUpdate() end
            end)
        end
    end
    return c
end

local function ConfigureContainer(c, wrapper, w, h)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", wrapper, "TOPLEFT", 0, 0)
    c:SetSize(w, h)
    c:SetFrameStrata(wrapper:GetFrameStrata() or "MEDIUM")
    c:SetFrameLevel((wrapper.GetFrameLevel and wrapper:GetFrameLevel() or 1) + 1)
    if AnchorUtil and AnchorUtil.FlowLayoutAxis and AnchorUtil.FlowDirection then
        c:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
        c:SetFlowLayoutAnchorPoint("TOPLEFT")
        c:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
    end
    if c.SetFlowLayoutPadding then c:SetFlowLayoutPadding(0, 0, 0, 0) end
    c:Show()
end

local function SetUnitLast(c, unit)
    if c._tuiUnit ~= unit then
        c:SetUnit(unit)
        c._tuiUnit = unit
        if c.UpdateAllAuras then c:UpdateAllAuras() end
    end
end

local function HarmfulTargetOK()
    return not (UnitExists("target") and UnitCanAssist("player", "target"))
end

local function PlayerAssistOK()
    local AL = ns.AuraLane
    if AL and AL.PlayerAssistOK then return AL.PlayerAssistOK() end
    return true
end

local function ApplyGroupTo(c, key, filter, spells, w, h, styler)
    local layout = { elementWidth = w, elementHeight = h, elementSpacing = 0, lineSpacing = 0 }
    if c:HasAuraGroup(key) then
        ns.SetAuraGroupCap(c, key, 1)
        c:SetAuraGroupFilterString(key, filter)
        c:SetAuraGroupCandidateFilters(key, { includeSpellIDs = spells })
        c:SetAuraGroupLayout(key, layout)
    else
        c:AddAuraGroup(key, filter, {
            maxFrameCount = 1,
            candidateFilters = { includeSpellIDs = spells },
            layout = layout,
            initializeFrame = function(button)
                local r = c._tuiRegions[button]
                if not r then r = {}; c._tuiRegions[button] = r end
                styler(button, r)
            end,
        })
    end
    for button, r in pairs(c._tuiRegions) do
        if not pcall(styler, button, r) then pending = true end
    end
end

function SA.StyleIconButton(button, r, wrapper, key)
    if button:IsForbidden() then return end
    local db = SB.GetIconDB(key)
    if not db then return end
    local w, h = wrapper:GetSize()
    if not w or w < 1 then w = db.width or 36 end
    if not h or h < 1 then h = w end
    ns.Pixel.SetSizeScaled(button, wrapper, w, h)

    if not r.icon then
        r.icon = button:CreateTexture(nil, "ARTWORK")
        if ns.AuraLane and ns.AuraLane.NoSnap then ns.AuraLane.NoSnap(r.icon) end
        r.icon:SetAllPoints(button)
        button:SetIcon(r.icon)
        if ns.AuraLane then ns.AuraLane.MakeFixedIcon(button, r) end
        r.overlay = CreateFrame("Frame", nil, button)
        r.overlay:SetAllPoints(button)
    end
    r.overlay:SetFrameLevel(button:GetFrameLevel() + 3)
    r.icon:SetTexCoord(SB.ComputeIconTexCoord(db))
    if ns.AuraLane then ns.AuraLane.ShowFixedIcon(r, db.customIcon, { SB.ComputeIconTexCoord(db) }) end

    local AL0 = ns.AuraLane
    if db.showBorder and AL0 then
        if not r.border then
            r.border = {}
            for i = 1, 4 do r.border[i] = button:CreateTexture(nil, "OVERLAY") end
        end
        local bs = db.borderSize or 1
        if db.glowBorderStroke and db.showGlow and AL0.MapGlowStyle(db.glowType) == "pixel" then bs = db.glowThickness or bs end
        -- outside the icon like the CDM's; Inset moves it in
        local bi = (db.borderInset or 0) - bs
        AL0.EdgeRing(button, r.border, bs, bi, db.borderColor or { r = 0, g = 0, b = 0, a = 1 })
        if r.borderIn then
            for i = 1, 4 do r.borderIn[i]:Hide() r.borderOut[i]:Hide() end
        end
    else
        if r.border then for _, tex in ipairs(r.border) do tex:Hide() end end
        if r.borderIn then
            for i = 1, 4 do r.borderIn[i]:Hide() r.borderOut[i]:Hide() end
        end
    end

    if db.showCooldown then
        if not r.cd then
            r.cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            r.cd:SetAllPoints(r.icon)
            r.cd:SetFrameLevel(button:GetFrameLevel() + 1)
            r.cd:SetDrawEdge(false)
            r.cd:SetHideCountdownNumbers(true)
        end
        r.cd:SetReverse(db.invertSwipe and true or false)
        r.cd:Show()
        button:SetDurationCooldown(r.cd)
    else
        button:ClearDurationCooldown()
        if r.cd then r.cd:Hide() end
    end

    local AL = ns.AuraLane
    local tx = SB.IconTextDB and SB.IconTextDB(db) or db
    if tx.showDuration ~= false then
        r.dur = r.dur or r.overlay:CreateFontString(nil, "OVERLAY")
        r.dur:ClearAllPoints()
        r.dur:SetPoint(tx.durationPoint or "CENTER", button, tx.durationPoint or "CENTER",
            tx.durationXOffset or 0, tx.durationYOffset or 0)
        E:SetFont(r.dur, LSM:Fetch("font", tx.durationFont or "Expressway"),
            tx.durationFontSize or 14, tx.durationFontOutline or "OUTLINE")
        local dc = tx.durationColor or {}
        r.dur:SetTextColor(dc.r or 1, dc.g or 1, dc.b or 1)
        r.dur:Show()
        button:SetDurationText(r.dur, { textFormatter = AL and AL.DurFormatter() or nil })
    else
        button:ClearDurationText()
        if r.dur then r.dur:SetText("") r.dur:Hide() end
    end

    if tx.showStacks then
        r.count = r.count or r.overlay:CreateFontString(nil, "OVERLAY")
        r.count:ClearAllPoints()
        r.count:SetPoint(tx.stackPoint or "BOTTOMRIGHT", button, tx.stackPoint or "BOTTOMRIGHT",
            tx.stackXOffset or 0, tx.stackYOffset or 0)
        E:SetFont(r.count, LSM:Fetch("font", tx.stackFont or "Expressway"),
            tx.stackFontSize or 14, tx.stackFontOutline or "OUTLINE")
        local sc = tx.stackColor or {}
        r.count:SetTextColor(sc.r or 1, sc.g or 1, sc.b or 1)
        r.count:Show()
        button:SetApplicationCount(r.count, {})
    else
        button:ClearApplicationCount()
        if r.count then r.count:SetText("") r.count:Hide() end
    end

    if AL then
        AL.ApplyButtonFX(button, r, AL.PandemicLook({
            style = db.showGlow and AL.MapGlowStyle(db.glowType) or nil,
            color = db.glowColor,
            anchor = r.icon,
            thickness = db.glowThickness,
            outline = (db.glowBorderStroke and db.showBorder) and true or false,
            lines = db.glowLines, length = db.glowLength,
            offset = db.glowOffset, frequency = db.glowSpeed,
            w = w, h = h,
            pandemic = db.showPandemic and true or false,
        }, db))
    end

    button:SetMouseMotionEnabled(true)
end

function SA.StyleBarButton(button, r, wrapper, key)
    if button:IsForbidden() then return end
    local db = SB.GetBarDB(key)
    if not db then return end
    local w, h = wrapper:GetSize()
    if not w or w < 1 then w = db.width or 200 end
    if not h or h < 1 then h = db.height or 24 end
    button:SetSize(w, h)

    if not r.bd then
        r.bd = CreateFrame("Frame", nil, button, "BackdropTemplate")
        r.bd:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
        r.overlay = CreateFrame("Frame", nil, button)
        r.overlay:SetAllPoints(button)
    end
    r.bd:SetFrameLevel(button:GetFrameLevel())
    r.overlay:SetFrameLevel(button:GetFrameLevel() + 3)
    -- the tick layer sits between fill and text (read here, before any aura makes the button secret)
    wrapper._tuiTickLevel = button:GetFrameLevel() + 2
    r.bd:SetBackdropColor(0, 0, 0, 0.6)
    r.bd:SetBackdropBorderColor(0, 0, 0, 1)

    local barOffset = 0
    if db.iconEnabled then
        if not r.iconBD then
            r.iconBD = CreateFrame("Frame", nil, button, "BackdropTemplate")
            r.iconBD:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
            r.iconBD:SetBackdropColor(0, 0, 0, 1)
            r.iconBD:SetBackdropBorderColor(0, 0, 0, 1)
            r.icon = r.iconBD:CreateTexture(nil, "ARTWORK")
            button:SetIcon(r.icon)
            if ns.AuraLane then ns.AuraLane.MakeFixedIcon(r.iconBD, r) end
        end
        r.iconBD:SetFrameLevel(button:GetFrameLevel())
        r.iconBD:ClearAllPoints()
        r.iconBD:SetPoint("LEFT", button, "LEFT", 0, 0)
        r.iconBD:SetSize(h, h)
        local z = db.iconZoom or 0.1
        r.icon:SetTexCoord(z, 1 - z, z, 1 - z)
        if ns.AuraLane then ns.AuraLane.ShowFixedIcon(r, db.customIcon, { z, 1 - z, z, 1 - z }) end
        r.icon:ClearAllPoints()
        r.icon:SetPoint("TOPLEFT", r.iconBD, "TOPLEFT", 1, -1)
        r.icon:SetPoint("BOTTOMRIGHT", r.iconBD, "BOTTOMRIGHT", -1, 1)
        r.iconBD:Show()
        barOffset = h + (db.iconSpacing or 1)
    elseif r.iconBD then
        r.iconBD:Hide()
    end

    r.bd:ClearAllPoints()
    r.bd:SetPoint("TOPLEFT", button, "TOPLEFT", barOffset, 0)
    r.bd:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)

    if not r.bar then
        r.bar = CreateFrame("StatusBar", nil, button)
        r.bar:SetMinMaxValues(0, 1)
        r.bar:SetValue(1)
    end
    r.bar:SetFrameLevel(button:GetFrameLevel() + 1)
    r.bar:ClearAllPoints()
    r.bar:SetPoint("TOPLEFT", r.bd, "TOPLEFT", 1, -1)
    r.bar:SetPoint("BOTTOMRIGHT", r.bd, "BOTTOMRIGHT", -1, 1)
    r.bar:SetStatusBarTexture(LSM:Fetch("statusbar", db.statusBarTexture))
    r.bar:SetReverseFill(db.reverseFill and true or false)
    if db.useClassColor then
        local c = E:ClassColor(E.myclass, true)
        r.bar:SetStatusBarColor(c.r, c.g, c.b)
    else
        local c = db.customColor or { r = 0.2, g = 0.6, b = 1 }
        r.bar:SetStatusBarColor(c.r, c.g, c.b)
    end
    if not r.barBound and type(button.SetDurationBar) == "function" then
        button:SetDurationBar(r.bar, { direction = DIR_REMAINING })
        r.barBound = true
    end


    local font = LSM:Fetch("font", db.font or "Expressway")
    r.name = r.name or r.overlay:CreateFontString(nil, "OVERLAY")
    if db.showName then
        E:SetFont(r.name, font, db.fontSize or 12, db.fontOutline or "OUTLINE")
        ns.TextColor(r.name, db.nameColor)
        r.name:ClearAllPoints()
        r.name:SetPoint(db.namePoint or "LEFT", r.bar, db.namePoint or "LEFT",
            db.nameXOffset or 2, db.nameYOffset or 0)
        local name = db.spellName
        if not name and db.spellID then
            local si = SB.GetCachedSpellInfo and SB.GetCachedSpellInfo(db.spellID)
            name = si and si.name
        end
        r.name:SetText(name or "")
        r.name:Show()
    else
        r.name:Hide()
    end

    local AL = ns.AuraLane
    if db.showDuration then
        r.dur = r.dur or r.overlay:CreateFontString(nil, "OVERLAY")
        r.dur:ClearAllPoints()
        r.dur:SetPoint(db.durationPoint or "RIGHT", r.bar, db.durationPoint or "RIGHT",
            db.durationXOffset or -4, db.durationYOffset or 0)
        E:SetFont(r.dur, font, db.fontSize or 12, db.fontOutline or "OUTLINE")
        ns.TextColor(r.dur, db.durationColor)
        r.dur:Show()
        button:SetDurationText(r.dur, { textFormatter = AL and AL.DurFormatter() or nil })
    else
        button:ClearDurationText()
        if r.dur then r.dur:SetText("") r.dur:Hide() end
    end

    if db.showStacks then
        r.count = r.count or r.overlay:CreateFontString(nil, "OVERLAY")
        r.count:ClearAllPoints()
        local anchorTo = (db.stackAnchor == "BAR" or not r.iconBD) and r.bar or r.iconBD
        r.count:SetPoint(db.stackPoint or "CENTER", anchorTo, db.stackPoint or "CENTER",
            db.stackXOffset or 0, db.stackYOffset or 0)
        E:SetFont(r.count, font, db.stackFontSize or 14, db.stackFontOutline or "OUTLINE")
        ns.TextColor(r.count, db.stackColor)
        r.count:Show()
        button:SetApplicationCount(r.count, {})
    else
        button:ClearApplicationCount()
        if r.count then r.count:SetText("") r.count:Hide() end
    end

    button:SetMouseMotionEnabled(true)
end

-- kind: nil = both sides, HELPFUL = buff on you only, HARMFUL = your debuff on the target only
local function Attach(wrapper, key, spellID, w, h, styler, kind)
    if not (wrapper and spellID) then return end
    if InCombatLockdown() then pending = true return end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end
    local spells = SA.ExpandSpellIDs(spellID)
    local gkey = "S" .. key

    if kind ~= "HARMFUL" then
        local cp = EnsureContainer(wrapper, "_tuiAuraP")
        ConfigureContainer(cp, wrapper, w, h)
        ApplyGroupTo(cp, gkey, "HELPFUL", spells, w, h, styler)
        SetUnitLast(cp, "player")
        cp:SetShown(PlayerAssistOK())
    else
        local cp = wrapper._tuiAuraP
        if cp and cp:HasAuraGroup(gkey) then ns.SetAuraGroupCap(cp, gkey, 0) end
    end

    if kind ~= "HELPFUL" then
        local ct = EnsureContainer(wrapper, "_tuiAuraT")
        ConfigureContainer(ct, wrapper, w, h)
        ApplyGroupTo(ct, gkey, "HARMFUL|PLAYER", spells, w, h, styler)
        SetUnitLast(ct, "target")
        ct:SetShown(HarmfulTargetOK())
    else
        local ct = wrapper._tuiAuraT
        if ct and ct:HasAuraGroup(gkey) then ns.SetAuraGroupCap(ct, gkey, 0) end
    end

    attached[key] = wrapper
end

function SA.AttachIcon(wrapper, key, db, w, h)
    Attach(wrapper, key, db.spellID, w, h, function(button, r)
        SA.StyleIconButton(button, r, wrapper, key)
    end, db.auraKind)
end

function SA.AttachBar(wrapper, key, db, w, h)
    Attach(wrapper, key, db.spellID, w, h, function(button, r)
        SA.StyleBarButton(button, r, wrapper, key)
    end)
end

function SA.Detach(wrapper, key)
    if not wrapper then return end
    if InCombatLockdown() then pending = true return end
    local gkey = "S" .. key
    local cp, ct = wrapper._tuiAuraP, wrapper._tuiAuraT
    if cp and cp.HasAuraGroup and cp:HasAuraGroup(gkey) then ns.SetAuraGroupCap(cp, gkey, 0) end
    if ct and ct.HasAuraGroup and ct:HasAuraGroup(gkey) then ns.SetAuraGroupCap(ct, gkey, 0) end
    attached[key] = nil
end

function SA.ReparseAll()
    for _, wrapper in pairs(attached) do
        for _, c in ipairs({ wrapper._tuiAuraP, wrapper._tuiAuraT }) do
            if c and c.UpdateAllAuras then c:UpdateAllAuras() end
        end
    end
end

function SA.RefreshVisibility()
    local pOK, tOK = PlayerAssistOK(), HarmfulTargetOK()
    for _, wrapper in pairs(attached) do
        local cp, ct = wrapper._tuiAuraP, wrapper._tuiAuraT
        if cp then cp:SetShown(pOK) end
        if ct and ct._tuiUnit == "target" then ct:SetShown(tOK) end
    end
end

local function ReparseSoon()
    C_Timer.After(0.1, SA.ReparseAll)
    C_Timer.After(2, SA.ReparseAll)
    C_Timer.After(5, SA.ReparseAll)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("CINEMATIC_STOP")
ev:RegisterEvent("STOP_MOVIE")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" or event == "CINEMATIC_STOP" or event == "STOP_MOVIE" then
        ReparseSoon()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        for id in pairs(provisional) do expandCache[id] = nil end
        wipe(provisional)
        if not pending then return end
        pending = false
        if TUI and TUI.QueueSpecialBarsUpdate then TUI:QueueSpecialBarsUpdate() end
        return
    end
    local tOK = HarmfulTargetOK()
    for _, wrapper in pairs(attached) do
        local ct = wrapper._tuiAuraT
        if ct and ct._tuiUnit == "target" then
            ct:SetShown(tOK)
            ct:SetUnit("target")
            if ct.UpdateAllAuras then ct:UpdateAllAuras() end
        end
    end
end)

local function DumpVal(v)
    if issecretvalue and issecretvalue(v) then return "secret" end
    return tostring(v)
end

-- each Aura Icon: what it filters on (* = on you now) and the state of its containers
ns.SlashCommand("icons", function()
    print(("|cFF8080FFtui icons|r combat=%s testMode=%s"):format(
        tostring(InCombatLockdown()), tostring(ns.CustomGroups and ns.CustomGroups.testMode or false)))
    for i = 1, (SB.GetIconCount and SB.GetIconCount() or 0) do
        local key = "icon" .. i
        local db = SB.GetIconDB(key)
        if db and db.spellID then
            local w = _G["TUI_SpecialIcon_" .. key]
            local gkey = "S" .. key
            local function cstate(c)
                if not c then return "none" end
                local has = c:HasAuraGroup(gkey)
                local en = has and c.IsAuraGroupEnabled and c:IsAuraGroupEnabled(gkey)
                return ("shown=%s vis=%s unit=%s group=%s enabled=%s"):format(DumpVal(c:IsShown()),
                    DumpVal(c:IsVisible()), tostring(c._tuiUnit), tostring(has), DumpVal(en))
            end
            local ids = {}
            for id in pairs(SA.ExpandSpellIDs(db.spellID) or {}) do
                -- restricted auras make the lookup throw in combat
                local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
                local aid = ok and aura and PlainID(aura.spellId)
                ids[#ids + 1] = ("%d%s%s"):format(id, (ok and aura) and "*" or "",
                    (aid and aid ~= id) and ("->" .. aid) or "")
            end
            table.sort(ids)
            print(("  %s %d %s en=%s kind=%s grp=%s row=%s attached=%s wrapper=%s/%s"):format(key, db.spellID,
                C_Spell.GetSpellName(db.spellID) or "?", tostring(db.enabled), tostring(db.auraKind or "BOTH"),
                tostring(db.customGroup), tostring(db.cdmRow), tostring(attached[key] ~= nil),
                DumpVal(w and w:IsShown()), DumpVal(w and w:IsVisible())))
            print("    ids: " .. table.concat(ids, ", "))
            print("    P: " .. cstate(w and w._tuiAuraP))
            print("    T: " .. cstate(w and w._tuiAuraT))
        end
    end
end)
