local addon, ns = ...

-- load time per file group (TOC order), shown by /tui prof
ns.loadMarks = { { "start", debugprofilestop() } }
function ns.LoadMark(name) ns.loadMarks[#ns.loadMarks + 1] = { name, debugprofilestop() } end

local E, L, V, P, G = unpack(ElvUI)
local EP = LibStub("LibElvUIPlugin-1.0")

local TUI = E:NewModule("thingsUI", "AceHook-3.0", "AceEvent-3.0")

ns.addon = addon
ns.E = E
ns.EP = EP
ns.TUI = TUI
ns.LSM = E.Libs.LSM

TUI.version = C_AddOns.GetAddOnMetadata(addon, "Version") or "dev"
TUI.name = "thingsUI"

ns.skinnedBars = ns.skinnedBars or {}
ns.yoinkedBars = ns.yoinkedBars or {}

local function FireNotify()
    local E = ns.E
    local reg = (E and E.Libs and E.Libs.AceConfigRegistry)
        or LibStub("AceConfigRegistry-3.0-ElvUI", true)
        or LibStub("AceConfigRegistry-3.0", true)
    if reg and reg.NotifyChange then reg:NotifyChange("ElvUI") end
end

local notifyPending = false
function ns.NotifyChange()
    if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
        if notifyPending then return end
        notifyPending = true
        local t
        t = C_Timer.NewTicker(0.05, function()
            if not IsMouseButtonDown("LeftButton") then
                t:Cancel()
                notifyPending = false
                FireNotify()
            end
        end)
        return
    end
    FireNotify()
end

function ns.ClassColor(token)
    local c = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]) or { r = 1, g = 1, b = 1 }
    return ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
end

function ns.DeepCopy(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do out[k] = ns.DeepCopy(v) end
    return out
end

-- nil color = white
function ns.TextColor(fs, c)
    fs:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
end

-- an options list entry in its own tab color, if it has one
function ns.TabName(name, c)
    if not c then return name end
    return ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, name)
end

-- "Tab Color" toggle and swatch; tbl(create) returns the entry's table
function ns.TabColorArgs(tbl, onChange, order)
    return {
        order = order, type = "toggle", name = "Tab Color", width = 0.7,
        get = function() local t = tbl() return (t and t.tabColor) ~= nil end,
        set = function(_, v)
            tbl(true).tabColor = v and { r = 0.3, g = 0.82, b = 0.65 } or nil
            onChange()
        end,
    }, {
        order = order + 0.01, type = "color", name = "", width = 0.3,
        hidden = function() local t = tbl() return not (t and t.tabColor) end,
        get = function()
            local c = tbl().tabColor
            return c.r, c.g, c.b
        end,
        set = function(_, r, g, b)
            tbl(true).tabColor = { r = r, g = g, b = b }
            onChange()
        end,
    }
end

-- Custom Icon: a texture file ID or path, or another spell's icon; get() -> icon, set(icon or nil)
function ns.CustomIconArgs(get, set, base, hidden, disabled)
    local function none() return (hidden and hidden()) or get() == nil end
    return {
        customIcon = {
            order = base, type = "input", name = "Custom Icon", desc = "Texture file ID or path.",
            hidden = hidden, disabled = disabled,
            get = function() local v = get() return v and tostring(v) or "" end,
            set = function(_, v)
                v = strtrim(v or "")
                set(v ~= "" and (tonumber(v) or v) or nil)
            end,
        },
        iconFromSpell = {
            order = base + 0.01, type = "input", name = "Icon From Spell", desc = "Spell ID or name.",
            hidden = hidden, disabled = disabled,
            get = function() return "" end,
            set = function(_, v)
                v = strtrim(v or "")
                local info = v ~= "" and C_Spell.GetSpellInfo(tonumber(v) or v)
                if info and info.iconID then set(info.iconID) end
            end,
        },
        iconPreview = {
            order = base + 0.02, type = "description", name = "", width = 0.25, hidden = none,
            image = function() return get() end, imageWidth = 28, imageHeight = 28,
            imageCoords = { 0.08, 0.92, 0.08, 0.92 },
        },
        iconClear = {
            order = base + 0.03, type = "execute", name = "Spell's Own Icon", width = 0.9,
            hidden = none, disabled = disabled,
            func = function() set(nil) end,
        },
    }
end

-- 12.1.5+: a cap of 0 also disables the group, so it stops parsing UNIT_AURA
function ns.SetAuraGroupCap(container, key, cap)
    if container.SetAuraGroupEnabled then
        if cap > 0 then container:SetAuraGroupEnabled(key, true) end
        container:SetAuraGroupMaxFrameCount(key, cap)
        if cap <= 0 then container:SetAuraGroupEnabled(key, false) end
        return
    end
    container:SetAuraGroupMaxFrameCount(key, cap)
end

function ns.SolidDialog(f)
    local fr = f and f.frame
    if not fr then return end
    if not fr._tuiSolid then
        local t = fr:CreateTexture(nil, "BACKGROUND", nil, -7)
        t:SetPoint("TOPLEFT", 1, -1)
        t:SetPoint("BOTTOMRIGHT", -1, 1)
        fr._tuiSolid = t
        fr:HookScript("OnHide", function() t:Hide() end)
    end
    local E = ns.E
    local c = E and E.media and E.media.backdropcolor
    fr._tuiSolid:SetColorTexture(c and c[1] or 0.08, c and c[2] or 0.08, c and c[3] or 0.08, 1)
    fr._tuiSolid:Show()
end

function ns.FontValues()
    local out = {}
    if ns.LSM then for _, n in ipairs(ns.LSM:List("font")) do out[n] = n end end
    return out
end

local _allSpecs, _specByID, _specsByClass
local function BuildSpecCache()
    _allSpecs, _specByID, _specsByClass = {}, {}, {}
    if not (GetNumClasses and GetClassInfo and GetNumSpecializationsForClassID and GetSpecializationInfoForClassID) then return end
    for cid = 1, GetNumClasses() do
        local className, classToken, classID = GetClassInfo(cid)
        if classID then
            local list = {}
            for i = 1, (GetNumSpecializationsForClassID(classID) or 0) do
                local id, name, _, icon = GetSpecializationInfoForClassID(classID, i)
                if id then
                    local rec = { id = id, name = name, icon = icon, classID = classID,
                                  classToken = classToken, className = className, specIndex = i }
                    _allSpecs[#_allSpecs + 1] = rec
                    _specByID[id] = rec
                    list[#list + 1] = rec
                end
            end
            _specsByClass[classID] = list
        end
    end
end
local function EnsureSpecCache() if not _allSpecs then BuildSpecCache() end end

function ns.AllSpecs()             EnsureSpecCache(); return _allSpecs end
function ns.SpecMeta(id)           EnsureSpecCache(); return _specByID[id] end
function ns.SpecsForClass(classID) EnsureSpecCache(); return _specsByClass[classID] or {} end

-- /tui <command>; modules add theirs with ns.SlashCommand
local slashCommands = {}
function ns.SlashCommand(name, fn) slashCommands[name] = fn end

SLASH_THINGSUI1 = "/tui"
SlashCmdList.THINGSUI = function(msg)
    local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.*)$")
    cmd = strlower(cmd)
    if cmd == "" then E:ToggleOptions("thingsUI") return end
    if slashCommands[cmd] then slashCommands[cmd](rest) return end
    print("|cFF8080FFthingsUI|r: /tui opens the options, /tui install the installer, /tui alt the alt profile setup, /tui prof the profiler.")
end

-- work inside hooks on ElvUI/Blizzard frames is billed to their rows, not ours
local PROF_ADDONS = { "ElvUI_thingsUI", "ElvUI", "ElvUI_Libraries" }
-- every loaded addon, worst first: run it, do the laggy thing, run it again
local function ProfAll(P, M)
    local rows = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and C_AddOns.IsAddOnLoaded(i) then
            rows[#rows + 1] = { name = name, over = P.GetAddOnMetric(name, M.CountTimeOver5Ms),
                peak = P.GetAddOnMetric(name, M.PeakTime), now = P.GetAddOnMetric(name, M.RecentAverageTime) }
        end
    end
    table.sort(rows, function(a, b)
        if a.over ~= b.over then return a.over > b.over end
        return a.peak > b.peak
    end)
    print("|cFF8080FFthingsUI|r frames over 5 ms | peak ms | now ms per frame (since login)")
    for i = 1, math.min(12, #rows) do
        local r = rows[i]
        print(("  %-24s %4.0f | %6.1f | %.3f"):format(r.name, r.over, r.peak, r.now))
    end
end

ns.SlashCommand("prof", function(arg)
    if strlower(strtrim(arg or "")) == "all" then
        local P, M = C_AddOnProfiler, Enum.AddOnProfilerMetric
        if P and P.IsEnabled and P.IsEnabled() and M then ProfAll(P, M)
        else print("|cFF8080FFthingsUI|r: the addon profiler is not available.") end
        return
    end
    local marks, parts = ns.loadMarks, {}
    for n = 2, #marks do
        parts[#parts + 1] = ("%s %.1f"):format(marks[n][1], marks[n][2] - marks[n - 1][2])
    end
    print(("|cFF8080FFthingsUI|r load at this login/reload: files %.1f ms (%s), Initialize %.1f ms"):format(
        marks[#marks][2] - marks[1][2], table.concat(parts, ", "), ns.loadInit or 0))

    local P, M = C_AddOnProfiler, Enum.AddOnProfilerMetric
    if not (P and P.IsEnabled and P.IsEnabled() and M) then
        print("|cFF8080FFthingsUI|r: the addon profiler is not available.")
        return
    end
    print("|cFF8080FFthingsUI|r CPU in ms per frame: now | session | boss | peak | frames over 5 ms")
    for _, name in ipairs(PROF_ADDONS) do
        if C_AddOns.IsAddOnLoaded(name) then
            print(("  %-16s %.3f | %.3f | %.3f | %.1f | %.0f"):format(name,
                P.GetAddOnMetric(name, M.RecentAverageTime),
                P.GetAddOnMetric(name, M.SessionAverageTime),
                P.GetAddOnMetric(name, M.EncounterAverageTime),
                P.GetAddOnMetric(name, M.PeakTime),
                P.GetAddOnMetric(name, M.CountTimeOver5Ms)))
        end
    end
    print(("  all addons %.3f of %.3f ms per frame"):format(
        P.GetOverallMetric(M.RecentAverageTime), P.GetApplicationMetric(M.RecentAverageTime)))
end)