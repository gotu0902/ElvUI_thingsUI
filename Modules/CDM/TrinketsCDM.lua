local _, ns = ...
local E = ns.E
local TUI = ns.TUI

-- on-use trinkets drawn inside Essential/Utility, no Blizzard CDM entry needed
ns.TrinketsCDM = ns.TrinketsCDM or {}
local M = ns.TrinketsCDM

local ipairs, wipe, tconcat = ipairs, wipe, table.concat

local SLOTS     = { 13, 14 }
local buttons   = {}
local timers    = {}
local listFor   = { essential = {}, utility = {} }
local shownSlot = {}
local waiting   = {}
local lastSig   = ""

local function RowFor(slot)
    local db = E.db and E.db.thingsUI and E.db.thingsUI.cdmIcons
    local d = db and db.trinketDest and db.trinketDest[tostring(slot)]
    return d and d.row
end

local function EnsureButton(slot)
    local btn = buttons[slot]
    if not btn then
        btn = ns.TimersRender.CreateButton(_G.UIParent, "TUI_TrinketCDM" .. slot,
            function() M.RefreshCooldowns() end)
        buttons[slot] = btn
        timers[slot] = { id = "trinket:" .. slot, kind = "item",
                         showCDTimer = false, trackCooldown = true, showIdle = true }
    end
    return btn
end

-- nil while the item or its tooltip is still loading
local function IsOnUse(slot, itemID)
    if C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(itemID) then
        waiting[itemID] = true
        C_Item.RequestLoadItemDataByID(itemID)
        return nil
    end
    if C_Item.GetItemSpell(itemID) then return true end
    -- an Equip proc can hide a separate Use line from GetItemSpell
    local tip = C_TooltipInfo and C_TooltipInfo.GetInventoryItem("player", slot)
    if not (tip and tip.lines) then return nil end
    local prefix = ITEM_SPELL_TRIGGER_ONUSE
    for _, line in ipairs(tip.lines) do
        local lt = line.leftText
        if lt and prefix and lt:sub(1, #prefix) == prefix then return true end
    end
    return false
end

function M.ShowsSlot(slot) return shownSlot[slot] or false end

function M.RefreshCooldowns()
    if not ns.TimersRender then return end
    for slot, btn in pairs(buttons) do
        if btn:IsShown() then ns.TimersRender.Update(btn, timers[slot]) end
    end
end

function M.Refresh()
    if not ns.TimersRender then return end
    wipe(listFor.essential)
    wipe(listFor.utility)
    wipe(shownSlot)
    local sig = {}
    for _, slot in ipairs(SLOTS) do
        local row = RowFor(slot)
        local itemID = row and GetInventoryItemID("player", slot)
        local list = itemID and listFor[row]
        local hidden = ns.CDMIcons and ns.CDMIcons.TrinketHidden and ns.CDMIcons.TrinketHidden(slot)
        if list and not hidden and IsOnUse(slot, itemID) then
            local btn = EnsureButton(slot)
            timers[slot].itemID = itemID
            btn.layoutIndex = 95000 + slot
            btn:Show()
            list[#list + 1] = btn
            shownSlot[slot] = true
            ns.TimersRender.Update(btn, timers[slot])
            sig[#sig + 1] = row .. ":" .. slot .. ":" .. itemID
        elseif buttons[slot] then
            buttons[slot]:Hide()
            buttons[slot].layoutIndex = nil
        end
    end
    local s = tconcat(sig, ",")
    if s == lastSig then return end
    lastSig = s
    local CI = ns.CDMIcons
    if CI and CI.QueuePassiveRebuild then CI.QueuePassiveRebuild() end
    if CI and CI.RefreshAll then CI.RefreshAll() end
    if ns.CDMText and ns.CDMText.RefreshAll then ns.CDMText.RefreshAll() end
    C_Timer.After(0, function()
        if ns.EssentialMover and ns.EssentialMover.Apply then ns.EssentialMover.Apply() end
        if ns.BarSetup and ns.BarSetup.ApplyStack then ns.BarSetup.ApplyStack() end
        if ns.TUI and ns.TUI.UpdateClusterPositioning then ns.TUI:UpdateClusterPositioning() end
        if ns.MoverSync and ns.MoverSync.Queue then ns.MoverSync.Queue() end
    end)
end

function M.GetInlineButtonsFor(viewer)
    if viewer == _G.EssentialCooldownViewer then
        return (#listFor.essential > 0) and listFor.essential or nil
    elseif viewer == _G.UtilityCooldownViewer then
        return (#listFor.utility > 0) and listFor.utility or nil
    end
end

function TUI:UpdateTrinketsCDM() M.Refresh() end

local cdPending = false
local function ThrottledCooldowns()
    if cdPending or not next(shownSlot) then return end
    cdPending = true
    C_Timer.After(0.1, function() cdPending = false; M.RefreshCooldowns() end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("ITEM_DATA_LOAD_RESULT")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
        ThrottledCooldowns()
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        if waiting[arg1] then waiting[arg1] = nil; M.Refresh() end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if arg1 == 13 or arg1 == 14 then M.Refresh() end
    else
        M.Refresh()
        -- tooltip lines can arrive after the item itself at login
        C_Timer.After(3, M.Refresh)
    end
end)
