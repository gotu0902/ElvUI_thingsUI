local _, ns = ...
local TUI = ns.TUI
local E = ns.E
local EP = ns.EP
local addon = ns.addon

-- Scan + hook CDM children so our OnShow hooks fire when bars appear.
-- We deliberately do NOT call CooldownViewerSettings:Show() here —
-- that path opens the Blizzard EditMode panel system, which calls
-- SetAttribute / RefreshLayout on CDM frames. If that happens during a
-- spec change or level-up (when CDM is already refreshing internally)
-- it taints `wasOnGCDLookup` — a secure Blizzard table — and makes
-- the entire CDM Essential/Utility viewer disappear until /reload.
-- CDM builds its bar frames lazily on the first UNIT_AURA after login;
-- our OnShow hooks in ScanAndHookCDMChildren catch them at that point.
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

    -- Spec change / level-up: release special bars first, THEN wipe tables,
    -- so yoinkedBars is accurate during the release pass. If we wipe first,
    -- ProcessUpdate in BuffBars sees the released bar as a normal buff bar
    -- (yoinkedBars[childFrame] == nil) and renders it as an empty tracked bar.
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function(_, unit)
        if unit ~= "player" then return end
        C_Timer.After(0.5, function()
            -- 1. Release all yoinked special bars back to their original parent
            --    BEFORE wiping shared state tables.
            if ns.SpecialBars and ns.SpecialBars.ReleaseAllSpecialBars then
                ns.SpecialBars.ReleaseAllSpecialBars()
            end

            -- 2. Now it is safe to wipe — no bar is mid-yoink.
            wipe(ns.skinnedBars)
            wipe(ns.yoinkedBars)

            -- 3. Scan for new spec's CDM children and reinitialise.
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