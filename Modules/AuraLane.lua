local addon, ns = ...
local TUI = ns.TUI
local E, L, V, P, G = unpack(ElvUI)
local LSM = E.Libs and E.Libs.LSM

local A = {}
ns.AuraLane = A

local lanes = {}
local pendingSync = false
local Teardown

local FLOW_UP, FLOW_DOWN, FLOW_LEFT, FLOW_RIGHT
local AXIS_V, AXIS_H

local function Ready()
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end
    if not (AnchorUtil and AnchorUtil.FlowLayoutAxis and AnchorUtil.FlowDirection) then return false end
    FLOW_UP, FLOW_DOWN = AnchorUtil.FlowDirection.Up, AnchorUtil.FlowDirection.Down
    FLOW_LEFT, FLOW_RIGHT = AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Right
    AXIS_V, AXIS_H = AnchorUtil.FlowLayoutAxis.Vertical, AnchorUtil.FlowLayoutAxis.Horizontal
    return true
end

A.Ready = Ready

function A.DB(group)
    group.auras = group.auras or {}
    return group.auras
end

function A.SpellList(def)
    local out = {}
    for id in pairs((def and def.spells) or {}) do
        local n = tonumber(id)
        if n then out[#out + 1] = n end
    end
    table.sort(out)
    return out
end

function A.SpellListUnique(def)
    local out, seen = {}, {}
    for _, id in ipairs(A.SpellList(def)) do
        local nm = (C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or id
        if not seen[nm] then
            seen[nm] = true
            out[#out + 1] = id
        end
    end
    return out
end

function A.Entries(group)
    if not group then return {} end
    local out = {}

    local order = group.scopeOrder or { "global", "class", "spec" }
    for si, scope in ipairs(order) do
        local root = ns.CustomGroups.GetScopeRoot(group, scope, nil, false)
        for uid, def in pairs((root and root.auras) or {}) do
            if def.enabled ~= false and next(def.spells or {}) then
                out[#out + 1] = {
                    key = ("TUIAura%d_%s_%s"):format(group.id or 0, scope,
                        tostring(uid):gsub("[^%w]", "")),
                    def = def,
                    rank = si * 100000 + (def.layoutIndex or 999),
                }
            end
        end
    end

    local SB = ns.SpecialBars
    if SB and SB.GetIconCount and SB.GetIconDB then
        local siSpec = 3
        for i, s in ipairs(order) do
            if s == "spec" then siSpec = i break end
        end
        for i = 1, SB.GetIconCount() do
            local ikey = "icon" .. i
            local idb = SB.GetIconDB(ikey)
            if idb and idb.enabled and idb.spellID and idb.customGroup == group.id and not idb.totemTimer then
                local spells = (ns.SpecialAura and ns.SpecialAura.ExpandSpellIDs
                    and ns.SpecialAura.ExpandSpellIDs(idb.spellID)) or { [idb.spellID] = true }
                local rank = siSpec * 100000 + (idb.customGroupOrder or 20000)
                out[#out + 1] = {
                    key = ("TUIAura%d_si_%s"):format(group.id or 0, ikey),
                    def = { spells = spells, max = 1, iconDB = idb },
                    rank = rank,
                }
                out[#out + 1] = {
                    key = ("TUIAura%d_siT_%s"):format(group.id or 0, ikey),
                    def = { spells = spells, max = 1, iconDB = idb, kind = "HARMFUL", unit = "target",
                        previewSkip = true },
                    rank = rank + 1,
                }
            end
        end
    end

    table.sort(out, function(x, y)
        if x.rank ~= y.rank then return x.rank < y.rank end
        return x.key < y.key
    end)
    return out
end

function A.HasSets(group)
    return #A.Entries(group) > 0
end

local playerAssistOK = true

function A.PlayerAssistOK()
    return playerAssistOK
end

local function SideVisOK(unit, pureHarm, hasHarm)
    if unit == "player" then
        return pureHarm or playerAssistOK
    end

    local assist = (UnitExists(unit) and UnitCanAssist("player", unit)) and true or false
    if not pureHarm and not assist then return false end
    if hasHarm and assist then return false end
    return true
end

local function LaneVisOK(lane)
    return SideVisOK(lane.unit or "player", lane.pureHarmful, lane.hasHarmful)
end

local function LaneVisOKT(lane)
    if not lane.unitT then return false end
    return SideVisOK(lane.unitT, lane.pureHarmfulT, lane.hasHarmfulT)
end

local durFormatter
local function Formatter()
    if durFormatter then return durFormatter end
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return nil end
    durFormatter = C_StringUtil.CreateNumericRuleFormatter()
    durFormatter:SetBreakpoints({
        {
            threshold = 60,
            rounding = Enum.NumericRuleFormatRounding.Down,
            format = "%dm",
            components = { { div = 60, step = 1, rounding = Enum.NumericRuleFormatRounding.Down } },
        },
        { threshold = 0, step = 1, rounding = Enum.NumericRuleFormatRounding.Up, format = "%d" },
    })
    return durFormatter
end

A.DurFormatter = Formatter

local colourCache = {}
local function ThresholdColour(group)
    local t = group.auras or {}
    if t.colorThreshold == false then return nil end
    local sec = math.min(math.max(tonumber(t.thresholdSeconds) or 3, 0.1), 59.9)
    local c = t.thresholdColor or { r = 1, g = 0.3, b = 0.3 }
    local n = (group.text and group.text.cooldownColor) or { r = 1, g = 1, b = 1 }
    local key = ("%d:%.1f:%.2f,%.2f,%.2f:%.2f,%.2f,%.2f")
        :format(group.id or 0, sec, c.r, c.g, c.b, n.r, n.g, n.b)
    local hit = colourCache[key]
    if hit then return hit end
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve) then return nil end
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0, CreateColor(c.r, c.g, c.b, 1))
    curve:AddPoint(sec, CreateColor(n.r, n.g, n.b, 1))
    hit = { curve = curve, property = Enum.DurationTextBindingProperty.RemainingDuration }
    colourCache[key] = hit
    return hit
end

local sourceOK
function A.CanShowSource(button)
    if sourceOK == nil and button then
        sourceOK = type(button.SetSourceName) == "function"
            and type(button.ClearSourceName) == "function"
    end
    return sourceOK == true
end

function A.SourceProbed()
    return sourceOK ~= nil
end

local pandemicOK
function A.CanPandemic(button)
    if pandemicOK == nil and button then
        pandemicOK = type(button.AddPandemicRegion) == "function"
    end
    return pandemicOK == true
end


local BORDER_BLACK = {}
local function Font(name, size, outline)
    local path = (LSM and LSM:Fetch("font", name or "Expressway")) or STANDARD_TEXT_FONT
    return path, size, outline
end

local function StyleButton(button, group, lane)
    local S = lane.slot
    if not S then return end
    ns.Pixel.SetSize(button, S.iw, S.ih)

    local r = lane.regions[button]
    if not r then
        r = {}
        r.icon = button:CreateTexture(nil, "ARTWORK")
        A.NoSnap(r.icon)
        r.icon:SetAllPoints(button)
        button:SetIcon(r.icon)
        r.overlay = CreateFrame("Frame", nil, button)
        r.overlay:SetAllPoints(button)
        lane.regions[button] = r
    end
    r.overlay:SetFrameLevel(button:GetFrameLevel() + 3)
    ns.CustomGroups.ApplyIconSkin(button, r.icon, S.crop, S.skin)

    local key = lane.keyByButton[button]
    local def = key and lane.defByKey[key]

    local idb = def and def.iconDB
    local au = group.auras or {}

    local t = S.text or group.text or {}
    if idb and idb.overrideGroupText then
        t = {
            showCooldown = idb.showDuration ~= false,
            cooldownFont = idb.durationFont,
            cooldownFontSize = idb.durationFontSize,
            cooldownFontOutline = idb.durationFontOutline,
            cooldownColor = idb.durationColor,
            cooldownPoint = idb.durationPoint,
            cooldownXOffset = idb.durationXOffset,
            cooldownYOffset = idb.durationYOffset,
            showStacks = idb.showStacks and true or false,
            stacksFont = idb.stackFont,
            stacksFontSize = idb.stackFontSize,
            stacksFontOutline = idb.stackFontOutline,
            stacksColor = idb.stackColor,
            stacksPoint = idb.stackPoint,
            stacksXOffset = idb.stackXOffset,
            stacksYOffset = idb.stackYOffset,
        }
    end

    local bShow, bSize, bInset, bColor = group.showBorder,
        group.borderSize or 1, group.borderInset or 0, group.borderColor
    local gau = group.auras
    if bShow and gau and gau.sortGlow and gau.sortGlowBorderStroke and (gau.sortMode or "manual") ~= "manual"
        and (gau.sortGlowStyle or "pulse") == "pixel" then
        bSize = gau.sortGlowThickness or bSize
    end
    if idb and idb.showBorder then
        bShow, bSize, bInset, bColor = true,
            idb.borderSize or 1, idb.borderInset or 0, idb.borderColor
        if idb.glowBorderStroke and idb.showGlow and A.MapGlowStyle(idb.glowType) == "pixel" then bSize = idb.glowThickness or bSize end
    end
    local SBm = ns.SpecialBars
    local st = (not idb) and def and def.styleName and SBm and SBm.Styles
        and SBm.Styles.Get("icons", def.styleName)
    if st then
        bShow, bSize, bInset, bColor = st.showBorder, st.borderSize or 1, st.borderInset or 0, st.borderColor
        if bShow and st.glowBorderStroke and st.showGlow and A.MapGlowStyle(st.glowType) == "pixel" then
            bSize = st.glowThickness or bSize
        end
    end

    if bShow then
        if not r.border then
            r.border = {}
            for i = 1, 4 do r.border[i] = button:CreateTexture(nil, "OVERLAY") end
        end
        A.EdgeRing(button, r.border, bSize, bInset, bColor or BORDER_BLACK)
    elseif r.border then
        for _, tex in ipairs(r.border) do tex:Hide() end
    end
    if r.borderIn then
        for i = 1, 4 do r.borderIn[i]:Hide() r.borderOut[i]:Hide() end
    end

    if t.showCooldown ~= false then
        r.duration = r.duration or r.overlay:CreateFontString(nil, "OVERLAY")
        r.duration:ClearAllPoints()
        r.duration:SetPoint(t.cooldownPoint or "CENTER", button, t.cooldownPoint or "CENTER",
            t.cooldownXOffset or 0, t.cooldownYOffset or 0)
        E:SetFont(r.duration, Font(t.cooldownFont, t.cooldownFontSize or 16, t.cooldownFontOutline or "OUTLINE"))
        local cc = t.cooldownColor or {}
        r.duration:SetTextColor(cc.r or 1, cc.g or 1, cc.b or 1)
        r.duration:Show()
        button:SetDurationText(r.duration, { textFormatter = Formatter(), textColor = ThresholdColour(group) })
    else
        button:ClearDurationText()
        if r.duration then r.duration:SetText("") r.duration:Hide() end
    end

    if t.showStacks ~= false then
        r.count = r.count or r.overlay:CreateFontString(nil, "OVERLAY")
        r.count:ClearAllPoints()
        r.count:SetPoint(t.stacksPoint or "TOP", button, t.stacksPoint or "TOP",
            t.stacksXOffset or 0, t.stacksYOffset or 7)
        E:SetFont(r.count, Font(t.stacksFont, t.stacksFontSize or 11, t.stacksFontOutline or "OUTLINE"))
        local nc = t.stacksColor or {}
        r.count:SetTextColor(nc.r or 0, nc.g or 1, nc.b or 0)
        r.count:Show()
        button:SetApplicationCount(r.count, {})
    else
        button:ClearApplicationCount()
        if r.count then r.count:SetText("") r.count:Hide() end
    end

    local swipeOn = au.swipe ~= false
    local swipeRev = au.swipeInverse and true or false

    if swipeOn then
        if not r.cd then
            r.cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            r.cd:SetAllPoints(r.icon)
            r.cd:SetFrameLevel(button:GetFrameLevel() + 1)
            r.cd:SetDrawEdge(false)
            r.cd:SetHideCountdownNumbers(true)
        end
        r.cd:SetReverse(swipeRev)
        r.cd:Show()
        button:SetDurationCooldown(r.cd)
    else
        button:ClearDurationCooldown()
        if r.cd then r.cd:Hide() end
    end

    local fx = A.GlowOptsFor(group, def) or {}
    fx.w, fx.h = S.iw, S.ih
    fx.anchor = r.icon
    fx.pandemic = (idb and idb.showPandemic) or (def and def.showPandemic) or false
    fx.pandemicColor = def and def.pandemicColor
    A.ApplyButtonFX(button, r, fx)

    if def and def.showSource and A.CanShowSource(button) then
        r.source = r.source or r.overlay:CreateFontString(nil, "OVERLAY")
        r.source:ClearAllPoints()
        r.source:SetPoint(def.sourcePoint or "TOP", button, def.sourcePoint or "TOP",
            def.sourceXOffset or 0, def.sourceYOffset or 10)
        E:SetFont(r.source, Font(t.countFont, def.sourceFontSize or t.countFontSize or 12,
            t.countFontOutline or "OUTLINE"))
        local sc = def.sourceColor or {}
        r.source:SetTextColor(sc.r or 1, sc.g or 1, sc.b or 1)
        r.source:Show()
        button:SetSourceName(r.source, {})
        if button.SetSourceNameShortened then
            button:SetSourceNameShortened(def.sourceShortened ~= false)
        end
    else
        if A.CanShowSource(button) then button:ClearSourceName() end
        if r.source then r.source:SetText("") r.source:Hide() end
    end

    button:SetMouseMotionEnabled(au.tooltips and true or false)
end

local function LaneFor(group, frame)
    local lane = lanes[group.id]
    if lane then
        if lane.frame ~= frame then
            lane.tail:SetParent(frame)
            lane.container:SetParent(frame)
            if lane.containerT then lane.containerT:SetParent(frame) end
            lane.frame = frame
        end
        return lane
    end
    local tail = CreateFrame("Frame", "TUI_CustomGroup" .. group.id .. "_AuraTail", frame)
    local container = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
    lane = { frame = frame, tail = tail, container = container,
             regions = {}, keys = {}, defByKey = {}, keyByButton = {} }
    lanes[group.id] = lane
    return lane
end

local function FlowFor(S)
    if S.horizontal then
        return AXIS_H,
            (S.alongSign == 1) and FLOW_RIGHT or FLOW_LEFT,
            (S.crossSign == 1) and FLOW_UP or FLOW_DOWN
    end
    return AXIS_V,
        (S.crossSign == 1) and FLOW_RIGHT or FLOW_LEFT,
        (S.alongSign == 1) and FLOW_UP or FLOW_DOWN
end

local function ApplyFlowTo(container, S, entries, anchor, hDir, vDir)
    local total = 0
    for _, e in ipairs(entries) do total = total + math.max(1, e.def.max or 1) end
    local perLine = (S.perLine > 0) and S.perLine or math.max(total, 1)

    container:SetFlowLayoutAxis(S.horizontal and AXIS_H or AXIS_V)
    container:SetFlowLayoutAnchorPoint(anchor)
    container:SetFlowLayoutGrowthDirection(hDir, vDir)
    container:SetFlowLayoutMaximumLineSize(perLine * S.alongDim + (perLine - 1) * S.sp)

    if container.SetFlowLayoutPadding then
        container:SetFlowLayoutPadding(0, 0, 0, 0)
    end
end

local function ApplyFlow(lane, group, entries)
    local S = lane.slot
    local _, hDir, vDir = FlowFor(S)

    local anchor = S.pt
    if S.center then
        anchor = ((vDir == FLOW_UP) and "BOTTOM" or "TOP")
            .. ((hDir == FLOW_LEFT) and "RIGHT" or "LEFT")
    end

    ApplyFlowTo(lane.container, S, entries, anchor, hDir, vDir)
    return hDir, vDir
end

local function AttachSideFor(group, S)
    local side = group.attachSide
    if side and side ~= "AUTO" then return side end
    if S.horizontal then
        return (S.alongSign == 1) and "RIGHT" or "LEFT"
    end
    return (S.alongSign == 1) and "TOP" or "BOTTOM"
end

local function AttachLayout(side, sp, hDir, vDir, centered)
    local tH, tV = hDir, vDir
    local tPt, cPt, ox, oy
    if side == "TOP" then
        tV = FLOW_UP
        local h = (hDir == FLOW_LEFT) and "RIGHT" or "LEFT"
        tPt, cPt, ox, oy = "BOTTOM" .. h, "TOP" .. h, 0, sp
        if centered then tPt, cPt = "BOTTOM", "TOP" end
    elseif side == "BOTTOM" then
        tV = FLOW_DOWN
        local h = (hDir == FLOW_LEFT) and "RIGHT" or "LEFT"
        tPt, cPt, ox, oy = "TOP" .. h, "BOTTOM" .. h, 0, -sp
        if centered then tPt, cPt = "TOP", "BOTTOM" end
    elseif side == "LEFT" then
        tH = FLOW_LEFT
        local v = (vDir == FLOW_UP) and "BOTTOM" or "TOP"
        tPt, cPt, ox, oy = v .. "RIGHT", v .. "LEFT", -sp, 0
        if centered then tPt, cPt = "RIGHT", "LEFT" end
    else
        tH = FLOW_RIGHT
        local v = (vDir == FLOW_UP) and "BOTTOM" or "TOP"
        tPt, cPt, ox, oy = v .. "LEFT", v .. "RIGHT", sp, 0
        if centered then tPt, cPt = "LEFT", "RIGHT" end
    end
    local flowAnchor = tPt
    if centered then
        flowAnchor = ((tV == FLOW_UP) and "BOTTOM" or "TOP")
            .. ((tH == FLOW_LEFT) and "RIGHT" or "LEFT")
    end
    return tPt, cPt, ox, oy, tH, tV, flowAnchor
end

local function SortFor(def)
    local SM, SD = _G.AuraContainerSortMethod, _G.AuraContainerSortDirection
    if not (SM and SD) then return nil, nil end
    local mode = def.sort or "instance"
    if mode == "short" then return SM.ExpirationOnly, SD.Normal end
    if mode == "long" then return SM.ExpirationOnly, SD.Reverse end
    if mode == "new" then return SM.AuraInstanceIDOnly, SD.Reverse end
    return SM.AuraInstanceIDOnly, SD.Normal
end

A.SortFor = SortFor

local function ApplyEntry(lane, group, entry, ord, c)
    c = c or lane.container
    local key, def = entry.key, entry.def
    local prev = lane.keys[key]
    if prev and prev ~= true and prev ~= c then prev:SetAuraGroupMaxFrameCount(key, 0) end
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

    local layout = {
        elementWidth = lane.slot.iw,
        elementHeight = lane.slot.ih,
        elementSpacing = lane.slot.sp,
        lineSpacing = lane.slot.sp,
        layoutIndex = ord,
    }
    local sortMethod, sortDir = SortFor(def)
    local maxCount = math.max(1, def.max or 1)

    lane.defByKey[key] = def
    if c:HasAuraGroup(key) then
        c:SetAuraGroupMaxFrameCount(key, maxCount)
        c:SetAuraGroupFilterString(key, filter)
        c:SetAuraGroupCandidateFilters(key, { includeSpellIDs = map })
        c:SetAuraGroupLayout(key, layout)
        if sortMethod then c:SetAuraGroupSortMethod(key, sortMethod, sortDir) end
    else
        c:AddAuraGroup(key, filter, {
            maxFrameCount = maxCount,
            sortMethod = sortMethod,
            sortDirection = sortDir,
            candidateFilters = { includeSpellIDs = map },
            layout = layout,
            initializeFrame = function(button)
                lane.keyByButton[button] = key
                StyleButton(button, lane.group or group, lane)
            end,
        })
    end
    lane.keys[key] = c
end

function Teardown(groupID)
    local lane = lanes[groupID]
    if not lane then return end
    if InCombatLockdown() then pendingSync = true return end
    for key, owner in pairs(lane.keys) do
        if owner == true then owner = lane.container end
        owner:SetAuraGroupMaxFrameCount(key, 0)
    end
    lane.container:Hide()
    if lane.containerT then lane.containerT:Hide() end
    lane.tail:Hide()
end

function A.Sync(group, frame)
    if not (group and frame and frame._tuiSlot) then return end
    if ns.CustomGroups.testMode then
        local lane = lanes[group.id]
        if lane then
            lane.container:Hide()
            if lane.containerT then lane.containerT:Hide() end
        end
        return
    end
    if InCombatLockdown() then
        if lanes[group.id] or A.HasSets(group) then pendingSync = true end
        return
    end

    local entries = A.Entries(group)
    if #entries == 0 then
        local lane = lanes[group.id]
        if lane then
            for key, owner in pairs(lane.keys) do
                if owner == true then owner = lane.container end
                owner:SetAuraGroupMaxFrameCount(key, 0)
            end
            lane.container:Hide()
            if lane.containerT then lane.containerT:Hide() end
        end
        return
    end
    if not Ready() then return end

    local au0 = group.auras or {}
    local sortMode = au0.sortMode or "manual"
    if sortMode ~= "manual" then
        local altU
        for _, e in ipairs(entries) do
            local u = e.def.unit
            if u and u ~= "player" then altU = altU or u break end
        end
        local buckets = {
            { tag = "H",  kind = nil,       unit = nil,  spells = {}, any = false },
            { tag = "D",  kind = "HARMFUL", unit = nil,  spells = {}, any = false },
            { tag = "HT", kind = nil,       unit = altU, spells = {}, any = false },
            { tag = "DT", kind = "HARMFUL", unit = altU, spells = {}, any = false },
        }
        for _, e in ipairs(entries) do
            local d = e.def
            local isAlt = altU ~= nil and d.unit == altU
            local b
            if d.kind == "HARMFUL" then b = isAlt and buckets[4] or buckets[2]
            else b = isAlt and buckets[3] or buckets[1] end
            b.any = true
            for id in pairs(d.spells or {}) do b.spells[id] = true end
        end
        local cap = tonumber(group.maxIcons) or 0
        local maxN = (cap > 0) and cap or 40
        local merged = {}
        for i, b in ipairs(buckets) do
            if b.any then
                merged[#merged + 1] = {
                    key = ("TUIAura%d_merged%s"):format(group.id or 0, b.tag),
                    def = { spells = b.spells, max = maxN, sort = sortMode, kind = b.kind, unit = b.unit },
                    rank = i,
                }
            end
        end
        if au0.sortGlow then
            for _, m in ipairs(merged) do
                m.def.showGlow = true
                m.def.glowStyle = au0.sortGlowStyle or "pulse"
                m.def.glowColor = au0.sortGlowColor
                m.def.glowThickness = au0.sortGlowThickness
                m.def.glowLines = au0.sortGlowLines
                m.def.glowLength = au0.sortGlowLength
                m.def.glowOffset = au0.sortGlowOffset
                m.def.glowSpeed = au0.sortGlowSpeed
                m.def.glowBorderStroke = au0.sortGlowBorderStroke
            end
        end
        entries = merged
    end

    local lane = LaneFor(group, frame)
    lane.group = group
    lane.slot = frame._tuiSlot
    local S = lane.slot

    local slotIndex = ns.CustomGroups.NextFreeSlot(group, frame)
    local pt, tx, ty = ns.CustomGroups.SlotPoint(frame, slotIndex)
    lane.tail:ClearAllPoints()
    ns.Pixel.SetSize(lane.tail, S.iw, S.ih)
    ns.Pixel.SetPoint(lane.tail, pt, frame, pt, tx, ty)
    lane.tail:Show()

    local mainEntries, altEntries, altUnit = {}, {}, nil
    for _, e in ipairs(entries) do
        local u = e.def.unit
        if u and u ~= "player" then altUnit = altUnit or u end
    end
    for _, e in ipairs(entries) do
        if altUnit and e.def.unit == altUnit then
            altEntries[#altEntries + 1] = e
        else
            mainEntries[#mainEntries + 1] = e
        end
    end
    local split = #mainEntries > 0 and #altEntries > 0
    if not split then
        mainEntries, altEntries, altUnit = entries, {}, nil
    end

    local unit = "player"
    local hasPlayerSide = false
    for _, e in ipairs(mainEntries) do
        local u = e.def.unit
        if not u or u == "player" then hasPlayerSide = true break end
    end
    if not hasPlayerSide then
        for _, e in ipairs(mainEntries) do
            if e.def.unit then unit = e.def.unit break end
        end
    end

    lane.container:ClearAllPoints()
    lane.container:SetSize(S.iw, S.ih)
    lane.container:SetPoint(S.pt, lane.tail, S.pt, 0, 0)
    lane.container:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")

    local hDir, vDir = ApplyFlow(lane, group, mainEntries)

    if split and not lane.containerT then
        lane.containerT = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
    end
    local cT = lane.containerT
    if split then
        local side = AttachSideFor(group, S)
        local tPt, cPt, ox, oy, tH, tV, tAnchor = AttachLayout(side, S.sp, hDir, vDir, S.center)
        cT:ClearAllPoints()
        cT:SetSize(S.iw, S.ih)
        -- if adding target @ debuff icon to a group after its been active, it'll throw a taint.. needs a reload I guess sadge
        local anchored = pcall(cT.SetPoint, cT, tPt, lane.container, cPt, ox, oy)
        if not anchored then
            local totalMain = 0
            for _, e in ipairs(mainEntries) do totalMain = totalMain + math.max(1, e.def.max or 1) end
            local perLine = (S.perLine > 0) and S.perLine or math.max(totalMain, 1)
            local lineLen = math.min(perLine, math.max(totalMain, 1))
            local lines = math.max(1, math.ceil(math.max(totalMain, 1) / perLine))
            local alongExt = lineLen * S.alongDim + (lineLen - 1) * S.sp
            local crossExt = lines * S.crossDim + (lines - 1) * S.sp
            local spanX = S.horizontal and ((S.alongSign == 1) and alongExt or -alongExt)
                or ((S.crossSign == 1) and crossExt or -crossExt)
            local spanY = S.horizontal and ((S.crossSign == 1) and crossExt or -crossExt)
                or ((S.alongSign == 1) and alongExt or -alongExt)
            local minX, maxX = math.min(0, spanX), math.max(0, spanX)
            local minY, maxY = math.min(0, spanY), math.max(0, spanY)
            local cx
            if cPt:find("LEFT") then cx = minX elseif cPt:find("RIGHT") then cx = maxX else cx = (minX + maxX) / 2 end
            local cy
            if cPt:find("TOP") then cy = maxY elseif cPt:find("BOTTOM") then cy = minY else cy = (minY + maxY) / 2 end
            cT:ClearAllPoints()
            cT:SetPoint(tPt, lane.tail, S.pt, cx + ox, cy + oy)
        end
        cT:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
        ApplyFlowTo(cT, S, altEntries, tAnchor, tH, tV)
    end

    local wanted = {}
    for i, entry in ipairs(mainEntries) do
        ApplyEntry(lane, group, entry, i, lane.container)
        wanted[entry.key] = true
    end
    for i, entry in ipairs(altEntries) do
        ApplyEntry(lane, group, entry, i, cT)
        wanted[entry.key] = true
    end
    for key, owner in pairs(lane.keys) do
        if not wanted[key] then
            if owner == true then owner = lane.container end
            owner:SetAuraGroupMaxFrameCount(key, 0)
        end
    end

    if lane.unit ~= unit then
        lane.container:SetUnit(unit)
        lane.unit = unit
        if lane.container.UpdateAllAuras then lane.container:UpdateAllAuras() end
    end
    if split and lane.unitT ~= altUnit then
        cT:SetUnit(altUnit)
        lane.unitT = altUnit
        if cT.UpdateAllAuras then cT:UpdateAllAuras() end
    end
    if not split then lane.unitT = nil end

    local function Flags(list)
        local pure, has = true, false
        for _, entry in ipairs(list) do
            if entry.def.kind == "HARMFUL" then has = true else pure = false end
        end
        return pure, has
    end
    lane.pureHarmful, lane.hasHarmful = Flags(mainEntries)
    lane.pureHarmfulT, lane.hasHarmfulT = Flags(altEntries)

    for button in pairs(lane.regions) do
        if not pcall(StyleButton, button, group, lane) then pendingSync = true end
    end
    lane.container:SetShown(LaneVisOK(lane))
    if cT then cT:SetShown(split and LaneVisOKT(lane) or false) end
end

function A.Release(groupID)
    Teardown(groupID)
end

function A.ReparseAll()
    for _, lane in pairs(lanes) do
        if lane.container.UpdateAllAuras then lane.container:UpdateAllAuras() end
        if lane.containerT and lane.containerT.UpdateAllAuras then lane.containerT:UpdateAllAuras() end
    end
end

local function RefreshHelpfulVis()
    if not (ns.CustomGroups and ns.CustomGroups.testMode) then
        for _, lane in pairs(lanes) do
            lane.container:SetShown(LaneVisOK(lane))
            if lane.containerT then lane.containerT:SetShown(LaneVisOKT(lane)) end
        end
    end
    if ns.SpecialAura and ns.SpecialAura.RefreshVisibility then ns.SpecialAura.RefreshVisibility() end
    if ns.CustomBars and ns.CustomBars.RefreshVisibility then ns.CustomBars.RefreshVisibility() end
end

local function ReparseEverything()
    A.ReparseAll()
    if ns.SpecialAura and ns.SpecialAura.ReparseAll then ns.SpecialAura.ReparseAll() end
    if ns.CustomBars and ns.CustomBars.ReparseAll then ns.CustomBars.ReparseAll() end
end

local assistTicker
local function CheckPlayerAssist()
    local ok = not not UnitCanAssist("player", "player")
    if ok ~= playerAssistOK then
        playerAssistOK = ok
        RefreshHelpfulVis()
        if ok then ReparseEverything() end
    end
    if not ok then
        if not assistTicker then assistTicker = C_Timer.NewTicker(1, CheckPlayerAssist) end
    elseif assistTicker then
        assistTicker:Cancel()
        assistTicker = nil
    end
end

local function ReparseSoon()
    local function sweep()
        CheckPlayerAssist()
        A.ReparseAll()
    end
    C_Timer.After(0.1, sweep)
    C_Timer.After(2, sweep)
    C_Timer.After(5, sweep)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_FOCUS_CHANGED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("CINEMATIC_STOP")
ev:RegisterEvent("STOP_MOVIE")
ev:RegisterUnitEvent("UNIT_PET", "player")
ev:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
ev:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
ev:RegisterUnitEvent("UNIT_FLAGS", "player")
ev:RegisterEvent("PLAYER_CONTROL_LOST")
ev:RegisterEvent("PLAYER_CONTROL_GAINED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" or event == "CINEMATIC_STOP" or event == "STOP_MOVIE" then
        ReparseSoon()
        return
    end
    if event == "UNIT_EXITED_VEHICLE" or event == "PLAYER_CONTROL_GAINED" then
        CheckPlayerAssist()
        C_Timer.After(0.5, ReparseEverything)
        return
    end
    if event == "UNIT_ENTERED_VEHICLE" or event == "PLAYER_CONTROL_LOST" or event == "UNIT_FLAGS" then
        CheckPlayerAssist()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if not pendingSync then return end
        pendingSync = false
        if TUI and TUI.UpdateCustomGroups then TUI:UpdateCustomGroups() end
        return
    end

    local want = (event == "PLAYER_FOCUS_CHANGED") and "focus"
        or (event == "UNIT_PET") and "pet" or "target"
    for _, lane in pairs(lanes) do
        if lane.unit == want then
            if not (ns.CustomGroups and ns.CustomGroups.testMode) then
                lane.container:SetShown(LaneVisOK(lane))
            end
            lane.container:SetUnit(want)
            if lane.container.UpdateAllAuras then lane.container:UpdateAllAuras() end
        end
        if lane.unitT == want and lane.containerT then
            if not (ns.CustomGroups and ns.CustomGroups.testMode) then
                lane.containerT:SetShown(LaneVisOKT(lane))
            end
            lane.containerT:SetUnit(want)
            if lane.containerT.UpdateAllAuras then lane.containerT:UpdateAllAuras() end
        end
    end
end)
