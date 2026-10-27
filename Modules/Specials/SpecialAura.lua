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

-- the CDM's buff entries: Blizzard's sets plus what the layout moved into the buff viewers.
-- Read once per frame: a spec change rebuilds every Aura Icon and Bar in one go
local rowsCache, rowsAt
local function CDMRows()
    local now = GetTime()
    if rowsCache and rowsAt == now then return rowsCache end
    local rows = {}
    local function consider(info)
        if not info then return end
        local r = { s = PlainID(info.spellID), o = PlainID(info.overrideSpellID), linked = {} }
        for _, lid in ipairs(info.linkedSpellIDs or {}) do
            local pl = PlainID(lid)
            if pl then r.linked[#r.linked + 1] = pl end
        end
        rows[#rows + 1] = r
    end
    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet then
        for _, cat in ipairs({ CAT_BUFF, CAT_BAR }) do
            local ids = cat and C_CooldownViewer.GetCooldownViewerCategorySet(cat, true)
            for _, cdID in ipairs(ids or {}) do consider(C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)) end
        end
    end
    for _, name in ipairs({ "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
        local v = _G[name]
        if v then
            for _, c in ipairs({ v:GetChildren() }) do consider(c.cooldownInfo) end
        end
    end
    rowsCache, rowsAt = rows, now
    return rows
end
SA.CDMRows = CDMRows

-- why: a list that gets a line for every ID added and where it came from (/tui aura)
local function Build(spellID, why)
    local function Note(fmt, ...) if why then why[#why + 1] = fmt:format(...) end end
    local map = { [spellID] = true }
    -- a patch can re-ID a buff (12.1.5: Lifebloom 1227806 lost its link to the 33763 HoT),
    -- so a tracked row with the same name counts too
    local myName = PlainID(C_Spell.GetSpellName(spellID))
    -- the base spell only when it's the same buff by name: an override can sit on another one
    local base = SB.GetBaseSpellID and SB.GetBaseSpellID(spellID)
    if base and base ~= spellID then
        if PlainID(C_Spell.GetSpellName(base)) == myName then
            map[base] = true
            Note("base spell %d (same name)", base)
        else
            Note("base spell %d %s left out (another name)", base, tostring(C_Spell.GetSpellName(base)))
            base = nil
        end
    end
    local rows = CDMRows()
    local function Is(id) return id ~= nil and (id == spellID or id == base) end
    local function Name(id) return id and PlainID(C_Spell.GetSpellName(id)) end
    -- the CDM entry for this spell brings all its auras; an entry that lists this aura
    -- brings just it (entries can share a spell: Violent Outburst and Seeing Red both sit on 386477)
    local direct = false
    for _, r in ipairs(rows) do
        if Is(r.s) or Is(r.o) then
            direct = true
            if r.s then map[r.s] = true end
            if r.o then map[r.o] = true end
            for _, l in ipairs(r.linked) do map[l] = true end
            Note("CDM entry %s is this spell: %s", tostring(r.s or r.o), table.concat(r.linked, ", "))
        else
            for _, l in ipairs(r.linked) do
                if Is(l) then
                    direct = true
                    Note("CDM entry %s lists it", tostring(r.s or r.o))
                    break
                end
            end
        end
    end
    -- not in the CDM under this ID (a patch re-IDed the buff): entries by the same name, their IDs with that name
    if not direct and myName then
        for _, r in ipairs(rows) do
            if Name(r.s) == myName or Name(r.o) == myName then
                local ids = { r.s, r.o }
                for _, l in ipairs(r.linked) do ids[#ids + 1] = l end
                for _, id in pairs(ids) do
                    if Name(id) == myName and not map[id] then
                        map[id] = true
                        Note("same name in CDM entry %s: %d", tostring(r.s or r.o), id)
                    end
                end
            end
        end
    end
    -- a CDM entry can carry another ID than the aura it tracks: the spell you know by
    -- that name, and what each ID resolves to while its aura is up (Lifebloom 1227806 -> 33763)
    if myName and not direct then
        local known = C_Spell.GetSpellInfo(myName)
        local kid = known and PlainID(known.spellID)
        if kid then
            map[kid] = true
            Note("the spell you know as %s: %d", myName, kid)
        end
    end
    if not InCombatLockdown() then
        local ids = {}
        for id in pairs(map) do ids[#ids + 1] = id end
        for _, id in ipairs(ids) do
            -- restricted auras make the lookup throw
            local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
            local aid = ok and aura and PlainID(aura.spellId)
            if aid then
                if not map[aid] then Note("aura up for %d: %d", id, aid) end
                map[aid] = true
            end
        end
    end
    return map
end

function SA.ExpandSpellIDs(spellID)
    if not spellID then return nil end
    local hit = expandCache[spellID]
    if hit then return hit end
    local map = Build(spellID)
    -- in combat some IDs read as secrets: keep it for now, rebuild once combat ends
    expandCache[spellID] = map
    if InCombatLockdown() then provisional[spellID] = true end
    return map
end

-- /tui aura <spellID>: the IDs an Aura Icon or Bar for it tracks, and why
ns.SlashCommand("aura", function(arg)
    local id = tonumber(strtrim(arg or ""))
    if not id then print("|cFF8080FFthingsUI|r: /tui aura <spellID>") return end
    local why = {}
    local map = Build(id, why)
    local ids = {}
    for k in pairs(map) do ids[#ids + 1] = ("%d %s"):format(k, tostring(C_Spell.GetSpellName(k))) end
    table.sort(ids)
    print(("|cFF8080FFthingsUI|r %d %s tracks: %s"):format(id, tostring(C_Spell.GetSpellName(id)), table.concat(ids, " | ")))
    for _, line in ipairs(why) do print("  " .. line) end
end)

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
    r.overlay:SetFrameLevel(button:GetFrameLevel() + 5)
    SB.PlaceArt(r.icon, button, SB.ArtInset(db))
    r.icon:SetTexCoord(SB.ComputeIconTexCoord(db))
    if ns.AuraLane then ns.AuraLane.ShowFixedIcon(r, db.customIcon, { SB.ComputeIconTexCoord(db) }) end

    local AL0 = ns.AuraLane
    -- no border of its own: the plain 1px edge the idle icon has (on top, the frame's own ring shows)
    local plain = not db.showBorder and not (db.overSpell and not db.cdmRow)
    if (db.showBorder or plain) and AL0 then
        if not r.border then
            r.border = {}
            for i = 1, 4 do r.border[i] = button:CreateTexture(nil, "OVERLAY") end
        end
        local bs = plain and 1 or (db.borderSize or 1)
        if not plain and db.glowBorderStroke and db.showGlow and AL0.MapGlowStyle(db.glowType) == "pixel" then bs = db.glowThickness or bs end
        -- outside the icon like the CDM's; Inset moves it in
        local bi = plain and 0 or ((db.borderInset or 0) - bs)
        r.borderAt = bi
        AL0.EdgeRing(button, r.border, bs, bi, (not plain and db.borderColor) or { r = 0, g = 0, b = 0, a = 1 })
        AL0.StrokeRing(button, r, bs, bi, (not plain) and db.borderStroke)
        if r.borderIn then
            for i = 1, 4 do r.borderIn[i]:Hide() r.borderOut[i]:Hide() end
        end
    else
        r.borderAt = 0
        if r.border then for _, tex in ipairs(r.border) do tex:Hide() end end
        if AL0 then AL0.StrokeRing(button, r, 0, 0, false) end
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
            pandemicInset = r.borderAt or 0,
        }, db))
    end

    button:SetMouseMotionEnabled(true)
end

-- Fill By Stacks: nil = fill by duration
function SA.StackCount(src)
    if not (src and src.fillMode == "stacks") then return nil end
    return math.max(1, math.floor(src.maxStacks or 4))
end

-- dark lines split the bar into one piece per stack
function SA.PaintSegments(host, areaW, n, gap)
    local lines = host._tuiSeg or {}
    host._tuiSeg = lines
    gap = gap or 0
    local want = (n and n > 1 and gap > 0) and (n - 1) or 0
    for k = 1, want do
        local t = lines[k]
        if not t then
            t = host:CreateTexture(nil, "OVERLAY", nil, -8)
            t:SetColorTexture(0, 0, 0, 1)
            lines[k] = t
        end
        local x = math.floor(areaW * k / n - gap / 2 + 0.5)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", host, "TOPLEFT", x, 0)
        t:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", x, 0)
        t:SetWidth(gap)
        t:Show()
    end
    for k = want + 1, #lines do lines[k]:Hide() end
end

-- the engine fills r.bar by duration, or a second bar by the aura's stacks (0..max)
function SA.BindBarFill(button, r, src, areaW, paint)
    local n = SA.StackCount(src)
    if n and type(button.SetApplicationBar) ~= "function" then n = nil end
    if n then
        if r.barBound then button:ClearDurationBar(); r.barBound = false end
        r.bar:Hide()
        r.sbar = r.sbar or CreateFrame("StatusBar", nil, button)
        paint(r.sbar)
        if r.sbarMax ~= n then
            button:SetApplicationBar(r.sbar, { minApplications = 0, maxApplications = n })
            r.sbarMax = n
        end
        r.seg = r.seg or CreateFrame("Frame", nil, button)
        r.seg:SetFrameLevel(button:GetFrameLevel() + 2)
        r.seg:SetAllPoints(r.sbar)
        SA.PaintSegments(r.seg, areaW, n, src.stackGap or 1)
        r.seg:Show()
    else
        if r.sbarMax then button:ClearApplicationBar(); r.sbarMax = nil end
        if r.sbar then r.sbar:Hide() end
        if r.seg then r.seg:Hide() end
        r.bar:Show()
        if not r.barBound and type(button.SetDurationBar) == "function" then
            button:SetDurationBar(r.bar, { direction = DIR_REMAINING })
            r.barBound = true
        end
    end
end

-- options preview: a stacks bar shows all but one piece filled
function SA.PreviewFill(bar, src, areaW)
    local n = SA.StackCount(src)
    if n then
        bar:SetMinMaxValues(0, n)
        bar:SetValue(math.max(1, n - 1))
    else
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0.7)
    end
    SA.PaintSegments(bar, areaW, n, n and (src.stackGap or 1) or 0)
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
    r.overlay:SetFrameLevel(button:GetFrameLevel() + 5)
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
    local function paint(bar)
        bar:SetFrameLevel(button:GetFrameLevel() + 1)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", r.bd, "TOPLEFT", 1, -1)
        bar:SetPoint("BOTTOMRIGHT", r.bd, "BOTTOMRIGHT", -1, 1)
        bar:SetStatusBarTexture(LSM:Fetch("statusbar", db.statusBarTexture))
        bar:SetReverseFill(db.reverseFill and true or false)
        local c = db.useClassColor and E:ClassColor(E.myclass, true) or db.customColor or { r = 0.2, g = 0.6, b = 1 }
        bar:SetStatusBarColor(c.r, c.g, c.b)
    end
    paint(r.bar)
    SA.BindBarFill(button, r, db, w - barOffset - 2, paint)


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
            if db.overSpell or db.showMissing or db.cdmRow then
                local tx = SB.IconTextDB(db)
                local ch = w and w._overChild
                local fc = ch and ch._tuiTextConfig
                local cdfs = ch and ch.Cooldown and ch.Cooldown.Text
                local fsz
                if cdfs and cdfs.GetFont then fsz = select(2, cdfs:GetFont()) end
                print(("    on top of=%s frame=%s textFromRow=%s override=%s durSize=%s style=%s missing=%s"):format(
                    tostring(db.overSpell), tostring(ch and (ch:GetName() or "found") or "none"),
                    tostring(tx ~= db), tostring(db.overrideGroupText), tostring(tx.durationFontSize),
                    tostring(db.styleName), tostring(db.showMissing)))
                print(("    frame text: cfg=%s cfgSize=%s fontSize=%s scale=%s border=%s size=%s inset=%s"):format(tostring(fc ~= nil),
                    tostring(fc and fc.cooldownFontSize), tostring(fsz),
                    (ch and w) and ("%.3f"):format(ch:GetEffectiveScale() / w:GetEffectiveScale()) or "?",
                    tostring(db.showBorder), tostring(db.borderSize), tostring(db.borderInset)))
            end
            print("    P: " .. cstate(w and w._tuiAuraP))
            print("    T: " .. cstate(w and w._tuiAuraT))
        end
    end
end)
