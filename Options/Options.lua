local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local function Colorize(tab, hex)
    if tab and tab.name then tab.name = "|cFF"..hex..tab.name.."|r" end
    return tab
end

-- Profile Sync in the module list: a green S on what this profile syncs, a grey one on the
-- rest, none at all until sync is set up. part(parts) narrows a Some module to its own share.
local SYNC_ON, SYNC_OFF = "|cFF40FF40S|r|cFF444444 |||r ", "|cFF555555S|r|cFF444444 |||r "
local function SyncMark(tab, ids, part)
    if not (tab and type(tab.name) == "string") then return tab end
    local base = tab.name
    tab.name = function()
        local PS = ns.ProfileSync
        if not (PS and PS.Active()) then return base end
        local on = false
        for _, id in ipairs(ids) do
            local m = PS.Mode(id)
            if m == "all" then
                on = true
            elseif m == "some" then
                local c = PS.Module(id) or {}
                if not part then on = on or (c.parts and next(c.parts) ~= nil) or false
                else on = on or (c.parts and part(c.parts)) or false end
            end
        end
        return (on and SYNC_ON or SYNC_OFF) .. base
    end
    return tab
end

local function AnyPart(keys)
    return function(parts)
        for _, k in ipairs(keys) do if parts[k] then return true end end
        return false
    end
end

local function AnyPartBut(keys)
    local skip = {}
    for _, k in ipairs(keys) do skip[k] = true end
    return function(parts)
        for k in pairs(parts) do if not skip[k] then return true end end
        return false
    end
end


local curSection, weOpenedCDM, userClosedCDM, closingCDM

local CDM_SECTIONS = { cdm = true, spellEditor = true, buffBars = true, customGroups = true, customBars = true, customText = true,
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

local TEST_SECTIONS = { customGroups = true, customBars = true, customText = true, specialIcons = true, specialBars = true }

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
            barSetup     = WithSentinel(withOrder(SyncMark(Colorize(TUI:BarSetupOptions(),     "FFB060"), { "barSetup" }), 1), "barSetup"),
            buffBars     = WithSentinel(withOrder(SyncMark(Colorize(TUI:BuffBarsOptions(),     "05D6F2"), { "buffBars" }), 2), "buffBars"),
            cdm          = WithSentinel(withOrder(SyncMark(Colorize(TUI:CDMIconsOptions(),     "FFD27F"), { "cdmIcons" },
                AnyPartBut({ "perSpell", "perBuff" })), 3), "cdm"),
            chargeBar    = WithSentinel(withOrder(SyncMark(Colorize(TUI:ChargeBarOptions(),    "C780FF"), { "chargeBar" }), 4), "chargeBar"),
            classbar     = WithSentinel(withOrder(SyncMark(Colorize(TUI:ClassbarModeOptions(), "6FB7FF"), { "classbarMode" }), 5), "classbar"),
            customGroups = WithSentinel(withOrder(SyncMark(Colorize(TUI:CustomGroupsOptions(), "F20553"), { "customGroups" }), 6), "customGroups"),
            customBars   = WithSentinel(withOrder(SyncMark(Colorize(TUI:CustomBarsOptions(), "F27D2A"), { "customBars" }), 6.2), "customBars"),
            customText   = WithSentinel(withOrder(SyncMark(Colorize(TUI:CustomTextOptions(), "F2C12E"), { "customText" }), 6.3), "customText"),
            auraCollections = WithSentinel(withOrder(SyncMark(Colorize(TUI:AuraCollectionsOptions(), "B0A0FF"), { "auraCollections" }), 0.5), "auraCollections"),
            damageMeter  = WithSentinel(withOrder(SyncMark(Colorize(TUI:DamageMeterOptions(),  "FF5C5C"), { "damageMeter" }), 5.5), "damageMeter"),
            specialBars  = WithSentinel(withOrder(SyncMark(Colorize(TUI:SpecialBarsOptions(),  "80FF80"), { "specialBars" }), 0.4), "specialBars"),
            specialIcons = WithSentinel(withOrder(SyncMark(Colorize(TUI:SpecialIconsOptions(), "FF80C0"), { "specialBars" }), 0.6), "specialIcons"),
            raidOrder    = WithSentinel(withOrder(SyncMark(Colorize(TUI:RaidOrderOptions(),    "4DD2A6"), { "essentialMover" },
                AnyPart({ "raidOrder" })), 7), "raidOrder"),
            spellEditor  = WithSentinel(withOrder(SyncMark(Colorize(TUI:SpellEditorOptions(),  "FFE9A8"), { "cdmIcons" },
                AnyPart({ "perSpell", "perBuff" })), 3.5), "spellEditor"),
            timers       = WithSentinel(withOrder(SyncMark(Colorize(TUI:TimersOptions(),       "FFC04D"), { "timers" }), 9), "timers"),
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
            syncTab              = WithSentinel(TUI:SyncOptions(), "sync"),
        },
    }
end
ns.LoadMark("options")
