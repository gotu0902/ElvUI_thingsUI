local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local function Colorize(tab, hex)
    if tab and tab.name then tab.name = "|cFF"..hex..tab.name.."|r" end
    return tab
end

function TUI.ConfigTable()
    E.Options.args.thingsUI = {
        order = 100,
        type = "group",
        name = "|cFF8080FFthingsUI|r",
        childGroups = "tab",
        args = {
            header = {
                order = 1,
                type = "header",
                name = "thingsUI v" .. TUI.version,
            },
            description = {
                order = 2,
                type = "description",
                name = "Skin Buff Bars, automatically move frames when using BCDM and CDM icons increase, seperate Tracked Bars with Special Bars o7.\n\n",
            },

            generalTab            = TUI:GeneralOptions(),
            buffBarsTab           = TUI:BuffBarsOptions(),
            clusterPositioningTab = TUI:BCDMElvUIOptions(),
            cdmSpecialsTab        = Colorize(TUI:CDMSpecialsOptions(),  "80FF80"), -- light green
            classbarModeTab       = Colorize(TUI:ClassbarModeOptions(), "6FB7FF"), -- blue
            chargeBarTab          = Colorize(TUI:ChargeBarOptions(),    "C780FF"), -- purple
        },
    }
end
