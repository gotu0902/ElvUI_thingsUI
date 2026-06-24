local _, ns = ...
local TUI = ns.TUI
local E   = ns.E

ns.EditModeLock = ns.EditModeLock or {}
local M = ns.EditModeLock

local LOCKED_VIEWERS = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "BuffBarCooldownViewer",
}

local installed = false
local noticeShown = false

local function IsLockEnabled()
    local db = E.db.thingsUI and E.db.thingsUI.cdmIcons
    return (db == nil) or (db.editModeLock ~= false)
end

local function ShowNotice()
    if noticeShown then return end
    noticeShown = true
    print("|cFF8080FFthingsUI|r - CDM viewers are locked in Edit Mode. Use the thingsUI options to configure them.")
end

local function IsCooldownViewerSystemFrame(frame)
    local cooldownSystem = Enum and Enum.EditModeSystem and Enum.EditModeSystem.CooldownViewer
    return cooldownSystem and frame and frame.system == cooldownSystem
end

local function LockViewer(viewer)
    if not viewer then return end
    if viewer.SetMovable then
        viewer:SetMovable(false)
    end

    local selection = viewer.Selection
    if selection then
        selection:SetScript("OnDragStart", nil)
        selection:SetScript("OnDragStop", nil)

        if not selection._tuiHidden then
            selection._tuiHidden = true
            hooksecurefunc(selection, "Show", function(s)
                if IsLockEnabled() then s:Hide() end
            end)
        end
        if IsLockEnabled() then selection:Hide() end
    end
end

local function LockAll()
    for _, name in ipairs(LOCKED_VIEWERS) do
        LockViewer(_G[name])
    end
end

local function HookEditMode()
    local dialog = _G.EditModeSystemSettingsDialog
    if not dialog or not dialog.AttachToSystemFrame then return false end

    hooksecurefunc(dialog, "AttachToSystemFrame", function(self, systemFrame)
        if not IsCooldownViewerSystemFrame(systemFrame) then return end
        self:Hide()
        ShowNotice()
    end)

    LockAll()
    return true
end

function M.Apply()
    if installed then
        LockAll()
        return
    end

    if HookEditMode() then
        installed = true
        return
    end

    if EventUtil and EventUtil.ContinueOnAddOnLoaded then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", function()
            if HookEditMode() then installed = true end
        end)
    end
end

function TUI:UpdateEditModeLock()
    if not IsLockEnabled() then return end
    M.Apply()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")

    C_Timer.After(0.5, function() M.Apply() end)
end)
