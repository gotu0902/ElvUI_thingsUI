-- ClassbarMode
--
-- Per-spec ElvUI classbar enable/positioning. When the current spec is
-- registered, ElvUI's player classbar is enabled, detached, parented to
-- UIParent, and anchored above either BCDM's primary or secondary power bar
-- (per-spec choice). Width inherits from EssentialCooldownViewer.
--
-- DynamicCastBarAnchor consumes ns.ClassbarMode.GetActiveAnchorFrame() so the
-- BCDM cast bar stacks on top of the classbar when one is active.

local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local CM = {}
ns.ClassbarMode = CM

local UF = E and E:GetModule("UnitFrames")

local updateFrame = CreateFrame("Frame")
local eventFrame  = CreateFrame("Frame")
local isDirty     = false
local isEnabled   = false
local lastApplied = nil -- cached spec key we last applied for, prevents redundant CreateAndUpdateUF

local function GetCurrentSpecID()
    local idx = GetSpecialization and GetSpecialization() or nil
    return idx and select(1, GetSpecializationInfo(idx)) or 0
end

local function GetSpecEntry()
    local db = E.db.thingsUI.classbarMode
    if not db or not db.enabled or not db.specs then return nil end
    local id = GetCurrentSpecID()
    if id == 0 then return nil end
    return db.specs[tostring(id)]
end

function CM.IsActive()
    return isEnabled and GetSpecEntry() ~= nil
end

-- Returns the frame that the BCDM cast bar should anchor above when classbar
-- mode is active. nil means classbar mode is not contributing an anchor.
function CM.GetActiveAnchorFrame()
    if not CM.IsActive() then return nil end
    local frame = _G["ElvUF_Player"]
    local holder = frame and frame.ClassBarHolder
    if holder and holder:IsShown() and holder:GetWidth() > 0 then
        return holder
    end
    return nil
end

local function GetAnchorTarget(slot)
    local secondary = _G["BCDM_SecondaryPowerBar"]
    local primary   = _G["BCDM_PowerBar"]
    local essential = _G["EssentialCooldownViewer"]

    if slot == "POWER" then
        -- classbar replaces primary power slot: sit on top of essential viewer
        if essential then return essential, "TOP" end
    else -- SECONDARY (default)
        -- classbar sits where the secondary power bar would: above primary
        if primary and primary:IsShown() and primary:GetWidth() > 0 then
            return primary, "TOP"
        end
        if essential then return essential, "TOP" end
    end
    return nil
end

local function ApplyEnableState(entry)
    if InCombatLockdown() then return false end

    local cb = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.player and E.db.unitframe.units.player.classbar
    if not cb then return false end

    local desiredEnable = entry ~= nil
    local desiredDetach = desiredEnable
    local desiredParent = "UIPARENT"

    local changed = false
    if cb.enable ~= desiredEnable then cb.enable = desiredEnable; changed = true end
    if desiredEnable then
        if cb.detachFromFrame ~= desiredDetach then cb.detachFromFrame = desiredDetach; changed = true end
        if cb.parent ~= desiredParent then cb.parent = desiredParent; changed = true end
    end

    if changed and UF and UF.CreateAndUpdateUF then
        UF:CreateAndUpdateUF("player")
    end
    return true
end

local function PositionClassBar(entry)
    if not entry then return end
    local frame = _G["ElvUF_Player"]
    local holder = frame and frame.ClassBarHolder
    if not holder then return end

    local db = E.db.thingsUI.classbarMode
    local target, point = GetAnchorTarget(entry.slot or "SECONDARY")
    if not target then return end

    local essential = _G["EssentialCooldownViewer"]
    local width = essential and essential:GetWidth() or 0
    if width and width > 0 then
        holder:SetWidth(width + (db.widthOffset or 0))
        local cb = E.db.unitframe.units.player.classbar
        if cb then cb.detachedWidth = math.floor(width + (db.widthOffset or 0)) end
    end

    holder:ClearAllPoints()
    holder:SetPoint("BOTTOM", target, point, db.xOffset or 0, db.gap or 1)
end

local function UpdateNow()
    if not isEnabled then return end
    if InCombatLockdown() then return end

    local entry = GetSpecEntry()
    local appliedKey = entry and ((entry.slot or "SECONDARY")..":"..tostring(GetCurrentSpecID())) or "OFF"

    -- Always re-apply position even if enable state didn't change (essential
    -- viewer width may have changed)
    if appliedKey ~= lastApplied then
        if not ApplyEnableState(entry) then return end
        lastApplied = appliedKey
    end

    if entry then PositionClassBar(entry) end
end

local function OnNextFrame(self)
    self:SetScript("OnUpdate", nil)
    isDirty = false
    UpdateNow()
end

local function MarkDirty()
    if not isEnabled then return end
    if isDirty then return end
    isDirty = true
    updateFrame:SetScript("OnUpdate", OnNextFrame)
end
CM.MarkDirty = MarkDirty

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        lastApplied = nil
        C_Timer.After(0.5, MarkDirty)
    end
end)

-- Hook EssentialCooldownViewer size changes to refresh width
local function HookEssential()
    local f = _G["EssentialCooldownViewer"]
    if not f or f._TUI_classbarHooked then return end
    f._TUI_classbarHooked = true
    f:HookScript("OnSizeChanged", function() MarkDirty() end)
end

function TUI:UpdateClassbarMode()
    local db = E.db.thingsUI.classbarMode
    if db and db.enabled then
        isEnabled = true
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        HookEssential()
        lastApplied = nil
        C_Timer.After(0.2, MarkDirty)
    else
        -- Disable: clear our enable so ElvUI returns to its native classbar setting.
        if not InCombatLockdown() then
            ApplyEnableState(nil)
        end
        isEnabled = false
        isDirty = false
        lastApplied = nil
        updateFrame:SetScript("OnUpdate", nil)
        eventFrame:UnregisterAllEvents()
    end
end

function CM.RequestUpdate()
    lastApplied = nil
    MarkDirty()
end
