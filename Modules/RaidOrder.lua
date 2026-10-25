local _, ns = ...
local TUI = ns.TUI
local E   = ns.E

-- Custom raid frame order on ElvUI's raid headers through the secure header's
-- own nameList sort. ElvUI writes header attributes only when it configures a
-- group, so the order goes on right after that and on roster changes, OOC.

local RO = {}
ns.RaidOrder = RO

RO.GROUPS = { "raid1", "raid2", "raid3" }

local function UF() return E:GetModule("UnitFrames", true) end

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- layouts are account-wide (outside profiles and their exports); on/off is per profile
function RO.Store()
    local g = _G.thingsUIGlobalDB
    if type(g) ~= "table" then g = {}; _G.thingsUIGlobalDB = g end
    local r = g.raidOrder
    if type(r) ~= "table" then r = {}; g.raidOrder = r end
    if type(r.layouts) ~= "table" then r.layouts = {} end
    if type(r.seen) ~= "table" then r.seen = {} end
    if not r.active or type(r.layouts[r.active]) ~= "table" then
        local first
        for k, v in pairs(r.layouts) do
            if type(v) == "table" and (not first or k < first) then first = k end
        end
        if not first then first = "Layout 1"; r.layouts[first] = {} end
        r.active = first
    end
    return r
end

function RO.ActiveList()
    local r = RO.Store()
    return r.layouts[r.active]
end

function RO.Enabled()
    local db = E.db.thingsUI and E.db.thingsUI.raidOrder
    return db and db.enabled == true
end

function RO.StripRealm(n)
    local dash = n:find("-", 1, true)
    return dash and n:sub(1, dash - 1) or n
end
local StripRealm = RO.StripRealm

-- exact full name first, realm-stripped fallback so entries survive transfers
local function BuildRanks(list)
    local full, short = {}, {}
    for i, entry in ipairs(list) do
        local l = entry:lower()
        if full[l] == nil then full[l] = i end
        local s = StripRealm(l)
        if short[s] == nil then short[s] = i end
    end
    return full, short
end
RO.BuildRanks = BuildRanks

function RO.ListAdd(list, entry)
    entry = (entry or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if entry == "" then return false end
    local l = entry:lower()
    for _, e in ipairs(list) do
        if e:lower() == l then return false end
    end
    list[#list + 1] = entry
    return true
end

-- class and role of listed names, so the editor can show them out of a group
function RO.Remember(name, class, role)
    if not (name and class) then return end
    local seen, k = RO.Store().seen, name:lower()
    local s = seen[k]
    if s and s.c == class and s.r == role then return end
    seen[k] = { c = class, r = role }
end

function RO.PruneSeen()
    local r = RO.Store()
    local keep = {}
    for _, list in pairs(r.layouts) do
        for _, n in ipairs(list) do keep[n:lower()] = true end
    end
    for k in pairs(r.seen) do
        if not keep[k] then r.seen[k] = nil end
    end
end

-- the current group: lower name -> { name, class, role, subgroup }; nil while a name is unresolved
function RO.Roster()
    local out = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, subgroup, _, _, classFile, _, _, _, _, _, combatRole = GetRaidRosterInfo(i)
            name, subgroup = Plain(name), Plain(subgroup)
            if not name or name == UNKNOWNOBJECT or not subgroup then return nil end
            out[name:lower()] = { name = name, class = Plain(classFile), role = Plain(combatRole), subgroup = subgroup }
        end
    else
        local units = { "player" }
        for i = 1, 4 do units[#units + 1] = "party" .. i end
        for _, unit in ipairs(units) do
            if UnitExists(unit) then
                local n, realm = UnitName(unit)
                n, realm = Plain(n), Plain(realm)
                if not n or n == "" or n == UNKNOWNOBJECT then return nil end
                if realm and realm ~= "" then n = n .. "-" .. realm end
                local _, classFile = UnitClass(unit)
                out[n:lower()] = { name = n, class = Plain(classFile), role = Plain(UnitGroupRolesAssigned(unit)), subgroup = 1 }
            end
        end
    end
    return out
end

-- the raid in list order: listed names first, everyone else by name; also how many are listed
local function Members()
    local roster = RO.Roster()
    if not roster then return nil, 0 end
    local full, short = BuildRanks(RO.ActiveList())
    local members, listed = {}, 0
    for l, m in pairs(roster) do
        local rank = full[l] or short[StripRealm(l)]
        if rank then
            RO.Remember(m.name, m.class, m.role)
            listed = listed + 1
        end
        members[#members + 1] = { name = m.name, subgroup = m.subgroup, rank = rank or 10000 }
    end
    -- name tiebreak: stable through subgroup moves, unlike raid index
    table.sort(members, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.name < b.name
    end)
    return members, listed
end

local function Names(members, maxGroup, onlyGroup)
    local out = {}
    for _, m in ipairs(members) do
        if (onlyGroup and m.subgroup == onlyGroup) or (not onlyGroup and m.subgroup <= maxGroup) then
            out[#out + 1] = m.name
        end
    end
    -- "" matches nobody: an empty group shows nothing instead of the whole raid
    return table.concat(out, ",")
end

local owned = setmetatable({}, { __mode = "k" })

local function SetOrder(hdr, nl)
    if hdr:GetAttribute("nameList") == nl and hdr:GetAttribute("sortMethod") == "NAMELIST"
        and hdr:GetAttribute("groupFilter") == nil and hdr:GetAttribute("roleFilter") == nil then
        owned[hdr] = true
        return
    end
    local shown = hdr:IsShown()
    -- hidden while the filter swaps: a half-set header shows the whole raid
    if shown then hdr:Hide() end
    hdr:SetAttribute("groupFilter", nil)
    hdr:SetAttribute("roleFilter", nil)
    hdr:SetAttribute("groupBy", nil)
    hdr:SetAttribute("sortMethod", "NAMELIST")
    hdr:SetAttribute("nameList", nl)
    -- the secure header never clears a shown button's old anchor
    if hdr.ClearChildPoints then hdr:ClearChildPoints() end
    if shown then hdr:Show() end
    owned[hdr] = true
end

-- back to what ElvUI's Configure_Groups writes
local function Release(Header, i)
    local hdr = Header.groups and Header.groups[i]
    if not (hdr and owned[hdr]) then return end
    owned[hdr] = nil
    local db = Header.db
    local n = Header.numGroups or 1
    local shown = hdr:IsShown()
    if shown then hdr:Hide() end
    hdr:SetAttribute("nameList", nil)
    UF():SetHeaderSortGroup(hdr, db.groupBy)
    hdr:SetAttribute("groupFilter", (i == 1 and db.raidWideSorting) and strsub("1,2,3,4,5,6,7,8", 1, n * 2 - 1) or tostring(i))
    if hdr.ClearChildPoints then hdr:ClearChildPoints() end
    if shown then hdr:Show() end
end

local function ReleaseAll()
    local uf = UF()
    for _, group in ipairs(RO.GROUPS) do
        local Header = uf and uf[group]
        for i = 1, #((Header and Header.groups) or {}) do Release(Header, i) end
    end
end

local function Owns()
    if not (RO.Enabled() and IsInRaid()) then return false end
    local list = RO.ActiveList()
    return list and #list > 0
end

local pendingRegen, retries, unresolved = false, 0, false
local Queue

-- ElvUI configures a shown header one attribute at a time and the secure layout never
-- clears a shown button's old anchor: passes before unitsPerColumn lands stack everyone
-- in one column, so frame 6 keeps "under frame 5" next to its column anchor.
-- One clean layout after ElvUI is done fixes it (with or without a custom order).
local reanchor = {}
local function Reanchor()
    local uf = UF()
    for group in pairs(reanchor) do
        reanchor[group] = nil
        local Header = uf and uf[group]
        if Header and Header.groups and not Header.isForced then
            for _, hdr in ipairs(Header.groups) do
                if hdr:IsShown() and hdr.ClearChildPoints then
                    hdr:Hide()
                    hdr:ClearChildPoints()
                    hdr:Show()
                end
            end
        end
    end
end

local function Apply()
    if InCombatLockdown() then pendingRegen = true return end
    Reanchor()
    if not Owns() then ReleaseAll() return end
    local members, listed = Members()
    -- a name list hides everyone it leaves out: while names still load, or nobody from
    -- the list is here, ElvUI's own group order shows the whole raid
    if not members or listed == 0 then
        ReleaseAll()
        unresolved = not members
        if unresolved and retries < 10 then
            retries = retries + 1
            C_Timer.After(1, Queue)
        end
        return
    end
    retries, unresolved = 0, false
    local uf = UF()
    for _, group in ipairs(RO.GROUPS) do
        local Header = uf and uf[group]
        local db = Header and Header.db
        if Header and Header.groups and db and db.enable and not Header.isForced then
            local n = Header.numGroups or 8
            if db.raidWideSorting then
                local hdr = Header.groups[1]
                if hdr then SetOrder(hdr, Names(members, n)) end
            else
                for i = 1, n do
                    local hdr = Header.groups[i]
                    if hdr then SetOrder(hdr, Names(members, n, i)) end
                end
            end
        end
    end
end

local queued = false
Queue = function()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        Apply()
    end)
end
RO.Queue = Queue

-- roster bursts: one leading and one trailing apply
local lastApply, trailing = 0, nil
local function Throttled()
    if GetTime() - lastApply >= 0.25 then
        lastApply = GetTime()
        Queue()
    elseif not trailing then
        trailing = C_Timer.NewTimer(0.3, function()
            trailing = nil
            lastApply = GetTime()
            Queue()
        end)
    end
end

-- after a layout, list or on/off change
function RO.Changed()
    RO.PruneSeen()
    Queue()
end

local hooked = false
local function Hook()
    local uf = UF()
    if hooked or not (uf and uf.CreateAndUpdateHeaderGroup) then return end
    hooked = true
    -- ElvUI rewrites the header's filter and sort every time it configures a group
    hooksecurefunc(uf, "CreateAndUpdateHeaderGroup", function(_, group)
        if group == "raid1" or group == "raid2" or group == "raid3" then
            reanchor[group] = true
            Queue()
        end
    end)
    if uf.HeaderConfig then
        hooksecurefunc(uf, "HeaderConfig", function(_, header, configMode)
            local group = header and header.groupName
            if not configMode and (group == "raid1" or group == "raid2" or group == "raid3") then
                reanchor[group] = true
                Queue()
            end
        end)
    end
end

function TUI:UpdateRaidOrder()
    Hook()
    for _, group in ipairs(RO.GROUPS) do reanchor[group] = true end
    Queue()
end

-- /tui rf dump: what each raid group header filters on right now
function RO.Dump()
    local p = "|cFF8080FFthingsUI|r rf"
    local members, listed = Members()
    print(("%s on %s, raid %s, owns %s | roster %s (%d listed) | waiting: combat %s, names %s"):format(p,
        tostring(RO.Enabled()), tostring(IsInRaid()), tostring(Owns()),
        members and #members or "unresolved", listed or 0, tostring(pendingRegen), tostring(unresolved)))
    local uf = UF()
    for _, group in ipairs(RO.GROUPS) do
        local Header = uf and uf[group]
        if Header then
            local db = Header.db or {}
            print(("  %s: shown %s, groups %s, raid-wide %s, forced %s"):format(group, tostring(Header:IsShown()),
                tostring(Header.numGroups), tostring(db.raidWideSorting), tostring(Header.isForced)))
            for i, hdr in ipairs(Header.groups or {}) do
                local kids = 0
                for c = 1, 40 do
                    local b = hdr:GetAttribute("child" .. c)
                    if b and b:IsShown() then kids = kids + 1 end
                end
                local nl = hdr:GetAttribute("nameList")
                local n = nl and select(2, nl:gsub("[^,]+", "")) or 0
                print(("    %d: shown %s, frames %d, ours %s, filter %s, sort %s, names %s%s"):format(i, tostring(hdr:IsShown()),
                    kids, tostring(owned[hdr] == true), tostring(hdr:GetAttribute("groupFilter")),
                    tostring(hdr:GetAttribute("sortMethod")), nl and n or "-", (nl and n > 0) and (" (" .. nl:sub(1, 60) .. ")") or ""))
            end
        end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("UNIT_NAME_UPDATE")
ev:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingRegen then
            pendingRegen = false
            Queue()
        end
    elseif event == "UNIT_NAME_UPDATE" then
        -- a raid member's name came in: the order can go on now
        if unresolved and unit and unit:find("^raid") and not InCombatLockdown() then Throttled() end
    elseif RO.Enabled() and IsInRaid() then
        if InCombatLockdown() then pendingRegen = true else Throttled() end
    end
end)

-- ------------------------------------------------------------ share strings

-- "!TRO1!Layout=Name1,Name2-Realm;Other=..." - the same format things for EUI reads
local PREFIX = "!TRO1!"

local function CleanName(s)
    return ((s or ""):gsub("[;=!,|]", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function RO.Export(name)
    local r = RO.Store()
    name = name or r.active
    local list = r.layouts[name]
    if not list then return "" end
    return PREFIX .. CleanName(name) .. "=" .. table.concat(list, ",")
end

local function SameList(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i]:lower() ~= b[i]:lower() then return false end
    end
    return true
end

-- returns the first imported layout's name, or nil and a reason
function RO.Import(str)
    str = (str or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if str:sub(1, #PREFIX) ~= PREFIX then return nil, "not a raid order string" end
    local r = RO.Store()
    local first
    for chunk in str:sub(#PREFIX + 1):gmatch("[^;]+") do
        local lname, names = chunk:match("^([^=]*)=(.*)$")
        if lname then
            lname = CleanName(lname)
            if lname == "" then lname = "Imported" end
            local list = {}
            for n in names:gmatch("[^,]+") do RO.ListAdd(list, n) end
            local cur = r.layouts[lname]
            if cur and not SameList(cur, list) then
                local i = 2
                while r.layouts[lname .. " (" .. i .. ")"] do i = i + 1 end
                lname = lname .. " (" .. i .. ")"
                cur = nil
            end
            if not cur then r.layouts[lname] = list end
            first = first or lname
        end
    end
    if not first then return nil, "nothing to import" end
    r.active = first
    RO.Changed()
    return first
end
