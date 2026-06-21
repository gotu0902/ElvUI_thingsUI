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
    local s = SB and SB.GetSpecRoot()
    local n = (s and s.iconCount) or 0
    for i = 1, n do
        local ikey = "icon" .. i
        local d = SB and SB.GetIconDB(ikey)
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

local function BuildCopySpecsTree(kind)
    local db = E.db.thingsUI and E.db.thingsUI.specialBars
    if not db or not db.specs then return {} end
    local currentID = CurrentSpecIDStr()

    local classTree, lookup = ns.Cascade.BuildAllSpecsTree()
    for _, classEntry in ipairs(classTree) do
        local filteredSpecs = {}
        for _, specEntry in ipairs(classEntry.children) do
            local specIDStr = specEntry.id
            if specIDStr ~= currentID then
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

local function ApplyCopy(kind, leafID, mode)
    if not leafID then return end
    local specIDStr, what = leafID:match("^([^:]+):(.+)$")
    if not specIDStr or not what then return end
    local db = E.db.thingsUI and E.db.thingsUI.specialBars
    local src = db and db.specs and db.specs[specIDStr]
    if not src then return end
    local dest = SB.GetSpecRoot()

    local slotsField  = (kind == "bars") and "bars"      or "icons"
    local countField  = (kind == "bars") and "barCount"  or "iconCount"
    local prefix      = (kind == "bars") and "bar"       or "icon"
    local release     = (kind == "bars") and SB.ReleaseBar or SB.ReleaseIcon

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
                insertedIDs[entry.data.spellID] = true
            end
        end
    end

    TUI:UpdateSpecialBars()
    NotifyChange()
end

StaticPopupDialogs["TUI_CASCADE_COPY_OVERWRITE_CONFIRM"] = {
    text = "This will DELETE your current %s on this spec and replace them. Continue?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        if not data then return end
        ApplyCopy(data.kind, data.leafID, "overwrite")
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function ShowChoicePopup(kind, leafLabel, leafID)
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
        ApplyCopy(kind, leafID, "add")
        AceGUI:Release(f)
    end)
    f:AddChild(addBtn)

    local overBtn = AceGUI:Create("Button")
    overBtn:SetText("Overwrite current")
    overBtn:SetRelativeWidth(0.33)
    overBtn:SetCallback("OnClick", function()
        AceGUI:Release(f)
        local dialog = StaticPopup_Show("TUI_CASCADE_COPY_OVERWRITE_CONFIRM", kind)
        if dialog then dialog.data = { kind = kind, leafID = leafID } end
    end)
    f:AddChild(overBtn)

    local cancelBtn = AceGUI:Create("Button")
    cancelBtn:SetText(CANCEL)
    cancelBtn:SetRelativeWidth(0.33)
    cancelBtn:SetCallback("OnClick", function() AceGUI:Release(f) end)
    f:AddChild(cancelBtn)
end

local function OpenCopyPicker(kind)
    if not ns.Cascade or not ns.Cascade.OpenSingle then
        E:Print("Cascade widget not loaded.")
        return
    end
    local tree = BuildCopySpecsTree(kind)
    if #tree == 0 then
        E:Print(("No other specs have %s configured to copy from."):format(kind))
        return
    end
    ns.Cascade.OpenSingle({
        title = ("Copy %s from..."):format(kind:gsub("^%l", string.upper)),
        tree  = tree,
        width = 480, height = 560,
        onSelect = function(leafID, leaf)
            ShowChoicePopup(kind, leaf and leaf.label, leafID)
        end,
    })
end

local function SpecialTabName(label, index, db)
    local name = db.spellName or ""
    if name == "" then return ("%s %d"):format(label, index) end
    local _, cf = UnitClass("player")
    local col = (ns.ClassColor and ns.ClassColor(cf)) or "|cffffffff"
    local tex = db.spellID and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(db.spellID)
    local icon = tex and ("|T" .. tex .. ":14:14|t ") or ""
    local out = ("%s%s%s|r"):format(icon, col, name)
    local inCDM = db.spellID and SB.GetRawSpellList and SB.GetRawSpellList()[db.spellID]
    if not inCDM then return "|cFFFF4444!|r " .. out end
    return out
end

local function BarTabName(barKey, index)
    if not SB then return ("Bar %d"):format(index) end
    return SpecialTabName("Bar", index, SB.GetBarDB(barKey) or {})
end

local function IconTabName(iconKey, index)
    if not SB then return ("Icon %d"):format(index) end
    return SpecialTabName("Icon", index, SB.GetIconDB(iconKey) or {})
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

local function BuildSpecialBarsGroup()
    return {
        order = 1,
        type = "group",
        name = "Special Bars",
        childGroups = "tab",
        args = {
            addBar = {
                order = 1, type = "execute", name = "|cFF40FF40+ New Special Bar|r", width = "double",
                disabled = function() return not SB or (SB.GetSpecRoot().barCount or 3) >= 12 end,
                func = function()
                    if not SB then return end
                    local s = SB.GetSpecRoot(); local c = s.barCount or 3
                    if c < 12 then s.barCount = c + 1; TUI:UpdateSpecialBars(); NotifyChange() end
                end,
            },
            copyBarsButton = {
                order = 2, type = "execute", name = "Copy from Another Spec...", width = "double",
                func = function() OpenCopyPicker("bars") end,
            },
            barCountHint = {
                order = 3, type = "description", fontSize = "medium",
                name = function() return ("|cFF888888%d / 12 bars - delete a bar from its own page.|r"):format((SB and SB.GetSpecRoot().barCount) or 3) end,
            },
            barsTab = {
                order = 10, type = "group", name = "Bars", childGroups = "tree",
                args = {
                    bar1Group  = { order=10,  type="group", childGroups="tab", name=function() return BarTabName("bar1",1)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 1  end, args=TUI:SpecialBarOptions("bar1")  },
                    bar2Group  = { order=20,  type="group", childGroups="tab", name=function() return BarTabName("bar2",2)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 2  end, args=TUI:SpecialBarOptions("bar2")  },
                    bar3Group  = { order=30,  type="group", childGroups="tab", name=function() return BarTabName("bar3",3)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 3  end, args=TUI:SpecialBarOptions("bar3")  },
                    bar4Group  = { order=40,  type="group", childGroups="tab", name=function() return BarTabName("bar4",4)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 4  end, args=TUI:SpecialBarOptions("bar4")  },
                    bar5Group  = { order=50,  type="group", childGroups="tab", name=function() return BarTabName("bar5",5)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 5  end, args=TUI:SpecialBarOptions("bar5")  },
                    bar6Group  = { order=60,  type="group", childGroups="tab", name=function() return BarTabName("bar6",6)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 6  end, args=TUI:SpecialBarOptions("bar6")  },
                    bar7Group  = { order=70,  type="group", childGroups="tab", name=function() return BarTabName("bar7",7)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 7  end, args=TUI:SpecialBarOptions("bar7")  },
                    bar8Group  = { order=80,  type="group", childGroups="tab", name=function() return BarTabName("bar8",8)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 8  end, args=TUI:SpecialBarOptions("bar8")  },
                    bar9Group  = { order=90,  type="group", childGroups="tab", name=function() return BarTabName("bar9",9)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 9  end, args=TUI:SpecialBarOptions("bar9")  },
                    bar10Group = { order=100, type="group", childGroups="tab", name=function() return BarTabName("bar10",10) end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 10 end, args=TUI:SpecialBarOptions("bar10") },
                    bar11Group = { order=110, type="group", childGroups="tab", name=function() return BarTabName("bar11",11) end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 11 end, args=TUI:SpecialBarOptions("bar11") },
                    bar12Group = { order=120, type="group", childGroups="tab", name=function() return BarTabName("bar12",12) end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 12 end, args=TUI:SpecialBarOptions("bar12") },
                },
            },
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
            addIcon = {
                order = 1, type = "execute", name = "|cFF40FF40+ New Special Icon|r", width = "double",
                disabled = function() return not SB or (SB.GetSpecRoot().iconCount or 3) >= 12 end,
                func = function()
                    if not SB then return end
                    local s = SB.GetSpecRoot(); local c = s.iconCount or 3
                    if c < 12 then
                        s.iconCount = c + 1
                        TUI:UpdateSpecialBars(); NotifyChange()
                        if ns.SB_OpenIconEditor then ns.SB_OpenIconEditor("icon" .. (c + 1)) end
                    end
                end,
            },
            copyIconsButton = {
                order = 2, type = "execute", name = "Copy from Another Spec...", width = "double",
                func = function() OpenCopyPicker("icons") end,
            },
            iconCountHint = {
                order = 3, type = "description", fontSize = "medium",
                name = function() return ("|cFF888888%d / 12 icons - delete an icon from its own page.|r"):format((SB and SB.GetSpecRoot().iconCount) or 3) end,
            },
            iconsTab = {
                order = 10, type = "group", name = "Icons", childGroups = "tree",
                args = BuildIconTreeArgs(),
            },
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
