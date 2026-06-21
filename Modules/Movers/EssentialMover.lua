local _, ns = ...
local TUI = ns.TUI
local E   = ns.E

ns.EssentialMover = ns.EssentialMover or {}
local M = ns.EssentialMover

local MOVER_NAME = "TUI_EssentialMover"
local DEFAULT_POINT = "CENTER"

local mover           -- our draggable handle (Frame)
local hookedViewer    = false
local applying        = false
local moverShown      = false  -- only visible while user toggles /emove-equivalent

local function GetDB()
    return E.db.thingsUI and E.db.thingsUI.essentialMover or nil
end

-- An explicit Growth Direction (CDM -> Essential) = the corner to hold stationary.
local PIN_FOR_GROWTH = {
    CENTERED_H = nil,    CENTERED_V = nil,
    RIGHT      = "LEFT", LEFT       = "RIGHT",
    DOWN       = "TOP",  UP         = "BOTTOM",
}
local function GrowthDirectionPin()
    local essDB = E.db.thingsUI and E.db.thingsUI.cdmIcons and E.db.thingsUI.cdmIcons.essential
    return PIN_FOR_GROWTH[essDB and essDB.growthDirection or ""]
end

local function RetargetPoint(targetPoint)
    local ev = _G.EssentialCooldownViewer
    local db = GetDB()
    if not (ev and db and db.point and targetPoint and db.point ~= targetPoint) then
        return
    end
    local cx, cy = ev:GetCenter()
    if not cx then return end
    local w, h = ev:GetSize()
    if not w or w < 1 then return end
    local uw = _G.UIParent:GetRight() or _G.UIParent:GetWidth() or 1
    local uh = _G.UIParent:GetTop()   or _G.UIParent:GetHeight() or 1
    local fx, fy = cx, cy
    if targetPoint:find("LEFT")   then fx = cx - w / 2 end
    if targetPoint:find("RIGHT")  then fx = cx + w / 2 end
    if targetPoint:find("TOP")    then fy = cy + h / 2 end
    if targetPoint:find("BOTTOM") then fy = cy - h / 2 end
    local rx, ry = uw / 2, uh
    if targetPoint:find("LEFT")   then rx = 0  end
    if targetPoint:find("RIGHT")  then rx = uw end
    if targetPoint == "BOTTOM" or targetPoint:find("BOTTOM") then ry = 0 end
    db.point = targetPoint
    db.x = math.floor(fx - rx + 0.5)
    db.y = math.floor(fy - ry + 0.5)
end

-- Public entry: called from CDMIcons when growth direction changes.
function M.OnGrowthDirectionChanged()
    local forced = GrowthDirectionPin()
    if forced then RetargetPoint(forced) end
    M.Apply()
end

local function GetTrinketCompX()
    if not (ns.TrinketsCDM and ns.TrinketsCDM.GetTrinketExtent) then return 0 end
    if ns.TrinketsCDM.GetTrinketAttachKey
       and ns.TrinketsCDM.GetTrinketAttachKey() ~= "essential" then
        return 0
    end
    local extent, side = ns.TrinketsCDM.GetTrinketExtent()
    extent = extent or 0
    if extent <= 0 then return 0 end
    if side == "LEFT" then return extent / 2 else return -extent / 2 end
end

local function GetTrinketCompY()
    if not (ns.TrinketsCDM and ns.TrinketsCDM.GetTrinketExtentY) then return 0 end
    if ns.TrinketsCDM.GetTrinketAttachKey
       and ns.TrinketsCDM.GetTrinketAttachKey() ~= "essential" then
        return 0
    end
    local extent, side = ns.TrinketsCDM.GetTrinketExtentY()
    extent = extent or 0
    if extent <= 0 then return 0 end
    if side == "TOP" then return -extent / 2 else return extent / 2 end
end

local function AnchorMover()
    local ev = _G.EssentialCooldownViewer
    if not (mover and ev) then return end
    -- Expand the handle to also cover the trinkets when they sit on Essential.
    local onEssential = (not ns.TrinketsCDM)
        or (not ns.TrinketsCDM.GetTrinketAttachKey)
        or ns.TrinketsCDM.GetTrinketAttachKey() == "essential"
    local extX, sideX, extY, sideY = 0, "RIGHT", 0, "TOP"
    if onEssential and ns.TrinketsCDM then
        if ns.TrinketsCDM.GetTrinketExtent  then extX, sideX = ns.TrinketsCDM.GetTrinketExtent();  extX = extX or 0 end
        if ns.TrinketsCDM.GetTrinketExtentY then extY, sideY = ns.TrinketsCDM.GetTrinketExtentY(); extY = extY or 0 end
    end
    local left   = (sideX == "LEFT")   and extX or 0
    local right  = (sideX == "RIGHT")  and extX or 0
    local top    = (sideY == "TOP")    and extY or 0
    local bottom = (sideY == "BOTTOM") and extY or 0
    mover:ClearAllPoints()
    if (left + right + top + bottom) > 0 then
        mover:SetPoint("TOPLEFT",     ev, "TOPLEFT",     -left,   top)
        mover:SetPoint("BOTTOMRIGHT", ev, "BOTTOMRIGHT",  right, -bottom)
    else
        mover:SetAllPoints(ev)
    end
end
M.AnchorMover = AnchorMover

-- Position Essential
local function ApplyAnchor()
    if applying then return end
    local ev = _G.EssentialCooldownViewer
    if not ev then return end
    if InCombatLockdown() then return end

    local db = GetDB()
    if not (db and db.enabled) then return end

    applying = true
    local point = db.point or DEFAULT_POINT
    local x = (db.x or 0) + GetTrinketCompX()
    local y = (db.y or 0) + GetTrinketCompY()

    ev:ClearAllPoints()
    ev:SetPoint(point, _G.UIParent, point, x, y)

    if mover then AnchorMover() end

    applying = false

    if ns.MoverSync and ns.MoverSync.Queue then ns.MoverSync.Queue() end
    if TUI.UpdateClusterPositioning then TUI:UpdateClusterPositioning() end
    if ns.BarSetup and ns.BarSetup.ApplyStack then ns.BarSetup.ApplyStack() end
end

local function ResolvePoint(centerX, centerY, width, height)
    local uw = _G.UIParent:GetRight() or _G.UIParent:GetWidth() or 1
    local uh = _G.UIParent:GetTop()   or _G.UIParent:GetHeight() or 1
    local point
    local x, y

    -- Vertical: top half vs bottom half.
    if centerY >= uh / 2 then
        point = "TOP"
        y = (centerY + height / 2) - uh
    else
        point = "BOTTOM"
        y = (centerY - height / 2)
    end

    -- Horizontal: left third / right third / middle.
    if centerX >= (uw * 2 / 3) then
        point = point .. "RIGHT"
        x = (centerX + width / 2) - uw
    elseif centerX <= (uw / 3) then
        point = point .. "LEFT"
        x = (centerX - width / 2)
    else
        x = centerX - uw / 2
    end

    return point, math.floor(x + 0.5), math.floor(y + 0.5)
end

-- Drag-stop handler for our custom mover.
local function OnDragStop(self)
    self:StopMovingOrSizing()
    local db = GetDB()
    if not db then return end

    local cx, cy = self:GetCenter()
    if not cx then return end
    local w, h = self:GetSize()
    -- Always compute quadrant first to get screen-space x/y values
    -- relative to UIParent corners.
    local point, x, y = ResolvePoint(cx, cy, w, h)
    local forced = GrowthDirectionPin()
    if forced and forced ~= point then
        -- Translate (cx, cy, w, h) into offsets from `forced` corner.
        local uw = _G.UIParent:GetRight() or _G.UIParent:GetWidth() or 1
        local uh = _G.UIParent:GetTop()   or _G.UIParent:GetHeight() or 1
        local fx, fy = cx, cy
        if forced:find("LEFT")   then fx = cx - w / 2 end
        if forced:find("RIGHT")  then fx = cx + w / 2 end
        if forced:find("TOP")    then fy = cy + h / 2 end
        if forced:find("BOTTOM") then fy = cy - h / 2 end
        local rx, ry = uw / 2, uh
        if forced:find("LEFT")   then rx = 0  end
        if forced:find("RIGHT")  then rx = uw end
        if forced == "BOTTOM" or forced:find("BOTTOM") then ry = 0 end
        point = forced
        x = math.floor(fx - rx + 0.5)
        y = math.floor(fy - ry + 0.5)
    end

    db.point = point
    db.x = x
    db.y = y

    if ns.TrinketsCDM and ns.TrinketsCDM.ResetEssentialSavedPoint then
        ns.TrinketsCDM.ResetEssentialSavedPoint()
    end
    ApplyAnchor()
end

-- Build the mover.
local function EnsureMover()
    if mover then return end
    local ev = _G.EssentialCooldownViewer
    if not ev then return end

    mover = CreateFrame("Button", MOVER_NAME, _G.UIParent)
    mover:SetFrameStrata("DIALOG")
    mover:SetClampedToScreen(true)
    mover:SetMovable(true)
    mover:EnableMouse(true)
    mover:EnableMouseWheel(true)
    mover:RegisterForDrag("LeftButton", "RightButton")

    if mover.SetTemplate then mover:SetTemplate("Transparent", nil, nil, true) end
    mover.name        = MOVER_NAME
    mover.textString  = "Essential Cooldowns"
    mover.parent      = ev
    mover.snapOffset  = -2

    local fs = mover:CreateFontString(nil, "OVERLAY")
    if fs.FontTemplate then fs:FontTemplate() end
    fs:SetPoint("CENTER")
    fs:SetText(mover.textString)
    if E.media and E.media.rgbvaluecolor then
        fs:SetTextColor(unpack(E.media.rgbvaluecolor))
    end
    fs:SetJustifyH("CENTER")
    mover:SetFontString(fs)
    mover.text = fs

    local coordTicker = CreateFrame("Frame")
    coordTicker:Hide()
    coordTicker:SetScript("OnUpdate", function()
        if not (mover and mover.GetCenter) then return end
        if not (E.CalculateMoverPoints and E.MoverNudgeFrame
                and E.GetXYOffset and E.UpdateNudgeFrame) then return end
        local x, y, _, nudgePoint, nudgeInversePoint = E:CalculateMoverPoints(mover)
        local coordX, coordY = E:GetXYOffset(nudgeInversePoint, 1)
        E.MoverNudgeFrame:ClearAllPoints()
        E.MoverNudgeFrame:SetPoint(nudgePoint, mover, nudgeInversePoint, coordX, coordY)
        E:UpdateNudgeFrame(mover, x, y)
    end)
    M._coordTicker = coordTicker

    mover:SetScript("OnDragStart", function(self)
        if E.AlertCombat and E:AlertCombat() then return end
        self:StartMoving()
        coordTicker:Show()
    end)
    mover:SetScript("OnDragStop", function(self)
        coordTicker:Hide()
        OnDragStop(self)
    end)

    mover:SetScript("OnEnter", function(self)
        if E.AssignFrameToNudge then E.AssignFrameToNudge(self) end
        if E.MoverNudgeFrame and E.CalculateMoverPoints and E.GetXYOffset then
            local x, y, _, nudgePoint, nudgeInversePoint = E:CalculateMoverPoints(self)
            local coordX, coordY = E:GetXYOffset(nudgeInversePoint, 1)
            E.MoverNudgeFrame:ClearAllPoints()
            E.MoverNudgeFrame:SetPoint(nudgePoint, self, nudgeInversePoint, coordX, coordY)
            E:UpdateNudgeFrame(self, x, y)
        end
    end)
    mover:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            if E.MoverNudgeFrame then
                E.MoverNudgeFrame:SetShown(not E.MoverNudgeFrame:IsShown())
            end
        end
    end)
    mover:SetScript("OnMouseDown", function(self, button)
        if button ~= "RightButton" then return end
        if IsShiftKeyDown() then
            self:Hide()
        elseif IsControlKeyDown() then
            local db = GetDB()
            if db then
                db.point, db.x, db.y = DEFAULT_POINT, 0, 0
                ApplyAnchor()
            end
        elseif E.ToggleOptions then
            E:ToggleOptions("thingsUI,modulesTab,cdm,essentialTab")
        end
    end)
    mover:SetScript("OnMouseWheel", function(_, delta)
        if not E.NudgeMover then return end
        if IsShiftKeyDown() then
            E:NudgeMover(delta)
        else
            E:NudgeMover(nil, delta)
        end
    end)

    -- Anchor over the viewer (expanded over trinkets); re-runs on every apply.
    AnchorMover()
    mover:Hide()  -- shown via ElvUI's config-mode toggle

    hooksecurefunc(mover, "SetPoint", function(self)
        if applying then return end
        local db = GetDB()
        if not (db and db.enabled) then return end
        local p, relTo, _, x, y = self:GetPoint()
        if not p or relTo == ev then return end

        local nx = math.floor((x or 0) + 0.5)
        local ny = math.floor((y or 0) + 0.5)

        local forced = GrowthDirectionPin()
        if forced and forced ~= p then
            local cx, cy = self:GetCenter()
            local w, h = self:GetSize()
            if cx and w and w > 0 then
                local uw = _G.UIParent:GetRight() or _G.UIParent:GetWidth() or 1
                local uh = _G.UIParent:GetTop()   or _G.UIParent:GetHeight() or 1
                local fx, fy = cx, cy
                if forced:find("LEFT")   then fx = cx - w / 2 end
                if forced:find("RIGHT")  then fx = cx + w / 2 end
                if forced:find("TOP")    then fy = cy + h / 2 end
                if forced:find("BOTTOM") then fy = cy - h / 2 end
                local rx, ry = uw / 2, uh
                if forced:find("LEFT")   then rx = 0  end
                if forced:find("RIGHT")  then rx = uw end
                if forced == "BOTTOM" or forced:find("BOTTOM") then ry = 0 end
                p  = forced
                nx = math.floor(fx - rx + 0.5)
                ny = math.floor(fy - ry + 0.5)
            end
        end

        if db.point == p and db.x == nx and db.y == ny then return end
        db.point, db.x, db.y = p, nx, ny
        if M._nudgeQueued then return end
        M._nudgeQueued = true
        C_Timer.After(0, function()
            M._nudgeQueued = nil
            ApplyAnchor()
        end)
    end)
end

-- Register with ElvUI's config-mode
local function HookConfigMode()
    if not E.ConfigModeLayouts then return end
    if not ns.__tuiEssMoverConfigHooked then
        ns.__tuiEssMoverConfigHooked = true
        hooksecurefunc(E, "ToggleMoveMode", function()
            if not mover then return end
            if E.configMode then
                mover:Show()
                moverShown = true
            else
                mover:Hide()
                moverShown = false
            end
        end)
    end
end

-- Catch the case where EditMode / Blizzard / TrinketsCDM moves Essential after we anchored it (avoid loops maybe probably).
local function HookViewerSetPoint()
    if hookedViewer then return end
    local ev = _G.EssentialCooldownViewer
    if not ev then return end
    hookedViewer = true
    hooksecurefunc(ev, "SetPoint", function(self)
        if applying then return end
        local db = GetDB()
        if not (db and db.enabled) then return end
        local p, relTo, _, x, y = self:GetPoint()
        if not p then return end
        -- Already where we want it -> Skip.
        if p == (db.point or DEFAULT_POINT)
           and (relTo == nil or relTo == _G.UIParent)
           and math.floor((x or 0) + 0.5) == math.floor((db.x or 0) + GetTrinketCompX() + 0.5)
           and math.floor((y or 0) + 0.5) == math.floor((db.y or 0) + GetTrinketCompY() + 0.5) then
            return
        end
        if M._reapplyQueued then return end
        M._reapplyQueued = true
        C_Timer.After(0, function()
            M._reapplyQueued = nil
            ApplyAnchor()
        end)
    end)
end

function M.Apply()
    local db = GetDB()
    if not (db and db.enabled) then return end
    EnsureMover()
    HookConfigMode()
    HookViewerSetPoint()
    
    local forced = GrowthDirectionPin()
    if forced then RetargetPoint(forced) end
    ApplyAnchor()
end

function TUI:UpdateEssentialMover()
    if InCombatLockdown() then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            C_Timer.After(0.1, M.Apply)
        end)
        return
    end
    M.Apply()
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    -- Defer so EssentialCooldownViewer exists and EditModeLock has run.
    C_Timer.After(1.5, function() M.Apply() end)
end)
