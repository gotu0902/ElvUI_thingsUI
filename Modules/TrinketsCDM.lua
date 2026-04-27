local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

ns.TrinketsCDM = ns.TrinketsCDM or {}
local M = ns.TrinketsCDM

local savedContainerPoint  = nil
local savedEssPoint        = nil   -- EssentialCooldownViewer position before our shift
local savedUtilityPoint    = nil   -- UtilityCooldownViewer position before FHT overflow nudge

local isApplied      = false
local isInUtilityMode = false   -- true when FHT overflow has trinkets at utility position

M._suppressHook    = false
M._suppressEssHook = false
M._suppressDepHook = false

local ESSENTIAL_DEPENDENTS = {
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "BCDM_PowerBar",
    "BCDM_SecondaryPowerBar",
    "BCDM_CastBar",
}

local currentDepShifts = {}
local updateQueued = false

local function GetBCDMProfile()
    if type(BCDMDB) ~= "table" then return nil end
    local profiles = rawget(BCDMDB, "profiles")
    if type(profiles) ~= "table" then return nil end
    local keys = rawget(BCDMDB, "profileKeys")

    local name  = UnitName("player")
    local realm = GetRealmName()
    if name and name ~= "" and name ~= "Unknown" and realm then
        local key = name .. " - " .. realm
        local profileName = keys and keys[key]
        if profileName and profiles[profileName] then
            return profiles[profileName]
        end
    end

    -- Fallback: first profile with CooldownManager data
    for _, p in pairs(profiles) do
        if type(p) == "table" and p.CooldownManager then return p end
    end
    return nil
end

local function GetBCDMEssentialIconSize()
    local profile = GetBCDMProfile()
    local v = profile and profile.CooldownManager
              and profile.CooldownManager.Essential
              and profile.CooldownManager.Essential.IconSize
    if type(v) == "number" and v > 0 then return v end
    return 42
end

local function GetBCDMTrinketSpacing()
    local profile = GetBCDMProfile()
    if not profile then return 2 end
    return (profile.CooldownManager
        and profile.CooldownManager.Trinket
        and profile.CooldownManager.Trinket.Spacing) or 2
end

local function GetBCDMUtilityIconSize()
    local profile = GetBCDMProfile()
    if not profile then return 42 end
    return (profile.CooldownManager
        and profile.CooldownManager.Utility
        and profile.CooldownManager.Utility.IconSize) or 42
end

local function CountVisibleChildren(frame)
    if not frame then return 0 end
    local count = 0
    for i = 1, frame:GetNumChildren() do
        local child = select(i, frame:GetChildren())
        if child and child:IsShown() then count = count + 1 end
    end
    return count
end

local function CountActiveTrinkets()
    return CountVisibleChildren(_G["BCDM_TrinketBar"])
end

function M.GetExtraEssentialCount()
    local db = E.db.thingsUI and E.db.thingsUI.trinketsCDM
    if not db or not db.enabled or not isApplied or isInUtilityMode then return 0 end
    return CountActiveTrinkets()
end

local function SaveContainerPoint()
    if savedContainerPoint then return end  -- already saved
    local c = _G["BCDM_TrinketBar"]
    if not c then return end
    local p, rel, rp, x, y = c:GetPoint(1)
    if p and rel then
        savedContainerPoint = { p, rel, rp, x or 0, y or 0 }
    end
end

local function RestoreContainerPoint()
    if not savedContainerPoint then return end
    local c = _G["BCDM_TrinketBar"]
    if c then
        M._suppressHook = true
        c:ClearAllPoints()
        c:SetPoint(
            savedContainerPoint[1], savedContainerPoint[2], savedContainerPoint[3],
            savedContainerPoint[4], savedContainerPoint[5]
        )
        M._suppressHook = false
    end
    savedContainerPoint = nil
end

local function SaveEssentialPoint()
    if savedEssPoint then return end  -- already saved
    local ev = _G["EssentialCooldownViewer"]
    if not ev then return end
    local p, rel, rp, x, y = ev:GetPoint(1)
    if p and rel then
        savedEssPoint = { p, rel, rp, x or 0, y or 0 }
    end
end

local function RestoreEssentialPoint()
    if not savedEssPoint then return end
    local ev = _G["EssentialCooldownViewer"]
    if ev then
        M._suppressEssHook = true
        ev:ClearAllPoints()
        ev:SetPoint(
            savedEssPoint[1], savedEssPoint[2], savedEssPoint[3],
            savedEssPoint[4], savedEssPoint[5]
        )
        M._suppressEssHook = false
    end
    savedEssPoint = nil
end

local function ShiftEssentialViewer(xDelta)
    if not savedEssPoint then return end
    local ev = _G["EssentialCooldownViewer"]
    if not ev then return end
    M._suppressEssHook = true
    ev:ClearAllPoints()
    ev:SetPoint(
        savedEssPoint[1], savedEssPoint[2], savedEssPoint[3],
        savedEssPoint[4] + xDelta, savedEssPoint[5]
    )
    M._suppressEssHook = false
end

local function ResizeTrinketIcons(iconSize, spacing, vertical)
    iconSize = tonumber(iconSize) or 42
    spacing  = tonumber(spacing)  or 2
    if iconSize <= 0 then iconSize = 42 end

    local c = _G["BCDM_TrinketBar"]
    if not c then return end
    local count = 0
    local prevIcon = nil
    for i = 1, c:GetNumChildren() do
        local child = select(i, c:GetChildren())
        if child and child:IsShown() then
            count = count + 1
            child:SetSize(iconSize, iconSize)
            child:ClearAllPoints()
            if vertical then
                if count == 1 then
                    child:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
                else
                    child:SetPoint("TOP", prevIcon, "BOTTOM", 0, -spacing)
                end
            else
                if count == 1 then
                    child:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
                else
                    child:SetPoint("LEFT", prevIcon, "RIGHT", spacing, 0)
                end
            end
            prevIcon = child
        end
    end
    if count > 0 then
        if vertical then
            c:SetSize(iconSize, count * iconSize + (count - 1) * spacing)
        else
            c:SetSize(count * iconSize + (count - 1) * spacing, iconSize)
        end
    end
end

local function ShiftAllDependents(targetShift)
    local essViewer = _G["EssentialCooldownViewer"]
    for _, name in ipairs(ESSENTIAL_DEPENDENTS) do
        local f = _G[name]
        if f and f:GetNumPoints() > 0 then
            local p, rel, rp, x, y = f:GetPoint(1)
            if rel == essViewer then
                local cur = currentDepShifts[name] or 0
                local netDelta = targetShift - cur
                if netDelta ~= 0 then
                    M._suppressDepHook = true
                    f:ClearAllPoints()
                    f:SetPoint(p, rel, rp, x + netDelta, y)
                    M._suppressDepHook = false
                end
                currentDepShifts[name] = targetShift
            end
        end
    end
end

-- Undo whatever shift we've applied to all dependent bars.
local function RestoreAllDependents()
    local essViewer = _G["EssentialCooldownViewer"]
    for _, name in ipairs(ESSENTIAL_DEPENDENTS) do
        local cur = currentDepShifts[name] or 0
        if cur ~= 0 then
            local f = _G[name]
            if f and f:GetNumPoints() > 0 then
                local p, rel, rp, x, y = f:GetPoint(1)
                if rel == essViewer then
                    M._suppressDepHook = true
                    f:ClearAllPoints()
                    f:SetPoint(p, rel, rp, x - cur, y)
                    M._suppressDepHook = false
                end
            end
        end
        currentDepShifts[name] = 0
    end
end

function M.ResetDepShift(barName)
    currentDepShifts[barName] = 0
end

local function SaveUtilityPoint()
    if savedUtilityPoint then return end
    local uv = _G["UtilityCooldownViewer"]
    if not uv then return end
    local p, rel, rp, x, y = uv:GetPoint(1)
    if p and rel then
        savedUtilityPoint = { p, rel, rp, x or 0, y or 0 }
    end
end

local function RestoreUtilityPoint()
    if not savedUtilityPoint then return end
    local uv = _G["UtilityCooldownViewer"]
    if uv then
        uv:ClearAllPoints()
        uv:SetPoint(
            savedUtilityPoint[1], savedUtilityPoint[2], savedUtilityPoint[3],
            savedUtilityPoint[4], savedUtilityPoint[5]
        )
    end
    savedUtilityPoint = nil
end

local function PlaceContainer(anchorPoint, anchorParent, anchorRelPoint, xOff, yOff)
    local c = _G["BCDM_TrinketBar"]
    if not c then return end
    M._suppressHook = true
    c:ClearAllPoints()
    c:SetPoint(anchorPoint, anchorParent, anchorRelPoint, xOff or 0, yOff or 0)
    M._suppressHook = false
end

local function ApplyTrinketPosition(db)
    if InCombatLockdown() then
        -- queue a retry on combat end
        if not M._combatRetryHooked then
            M._combatRetryHooked = true
            TUI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
                TUI:UnregisterEvent("PLAYER_REGEN_ENABLED")
                M._combatRetryHooked = nil
                M.QueueUpdate()
            end)
        end
        return
    end


    local essViewer = _G["EssentialCooldownViewer"]
    if not essViewer then return end

    SaveContainerPoint()

    local side         = db.side or "RIGHT"
    local essIconSize  = GetBCDMEssentialIconSize()
    local trinketSpace = GetBCDMTrinketSpacing()

    if db.mode == "NHT" then
        if isInUtilityMode then
            RestoreUtilityPoint()
            isInUtilityMode = false
        end

        -- Container's left/right edge anchors to Essential's right/left edge.
        local fromPt = (side == "RIGHT") and "BOTTOMLEFT"  or "BOTTOMRIGHT"
        local relPt  = (side == "RIGHT") and "BOTTOMRIGHT" or "BOTTOMLEFT"
        local gap    = db.gap or 1
        local gapX   = (side == "RIGHT") and gap or -gap

        PlaceContainer(fromPt, essViewer, relPt, gapX, 0)

        -- Resize trinket icons to match Essential and update container dimensions.
        ResizeTrinketIcons(essIconSize, trinketSpace)
        RestoreEssentialPoint()
        SaveEssentialPoint()
        local trinketCount = CountActiveTrinkets()
        if trinketCount > 0 then
            local trinketBarW  = trinketCount * essIconSize + math.max(0, trinketCount - 1) * trinketSpace
            local xDelta = (side == "RIGHT") and -((trinketBarW + gap) / 2) or ((trinketBarW + gap) / 2)
            ShiftEssentialViewer(xDelta)
            ShiftAllDependents(-xDelta)

            -- MatchWidthOfAnchor bars should span the full combined width (including gap).
            local essW = essViewer:GetWidth()
            if essW and essW > 1 then
                C_Timer.After(0.15, function() M.ApplyMatchWidth(essW + gap) end)
            end
        else
            -- No trinkets: undo any previous shifts.
            ShiftAllDependents(0)
        end

        isApplied      = true
        isInUtilityMode = false

    elseif db.mode == "FHT" then

        RestoreEssentialPoint()
        RestoreAllDependents()

        local essCount     = CountVisibleChildren(essViewer)
        local trinketCount = CountActiveTrinkets()
        local limit        = db.fhtLimit or 9
        local gap          = db.gap or 1

        -- How many trinkets fit below Essential before overflowing.
        local fitsCount    = math.max(0, limit - essCount)
        local overflowCount = math.max(0, trinketCount - fitsCount)

        if overflowCount == 0 then
            -- All fit: restore utility if previously nudged, place all below Essential.
            if isInUtilityMode then
                RestoreUtilityPoint()
                isInUtilityMode = false
            end

            local fromPt = "TOPRIGHT"
            local relPt  = "BOTTOMRIGHT"
            PlaceContainer(fromPt, essViewer, relPt, 0, -gap)
            ResizeTrinketIcons(essIconSize, trinketSpace, true)

            isApplied       = true
            isInUtilityMode = false

        else
            -- Split: first fitsCount icons below Essential, remainder at Utility slot.
            if not isInUtilityMode then SaveUtilityPoint() end
            if not savedUtilityPoint then return end

            local uv = _G["UtilityCooldownViewer"]
            local utilIconSize = GetBCDMUtilityIconSize()
            local c  = _G["BCDM_TrinketBar"]
            if not uv or not c then return end

            -- Layout all icons manually: fitsCount in container below Essential,
            -- overflow icons anchored directly to Utility (outside container).
            local count = 0
            local prevFit = nil
            local prevOver = nil
            for i = 1, c:GetNumChildren() do
                local child = select(i, c:GetChildren())
                if child and child:IsShown() then
                    count = count + 1
                    local overflowIdx = count - fitsCount
                    if overflowIdx <= 0 then
                        -- Fits below Essential: position inside container vertically.
                        child:SetSize(essIconSize, essIconSize)
                        child:ClearAllPoints()
                        if prevFit == nil then
                            child:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
                        else
                            child:SetPoint("TOP", prevFit, "BOTTOM", 0, -trinketSpace)
                        end
                        prevFit = child
                    else
                        -- Overflow: anchor to Utility's saved (pre-nudge) position.
                        child:SetSize(utilIconSize, utilIconSize)
                        child:ClearAllPoints()
                        local sp = savedUtilityPoint
                        if overflowIdx == 1 then
                            child:SetPoint(sp[1], sp[2], sp[3], sp[4], sp[5])
                        else
                            child:SetPoint("TOP", prevOver, "BOTTOM", 0, -trinketSpace)
                        end
                        prevOver = child
                    end
                end
            end

            -- Resize container to fit only the icons that belong to it.
            if fitsCount > 0 then
                local containerH = fitsCount * essIconSize + (fitsCount - 1) * trinketSpace
                c:SetSize(essIconSize, containerH)
                PlaceContainer("TOPRIGHT", essViewer, "BOTTOMRIGHT", 0, -gap)
            else
                -- No icons fit below Essential; hide the container out of the way.
                c:SetSize(0.1, 0.1)
                PlaceContainer("TOPRIGHT", essViewer, "BOTTOMRIGHT", 0, 0)
            end

            -- Nudge Utility down by the overflow icons' total height + gap.
            local sp = savedUtilityPoint
            local overflowH = overflowCount * utilIconSize + (overflowCount - 1) * trinketSpace
            uv:ClearAllPoints()
            uv:SetPoint(sp[1], sp[2], sp[3], sp[4], sp[5] - overflowH - gap)

            isApplied       = true
            isInUtilityMode = true
        end
    end

    if TUI.QueueClusterUpdate then TUI:QueueClusterUpdate() end

    local db = E.db.thingsUI and E.db.thingsUI.trinketsCDM
    local isNHTWithTrinkets = db.mode == "NHT" and isApplied and CountActiveTrinkets() > 0
    if not isNHTWithTrinkets then
        C_Timer.After(0.15, function()
            M.ApplyMatchWidth()
        end)
    end
end

function M.ApplyMatchWidth(overrideWidth)
    local essViewer = _G["EssentialCooldownViewer"]
    if not essViewer then return end
    local combinedW = overrideWidth or essViewer:GetWidth()
    if not combinedW or combinedW < 1 then return end
    local profile = GetBCDMProfile()
    if not profile then return end
    local barMap = {
        ["BCDM_PowerBar"]          = profile.PowerBar,
        ["BCDM_SecondaryPowerBar"] = profile.SecondaryPowerBar,
        ["BCDM_CastBar"]          = profile.CastBar,
    }
    for barName, barDB in pairs(barMap) do
        if barDB and barDB.MatchWidthOfAnchor then
            local f = _G[barName]
            if f then
                f:SetWidth(combinedW)
            end
        end
    end
end

-- Called from Init.lua hooks when BCDM repositions Essential.
function M.ResetEssentialSavedPoint()
    savedEssPoint = nil
end

function M.QueueUpdate()
    if updateQueued then return end
    updateQueued = true
    C_Timer.After(0, function()
        updateQueued = false
        if E.db.thingsUI and E.db.thingsUI.trinketsCDM and E.db.thingsUI.trinketsCDM.enabled then
            TUI:UpdateTrinketsCDM()
        end
    end)
end

function M.GetNHTAnchor()
    if not isApplied or isInUtilityMode then return nil end
    local db = E.db.thingsUI and E.db.thingsUI.trinketsCDM
    if not db or db.mode ~= "NHT" then return nil end
    if CountActiveTrinkets() == 0 then return nil end
    return db.side or "RIGHT"
end

function TUI:UpdateTrinketsCDM()
    local db = E.db.thingsUI and E.db.thingsUI.trinketsCDM

    if not db or not db.enabled then
        if isApplied then
            RestoreContainerPoint()
            RestoreEssentialPoint()
            RestoreAllDependents()
            RestoreUtilityPoint()
            isApplied      = false
            isInUtilityMode = false
            if TUI.QueueClusterUpdate then TUI:QueueClusterUpdate() end
        end
        return
    end

    if not _G["BCDM_TrinketBar"] then return end

    ApplyTrinketPosition(db)
end