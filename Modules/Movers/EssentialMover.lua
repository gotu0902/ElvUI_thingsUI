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

local function GetProxy()
    local ev = _G.EssentialCooldownViewer
    return ev and ns.CDMIcons and ns.CDMIcons.GetProxy and ns.CDMIcons.GetProxy(ev)
end

-- the proxy carries the viewer's Edit Mode scale: its offsets are in its own units
local function ProxyScale()
    local ev = _G.EssentialCooldownViewer
    local s = ev and (ev:GetEffectiveScale() or 1) / (_G.UIParent:GetEffectiveScale() or 1)
    return (s and s > 0) and s or 1
end

-- offsets that put `point` of a rect (UIParent units) on the same point of UIParent
local function PointOffsets(point, cx, cy, w, h)
    w, h = math.floor(w + 0.5), math.floor((h or 0) + 0.5)
    local uw = _G.UIParent:GetRight() or _G.UIParent:GetWidth() or 1
    local uh = _G.UIParent:GetTop()   or _G.UIParent:GetHeight() or 1
    local fx, fy, rx, ry = cx, cy, uw / 2, uh / 2
    if point:find("LEFT")   then fx, rx = cx - w / 2, 0  end
    if point:find("RIGHT")  then fx, rx = cx + w / 2, uw end
    if point:find("TOP")    then fy, ry = cy + h / 2, uh end
    if point:find("BOTTOM") then fy, ry = cy - h / 2, 0  end
    local s = ProxyScale()
    return math.floor((fx - rx) / s + 0.5), math.floor((fy - ry) / s + 0.5)
end

-- ElvUI's convention: the corner of the screen third the center falls in
local function ResolvePoint(cx, cy)
    local uw = _G.UIParent:GetRight() or _G.UIParent:GetWidth() or 1
    local uh = _G.UIParent:GetTop()   or _G.UIParent:GetHeight() or 1
    local point = (cy >= uh / 2) and "TOP" or "BOTTOM"
    if cx >= uw * 2 / 3 then
        point = point .. "RIGHT"
    elseif cx <= uw / 3 then
        point = point .. "LEFT"
    end
    return point
end

local function RetargetPoint(targetPoint)
    local ev = _G.EssentialCooldownViewer
    local db = GetDB()
    if not (ev and db and db.point and targetPoint and db.point ~= targetPoint) then
        return
    end
    local ref = GetProxy() or ev
    local cx, cy = ref:GetCenter()
    if not cx then return end
    local w, h = ref:GetSize()
    if not w or w < 1 then return end
    local k = ref:GetEffectiveScale() / _G.UIParent:GetEffectiveScale()
    db.point = targetPoint
    db.x, db.y = PointOffsets(targetPoint, cx * k, cy * k, w * k, (h or 0) * k)
end

function M.OnGrowthDirectionChanged()
    local forced = GrowthDirectionPin()
    if forced then RetargetPoint(forced) end
    M.Apply()
end

local function AnchorMover()
    local proxy = GetProxy()
    if not (mover and proxy) then return end
    -- a size of its own: ElvUI's nudge re-anchors it by a single point
    local k = proxy:GetEffectiveScale() / mover:GetEffectiveScale()
    mover:SetSize(math.max(proxy:GetWidth() * k, 1), math.max(proxy:GetHeight() * k, 1))
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
    local x = db.x or 0
    local y = db.y or 0

    proxy:SetScale(ProxyScale())
    proxy:ClearAllPoints()
    proxy:SetPoint(point, _G.UIParent, point, x, y)

    if mover then AnchorMover() end

    applying = false

    if ns.MoverSync and ns.MoverSync.Queue then ns.MoverSync.Queue() end
    if TUI.UpdateClusterPositioning then TUI:UpdateClusterPositioning() end
    if ns.BarSetup and ns.BarSetup.ApplyStack then ns.BarSetup.ApplyStack() end
end

local function OnDragStop(self)
    self:StopMovingOrSizing()
    local db = GetDB()
    if not db then return end

    local cx, cy = self:GetCenter()
    if not cx then return end
    local w, h = self:GetSize()
    local point = GrowthDirectionPin() or ResolvePoint(cx, cy)
    db.point = point
    db.x, db.y = PointOffsets(point, cx, cy, w or 0, h or 0)

    ApplyAnchor()
end

function M.RefreshLabel()
    if not (mover and mover.text) then return end
    local cp = E.db.thingsUI and E.db.thingsUI.clusterPositioning
    local suffix = (cp and cp.enabled) and "  |cFF40FF40(Master - Move This)|r" or ""
    mover.text:SetText((mover.textString or "Essential Cooldowns") .. suffix)
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
    M.RefreshLabel()

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
            E:ToggleOptions("thingsUI,modulesTab,cdm,layoutTab,essentialTab")
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

    -- an outside SetPoint (ElvUI's nudge) keeps our point: same spot, our offsets
    hooksecurefunc(mover, "SetPoint", function(self)
        if applying then return end
        local db = GetDB()
        if not (db and db.enabled) then return end
        local p, relTo = self:GetPoint()
        local proxy = GetProxy()
        if not p or relTo == ev or (proxy and relTo == proxy) then return end
        local cx, cy = self:GetCenter()
        local w, h = self:GetSize()
        if not cx or (w or 0) < 4 then return end

        local point = GrowthDirectionPin() or db.point or DEFAULT_POINT
        local nx, ny = PointOffsets(point, cx, cy, w, h)
        if db.point == point and db.x == nx and db.y == ny then return end
        db.point, db.x, db.y = point, nx, ny
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
