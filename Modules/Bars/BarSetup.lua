local _, ns = ...
local TUI = ns.TUI
local E   = ns.E

ns.BarSetup = ns.BarSetup or {}
local M = ns.BarSetup

M.BAR_KEYS = { "power", "castbar", "classbar", "chargebar" }
M.BAR_LABELS = {
    power     = "Power Bar",
    castbar   = "Cast Bar",
    classbar  = "Class Bar",
    chargebar = "Charge Bar",
}

function M.GetBarLabel(key)
    if type(key) ~= "string" then return tostring(key) end
    local fixed = M.BAR_LABELS[key]
    if fixed then return fixed end
    if key:sub(1, 6) == "combo:" and ns.ComboBars then return ns.ComboBars.Label(key) end
    if key:sub(1, 8) == "special:" then
        local slotKey = key:sub(9)
        local idx = tonumber(slotKey:match("^bar(%d+)$")) or "?"
        local SB = ns.SpecialBars
        local hint
        if SB and SB.GetBarDB then
            local bdb = SB.GetBarDB(slotKey)
            if type(bdb) == "table" then
                hint = bdb.spellName
                if (not hint) and bdb.spellID and C_Spell and C_Spell.GetSpellInfo then
                    local info = C_Spell.GetSpellInfo(bdb.spellID)
                    hint = info and info.name
                end
            end
        end
        if hint and hint ~= "" then
            return string.format("Aura Bar %s (%s)", tostring(idx), hint)
        end
        return string.format("Aura Bar %s", tostring(idx))
    end
    return key
end

local function GetCurrentSpecID()
    local idx = C_SpecializationInfo.GetSpecialization()
    if not idx then return 0 end
    local id = C_SpecializationInfo.GetSpecializationInfo(idx)
    return id or 0
end
M.GetCurrentSpecID = GetCurrentSpecID

local function DefaultOrder()
    return { "power", "classbar", "chargebar", "castbar" }
end

local function NewBar()
    return {
        enabled = true,
        mode    = "NHT",
        widthOffset = 0,
        anchorFrame = "UIParent",
        anchorPoint = "CENTER",
        anchorTo    = "CENTER",
        xOffset     = 0,
        yOffset     = 0,
        inheritWidthFromAnchor = false,
        inheritWidthOffset     = 0,
    }
end

local DEFAULT_WIDTH_OFFSETS = {
    power     = 0,
    castbar   = 1,
    classbar  = 0,
    chargebar = 0,
}

local BAR_X_NUDGE = {
    chargebar = -0.1,
}

local function DefaultBars()
    local bars = {
        power     = NewBar(),
        classbar  = NewBar(),
        chargebar = NewBar(),
        castbar   = NewBar(),
    }
    for k, v in pairs(DEFAULT_WIDTH_OFFSETS) do
        bars[k].widthOffset = v
    end
    return bars
end

local function NewSetup(name)
    return {
        name        = name or "Setup",
        specs       = {},
        order       = DefaultOrder(),
        bars        = DefaultBars(),
        anchorFrame = "EssentialCooldownViewer",
        anchorPoint = "BOTTOM",
        anchorTo    = "TOP",
        xOffset     = 0,
        yOffset     = 1,
        gap         = 1,
        inheritWidth = true,
        widthOffset  = 0,
        minWidth     = 0,
    }
end
M.NewSetup = NewSetup

local function EnsureDB()
    local db = E.db.thingsUI
    if not db.barSetup then
        db.barSetup = { setups = { NewSetup("Global") }, active = 1 }
    end
    if not db.barSetup.setups or #db.barSetup.setups == 0 then
        db.barSetup.setups = { NewSetup("Global") }
    end
    if db.barSetup.powerDetachedHeight == nil then
        local pw = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.player and E.db.unitframe.units.player.power
        if pw and pw.height then db.barSetup.powerDetachedHeight = pw.height end
    end
    for _, s in ipairs(db.barSetup.setups) do
        if type(s.order) ~= "table" or #s.order == 0 then s.order = DefaultOrder() end
        if type(s.specs) ~= "table" then s.specs = {} end

        do
            local maxKey = 0
            for k in pairs(s.order) do
                if type(k) == "number" and k > maxKey then maxKey = k end
            end
            local clean, seen = {}, {}
            for i = 1, maxKey do
                local v = rawget(s.order, i)
                if type(v) == "string" and v ~= "" and not seen[v] then
                    seen[v] = true
                    clean[#clean + 1] = v
                end
            end
            for _, k in ipairs(M.BAR_KEYS) do
                if not seen[k] then
                    clean[#clean + 1] = k
                    seen[k] = true
                end
            end
            s.order = clean
        end

        local hadBars = type(s.bars) == "table"
        if not hadBars then s.bars = DefaultBars() end
        if type(s.enabled) == "table" then
            for k, v in pairs(s.enabled) do
                if s.bars[k] and v ~= nil
                   and (not hadBars or s.bars[k].enabled == nil) then
                    s.bars[k].enabled = v
                end
            end
            s.enabled = nil
        end
        for _, k in ipairs(M.BAR_KEYS) do
            if type(s.bars[k]) ~= "table" then s.bars[k] = NewBar() end
            local b = s.bars[k]
            if b.enabled == nil    then b.enabled = true end
            if b.mode    == nil    then b.mode = "NHT" end
            if b.widthOffset == nil then b.widthOffset = DEFAULT_WIDTH_OFFSETS[k] or 0 end
            b.anchorFrame = b.anchorFrame or "UIParent"
            b.anchorPoint = b.anchorPoint or "CENTER"
            b.anchorTo    = b.anchorTo    or "CENTER"
            b.xOffset     = b.xOffset     or 0
            b.yOffset     = b.yOffset     or 0
        end

        -- own heights per setup, stops global bleed
        if type(s.barHeights) ~= "table" then s.barHeights = {} end
        for _, k in ipairs(M.BAR_KEYS) do
            if not (type(s.barHeights[k]) == "number" and s.barHeights[k] > 0) then
                local v = M.GetBarHeight and M.GetBarHeight(k, s)
                if type(v) == "number" and v > 0 then s.barHeights[k] = v end
            end
        end

        s.gap          = s.gap          or 1
        s.xOffset      = s.xOffset      or 0
        s.yOffset      = s.yOffset      or 0
        s.widthOffset  = s.widthOffset  or 0
        s.minWidth     = s.minWidth     or 0
        if s.inheritWidth == nil then s.inheritWidth = true end
        s.anchorFrame  = s.anchorFrame  or "EssentialCooldownViewer"
        s.anchorPoint  = s.anchorPoint  or "BOTTOM"
        s.anchorTo     = s.anchorTo     or "TOP"
    end
end
M.EnsureDB = EnsureDB

-- the setup a spec uses: the first with it ticked, else the fallback
function M.SetupForSpec(specID)
    EnsureDB()
    local db = E.db.thingsUI.barSetup
    if specID and specID ~= 0 then
        for _, s in ipairs(db.setups) do
            if s.specs and s.specs[specID] then return s end
        end
    end
    return db.setups[db.active] or db.setups[1]
end

function M.GetActiveSetup()
    return M.SetupForSpec(GetCurrentSpecID())
end

function M.UsesKey(setup, key)
    if not (setup and setup.order and setup.bars) then return false end
    for _, k in ipairs(setup.order) do
        if k == key then
            local b = setup.bars[k]
            return b ~= nil and b.enabled == true
        end
    end
    return false
end

-- a new Aura Bar place goes right after the last one in the order
function M.IncludeSpecialBar(setup, key)
    local at
    for i, k in ipairs(setup.order) do
        if k == key then at = false break end
        if k:sub(1, 8) == "special:" then at = i + 1 end
    end
    if at ~= false then table.insert(setup.order, at or (#setup.order + 1), key) end
    if setup.bars[key] then
        setup.bars[key].enabled = true
    else
        setup.bars[key] = {
            enabled = true, mode = "NHT", widthOffset = 0,
            anchorFrame = "UIParent", anchorPoint = "CENTER",
            anchorTo = "CENTER", xOffset = 0, yOffset = 0,
        }
    end
end

-- Show In > Bar Setup: the spec's setup takes this bar's number; other specs on it keep theirs Standalone
function M.AddAuraBar(slotKey, specID)
    specID = specID or GetCurrentSpecID()
    local setup = M.SetupForSpec(specID)
    local key = "special:" .. slotKey
    if not setup or M.UsesKey(setup, key) then return end
    local own = tostring(specID == 0 and 1 or specID)
    local sb = E.db.thingsUI.specialBars
    for sk, root in pairs((sb and sb.specs) or {}) do
        local d = sk ~= own and type(root) == "table" and type(root.bars) == "table" and root.bars[slotKey]
        if type(d) == "table" and d.spellID and d.customGroup == nil and M.SetupForSpec(tonumber(sk)) == setup then
            d.customGroup = -1
        end
    end
    M.IncludeSpecialBar(setup, key)
end

function M.AddSetup()
    EnsureDB()
    local db = E.db.thingsUI.barSetup
    local s = NewSetup("Setup " .. (#db.setups + 1))
    db.setups[#db.setups + 1] = s
    return s
end

function M.RemoveSetup(index)
    EnsureDB()
    local db = E.db.thingsUI.barSetup
    if index <= 1 then return end
    table.remove(db.setups, index)
    if db.active > #db.setups then db.active = 1 end
end

function M.MoveBar(setup, key, delta)
    if not setup or not setup.order then return end
    for i, k in ipairs(setup.order) do
        if k == key then
            local j = i + delta
            if j < 1 or j > #setup.order then return end
            setup.order[i], setup.order[j] = setup.order[j], setup.order[i]
            return
        end
    end
end

local function GetBarFrame(key)
    if key == "power" then
        local p = _G.ElvUF_Player
        return p and (p.Power and p.Power.Holder or p)
    elseif key == "castbar" then
        local p = _G.ElvUF_Player
        local cb = p and p.Castbar
        return cb and (cb.Holder or cb)
    elseif key == "classbar" then
        local p = _G.ElvUF_Player
        return p and p.ClassBarHolder
    elseif key == "chargebar" then
        return _G.ElvUI_thingsUI_ChargeBar
    elseif type(key) == "string" and key:sub(1, 8) == "special:" then
        return _G["TUI_SpecialBar_" .. key:sub(9)]
    elseif type(key) == "string" and key:sub(1, 6) == "combo:" then
        return ns.ComboBars and ns.ComboBars.Frame(key)
    end
end
M.GetBarFrame = GetBarFrame

-- Aura Bars and Aura Combo Bars keep their own height
local function OwnHeight(key)
    return type(key) == "string" and (key:sub(1, 8) == "special:" or key:sub(1, 6) == "combo:")
end
M.OwnHeight = OwnHeight

local function IsSpecialBarAvailable(key)
    if type(key) == "string" and key:sub(1, 6) == "combo:" then
        return ns.ComboBars ~= nil and ns.ComboBars.Available(key)
    end
    if type(key) ~= "string" or key:sub(1, 8) ~= "special:" then return true end
    local slotKey = key:sub(9)
    local SB = ns.SpecialBars
    if not SB or not SB.GetBarDB then return false end
    local bdb = SB.GetBarDB(slotKey)
    if type(bdb) ~= "table" then return false end
    if bdb.customGroup ~= nil then return false end
    if SB.SpellLearned and bdb.spellID and not SB.SpellLearned(bdb.spellID) then return false end
    return (bdb.enabled == true) and (bdb.spellID ~= nil)
end
M.IsSpecialBarAvailable = IsSpecialBarAvailable

-- why an Aura Bar sits out of the stack on this spec
function M.AuraBarOutReason(key)
    local SB = ns.SpecialBars
    local bdb = SB and SB.GetBarDB and SB.GetBarDB(key:sub(9))
    if type(bdb) ~= "table" or not bdb.spellID then return "empty on this spec" end
    local gid = bdb.customGroup
    local g = type(gid) == "number" and gid > 0 and ns.CustomBars and ns.CustomBars.GroupByID and ns.CustomBars.GroupByID(gid)
    if g then return "in " .. (g.name or "a Bar Group") .. " on this spec" end
    if gid ~= nil then return "Standalone on this spec" end
    if not bdb.enabled then return "off on this spec" end
    return "not talented"
end

function M.GetTopmostBarFrame()
    EnsureDB()
    local setup = M.GetActiveSetup()
    if not setup or not setup.order then return nil end
    for i = #setup.order, 1, -1 do
        local key = setup.order[i]
        local b   = setup.bars[key]
        local isSpecial = type(key) == "string" and key:sub(1, 8) == "special:"
        local isInStack = b and b.enabled and (isSpecial or b.mode == "NHT")
        if isInStack and IsSpecialBarAvailable(key) then
            local f = GetBarFrame(key)
            if f and f.IsShown and f:IsShown() then return f end
        end
    end
    return nil
end

local function GetBarHeight(key, setup)
    setup = setup or M.GetActiveSetup()
    local bh = setup and setup.barHeights
    if bh and type(bh[key]) == "number" and bh[key] > 0 then return bh[key] end
    local udb = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.player
    if key == "power" then
        local dh = E.db.thingsUI and E.db.thingsUI.barSetup and E.db.thingsUI.barSetup.powerDetachedHeight
        if dh then return dh end
        if udb and udb.power and udb.power.height then return udb.power.height end
    elseif key == "castbar" then
        if udb and udb.castbar and udb.castbar.height then return udb.castbar.height end
    elseif key == "classbar" then
        if udb and udb.classbar and udb.classbar.height then return udb.classbar.height end
    elseif key == "chargebar" then
        local cb = E.db.thingsUI and E.db.thingsUI.chargeBar
        if cb and cb.height then return cb.height end
    elseif type(key) == "string" and key:sub(1, 8) == "special:" then
        local SB = ns.SpecialBars
        if SB and SB.GetBarDB then
            local bdb = SB.GetBarDB(key:sub(9))
            if type(bdb) == "table" and bdb.height then return bdb.height end
        end
    elseif type(key) == "string" and key:sub(1, 6) == "combo:" then
        local h = ns.ComboBars and ns.ComboBars.StackHeight(key)
        if h then return h end
    end
    local f = GetBarFrame(key)
    if f and f.GetHeight then return f:GetHeight() or 0 end
    return 0
end
M.GetBarHeight = GetBarHeight

local DEFAULT_ATTACHED_HEIGHT = 15
local function GetAttachedHeight(setup, key)
    local t = setup and setup.attachedHeights
    local v = t and t[key]
    if type(v) == "number" and v > 0 then return v end
    return DEFAULT_ATTACHED_HEIGHT
end
local function SetAttachedHeight(setup, key, value)
    if type(value) ~= "number" or value < 1 then return end
    setup.attachedHeights = setup.attachedHeights or {}
    setup.attachedHeights[key] = value
end
M.GetAttachedHeight = GetAttachedHeight
M.SetAttachedHeight = SetAttachedHeight

local function HasAttachedMode(key)
    return key == "power" or key == "classbar"
end
M.HasAttachedMode = HasAttachedMode

local function IsAttachedNow(key)
    if not HasAttachedMode(key) then return false end
    local s = M.GetActiveSetup()
    local b = s and s.bars and s.bars[key]
    return b and b.mode == "ATTACHED" or false
end
M.IsAttachedNow = IsAttachedNow

-- Attached class bar away from ElvUI's top spot: detached, parent FRAME, hung on the player frame
local HANG = {
    HEALTH_BOTTOM = { "BOTTOMLEFT", "health", "BOTTOMLEFT" },
    ABOVE = { "BOTTOMLEFT", "frame", "TOPLEFT" },
    BELOW = { "TOPLEFT", "frame", "BOTTOMLEFT" },
}
local function ClassbarHang(setup)
    local b = setup and setup.bars and setup.bars.classbar
    return (b and b.enabled and b.mode == "ATTACHED" and HANG[b.attachPoint or ""]) and b or nil
end

function M.PlaceHungClassbar()
    if not M.IsActive() then return end
    local b = ClassbarHang(M.GetActiveSetup())
    local p = _G.ElvUF_Player
    local holder = p and p.ClassBarHolder
    if not (b and holder) or (InCombatLockdown() and holder:IsProtected()) then return end
    local h = HANG[b.attachPoint]
    local health = p.Health and (p.Health.backdrop or p.Health)
    local ref = (h[2] == "health" and health) or p
    -- under/over the frame, lined up with the health bar (a portrait sits beside it)
    local dx = 0
    if ref == p and health and health:GetLeft() and p:GetLeft() then dx = health:GetLeft() - p:GetLeft() end
    holder:ClearAllPoints()
    holder:SetPoint(h[1], ref, h[3], dx + (b.attachX or 0), b.attachY or 0)
end

local classbarHooked = false
local function HookClassbarConfigure(UF)
    if classbarHooked or not (UF and UF.Configure_ClassBar) then return end
    classbarHooked = true
    hooksecurefunc(UF, "Configure_ClassBar", function(_, frame)
        if not (frame and frame.unit == "player" and M.IsActive() and ClassbarHang(M.GetActiveSetup())) then return end
        M.PlaceHungClassbar()
        -- ElvUI turns the detached bar's mover back on
        if ns.MoverSync and ns.MoverSync.Queue then ns.MoverSync.Queue() end
    end)
end

local function SafeUpdatePlayerUF(UF)
    if not UF or not UF.CreateAndUpdateUF then return false end
    local frame = _G.ElvUF_Player
    if not frame then return false end
    local key = frame.ClassBar
    if type(key) ~= "string" or not frame[key] or not frame[key].IsShown then
        return false
    end
    return select(1, pcall(UF.CreateAndUpdateUF, UF, "player"))
end

local function SafeConfigureCastbar(UF, frame)
    if UF and UF.Configure_Castbar and frame then
        return pcall(UF.Configure_Castbar, UF, frame)
    end
end

local function WriteBarHeightToDB(key, value)
    if type(value) ~= "number" or value < 1 then return end
    local UF = (E and E.GetModule) and E:GetModule("UnitFrames", true) or nil

    if key == "power" then
        local pdb = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.player and E.db.unitframe.units.player.power
        if not pdb then return end
        if pdb.height == value then return end
        pdb.height = value
        SafeUpdatePlayerUF(UF)

    elseif key == "castbar" then
        local cdb = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.player and E.db.unitframe.units.player.castbar
        if not cdb then return end
        if cdb.height == value then return end
        cdb.height = value
        SafeConfigureCastbar(UF, _G.ElvUF_Player)

    elseif key == "classbar" then
        local cbdb = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.player and E.db.unitframe.units.player.classbar
        if not cbdb then return end
        if cbdb.height == value then return end
        cbdb.height = value
        SafeUpdatePlayerUF(UF)

    elseif key == "chargebar" then
        local cb = E.db.thingsUI and E.db.thingsUI.chargeBar
        if not cb then return end
        if cb.height == value then return end
        cb.height = value
        local f = _G.ElvUI_thingsUI_ChargeBar
        if f and f.SetHeight then f:SetHeight(value) end
        if TUI.UpdateChargeBar then TUI:UpdateChargeBar() end

    elseif type(key) == "string" and key:sub(1, 8) == "special:" then
        local SB = ns.SpecialBars
        if SB and SB.GetBarDB then
            local bdb = SB.GetBarDB(key:sub(9))
            if type(bdb) == "table" then
                if bdb.height == value then return end
                bdb.height = value
            end
        end
        if TUI.QueueSpecialBarsUpdate then TUI:QueueSpecialBarsUpdate() end

    elseif type(key) == "string" and key:sub(1, 6) == "combo:" then
        if ns.ComboBars then ns.ComboBars.SetHeight(key, value) end
    end
end

local function SetBarHeight(key, value, setup)
    if type(value) ~= "number" or value < 1 then return end
    setup = setup or M.GetActiveSetup()
    local b = setup and setup.bars and setup.bars[key]
    local mode = b and b.mode
    local isSpecial = OwnHeight(key)
    local isActive = setup == M.GetActiveSetup()

    if HasAttachedMode(key) and mode == "ATTACHED" then
        SetAttachedHeight(setup, key, value)
    elseif not isSpecial then
        setup.barHeights = setup.barHeights or {}
        setup.barHeights[key] = value
        if isActive and key == "power" then
            E.db.thingsUI.barSetup.powerDetachedHeight = value
        end
    end
    if isActive or isSpecial then
        WriteBarHeightToDB(key, value)
    end
end

M.SetBarHeight = SetBarHeight
local function GetClusterWidth()
    local v = _G.EssentialCooldownViewer
    local p = (v and ns.CDMIcons and ns.CDMIcons.GetProxy and ns.CDMIcons.GetProxy(v)) or v
    if p and p.GetWidth then
        local w = p:GetWidth() or 0
        if w > 1 then return w + 2 end
    end
    return 0
end

function M.IsActive()
    if E.db.thingsUI.barSetup and E.db.thingsUI.barSetup.enabled == false then return false end
    local s = M.GetActiveSetup()
    return s ~= nil
end

function M.GetInheritedWidth()
    local setup = M.GetActiveSetup()
    if not setup or not setup.inheritWidth then return nil end
    local w = GetClusterWidth()
    if setup.minWidth and setup.minWidth > w then w = setup.minWidth end
    w = w + (setup.widthOffset or 0)
    if w <= 1 then return nil end
    return math.floor(w + 0.5)
end

local lastWidth = {}

function M.ResetWidthCache() wipe(lastWidth) end

-- Height by Position (per setup): key -> height for the bars in the first places of the stack
M.MAX_POS = 5
M.ORDINAL = { "1st", "2nd", "3rd", "4th", "5th" }
local MAX_POS = M.MAX_POS
local posHeight, posPlace = {}, {}
function M.PositionHeight(key) return posHeight[key] end
-- the place (1..5) and height a bar of the active setup holds right now
function M.PositionPlace(key) return posPlace[key], posHeight[key] end

-- the bars in the stack's first places right now, for the options' starting values
function M.StackKeysInOrder(setup)
    local out = {}
    for _, key in ipairs((setup and setup.order) or {}) do
        local b = setup.bars and setup.bars[key]
        if b and b.enabled and b.mode == "NHT" and IsSpecialBarAvailable(key) then
            out[#out + 1] = key
        end
    end
    return out
end

function M.RestoreBarsToElvUI()
    if InCombatLockdown() then return end
    local UF = (E and E.GetModule) and E:GetModule("UnitFrames", true) or nil
    if not UF then return end
    M._managed = nil
    posHeight, posPlace = {}, {}
    -- Bar Setup may have hidden the power bar (Disabled mode) — bring it back.
    local pw = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.player and E.db.unitframe.units.player.power
    if pw and pw.enable == false then pw.enable = true end
    SafeConfigureCastbar(UF, _G.ElvUF_Player)
    SafeUpdatePlayerUF(UF)
    local cb = _G.ElvUF_Player and _G.ElvUF_Player.Castbar
    local holderFrame = cb and (cb.Holder or cb)
    local moved = (holderFrame and holderFrame.mover and holderFrame)
               or (cb and cb.mover and cb) or nil
    if moved and moved.mover.name and E.SetMoverPoints then
        pcall(E.SetMoverPoints, E, moved.mover.name, moved)
    end

    local cbh = _G.ElvUF_Player and _G.ElvUF_Player.ClassBarHolder
    if cbh and cbh.mover and cbh.mover.name and E.SetMoverPoints then
        pcall(E.SetMoverPoints, E, cbh.mover.name, cbh)
    end
    wipe(lastWidth)
end

local function ApplyBarWidth(key, width)
    if not width then return end
    local UF = (E and E.GetModule) and E:GetModule("UnitFrames", true) or nil
    local frame = _G.ElvUF_Player
    if not frame or not UF then return end

    if key == "power" then
        local pdb = E.db.unitframe.units.player.power
        if not pdb or not pdb.detachFromFrame then return end
        if pdb.detachedWidth == width and lastWidth.power == width then return end
        pdb.detachedWidth = width
        lastWidth.power = width
        SafeUpdatePlayerUF(UF)

    elseif key == "castbar" then
        local cdb = E.db.unitframe.units.player.castbar
        if not cdb then return end
        if cdb.width == width and lastWidth.castbar == width then return end
        cdb.width = width
        lastWidth.castbar = width
        SafeConfigureCastbar(UF, frame)

    elseif key == "classbar" then
        local cbdb = E.db.unitframe.units.player.classbar
        if not cbdb then return end
        if cbdb.detachedWidth == width and lastWidth.classbar == width then return end
        cbdb.detachedWidth = width
        lastWidth.classbar = width
        SafeUpdatePlayerUF(UF)

    elseif key == "chargebar" then
        if lastWidth.chargebar == width then return end
        local f = _G.ElvUI_thingsUI_ChargeBar
        if f and f.SetWidth then
            if ns.Pixel and ns.Pixel.SetSize then
                ns.Pixel.SetSize(f, width, f:GetHeight() or 18)
            else
                f:SetWidth(width)
            end
            lastWidth.chargebar = width
            if ns.ChargeBar and ns.ChargeBar.RequestUpdate then
                ns.ChargeBar.RequestUpdate()
            end
        end

    elseif type(key) == "string" and key:sub(1, 8) == "special:" then

        local slotKey = key:sub(9)
        local SB = ns.SpecialBars
        if SB and SB.GetBarDB then
            local bdb = SB.GetBarDB(slotKey)
            if type(bdb) == "table" then
                if lastWidth[key] == width and bdb.width == width then return end
                bdb.width = width
                lastWidth[key] = width
            end
        end
        local f = _G["TUI_SpecialBar_" .. slotKey]
        if f and f.SetWidth then f:SetWidth(width) end
        if TUI.QueueSpecialBarsUpdate then TUI:QueueSpecialBarsUpdate() end

    elseif type(key) == "string" and key:sub(1, 6) == "combo:" then
        local f = ns.ComboBars and ns.ComboBars.Frame(key)
        if f and math.abs((f:GetWidth() or 0) - width) > 0.01 then f:SetWidth(width) end
    end
end

local function IsDescendantOf(maybeChild, ancestor)
    if not maybeChild or not ancestor then return false end
    local p = maybeChild
    for _ = 1, 12 do
        if p == ancestor then return true end
        if not p.GetParent then return false end
        p = p:GetParent()
        if not p then return false end
    end
    return false
end

local positioning = false
function M.PositionStack(positionOnly)
    if positioning then return end
    EnsureDB()
    if E.db.thingsUI.barSetup and E.db.thingsUI.barSetup.enabled == false then return end
    local setup = M.GetActiveSetup()
    if not setup then return end

    local anchorName = setup.anchorFrame or "EssentialCooldownViewer"
    local stackAnchor = (ns.CDMIcons and ns.CDMIcons.ProxyForName and ns.CDMIcons.ProxyForName(anchorName))
        or _G[anchorName]

    local inCombat = InCombatLockdown()

    positionOnly = positionOnly or inCombat
    positioning = true
    M._managed = true

    local baseWidth = M.GetInheritedWidth()
    local function EffectiveWidth(b)
        if not baseWidth then return nil end
        return baseWidth + (b.widthOffset or 0)
    end

    local function ShouldInclude(key)
        if key == "classbar" then
            local CM = ns.ClassbarMode
            if not (CM and CM.IsNHTForCurrentSpec and CM.IsNHTForCurrentSpec()) then
                return false
            end
            -- Dynamic Classbar (Druid)
            local cdb = E.db.thingsUI and E.db.thingsUI.classbarMode
            if cdb and cdb.dynamicClassbar and E.myclass == "DRUID" then
                local p = _G.ElvUF_Player
                local element = p and p.ClassPower
                if not (element and element:IsShown()) then
                    return false
                end
            end
            return true
        elseif key == "chargebar" then
            local CB = ns.ChargeBar
            if CB and CB.IsNHTForCurrentSpec then
                return CB.IsNHTForCurrentSpec()
            end
            return false
        elseif type(key) == "string" and (key:sub(1, 8) == "special:" or key:sub(1, 6) == "combo:") then
            return IsSpecialBarAvailable(key)
        end
        return true
    end

    -- Height by Position: the first bars that show in the stack take the setup's heights, whichever
    -- bars they are. Worked out out of combat only; in combat the heights the bars have stay
    if not positionOnly then
        local pos, place = {}, {}
        if setup.heightByPos then
            local n, k = math.min(setup.posCount or 2, MAX_POS), 0
            for _, key in ipairs(setup.order) do
                local b = setup.bars[key]
                if b and b.enabled and b.mode == "NHT" and ShouldInclude(key) then
                    k = k + 1
                    if k > n then break end
                    local h = setup.posHeights and setup.posHeights[k]
                    if h then pos[key], place[key] = h, k end
                end
            end
        end
        posPlace = place
        local auraChanged, comboChanged = false, false
        for key in pairs(posHeight) do
            if pos[key] ~= posHeight[key] then
                if key:sub(1, 8) == "special:" then auraChanged = true end
                if key:sub(1, 6) == "combo:" then comboChanged = true end
            end
        end
        for key, h in pairs(pos) do
            if posHeight[key] ~= h then
                if key:sub(1, 8) == "special:" then auraChanged = true end
                if key:sub(1, 6) == "combo:" then comboChanged = true end
            end
        end
        posHeight = pos
        if auraChanged and TUI.QueueSpecialBarsUpdate then TUI:QueueSpecialBarsUpdate() end
        if comboChanged and ns.ComboBars then ns.ComboBars.QueueRefresh() end
    end

    local UF = (E and E.GetModule) and E:GetModule("UnitFrames", true) or nil
    local function SetDetached(dbPath, want)
        local cur = dbPath.detachFromFrame
        if cur == want then return false end
        dbPath.detachFromFrame = want
        return true
    end
    local needsPlayerUF = false
    local udb = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.player
    local function PushAttachedHeight(udbBar, key)
        if not udbBar then return false end
        local saved = GetAttachedHeight(setup, key)
        if udbBar.height == saved then return false end
        udbBar.height = saved
        return true
    end
    -- Custom Texts on the power bar (the pack's [perpp]) go with Hide Power Text; only ours come back
    local function PowerCustomTexts(hide)
        local ct, root = udb.customTexts, E.db.thingsUI.barSetup
        if not ct then return false end
        local ours = root.powerHiddenTexts or {}
        root.powerHiddenTexts = ours
        local changed = false
        for name, t in pairs(ct) do
            if hide and t.attachTextTo == "Power" and t.enable ~= false then
                t.enable, ours[name], changed = false, true, true
            elseif not hide and ours[name] then
                t.enable, changed = true, true
            end
        end
        if not hide then wipe(ours) end
        return changed
    end
    if udb then
        local pBar = setup.bars.power
        if udb.power and pBar and pBar.enabled then
            local p = udb.power
            if PowerCustomTexts(pBar.mode == "ATTACHED" and pBar.hideText) then needsPlayerUF = true end
            if pBar.mode == "DISABLED" then
                if p.enable ~= false then p.enable = false; needsPlayerUF = true end
            else
                if p.enable == false then p.enable = true; needsPlayerUF = true end
                local want = (pBar.mode == "NHT" or pBar.mode == "FHT")
                if SetDetached(p, want) then needsPlayerUF = true end
                if pBar.mode == "ATTACHED" then
                    if PushAttachedHeight(p, "power") then needsPlayerUF = true end
                    local root = E.db.thingsUI.barSetup
                    if pBar.hideText then
                        if p.text_format ~= "" then
                            root.powerShownFormat = p.text_format
                            p.text_format = ""
                            needsPlayerUF = true
                        end
                    elseif p.text_format and p.text_format ~= "" then
                        root.powerShownFormat = p.text_format
                    elseif root.powerShownFormat and root.powerShownFormat ~= "" then
                        p.text_format = root.powerShownFormat
                        needsPlayerUF = true
                    end
                    if pBar.textX ~= nil and p.xOffset ~= pBar.textX then p.xOffset = pBar.textX; needsPlayerUF = true end
                    if pBar.textY ~= nil and p.yOffset ~= pBar.textY then p.yOffset = pBar.textY; needsPlayerUF = true end
                else
                    local dh = posHeight.power or (setup.barHeights and setup.barHeights.power)
                        or E.db.thingsUI.barSetup.powerDetachedHeight
                    if dh and p.height ~= dh then p.height = dh; needsPlayerUF = true end
                end
            end
        end
        local cBar = setup.bars.classbar
        if udb.classbar and cBar and cBar.enabled then
            local hang = ClassbarHang(setup) ~= nil
            local want = (cBar.mode == "NHT" or cBar.mode == "FHT")
            if SetDetached(udb.classbar, want or hang) then needsPlayerUF = true end
            local wantParent = want and "UIPARENT" or "FRAME"
            if udb.classbar.parent ~= wantParent then
                udb.classbar.parent = wantParent
                needsPlayerUF = true
            end
            if hang then
                HookClassbarConfigure(UF)
                -- the width ElvUI gives it attached
                local w = _G.ElvUF_Player and _G.ElvUF_Player.CLASSBAR_WIDTH
                if w and udb.classbar.detachedWidth ~= w then
                    udb.classbar.detachedWidth = w
                    lastWidth.classbar = nil
                    needsPlayerUF = true
                end
            end
            if cBar.mode == "ATTACHED"
               and PushAttachedHeight(udb.classbar, "classbar") then
                needsPlayerUF = true
            end
        end
    end
    if needsPlayerUF and not positionOnly then
        SafeUpdatePlayerUF(UF)
    end
    M.PlaceHungClassbar()

    -- Aura Bars keep their own height: their position's height only sizes them in the stack
    if not positionOnly then
        for _, key in ipairs(setup.order) do
            local b = setup.bars[key]
            local h = posHeight[key] or (setup.barHeights and setup.barHeights[key])
            if h and b and b.enabled and key ~= "power" and not OwnHeight(key)
               and b.mode ~= "ATTACHED" and b.mode ~= "DISABLED" then
                WriteBarHeightToDB(key, h)
            end
        end
    end

    -- a druid's classbar hides outside cat form: keep its width current anyway, it can
    -- only be resized out of combat and may show mid-fight
    local function SizedWhileHidden(key)
        if key ~= "classbar" then return false end
        local CM = ns.ClassbarMode
        return CM and CM.IsNHTForCurrentSpec and CM.IsNHTForCurrentSpec() or false
    end
    if baseWidth and not positionOnly then
        for _, key in ipairs(setup.order) do
            local b = setup.bars[key]
            if b and b.enabled and b.mode == "NHT" and (ShouldInclude(key) or SizedWhileHidden(key)) then
                ApplyBarWidth(key, EffectiveWidth(b))
            end
        end
    end

    local accY = (setup.yOffset or 0)
    local gap  = setup.gap or 1
    local xOff = setup.xOffset or 0
    local trinketShift = 0
    if stackAnchor then
        for _, key in ipairs(setup.order) do
            local b = setup.bars[key]
            if b and b.enabled and b.mode == "NHT" and ShouldInclude(key) then
                local f = GetBarFrame(key)
                if f and f ~= stackAnchor and not IsDescendantOf(stackAnchor, f) then
                    local protected = inCombat and f.IsProtected and f:IsProtected()
                    local w = EffectiveWidth(b)
                    if w and f.SetWidth and not positionOnly and not protected then f:SetWidth(w) end
                    accY = accY + gap
                    if not protected then
                        local localXOff = xOff + (b.xOffset or 0) + trinketShift + (BAR_X_NUDGE[key] or 0)
                        if key == "castbar" then
                            local wo = b.widthOffset or 0
                            if wo ~= 0 then localXOff = localXOff - (wo / 2) end
                        end
                        f:ClearAllPoints()
                        f:SetPoint(setup.anchorPoint or "BOTTOM", stackAnchor, setup.anchorTo or "TOP", localXOff, accY)
                    end
                    local SB = key:sub(1, 8) == "special:" and ns.SpecialBars
                    accY = accY + (posHeight[key]
                        or ((SB and SB.StackHeight) and SB.StackHeight(key:sub(9)))
                        or GetBarHeight(key, setup))
                end
            end
        end
    end

    for _, key in ipairs(setup.order) do
        local b = setup.bars[key]
        if b and b.enabled and b.mode == "FHT" then
            local f = GetBarFrame(key)
            local anchorName = b.anchorFrame or "UIParent"
            local target = _G[anchorName]

            if target and anchorName == "ElvUF_Player_CastBar" and target.Holder then
                target = target.Holder
            end
            if f and target and f ~= target and not IsDescendantOf(target, f)
               and not (inCombat and f.IsProtected and f:IsProtected()) then
                if b.inheritWidthFromAnchor and target.GetWidth and not positionOnly then
                    local aw = target:GetWidth() or 0
                    if aw > 1 then
                        ApplyBarWidth(key, aw + (b.inheritWidthOffset or 0))
                    end
                end
                if key == "castbar" and not positionOnly then
                    local UF = (E and E.GetModule) and E:GetModule("UnitFrames", true) or nil
                    SafeConfigureCastbar(UF, _G.ElvUF_Player)
                end
                f:ClearAllPoints()
                f:SetPoint(b.anchorPoint or "CENTER", target, b.anchorTo or "CENTER", b.xOffset or 0, b.yOffset or 0)
            end
        end
    end

    positioning = false

    if not inCombat and ns.CDMIcons and ns.CDMIcons.RefreshAll then
        ns.CDMIcons.RefreshAll()
    end

    if ns.MoverSync and ns.MoverSync.Queue then
        ns.MoverSync.Queue()
    end
end

function M.ApplyStack()
    M.PositionStack()
end

local shiftPending = false
local function QueueShapeshiftRestack()
    if shiftPending then return end

    if E.myclass ~= "DRUID" then return end
    local cdb = E.db.thingsUI and E.db.thingsUI.classbarMode
    if not (cdb and cdb.dynamicClassbar) then return end
    shiftPending = true
    C_Timer.After(0.15, function()
        shiftPending = false
        M.PositionStack()
    end)
end

local hookedClassPowerEl
local function EnsureClassPowerHook()
    if E.myclass ~= "DRUID" then return end
    local p = _G.ElvUF_Player
    local el = p and p.ClassPower
    if not el or el == hookedClassPowerEl or not el.HookScript then return end
    hookedClassPowerEl = el
    el:HookScript("OnShow", QueueShapeshiftRestack)
    el:HookScript("OnHide", QueueShapeshiftRestack)
end

local watcher
function M.InstallWatcher()
    if watcher then return end
    watcher = CreateFrame("Frame")
    watcher:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    watcher:RegisterEvent("PLAYER_LOGIN")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    if E.myclass == "DRUID" then
        watcher:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    end
    watcher:SetScript("OnEvent", function(_, event)
        if event == "UPDATE_SHAPESHIFT_FORM" then
            QueueShapeshiftRestack()
            return
        end
        if InCombatLockdown() then return end
        local function tick() EnsureClassPowerHook(); M.ApplyStack() end
        C_Timer.After(0.5, tick)
        -- a fight's end only has what combat held back; the later passes are for loading in
        if event == "PLAYER_REGEN_ENABLED" then return end
        C_Timer.After(2.0, tick)
        C_Timer.After(4.0, tick)
    end)
end

function TUI:UpdateBarSetup()
    EnsureDB()
    M.InstallWatcher()
    if E.db.thingsUI.barSetup and E.db.thingsUI.barSetup.enabled == false then
        -- only bars this session moved need handing back (it rebuilds ElvUI's player frame)
        if M._managed and C_Timer and C_Timer.After then C_Timer.After(0.2, M.RestoreBarsToElvUI) end
        return
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, M.ApplyStack)
    end
end
