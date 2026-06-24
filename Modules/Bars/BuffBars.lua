local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM

local ipairs, select, wipe = ipairs, select, wipe
local tsort = table.sort

local skinnedBars = ns.skinnedBars
local yoinkedBars = ns.yoinkedBars

local viewerReadyHooked = false
local viewerReadyTicker
local hookedBuffChildren = {}
local applyingLayout = false
local anchoringContainer = false
local AnchorBuffBarContainer
local HookBuffBarEditMode


local function OnBuffChildPointChanged(child)
    if applyingLayout then return end
    if child and yoinkedBars[child] then return end
    if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
end

local function HookBuffChild(child)
    if not child or hookedBuffChildren[child] then return end
    hookedBuffChildren[child] = true
    hooksecurefunc(child, "SetPoint", OnBuffChildPointChanged)
    hooksecurefunc(child, "ClearAllPoints", OnBuffChildPointChanged)

    if type(child.OnAuraInstanceInfoSet) == "function" then
        hooksecurefunc(child, "OnAuraInstanceInfoSet", function()
            if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
        end)
    end
    if type(child.OnAuraInstanceInfoCleared) == "function" then
        hooksecurefunc(child, "OnAuraInstanceInfoCleared", function()
            if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
        end)
    end
end

local function ScanAndHookBuffChildren()
    if not BuffBarCooldownViewer then return false end
    if not viewerReadyHooked then
        local hookedAny = false
        if type(BuffBarCooldownViewer.RefreshLayout) == "function" then
            hooksecurefunc(BuffBarCooldownViewer, "RefreshLayout", function()
                if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
            end)
            hookedAny = true
        end
        if type(BuffBarCooldownViewer.Layout) == "function" then
            hooksecurefunc(BuffBarCooldownViewer, "Layout", function()
                if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
            end)
            hookedAny = true
        end

        local function onViewerMoved()
            if anchoringContainer then return end

            if InCombatLockdown() then return end
            local db = E.db.thingsUI.buffBars
            if not (db and db.anchorEnabled) then return end
            if AnchorBuffBarContainer then AnchorBuffBarContainer() end
        end
        hooksecurefunc(BuffBarCooldownViewer, "SetPoint", onViewerMoved)
        hooksecurefunc(BuffBarCooldownViewer, "ClearAllPoints", onViewerMoved)

        if type(BuffBarCooldownViewer.OnAcquireItemFrame) == "function" then
            hooksecurefunc(BuffBarCooldownViewer, "OnAcquireItemFrame", function(_, itemFrame)
                HookBuffChild(itemFrame)
                if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
            end)
        end
        if hookedAny then viewerReadyHooked = true end
    end

    local n = BuffBarCooldownViewer:GetNumChildren()
    if n > 0 then
        local kids = { BuffBarCooldownViewer:GetChildren() }
        for i = 1, n do HookBuffChild(kids[i]) end
    end
    return n > 0
end

local function StartViewerReadyTicker()
    if viewerReadyTicker then return end
    local tries = 0
    viewerReadyTicker = C_Timer.NewTicker(0.25, function()
        tries = tries + 1
        local hasChildren = ScanAndHookBuffChildren()
        if BuffBarCooldownViewer and hasChildren and ns.MarkBuffBarsDirty then
            ns.MarkBuffBarsDirty()
        end
        if tries >= 20 then
            viewerReadyTicker:Cancel()
            viewerReadyTicker = nil
        end
    end)
end

local updateFrame = CreateFrame("Frame")
local isDirty = false
local isEnabled = false
local sortedBars = {}

local cachedClassR, cachedClassG, cachedClassB
local function GetClassColor()
    if not cachedClassR then
        local c = E:ClassColor(E.myclass, true)
        cachedClassR, cachedClassG, cachedClassB = c.r, c.g, c.b
    end
    return cachedClassR, cachedClassG, cachedClassB
end

local function SkinBuffBar(childFrame)
    if not childFrame or not childFrame.Bar then return end
    if skinnedBars[childFrame] then return end

    local db = E.db.thingsUI.buffBars
    local bar = childFrame.Bar
    local icon = childFrame.Icon

    if childFrame.tuiBackdrop then childFrame.tuiBackdrop:Hide() end

    if icon and icon.Icon then
        if db.iconEnabled then
            icon:SetAlpha(1)
            icon.Icon:SetTexCoord(db.iconZoom, 1 - db.iconZoom, db.iconZoom, 1 - db.iconZoom)
            if not icon.tuiBackdrop then
                icon.tuiBackdrop = CreateFrame("Frame", nil, icon, "BackdropTemplate")
                icon.tuiBackdrop:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
                icon.tuiBackdrop:SetBackdropColor(0, 0, 0, 1)
                icon.tuiBackdrop:SetBackdropBorderColor(0, 0, 0, 1)
            end
            icon.tuiBackdrop:Show()
            icon.tuiBackdrop:SetFrameLevel(icon:GetFrameLevel() - 1)
        else

            icon:SetAlpha(0)
        end
    end

    if not bar.tuiBackdrop then
        bar.tuiBackdrop = CreateFrame("Frame", nil, childFrame, "BackdropTemplate")
        bar.tuiBackdrop:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
        bar.tuiBackdrop:SetBackdropColor(0, 0, 0, 0.7)
        bar.tuiBackdrop:SetBackdropBorderColor(0, 0, 0, 1)
        bar.tuiBackdrop:SetFrameLevel(childFrame:GetFrameLevel() - 1)
    end
    bar.tuiBackdrop:Show()

    local texture = LSM:Fetch("statusbar", db.statusBarTexture)
    bar:SetStatusBarTexture(texture)
    if db.useClassColor then
        bar:SetStatusBarColor(GetClassColor())
    else
        bar:SetStatusBarColor(db.customColor.r, db.customColor.g, db.customColor.b)
    end

    if bar.BarBG then bar.BarBG:SetAlpha(0) end
    if bar.Pip then bar.Pip:SetAlpha(0) end

    skinnedBars[childFrame] = true
end

local JUSTIFY_H_MAP = {
    LEFT = "LEFT", RIGHT = "RIGHT", CENTER = "CENTER",
    TOPLEFT = "LEFT", TOPRIGHT = "RIGHT", TOP = "CENTER",
    BOTTOMLEFT = "LEFT", BOTTOMRIGHT = "RIGHT", BOTTOM = "CENTER",
}
local JUSTIFY_V_MAP = {
    TOP = "TOP", BOTTOM = "BOTTOM", CENTER = "MIDDLE",
    TOPLEFT = "TOP", TOPRIGHT = "TOP",
    BOTTOMLEFT = "BOTTOM", BOTTOMRIGHT = "BOTTOM",
    LEFT = "MIDDLE", RIGHT = "MIDDLE",
}

local function LayoutBuffBar(childFrame)
    if not childFrame or not childFrame.Bar then return end

    local db = E.db.thingsUI.buffBars
    local bar = childFrame.Bar
    local icon = childFrame.Icon

    local effectiveWidth = db.width
    if db.inheritWidth and db.anchorEnabled then
        local anchorFrame = (ns.SpecialBars and ns.SpecialBars.ResolveAnchorTarget
            and ns.SpecialBars.ResolveAnchorTarget(db.anchorFrame)) or _G[db.anchorFrame]
        if anchorFrame then
            local aw = anchorFrame:GetWidth()
            if aw and aw > 0 then effectiveWidth = aw + (db.inheritWidthOffset or 0) end
        end
    end
    childFrame:SetSize(effectiveWidth, db.height)

    local barOffset = 0
    local iconSize = db.height

    if icon and icon.Icon and db.iconEnabled then
        icon:SetSize(iconSize, iconSize)
        if icon.tuiBackdrop then icon.tuiBackdrop:SetAllPoints(icon) end
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", childFrame, "LEFT", 0, 0)
        icon.Icon:ClearAllPoints()
        icon.Icon:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
        icon.Icon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
        barOffset = iconSize + (db.iconSpacing or 3)
    end

    if bar.tuiBackdrop then
        bar.tuiBackdrop:ClearAllPoints()
        bar.tuiBackdrop:SetPoint("TOPLEFT", childFrame, "TOPLEFT", barOffset, 0)
        bar.tuiBackdrop:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", 0, 0)
    end

    bar:ClearAllPoints()
    if bar.tuiBackdrop then
        bar:SetPoint("TOPLEFT", bar.tuiBackdrop, "TOPLEFT", 1, -1)
        bar:SetPoint("BOTTOMRIGHT", bar.tuiBackdrop, "BOTTOMRIGHT", -1, 1)
    end

    if icon and icon.Applications then
        if db.stackAnchor == "BAR" then
            if icon.Applications:GetParent() ~= bar then
                icon.Applications:SetParent(bar)
            end
            local iconSize = db.height or 23
            local spacing = db.iconSpacing or 1
            local xOff = (db.stackXOffset or 0) - ((iconSize + spacing) / 2)
            local stackPoint = db.stackPoint or "CENTER"
            icon.Applications:SetWidth(iconSize)
            icon.Applications:SetJustifyH("CENTER")
            icon.Applications:ClearAllPoints()
            icon.Applications:SetPoint(stackPoint, bar, stackPoint, xOff, db.stackYOffset or 0)
        else

            if icon.Applications:GetParent() ~= icon then
                icon.Applications:SetParent(icon)
                icon.Applications:SetWidth(0)
            end
        end
    end
end

local function ApplyContainerStrata()
    if not BuffBarCooldownViewer then return end
    local db = E.db.thingsUI.buffBars
    BuffBarCooldownViewer:SetFrameStrata((db and db.frameStrata) or "MEDIUM")
end

function AnchorBuffBarContainer()
    if not BuffBarCooldownViewer then return end
    local db = E.db.thingsUI.buffBars
    ApplyContainerStrata()

    if not db.anchorEnabled then return end
    local anchorFrame = (ns.SpecialBars and ns.SpecialBars.ResolveAnchorTarget
        and ns.SpecialBars.ResolveAnchorTarget(db.anchorFrame)) or _G[db.anchorFrame]
    if not anchorFrame then return end
    anchoringContainer = true
    BuffBarCooldownViewer:ClearAllPoints()
    BuffBarCooldownViewer:SetPoint(db.anchorPoint, anchorFrame, db.anchorRelativePoint, db.anchorXOffset, db.anchorYOffset)
    anchoringContainer = false
end

local hookedAuraBorders = {}
local function ApplyAuraBorderHide(childFrame)
    local b = childFrame and childFrame.DebuffBorder
    if not b then return end
    if not hookedAuraBorders[b] and type(b.UpdateFromAuraData) == "function" then
        hookedAuraBorders[b] = true
        hooksecurefunc(b, "UpdateFromAuraData", function(self)
            local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
            if cdm and cdm.hideAuraBorder then self:SetAlpha(0) end
        end)
    end
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    if cdm and cdm.hideAuraBorder then b:SetAlpha(0) end
end

local function ProcessUpdate()
    if not BuffBarCooldownViewer then return end
    if not E.db.thingsUI then return end

    ScanAndHookBuffChildren()
    if HookBuffBarEditMode then HookBuffBarEditMode() end

    local buffBarsEnabled = E.db.thingsUI.buffBars and E.db.thingsUI.buffBars.enabled
    local specialBarsExist = E.db.thingsUI.specialBars

    if specialBarsExist then
        ns.SpecialBars.ScanAndHookCDMChildren()
    end

    if not buffBarsEnabled then return end

    local db = E.db.thingsUI.buffBars
    wipe(sortedBars)
    local children = { BuffBarCooldownViewer:GetChildren() }

    local SB = ns.SpecialBars
    for _, childFrame in ipairs(children) do
        if childFrame then ApplyAuraBorderHide(childFrame) end
        if childFrame and childFrame:IsShown() and childFrame.Bar
           and not yoinkedBars[childFrame] and not childFrame._tui_hidden
           and not (SB and SB.IsChildClaimedBySpecial and SB.IsChildClaimedBySpecial(childFrame)) then
            SkinBuffBar(childFrame)
            LayoutBuffBar(childFrame)
            sortedBars[#sortedBars + 1] = childFrame
        end
    end

    AnchorBuffBarContainer()
    if #sortedBars == 0 then return end
    tsort(sortedBars, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)

    local spacing = db.spacing
    local height = db.height
    applyingLayout = true
    for index, barFrame in ipairs(sortedBars) do
        barFrame:ClearAllPoints()
        if db.growthDirection == "DOWN" then
            barFrame:SetPoint("TOP", BuffBarCooldownViewer, "TOP", 0, -((index - 1) * (height + spacing)))
        else
            barFrame:SetPoint("BOTTOM", BuffBarCooldownViewer, "BOTTOM", 0, ((index - 1) * (height + spacing)))
        end
    end
    applyingLayout = false
end

local lastProcessTime = 0
local throttledPending = false
local THROTTLE_INTERVAL = 0.1

local function OnNextFrame(self)
    self:SetScript("OnUpdate", nil)
    isDirty = false
    lastProcessTime = GetTime()
    ProcessUpdate()
end

local function MarkDirty()
    if not isEnabled then return end
    if isDirty then return end
    isDirty = true
    updateFrame:SetScript("OnUpdate", OnNextFrame)
end

local function MarkDirtyThrottled()
    if not isEnabled then return end
    if isDirty or throttledPending then return end
    local since = GetTime() - lastProcessTime
    if since >= THROTTLE_INTERVAL then
        MarkDirty()
    else
        throttledPending = true
        C_Timer.After(THROTTLE_INTERVAL - since, function()
            throttledPending = false
            MarkDirty()
        end)
    end
end

ns.MarkBuffBarsDirty = MarkDirty

local function MarkDirtyStaggered()
    MarkDirty()
    C_Timer.After(0.05, MarkDirty)
    C_Timer.After(0.20, MarkDirty)
end
local emmBBHooked, cvsBBHooked = false, false
HookBuffBarEditMode = function()
    if not emmBBHooked then
        local emm = _G.EditModeManagerFrame
        if emm then
            emmBBHooked = true
            if type(emm.EnterEditMode) == "function" then
                hooksecurefunc(emm, "EnterEditMode", MarkDirtyStaggered)
            end
            hooksecurefunc(emm, "ExitEditMode", MarkDirtyStaggered)
        end
    end
    if not cvsBBHooked then
        local cvs = _G.CooldownViewerSettings
        if cvs and cvs.HookScript then
            cvsBBHooked = true
            cvs:HookScript("OnShow", MarkDirtyStaggered)
            cvs:HookScript("OnHide", MarkDirtyStaggered)
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if not E.db.thingsUI then return end
    if not BuffBarCooldownViewer then return end

    if event == "UNIT_AURA" then
        MarkDirtyThrottled()
    elseif event == "PLAYER_REGEN_ENABLED" then
        wipe(skinnedBars)
        MarkDirty()
    elseif event == "PLAYER_ENTERING_WORLD" then
        StartViewerReadyTicker()
        C_Timer.After(0.5, function() wipe(skinnedBars); MarkDirty() end)
        C_Timer.After(1.5, function() wipe(skinnedBars); MarkDirty() end)
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        MarkDirty()
    end
end)

function TUI:UpdateBuffBars()
    if E.db.thingsUI.buffBars.enabled or (E.db.thingsUI.specialBars and next(E.db.thingsUI.specialBars.specs or {})) then
        isEnabled = true
        StartViewerReadyTicker()
        eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
        wipe(skinnedBars)
        MarkDirty()
    else
        isEnabled = false
        isDirty = false
        updateFrame:SetScript("OnUpdate", nil)
        eventFrame:UnregisterAllEvents()
    end
end

ns.BuffBars = ns.BuffBars or {}
ns.BuffBars.MarkDirty = MarkDirty
ns.BuffBars.ProcessUpdate = ProcessUpdate