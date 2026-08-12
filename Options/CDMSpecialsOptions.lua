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
    else

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
    ns.SolidDialog(f)
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

local barPages, iconPages

local function MaxCountOver(field)
    local m = 3
    local sb = E.db.thingsUI and E.db.thingsUI.specialBars
    for _, s in pairs((sb and sb.specs) or {}) do
        local c = s[field] or 3
        if c > m then m = c end
    end
    local cap = (SB and SB.MAX_SLOTS) or 12
    if m > cap then m = cap end
    return m
end

local function RebuildBarPages()
    if not barPages then return end
    for k in pairs(barPages) do
        if k:match("^bar%d+Group$") then barPages[k] = nil end
    end
    for i = 1, MaxCountOver("barCount") do
        local key = "bar" .. i
        local n = i
        barPages[key .. "Group"] = {
            order = i * 10, type = "group", childGroups = "tab",
            name = function() return BarTabName(key, n) end,
            hidden = function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).barCount or 3) < n end,
            args = TUI:SpecialBarOptions(key),
        }
    end
end

local function RebuildIconPages()
    if not iconPages then return end
    for k in pairs(iconPages) do
        if k:match("^icon%d+Group$") then iconPages[k] = nil end
    end
    for i = 1, MaxCountOver("iconCount") do
        local ikey, idx = "icon" .. i, i
        iconPages[ikey .. "Group"] = {
            type = "group", childGroups = "tab",
            order  = function() local di, ii = IconSlot(ikey); return (di and ii) and (di * 1000 + ii * 10) or 99999 end,
            name   = function() return IconTabName(ikey, idx) end,
            hidden = function() return IconSlot(ikey) == nil end,
            args   = TUI:SpecialIconOptions(ikey),
        }
    end
end

ns.SB_RebuildSlotPages = function()
    RebuildBarPages()
    RebuildIconPages()
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
    iconPages = box
    RebuildIconPages()
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
        useRow = ns.SB_StyleUseRow and ns.SB_StyleUseRow(kind, sel, 6) or nil,
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
                disabled = function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).barCount or 3) >= (SB.MAX_SLOTS or 12) end,
                func = function()
                    local s = SB.GetSpecRoot(SB.EditingSpec()); local c = s.barCount or 3
                    if c < (SB.MAX_SLOTS or 12) then
                        s.barCount = c + 1
                        SB.Styles.ApplyToDB("bars", SB.Styles.EffectiveDefault("bars"), SB.GetBarDB("bar" .. (c + 1), SB.EditingSpec()))
                        if ns.SB_RebuildSlotPages then ns.SB_RebuildSlotPages() end; TUI:UpdateSpecialBars(); NotifyChange()
                    end
                end,
            },
            addBar = {
                order = 1, type = "execute", width = "double",
                name = function() return "|cFF40FF40+ New Special Bar for |r" .. SpecTag(CurSpecNum()) end,
                disabled = function() return not SB or (SB.GetSpecRoot().barCount or 3) >= (SB.MAX_SLOTS or 12) end,
                func = function()
                    if not SB then return end
                    local s = SB.GetSpecRoot(); local c = s.barCount or 3
                    if c < (SB.MAX_SLOTS or 12) then
                        s.barCount = c + 1
                        SB.Styles.ApplyToDB("bars", SB.Styles.EffectiveDefault("bars"), SB.GetBarDB("bar" .. (c + 1)))
                        if ns.SB_RebuildSlotPages then ns.SB_RebuildSlotPages() end; TUI:UpdateSpecialBars(); NotifyChange()
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
                name = function() return ("|cFF888888%d / %d bars - delete a bar from its own page.|r"):format((SB and SB.GetSpecRoot(SB.EditingSpec()).barCount) or 3, (SB and SB.MAX_SLOTS) or 12) end,
            },
            barsTab = {
                order = 10, type = "group", name = "Bars", childGroups = "tree",
                args = (function()
                    barPages = {}
                    RebuildBarPages()
                    return barPages
                end)(),
            },
            stylesTab = BuildStylesTab("bars"),
        },
    }
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
                disabled = function() return not SB or (SB.GetSpecRoot(SB.EditingSpec()).iconCount or 3) >= (SB.MAX_SLOTS or 12) end,
                func = function()
                    local s = SB.GetSpecRoot(SB.EditingSpec()); local c = s.iconCount or 3
                    if c < (SB.MAX_SLOTS or 12) then
                        s.iconCount = c + 1
                        SB.Styles.ApplyToDB("icons", SB.Styles.EffectiveDefault("icons"), SB.GetIconDB("icon" .. (c + 1), SB.EditingSpec()))
                        if ns.SB_RebuildSlotPages then ns.SB_RebuildSlotPages() end; TUI:UpdateSpecialBars(); NotifyChange()
                        if ns.SB_OpenIconEditor then ns.SB_OpenIconEditor("icon" .. (c + 1)) end
                    end
                end,
            },
            addIcon = {
                order = 1, type = "execute", width = "double",
                name = function() return "|cFF40FF40+ New Special Icon for |r" .. SpecTag(CurSpecNum()) end,
                disabled = function() return not SB or (SB.GetSpecRoot().iconCount or 3) >= (SB.MAX_SLOTS or 12) end,
                func = function()
                    if not SB then return end
                    local s = SB.GetSpecRoot(); local c = s.iconCount or 3
                    if c < (SB.MAX_SLOTS or 12) then
                        s.iconCount = c + 1
                        SB.Styles.ApplyToDB("icons", SB.Styles.EffectiveDefault("icons"), SB.GetIconDB("icon" .. (c + 1)))
                        if ns.SB_RebuildSlotPages then ns.SB_RebuildSlotPages() end; TUI:UpdateSpecialBars(); NotifyChange()
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
                name = function() return ("|cFF888888%d / %d icons - delete an icon from its own page.|r"):format((SB and SB.GetSpecRoot(SB.EditingSpec()).iconCount) or 3, (SB and SB.MAX_SLOTS) or 12) end,
            },
            iconsTab = {
                order = 10, type = "group", name = "Icons", childGroups = "tree",
                args = BuildIconTreeArgs(),
            },
            stylesTab = BuildStylesTab("icons"),
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
