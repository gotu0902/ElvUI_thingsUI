-- ClassbarMode
--
-- Per-spec ElvUI classbar enable/positioning. When the current spec is
-- registered, ElvUI's player classbar is enabled, detached, parented to
-- UIParent, and anchored above either BCDM's primary or secondary power bar
-- (per-spec choice). Width inherits from the visible BCDM cluster
-- (EssentialCooldownViewer + trinket bar bounding box).
--
-- DynamicCastBarAnchor consumes ns.ClassbarMode.GetActiveAnchorFrame() so the
-- BCDM cast bar stacks on top of the classbar when one is active.

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
local playerEntered = false -- safe to call CreateAndUpdateUF/Configure_ClassBar
local lastEnableState = nil -- "ON" or "OFF"; tracks what we last applied

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
    local primary   = _G["BCDM_PowerBar"]
    local essential = _G["EssentialCooldownViewer"]

    if slot == "POWER" then
        if essential then return essential, "TOP" end
    else -- SECONDARY (default)
        if primary and primary:IsShown() and primary:GetWidth() > 0 then
            return primary, "TOP"
        end
        if essential then return essential, "TOP" end
    end
    return nil
end

-- Returns the cluster bounding box (left, right) including the trinket bar
-- when it's currently visible beside EssentialCooldownViewer.
local function GetClusterBounds()
    local essential = _G["EssentialCooldownViewer"]
    if not essential then return nil end
    local left, right = essential:GetLeft(), essential:GetRight()
    if not left or not right then return nil end

    local trinket = _G["BCDM_TrinketBar"]
    if trinket and trinket:IsShown() and trinket:GetWidth() > 0 then
        local tl, tr = trinket:GetLeft(), trinket:GetRight()
        if tl and tr then
            if tl < left  then left  = tl end
            if tr > right then right = tr end
        end
    end
    return left, right
end

-- Updates the classbar enable/detach config and (when desired state changed)
-- calls CreateAndUpdateUF so ElvUI rebuilds the player frame.
local function ApplyEnableState(entry)
    if InCombatLockdown() then return false end
    if not playerEntered then return false end

    local UF = GetUF()
    if not UF or not UF.CreateAndUpdateUF then return false end

    local cb = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.player and E.db.unitframe.units.player.classbar
    if not cb then return false end

    local desired = entry ~= nil
    local desiredKey = desired and "ON" or "OFF"

    if desired then
        cb.enable         = true
        cb.detachFromFrame = true
        cb.parent         = "UIPARENT"
    else
        if lastEnableState == "ON" then
            cb.enable = false
        end
    end

    if desiredKey ~= lastEnableState then
        local ok = pcall(UF.CreateAndUpdateUF, UF, "player")
        if not ok then
            -- Styles not registered yet etc — bail and let next dirty retry.
            return false
        end
        lastEnableState = desiredKey

        -- The cast bar may have been anchored to our classbar holder; tell
        -- DynamicCastBarAnchor to re-evaluate so it picks up secondary/primary
        -- power bar after we disable, or our holder after we enable.
        if TUI.InvalidateDynamicCastBarAnchor then
            TUI:InvalidateDynamicCastBarAnchor()
        end
    end
    return true
end

-- Pushes width into the classbar config and asks ElvUI to re-configure the
-- detached holder, then re-anchors the holder to the BCDM cluster.
local function ApplyWidthAndPosition(entry)
    if not entry or not playerEntered then return end

    local frame = _G["ElvUF_Player"]
    local holder = frame and frame.ClassBarHolder
    if not holder then return end

    local db = E.db.thingsUI.classbarMode
    local target, point = GetAnchorTarget(entry.slot or "SECONDARY")
    if not target then return end

    local left, right = GetClusterBounds()
    local clusterWidth = (left and right and right > left) and (right - left) or (target:GetWidth() or 0)

    if clusterWidth and clusterWidth > 0 then
        local desiredWidth = math.floor(clusterWidth + (db.widthOffset or 0) + 0.5)
        local cb = E.db.unitframe.units.player.classbar
        if cb and cb.detachedWidth ~= desiredWidth then
            cb.detachedWidth = desiredWidth
            local UF = GetUF()
            if UF and UF.Configure_ClassBar and frame then
                pcall(UF.Configure_ClassBar, UF, frame)
            end
        end
        holder:SetWidth(desiredWidth)
    end

    -- Use two separate anchor points: LEFT defines the X edge from the
    -- cluster's leftmost frame, BOTTOM defines the Y edge from the actual
    -- target (power bar or essential viewer). This avoids the pixel-snapping
    -- mismatch a center-anchor would cause and respects trinket bar width.
    local essential = _G["EssentialCooldownViewer"]
    local trinket   = _G["BCDM_TrinketBar"]
    local leftAnchor = essential
    if trinket and trinket:IsShown() and trinket:GetWidth() > 0 then
        local tl = trinket:GetLeft()
        local el = essential and essential:GetLeft()
        if tl and el and tl < el then leftAnchor = trinket end
    end
    if not leftAnchor then leftAnchor = target end

    holder:ClearAllPoints()
    holder:SetPoint("LEFT",   leftAnchor, "LEFT", db.xOffset or 0, 0)
    holder:SetPoint("BOTTOM", target,     "TOP",  0,                db.gap or 1)
end

local function UpdateNow()
    if not isEnabled or not playerEntered then return end
    if InCombatLockdown() then return end

    local entry = GetSpecEntry()
    if not ApplyEnableState(entry) then return end
    if entry then ApplyWidthAndPosition(entry) end
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

local function HookEssential()
    local f = _G["EssentialCooldownViewer"]
    if f and not f._TUI_classbarHooked then
        f._TUI_classbarHooked = true
        f:HookScript("OnSizeChanged", function() MarkDirty() end)
    end
    local t = _G["BCDM_TrinketBar"]
    if t and not t._TUI_classbarHooked then
        t._TUI_classbarHooked = true
        t:HookScript("OnSizeChanged", function() MarkDirty() end)
        t:HookScript("OnShow",        function() MarkDirty() end)
        t:HookScript("OnHide",        function() MarkDirty() end)
    end
    local p = _G["BCDM_PowerBar"]
    if p and not p._TUI_classbarHooked then
        p._TUI_classbarHooked = true
        p:HookScript("OnSizeChanged", function() MarkDirty() end)
    end
end

-- Re-apply our position whenever ElvUI reconfigures the classbar (e.g. when
-- the user changes height in the options panel). Without this the holder
-- drifts by 1px after each rebuild because of pixel-snapping rounding.
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
        -- Defer initial apply — first call may run before UnitFrame styles
        -- are registered. The PEW handler will MarkDirty once it's safe.
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
