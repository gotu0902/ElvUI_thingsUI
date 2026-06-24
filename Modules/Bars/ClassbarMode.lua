local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local CM = {}
ns.ClassbarMode = CM

local function GetUF() return E and E:GetModule("UnitFrames", true) end

local updateFrame = CreateFrame("Frame")
local eventFrame  = CreateFrame("Frame")
local isDirty     = false
local isEnabled   = false
local playerEntered = false
local lastEnableState = nil

local HookEssential = function() end

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

function CM.IsEnabledForCurrentSpec()
    return GetSpecEntry() ~= nil
end

function CM.IsNHTForCurrentSpec()
    return CM.IsEnabledForCurrentSpec()
end

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
    local essential = _G["EssentialCooldownViewer"]
    essential = (essential and ns.CDMIcons and ns.CDMIcons.GetProxy and ns.CDMIcons.GetProxy(essential)) or essential
    if slot == "ABOVE_CHARGEBAR" then
        local cb = ns.ChargeBar and ns.ChargeBar.GetActiveAnchorFrame and ns.ChargeBar.GetActiveAnchorFrame()
        if cb then return cb, "TOP" end
    end

    if essential then return essential, "TOP" end
    return nil
end

local function GetClusterBounds()
    local essential = _G["EssentialCooldownViewer"]
    local p = (essential and ns.CDMIcons and ns.CDMIcons.GetProxy and ns.CDMIcons.GetProxy(essential)) or essential
    if not p then return nil end
    local left, right = p:GetLeft(), p:GetRight()
    if not left or not right then return nil end
    return left, right
end

local function PlayerFrameClassBarReady()
    local frame = _G.ElvUF_Player
    if not frame then return false end
    local key = frame.ClassBar
    if type(key) ~= "string" then return false end
    local element = frame[key]
    return element and element.IsShown ~= nil
end

local function ApplyEnableState(entry)
    if InCombatLockdown() then return false end
    if not playerEntered then return false end

    local UF = GetUF()
    if not UF or not UF.CreateAndUpdateUF then return false end

    local cb = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.player and E.db.unitframe.units.player.classbar
    if not cb then return false end

    local desired = entry ~= nil
    local desiredKey = desired and "ON" or "OFF"

    cb.enable = desired

    if desiredKey ~= lastEnableState then
        if not PlayerFrameClassBarReady() then
            return false
        end
        local ok = pcall(UF.CreateAndUpdateUF, UF, "player")
        if not ok then
            return false
        end
        lastEnableState = desiredKey

        if ns.BarSetup and ns.BarSetup.ApplyStack then
            ns.BarSetup.ApplyStack()
        end
    end
    return true
end

local function ApplyWidthAndPosition(entry)
end

local function ChargeBarWantsUs()
    local cbDB = E.db.thingsUI and E.db.thingsUI.chargeBar
    if not cbDB or not cbDB.enabled or not cbDB.specs then return false end
    local idx = GetSpecialization and GetSpecialization() or nil
    local id  = idx and select(1, GetSpecializationInfo(idx)) or 0
    if id == 0 then return false end
    local entry = cbDB.specs[tostring(id)]
    return entry and (entry.slot == "ABOVE_CLASSBAR") or false
end

local function UpdateNow()
    if not isEnabled or not playerEntered then return end
    if InCombatLockdown() then return end

    HookEssential() -- re-scan for newly-added trinket / essential children
    local entry = GetSpecEntry()
    if not ApplyEnableState(entry) then return end
    if entry then ApplyWidthAndPosition(entry) end

    if ChargeBarWantsUs() and ns.ChargeBar and ns.ChargeBar.RequestUpdate then
        ns.ChargeBar.RequestUpdate()
    end
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
    if event == "PLAYER_ENTERING_WORLD" then
        playerEntered = true
        C_Timer.After(0.5, MarkDirty)
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        C_Timer.After(0.5, MarkDirty)
    end
end)

HookEssential = function()
    local f = _G["EssentialCooldownViewer"]
    if not f or f._TUI_classbarHooked then return end
    f._TUI_classbarHooked = true
    if type(f.RefreshLayout) == "function" then
        hooksecurefunc(f, "RefreshLayout", function() MarkDirty() end)
    end
end

local hookedConfigureClassBar = false
local function HookConfigureClassBar()
    if hookedConfigureClassBar then return end
    local UF = GetUF()
    if not UF or not UF.Configure_ClassBar then return end
    hookedConfigureClassBar = true
    hooksecurefunc(UF, "Configure_ClassBar", function(_, frame)
        if not isEnabled then return end
        if not frame or frame.unit ~= "player" then return end
        MarkDirty()
    end)
end

function TUI:UpdateClassbarMode()
    local db = E.db.thingsUI.classbarMode
    if db and db.enabled then
        isEnabled = true
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        HookEssential()
        HookConfigureClassBar()

        if playerEntered then
            C_Timer.After(0.2, MarkDirty)
        end
    else
        if playerEntered and not InCombatLockdown() then
            ApplyEnableState(nil)
        end
        isEnabled = false
        isDirty = false
        lastEnableState = nil
        updateFrame:SetScript("OnUpdate", nil)
        eventFrame:UnregisterAllEvents()
    end
end

function CM.RequestUpdate()
    MarkDirty()
end
