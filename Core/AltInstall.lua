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
        key = "platynator", title = "Platynator", color = "FF6EB4",
        loaded = function() return _G.PLATYNATOR_CONFIG and _G.PLATYNATOR_CONFIG.Profiles and true or false end,
        profiles = function()
            local out = {}
            for name in pairs(_G.PLATYNATOR_CONFIG.Profiles) do out[#out + 1] = name end
            return out
        end,
        current = function() return _G.PLATYNATOR_CURRENT_PROFILE end,
        set = function(name)
            if _G.PLATYNATOR_CONFIG.Profiles[name] == nil then return end
            if _G.PLATYNATOR_CURRENT_PROFILE ~= name then
                _G.PLATYNATOR_CURRENT_PROFILE = name
                M._needReload = true
            end
        end,
    },
    {
        key = "elvui", title = "ElvUI", color = "8080FF",
        loaded = function() return E.data ~= nil end,
        profiles = function() return E.data:GetProfiles() end,
        current = function() return E.data:GetCurrentProfile() end,
        set = function(name) E.data:SetProfile(name) end,
        specApply = function(map) DualSpecApply(E.data, map) end,
    },
    {
        key = "elvpriv", title = "ElvUI Private", color = "CBA0FF",
        noRoles = true, deferSet = true,
        loaded = function() return E.charSettings ~= nil end,
        profiles = function() return E.charSettings:GetProfiles() end,
        current = function() return E.charSettings:GetCurrentProfile() end,
        set = function(name) E.charSettings:SetProfile(name) end,
    },
    {
        key = "grid2", title = "Grid2", color = "7FFF7F",
        loaded = function() return _G.Grid2 and _G.Grid2.db and true or false end,
        profiles = function() return _G.Grid2.db:GetProfiles() end,
        current = function() return _G.Grid2.db:GetCurrentProfile() end,
        set = function(name)
            local G2 = _G.Grid2
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
        key = "bigwigs", title = "BigWigs", color = "FF7F3F",
        loaded = function() return _G.BigWigsLoader and _G.BigWigsLoader.db and true or false end,
        profiles = function() return _G.BigWigsLoader.db:GetProfiles() end,
        current = function() return _G.BigWigsLoader.db:GetCurrentProfile() end,
        set = function(name) _G.BigWigsLoader.db:SetProfile(name) end,
        specApply = function(map) DualSpecApply(_G.BigWigsLoader.db, map) end,
    },
    {
        key = "buffreminders", title = "BuffReminders", color = "FFD700",
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
table.sort(PROVIDERS, function(a, b) return a.title < b.title end)

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

local function EMSpecStore(create)
    _G.thingsUIGlobalDB = _G.thingsUIGlobalDB or {}
    local g = _G.thingsUIGlobalDB
    if create then g.emSpec = g.emSpec or {} end
    local t = g.emSpec
    if not t then return nil end
    if create then t[CharKey()] = t[CharKey()] or {} end
    return t[CharKey()]
end

local pendingEM = false
function M.ApplyEMForSpec(fromApply)
    local st = EMSpecStore(false)
    if not (st and st.enabled and st.spec) then return end
    if InCombatLockdown() then pendingEM = true return end
    local idx = GetSpecialization()
    local want = idx and st.spec[idx]
    if not want then return end
    local combined, _, active = EditModeLayouts()
    if not combined then return end
    local wantIdx
    for i, l in ipairs(combined) do
        if l.layoutName == want then wantIdx = i break end
    end
    if not wantIdx or wantIdx == active then return end
    C_EditMode.SetActiveLayout(wantIdx)
    print("|cFF8080FFthingsUI|r: Edit Mode layout -> " .. want)
    if fromApply then E:StaticPopup_Show("TUI_ALT_RELOAD") end
end

local emEv = CreateFrame("Frame")
emEv:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
emEv:RegisterEvent("PLAYER_REGEN_ENABLED")
emEv:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        if unit and unit ~= "player" then return end
        C_Timer.After(1, function() M.ApplyEMForSpec() end)
        C_Timer.After(2, function() if M.CheckRoleMismatch then M.CheckRoleMismatch() end end)
    elseif event == "PLAYER_REGEN_ENABLED" and pendingEM then
        pendingEM = false
        C_Timer.After(1, function() M.ApplyEMForSpec() end)
    end
end)

local function Presets()
    _G.thingsUIGlobalDB = _G.thingsUIGlobalDB or {}
    local g = _G.thingsUIGlobalDB
    g.altPresets = g.altPresets or {}
    return g.altPresets
end

local PRESET_PREFIX = "!TUIALT2!"
local OLD_PRESET_PREFIX = "!TUIALT1!"

function M.ExportPresets()
    local presets = Presets()
    if not next(presets) then return nil end
    return ns.Share and ns.Share.EncodeTable and ns.Share.EncodeTable(presets, PRESET_PREFIX)
end

function M.ImportPresets(str)
    str = tostring(str or ""):gsub("%s", "")
    if str:sub(1, #OLD_PRESET_PREFIX) == OLD_PRESET_PREFIX then
        print("|cFF8080FFthingsUI|r: old preset format - re-export with this version.")
        return 0
    end
    local data = ns.Share and ns.Share.DecodeTable and ns.Share.DecodeTable(str, PRESET_PREFIX)
    if type(data) ~= "table" then return 0 end
    local presets = Presets()
    local n = 0
    for name, p in pairs(data) do
        if type(name) == "string" and type(p) == "table" then
            presets[name] = p
            n = n + 1
        end
    end
    return n
end

local function RoleStore(create)
    _G.thingsUIGlobalDB = _G.thingsUIGlobalDB or {}
    local g = _G.thingsUIGlobalDB
    if create then
        g.rolePresets = g.rolePresets or { mergeTankDps = true }
        g.rolePresets.providers = g.rolePresets.providers or {}
        g.rolePresets.em = g.rolePresets.em or {}
    end
    return g.rolePresets
end
M.RoleStore = RoleStore

local function RoleForSpecIndex(i)
    local classID = select(3, UnitClass("player"))
    if not classID then return nil end
    return select(5, GetSpecializationInfoForClassID(classID, i))
end

local function RoleKeyFor(i, rp)
    local role = RoleForSpecIndex(i)
    if not role then return nil end
    if rp.mergeTankDps ~= false and role == "TANK" then role = "DAMAGER" end
    return role
end

function M.ApplyRoleProfiles(silent)
    local rp = RoleStore(false)
    if not (rp and rp.enabled and rp.providers) then return end
    local specs = ClassSpecs()
    local curIdx = GetSpecialization()
    for _, prov in ipairs(PROVIDERS) do
        local rmap = rp.providers[prov.key]
        if rmap and prov.loaded() and not prov.noRoles then
            local exists = {}
            for _, n in ipairs(prov.profiles() or {}) do exists[n] = true end
            local map = {}
            for i in ipairs(specs) do
                local want = rmap[RoleKeyFor(i, rp) or ""]
                if want and exists[want] then map[i] = want end
            end
            if curIdx and map[curIdx] and map[curIdx] ~= prov.current() then prov.set(map[curIdx]) end
            if prov.specApply and next(map) then prov.specApply(map) end
        end
    end
    local emSpec = {}
    for i in ipairs(specs) do
        local nm = rp.em and rp.em[RoleKeyFor(i, rp) or ""]
        if nm then emSpec[i] = nm end
    end
    if next(emSpec) then
        local st = EMSpecStore(true)
        st.enabled = true
        st.spec = emSpec
        M.ApplyEMForSpec(not silent)
    end
    if M._needReload then
        M._needReload = nil
        E:StaticPopup_Show("TUI_ALT_RELOAD")
    end
end
M.ApplyRolePresets = M.ApplyRoleProfiles

E.PopupDialogs["TUI_ALT_ROLEPOPUP"] = {
    text = "%s",
    button1 = ACCEPT, button2 = CANCEL,
    OnAccept = function() M.ApplyRoleProfiles() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

function M.CheckRoleMismatch()
    local rp = RoleStore(false)
    if not (rp and rp.enabled and rp.providers) or InCombatLockdown() then return end
    local curIdx = GetSpecialization()
    if not curIdx then return end
    local rk = RoleKeyFor(curIdx, rp)
    if not rk then return end
    local lines = {}
    for _, prov in ipairs(PROVIDERS) do
        local rmap = rp.providers[prov.key]
        local want = rmap and rmap[rk]
        if want and prov.loaded() and want ~= prov.current() then
            lines[#lines + 1] = ("|cFF%s%s:|r %s"):format(prov.color or "FFFFFF", prov.title, want)
        end
    end
    if #lines == 0 then return end
    local msg = "|cFF8080FFthingsUI|r: Update profile preset?\n\n" .. table.concat(lines, "\n")
    E:StaticPopup_Show("TUI_ALT_ROLEPOPUP", msg)
end

E.PopupDialogs["TUI_ALT_ROLEUPDATE"] = {
    text = "%s",
    button1 = YES, button2 = NO,
    OnAccept = function(_, data)
        local rp = RoleStore(false)
        if rp and rp.providers then
            rp.providers[data.provKey] = rp.providers[data.provKey] or {}
            rp.providers[data.provKey][data.role] = data.profile
            print("|cFF8080FFthingsUI|r - Multi-Spec preset updated.")
        end
    end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

local function DefaultPresetName()
    local g = _G.thingsUIGlobalDB
    local name = g and g.altPresetDefault
    return (name and Presets()[name]) and name or nil
end

local function DefaultPresetDiff()
    local name = DefaultPresetName()
    local p = name and Presets()[name]
    if not p then return nil end
    local rp = RoleStore(false)
    local diff = {}
    for _, prov in ipairs(PROVIDERS) do
        local pp = p.providers and p.providers[prov.key]
        local roleGoverned = rp and rp.enabled and rp.providers
            and rp.providers[prov.key] and next(rp.providers[prov.key])
        if pp and pp.profile and prov.loaded() and not roleGoverned then
            local exists = {}
            for _, n in ipairs(prov.profiles() or {}) do exists[n] = true end
            if exists[pp.profile] and prov.current() ~= pp.profile then
                diff[#diff + 1] = { prov = prov, profile = pp.profile }
            end
        end
    end
    return diff, name
end

function M.ApplyDefaultPreset()
    local diff = DefaultPresetDiff()
    if not diff then return end
    local deferred
    for _, d in ipairs(diff) do
        if d.prov.deferSet then
            local pr, nm = d.prov, d.profile
            deferred = function() pr.set(nm) end
        else
            d.prov.set(d.profile)
        end
    end
    if M._needReload then
        M._needReload = nil
        E:StaticPopup_Show("TUI_ALT_RELOAD")
    end
    if deferred then deferred() end
end

E.PopupDialogs["TUI_ALT_DEFPRESET"] = {
    text = "%s",
    button1 = ACCEPT, button2 = CANCEL,
    OnAccept = function() M.ApplyDefaultPreset() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

function M.CheckDefaultPreset()
    if InCombatLockdown() then return end
    if not Store()[CharKey()] then return end
    local diff, name = DefaultPresetDiff()
    if not (diff and #diff > 0) then return end
    local lines = {}
    for _, d in ipairs(diff) do
        lines[#lines + 1] = ("|cFF%s%s:|r %s"):format(d.prov.color or "FFFFFF", d.prov.title, d.profile)
    end
    E:StaticPopup_Show("TUI_ALT_DEFPRESET",
        ("|cFF8080FFthingsUI|r: Switch to the '%s' preset profiles?\n\n%s"):format(name, table.concat(lines, "\n")))
end

function M.OfferRoleUpdate(provKey, profileName)
    local rp = RoleStore(false)
    if not (rp and rp.enabled and rp.providers) then return end
    local curIdx = GetSpecialization()
    local rk = curIdx and RoleKeyFor(curIdx, rp)
    if not rk then return end
    local prov
    for _, p in ipairs(PROVIDERS) do if p.key == provKey then prov = p break end end
    if not prov or prov.noRoles then return end
    local rmap = rp.providers[provKey]
    local have = rmap and rmap[rk]
    if have == profileName then return end
    local roleLabel = (rk == "HEALER") and "Healer"
        or ((rp.mergeTankDps ~= false) and "Tank & DPS" or ((rk == "TANK") and "Tank" or "DPS"))
    local msg = ("|cFF8080FFthingsUI|r: Set the |cFF%s%s|r Multi-Spec profile for |cFFFFFFFF%s|r to '%s'?\n\nPreset currently has: %s"):format(
        prov.color or "FFFFFF", prov.title, roleLabel, profileName, have or "|cFF888888- none -|r")
    E:StaticPopup_Show("TUI_ALT_ROLEUPDATE", msg, nil, { provKey = provKey, role = rk, profile = profileName })
end

local function CapturePreset(sel, emSel, emSpec)
    local p = { providers = {} }
    if emSpec then
        p.editModeSpecEnabled = emSpec.enabled or nil
        if emSpec.spec and next(emSpec.spec) then p.editModeSpec = CopyTable(emSpec.spec) end
    end
    for _, prov in ipairs(PROVIDERS) do
        if prov.loaded() then
            local s = sel[prov.key]
            local profile = (s and s.profile) or prov.current()
            if profile then
                local entry = { profile = profile }
                if s and s.specEnabled then
                    entry.specEnabled = true
                    if s.spec and next(s.spec) then entry.spec = CopyTable(s.spec) end
                end
                p.providers[prov.key] = entry
            end
        end
    end
    local combined, _, active = EditModeLayouts()
    local idx = emSel or active
    local l = combined and idx and combined[idx]
    if l and l.layoutName then p.editModeLayout = l.layoutName end
    return p
end

local function ApplyPresetToSel(preset, sel, specs, emSpecOut)
    if emSpecOut then
        emSpecOut.enabled = preset.editModeSpecEnabled or false
        emSpecOut.spec = {}
        for i, nm in pairs(preset.editModeSpec or {}) do
            if type(i) == "number" and type(nm) == "string" then emSpecOut.spec[i] = nm end
        end
    end
    local missing = {}
    for _, prov in ipairs(PROVIDERS) do
        local pp = preset.providers and preset.providers[prov.key]
        if pp and prov.loaded() then
            local s = sel[prov.key] or { spec = {} }
            sel[prov.key] = s
            local exists = {}
            for _, n in ipairs(prov.profiles() or {}) do exists[n] = true end
            if pp.profile then
                if exists[pp.profile] then s.profile = pp.profile
                else missing[#missing + 1] = ("|cFF%s%s:|r %s"):format(prov.color or "FFFFFF", prov.title, pp.profile) end
            end
            s.specEnabled = pp.specEnabled or false
            s.spec = {}
            for i in ipairs(specs) do
                local want = (pp.spec and pp.spec[i]) or pp.profile
                if want and exists[want] then s.spec[i] = want end
            end
        end
    end
    local emIdx
    if preset.editModeLayout then
        local combined = EditModeLayouts()
        if combined then
            for i, l in ipairs(combined) do
                if l.layoutName == preset.editModeLayout then emIdx = i break end
            end
            if not emIdx then missing[#missing + 1] = "|cFFAAAAAAEdit Mode:|r " .. preset.editModeLayout end
        end
    end
    return emIdx, missing
end

local function ShowTextPopup(title, text, onAccept)
    local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
    if not AceGUI then return end
    local f = AceGUI:Create("Frame")
    ns.SolidDialog(f)
    f:SetTitle(title)
    f:SetWidth(480)
    f:SetHeight(340)
    f:SetLayout("Fill")
    f:SetCallback("OnClose", function(w) AceGUI:Release(w) end)
    local eb = AceGUI:Create("MultiLineEditBox")
    eb:SetLabel(onAccept and "Paste the string, then press Accept" or "Copy the string (Ctrl+C)")
    eb:SetText(text or "")
    if onAccept then
        eb:SetCallback("OnEnterPressed", function(_, _, v) f:Hide(); onAccept(v) end)
    else
        eb:DisableButton(true)
    end
    eb:SetFullWidth(true)
    eb:SetFullHeight(true)
    f:AddChild(eb)
    if text and eb.editBox then eb.editBox:HighlightText(); eb.editBox:SetFocus() end
end

E.PopupDialogs["TUI_ALT_RELOAD"] = {
    text = "|cFF8080FFthingsUI|r: Edit Mode layout switched. Reload now to apply it cleanly?",
    button1 = ACCEPT, button2 = CANCEL,
    OnAccept = function() ReloadUI() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

local frame

function M.Apply(sel, emSel, emSpec)
    if InCombatLockdown() then
        print("|cFF8080FFthingsUI|r - Cannot apply profiles during combat.")
        return
    end
    local deferred
    for _, prov in ipairs(PROVIDERS) do
        local s = sel[prov.key]
        if s and prov.loaded() then
            if s.profile and s.profile ~= prov.current() then
                if prov.deferSet then
                    local p, n = prov, s.profile
                    deferred = function() p.set(n) end
                else
                    prov.set(s.profile)
                end
            end
            if s.specEnabled and prov.specApply then
                local map = {}
                for i, name in pairs(s.spec or {}) do
                    if type(i) == "number" and type(name) == "string" then map[i] = name end
                end
                if next(map) then prov.specApply(map) end
            end
        end
    end
    if emSpec then
        local st = EMSpecStore(true)
        st.enabled = emSpec.enabled or nil
        st.spec = {}
        for i, nm in pairs(emSpec.spec or {}) do
            if type(i) == "number" and type(nm) == "string" then st.spec[i] = nm end
        end
    end
    local reloadNeeded = false
    if emSpec and emSpec.enabled then
        M.ApplyEMForSpec(true)
    elseif emSel then
        local combined, _, active = EditModeLayouts()
        if combined and emSel ~= active and combined[emSel] then
            C_EditMode.SetActiveLayout(emSel)
            reloadNeeded = true
        end
    end
    Store()[CharKey()] = true
    if frame then frame:Hide() end
    local rp = RoleStore(false)
    if rp and rp.enabled then M.ApplyRolePresets(true) end
    if deferred then deferred() return end
    if reloadNeeded or M._needReload then
        M._needReload = nil
        E:StaticPopup_Show("TUI_ALT_RELOAD")
    end
end

function M.Open()
    local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
    if not AceGUI then print("|cFF8080FFthingsUI|r: AceGUI unavailable.") return end
    if frame then frame:Hide(); frame = nil end

    local sel = {}
    local emSel
    local presetSel
    local presetMissing
    local specs = ClassSpecs()
    local emStore = EMSpecStore(false)
    local emSpec = { enabled = (emStore and emStore.enabled) or false, spec = {} }
    for i in ipairs(specs) do
        emSpec.spec[i] = emStore and emStore.spec and emStore.spec[i] or nil
    end

    do
        local dflt = DefaultPresetName()
        if dflt then
            presetSel = dflt
            local emIdx, missing = ApplyPresetToSel(Presets()[dflt], sel, specs, emSpec)
            presetMissing = (missing and #missing > 0) and missing or nil
            if emIdx then emSel = emIdx end
        end
    end

    local f = AceGUI:Create("Frame")
    ns.SolidDialog(f)
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

        local presets = Presets()
        Add(scroll, "Heading", function(w) w:SetText("Presets"); w:SetFullWidth(true) end)
        do
            local list, order = { [""] = "|cFF888888- None -|r" }, { "" }
            local names = {}
            local dflt = DefaultPresetName()
            for name in pairs(presets) do names[#names + 1] = name end
            table.sort(names)
            for _, n in ipairs(names) do
                list[n] = (n == dflt) and (n .. " |cFF888888(default)|r") or n
                order[#order + 1] = n
            end
            Add(scroll, "Dropdown", function(w)
                w:SetLabel("Load Preset")
                w:SetRelativeWidth(0.4)
                w:SetList(list, order)
                w:SetValue((presetSel and presets[presetSel]) and presetSel or "")
                w:SetCallback("OnValueChanged", function(_, _, v)
                    if v == "" then presetSel = nil; presetMissing = nil; render() return end
                    presetSel = v
                    local p = presets[v]
                    if p then
                        local emIdx, missing = ApplyPresetToSel(p, sel, specs, emSpec)
                        presetMissing = (missing and #missing > 0) and missing or nil
                        if emIdx then emSel = emIdx end
                        render()
                    end
                end)
            end)
            Add(scroll, "Button", function(w)
                w:SetText("Update Preset")
                w:SetRelativeWidth(0.3)
                w:SetDisabled(not (presetSel and presets[presetSel]))
                w:SetCallback("OnClick", function()
                    if presetSel and presets[presetSel] then
                        presets[presetSel] = CapturePreset(sel, emSel, emSpec)
                        print("|cFF8080FFthingsUI|r - preset '" .. presetSel .. "' updated.")
                    end
                end)
            end)
            local function FixRoleRefs(old, new)
                local rp = RoleStore(false)
                if not rp then return end
                for _, k in ipairs({ "TANK", "DAMAGER", "HEALER" }) do
                    if rp[k] == old then rp[k] = new end
                end
                for _, cs in pairs(rp.classSpec or {}) do
                    for i, nm in pairs(cs) do
                        if nm == old then cs[i] = new end
                    end
                end
            end
            Add(scroll, "Button", function(w)
                w:SetText("Delete")
                w:SetRelativeWidth(0.3)
                w:SetDisabled(not (presetSel and presets[presetSel]))
                w:SetCallback("OnClick", function()
                    if presetSel then
                        presets[presetSel] = nil
                        FixRoleRefs(presetSel, nil)
                        local g = _G.thingsUIGlobalDB
                        if g and g.altPresetDefault == presetSel then g.altPresetDefault = nil end
                        presetSel = nil
                        render()
                    end
                end)
            end)
            Add(scroll, "CheckBox", function(w)
                w:SetLabel("Default")
                w:SetFullWidth(true)
                w:SetDisabled(not (presetSel and presets[presetSel]))
                w:SetValue(presetSel ~= nil and DefaultPresetName() == presetSel)
                w:SetCallback("OnValueChanged", function(_, _, v)
                    _G.thingsUIGlobalDB = _G.thingsUIGlobalDB or {}
                    local g = _G.thingsUIGlobalDB
                    if v then g.altPresetDefault = presetSel
                    elseif g.altPresetDefault == presetSel then g.altPresetDefault = nil end
                    render()
                end)
            end)
            Add(scroll, "EditBox", function(w)
                w:SetLabel("Rename selected preset to")
                w:SetRelativeWidth(0.5)
                w:SetDisabled(not (presetSel and presets[presetSel]))
                w:SetCallback("OnEnterPressed", function(_, _, v)
                    v = (v or ""):match("^%s*(.-)%s*$")
                    if v == "" or not (presetSel and presets[presetSel]) then return end
                    if presets[v] then
                        print("|cFF8080FFthingsUI|r - a preset named '" .. v .. "' already exists.")
                        return
                    end
                    presets[v] = presets[presetSel]
                    presets[presetSel] = nil
                    FixRoleRefs(presetSel, v)
                    local g = _G.thingsUIGlobalDB
                    if g and g.altPresetDefault == presetSel then g.altPresetDefault = v end
                    print("|cFF8080FFthingsUI|r - preset '" .. presetSel .. "' renamed to '" .. v .. "'.")
                    presetSel = v
                    render()
                end)
            end)
            Add(scroll, "EditBox", function(w)
                w:SetLabel("Save current as new preset")
                w:SetRelativeWidth(0.5)
                w:SetCallback("OnEnterPressed", function(_, _, v)
                    v = (v or ""):match("^%s*(.-)%s*$")
                    if v ~= "" then
                        presets[v] = CapturePreset(sel, emSel, emSpec)
                        presetSel = v
                        render()
                    end
                end)
            end)
            Add(scroll, "Button", function(w)
                w:SetText("Export Presets")
                w:SetRelativeWidth(0.5)
                w:SetCallback("OnClick", function()
                    local str = M.ExportPresets()
                    ShowTextPopup("Alt Presets Export", str or "Nothing to export.")
                end)
            end)
            Add(scroll, "Button", function(w)
                w:SetText("Import Presets")
                w:SetRelativeWidth(0.5)
                w:SetCallback("OnClick", function()
                    ShowTextPopup("Alt Presets Import", nil, function(v)
                        local n = M.ImportPresets(v)
                        print("|cFF8080FFthingsUI|r - imported " .. n .. " alt preset(s).")
                        render()
                    end)
                end)
            end)
        end

        if presetMissing then
            Add(scroll, "Label", function(w)
                w:SetFullWidth(true)
                w:SetText("|cFFFF6060Preset profiles not found on this account:|r " .. table.concat(presetMissing, "   ") .. "\n")
            end)
        end

        local rp = RoleStore(true)
        Add(scroll, "Heading", function(w) w:SetText("Multi-Spec"); w:SetFullWidth(true) end)
        Add(scroll, "CheckBox", function(w)
            w:SetLabel("Enable Multi-Spec")
            w:SetFullWidth(true)
            w:SetValue(rp.enabled or false)
            w:SetCallback("OnValueChanged", function(_, _, v) rp.enabled = v or nil; render() end)
        end)
        if rp.enabled then
            Add(scroll, "CheckBox", function(w)
                w:SetLabel("Tank & DPS share profile")
                w:SetFullWidth(true)
                w:SetValue(rp.mergeTankDps ~= false)
                w:SetCallback("OnValueChanged", function(_, _, v) rp.mergeTankDps = v and true or false; render() end)
            end)
        end
        local uiRoles = (rp.mergeTankDps ~= false)
            and { { key = "DAMAGER", label = "Tank & DPS" }, { key = "HEALER", label = "Healer" } }
            or { { key = "TANK", label = "Tank" }, { key = "DAMAGER", label = "DPS" }, { key = "HEALER", label = "Healer" } }

        for _, prov in ipairs(PROVIDERS) do
            if prov.loaded() then
                local s = sel[prov.key]
                if not s then s = { spec = {} }; sel[prov.key] = s end

                Add(scroll, "Heading", function(w)
                    w:SetText(("|cFF%s%s|r"):format(prov.color or "FFFFFF", prov.title))
                    w:SetFullWidth(true)
                end)

                local names = prov.profiles() or {}
                table.sort(names)
                local list, order = {}, {}
                local current = prov.current()
                for _, n in ipairs(names) do
                    list[n] = (n == current) and (n .. " |cFF888888(current)|r") or n
                    order[#order + 1] = n
                end

                if rp.enabled and not prov.noRoles then
                    rp.providers[prov.key] = rp.providers[prov.key] or {}
                    local rmap = rp.providers[prov.key]
                    local rlist = { [""] = "|cFF888888- None -|r" }
                    local rorder = { "" }
                    for _, n in ipairs(order) do rlist[n] = list[n]; rorder[#rorder + 1] = n end
                    for _, role in ipairs(uiRoles) do
                        Add(scroll, "Dropdown", function(w)
                            w:SetLabel(role.label)
                            w:SetRelativeWidth(1 / #uiRoles)
                            w:SetList(rlist, rorder)
                            w:SetValue(rmap[role.key] or "")
                            w:SetCallback("OnValueChanged", function(_, _, v)
                                rmap[role.key] = (v ~= "") and v or nil
                            end)
                        end)
                    end
                else
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
                end

                if prov.specApply and #specs > 0 and not rp.enabled then
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
            if rp.enabled then
                rp.em = rp.em or {}
                local rlist = { [""] = "|cFF888888- None -|r" }
                local rorder = { "" }
                for i, l in ipairs(combined) do
                    local nm = l.layoutName
                    if nm and rlist[nm] == nil then
                        rlist[nm] = list[tostring(i)]
                        rorder[#rorder + 1] = nm
                    end
                end
                for _, role in ipairs(uiRoles) do
                    Add(scroll, "Dropdown", function(w)
                        w:SetLabel(role.label)
                        w:SetRelativeWidth(1 / #uiRoles)
                        w:SetList(rlist, rorder)
                        w:SetValue(rp.em[role.key] or "")
                        w:SetCallback("OnValueChanged", function(_, _, v)
                            rp.em[role.key] = (v ~= "") and v or nil
                        end)
                    end)
                end
            else
            Add(scroll, "Dropdown", function(w)
                w:SetLabel(emSpec.enabled and "Layout |cff888888(spec layouts below take over)|r"
                    or "Layout (switching prompts a reload)")
                w:SetFullWidth(true)
                w:SetList(list, order)
                w:SetValue(tostring(emSel or active))
                w:SetCallback("OnValueChanged", function(_, _, v) emSel = tonumber(v) end)
            end)
            Add(scroll, "CheckBox", function(w)
                w:SetLabel("Spec layouts (auto-switch on spec change)")
                w:SetFullWidth(true)
                w:SetValue(emSpec.enabled or false)
                w:SetCallback("OnValueChanged", function(_, _, v)
                    emSpec.enabled = v
                    if v then
                        local curName = combined[active] and combined[active].layoutName
                        for i in ipairs(specs) do
                            if emSpec.spec[i] == nil then emSpec.spec[i] = curName end
                        end
                    end
                    render()
                end)
            end)
            if emSpec.enabled then
                local function idxForName(nm)
                    for i, l in ipairs(combined) do
                        if l.layoutName == nm then return i end
                    end
                end
                for i, specName in ipairs(specs) do
                    Add(scroll, "Dropdown", function(w)
                        w:SetLabel(specName)
                        w:SetRelativeWidth(0.5)
                        w:SetList(list, order)
                        local cur = idxForName(emSpec.spec[i])
                        w:SetValue(tostring(cur or active))
                        w:SetCallback("OnValueChanged", function(_, _, v)
                            local l = combined[tonumber(v)]
                            emSpec.spec[i] = l and l.layoutName or nil
                        end)
                    end)
                end
            end
            end
        end

        local offline = {}
        for _, prov in ipairs(PROVIDERS) do
            if not prov.loaded() then offline[#offline + 1] = ("|cFF%s%s|r"):format(prov.color or "FFFFFF", prov.title) end
        end
        if #offline > 0 then
            Add(scroll, "Label", function(w)
                w:SetFullWidth(true)
                w:SetText("\n|cFFFF6060Addons not installed or enabled:|r " .. table.concat(offline, ", "))
            end)
        end

        Add(scroll, "Label", function(w) w:SetFullWidth(true); w:SetText("\n") end)
        Add(scroll, "Button", function(w)
            w:SetText("Apply")
            w:SetRelativeWidth(0.5)
            w:SetCallback("OnClick", function() M.Apply(sel, emSel, emSpec) end)
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

local function GateCheck(verbose)
    local function why(msg)
        if verbose then print("|cFF8080FFthingsUI|r AltSetup gate: " .. msg) end
    end
    local g = _G.thingsUIGlobalDB
    if not (g and g.installComplete) then why("main installer not completed yet") return false end
    if Store()[CharKey()] then why("already done/skipped on " .. CharKey()) return false end
    if not (E.data and E.data.GetCurrentProfile) then why("E.data not ready") return false end
    local cur = E.data:GetCurrentProfile()
    if cur ~= "Default" then why("ElvUI profile is '" .. tostring(cur) .. "', not 'Default'") return false end
    if InCombatLockdown() then why("in combat") return false end
    why("all gates pass")
    return true
end

SLASH_TUIALTSETUP1 = "/tuialt"
SlashCmdList["TUIALTSETUP"] = function(msg)
    if (msg or ""):match("^%s*why") then GateCheck(true) return end
    M.Open()
end

local booted = false
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    local presets = Presets()
    if not next(presets) then
        local s = ns.InstallStrings and ns.InstallStrings.ALT_PRESETS
        if s and s ~= "" then M.ImportPresets(s) end
    end
    for _, t in ipairs({ 4, 10, 20 }) do
        C_Timer.After(t, function()
            if booted or frame then return end
            if GateCheck() then
                booted = true
                M.Open()
            end
        end)
    end
    C_Timer.After(8, function() M.CheckRoleMismatch() end)
    C_Timer.After(10, function() M.CheckDefaultPreset() end)
end)
