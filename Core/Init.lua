local _, ns = ...
local TUI = ns.TUI
local E = ns.E
local EP = ns.EP
local addon = ns.addon

local function PrimeAndScanCDM()
    wipe(ns.skinnedBars)
    wipe(ns.yoinkedBars)

    if InCombatLockdown() then
        if not TUI.__cdmRegenHooked then
            TUI.__cdmRegenHooked = true
            TUI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
                TUI:UnregisterEvent("PLAYER_REGEN_ENABLED")
                TUI.__cdmRegenHooked = nil
                C_Timer.After(0.1, PrimeAndScanCDM)
            end)
        end
        return
    end

    if ns.SpecialBars and ns.SpecialBars.ScanAndHookCDMChildren then
        ns.SpecialBars.ScanAndHookCDMChildren()
    end

    if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
    C_Timer.After(1, PrimeAndScanCDM)
end)


function TUI:Initialize()
    EP:RegisterPlugin(addon, TUI.ConfigTable)

    -- Clean slate
    wipe(ns.skinnedBars)
    wipe(ns.yoinkedBars)

    -- Initialize all modules — each registers its own events
    self:UpdateVerticalBuffs()
    self:UpdateBuffBars()
    self:UpdateSpecialBars()
    self:UpdateClusterPositioning()
    self:UpdateDynamicCastBarAnchor()

    -- On entering world, give CDM time to create its frames then refresh
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(2, function()
            wipe(ns.skinnedBars)
            wipe(ns.yoinkedBars)
            PrimeAndScanCDM()

            if ns.SpecialBars and ns.SpecialBars.ScanAndHookCDMChildren then
                ns.SpecialBars.ScanAndHookCDMChildren()
            end

            if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
        end)
    end)

    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function(_, unit)
        if unit ~= "player" then return end
        -- I Init.lua, PLAYER_SPECIALIZATION_CHANGED
        C_Timer.After(1.5, function()
            if ns.SpecialBars and ns.SpecialBars.ReleaseAllSpecialBars then
                ns.SpecialBars.ReleaseAllSpecialBars()
            end
            
            if ns.SpecialBars then
                if ns.SpecialBars.trackedBarsByName then
                    wipe(ns.SpecialBars.trackedBarsByName)
                end
                if ns.SpecialBars.hookedCDMChildren then
                    wipe(ns.SpecialBars.hookedCDMChildren)
                end
            end
            
            wipe(ns.skinnedBars)
            wipe(ns.yoinkedBars)
            PrimeAndScanCDM()
            TUI:UpdateSpecialBars()
            TUI:UpdateBuffBars()
        end)
    end)

    print("|cFF8080FFElvUI_thingsUI|r v" .. self.version .. " loaded - Config in /elvui -> thingsUI")
end

function TUI:ProfileUpdate()
    wipe(ns.skinnedBars)
    wipe(ns.yoinkedBars)
    self:UpdateVerticalBuffs()
    self:UpdateBuffBars()
    self:UpdateSpecialBars()
    self:UpdateClusterPositioning()
    self:UpdateDynamicCastBarAnchor()
end

local function OnProfileChanged()
    TUI:ProfileUpdate()
end

hooksecurefunc(E, "UpdateAll", OnProfileChanged)

E:RegisterModule(TUI:GetName())