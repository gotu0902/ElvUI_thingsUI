local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM   -- for texture/font fetching

-- Coalesce rapid option updates (e.g. sliders) into a single UpdateSpecialBars call per frame
local specialBarsUpdateQueued = false
function TUI:QueueSpecialBarsUpdate()
    if specialBarsUpdateQueued then return end
    specialBarsUpdateQueued = true
    C_Timer.After(0, function()
        specialBarsUpdateQueued = false
        if TUI and TUI.UpdateSpecialBars then
            TUI:UpdateSpecialBars()
        end
    end)
end
local barUpdateFrame = ns.BuffBars and ns.BuffBars.barUpdateFrame
local BuffBarOnUpdate = ns.BuffBars and ns.BuffBars.BuffBarOnUpdate
local yoinkedBars = ns.yoinkedBars
local trackedBarsByName = {}
TUI.scanScheduled = false

local SPECIAL_BAR_DEFAULTS = {
    enabled = false,
    spellName = "",
    width = 230,
    inheritWidth = false,
    inheritWidthOffset = 0,
    height = 23,
    inheritHeight = false,
    inheritHeightOffset = 0,
    statusBarTexture = "ElvUI Blank",
    font = "Expressway",
    fontSize = 14,
    fontOutline = "OUTLINE",
    useClassColor = true,
    customColor = { r = 0.2, g = 0.6, b = 1.0 },
    backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 },
    showBackdrop = false,
    backdropColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.6 },
    iconEnabled = true,
    iconSpacing = 1,
    iconZoom = 0.1,
    showStacks = true,
    stackFontSize = 14,
    stackFontOutline = "OUTLINE",
    stackPoint = "CENTER",
    stackAnchor = "ICON", -- New: "ICON" or "BAR"
    stackXOffset = 0,
    stackYOffset = 0,
    showName = true,
    namePoint = "LEFT",
    nameXOffset = 2,
    nameYOffset = 0,
    showDuration = true,
    durationPoint = "RIGHT",
    durationXOffset = -4,
    durationYOffset = 0,
    anchorMode = "UIParent",  -- Predefined or "CUSTOM"
    anchorFrame = "BCDM_CastBar", -- Used when anchorMode == "CUSTOM"
    anchorPoint = "CENTER",
    anchorRelativePoint = "CENTER",
    anchorXOffset = 0,
    anchorYOffset = 0,
}

-- Resolve actual frame name from anchor settings
local function ResolveAnchorFrame(db)
    local mode = db.anchorMode or db.anchorFrame or "ElvUF_Player"
    if mode == "CUSTOM" then
        return db.anchorFrame or "ElvUF_Player"
    end
    return mode
end

-- Get the current spec ID
local GetCurrentSpecID = function()
    local specIndex = GetSpecialization()
    if specIndex then
        return GetSpecializationInfo(specIndex) or 0
    end
    return 0
end

local function GetClassColor()
    local classColor = E:ClassColor(E.myclass, true)
    return classColor.r, classColor.g, classColor.b
end

-- Get or create spec-specific special bar config
-- Returns the bar table for the current spec, creating defaults if needed
local GetSpecialBarDB = function()
    if not E.db.thingsUI.specialBars then
        E.db.thingsUI.specialBars = { specs = {} }
    end
    if not E.db.thingsUI.specialBars.specs then
        E.db.thingsUI.specialBars.specs = {}
    end
    
    local specID = GetCurrentSpecID()
    if specID == 0 then specID = 1 end  -- Fallback
    local specKey = tostring(specID)
    
    if not E.db.thingsUI.specialBars.specs[specKey] then
        -- Create fresh defaults for this spec
        E.db.thingsUI.specialBars.specs[specKey] = {}
        for _, barKey in ipairs({"bar1", "bar2", "bar3"}) do
            E.db.thingsUI.specialBars.specs[specKey][barKey] = {}
            for k, v in pairs(SPECIAL_BAR_DEFAULTS) do
                if type(v) == "table" then
                    E.db.thingsUI.specialBars.specs[specKey][barKey][k] = {}
                    for k2, v2 in pairs(v) do
                        E.db.thingsUI.specialBars.specs[specKey][barKey][k][k2] = v2
                    end
                else
                    E.db.thingsUI.specialBars.specs[specKey][barKey][k] = v
                end
            end
        end

    end
    
    return E.db.thingsUI.specialBars.specs[specKey]
end

-- Get a specific bar's DB for the current spec
local GetSpecialBarSlotDB = function(barKey)
    local specDB = GetSpecialBarDB()
    if not specDB[barKey] then
        specDB[barKey] = {}
    end
    -- Ensure all defaults exist (fill in missing keys)
    for k, v in pairs(SPECIAL_BAR_DEFAULTS) do
        if specDB[barKey][k] == nil then
            if type(v) == "table" then
                specDB[barKey][k] = {}
                for k2, v2 in pairs(v) do
                    specDB[barKey][k][k2] = v2
                end
            else
                specDB[barKey][k] = v
            end
        elseif type(v) == "table" and type(specDB[barKey][k]) == "table" then
            -- Ensure nested table has all default keys
            for k2, v2 in pairs(v) do
                if specDB[barKey][k][k2] == nil then
                    specDB[barKey][k][k2] = v2
                end
            end
        end
    end
    return specDB[barKey]
end

local specialBarUpdateFrame = CreateFrame("Frame")
local specialBarThrottle = 0.05
local specialBarNextUpdate = 0
local specialBarState = {}  -- Track state per barKey: { childFrame, originalParent, wrapperFrame }

-- Track known CDM children so we can detect newly created ones
local knownCDMChildren = {}   -- [childFrame] = true
local hookedCDMChildren = {}  -- [childFrame] = true (OnShow hooked)

-- Helper: clean text for matching (remove colors, trim spaces)
local function CleanString(str)
    if not str then return "" end
    -- Remove color codes like |c%x%x%x%x%x%x%x%x
    str = str:gsub("|c%x%x%x%x%x%x%x%x", "")
    -- Remove restore code |r
    str = str:gsub("|r", "")
    -- Trim whitespace
    str = str:match("^%s*(.-)%s*$")
    return str
end

-- Called when a BCDM child frame is shown (either new or re-shown)
-- This is the critical path for catching first-time spell casts mid-combat
local function OnCDMChildShown(childFrame)
    if not E.db.thingsUI or not E.db.thingsUI.specialBars then return end
    if not childFrame or not childFrame.Bar then return end
    
    -- Check if any special bar is waiting for this spell
    local specDB = GetSpecialBarDB()
    for barKey, barDB in pairs(specDB) do
        if type(barDB) == "table" and barDB.enabled and barDB.spellName and barDB.spellName ~= "" then
            local match = false
            local targetName = CleanString(barDB.spellName)
            
            -- Try text match first (works out of combat)
            if childFrame.Bar.Name then
                pcall(function()
                    local barText = CleanString(childFrame.Bar.Name:GetText())
                    if barText and barText ~= "" then
                        trackedBarsByName[barText] = childFrame -- cache for later lookups
                        if barText == targetName then
                            match = true
                        end
                    end
                end)
            end
            -- Fallback: match via auraSpellID (works in combat OR if user entered an ID)
            if not match and childFrame.auraSpellID then
                pcall(function()
                    -- Check if user entered a raw spell ID
                    local targetID = tonumber(targetName)
                    if targetID and targetID == childFrame.auraSpellID then
                        match = true
                    else
                        -- Check against spell info name
                    local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(childFrame.auraSpellID)
                    local resolvedName = spellInfo and spellInfo.name
                    if not resolvedName then
                        resolvedName = GetSpellInfo(childFrame.auraSpellID)
                    end
                        if resolvedName and CleanString(resolvedName) == targetName then
                        match = true
                        end
                    end
                end)
            end
            if match then
                -- This child matches a special bar! Check if we already yoinked it
                local state = specialBarState[barKey]
                if not state or not state.childFrame or state.childFrame ~= childFrame then
                    -- New match — immediately try to yoink via UpdateSpecialBarSlot
                    pcall(UpdateSpecialBarSlot, barKey)
                end
            end
        end
    end
end

-- Scan BuffBarCooldownViewer for new children and hook their OnShow
local ScanAndHookCDMChildren = function()
    if not BuffBarCooldownViewer then return end
    
    local ok, children = pcall(function() return { BuffBarCooldownViewer:GetChildren() } end)
    if not ok or not children then return end
    
    for _, childFrame in ipairs(children) do
        if childFrame and not hookedCDMChildren[childFrame] then
            hookedCDMChildren[childFrame] = true
            knownCDMChildren[childFrame] = true
            -- Hook OnShow so we catch the moment CDM activates this bar
            pcall(function()
                childFrame:HookScript("OnShow", OnCDMChildShown)
            end)
            -- If it's already shown right now, process it immediately
            local isShown = false
            pcall(function() isShown = childFrame:IsShown() end)
            if isShown then
                OnCDMChildShown(childFrame)
            end
        end
    end
end

-- Ask Blizzard CDM viewer to re-layout / refresh after re-parenting bars back.
-- Different client builds/forks expose different method names, so we try a small set safely.
local function RequestCDMRefresh()
    if not BuffBarCooldownViewer then return end
    local methods = {
        "UpdateBars",
        "Update",
        "Refresh",
        "Layout",
        "UpdateAllBars",
        "UpdateTrackedBars",
        "UpdateAura",
    }
    for _, m in ipairs(methods) do
        local fn = BuffBarCooldownViewer[m]
        if type(fn) == "function" then
            pcall(fn, BuffBarCooldownViewer)
            return
        end
    end
end

-- Wrapper frame for a yoinked bar — provides independent anchoring
local GetOrCreateWrapper = function(barKey)
    -- Check if we already have this wrapper in memory
    if specialBarState[barKey] and specialBarState[barKey].wrapper then
        return specialBarState[barKey].wrapper
    end
    
    -- Check if the frame already exists globally (prevents duplication on script reload/update)
    local frameName = "TUI_SpecialBar_" .. barKey
    local wrapper = _G[frameName] or CreateFrame("Frame", frameName, UIParent)
    
    -- Ensure default props
    if not wrapper:IsShown() then wrapper:Show() end
    wrapper:SetFrameStrata("MEDIUM")
    wrapper:SetFrameLevel(10)
    
    -- Check if backdrop exists on this frame (might be a reused frame)
    if not wrapper.backdrop then
        local bd = CreateFrame("Frame", nil, wrapper, "BackdropTemplate")
        bd:SetAllPoints(wrapper)
        bd:SetFrameLevel(wrapper:GetFrameLevel())
        bd:SetBackdrop({
            bgFile = E.media.blankTex,
            edgeFile = E.media.blankTex,
            edgeSize = 1,
        })
        bd:SetBackdropColor(0.0, 0.0, 0.0, 0.6)
        bd:SetBackdropBorderColor(0, 0, 0, 0.8)
        bd:Hide()
        wrapper.backdrop = bd
    end
    
    return wrapper
end

-- Find a tracked bar by spell name from BuffBarCooldownViewer
local FindBarBySpellName = function(spellName)
    if not BuffBarCooldownViewer or not spellName or spellName == "" then return nil end
    
    local ok, children = pcall(function() return { BuffBarCooldownViewer:GetChildren() } end)
    if not ok or not children then return nil end
    
    local targetName = CleanString(spellName)
    if trackedBarsByName[targetName] then
        return trackedBarsByName[targetName]
    end
    
    for _, childFrame in ipairs(children) do
        if childFrame and childFrame.Bar then
            local match = false
            -- Primary: try matching via Bar.Name text (works out of combat)
            if childFrame.Bar.Name then
                pcall(function()
                    local barText = CleanString(childFrame.Bar.Name:GetText())
                    if barText and barText ~= "" then
                        trackedBarsByName[barText] = childFrame -- cache for later lookups
                        if barText == targetName then
                            match = true
                        end
                    end
                end)
            end
            -- Fallback: match via auraSpellID (works in combat when GetText returns secret value)
            if not match and childFrame.auraSpellID then
                pcall(function()
                    -- Check if user entered a raw spell ID
                    local targetID = tonumber(targetName)
                    if targetID and targetID == childFrame.auraSpellID then
                        match = true
                    else
                    local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(childFrame.auraSpellID)
                    local resolvedName = spellInfo and spellInfo.name
                    if not resolvedName then
                        -- Legacy API fallback
                        resolvedName = GetSpellInfo(childFrame.auraSpellID)
                    end
                        if resolvedName and CleanString(resolvedName) == targetName then
                        match = true
                        end
                    end
                end)
            end
            if match then return childFrame end
        end
    end
    return nil
end

-- Release a yoinked bar back to its original parent
local ReleaseSpecialBar = function(barKey, opts)
    opts = opts or {}
    local state = specialBarState[barKey]
    if not state then return false end

    local returnedBar = state.childFrame
    local originalParent = state.originalParent
    local didReturn = false

    if returnedBar and originalParent then
        pcall(function()
        returnedBar:ClearAllPoints()
        returnedBar:SetParent(originalParent)

        if opts.keepHidden then
            returnedBar:Hide()
        else
            returnedBar:Show()
        end

        yoinkedBars[returnedBar] = nil
        didReturn = true

        end)
    end

    if state.wrapper then
        if state.wrapper.backdrop then state.wrapper.backdrop:Hide() end
        state.wrapper:Hide()
    end

    specialBarState[barKey] = nil

    -- Only refresh CDM / BuffBars if we actually returned something
    if didReturn then
        C_Timer.After(0, function()
            if RequestCDMRefresh then pcall(RequestCDMRefresh) end

            -- only mark this returned bar dirty (cheap) then run viewer update once
            if ns and ns.skinnedBars and returnedBar then
                ns.skinnedBars[returnedBar] = nil
            end

            -- This is the part that causes "BuffBars update stuff".
            -- Keep it here (disable path), but NOT in option-change paths.
            if TUI and TUI.UpdateBuffBars then
                pcall(function() TUI:UpdateBuffBars() end)
            end
        end)
    end
    return didReturn
end

-- Style a yoinked bar with special bar settings
local StyleSpecialBar = function(childFrame, db)
    local bar = childFrame.Bar
    local icon = childFrame.Icon
    if not bar then return end
    
    -- SIZING: childFrame is strictly sized.
    -- We need to split the backdrops for spacing to work.
    
    -- 1. Use the childFrame.tuiBackdrop as the BAR backdrop (repurposed)
    if not childFrame.tuiBackdrop then
        childFrame.tuiBackdrop = CreateFrame("Frame", nil, childFrame, "BackdropTemplate")
        childFrame.tuiBackdrop:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
    end
    -- We will position this backdrop later based on offset
    childFrame.tuiBackdrop:SetBackdropColor(0, 0, 0, 0.6)
    childFrame.tuiBackdrop:SetBackdropBorderColor(0, 0, 0, 1)
    childFrame.tuiBackdrop:SetFrameLevel(childFrame:GetFrameLevel() - 1)

    local height = db.height
    local barOffset = 0

    -- 2. ICON STYLING
    if db.iconEnabled and icon then
        icon:Show()
        icon:SetSize(height, height) -- Square icon match bar height
        
        if icon.Icon then
            icon.Icon:SetTexCoord(db.iconZoom or 0.1, 1-(db.iconZoom or 0.1), db.iconZoom or 0.1, 1-(db.iconZoom or 0.1))
            icon.Icon:SetDrawLayer("ARTWORK", 1) 
            -- Inset texture
            icon.Icon:ClearAllPoints()
            icon.Icon:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
            icon.Icon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
        end
        
        -- Icon Backdrop
        if not icon.tuiBackdrop then
            icon.tuiBackdrop = CreateFrame("Frame", nil, icon, "BackdropTemplate")
            icon.tuiBackdrop:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
            icon.tuiBackdrop:SetBackdropColor(0, 0, 0, 1)
            icon.tuiBackdrop:SetBackdropBorderColor(0, 0, 0, 1)
        end
        icon.tuiBackdrop:Show()
        icon.tuiBackdrop:SetAllPoints(icon)
        icon.tuiBackdrop:SetFrameLevel(icon:GetFrameLevel() - 1)
        
        -- Icon Position
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", childFrame, "LEFT", 0, 0)
        
        barOffset = height + (db.iconSpacing or 3)
    elseif icon then
        icon:Hide()
        barOffset = 0
    end
    
    -- 3. BAR BACKDROP POSITIONING
    childFrame.tuiBackdrop:Show()
    childFrame.tuiBackdrop:ClearAllPoints()
    childFrame.tuiBackdrop:SetPoint("TOPLEFT", childFrame, "TOPLEFT", barOffset, 0)
    childFrame.tuiBackdrop:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", 0, 0)

    -- 4. BAR POSITIONING (Inset inside the bar backdrop)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", childFrame.tuiBackdrop, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", childFrame.tuiBackdrop, "BOTTOMRIGHT", -1, 1)
    
    -- Show Name logic
    local font = LSM:Fetch("font", db.font)
    if bar.Name then
        if db.showName then
            bar.Name:Show()
            bar.Name:SetFont(font, db.fontSize, db.fontOutline)
            bar.Name:ClearAllPoints()
            bar.Name:SetPoint(db.namePoint or "LEFT", bar, db.namePoint or "LEFT", db.nameXOffset or 4, db.nameYOffset or 0)
        else
            bar.Name:Hide()
        end
    end
    
    -- Show Duration logic
    if bar.Duration then
        if db.showDuration then
            bar.Duration:Show()
            bar.Duration:SetFont(font, db.fontSize, db.fontOutline)
            bar.Duration:ClearAllPoints()
            bar.Duration:SetPoint(db.durationPoint or "RIGHT", bar, db.durationPoint or "RIGHT", db.durationXOffset or -4, db.durationYOffset or 0)
        else
            bar.Duration:Hide()
        end
    end
    
    -- Statusbar Texture & Colors
    bar:SetStatusBarTexture(LSM:Fetch("statusbar", db.statusBarTexture))
    if db.useClassColor then bar:SetStatusBarColor(GetClassColor()) else bar:SetStatusBarColor(db.customColor.r, db.customColor.g, db.customColor.b) end
    if bar.BarBG then bar.BarBG:SetAlpha(0) end
    if bar.Pip then bar.Pip:SetAlpha(0) end
    
    -- Fonts
    local font = LSM:Fetch("font", db.font)
    if bar.Name then bar.Name:SetFont(font, db.fontSize, db.fontOutline) end
    if bar.Duration then bar.Duration:SetFont(font, db.fontSize, db.fontOutline) end
end

-- Main update for a single special bar slot
local UpdateSpecialBarSlot = function(barKey)
    local db = GetSpecialBarSlotDB(barKey)
    if not db or not db.enabled or not db.spellName or db.spellName == "" then
        ReleaseSpecialBar(barKey)
        return
    end
    
    local state = specialBarState[barKey]
    local childFrame
    local resolvedAnchor = ResolveAnchorFrame(db)
    local anchorFrame = _G[resolvedAnchor]

    -- STRICT SIZING: Do not guess borders. Use raw values.
    local effectiveWidth = db.width
    if db.inheritWidth and anchorFrame then
        local aw = anchorFrame:GetWidth()
        if aw and aw > 0 then 
            effectiveWidth = aw + (db.inheritWidthOffset or 0)
        end
    end

    -- Height handling:
    -- When inheritHeight is enabled we MUST NOT permanently overwrite db.height.
    -- Otherwise the UI "sticks" to the anchor's height after you disable inherit.
    --
    -- We store the user's previous value once in db._tui_prevHeight, compute an
    -- effectiveHeight for this update pass, and restore when inherit is turned off.
    local effectiveHeight = db.height
    if db.inheritHeight and anchorFrame then
        if db._tui_prevHeight == nil then
            db._tui_prevHeight = db.height
        end
        local ah = anchorFrame:GetHeight()
        if ah and ah > 0 then
            effectiveHeight = ah + (db.inheritHeightOffset or 0)
        end
    else
        if db._tui_prevHeight ~= nil then
            db.height = db._tui_prevHeight
            db._tui_prevHeight = nil
        end
        effectiveHeight = db.height
    end
    
    if state and state.childFrame then
        local stillValid = false
        pcall(function() if state.childFrame.Bar and state.childFrame.Bar.Name then stillValid = true end end)
        if stillValid then
            childFrame = state.childFrame
            yoinkedBars[childFrame] = true
        else
            if state.childFrame then yoinkedBars[state.childFrame] = nil end
            if state.wrapper then state.wrapper:Hide() end
            specialBarState[barKey] = nil
            state = nil
        end
    end
    
    if not childFrame then
        ScanAndHookCDMChildren()
        childFrame = FindBarBySpellName(db.spellName)
    end
    
    if not childFrame then
        -- Only scan for spell typed in Special Bar #
        childFrame = FindBarBySpellName(db.spellName)
        
        -- If still not found, schedule a full scan (but throttle it)
        if not childFrame and not TUI.scanScheduled then
            TUI.scanScheduled = true
            C_Timer.After(0.5, function()
                ScanAndHookCDMChildren()
                -- Also try to find this specific bar again
                TUI.scanScheduled = nil
                -- Force an immediate retry (go fast - should work if not lmk /D.G)
                TUI:UpdateSpecialBars()
            end)
        end
    end

    local wrapper = GetOrCreateWrapper(barKey)
    
    -- Apply strict sizing to wrapper
    wrapper:SetSize(effectiveWidth, effectiveHeight)
    
    pcall(function()
        if anchorFrame then
            wrapper:ClearAllPoints()
            wrapper:SetPoint(db.anchorPoint, anchorFrame, db.anchorRelativePoint, db.anchorXOffset, db.anchorYOffset)
        end
    end)
    
    -- Placeholder logic (Backdrop)
    if wrapper.backdrop then
        if db.showBackdrop and (not childFrame or not childFrame:IsShown()) then
            wrapper.backdrop:Show()
            wrapper:Show()
            
            -- Adjust placeholder to match the split layout (Only show "Bar" area)
            local bc = db.backdropColor or { r = 0.1, g = 0.1, b = 0.1, a = 0.6 }
            wrapper.backdrop:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
            wrapper.backdrop:ClearAllPoints()
            wrapper.backdrop:SetPoint("TOPLEFT", wrapper, "TOPLEFT", 0, 0)
            wrapper.backdrop:SetPoint("BOTTOMRIGHT", wrapper, "BOTTOMRIGHT", 0, 0)
            
        else
            wrapper.backdrop:Hide()
            if not childFrame then wrapper:Hide() end
        end
    end
    
    -- No child frame? We are done (just showed placeholder if needed)
    if not childFrame then
        if not specialBarState[barKey] then specialBarState[barKey] = { wrapper = wrapper } end
        return
    end
    
    local isActive = false
    pcall(function() isActive = childFrame:IsShown() end)
    yoinkedBars[childFrame] = true
    
    if not isActive then
        return
    end

    if not state or state.childFrame ~= childFrame then
        if state and state.childFrame and state.childFrame ~= childFrame then
            yoinkedBars[state.childFrame] = nil
            if state.originalParent then pcall(function() state.childFrame:SetParent(state.originalParent) end) end
        end
        
        specialBarState[barKey] = {
            childFrame = childFrame,
            originalParent = childFrame:GetParent(),
            wrapper = wrapper,
        }
        state = specialBarState[barKey]
    end
    
    -- Parent the child to the wrapper
    pcall(function()
        if childFrame:GetParent() ~= wrapper then childFrame:SetParent(wrapper) end
        
        -- Resize the actual childFrame to match wrapper exactly
        childFrame:SetSize(effectiveWidth, effectiveHeight)
        
        childFrame:ClearAllPoints()
        childFrame:SetPoint("CENTER", wrapper, "CENTER", 0, 0)
    end)
    
    -- Apply styling (texture, icon pos, etc)
    -- StyleSpecialBar expects db.height for icon sizing; use the computed
    -- effectiveHeight WITHOUT permanently overwriting the user's configured value.
    local oldHeight = db.height
    db.height = effectiveHeight
    pcall(StyleSpecialBar, childFrame, db)
    db.height = oldHeight
    wrapper:Show()
end

local function SpecialBarOnUpdate()
    -- This is only used when buff bar skinning is disabled but special bars are active
    local currentTime = GetTime()
    if currentTime < specialBarNextUpdate then return end
    specialBarNextUpdate = currentTime + specialBarThrottle
    
    if not E.db.thingsUI or not E.db.thingsUI.specialBars then return end
    if not BuffBarCooldownViewer then return end
    
    -- CDM children are hooked via OnShow; avoid expensive rescans here
    
    local specDB = GetSpecialBarDB()
    for barKey, barDB in pairs(specDB) do
        if type(barDB) == "table" then
            pcall(UpdateSpecialBarSlot, barKey)
        end
    end
end

function TUI:UpdateSpecialBars()
    if not E.db.thingsUI.specialBars then return end
    
    -- Hook existing CDM children immediately so we catch OnShow events
    ScanAndHookCDMChildren()
    
    local specDB = GetSpecialBarDB()
    local anyEnabled = false
    local releasedAny = false
    
    -- First release any bars from OTHER specs that might be yoinked
    for barKey, state in pairs(specialBarState) do
        local db = specDB[barKey]
        if not db or not db.enabled or not db.spellName or db.spellName == "" then
            if ReleaseSpecialBar(barKey) then releasedAny = true end
        end
    end
    
    for barKey, barDB in pairs(specDB) do
        if type(barDB) == "table" and barDB.enabled and barDB.spellName and barDB.spellName ~= "" then
            anyEnabled = true
        else
            if type(barDB) == "table" then
                if ReleaseSpecialBar(barKey) then releasedAny = true end
            end
        end
    end
    
    if anyEnabled then
        if not E.db.thingsUI.buffBars or not E.db.thingsUI.buffBars.enabled then
            specialBarUpdateFrame:SetScript("OnUpdate", SpecialBarOnUpdate)
        end
        if barUpdateFrame and BuffBarOnUpdate then
            barUpdateFrame:SetScript("OnUpdate", BuffBarOnUpdate)
        end

        -- Apply changes immediately for option updates (no waiting for delayed scans / OnUpdate)
        for barKey, barDB in pairs(specDB) do
            if type(barDB) == "table" and barDB.enabled and barDB.spellName and barDB.spellName ~= "" then
                pcall(UpdateSpecialBarSlot, barKey)
            end
        end

        
        -- Schedule additional scans to catch CDM children created after init
        -- CDM may create bar frames slightly later during loading
        -- Only schedule init scans once (login/enable), not on every options tweak
        if not TUI._specialBarsInitScansScheduled then
            TUI._specialBarsInitScansScheduled = true

            for _, delay in ipairs({ 0.5, 1.0, 2.0, 5.0 }) do
                C_Timer.After(delay, function()
                    ScanAndHookCDMChildren()
                    -- Also try to yoink immediately on each delayed scan
                    local currentSpecDB = GetSpecialBarDB()
                    for barKey, barDB in pairs(currentSpecDB) do
                        if type(barDB) == "table" and barDB.enabled and barDB.spellName and barDB.spellName ~= "" then
                            pcall(UpdateSpecialBarSlot, barKey)
                        end
                    end
                end)
            end
        end
    else
        specialBarUpdateFrame:SetScript("OnUpdate", nil)
        TUI._specialBarsInitScansScheduled = nil
        for barKey, _ in pairs(specialBarState) do
            if ReleaseSpecialBar(barKey) then releasedAny = true end
        end
    end

    if releasedAny then
        C_Timer.After(0, RequestCDMRefresh)
    end
end

ns.SpecialBars = ns.SpecialBars or {}
ns.SpecialBars.ScanAndHookCDMChildren = ScanAndHookCDMChildren
ns.SpecialBars.GetSpecialBarDB = GetSpecialBarDB
ns.SpecialBars.UpdateSpecialBarSlot = UpdateSpecialBarSlot
ns.SpecialBars.ReleaseSpecialBar = ReleaseSpecialBar
ns.SpecialBars.specialBarState = specialBarState
ns.SpecialBars.CleanString = CleanString
ns.SpecialBars.SPECIAL_BAR_DEFAULTS = SPECIAL_BAR_DEFAULTS
ns.SpecialBars.GetSpecialBarSlotDB = GetSpecialBarSlotDB