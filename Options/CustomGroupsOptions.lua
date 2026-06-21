local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local NotifyChange = ns.NotifyChange

local SCOPE_LABEL = { global = "|cFFFFCF40Global|r", class = "|cFF80C0FFClass|r", spec = "|cFFFFD200Spec|r" }
local CG_UP, CG_DOWN = "^", "v"
local CURATED_ITEMS = {
    5512, 241304, 241308, 241300, 241294, 241288, 241292,
}
local editSpec, editClass

local function GroupSpecialCount(group, specID)
    local sb = E.db.thingsUI and E.db.thingsUI.specialBars
    local s = sb and sb.specs and sb.specs[tostring(specID)]
    if not (s and s.icons) then return 0 end
    local n = 0
    for _, idb in pairs(s.icons) do
        if idb and idb.enabled and idb.spellID and idb.customGroup == group.id then n = n + 1 end
    end
    return n
end

-- How many entries (spells/items + class-scoped timers) this group has for a given class.
local function GroupClassCount(group, classFile)
    local n = 0
    local CG = ns.CustomGroups
    local root = CG and CG.GetScopeRoot and CG.GetScopeRoot(group, "class", classFile, false)
    if root then
        for _ in pairs(root.spells or {}) do n = n + 1 end
        for _ in pairs(root.items  or {}) do n = n + 1 end
    end
    if ns.Timers then
        for _, t in ipairs(ns.Timers.GetTimers()) do
            if t.destination == group.id and t.kind ~= "lust" and t.groupScope == classFile then n = n + 1 end
        end
    end
    return n
end

local function LiveSpecialKeyForSpell(spellID)
    local SB = ns.SpecialBars
    if not (SB and SB.GetIconCount and SB.GetIconDB and spellID) then return nil end
    for i = 1, SB.GetIconCount() do
        local k = "icon" .. i
        local idb = SB.GetIconDB(k)
        if idb and idb.spellID == spellID then return k end
    end
end

-- Copy another spec's Special Icon (full style + group) into a new slot on the live spec.
local function CopySpecialToLive(srcSpec, srcIconKey, groupID)
    local SB = ns.SpecialBars
    local sb = E.db.thingsUI and E.db.thingsUI.specialBars
    local src = sb and sb.specs and sb.specs[srcSpec] and sb.specs[srcSpec].icons and sb.specs[srcSpec].icons[srcIconKey]
    if not (SB and SB.GetSpecRoot and src) then return end
    local s = SB.GetSpecRoot()
    if not s then return end
    local c = s.iconCount or 3
    if c >= 12 then E:Print("All 12 Special Icon slots are in use on this spec.") return end
    local copy = ns.DeepCopy(src)
    copy.customGroup = groupID
    s.icons = s.icons or {}
    s.icons["icon" .. (c + 1)] = copy
    s.iconCount = c + 1
    TUI:UpdateSpecialBars(); TUI:UpdateCustomGroups(); NotifyChange()
end

function TUI:CustomGroupsOptions()
    local CG = ns.CustomGroups

    -- current live keys
    local function curSpecID()
        local idx = GetSpecialization()
        return tostring((idx and GetSpecializationInfo(idx)) or 1)
    end
    local function curClassFile() local _, cf = UnitClass("player"); return cf end
    local function getEditSpec()  return editSpec  or curSpecID()  end
    local function getEditClass() return editClass or curClassFile() end
    local function ReFeedScope(group, scope)
        C_Timer.After(0, function()
            local ACD = E.Libs and E.Libs.AceConfigDialog
            local groups = CG and CG.GetGroups and CG.GetGroups()
            if not (ACD and groups) then return end
            for i = 1, #groups do
                if groups[i] == group then
                    ACD:SelectGroup("ElvUI", "thingsUI", "modulesTab", "customGroups", "group" .. i, scope .. "Tab")
                    return
                end
            end
        end)
    end

    local function racialValues()
        local out = {}
        for _, id in ipairs(ns.Racials or {}) do
            local nm = C_Spell.GetSpellName and C_Spell.GetSpellName(id)
            if not nm and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(id) end
            local tex = (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or 0
            out[tostring(id)] = ("|T%d:14:14|t %s"):format(tex, nm or ("Spell " .. id))
        end
        return out
    end
    local function racialSorting()
        local list = {}
        for _, id in ipairs(ns.Racials or {}) do
            list[#list + 1] = { id = id, nm = (C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("Spell " .. id) }
        end
        table.sort(list, function(a, b) return a.nm < b.nm end)
        local out = {}
        for _, e in ipairs(list) do out[#out + 1] = tostring(e.id) end
        return out
    end
    local function allClassValues()
        local out = {}
        for cid = 1, GetNumClasses() do
            local className, classFile = GetClassInfo(cid)
            if classFile then out[classFile] = ns.ClassColor(classFile) .. (className or classFile) .. "|r" end
        end
        return out
    end
    local function allClassSorting()
        local list = {}
        for cid = 1, GetNumClasses() do
            local className, classFile = GetClassInfo(cid)
            if classFile then list[#list + 1] = { cf = classFile, cls = className or classFile } end
        end
        table.sort(list, function(a, b) return a.cls < b.cls end)
        local out = {}
        for _, e in ipairs(list) do out[#out + 1] = e.cf end
        return out
    end
    local function commonItemValues()
        local out = {}
        for _, id in ipairs(CURATED_ITEMS) do
            local nm = C_Item.GetItemInfo(id)
            if not nm and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
            local tex = (C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or 134400
            local suffix = (CG and CG.POTION_OF and CG.POTION_OF[id]) and "  |cFF888888(all ranks)|r" or ""
            out[tostring(id)] = ("|T%d:16:16|t %s%s"):format(tex, nm or ("Item " .. id), suffix)
        end
        return out
    end
    local function commonItemSorting()
        local out = {}
        for _, id in ipairs(CURATED_ITEMS) do out[#out + 1] = tostring(id) end
        return out
    end
    local function entriesFor(group, scope, key)
        local out, itemSeen = {}, {}
        local root = CG and CG.GetScopeRoot(group, scope, key, false)
        if root then
            for id, d in pairs(root.spells or {}) do
                out[#out + 1] = { kind = "spell", id = id, li = d.layoutIndex or 999, uid = "spell:" .. id,
                    name = (C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("Spell " .. id),
                    tex  = (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or 134400 }
            end
            for id, d in pairs(root.items or {}) do
                itemSeen[id] = true
                out[#out + 1] = { kind = "item", id = id, li = d.layoutIndex or 999, uid = "item:" .. id,
                    name = (C_Item.GetItemInfo(id)) or ("Item " .. id),
                    tex  = (C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or select(10, C_Item.GetItemInfo(id)) or 134400 }
            end
        end
        -- Timers pointed at this group + scope (groupScope: "global" | classToken | specID).
        if ns.Timers then
            for _, t in ipairs(ns.Timers.GetTimers()) do
                if t.destination == group.id and t.kind ~= "lust" then
                    local gs = t.groupScope or "global"
                    local match = (scope == "global" and gs == "global")
                        or (scope == "spec" and tostring(gs) == tostring(key))
                        or (scope == "class" and gs == key)
                    -- Skip if a legacy plain item already represents this item-timer.
                    if match and not (t.kind == "item" and t.itemID and itemSeen[t.itemID]) then
                        local nm = (t.kind == "item")
                            and ((C_Item.GetItemInfo(t.itemID)) or ("Item " .. tostring(t.itemID)))
                            or  ((C_Spell.GetSpellName and C_Spell.GetSpellName(t.spellID)) or ("Spell " .. tostring(t.spellID)))
                        out[#out + 1] = { kind = "timer", id = t.id, li = t.groupOrder or 10000, uid = "timer:" .. t.id,
                            realID = t.itemID or t.spellID,
                            name = nm, tex = (ns.Timers.GetTexture and ns.Timers.GetTexture(t)) or 134400 }
                    end
                end
            end
        end

        if scope == "spec" and ns.SpecialBars then
            local isLive = (tostring(key) == curSpecID())
            local sb = E.db.thingsUI and E.db.thingsUI.specialBars
            local icons = sb and sb.specs and sb.specs[tostring(key)] and sb.specs[tostring(key)].icons
            if icons then
                for ikey, idb in pairs(icons) do
                    if idb and idb.enabled and idb.spellID and idb.customGroup == group.id then
                        out[#out + 1] = { kind = "specialicon", id = idb.spellID, iconKey = ikey,
                            srcSpec = tostring(key), live = isLive,
                            existsKey = (not isLive) and LiveSpecialKeyForSpell(idb.spellID) or nil,
                            li = idb.customGroupOrder or 20000, uid = "si:" .. ikey,
                            name = (C_Spell.GetSpellName and C_Spell.GetSpellName(idb.spellID)) or ("Spell " .. tostring(idb.spellID)),
                            tex  = (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(idb.spellID)) or 134400 }
                    end
                end
            end
        end
        table.sort(out, function(a, b)
            if a.li == b.li then return (a.iconKey or tostring(a.id)) < (b.iconKey or tostring(b.id)) end
            return a.li < b.li
        end)
        return out
    end
    local function entryLabel(e)
        -- Grey out racials this race doesn't have, and cross-spec specials that already exist live.
        local raceDim = ns.RacialSet and ns.RacialSet[e.id] and CG and CG.PlayerHasRacial and not CG.PlayerHasRacial(e.id)
        local dim = raceDim or (e.kind == "specialicon" and e.existsKey ~= nil)
        local name = dim and ("|cFF777777" .. e.name .. "|r") or e.name
        local extra = raceDim and " |cFF555555(other race)|r" or ""
        local idShown = (e.kind == "timer" and e.realID) or e.id
        if e.kind == "timer" then extra = extra .. " |cFF8AC8FF(Timer)|r" end
        if e.kind == "specialicon" then extra = extra .. " |cFFFF80C0(Special Icon)|r" end
        return ("|T%d:18:18:0:0|t %s |cFF888888(%d)|r%s"):format(e.tex or 134400, name, idShown, extra)
    end

    local function scopeArgs(group, scope, getKey)
        local function editedClassFile()
            if scope == "class" then return getKey() end
            if scope == "spec" then local m = ns.SpecMeta(tonumber(getKey())); return m and m.classToken end
            return select(2, UnitClass("player"))
        end

        local function classSpellList()
            if scope == "spec" then return (ns.GetSpecSpellList and ns.GetSpecSpellList(tonumber(getKey()))) or {} end
            return (ns.GetClassSpellList and ns.GetClassSpellList(editedClassFile())) or {}
        end

        local function cdmMap()
            local CDM = ns.CDMSpells
            if not CDM then return nil end
            if scope == "spec" then return CDM.GetForSpec(tonumber(getKey())) end
            if scope == "class" then return CDM.GetForClass(editedClassFile()) end
            return CDM.GetForSpec(tonumber(curSpecID()))  -- global: what we can track
        end
        local function cdmOrdered()
            local map, list = cdmMap(), {}
            if map and next(map) then
                for id, nd in pairs(map) do
                    list[#list + 1] = { id = id, nd = nd,
                        nm = (C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("Spell " .. id) }
                end
            else
                for _, id in ipairs(classSpellList()) do
                    list[#list + 1] = { id = id, nd = false,
                        nm = (C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("Spell " .. id) }
                end
            end

            table.sort(list, function(a, b)
                if a.nd ~= b.nd then return not a.nd end
                return a.nm < b.nm
            end)
            return list
        end
        local function cdmValues()
            local out = {}
            for _, e in ipairs(cdmOrdered()) do
                if not e.nm and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(e.id) end
                local tex = (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(e.id)) or 0
                local nm = e.nm or ("Spell " .. e.id)
                out[tostring(e.id)] = e.nd
                    and ("|T%d:14:14|t |cFFFF6060%s|r"):format(tex, nm)
                    or  ("|T%d:14:14|t %s"):format(tex, nm)
            end
            return out
        end
        local function cdmSorting()
            local out = {}
            for _, e in ipairs(cdmOrdered()) do out[#out + 1] = tostring(e.id) end
            return out
        end
        local a = {
            addSpell = {
                order = 5, type = "select", width = "double",
                name = function()
                    local label
                    if scope == "spec" then
                        local m = ns.SpecMeta(tonumber(getKey()))
                        label = "Add Spell - " .. ((m and m.name) or "Spec")
                    elseif scope == "class" then
                        local cf = editedClassFile()
                        local nm = cf and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cf]
                        label = "Add Spell - " .. (nm or cf or "Class")
                    else
                        label = "Add Spell"
                    end
                    return "|cFF8AC8FF" .. label .. "|r"   -- spells = light blue
                end,
                values = cdmValues, sorting = cdmSorting,
                get = function() return "" end,
                set = function(_, v) local id = tonumber(v); if id and CG then CG.AddSpell(group, scope, getKey(), id); NotifyChange() end end,
            },
            addSpellID = {
                order = 6, type = "input", name = "|cFFFFD200...or Spell by ID|r",   -- gold
                get = function() return "" end,
                set = function(_, v) local id = tonumber((v or ""):gsub("%s", "")); if id and CG then CG.AddSpell(group, scope, getKey(), id); NotifyChange() end end,
            },
            addItem = {
                order = 8, type = "input", name = "|cFFFF8040Add Item (ID or name)|r", width = "double",   -- items = orange
                get = function() return "" end,
                set = function(_, v)
                    v = (v or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if v == "" or not CG then return end
                    local id = tonumber(v)
                    if id then
                        CG.AddItem(group, scope, getKey(), id); NotifyChange()
                    elseif CG.AddItemByName(group, scope, getKey(), v) then
                        NotifyChange()
                    else
                        print("|cFF8080FFthingsUI|r: no item '" .. v .. "' found (must be cached or in your bags).")
                    end
                end,
            },
            commonItems = {
                order = 11, type = "select", name = "|cFFFF8040Common Items|r", width = "double",   -- items = orange
                values = commonItemValues, sorting = commonItemSorting,
                get = function() return "" end,
                set = function(_, v) local id = tonumber(v); if id and CG then CG.AddItem(group, scope, getKey(), id); NotifyChange() end end,
            },
            addTimer = {
                order = 12, type = "select", name = "|cFF8AC8FFAdd Timer|r", width = "double",   -- timers = light blue
                hidden = function()
                    if not ns.Timers then return true end
                    for _, t in ipairs(ns.Timers.GetTimers()) do if t.kind ~= "lust" then return false end end
                    return true
                end,
                values = function()
                    local v = {}
                    if ns.Timers then
                        for _, t in ipairs(ns.Timers.GetTimers()) do
                            if t.kind ~= "lust" then
                                local nm = (t.kind == "item")
                                    and ((C_Item.GetItemInfo(t.itemID)) or ("Item " .. tostring(t.itemID)))
                                    or  ((C_Spell.GetSpellName and C_Spell.GetSpellName(t.spellID)) or ("Spell " .. tostring(t.spellID)))
                                -- Show where the timer currently lives
                                local d, where = t.destination, ""
                                if d == "essential" then where = "  |cFF888888(in CDM Essential)|r"
                                elseif d == "utility" then where = "  |cFF888888(in CDM Utility)|r"
                                elseif d == "standalone" then where = "  |cFF888888(Standalone)|r"
                                elseif d == group.id then where = "  |cFF888888(here)|r"
                                elseif type(d) == "number" then
                                    local og = CG and CG.GroupByID and CG.GroupByID(d)
                                    where = ("  |cFFFF8040(in %s)|r"):format(og and (og.name or ("Group " .. d)) or ("Group " .. d))
                                end
                                v[tostring(t.id)] = ("|T%d:16:16:0:0|t %s%s"):format((ns.Timers.GetTexture and ns.Timers.GetTexture(t)) or 134400, nm, where)
                            end
                        end
                    end
                    return v
                end,
                get = function() return "" end,
                set = function(_, v)
                    local t = ns.Timers and ns.Timers.GetByID(tonumber(v))
                    if t then
                        t.destination = group.id
                        local k = getKey()
                        t.groupScope = (scope == "global") and "global" or (scope == "spec") and tonumber(k) or k
                        ns.Timers.Update(); NotifyChange()
                    end
                end,
            },
            addSpecialIcon = {
                order = 13, type = "select", name = "|cFFFF80C0Add Special Icon|r", width = "double",   -- special icons = pink
                hidden = function()
                    if scope ~= "spec" or getKey() ~= curSpecID() then return true end
                    local SB = ns.SpecialBars
                    if not SB then return true end
                    for i = 1, (SB.GetIconCount and SB.GetIconCount() or 0) do
                        local idb = SB.GetIconDB and SB.GetIconDB("icon" .. i)
                        if idb and idb.enabled and idb.spellID then return false end
                    end
                    return true
                end,
                values = function()
                    local v, SB = {}, ns.SpecialBars
                    if SB then
                        for i = 1, (SB.GetIconCount and SB.GetIconCount() or 0) do
                            local ikey = "icon" .. i
                            local idb = SB.GetIconDB and SB.GetIconDB(ikey)
                            if idb and idb.enabled and idb.spellID then
                                local nm = (C_Spell.GetSpellName and C_Spell.GetSpellName(idb.spellID)) or ("Spell " .. tostring(idb.spellID))
                                local where = (idb.customGroup == group.id) and "  |cFF888888(here)|r"
                                    or (idb.customGroup and "  |cFFFF8040(in another group)|r") or ""
                                v[ikey] = ("|T%d:16:16|t %s%s"):format((C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(idb.spellID)) or 134400, nm, where)
                            end
                        end
                    end
                    return v
                end,
                get = function() return "" end,
                set = function(_, v)
                    local SB = ns.SpecialBars
                    local idb = SB and SB.GetIconDB and SB.GetIconDB(v)
                    if idb then
                        idb.customGroup = group.id
                        if SB.ReleaseIcon then SB.ReleaseIcon(v) end
                        TUI:UpdateSpecialBars(); TUI:UpdateCustomGroups(); NotifyChange()
                    end
                end,
            },
            entriesBox = {
                order = 15, type = "group", inline = true, name = " ",
                args = (function()
                    local box = {}
                    box._empty = {
                        order = 1, type = "description", width = "full", fontSize = "medium",
                        name = "|cFF888888Nothing added for this scope.|r",
                        hidden = function() return #entriesFor(group, scope, getKey()) > 0 end,
                    }
                    for i = 1, 50 do
                        local idx = i
                        local function entry() return entriesFor(group, scope, getKey())[idx] end
                        local base = 10 + i * 10
                        local function gone() return entry() == nil end
                        -- Special-icon order is per-spec; reordering one from another spec is a no-op, so grey the arrows.
                        local function reorderLocked() local e = entry(); return e and e.kind == "specialicon" and not e.live or false end
                        box["r" .. i .. "_up"] = {
                            order = base + 1, type = "execute", name = CG_UP, width = 0.3, hidden = gone, disabled = reorderLocked,
                            func = function() local e = entry(); if e and CG then CG.MoveEntry(group, scope, getKey(), e.uid, -1); NotifyChange() end end,
                        }
                        box["r" .. i .. "_down"] = {
                            order = base + 2, type = "execute", name = CG_DOWN, width = 0.3, hidden = gone, disabled = reorderLocked,
                            func = function() local e = entry(); if e and CG then CG.MoveEntry(group, scope, getKey(), e.uid, 1); NotifyChange() end end,
                        }
                        box["r" .. i .. "_label"] = {
                            order = base + 3, type = "description", width = 2.0, fontSize = "medium", hidden = gone,
                            name = function() local e = entry(); return e and entryLabel(e) or "" end,
                        }
                        -- Timer / Special Icon entries link to their own config.
                        box["r" .. i .. "_link"] = {
                            order = base + 3.5, type = "execute", width = 0.8,
                            name = function()
                                local e = entry(); if not e then return "" end
                                if e.kind == "timer" then return "|cFF8AC8FFEdit Timer|r" end
                                if e.kind ~= "specialicon" then return "" end
                                if e.live then return "|cFFFF80C0Edit Icon|r" end
                                if e.existsKey then return "|cFF999999Exists|r" end
                                return "|cFF40D080Copy Icon|r"
                            end,
                            hidden = function() local e = entry(); return not (e and (e.kind == "timer" or e.kind == "specialicon")) end,
                            func = function()
                                local e = entry(); if not e then return end
                                if e.kind == "timer" then
                                    if E.ToggleOptions then E:ToggleOptions("thingsUI,modulesTab,timers,tmr" .. e.id) end
                                elseif e.live then
                                    if ns.SB_OpenIconEditor then ns.SB_OpenIconEditor(e.iconKey) end
                                elseif e.existsKey then
                                    if ns.SB_OpenIconEditor then ns.SB_OpenIconEditor(e.existsKey) end  -- jump to the one you already have
                                else
                                    CopySpecialToLive(e.srcSpec, e.iconKey, group.id)   -- replicate onto your live spec
                                end
                            end,
                        }
                        box["r" .. i .. "_remove"] = {
                            order = base + 4, type = "execute", name = "X", width = 0.3, hidden = gone,
                            func = function()
                                local e = entry(); if not e then return end
                                if e.kind == "timer" then
                                    local t = ns.Timers and ns.Timers.GetByID(e.id)
                                    if t then t.destination = nil; ns.Timers.Update() end
                                elseif e.kind == "specialicon" then
                                    local SB = ns.SpecialBars
                                    if e.live then
                                        local idb = SB and SB.GetIconDB and SB.GetIconDB(e.iconKey)
                                        if idb then idb.customGroup = nil; if SB.ReleaseIcon then SB.ReleaseIcon(e.iconKey) end end
                                    else
                                        local sb = E.db.thingsUI and E.db.thingsUI.specialBars
                                        local idb = sb and sb.specs and sb.specs[e.srcSpec] and sb.specs[e.srcSpec].icons and sb.specs[e.srcSpec].icons[e.iconKey]
                                        if idb then idb.customGroup = nil end
                                    end
                                    TUI:UpdateSpecialBars(); TUI:UpdateCustomGroups()
                                elseif CG then
                                    if e.kind == "item" then CG.RemoveItem(group, scope, getKey(), e.id) else CG.RemoveSpell(group, scope, getKey(), e.id) end
                                end
                                NotifyChange()
                            end,
                        }

                        box["r" .. i .. "_break"] = {
                            order = base + 5, type = "description", width = "full", fontSize = "small", name = " ", hidden = gone,
                        }
                    end
                    return box
                end)(),
            },
        }
        return a
    end

    local function GroupEditor(group, index)
        local function gset(k, v) group[k] = v; TUI:UpdateCustomGroups(); NotifyChange() end
        local function apply() TUI:UpdateSpecialBars(); TUI:UpdateCustomGroups(); NotifyChange() end
        local function tdb() return group.text end
        -- UpdateSpecialBars too: folded Special Icons get their cooldown text from the group's text.
        local function tset(k, v) tdb()[k] = v; TUI:UpdateSpecialBars(); TUI:UpdateCustomGroups(); NotifyChange() end
        local function isUIParent() return (group.anchorFrame or "UIParent") == "UIParent" end
        local function noCD() return not tdb().showCooldown end
        local function noCount() return not tdb().showCount end
        local function noStacks() return tdb().showStacks == false end
        -- The group references at least one item (plain, any scope) or item-kind timer.
        local function hasItems()
            local function rootHasItem(r) return r and r.items and next(r.items) ~= nil end
            if rootHasItem(group.global) then return true end
            for _, r in pairs(group.classes or {}) do if rootHasItem(r) then return true end end
            for _, r in pairs(group.specs or {}) do if rootHasItem(r) then return true end end
            if ns.Timers then
                for _, t in ipairs(ns.Timers.GetTimers()) do
                    -- Only a Show-When-Idle item timer actually draws count/quality.
                    if t.destination == group.id and t.kind == "item" and t.showIdle then return true end
                end
            end
            return false
        end

        local specArgs = scopeArgs(group, "spec", getEditSpec)
        specArgs.picker = {
            order = 1, type = "select", name = "Editing Spec", width = "double",
            dialogControl = "TUI_CascadeDropdown",
            values = function() return ns.CascadeDropdown.AllSpecs() end,
            get = function()
                local sid = tonumber(getEditSpec())
                local m = sid and ns.SpecMeta(sid)
                return m and (m.classToken .. ":" .. sid) or nil
            end,
            set = function(_, value)
                local sid = value and value:match("^[A-Z_]+:(%d+)$")
                if sid then editSpec = sid; NotifyChange() end
            end,
        }
        specArgs.gotoCur = {
            order = 1.5, type = "execute", width = 1.2,
            name = function()
                local m = ns.SpecMeta(tonumber(curSpecID()))
                if not m then return "Go to Current Spec" end
                local icon = m.icon and ("|T" .. m.icon .. ":14:14|t ") or ""
                return "Go to " .. icon .. ns.ClassColor(m.classToken) .. (m.name or "Current Spec") .. "|r"
            end,
            func = function() editSpec = curSpecID(); NotifyChange() end,
        }
        -- Clickable: each spec with specials jumps Editing Spec to it.
        specArgs.specSummary = ns.OptionLinkRowDynamic(1.7, function()
            local links = { { label = "Special Icons by spec:  ", color = { 1, 0.82, 0 } } }
            for _, r in ipairs(ns.AllSpecs()) do
                local n = GroupSpecialCount(group, r.id)
                if n > 0 then
                    local cc = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[r.classToken]
                    local icon = r.icon and ("|T" .. r.icon .. ":14:14|t ") or ""
                    local sid = tostring(r.id)
                    links[#links + 1] = {
                        label   = icon .. (r.name or r.id) .. " (" .. n .. ")",
                        color   = cc and { cc.r, cc.g, cc.b } or { 0.7, 0.7, 0.7 },
                        onClick = function() editSpec = sid; ReFeedScope(group, "spec") end,
                    }
                end
            end
            if #links == 1 then links[1] = { label = "No Special Icons assigned to this group on any spec yet.", color = { 0.5, 0.5, 0.5 } } end
            return links
        end)
        specArgs.pickerGap = { order = 2, type = "description", name = " " }

        local classArgs = scopeArgs(group, "class", getEditClass)
        classArgs.picker = {
            order = 1, type = "select", name = "Editing Class", width = "double",
            values = allClassValues, sorting = allClassSorting,
            get = function() return getEditClass() end,
            set = function(_, v) editClass = v; NotifyChange() end,
        }
        classArgs.gotoCur = {
            order = 1.5, type = "execute", width = 1.2,
            name = function()
                local _, cf = UnitClass("player")
                local nm = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cf]) or cf or "Current Class"
                local ic = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[cf]
                local icon = ic and ("|TInterface\\TargetingFrame\\UI-Classes-Circles:14:14:0:0:256:256:%d:%d:%d:%d|t "):format(ic[1] * 256, ic[2] * 256, ic[3] * 256, ic[4] * 256) or ""
                return "Go to " .. icon .. ns.ClassColor(cf) .. nm .. "|r"
            end,
            func = function() editClass = select(2, UnitClass("player")); NotifyChange() end,
        }
        -- Clickable: each class with entries jumps Editing Class to it.
        classArgs.classSummary = ns.OptionLinkRowDynamic(1.7, function()
            local links = { { label = "By class:  ", color = { 1, 0.82, 0 } } }
            for cid = 1, GetNumClasses() do
                local className, classFile = GetClassInfo(cid)
                if classFile then
                    local n = GroupClassCount(group, classFile)
                    if n > 0 then
                        local cc = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[classFile]
                        local ic = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
                        local icon = ic and ("|TInterface\\TargetingFrame\\UI-Classes-Circles:14:14:0:0:256:256:%d:%d:%d:%d|t "):format(ic[1] * 256, ic[2] * 256, ic[3] * 256, ic[4] * 256) or ""
                        local cf = classFile
                        links[#links + 1] = {
                            label   = icon .. (className or classFile) .. " (" .. n .. ")",
                            color   = cc and { cc.r, cc.g, cc.b } or { 0.7, 0.7, 0.7 },
                            onClick = function() editClass = cf; ReFeedScope(group, "class") end,
                        }
                    end
                end
            end
            if #links == 1 then links[1] = { label = "Nothing added to this group on any class yet.", color = { 0.5, 0.5, 0.5 } } end
            return links
        end)
        classArgs.pickerGap = { order = 2, type = "description", name = " " }

        local globalArgs = scopeArgs(group, "global", function() return nil end)
        globalArgs.gdesc = { order = 1, type = "description", name = "Global entries show on |cFFFFCF40every character and spec|r.\n" }
        -- Global swaps the known-spell dropdown for a racial picker.
        globalArgs.addSpell = nil
        globalArgs.addRacial = {
            order = 5, type = "select", name = "Add Racial", width = "double",
            values = racialValues, sorting = racialSorting,
            get = function() return "" end,
            set = function(_, v) local id = tonumber(v); if id and CG then CG.AddSpell(group, "global", nil, id); NotifyChange() end end,
        }
        globalArgs.addAllRacials = {
            order = 5.5, type = "execute", name = "|cFF40FF40Add All Racials|r", width = "double",
            func = function()
                if not (CG and ns.Racials) then return end
                for _, id in ipairs(ns.Racials) do CG.AddSpell(group, "global", nil, id) end
                NotifyChange()
            end,
        }

        local orderArgs = {
            desc = { order = 0, type = "description", name = "Order of the entry blocks (^/v). Each block keeps its own internal order.\n" },
        }
        for i = 1, 3 do
            local idx = i
            local function sc() local o = group.scopeOrder or { "global", "class", "spec" }; return o[idx] end
            orderArgs["block" .. i] = {
                order = 10 + i, type = "group", inline = true, name = "",
                args = {
                    up = { order = 1, type = "execute", name = CG_UP, width = 0.3,
                        func = function() local s = sc(); if s and CG then CG.MoveScope(group, s, -1); NotifyChange() end end },
                    down = { order = 2, type = "execute", name = CG_DOWN, width = 0.3,
                        func = function() local s = sc(); if s and CG then CG.MoveScope(group, s, 1); NotifyChange() end end },
                    label = { order = 3, type = "description", width = 2, fontSize = "medium",
                        name = function() local s = sc(); return idx .. ".  " .. (SCOPE_LABEL[s] or tostring(s)) end },
                },
            }
        end

        return {
            order = 10 + index, type = "group", childGroups = "tab",
            name = (group.enabled and group.name) or ("|cFF888888" .. (group.name or "Group") .. "|r"),
            args = {
                enable = {
                    order = 0, type = "toggle", name = "Enable", width = "half",
                    get = function() return group.enabled end,
                    set = function(_, v)
                        group.enabled = v
                        TUI:UpdateCustomGroups()
                        if TUI.UpdateTrinketsCDM then TUI:UpdateTrinketsCDM() end
                        if CG._rebuildOptions then CG._rebuildOptions() end
                        NotifyChange()
                    end,
                },
                gname = {
                    order = 1, type = "input", name = "Group Name", width = "double",
                    get = function() return group.name or "" end,
                    set = function(_, v)
                        if v and v ~= "" then group.name = v; if CG._rebuildOptions then CG._rebuildOptions() end; NotifyChange() end
                    end,
                },
                del = {
                    order = 2, type = "execute", name = "Delete Group", confirm = true,
                    confirmText = "Delete this Custom Group?",
                    func = function()
                        if CG then CG.RemoveGroup(index); if TUI.UpdateTrinketsCDM then TUI:UpdateTrinketsCDM() end; if CG._rebuildOptions then CG._rebuildOptions() end; NotifyChange() end
                    end,
                },

                specTab   = { order = 10, type = "group", name = "Spec",   args = specArgs },
                classTab  = { order = 11, type = "group", name = "Class",  args = classArgs },
                globalTab = { order = 12, type = "group", name = "Global", args = globalArgs },
                itemsTab = {
                    order = 13, type = "group", name = "Items",
                    hidden = function() return not hasItems() end,
                    args = {
                        hideZero = { order = 1, type = "toggle", name = "Hide When Empty", width = "full",
                            get = function() return group.hideZeroCharges end, set = function(_, v) gset("hideZeroCharges", v) end },
                        qualityGroup = {
                            order = 2, type = "group", name = "Quality Icon", inline = true,
                            args = {
                                quality = { order = 1, type = "toggle", name = "Show Quality Icon", width = "full",
                                    get = function() return group.qualityBorder end, set = function(_, v) gset("qualityBorder", v) end },
                                qScale = { order = 2, type = "range", name = "Size", min = 0.15, max = 1, step = 0.01, isPercent = true,
                                    disabled = function() return not group.qualityBorder end,
                                    get = function() return group.qualityScale or 0.42 end, set = function(_, v) gset("qualityScale", v) end },
                                qLayer = { order = 3, type = "select", name = "Layer",
                                    values = { TOP = "On Top", BEHIND = "Behind Cooldown" },
                                    sorting = { "TOP", "BEHIND" },
                                    disabled = function() return not group.qualityBorder end,
                                    get = function() return group.qualityLayer or "TOP" end, set = function(_, v) gset("qualityLayer", v) end },
                                qPoint = { order = 4, type = "select", name = "Anchor Point", values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                                    disabled = function() return not group.qualityBorder end,
                                    get = function() return group.qualityPoint or "TOPLEFT" end, set = function(_, v) gset("qualityPoint", v) end },
                                qX = { order = 5, type = "range", name = "X Offset", min = -32, max = 32, step = 1,
                                    disabled = function() return not group.qualityBorder end,
                                    get = function() return group.qualityXOffset or 0 end, set = function(_, v) gset("qualityXOffset", v) end },
                                qY = { order = 6, type = "range", name = "Y Offset", min = -32, max = 32, step = 1,
                                    disabled = function() return not group.qualityBorder end,
                                    get = function() return group.qualityYOffset or 0 end, set = function(_, v) gset("qualityYOffset", v) end },
                            },
                        },
                        fleetingGroup = {
                            order = 3, type = "group", name = "Fleeting Border", inline = true,
                            args = {
                                fleeting = { order = 1, type = "toggle", name = "Show on Fleeting Potions", width = "full",
                                    get = function() return group.fleetingMarker end, set = function(_, v) gset("fleetingMarker", v) end },
                                size = { order = 2, type = "range", name = "Size", min = 1, max = 16, step = 0.01, bigStep = 1,
                                    disabled = function() return not group.fleetingMarker end,
                                    get = function() return group.fleetingBorderSize end, set = function(_, v) gset("fleetingBorderSize", v) end },
                                color = { order = 3, type = "color", name = "Color", hasAlpha = true,
                                    disabled = function() return not group.fleetingMarker end,
                                    get = function() local c = group.fleetingBorderColor or {}; return c.r or 0.2, c.g or 0.8, c.b or 1, c.a or 1 end,
                                    set = function(_, r, g, b, al) local c = group.fleetingBorderColor or {}; c.r, c.g, c.b, c.a = r, g, b, al; group.fleetingBorderColor = c; apply() end },
                                inset = { order = 4, type = "range", name = "Inset", min = -10, max = 10, step = 0.01, bigStep = 1,
                                    disabled = function() return not group.fleetingMarker end,
                                    get = function() return group.fleetingBorderInset end, set = function(_, v) gset("fleetingBorderInset", v) end },
                                stroke = { order = 5, type = "toggle", name = "Stroke",
                                    disabled = function() return not group.fleetingMarker end,
                                    get = function() return group.fleetingBorderStroke end, set = function(_, v) gset("fleetingBorderStroke", v) end },
                            },
                        },
                    },
                },
                orderTab  = { order = 14, type = "group", name = "Order", args = orderArgs },
                layoutTab = {
                    order = 15, type = "group", name = "Layout & Position",
                    args = {
                        iconWidth = { order = 1, type = "range", min = 8, max = 80, step = 0.01, bigStep = 1,
                            name = function() return (group.squareIcon ~= false) and "Icon Size" or "Icon Width" end,
                            get = function() return group.iconWidth or group.iconSize or 36 end,
                            set = function(_, v) gset("iconWidth", v) end },
                        iconHeight = { order = 1.2, type = "range", name = "Icon Height", min = 8, max = 80, step = 0.01, bigStep = 1,
                            hidden = function() return group.squareIcon ~= false end,
                            get = function() return group.iconHeight or group.iconWidth or group.iconSize or 36 end,
                            set = function(_, v) gset("iconHeight", v) end },
                        squareIcon = { order = 1.4, type = "toggle", name = "Square Icons", width = 1.2,
                            get = function() return group.squareIcon ~= false end,
                            set = function(_, v) gset("squareIcon", v) end },
                        spacing = { order = 2, type = "range", name = "Spacing", min = -10, max = 10, step = 0.01, bigStep = 1,
                            get = function() return group.spacing end, set = function(_, v) gset("spacing", v) end },
                        growth = { order = 3, type = "select", name = "Growth Direction", values = ns.GROWTH.DIRECTIONAL, sorting = ns.GROWTH.DIRECTIONAL_ORDER,
                            get = function() return group.growth end, set = function(_, v) gset("growth", v) end },
                        columns = { order = 4, type = "range", name = "Wrap After (0 = no wrap)", min = 0, max = 20, step = 1,
                            get = function() return group.columns end, set = function(_, v) gset("columns", v) end },
                        wrapDir = {
                            order = 5, type = "select", name = "Wrap Direction",
                            disabled = function() return (group.columns or 0) <= 0 end,
                            values = function()
                                local g = group.growth
                                if g == "UP" or g == "DOWN" then return { RIGHT = "Right", LEFT = "Left" } end
                                return { DOWN = "Down", UP = "Up" }
                            end,
                            get = function()
                                local g = group.growth
                                local default = (g == "UP" or g == "DOWN") and "RIGHT" or "DOWN"
                                return group.wrapDir or default
                            end,
                            set = function(_, v) gset("wrapDir", v) end },
                        borderGroup = {
                            order = 6, type = "group", name = "Border", inline = true,
                            args = {
                                showBorder = { order = 1, type = "toggle", name = "Show Border", width = "full",
                                    get = function() return group.showBorder end, set = function(_, v) gset("showBorder", v) end },
                                size = { order = 2, type = "range", name = "Size", min = 1, max = 16, step = 0.01, bigStep = 1,
                                    disabled = function() return not group.showBorder end,
                                    get = function() return group.borderSize or 1 end, set = function(_, v) gset("borderSize", v) end },
                                color = { order = 3, type = "color", name = "Color", hasAlpha = true,
                                    disabled = function() return not group.showBorder end,
                                    get = function() local c = group.borderColor or {}; return c.r or 0, c.g or 0, c.b or 0, c.a or 1 end,
                                    set = function(_, r, g, b, al) local c = group.borderColor or {}; c.r, c.g, c.b, c.a = r, g, b, al; group.borderColor = c; apply() end },
                                inset = { order = 4, type = "range", name = "Inset", min = -10, max = 10, step = 0.01, bigStep = 1,
                                    disabled = function() return not group.showBorder end,
                                    get = function() return group.borderInset or 0 end, set = function(_, v) gset("borderInset", v) end },
                                stroke = { order = 5, type = "toggle", name = "Stroke",
                                    disabled = function() return not group.showBorder end,
                                    get = function() return group.borderStroke end, set = function(_, v) gset("borderStroke", v) end },
                            },
                        },
                        positionGroup = {
                            order = 7, type = "group", name = "Position", inline = true,
                            args = {
                                moveHint = { order = 0, type = "description",
                                    name = "UIParent = free (move via |cFFFFD200/emove|r). Pick a frame to snap to it.\n" },
                                anchorFrame = { order = 1, type = "select", name = "Anchor To", values = ns.ANCHORS.GetSharedAnchorValues, sorting = ns.ANCHORS.GetSharedAnchorOrder,
                                    get = function() return group.anchorFrame or "UIParent" end, set = function(_, v) gset("anchorFrame", v) end },
                                anchorCustom = { order = 1.5, type = "input", name = "Custom Frame Name", width = "double",
                                    hidden = function() return group.anchorFrame ~= "CUSTOM" end,
                                    get = function() return group.anchorFrameCustom or "" end,
                                    set = function(_, v) gset("anchorFrameCustom", (v or ""):gsub("%s", "")) end },
                                anchorPoint = { order = 2, type = "select", name = "Anchor From (self)", values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                                    hidden = isUIParent, get = function() return group.anchorPoint end, set = function(_, v) gset("anchorPoint", v) end },
                                anchorRelativePoint = { order = 3, type = "select", name = "Anchor To (target)", values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                                    hidden = isUIParent, get = function() return group.anchorRelativePoint end, set = function(_, v) gset("anchorRelativePoint", v) end },
                                anchorXOffset = { order = 4, type = "range", name = "X Offset", min = -400, max = 400, step = 1,
                                    hidden = isUIParent, get = function() return group.anchorXOffset end, set = function(_, v) gset("anchorXOffset", v) end },
                                anchorYOffset = { order = 5, type = "range", name = "Y Offset", min = -400, max = 400, step = 1,
                                    hidden = isUIParent, get = function() return group.anchorYOffset end, set = function(_, v) gset("anchorYOffset", v) end },
                            },
                        },
                    },
                },
                textTab = {
                    order = 17, type = "group", name = "Text",
                    args = {
                        cdGroup = {
                            order = 1, type = "group", name = "Cooldown Text", inline = true,
                            args = {
                                showCooldown = { order = 1, type = "toggle", name = "Show Cooldown Text", width = "full",
                                    get = function() return tdb().showCooldown end, set = function(_, v) tset("showCooldown", v) end },
                                cdFont = { order = 2, type = "select", dialogControl = "LSM30_Font", name = "Font", values = ns.FontValues, disabled = noCD,
                                    get = function() return tdb().cooldownFont end, set = function(_, v) tset("cooldownFont", v) end },
                                cdSize = { order = 3, type = "range", name = "Font Size", min = 6, max = 40, step = 1, disabled = noCD,
                                    get = function() return tdb().cooldownFontSize end, set = function(_, v) tset("cooldownFontSize", v) end },
                                cdOutline = { order = 4, type = "select", name = "Outline", values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER, disabled = noCD,
                                    get = function() return tdb().cooldownFontOutline end, set = function(_, v) tset("cooldownFontOutline", v) end },
                                cdColor = { order = 5, type = "color", name = "Color", disabled = noCD,
                                    get = function() local c = tdb().cooldownColor or {}; return c.r or 1, c.g or 1, c.b or 1 end,
                                    set = function(_, r, g, b) local c = tdb().cooldownColor or {}; c.r, c.g, c.b = r, g, b; tdb().cooldownColor = c; apply() end },
                                cdPoint = { order = 6, type = "select", name = "Text Position", values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER, disabled = noCD,
                                    get = function() return tdb().cooldownPoint end, set = function(_, v) tset("cooldownPoint", v) end },
                                cdX = { order = 7, type = "range", name = "Text X", min = -50, max = 50, step = 1, disabled = noCD,
                                    get = function() return tdb().cooldownXOffset end, set = function(_, v) tset("cooldownXOffset", v) end },
                                cdY = { order = 8, type = "range", name = "Text Y", min = -50, max = 50, step = 1, disabled = noCD,
                                    get = function() return tdb().cooldownYOffset end, set = function(_, v) tset("cooldownYOffset", v) end },
                            },
                        },
                        countGroup = {
                            order = 2, type = "group", name = "Count Text", inline = true,
                            args = {
                                countDesc = { order = 0, type = "description",
                                    name = "The number in the corner: |cFFFFD200spell charges|r or |cFF80C0FFitem quantity|r.\n" },
                                showCount = { order = 1, type = "toggle", name = "Show Count Text", width = "full",
                                    get = function() return tdb().showCount end, set = function(_, v) tset("showCount", v) end },
                                cntFont = { order = 2, type = "select", dialogControl = "LSM30_Font", name = "Font", values = ns.FontValues, disabled = noCount,
                                    get = function() return tdb().countFont end, set = function(_, v) tset("countFont", v) end },
                                cntSize = { order = 3, type = "range", name = "Font Size", min = 6, max = 40, step = 1, disabled = noCount,
                                    get = function() return tdb().countFontSize end, set = function(_, v) tset("countFontSize", v) end },
                                cntOutline = { order = 4, type = "select", name = "Outline", values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER, disabled = noCount,
                                    get = function() return tdb().countFontOutline end, set = function(_, v) tset("countFontOutline", v) end },
                                cntColor = { order = 5, type = "color", name = "Color", disabled = noCount,
                                    get = function() local c = tdb().countColor or {}; return c.r or 1, c.g or 1, c.b or 1 end,
                                    set = function(_, r, g, b) local c = tdb().countColor or {}; c.r, c.g, c.b = r, g, b; tdb().countColor = c; apply() end },
                                cntPoint = { order = 6, type = "select", name = "Text Position", values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER, disabled = noCount,
                                    get = function() return tdb().countPoint end, set = function(_, v) tset("countPoint", v) end },
                                cntX = { order = 7, type = "range", name = "Text X", min = -50, max = 50, step = 1, disabled = noCount,
                                    get = function() return tdb().countXOffset end, set = function(_, v) tset("countXOffset", v) end },
                                cntY = { order = 8, type = "range", name = "Text Y", min = -50, max = 50, step = 1, disabled = noCount,
                                    get = function() return tdb().countYOffset end, set = function(_, v) tset("countYOffset", v) end },
                            },
                        },
                        stacksGroup = {
                            order = 3, type = "group", name = "Stacks Text", inline = true,
                            args = {
                                stacksDesc = { order = 0, type = "description",
                                    name = "Buff |cFFFFD200stack count|r (e.g. Moonfire stacks) on folded Special Icons.\n" },
                                showStacks = { order = 1, type = "toggle", name = "Show Stacks Text", width = "full",
                                    get = function() return tdb().showStacks ~= false end, set = function(_, v) tset("showStacks", v) end },
                                stkFont = { order = 2, type = "select", dialogControl = "LSM30_Font", name = "Font", values = ns.FontValues, disabled = noStacks,
                                    get = function() return tdb().stacksFont end, set = function(_, v) tset("stacksFont", v) end },
                                stkSize = { order = 3, type = "range", name = "Font Size", min = 6, max = 40, step = 1, disabled = noStacks,
                                    get = function() return tdb().stacksFontSize end, set = function(_, v) tset("stacksFontSize", v) end },
                                stkOutline = { order = 4, type = "select", name = "Outline", values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER, disabled = noStacks,
                                    get = function() return tdb().stacksFontOutline end, set = function(_, v) tset("stacksFontOutline", v) end },
                                stkColor = { order = 5, type = "color", name = "Color", disabled = noStacks,
                                    get = function() local c = tdb().stacksColor or {}; return c.r or 1, c.g or 1, c.b or 1 end,
                                    set = function(_, r, g, b) local c = tdb().stacksColor or {}; c.r, c.g, c.b = r, g, b; tdb().stacksColor = c; apply() end },
                                stkPoint = { order = 6, type = "select", name = "Text Position", values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER, disabled = noStacks,
                                    get = function() return tdb().stacksPoint end, set = function(_, v) tset("stacksPoint", v) end },
                                stkX = { order = 7, type = "range", name = "Text X", min = -50, max = 50, step = 1, disabled = noStacks,
                                    get = function() return tdb().stacksXOffset end, set = function(_, v) tset("stacksXOffset", v) end },
                                stkY = { order = 8, type = "range", name = "Text Y", min = -50, max = 50, step = 1, disabled = noStacks,
                                    get = function() return tdb().stacksYOffset end, set = function(_, v) tset("stacksYOffset", v) end },
                            },
                        },
                    },
                },
            },
        }
    end

    -- Top: New button + one tab per group
    local args = {
        intro = {
            order = 0, type = "description",
            name = "\n\n",
        },
        addGroup = {
            order = 1, type = "execute", name = "|cFF40FF40+ New Custom Group|r",
            func = function() if CG then CG.AddGroup(); if CG._rebuildOptions then CG._rebuildOptions() end; NotifyChange() end end,
        },
        emptyHint = {
            order = 2, type = "description", fontSize = "medium",
            name = "|cFF888888No groups yet - click + New Custom Group.|r",
            hidden = function() return #(CG and CG.GetGroups() or {}) > 0 end,
        },
    }

    local function rebuildGroupEntries()
        for k in pairs(args) do
            if type(k) == "string" and k:match("^group%d+$") then args[k] = nil end
        end
        local groups = CG and CG.GetGroups() or {}
        -- Alphabetical tab order; keys stay group<i> (DB index) so navigation is unchanged.
        local rank = {}
        for i = 1, #groups do rank[i] = i end
        table.sort(rank, function(a, b) return (groups[a].name or "") < (groups[b].name or "") end)
        for r = 1, #rank do
            local i = rank[r]
            local editor = GroupEditor(groups[i], i)
            editor.order = 10 + r
            args["group" .. i] = editor
        end
    end
    if CG then CG._rebuildOptions = rebuildGroupEntries end
    rebuildGroupEntries()

    return {
        order = 8, type = "group", name = "Custom Groups", childGroups = "tab",
        args = args,
    }
end
