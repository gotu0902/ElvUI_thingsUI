local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM

ns.CustomBars = ns.CustomBars or {}
local M = ns.CustomBars

local DeepCopy = ns.DeepCopy
local state = {}
local moverMade = {}
local pendingSync = false

local function Root()
    local db = E.db.thingsUI
    if not db then return nil end
    db.customBars = db.customBars or { groups = {}, nextID = 1 }
    db.customBars.groups = db.customBars.groups or {}
    db.customBars.nextID = db.customBars.nextID or 1
    return db.customBars
end

function M.GetGroups()
    local r = Root()
    return r and r.groups or {}
end

function M.GroupByID(id)
    for _, g in ipairs(M.GetGroups()) do
        if g.id == id then return g end
    end
end

function M.NewGroup()
    local r = Root(); if not r then return end
    local g = DeepCopy(ns.CUSTOM_BAR_GROUP_DEFAULTS or {})
    g.id = r.nextID
    g.name = "Bar Group " .. g.id
    g.auras = g.auras or {}
    r.nextID = r.nextID + 1
    r.groups[#r.groups + 1] = g
    return g
end

function M.RemoveGroup(index)
    local r = Root(); if not r then return end
    local g = r.groups[index]
    if not g then return end
    local st = state[g.id]
    if st then
        if InCombatLockdown() then
            pendingSync = true
        elseif st.container then
            for key in pairs(st.keys) do st.container:SetAuraGroupMaxFrameCount(key, 0) end
        end
        if st.frame then st.frame:Hide() end
    end
    if ns.MoverSync and ns.MoverSync.RemoveManaged then
        ns.MoverSync.RemoveManaged("TUI_CustomBarsMover" .. g.id, st and st.frame)
    end
    table.remove(r.groups, index)
end

local function GetCurrentClassFile()
    return select(2, UnitClass("player"))
end

local function GetCurrentSpecID()
    local idx = GetSpecialization and GetSpecialization()
    local id = idx and select(1, GetSpecializationInfo(idx))
    return (id and id ~= 0) and id or 1
end

function M.GetScopeRoot(group, scope, create)
    if not group then return nil end
    local root
    if scope == "class" then
        group.classes = group.classes or {}
        local key = GetCurrentClassFile()
        if create then group.classes[key] = group.classes[key] or {} end
        root = group.classes[key]
    elseif scope == "spec" then
        group.specs = group.specs or {}
        local key = tostring(GetCurrentSpecID())
        if create then group.specs[key] = group.specs[key] or {} end
        root = group.specs[key]
    else
        root = group
    end
    if create and root then root.auras = root.auras or {} end
    return root
end

local function NextIndex(root)
    local n = 0
    for _, d in pairs((root and root.auras) or {}) do
        local li = d.layoutIndex or 0
        if li > n and li < 90000 then n = li end
    end
    return n + 1
end

function M.AddAura(group, scope, spellID)
    spellID = tonumber(spellID)
    if not (group and spellID) then return end
    local root = M.GetScopeRoot(group, scope, true)
    local uid = "spell:" .. spellID
    if root.auras[uid] then return end
    root.auras[uid] = { spells = { [spellID] = true }, kind = "HELPFUL", max = 1,
        layoutIndex = NextIndex(root) }
end

function M.AddAuraSet(group, scope, uid, def)
    if not (group and uid and def) then return end
    local root = M.GetScopeRoot(group, scope, true)
    if root.auras[uid] then return end
    local spells = {}
    for _, id in ipairs(def.spells or {}) do spells[id] = true end
    root.auras[uid] = {
        enabled = true, layoutIndex = NextIndex(root),
        name = def.name, spells = spells,
        kind = def.kind or "HELPFUL", max = def.max or 1,
    }
end

function M.RemoveAura(group, scope, uid)
    local root = M.GetScopeRoot(group, scope, false)
    if root and root.auras then root.auras[uid] = nil end
end

function M.ScopeEntries(group, scope)
    local out = {}
    local root = M.GetScopeRoot(group, scope, false)
    for uid, def in pairs((root and root.auras) or {}) do
        out[#out + 1] = { kind = "aura", uid = uid, def = def, li = def.layoutIndex or 999 }
    end
    if scope == "spec" then
        local SBm = ns.SpecialBars
        if SBm and SBm.GetBarCount and SBm.GetBarDB then
            for i = 1, SBm.GetBarCount() do
                local bkey = "bar" .. i
                local bdb = SBm.GetBarDB(bkey)
                if bdb and bdb.enabled and bdb.spellID and bdb.customGroup == group.id then
                    out[#out + 1] = { kind = "specialbar", uid = "sb:" .. bkey, barKey = bkey,
                        def = bdb, li = bdb.customGroupOrder or 20000 }
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.li ~= b.li then return a.li < b.li end
        return a.uid < b.uid
    end)
    return out
end

local SCOPE_BAND = { global = 1, class = 2, spec = 3 }
local SCOPES = { "global", "class", "spec" }

function M.Entries(group)
    local out = {}
    for _, scope in ipairs(SCOPES) do
        for _, e in ipairs(M.ScopeEntries(group, scope)) do
            if e.kind == "aura" then
                if e.def.enabled ~= false and next(e.def.spells or {}) then
                    out[#out + 1] = {
                        uid = scope .. "_" .. e.uid,
                        def = e.def,
                        rank = SCOPE_BAND[scope] * 100000 + e.li,
                    }
                end
            else
                local spells = (ns.SpecialAura and ns.SpecialAura.ExpandSpellIDs
                    and ns.SpecialAura.ExpandSpellIDs(e.def.spellID)) or { [e.def.spellID] = true }
                out[#out + 1] = {
                    uid = scope .. "_" .. e.uid:gsub(":", ""),
                    def = { spells = spells, max = 1 },
                    rank = SCOPE_BAND[scope] * 100000 + e.li,
                }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.uid < b.uid
    end)
    return out
end

function M.MoveEntry(group, scope, uid, dir)
    local list = M.ScopeEntries(group, scope)
    local idx
    for i, e in ipairs(list) do
        if e.uid == uid then idx = i break end
    end
    if not idx then return end
    local to = idx + dir
    if to < 1 or to > #list then return end
    local function write(e, v)
        if e.kind == "specialbar" then e.def.customGroupOrder = v
        else e.def.layoutIndex = v end
    end
    for i, e in ipairs(list) do write(e, i) end
    write(list[idx], to)
    write(list[to], idx)
end

local spellNameOK
local function CanSpellName(button)
    if spellNameOK == nil and button then
        spellNameOK = type(button.SetSpellName) == "function"
            and type(button.ClearSpellName) == "function"
    end
    return spellNameOK == true
end

function M.FirstSpell(def)
    local best
    for id in pairs((def and def.spells) or {}) do
        local n = tonumber(id)
        if n and (not best or n < best) then best = n end
    end
    return best
end

local function StyleBar(button, r, group, def)
    local st = state[group.id]
    local sp = group.spacing or 2
    local w = (st and st.effW) or group.width or 220
    if def.halfWidth then w = math.floor((w - sp) / 2) end
    local h = (st and st.effH) or group.height or 22
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
    if group.iconEnabled ~= false then
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
        local z = group.iconZoom or 0.1
        r.icon:SetTexCoord(z, 1 - z, z, 1 - z)
        r.icon:ClearAllPoints()
        r.icon:SetPoint("TOPLEFT", r.iconBD, "TOPLEFT", 1, -1)
        r.icon:SetPoint("BOTTOMRIGHT", r.iconBD, "BOTTOMRIGHT", -1, 1)
        r.iconBD:Show()
        barOffset = h + (group.iconSpacing or 1)
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
    r.bar:SetStatusBarTexture(LSM:Fetch("statusbar", group.statusBarTexture))
    if group.useClassColor ~= false then
        local c = E:ClassColor(E.myclass, true)
        r.bar:SetStatusBarColor(c.r, c.g, c.b)
    else
        local c = group.customColor or { r = 0.2, g = 0.6, b = 1 }
        r.bar:SetStatusBarColor(c.r, c.g, c.b)
    end
    if not r.barBound and type(button.SetDurationBar) == "function" then
        button:SetDurationBar(r.bar, {
            direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime,
        })
        r.barBound = true
    end

    local font = LSM:Fetch("font", group.font or "Expressway")
    r.name = r.name or r.overlay:CreateFontString(nil, "OVERLAY")
    if group.showName ~= false then
        E:SetFont(r.name, font, group.fontSize or 12, group.fontOutline or "OUTLINE")
        r.name:ClearAllPoints()
        r.name:SetPoint(group.namePoint or "LEFT", r.bar, group.namePoint or "LEFT",
            group.nameXOffset or 4, group.nameYOffset or 0)
        r.name:Show()
        if CanSpellName(button) then
            button:SetSpellName(r.name)
        else
            local sid = M.FirstSpell(def)
            local nm = sid and C_Spell.GetSpellName and C_Spell.GetSpellName(sid)
            r.name:SetText(nm or "")
        end
    else
        if CanSpellName(button) then button:ClearSpellName() end
        r.name:SetText("")
        r.name:Hide()
    end

    local AL = ns.AuraLane
    if group.showDuration ~= false then
        r.dur = r.dur or r.overlay:CreateFontString(nil, "OVERLAY")
        r.dur:ClearAllPoints()
        r.dur:SetPoint(group.durationPoint or "RIGHT", r.bar, group.durationPoint or "RIGHT",
            group.durationXOffset or -4, group.durationYOffset or 0)
        E:SetFont(r.dur, font, group.fontSize or 12, group.fontOutline or "OUTLINE")
        r.dur:Show()
        button:SetDurationText(r.dur, { textFormatter = AL and AL.DurFormatter() or nil })
    else
        button:ClearDurationText()
        if r.dur then r.dur:SetText("") r.dur:Hide() end
    end

    if group.showStacks ~= false then
        r.count = r.count or r.overlay:CreateFontString(nil, "OVERLAY")
        r.count:ClearAllPoints()
        local anchorTo = (group.stackAnchor == "BAR" or group.iconEnabled == false or not r.iconBD)
            and r.bar or r.iconBD
        r.count:SetPoint(group.stackPoint or "CENTER", anchorTo, group.stackPoint or "CENTER",
            group.stackXOffset or 0, group.stackYOffset or 0)
        E:SetFont(r.count, font, group.stackFontSize or 12, group.fontOutline or "OUTLINE")
        r.count:Show()
        button:SetApplicationCount(r.count, {})
    else
        button:ClearApplicationCount()
        if r.count then r.count:SetText("") r.count:Hide() end
    end

    button:SetMouseMotionEnabled(true)
end

local function RenderTestBars(st, group)
    local pool = st.testBars
    if not (ns.CustomGroups and ns.CustomGroups.testMode) then
        if pool then for _, f in ipairs(pool) do f:Hide() end end
        return false
    end
    st.testBars = pool or {}
    pool = st.testBars

    local sp = group.spacing or 2
    local W = st.effW or group.width or 220
    local H = st.effH or group.height or 22
    local up = group.growth == "UP"
    local font = LSM:Fetch("font", group.font or "Expressway")
    local lineX, row, idx = 0, 0, 0
    local entries = M.Entries(group)
    local counts = {}
    for i, e in ipairs(entries) do
        counts[i] = math.max(1, e.def.max or 1)
    end

    for ei, e in ipairs(entries) do
        local spells = (ns.AuraLane and ns.AuraLane.SpellList and ns.AuraLane.SpellList(e.def)) or {}
        for k = 1, counts[ei] do
            idx = idx + 1
            local f = pool[idx]
            if not f then
                f = CreateFrame("Frame", nil, st.frame, "BackdropTemplate")
                f:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
                f:SetBackdropColor(0, 0, 0, 0.6)
                f:SetBackdropBorderColor(0, 0, 0, 1)
                f.iconBD = CreateFrame("Frame", nil, f, "BackdropTemplate")
                f.iconBD:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
                f.iconBD:SetBackdropColor(0, 0, 0, 1)
                f.iconBD:SetBackdropBorderColor(0, 0, 0, 1)
                f.icon = f.iconBD:CreateTexture(nil, "ARTWORK")
                f.bar = CreateFrame("StatusBar", nil, f)
                f.bar:SetMinMaxValues(0, 1)
                f.name = f.bar:CreateFontString(nil, "OVERLAY")
                f.dur = f.bar:CreateFontString(nil, "OVERLAY")
                pool[idx] = f
            end

            local w = e.def.halfWidth and math.floor((W - sp) / 2) or W
            f:SetSize(w, H)
            if lineX > 0 and lineX + w > W then
                row = row + 1
                lineX = 0
            end
            local x, y = lineX, (H + sp) * row
            f:ClearAllPoints()
            if up then f:SetPoint("BOTTOMLEFT", st.frame, "BOTTOMLEFT", x, y)
            else f:SetPoint("TOPLEFT", st.frame, "TOPLEFT", x, -y) end
            lineX = lineX + w + sp

            local sid = spells[((k - 1) % math.max(1, #spells)) + 1] or M.FirstSpell(e.def)
            local off = 0
            if group.iconEnabled ~= false then
                f.iconBD:ClearAllPoints()
                f.iconBD:SetPoint("LEFT", f, "LEFT", 0, 0)
                f.iconBD:SetSize(H, H)
                f.icon:SetTexture((sid and C_Spell.GetSpellTexture(sid)) or 134400)
                local z = group.iconZoom or 0.1
                f.icon:SetTexCoord(z, 1 - z, z, 1 - z)
                f.icon:ClearAllPoints()
                f.icon:SetPoint("TOPLEFT", f.iconBD, "TOPLEFT", 1, -1)
                f.icon:SetPoint("BOTTOMRIGHT", f.iconBD, "BOTTOMRIGHT", -1, 1)
                f.iconBD:Show()
                off = H + (group.iconSpacing or 1)
            else
                f.iconBD:Hide()
            end

            f.bar:ClearAllPoints()
            f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", off + 1, -1)
            f.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
            f.bar:SetStatusBarTexture(LSM:Fetch("statusbar", group.statusBarTexture))
            if group.useClassColor ~= false then
                local c = E:ClassColor(E.myclass, true)
                f.bar:SetStatusBarColor(c.r, c.g, c.b)
            else
                local c = group.customColor or { r = 0.2, g = 0.6, b = 1 }
                f.bar:SetStatusBarColor(c.r, c.g, c.b)
            end
            f.bar:SetValue(0.7)

            if group.showName ~= false then
                E:SetFont(f.name, font, group.fontSize or 12, group.fontOutline or "OUTLINE")
                f.name:ClearAllPoints()
                f.name:SetPoint(group.namePoint or "LEFT", f.bar, group.namePoint or "LEFT",
                    group.nameXOffset or 4, group.nameYOffset or 0)
                f.name:SetText((sid and C_Spell.GetSpellName and C_Spell.GetSpellName(sid)) or "Buff")
                f.name:Show()
            else
                f.name:Hide()
            end
            if group.showDuration ~= false then
                E:SetFont(f.dur, font, group.fontSize or 12, group.fontOutline or "OUTLINE")
                f.dur:ClearAllPoints()
                f.dur:SetPoint(group.durationPoint or "RIGHT", f.bar, group.durationPoint or "RIGHT",
                    group.durationXOffset or -4, group.durationYOffset or 0)
                f.dur:SetText("12")
                f.dur:Show()
            else
                f.dur:Hide()
            end
            f.stacks = f.stacks or f.bar:CreateFontString(nil, "OVERLAY")
            if group.showStacks ~= false then
                E:SetFont(f.stacks, font, group.stackFontSize or 12, group.fontOutline or "OUTLINE")
                f.stacks:ClearAllPoints()
                local anchorTo = (group.stackAnchor == "BAR" or group.iconEnabled == false) and f.bar or f.iconBD
                f.stacks:SetPoint(group.stackPoint or "CENTER", anchorTo, group.stackPoint or "CENTER",
                    group.stackXOffset or 0, group.stackYOffset or 0)
                f.stacks:SetText("3")
                f.stacks:Show()
            else
                f.stacks:Hide()
            end
            f:Show()
        end
    end
    for k = idx + 1, #pool do pool[k]:Hide() end
    return true
end

local function EnsureState(group)
    local st = state[group.id]
    if st then return st end
    local frame = CreateFrame("Frame", "TUI_CustomBars" .. group.id, UIParent)
    frame:SetFrameStrata("MEDIUM")
    local container = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
    st = { frame = frame, container = container,
           regions = {}, keys = {}, defByKey = {}, keyByButton = {} }
    state[group.id] = st
    return st
end

local function EnsureMover(st, group)
    if moverMade[group.id] then return end
    local ms = ns.MoverSync
    if not (ms and ms.CreateManaged) then return end
    ms.CreateManaged(st.frame, "TUI_CustomBarsMover" .. group.id, group.name or ("Bar Group " .. group.id), {
        configString  = "thingsUI,modulesTab,customBars",
        shouldDisable = function() return not M.GroupByID(group.id) end,
        onSave = function(point, relPoint, x, y)
            local g = M.GroupByID(group.id)
            if not g then return end
            g.anchorPoint = point
            g.anchorRelativePoint = relPoint
            g.anchorXOffset = x
            g.anchorYOffset = y
            TUI:UpdateCustomBars()
            ns.NotifyChange()
        end,
    })
    moverMade[group.id] = true
end

local function ApplyEntryTo(st, group, entry, ord)
    local key = "CB" .. group.id .. "_" .. entry.uid:gsub("[^%w]", "")
    local def = entry.def

    local filter
    if def.kind == "HARMFUL" then
        filter = "HARMFUL|PLAYER"
    else
        filter = def.onlyMine and "HELPFUL|PLAYER" or "HELPFUL"
    end

    local map = {}
    for id in pairs(def.spells or {}) do
        local n = tonumber(id)
        if n then map[n] = true end
    end

    local sp = group.spacing or 2
    local w = st.effW or group.width or 220
    if def.halfWidth then w = math.floor((w - sp) / 2) end

    local layout = {
        elementWidth = w,
        elementHeight = st.effH or group.height or 22,
        elementSpacing = sp,
        lineSpacing = sp,
        layoutIndex = ord,
    }

    local maxCount = math.max(1, def.max or 1)
    local sortMethod, sortDir
    if ns.AuraLane and ns.AuraLane.SortFor then
        sortMethod, sortDir = ns.AuraLane.SortFor(def)
    end
    st.defByKey[key] = def
    if st.container:HasAuraGroup(key) then
        st.container:SetAuraGroupMaxFrameCount(key, maxCount)
        st.container:SetAuraGroupFilterString(key, filter)
        st.container:SetAuraGroupCandidateFilters(key, { includeSpellIDs = map })
        st.container:SetAuraGroupLayout(key, layout)
        if sortMethod then st.container:SetAuraGroupSortMethod(key, sortMethod, sortDir) end
    else
        st.container:AddAuraGroup(key, filter, {
            maxFrameCount = maxCount,
            sortMethod = sortMethod,
            sortDirection = sortDir,
            candidateFilters = { includeSpellIDs = map },
            layout = layout,
            initializeFrame = function(button)
                st.keyByButton[button] = key
                local r = st.regions[button]
                if not r then r = {}; st.regions[button] = r end
                StyleBar(button, r, st.group or group, st.defByKey[key] or def)
            end,
        })
    end
    st.keys[key] = true
    return key
end

local function SyncGroup(group)
    if not (ns.AuraLane and ns.AuraLane.Ready and ns.AuraLane.Ready()) then return end
    local st = EnsureState(group)
    st.group = group
    local frame, c = st.frame, st.container

    local af = group.anchorFrame or "UIParent"
    if af == "CUSTOM" then af = group.anchorFrameCustom or "UIParent" end
    local target = (af ~= "UIParent")
        and ((ns.ANCHORS and ns.ANCHORS.ResolveAnchorTarget and ns.ANCHORS.ResolveAnchorTarget(af)) or _G[af])
        or nil

    local effW = group.width or 220
    local effH = group.height or 22
    if target then
        if group.inheritWidth then
            local aw = target:GetWidth()
            if aw and aw > 0 then effW = aw + (group.inheritWidthOffset or 0) end
        end
        if group.inheritHeight then
            local ah = target:GetHeight()
            if ah and ah > 0 then effH = ah + (group.inheritHeightOffset or 0) end
        end
    end
    st.effW, st.effH = effW, effH

    ns.Pixel.SetSize(frame, effW, effH)
    frame:ClearAllPoints()
    ns.Pixel.SetPoint(frame, group.anchorPoint or "CENTER", target or _G.UIParent,
        group.anchorRelativePoint or "CENTER", group.anchorXOffset or 0, group.anchorYOffset or 0)
    EnsureMover(st, group)
    frame:Show()

    if RenderTestBars(st, group) then
        c:Hide()
        return
    end

    if InCombatLockdown() then pendingSync = true return end

    local entries = M.Entries(group)
    if not group.enabled or #entries == 0 then
        for key in pairs(st.keys) do c:SetAuraGroupMaxFrameCount(key, 0) end
        c:Hide()
        return
    end

    local up = group.growth == "UP"
    local pt = up and "BOTTOMLEFT" or "TOPLEFT"
    c:ClearAllPoints()
    c:SetSize(effW, effH)
    c:SetPoint(pt, frame, pt, 0, 0)
    c:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
    c:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    c:SetFlowLayoutAnchorPoint(pt)
    c:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right,
        up and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
    if c.SetFlowLayoutPadding then c:SetFlowLayoutPadding(0, 0, 0, 0) end
    c:SetFlowLayoutMaximumLineSize(effW)

    local wanted = {}
    for i, entry in ipairs(entries) do
        wanted[ApplyEntryTo(st, group, entry, i)] = true
    end
    for key in pairs(st.keys) do
        if not wanted[key] then c:SetAuraGroupMaxFrameCount(key, 0) end
    end

    local unit = group.unit or "player"
    if st.unit ~= unit then
        c:SetUnit(unit)
        st.unit = unit
        if c.UpdateAllAuras then c:UpdateAllAuras() end
    end

    st.pureHarmful = true
    for _, entry in ipairs(entries) do
        if entry.def.kind ~= "HARMFUL" then st.pureHarmful = false break end
    end

    for button, r in pairs(st.regions) do
        local key = st.keyByButton[button]
        local def = key and st.defByKey[key]
        if def then StyleBar(button, r, group, def) end
    end
    if unit ~= "player" and st.pureHarmful then
        c:SetShown(not (UnitExists(unit) and UnitCanAssist("player", unit)))
    else
        c:Show()
    end
end

local cbUpdateQueued = false
function TUI:QueueCustomBarsUpdate()
    if cbUpdateQueued then return end
    cbUpdateQueued = true
    C_Timer.After(0, function()
        cbUpdateQueued = false
        if TUI.UpdateCustomBars then TUI:UpdateCustomBars() end
    end)
end

function TUI:UpdateCustomBars()
    if not (E.db.thingsUI and Root()) then return end
    local live = {}
    for _, g in ipairs(M.GetGroups()) do
        live[g.id] = true
        SyncGroup(g)
    end
    for id, st in pairs(state) do
        if not live[id] then
            if InCombatLockdown() then
                pendingSync = true
            elseif st.container then
                for key in pairs(st.keys) do st.container:SetAuraGroupMaxFrameCount(key, 0) end
            end
            st.frame:Hide()
        end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_FOCUS_CHANGED")
ev:RegisterUnitEvent("UNIT_PET", "player")
ev:RegisterEvent("CINEMATIC_STOP")
ev:RegisterEvent("STOP_MOVIE")
ev:SetScript("OnEvent", function(_, event)

    if event == "PLAYER_ENTERING_WORLD" or event == "CINEMATIC_STOP" or event == "STOP_MOVIE" then
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(1, function() TUI:UpdateCustomBars() end)
        end
        local function reparse()
            for _, st in pairs(state) do
                if st.container.UpdateAllAuras then st.container:UpdateAllAuras() end
            end
        end
        C_Timer.After(0.1, reparse)
        C_Timer.After(2, reparse)
        C_Timer.After(5, reparse)
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if not pendingSync then return end
        pendingSync = false
        TUI:UpdateCustomBars()
        return
    end
    local want = (event == "PLAYER_FOCUS_CHANGED") and "focus"
        or (event == "UNIT_PET") and "pet" or "target"
    for _, st in pairs(state) do
        if st.unit == want then
            if st.pureHarmful then
                st.container:SetShown(not (UnitExists(want) and UnitCanAssist("player", want)))
            end
            st.container:SetUnit(want)
            if st.container.UpdateAllAuras then st.container:UpdateAllAuras() end
        end
    end
end)
