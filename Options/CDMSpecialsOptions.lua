local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local SB = ns.SpecialBars

-- Tracks which source spec is selected in the copy-from dropdowns
local selectedCopySpec = ""

local function NotifyChange()
    local ok, reg = pcall(LibStub, "AceConfigRegistry-3.0")
    if ok and reg and reg.NotifyChange then reg:NotifyChange("ElvUI") end
end

local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do t[k] = DeepCopy(v) end
    return t
end

-- Returns number of bar slots and icon slots that have a spell configured
local function CountConfiguredSlots(specData)
    local bars, icons = 0, 0
    if specData.bars then
        for _, slot in pairs(specData.bars) do
            if type(slot) == "table" and slot.spellID then bars = bars + 1 end
        end
    end
    if specData.icons then
        for _, slot in pairs(specData.icons) do
            if type(slot) == "table" and slot.spellID then icons = icons + 1 end
        end
    end
    return bars, icons
end

-- Returns a table of {[specIDstring] = "ClassName - SpecName"} for specs that
-- have saved data, excluding the current spec.
local function GetOtherSpecChoices()
    local choices = { [""] = "|cFF888888— Select Spec —|r" }
    local db = E.db.thingsUI and E.db.thingsUI.specialBars
    if not db or not db.specs then return choices end
    local currentID = tostring(SB and SB.GetSpecRoot and (function()
        local idx = GetSpecialization()
        return idx and select(1, GetSpecializationInfo(idx)) or 0
    end)() or 0)
    for specIDStr, specData in pairs(db.specs) do
        if specIDStr ~= currentID then
            local configuredBars, configuredIcons = CountConfiguredSlots(specData)
            -- Skip specs with nothing configured
            if configuredBars > 0 or configuredIcons > 0 then
                local sid = tonumber(specIDStr)
                local specName, className
                if sid and sid > 0 then
                    local _, sName, _, _, _, _, cName = GetSpecializationInfoByID(sid)
                    specName  = sName  or ("Spec "..specIDStr)
                    className = cName  or ""
                else
                    specName, className = "Spec "..specIDStr, ""
                end
                local label = className ~= "" and (className.." - "..specName) or specName
                label = label .. " |cFF888888("..configuredBars.."b/"..configuredIcons.."i)|r"
                choices[specIDStr] = label
            end
        end
    end
    return choices
end

local function CopySpecSection(sourceKey, copyBars, copyIcons)
    if not sourceKey or sourceKey == "" then return end
    local db = E.db.thingsUI and E.db.thingsUI.specialBars
    if not db or not db.specs then return end
    local src = db.specs[sourceKey]
    if not src then return end

    local dest = SB.GetSpecRoot()

    if copyBars and src.bars then
        dest.barCount = src.barCount or dest.barCount or 3
        dest.bars = dest.bars or {}
        for i = 1, (dest.barCount or 3) do
            local key = "bar"..i
            local srcSlot = src.bars[key]
            if srcSlot then
                SB.ReleaseBar(key)
                dest.bars[key] = DeepCopy(srcSlot)
                -- Keep spellID as-is. If it doesn't exist in this spec's CDM the slot
                -- simply sits inactive — the user can add the spell to CDM or pick a new one.
            end
        end
    end

    if copyIcons and src.icons then
        dest.iconCount = src.iconCount or dest.iconCount or 3
        dest.icons = dest.icons or {}
        for i = 1, (dest.iconCount or 3) do
            local key = "icon"..i
            local srcSlot = src.icons[key]
            if srcSlot then
                SB.ReleaseIcon(key)
                dest.icons[key] = DeepCopy(srcSlot)
            end
        end
    end

    TUI:UpdateSpecialBars()
    NotifyChange()
end

local function BarTabName(barKey, index)
    if not SB then return ("Bar %d"):format(index) end
    local db = SB.GetBarDB(barKey) or {}
    local name = db.spellName or ""
    if name == "" then return ("Bar %d"):format(index) end
    -- Warn if the spell isn't in the current spec's CDM list
    local inCDM = SB.GetRawSpellList and SB.GetRawSpellList()[db.spellID]
    if not inCDM then
        return ("|cFFFF4444! Bar %d: %s|r"):format(index, name)
    end
    return ("Bar %d: %s"):format(index, name)
end

local function IconTabName(iconKey, index)
    if not SB then return ("Icon %d"):format(index) end
    local db = SB.GetIconDB(iconKey) or {}
    local name = db.spellName or ""
    if name == "" then return ("Icon %d"):format(index) end
    local inCDM = SB.GetRawSpellList and SB.GetRawSpellList()[db.spellID]
    if not inCDM then
        return ("|cFFFF4444! Icon %d: %s|r"):format(index, name)
    end
    return ("Icon %d: %s"):format(index, name)
end

local function BuildSpecialBarsGroup()
    return {
        order = 1,
        type = "group",
        name = "Special Bars",
        childGroups = "tab",
        args = {
            controlGroup = {
                order = 1, type = "group", name = "Manage",
                args = {
                    desc = { order = 1, type = "description",
                        name = "Pull individual Tracked Buff bars from the Cooldown Manager and reposition them anywhere.\n\nSettings are saved per specialization.\n" },
                    barCountHeader = { order = 2, type = "header", name = "Special Bars" },
                    barCount = {
                        order = 3, type = "range", name = "Number of Bar Slots", min = 1, max = 12, step = 1,
                        get = function() if not SB then return 3 end; return SB.GetSpecRoot().barCount or 3 end,
                        set = function(_, v)
                            if not SB then return end
                            local old = SB.GetSpecRoot().barCount or 3
                            SB.GetSpecRoot().barCount = v
                            if v < old then
                                for i = v+1, old do SB.ReleaseBar("bar"..i) end
                                TUI:UpdateSpecialBars()
                            end
                            NotifyChange()
                        end,
                    },
                    copyHeader = { order = 10, type = "header", name = "Copy from Another Spec" },
                    copyDesc = { order = 11, type = "description",
                        name = "Copies bar settings from another spec. Spells not available in the current spec are set to None.\n" },
                    copySpecSelect = {
                        order = 12, type = "select", name = "Copy From", width = "double",
                        values = GetOtherSpecChoices,
                        get = function() return selectedCopySpec end,
                        set = function(_, v) selectedCopySpec = v; NotifyChange() end,
                    },
                    copyBarsButton = {
                        order = 13, type = "execute", name = "Copy Bars",
                        disabled = function() return not selectedCopySpec or selectedCopySpec == "" end,
                        confirm = function() return "Overwrite your current bar settings with bars from the selected spec?" end,
                        func = function() CopySpecSection(selectedCopySpec, true, false) end,
                    },
                },
            },
            bar1Group  = { order=10,  type="group", childGroups="tree", name=function() return BarTabName("bar1",1)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 1  end, args=TUI:SpecialBarOptions("bar1")  },
            bar2Group  = { order=20,  type="group", childGroups="tree", name=function() return BarTabName("bar2",2)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 2  end, args=TUI:SpecialBarOptions("bar2")  },
            bar3Group  = { order=30,  type="group", childGroups="tree", name=function() return BarTabName("bar3",3)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 3  end, args=TUI:SpecialBarOptions("bar3")  },
            bar4Group  = { order=40,  type="group", childGroups="tree", name=function() return BarTabName("bar4",4)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 4  end, args=TUI:SpecialBarOptions("bar4")  },
            bar5Group  = { order=50,  type="group", childGroups="tree", name=function() return BarTabName("bar5",5)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 5  end, args=TUI:SpecialBarOptions("bar5")  },
            bar6Group  = { order=60,  type="group", childGroups="tree", name=function() return BarTabName("bar6",6)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 6  end, args=TUI:SpecialBarOptions("bar6")  },
            bar7Group  = { order=70,  type="group", childGroups="tree", name=function() return BarTabName("bar7",7)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 7  end, args=TUI:SpecialBarOptions("bar7")  },
            bar8Group  = { order=80,  type="group", childGroups="tree", name=function() return BarTabName("bar8",8)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 8  end, args=TUI:SpecialBarOptions("bar8")  },
            bar9Group  = { order=90,  type="group", childGroups="tree", name=function() return BarTabName("bar9",9)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 9  end, args=TUI:SpecialBarOptions("bar9")  },
            bar10Group = { order=100, type="group", childGroups="tree", name=function() return BarTabName("bar10",10) end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 10 end, args=TUI:SpecialBarOptions("bar10") },
            bar11Group = { order=110, type="group", childGroups="tree", name=function() return BarTabName("bar11",11) end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 11 end, args=TUI:SpecialBarOptions("bar11") },
            bar12Group = { order=120, type="group", childGroups="tree", name=function() return BarTabName("bar12",12) end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 12 end, args=TUI:SpecialBarOptions("bar12") },
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
            controlGroup = {
                order = 1, type = "group", name = "Manage",
                args = {
                    iconCountHeader = { order = 1, type = "header", name = "Special Icons" },
                    iconCount = {
                        order = 2, type = "range", name = "Number of Icon Slots", min = 1, max = 12, step = 1,
                        get = function() if not SB then return 3 end; return SB.GetSpecRoot().iconCount or 3 end,
                        set = function(_, v)
                            if not SB then return end
                            local old = SB.GetSpecRoot().iconCount or 3
                            SB.GetSpecRoot().iconCount = v
                            if v < old then
                                for i = v+1, old do SB.ReleaseIcon("icon"..i) end
                                TUI:UpdateSpecialBars()
                            end
                            NotifyChange()
                        end,
                    },
                    copyHeader = { order = 10, type = "header", name = "Copy from Another Spec" },
                    copyDesc = { order = 11, type = "description",
                        name = "Copies icon settings from another spec. Spells not available in the current spec are set to None.\n" },
                    copySpecSelect = {
                        order = 12, type = "select", name = "Copy From", width = "double",
                        values = GetOtherSpecChoices,
                        get = function() return selectedCopySpec end,
                        set = function(_, v) selectedCopySpec = v; NotifyChange() end,
                    },
                    copyIconsButton = {
                        order = 13, type = "execute", name = "Copy Icons",
                        disabled = function() return not selectedCopySpec or selectedCopySpec == "" end,
                        confirm = function() return "Overwrite your current icon settings with icons from the selected spec?" end,
                        func = function() CopySpecSection(selectedCopySpec, false, true) end,
                    },
                },
            },
            icon1Group  = { order=201, type="group", childGroups="tree", name=function() return IconTabName("icon1",1)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 1  end, args=TUI:SpecialIconOptions("icon1")  },
            icon2Group  = { order=202, type="group", childGroups="tree", name=function() return IconTabName("icon2",2)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 2  end, args=TUI:SpecialIconOptions("icon2")  },
            icon3Group  = { order=203, type="group", childGroups="tree", name=function() return IconTabName("icon3",3)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 3  end, args=TUI:SpecialIconOptions("icon3")  },
            icon4Group  = { order=204, type="group", childGroups="tree", name=function() return IconTabName("icon4",4)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 4  end, args=TUI:SpecialIconOptions("icon4")  },
            icon5Group  = { order=205, type="group", childGroups="tree", name=function() return IconTabName("icon5",5)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 5  end, args=TUI:SpecialIconOptions("icon5")  },
            icon6Group  = { order=206, type="group", childGroups="tree", name=function() return IconTabName("icon6",6)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 6  end, args=TUI:SpecialIconOptions("icon6")  },
            icon7Group  = { order=207, type="group", childGroups="tree", name=function() return IconTabName("icon7",7)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 7  end, args=TUI:SpecialIconOptions("icon7")  },
            icon8Group  = { order=208, type="group", childGroups="tree", name=function() return IconTabName("icon8",8)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 8  end, args=TUI:SpecialIconOptions("icon8")  },
            icon9Group  = { order=209, type="group", childGroups="tree", name=function() return IconTabName("icon9",9)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 9  end, args=TUI:SpecialIconOptions("icon9")  },
            icon10Group = { order=210, type="group", childGroups="tree", name=function() return IconTabName("icon10",10) end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 10 end, args=TUI:SpecialIconOptions("icon10") },
            icon11Group = { order=211, type="group", childGroups="tree", name=function() return IconTabName("icon11",11) end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 11 end, args=TUI:SpecialIconOptions("icon11") },
            icon12Group = { order=212, type="group", childGroups="tree", name=function() return IconTabName("icon12",12) end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 12 end, args=TUI:SpecialIconOptions("icon12") },
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
