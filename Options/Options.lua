local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local function Colorize(tab, hex)
    if tab and tab.name then tab.name = "|cFF"..hex..tab.name.."|r" end
    return tab
end

local curSection, weOpenedCDM, userClosedCDM, closingCDM

local CDM_SECTIONS = { cdm = true, spellEditor = true, buffBars = true, customGroups = true, customBars = true,
    specialIcons = true, specialBars = true }

-- closed by hand on one of our CDM pages: it stays closed until the options close
local cvsHooked = false
local function HookCDMClose(cvs)
    if cvsHooked then return end
    cvsHooked = true
    cvs:HookScript("OnHide", function()
        if not closingCDM and curSection and CDM_SECTIONS[curSection] then userClosedCDM = true end
        weOpenedCDM = nil
    end)
end

local function OpenCDMSettings()
    if InCombatLockdown() or userClosedCDM then return end
    local cvs = _G.CooldownViewerSettings
    if cvs and cvs.ShowUIPanel and not cvs:IsShown() then
        HookCDMClose(cvs)
        weOpenedCDM = true
        cvs:ShowUIPanel()
    end
end

local function CloseCDMSettings()
    if not weOpenedCDM then return end
    weOpenedCDM = nil
    if InCombatLockdown() then return end
    local cvs = _G.CooldownViewerSettings
    if cvs and cvs:IsShown() then
        closingCDM = true
        HideUIPanel(cvs)
        closingCDM = nil
    end
end

local watchTicker
local function StopSectionWatch()
    if watchTicker then
        watchTicker:Cancel()
        watchTicker = nil
    end
end

local function OnConfigClosed()
    curSection = nil
    userClosedCDM = nil
    StopSectionWatch()
    if ns.CustomGroups and ns.CustomGroups.SetTestReason then
        ns.CustomGroups.SetTestReason("options", false)
    end
    CloseCDMSettings()
end

local function StillInThingsUI()
    local ACD = E.Libs and E.Libs.AceConfigDialog
    local st = ACD and ACD.GetStatusTable and ACD:GetStatusTable("ElvUI")
    local sel = st and st.groups and st.groups.selected
    if type(sel) ~= "string" then return true end
    return sel == "thingsUI" or sel:sub(1, 9) == "thingsUI\001"
end

local function StartSectionWatch()
    if watchTicker then return end
    watchTicker = C_Timer.NewTicker(0.3, function()
        if not curSection then
            StopSectionWatch()
            return
        end
        if not StillInThingsUI() then
            curSection = nil
            StopSectionWatch()
            if ns.CustomGroups and ns.CustomGroups.SetTestReason then
                ns.CustomGroups.SetTestReason("options", false)
            end
            CloseCDMSettings()
        end
    end)
end

local hookedWindows = setmetatable({}, { __mode = "k" })
local function EnsureCloseHook()
    local frame = E.Config_GetWindow and E:Config_GetWindow()
    if frame and not hookedWindows[frame] then
        hookedWindows[frame] = true
        frame:HookScript("OnHide", OnConfigClosed)
    end
end

local TEST_SECTIONS = { customGroups = true, customBars = true, specialIcons = true, specialBars = true }

local function SectionShown(key)
    EnsureCloseHook()
    StartSectionWatch()
    if _G.CooldownViewerSettings then HookCDMClose(_G.CooldownViewerSettings) end
    if key == curSection then return end
    local prev = curSection
    curSection = key
    if ns.CustomGroups and ns.CustomGroups.SetTestReason then
        ns.CustomGroups.SetTestReason("options", TEST_SECTIONS[key] or false)
    end
    if CDM_SECTIONS[key] then
        OpenCDMSettings()
    elseif prev and CDM_SECTIONS[prev] then
        CloseCDMSettings()
    end
end

local function WithSentinel(grp, key)
    if grp and grp.args then
        grp.args._section = {
            order = 0, type = "description",
            name = function() SectionShown(key) return "" end,
        }
    end
    return grp
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
            barSetup     = WithSentinel(withOrder(Colorize(TUI:BarSetupOptions(),     "FFB060"), 1), "barSetup"),
            buffBars     = WithSentinel(withOrder(Colorize(TUI:BuffBarsOptions(),     "05D6F2"), 2), "buffBars"),
            cdm          = WithSentinel(withOrder(Colorize(TUI:CDMIconsOptions(),     "FFD27F"), 3), "cdm"),
            chargeBar    = WithSentinel(withOrder(Colorize(TUI:ChargeBarOptions(),    "C780FF"), 4), "chargeBar"),
            classbar     = WithSentinel(withOrder(Colorize(TUI:ClassbarModeOptions(), "6FB7FF"), 5), "classbar"),
            customGroups = WithSentinel(withOrder(Colorize(TUI:CustomGroupsOptions(), "F20553"), 6), "customGroups"),
            customBars   = WithSentinel(withOrder(Colorize(TUI:CustomBarsOptions(), "F27D2A"), 6.2), "customBars"),
            auraCollections = WithSentinel(withOrder(Colorize(TUI:AuraCollectionsOptions(), "B0A0FF"), 0.5), "auraCollections"),
            damageMeter  = WithSentinel(withOrder(Colorize(TUI:DamageMeterOptions(),  "FF5C5C"), 5.5), "damageMeter"),
            specialBars  = WithSentinel(withOrder(Colorize(TUI:SpecialBarsOptions(),  "80FF80"), 0.4), "specialBars"),
            specialIcons = WithSentinel(withOrder(Colorize(TUI:SpecialIconsOptions(), "FF80C0"), 0.6), "specialIcons"),
            raidOrder    = WithSentinel(withOrder(Colorize(TUI:RaidOrderOptions(),    "4DD2A6"), 7), "raidOrder"),
            spellEditor  = WithSentinel(withOrder(Colorize(TUI:SpellEditorOptions(),  "FFE9A8"), 3.5), "spellEditor"),
            timers       = WithSentinel(withOrder(Colorize(TUI:TimersOptions(),       "FFC04D"), 9), "timers"),
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
            positioningTweaksTab = WithSentinel(TUI:PositioningTweaksOptions(), "positioning"),
            fixesAndQoLTab       = WithSentinel(TUI:FixesAndQoLOptions(), "fixes"),
            grid2Tab             = WithSentinel(TUI:Grid2Options(), "grid2"),
            shareTab             = WithSentinel(TUI:ShareOptions(), "share"),
        },
    }
end
ns.LoadMark("options")
