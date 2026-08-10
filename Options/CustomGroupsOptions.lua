local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local NotifyChange = ns.NotifyChange

local SCOPE_LABEL = { global = "|cFFFFCF40Global|r", class = "|cFF80C0FFClass|r", spec = "|cFFFFD200Spec|r" }

-- preset buttons ask where the entry belongs rather than guessing a scope.
-- StaticPopup only wires two safe buttons, and escape must not pick a scope.
local function AskScope(title, subtitle, apply)
    local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
    if not AceGUI then apply("global") return end

    local f = AceGUI:Create("Frame")
    f:SetTitle("Add " .. title)
    f:SetStatusText(subtitle)
    f:SetLayout("Flow")
    f:SetWidth(380)
    f:SetHeight(180)
    f:EnableResize(false)

    local head = AceGUI:Create("Label")
    head:SetFullWidth(true)
    head:SetFontObject(GameFontHighlight)
    head:SetText("\nWhich characters should it show for?\n")
    f:AddChild(head)

    local _, classFile = UnitClass("player")
    local className = (classFile and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]) or classFile or "Class"
    local choices = {
        { scope = "global", label = "All Characters" },
        { scope = "class",  label = "This Class (" .. className .. ")" },
        { scope = "spec",   label = "This Spec" },
    }
    for _, c in ipairs(choices) do
        local b = AceGUI:Create("Button")
        b:SetText(c.label)
        b:SetWidth(115)
        b:SetCallback("OnClick", function()
            apply(c.scope)
            AceGUI:Release(f)
        end)
        f:AddChild(b)
    end
end
-- an aura row stays as narrow as every other row; the per-aura knobs live here
local function EditAura(def, title, onChange)
    local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
    if not (AceGUI and def) then return end

    local f = AceGUI:Create("Frame")
    f:SetTitle(title or "Buff")
    f:SetStatusText("Applies to this entry only")
    f:SetLayout("Flow")
    f:SetWidth(400)
    f:SetHeight(300)
    f:EnableResize(false)

    local on = AceGUI:Create("CheckBox")
    on:SetLabel("Enabled")
    on:SetWidth(170)
    on:SetValue(def.enabled ~= false)
    on:SetCallback("OnValueChanged", function(_, _, v) def.enabled = v; onChange() end)
    f:AddChild(on)

    local spacer = AceGUI:Create("Label")
    spacer:SetWidth(170)
    spacer:SetText(" ")
    f:AddChild(spacer)

    local kind = AceGUI:Create("Dropdown")
    kind:SetLabel("Type")
    kind:SetWidth(170)
    kind:SetList({ HELPFUL = "Buff", HARMFUL = "Debuff" }, { "HELPFUL", "HARMFUL" })
    kind:SetValue(def.kind or "HELPFUL")
    kind:SetCallback("OnValueChanged", function(_, _, v) def.kind = v; onChange() end)
    f:AddChild(kind)

    local unit = AceGUI:Create("Dropdown")
    unit:SetLabel("Unit")
    unit:SetWidth(170)
    unit:SetList({ player = "Player", target = "Target", focus = "Focus", pet = "Pet" },
        { "player", "target", "focus", "pet" })
    unit:SetValue(def.unit or "player")
    unit:SetCallback("OnValueChanged", function(_, _, v) def.unit = v; onChange() end)
    f:AddChild(unit)

    local mine = AceGUI:Create("CheckBox")
    mine:SetLabel("Only Mine")
    mine:SetWidth(170)
    mine:SetValue(def.onlyMine and true or false)
    mine:SetCallback("OnValueChanged", function(_, _, v) def.onlyMine = v; onChange() end)
    f:AddChild(mine)

    -- stored now, rendered the moment Blizzard hands out the sink
    local AL = ns.AuraLane
    local caster = AceGUI:Create("CheckBox")
    caster:SetLabel("Show Caster Name")
    caster:SetWidth(170)
    caster:SetValue(def.showSource and true or false)
    caster:SetCallback("OnValueChanged", function(_, _, v) def.showSource = v; onChange() end)
    f:AddChild(caster)
    if AL.SourceProbed() and not AL.CanShowSource() then
        local note = AceGUI:Create("Label")
        note:SetFullWidth(true)
        note:SetText("|cff888888Caster names arrive with Blizzard patch 12.1.5 - the setting applies automatically once it ships.|r")
        f:AddChild(note)
    end

    local max = AceGUI:Create("Slider")
    max:SetLabel("Max Icons")
    max:SetWidth(170)
    max:SetSliderValues(1, 10, 1)
    max:SetValue(def.max or 1)
    max:SetCallback("OnValueChanged", function(_, _, v) def.max = v; onChange() end)
    f:AddChild(max)
end

local CG_UP   = "|TInterface\\Buttons\\Arrow-Up-Up:16:16:0:2|t"
local CG_DOWN = "|TInterface\\Buttons\\Arrow-Up-Up:16:16:0:-2:32:32:0:32:32:0|t"
local CG_X    = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:13|t"
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

local function SpecEntryCount(group, specID)
    local n = GroupSpecialCount(group, specID)
    local CG = ns.CustomGroups
    local root = CG and CG.GetScopeRoot and CG.GetScopeRoot(group, "spec", specID, false)
    if root then
        for _, d in pairs(root.spells or {}) do if d and d.enabled ~= false then n = n + 1 end end
        for _, d in pairs(root.items  or {}) do if d and d.enabled ~= false then n = n + 1 end end
    end
    if ns.Timers and ns.Timers.GetTimers then
        for _, t in ipairs(ns.Timers.GetTimers()) do
            if t.enabled and t.destination == group.id and t.groupScope == specID then n = n + 1 end
        end
    end
    return n
end

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
    local function curSpecID()
        local idx = GetSpecialization()
        return tostring((idx and GetSpecializationInfo(idx)) or 1)
    end
    local function curClassFile() local _, cf = UnitClass("player"); return cf end
    local function getEditSpec()  return editSpec  or curSpecID()  end
    local function getEditClass() return editClass or curClassFile() end

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
    local function auraPresetByKey(key)
        for _, p in ipairs(ns.AURA_PRESETS or {}) do
            if p.key == key then return p end
        end
    end
    local function auraCommonOrdered()
        local list = {}
        for _, id in ipairs(ns.AURA_COMMON or {}) do
            local nm = C_Spell.GetSpellName and C_Spell.GetSpellName(id)
            if not nm and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(id) end
            list[#list + 1] = { key = tostring(id), id = id, nm = nm }
        end
        local lust = auraPresetByKey("bloodlust")
        if lust then
            list[#list + 1] = { key = "p:bloodlust", id = lust.spells[1],
                nm = "Bloodlust & Heroism", suffix = " |cff888888" .. #lust.spells .. " spells|r" }
        end
        table.sort(list, function(a, b) return (a.nm or tostring(a.id)) < (b.nm or tostring(b.id)) end)
        return list
    end
    local function auraCommonValues()
        local out = {}
        for _, e in ipairs(auraCommonOrdered()) do
            local tex = (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(e.id)) or 0
            out[e.key] = ("|T%d:14:14|t %s%s"):format(tex, e.nm or ("Spell " .. e.id), e.suffix or "")
        end
        return out
    end
    local function auraCommonSorting()
        local out = {}
        for _, e in ipairs(auraCommonOrdered()) do out[#out + 1] = e.key end
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
            for uid, d in pairs(root.auras or {}) do
                local spells = ns.AuraLane.SpellList(d)
                local first = spells[1]
                out[#out + 1] = { kind = "aura", id = first or 0, auraUID = tostring(uid),
                    li = d.layoutIndex or 999, uid = "aura:" .. tostring(uid),
                    setCount = (#spells > 1) and #spells or nil,
                    name = d.name or (first and C_Spell.GetSpellName and C_Spell.GetSpellName(first)) or "Aura",
                    tex  = (first and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(first)) or 134400 }
            end
        end

        if ns.Timers then
            for _, t in ipairs(ns.Timers.GetTimers()) do
                if t.destination == group.id and t.kind ~= "lust" then
                    local gs = t.groupScope or "global"
                    local match = (scope == "global" and gs == "global")
                        or (scope == "spec" and tostring(gs) == tostring(key))
                        or (scope == "class" and gs == key)

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
        local raceDim = ns.RacialSet and ns.RacialSet[e.id] and CG and CG.PlayerHasRacial and not CG.PlayerHasRacial(e.id)
        local dim = raceDim or (e.kind == "specialicon" and e.existsKey ~= nil)
        local name = dim and ("|cFF777777" .. e.name .. "|r") or e.name
        local extra = raceDim and " |cFF555555(other race)|r" or ""
        local idShown = (e.kind == "timer" and e.realID) or e.id
        if e.kind == "timer" then extra = extra .. " |cFF8AC8FF(Timer)|r" end
        if e.kind == "specialicon" then extra = extra .. " |cFFFF80C0(Special Icon)|r" end
        if e.kind == "aura" then
            extra = extra .. " |cFF60E0A0(Buff)|r"
            if e.setCount then
                return ("|T%d:14:14:0:0|t %s |cFF888888(%d spells)|r%s")
                    :format(e.tex or 134400, name, e.setCount, extra)
            end
        end
        return ("|T%d:14:14:0:0|t %s |cFF888888(%d)|r%s"):format(e.tex or 134400, name, idShown, extra)
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
                set = function(_, v) local id = tonumber(((v or ""):gsub("%s", ""))); if id and CG then CG.AddSpell(group, scope, getKey(), id); NotifyChange() end end,
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
            addAura = {
                order = 11.5, type = "select", name = "|cFF60E0A0Add Buff|r", width = "double",   -- auras = green
                values = auraCommonValues, sorting = auraCommonSorting,
                get = function() return "" end,
                set = function(_, v)
                    if not CG then return end
                    local pkey = v:match("^p:(.+)")
                    if pkey then
                        local p = auraPresetByKey(pkey)
                        if p then CG.AddAuraSet(group, scope, getKey(), "preset:" .. pkey, p) end
                    else
                        local id = tonumber(v)
                        if id then CG.AddAura(group, scope, getKey(), id) end
                    end
                    TUI:UpdateCustomGroups(); NotifyChange()
                end,
            },
            addAuraID = {
                order = 11.6, type = "input", name = "|cFF60E0A0...or Buff by ID or name|r",
                get = function() return "" end,
                set = function(_, v)
                    v = (v or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if v == "" or not CG then return end
                    local id = tonumber(v)
                    if not id then
                        local info = C_Spell.GetSpellInfo(v)
                        id = info and info.spellID
                    end
                    if not (id and C_Spell.GetSpellInfo(id)) then return end
                    CG.AddAura(group, scope, getKey(), id)
                    TUI:UpdateCustomGroups(); NotifyChange()
                end,
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
            newSpecialIcon = {
                order = 13.5, type = "select", name = "|cFFFF80C0New Special Icon (from spell)|r", width = "double",
                hidden = function()
                    return scope ~= "spec" or getKey() ~= curSpecID() or not ns.SpecialBars
                end,
                values = function()
                    return (ns.SB_SpellChoices and ns.SB_SpellChoices(nil, false, true)) or {}
                end,
                sorting = function()
                    return ns.SB_SpellChoicesSorting and ns.SB_SpellChoicesSorting(true) or nil
                end,
                get = function() return "" end,
                set = function(_, v)
                    local SB = ns.SpecialBars
                    local id = tonumber(v)
                    if not (SB and id and SB.GetSpecRoot and SB.GetIconDB) then return end
                    local usage = SB.GetSpellUsageInfo and SB.GetSpellUsageInfo(id)
                    if usage then E:Print("This spell is already used by " .. usage .. "!") return end
                    local s = SB.GetSpecRoot()
                    local c = s.iconCount or 3
                    if c >= 12 then E:Print("All 12 Special Icon slots are in use on this spec.") return end
                    s.iconCount = c + 1
                    local idb = SB.GetIconDB("icon" .. (c + 1))
                    if SB.Styles and SB.Styles.ApplyToDB then
                        SB.Styles.ApplyToDB("icons", SB.Styles.EffectiveDefault("icons"), idb)
                    end
                    local raw = SB.GetRawSpellList and SB.GetRawSpellList() or {}
                    idb.spellID = id
                    idb.spellName = (raw[id] and raw[id].name) or ""
                    idb.enabled = true
                    idb.customGroup = group.id
                    TUI:UpdateSpecialBars(); TUI:UpdateCustomGroups(); NotifyChange()
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

                        local function reorderLocked() local e = entry(); return e and e.kind == "specialicon" and not e.live or false end
                        box["r" .. i .. "_up"] = {
                            order = base + 1, type = "execute", name = CG_UP, width = 0.3, hidden = gone, disabled = reorderLocked,
                            func = function() local e = entry(); if e and CG then CG.MoveEntry(group, scope, getKey(), e.uid, -1); NotifyChange() end end,
                        }
                        box["r" .. i .. "_down"] = {
                            order = base + 2, type = "execute", name = CG_DOWN, width = 0.3, hidden = gone, disabled = reorderLocked,
                            func = function() local e = entry(); if e and CG then CG.MoveEntry(group, scope, getKey(), e.uid, 1); NotifyChange() end end,
                        }
                        -- no fontSize: a taller font sets the row height for the
                        -- whole line, and the buttons are already 24px
                        box["r" .. i .. "_label"] = {
                            order = base + 3, type = "description", width = 1.55, hidden = gone,
                            name = function() local e = entry(); return e and entryLabel(e) or "" end,
                        }

                        box["r" .. i .. "_link"] = {
                            order = base + 3.5, type = "execute", width = 0.6,
                            name = function()
                                local e = entry(); if not e then return "" end
                                if e.kind == "timer" then return "|cFF8AC8FFEdit Timer|r" end
                                if e.kind == "aura" then return "|cFF60E0A0Settings|r" end
                                if e.kind ~= "specialicon" then return "" end
                                if e.live then return "|cFFFF80C0Edit Icon|r" end
                                if e.existsKey then return "|cFF999999Exists|r" end
                                return "|cFF40D080Copy Icon|r"
                            end,
                            hidden = function()
                                local e = entry()
                                return not (e and (e.kind == "timer" or e.kind == "specialicon" or e.kind == "aura"))
                            end,
                            func = function()
                                local e = entry(); if not e then return end
                                if e.kind == "aura" then
                                    local root = CG and CG.GetScopeRoot(group, scope, getKey(), false)
                                    local def = root and root.auras and root.auras[e.auraUID]
                                    if def then
                                        EditAura(def, e.name, function()
                                            TUI:UpdateCustomGroups(); NotifyChange()
                                        end)
                                    end
                                elseif e.kind == "timer" then
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
                            order = base + 4, type = "execute", name = CG_X, width = 0.3, hidden = gone,
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
                                    if e.kind == "item" then CG.RemoveItem(group, scope, getKey(), e.id)
                                    elseif e.kind == "aura" then CG.RemoveAura(group, scope, getKey(), e.auraUID)
                                    else CG.RemoveSpell(group, scope, getKey(), e.id) end
                                    TUI:UpdateCustomGroups()
                                end
                                NotifyChange()
                            end,
                        }

                        box["r" .. i .. "_style"] = {
                            order = base + 4.5, type = "select", name = "", width = 1.2,
                            hidden = function() local e = entry(); return not (e and e.kind == "specialicon" and e.live) end,
                            values = function()
                                local SB = ns.SpecialBars
                                return (SB and SB.Styles and SB.Styles.DropdownValues("icons", "|cFF888888- No Style -|r")) or {}
                            end,
                            sorting = function()
                                local SB = ns.SpecialBars
                                return SB and SB.Styles and SB.Styles.DropdownSorting("icons", true) or nil
                            end,
                            get = function()
                                local e = entry(); local SB = ns.SpecialBars
                                local idb = e and SB and SB.GetIconDB and SB.GetIconDB(e.iconKey)
                                return (idb and idb.styleName) or ""
                            end,
                            set = function(_, v)
                                local e = entry(); local SB = ns.SpecialBars
                                local idb = e and SB and SB.GetIconDB and SB.GetIconDB(e.iconKey)
                                if not idb then return end
                                idb._styleDriftAck = nil
                                if v == "" then
                                    idb.styleName = nil
                                else
                                    SB.Styles.ApplyToDB("icons", v, idb)
                                end
                                TUI:UpdateSpecialBars(); NotifyChange()
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
        local function tset(k, v) tdb()[k] = v; TUI:UpdateSpecialBars(); TUI:UpdateCustomGroups(); NotifyChange() end
        local function isUIParent() return (group.anchorFrame or "UIParent") == "UIParent" end
        local function noCD() return not tdb().showCooldown end
        local function noCount() return not tdb().showCount end
        local function noStacks() return tdb().showStacks == false end
        local function hasItems()
            local function rootHasItem(r) return r and r.items and next(r.items) ~= nil end
            if rootHasItem(group.global) then return true end
            for _, r in pairs(group.classes or {}) do if rootHasItem(r) then return true end end
            for _, r in pairs(group.specs or {}) do if rootHasItem(r) then return true end end
            if ns.Timers then
                for _, t in ipairs(ns.Timers.GetTimers()) do
                    if t.destination == group.id and t.kind == "item" and t.showIdle then return true end
                end
            end
            return false
        end

        local specArgs = scopeArgs(group, "spec", getEditSpec)
        specArgs.picker = {
            order = 1, type = "select", name = "Editing Spec", width = "double",
            dialogControl = "TUI_CascadeDropdown",
            values = function()
                local counts = {}
                for _, r in ipairs(ns.AllSpecs()) do counts[r.id] = SpecEntryCount(group, r.id) end
                return ns.CascadeDropdown.AllSpecsWithCounts(counts)
            end,
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
        specArgs.pickerGap = { order = 2, type = "description", name = " " }

        local classArgs = scopeArgs(group, "class", getEditClass)
        classArgs.picker = {
            order = 1, type = "select", name = "Editing Class", width = "double",
            values = function()
                local out = allClassValues()
                for cf in pairs(out) do
                    local n = GroupClassCount(group, cf)
                    if n > 0 then out[cf] = out[cf] .. " |cFFFFD200(" .. n .. ")|r" end
                end
                return out
            end,
            sorting = allClassSorting,
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
        classArgs.pickerGap = { order = 2, type = "description", name = " " }

        local globalArgs = scopeArgs(group, "global", function() return nil end)
        globalArgs.gdesc = { order = 1, type = "description", name = "Global entries show on |cFFFFCF40every character and spec|r.\n" }
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
        globalArgs.addUnassignedRacials = {
            order = 5.6, type = "execute", name = "|cFF59D759Add All Unassigned Racials|r", width = "double",
            hidden = function()
                local r = E.db.thingsUI and E.db.thingsUI.racialsCDM
                return not (r and r.customGroupsOnly)
            end,
            func = function()
                if not (CG and ns.Racials) then return end
                local find = ns.RacialsCDM and ns.RacialsCDM.FindRacialGroup
                for _, id in ipairs(ns.Racials) do
                    if not (find and find(id)) then CG.AddSpell(group, "global", nil, id) end
                end
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
        -- auras always render last: the block grows with the aura count, which
        -- is a secret value, so nothing can be placed after it
        orderArgs.auraBlock = {
            order = 14, type = "group", inline = true, name = "",
            hidden = function()
                return not (ns.AuraLane and ns.AuraLane.HasSets(group))
            end,
            args = {
                pad = { order = 1, type = "description", width = 0.6, name = " " },
                label = { order = 2, type = "description", width = 2, fontSize = "medium",
                    name = "4.  Auras  |cff888888(always last)|r" },
            },
        }

        local AL = ns.AuraLane

        local aurasArgs = {
            desc = {
                order = 1, type = "description",
                name = "Buffs and debuffs drawn at the end of this group, using its icon size, spacing, growth, font and border.\n|cff888888Add single auras with Add Buff in the Spec, Class or Global tab. They appear in that tab's list. The buttons below add a whole set at once.|r\n",
            },
            presets = {
                order = 20, type = "group", inline = true, name = "Ready-Made Sets",
                args = {},
            },
            display = {
                order = 30, type = "group", inline = true, name = "Display",
                args = {
                    swipe = {
                        order = 1, type = "toggle", name = "Cooldown Swipe",
                        get = function() return AL.DB(group).swipe ~= false end,
                        set = function(_, v) AL.DB(group).swipe = v; TUI:UpdateCustomGroups() end,
                    },
                    swipeInverse = {
                        order = 2, type = "toggle", name = "Invert Swipe",
                        disabled = function() return AL.DB(group).swipe == false end,
                        get = function() return AL.DB(group).swipeInverse end,
                        set = function(_, v) AL.DB(group).swipeInverse = v; TUI:UpdateCustomGroups() end,
                    },
                    tooltips = {
                        order = 3, type = "toggle", name = "Tooltips",
                        get = function() return AL.DB(group).tooltips end,
                        set = function(_, v) AL.DB(group).tooltips = v; TUI:UpdateCustomGroups() end,
                    },
                    colorThreshold = {
                        order = 4, type = "toggle", name = "Color When Low",
                        get = function() return AL.DB(group).colorThreshold ~= false end,
                        set = function(_, v) AL.DB(group).colorThreshold = v; TUI:UpdateCustomGroups() end,
                    },
                    thresholdSeconds = {
                        order = 5, type = "range", name = "Below", min = 1, max = 30, step = 1,
                        disabled = function() return AL.DB(group).colorThreshold == false end,
                        get = function() return AL.DB(group).thresholdSeconds or 3 end,
                        set = function(_, v) AL.DB(group).thresholdSeconds = v; TUI:UpdateCustomGroups() end,
                    },
                    thresholdColor = {
                        order = 6, type = "color", name = "Low Color",
                        disabled = function() return AL.DB(group).colorThreshold == false end,
                        get = function()
                            local c = AL.DB(group).thresholdColor or {}
                            return c.r or 1, c.g or 0.3, c.b or 0.3
                        end,
                        set = function(_, r, g, b)
                            AL.DB(group).thresholdColor = { r = r, g = g, b = b }
                            TUI:UpdateCustomGroups()
                        end,
                    },
                },
            },
        }

        for pi, preset in ipairs(ns.AURA_PRESETS or {}) do
            local p = preset
            aurasArgs.presets.args[p.key] = {
                order = pi, type = "execute", name = p.name, width = 1.1,
                func = function()
                    AskScope(p.name, group.name or ("Group " .. group.id), function(sc)
                        CG.AddAuraSet(group, sc, nil, "preset:" .. p.key, p)
                        if CG._rebuildOptions then CG._rebuildOptions() end
                        TUI:UpdateCustomGroups(); NotifyChange()
                    end)
                end,
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
                    order = 14.5, type = "group", name = "Items",
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
                aurasTab = {
                    order = 12.7, type = "group", childGroups = "tab", name = "Auras",
                    args = aurasArgs,
                },
                orderTab  = { order = 14, type = "group", name = "Order", args = orderArgs },
                visibilityTab = {
                    order = 16.5, type = "group", name = "Visibility",
                    args = {
                        enabled = {
                            order = 1, type = "toggle", name = "Limit Visibility", width = "full",
                            desc = "When off the group follows its normal rules and shows everywhere.",
                            get = function() return group.visibility and group.visibility.enabled or false end,
                            set = function(_, v)
                                group.visibility = group.visibility or {}
                                group.visibility.enabled = v
                                TUI:UpdateCustomGroups()
                            end,
                        },
                        desc = {
                            order = 2, type = "description",
                            name = "Pick the group sizes the group is allowed to show in.\n",
                            hidden = function() return not (group.visibility and group.visibility.enabled) end,
                        },
                        solo = {
                            order = 3, type = "toggle", name = "Solo",
                            hidden = function() return not (group.visibility and group.visibility.enabled) end,
                            get = function() return group.visibility.solo ~= false end,
                            set = function(_, v) group.visibility.solo = v; TUI:UpdateCustomGroups() end,
                        },
                        party = {
                            order = 4, type = "toggle", name = "Party",
                            hidden = function() return not (group.visibility and group.visibility.enabled) end,
                            get = function() return group.visibility.party ~= false end,
                            set = function(_, v) group.visibility.party = v; TUI:UpdateCustomGroups() end,
                        },
                        raid = {
                            order = 5, type = "toggle", name = "Raid",
                            hidden = function() return not (group.visibility and group.visibility.enabled) end,
                            get = function() return group.visibility.raid ~= false end,
                            set = function(_, v) group.visibility.raid = v; TUI:UpdateCustomGroups() end,
                        },
                    },
                },
                layoutTab = {
                    order = 15, type = "group", name = "Layout & Position",
                    args = {
                        matchAnchor = { order = 0.5, type = "toggle", width = 1.5,
                            name = "Match Anchored CDM Icons",
                            desc = "Copy icon size, spacing and scale from the CDM viewer this group is anchored to, pixel-perfectly.",
                            hidden = function()
                                local af = group.anchorFrame or ""
                                return not (af:find("^CDMTAIL_") or af:find("CooldownViewer$"))
                            end,
                            get = function() return group.matchAnchorIcons end,
                            set = function(_, v) gset("matchAnchorIcons", v) end },
                        iconWidth = { order = 1, type = "range", min = 8, max = 80, step = 0.01, bigStep = 1,
                            name = function() return (group.squareIcon ~= false) and "Icon Size" or "Icon Width" end,
                            disabled = function() return group.matchAnchorIcons end,
                            get = function() return group.iconWidth or group.iconSize or 36 end,
                            set = function(_, v) gset("iconWidth", v) end },
                        iconHeight = { order = 1.2, type = "range", name = "Icon Height", min = 8, max = 80, step = 0.01, bigStep = 1,
                            hidden = function() return group.squareIcon ~= false end,
                            disabled = function() return group.matchAnchorIcons end,
                            get = function() return group.iconHeight or group.iconWidth or group.iconSize or 36 end,
                            set = function(_, v) gset("iconHeight", v) end },
                        squareIcon = { order = 1.4, type = "toggle", name = "Square Icons", width = 1.2,
                            disabled = function() return group.matchAnchorIcons end,
                            get = function() return group.squareIcon ~= false end,
                            set = function(_, v) gset("squareIcon", v) end },
                        iconZoom = { order = 1.6, type = "range", name = "Icon Zoom",
                            min = 0, max = 0.3, step = 0.01, isPercent = true,
                            disabled = function() return group.matchAnchorIcons end,
                            get = function() return group.iconZoom or 0 end,
                            set = function(_, v) gset("iconZoom", v) end },
                        spacing = { order = 2, type = "range", name = "Spacing", min = -10, max = 10, step = 0.01, bigStep = 1,
                            disabled = function() return group.matchAnchorIcons end,
                            get = function() return (group.spacing or 2) - (ns.CDM_SPACING_INSET or 2) end,
                            set = function(_, v) gset("spacing", v + (ns.CDM_SPACING_INSET or 2)) end },
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
                                anchorXOffset = { order = 4, type = "range", name = "X Offset", min = -400, max = 400, step = 0.5, bigStep = 0.5,
                                    hidden = isUIParent, get = function() return group.anchorXOffset end, set = function(_, v) gset("anchorXOffset", v) end },
                                anchorYOffset = { order = 5, type = "range", name = "Y Offset", min = -400, max = 400, step = 0.5, bigStep = 0.5,
                                    hidden = isUIParent, get = function() return group.anchorYOffset end, set = function(_, v) gset("anchorYOffset", v) end },
                            },
                        },
                    },
                },
                textTab = {
                    order = 17, type = "group", name = "Text",
                    disabled = function() return group.matchAnchorIcons end,
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
