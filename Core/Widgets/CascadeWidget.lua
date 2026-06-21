local _, ns = ...
local E = ns.E
local AceGUI = LibStub("AceGUI-3.0", true)

if not AceGUI then return end

local Cascade = {}
ns.Cascade = Cascade

-- Open aceGUI tree
local function CreateWindow(title, width, height)
    local f = AceGUI:Create("Frame")
    f:SetTitle(title or "Select")
    f:SetStatusText("")
    f:SetWidth(width or 420)
    f:SetHeight(height or 480)
    f:SetLayout("Flow")
    f:EnableResize(false)
    return f
end

-- Single-select tree
function Cascade.OpenSingle(opts)
    if not opts or type(opts.tree) ~= "table" then return end
    local f = CreateWindow(opts.title or "Select", opts.width, opts.height)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    f:AddChild(scroll)

    for _, classEntry in ipairs(opts.tree) do
        local classHeading = AceGUI:Create("Heading")
        classHeading:SetText(classEntry.label or "")
        classHeading:SetFullWidth(true)
        scroll:AddChild(classHeading)

        for _, specEntry in ipairs(classEntry.children or {}) do
            local specGroup = AceGUI:Create("InlineGroup")
            specGroup:SetTitle(specEntry.label or "")
            specGroup:SetFullWidth(true)
            specGroup:SetLayout("Flow")
            scroll:AddChild(specGroup)

            local children = specEntry.children or {}
            if #children == 0 then
                local empty = AceGUI:Create("Label")
                empty:SetText("|cFF888888(empty)|r")
                empty:SetFullWidth(true)
                specGroup:AddChild(empty)
            else
                for _, leaf in ipairs(children) do
                    local btn = AceGUI:Create("Button")
                    btn:SetText(leaf.label or leaf.id or "?")
                    btn:SetRelativeWidth(0.5)
                    btn:SetCallback("OnClick", function()
                        if opts.onSelect then opts.onSelect(leaf.id, leaf) end
                        AceGUI:Release(f)
                    end)
                    specGroup:AddChild(btn)
                end
            end
        end
    end

    return f
end

-- Multi-select tree
function Cascade.OpenMulti(opts)
    if not opts or type(opts.tree) ~= "table" then return end
    local f = CreateWindow(opts.title or "Select", opts.width, opts.height or 520)
    local working = {}
    if type(opts.selected) == "table" then
        for k, v in pairs(opts.selected) do working[k] = v and true or nil end
    end

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    f:AddChild(scroll)

    for _, classEntry in ipairs(opts.tree) do
        local classHeading = AceGUI:Create("Heading")
        classHeading:SetText(classEntry.label or "")
        classHeading:SetFullWidth(true)
        scroll:AddChild(classHeading)

        for _, specEntry in ipairs(classEntry.children or {}) do
            local children = specEntry.children or {}
            local rowLabel = specEntry.label or ""

            if #children == 1 then
                local leaf = children[1]
                local cb = AceGUI:Create("CheckBox")
                cb:SetLabel(rowLabel)
                cb:SetValue(working[leaf.id] == true)
                cb:SetRelativeWidth(0.5)
                cb:SetCallback("OnValueChanged", function(_, _, v)
                    working[leaf.id] = v and true or nil
                end)
                scroll:AddChild(cb)
            elseif #children > 1 then
                local specGroup = AceGUI:Create("InlineGroup")
                specGroup:SetTitle(rowLabel)
                specGroup:SetFullWidth(true)
                specGroup:SetLayout("Flow")
                scroll:AddChild(specGroup)
                for _, leaf in ipairs(children) do
                    local cb = AceGUI:Create("CheckBox")
                    cb:SetLabel(leaf.label or leaf.id or "?")
                    cb:SetValue(working[leaf.id] == true)
                    cb:SetRelativeWidth(0.5)
                    cb:SetCallback("OnValueChanged", function(_, _, v)
                        working[leaf.id] = v and true or nil
                    end)
                    specGroup:AddChild(cb)
                end
            end
        end
    end

    local footer = AceGUI:Create("SimpleGroup")
    footer:SetFullWidth(true)
    footer:SetLayout("Flow")
    f:AddChild(footer)

    local confirm = AceGUI:Create("Button")
    confirm:SetText("Confirm")
    confirm:SetRelativeWidth(0.5)
    confirm:SetCallback("OnClick", function()
        if opts.onConfirm then opts.onConfirm(working) end
        AceGUI:Release(f)
    end)
    footer:AddChild(confirm)

    local cancel = AceGUI:Create("Button")
    cancel:SetText("Cancel")
    cancel:SetRelativeWidth(0.5)
    cancel:SetCallback("OnClick", function()
        AceGUI:Release(f)
    end)
    footer:AddChild(cancel)

    return f
end

-- Tree builders
local CLASS_ORDER = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
    "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER",
}

local ClassColor = ns.ClassColor

local function ClassLabel(classToken)
    local info = C_CreatureInfo and C_CreatureInfo.GetClassInfo
    local className = classToken
    if info then
        local data = info(GetClassIDFromToken and GetClassIDFromToken(classToken) or 0)
        if data and data.className then className = data.className end
    end
    if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken] then
        className = LOCALIZED_CLASS_NAMES_MALE[classToken]
    end
    return ClassColor(classToken) .. className .. "|r"
end

local _classIDCache
local function GetClassIDByToken(token)
    if not _classIDCache then
        _classIDCache = {}
        for id = 1, GetNumClasses and GetNumClasses() or 13 do
            local _, t = GetClassInfo(id)
            if t then _classIDCache[t] = id end
        end
    end
    return _classIDCache[token]
end

function Cascade.BuildAllSpecsTree()
    local tree = {}
    local lookup = {}
    for _, classToken in ipairs(CLASS_ORDER) do
        local classID = GetClassIDByToken(classToken)
        if classID then
            local classEntry = {
                token    = classToken,
                classID  = classID,
                label    = ClassLabel(classToken),
                children = {},
            }
            for _, r in ipairs(ns.SpecsForClass(classID)) do
                local specID, specName, specIcon = r.id, r.name, r.icon
                if specID and specName then
                    local iconStr = specIcon and ("|T"..specIcon..":14:14|t ") or ""
                    local specEntry = {
                        id       = tostring(specID),
                        specID   = specID,
                        label    = iconStr .. specName,
                        children = {}, -- caller fills
                    }
                    classEntry.children[#classEntry.children + 1] = specEntry
                    lookup[specID] = {
                        classToken = classToken,
                        classID    = classID,
                        specID     = specID,
                        specName   = specName,
                        specIcon   = specIcon,
                        classLabel = classEntry.label,
                        specLabel  = specEntry.label,
                    }
                end
            end
            tree[#tree + 1] = classEntry
        end
    end
    return tree, lookup
end
