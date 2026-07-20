local _, ns = ...
local TUI = ns.TUI
local E   = ns.E

ns.TUIMeter = ns.TUIMeter or {}
local M = ns.TUIMeter

local LSM = E.Libs and E.Libs.LSM
local MAX_ROWS = 60

local function Secret(v) return issecretvalue and issecretvalue(v) end

local function DB() return E.db.thingsUI and E.db.thingsUI.damageMeter end
local function TDB()
    local db = DB()
    if not db then return nil end
    db.tui = db.tui or {}
    return db.tui
end
local function Active()
    return DB() and DB().provider == "TUI" and C_DamageMeter and C_DamageMeter.GetCombatSessionFromType
end

local function Cells(db)
    local h = db.splitH or 0.5
    local v = db.splitV or 0.5
    local l = db.layout or "2"
    if l == "1" then return { { 0, 0, 1, 1 } } end
    if l == "1L2R" then return { { 0, 0, h, 1 }, { h, 0, 1 - h, v }, { h, v, 1 - h, 1 - v } } end
    if l == "2L1R" then return { { 0, 0, h, v }, { 0, v, h, 1 - v }, { h, 0, 1 - h, 1 } } end
    if l == "4" then return { { 0, 0, h, v }, { h, 0, 1 - h, v }, { 0, v, h, 1 - v }, { h, v, 1 - h, 1 - v } } end
    return { { 0, 0, h, 1 }, { h, 0, 1 - h, 1 } }
end

local TYPE_NAMES = {}
local TYPE_ORDER = {}
local TYPE_NO_PS = {}
do
    local T = Enum.DamageMeterType
    if T then
        local defs = {
            { T.DamageDone,        "Damage Done" },
            { T.Dps,               "DPS" },
            { T.HealingDone,       "Healing Done" },
            { T.Hps,               "HPS" },
            { T.DamageTaken,       "Damage Taken" },
            { T.EnemyDamageTaken,  "Enemy Damage Taken" },
            { T.Interrupts,        "Interrupts" },
            { T.Dispels,           "Dispels" },
            { T.Deaths,            "Deaths" },
        }
        for _, d in ipairs(defs) do
            if d[1] then TYPE_NAMES[d[1]] = d[2]; TYPE_ORDER[#TYPE_ORDER + 1] = d[1] end
        end
        if T.Interrupts then TYPE_NO_PS[T.Interrupts] = true end
        if T.Dispels then TYPE_NO_PS[T.Dispels] = true end
        if T.Deaths then TYPE_NO_PS[T.Deaths] = true end
    end
end

local function Abbrev(v)
    if Secret(v) then return AbbreviateNumbers and AbbreviateNumbers(v) or "" end
    if v == nil then return "" end
    if type(v) == "number" then v = math.floor(v + 0.5) end
    if AbbreviateNumbers then return AbbreviateNumbers(v) end
    if type(v) ~= "number" then return tostring(v) end
    if v >= 1e6 then return ("%.1fM"):format(v / 1e6) end
    if v >= 1e3 then return ("%.0fK"):format(v / 1e3) end
    return ("%.0f"):format(v)
end

local function ValueText(total, perSec, mode)
    if mode == "total" then return ("%s"):format(Abbrev(total)) end
    if mode == "persec" then return ("%s"):format(Abbrev(perSec)) end
    return ("%s (%s)"):format(Abbrev(total), Abbrev(perSec))
end

local function Clock(d)
    return ("%d:%02d"):format(math.floor(d / 60), math.floor(d % 60))
end

local windows = {}
local ApplyLayout, RefreshWindow, EnterDrill, RenderPopout
local function Panel() return _G.RightChatPanel end

local function FetchSession(win)
    local cfg = win.cfg
    local t = cfg.type or 0
    if type(cfg.session) == "number" then
        -- new PTR API; errors while no session data exists
        local ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, cfg.session, t)
        if ok then return session end
        return nil
    end
    local sType = (cfg.session == "overall") and Enum.DamageMeterSessionType.Overall or Enum.DamageMeterSessionType.Current
    -- new PTR API; errors while no session data exists
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, sType, t)
    if ok then return session end
    return nil
end

local function FetchSource(session, t, d)
    if not d then return nil end
    -- new PTR API; errors while no session data exists / on secret args in combat
    local ok, src
    if type(session) == "number" then
        ok, src = pcall(C_DamageMeter.GetCombatSessionSourceFromID, session, t, d.guid, d.creatureID)
    else
        local sType = (session == "overall") and Enum.DamageMeterSessionType.Overall or Enum.DamageMeterSessionType.Current
        ok, src = pcall(C_DamageMeter.GetCombatSessionSourceFromType, sType, t, d.guid, d.creatureID)
    end
    if ok then return src end
    return nil
end

local function FetchDrill(win)
    return FetchSource(win.cfg.session, win.cfg.type or 0, win.drill)
end

local function DrillInfo(src)
    if not src then return nil end
    if not (src.sourceGUID or src.sourceCreatureID) then return nil end
    return {
        guid = src.sourceGUID,
        creatureID = src.sourceCreatureID,
        name = src.name,
        classFile = (not Secret(src.classFilename)) and src.classFilename or nil,
    }
end

local function PlainStr(v)
    if v and not Secret(v) and v ~= "" then return v end
    return nil
end

local function SpellDisplay(spell, drill)
    local det = spell.combatSpellDetails
    local sid = spell.spellID
    if Secret(sid) or sid == 0 then sid = nil end
    local spellName = sid and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(sid) or nil
    local unitName = PlainStr(det and det.unitName)
    local unitClass = PlainStr(det and det.unitClassFilename)
    local creature = PlainStr(spell.creatureName)
    local db = TDB()
    local colorNames = db and db.classColor == false

    local name
    if spellName then
        if creature then
            name = spellName .. " (" .. creature .. ")"
        elseif unitName then
            local un = unitName
            if colorNames and unitClass and RAID_CLASS_COLORS[unitClass] then
                un = RAID_CLASS_COLORS[unitClass]:WrapTextInColorCode(un)
            end
            name = spellName .. " - " .. un
        else
            name = spellName
        end
    elseif unitName then
        name = unitName
        if colorNames and unitClass and RAID_CLASS_COLORS[unitClass] then
            name = RAID_CLASS_COLORS[unitClass]:WrapTextInColorCode(name)
        end
    else
        name = det and det.unitName or nil
    end

    local classFile = unitClass or (drill and drill.classFile) or nil
    local icon = det and det.specIconID
    if Secret(icon) or icon == 0 then icon = nil end
    if not icon and sid then
        icon = (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(sid)) or 134400
    end
    return name, icon or 0, classFile
end

local function PlayerTargets(ctx)
    local playerName = ctx.drill and ctx.drill.name
    if not playerName or Secret(playerName) then return nil end
    local T = Enum.DamageMeterType
    local edt = T and T.EnemyDamageTaken
    if not edt then return nil end
    local session
    -- new PTR API; errors while no session data exists
    if type(ctx.session) == "number" then
        local ok, s = pcall(C_DamageMeter.GetCombatSessionFromID, ctx.session, edt)
        session = ok and s or nil
    else
        local sType = (ctx.session == "overall") and Enum.DamageMeterSessionType.Overall or Enum.DamageMeterSessionType.Current
        local ok, s = pcall(C_DamageMeter.GetCombatSessionFromType, sType, edt)
        session = ok and s or nil
    end
    local enemies = session and session.combatSources
    if not enemies then return nil end
    local out, byName = {}, {}
    for i = 1, math.min(#enemies, 40) do
        local en = enemies[i]
        local src = FetchSource(ctx.session, edt, { guid = en.sourceGUID, creatureID = en.sourceCreatureID })
        local spells = src and src.combatSpells
        if spells then
            local sum = 0
            for _, sp in ipairs(spells) do
                local det = sp.combatSpellDetails
                local un = det and det.unitName
                if un and not Secret(un) and un == playerName then
                    local amt = sp.totalAmount
                    if type(amt) == "number" and not Secret(amt) then sum = sum + amt end
                end
            end
            if sum > 0 then
                local nm = PlainStr(en.name) or "?"
                local idx = byName[nm]
                if idx then
                    out[idx].amount = out[idx].amount + sum
                else
                    out[#out + 1] = { name = nm, amount = sum }
                    byName[nm] = #out
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.amount > b.amount end)
    return out
end

local function SpellRowSrc(win, i, spell, drill)
    win._scratch = win._scratch or {}
    local t = win._scratch[i] or {}
    win._scratch[i] = t
    local name, icon, classFile = SpellDisplay(spell, drill)
    t.name = name
    t.specIconID = icon
    t.classFilename = classFile
    t.totalAmount = spell.totalAmount
    t.amountPerSecond = spell.amountPerSecond
    return t
end

local function StyleRowStatics(win, bar, db)
    local font = LSM and LSM:Fetch("font", db.font or "Expressway")
    local flag = (db.fontOutline ~= "NONE") and (db.fontOutline or "OUTLINE") or ""
    local nameSize = db.fontSize or 12
    local valSize  = db.valueFontSize or nameSize
    if font then
        bar.pos:SetFont(font, nameSize, flag)
        bar.label:SetFont(font, nameSize, flag)
        bar.amount:SetFont(font, valSize, flag)
    end
    local shadow = db.fontShadow
    for _, fs in ipairs({ bar.pos, bar.label, bar.amount }) do
        if shadow then fs:SetShadowColor(0, 0, 0, 1); fs:SetShadowOffset(1, -1)
        else fs:SetShadowColor(0, 0, 0, 0) end
    end
    local tex = (db.barTexture and db.barTexture ~= "" and LSM) and LSM:Fetch("statusbar", db.barTexture)
    bar.fill:SetStatusBarTexture(tex or [[Interface\Buttons\WHITE8x8]])
    bar.bg:SetColorTexture(0, 0, 0, db.barBgAlpha or 0)
    local s = db.iconBorderSize or 1
    local c = db.iconBorderColor or {}
    if db.iconBorder then
        bar.iconBorder:SetBackdrop({ edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = s })
        bar.iconBorder:SetBackdropBorderColor(c.r or 0, c.g or 0, c.b or 0, c.a or 1)
    end
    if db.barBorder ~= false then
        bar.barBorder:SetBackdrop({ edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = s })
        bar.barBorder:SetBackdropBorderColor(c.r or 0, c.g or 0, c.b or 0, c.a or 1)
        bar.barBorder:Show()
    else
        bar.barBorder:Hide()
    end
    bar._staticSig = win._staticSig
end

local function EffectiveBars(win, db)
    local conf = db.barHeight or 23.4
    local s = db.barSpacing or -1
    local H = win.content:GetHeight() or 0
    local step = conf + s
    if H < 5 or step <= 0.5 then return conf, 1 end
    if db.autoFit == false then
        return conf, math.min(MAX_ROWS, math.max(1, math.floor((H + s + 0.001) / step)))
    end
    local n = math.min(MAX_ROWS, math.max(1, math.floor((H + s) / step + 0.5)))
    return (H - (n - 1) * s) / n, n
end

local function PositionRow(win, row, i, db)
    local barH = win._barH or db.barHeight or 23.4
    local sp   = db.barSpacing or -1
    row:SetHeight(barH)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", win.content, "TOPLEFT", 0, -((i - 1) * (barH + sp)))
    row:SetPoint("TOPRIGHT", win.content, "TOPRIGHT", 0, -((i - 1) * (barH + sp)))
end

local function CreateRow(win, i)
    local db = TDB()
    local row = CreateFrame("Button", nil, win.content)
    row:Hide()

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)

    row.fill = CreateFrame("StatusBar", nil, row)
    row.fill:SetMinMaxValues(0, 1)
    row.fill:SetValue(0)

    row.barBorder = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.barBorder:SetAllPoints(row.fill)
    row.barBorder:SetFrameLevel(row.fill:GetFrameLevel() + 1)
    row.barBorder:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.icon:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)

    row.iconBorder = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.iconBorder:SetFrameLevel(row:GetFrameLevel() + 3)

    local tf = CreateFrame("Frame", nil, row.fill)
    tf:SetAllPoints(row.fill)
    tf:SetFrameLevel(row.fill:GetFrameLevel() + 2)
    row.pos    = tf:CreateFontString(nil, "OVERLAY")
    row.label  = tf:CreateFontString(nil, "OVERLAY")
    row.amount = tf:CreateFontString(nil, "OVERLAY")
    row.pos:SetPoint("LEFT", tf, "LEFT", 2, 0)
    row.amount:SetPoint("RIGHT", tf, "RIGHT", -2, 0)
    row.amount:SetJustifyH("RIGHT")
    row.label:SetPoint("LEFT", row.pos, "RIGHT", 2, 0)
    row.label:SetPoint("RIGHT", row.amount, "LEFT", -3, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    row:SetScript("OnClick", function(self, btn)
        if btn == "RightButton" then
            if win.drill then
                win.drill = nil; win.scroll = 0; RefreshWindow(win)
            else
                M.ShowModeMenu(win)
            end
        elseif btn == "MiddleButton" and not win.drill and not M.testMode then
            M.OpenPopout(win, DrillInfo(self._src))
        elseif btn == "LeftButton" and not M.testMode then
            if win.drill then
                M.OpenPopout(win, win.drill)
            else
                EnterDrill(win, self._src)
            end
        end
    end)

    PositionRow(win, row, i, db)
    win.rows[i] = row
    return row
end

local function LayoutRows(win)
    local db = TDB()
    win._barH = EffectiveBars(win, db)
    for i, row in ipairs(win.rows) do
        PositionRow(win, row, i, db)
    end
end

local function UpdateRow(win, i, rank, src, maxAmt, db)
    local row = win.rows[i] or CreateRow(win, i)
    if row._staticSig ~= win._staticSig then StyleRowStatics(win, row, db) end

    local barH = win._barH or db.barHeight or 23.4
    local showIcon = (db.iconStyle or "spec") ~= "none"
    local classFile = src.classFilename
    if Secret(classFile) then classFile = nil end

    local iconW = 0
    if showIcon then
        local z = db.iconZoom or 0.05
        local specIcon = src.specIconID
        if Secret(specIcon) then specIcon = nil end
        if db.iconStyle == "spec" and specIcon and specIcon ~= 0 then
            row.icon:SetTexture(specIcon)
            row.icon:SetTexCoord(z, 1 - z, z, 1 - z)
            row.icon:Show(); iconW = barH
        elseif classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile] then
            local tc = CLASS_ICON_TCOORDS[classFile]
            local w, h = tc[2] - tc[1], tc[4] - tc[3]
            row.icon:SetTexture([[Interface\Glues\CharacterCreate\UI-CharacterCreate-Classes]])
            row.icon:SetTexCoord(tc[1] + w * z, tc[2] - w * z, tc[3] + h * z, tc[4] - h * z)
            row.icon:Show(); iconW = barH
        else
            row.icon:Hide()
        end
    else
        row.icon:Hide()
    end
    row.icon:SetWidth(barH)
    row.iconBorder:ClearAllPoints()
    row.iconBorder:SetPoint("TOPLEFT", row.icon, "TOPLEFT", 0, 0)
    row.iconBorder:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 0, 0)
    row.iconBorder:SetShown(db.iconBorder and row.icon:IsShown() or false)

    row.fill:ClearAllPoints()
    row.fill:SetPoint("TOPLEFT", row, "TOPLEFT", iconW + (iconW > 0 and (db.iconGap or 0) or 0), 0)
    row.fill:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)

    if db.classColor ~= false and classFile and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        row.fill:SetStatusBarColor(c.r, c.g, c.b)
    else
        local c = db.barColor or {}
        row.fill:SetStatusBarColor(c.r or 0.35, c.g or 0.55, c.b or 0.8)
    end

    row.fill:SetMinMaxValues(0, maxAmt)
    row.fill:SetValue(src.totalAmount or 0)

    row.pos:SetText(db.showRank ~= false and (rank .. ".") or "")
    local name = src.name
    if name then
        if win.drill then
            row.label:SetText(name)
        else
            row.label:SetText(Ambiguate and Ambiguate(name, "short") or name)
        end
    else
        row.label:SetText("")
    end
    local fmt = TYPE_NO_PS[win.cfg and win.cfg.type or 0] and "total" or db.numberFormat
    row.amount:SetText(ValueText(src.totalAmount, src.amountPerSecond, fmt))
    row._src = src
    row:Show()
end

local frozenCur, frozenOverall = 0, 0
local combatStart
local lastCombatEnd = 0

local function SessionTimerText(win, session)
    local s = win.cfg.session
    if type(s) == "number" then
        local d = session and session.durationSeconds
        if Secret(d) then return "" end
        if type(d) == "number" then return Clock(d) end
        return ""
    end
    local overall = s == "overall"
    if not InCombatLockdown() and C_DamageMeter.GetSessionDurationSeconds then
        local sType = overall and Enum.DamageMeterSessionType.Overall or Enum.DamageMeterSessionType.Current
        -- new PTR API; errors while no session data exists
        local ok, d = pcall(C_DamageMeter.GetSessionDurationSeconds, sType)
        if ok and type(d) == "number" and not Secret(d) then
            if overall then frozenOverall = d else frozenCur = d end
        end
    end
    local shown
    if overall then
        shown = (frozenOverall or 0) + (combatStart and (GetTime() - combatStart) or 0)
    else
        shown = combatStart and (GetTime() - combatStart) or frozenCur or 0
    end
    return Clock(shown)
end


local testSources
local function TestSources()
    if testSources then return testSources end
    testSources = {}
    local names = {
        "Gruff", "Baregeir", "Odla", "Meiler", "Drgejr", "Leoridk", "Zerlat", "Quiys",
        "Yrwenmonk", "Mcmengdh", "Askeladd", "Tussi", "Bolle", "Knerten", "Pesten", "Lusa",
        "Brumund", "Sindre", "Vaffel", "Krampus", "Fjompen", "Snerk", "Vims", "Lurifax",
    }
    local numClasses = GetNumClasses and GetNumClasses() or 13
    local total = #names
    for i = 1, total do
        local classID = ((i - 1) % numClasses) + 1
        local _, classFile = GetClassInfo(classID)
        local specIcon = 0
        if GetNumSpecializationsForClassID and GetSpecializationInfoForClassID then
            local n = GetNumSpecializationsForClassID(classID)
            if n and n > 0 then
                local _, _, _, icon = GetSpecializationInfoForClassID(classID, ((i - 1) % n) + 1)
                specIcon = icon or 0
            end
        end
        local amt = math.floor(2500000 * (1 - (i - 1) / total)) + math.random(0, 40000)
        testSources[i] = {
            name = names[i],
            classFilename = classFile,
            specIconID = specIcon,
            totalAmount = amt,
            amountPerSecond = math.floor(amt / 90),
        }
    end
    return testSources
end

RefreshWindow = function(win)
    if not (win.frame:IsShown() and Active()) then return end
    local db = TDB()
    local session, sources, drill
    if M.testMode then
        sources = TestSources()
    elseif win.drill then
        drill = FetchDrill(win)
        sources = drill and drill.combatSpells
    else
        session = FetchSession(win)
        sources = session and session.combatSources
    end
    local total = sources and #sources or 0
    win._lastTotal = total
    local bh, vis = EffectiveBars(win, db)
    if math.abs(bh - (win._barH or 0)) > 0.005 then
        win._barH = bh
        for i, row in ipairs(win.rows) do PositionRow(win, row, i, db) end
    end
    local maxScroll = math.max(0, total - vis)
    if (win.scroll or 0) > maxScroll then win.scroll = maxScroll end
    local first = 1 + (win.scroll or 0)
    local maxAmt = (sources and sources[1] and sources[1].totalAmount) or 1
    local shown = 0
    for rank = first, math.min(total, first + vis - 1) do
        shown = shown + 1
        local src = sources[rank]
        if win.drill then src = SpellRowSrc(win, rank, src, win.drill) end
        UpdateRow(win, shown, rank, src, maxAmt, db)
    end
    for i = shown + 1, #win.rows do win.rows[i]:Hide() end
    if win.drill then
        win.title:SetText(win.drill.name or "")
    else
        local title = TYPE_NAMES[win.cfg.type or 0] or "Damage Done"
        if db.sessionTag ~= false then
            local s = win.cfg.session
            local tag = (type(s) == "number") and ("#" .. s) or (s == "overall" and "O" or "C")
            title = title .. " |cFF808080[" .. tag .. "]|r"
        end
        win.title:SetText(title)
    end
    if win.cfg.showTimer then
        win.timer:Show()
        win.timer:SetText(M.testMode and "1:30" or SessionTimerText(win, session))
    else
        win.timer:Hide()
    end
end

function M.RefreshAll()
    for _, win in ipairs(windows) do RefreshWindow(win) end
    if RenderPopout then RenderPopout() end
end

EnterDrill = function(win, src)
    local d = DrillInfo(src)
    if not d then return end
    win.drill = d
    win.scroll = 0
    RefreshWindow(win)
end

local popout

local function EnsurePopout()
    if popout then return popout end
    popout = CreateFrame("Frame", "TUI_MeterPopout", E.UIParent, "BackdropTemplate")
    popout:SetFrameStrata("DIALOG")
    popout:SetSize(460, 200)
    popout:SetPoint("CENTER", E.UIParent, "CENTER", 0, 60)
    popout:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]], edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    popout:SetBackdropColor(0.04, 0.04, 0.04, 0.97)
    popout:SetBackdropBorderColor(0, 0, 0, 1)
    popout:SetMovable(true)
    popout:SetClampedToScreen(true)
    popout:EnableMouse(true)
    popout:EnableMouseWheel(true)
    popout:SetScript("OnMouseUp", function(_, btn)
        if btn == "RightButton" then popout:Hide() end
    end)
    popout:SetScript("OnMouseWheel", function(_, d)
        if d > 0 then popout.offset = math.max(0, (popout.offset or 0) - 1)
        else popout.offset = (popout.offset or 0) + 1 end
        RenderPopout()
    end)
    popout.rows = {}

    local header = CreateFrame("Button", nil, popout)
    header:SetPoint("TOPLEFT", popout, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", popout, "TOPRIGHT", -1, -1)
    header:SetHeight(26)
    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints(header)
    header.bg:SetColorTexture(0.08, 0.08, 0.08, 1)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() popout:StartMoving() end)
    header:SetScript("OnDragStop", function() popout:StopMovingOrSizing() end)
    header:RegisterForClicks("RightButtonUp")
    header:SetScript("OnClick", function() popout:Hide() end)
    popout.header = header
    popout.title = header:CreateFontString(nil, "OVERLAY")
    popout.title:SetPoint("LEFT", header, "LEFT", 8, 0)
    popout.tag = header:CreateFontString(nil, "OVERLAY")
    popout.tag:SetPoint("RIGHT", header, "RIGHT", -8, 0)
    tinsert(UISpecialFrames, "TUI_MeterPopout")
    return popout
end

local function PopoutRow(i)
    local p = popout
    if p.rows[i] then return p.rows[i] end
    local row = CreateFrame("Frame", nil, p)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.fill = CreateFrame("StatusBar", nil, row)
    row.fill:SetMinMaxValues(0, 1)
    row.fill:SetValue(0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.icon:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    local tf = CreateFrame("Frame", nil, row.fill)
    tf:SetAllPoints(row.fill)
    tf:SetFrameLevel(row.fill:GetFrameLevel() + 2)
    row.pos = tf:CreateFontString(nil, "OVERLAY")
    row.label = tf:CreateFontString(nil, "OVERLAY")
    row.amount = tf:CreateFontString(nil, "OVERLAY")
    row.pos:SetPoint("LEFT", tf, "LEFT", 4, 0)
    row.amount:SetPoint("RIGHT", tf, "RIGHT", -6, 0)
    row.amount:SetJustifyH("RIGHT")
    row.label:SetPoint("LEFT", row.pos, "RIGHT", 4, 0)
    row.label:SetPoint("RIGHT", row.amount, "LEFT", -6, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    p.rows[i] = row
    return row
end

RenderPopout = function()
    local p = popout
    if not (p and p:IsShown() and p.ctx and Active()) then return end
    local db = TDB()
    local ctx = p.ctx
    local src = FetchSource(ctx.session, ctx.type or 0, ctx.drill)
    local spells = src and src.combatSpells or {}
    local total = #spells
    local rowH = math.max(20, math.floor((db.barHeight or 20) + 0.5))
    local maxRows = math.max(4, math.floor(((E.UIParent:GetHeight() or 800) * 0.6) / (rowH + 1)))
    local offMax = math.max(0, total - maxRows)
    if (p.offset or 0) > offMax then p.offset = offMax end
    local first = 1 + (p.offset or 0)
    local font = (LSM and LSM:Fetch("font", db.font or "Expressway")) or STANDARD_TEXT_FONT
    local flag = (db.fontOutline ~= "NONE") and (db.fontOutline or "OUTLINE") or ""
    local tex = (db.barTexture and db.barTexture ~= "" and LSM) and LSM:Fetch("statusbar", db.barTexture) or [[Interface\Buttons\WHITE8x8]]
    local cc = ctx.drill.classFile and RAID_CLASS_COLORS[ctx.drill.classFile]
    local maxAmt = (spells[1] and spells[1].totalAmount) or 1
    local pTotal = src and src.totalAmount
    local z = db.iconZoom or 0.05
    local y = 28
    local shown = 0
    for rank = first, math.min(total, first + maxRows - 1) do
        shown = shown + 1
        local sp = spells[rank]
        local row = PopoutRow(shown)
        row:Show()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -y)
        row:SetPoint("TOPRIGHT", p, "TOPRIGHT", -1, -y)
        row:SetHeight(rowH)
        y = y + rowH + 1
        row.bg:SetColorTexture(0, 0, 0, math.max(db.barBgAlpha or 0, 0.25))
        row.fill:SetStatusBarTexture(tex)
        row.pos:SetFont(font, db.fontSize or 12, flag)
        row.label:SetFont(font, db.fontSize or 12, flag)
        row.amount:SetFont(font, db.valueFontSize or 12, flag)
        local nm, icon, cf = SpellDisplay(sp, ctx.drill)
        row.icon:SetWidth(rowH)
        if icon and icon ~= 0 then
            row.icon:SetTexture(icon)
            row.icon:SetTexCoord(z, 1 - z, z, 1 - z)
        elseif cf and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[cf] then
            local tc = CLASS_ICON_TCOORDS[cf]
            local w, h = tc[2] - tc[1], tc[4] - tc[3]
            row.icon:SetTexture([[Interface\Glues\CharacterCreate\UI-CharacterCreate-Classes]])
            row.icon:SetTexCoord(tc[1] + w * z, tc[2] - w * z, tc[3] + h * z, tc[4] - h * z)
        else
            row.icon:SetTexture(134400)
            row.icon:SetTexCoord(z, 1 - z, z, 1 - z)
        end
        row.fill:ClearAllPoints()
        row.fill:SetPoint("TOPLEFT", row, "TOPLEFT", rowH + 1, 0)
        row.fill:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        local rc = (db.classColor ~= false) and cf and RAID_CLASS_COLORS[cf] or cc
        if rc then
            row.fill:SetStatusBarColor(rc.r, rc.g, rc.b)
        else
            local c = db.barColor or {}
            row.fill:SetStatusBarColor(c.r or 0.35, c.g or 0.55, c.b or 0.8)
        end
        row.fill:SetMinMaxValues(0, maxAmt)
        row.fill:SetValue(sp.totalAmount or 0)
        row.pos:SetText(rank .. ".")
        if nm then row.label:SetText(nm) else row.label:SetText("") end
        local vt = ValueText(sp.totalAmount, sp.amountPerSecond, db.numberFormat)
        local ta = sp.totalAmount
        if type(ta) == "number" and not Secret(ta) and type(pTotal) == "number" and not Secret(pTotal) and pTotal > 0 then
            vt = vt .. ("  |cFF808080%.1f%%|r"):format(ta / pTotal * 100)
        end
        row.amount:SetText(vt)
    end

    local T = Enum.DamageMeterType
    local isDamage = T and (ctx.type == T.DamageDone or ctx.type == T.Dps) or (ctx.type or 0) == 0
    if isDamage and not InCombatLockdown() then
        local targets = PlayerTargets(ctx)
        if targets and #targets > 0 then
            shown = shown + 1
            local hr = PopoutRow(shown)
            hr:Show()
            hr:ClearAllPoints()
            hr:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -y)
            hr:SetPoint("TOPRIGHT", p, "TOPRIGHT", -1, -y)
            hr:SetHeight(18)
            y = y + 19
            hr.bg:SetColorTexture(0, 0, 0, 0)
            hr.fill:SetMinMaxValues(0, 1)
            hr.fill:SetValue(0)
            hr.icon:SetTexture(nil)
            hr.icon:SetWidth(1)
            hr.pos:SetFont(font, db.fontSize or 12, flag)
            hr.label:SetFont(font, db.fontSize or 12, flag)
            hr.amount:SetFont(font, db.valueFontSize or 12, flag)
            hr.pos:SetText("")
            hr.label:SetText("|cFF808080Targets|r")
            hr.amount:SetText("")
            local tMax = targets[1].amount
            for ti = 1, #targets do
                local tg = targets[ti]
                shown = shown + 1
                local row = PopoutRow(shown)
                row:Show()
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -y)
                row:SetPoint("TOPRIGHT", p, "TOPRIGHT", -1, -y)
                row:SetHeight(rowH)
                y = y + rowH + 1
                row.bg:SetColorTexture(0, 0, 0, math.max(db.barBgAlpha or 0, 0.25))
                row.fill:SetStatusBarTexture(tex)
                row.fill:ClearAllPoints()
                row.fill:SetPoint("TOPLEFT", row, "TOPLEFT", 1, 0)
                row.fill:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
                row.fill:SetStatusBarColor(0.6, 0.22, 0.22)
                row.fill:SetMinMaxValues(0, tMax > 0 and tMax or 1)
                row.fill:SetValue(tg.amount)
                row.icon:SetTexture(nil)
                row.icon:SetWidth(1)
                row.pos:SetFont(font, db.fontSize or 12, flag)
                row.label:SetFont(font, db.fontSize or 12, flag)
                row.amount:SetFont(font, db.valueFontSize or 12, flag)
                row.pos:SetText(ti .. ".")
                row.label:SetText(tg.name)
                local vt = Abbrev(tg.amount)
                if type(pTotal) == "number" and not Secret(pTotal) and pTotal > 0 then
                    vt = vt .. ("  |cFF808080%.1f%%|r"):format(tg.amount / pTotal * 100)
                end
                row.amount:SetText(vt)
            end
        end
    end

    for i = shown + 1, #p.rows do p.rows[i]:Hide() end
    p:SetHeight(y + 2)
    p.title:SetFont(font, db.headerFontSize or 13, flag)
    p.tag:SetFont(font, math.max(8, (db.headerFontSize or 13) - 2), flag)
    local nm = ctx.drill.name
    local typeName = TYPE_NAMES[ctx.type or 0] or ""
    if nm and not Secret(nm) then
        p.title:SetText("|cFF808080" .. typeName .. ":|r " .. nm)
    else
        p.title:SetText(nm or "")
    end
    local s = ctx.session
    local tag = (type(s) == "number") and ("#" .. s) or (s == "overall" and "Overall" or "Current")
    p.tag:SetText("|cFF808080" .. tag .. "|r")
end

function M.OpenPopout(win, drill)
    if not drill then return end
    local p = EnsurePopout()
    p.ctx = { session = win.cfg.session, type = win.cfg.type, drill = drill }
    p.offset = 0
    p:Show()
    RenderPopout()
end

local function StopExpand(win)
    if not win._expanding then return end
    win._expanding = nil
    win.header:SetScript("OnUpdate", nil)
    if win._prevStrata then win.frame:SetFrameStrata(win._prevStrata); win._prevStrata = nil end
    if ApplyLayout then ApplyLayout() end
    M.RefreshAll()
end

local function ExpandMaxHeight(win, db)
    local total = win._lastTotal or 0
    local step = (db.barHeight or 18) + (db.barSpacing or 1)
    local needed = (db.headerHeight or 20) + (db.contentPad or 1) + total * step + 8
    local screen = (E.UIParent:GetTop() or 1000) - (win.frame:GetBottom() or 0) - 10
    return math.max(win._expandBaseH or 0, math.min(needed, screen))
end

local function ExpandTick(win)
    if not IsMouseButtonDown("LeftButton") then StopExpand(win); return end
    local db = TDB()
    if not db then return end
    local _, cy = GetCursorPosition()
    cy = cy / win.frame:GetEffectiveScale()
    local dh = cy - (win._expandStartY or cy)
    local newH = math.max(win._expandBaseH or 0, math.min((win._expandBaseH or 0) + dh, ExpandMaxHeight(win, db)))
    win.frame:SetHeight(newH)
    RefreshWindow(win)
end

local menuFrame
local MENU_ROW = 20
local RenderMenu

local function EnsureMenu()
    if menuFrame then return menuFrame end
    menuFrame = CreateFrame("Frame", "TUI_MeterMenuFrame", E.UIParent, "BackdropTemplate")
    menuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    menuFrame:SetFrameLevel(110)
    menuFrame:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]], edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    menuFrame:SetBackdropColor(0.04, 0.04, 0.04, 0.97)
    menuFrame:SetBackdropBorderColor(0, 0, 0, 1)
    menuFrame:SetClampedToScreen(true)
    menuFrame:Hide()
    menuFrame.rows = {}

    local watcher = CreateFrame("Frame")
    watcher:SetScript("OnEvent", function()
        if menuFrame:IsShown() and not menuFrame:IsMouseOver() then menuFrame:Hide() end
    end)
    menuFrame:SetScript("OnShow", function() watcher:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    menuFrame:SetScript("OnHide", function()
        watcher:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        menuFrame._closedWin, menuFrame._closedKind, menuFrame._closedAt = menuFrame.win, menuFrame.kind, GetTime()
        menuFrame.win = nil
        menuFrame.kind = nil
    end)

    menuFrame.upHint = menuFrame:CreateFontString(nil, "OVERLAY")
    menuFrame.upHint:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    menuFrame.upHint:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -5, -4)
    menuFrame.upHint:SetText("|cFF808080^|r")
    menuFrame.upHint:Hide()
    menuFrame.downHint = menuFrame:CreateFontString(nil, "OVERLAY")
    menuFrame.downHint:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    menuFrame.downHint:SetPoint("BOTTOMRIGHT", menuFrame, "BOTTOMRIGHT", -5, 4)
    menuFrame.downHint:SetText("|cFF808080v|r")
    menuFrame.downHint:Hide()

    menuFrame:EnableMouseWheel(true)
    menuFrame:SetScript("OnMouseWheel", function(_, d)
        if d > 0 then
            if (menuFrame.offset or 0) <= 0 then return end
            menuFrame.offset = menuFrame.offset - 1
        else
            if not menuFrame._lastShown or menuFrame._lastShown >= #(menuFrame.entries or {}) then return end
            menuFrame.offset = (menuFrame.offset or 0) + 1
        end
        RenderMenu(menuFrame)
    end)

    tinsert(UISpecialFrames, "TUI_MeterMenuFrame")
    return menuFrame
end

local function MenuRow(i)
    local m = EnsureMenu()
    if m.rows[i] then return m.rows[i] end
    local row = CreateFrame("Button", nil, m)
    row:SetHeight(MENU_ROW)
    row:SetPoint("TOPLEFT", m, "TOPLEFT", 1, -(1 + (i - 1) * MENU_ROW))
    row:SetPoint("TOPRIGHT", m, "TOPRIGHT", -1, -(1 + (i - 1) * MENU_ROW))
    row:RegisterForClicks("LeftButtonUp")
    row:SetHighlightTexture([[Interface\Buttons\WHITE8x8]])
    row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.line = row:CreateTexture(nil, "OVERLAY")
    row.line:SetColorTexture(1, 1, 1, 0.12)
    row.line:SetHeight(1)
    row.line:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.line:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    m.rows[i] = row
    return row
end

local function DoResetData()
    if C_DamageMeter.ResetAllCombatSessions then C_DamageMeter.ResetAllCombatSessions() end
    frozenCur, frozenOverall = 0, 0
    for _, w in ipairs(windows) do
        if w.cfg and type(w.cfg.session) == "number" then w.cfg.session = "current" end
    end
    M.RefreshAll()
end

local confirm
local function EnsureConfirm()
    if confirm then return confirm end
    confirm = CreateFrame("Frame", "TUI_MeterConfirmFrame", E.UIParent, "BackdropTemplate")
    confirm:SetFrameStrata("FULLSCREEN_DIALOG")
    confirm:SetFrameLevel(130)
    confirm:SetSize(260, 84)
    confirm:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]], edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    confirm:SetBackdropColor(0.04, 0.04, 0.04, 0.97)
    confirm:SetBackdropBorderColor(0, 0, 0, 1)
    confirm:EnableMouse(true)
    confirm:Hide()
    confirm.text = confirm:CreateFontString(nil, "OVERLAY")
    confirm.text:SetPoint("TOP", confirm, "TOP", 0, -16)
    local function MkBtn(x)
        local b = CreateFrame("Button", nil, confirm, "BackdropTemplate")
        b:SetSize(105, 26)
        b:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]], edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
        b:SetBackdropColor(0.12, 0.12, 0.12, 1)
        b:SetBackdropBorderColor(0, 0, 0, 1)
        b:SetPoint("BOTTOM", confirm, "BOTTOM", x, 12)
        b.text = b:CreateFontString(nil, "OVERLAY")
        b.text:SetPoint("CENTER")
        b:SetHighlightTexture([[Interface\Buttons\WHITE8x8]])
        b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
        return b
    end
    confirm.yes = MkBtn(-57)
    confirm.no = MkBtn(57)
    confirm.yes:SetScript("OnClick", function() confirm:Hide(); DoResetData() end)
    confirm.no:SetScript("OnClick", function() confirm:Hide() end)
    tinsert(UISpecialFrames, "TUI_MeterConfirmFrame")
    return confirm
end

local function ShowResetConfirm()
    local db = TDB()
    if not db then return end
    local c = EnsureConfirm()
    local font = (LSM and LSM:Fetch("font", db.font or "Expressway")) or STANDARD_TEXT_FONT
    local flag = (db.fontOutline ~= "NONE") and (db.fontOutline or "OUTLINE") or ""
    c.text:SetFont(font, (db.fontSize or 12) + 1, flag)
    c.yes.text:SetFont(font, db.fontSize or 12, flag)
    c.no.text:SetFont(font, db.fontSize or 12, flag)
    c.text:SetText("Reset all damage meter data?")
    c.yes.text:SetText("|cFFFF5C5CReset|r")
    c.no.text:SetText("Cancel")
    c:ClearAllPoints()
    local p = Panel()
    if E.db.thingsUI.rightChatAsBackground and p then
        c:SetPoint("CENTER", p, "CENTER", 0, 30)
    else
        c:SetPoint("CENTER", E.UIParent, "CENTER", 0, -100)
    end
    c:Show()
end

local function BuildTypeEntries(win)
    local e = {}
    for _, t in ipairs(TYPE_ORDER) do
        e[#e + 1] = { label = TYPE_NAMES[t], selected = win.cfg.type == t, func = function()
            win.cfg.type = t; win.scroll = 0; win.drill = nil
        end }
    end
    return e
end

local function AllOnSameSegment()
    local id
    for _, w in ipairs(windows) do
        if w.cfg then
            if type(w.cfg.session) ~= "number" then return false end
            id = id or w.cfg.session
            if w.cfg.session ~= id then return false end
        end
    end
    return id ~= nil
end

local function SetSession(win, session)
    if AllOnSameSegment() then
        for _, w in ipairs(windows) do
            if w.cfg then w.cfg.session = session; w.scroll = 0; w.drill = nil end
        end
    else
        win.cfg.session = session
        win.scroll = 0
        win.drill = nil
    end
end

local function BuildSessionEntries(win)
    local db = TDB()
    local e = {}
    e[#e + 1] = { label = "Current", selected = win.cfg.session ~= "overall" and type(win.cfg.session) ~= "number", func = function()
        SetSession(win, "current")
    end }
    e[#e + 1] = { label = "Overall", selected = win.cfg.session == "overall", func = function()
        SetSession(win, "overall")
    end }
    local avail = C_DamageMeter.GetAvailableCombatSessions and C_DamageMeter.GetAvailableCombatSessions()
    if avail and #avail > 0 then
        e[#e + 1] = { divider = true }
        e[#e + 1] = { header = "Segments" }
        local maxSeg = db.menuSegments or 20
        local count = 0
        for i = #avail, 1, -1 do
            count = count + 1
            if count > maxSeg then break end
            local s = avail[i]
            local nm = (s.name and s.name ~= "") and s.name or ("Combat " .. s.sessionID)
            if type(s.durationSeconds) == "number" and not Secret(s.durationSeconds) then
                nm = ("%s |cFF808080[%s]|r"):format(nm, Clock(s.durationSeconds))
            end
            nm = ("|cFF808080%d.|r %s"):format(count, nm)
            local id = s.sessionID
            e[#e + 1] = { label = nm, selected = win.cfg.session == id, func = function()
                for _, w in ipairs(windows) do
                    if w.cfg then w.cfg.session = id; w.scroll = 0; w.drill = nil end
                end
            end }
        end
    end
    e[#e + 1] = { divider = true }
    e[#e + 1] = { label = "Test Mode", selected = M.testMode and true or false, func = function()
        M.testMode = not M.testMode
    end }
    e[#e + 1] = { label = "Reset Data", func = ShowResetConfirm }
    return e
end

RenderMenu = function(m)
    local db = TDB()
    if not db then return end
    local font = LSM and LSM:Fetch("font", db.font or "Expressway")
    local flag = (db.fontOutline ~= "NONE") and (db.fontOutline or "OUTLINE") or ""
    local entries = m.entries or {}
    local first = m.offset or 0
    local h = 2
    local shown = 0
    m._lastShown = first
    for idx = first + 1, #entries do
        local entry = entries[idx]
        local rowH = entry.divider and 7 or MENU_ROW
        if h + rowH + 2 > (m.maxH or 800) and shown > 0 then break end
        shown = shown + 1
        local row = MenuRow(shown)
        row:Show()
        row.line:Hide()
        row.text:SetFont(font or STANDARD_TEXT_FONT, db.fontSize or 12, flag)
        row.text:SetText("")
        row:SetScript("OnClick", nil)
        if entry.divider then
            row:EnableMouse(false)
            row:SetHeight(7)
            row.line:Show()
        else
            row:SetHeight(MENU_ROW)
            row:EnableMouse(not entry.header)
            if entry.header then
                row.text:SetText("|cFF808080" .. entry.header .. "|r")
            elseif entry.selected then
                row.text:SetText("|cFF8080FF" .. entry.label .. "|r")
            else
                row.text:SetText(entry.label)
            end
            row:SetScript("OnClick", function()
                if entry.func then entry.func() end
                m:Hide()
                M.RefreshAll()
            end)
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", m, "TOPLEFT", 1, -h)
        row:SetPoint("TOPRIGHT", m, "TOPRIGHT", -1, -h)
        h = h + rowH
        m._lastShown = idx
    end
    for i = shown + 1, #m.rows do m.rows[i]:Hide() end
    if m.autoHeight then m:SetHeight(h + 2) end
    m.upHint:SetShown(first > 0)
    m.downHint:SetShown(m._lastShown < #entries)
end

function M.ShowModeMenu(win, kind)
    kind = kind or "types"
    local m = EnsureMenu()
    if m:IsShown() and m.win == win and m.kind == kind then m:Hide(); return end
    if m._closedWin == win and m._closedKind == kind and GetTime() - (m._closedAt or 0) < 0.4 then
        m._closedWin = nil
        return
    end
    m._closedWin = nil
    local db = TDB()
    if not db then return end
    m.entries = (kind == "session") and BuildSessionEntries(win) or BuildTypeEntries(win)
    m.offset = 0
    m:ClearAllPoints()
    if kind == "session" then
        m.autoHeight = true
        local headerTop = win.header:GetTop() or 0
        local screenTop = E.UIParent:GetTop() or 1000
        m.maxH = math.max(MENU_ROW + 4, screenTop - headerTop - 8)
        m:SetPoint("BOTTOMLEFT", win.header, "TOPLEFT", 0, 1)
        m:SetPoint("BOTTOMRIGHT", win.header, "TOPRIGHT", 0, 1)
    else
        m.autoHeight = false
        m.maxH = math.max(MENU_ROW + 4, (win.frame:GetHeight() or 200) - (win.header:GetHeight() or 20))
        m:SetPoint("TOPLEFT", win.header, "BOTTOMLEFT", 0, 1)
        m:SetPoint("BOTTOMRIGHT", win.frame, "BOTTOMRIGHT", 0, 0)
    end
    m.win = win
    m.kind = kind
    RenderMenu(m)
    m:Show()
end

local function CreateWindow(i)
    local db = TDB()
    local f = CreateFrame("Frame", "TUI_MeterWindow" .. i, E.UIParent, "BackdropTemplate")
    f:SetSize(db.windowWidth or 260, db.windowHeight or 180)
    f:SetPoint("CENTER", E.UIParent, "CENTER", (i - 1) * 280 - 400, -200)

    local header = CreateFrame("Button", nil, f)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    header:SetHeight(db.headerHeight or 20)
    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints(header)
    header.bg:SetColorTexture(0.08, 0.08, 0.08, 0.9)
    header:RegisterForClicks("RightButtonUp")
    header:RegisterForDrag("LeftButton")

    header.borderFrame = CreateFrame("Frame", nil, header, "BackdropTemplate")
    header.borderFrame:SetAllPoints(header)
    header.borderFrame:SetFrameLevel(header:GetFrameLevel() + 5)
    header.borderFrame:Hide()

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetPoint("LEFT", header, "LEFT", 4, 0)
    local timer = header:CreateFontString(nil, "OVERLAY")
    timer:SetPoint("RIGHT", header, "RIGHT", -4, 0)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -(db.contentPad or 1))
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    content:SetClipsChildren(true)

    f.divider = CreateFrame("Frame", nil, f)
    f.divider:SetFrameLevel(f:GetFrameLevel() + 10)
    f.divider.tex = f.divider:CreateTexture(nil, "OVERLAY")
    f.divider.tex:SetAllPoints(f.divider)
    f.divider:Hide()

    f.dividerTop = CreateFrame("Frame", nil, f)
    f.dividerTop:SetFrameLevel(f:GetFrameLevel() + 10)
    f.dividerTop.tex = f.dividerTop:CreateTexture(nil, "OVERLAY")
    f.dividerTop.tex:SetAllPoints(f.dividerTop)
    f.dividerTop:Hide()

    local win = { frame = f, header = header, title = title, timer = timer, content = content, rows = {}, cfg = db.windows[i], index = i, scroll = 0 }
    header:SetScript("OnClick", function() M.ShowModeMenu(win, "session") end)
    header:SetScript("OnDragStart", function()
        if not (Active() and E.db.thingsUI.rightChatAsBackground and Panel()) then return end
        local left, bottom = f:GetLeft(), f:GetBottom()
        if not (left and bottom) then return end
        win._expandBaseH = f:GetHeight()
        local _, cy = GetCursorPosition()
        win._expandStartY = cy / f:GetEffectiveScale()
        win._prevStrata = f:GetFrameStrata()
        f:SetFrameStrata("DIALOG")
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", E.UIParent, "BOTTOMLEFT", left, bottom)
        win._expanding = true
        header:SetScript("OnUpdate", function() ExpandTick(win) end)
    end)
    header:SetScript("OnDragStop", function() StopExpand(win) end)

    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        win.scroll = math.max(0, (win.scroll or 0) - delta)
        RefreshWindow(win)
    end)
    f:SetScript("OnMouseUp", function(_, btn)
        if btn == "RightButton" then
            if win.drill then
                win.drill = nil; win.scroll = 0; RefreshWindow(win)
            else
                M.ShowModeMenu(win)
            end
        end
    end)

    if ns.MoverSync and ns.MoverSync.CreateManaged then
        ns.MoverSync.CreateManaged(f, "TUI_MeterMover" .. i, "thingsUI Meter " .. i, {
            configString = "thingsUI,modulesTab,damageMeter",
            shouldDisable = function()
                return not Active() or (E.db.thingsUI.rightChatAsBackground and true or false)
            end,
            onSave = function(point, relPoint, x, y)
                local c = win.cfg
                if c then c.point, c.relPoint, c.x, c.y = point, relPoint, x, y end
            end,
        })
    end

    windows[i] = win
    return win
end

local function ApplyWindowChrome(win)
    local db = TDB()
    local font = LSM and LSM:Fetch("font", db.font or "Expressway")
    local flag = (db.fontOutline ~= "NONE") and (db.fontOutline or "OUTLINE") or ""
    if font then
        win.title:SetFont(font, db.headerFontSize or 11, flag)
        win.timer:SetFont(font, db.headerFontSize or 11, flag)
    end
    win.header:SetHeight(db.headerHeight or 20)

    local wb, hb = db.windowBorder == true, db.headerBorder ~= false
    local bs = db.windowBorderSize or 1
    local c = db.windowBorderColor or {}
    local br, bg2, bb, ba = c.r or 0, c.g or 0, c.b or 0, c.a or 1
    if wb then
        win.frame:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]], edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = bs })
        win.frame:SetBackdropBorderColor(br, bg2, bb, ba)
    else
        win.frame:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
    end
    win.frame:SetBackdropColor(0, 0, 0, db.bgAlpha or 0)

    local header = win.header
    if hb then
        header.borderFrame:SetBackdrop({ edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = bs })
        header.borderFrame:SetBackdropBorderColor(br, bg2, bb, ba)
        header.borderFrame:Show()
    else
        header.borderFrame:Hide()
    end

    local gap = db.windowGap or -1
    local off = -(gap + bs) / 2
    local divider = win.frame.divider
    if win._dividerOn and db.windowDivider ~= false then
        divider:ClearAllPoints()
        divider:SetPoint("TOPLEFT", win.frame, "TOPLEFT", off, 0)
        divider:SetPoint("BOTTOMLEFT", win.frame, "BOTTOMLEFT", off, 0)
        divider:SetWidth(bs)
        divider.tex:SetColorTexture(br, bg2, bb, ba)
        divider:Show()
    else
        divider:Hide()
    end
    local dividerTop = win.frame.dividerTop
    if win._dividerTopOn and db.windowDivider ~= false then
        dividerTop:ClearAllPoints()
        dividerTop:SetPoint("TOPLEFT", win.frame, "TOPLEFT", 0, -off)
        dividerTop:SetPoint("TOPRIGHT", win.frame, "TOPRIGHT", 0, -off)
        dividerTop:SetHeight(bs)
        dividerTop.tex:SetColorTexture(br, bg2, bb, ba)
        dividerTop:Show()
    else
        dividerTop:Hide()
    end

    local inset = wb and bs or 0
    win.content:ClearAllPoints()
    win.content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", inset, -(db.contentPad or 1))
    win.content:SetPoint("BOTTOMRIGHT", win.frame, "BOTTOMRIGHT", -inset, inset)
end

ApplyLayout = function()
    if not Active() then return end
    local db = TDB()
    local cells = Cells(db)
    local docked = E.db.thingsUI.rightChatAsBackground and Panel()
    local pad = db.panelInset or 0
    local gap = db.windowGap or -1
    for i, win in ipairs(windows) do
        if win._expanding then StopExpand(win) end
        local cell = cells[i]
        local shown = cell and win.cfg and win.cfg.shown ~= false
        win._dividerOn, win._dividerTopOn = false, false
        win.frame:SetShown(shown and true or false)
        if shown then
            if docked then
                local p = Panel()
                local pw = (p:GetWidth() or 0) - pad * 2
                local ph = (p:GetHeight() or 0) - pad * 2
                if pw > 50 and ph > 50 then
                    local x0 = cell[1] * pw + (cell[1] > 0.001 and gap / 2 or 0)
                    local x1 = (cell[1] + cell[3]) * pw - ((cell[1] + cell[3]) < 0.999 and gap / 2 or 0)
                    local y0 = cell[2] * ph + (cell[2] > 0.001 and gap / 2 or 0)
                    local y1 = (cell[2] + cell[4]) * ph - ((cell[2] + cell[4]) < 0.999 and gap / 2 or 0)
                    win.frame:ClearAllPoints()
                    win.frame:SetPoint("TOPLEFT", p, "TOPLEFT", pad + x0, -(pad + y0))
                    win.frame:SetSize(math.max(20, x1 - x0), math.max(20, y1 - y0))
                    win._dividerOn = cell[1] > 0.001
                    win._dividerTopOn = cell[2] > 0.001
                end
                if ns.MoverSync then ns.MoverSync.SetManagedEnabled("TUI_MeterMover" .. i, false) end
            else
                win.frame:SetSize(db.windowWidth or 260, db.windowHeight or 180)
                local mv = _G["TUI_MeterMover" .. i]
                win.frame:ClearAllPoints()
                if mv then
                    win.frame:SetPoint("CENTER", mv, "CENTER", 0, 0)
                else
                    local cfg = win.cfg
                    if cfg.point then
                        win.frame:SetPoint(cfg.point, E.UIParent, cfg.relPoint or cfg.point, cfg.x or 0, cfg.y or 0)
                    else
                        win.frame:SetPoint("CENTER", E.UIParent, "CENTER", (i - 1) * 280 - 400, -200)
                    end
                end
                if ns.MoverSync then ns.MoverSync.SetManagedEnabled("TUI_MeterMover" .. i, true) end
            end
        elseif windows[i] and ns.MoverSync then
            ns.MoverSync.SetManagedEnabled("TUI_MeterMover" .. i, false)
        end
    end
    for _, win in ipairs(windows) do
        win._staticSig = (win._staticSig or 0) + 1
        ApplyWindowChrome(win)
        LayoutRows(win)
    end
end

local ticker
local function StopTicker()
    if ticker then ticker:Cancel(); ticker = nil end
end
local function StartTicker()
    if ticker or not Active() then return end
    local rate = TDB().refreshRate or 0.5
    ticker = C_Timer.NewTicker(rate, M.RefreshAll)
end

local pendingRefresh = false
local function QueueRefresh()
    if pendingRefresh then return end
    pendingRefresh = true
    C_Timer.After(0.1, function() pendingRefresh = false; M.RefreshAll() end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
if C_DamageMeter then
    ev:RegisterEvent("DAMAGE_METER_RESET")
    ev:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
    ev:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
end
ev:SetScript("OnEvent", function(_, event)
    if not Active() then return end
    if event == "PLAYER_REGEN_DISABLED" then
        combatStart = GetTime()
        frozenCur = 0
        StartTicker()
    elseif event == "PLAYER_REGEN_ENABLED" then
        lastCombatEnd = GetTime()
        if combatStart then
            frozenOverall = (frozenOverall or 0) + (GetTime() - combatStart)
            frozenCur = GetTime() - combatStart
        end
        combatStart = nil
        StopTicker()
        M.RefreshAll()
        C_Timer.After(0.5, M.RefreshAll)
    elseif event == "DAMAGE_METER_CURRENT_SESSION_UPDATED" then
        if InCombatLockdown() then
            frozenCur = 0
            if not combatStart then combatStart = GetTime() end
            QueueRefresh()
            StartTicker()
        elseif GetTime() - lastCombatEnd < 3 then
            QueueRefresh()
        end
    elseif event == "DAMAGE_METER_RESET" then
        frozenCur, frozenOverall = 0, 0
        QueueRefresh()
    elseif event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        if not InCombatLockdown() and (GetTime() - lastCombatEnd) < 3 then QueueRefresh() end
    else
        C_Timer.After(1, function() TUI:UpdateTUIMeter() end)
    end
end)

local panelHooked = false
function TUI:UpdateTUIMeter()
    local dm = DB()
    if dm and dm.provider == "BLIZZARD" then dm.provider = "TUI" end
    if not Active() then
        for _, win in ipairs(windows) do win.frame:Hide() end
        StopTicker()
        return
    end
    local db = TDB()
    db.windows = db.windows or {}
    local n = #Cells(db)
    local T = Enum.DamageMeterType or {}
    local typeDefaults = { 0, T.HealingDone or 2, T.DamageTaken or 7, T.Interrupts or 5 }
    for i = 1, n do
        local w = db.windows[i] or {}
        db.windows[i] = w
        if w.type == nil then w.type = typeDefaults[i] or 0 end
        if w.session == nil then w.session = "current" end
        if w.shown == nil then w.shown = true end
        if w.showTimer == nil then w.showTimer = (i == 1) end
    end
    if GetCVar and GetCVar("damageMeterEnabled") ~= "0" then
        SetCVar("damageMeterEnabled", "0")
    end
    for i = 1, n do
        if not windows[i] then CreateWindow(i) end
        windows[i].cfg = db.windows[i]
    end
    for i = n + 1, #windows do
        windows[i].cfg = nil
        windows[i].frame:Hide()
    end
    if not panelHooked and Panel() then
        panelHooked = true
        hooksecurefunc(Panel(), "SetWidth",  function() C_Timer.After(0, ApplyLayout) end)
        hooksecurefunc(Panel(), "SetHeight", function() C_Timer.After(0, ApplyLayout) end)
    end
    ApplyLayout()
    M.RefreshAll()
    if InCombatLockdown() then StartTicker() end
    if ns.MoverSync and ns.MoverSync.Queue then ns.MoverSync.Queue() end
end
