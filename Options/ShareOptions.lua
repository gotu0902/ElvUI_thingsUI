local _, ns = ...
local TUI = ns.TUI
local E = ns.E

local NotifyChange = ns.NotifyChange

local selected = {}   -- [sectionIndex] = true to include; default exclude

local function SectionValues()
    local v = {}
    for i, sec in ipairs(ns.Share.SECTIONS) do v[i] = sec.name end
    return v
end

function TUI:ShareOptions()
    local args = {
            desc = {
                order = 1, type = "description", fontSize = "medium", width = "full",
                name = "Export any sections to a string, or paste one below to import - the importer picks exactly what to bring in (whole sections, only new items, or individual bar setups / custom groups / specials, with per-part overwrite when something already exists).\n",
            },
            runInstaller = {
                order = 2, type = "execute", name = "|cFF40FF40Run Installer|r", width = "double",
                hidden = function() return not ns.OpenInstaller end,
                func = function() if ns.OpenInstaller then ns.OpenInstaller() end end,
            },
            installerBreak = { order = 3, type = "description", width = "full", name = "\n" },

            defaultsHeader = { order = 4, type = "header", name = "Import default presets" },
            defaultsDesc = { order = 5, type = "description",
                name = "Import all |cFF8080FFthingsUI|r stuff, if you want to start with and edit my stuff. |cFFFF6060Overwrites everythings hah.|r\n" },
            defaultsBreak = { order = 7, type = "description", width = "full", name = "\n" },

            exportHeader = { order = 10, type = "header", name = "Export" },
            exportSelectAll = {
                order = 10.1, type = "execute", name = "Select All", width = 0.8,
                func = function()
                    for i in ipairs(ns.Share.SECTIONS) do selected[i] = true end
                    NotifyChange()
                end,
            },
            exportClearAll = {
                order = 10.2, type = "execute", name = "Clear All", width = 0.8,
                func = function()
                    wipe(selected)
                    NotifyChange()
                end,
            },
            exportSections = {
                order = 11, type = "multiselect", name = "Sections to include",
                values = SectionValues,
                get = function(_, i) return selected[i] == true end,
                set = function(_, i, val) selected[i] = val and true or nil; NotifyChange() end,
            },
            exportButton = {
                order = 12, type = "execute", name = "Generate Export String",
                func = function()
                    local sel = {}
                    for i in ipairs(ns.Share.SECTIONS) do sel[i] = selected[i] == true end
                    local s = (ns.Share and ns.Share.Export(sel)) or ""
                    if s == "" then
                        print("|cFF8080FFthingsUI|r: nothing to export - pick at least one section.")
                    elseif ns.ShareWizard and ns.ShareWizard.ShowExport then
                        ns.ShareWizard.ShowExport(s)
                    end
                end,
            },

            importHeader = { order = 20, type = "header", name = "Import" },
            importDesc = {
                order = 21, type = "description", fontSize = "medium", width = "full",
                name = "Opens the importer - paste the string there and pick what to bring in.\n",
            },
            importButton = {
                order = 22, type = "execute", name = "Import...", width = "double",
                func = function()
                    if ns.ShareWizard then ns.ShareWizard.Open() end
                end,
            },
    }

    for i, p in ipairs(ns.PRESET_LIST or {}) do
        args["preset" .. p.key] = {
            order = 5 + i * 0.1, type = "execute", name = "Import " .. p.label,
            func = function()
                local s = ns.PresetString and ns.PresetString(p.key)
                if s and s ~= "" and ns.ShareWizard then
                    ns.ShareWizard.Open(s)
                elseif ns.ImportPresetConfirm then
                    ns.ImportPresetConfirm(p.key, p.label)
                end
            end,
        }
    end

    return { order = 40, type = "group", name = "Share", args = args }
end
