local _, ns = ...
local TUI = ns.TUI
local E   = ns.E

ns.EssentialMover = ns.EssentialMover or {}
local M = ns.EssentialMover

local MOVER_NAME = "TUI_EssentialMover"
local DEFAULT_POINT = "CENTER"

local mover
local applying   = false
local moverShown = false

local function GetDB()
    return E.db.thingsUI and E.db.thingsUI.essentialMover or nil
end

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
    local ref = (ns.CDMIcons and ns.CDMIcons.GetProxy and ns.CDMIcons.GetProxy(ev)) or ev
    local cx, cy = ref:GetCenter()
    if not cx then return end
    local w, h = ref:GetSize()
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
    local proxy = ns.CDMIcons and ns.CDMIcons.GetProxy and ns.CDMIcons.GetProxy(ev)
    if not proxy then return end
    mover:ClearAllPoints()
    mover:SetAllPoints(proxy)
end
M.AnchorMover = AnchorMover

local function ApplyAnchor()
    if applying then return end
    local ev = _G.EssentialCooldownViewer
    if not ev then return end
    if InCombatLockdown() then return end

    local db = GetDB()
    if not (db and db.enabled) then return end

    local proxy = ns.CDMIcons and ns.CDMIcons.GetProxy and ns.CDMIcons.GetProxy(ev)
    if not proxy then return end

    applying = true
    local point = db.point or DEFAULT_POINT
    local x = (db.x or 0) + GetTrinketCompX()
    local y = (db.y or 0) + GetTrinketCompY()

    proxy:SetScale((ev:GetEffectiveScale() or 1) / (_G.UIParent:GetEffectiveScale() or 1))
    proxy:ClearAllPoints()
    proxy:SetPoint(point, _G.UIParent, point, x, y)

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

    if centerY >= uh / 2 then
        point = "TOP"
        y = (centerY + height / 2) - uh
    else
        point = "BOTTOM"
        y = (centerY - height / 2)
    end

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

local function OnDragStop(self)
    self:StopMovingOrSizing()
    local db = GetDB()
    if not db then return end

    local cx, cy = self:GetCenter()
    if not cx then return end
    local w, h = self:GetSize()
    local point, x, y = ResolvePoint(cx, cy, w, h)
    local forced = GrowthDirectionPin()
    if forced and forced ~= point then
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

    AnchorMover()
    mover:Hide()

    hooksecurefunc(mover, "SetPoint", function(self)
        if applying then return end
        local db = GetDB()
        if not (db and db.enabled) then return end
        if (self:GetWidth() or 0) < 4 then return end
        local p, relTo, _, x, y = self:GetPoint()
        local proxy = ns.CDMIcons and ns.CDMIcons.GetProxy and ns.CDMIcons.GetProxy(ev)
        if not p or relTo == ev or (proxy and relTo == proxy) then return end

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

function M.Apply()
    local db = GetDB()
    if not (db and db.enabled) then return end
    EnsureMover()
    HookConfigMode()

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
    C_Timer.After(1.5, function() M.Apply() end)
end)
