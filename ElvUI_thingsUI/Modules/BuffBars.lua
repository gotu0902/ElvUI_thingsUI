local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM

local skinnedBars = ns.skinnedBars
local yoinkedBars = ns.yoinkedBars

-- =========================================
-- LAZY CDM CHILD CREATION
-- =========================================
-- CDM can create/show BuffBarCooldownViewer children lazily (often only after
-- the first aura/cast). To ensure we skin/layout immediately on login and
-- whenever new bars appear, we:
--  1) keep a short ticker after entering world until the viewer exists
--  2) hook each child frame's OnShow to trigger a re-skin/re-layout
local hookedBuffChildren = {} -- [childFrame] = true
local viewerReadyTicker

local function HookBuffChild(childFrame)
    if not childFrame or hookedBuffChildren[childFrame] then return end
    hookedBuffChildren[childFrame] = true
    pcall(function()
        childFrame:HookScript("OnShow", function()
            if ns.MarkBuffBarsDirty then
                ns.MarkBuffBarsDirty()
            end
        end)
    end)
end

local function ScanAndHookBuffChildren()
    if not BuffBarCooldownViewer then return false end
    local ok, children = pcall(function() return { BuffBarCooldownViewer:GetChildren() } end)
    if not ok or not children then return false end
    for _, childFrame in ipairs(children) do
        HookBuffChild(childFrame)
    end
    return #children > 0
end

local function StartViewerReadyTicker()
    if viewerReadyTicker then return end
    local tries = 0
    viewerReadyTicker = C_Timer.NewTicker(0.25, function()
        tries = tries + 1
        local hasChildren = ScanAndHookBuffChildren()

        -- When viewer exists and has children, force at least one pass
        if BuffBarCooldownViewer and hasChildren and ns.MarkBuffBarsDirty then
            ns.MarkBuffBarsDirty()
        end

        -- stop after a short window; avoids permanent ticking
        if tries >= 20 then
            viewerReadyTicker:Cancel()
            viewerReadyTicker = nil
        end
    end)
end

-- =========================================
-- DIRTY-FLAG UPDATE SYSTEM
-- =========================================
local updateFrame = CreateFrame("Frame")
local isDirty = false
local isEnabled = false
local sortedBars = {}

local function GetSpecialBarDB_Safe()
    return ns.SpecialBars and ns.SpecialBars.GetSpecialBarDB and ns.SpecialBars.GetSpecialBarDB() or {}
end

local function UpdateSpecialBarSlot_Safe(barKey)
    if ns.SpecialBars and ns.SpecialBars.UpdateSpecialBarSlot then
        return ns.SpecialBars.UpdateSpecialBarSlot(barKey)
    end
end

local function ScanAndHookCDMChildren_Safe()
    if ns.SpecialBars and ns.SpecialBars.ScanAndHookCDMChildren then
        return ns.SpecialBars.ScanAndHookCDMChildren()
    end
end

-- =========================================
-- CLASS COLOR (cached)
-- =========================================
local cachedClassR, cachedClassG, cachedClassB
local function GetClassColor()
    if not cachedClassR then
        local c = E:ClassColor(E.myclass, true)
        cachedClassR, cachedClassG, cachedClassB = c.r, c.g, c.b
    end
    return cachedClassR, cachedClassG, cachedClassB
end

-- =========================================
-- SKINNING — one-time visual setup per bar
-- =========================================
local function SkinBuffBar(childFrame)
    if not childFrame or not childFrame.Bar then return end
    if skinnedBars[childFrame] then return end
    
    local db = E.db.thingsUI.buffBars
    local bar = childFrame.Bar
    local icon = childFrame.Icon
    
    if childFrame.tuiBackdrop then childFrame.tuiBackdrop:Hide() end

    if icon and icon.Icon then
        if db.iconEnabled then
            icon:Show()
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
            icon:Hide()
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
    
    local font = LSM:Fetch("font", db.font)
    if bar.Name then bar.Name:SetFont(font, db.fontSize, db.fontOutline) end
    if bar.Duration then bar.Duration:SetFont(font, db.fontSize, db.fontOutline) end
    
    skinnedBars[childFrame] = true
end

-- =========================================
-- LAYOUT — runs every update, handles dynamic sizing
-- =========================================
local function LayoutBuffBar(childFrame)
    if not childFrame or not childFrame.Bar then return end
    
    local db = E.db.thingsUI.buffBars
    local bar = childFrame.Bar
    local icon = childFrame.Icon
    
    local effectiveWidth = db.width
    if db.inheritWidth and db.anchorEnabled then
        local anchorFrame = _G[db.anchorFrame]
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
    
    if bar.Name then
        bar.Name:ClearAllPoints()
        bar.Name:SetPoint(db.namePoint or "LEFT", bar, db.namePoint or "LEFT", db.nameXOffset or 4, db.nameYOffset or 0)
    end
    if bar.Duration then
        bar.Duration:ClearAllPoints()
        bar.Duration:SetPoint(db.durationPoint or "RIGHT", bar, db.durationPoint or "RIGHT", db.durationXOffset or -4, db.durationYOffset or 0)
    end
end

-- =========================================
-- CONTAINER ANCHOR
-- =========================================
local function AnchorBuffBarContainer()
    if not BuffBarCooldownViewer then return end
    local db = E.db.thingsUI.buffBars
    if not db.anchorEnabled then return end
    local anchorFrame = _G[db.anchorFrame]
    if not anchorFrame then return end
    pcall(function()
        BuffBarCooldownViewer:ClearAllPoints()
        BuffBarCooldownViewer:SetPoint(db.anchorPoint, anchorFrame, db.anchorRelativePoint, db.anchorXOffset, db.anchorYOffset)
    end)
end

-- =========================================
-- MAIN UPDATE
-- =========================================
local function ProcessUpdate()
    if not BuffBarCooldownViewer then return end
    if not E.db.thingsUI then return end

    -- Ensure any newly created/activated CDM children are hooked so we can
    -- re-skin/re-layout the moment they appear.
    ScanAndHookBuffChildren()
    
    local buffBarsEnabled = E.db.thingsUI.buffBars and E.db.thingsUI.buffBars.enabled
    local specialBarsExist = E.db.thingsUI.specialBars
    
    if specialBarsExist then
        ScanAndHookCDMChildren_Safe()
        local specDB = GetSpecialBarDB_Safe()
        for barKey, barDB in pairs(specDB) do
            if type(barDB) == "table" then
                pcall(UpdateSpecialBarSlot_Safe, barKey)
            end
        end
    end
    
    if not buffBarsEnabled then return end
    
    local db = E.db.thingsUI.buffBars
    wipe(sortedBars)
    local children = { BuffBarCooldownViewer:GetChildren() }
    
    for _, childFrame in ipairs(children) do
        if childFrame and childFrame:IsShown() and childFrame.Bar
           and not yoinkedBars[childFrame] and not childFrame._tui_hidden then
            SkinBuffBar(childFrame)
            LayoutBuffBar(childFrame)
            sortedBars[#sortedBars + 1] = childFrame
        end
    end
    
    if #sortedBars == 0 then return end
    
    table.sort(sortedBars, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)
    
    local spacing = db.spacing
    local height = db.height
    for index, barFrame in ipairs(sortedBars) do
        barFrame:ClearAllPoints()
        if db.growthDirection == "DOWN" then
            barFrame:SetPoint("TOP", BuffBarCooldownViewer, "TOP", 0, -((index - 1) * (height + spacing)))
        else
            barFrame:SetPoint("BOTTOM", BuffBarCooldownViewer, "BOTTOM", 0, ((index - 1) * (height + spacing)))
        end
    end
    
    AnchorBuffBarContainer()
end

-- =========================================
-- DIRTY-FLAG
-- =========================================
local function OnNextFrame(self)
    self:SetScript("OnUpdate", nil)
    isDirty = false
    ProcessUpdate()
end

local function MarkDirty()
    if not isEnabled then return end
    if isDirty then return end
    isDirty = true
    updateFrame:SetScript("OnUpdate", OnNextFrame)
end

ns.MarkBuffBarsDirty = MarkDirty

-- =========================================
-- EVENTS
-- =========================================
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if not E.db.thingsUI then return end
    if not BuffBarCooldownViewer then return end
    
    if event == "UNIT_AURA" then
        MarkDirty()
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

-- =========================================
-- PUBLIC API
-- =========================================
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
