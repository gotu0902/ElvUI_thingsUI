local _, ns = ...
local TUI = ns.TUI
local E = ns.E

local NotifyChange = ns.NotifyChange

local exportCache  = ""
local importBuffer = ""
local selected     = {}   -- [sectionIndex] = false to exclude; default include

local function SectionValues()
    local v = {}
    for i, sec in ipairs(ns.Share.SECTIONS) do v[i] = sec.name end
    return v
end

function TUI:ShareOptions()
    local args = {
            desc = {
                order = 1, type = "description", fontSize = "medium", width = "full",
                name = "Currently no merge feature or module copy, need to learn how that works first.\n",
            },
            runInstaller = {
                order = 2, type = "execute", name = "|cFF40FF40Run Installer|r", width = "double",
                hidden = function() return not ns.OpenInstaller end,
                func = function() if ns.OpenInstaller then ns.OpenInstaller() end end,
            },
            installerBreak = { order = 3, type = "description", width = "full", name = "\n" },

            defaultsHeader = { order = 4, type = "header", name = "thingsUI Defaults" },
            defaultsDesc = { order = 5, type = "description",
                name = "Import a |cFF8080FFthingsUI|r layout for a raid tier. |cFFFF6060Overwrites your current thingsUI sections.|r\n" },
            defaultsBreak = { order = 7, type = "description", width = "full", name = "\n" },

            exportHeader = { order = 10, type = "header", name = "Export" },
            exportSections = {
                order = 11, type = "multiselect", name = "Sections to include",
                values = SectionValues,
                get = function(_, i) return selected[i] ~= false end,
                set = function(_, i, val) selected[i] = val; exportCache = ""; NotifyChange() end,
            },
            exportButton = {
                order = 12, type = "execute", name = "Generate Export String",
                func = function()
                    exportCache = (ns.Share and ns.Share.Export(selected)) or ""
                    if exportCache == "" then
                        print("|cFF8080FFthingsUI|r: nothing to export - pick at least one section.")
                    end
                    NotifyChange()
                end,
            },
            exportBox = {
                order = 13, type = "input", multiline = 10, width = "full",
                name = "Select all (Ctrl+A) + copy (Ctrl+C):",
                hidden = function() return exportCache == "" end,
                get = function() return exportCache end,
                set = function() end,
            },

            importHeader = { order = 20, type = "header", name = "Import" },
            importBox = {
                order = 21, type = "input", multiline = 10, width = "full",
                name = "Paste an export string here:",
                get = function() return importBuffer end,
                set = function(_, v) importBuffer = v or "" end,
            },
            importButton = {
                order = 22, type = "execute", name = "Import & Reload",
                disabled = function() return (importBuffer or ""):gsub("%s", "") == "" end,
                confirm = function()
                    local secs = ns.Share and ns.Share.SectionsInString(importBuffer)
                    local list = (secs and #secs > 0) and table.concat(secs, ", ") or "?"
                    return "Replace these sections: " .. list .. "\n(Other settings stay.) Reloads after. Continue?"
                end,
                func = function()
                    local ok, err = ns.Share and ns.Share.Import(importBuffer)
                    if ok then
                        importBuffer = ""
                        ReloadUI()
                    else
                        print("|cFF8080FFthingsUI|r: import failed - " .. (err or "unknown error"))
                    end
                end,
            },
    }

    for i, p in ipairs(ns.PRESET_LIST or {}) do
        args["preset" .. p.key] = {
            order = 5 + i * 0.1, type = "execute", name = "Import " .. p.label,
            func = function() if ns.ImportPresetConfirm then ns.ImportPresetConfirm(p.key, p.label) end end,
        }
    end

    return { order = 40, type = "group", name = "Share", args = args }
end
