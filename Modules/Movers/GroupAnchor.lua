local _, ns = ...
local TUI = ns.TUI
local E   = ns.E

-- ElvUI hangs a group header off its mover by the header's BOTTOMLEFT, saves
-- the mover by the corner of the screen third it sits in, and clamps it to the
-- screen with the footprint of every configured group. Frames growing from any
-- other corner shift whenever the header resizes or that footprint would leave
-- the screen. A locked group pins one corner instead: the mover is saved by it,
-- the header hangs off it there, and the mover may run past the screen edge.

local GA = {}
ns.GroupAnchor = GA

GA.GROUPS = { "party", "raid1", "raid2", "raid3" }
GA.LABELS = { party = "Party", raid1 = "Raid 1", raid2 = "Raid 2", raid3 = "Raid 3" }

-- ElvUI's DIRECTION_TO_GROUP_ANCHOR_POINT (OUT_ = start from center)
local GROWTH_CORNER = {
    DOWN_RIGHT = "TOPLEFT", DOWN_LEFT = "TOPRIGHT", UP_RIGHT = "BOTTOMLEFT", UP_LEFT = "BOTTOMRIGHT",
    RIGHT_DOWN = "TOPLEFT", RIGHT_UP = "BOTTOMLEFT", LEFT_DOWN = "TOPRIGHT", LEFT_UP = "BOTTOMRIGHT",
}
local CENTER_CORNER = {
    RIGHT_UP = "BOTTOM", LEFT_UP = "BOTTOM", RIGHT_DOWN = "TOP", LEFT_DOWN = "TOP",
    UP_RIGHT = "LEFT", UP_LEFT = "RIGHT", DOWN_RIGHT = "LEFT", DOWN_LEFT = "RIGHT",
}

local function UF() return E:GetModule("UnitFrames", true) end

local function DB() return E.db.thingsUI and E.db.thingsUI.groupAnchor end

-- nil = ElvUI's own handling
function GA.CornerFor(group)
    local db = DB()
    local v = db and db[group]
    if not v or v == "ELVUI" then return nil end
    if v ~= "GROWTH" then return v end
    local u = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units[group]
    local dir = u and u.growthDirection or ""
    if u and u.startFromCenter and (group == "party" or u.raidWideSorting) then
        return CENTER_CORNER[dir] or "TOP"
    end
    return GROWTH_CORNER[dir] or "TOPLEFT"
end

local function HeaderOf(group)
    local uf = UF()
    local header = uf and uf[group]
    return header, header and header.mover
end

local function GroupOfMover(name)
    for _, group in ipairs(GA.GROUPS) do
        local _, mover = HeaderOf(group)
        if mover and mover.name == name then return group end
    end
end

-- where `corner` of the frame sits, as offsets from the same corner of E.UIParent
local function CornerOffsets(frame, corner)
    local p = E.UIParent
    local l, b, w, h = frame:GetRect()
    local pl, pb, pw, ph = p:GetRect()
    if not (l and pl and w and w > 0) then return end
    local k = frame:GetEffectiveScale() / p:GetEffectiveScale()
    l, b, w, h = l * k - pl, b * k - pb, w * k, h * k
    local fx, fy, rx, ry = l + w / 2, b + h / 2, pw / 2, ph / 2
    if corner:find("LEFT")   then fx, rx = l, 0      end
    if corner:find("RIGHT")  then fx, rx = l + w, pw end
    if corner:find("TOP")    then fy, ry = b + h, ph end
    if corner:find("BOTTOM") then fy, ry = b, 0      end
    return E:Round(fx - rx), E:Round(fy - ry)
end

local pinning, pendingRegen = false, false
local pinned = {}

local function Pin(group)
    local corner = GA.CornerFor(group)
    local header, mover = HeaderOf(group)
    if not (corner and mover) then return end
    -- the header is a secure frame
    if InCombatLockdown() then pendingRegen = true; return end
    local x, y = CornerOffsets(mover, corner)
    if not x then return end
    pinning = true
    mover:SetClampedToScreen(false)
    mover:ClearAllPoints()
    mover:SetPoint(corner, E.UIParent, corner, x, y)
    E:SaveMoverPosition(mover.name)
    header:ClearAllPoints()
    header:SetPoint(corner, mover, corner)
    pinning = false
    pinned[group] = true
end

-- back to ElvUI's own anchoring
local function Unpin(group)
    local header, mover = HeaderOf(group)
    if not (pinned[group] and mover) then return end
    if InCombatLockdown() then pendingRegen = true; return end
    pinned[group] = nil
    mover:SetClampedToScreen(true)
    E:SetMoverPoints(mover.name, header)
end

function GA.Apply(group)
    if not (UF() and E.SaveMoverPosition) then return end
    for _, g in ipairs(group and { group } or GA.GROUPS) do
        if GA.CornerFor(g) then Pin(g) else Unpin(g) end
    end
end

local hooked = false
local function Hook()
    local uf = UF()
    if hooked or not (uf and uf.CreateAndUpdateHeaderGroup and E.SaveMoverPosition) then return end
    hooked = true
    -- ElvUI re-anchors the header every time it configures the group
    hooksecurefunc(uf, "CreateAndUpdateHeaderGroup", function(_, group)
        if GA.CornerFor(group) then Pin(group) end
    end)
    -- drag, nudge and every other save: keep it in the pinned corner
    hooksecurefunc(E, "SaveMoverPosition", function(_, name)
        if pinning then return end
        local group = GroupOfMover(name)
        if group and GA.CornerFor(group) then Pin(group) end
    end)
    hooksecurefunc(E, "SetMoverPoints", function(_, name)
        if pinning then return end
        local group = GroupOfMover(name)
        if group and GA.CornerFor(group) then Pin(group) end
    end)
    -- a UI scale change re-clamps every mover
    hooksecurefunc(E, "SetMoversClampedToScreen", function()
        for _, g in ipairs(GA.GROUPS) do
            local _, mover = HeaderOf(g)
            if mover and GA.CornerFor(g) then mover:SetClampedToScreen(false) end
        end
    end)
end

function TUI:UpdateGroupAnchor()
    Hook()
    GA.Apply()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function()
    if pendingRegen then
        pendingRegen = false
        GA.Apply()
    end
end)
