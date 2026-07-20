local _, ns = ...
local TUI = ns.TUI
local E   = ns.E

ns.MBB = ns.MBB or {}
local M = ns.MBB

local function DB() return E.db.thingsUI and E.db.thingsUI.mbb end
local function MainButton() return _G.MinimapButtonButtonButton end
local function Loaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MinimapButtonButton") and MainButton()
end

local function ApplyPosition()
    local db = DB()
    local btn = MainButton()
    if not (db and db.manage and btn) then return end
    local target = ns.ANCHORS.ResolveAnchorTarget(db.anchor or "Minimap") or _G.UIParent
    local point = db.point or "TOPRIGHT"
    btn:ClearAllPoints()
    btn:SetPoint(point, target, point, db.x or 0, db.y or 0)
end

local STRIP_IDS = { [136430] = true, [136467] = true, [136477] = true, [136443] = true }

local skinned = {}
local function SkinButton(btn)
    if skinned[btn] then return end
    skinned[btn] = true
    local icon = btn.icon
    for _, region in next, { btn:GetRegions() } do
        if region.IsObjectType and region:IsObjectType("Texture") and region ~= icon then
            local tex = region:GetTexture()
            local drop = region == btn.border or region == btn.background
            if not drop and type(tex) == "number" then drop = STRIP_IDS[tex] end
            if not drop and type(tex) == "string" then
                local l = tex:lower()
                drop = l:find("border") or l:find("background") or l:find("alphamask") or l:find("trackingborder")
            end
            if drop then
                region:SetTexture(nil)
                region:Hide()
            end
        end
    end
    if icon and icon.SetTexCoord then
        icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    end
    if not btn._tuiSkin then
        local bf = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        bf:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        bf:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        bf:SetFrameLevel(btn:GetFrameLevel() + 5)
        bf:SetBackdrop({ edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
        bf:SetBackdropBorderColor(0, 0, 0, 1)
        btn._tuiSkin = bf
    end
    btn._tuiSkin:SetShown(true)
end

local function SkinAll()
    local db = DB()
    local main = MainButton()
    if not (db and db.skin and main) then return end
    for _, container in ipairs({ main:GetChildren() }) do
        if container.IsObjectType and container:IsObjectType("Frame") then
            for _, btn in ipairs({ container:GetChildren() }) do
                if btn.GetRegions then SkinButton(btn) end
            end
        end
    end
end

local pending
local function QueueSkin()
    if pending then return end
    pending = true
    C_Timer.After(0.2, function() pending = false; SkinAll() end)
end

local hooked = false
function TUI:UpdateMBB()
    if not Loaded() then return end
    if not hooked then
        hooked = true
        MainButton():HookScript("OnMouseDown", QueueSkin)
    end
    ApplyPosition()
    SkinAll()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
    C_Timer.After(2, function()
        if TUI.UpdateMBB then TUI:UpdateMBB() end
    end)
end)
