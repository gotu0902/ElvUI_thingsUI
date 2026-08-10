local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local SB = ns.SpecialBars

local NotifyChange = ns.NotifyChange

local DeepCopy = ns.DeepCopy
local function SpellLabel(spellID, fallback)
    if not spellID then return fallback or "?" end
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    local name = (info and info.name) or fallback or ("Spell "..tostring(spellID))
    local icon = info and info.iconID
    if icon then return ("|T%d:14:14|t %s"):format(icon, name) end
    return name
end

local function SpellName(spellID)
    local info = spellID and C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    return (info and info.name) or ("Spell " .. tostring(spellID or "?"))
end

ns.SB_OpenIconEditor = function(key)
    if E.ToggleOptions and key then E:ToggleOptions("thingsUI,modulesTab,specialIcons,iconsTab," .. key .. "Group") end
end
ns.SB_CloseIconEditor = function()
    if E.ToggleOptions then E:ToggleOptions("thingsUI,modulesTab,specialIcons,controlGroup") end
end

local function ComputeIconLayout()
    local dests, byKey = {}, {}
    local function bucket(key, name)
        local b = byKey[key]
        if not b then b = { key = key, name = name, icons = {} }; byKey[key] = b; dests[#dests + 1] = b end
        return b
    end
    local s = SB and SB.GetSpecRoot(SB.EditingSpec())
    local n = (s and s.iconCount) or 0
    for i = 1, n do
        local ikey = "icon" .. i
        local d = SB and SB.GetIconDB(ikey, SB.EditingSpec())
        if d and d.spellID then
            local gid = d.customGroup
            local g = gid and ns.CustomGroups and ns.CustomGroups.GroupByID and ns.CustomGroups.GroupByID(gid)
            local b = g and bucket("g" .. gid, g.name or ("Group " .. gid)) or bucket("standalone", "Standalone")
            b.icons[#b.icons + 1] = { key = ikey, name = SpellName(d.spellID) }
        elseif d then
            local b = bucket("unconfigured", "Unconfigured")
            b.icons[#b.icons + 1] = { key = ikey, name = ("Icon %d"):format(i) }
        end
    end
    local function rank(k) return (k == "standalone") and 0 or (k == "unconfigured") and 2 or 1 end
    table.sort(dests, function(a, b)
        if rank(a.key) ~= rank(b.key) then return rank(a.key) < rank(b.key) end
        return (a.name or ""):lower() < (b.name or ""):lower()
    end)
    for _, dest in ipairs(dests) do
        table.sort(dest.icons, function(x, y) return (x.name or ""):lower() < (y.name or ""):lower() end)
    end
    return dests
end

local function IconSlot(ikey)
    for di, dest in ipairs(ComputeIconLayout()) do
        for ii, ic in ipairs(dest.icons) do
            if ic.key == ikey then return di, ii end
        end
    end
end

local function CurrentSpecIDStr()
    local idx = GetSpecialization()
    if not idx then return "0" end
    local sid = select(1, GetSpecializationInfo(idx))
    return tostring(sid or 0)
end

local function BuildCopySpecsTree(kind, onlySpecStr, destSpecID)
    local db = E.db.thingsUI and E.db.thingsUI.specialBars
    if not db or not db.specs then return {} end
    local currentID
    if destSpecID then
        currentID = tostring(destSpecID)
    else
        local es = SB.EditingSpec()
        currentID = es and tostring(es) or CurrentSpecIDStr()
    end

    local classTree, lookup = ns.Cascade.BuildAllSpecsTree()
    for _, classEntry in ipairs(classTree) do
        local filteredSpecs = {}
        for _, specEntry in ipairs(classEntry.children) do
            local specIDStr = specEntry.id
            if specIDStr ~= currentID and (not onlySpecStr or specIDStr == onlySpecStr) then
                local specData = db.specs[specIDStr]
                if specData then
                    local slots = (kind == "bars") and specData.bars or specData.icons
                    local leaves = {}
                    if slots then
                        local prefix = (kind == "bars") and "bar" or "icon"
                        local n = (kind == "bars") and (specData.barCount or 3) or (specData.iconCount or 3)
                        for i = 1, n do
                            local slotKey = prefix .. i
                            local s = slots[slotKey]
                            if type(s) == "table" and s.spellID then
                                leaves[#leaves + 1] = {
                                    id    = specIDStr .. ":" .. slotKey,
                                    label = SpellLabel(s.spellID, s.spellName),
                                }
                            end
                        end
                    end
                    if #leaves > 0 then
                        -- "Copy all" leaf at the top.
                        local allLeaf = {
                            id    = specIDStr .. ":ALL",
                            label = ("|cFFFFD200[Copy all %s (%d)]|r"):format(kind, #leaves),
                        }
                        local outChildren = { allLeaf }
                        for _, l in ipairs(leaves) do outChildren[#outChildren+1] = l end
                        filteredSpecs[#filteredSpecs+1] = {
                            id       = specEntry.id,
                            label    = specEntry.label,
                            children = outChildren,
                        }
                    end
                end
            end
        end
        classEntry.children = filteredSpecs
    end

    -- Prune empty classes.
    local pruned = {}
    for _, ce in ipairs(classTree) do
        if #ce.children > 0 then pruned[#pruned+1] = ce end
    end
    return pruned, lookup
end

local function ApplyCopy(kind, leafID, mode, destSpecID)
    if not leafID then return end
    local specIDStr, what = leafID:match("^([^:]+):(.+)$")
    if not specIDStr or not what then return end
    local db = E.db.thingsUI and E.db.thingsUI.specialBars
    local src = db and db.specs and db.specs[specIDStr]
    if not src then return end
    local destID = destSpecID or SB.EditingSpec()
    local destIsCurrent = (destID == nil) or (tostring(destID) == CurrentSpecIDStr())
    local dest = SB.GetSpecRoot(destID)

    local slotsField  = (kind == "bars") and "bars"      or "icons"
    local countField  = (kind == "bars") and "barCount"  or "iconCount"
    local prefix      = (kind == "bars") and "bar"       or "icon"
    local release     = (kind == "bars") and SB.ReleaseBar or SB.ReleaseIcon
    if not destIsCurrent then release = nil end

    local srcSlots = src[slotsField] or {}
    local destSlots = dest[slotsField] or {}
    dest[slotsField] = destSlots

    local sources = {}
    if what == "ALL" then
        local n = src[countField] or 3
        for i = 1, n do
            local k = prefix .. i
            if type(srcSlots[k]) == "table" and srcSlots[k].spellID then
                sources[#sources+1] = { key = k, data = srcSlots[k] }
            end
        end
    else
        if type(srcSlots[what]) == "table" and srcSlots[what].spellID then
            sources[#sources+1] = { key = what, data = srcSlots[what] }
        end
    end
    if #sources == 0 then return end
    local written = {}

    if mode == "overwrite" then
        local needed = #sources
        if (dest[countField] or 0) < needed then dest[countField] = needed end
        for i = 1, dest[countField] do
            local k = prefix .. i
            if release then release(k) end
            destSlots[k] = nil
        end
        for i, entry in ipairs(sources) do
            local k = prefix .. i
            destSlots[k] = DeepCopy(entry.data)
            written[#written + 1] = k
        end
    else -- "add"

        local function isFree(k)
            local s = destSlots[k]
            return type(s) ~= "table" or not s.spellID
        end
        local insertedIDs = {}
        for k, s in pairs(destSlots) do
            if type(s) == "table" and s.spellID then insertedIDs[s.spellID] = true end
        end
        for _, entry in ipairs(sources) do
            -- Skip if the spell is already configured (no duplicates).
            if not insertedIDs[entry.data.spellID] then
                local slot
                for i = 1, dest[countField] do
                    if isFree(prefix..i) then slot = prefix..i; break end
                end
                if not slot then
                    dest[countField] = (dest[countField] or 0) + 1
                    slot = prefix .. dest[countField]
                end
                if release then release(slot) end
                destSlots[slot] = DeepCopy(entry.data)
                written[#written + 1] = slot
                insertedIDs[entry.data.spellID] = true
            end
        end
    end

    TUI:UpdateSpecialBars()
    NotifyChange()

    local def = SB.Styles and SB.Styles.GetDefault(kind)
    if def and #written > 0 then
        local dialog = StaticPopup_Show("TUI_COPY_APPLY_DEFAULT_STYLE", def, kind)
        if dialog then dialog.data = { kind = kind, name = def, slots = written, destID = destID } end
    end
end

StaticPopupDialogs["TUI_COPY_APPLY_DEFAULT_STYLE"] = {
    text = "Apply the default style '%s' to the copied %s?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        if not data then return end
        local getDB = (data.kind == "bars") and SB.GetBarDB or SB.GetIconDB
        for _, k in ipairs(data.slots) do
            local d = getDB(k, data.destID)
            if d then SB.Styles.ApplyToDB(data.kind, data.name, d) end
        end
        TUI:UpdateSpecialBars()
        NotifyChange()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["TUI_CASCADE_COPY_OVERWRITE_CONFIRM"] = {
    text = "This will DELETE your current %s on this spec and replace them. Continue?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        if not data then return end
        ApplyCopy(data.kind, data.leafID, "overwrite", data.destSpec)
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function ShowChoicePopup(kind, leafLabel, leafID, destSpec)
    local AceGUI = LibStub("AceGUI-3.0", true)
    if not AceGUI then return end
    local f = AceGUI:Create("Frame")
    f:SetTitle("Copy " .. kind)
    f:SetStatusText("")
    f:SetWidth(440)
    f:SetHeight(200)
    f:SetLayout("Flow")
    f:EnableResize(false)

    local lbl = AceGUI:Create("Label")
    lbl:SetText("\nCopying from:\n   " .. (leafLabel or leafID) .. "\n")
    lbl:SetFullWidth(true)
    lbl:SetFontObject(GameFontNormal)
    f:AddChild(lbl)

    local addBtn = AceGUI:Create("Button")
    addBtn:SetText("Add to existing")
    addBtn:SetRelativeWidth(0.33)
    addBtn:SetCallback("OnClick", function()
        ApplyCopy(kind, leafID, "add", destSpec)
        AceGUI:Release(f)
    end)
    f:AddChild(addBtn)

    local overBtn = AceGUI:Create("Button")
    overBtn:SetText("Overwrite current")
    overBtn:SetRelativeWidth(0.33)
    overBtn:SetCallback("OnClick", function()
        AceGUI:Release(f)
        local dialog = StaticPopup_Show("TUI_CASCADE_COPY_OVERWRITE_CONFIRM", kind)
        if dialog then dialog.data = { kind = kind, leafID = leafID, destSpec = destSpec } end
    end)
    f:AddChild(overBtn)

    local cancelBtn = AceGUI:Create("Button")
    cancelBtn:SetText(CANCEL)
    cancelBtn:SetRelativeWidth(0.33)
    cancelBtn:SetCallback("OnClick", function() AceGUI:Release(f) end)
    f:AddChild(cancelBtn)
end

local function OpenCopyPicker(kind, onlySpecStr, destSpec)
    if not ns.Cascade or not ns.Cascade.OpenSingle then
        E:Print("Cascade widget not loaded.")
        return
    end
    local tree = BuildCopySpecsTree(kind, onlySpecStr, destSpec)
    if #tree == 0 then
        E:Print(("No other specs have %s configured to copy from."):format(kind))
        return
    end
    ns.Cascade.OpenSingle({
        title = ("Copy %s from..."):format(kind:gsub("^%l", string.upper)),
        tree  = tree,
        width = 480, height = 560,
        onSelect = function(leafID, leaf)
            ShowChoicePopup(kind, leaf and leaf.label, leafID, destSpec)
        end,
    })
end

local function CurSpecNum()
    return tonumber(CurrentSpecIDStr())
end

local function SpecTag(specID)
    local m = specID and ns.SpecMeta and ns.SpecMeta(specID)
    if not m then return "?" end
    local icon = m.icon and ("|T" .. m.icon .. ":14:14|t ") or ""
    return icon .. (ns.ClassColor and ns.ClassColor(m.classToken) or "") .. (m.name or "?") .. "|r"
end

local function SpecialTabName(label, index, db)
    local name = db.spellName or ""
    if name == "" then return ("%s %d"):format(label, index) end
    local es = SB.EditingSpec and SB.EditingSpec()
    local cf
    if es then
        local m = ns.SpecMeta and ns.SpecMeta(es)
        cf = m and m.classToken
    end
    if not cf then local _, pcf = UnitClass("player"); cf = pcf end
    local col = (ns.ClassColor and ns.ClassColor(cf)) or "|cffffffff"
    local tex = db.spellID and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(db.spellID)
    local icon = tex and ("|T" .. tex .. ":14:14|t ") or ""
    local out = ("%s%s%s|r"):format(icon, col, name)
    if es then return out end
    local inCDM = db.spellID and SB.GetRawSpellList and SB.GetRawSpellList()[db.spellID]
    if not inCDM then return "|cFFFF4444!|r " .. out end
    return out
end

local function BarTabName(barKey, index)
    if not SB then return ("Bar %d"):format(index) end
    return SpecialTabName("Bar", index, SB.GetBarDB(barKey, SB.EditingSpec()) or {})
end

local function IconTabName(iconKey, index)
    if not SB then return ("Icon %d"):format(index) end
    return SpecialTabName("Icon", index, SB.GetIconDB(iconKey, SB.EditingSpec()) or {})
end

local function BuildIconTreeArgs()
    local box = {}
    for k = 1, 13 do
        local kk = k
        box["h" .. kk] = {
            type = "group", disabled = true, order = kk * 1000, args = {},
            name   = function() local d = ComputeIconLayout()[kk]; return d and d.name or "" end,
            hidden = function() return not ComputeIconLayout()[kk] end,
        }
    end
    for i = 1, 12 do
        local ikey, idx = "icon" .. i, i
        box[ikey .. "Group"] = {
            type = "group", childGroups = "tab",
            order  = function() local di, ii = IconSlot(ikey); return (di and ii) and (di * 1000 + ii * 10) or 99999 end,
            name   = function() return IconTabName(ikey, idx) end,
            hidden = function() return IconSlot(ikey) == nil end,
            args   = TUI:SpecialIconOptions(ikey),
        }
    end
    return box
end

local selectedStyle = { bars = "Global", icons = "Global" }

ns.SB_OpenStyleTab = function(kind, styleName)
    if styleName then selectedStyle[kind] = styleName end
    local module = (kind == "bars") and "specialBars" or "specialIcons"
    if E.ToggleOptions then E:ToggleOptions("thingsUI,modulesTab," .. module .. ",stylesTab") end
end

local function SpecialCopyEntries(kind, styleName)
    local vals, list = {}, {}
    local sbdb = E.db.thingsUI and E.db.thingsUI.specialBars
    local specs = sbdb and sbdb.specs or {}
    local field = (kind == "bars") and "bars" or "icons"
    for specKey, s in pairs(specs) do
        local m = ns.SpecMeta and ns.SpecMeta(tonumber(specKey))
        local specLabel = m and ((m.icon and ("|T" .. m.icon .. ":14:14|t ") or "") .. (m.name or specKey)) or ("Spec " .. specKey)
        for slotKey, d in pairs(s[field] or {}) do
            if type(d) == "table" and d.spellID then
                local key = specKey .. "|" .. slotKey
                local base = specLabel .. ": " .. SpellLabel(d.spellID, d.spellName)
                local rank, label
                if styleName and d.styleName == styleName then
                    if SB.Styles.IsDirty(kind, styleName, d) then
                        rank, label = 1, base .. " |cFFFFD200(Using this, but different settings)|r"
                    else
                        rank, label = 2, base .. " |cFF40FF40(Using this)|r"
                    end
                elseif d.styleName then
                    rank, label = 3, base .. " |cFF" .. SB.Styles.ColorHex(d.styleName) .. "[" .. d.styleName .. "]|r"
                else
                    rank, label = 4, "|cFF999999" .. base .. " (no style)|r"
                end
                vals[key] = label
                list[#list + 1] = { key = key, rank = rank, label = label }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.label < b.label
    end)
    local sorting = {}
    for _, e in ipairs(list) do sorting[#sorting + 1] = e.key end
    return vals, sorting
end

local function BuildStylesTab(kind)
    local noun = (kind == "bars") and "Bar" or "Icon"
    local function sel() return selectedStyle[kind] end
    local manage = {
        pick = {
            order = 1, type = "select", name = "Style", width = 1.2,
            values = function() return SB.Styles.DropdownValues(kind) end,
            sorting = function() return SB.Styles.DropdownSorting(kind) end,
            get = sel,
            set = function(_, v) selectedStyle[kind] = v; NotifyChange() end,
        },
        usage = {
            order = 1.5, type = "description", fontSize = "medium",
            name = function()
                local n = 0
                SB.Styles.EachSpecial(kind, function(d) if d.styleName == sel() then n = n + 1 end end)
                return ("|cFF888888Used by %d special %s(s) across all specs. Assign styles on each %s's own page.|r")
                    :format(n, noun:lower(), noun:lower())
            end,
        },
        newStyle = {
            order = 2, type = "input", name = "Create New Style (name)",
            get = function() return "" end,
            set = function(_, v)
                v = (v or ""):match("^%s*(.-)%s*$")
                if v == "" then return end
                local root = SB.Styles.Root(kind)
                if root[v] then E:Print("A style with that name already exists.") return end
                root[v] = SB.Styles.Capture(kind, (kind == "bars") and ns.SPECIAL_BAR_DEFAULTS or ns.SPECIAL_ICON_DEFAULTS)
                selectedStyle[kind] = v
                NotifyChange()
            end,
        },
        rename = {
            order = 3, type = "input", name = "Rename Style",
            disabled = function() return sel() == "Global" end,
            get = function() return "" end,
            set = function(_, v)
                v = (v or ""):match("^%s*(.-)%s*$")
                if SB.Styles.Rename(kind, sel(), v) then
                    selectedStyle[kind] = v
                    NotifyChange()
                end
            end,
        },
        delete = {
            order = 4, type = "execute", name = "Delete Style",
            disabled = function() return sel() == "Global" end,
            confirm = function()
                return ("Delete style '%s'? Specials keep their current look but lose the style link."):format(sel() or "?")
            end,
            func = function()
                if SB.Styles.Delete(kind, sel()) then
                    selectedStyle[kind] = "Global"
                    NotifyChange()
                end
            end,
        },
        setDefault = {
            order = 4.5, type = "execute",
            name = function()
                if SB.Styles.EffectiveDefault(kind) == sel() then return "|cFF40FF40Default for new " .. noun:lower() .. "s|r" end
                return "Set as Default"
            end,
            desc = "New " .. noun:lower() .. "s start with the default style. Global is the default until you set another.",
            disabled = function() return SB.Styles.EffectiveDefault(kind) == sel() end,
            func = function() SB.Styles.SetDefault(kind, sel()); NotifyChange() end,
        },
        copyHeader = {
            order = 10, type = "description", width = "full", fontSize = "medium",
            name = function() return ("\n|cFFFFD200Overwrite|r %s |cFFFFD200from...|r"):format(SB.Styles.ColoredName(sel())) end,
        },
        copyFromStyle = {
            order = 11, type = "select", name = "...Another Style", width = "double",
            values = function()
                local t = {}
                for _, n in ipairs(SB.Styles.Names(kind)) do
                    if n ~= sel() then t[n] = SB.Styles.ColoredName(n) end
                end
                return t
            end,
            confirm = function(_, v)
                return ("Overwrite style '%s' with '%s'? Every special using '%s' follows."):format(sel() or "?", v, sel() or "?")
            end,
            get = function() return "" end,
            set = function(_, v)
                local src = SB.Styles.Get(kind, v)
                if src then
                    SB.Styles.Root(kind)[sel()] = DeepCopy(src)
                    SB.Styles.ApplyToUsers(kind, sel())
                    TUI:UpdateSpecialBars()
                    NotifyChange()
                end
            end,
        },
        copyFromSpecial = {
            order = 12, type = "select", name = ("...A Special %s's Settings"):format(noun), width = "double",
            values = function() return (SpecialCopyEntries(kind, sel())) end,
            sorting = function() return select(2, SpecialCopyEntries(kind, sel())) end,
            confirm = function()
                return ("This will overwrite style '%s' and every special using it. If you're updating the style for all your specs' %ss, you're in the right place. Full send it?"):format(sel() or "?", noun:lower())
            end,
            get = function() return "" end,
            set = function(_, v)
                local specKey, slotKey = v:match("^(%d+)|(.+)$")
                if not specKey then return end
                local d = (kind == "bars") and SB.GetBarDB(slotKey, tonumber(specKey))
                    or SB.GetIconDB(slotKey, tonumber(specKey))
                if d then
                    SB.Styles.Root(kind)[sel()] = SB.Styles.Capture(kind, d)
                    SB.Styles.ApplyToUsers(kind, sel())
                    TUI:UpdateSpecialBars()
                    NotifyChange()
                end
            end,
        },
    }

    local editor = (kind == "bars")
        and TUI:SpecialBarOptions(nil, { styleName = sel })
        or  TUI:SpecialIconOptions(nil, { styleName = sel })
    local layoutG = editor.layoutGroup or editor.appearGroup
    local textG = editor.textGroup

    local args = {
        manageBox = { order = 1, type = "group", name = "Style", inline = true, args = manage },
        spacer = { order = 5, type = "description", width = "full", fontSize = "large", name = " " },
    }
    for k, g in pairs(layoutG.args) do g.order = (g.order or 0) + 10; args[k] = g end
    for k, g in pairs(textG.args) do g.order = (g.order or 0) + 100; args[k] = g end

    return { order = 20, type = "group", name = "Styles", args = args }
end

local function BuildSpecialBarsGroup()
    return {
        order = 1,
        type = "group",
        name = "Special Bars",
        childGroups = "tab",
        args = {
            addBarForEdited = {
                order = 0.5, type = "execute", width = "double",
                hidden = function() return not (SB and SB.EditingSpec()) end,
                name = function() return "|cFF40FF40+ New Special Bar for |r" .. SpecTag(SB.EditingSpec()) end,
                disabled = function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).barCount or 3) >= 12 end,
                func = function()
                    local s = SB.GetSpecRoot(SB.EditingSpec()); local c = s.barCount or 3
                    if c < 12 then
                        s.barCount = c + 1
                        SB.Styles.ApplyToDB("bars", SB.Styles.EffectiveDefault("bars"), SB.GetBarDB("bar" .. (c + 1), SB.EditingSpec()))
                        TUI:UpdateSpecialBars(); NotifyChange()
                    end
                end,
            },
            addBar = {
                order = 1, type = "execute", width = "double",
                name = function() return "|cFF40FF40+ New Special Bar for |r" .. SpecTag(CurSpecNum()) end,
                disabled = function() return not SB or (SB.GetSpecRoot().barCount or 3) >= 12 end,
                func = function()
                    if not SB then return end
                    local s = SB.GetSpecRoot(); local c = s.barCount or 3
                    if c < 12 then
                        s.barCount = c + 1
                        SB.Styles.ApplyToDB("bars", SB.Styles.EffectiveDefault("bars"), SB.GetBarDB("bar" .. (c + 1)))
                        TUI:UpdateSpecialBars(); NotifyChange()
                    end
                end,
            },
            copyRow = ns.OptionLinkRowDynamic(2, function()
                local links = {
                    { label = "Copy Bars:  ", color = { 1, 0.82, 0 } },
                    { label = "From Another Spec...", color = { 0.54, 0.78, 1 },
                      onClick = function() OpenCopyPicker("bars") end },
                }
                if SB and SB.EditingSpec() then
                    local es = SB.EditingSpec()
                    links[#links + 1] = { label = "From " .. SpecTag(es) .. " to " .. SpecTag(CurSpecNum()) .. "...", color = { 0.54, 0.78, 1 },
                        onClick = function() OpenCopyPicker("bars", tostring(es), CurSpecNum()) end }
                    links[#links + 1] = { label = "ALL from " .. SpecTag(es), color = { 0.54, 0.78, 1 },
                        onClick = function() ShowChoicePopup("bars", SpecTag(es) .. " - all bars", tostring(es) .. ":ALL", CurSpecNum()) end }
                end
                return links
            end),
            barCountHint = {
                order = 3, type = "description", fontSize = "medium",
                name = function() return ("|cFF888888%d / 12 bars - delete a bar from its own page.|r"):format((SB and SB.GetSpecRoot(SB.EditingSpec()).barCount) or 3) end,
            },
            barsTab = {
                order = 10, type = "group", name = "Bars", childGroups = "tree",
                args = {
                    bar1Group  = { order=10,  type="group", childGroups="tab", name=function() return BarTabName("bar1",1)   end, hidden=function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).barCount or 3) < 1  end, args=TUI:SpecialBarOptions("bar1")  },
                    bar2Group  = { order=20,  type="group", childGroups="tab", name=function() return BarTabName("bar2",2)   end, hidden=function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).barCount or 3) < 2  end, args=TUI:SpecialBarOptions("bar2")  },
                    bar3Group  = { order=30,  type="group", childGroups="tab", name=function() return BarTabName("bar3",3)   end, hidden=function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).barCount or 3) < 3  end, args=TUI:SpecialBarOptions("bar3")  },
                    bar4Group  = { order=40,  type="group", childGroups="tab", name=function() return BarTabName("bar4",4)   end, hidden=function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).barCount or 3) < 4  end, args=TUI:SpecialBarOptions("bar4")  },
                    bar5Group  = { order=50,  type="group", childGroups="tab", name=function() return BarTabName("bar5",5)   end, hidden=function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).barCount or 3) < 5  end, args=TUI:SpecialBarOptions("bar5")  },
                    bar6Group  = { order=60,  type="group", childGroups="tab", name=function() return BarTabName("bar6",6)   end, hidden=function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).barCount or 3) < 6  end, args=TUI:SpecialBarOptions("bar6")  },
                    bar7Group  = { order=70,  type="group", childGroups="tab", name=function() return BarTabName("bar7",7)   end, hidden=function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).barCount or 3) < 7  end, args=TUI:SpecialBarOptions("bar7")  },
                    bar8Group  = { order=80,  type="group", childGroups="tab", name=function() return BarTabName("bar8",8)   end, hidden=function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).barCount or 3) < 8  end, args=TUI:SpecialBarOptions("bar8")  },
                    bar9Group  = { order=90,  type="group", childGroups="tab", name=function() return BarTabName("bar9",9)   end, hidden=function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).barCount or 3) < 9  end, args=TUI:SpecialBarOptions("bar9")  },
                    bar10Group = { order=100, type="group", childGroups="tab", name=function() return BarTabName("bar10",10) end, hidden=function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).barCount or 3) < 10 end, args=TUI:SpecialBarOptions("bar10") },
                    bar11Group = { order=110, type="group", childGroups="tab", name=function() return BarTabName("bar11",11) end, hidden=function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).barCount or 3) < 11 end, args=TUI:SpecialBarOptions("bar11") },
                    bar12Group = { order=120, type="group", childGroups="tab", name=function() return BarTabName("bar12",12) end, hidden=function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).barCount or 3) < 12 end, args=TUI:SpecialBarOptions("bar12") },
                },
            },
            stylesTab = BuildStylesTab("bars"),
        },
    }
end

local AURA_KIND = { HELPFUL = "Buff", HARMFUL = "Debuff" }
local AURA_UNITS = { player = "Player", target = "Target", focus = "Focus", pet = "Pet" }
local AURA_SORT = { instance = "Applied", short = "Shortest First", long = "Longest First" }

local function GlobalIconArgs(iconID)
    local AL = ns.AuraLane
    local function I() return AL.GlobalIconByID(iconID) end
    local args = {
        gname = {
            order = 1, type = "input", name = "Name",
            get = function() local i = I(); return i and i.name or "" end,
            set = function(_, v)
                local i = I()
                if i and v ~= "" then i.name = v; NotifyChange() end
            end,
        },
        genable = {
            order = 2, type = "toggle", name = "Enable", width = "half",
            get = function() local i = I(); return i and i.enabled ~= false end,
            set = function(_, v)
                local i = I(); if i then i.enabled = v end
                TUI:UpdateCustomGroups(); NotifyChange()
            end,
        },
        gup = {
            order = 3, type = "execute", name = "^", width = 0.3,
            func = function() AL.MoveGlobalIcon(iconID, -1); TUI:UpdateCustomGroups(); NotifyChange() end,
        },
        gdown = {
            order = 4, type = "execute", name = "v", width = 0.3,
            func = function() AL.MoveGlobalIcon(iconID, 1); TUI:UpdateCustomGroups(); NotifyChange() end,
        },
        gdel = {
            order = 5, type = "execute", name = "Delete", confirm = true,
            confirmText = "Delete this global icon?",
            func = function()
                AL.RemoveGlobalIcon(iconID)
                TUI:UpdateCustomGroups(); NotifyChange()
            end,
        },
        ggroup = {
            order = 6, type = "select", name = "Custom Group",
            values = function()
                local out = { [0] = "|cff888888Not Shown|r" }
                for _, g in ipairs((ns.CustomGroups and ns.CustomGroups.GetGroups()) or {}) do
                    out[g.id] = g.name or ("Group " .. g.id)
                end
                return out
            end,
            get = function() local i = I(); return (i and i.group) or 0 end,
            set = function(_, v)
                local i = I(); if i then i.group = (v ~= 0) and v or nil end
                TUI:UpdateCustomGroups(); NotifyChange()
            end,
        },
        gkind = {
            order = 7, type = "select", name = "Type", values = AURA_KIND,
            sorting = { "HELPFUL", "HARMFUL" },
            get = function() local i = I(); return i and i.kind or "HELPFUL" end,
            set = function(_, v) local i = I(); if i then i.kind = v end; TUI:UpdateCustomGroups() end,
        },
        gunit = {
            order = 8, type = "select", name = "Unit", values = AURA_UNITS,
            sorting = { "player", "target", "focus", "pet" },
            get = function() local i = I(); return i and i.unit or "player" end,
            set = function(_, v) local i = I(); if i then i.unit = v end; TUI:UpdateCustomGroups() end,
        },
        gonlyMine = {
            order = 9, type = "toggle", name = "Only Mine",
            get = function() local i = I(); return i and i.onlyMine end,
            set = function(_, v) local i = I(); if i then i.onlyMine = v end; TUI:UpdateCustomGroups() end,
        },
        gmax = {
            order = 10, type = "range", name = "Max Icons", min = 1, max = 10, step = 1,
            get = function() local i = I(); return i and i.max or 1 end,
            set = function(_, v) local i = I(); if i then i.max = v end; TUI:UpdateCustomGroups() end,
        },
        gsort = {
            order = 11, type = "select", name = "Sort", values = AURA_SORT,
            sorting = { "instance", "short", "long" },
            get = function() local i = I(); return i and i.sort or "instance" end,
            set = function(_, v) local i = I(); if i then i.sort = v end; TUI:UpdateCustomGroups() end,
        },
        casterBox = {
            order = 20, type = "group", inline = true, name = "Caster Name",
            args = {
                note = {
                    order = 0, type = "description",
                    hidden = function()
                        local AL = ns.AuraLane
                        return not (AL.SourceProbed() and not AL.CanShowSource())
                    end,
                    name = "|cff888888Caster names arrive with Blizzard patch 12.1.5 - settings here apply automatically once it ships.|r\n",
                },
                show = {
                    order = 1, type = "toggle", name = "Show",
                    get = function() local i = I(); return i and i.showSource end,
                    set = function(_, v) local i = I(); if i then i.showSource = v end; TUI:UpdateCustomGroups() end,
                },
                short = {
                    order = 2, type = "toggle", name = "Shorten",
                    disabled = function() local i = I(); return not (i and i.showSource) end,
                    get = function() local i = I(); return i and i.sourceShortened ~= false end,
                    set = function(_, v) local i = I(); if i then i.sourceShortened = v end; TUI:UpdateCustomGroups() end,
                },
                point = {
                    order = 3, type = "select", name = "Point",
                    values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                    disabled = function() local i = I(); return not (i and i.showSource) end,
                    get = function() local i = I(); return i and i.sourcePoint or "TOP" end,
                    set = function(_, v) local i = I(); if i then i.sourcePoint = v end; TUI:UpdateCustomGroups() end,
                },
                size = {
                    order = 4, type = "range", name = "Size", min = 6, max = 32, step = 1,
                    disabled = function() local i = I(); return not (i and i.showSource) end,
                    get = function() local i = I(); return i and i.sourceFontSize or 12 end,
                    set = function(_, v) local i = I(); if i then i.sourceFontSize = v end; TUI:UpdateCustomGroups() end,
                },
                x = {
                    order = 5, type = "range", name = "X", min = -60, max = 60, step = 1,
                    disabled = function() local i = I(); return not (i and i.showSource) end,
                    get = function() local i = I(); return i and i.sourceXOffset or 0 end,
                    set = function(_, v) local i = I(); if i then i.sourceXOffset = v end; TUI:UpdateCustomGroups() end,
                },
                y = {
                    order = 6, type = "range", name = "Y", min = -60, max = 60, step = 1,
                    disabled = function() local i = I(); return not (i and i.showSource) end,
                    get = function() local i = I(); return i and i.sourceYOffset or 10 end,
                    set = function(_, v) local i = I(); if i then i.sourceYOffset = v end; TUI:UpdateCustomGroups() end,
                },
                colour = {
                    order = 7, type = "color", name = "Color",
                    disabled = function() local i = I(); return not (i and i.showSource) end,
                    get = function()
                        local i = I(); local c = (i and i.sourceColor) or {}
                        return c.r or 1, c.g or 1, c.b or 1
                    end,
                    set = function(_, r, g, b)
                        local i = I(); if i then i.sourceColor = { r = r, g = g, b = b } end
                        TUI:UpdateCustomGroups()
                    end,
                },
            },
        },
        spellBox = {
            order = 30, type = "group", inline = true, name = "Tracked Spells",
            args = {},
        },
    }

    local icon = AL.GlobalIconByID(iconID)
    args.spellBox.args.add = {
        order = 1, type = "input", name = "Add Spell", width = "double",
        get = function() return "" end,
        set = function(_, v)
            local i = I(); if not i then return end
            local id = tonumber(v)
            if not id then
                local info = C_Spell.GetSpellInfo(v)
                id = info and info.spellID
            end
            if not (id and C_Spell.GetSpellInfo(id)) then return end
            i.spells = i.spells or {}
            i.spells[id] = true
            TUI:UpdateCustomGroups(); NotifyChange()
        end,
    }
    for ri, spellID in ipairs(AL.SpellList(icon)) do
        local sid = spellID
        local info = C_Spell.GetSpellInfo(sid)
        args.spellBox.args["sp" .. sid] = {
            order = 10 + ri, type = "group", inline = true, name = "",
            args = {
                pic = {
                    order = 1, type = "description", width = 0.3, name = "",
                    image = info and info.iconID, imageWidth = 22, imageHeight = 22,
                },
                label = {
                    order = 2, type = "description", width = 1.8, fontSize = "medium",
                    name = (info and info.name or "?") .. "  |cff888888" .. sid .. "|r",
                },
                del = {
                    order = 3, type = "execute", name = "Remove", width = 0.7,
                    func = function()
                        local i = I()
                        if i and i.spells then i.spells[sid] = nil end
                        TUI:UpdateCustomGroups(); NotifyChange()
                    end,
                },
            },
        }
    end
    return args
end

local function BuildGlobalIconsTab()
    local AL = ns.AuraLane
    local args = {
        desc = {
            order = 1, type = "description",
            name = "Aura icons defined once for every character and spec, then assigned to a Custom Group.\n|cff888888They draw at the end of the group and inherit its icon size, spacing, growth, font and border.|r\n",
        },
        newIcon = {
            order = 2, type = "execute", name = "|cFF40FF40+ New Global Icon|r", width = "double",
            func = function() AL.NewGlobalIcon(); TUI:UpdateCustomGroups(); NotifyChange() end,
        },
        presets = {
            order = 3, type = "group", inline = true, name = "Ready-Made",
            args = {},
        },
    }
    for pi, preset in ipairs(ns.AURA_PRESETS or {}) do
        local pkey, pname = preset.key, preset.name
        args.presets.args[pkey] = {
            order = pi, type = "execute", name = pname, width = 1.1,
            func = function() AL.AddPreset(pkey, nil); TUI:UpdateCustomGroups(); NotifyChange() end,
        }
    end

    local lib = AL and AL.Library()
    local sorted = {}
    for _, icon in ipairs((lib and lib.icons) or {}) do sorted[#sorted + 1] = icon end
    table.sort(sorted, function(x, y) return (x.order or 100) < (y.order or 100) end)
    for si, icon in ipairs(sorted) do
        local iid = icon.id
        args["gi" .. iid] = {
            order = 10 + si, type = "group",
            name = (icon.enabled ~= false) and (icon.name or ("Icon " .. iid))
                or ("|cFF888888" .. (icon.name or ("Icon " .. iid)) .. "|r"),
            args = GlobalIconArgs(iid),
        }
    end
    if #sorted == 0 then
        args.none = {
            order = 5, type = "description",
            name = "|cff888888Nothing yet. Add a ready-made icon above, or start a blank one.|r",
        }
    end

    return { order = 30, type = "group", childGroups = "tab", name = "Global Icons", args = args }
end

local function BuildSpecialIconsGroup()
    return {
        order = 2,
        type = "group",
        name = "Special Icons",
        childGroups = "tab",
        args = {
            addIconForEdited = {
                order = 0.5, type = "execute", width = "double",
                hidden = function() return not (SB and SB.EditingSpec()) end,
                name = function() return "|cFF40FF40+ New Special Icon for |r" .. SpecTag(SB.EditingSpec()) end,
                disabled = function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).iconCount or 3) >= 12 end,
                func = function()
                    local s = SB.GetSpecRoot(SB.EditingSpec()); local c = s.iconCount or 3
                    if c < 12 then
                        s.iconCount = c + 1
                        SB.Styles.ApplyToDB("icons", SB.Styles.EffectiveDefault("icons"), SB.GetIconDB("icon" .. (c + 1), SB.EditingSpec()))
                        TUI:UpdateSpecialBars(); NotifyChange()
                        if ns.SB_OpenIconEditor then ns.SB_OpenIconEditor("icon" .. (c + 1)) end
                    end
                end,
            },
            addIcon = {
                order = 1, type = "execute", width = "double",
                name = function() return "|cFF40FF40+ New Special Icon for |r" .. SpecTag(CurSpecNum()) end,
                disabled = function() return not SB or (SB.GetSpecRoot().iconCount or 3) >= 12 end,
                func = function()
                    if not SB then return end
                    local s = SB.GetSpecRoot(); local c = s.iconCount or 3
                    if c < 12 then
                        s.iconCount = c + 1
                        SB.Styles.ApplyToDB("icons", SB.Styles.EffectiveDefault("icons"), SB.GetIconDB("icon" .. (c + 1)))
                        TUI:UpdateSpecialBars(); NotifyChange()
                        if not SB.EditingSpec() and ns.SB_OpenIconEditor then ns.SB_OpenIconEditor("icon" .. (c + 1)) end
                    end
                end,
            },
            copyRow = ns.OptionLinkRowDynamic(2, function()
                local links = {
                    { label = "Copy Icons:  ", color = { 1, 0.82, 0 } },
                    { label = "From Another Spec...", color = { 0.54, 0.78, 1 },
                      onClick = function() OpenCopyPicker("icons") end },
                }
                if SB and SB.EditingSpec() then
                    local es = SB.EditingSpec()
                    links[#links + 1] = { label = "From " .. SpecTag(es) .. " to " .. SpecTag(CurSpecNum()) .. "...", color = { 0.54, 0.78, 1 },
                        onClick = function() OpenCopyPicker("icons", tostring(es), CurSpecNum()) end }
                    links[#links + 1] = { label = "ALL from " .. SpecTag(es), color = { 0.54, 0.78, 1 },
                        onClick = function() ShowChoicePopup("icons", SpecTag(es) .. " - all icons", tostring(es) .. ":ALL", CurSpecNum()) end }
                end
                return links
            end),
            iconCountHint = {
                order = 3, type = "description", fontSize = "medium",
                name = function() return ("|cFF888888%d / 12 icons - delete an icon from its own page.|r"):format((SB and SB.GetSpecRoot(SB.EditingSpec()).iconCount) or 3) end,
            },
            iconsTab = {
                order = 10, type = "group", name = "Icons", childGroups = "tree",
                args = BuildIconTreeArgs(),
            },
            stylesTab = BuildStylesTab("icons"),
            globalIconsTab = BuildGlobalIconsTab(),
        },
    }
end

function TUI:CDMSpecialsOptions()
    return {
        order = 50,
        type = "group",
        name = "CDM Specials",
        childGroups = "tab",
        args = {
            specialBarsTab  = BuildSpecialBarsGroup(),
            specialIconsTab = BuildSpecialIconsGroup(),
        },
    }
end

function TUI:SpecialBarsOptions()
    return BuildSpecialBarsGroup()
end
function TUI:SpecialIconsOptions()
    return BuildSpecialIconsGroup()
end
