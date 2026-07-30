local _, ns = ...
local E = ns.E

ns.AltInstall = ns.AltInstall or {}
local M = ns.AltInstall

local function Store()
    _G.thingsUIGlobalDB = _G.thingsUIGlobalDB or {}
    local g = _G.thingsUIGlobalDB
    g.altInstall = g.altInstall or {}
    return g.altInstall
end

local function CharKey()
    return E.mynameRealm or (UnitName("player") .. " - " .. GetRealmName())
end

local function AceDBForSV(sv)
    local lib = LibStub and LibStub("AceDB-3.0", true)
    if not (lib and sv) then return nil end
    for db in pairs(lib.db_registry) do
        if rawget(db, "sv") == sv then return db end
    end
end

-- LibDualSpec stores below level 10 too and auto-applies once specs unlock
local function DualSpecApply(db, map)
    if not (db and db.SetDualSpecEnabled and db.SetDualSpecProfile) then return end
    db:SetDualSpecEnabled(true)
    for i, name in pairs(map) do db:SetDualSpecProfile(name, i) end
end

local PROVIDERS = {
    {
        key = "elvui", title = "ElvUI",
        loaded = function() return E.data ~= nil end,
        profiles = function() return E.data:GetProfiles() end,
        current = function() return E.data:GetCurrentProfile() end,
        set = function(name) E.data:SetProfile(name) end,
        specApply = function(map) DualSpecApply(E.data, map) end,
    },
    {
        key = "grid2", title = "Grid2",
        loaded = function() return _G.Grid2 and _G.Grid2.db and true or false end,
        profiles = function() return _G.Grid2.db:GetProfiles() end,
        current = function() return _G.Grid2.db:GetCurrentProfile() end,
        set = function(name)
            local G2 = _G.Grid2
            -- SetProfile silently CREATES unknown names; only switch to existing
            if G2.db.profiles and G2.db.profiles[name] == nil then return end
            G2.db:SetProfile(name)
        end,
        specApply = function(map)
            local G2 = _G.Grid2
            if not (G2 and G2.EnableProfilesPerSpec and G2.SetProfileForSpec) then return end
            G2:EnableProfilesPerSpec(true)
            for i, name in pairs(map) do G2:SetProfileForSpec(name, i) end
        end,
    },
    {
        key = "bigwigs", title = "BigWigs",
        loaded = function() return _G.BigWigsLoader and _G.BigWigsLoader.db and true or false end,
        profiles = function() return _G.BigWigsLoader.db:GetProfiles() end,
        current = function() return _G.BigWigsLoader.db:GetCurrentProfile() end,
        set = function(name) _G.BigWigsLoader.db:SetProfile(name) end,
        specApply = function(map) DualSpecApply(_G.BigWigsLoader.db, map) end,
    },
    {
        key = "buffreminders", title = "BuffReminders",
        loaded = function() return _G.BuffReminders and _G.BuffRemindersDB and true or false end,
        profiles = function()
            local db = AceDBForSV(_G.BuffRemindersDB)
            if db then return db:GetProfiles() end
            local out = {}
            local keys = _G.BuffReminders.GetProfileKeys and _G.BuffReminders:GetProfileKeys() or {}
            for name in pairs(keys) do out[#out + 1] = name end
            return out
        end,
        current = function()
            local db = AceDBForSV(_G.BuffRemindersDB)
            if db then return db:GetCurrentProfile() end
            return _G.BuffReminders.GetCurrentProfileKey and _G.BuffReminders:GetCurrentProfileKey()
        end,
        set = function(name)
            if _G.BuffReminders.SetProfile then _G.BuffReminders:SetProfile(name) end
        end,
        specApply = function(map) DualSpecApply(AceDBForSV(_G.BuffRemindersDB), map) end,
    },
}

local function ClassSpecs()
    local classID = select(3, UnitClass("player"))
    if not classID then return {} end
    local getNum = (C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID)
        or GetNumSpecializationsForClassID
    local n = getNum and getNum(classID) or 0
    local out = {}
    for i = 1, n do
        local _, name = GetSpecializationInfoForClassID(classID, i)
        out[i] = name or ("Spec " .. i)
    end
    return out
end

-- GetLayouts omits Blizzard's presets, but every index counts them
local function EditModeLayouts()
    if not (C_EditMode and C_EditMode.GetLayouts and C_EditMode.SetActiveLayout) then return nil end
    if not (EditModeManagerFrame and EditModeManagerFrame.accountSettings) then return nil end
    if not (EditModePresetLayoutManager and EditModePresetLayoutManager.GetCopyOfPresetLayouts) then return nil end
    local info = C_EditMode.GetLayouts()
    if not (info and info.layouts) then return nil end
    local combined = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
    local presets = #combined
    for _, l in ipairs(info.layouts) do combined[#combined + 1] = l end
    return combined, presets, info.activeLayout
end

E.PopupDialogs["TUI_ALT_RELOAD"] = {
    text = "|cFF8080FFthingsUI|r: Edit Mode layout switched. Reload now to apply it cleanly?",
    button1 = ACCEPT, button2 = CANCEL,
    OnAccept = function() ReloadUI() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

local frame

function M.Apply(sel, emSel)
    if InCombatLockdown() then
        print("|cFF8080FFthingsUI|r - Cannot apply profiles during combat.")
        return
    end
    for _, prov in ipairs(PROVIDERS) do
        local s = sel[prov.key]
        if s and prov.loaded() then
            if s.profile and s.profile ~= prov.current() then prov.set(s.profile) end
            if s.specEnabled and prov.specApply then
                local map = {}
                for i, name in pairs(s.spec or {}) do
                    if type(i) == "number" and type(name) == "string" then map[i] = name end
                end
                if next(map) then prov.specApply(map) end
            end
        end
    end
    local reloadNeeded = false
    if emSel then
        local combined, _, active = EditModeLayouts()
        if combined and emSel ~= active and combined[emSel] then
            C_EditMode.SetActiveLayout(emSel)
            reloadNeeded = true
        end
    end
    Store()[CharKey()] = true
    if frame then frame:Hide() end
    if reloadNeeded then E:StaticPopup_Show("TUI_ALT_RELOAD") end
end

function M.Open()
    local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
    if not AceGUI then print("|cFF8080FFthingsUI|r: AceGUI unavailable.") return end
    if frame then frame:Hide(); frame = nil end

    local sel = {}
    local emSel
    local specs = ClassSpecs()

    local f = AceGUI:Create("Frame")
    frame = f
    f:SetTitle("|cFF8080FFthingsUI|r Alt Setup")
    f:SetWidth(560)
    f:SetHeight(660)
    f:SetLayout("Fill")
    f:SetCallback("OnClose", function(w)
        Store()[CharKey()] = true
        AceGUI:Release(w)
        if frame == w then frame = nil end
    end)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    f:AddChild(scroll)

    local function Add(c, wtype, setup)
        local w = AceGUI:Create(wtype)
        if setup then setup(w) end
        c:AddChild(w)
        return w
    end

    local render
    render = function()
        scroll:ReleaseChildren()

        Add(scroll, "Label", function(w)
            w:SetFullWidth(true)
            w:SetFontObject(GameFontHighlight)
            w:SetText("Pick which of your existing profiles this character should use.\nSpec profiles chosen before level 10 are stored and apply automatically once specializations unlock.\n")
        end)

        for _, prov in ipairs(PROVIDERS) do
            if prov.loaded() then
                local s = sel[prov.key]
                if not s then s = { spec = {} }; sel[prov.key] = s end

                Add(scroll, "Heading", function(w) w:SetText(prov.title); w:SetFullWidth(true) end)

                local names = prov.profiles() or {}
                table.sort(names)
                local list, order = {}, {}
                local current = prov.current()
                for _, n in ipairs(names) do
                    list[n] = (n == current) and (n .. " |cFF888888(current)|r") or n
                    order[#order + 1] = n
                end

                Add(scroll, "Dropdown", function(w)
                    w:SetLabel("Profile")
                    w:SetFullWidth(true)
                    w:SetList(list, order)
                    w:SetValue(s.profile or current)
                    w:SetCallback("OnValueChanged", function(_, _, v)
                        s.profile = v
                        if s.specEnabled then
                            for i in ipairs(specs) do
                                if s.spec[i] == nil or s.spec[i] == s._auto then s.spec[i] = v end
                            end
                            s._auto = v
                            render()
                        end
                    end)
                end)

                if prov.specApply and #specs > 0 then
                    Add(scroll, "CheckBox", function(w)
                        w:SetLabel("Spec profiles")
                        w:SetFullWidth(true)
                        w:SetValue(s.specEnabled or false)
                        w:SetCallback("OnValueChanged", function(_, _, v)
                            s.specEnabled = v
                            if v then
                                local base = s.profile or current
                                for i in ipairs(specs) do
                                    if s.spec[i] == nil then s.spec[i] = base end
                                end
                                s._auto = base
                            end
                            render()
                        end)
                    end)
                    if s.specEnabled then
                        for i, specName in ipairs(specs) do
                            Add(scroll, "Dropdown", function(w)
                                w:SetLabel(specName)
                                w:SetRelativeWidth(0.5)
                                w:SetList(list, order)
                                w:SetValue(s.spec[i] or s.profile or current)
                                w:SetCallback("OnValueChanged", function(_, _, v) s.spec[i] = v end)
                            end)
                        end
                    end
                end
            end
        end

        local combined, presets, active = EditModeLayouts()
        if combined then
            Add(scroll, "Heading", function(w) w:SetText("Edit Mode Layout"); w:SetFullWidth(true) end)
            local list, order = {}, {}
            for i, l in ipairs(combined) do
                local k = tostring(i)
                local suffix = (i <= presets) and " |cFF888888(preset)|r"
                    or (Enum.EditModeLayoutType and l.layoutType == Enum.EditModeLayoutType.Character
                        and " |cFF888888(character)|r" or "")
                local cur = (i == active) and " |cFF888888(current)|r" or ""
                list[k] = (l.layoutName or ("Layout " .. i)) .. suffix .. cur
                order[#order + 1] = k
            end
            Add(scroll, "Dropdown", function(w)
                w:SetLabel("Layout (switching prompts a reload)")
                w:SetFullWidth(true)
                w:SetList(list, order)
                w:SetValue(tostring(emSel or active))
                w:SetCallback("OnValueChanged", function(_, _, v) emSel = tonumber(v) end)
            end)
        end

        Add(scroll, "Label", function(w) w:SetFullWidth(true); w:SetText("\n") end)
        Add(scroll, "Button", function(w)
            w:SetText("Apply")
            w:SetRelativeWidth(0.5)
            w:SetCallback("OnClick", function() M.Apply(sel, emSel) end)
        end)
        Add(scroll, "Button", function(w)
            w:SetText("Skip")
            w:SetRelativeWidth(0.5)
            w:SetCallback("OnClick", function() f:Hide() end)
        end)
    end

    render()
    f:Show()
end

SLASH_TUIALTSETUP1 = "/tuialt"
SlashCmdList["TUIALTSETUP"] = function() M.Open() end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    C_Timer.After(4, function()
        local g = _G.thingsUIGlobalDB
        if not (g and g.installComplete) then return end
        if Store()[CharKey()] then return end
        if not (E.data and E.data.GetCurrentProfile) then return end
        if E.data:GetCurrentProfile() ~= "Default" then return end
        if InCombatLockdown() then return end
        M.Open()
    end)
end)
