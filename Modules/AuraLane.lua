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

    table.sort(out, function(x, y)
        if x.rank ~= y.rank then return x.rank < y.rank end
        return x.key < y.key
    end)
    return out
end

function A.HasSets(group)
    return #A.Entries(group) > 0
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

local function Font(name, size, outline)
    local path = (LSM and LSM:Fetch("font", name or "Expressway")) or STANDARD_TEXT_FONT
    return path, size, outline
end

local function StyleButton(button, group, lane, def)
    local S = lane.slot
    if not S then return end
    button:SetSize(S.iw, S.ih)

    local r = lane.regions[button]
    if not r then
        r = {}
        r.icon = button:CreateTexture(nil, "ARTWORK")
        r.icon:SetAllPoints(button)
        button:SetIcon(r.icon)
        r.overlay = CreateFrame("Frame", nil, button)
        r.overlay:SetAllPoints(button)
        lane.regions[button] = r
    end
    r.overlay:SetFrameLevel(button:GetFrameLevel() + 3)
    ns.CustomGroups.ApplyIconSkin(button, r.icon, S.crop, S.skin)

    local t = S.text or group.text or {}
    local au = group.auras or {}

    if group.showBorder then
        if not r.border then
            r.border = {}
            for i = 1, 4 do r.border[i] = button:CreateTexture(nil, "OVERLAY") end
        end
        local bs, bi = group.borderSize or 1, group.borderInset or 0
        local bc = group.borderColor or { r = 0, g = 0, b = 0, a = 1 }
        for _, tex in ipairs(r.border) do
            tex:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
            tex:ClearAllPoints()
            tex:Show()
        end
        r.border[1]:SetPoint("TOPLEFT", button, "TOPLEFT", bi, -bi)
        r.border[1]:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", -bi, -bi - bs)
        r.border[2]:SetPoint("TOPLEFT", button, "BOTTOMLEFT", bi, bi + bs)
        r.border[2]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -bi, bi)
        r.border[3]:SetPoint("TOPLEFT", button, "TOPLEFT", bi, -bi)
        r.border[3]:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", bi + bs, bi)
        r.border[4]:SetPoint("TOPLEFT", button, "TOPRIGHT", -bi - bs, -bi)
        r.border[4]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -bi, bi)
    elseif r.border then
        for _, tex in ipairs(r.border) do tex:Hide() end
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

    if t.showCount ~= false then
        r.count = r.count or r.overlay:CreateFontString(nil, "OVERLAY")
        r.count:ClearAllPoints()
        r.count:SetPoint(t.countPoint or "BOTTOMRIGHT", button, t.countPoint or "BOTTOMRIGHT",
            t.countXOffset or -1, t.countYOffset or 1)
        E:SetFont(r.count, Font(t.countFont, t.countFontSize or 12, t.countFontOutline or "OUTLINE"))
        local nc = t.countColor or {}
        r.count:SetTextColor(nc.r or 1, nc.g or 1, nc.b or 1)
        r.count:Show()
        button:SetApplicationCount(r.count, {})
    else
        button:ClearApplicationCount()
        if r.count then r.count:SetText("") r.count:Hide() end
    end

    if au.swipe ~= false then
        if not r.cd then
            r.cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            r.cd:SetAllPoints(r.icon)
            r.cd:SetFrameLevel(button:GetFrameLevel() + 1)
            r.cd:SetDrawEdge(false)
            r.cd:SetHideCountdownNumbers(true)
        end
        r.cd:SetReverse(au.swipeInverse and true or false)
        r.cd:Show()
        button:SetDurationCooldown(r.cd)
    else
        button:ClearDurationCooldown()
        if r.cd then r.cd:Hide() end
    end

    def = def or lane.defByButton[button]
    if def then lane.defByButton[button] = def end

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
            lane.frame = frame
        end
        return lane
    end
    local tail = CreateFrame("Frame", "TUI_CustomGroup" .. group.id .. "_AuraTail", frame)
    local container = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
    lane = { frame = frame, tail = tail, container = container,
             regions = {}, keys = {}, defByButton = {} }
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

local function ApplyFlow(lane, group, entries)
    local S = lane.slot
    local total = 0
    for _, e in ipairs(entries) do total = total + math.max(1, e.def.max or 1) end
    local perLine = (S.perLine > 0) and S.perLine or math.max(total, 1)
    local axis, hDir, vDir = FlowFor(S)

    lane.container:SetFlowLayoutAxis(axis)
    lane.container:SetFlowLayoutAnchorPoint(S.pt)
    lane.container:SetFlowLayoutGrowthDirection(hDir, vDir)
    lane.container:SetFlowLayoutMaximumLineSize(perLine * S.alongDim + (perLine - 1) * S.sp)

    if lane.container.SetFlowLayoutPadding then
        lane.container:SetFlowLayoutPadding(0, 0, 0, 0)
    end
end

local function SortFor(def)
    local SM, SD = _G.AuraContainerSortMethod, _G.AuraContainerSortDirection
    if not (SM and SD) then return nil, nil end
    local mode = def.sort or "instance"
    if mode == "short" then return SM.ExpirationOnly, SD.Normal end
    if mode == "long" then return SM.ExpirationOnly, SD.Reverse end
    return SM.AuraInstanceIDOnly, SD.Normal
end

local function ApplyEntry(lane, group, entry)
    local key, def = entry.key, entry.def
    -- 12.1 only sanctions YOUR debuffs on enemies; the choice doesn't exist
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
    }
    local sortMethod, sortDir = SortFor(def)
    local maxCount = math.max(1, def.max or 1)

    if lane.container:HasAuraGroup(key) then
        lane.container:SetAuraGroupMaxFrameCount(key, maxCount)
        lane.container:SetAuraGroupFilterString(key, filter)
        lane.container:SetAuraGroupCandidateFilters(key, { includeSpellIDs = map })
        lane.container:SetAuraGroupLayout(key, layout)
        if sortMethod then lane.container:SetAuraGroupSortMethod(key, sortMethod, sortDir) end
    else
        lane.container:AddAuraGroup(key, filter, {
            maxFrameCount = maxCount,
            sortMethod = sortMethod,
            sortDirection = sortDir,
            candidateFilters = { includeSpellIDs = map },
            layout = layout,
            initializeFrame = function(button) StyleButton(button, group, lane, def) end,
        })
    end
    lane.keys[key] = true
end

function Teardown(groupID)
    local lane = lanes[groupID]
    if not (lane and not InCombatLockdown()) then return end
    for key in pairs(lane.keys) do lane.container:SetAuraGroupMaxFrameCount(key, 0) end
    lane.container:Hide()
    lane.tail:Hide()
end

function A.Sync(group, frame)
    if not (group and frame and frame._tuiSlot) then return end
    if ns.CustomGroups.testMode then
        local lane = lanes[group.id]
        if lane then lane.container:Hide() end
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
            for key in pairs(lane.keys) do lane.container:SetAuraGroupMaxFrameCount(key, 0) end
            lane.container:Hide()
        end
        return
    end
    if not Ready() then return end

    local lane = LaneFor(group, frame)
    lane.slot = frame._tuiSlot
    local S = lane.slot

    local slotIndex = ns.CustomGroups.NextFreeSlot(group, frame)
    local pt, tx, ty = ns.CustomGroups.SlotPoint(frame, slotIndex)
    lane.tail:ClearAllPoints()
    ns.Pixel.SetSize(lane.tail, S.iw, S.ih)
    ns.Pixel.SetPoint(lane.tail, pt, frame, pt, tx, ty)
    lane.tail:Show()

    local unit = entries[1].def.unit or "player"
    lane.container:ClearAllPoints()
    lane.container:SetSize(S.iw, S.ih)
    lane.container:SetPoint(S.pt, lane.tail, S.pt, 0, 0)
    lane.container:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
    if lane.unit ~= unit then
        lane.container:SetUnit(unit)
        lane.unit = unit
    end

    ApplyFlow(lane, group, entries)

    local wanted = {}
    for _, entry in ipairs(entries) do
        ApplyEntry(lane, group, entry)
        wanted[entry.key] = true
    end
    for key in pairs(lane.keys) do
        if not wanted[key] then lane.container:SetAuraGroupMaxFrameCount(key, 0) end
    end

    for button in pairs(lane.regions) do StyleButton(button, group, lane) end
    lane.container:Show()
end

function A.Release(groupID)
    Teardown(groupID)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function()
    if not pendingSync then return end
    pendingSync = false
    if TUI and TUI.UpdateCustomGroups then TUI:UpdateCustomGroups() end
end)
