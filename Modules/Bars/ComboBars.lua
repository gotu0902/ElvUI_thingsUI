local _, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM

-- Aura Combo Bars: pieces that light while their auras are up. Blizzard's aura engine
-- lights Any/Count pieces (secret auras too); All/None pieces and the bar glow read the CDM.
ns.ComboBars = ns.ComboBars or {}
local M = ns.ComboBars

local D = ns.COMBO_BAR_DEFAULTS
local NP_ONLY = "INCLUDE_NAME_PLATE_ONLY"
local DIR_REMAINING = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime
local MAX_PIECES = 10
local issecret = issecretvalue
local WHITE = { r = 1, g = 1, b = 1, a = 1 }

local state = {}
local pending = false
local moverMade = {}

local function Root()
    local db = E.db.thingsUI
    db.comboBars = db.comboBars or {}
    local r = db.comboBars
    r.bars = r.bars or {}
    r.nextID = r.nextID or 1
    return r
end

function M.GetBars() return Root().bars end

function M.ByID(id)
    for _, b in ipairs(Root().bars) do
        if b.id == id then return b end
    end
end

function M.IndexOf(id)
    for i, b in ipairs(Root().bars) do
        if b.id == id then return i end
    end
end

local function G(bar, k)
    local v = bar[k]
    if v == nil then v = D[k] end
    return v
end
M.Get = G

local function CurSpec()
    local BS = ns.BarSetup
    return (BS and BS.GetCurrentSpecID and BS.GetCurrentSpecID()) or 0
end

function M.LoadedHere(bar)
    if not (bar and bar.enabled) then return false end
    local specs = bar.specs
    if specs and next(specs) then return specs[CurSpec()] == true end
    return true
end

function M.Pieces(seg)
    if seg.lights == "count" then return math.max(1, math.min(MAX_PIECES, seg.pieces or 3)) end
    return 1
end

-- a count needs one side: both would light the same pieces twice
function M.Side(seg)
    local s = seg.side or "auto"
    if seg.lights == "count" and s == "auto" then return "HARMFUL" end
    return s
end

local function LuaLit(seg) return seg.lights == "all" or seg.lights == "none" end
M.LuaLit = LuaLit

-- its own spells plus a linked collection's (spell-list collections only)
function M.SegSpells(seg)
    local out = {}
    for id in pairs(seg.spells or {}) do out[id] = true end
    local AC = ns.AuraCollections
    local c = seg.collection and AC and AC.Exists(seg.collection) and AC.Get(seg.collection)
    if c and not c.filters then
        for id in pairs(c.spells or {}) do out[id] = true end
    end
    return out
end

local function Expand(id)
    local SA = ns.SpecialAura
    return (SA and SA.ExpandSpellIDs and SA.ExpandSpellIDs(id)) or { [id] = true }
end

function M.SegLabel(seg, i)
    if seg.label and seg.label ~= "" then return seg.label end
    local AC = ns.AuraCollections
    local c = seg.collection and AC and AC.Exists(seg.collection) and AC.Get(seg.collection)
    if c then return c.name end
    local first
    for id in pairs(seg.spells or {}) do
        if not first or id < first then first = id end
    end
    return (first and C_Spell.GetSpellName(first)) or ("Minibar " .. tostring(i or "?"))
end

local function Cased(bar, str)
    if ns.TextCased then return ns.TextCased(bar, str) end
    return str
end

-- ------------------------------------------------------------------ aura state (Lua)

local lastUp = {}

local function PlainUp(ids, side)
    if side ~= "HARMFUL" then
        for id in pairs(ids) do
            if C_UnitAuras.GetPlayerAuraBySpellID(id) then return true end
        end
    end
    if side ~= "HELPFUL" and UnitExists("target") then
        for i = 1, 40 do
            local a = C_UnitAuras.GetAuraDataByIndex("target", i, "HARMFUL|PLAYER")
            if not a then break end
            local sid = a.spellId
            if not (issecret and issecret(sid)) and ids[sid] then return true end
        end
    end
    return false
end

-- one aura up: the CDM's answer holds in combat, plain reads only out of it
-- (an untracked aura keeps its last answer in combat); 2nd return = the CDM follows it
function M.AuraUp(id, side)
    local ids = Expand(id)
    local CI = ns.CDMIcons
    local up = CI and CI.AuraUp and CI.AuraUp(ids)
    if up ~= nil then
        lastUp[id] = up
        return up, true
    end
    if InCombatLockdown() then return lastUp[id] or false, false end
    up = PlainUp(ids, side)
    lastUp[id] = up
    return up, false
end

-- lit (a count: full), how many are up, every aura followed by the CDM
function M.SegState(seg)
    local side = M.Side(seg)
    local up, n, tracked = 0, 0, true
    for id in pairs(M.SegSpells(seg)) do
        n = n + 1
        local u, t = M.AuraUp(id, side)
        if u then up = up + 1 end
        if not t then tracked = false end
    end
    local lit
    if seg.lights == "all" then lit = n > 0 and up == n
    elseif seg.lights == "none" then lit = up == 0
    elseif seg.lights == "count" then lit = up >= M.Pieces(seg)
    else lit = up > 0 end
    return lit, up, tracked
end

local function NeedsLua(bar)
    if G(bar, "glowWhen") ~= "off" then return true end
    for _, seg in ipairs(bar.segments or {}) do
        if LuaLit(seg) then return true end
    end
    return false
end
M.NeedsLua = NeedsLua

-- auras the Lua side reads that Blizzard's CDM doesn't follow (they go stale in combat)
function M.Untracked(bar)
    local out, seen = {}, {}
    local glow = G(bar, "glowWhen") ~= "off"
    local CI = ns.CDMIcons
    for _, seg in ipairs(bar.segments or {}) do
        if glow or LuaLit(seg) then
            for id in pairs(M.SegSpells(seg)) do
                if not seen[id] and not (CI and CI.AuraUp and CI.AuraUp(Expand(id)) ~= nil) then
                    seen[id] = true
                    out[#out + 1] = id
                end
            end
        end
    end
    table.sort(out)
    return out
end

-- ------------------------------------------------------------------ glow

function M.GlowOpts(bar)
    return {
        style = G(bar, "glowType"), color = G(bar, "glowColor"), thickness = G(bar, "glowThickness"),
        lines = G(bar, "glowLines"), length = G(bar, "glowLength"),
        frequency = math.abs(G(bar, "glowSpeed")), offset = G(bar, "glowOffset"),
    }
end

local function SetGlow(host, store, on, opts, w, h)
    local A = ns.AuraLane
    if not (A and A.ApplyButtonFX) then return end
    if on then
        opts.w, opts.h = w, h
        A.ApplyButtonFX(host, store, opts)
        store.tuiOn = true
    elseif store.tuiOn then
        A.ApplyButtonFX(host, store, {})
        store.tuiOn = nil
    end
end

-- ------------------------------------------------------------------ frames

local function TestMode() return ns.CustomGroups and ns.CustomGroups.testMode end

local function PlayerOK()
    local AL = ns.AuraLane
    if AL and AL.PlayerAssistOK then return AL.PlayerAssistOK() end
    return true
end

local function TargetOK()
    return not (UnitExists("target") and UnitCanAssist("player", "target"))
end

local function EnsureState(bar)
    local st = state[bar.id]
    if st then return st end
    local f = CreateFrame("Frame", "TUI_ComboBar_" .. bar.id, UIParent)
    f:SetSize(220, 12)
    f:SetPoint("CENTER")
    f:Hide()
    local top = CreateFrame("Frame", nil, f)
    top:SetAllPoints(f)
    st = { frame = f, top = top, pieces = {}, segs = {}, fx = {}, id = bar.id }
    f:SetScript("OnSizeChanged", function()
        if st.bar and not st.laying then M.QueueRefresh() end
    end)
    state[bar.id] = st
    return st
end

local function Piece(st, k)
    local p = st.pieces[k]
    if not p then
        p = CreateFrame("Frame", nil, st.frame, "BackdropTemplate")
        p.lit = p:CreateTexture(nil, "ARTWORK")
        p.lit:Hide()
        st.pieces[k] = p
    end
    return p
end

local function Seg(st, i)
    local ss = st.segs[i]
    if not ss then
        local host = CreateFrame("Frame", nil, st.frame)
        ss = { host = host, regions = {}, fx = {} }
        ss.label = host:CreateFontString(nil, "OVERLAY", nil, 0)
        ss.litLabel = host:CreateFontString(nil, "OVERLAY", nil, 1)
        ss.barLabel = st.top:CreateFontString(nil, "OVERLAY")
        st.segs[i] = ss
    end
    return ss
end

local function StylePiece(p, bar, px, tex)
    local border = G(bar, "showBorder")
    p:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = border and E.media.blankTex or nil,
        edgeSize = border and px or nil })
    local ec = G(bar, "emptyColor")
    p:SetBackdropColor(ec.r, ec.g, ec.b, ec.a or 1)
    if border then
        local bc = G(bar, "borderColor")
        p:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a or 1)
    end
    local inset = border and px or 0
    p.lit:ClearAllPoints()
    p.lit:SetPoint("TOPLEFT", p, "TOPLEFT", inset, -inset)
    p.lit:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -inset, inset)
    p.lit:SetTexture(tex)
end

-- where every segment's pieces and aura frames go; our own frames only (fine in combat)
local function LayoutBar(bar, st)
    st.laying = true
    local f = st.frame
    local text = G(bar, "display") == "text"
    local segs = bar.segments or {}
    local px = ns.Pixel.Size(f)
    local tex = LSM:Fetch("statusbar", G(bar, "statusBarTexture"))
    local font = LSM:Fetch("font", G(bar, "font"))
    local fsize, outline = G(bar, "fontSize"), G(bar, "fontOutline")
    local border = G(bar, "showBorder")
    local k = 0

    st.top:SetFrameLevel(f:GetFrameLevel() + 8)
    if text then
        local h = fsize + 4
        local pip = math.max(4, math.floor(fsize * 0.6 + 0.5))
        local durW = G(bar, "showDuration") and math.floor(fsize * 2.2 + 0.5) or 0
        local sp = G(bar, "textSpacing")
        local cells, sum = {}, 0
        for i, seg in ipairs(segs) do
            local ss = Seg(st, i)
            E:SetFont(ss.label, font, fsize, outline)
            ss.text = Cased(bar, M.SegLabel(seg, i))
            ss.label:SetText(ss.text)
            local lw = math.ceil(ss.label:GetStringWidth() or 0)
            local n = M.Pieces(seg)
            local w
            if seg.lights == "count" then
                w = lw + 4 + n * pip + (n - 1) * 2
            else
                w = lw + ((durW > 0 and not LuaLit(seg)) and (durW + 3) or 0)
            end
            cells[i] = { lw = lw, w = w }
            sum = sum + w + (i > 1 and sp or 0)
        end
        if not st.stacked then ns.Pixel.SetSize(f, math.max(1, sum), h) else f:SetHeight(h) end
        local room = math.max(0, (f:GetWidth() or sum) - sum)
        local j = G(bar, "justify")
        local x = math.floor(((j == "LEFT") and 0 or (j == "RIGHT") and room or room / 2) + 0.5)
        for i, seg in ipairs(segs) do
            local ss = Seg(st, i)
            local c = cells[i]
            local n = M.Pieces(seg)
            ss.n, ss.lw, ss.inset, ss.tex = n, c.lw, 0, tex
            ss.host:ClearAllPoints()
            ss.host:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0)
            ss.host:SetSize(math.max(1, c.w), h)
            ss.host:SetFrameLevel(f:GetFrameLevel() + 1)
            ss.label:ClearAllPoints()
            ss.label:SetPoint("LEFT", ss.host, "LEFT", 0, 0)
            ns.TextColor(ss.label, G(bar, "dimTextColor"))
            ss.label:Show()
            E:SetFont(ss.litLabel, font, fsize, outline)
            ss.litLabel:SetText(ss.text)
            ss.litLabel:ClearAllPoints()
            ss.litLabel:SetPoint("LEFT", ss.host, "LEFT", 0, 0)
            ns.TextColor(ss.litLabel, seg.color or WHITE)
            ss.barLabel:Hide()
            if seg.lights == "count" then
                ss.cx, ss.cy, ss.ew, ss.eh, ss.eg = c.lw + 4, -math.floor((h - pip) / 2), pip, pip, 2
                for j = 1, n do
                    k = k + 1
                    local p = Piece(st, k)
                    p:SetFrameLevel(f:GetFrameLevel() + 1)
                    p:ClearAllPoints()
                    p:SetPoint("TOPLEFT", ss.host, "TOPLEFT", ss.cx + (j - 1) * (pip + 2), ss.cy)
                    p:SetSize(pip, pip)
                    StylePiece(p, bar, px, tex)
                    p._seg = i
                    p:Show()
                end
            else
                ss.cx, ss.cy, ss.ew, ss.eh, ss.eg = 0, 0, math.max(1, c.w), h, 0
            end
            ss.host:Show()
            x = x + c.w + sp
        end
    else
        local total = 0
        for _, seg in ipairs(segs) do total = total + M.Pieces(seg) end
        local h = (st.stackH and st.stacked) and st.stackH or G(bar, "height")
        if st.stacked then f:SetHeight(h) else ns.Pixel.SetSize(f, G(bar, "width"), h) end
        local W = f:GetWidth() or G(bar, "width")
        local gap = G(bar, "gap")
        local pw = math.max(1, math.floor((W - gap * (total - 1)) / math.max(1, total)))
        local x = math.floor((W - (pw * total + gap * (total - 1))) / 2)
        local inset = border and px or 0
        for i, seg in ipairs(segs) do
            local ss = Seg(st, i)
            local n = M.Pieces(seg)
            local sw = n * pw + (n - 1) * gap
            ss.n, ss.inset, ss.tex = n, inset, tex
            ss.host:ClearAllPoints()
            ss.host:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0)
            ss.host:SetSize(sw, h)
            ss.host:SetFrameLevel(f:GetFrameLevel() + 1)
            ss.cx, ss.cy, ss.ew, ss.eh, ss.eg = 0, 0, pw, h, gap
            ss.label:Hide()
            ss.litLabel:Hide()
            for j = 1, n do
                k = k + 1
                local p = Piece(st, k)
                p:SetFrameLevel(f:GetFrameLevel() + 1)
                p:ClearAllPoints()
                p:SetPoint("TOPLEFT", ss.host, "TOPLEFT", (j - 1) * (pw + gap), 0)
                p:SetSize(pw, h)
                StylePiece(p, bar, px, tex)
                p._seg = i
                p:Show()
            end
            if G(bar, "showLabels") then
                E:SetFont(ss.barLabel, font, fsize, outline)
                ss.barLabel:SetText(Cased(bar, M.SegLabel(seg, i)))
                ss.barLabel:ClearAllPoints()
                local np = G(bar, "namePoint")
                ss.barLabel:SetPoint(np, ss.host, np, G(bar, "nameXOffset"), G(bar, "nameYOffset"))
                ns.TextColor(ss.barLabel, G(bar, "nameColor"))
                ss.barLabel:Show()
            else
                ss.barLabel:Hide()
            end
            ss.host:Show()
            x = x + sw + gap
        end
    end
    st.pieceCount = k
    for j = k + 1, #st.pieces do st.pieces[j]:Hide(); st.pieces[j].lit:Hide() end
    for i = #segs + 1, #st.segs do
        local ss = st.segs[i]
        ss.host:Hide()
        ss.barLabel:Hide()
    end
    st.laying = false
end

-- ------------------------------------------------------------------ aura frames

local function StyleButton(button, r, ss)
    if button:IsForbidden() then return end
    local bar, seg = ss.bar, ss.seg
    if not (bar and seg) then return end
    local text = G(bar, "display") == "text"
    local cell = text and seg.lights ~= "count"
    local col = seg.color or WHITE
    local font = LSM:Fetch("font", G(bar, "font"))
    local fsize, outline = G(bar, "fontSize"), G(bar, "fontOutline")
    button:SetSize(ss.ew, ss.eh)
    if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end

    r.top = r.top or CreateFrame("Frame", nil, button)
    r.top:SetAllPoints(button)
    r.top:SetFrameLevel(button:GetFrameLevel() + 3)

    if cell then
        if r.bar then r.bar:Hide() end
        -- the lit copy sits exactly over the dim label and covers it
        r.label = r.label or r.top:CreateFontString(nil, "OVERLAY")
        E:SetFont(r.label, font, fsize, outline)
        r.label:ClearAllPoints()
        r.label:SetPoint("LEFT", button, "LEFT", 0, 0)
        r.label:SetText(ss.text or "")
        r.label:SetTextColor(col.r, col.g, col.b, 1)
        r.label:Show()
    else
        if r.label then r.label:Hide() end
        r.bar = r.bar or CreateFrame("StatusBar", nil, button)
        local inset = ss.inset or 0
        r.bar:ClearAllPoints()
        r.bar:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
        r.bar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
        r.bar:SetFrameLevel(button:GetFrameLevel() + 1)
        r.bar:SetStatusBarTexture(ss.tex)
        r.bar:SetStatusBarColor(col.r, col.g, col.b, 1)
        local timed = not text and seg.fill == "time" and seg.lights ~= "count"
            and type(button.SetDurationBar) == "function"
        if timed then
            if not r.bound then button:SetDurationBar(r.bar, { direction = DIR_REMAINING }); r.bound = true end
        else
            if r.bound then button:ClearDurationBar(); r.bound = false end
            r.bar:SetMinMaxValues(0, 1)
            r.bar:SetValue(1)
        end
        r.bar:Show()
    end

    if G(bar, "showDuration") and seg.lights ~= "count" then
        r.dur = r.dur or r.top:CreateFontString(nil, "OVERLAY")
        E:SetFont(r.dur, font, fsize, outline)
        r.dur:ClearAllPoints()
        if cell then
            -- a word: its time follows it, in its color
            r.dur:SetPoint("LEFT", button, "LEFT", (ss.lw or 0) + 3, 0)
            r.dur:SetTextColor(col.r, col.g, col.b, 1)
        else
            local dp = G(bar, "durationPoint")
            r.dur:SetPoint(dp, button, dp, G(bar, "durationXOffset"), G(bar, "durationYOffset"))
            ns.TextColor(r.dur, G(bar, "durationColor"))
        end
        r.dur:Show()
        local AL = ns.AuraLane
        button:SetDurationText(r.dur, { textFormatter = AL and AL.DurFormatter and AL.DurFormatter() or nil })
    else
        button:ClearDurationText()
        if r.dur then r.dur:SetText(""); r.dur:Hide() end
    end

    if G(bar, "showStacks") and not text and seg.lights ~= "count" then
        r.count = r.count or r.top:CreateFontString(nil, "OVERLAY")
        E:SetFont(r.count, font, G(bar, "stackFontSize"), G(bar, "stackFontOutline"))
        r.count:ClearAllPoints()
        local sp = G(bar, "stackPoint")
        r.count:SetPoint(sp, button, sp, G(bar, "stackXOffset"), G(bar, "stackYOffset"))
        ns.TextColor(r.count, G(bar, "stackColor"))
        r.count:Show()
        button:SetApplicationCount(r.count, {})
    else
        button:ClearApplicationCount()
        if r.count then r.count:SetText(""); r.count:Hide() end
    end

    SetGlow(button, r, seg.glow and true or false, M.GlowOpts(bar), ss.ew, ss.eh)
end

local function EnsureC(ss, field)
    local c = ss[field]
    if not c then
        c = CreateFrame("AuraContainer", nil, ss.host, "CustomAuraContainerTemplate")
        ss[field] = c
    end
    return c
end

local function ConfigC(c, ss, st)
    local n = ss.n or 1
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", ss.host, "TOPLEFT", ss.cx or 0, ss.cy or 0)
    c:SetSize(math.max(1, n * ss.ew + (n - 1) * ss.eg), math.max(1, ss.eh))
    c:SetFrameLevel(st.frame:GetFrameLevel() + 3)
    c:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    c:SetFlowLayoutAnchorPoint("TOPLEFT")
    c:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
    if c.SetFlowLayoutPadding then c:SetFlowLayoutPadding(0, 0, 0, 0) end
end

local function SetUnitLast(c, unit)
    if c._tuiUnit ~= unit then
        c:SetUnit(unit)
        c._tuiUnit = unit
        if c.UpdateAllAuras then c:UpdateAllAuras() end
    end
end

local function GroupKey(id, i) return "CB" .. id .. "_" .. i end

local function ApplyGroup(c, key, filter, ids, ss)
    local layout = { elementWidth = ss.ew, elementHeight = ss.eh, elementSpacing = ss.eg, lineSpacing = 0 }
    local SM, SD = _G.AuraContainerSortMethod, _G.AuraContainerSortDirection
    local sm, sd = SM and SM.ExpirationOnly, SD and SD.Normal
    local cf = { includeSpellIDs = ids }
    if c:HasAuraGroup(key) then
        ns.SetAuraGroupCap(c, key, ss.n)
        c:SetAuraGroupFilterString(key, filter)
        c:SetAuraGroupCandidateFilters(key, cf)
        c:SetAuraGroupLayout(key, layout)
        if sm then c:SetAuraGroupSortMethod(key, sm, sd) end
    else
        c:AddAuraGroup(key, filter, {
            maxFrameCount = ss.n, candidateFilters = cf, layout = layout,
            sortMethod = sm, sortDirection = sd,
            initializeFrame = function(button)
                local r = ss.regions[button]
                if not r then r = {}; ss.regions[button] = r end
                StyleButton(button, r, ss)
            end,
        })
    end
end

local function Off(c, key)
    if c and c:HasAuraGroup(key) then ns.SetAuraGroupCap(c, key, 0) end
end

local function SyncSegAuras(st, i, seg)
    local ss = st.segs[i]
    local key = GroupKey(st.id, i)
    local ids, any = {}, false
    if seg and not LuaLit(seg) then
        for id in pairs(M.SegSpells(seg)) do
            for x in pairs(Expand(id)) do ids[x] = true; any = true end
        end
    end
    local side = seg and M.Side(seg)
    if any and side ~= "HARMFUL" then
        local cp = EnsureC(ss, "cp")
        ConfigC(cp, ss, st)
        ApplyGroup(cp, key, "HELPFUL|" .. NP_ONLY, ids, ss)
        SetUnitLast(cp, "player")
        cp:SetShown(PlayerOK())
    else
        Off(ss.cp, key)
    end
    if any and side ~= "HELPFUL" then
        local ct = EnsureC(ss, "ct")
        ConfigC(ct, ss, st)
        ApplyGroup(ct, key, "HARMFUL|PLAYER|" .. NP_ONLY, ids, ss)
        SetUnitLast(ct, "target")
        ct:SetShown(TargetOK())
    else
        Off(ss.ct, key)
    end
    -- aura frames already made pick up the new look (a secret aura denies access: retry later)
    for button, r in pairs(ss.regions) do
        if not pcall(StyleButton, button, r, ss) then pending = true end
    end
end

local function ReleaseAuras(st, from)
    for i = from, #st.segs do
        local ss = st.segs[i]
        local key = GroupKey(st.id, i)
        Off(ss.cp, key)
        Off(ss.ct, key)
    end
end

-- ------------------------------------------------------------------ placement

function M.Key(bar) return "combo:" .. bar.id end

function M.InStack(bar)
    if G(bar, "showIn") ~= "barsetup" then return false end
    local BS = ns.BarSetup
    if not (BS and BS.IsActive and BS.IsActive()) then return false end
    return BS.UsesKey(BS.GetActiveSetup(), M.Key(bar))
end

local function KeyBar(key)
    local id = type(key) == "string" and tonumber(key:match("^combo:(%d+)$"))
    return id and M.ByID(id)
end

-- Bar Setup asks whether "combo:<id>" takes a place in the stack now
function M.Available(key)
    local bar = KeyBar(key)
    return bar ~= nil and M.LoadedHere(bar) and G(bar, "showIn") == "barsetup" and #(bar.segments or {}) > 0
end

function M.OutReason(key)
    local bar = KeyBar(key)
    if not bar then return "deleted" end
    if not bar.enabled then return "off" end
    if not M.LoadedHere(bar) then return "not loaded on this spec" end
    if G(bar, "showIn") ~= "barsetup" then return "Standalone" end
    if #(bar.segments or {}) == 0 then return "no minibars yet" end
end

function M.Label(key)
    local bar = KeyBar(key)
    return "Combo: " .. ((bar and bar.name) or "?")
end

function M.Frame(key)
    local bar = KeyBar(key)
    local st = bar and state[bar.id]
    return st and st.frame
end

function M.StackHeight(key)
    local bar = KeyBar(key)
    if not bar then return nil end
    local st = state[bar.id]
    local h = st and st.bar and st.frame:GetHeight()
    if h and h > 0 then return h end
    if G(bar, "display") == "text" then return G(bar, "fontSize") + 4 end
    return G(bar, "height")
end

-- Bar Setup's height slider (a text bar is as tall as its font)
function M.SetHeight(key, v)
    local bar = KeyBar(key)
    if not bar or G(bar, "display") == "text" or bar.height == v then return end
    bar.height = v
    M.QueueRefresh()
end

local function MoverName(id) return "TUI_ComboBarMover" .. id end

local function EnsureMover(bar, st)
    local ms = ns.MoverSync
    if not (ms and ms.CreateManaged) then return end
    local label = "Combo: " .. (bar.name or tostring(bar.id))
    if moverMade[bar.id] then
        ms.SetManagedLabel(MoverName(bar.id), label)
        return
    end
    local id = bar.id
    ms.CreateManaged(st.frame, MoverName(id), label, {
        configString = "thingsUI,modulesTab,comboBars",
        shouldDisable = function()
            local b = M.ByID(id)
            return not (b and M.LoadedHere(b)) or M.InStack(b)
        end,
        onSave = function(point, relPoint, x, y)
            local b = M.ByID(id)
            if not b then return end
            b.anchorPoint, b.anchorRelativePoint = point, relPoint
            b.anchorXOffset, b.anchorYOffset = x, y
            M.Refresh()
            ns.NotifyChange()
        end,
        onNudge = function(dx, dy)
            ms.ShiftOffsets(M.ByID(id), dx, dy)
            M.Refresh()
            ns.NotifyChange()
        end,
    })
    moverMade[id] = true
end

local function Place(bar, st)
    local f = st.frame
    local ms = ns.MoverSync
    st.stacked = M.InStack(bar)
    if st.stacked then
        local BS = ns.BarSetup
        st.stackH = BS.PositionHeight and BS.PositionHeight(M.Key(bar)) or nil
        if moverMade[bar.id] and ms then ms.SetManagedEnabled(MoverName(bar.id), false) end
        return
    end
    st.stackH = nil
    local af = G(bar, "anchorFrame")
    if af == "CUSTOM" then af = bar.anchorFrameCustom or "UIParent" end
    local target = (af ~= "UIParent")
        and ((ns.ANCHORS and ns.ANCHORS.ResolveAnchorTarget and ns.ANCHORS.ResolveAnchorTarget(af)) or _G[af])
        or nil
    if target == f then target = nil end
    f:ClearAllPoints()
    ns.Pixel.SetPoint(f, G(bar, "anchorPoint"), target or UIParent, G(bar, "anchorRelativePoint"),
        G(bar, "anchorXOffset"), G(bar, "anchorYOffset"))
    EnsureMover(bar, st)
    if ms then ms.SetManagedEnabled(MoverName(bar.id), true) end
end

local function Shown(bar)
    local V = ns.Visibility
    if not V then return true end
    if TestMode() then return V.PreviewShown(bar.visibility) end
    return V.Shown(bar.visibility)
end

-- ------------------------------------------------------------------ lit state + glow

local function Evaluate(st)
    local bar = st.bar
    if not (bar and st.frame:IsShown()) then return end
    local test = TestMode()
    local segs = bar.segments or {}
    local text = G(bar, "display") == "text"
    local gw = G(bar, "glowWhen")
    local allLit = true
    local k = 0
    local glowOpts
    for i, seg in ipairs(segs) do
        local ss = st.segs[i]
        local n = M.Pieces(seg)
        local lit, up
        if test then
            lit, up = i < #segs, (i < #segs) and n or math.max(0, n - 1)
        elseif LuaLit(seg) or gw ~= "off" then
            lit, up = M.SegState(seg)
        end
        if not lit then allLit = false end
        local col = seg.color or WHITE
        for j = 1, (text and seg.lights ~= "count") and 0 or n do
            k = k + 1
            local p = st.pieces[k]
            local on = false
            if test then on = (seg.lights == "count") and (j <= up) or lit
            elseif LuaLit(seg) then on = lit end
            if p then
                if on then p.lit:SetVertexColor(col.r, col.g, col.b, 1) end
                p.lit:SetShown(on and true or false)
            end
        end
        if text and seg.lights ~= "count" then
            ss.litLabel:SetShown((test and lit) or (LuaLit(seg) and lit) or false)
        end
        -- glow on a piece the Lua side lights (aura frames glow on their own)
        local segGlow = seg.glow and LuaLit(seg) and lit and true or (test and seg.glow and lit) or false
        if segGlow or (ss.fx and ss.fx.tuiOn) then
            glowOpts = glowOpts or M.GlowOpts(bar)
            SetGlow(ss.host, ss.fx, segGlow and true or false, glowOpts, ss.host:GetWidth(), ss.host:GetHeight())
        end
    end
    -- the preview always shows the look
    local want = false
    if test then
        want = gw ~= "off"
    elseif gw ~= "off" and (not G(bar, "glowCombat") or InCombatLockdown()) then
        if gw == "all" then want = allLit else want = not allLit end
    end
    if want or st.fx.tuiOn then
        SetGlow(st.frame, st.fx, want, glowOpts or M.GlowOpts(bar), st.frame:GetWidth(), st.frame:GetHeight())
    end
end

local driver = CreateFrame("Frame")
driver:Hide()
local dirty, since = true, 0
driver:SetScript("OnUpdate", function(self, el)
    since = since + el
    if not dirty or since < 0.1 then return end
    dirty, since = false, 0
    for _, st in pairs(state) do Evaluate(st) end
end)

local function MarkDirty() dirty = true end
M.MarkDirty = MarkDirty

local luaEv = CreateFrame("Frame")
luaEv:SetScript("OnEvent", MarkDirty)

local cdmHooked = false
local function UpdateDriver()
    local need = TestMode()
    for _, st in pairs(state) do
        if st.bar and st.frame:IsShown() and NeedsLua(st.bar) then need = true end
    end
    if need then
        luaEv:RegisterUnitEvent("UNIT_AURA", "player", "target")
        luaEv:RegisterEvent("PLAYER_REGEN_DISABLED")
        luaEv:RegisterEvent("PLAYER_REGEN_ENABLED")
        if not cdmHooked and ns.CDMIcons and ns.CDMIcons.OnAuraState then
            cdmHooked = true
            ns.CDMIcons.OnAuraState(function() if driver:IsShown() then dirty = true end end)
        end
        dirty = true
        driver:Show()
    else
        luaEv:UnregisterAllEvents()
        driver:Hide()
        for _, st in pairs(state) do
            if st.fx.tuiOn then SetGlow(st.frame, st.fx, false) end
            for _, ss in ipairs(st.segs) do
                if ss.fx.tuiOn then SetGlow(ss.host, ss.fx, false) end
                ss.litLabel:Hide()
            end
            for _, p in ipairs(st.pieces) do p.lit:Hide() end
        end
    end
end

-- ------------------------------------------------------------------ sync

local function Teardown(st)
    if InCombatLockdown() then pending = true else ReleaseAuras(st, 1) end
    st.frame:Hide()
    local ms = ns.MoverSync
    if moverMade[st.id] and ms then ms.SetManagedEnabled(MoverName(st.id), false) end
    st.bar = nil
end

local function SyncBar(bar)
    local st = EnsureState(bar)
    st.bar = bar
    local segs = bar.segments or {}
    if not (M.LoadedHere(bar) and #segs > 0) then
        Teardown(st)
        return st
    end
    for i, seg in ipairs(segs) do
        local ss = Seg(st, i)
        ss.bar, ss.seg = bar, seg
    end
    ns.STRATA.Apply(st.frame, G(bar, "frameStrata"))
    Place(bar, st)
    LayoutBar(bar, st)
    if InCombatLockdown() then
        pending = true
    else
        for i, seg in ipairs(segs) do SyncSegAuras(st, i, seg) end
        ReleaseAuras(st, #segs + 1)
    end
    st.frame:SetShown(Shown(bar))
    return st
end

local lastStackSig
function M.Refresh()
    local AL = ns.AuraLane
    if not (E.db and E.db.thingsUI and AL and AL.Ready and AL.Ready()) then return end
    if not InCombatLockdown() then pending = false end
    local alive, sig = {}, {}
    for _, bar in ipairs(M.GetBars()) do
        local st = SyncBar(bar)
        alive[bar.id] = true
        if st.bar and st.stacked then
            sig[#sig + 1] = bar.id .. ":" .. tostring(st.frame:GetHeight())
        end
    end
    for id, st in pairs(state) do
        if not alive[id] and st.bar then Teardown(st) end
    end
    -- a bar that joins, leaves or changes height in the stack: Bar Setup restacks
    local s = table.concat(sig, ",")
    if s ~= lastStackSig and not InCombatLockdown() then
        lastStackSig = s
        local BS = ns.BarSetup
        if BS and BS.ApplyStack then C_Timer.After(0, BS.ApplyStack) end
    end
    UpdateDriver()
    dirty = true
end

local queued = false
function M.QueueRefresh()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        M.Refresh()
    end)
end

function TUI:UpdateComboBars() M.Refresh() end

function M.ReparseAll()
    for _, st in pairs(state) do
        for _, ss in ipairs(st.segs) do
            if ss.cp and ss.cp.UpdateAllAuras then ss.cp:UpdateAllAuras() end
            if ss.ct and ss.ct.UpdateAllAuras then ss.ct:UpdateAllAuras() end
        end
    end
end

-- ------------------------------------------------------------------ edits

function M.NewBar(name)
    local r = Root()
    local id = r.nextID
    r.nextID = id + 1
    local bar = ns.Defaults.ComboBar(id, name, CurSpec())
    bar.segments[1] = ns.Defaults.ComboSegment(1)
    r.bars[#r.bars + 1] = bar
    M.Refresh()
    return bar
end

function M.DeleteBar(id)
    local r = Root()
    local i = M.IndexOf(id)
    if not i then return end
    table.remove(r.bars, i)
    local key = "combo:" .. id
    for _, s in ipairs((E.db.thingsUI.barSetup and E.db.thingsUI.barSetup.setups) or {}) do
        for j = #(s.order or {}), 1, -1 do
            if s.order[j] == key then table.remove(s.order, j) end
        end
        if s.bars then s.bars[key] = nil end
    end
    M.Refresh()
end

-- where else auras show on this spec (options): aura id -> { { label, path } }
function M.UsageIndex(skipBarID)
    local idx = {}
    local function put(ids, label, path)
        for id in pairs(ids or {}) do
            for x in pairs(Expand(id)) do
                local l = idx[x]
                if not l then l = {}; idx[x] = l end
                if not l[label] then l[label] = true; l[#l + 1] = { label = label, path = path } end
            end
        end
    end
    local SB = ns.SpecialBars
    if SB and SB.GetIconCount then
        for i = 1, SB.GetIconCount() do
            local d = SB.GetIconDB("icon" .. i)
            if type(d) == "table" and d.enabled and d.spellID then
                put({ [d.spellID] = true }, "Aura Icon " .. i,
                    { "thingsUI", "modulesTab", "specialIcons", "iconsTab", "icon" .. i .. "Group" })
            end
        end
        for i = 1, SB.GetBarCount() do
            local d = SB.GetBarDB("bar" .. i)
            if type(d) == "table" and d.enabled and d.spellID then
                put({ [d.spellID] = true }, "Aura Bar " .. i,
                    { "thingsUI", "modulesTab", "specialBars", "barsTab", "bar" .. i .. "Group" })
            end
        end
    end
    local AC = ns.AuraCollections
    local _, classToken = UnitClass("player")
    local spec = CurSpec()
    local function scan(g, global, label, path)
        if type(g) ~= "table" or g.enabled == false then return end
        local specs = g.specs or {}
        for _, root in ipairs({ global, g.classes and g.classes[classToken], specs[spec] or specs[tostring(spec)] }) do
            for uid, def in pairs((type(root) == "table" and root.auras) or {}) do
                if type(def) == "table" and def.enabled ~= false then
                    local key = AC and AC.LinkOf(uid, def)
                    local c = key and AC.Get(key)
                    put((c and c.spells) or def.spells, label, path)
                end
            end
        end
    end
    local cg = E.db.thingsUI.customGroups
    for gi, g in ipairs((cg and cg.groups) or {}) do
        scan(g, g.global, "Groups - Icons: " .. tostring(g.name or gi), { "thingsUI", "modulesTab", "customGroups", "group" .. gi })
    end
    local cb = E.db.thingsUI.customBars
    for gi, g in ipairs((cb and cb.groups) or {}) do
        local text = g.display == "text"
        scan(g, g, (text and "Groups - Text: " or "Groups - Bars: ") .. tostring(g.name or gi),
            { "thingsUI", "modulesTab", text and "customText" or "customBars", "group" .. gi })
    end
    for bi, b in ipairs(M.GetBars()) do
        if b.id ~= skipBarID and M.LoadedHere(b) then
            for _, seg in ipairs(b.segments or {}) do
                put(M.SegSpells(seg), "Combo Bar: " .. tostring(b.name or b.id), { "thingsUI", "modulesTab", "comboBars", "bar" .. bi })
            end
        end
    end
    return idx
end

-- the other places a minibar's auras show
function M.AlsoIn(seg, barID)
    local idx = M.UsageIndex(barID)
    local out, seen = {}, {}
    for id in pairs(M.SegSpells(seg)) do
        for x in pairs(Expand(id)) do
            for _, e in ipairs(idx[x] or {}) do
                if not seen[e.label] then seen[e.label] = true; out[#out + 1] = e end
            end
        end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

-- Bar Setup: takes a place in the setup this spec uses (or the one given)
function M.SetShowIn(bar, v, setup)
    bar.showIn = v
    local BS = ns.BarSetup
    if v == "barsetup" and BS then
        setup = setup or BS.SetupForSpec(CurSpec())
        if setup and not BS.UsesKey(setup, M.Key(bar)) then BS.IncludeSpecialBar(setup, M.Key(bar)) end
    end
    M.Refresh()
    if BS and BS.ApplyStack and not InCombatLockdown() then BS.ApplyStack() end
end

-- every bar piece linked to a collection: "Aura Combo Bars: <bar> (<piece>)"
function M.UsedBy(key)
    local out = {}
    for _, bar in ipairs(M.GetBars()) do
        for i, seg in ipairs(bar.segments or {}) do
            if seg.collection == key then
                out[#out + 1] = ("Aura Combo Bars: %s (%s)"):format(bar.name or "Bar", M.SegLabel(seg, i))
            end
        end
    end
    return out
end

-- a deleted collection leaves its spells behind in the pieces that used it
function M.CollectionDeleted(key, c)
    for _, bar in ipairs(M.GetBars()) do
        for _, seg in ipairs(bar.segments or {}) do
            if seg.collection == key then
                seg.spells = seg.spells or {}
                for id in pairs((c and c.spells) or {}) do seg.spells[id] = true end
                seg.label = seg.label or (c and c.name)
                seg.collection = nil
            end
        end
    end
    M.QueueRefresh()
end

-- ------------------------------------------------------------------ events

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then M.Refresh() end
    elseif event == "PLAYER_TARGET_CHANGED" then
        local ok = TargetOK()
        for _, st in pairs(state) do
            for _, ss in ipairs(st.segs) do
                if ss.ct and ss.ct._tuiUnit == "target" then ss.ct:SetShown(ok) end
            end
        end
        dirty = true
    end
end)

if ns.Visibility and ns.Visibility.OnChange then
    ns.Visibility.OnChange(function()
        for _, st in pairs(state) do
            if st.bar then st.frame:SetShown(Shown(st.bar)) end
        end
        UpdateDriver()
    end)
end

-- Bar Setup moved things: our place in the stack may have changed
if ns.BarSetup and ns.BarSetup.PositionStack then
    hooksecurefunc(ns.BarSetup, "PositionStack", function()
        for _, st in pairs(state) do
            if st.bar and st.stacked ~= M.InStack(st.bar) then M.QueueRefresh() return end
        end
    end)
end
