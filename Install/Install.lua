local _, ns = ...
local TUI = ns.TUI
local E = ns.E

local PI = E and E.PluginInstaller
if not PI then return end

local function Store()
    _G.thingsUIGlobalDB = _G.thingsUIGlobalDB or {}
    return _G.thingsUIGlobalDB
end

-- 1440p strings carry the plain name, other resolutions a suffix (NHT_PROFILE_1080P)
local RES_BOUND = { NHT_PROFILE = true, FHT_PROFILE = true, NHT_PLUGIN = true, FHT_PLUGIN = true }
function ns.InstallString(key, res)
    local strs = ns.InstallStrings or {}
    if RES_BOUND[key] and res and res ~= "1440p" then key = key .. "_" .. res:upper() end
    local s = strs[key]
    s = s and strtrim(s)
    if s and s ~= "" then return s end
end

local function Res() return ns.Setup and ns.Setup.Res and ns.Setup.Res() or "1440p" end

local PRESETS = {
    { key = "NHT", label = "|cFFff0000NHT|r " },
    { key = "FHT", label = "|cFF00ff17FHT|r" },
}

local function PresetStr(key, res) return ns.InstallString(key .. "_PLUGIN", res or Res()) end
function ns.PresetString(key) return PresetStr(key) end
function ns.ImportPreset(key, res)
    local s = PresetStr(key, res)
    if not s or s == "" then print("|cFF8080FFthingsUI|r: preset '" .. tostring(key) .. "' not set.") return end
    local ok, err = false, nil
    if ns.Share then ok, err = ns.Share.Import(s) end
    if ok then print("|cFF8080FFthingsUI|r - Imported " .. key .. " defaults.")
    else print("|cFF8080FFthingsUI|r - " .. key .. " plugin import |cFFFF6060failed|r: " .. tostring(err or "Share module unavailable")) end
    return ok, err
end

E.PopupDialogs["TUI_IMPORT_PRESET"] = {
    text = "Import the |cFF8080FFthingsUI|r %s?\nThis overwrites your current thingsUI layout sections.",
    button1 = YES, button2 = CANCEL,
    OnAccept = function(_, key) ns.ImportPreset(key) end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}
function ns.ImportPresetConfirm(key, label)
    E:StaticPopup_Show("TUI_IMPORT_PRESET", label or key, nil, key)
end

-- plugin preset queued behind an async profile-name popup; drained on accept/cancel
local function DrainPendingPreset()
    local pk = ns.__afterProfilePreset
    if pk then
        ns.__afterProfilePreset = nil
        ns.ImportPreset(pk)
        E:StaticPopup_Show("IMPORT_RL")
    end
end

-- profile swap keeps thingsUI, any step order works
local function FinishElvProfileImport(key, data)
    local D = E:GetModule("Distributor", true)
    if not (D and D.SetImportedProfile) then return false end
    local keep = ns.DeepCopy(E.db.thingsUI or {})
    ns.SuppressNewProfileAsk = GetTime()
    D:SetImportedProfile("profile", key, data, true)
    E.db.thingsUI = keep
    -- ElvUI keeps this out of profile strings (Distributor blacklist)
    E.db.chat.hideVoiceButtons = true
    if E.StaggeredUpdateAll then E:StaggeredUpdateAll() end
    DrainPendingPreset()
    return true
end

E.PopupDialogs["TUI_IMPORT_PROFILE_NAME"] = {
    text = "|cFF8080FFthingsUI|r: Profile '%s' already exists.\nChoose a new name, or accept to overwrite it.",
    button1 = ACCEPT, button2 = CANCEL,
    hasEditBox = 1, editBoxWidth = 350, maxLetters = 127,
    OnAccept = function(frame, data)
        FinishElvProfileImport(frame.editBox:GetText(), data.data)
    end,
    OnCancel = function() DrainPendingPreset() end,
    EditBoxOnTextChanged = function(frame)
        frame:GetParent().button1:SetEnabled(frame:GetText() ~= "")
    end,
    OnShow = function(frame, data)
        frame.editBox:SetText(data.key)
        frame.editBox:SetFocus()
    end,
    timeout = 0, whileDead = 1, hideOnEscape = true, preferredIndex = 3,
}

local function DecodeProfileStr(key, res)
    local s = ns.InstallString(key .. "_PROFILE", res or Res())
    local D = E:GetModule("Distributor", true)
    if not (s and D and D.Decode) then return end
    local ptype, name, data = D:Decode(s)
    if ptype == "profile" and name and type(data) == "table" then return name, data end
end

local function HasElvProfile(name)
    return name and _G.ElvDB and _G.ElvDB.profiles and _G.ElvDB.profiles[name] and true or false
end

-- both profiles with their thingsUI layout; the one this spec uses ends active
function ns.InstallElvProfiles(res, overwrite)
    local main = ns.Setup and ns.Setup.SpecPackKey and ns.Setup.SpecPackKey() or "NHT"
    local order = (main == "FHT") and { "NHT", "FHT" } or { "FHT", "NHT" }
    local n = 0
    for _, key in ipairs(order) do
        local name, data = DecodeProfileStr(key, res)
        if name and (overwrite or not HasElvProfile(name)) then
            FinishElvProfileImport(name, data)
            ns.ImportPreset(key, res)
            n = n + 1
        end
    end
    local mname = DecodeProfileStr(main, res)
    if HasElvProfile(mname) and E.data:GetCurrentProfile() ~= mname then E.data:SetProfile(mname) end
    return n
end

function ns.ImportElvProfile(s)
    local D = E:GetModule("Distributor", true)
    if not (D and D.Decode and D.SetImportedProfile) then return false end
    local ptype, key, data = D:Decode(s)
    if ptype ~= "profile" or not key or type(data) ~= "table" then return false end
    if _G.ElvDB and _G.ElvDB.profiles and _G.ElvDB.profiles[key] then
        E:StaticPopup_Show("TUI_IMPORT_PROFILE_NAME", key, nil, { key = key, data = data })
        return true, true
    end
    return FinishElvProfileImport(key, data)
end

-- never overwrites an existing private profile
local PRIVATE_NAME = "Private things"
function ns.ImportElvPrivate(s)
    local D = E:GetModule("Distributor", true)
    if not (D and D.Decode) then return false end
    local ptype, _, data = D:Decode(s)
    if ptype ~= "private" or type(data) ~= "table" then return false end
    local sv = _G.ElvPrivateDB
    if not sv then return false end
    sv.profiles = sv.profiles or {}
    if not sv.profiles[PRIVATE_NAME] then
        sv.profiles[PRIVATE_NAME] = E:FilterTableFromBlacklist(data, D.blacklistedKeys.private)
    end
    sv.profileKeys = sv.profileKeys or {}
    sv.profileKeys[E.mynameRealm] = PRIVATE_NAME
    return true
end

ns.PRESET_LIST = {}
for _, p in ipairs(PRESETS) do ns.PRESET_LIST[#ns.PRESET_LIST + 1] = { key = p.key, label = p.label } end

-- ActionBars layouts
local L, R = -206, 207
local function M(x, y) return ("BOTTOM,ElvUIParent,BOTTOM,%d,%d"):format(x, y) end
local SIX = { bar1 = true, bar2 = true, bar3 = true, bar4 = true, bar5 = true, bar6 = true }
local FOUR = { bar1 = true, bar2 = true, bar3 = true, bar4 = true, bar5 = false, bar6 = false }
local AB_LAYOUTS = {
    {   -- 6 bars: left col 1/2/3, right col 4/5/6
        name = "6 Bars: 1-4 / 2-5 / 3-6",
        enables = SIX,
        movers = {
            ElvAB_1 = M(L, 70), ElvAB_2 = M(L, 36), ElvAB_3 = M(L, 2),
            ElvAB_4 = M(R, 70), ElvAB_5 = M(R, 36), ElvAB_6 = M(R, 2),
        },
    },
    {   -- 6 bars: pairs per row 1-2 / 3-4 / 5-6
        name = "6 Bars: 1-2 / 3-4 / 5-6",
        enables = SIX,
        movers = {
            ElvAB_1 = M(L, 70), ElvAB_2 = M(R, 70),
            ElvAB_3 = M(L, 36), ElvAB_4 = M(R, 36),
            ElvAB_5 = M(L, 2),  ElvAB_6 = M(R, 2),
        },
    },
    {   -- 4 bars: rows 1-2 / 3-4
        name = "4 Bars: 1-2 / 3-4",
        enables = FOUR,
        movers = {
            ElvAB_1 = M(L, 36), ElvAB_2 = M(R, 36),
            ElvAB_3 = M(L, 2),  ElvAB_4 = M(R, 2),
        },
    },
    {   -- 4 bars: columns 1/2 left, 3/4 right
        name = "4 Bars: 1-3 / 2-4",
        enables = FOUR,
        movers = {
            ElvAB_1 = M(L, 36), ElvAB_3 = M(R, 36),
            ElvAB_2 = M(L, 2),  ElvAB_4 = M(R, 2),
        },
    },
}

local function ApplyABLayout(layout)
    if not layout then return end
    for bar, on in pairs(layout.enables or {}) do
        if E.db.actionbar[bar] then E.db.actionbar[bar].enabled = on end
    end
    for k, v in pairs(layout.movers or {}) do E.db.movers[k] = v end
    local AB = E:GetModule("ActionBars", true)
    if AB and AB.UpdateButtonSettings then AB:UpdateButtonSettings() end
    if E.UpdateMoverPositions then E:UpdateMoverPositions() end
end

local function StepDone(msg)
    local f = _G.PluginInstallStepComplete
    if f then f.message = msg; f:Show() end
end

local function InstallComplete()
    Store().installComplete = true
    ReloadUI()
end

local function PIF() return _G.PluginInstallFrame end

local function IsInstalled(addon)
    local name, _, _, _, reason = C_AddOns.GetAddOnInfo(addon)
    return name ~= nil and reason ~= "MISSING"
end
local function IsEnabled(addon) return E.IsAddOnEnabled and E:IsAddOnEnabled(addon) end

local UF_GROUP_UNITS = { "party", "raid1", "raid2", "raid3" }
local function SetElvUFGroups(on)
    for _, u in ipairs(UF_GROUP_UNITS) do
        local cfg = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units[u]
        if cfg then cfg.enable = on end
    end
end
function ns.UseElvUF()
    SetElvUFGroups(true)
    if IsInstalled("Grid2") then C_AddOns.DisableAddOn("Grid2", E.myguid) end
    print("|cFF8080FFthingsUI|r - ElvUI UnitFrames enabled, Grid2 disabled. |cFFFFFF00Reload required.|r")
end
function ns.UseGrid2()
    SetElvUFGroups(false)
    if IsInstalled("Grid2") then C_AddOns.EnableAddOn("Grid2", E.myguid) end
    print("|cFF8080FFthingsUI|r - Grid2 enabled, ElvUI raid frames disabled. |cFFFFFF00Reload required.|r")
end

function ns.DisableBCM()
    C_AddOns.DisableAddOn("BetterCooldownManager", E.myguid)
    print("|cFF8080FFthingsUI|r - BetterCooldownManager disabled. |cFFFFFF00Reload required.|r")
end

function ns.SetDamageMeterProvider(provider)
    E.db.thingsUI.damageMeter = E.db.thingsUI.damageMeter or {}
    E.db.thingsUI.damageMeter.provider = provider
    local hasDetails = IsInstalled("Details")
    if provider == "TUI" then
        if hasDetails then C_AddOns.DisableAddOn("Details", E.myguid) end
        pcall(SetCVar, "damageMeterEnabled", "0")
        print("|cFF8080FFthingsUI|r - Mini Meter selected" .. (hasDetails and ", Details! disabled." or ".") .. " |cFFFFFF00Reload required.|r")
    else
        if hasDetails then C_AddOns.EnableAddOn("Details", E.myguid) end
        pcall(SetCVar, "damageMeterEnabled", "1")
        print("|cFF8080FFthingsUI|r - Details! selected" .. (hasDetails and "." or " |cFFFF6060(not installed)|r.") .. " |cFFFFFF00Reload required.|r")
    end
    if TUI.UpdateTUIMeter then TUI:UpdateTUIMeter() end
    if ns.MoverSync and ns.MoverSync.Queue then ns.MoverSync.Queue() end
end

function ns.GetDamageMeterProvider()
    local dm = E.db.thingsUI and E.db.thingsUI.damageMeter
    return (dm and dm.provider) or "DETAILS"
end
E.PopupDialogs["TUI_BCM_WARNING"] = {
    text = "|cFF8080FFthingsUI|r: |cFFFFFFFFBetterCooldownManager|r is enabled and conflicts with the Cooldown Manager styling.\nDisable it? (Applies on the reload at the end.)",
    button1 = YES, button2 = NO,
    OnAccept = function() ns.DisableBCM() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

local DETAILS_PROFILE_NAME = "things"
-- imports only when missing, then use on all characters
function ns.EnsureDetailsProfile()
    local s = ns.InstallStrings and ns.InstallStrings.DETAILS_PROFILE
    if not s or s == "" then return false end
    local Det = _G.Details
    if not Det then
        Store().pendingDetailsProfile = true
        return false, true
    end
    if not (Det.GetProfile and Det.ImportProfile) then return false end
    if not Det:GetProfile(DETAILS_PROFILE_NAME, false) then
        Det:ImportProfile(s, DETAILS_PROFILE_NAME)
    elseif Det.ApplyProfile then
        Det:ApplyProfile(DETAILS_PROFILE_NAME)
    end
    Det.always_use_profile = true
    Det.always_use_profile_name = DETAILS_PROFILE_NAME
    if type(Det.always_use_profile_exception) == "table" then
        Det.always_use_profile_exception[UnitName("player")] = nil
    end
    Store().pendingDetailsProfile = nil
    print("|cFF8080FFthingsUI|r - Details profile '" .. DETAILS_PROFILE_NAME .. "' active on all characters.")
    return true
end


function ns.ImportElvExtras()
    local strs = ns.InstallStrings or {}
    local D = E:GetModule("Distributor", true)
    local okP = strs.ELV_PRIVATE and strs.ELV_PRIVATE ~= "" and ns.ImportElvPrivate(strs.ELV_PRIVATE)
    local okG = strs.ELV_GLOBAL and strs.ELV_GLOBAL ~= "" and D and D.ImportProfile and D:ImportProfile(strs.ELV_GLOBAL) or false
    return okP or false, okG or false
end

-- spec profiles, Cooldown Manager, then BigWigs (its popups wait for the user)
local function SetupRest()
    local S = ns.Setup
    if not S then return end
    S.ApplySpecProfiles()
    S.InstallCDM(function() S.InstallBigWigs() end)
end

local function QuickSetup(key)
    local ps = ns.InstallString(key .. "_PROFILE", Res())
    local ok, pending
    if ps then ok, pending = ns.ImportElvProfile(ps) end
    if pending then ns.__afterProfilePreset = key else ns.ImportPreset(key) end
    ns.ImportElvExtras()
    if ns.SetAutoScale then ns.SetAutoScale() end
    if ns.ApplyDarkMode then ns.ApplyDarkMode() end
    ns.SetDamageMeterProvider("TUI")
    E.db.thingsUI.rightChatAsBackground = true
    if IsInstalled("Grid2") then ns.UseGrid2() else ns.UseElvUF() end
    SetupRest()
end

-- healer spec (or Augmentation) = FHT, everything else = NHT
function ns.QuickSetupAuto()
    local spec = GetSpecialization and GetSpecialization()
    local role = spec and GetSpecializationRole and GetSpecializationRole(spec)
    local mainKey = ns.Setup and ns.Setup.SpecPackKey and ns.Setup.SpecPackKey() or ((role == "HEALER") and "FHT" or "NHT")
    local otherKey = (mainKey == "FHT") and "NHT" or "FHT"

    local oname, odata = DecodeProfileStr(otherKey)
    if oname and not HasElvProfile(oname) then FinishElvProfileImport(oname, odata) end
    local mname, mdata = DecodeProfileStr(mainKey)
    if mname then
        if HasElvProfile(mname) then
            if E.data:GetCurrentProfile() ~= mname then E.data:SetProfile(mname) end
        else
            FinishElvProfileImport(mname, mdata)
        end
    end

    ns.ImportElvExtras()

    ns.ImportPreset(mainKey)
    if ns.SetAutoScale then ns.SetAutoScale() end
    if ns.ApplyDarkMode then ns.ApplyDarkMode() end
    ns.SetDamageMeterProvider("TUI")
    E.db.thingsUI.rightChatAsBackground = true
    if IsInstalled("Grid2") then ns.UseGrid2() else ns.UseElvUF() end
    SetupRest()
    return mainKey, role
end

E.PopupDialogs["TUI_CDMSKIN_WARNING"] = {
    text = "|cFF8080FFthingsUI|r: ElvUI's |cFFFFFFFFCooldown Manager skin|r is disabled for this character.\nthingsUI's CDM styling is built on top of it - enable it and reload?",
    button1 = "Enable",
    button2 = "Ignore Warning",
    OnAccept = function()
        local skins = E.private and E.private.skins and E.private.skins.blizzard
        if skins then skins.cooldownManager = true end
        ReloadUI()
    end,
    OnCancel = function() Store().cdmSkinIgnore = true end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

ns.installTable = {
    Name  = "|cFF8080FFthingsUI|r",
    Title = "|cFF8080FFthingsUI|r Installation",
    tutorialImage = [[Interface\AddOns\ElvUI_thingsUI\tui_options_banner]],
    tutorialImageSize = { 198, 60 },
    tutorialImagePoint = { 0, 208 },
    Pages = {
        -- 1: Quick setup
        function()
            local f = PIF()
            f.SubTitle:SetText("Quick Setup")
            f.Desc1:SetText("One click sets up everything like I have it" .. (IsInstalled("|cFFFFFEE1UF: Grid2|r") and " (Grid2)" or " (ElvUI)") .. ".")
            f.Desc2:SetText("Continue to pick stuff yourself.")
            f.Desc3:SetText("")
            local defs = {
                { key = "NHT", label = "Quick |cFFff0000NHT|r Setup" },
                { key = "FHT", label = "Quick |cFF00ff17FHT|r Setup" },
            }
            for i, d in ipairs(defs) do
                local opt = f["Option" .. i]
                opt:Show(); opt:Enable(); opt:SetText(d.label)
                opt:SetScript("OnClick", function()
                    -- surface errors without stranding the wizard mid-page
                    local ok, err = pcall(QuickSetup, d.key)
                    if not ok then
                        geterrorhandler()(err)
                        print("|cFF8080FFthingsUI|r - Quick setup hit an error (see BugSack); parts may not have applied.")
                    end
                    StepDone(d.key .. " done - accept BigWigs' popups, then Finished")
                    local fr = PIF()
                    if PI.SetPage and fr and fr.CurrentPage then
                        PI:SetPage(#ns.installTable.Pages, fr.CurrentPage)
                    end
                end)
            end
            local auto = f.Option3
            auto:Show(); auto:Enable(); auto:SetText("Everything!")
            auto:SetScript("OnClick", function()
                local ok, key = pcall(ns.QuickSetupAuto)
                if not ok then
                    geterrorhandler()(key)
                    print("|cFF8080FFthingsUI|r - Quick setup hit an error (see BugSack); parts may not have applied.")
                    key = nil
                end
                StepDone((key or "Quick") .. " done - accept BigWigs' popups, then Finished")
                local fr = PIF()
                if PI.SetPage and fr and fr.CurrentPage then
                    PI:SetPage(#ns.installTable.Pages, fr.CurrentPage)
                end
            end)
        end,
        -- 2: Plugin import
        function()
            local f = PIF()
            f.SubTitle:SetText("Plugin things")
            f.Desc1:SetText("Import the thingsUI plugin layout (custom groups, aura bars/icons, timers, bar setup).")
            for i, p in ipairs(PRESETS) do
                local opt = f["Option" .. i]
                if opt then
                    opt:Show(); opt:Enable(); opt:SetText("Import " .. p.label)
                    opt:SetScript("OnClick", function()
                        local ok, err = ns.ImportPreset(p.key, Res())
                        StepDone(ok and (p.label .. " imported") or ("Import failed: " .. (err or "?")))
                    end)
                end
            end
        end,
        -- 3: ElvUI profile
        function()
            local f = PIF()
            f.SubTitle:SetText("ElvUI Profile")
            f.Desc1:SetText("Import the ElvUI profile.")
            f.Desc2:SetText("Your imported thingsUI layout is carried over to the new profile.")
            local defs = {
                { key = "NHT_PROFILE", label = "|cFFff0000NHT|r Profile" },
                { key = "FHT_PROFILE", label = "|cFF00ff17FHT|r Profile" },
            }
            for i, d in ipairs(defs) do
                local opt = f["Option" .. i]
                if opt then
                    opt:Show(); opt:Enable(); opt:SetText("Import " .. d.label)
                    opt:SetScript("OnClick", function()
                        local s = ns.InstallString(d.key, Res())
                        if not s then StepDone("Profile string not set yet") return end
                        local ok, pending = ns.ImportElvProfile(s)
                        StepDone(ok and (pending and "Name exists - pick one in the popup" or (d.label .. " imported"))
                            or "Import failed")
                    end)
                end
            end
        end,
        -- 4: Private + Global + Alt Presets
        function()
            local f = PIF()
            f.SubTitle:SetText("Account Settings")
            f.Desc1:SetText("|cFFFFFFFFPrivate|r (per character: fonts, skins, chat bubbles) \n |cFFFFFFFFGlobal|r (datatext panels).")
            f.Desc2:SetText("Spec Profiles: ElvUI and BigWigs use FHT on healer specs (and Augmentation), NHT on the rest.")
            f.Desc3:SetText("Applies on the reload at the end.")
            f.Option1:Show(); f.Option1:Enable(); f.Option1:SetText("Private + Global")
            f.Option1:SetScript("OnClick", function()
                local okP, okG = ns.ImportElvExtras()
                StepDone((okP and okG) and "Private + Global imported" or "Import failed")
            end)
            f.Option2:Show(); f.Option2:Enable(); f.Option2:SetText("Spec Profiles")
            f.Option2:SetScript("OnClick", function()
                local S = ns.Setup
                StepDone((S and S.ApplySpecProfiles()) and "Spec profiles set" or "No NHT/FHT profiles yet")
            end)
        end,
        -- BigWigs + Cooldown Manager
        function()
            local f = PIF()
            local S = ns.Setup
            f.SubTitle:SetText("Boss Mods & Cooldowns")
            f.Desc1:SetText("|cFFFFFFFFBigWigs|r: the NHT and FHT profiles (BigWigs asks once per profile).\n|cFFFFFFFFCooldown Manager|r: Blizzard's layouts for your class, one per spec.")
            f.Desc2:SetText("Character Setup (/tui alt) shows what each character uses and loads it.")
            f.Desc3:SetText("")
            f.Option1:Show(); f.Option1:Enable(); f.Option1:SetText("BigWigs")
            f.Option1:SetScript("OnClick", function()
                StepDone((S and S.InstallBigWigs()) and "Accept BigWigs' popups" or "BigWigs is not loaded")
            end)
            f.Option2:Show(); f.Option2:Enable(); f.Option2:SetText("Cooldown Manager")
            f.Option2:SetScript("OnClick", function()
                StepDone((S and S.InstallCDM()) and "Cooldown Manager layouts installed" or "No layouts for your class")
            end)
            f.Option3:Show(); f.Option3:Enable(); f.Option3:SetText("Character Setup")
            f.Option3:SetScript("OnClick", function() if S then S.Open() end end)
        end,
        -- 3: UI Scale
        function()
            local f = PIF()
            local best = (E.PixelBestSize and E:PixelBestSize()) or 0
            local cur = (E.global and E.global.general and E.global.general.UIScale) or 0
            f.SubTitle:SetText("UI Scale")
            f.Desc1:SetText(("Pixel-perfect scale for your screen (|cFFFFFF00%s|r) is |cFFFFFF00%.4f|r - your current UI Scale is |cFFFFFF00%.4f|r."):format(E.resolution or "?", best, cur))
            f.Desc2:SetText("Set it to the recommended value so everything lines up pixel-perfect. |cFFFF6B6BReload after finishing.|r")
            f.Desc3:SetText("")
            f.Option1:Show(); f.Option1:SetText(("Set Auto Scale (%.4f)"):format(best))
            f.Option1:SetScript("OnClick", function() if ns.SetAutoScale then ns.SetAutoScale() end StepDone("UI Scale set - reload after finishing") end)
        end,
        -- 3: UnitFrame coloring
        function()
            local f = PIF()
            f.SubTitle:SetText("UnitFrame Coloring")
            f.Desc1:SetText("Class-coloured health bars, or dark bars with class-coloured names?")
            f.Desc2:SetText("")
            f.Desc3:SetText("")
            f.Option1:Show(); f.Option1:SetText("Class Colored")
            f.Option1:SetScript("OnClick", function() if ns.ApplyClassColored then ns.ApplyClassColored() end; StepDone("Class Colored") end)
            f.Option2:Show(); f.Option2:Enable(); f.Option2:SetText("Dark Mode")
            f.Option2:SetScript("OnClick", function() if ns.ApplyDarkMode then ns.ApplyDarkMode() end; StepDone("Dark Mode") end)
        end,
        -- 4: Move That Stuff
        function()
            local f = PIF()
            f.SubTitle:SetText("Minimap & Aura Positions")
            f.Desc1:SetText("Move the minimap, auras and DataText panels to the top-right corner?")
            f.Desc2:SetText("Skip to keep your current ElvUI positions.")
            f.Desc3:SetText("")
            f.Option1:Show(); f.Option1:SetText("Move That Stuff")
            f.Option1:SetScript("OnClick", function() if ns.MoveThatStuff then ns.MoveThatStuff() end; StepDone("Moved to top-right") end)
        end,
        -- Damage meter choice
        function()
            local f = PIF()
            local hasDetails = IsInstalled("Details")
            f.SubTitle:SetText("Damage Meter")
            f.Desc1:SetText("Pick your damage meter. Details! gets anchored inside ElvUI's right chat panel.\n |cFF8080FFMini Meter|r uses Blizzard's built-in meter data with thingsUI's look, filling the same panel.")
            f.Desc2:SetText(hasDetails and "Picking the Mini Meter disables the Details! addon." or "|cFFFF6060Details! is not installed - Mini Meter is your option.|r")
            f.Desc3:SetText(hasDetails and "Details! also imports my Details profile ('things', if missing) and sets it for all characters." or "")
            f.Option1:Show(); f.Option1:SetText("Details!")
            if hasDetails then
                f.Option1:Enable()
                f.Option1:SetScript("OnClick", function()
                    ns.SetDamageMeterProvider("DETAILS")
                    E.db.thingsUI.rightChatAsBackground = true
                    if TUI.ApplyDetailsRightChatAnchor then TUI:ApplyDetailsRightChatAnchor() end
                    local _, pending = ns.EnsureDetailsProfile()
                    StepDone(pending and "Details! set - profile imports at next login" or "Details! anchored to right chat")
                end)
            else
                f.Option1:Disable()
                f.Option1:SetScript("OnClick", nil)
            end
            f.Option2:Show(); f.Option2:Enable(); f.Option2:SetText("|cFF8080FFMini Meter|r")
            f.Option2:SetScript("OnClick", function()
                ns.SetDamageMeterProvider("TUI")
                E.db.thingsUI.rightChatAsBackground = true
                StepDone("Ingame Mini Meter OK - reload after finishing")
            end)
        end,
        -- 7: ActionBars style
        function()
            local f = PIF()
            f.SubTitle:SetText("ActionBars Style")
            f.Desc1:SetText("Pick an action bar layout.")
            f.Desc2:SetText("")
            f.Desc3:SetText("")
            local n = math.min(4, #AB_LAYOUTS)
            for i = 1, n do
                local lay = AB_LAYOUTS[i]
                local opt = f["Option" .. i]
                opt:Show(); opt:Enable(); opt:SetText(lay.name)
                opt:SetScript("OnClick", function() ApplyABLayout(lay); StepDone(lay.name) end)
            end

            local pts = {
                { "BOTTOMRIGHT", f, "BOTTOM", -4, 79 }, { "BOTTOMLEFT", f, "BOTTOM", 4, 79 },
                { "BOTTOMRIGHT", f, "BOTTOM", -4, 45 }, { "BOTTOMLEFT", f, "BOTTOM", 4, 45 },
            }
            for i = 1, n do
                local opt = f["Option" .. i]
                opt:SetWidth(180)
                opt:ClearAllPoints()
                opt:SetPoint(unpack(pts[i]))
            end
        end,
        -- 8: Unit Frames (ElvUI UF vs Grid2)
        function()
            local f = PIF()
            local grid2 = IsInstalled("Grid2")
            f.SubTitle:SetText("Raid Frames")
            f.Desc1:SetText("Pick ElvUI's UnitFrames or Grid2\n")
            f.Desc2:SetText(grid2 and "|cFFFFFEE1Grid2 is installed - pick either.|r" or "|cFFFF6B6BGrid2 is not installed - choose ElvUI UnitFrames.|r")
            f.Desc3:SetText(grid2 and "Picked Grid2? Apply a profile afterwards in |cFFFFFFFFthingsUI -> Grid2|r." or "")
            f.Option1:Show(); f.Option1:Enable(); f.Option1:SetText("ElvUI UnitFrames")
            f.Option1:SetScript("OnClick", function() ns.UseElvUF(); StepDone("ElvUI UnitFrames - reload after finishing") end)
            f.Option2:Show(); f.Option2:SetText("Grid2")
            if grid2 then
                f.Option2:Enable()
                f.Option2:SetScript("OnClick", function() ns.UseGrid2(); StepDone("Grid2 - reload after finishing") end)
            else
                f.Option2:Disable()
                f.Option2:SetScript("OnClick", nil)
            end
        end,
        -- 9: Finished
        function()
            local f = PIF()
            f.SubTitle:SetText("All done!")
            f.Desc1:SetText("thingsUI is set up. Re-run this any time from thingsUI -> Share -> Run Installer.")
            f.Desc2:SetText("Click Finished to save and reload.")
            f.Desc3:SetText("")
            f.Option1:Show(); f.Option1:SetText("Finished")
            f.Option1:SetScript("OnClick", InstallComplete)
        end,
    },
    StepTitles = {
        "Quick Setup", "Plugin things", "ElvUI Profile", "Account Settings", "Boss Mods", "Scale", "Coloring", "Positions", "Damage Meter", "ActionBars", "Unit Frames", "Finished",
    },
    StepTitlesColorSelected = { 0.5, 0.5, 1 },
}

local function TweakLayout()
    local f = PIF()
    if not f then return end
    if not f._tuiHideHook then
        f._tuiHideHook = true
        f:HookScript("OnHide", function()
            if f._tuiDescShift then
                f._tuiDescShift = nil
                f.Desc1:ClearAllPoints()
                f.Desc1:SetPoint("TOPLEFT", 20, -75)
            end
        end)
    end
    if not f._tuiDescShift then
        f._tuiDescShift = true
        f.Desc1:ClearAllPoints()
        f.Desc1:SetPoint("TOPLEFT", 20, -128)
    end
end

do
    local pages = ns.installTable.Pages
    for i, fn in ipairs(pages) do
        pages[i] = function() TweakLayout(); fn() end
    end
end

function ns.OpenInstaller()
    if PI.Queue then PI:Queue(ns.installTable) end
    if IsEnabled("BetterCooldownManager") then
        C_Timer.After(0.5, function() E:StaticPopup_Show("TUI_BCM_WARNING") end)
    end
end
ns.SlashCommand("install", ns.OpenInstaller)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if not Store().installComplete then
        C_Timer.After(2, ns.OpenInstaller)
    end
    C_Timer.After(4, function()
        local st = Store()
        if st.pendingDetailsProfile and _G.Details then ns.EnsureDetailsProfile() end
        if st.installComplete and not st.cdmSkinIgnore then
            local skins = E.private and E.private.skins and E.private.skins.blizzard
            local guid = UnitGUID and UnitGUID("player")
            local autoWill = E.db.thingsUI and E.db.thingsUI.cdmIcons and E.db.thingsUI.cdmIcons.autoEnableCDM
                and not (st.cdmSkinEnabled and guid and st.cdmSkinEnabled[guid])
            if skins and not skins.cooldownManager and not autoWill then
                E:StaticPopup_Show("TUI_CDMSKIN_WARNING")
            end
        end
    end)
end)
ns.LoadMark("install")
