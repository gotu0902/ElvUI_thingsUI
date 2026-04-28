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
    elseif slot == "ABOVE_CHARGEBAR" then
        -- Stack on top of the Charge Bar frame. Falls back if Charge Bar isn't
        -- active on this spec (the dropdown should hide this choice in that
        -- case, but be defensive).
        local cb = ns.ChargeBar and ns.ChargeBar.GetActiveAnchorFrame and ns.ChargeBar.GetActiveAnchorFrame()
        if cb then return cb, "TOP" end
        if primary and primary:IsShown() and primary:GetWidth() > 0 then return primary, "TOP" end
        if essential then return essential, "TOP" end
    else -- SECONDARY (default)
        if primary and primary:IsShown() and primary:GetWidth() > 0 then
            return primary, "TOP"
        end
        if essential then return essential, "TOP" end
    end
    return nil
end

local function GetClusterBounds()
    local essential = _G["EssentialCooldownViewer"]
    if not essential then return nil end
    local left, right = essential:GetLeft(), essential:GetRight()
    if not left or not right then return nil end

    local trinket = _G["BCDM_TrinketBar"]
    local isBlacklisted = ns.TrinketsCDM and ns.TrinketsCDM.IsTrinketBlacklisted
    if trinket then
        -- Always derive trinket bounds from non-blacklisted children. The
        -- container's own GetLeft/GetRight reflect BCDM's pre-filter layout
        -- and would include hidden trinkets in the cluster width.
        local tl, tr
        for i = 1, trinket:GetNumChildren() do
            local child = select(i, trinket:GetChildren())
            if child and child:IsShown() and child.GetLeft and not (isBlacklisted and isBlacklisted(child)) then
                local cl, cr = child:GetLeft(), child:GetRight()
                if cl and cr then
                    tl = (tl and math.min(tl, cl)) or cl
                    tr = (tr and math.max(tr, cr)) or cr
                end
            end
        end
        if tl and tr then
            if tl < left  then left  = tl end
            if tr > right then right = tr end
        end
    end
    return left, right
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

    if desired then
        cb.enable         = true
        cb.detachFromFrame = true
        cb.parent         = "UIPARENT"
    else
        cb.enable = false
    end

    if desiredKey ~= lastEnableState then
        local ok = pcall(UF.CreateAndUpdateUF, UF, "player")
        if not ok then
            -- Styles not registered yet etc — bail and let next dirty retry.
            return false
        end
        lastEnableState = desiredKey

        if TUI.InvalidateDynamicCastBarAnchor then
            TUI:InvalidateDynamicCastBarAnchor()
        end
    end
    return true
end

local function ApplyWidthAndPosition(entry)
    if not entry or not playerEntered then return end

    local frame = _G["ElvUF_Player"]
    local holder = frame and frame.ClassBarHolder
    if not holder then return end

    local db = E.db.thingsUI.classbarMode
    holder:SetFrameStrata(db.frameStrata or "MEDIUM")
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

    local essential = _G["EssentialCooldownViewer"]
    local leftAnchorFrame = essential or target
    local leftDelta = 0
    if essential and left then
        local el = essential:GetLeft()
        if el then leftDelta = left - el end
    end

    holder:ClearAllPoints()
    holder:SetPoint("LEFT",   leftAnchorFrame, "LEFT", (db.xOffset or 0) + leftDelta, 0)
    holder:SetPoint("BOTTOM", target,          "TOP",  0,                              db.gap or 1)
end

local function ChargeBarWantsUs()
    -- True if ChargeBar's current spec entry is set to ABOVE_CLASSBAR — i.e.
    -- the chargebar is anchored to our holder and needs a poke after we move.
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

    -- ChargeBar might be anchored to our holder (slot = ABOVE_CLASSBAR); poke it
    -- so its width/position re-resolves against the classbar's new bounds.
    -- Guarded to avoid feedback loops when ChargeBar is anchored elsewhere.
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
    if f and not f._TUI_classbarHooked then
        f._TUI_classbarHooked = true
        f:HookScript("OnSizeChanged", function() MarkDirty() end)
    end
    if f then
        for i = 1, f:GetNumChildren() do
            local child = select(i, f:GetChildren())
            if child and not child._TUI_classbarHooked then
                child._TUI_classbarHooked = true
                child:HookScript("OnShow", function() MarkDirty() end)
                child:HookScript("OnHide", function() MarkDirty() end)
            end
        end
    end
    local t = _G["BCDM_TrinketBar"]
    if t and not t._TUI_classbarHooked then
        t._TUI_classbarHooked = true
        t:HookScript("OnSizeChanged", function() MarkDirty() end)
        t:HookScript("OnShow",        function() MarkDirty() end)
        t:HookScript("OnHide",        function() MarkDirty() end)
    end
    if t then
        for i = 1, t:GetNumChildren() do
            local child = select(i, t:GetChildren())
            if child and not child._TUI_classbarHooked then
                child._TUI_classbarHooked = true
                child:HookScript("OnShow", function() MarkDirty() end)
                child:HookScript("OnHide", function() MarkDirty() end)
            end
        end
    end
    local p = _G["BCDM_PowerBar"]
    if p and not p._TUI_classbarHooked then
        p._TUI_classbarHooked = true
        p:HookScript("OnSizeChanged", function() MarkDirty() end)
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
