local _, ns = ...
local TUI = ns.TUI
local E = ns.E

local MAX_ROWS = 60
local CG_X = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:13|t"
local UP = "|TInterface\\Buttons\\Arrow-Up-Up:13:13|t"
local DOWN = "|TInterface\\Buttons\\Arrow-Down-Up:13:13|t"

local function RO() return ns.RaidOrder end
local function List() return RO().ActiveList() end

local function Changed()
    RO().Changed()
    ns.NotifyChange()
end

local function CleanLayoutName(v)
    return ((v or ""):gsub("[;=!,|]", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- class colors from the group, else from when we last saw them; one build per frame
local colorStamp, colorMap, rosterMap
local function Colors()
    local now = GetTime()
    if colorStamp ~= now then
        colorStamp = now
        colorMap, rosterMap = {}, RO().Roster() or {}
        for l, m in pairs(rosterMap) do colorMap[l] = m.class end
        for l, s in pairs(RO().Store().seen) do colorMap[l] = colorMap[l] or s.c end
    end
    return colorMap, rosterMap
end

local function RowLabel(i, name)
    local colors, roster = Colors()
    local l = name:lower()
    local class = colors[l]
    local col = class and (E:ClassColor(class) or RAID_CLASS_COLORS[class])
    local hex = col and ("ff%02x%02x%02x"):format(col.r * 255, col.g * 255, col.b * 255) or "ff9d9d9d"
    local away = IsInGroup() and not roster[l] and " |cFF666666(not in group)|r" or ""
    return ("|cFF888888%d.|r |c%s%s|r%s"):format(i, hex, name, away)
end

local function Move(from, to)
    local list = List()
    if not list[from] or to < 1 or to > #list then return end
    table.insert(list, to, table.remove(list, from))
    Changed()
end

local function AddFromGroup()
    local list, added = List(), false
    for _, m in pairs(RO().Roster() or {}) do
        if RO().ListAdd(list, m.name) then
            RO().Remember(m.name, m.class, m.role)
            added = true
        end
    end
    if added then Changed() end
end

local function AddTarget()
    if not (UnitExists("target") and UnitIsPlayer("target")) then return end
    local n, realm = UnitName("target")
    if not n or (issecretvalue and (issecretvalue(n) or issecretvalue(realm))) then return end
    if realm and realm ~= "" then n = n .. "-" .. realm end
    local _, class = UnitClass("target")
    if RO().ListAdd(List(), n) then
        RO().Remember(n, class, UnitGroupRolesAssigned("target"))
        Changed()
    end
end

-- enabled raid headers that show each group on its own
local function SeparatedNote()
    local out = {}
    local units = E.db.unitframe and E.db.unitframe.units or {}
    for i, g in ipairs({ "raid1", "raid2", "raid3" }) do
        local u = units[g]
        if u and u.enable and not u.raidWideSorting then out[#out + 1] = "Raid " .. i end
    end
    if #out == 0 then return nil end
    return "|cFFFFD24D" .. table.concat(out, ", ") .. " without Raid-Wide Sorting: the order applies inside each group.|r\n"
end

local function LayoutValues()
    local out = {}
    for k, list in pairs(RO().Store().layouts) do out[k] = ("%s |cFF888888(%d)|r"):format(k, #list) end
    return out
end

local function LayoutSorting()
    local out = {}
    for k in pairs(RO().Store().layouts) do out[#out + 1] = k end
    table.sort(out)
    return out
end

function TUI:RaidOrderOptions()
    local rows = {
        add = {
            order = 1, type = "input", name = "Add Names", width = 1.5,
            desc = "Name or Name-Realm, or a comma-separated list.",
            get = function() return "" end,
            set = function(_, v)
                local added = false
                for entry in (v or ""):gmatch("[^,]+") do
                    if RO().ListAdd(List(), entry) then added = true end
                end
                if added then Changed() end
            end,
        },
        group = { order = 2, type = "execute", name = "Add Group", width = 0.7, func = AddFromGroup },
        target = { order = 3, type = "execute", name = "Add Target", width = 0.7, func = AddTarget },
        clear = {
            order = 4, type = "execute", name = "Clear", width = 0.5,
            confirm = true, confirmText = "Remove every name from this layout?",
            disabled = function() return #List() == 0 end,
            func = function()
                wipe(List())
                Changed()
            end,
        },
        empty = {
            order = 5, type = "description", name = "|cFF888888No names yet.|r",
            hidden = function() return #List() > 0 end,
        },
        -- the list starts on its own line, whatever the window width
        listBrk = { order = 6, type = "description", name = "", width = "full" },
    }
    for ri = 1, MAX_ROWS do
        local hidden = function() return List()[ri] == nil end
        local base = 10 + ri
        rows["r" .. ri] = {
            order = base, type = "description", width = 1.6, fontSize = "medium", hidden = hidden,
            name = function() local n = List()[ri] return n and RowLabel(ri, n) or "" end,
        }
        rows["u" .. ri] = {
            order = base + 0.1, type = "execute", width = 0.3, name = UP, hidden = hidden,
            disabled = function() return ri == 1 end,
            func = function() Move(ri, ri - 1) end,
        }
        rows["d" .. ri] = {
            order = base + 0.2, type = "execute", width = 0.3, name = DOWN, hidden = hidden,
            disabled = function() return ri == #List() end,
            func = function() Move(ri, ri + 1) end,
        }
        rows["x" .. ri] = {
            order = base + 0.3, type = "execute", width = 0.3, name = CG_X, hidden = hidden,
            func = function()
                table.remove(List(), ri)
                Changed()
            end,
        }
        rows["b" .. ri] = { order = base + 0.4, type = "description", name = "", width = "full", hidden = hidden }
    end

    return {
        type = "group",
        name = "Raid Frame Builder",
        args = {
            intro = {
                order = 1, type = "description", fontSize = "medium",
                name = "Sorts ElvUI's raid frames by your list: listed names first, everyone else by name. Layouts are shared by all characters; Enable is per profile.\n",
            },
            enabled = {
                order = 2, type = "toggle", name = "Enable", width = "full",
                get = function() return E.db.thingsUI.raidOrder.enabled end,
                set = function(_, v)
                    E.db.thingsUI.raidOrder.enabled = v
                    Changed()
                end,
            },
            open = {
                order = 3, type = "execute", name = "|cFF4DD2A6Open Builder|r", width = "double",
                func = function() RO().Editor.Open() end,
            },
            openBrk = { order = 3.5, type = "description", name = " ", width = "full" },
            note = {
                order = 4, type = "description",
                name = function() return SeparatedNote() or "" end,
                hidden = function() return SeparatedNote() == nil end,
            },
            layoutGroup = {
                order = 10, type = "group", inline = true, name = "Layout",
                args = {
                    active = {
                        order = 1, type = "select", name = "Active Layout",
                        values = LayoutValues, sorting = LayoutSorting,
                        get = function() return RO().Store().active end,
                        set = function(_, v)
                            RO().Store().active = v
                            Changed()
                        end,
                    },
                    rename = {
                        order = 2, type = "input", name = "Rename",
                        get = function() return RO().Store().active end,
                        set = function(_, v)
                            local r = RO().Store()
                            v = CleanLayoutName(v)
                            if v == "" or r.layouts[v] then return end
                            r.layouts[v], r.layouts[r.active] = r.layouts[r.active], nil
                            r.active = v
                            Changed()
                        end,
                    },
                    new = {
                        order = 3, type = "input", name = "New Layout",
                        get = function() return "" end,
                        set = function(_, v)
                            local r = RO().Store()
                            v = CleanLayoutName(v)
                            if v == "" or r.layouts[v] then return end
                            r.layouts[v] = {}
                            r.active = v
                            Changed()
                        end,
                    },
                    copy = {
                        order = 4, type = "execute", name = "Copy Layout",
                        func = function()
                            local r = RO().Store()
                            local name, i = r.active .. " Copy", 2
                            while r.layouts[name] do
                                name = r.active .. " Copy " .. i
                                i = i + 1
                            end
                            local t = {}
                            for k, n in ipairs(r.layouts[r.active]) do t[k] = n end
                            r.layouts[name] = t
                            r.active = name
                            Changed()
                        end,
                    },
                    delete = {
                        order = 5, type = "execute", name = "Delete Layout",
                        confirm = true, confirmText = "Delete this layout?",
                        func = function()
                            local r = RO().Store()
                            r.layouts[r.active] = nil
                            r.active = nil
                            Changed()
                        end,
                    },
                },
            },
            namesGroup = {
                order = 20, type = "group", inline = true, name = "Names",
                args = rows,
            },
            shareGroup = {
                order = 30, type = "group", inline = true, name = "Share",
                args = {
                    export = {
                        order = 1, type = "input", name = "Export Active Layout", width = "full", multiline = 3,
                        desc = "Works in things for EUI too.",
                        get = function() return RO().Export() end,
                        set = function() end,
                    },
                    import = {
                        order = 2, type = "input", name = "Import", width = "full", multiline = 3,
                        get = function() return "" end,
                        set = function(_, v)
                            local name, err = RO().Import(v)
                            if name then
                                print(("|cFF8080FFthingsUI|r: imported raid layout %s."):format(name))
                            else
                                print(("|cFF8080FFthingsUI|r: couldn't import that (%s)."):format(err))
                            end
                            ns.NotifyChange()
                        end,
                    },
                },
            },
        },
    }
end
