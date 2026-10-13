local _, ns = ...
local E = ns.E
local TUI = ns.TUI

-- named aura lists that Groups - Icons/Bars link to: a spell list, or a
-- Blizzard aura filter the AuraContainer matches C-side. Built-ins come from
-- ns.AURA_PRESETS and keep only the user's edits, so shipped lists still update.
ns.AuraCollections = ns.AuraCollections or {}
local M = ns.AuraCollections

M.FILTERS = {
    BIG_DEFENSIVE      = { name = "Big Defensives",      kind = "HELPFUL", sample = 45438 },
    EXTERNAL_DEFENSIVE = { name = "External Defensives", kind = "HELPFUL", sample = 33206 },
    IMPORTANT          = { name = "Important",                             sample = 2825 },
    RAID_IN_COMBAT     = { name = "HoTs and Shields",    kind = "HELPFUL", sample = 774 },
    CROWD_CONTROL      = { name = "Crowd Control",       kind = "HARMFUL", sample = 118 },
}
M.FILTER_ORDER = { "BIG_DEFENSIVE", "EXTERNAL_DEFENSIVE", "IMPORTANT", "RAID_IN_COMBAT", "CROWD_CONTROL" }

local function Root()
    local db = E.db.thingsUI
    db.auraCollections = db.auraCollections or {}
    local r = db.auraCollections
    r.custom = r.custom or {}
    r.edits = r.edits or {}
    r.nextID = r.nextID or 1
    return r
end

local function Preset(key)
    for _, p in ipairs(ns.AURA_PRESETS or {}) do
        if p.key == key then return p end
    end
end
M.Preset = Preset

-- a custom collection, or the user's edits on a built-in
function M.Raw(key, create)
    local r = Root()
    if r.custom[key] then return r.custom[key] end
    if not Preset(key) then return nil end
    if create and not r.edits[key] then r.edits[key] = {} end
    return r.edits[key]
end

function M.Exists(key)
    return key ~= nil and (Preset(key) ~= nil or Root().custom[key] ~= nil)
end

function M.List()
    local out = {}
    for _, p in ipairs(ns.AURA_PRESETS or {}) do
        local raw = Root().edits[p.key]
        out[#out + 1] = { key = p.key, name = (raw and raw.name) or p.name, builtin = true }
    end
    local custom = {}
    for key, c in pairs(Root().custom) do custom[#custom + 1] = { key = key, name = c.name or key } end
    table.sort(custom, function(a, b) return a.name < b.name end)
    for _, c in ipairs(custom) do out[#out + 1] = c end
    return out
end

-- enabled spells of a named ElvUI aura filter (ElvUI > Filters)
function M.ElvFilterSpells(name)
    if not name or name == "" or not E.Auras_GetFilter then return nil end
    local auras = E.global.unitframe and E.global.unitframe.aurafilters
    return E:Auras_GetFilter(auras, name)
end

function M.ElvFilterNames()
    local out = {}
    for name in pairs((E.global.unitframe and E.global.unitframe.aurafilters) or {}) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function M.Source(key)
    local raw, p = M.Raw(key) or {}, Preset(key)
    return raw.source or ((p and p.filter) and "filter" or "spells")
end

-- the collection's Blizzard filters in FILTER_ORDER; several = auras matching ANY of them
function M.FilterTokens(key)
    local raw, p = M.Raw(key) or {}, Preset(key)
    local set = raw.filters
    if not set then set = { [raw.filter or (p and p.filter) or "BIG_DEFENSIVE"] = true } end
    local out = {}
    for _, t in ipairs(M.FILTER_ORDER) do
        if set[t] then out[#out + 1] = t end
    end
    return out
end

function M.HasFilter(key, token)
    for _, t in ipairs(M.FilterTokens(key)) do
        if t == token then return true end
    end
    return false
end

-- the last filter can not be switched off
function M.SetFilter(key, token, on)
    local set = {}
    for _, t in ipairs(M.FilterTokens(key)) do set[t] = true end
    set[token] = on or nil
    if not next(set) then return end
    local raw = M.Raw(key, true)
    raw.filters, raw.filter = set, nil
    M.Changed()
end

-- the collection's own list: spells to show, or (filter) spells to leave out
function M.OwnList(key)
    local raw, p = M.Raw(key) or {}, Preset(key)
    local list = {}
    if M.Source(key) == "filter" then
        for id in pairs(raw.exclude or {}) do list[id] = true end
        return list
    end
    if p then for _, id in ipairs(p.spells or {}) do list[id] = true end end
    for id in pairs(raw.spells or {}) do list[id] = true end
    for id in pairs(raw.removed or {}) do list[id] = nil end
    return list
end

function M.AddSpell(key, id)
    local raw = M.Raw(key, true)
    if not (raw and id) then return end
    if M.Source(key) == "filter" then
        raw.exclude = raw.exclude or {}
        raw.exclude[id] = true
    elseif raw.removed and raw.removed[id] then
        raw.removed[id] = nil
    else
        raw.spells = raw.spells or {}
        raw.spells[id] = true
    end
    M.Changed()
end

function M.RemoveSpell(key, id)
    local raw, p = M.Raw(key, true), Preset(key)
    if not (raw and id) then return end
    if M.Source(key) == "filter" then
        if raw.exclude then raw.exclude[id] = nil end
    else
        if raw.spells then raw.spells[id] = nil end
        local inPreset = false
        for _, pid in ipairs((p and p.spells) or {}) do
            if pid == id then inPreset = true break end
        end
        if inPreset then
            raw.removed = raw.removed or {}
            raw.removed[id] = true
        end
    end
    M.Changed()
end

-- the collection as the groups see it
function M.Get(key)
    local p = Preset(key)
    local raw = M.Raw(key)
    if not (p or raw) then return nil end
    raw = raw or {}
    local list = M.OwnList(key)
    for id in pairs(M.ElvFilterSpells(raw.elvFilter) or {}) do list[id] = true end
    local c = {
        key = key, builtin = p ~= nil,
        name = raw.name or (p and p.name) or key,
        kind = (p and p.kind) or "HELPFUL",
        max = (p and p.max) or 10,
    }
    if M.Source(key) == "filter" then
        local tokens = M.FilterTokens(key)
        local f = M.FILTERS[tokens[1]]
        c.filters, c.spells, c.exclude = tokens, {}, list
        c.preview = f and f.sample
        c.kind = (f and f.kind) or c.kind
    else
        c.spells = list
    end
    return c
end

-- which collection a group entry follows; old Ready-Made Set entries link too
function M.LinkOf(uid, def)
    local key = def and def.collection
    if not key and type(uid) == "string" then key = uid:match("^preset:(.+)$") end
    if key and M.Exists(key) then return key end
end

-- the entry with the collection's auras in it; the stored entry is not touched
function M.Effective(uid, raw)
    local key = M.LinkOf(uid, raw)
    local c = key and M.Get(key)
    if not c then return raw end
    local d = {}
    for k, v in pairs(raw) do d[k] = v end
    d.spells, d.exclude, d.filterTokens, d.preview = c.spells, c.exclude, c.filters, c.preview
    d.name = c.name
    return d
end

-- one def per Blizzard filter: tokens joined in one string must ALL match,
-- an aura group each shows auras matching any of them
function M.Expand(def)
    local tokens = def.filterTokens
    if not tokens then return { def } end
    local out = {}
    for _, t in ipairs(tokens) do
        local d = {}
        for k, v in pairs(def) do d[k] = v end
        d.filterTokens, d.filterToken = nil, t
        local f = M.FILTERS[t]
        d.preview = f and f.sample
        if f and f.kind then d.kind = f.kind end
        out[#out + 1] = d
    end
    return out
end

-- fn(key, def, root, uid, label) for every linked group entry
local function EachLinked(fn)
    local mods = {
        { "Groups - Icons", "customGroups", function(g) return g.global end },
        { "Groups - Bars",  "customBars",   function(g) return g end },
    }
    for _, m in ipairs(mods) do
        local store = E.db.thingsUI[m[2]]
        for _, g in pairs((store and store.groups) or {}) do
            if type(g) == "table" then
                local roots = { { "Global", m[3](g) } }
                for k, r in pairs(g.classes or {}) do roots[#roots + 1] = { k, r } end
                for k, r in pairs(g.specs or {}) do
                    local _, nm = GetSpecializationInfoByID(tonumber(k) or 0)
                    roots[#roots + 1] = { nm or k, r }
                end
                for _, rr in ipairs(roots) do
                    for uid, def in pairs((rr[2] and rr[2].auras) or {}) do
                        if type(def) == "table" then
                            local key = M.LinkOf(uid, def)
                            if key then
                                fn(key, def, rr[2], uid, ("%s: %s (%s)"):format(m[1], g.name or "Group", rr[1]))
                            end
                        end
                    end
                end
            end
        end
    end
end

function M.UsedBy(key)
    local out = {}
    EachLinked(function(k, _, _, _, label) if k == key then out[#out + 1] = label end end)
    table.sort(out)
    return out
end

function M.Create(name)
    local r = Root()
    local key = "c" .. r.nextID
    r.nextID = r.nextID + 1
    r.custom[key] = { name = (name and name ~= "") and name or ("Collection " .. key), source = "spells", spells = {} }
    M.Changed()
    return key
end

-- linked entries keep a copy of a spell list; filter ones go with it
function M.Delete(key)
    local r = Root()
    if not r.custom[key] then return end
    local c = M.Get(key)
    EachLinked(function(k, def, root, uid)
        if k ~= key then return end
        if c.filters then
            root.auras[uid] = nil
        else
            def.spells = ns.DeepCopy(c.spells)
            def.name = def.name or c.name
            def.collection = nil
        end
    end)
    r.custom[key] = nil
    M.Changed()
end

function M.Reset(key)
    Root().edits[key] = nil
    M.Changed()
end

function M.Changed()
    if TUI.UpdateCustomGroups then TUI:UpdateCustomGroups() end
    if TUI.UpdateCustomBars then TUI:UpdateCustomBars() end
    if ns.CustomGroups and ns.CustomGroups._rebuildOptions then ns.CustomGroups._rebuildOptions() end
    if ns.CustomBars and ns.CustomBars._rebuildOptions then ns.CustomBars._rebuildOptions() end
    if M._rebuildOptions then M._rebuildOptions() end
    if ns.NotifyChange then ns.NotifyChange() end
end
