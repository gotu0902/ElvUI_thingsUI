local _, ns = ...
local TUI, E = ns.TUI, ns.E

-- ElvUI's Filters page: fill the Aura Indicator on screen with the auras another one has
local OWN = {
    ["Aura Indicator (Global)"] = "GLOBAL", ["Aura Indicator (Pet)"] = "PET",
    ["Aura Indicator (Class)"] = "CLASS", ["Aura Indicator (Profile)"] = "PROFILE",
}
local FIXED = { PROFILE = "Profile", GLOBAL = "Global", PET = "Pet" }

local selectFilter

local function Selected()
    local f = selectFilter and selectFilter.get and selectFilter.get()
    return f and OWN[f], f
end

local function Table(key, create)
    if key == "PROFILE" then return E.db.unitframe.filters.aurawatch end
    if key == "CLASS" then key = E.myclass end
    local aw = E.global.unitframe.aurawatch
    if create and not aw[key] then aw[key] = {} end
    return aw[key]
end

local function Sources()
    local target = Selected()
    local out = {}
    for key, name in pairs(FIXED) do
        if key ~= target and next(Table(key) or {}) then out[key] = name end
    end
    for token, t in pairs(E.global.unitframe.aurawatch) do
        if RAID_CLASS_COLORS[token] and type(t) == "table" and next(t) and not (target == "CLASS" and token == E.myclass) then
            out[token] = ns.ClassColor(token) .. ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token) .. "|r"
        end
    end
    return out
end

local function Sorting()
    local out, classes = {}, {}
    for key in pairs(Sources()) do
        if FIXED[key] then out[#out + 1] = key else classes[#classes + 1] = key end
    end
    table.sort(out)
    table.sort(classes)
    for _, k in ipairs(classes) do out[#out + 1] = k end
    return out
end

-- adds what the target lacks; an aura it has (or covers through a rank) stays as it is
local function Copy(_, key)
    local target, name = Selected()
    local src, dst = Table(key), target and Table(target, true)
    if not (src and dst) or src == dst then return end
    local covered = {}
    for id, a in pairs(dst) do
        covered[id] = true
        if type(a) == "table" then
            for _, inc in pairs(a.includeIDs or {}) do covered[inc] = true end
        end
    end
    local added, had, off = 0, 0, 0
    for id, a in pairs(src) do
        if type(a) == "table" then
            local has = covered[id]
            for _, inc in pairs(a.includeIDs or {}) do has = has or covered[inc] end
            if a.enabled == false then
                off = off + 1
            elseif has then
                had = had + 1
            else
                dst[id] = E:CopyTable({}, a)
                added = added + 1
            end
        end
    end
    E:GetModule("UnitFrames"):Update_AllFrames()
    print(("|cFFFF00F1thingsUI|r: %d auras added to %s, %d already there%s."):format(added, name, had,
        off > 0 and (", " .. off .. " turned off (left out)") or ""))
    ns.NotifyChange()
end

function TUI:AuraIndicatorCopy()
    local main = E.Options and E.Options.args.filters and E.Options.args.filters.args.mainOptions
    local grp = main and main.args.filterGroup
    if not (grp and grp.args and main.args.selectFilter) or grp.args.tuiCopyAuras then return end
    selectFilter = main.args.selectFilter
    grp.args.tuiCopyAuras = {
        order = 7, type = "select", name = "|cFF8080FFCopy Auras From|r", customWidth = 350,
        hidden = function() return not Selected() end,
        values = Sources, sorting = Sorting,
        get = function() return nil end,
        confirm = function(_, key)
            local _, name = Selected()
            return ("Add the auras %s has that %s doesn't? Nothing already there changes."):format(Sources()[key] or key, name or "")
        end,
        set = Copy,
    }
end
