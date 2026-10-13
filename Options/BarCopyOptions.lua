local _, ns = ...
local TUI = ns.TUI
local E = ns.E

local EMPTY = [[Interface\PaperDoll\UI-Backpack-EmptySlot]]

local function ActionName(slot)
    if not HasAction(slot) then return nil end
    local t, id = GetActionInfo(slot)
    if issecretvalue and (issecretvalue(t) or issecretvalue(id)) then return nil end
    if t == "spell" then return C_Spell.GetSpellName(id) end
    if t == "item" then return C_Item.GetItemNameByID(id) end
    return GetActionText(slot)
end

local function BarGroup(order, key)
    local BC = ns.BarCopy
    local bar, other = BC.BARS[key], BC.BARS[BC.OTHER[key]]
    local args = {
        status = {
            order = 1, type = "description", width = "full", fontSize = "medium",
            name = function()
                local state = BC.IsShown(key) and "|cFF40FF40Shown in this profile|r" or "|cFF888888Hidden in this profile|r"
                return ("%s   %d/12 buttons on this spec   %d keybind(s)"):format(
                    state, BC.CountSpells(key), BC.CountKeys(key))
            end,
        },
        copy = {
            order = 30, type = "execute", width = 1.2, name = "Copy From " .. other.label,
            confirm = function()
                local lost = BC.Lost(BC.OTHER[key], key)
                if lost == 0 then return false end
                return ("%d button(s) on %s will be replaced or cleared on this spec. %s stays as it is."):format(
                    lost, bar.label, other.label)
            end,
            func = function() BC.Copy(BC.OTHER[key], key) end,
        },
        keys = {
            order = 31, type = "execute", width = 1.2, name = "Move Keybinds Here",
            disabled = function() return BC.CountKeys(BC.OTHER[key]) == 0 end,
            func = function() BC.MoveKeys(key) end,
        },
    }
    for i = 1, 12 do
        args["i" .. i] = {
            order = 10 + i, type = "execute", width = 0.25,
            name = function()
                local k = BC.KeysOf(key, i)[1]
                return k and GetBindingText(k, true) or ""
            end,
            desc = function() return ActionName(BC.Slot(key, i)) or "Empty" end,
            image = function()
                local s = BC.Slot(key, i)
                return HasAction(s) and GetActionTexture(s) or EMPTY
            end,
            imageWidth = 28, imageHeight = 28, imageCoords = { 0.08, 0.92, 0.08, 0.92 },
            func = function() end,
        }
    end
    return {
        order = order, type = "group", inline = true,
        name = bar.label .. " |cFF888888(" .. bar.note .. ")|r",
        args = args,
    }
end

function TUI:BarCopyGroup(order)
    local BC = ns.BarCopy
    if not BC then return nil end
    local function db()
        E.db.thingsUI.actionBarCopy = E.db.thingsUI.actionBarCopy or {}
        return E.db.thingsUI.actionBarCopy
    end
    return {
        order = order, type = "group", inline = true, name = "Action Bar 2 and 13",
        args = {
            desc = {
                order = 1, type = "description", width = "full",
                name = "Bar 13 is the bar Blizzard and EllesmereUI call Action Bar 6. WoW keeps spells per spec, so a copy only changes the spec you are on, and the source bar stays as it is.\n",
            },
            keysFollow = {
                order = 2, type = "toggle", width = 1.5, name = "Keybinds Follow the Shown Bar",
                get = function() return db().keysFollow and true or false end,
                set = function(_, v)
                    db().keysFollow = v
                    if v then BC.AutoFollow() end
                end,
            },
            autoFill = {
                order = 3, type = "toggle", width = 1.5, name = "Fill the Shown Bar on Each Spec",
                get = function() return db().autoFill and true or false end,
                set = function(_, v)
                    db().autoFill = v
                    if v then BC.AutoFill() end
                end,
            },
            bar2 = BarGroup(10, "bar2"),
            bar13 = BarGroup(20, "bar13"),
        },
    }
end
