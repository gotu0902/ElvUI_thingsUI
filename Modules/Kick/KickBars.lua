local _, ns = ...
local TUI, E, LSM = ns.TUI, ns.E, ns.LSM
local KE, KD = ns.KickEngine, ns.KickData

-- A row per group member with a kick. A kick the engine can't name puts a layer over everyone who
-- may have landed it: their row on that cooldown, in a clip that opens only where their count rose.
-- Nothing is built or registered until the module is enabled.
local M = {}
ns.KickBars = M

local MOVER = "TUI_KickTrackerMover"
local OFF, LIVE, SAMPLE = 0, 1, 2
local ROWS = 5          -- the frame fits a full group, so a row coming or going never moves the anchor
local TICK = 0.1
local MERGE = 0.3       -- meter updates this close are one kick
local MAX_LAYERS = 8    -- per member
local LEVELS = 4        -- frame levels one row takes
-- the gate is SPAN rows long, so one more kick opens the clip over the row, up to SPAN kicks a fight
local SPAN, PAD, EDGE, TALL = 100, 4, 2, 24
local BLACK = { r = 0, g = 0, b = 0, a = 1 }

local IMMEDIATE = Enum.StatusBarInterpolation.Immediate
local ELAPSED = Enum.StatusBarTimerDirection.ElapsedTime
local REMAINING = Enum.StatusBarTimerDirection.RemainingTime

-- class, kick, seconds left
local PREVIEW = (ns.FV and ns.FV.KICK_PREVIEW) or {
    { "WARRIOR", 6552, 0 },
    { "MAGE", 2139, 9 },
    { "DEATHKNIGHT", 47528, 0 },
    { "SHAMAN", 57994, 4 },
    { "DEMONHUNTER", 183752, 12 },
}

local frame
local rows, rowOf = {}, {}    -- pool by slot; guid -> its row
local shown = 0
local layers, free = {}, {}   -- guid -> live layers, oldest first; released ones
local mode = OFF
local preview = false
local moverMade = false
local gen = 0                 -- bumped by every settings pass; a row restyles when its stamp differs
local effW, effH = 220, 22
local ticker
local fillDir, tenths = REMAINING, 5
local cdColor                 -- the bar's color while the kick is down; nil = same as ready

local function DB()
    return E.db.thingsUI and E.db.thingsUI.kickTracker
end

local function StopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local Tick
local function ArmTicker()
    if not ticker then ticker = C_Timer.NewTicker(TICK, Tick) end
end

-- ---------------------------------------------------------------- rows

local function NewRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:EnableMouse(false)
    r.iconBox = CreateFrame("Frame", nil, r)
    local back = r.iconBox:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 1)
    r.icon = r.iconBox:CreateTexture(nil, "ARTWORK")
    r.barBox = CreateFrame("Frame", nil, r)
    r.bg = r.barBox:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bar = CreateFrame("StatusBar", nil, r.barBox)
    r.dur = C_DurationUtil.CreateDuration()
    r.top = CreateFrame("Frame", nil, r)
    r.top:SetAllPoints(r)
    r.iconRing, r.barRing = {}, {}
    for i = 1, 4 do
        r.iconRing[i] = r.top:CreateTexture(nil, "OVERLAY")
        r.barRing[i] = r.top:CreateTexture(nil, "OVERLAY")
    end
    r.name = r.top:CreateFontString(nil, "OVERLAY")
    r.name:SetWordWrap(false)
    r.time = r.top:CreateFontString(nil, "OVERLAY")
    return r
end

local function RowLevels(r, base)
    r:SetFrameLevel(base)
    r.iconBox:SetFrameLevel(base + 1)
    r.barBox:SetFrameLevel(base + 1)
    r.bar:SetFrameLevel(base + 2)
    r.top:SetFrameLevel(base + 3)
end

local function Ring(host, ring, on, size, color)
    if on then
        ns.AuraLane.EdgeRing(host, ring, size, 0, color)
    else
        for _, t in ipairs(ring) do t:Hide() end
    end
end

local function StyleRow(r, db)
    r.gen = gen
    local P = ns.Pixel
    local h = effH
    P.SetSize(r, effW, h)
    local iconOn = db.iconEnabled ~= false
    local right = db.iconSide == "RIGHT"
    local bs = db.showBorder and (db.borderSize or 1) or 0
    local bc = db.borderColor or BLACK

    local off = 0
    r.iconBox:SetShown(iconOn)
    if iconOn then
        local side = right and "RIGHT" or "LEFT"
        r.iconBox:ClearAllPoints()
        r.iconBox:SetPoint(side, r, side, 0, 0)
        P.SetSize(r.iconBox, h, h)
        local z = db.iconZoom or 0.1
        r.icon:SetTexCoord(z, 1 - z, z, 1 - z)
        r.icon:ClearAllPoints()
        P.SetPoint(r.icon, "TOPLEFT", r.iconBox, "TOPLEFT", bs, -bs)
        P.SetPoint(r.icon, "BOTTOMRIGHT", r.iconBox, "BOTTOMRIGHT", -bs, bs)
        off = h + (db.iconSpacing or 1)
    end

    r.barBox:ClearAllPoints()
    P.SetPoint(r.barBox, "TOPLEFT", r, "TOPLEFT", right and 0 or off, 0)
    P.SetPoint(r.barBox, "BOTTOMRIGHT", r, "BOTTOMRIGHT", right and -off or 0, 0)
    r.bar:ClearAllPoints()
    P.SetPoint(r.bar, "TOPLEFT", r.barBox, "TOPLEFT", bs, -bs)
    P.SetPoint(r.bar, "BOTTOMRIGHT", r.barBox, "BOTTOMRIGHT", -bs, bs)
    r.bar:SetStatusBarTexture(LSM:Fetch("statusbar", db.statusBarTexture))
    ns.AuraLane.NoSnap(r.bar:GetStatusBarTexture())
    r.bar:SetReverseFill(db.reverseFill and true or false)
    Ring(r.barBox, r.barRing, bs > 0, bs, bc)
    Ring(r.iconBox, r.iconRing, iconOn and bs > 0, bs, bc)

    local font = LSM:Fetch("font", db.font or "Expressway")
    local size, outline = db.fontSize or 12, db.fontOutline or "OUTLINE"
    local timeOn = db.showDuration ~= false
    E:SetFont(r.name, font, size, outline)
    E:SetFont(r.time, font, size, outline)
    if db.showName ~= false then
        local pt = db.namePoint or "LEFT"
        r.name:ClearAllPoints()
        r.name:SetPoint(pt, r.bar, pt, db.nameXOffset or 4, db.nameYOffset or 0)
        r.name:SetJustifyH(pt)
        r.name:SetWidth(math.max(1, effW - off - 2 * bs - 8 - (timeOn and size * 2.4 or 0)))
        r.name:Show()
    else
        r.name:Hide()
    end
    if timeOn then
        local pt = db.durationPoint or "RIGHT"
        r.time:ClearAllPoints()
        r.time:SetPoint(pt, r.bar, pt, db.durationXOffset or -4, db.durationYOffset or 0)
        ns.TextColor(r.time, db.durationColor)
        r.time:Show()
    else
        r.time:Hide()
    end
end

local function BarColor(r)
    local c = (r.readyAt and cdColor) or r.color
    if c then r.bar:SetStatusBarColor(c.r or 0, c.g or 0, c.b or 0, c.a or 1) end
end

local function PaintMember(r, db, class, kick, name)
    r.icon:SetTexture((kick and C_Spell.GetSpellTexture(kick)) or 134400)
    r.name:SetText(name)
    local cc = class and E:ClassColor(class, true)
    r.color = (db.useClassColor ~= false and cc) or db.customColor or BLACK
    BarColor(r)
    ns.TextColor(r.name, (db.nameClassColor and cc) or db.nameColor)
    local bg = db.backgroundColor or BLACK
    -- a layer hides the row under it, whatever the background's alpha
    r.bg:SetColorTexture(bg.r or 0, bg.g or 0, bg.b or 0, r.opaque and 1 or (bg.a or 0.6))
end

local function PaintTime(r, left)
    if left < tenths then
        local q = math.floor(left * 10 + 0.5)
        if r.q ~= q then
            r.q = q
            r.time:SetFormattedText("%.1f", q / 10)
        end
    else
        local s = math.ceil(left)
        if r.q ~= -s then
            r.q = -s
            r.time:SetFormattedText("%d", s)
        end
    end
end

-- no cooldown: a span that already ended, read as elapsed, is a full bar
local function PaintCd(r, start, dur)
    local now = GetTime()
    if start and dur and start + dur > now then
        r.dur:SetTimeFromStart(start, dur)
        r.bar:SetTimerDuration(r.dur, IMMEDIATE, fillDir)
        r.readyAt = start + dur
        PaintTime(r, r.readyAt - now)
        ArmTicker()
    else
        r.dur:SetTimeFromStart(now - 1, 0.5)
        r.bar:SetTimerDuration(r.dur, IMMEDIATE, ELAPSED)
        r.readyAt = nil
        r.q = nil
        r.time:SetText("")
    end
    BarColor(r)
end

-- ---------------------------------------------------------------- layers

local function NewLayer()
    local L = CreateFrame("Frame", nil, frame)
    L:Hide()
    L:EnableMouse(false)
    -- draws nothing; the clip hangs from its fill
    local gate = CreateFrame("StatusBar", nil, L)
    gate:EnableMouse(false)
    gate:SetStatusBarTexture(E.media.blankTex)
    gate:SetAlpha(0)
    local fill = gate:GetStatusBarTexture()
    ns.AuraLane.NoSnap(fill)
    local clip = CreateFrame("Frame", nil, L)
    clip:SetClipsChildren(true)
    clip:EnableMouse(false)
    local row = NewRow(clip)
    row.opaque = true
    row:Show()
    L.gate, L.fill, L.clip, L.row = gate, fill, clip, row
    return L
end

-- count before as value, after as max: a whole fill leaves the clip empty, one more kick opens it.
-- Re-hung each feed, and fed again on the next tick: a fill that moved gets no layout of its own.
local function FeedLayer(L)
    local gate, fill, clip = L.gate, L.fill, L.clip
    gate:SetMinMaxValues(0, L.after)
    gate:SetValue(L.before)
    clip:ClearAllPoints()
    clip:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
    clip:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)
    clip:SetPoint("TOPRIGHT", gate, "TOPRIGHT", 0, 0)
    clip:SetPoint("BOTTOMRIGHT", gate, "BOTTOMRIGHT", 0, 0)
    L.feed = nil
end

local function LayerLevels(L, R, depth)
    local base = R:GetFrameLevel() + LEVELS * (depth + 1)
    L:SetFrameLevel(base)
    L.gate:SetFrameLevel(base)
    L.clip:SetFrameLevel(base)
    RowLevels(L.row, base)
end

local function PlaceLayer(L, R, depth)
    local db = DB()
    local row = L.row
    if row.gen ~= gen then StyleRow(row, db) end
    L:ClearAllPoints()
    L:SetAllPoints(R)
    row:ClearAllPoints()
    row:SetAllPoints(R)
    local gate = L.gate
    gate:SetSize(SPAN * (effW + PAD), effH + TALL)
    gate:ClearAllPoints()
    gate:SetPoint("RIGHT", R, "RIGHT", EDGE, 0)
    LayerLevels(L, R, depth)
    PaintMember(row, db, L.class, L.kick, L.name)
end

local function FreeLayer(L)
    L:Hide()
    PaintCd(L.row)
    L.gate:SetMinMaxValues(0, 1)
    L.gate:SetValue(1)
    L.t, L.guid, L.before, L.after, L.feed = nil, nil, nil, nil, nil
    free[#free + 1] = L
end

local function Relevel(guid)
    local list, R = layers[guid], rowOf[guid]
    if not (list and R) then return end
    for i, L in ipairs(list) do LayerLevels(L, R, i - 1) end
end

-- the member's layers up to a kick that's theirs for sure; nil = all of them
local function ReleaseLayers(guid, upto)
    local list = layers[guid]
    if not list then return end
    for i = #list, 1, -1 do
        if not upto or list[i].t <= upto then
            FreeLayer(list[i])
            table.remove(list, i)
        end
    end
    Relevel(guid)
end

local function ReleaseAll()
    for guid in pairs(layers) do ReleaseLayers(guid) end
end

local function RelayLayers()
    for guid, list in pairs(layers) do
        local R = rowOf[guid]
        if not R then
            ReleaseLayers(guid)
        else
            for i, L in ipairs(list) do
                PlaceLayer(L, R, i - 1)
                FeedLayer(L)
                L.feed = true
            end
        end
    end
end

Tick = function()
    local now = GetTime()
    local any = false
    for i = 1, shown do
        local r = rows[i]
        local at = r.readyAt
        if at then
            if at <= now then
                PaintCd(r)
            else
                any = true
                PaintTime(r, at - now)
            end
        end
    end
    for guid, list in pairs(layers) do
        local gone = false
        for i = #list, 1, -1 do
            local L = list[i]
            local at = L.row.readyAt
            if not at or at <= now then
                FreeLayer(L)
                table.remove(list, i)
                gone = true
            else
                any = true
                if L.feed then FeedLayer(L) end
                PaintTime(L.row, at - now)
            end
        end
        if gone then Relevel(guid) end
    end
    if not any then
        StopTicker()
        -- the preview's samples run again
        if mode == SAMPLE then M.Layout() end
    end
end

-- ---------------------------------------------------------------- layout

local function NameOf(unit, db)
    local name = UnitName(unit)
    if db.nsrtNicknames ~= false then return ns.TUIMeter.NickFor(name) or name end
    return name
end

local function UseRow(i, db, class, kick, name, start, dur)
    local r = rows[i]
    if not r then
        r = NewRow(frame)
        rows[i] = r
    end
    if r.gen ~= gen then StyleRow(r, db) end
    RowLevels(r, frame:GetFrameLevel() + 1)
    local off = (i - 1) * (effH + (db.spacing or 1))
    r:ClearAllPoints()
    if db.growth == "UP" then
        ns.Pixel.SetPoint(r, "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, off)
    else
        ns.Pixel.SetPoint(r, "TOPLEFT", frame, "TOPLEFT", 0, -off)
    end
    PaintMember(r, db, class, kick, name)
    PaintCd(r, start, dur)
    r:Show()
    return r
end

function M.Layout()
    local db = DB()
    if not (frame and db) then return end
    wipe(rowOf)
    local n = 0
    if mode == SAMPLE then
        local now = GetTime()
        for _, s in ipairs(PREVIEW) do
            local cd = KD.Cooldown(s[2])
            local left = s[3]
            n = n + 1
            UseRow(n, db, s[1], s[2], LOCALIZED_CLASS_NAMES_MALE[s[1]], left > 0 and (now - (cd - left)) or nil, left > 0 and cd or nil)
        end
    elseif mode == LIVE then
        for _, u in ipairs(KE.UNITS) do
            local m = KE.Member(u)
            if m and m.guid and m.kick and (u ~= "player" or db.showSelf ~= false) then
                local start, dur = KE.Cooldown(u)
                n = n + 1
                rowOf[m.guid] = UseRow(n, db, m.class, m.kick, NameOf(u, db), start, dur)
            end
        end
    end
    for i = n + 1, #rows do
        rows[i]:Hide()
        rows[i].readyAt = nil
    end
    shown = n
    RelayLayers()
    frame:SetShown(n > 0)
end

-- ---------------------------------------------------------------- engine

local function OnCooldown(unit, start, dur)
    if mode ~= LIVE then return end
    local m = KE.Member(unit)
    if not m then return end
    ReleaseLayers(m.guid, start + 0.01)
    local r = rowOf[m.guid]
    if r then PaintCd(r, start, dur) end
end

local function OnGate(t, units, before, after)
    if mode ~= LIVE then return end
    local db = DB()
    local now = GetTime()
    for _, u in ipairs(units) do
        local m = KE.Member(u)
        local R = m and rowOf[m.guid]
        local dur = R and m.landed
        if dur and t + dur > now then
            local list = layers[m.guid]
            if not list then
                list = {}
                layers[m.guid] = list
            end
            local last = list[#list]
            if last and t - last.t <= MERGE then
                last.after = after[m.guid]
                FeedLayer(last)
                last.feed = true
            else
                if #list >= MAX_LAYERS then
                    FreeLayer(table.remove(list, 1))
                    Relevel(m.guid)
                end
                local L = table.remove(free) or NewLayer()
                list[#list + 1] = L
                L.t, L.guid, L.before, L.after = t, m.guid, before[m.guid], after[m.guid]
                L.class, L.kick, L.name = m.class, m.kick, NameOf(u, db)
                PlaceLayer(L, R, #list - 1)
                FeedLayer(L)
                PaintCd(L.row, t, dur)
                L:Show()
                L.feed = true
            end
        end
    end
end

local HANDLERS = { cooldown = OnCooldown, gate = OnGate, roster = function()
    if mode == LIVE then M.Layout() end
end }

local function WantMode(db)
    if preview then return SAMPLE end
    return ns.Visibility.Shown(db.visibility) and LIVE or OFF
end

local function SetMode(want)
    if want == mode then return end
    local was = mode
    mode = want
    if was == LIVE then
        KE.Stop()
        ReleaseAll()
    end
    if want == LIVE then KE.Start(HANDLERS) end
end

-- ---------------------------------------------------------------- frame

local function EnsureFrame()
    if frame then return end
    frame = CreateFrame("Frame", "TUI_KickTracker", UIParent)
    frame:Hide()
end

local updateQueued = false
local function QueueUpdate()
    if updateQueued then return end
    updateQueued = true
    C_Timer.After(0, function()
        updateQueued = false
        TUI:UpdateKickTracker()
    end)
end

local function Place(db)
    local af = db.anchorFrame or "UIParent"
    local target = (af ~= "UIParent") and ns.ANCHORS.ResolveAnchorTarget(af) or nil
    if target == frame then target = nil end
    if target and (db.inheritWidth or db.inheritHeight) and target.HookScript and not target._tuiKickHooked then
        target._tuiKickHooked = true
        target:HookScript("OnSizeChanged", QueueUpdate)
    end
    effW, effH = ns.ANCHORS.InheritedSize(db, frame, target, db.width or 220, db.height or 22)
    ns.Pixel.SetSize(frame, effW, ROWS * effH + (ROWS - 1) * (db.spacing or 1))
    frame:ClearAllPoints()
    ns.Pixel.SetPoint(frame, db.anchorPoint or "CENTER", target or UIParent, db.anchorRelativePoint or "CENTER",
        db.anchorXOffset or 0, db.anchorYOffset or 0)
end

local function EnsureMover()
    local ms = ns.MoverSync
    if moverMade or not (ms and ms.CreateManaged) then return end
    ms.CreateManaged(frame, MOVER, "Kick Tracker", {
        configString = "thingsUI,modulesTab,kickTracker",
        shouldDisable = function()
            local db = DB()
            return not (db and db.enabled)
        end,
        onSave = function(point, relPoint, x, y)
            local db = DB()
            db.anchorPoint, db.anchorRelativePoint, db.anchorXOffset, db.anchorYOffset = point, relPoint, x, y
            TUI:UpdateKickTracker()
            ns.NotifyChange()
        end,
        onNudge = function(dx, dy)
            ms.ShiftOffsets(DB(), dx, dy)
            TUI:UpdateKickTracker()
            ns.NotifyChange()
        end,
    })
    moverMade = true
end

function TUI:UpdateKickTracker()
    local db = DB()
    if not (db and db.enabled) then
        SetMode(OFF)
        StopTicker()
        if frame then
            frame:Hide()
            ns.MoverSync.Queue()
        end
        return
    end
    EnsureFrame()
    gen = gen + 1
    fillDir = (db.cooldownFill == "fill") and ELAPSED or REMAINING
    tenths = db.tenthsBelow or 5
    cdColor = db.useCooldownColor and db.cooldownColor or nil
    ns.STRATA.Apply(frame, db.frameStrata, db.frameLevel)
    Place(db)
    if not moverMade then
        EnsureMover()
        Place(db)
    end
    SetMode(WantMode(db))
    M.Layout()
    ns.MoverSync.Queue()
end

-- the options page shows sample rows
function M.SetPreview(on)
    on = on and true or false
    if preview == on then return end
    preview = on
    local db = DB()
    if db and db.enabled then TUI:UpdateKickTracker() end
end

ns.Visibility.OnChange(function()
    local db = DB()
    if not (frame and db and db.enabled) then return end
    SetMode(WantMode(db))
    M.Layout()
end)
