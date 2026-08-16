local _, ns = ...
local E = ns.E

ns.SpecialBars = ns.SpecialBars or {}
local SB = ns.SpecialBars
local DeepCopy = ns.DeepCopy

local M = {}
SB.Styles = M

local EXCLUDE = {
    icons = {
        spellID = true, spellName = true, enabled = true, styleName = true,
        anchorMode = true, anchorFrame = true, anchorPoint = true,
        anchorRelativePoint = true, anchorXOffset = true, anchorYOffset = true,
        customGroup = true, customGroupOrder = true,
        totemTimer = true,
    },
    bars = {
        spellID = true, spellName = true, enabled = true, styleName = true,
        anchorMode = true, anchorFrame = true, anchorPoint = true,
        anchorRelativePoint = true, anchorXOffset = true, anchorYOffset = true,
        totemTimer = true, totemTicks = true, totemTickThickness = true,
        totemTickLength = true, totemTickColor = true,
    },
}

local function DeepEqual(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if not DeepEqual(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

function M.Capture(kind, fromDB)
    local out = {}
    local ex = EXCLUDE[kind]
    for k, v in pairs(fromDB or {}) do
        if not ex[k] and type(k) == "string" and k:sub(1, 1) ~= "_" then
            out[k] = type(v) == "table" and DeepCopy(v) or v
        end
    end
    return out
end

function M.Root(kind)
    local db = E.db.thingsUI
    if not db then return nil end
    db.specialStyles = db.specialStyles or {}
    local r = db.specialStyles
    r.icons = r.icons or {}
    r.bars  = r.bars  or {}
    if not r.icons.Global then r.icons.Global = M.Capture("icons", ns.SPECIAL_ICON_DEFAULTS) end
    if not r.bars.Global  then r.bars.Global  = M.Capture("bars",  ns.SPECIAL_BAR_DEFAULTS)  end
    return kind and r[kind] or r
end

function M.Get(kind, name)
    local root = M.Root(kind)
    return root and name and root[name] or nil
end

function M.ApplyToDB(kind, name, db)
    local style = M.Get(kind, name)
    if not (style and db) then return false end
    for k, v in pairs(style) do
        db[k] = type(v) == "table" and DeepCopy(v) or v
    end
    db.styleName = name
    return true
end

function M.IsDirty(kind, name, db, ignore)
    local style = M.Get(kind, name)
    if not (style and db) then return false end
    for k, v in pairs(style) do
        if not (ignore and ignore[k]) and not DeepEqual(v, db[k]) then return true end
    end
    return false
end

local function EachSpecial(kind, fn)
    local sb = E.db.thingsUI and E.db.thingsUI.specialBars
    local specs = sb and sb.specs
    if not specs then return end
    local field = (kind == "bars") and "bars" or "icons"
    for specKey, s in pairs(specs) do
        for slotKey, d in pairs(s[field] or {}) do
            if type(d) == "table" then fn(d, specKey, slotKey) end
        end
    end
end
M.EachSpecial = EachSpecial

function M.ApplyToUsers(kind, name)
    local style = M.Get(kind, name)
    if not style then return 0 end
    local n = 0
    EachSpecial(kind, function(d)
        if d.styleName == name then
            for k, v in pairs(style) do
                d[k] = type(v) == "table" and DeepCopy(v) or v
            end
            n = n + 1
        end
    end)
    return n
end

function M.Save(kind, name, fromDB)
    local root = M.Root(kind)
    if not (root and name and name ~= "" and fromDB) then return false end
    root[name] = M.Capture(kind, fromDB)
    if fromDB.styleName ~= name then fromDB.styleName = name end
    M.ApplyToUsers(kind, name)
    return true
end

function M.Delete(kind, name)
    local root = M.Root(kind)
    if not (root and name) or name == "Global" then return false end
    root[name] = nil
    if M.GetDefault(kind) == name then M.SetDefault(kind, nil) end
    EachSpecial(kind, function(d)
        if d.styleName == name then d.styleName = nil end
    end)
    return true
end

function M.Rename(kind, old, new)
    local root = M.Root(kind)
    if not (root and root[old]) or old == "Global" or not new or new == "" or root[new] then return false end
    root[new] = root[old]
    root[old] = nil
    if E.db.thingsUI.specialStyles.defaults and E.db.thingsUI.specialStyles.defaults[kind] == old then
        E.db.thingsUI.specialStyles.defaults[kind] = new
    end
    EachSpecial(kind, function(d)
        if d.styleName == old then d.styleName = new end
    end)
    return true
end

function M.GetDefault(kind)
    local db = E.db.thingsUI
    local r = db and db.specialStyles
    local name = r and r.defaults and r.defaults[kind]
    if name and M.Get(kind, name) then return name end
    return nil
end

function M.EffectiveDefault(kind)
    return M.GetDefault(kind) or "Global"
end

function M.SetDefault(kind, name)
    local db = E.db.thingsUI
    if not db then return end
    db.specialStyles = db.specialStyles or {}
    db.specialStyles.defaults = db.specialStyles.defaults or {}
    db.specialStyles.defaults[kind] = name
end

function M.Names(kind)
    local out = {}
    for name in pairs(M.Root(kind) or {}) do out[#out + 1] = name end
    table.sort(out, function(a, b)
        if a == "Global" then return true end
        if b == "Global" then return false end
        return a < b
    end)
    return out
end

function M.UsageCounts(kind)
    local out = {}
    for _, n in ipairs(M.Names(kind)) do out[n] = 0 end
    EachSpecial(kind, function(d)
        if d.spellID and d.styleName and out[d.styleName] ~= nil then
            out[d.styleName] = out[d.styleName] + 1
        end
    end)
    return out
end

local PALETTE = {
    "FF6B6B", "FFA94D", "FFD43B", "A9E34B", "51CF66", "20C997",
    "3BC9DB", "4DABF7", "748FFC", "9775FA", "DA77F2", "F783AC",
}
M.PALETTE = PALETTE

function M.ColorHex(name)
    if not name or name == "" or name == "Global" then return "BBBBBB" end
    local hsh = 5381
    for i = 1, #name do hsh = (hsh * 33 + name:byte(i)) % 2147483647 end
    return PALETTE[(hsh % #PALETTE) + 1]
end

function M.ColoredName(name)
    if not name or name == "" then return "|cFF888888- None -|r" end
    return "|cFF" .. M.ColorHex(name) .. name .. "|r"
end

function M.DropdownValues(kind, noneLabel)
    local counts = M.UsageCounts(kind)
    local def = M.EffectiveDefault(kind)
    local t = {}
    if noneLabel then t[""] = noneLabel end
    for name, n in pairs(counts) do
        local suffix = (name == def) and "  |cFF40FF40(default)|r" or ""
        t[name] = ("|cFFAAAAAA%d|r  %s%s"):format(n, M.ColoredName(name), suffix)
    end
    return t
end

function M.DropdownSorting(kind, includeNone)
    local counts = M.UsageCounts(kind)
    local names = M.Names(kind)
    table.sort(names, function(a, b)
        local ca, cb = counts[a] or 0, counts[b] or 0
        if ca ~= cb then return ca > cb end
        if a == "Global" then return true end
        if b == "Global" then return false end
        return a < b
    end)
    local out = includeNone and { "" } or {}
    for _, n in ipairs(names) do out[#out + 1] = n end
    return out
end
