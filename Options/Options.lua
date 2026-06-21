local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local function Colorize(tab, hex)
    if tab and tab.name then tab.name = "|cFF"..hex..tab.name.."|r" end
    return tab
end

local BANNER_TEX = [[Interface\AddOns\ElvUI_thingsUI\tui_options_banner]]
local BANNER_W, BANNER_H = 198, 60

function TUI.ConfigTable()
    local function withOrder(grp, n) grp.order = n; return grp end
    local modulesGroup = {
        order = 10,
        type = "group",
        name = "Modules",
        childGroups = "tree",
        args = {
            barSetup     = withOrder(Colorize(TUI:BarSetupOptions(),     "FFB060"), 1),
            buffBars     = withOrder(Colorize(TUI:BuffBarsOptions(),     "05D6F2"), 2),
            cdm          = withOrder(Colorize(TUI:CDMIconsOptions(),     "FFD27F"), 3), 
            chargeBar    = withOrder(Colorize(TUI:ChargeBarOptions(),    "C780FF"), 4), 
            classbar     = withOrder(Colorize(TUI:ClassbarModeOptions(), "6FB7FF"), 5),
            customGroups = withOrder(Colorize(TUI:CustomGroupsOptions(), "F20553"), 6),  
            specialBars  = withOrder(Colorize(TUI:SpecialBarsOptions(),  "80FF80"), 7),
            specialIcons = withOrder(Colorize(TUI:SpecialIconsOptions(), "FF80C0"), 8),
            timers       = withOrder(Colorize(TUI:TimersOptions(),       "FFC04D"), 9),
            trinkets     = withOrder(Colorize(TUI:TrinketsOptions(),     "40D0B0"), 10),
        },
    }
    E.Options.args.thingsUI = {
        order = 100,
        type = "group",
        name = "|cFF8080FFthingsUI|r",
        childGroups = "tab",
        args = {
            header = {
                order = 1,
                type = "header",
                name = "|cFF8080FF" .. TUI.version .. "|r",
            },
            banner = {
                order = 2,
                type = "description",
                width = "full",
                name = "",
                image = BANNER_TEX,
                imageWidth = BANNER_W,
                imageHeight = BANNER_H,
                imageCoords = { 0, 1, 0, 1 },
            },
            description = {
                order = 3,
                type = "description",
                name = "",
            },
            toggleMovers = {
                order = 3.5,
                type = "execute",
                width = "single",
                name = "|cFF8080FFToggle thingsUI Mover|r",
                func = function()
                    if ns.MoverSync and ns.MoverSync.ToggleMover then ns.MoverSync.ToggleMover() end
                end,
            },
            toggleActionBars = {
                order = 4,
                type = "execute",
                width = "double",
                name = "|cFF41fc03Toggle Show/Hide ActionBars|r",
                func = function()
                    if InCombatLockdown() then
                        print("|cFFFF00F1thingsUI|r: can't toggle action bars in combat.")
                        return
                    end
                    for _, d in ipairs({ 1, 2, 3, 4, 5, 6 }) do
                        local bar = E.db.actionbar["bar" .. d]
                        if bar then
                            bar.visibility = (bar.visibility == "hide") and "[petbattle]hide;show" or "hide"
                            E.ActionBars:PositionAndSizeBar("bar" .. d)
                        end
                    end
                end,
            },

            modulesTab           = modulesGroup,
            positioningTweaksTab = TUI:PositioningTweaksOptions(),
            fixesAndQoLTab       = TUI:FixesAndQoLOptions(),
            grid2Tab             = TUI:Grid2Options(),
            shareTab             = TUI:ShareOptions(),
        },
    }
end
