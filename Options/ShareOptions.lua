local _, ns = ...
local TUI = ns.TUI
local E = ns.E

local NotifyChange = ns.NotifyChange

local selected = {}

local function SectionValues()
    local v = {}
    for i, sec in ipairs(ns.Share.SECTIONS) do v[i] = sec.name end
    return v
end

local function ImportProfileString(key, label)
    local s = ns.InstallStrings and ns.InstallStrings[key]
    if not s or s == "" then
        print("|cFF8080FFthingsUI|r: profile string not set yet.")
        return false
    end
    local ok, pending = ns.ImportElvProfile(s)
    print(ok and ("|cFF8080FFthingsUI|r - " .. label .. (pending and ": name exists, pick one in the popup." or " profile imported."))
        or "|cFF8080FFthingsUI|r: import failed.")
    return ok, pending
end

local function FullSetup(order, key, label)
    local profKey = key .. "_PROFILE"
    local profLabel = label .. " ElvUI"
    return {
        order = order, type = "group", inline = true, name = label,
        args = {
            full = {
                order = 1, type = "execute", width = 3.4,
                name = label .. " Full Install",
                confirm = function()
                    return ("Import the full %s setup? This overwrites your ElvUI profile, global/private settings and thingsUI sections."):format(key)
                end,
                func = function()
                    local ok, pending = ImportProfileString(profKey, profLabel)
                    if pending then ns.__afterProfilePreset = key
                    elseif ns.ImportPreset then ns.ImportPreset(key) end
                    if ns.ImportElvExtras then ns.ImportElvExtras() end
                    if ok and not pending then E:StaticPopup_Show("IMPORT_RL") end
                end,
            },
            profile = {
                order = 2, type = "execute", width = 1.7,
                name = label .. " ElvUI Profile",
                confirm = function()
                    return "Import the " .. profLabel .. " profile? This overwrites your current ElvUI profile."
                end,
                func = function()
                    local ok, pending = ImportProfileString(profKey, profLabel)
                    if ok and not pending then E:StaticPopup_Show("IMPORT_RL") end
                end,
            },
            plugin = {
                order = 3, type = "execute", width = 1.7,
                name = label .. " Plugin Stuff",
                func = function()
                    local s = ns.PresetString and ns.PresetString(key)
                    if s and s ~= "" and ns.ShareWizard then
                        ns.ShareWizard.Open(s)
                    elseif ns.ImportPresetConfirm then
                        ns.ImportPresetConfirm(key, label)
                    end
                end,
            },
        },
    }
end

function TUI:ShareOptions()
    local importTab = {
        order = 1, type = "group", name = "Import / Install",
        args = {
            desc = {
                order = 1, type = "description", fontSize = "medium", width = "full",
                name = "\n",
            },
            runInstaller = {
                order = 2, type = "execute", name = "|cFF40FF40Run Installer|r", width = "double",
                hidden = function() return not ns.OpenInstaller end,
                func = function() if ns.OpenInstaller then ns.OpenInstaller() end end,
            },
            runAltSetup = {
                order = 2.2, type = "execute", name = "|cFF8AC8FFAlt Profile Setup|r", width = "double",
                hidden = function() return not (ns.AltInstall and ns.AltInstall.Open) end,
                func = function() ns.AltInstall.Open() end,
            },
            installerBreak = { order = 3, type = "description", width = "full", name = "\n" },

            defaultsHeader = { order = 4, type = "header", name = "Import default presets" },
            defaultsDesc = { order = 5, type = "description",
                name = "Import |cFF8080FFthe ElvUI profile and plugin things|r\n\n" },
            FullNHT = FullSetup(6, "NHT", "|cFFff0000NHT|r"),
            FullFHT = FullSetup(7, "FHT", "|cFF00ff17FHT|r"),

            accountGroup = {
                order = 10, type = "group", inline = true, name = "Account Settings",
                args = {
                    accountDesc = {
                        order = 1, type = "description", width = "full",
                        name = "Standalone pieces of the full setup.\n|cFFFFFFFFPrivate|r = per character (fonts, skins, chat bubbles) - |cFFFFFFFFGlobal|r = account (datatext panels) - |cFFFFFFFFAlt Presets|r = /tuialt profile combos.\n",
                    },
                    importPrivate = {
                        order = 2, type = "execute", width = 1.13, name = "ElvUI Private",
                        confirm = function() return "Import the private settings for this character? Applies on reload." end,
                        func = function()
                            local s = ns.InstallStrings and ns.InstallStrings.ELV_PRIVATE
                            if not s or s == "" then print("|cFF8080FFthingsUI|r: private string not set yet.") return end
                            if ns.ImportElvPrivate(s) then E:StaticPopup_Show("IMPORT_RL")
                            else print("|cFF8080FFthingsUI|r: private import failed.") end
                        end,
                    },
                    importGlobal = {
                        order = 3, type = "execute", width = 1.13, name = "ElvUI Global",
                        confirm = function() return "Import the account-wide global settings (datatext panels etc.)?" end,
                        func = function()
                            local s = ns.InstallStrings and ns.InstallStrings.ELV_GLOBAL
                            local D = E:GetModule("Distributor", true)
                            if not s or s == "" then print("|cFF8080FFthingsUI|r: global string not set yet.") return end
                            if D and D.ImportProfile and D:ImportProfile(s) then E:StaticPopup_Show("IMPORT_RL")
                            else print("|cFF8080FFthingsUI|r: global import failed.") end
                        end,
                    },
                    importAltPresets = {
                        order = 4, type = "execute", width = 1.13, name = "Alt Presets",
                        confirm = function() return "Import the Alt Profile Setup presets (overwrites same-named presets)?" end,
                        func = function()
                            local n = ns.EnsureAltPresets and ns.EnsureAltPresets() or 0
                            print(("|cFF8080FFthingsUI|r - %s"):format(n > 0 and ("imported " .. n .. " alt preset(s).") or "alt preset import failed."))
                        end,
                    },
                },
            },

            importHeader = { order = 20, type = "header", name = "Import" },
            importDesc = {
                order = 21, type = "description", fontSize = "medium", width = "full",
                name = "Opens the importer - paste the string there and pick what you want.\n\n\n",
            },
            importButton = {
                order = 22, type = "execute", name = "Import...", width = "double",
                func = function()
                    if ns.ShareWizard then ns.ShareWizard.Open() end
                end,
            },
        },
    }

    local exportTab = {
        order = 2, type = "group", name = "Export",
        args = {
            exportSelectAll = {
                order = 1, type = "execute", name = "Select All", width = 0.8,
                func = function()
                    for i in ipairs(ns.Share.SECTIONS) do selected[i] = true end
                    NotifyChange()
                end,
            },
            exportClearAll = {
                order = 2, type = "execute", name = "Clear All", width = 0.8,
                func = function()
                    wipe(selected)
                    NotifyChange()
                end,
            },
            exportSections = {
                order = 3, type = "multiselect", name = "Sections to include",
                descStyle = "inline",
                values = SectionValues,
                get = function(_, i) return selected[i] == true end,
                set = function(_, i, val) selected[i] = val and true or nil; NotifyChange() end,
            },
            exportButton = {
                order = 4, type = "execute", name = "Generate Export String",
                func = function()
                    local sel, any = {}, false
                    for i in ipairs(ns.Share.SECTIONS) do
                        sel[i] = selected[i] == true
                        if sel[i] then any = true end
                    end
                    if not any then
                        print("|cFF8080FFthingsUI|r: nothing to export - pick at least one section.")
                        return
                    end
                    local s = (ns.Share and ns.Share.Export(sel)) or ""
                    if s == "" then
                        print("|cFF8080FFthingsUI|r: export failed - the picked sections have no saved settings yet.")
                    elseif ns.ShareWizard and ns.ShareWizard.ShowExport then
                        ns.ShareWizard.ShowExport(s)
                    end
                end,
            },
        },
    }

    return {
        order = 40, type = "group", name = "Import - Export - Install", childGroups = "tab",
        args = {
            importTab = importTab,
            exportTab = exportTab,
        },
    }
end
