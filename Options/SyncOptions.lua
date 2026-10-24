local _, ns = ...
local TUI = ns.TUI
local E = ns.E

local NotifyChange = ns.NotifyChange

-- Sync: the profiles that keep modules the same on top, every module in the tree below
function TUI:SyncOptions()
    local PS = ns.ProfileSync
    local function Cur() return PS.Current() end
    local function Member() return PS.InSet(Cur()) end
    local function Others()
        local out = {}
        for _, n in ipairs(PS.SetProfiles()) do if n ~= Cur() then out[#out + 1] = n end end
        return out
    end
    local function Blue(s) return "|cFF8AC8FF" .. s .. "|r" end
    -- "FHT -> NHT, Alt": who hands what to whom right now
    local function Flow()
        return Blue(Cur() or "?") .. " -> " .. Blue(table.concat(Others(), ", "))
    end

    -- a mode only sticks once its warning or questions are answered
    local function SetMode(id, m)
        local prev = PS.Mode(id)
        if m == prev then return end
        PS.SetMode(id, m)
        if m and #Others() > 0 then
            PS.SeedModule(id, PS.SetProfiles(), function()
                NotifyChange()
                print(("|cFF8080FFthingsUI|r - %s synced to %s."):format(PS.ModuleName(id), table.concat(Others(), ", ")))
            end, false, function()
                PS.SetMode(id, prev)
                NotifyChange()
            end)
        end
        NotifyChange()
    end

    local INVIS = E.Media and E.Media.Textures and E.Media.Textures.Invisible
    local probe
    local function Width(text)
        if not probe then
            probe = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            probe:Hide()
        end
        probe:SetText(text)
        return probe:GetStringWidth() or 0
    end
    local function Gap(px)
        px = math.floor(px)
        if not INVIS or px < 2 then return "  " end
        return ("|T%s:1:%d|t"):format(INVIS, px)
    end
    -- wider than Ace's 175 the first time; a drag on its edge sticks
    local function TreeWidth()
        local ACD = E.Libs and E.Libs.AceConfigDialog
        local st = ACD and ACD:GetStatusTable("ElvUI", { "thingsUI", "syncTab" })
        if not st then return 175 end
        st.groups = st.groups or {}
        if not st.groups._tuiWide then
            st.groups._tuiWide = true
            st.groups.treewidth = 390
        end
        return st.groups.treewidth or 175
    end
    local COLS = { "All", "Some", "X/Y", "W/H" }
    local SEP = "|cFF3A3A3A  ||  |r"
    local blockW
    local function Columns(id)
        local c = PS.Module(id) or {}
        local m = c.mode
        local on = { m == "all", m == "some", c.pos and true, c.size and true }
        local rel = { true, true, PS.HasPositions(id), PS.HasSizes(id) }
        local out = {}
        for i, t in ipairs(COLS) do
            local col = (not rel[i]) and "|cFF262626" or (on[i] and "|cFF40FF40" or "|cFF5A5A5A")
            out[i] = col .. t .. "|r"
        end
        return table.concat(out, SEP)
    end
    local function Label(sec, id)
        blockW = blockW or Width(table.concat(COLS, "  ||  "))
        local name = "|cFF" .. (sec.color or "FFFFFF") .. sec.name .. "|r"
        local room = TreeWidth() - 40 - Width(sec.name) - blockW
        return name .. Gap(room) .. Columns(id)
    end

    local function Said(id, what)
        if PS.Active() then
            print(("|cFF8080FFthingsUI|r - %s: %s %s."):format(PS.ModuleName(id), what, table.concat(Others(), ", ")))
        end
    end

    local function ModuleGroup(order, sec)
        local id = PS.SectionID(sec)
        local function mode() return PS.Mode(id) end
        local function cfg() return PS.Module(id) or {} end
        local function locked() return not Member() end
        return {
            -- synced modules on top, the line, then the rest
            order = function() return (mode() and 10 or 100) + order end,
            type = "group",
            name = function() return Label(sec, id) end,
            args = {
                status = {
                    order = 1, type = "description", fontSize = "medium", width = "full",
                    name = function()
                        if not mode() then return "|cFF888888Not synced.|r\n" end
                        if #Others() == 0 or not Member() then return "|cFFFFD200Synced once this profile and another one are ticked above.|r\n" end
                        -- a dry run says whether the others already match
                        local differ = {}
                        for _, n in ipairs(Others()) do
                            if PS.Differs(id, Cur(), n) then differ[#differ + 1] = n end
                        end
                        local line = "Synced: " .. Flow() .. ". "
                        if #differ == 0 then
                            return line .. "|cFF40FF40In sync - " .. table.concat(Others(), ", ") .. " match" .. ((#Others() == 1) and "es" or "") .. " this profile.|r\n"
                        end
                        return line .. "|cFFFFD200" .. table.concat(differ, ", ") .. " still differ" .. ((#differ == 1) and "s" or "")
                            .. " - they get this profile's when you switch profile, log out or click Sync Now.|r\n"
                    end,
                },
                all = {
                    order = 2, type = "toggle", name = "All", width = 0.6, disabled = locked,
                    get = function() return mode() == "all" end,
                    set = function(_, v) SetMode(id, v and "all" or nil) end,
                },
                some = {
                    order = 3, type = "toggle", name = "Some", width = 0.6, disabled = locked,
                    get = function() return mode() == "some" end,
                    set = function(_, v) SetMode(id, v and "some" or nil) end,
                },
                pos = {
                    order = 4, type = "toggle", name = "Sync Position (X/Y)", width = 1.1,
                    hidden = function() return not PS.HasPositions(id) end,
                    disabled = function() return locked() or not mode() end,
                    get = function() return cfg().pos end,
                    set = function(_, v)
                        PS.SetFlag(id, "pos", v)
                        if v then PS.Push(id); Said(id, "positions synced to") end
                        NotifyChange()
                    end,
                },
                size = {
                    order = 5, type = "toggle", name = "Sync Size (W/H)", width = 1.1,
                    hidden = function() return not PS.HasSizes(id) end,
                    disabled = function() return locked() or not mode() end,
                    get = function() return cfg().size end,
                    set = function(_, v)
                        PS.SetFlag(id, "size", v)
                        if v then PS.Push(id); Said(id, "sizes synced to") end
                        NotifyChange()
                    end,
                },
                take = {
                    order = 6, type = "select", name = "Take It From...", width = 1.1,
                    desc = "Copies this module from that profile into this one first (overwrite, add or pick), then this profile hands the result back.",
                    hidden = function() return #Others() == 0 or not Member() end,
                    values = function()
                        local out = {}
                        for _, n in ipairs(Others()) do out[n] = n end
                        return out
                    end,
                    get = function() return nil end,
                    set = function(_, n) ns.Share.OpenCopy("from", n, order) end,
                },
                note = {
                    order = 7, type = "description", width = "full",
                    name = function()
                        local lines = {}
                        local dock = PS.DockedNote(id)
                        if dock then
                            lines[#lines + 1] = dock
                        else
                            if not PS.HasPositions(id) then lines[#lines + 1] = "Its spot is set by an ElvUI mover, which stays with each profile." end
                            if not PS.HasSizes(id) then lines[#lines + 1] = "No size of its own to sync." end
                        end
                        if id == "essentialMover" then
                            lines[#lines + 1] = "Raid Frame Builder layouts are shared by every profile already - only its Enable is per profile."
                        end
                        if #lines == 0 then return "" end
                        return "\n|cFF888888" .. table.concat(lines, "\n") .. "|r"
                    end,
                },
                partsHead = {
                    order = 10, type = "header", name = "What Syncs",
                    hidden = function() return mode() ~= "some" end,
                },
                parts = {
                    order = 11, type = "multiselect", name = "", width = "full", disabled = locked,
                    hidden = function() return mode() ~= "some" or #PS.Parts(id) == 0 end,
                    values = function()
                        local out = {}
                        for _, p in ipairs(PS.Parts(id)) do out[p.key] = p.label end
                        return out
                    end,
                    get = function(_, k) local p = cfg().parts return p and p[k] end,
                    set = function(_, k, v)
                        PS.SetPart(id, k, v)
                        if v then PS.Push(id); Said(id, "synced to") end
                        NotifyChange()
                    end,
                },
                partsEmpty = {
                    order = 12, type = "description", width = "full",
                    hidden = function() return mode() ~= "some" or #PS.Parts(id) > 0 end,
                    name = "|cFF888888Nothing in this module to pick yet.|r",
                },
            },
        }
    end

    local args = {
        intro = {
            order = 1, type = "description", fontSize = "medium", width = "full",
            name = function() TreeWidth() return "Keep modules the same in the profiles you tick. The profile you're on hands its settings to the others when you switch profile (spec swaps too), log out or click Sync Now. Positions (X/Y) and sizes (W/H) stay with each profile unless you sync them.\n" end,
        },
        profiles = {
            order = 2, type = "multiselect", name = "Profiles", width = "full",
            values = function()
                local out, cur = {}, Cur()
                for name in pairs((E.data and E.data.profiles) or {}) do
                    out[name] = (name == cur) and (name .. " |cFF888888(this one)|r") or name
                end
                return out
            end,
            get = function(_, name) return PS.InSet(name) end,
            set = function(_, name, on)
                if not on then
                    PS.SetInSet(name, false)
                    NotifyChange()
                elseif name == Cur() then
                    PS.JoinSelf(NotifyChange)
                else
                    PS.Join(name, NotifyChange)
                end
            end,
        },
        -- where things stand, in one line
        flow = {
            order = 3, type = "description", width = "full", fontSize = "medium",
            name = function()
                if not Member() then
                    return "|cFFFFD200Tick this profile (" .. (Cur() or "?") .. ") to set up sync from here - the profile you're on is the one that hands its settings on.|r\n"
                end
                if #Others() == 0 then return "|cFFFFD200Tick a second profile to sync with.|r\n" end
                local n = #PS.SyncedIDs()
                if n == 0 then return "|cFFFFD200Nothing syncs yet - pick modules below (All or Some).|r\n" end
                return ("You're on %s, so it hands %d module%s to %s. When you switch to one of them, that one hands its changes back.\n"):format(
                    Blue(Cur()), n, (n == 1) and "" or "s", Blue(table.concat(Others(), ", ")))
            end,
        },
        now = {
            order = 4, type = "execute", width = 1.6,
            name = function()
                if PS.Active() and #PS.SyncedIDs() > 0 then return "Sync Now: " .. Cur() .. " -> " .. table.concat(Others(), ", ") end
                return "Sync Now"
            end,
            disabled = function() return not (PS.Active() and #PS.SyncedIDs() > 0) end,
            func = function()
                PS.Push()
                print("|cFF8080FFthingsUI|r - synced.")
            end,
        },
        pack = {
            order = 5, type = "execute", name = "Sync Like the Pack", width = 1.2,
            hidden = function() return not (ns.PackSyncConfig and next(ns.PackSyncConfig()) ~= nil) end,
            func = function()
                local ok, err = ns.ApplyPackSync(ns.PackSyncConfig(), nil, true, function()
                    NotifyChange()
                    print("|cFF8080FFthingsUI|r - synced like the pack.")
                end)
                if not ok then print("|cFF8080FFthingsUI|r - " .. err) end
            end,
        },
    }
    for i, sec in ipairs(ns.Share.SECTIONS) do
        args["m_" .. PS.SectionID(sec)] = ModuleGroup(i, sec)
    end
    -- between what syncs and what doesn't
    args.line = {
        order = 50, type = "group", disabled = true, args = {},
        name = function()
            local w = math.max(40, TreeWidth() - 40)
            return ("|TInterface\\Buttons\\WHITE8x8:1:%d:0:0:8:8:0:8:0:8:70:70:70|t"):format(w)
        end,
        hidden = function()
            local any, all = false, true
            for _, sec in ipairs(ns.Share.SECTIONS) do
                if PS.Mode(PS.SectionID(sec)) then any = true else all = false end
            end
            return not any or all
        end,
    }
    return { order = 41, type = "group", name = "Sync", childGroups = "tree", args = args }
end
