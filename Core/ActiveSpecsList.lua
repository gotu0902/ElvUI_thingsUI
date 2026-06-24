-- API:
--   ns.ActiveSpecsList.Build(opts)
--     opts.order       : AceConfig order key
--     opts.selected    : function() returning a { [specID]=true } map
--     opts.onRemove    : function(specID) called when user clicks X
--     opts.emptyText   : string shown when no specs are selected
--   Returns: AceConfig group args table.

local _, ns = ...
local E = ns.E

ns.ActiveSpecsList = ns.ActiveSpecsList or {}

local ClassColor = ns.ClassColor
local MAX_ROWS = 40

local function ClassName(token)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token
end

local GetMeta = ns.SpecMeta

local function SortSpecIDs(ids)
    table.sort(ids, function(a, b)
        local ma, mb = GetMeta(a), GetMeta(b)
        if not ma then return false end
        if not mb then return true end
        local na, nb = ClassName(ma.classToken), ClassName(mb.classToken)
        if na ~= nb then return na < nb end
        return ma.specIndex < mb.specIndex
    end)
end

function ns.ActiveSpecsList.BuildDynamic(opts)
    opts = opts or {}
    local args = {}

    local function GetIDs()
        local selected = opts.selected and opts.selected() or {}
        local ids = {}
        for sid, v in pairs(selected) do
            if v then ids[#ids + 1] = sid end
        end
        SortSpecIDs(ids)
        return ids
    end

    args._empty = {
        order = 1, type = "description", width = "full", fontSize = "medium",
        name = "|cFF888888"..(opts.emptyText or "No specs selected yet.").."|r",
        hidden = function() return #GetIDs() > 0 end,
    }

    for i = 1, MAX_ROWS do
        local function specAt() return GetIDs()[i] end
        args["row"..i.."_label"] = {
            order = 10 + i * 2, type = "description", width = 2.7, fontSize = "medium",
            hidden = function() return specAt() == nil end,
            name = function()
                local id = specAt()
                if not id then return "" end
                local m = GetMeta(id)
                if m then
                    local iconStr = m.icon and ("|T"..m.icon..":14:14|t ") or ""
                    return iconStr .. ClassColor(m.classToken) .. ClassName(m.classToken) .. "|r - " .. (m.name or tostring(id))
                end
                return "|cFFAAAAAASpec "..tostring(id).."|r"
            end,
        }
        args["row"..i.."_x"] = {
            order = 11 + i * 2, type = "execute", width = 0.3, name = "X",
            hidden = function() return specAt() == nil end,
            func = function()
                local id = specAt()
                if id and opts.onRemove then opts.onRemove(id) end
            end,
        }
    end

    return args
end

function ns.ActiveSpecsList.Build(opts)
    opts = opts or {}
    local args = {}

    args._listHeader = {
        order = 1, type = "description", width = "full", fontSize = "small",
        name = "|cFFFFD200Active Specs|r  |cFF888888(click X to remove)|r",
    }

    local selected = opts.selected and opts.selected() or {}
    local ids = {}
    for sid, v in pairs(selected) do
        if v then ids[#ids + 1] = sid end
    end

    if #ids == 0 then
        args._empty = {
            order = 2, type = "description", width = "full", fontSize = "medium",
            name = "|cFF888888"..(opts.emptyText or "No specs selected yet.").."|r",
        }
        return args
    end

    SortSpecIDs(ids)

    local order = 10
    for _, specID in ipairs(ids) do
        local m = GetMeta(specID)
        local label
        if m then
            local iconStr = m.icon and ("|T"..m.icon..":14:14|t ") or ""
            label = iconStr .. ClassColor(m.classToken) .. ClassName(m.classToken) .. "|r - " .. (m.name or tostring(specID))
        else
            label = "|cFFAAAAAASpec "..tostring(specID).."|r"
        end

        args["row"..specID.."_label"] = {
            order = order, type = "description", width = 2.4, fontSize = "medium",
            name = label,
        }
        args["row"..specID.."_x"] = {
            order = order + 1, type = "execute", width = 0.3, name = "X",
            func = function() if opts.onRemove then opts.onRemove(specID) end end,
        }
        order = order + 2
    end

    return args
end
