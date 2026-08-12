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

function SA.InvalidateSpellExpansion()
    wipe(expandCache)
end

function SA.ExpandSpellIDs(spellID)
    if not spellID then return nil end
    local hit = expandCache[spellID]
    if hit then return hit end
    local map = { [spellID] = true }
    local base = SB.GetBaseSpellID and SB.GetBaseSpellID(spellID)
    if base then map[base] = true end
    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet then
        local row = {}
        for _, cat in ipairs({ CAT_BUFF, CAT_BAR }) do
            local ids = cat and C_CooldownViewer.GetCooldownViewerCategorySet(cat, true)
            if ids then
                for _, cdID in ipairs(ids) do
                    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                    if info then
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
                        if match then
                            for _, id in ipairs(row) do map[id] = true end
                        end
                    end
                end
            end
        end
    end
    if not InCombatLockdown() then expandCache[spellID] = map end
    return map
end

local function EnsureContainer(wrapper, field)
    local c = wrapper[field]
    if not c then
        c = CreateFrame("AuraContainer", nil, wrapper, "CustomAuraContainerTemplate")
        c._tuiRegions = {}
        wrapper[field] = c
    end
    return c
end

local function ConfigureContainer(c, wrapper, w, h)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", wrapper, "TOPLEFT", 0, 0)
    c:SetSize(w, h)
    c:SetFrameStrata(wrapper:GetFrameStrata() or "MEDIUM")
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

local function ApplyGroupTo(c, key, filter, spells, w, h, styler)
    local layout = { elementWidth = w, elementHeight = h, elementSpacing = 0, lineSpacing = 0 }
    if c:HasAuraGroup(key) then
        c:SetAuraGroupMaxFrameCount(key, 1)
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
    for button, r in pairs(c._tuiRegions) do styler(button, r) end
end

local function IconTexture(spellID)
    local raw = SB.GetRawSpellList and SB.GetRawSpellList()[spellID]
    if raw and raw.icon then return raw.icon end
    local si = SB.GetCachedSpellInfo and SB.GetCachedSpellInfo(spellID)
    return si and si.iconID or nil
end

function SA.StyleIconButton(button, r, wrapper, key)
    local db = SB.GetIconDB(key)
    if not db then return end
    local w, h = wrapper:GetSize()
    if not w or w < 1 then w = db.width or 36 end
    if not h or h < 1 then h = w end
    button:SetSize(w, h)

    if not r.icon then
        r.icon = button:CreateTexture(nil, "ARTWORK")
        r.icon:SetAllPoints(button)
        button:SetIcon(r.icon)
        r.overlay = CreateFrame("Frame", nil, button)
        r.overlay:SetAllPoints(button)
    end
    r.overlay:SetFrameLevel(button:GetFrameLevel() + 3)
    r.icon:SetTexCoord(SB.ComputeIconTexCoord(db))

    local AL0 = ns.AuraLane
    if db.showBorder and AL0 then
        if not r.border then
            r.border = {}
            for i = 1, 4 do r.border[i] = button:CreateTexture(nil, "OVERLAY") end
        end
        local bs = db.borderSize or 1
        local bi = db.borderInset or 0
        AL0.EdgeRing(button, r.border, bs, bi, db.borderColor or { r = 0, g = 0, b = 0, a = 1 })
        if db.borderStroke then
            if not r.borderIn then
                r.borderIn, r.borderOut = {}, {}
                for i = 1, 4 do
                    r.borderIn[i] = button:CreateTexture(nil, "OVERLAY")
                    r.borderOut[i] = button:CreateTexture(nil, "OVERLAY")
                end
            end
            AL0.EdgeRing(button, r.borderIn, 1, bi + bs, { a = 1 })
            AL0.EdgeRing(button, r.borderOut, 1, bi - 1, { a = 1 })
        elseif r.borderIn then
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
    if db.showDuration ~= false then
        r.dur = r.dur or r.overlay:CreateFontString(nil, "OVERLAY")
        r.dur:ClearAllPoints()
        r.dur:SetPoint(db.durationPoint or "CENTER", button, db.durationPoint or "CENTER",
            db.durationXOffset or 0, db.durationYOffset or 0)
        E:SetFont(r.dur, LSM:Fetch("font", db.durationFont or "Expressway"),
            db.durationFontSize or 14, db.durationFontOutline or "OUTLINE")
        local dc = db.durationColor or {}
        r.dur:SetTextColor(dc.r or 1, dc.g or 1, dc.b or 1)
        r.dur:Show()
        button:SetDurationText(r.dur, { textFormatter = AL and AL.DurFormatter() or nil })
    else
        button:ClearDurationText()
        if r.dur then r.dur:SetText("") r.dur:Hide() end
    end

    if db.showStacks then
        r.count = r.count or r.overlay:CreateFontString(nil, "OVERLAY")
        r.count:ClearAllPoints()
        r.count:SetPoint(db.stackPoint or "BOTTOMRIGHT", button, db.stackPoint or "BOTTOMRIGHT",
            db.stackXOffset or 0, db.stackYOffset or 0)
        E:SetFont(r.count, LSM:Fetch("font", db.stackFont or "Expressway"),
            db.stackFontSize or 14, db.stackFontOutline or "OUTLINE")
        local sc = db.stackColor or {}
        r.count:SetTextColor(sc.r or 1, sc.g or 1, sc.b or 1)
        r.count:Show()
        button:SetApplicationCount(r.count, {})
    else
        button:ClearApplicationCount()
        if r.count then r.count:SetText("") r.count:Hide() end
    end

    if AL then
        AL.ApplyButtonFX(button, r, {
            style = db.showGlow and AL.MapGlowStyle(db.glowType) or nil,
            color = db.glowColor,
            thickness = db.glowThickness,
            w = w, h = h,
            pandemic = db.showPandemic and true or false,
        })
    end

    button:SetMouseMotionEnabled(true)
end

function SA.StyleBarButton(button, r, wrapper, key)
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
        end
        r.iconBD:SetFrameLevel(button:GetFrameLevel())
        r.iconBD:ClearAllPoints()
        r.iconBD:SetPoint("LEFT", button, "LEFT", 0, 0)
        r.iconBD:SetSize(h, h)
        local z = db.iconZoom or 0.1
        r.icon:SetTexCoord(z, 1 - z, z, 1 - z)
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
        r.count:Show()
        button:SetApplicationCount(r.count, {})
    else
        button:ClearApplicationCount()
        if r.count then r.count:SetText("") r.count:Hide() end
    end

    button:SetMouseMotionEnabled(true)
end

local function Attach(wrapper, key, spellID, w, h, styler)
    if not (wrapper and spellID) then return end
    if InCombatLockdown() then pending = true return end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end
    local spells = SA.ExpandSpellIDs(spellID)
    local gkey = "S" .. key

    local cp = EnsureContainer(wrapper, "_tuiAuraP")
    ConfigureContainer(cp, wrapper, w, h)
    ApplyGroupTo(cp, gkey, "HELPFUL", spells, w, h, styler)
    SetUnitLast(cp, "player")

    local ct = EnsureContainer(wrapper, "_tuiAuraT")
    ConfigureContainer(ct, wrapper, w, h)
    ApplyGroupTo(ct, gkey, "HARMFUL|PLAYER", spells, w, h, styler)
    SetUnitLast(ct, "target")
    ct:SetShown(HarmfulTargetOK())

    attached[key] = wrapper
end

function SA.AttachIcon(wrapper, key, db, w, h)
    Attach(wrapper, key, db.spellID, w, h, function(button, r)
        SA.StyleIconButton(button, r, wrapper, key)
    end)
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
    if cp and cp.HasAuraGroup and cp:HasAuraGroup(gkey) then cp:SetAuraGroupMaxFrameCount(gkey, 0) end
    if ct and ct.HasAuraGroup and ct:HasAuraGroup(gkey) then ct:SetAuraGroupMaxFrameCount(gkey, 0) end
    attached[key] = nil
end

function SA.ReparseAll()
    for _, wrapper in pairs(attached) do
        for _, c in ipairs({ wrapper._tuiAuraP, wrapper._tuiAuraT }) do
            if c and c.UpdateAllAuras then c:UpdateAllAuras() end
        end
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
