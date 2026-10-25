local _, ns = ...
local E = ns.E
local DeepCopy = ns.DeepCopy

ns.Share = ns.Share or {}
local M = ns.Share

local PREFIX = "!TUI2!"
local OLD_PREFIX = "!TUI1!"

M.SECTIONS = {
    { name = "Bar Setup",            keys = { "barSetup" },     collection = "barSetup",      color = "FFB060" },
    { name = "Buff Bars",            keys = { "buffBars" },                                   color = "05D6F2" },
    { name = "CDM Icons",            keys = { "cdmIcons" },                                   color = "FFD27F" },
    { name = "Charge Bar",           keys = { "chargeBar" },                                  color = "C780FF" },
    { name = "Classbar",             keys = { "classbarMode" },                               color = "6FB7FF" },
    { name = "Groups - Icons",       keys = { "customGroups" }, collection = "customGroups",  color = "F20553" },
    { name = "Groups - Bars", id = "customBars", keys = { "customBars" }, collection = "customBars", only = "bars", color = "F27D2A" },
    { name = "Groups - Text", id = "customText", keys = { "customBars" }, collection = "customBars", only = "text", color = "F2C12E" },
    { name = "Aura Collections",     keys = { "auraCollections" },                            color = "B0A0FF" },
    { name = "Aura Bars & Icons", keys = { "specialBars" },  collection = "specialBars",   color = "80FF80" },
    { name = "Aura Styles",       keys = { "specialStyles" }, collection = "specialStyles", color = "FF80C0" },
    { name = "Timers",               keys = { "timers" },                                     color = "FFC04D" },
    { name = "Racials",              keys = { "racialsCDM" } },
    { name = "Cluster Positioning",  keys = { "clusterPositioning" } },
    { name = "Damage Meter",         keys = { "damageMeter" },                                color = "FF6B6B" },
    { name = "Minimap",              keys = { "mbb", "instanceDifficulty" } },
    { name = "Movers & General",     keys = { "essentialMover", "groupAnchor", "raidOrder", "actionBarCopy", "autoSetAudioChannels", "rightChatAsBackground", "rightChatWidthOffset", "rightChatHeightOffset" } },
}

-- Groups - Bars and Groups - Text share customBars: a group is one or the other
function M.GroupKind(g) return (type(g) == "table" and g.display == "text") and "text" or "bars" end
local GroupKind = M.GroupKind

local function Fits(sec, g) return not sec.only or GroupKind(g) == sec.only end
M.Fits = Fits

-- what a section owns of a value: all of it, or its kind of groups
local function Owned(sec, v)
    if not sec.only or type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do if k ~= "groups" then out[k] = x end end
    out.groups = {}
    for _, g in ipairs(v.groups or {}) do
        if Fits(sec, g) then out.groups[#out.groups + 1] = g end
    end
    return out
end

local function Present(sec, data)
    for _, k in ipairs(sec.keys) do
        local v = data[k]
        if v ~= nil then
            if not sec.only then return true end
            for _, g in ipairs((type(v) == "table" and v.groups) or {}) do
                if Fits(sec, g) then return true end
            end
        end
    end
    return false
end

local COMPRESS = Enum.CompressionMethod and Enum.CompressionMethod.Deflate or 0
local OPTIMIZE = Enum.CompressionLevel and Enum.CompressionLevel.Default or 0

local function Tools()
    local CE = C_EncodingUtil
    if CE and CE.SerializeCBOR and CE.CompressString and CE.EncodeBase64
        and CE.DeserializeCBOR and CE.DecompressString and CE.DecodeBase64 then
        return CE
    end
end

-- src: another profile's thingsUI table (default: this profile's)
function M.Export(selected, src)
    local CE = Tools()
    if not CE then return nil end
    local mine = src == nil
    src = src or E.db.thingsUI
    local data, ids, by = {}, {}, {}
    for i, sec in ipairs(M.SECTIONS) do
        if (not selected) or selected[i] ~= false then
            ids[#ids + 1] = sec.id or sec.keys[1]
            for _, k in ipairs(sec.keys) do
                if src[k] ~= nil then
                    by[k] = by[k] or {}
                    by[k][#by[k] + 1] = sec
                end
            end
        end
    end
    -- one section of a shared key takes only its own part
    for k, secs in pairs(by) do
        data[k] = (#secs == 1) and Owned(secs[1], src[k]) or src[k]
    end
    -- the modules this profile syncs ride along, so an installer can offer the same
    local PS = ns.ProfileSync
    if mine and PS and PS.ExportConfig then
        local cfg = PS.ExportConfig(ids)
        if cfg then data._sync = cfg end
    end
    if next(data) == nil then return nil end
    local serialized = CE.SerializeCBOR(data)
    local compressed = serialized and CE.CompressString(serialized, COMPRESS, OPTIMIZE)
    local printable = compressed and CE.EncodeBase64(compressed)
    if not printable then return nil end
    return PREFIX .. printable
end

function M.EncodeTable(data, prefix)
    local CE = Tools()
    if not (CE and type(data) == "table" and next(data)) then return nil end
    local s = CE.SerializeCBOR(data)
    local c = s and CE.CompressString(s, COMPRESS, OPTIMIZE)
    local p = c and CE.EncodeBase64(c)
    return p and ((prefix or "") .. p) or nil
end

function M.DecodeTable(str, prefix)
    local CE = Tools()
    if not CE then return nil end
    str = tostring(str or ""):gsub("%s", "")
    prefix = prefix or ""
    if str == "" or str:sub(1, #prefix) ~= prefix then return nil end

    local ok, data = pcall(function()
        local decoded = CE.DecodeBase64(str:sub(#prefix + 1))
        local decompressed = decoded and CE.DecompressString(decoded, COMPRESS)
        return decompressed and CE.DeserializeCBOR(decompressed) or nil
    end)
    if ok and type(data) == "table" then return data end
end

local function Decode(str)
    return M.DecodeTable(str, PREFIX)
end
M.Decode = Decode

function M.Import(str)
    if not Tools() then return false, "Serialization unavailable." end
    local s = tostring(str or ""):gsub("%s", "")
    if s == "" then return false, "Paste an export string first." end
    if s:sub(1, #OLD_PREFIX) == OLD_PREFIX then return false, "Old export format - generate a new string with this version." end
    if s:sub(1, #PREFIX) ~= PREFIX then return false, "Not a thingsUI export string." end
    local data = Decode(s)
    if not data then return false, "Could not decode the string." end
    for k, v in pairs(data) do
        if k ~= "_sync" then E.db.thingsUI[k] = v end
    end
    ns.SpecialBars.Styles.MigrateBorders()
    return true
end

local destName

function M.CurrentProfile() return E.data and E.data:GetCurrentProfile() end

-- another profile's saved thingsUI table (only what differs from the defaults)
function M.ProfileDB(name, create)
    local profiles = E.data and E.data.profiles
    local p = name and profiles and profiles[name]
    if not p then return nil end
    if p.thingsUI == nil and create then p.thingsUI = {} end
    return p.thingsUI
end

function M.OtherProfiles()
    local out = {}
    local cur = M.CurrentProfile()
    for name in pairs((E.data and E.data.profiles) or {}) do
        if name ~= cur then out[#out + 1] = name end
    end
    table.sort(out)
    return out
end

local function Dest()
    return (destName and M.ProfileDB(destName, true)) or E.db.thingsUI
end

local function Root(key, seed)
    local db = Dest()
    if db[key] == nil then db[key] = seed and DeepCopy(seed) or {} end
    return db[key]
end

local function SpecLabel(specKey)
    local m = ns.SpecMeta and ns.SpecMeta(tonumber(specKey))
    if not m then return "Spec " .. tostring(specKey) end
    local icon = m.icon and ("|T" .. m.icon .. ":14:14|t ") or ""
    return icon .. (ns.ClassColor and ns.ClassColor(m.classToken) or "") .. (m.name or specKey) .. "|r"
end

local CG_IDENTITY = { id = true, name = true }
local CG_SPELLS   = { global = true, classes = true, specs = true }
local CG_ANCHOR   = { enabled = true, anchorFrame = true, anchorFrameCustom = true,
    anchorPoint = true, anchorRelativePoint = true, anchorXOffset = true, anchorYOffset = true }

local function CGGroupOf(k)
    if CG_SPELLS[k] then return "spells" end
    if CG_ANCHOR[k] then return "anchor" end
    return "layout"
end

local BS_IDENTITY = { name = true }
local BS_ANCHOR   = { anchorFrame = true, anchorPoint = true, anchorTo = true, xOffset = true, yOffset = true }

local function BSGroupOf(k)
    if BS_ANCHOR[k] then return "anchor" end
    return "layout"
end

local function MergeByGroup(existing, imp, identity, groupOf, fields)
    for k, v in pairs(imp) do
        if not identity[k] and fields[groupOf(k)] then
            existing[k] = (type(v) == "table") and DeepCopy(v) or v
        end
    end
end

local COLL = {}

-- Groups - Bars and Groups - Text share one list: members are the auras (and text cooldowns)
local CB_MEMBERS = { auras = true, classes = true, specs = true, cooldowns = true }
local function CBGroupOf(k)
    if CB_MEMBERS[k] then return "spells" end
    if CG_ANCHOR[k] then return "anchor" end
    return "layout"
end

COLL.customBars = {
    fieldGroups = {
        { key = "spells", label = "Auras / cooldowns" },
        { key = "layout", label = "Layout & look" },
        { key = "anchor", label = "Position & anchor" },
    },
    Items = function(data, sec)
        local imp = data.customBars or {}
        local db = Dest()
        local existing = {}
        for _, g in ipairs((db.customBars and db.customBars.groups) or {}) do
            if Fits(sec, g) then existing[g.name or ""] = true end
        end
        local out = {}
        for idx, g in ipairs(imp.groups or {}) do
            if Fits(sec, g) then
                out[#out + 1] = { id = "c" .. idx, label = g.name or ("Group " .. idx), exists = existing[g.name or ""] == true }
            end
        end
        return out
    end,
    -- sel.mode "replace" = this kind goes, the other kind stays; same names keep their ids
    Apply = function(data, sel, sec)
        local imp = data.customBars; if not imp then return end
        local cur = Root("customBars", { groups = {}, nextID = 1 })
        cur.groups = cur.groups or {}; cur.nextID = cur.nextID or 1
        local byName = {}
        for _, g in ipairs(cur.groups) do
            if type(g.id) == "number" and g.id >= cur.nextID then cur.nextID = g.id + 1 end
            if Fits(sec, g) then byName[g.name or ""] = g end
        end
        if sel.mode == "replace" then
            local keep = {}
            for _, g in ipairs(cur.groups) do if not Fits(sec, g) then keep[#keep + 1] = g end end
            cur.groups = keep
            for _, g in ipairs(imp.groups or {}) do
                if Fits(sec, g) then
                    local ng = DeepCopy(g)
                    local old = byName[ng.name or ""]
                    if old then ng.id = old.id else ng.id = cur.nextID; cur.nextID = cur.nextID + 1 end
                    cur.groups[#cur.groups + 1] = ng
                end
            end
            return
        end
        for idx, g in ipairs(imp.groups or {}) do
            if not Fits(sec, g) then
                -- the other section's group
            else
            local exists = byName[g.name or ""]
            local it = sel.items and sel.items["c" .. idx]
            local doIt, fields
            if sel.mode == "add" then
                doIt = not exists
            elseif it and it.include then
                doIt = true; fields = it.fields
            end
            if doIt then
                if exists and sel.mode ~= "add" then
                    MergeByGroup(exists, g, CG_IDENTITY, CBGroupOf, fields or { spells = true, layout = true, anchor = true })
                else
                    local ng = DeepCopy(g)
                    ng.id = cur.nextID; cur.nextID = cur.nextID + 1
                    if byName[ng.name or ""] then ng.name = (ng.name or "Group") .. " (imported)" end
                    cur.groups[#cur.groups + 1] = ng
                    byName[ng.name or ""] = ng
                end
            end
            end
        end
    end,
}

COLL.customGroups = {
    fieldGroups = {
        { key = "spells", label = "Spells / members" },
        { key = "layout", label = "Layout & size" },
        { key = "anchor", label = "Position & anchor" },
    },
    Items = function(data)
        local imp = data.customGroups or {}
        local existing = {}
        local db = Dest()
        for _, g in ipairs((db.customGroups and db.customGroups.groups) or {}) do
            existing[g.name or ""] = true
        end
        local out = {}
        for idx, g in ipairs(imp.groups or {}) do
            out[#out + 1] = { id = "g" .. idx, label = g.name or ("Group " .. idx), exists = existing[g.name or ""] == true }
        end
        return out
    end,
    Apply = function(data, sel)
        local imp = data.customGroups; if not imp then return end
        local cur = Root("customGroups", { groups = {}, nextID = 1 })
        cur.groups = cur.groups or {}; cur.nextID = cur.nextID or 1
        local byName = {}
        for _, g in ipairs(cur.groups) do byName[g.name or ""] = g end
        for idx, g in ipairs(imp.groups or {}) do
            local exists = byName[g.name or ""]
            local it = sel.items and sel.items["g" .. idx]
            local doIt, fields
            if sel.mode == "add" then
                doIt = not exists
            elseif it and it.include then
                doIt = true; fields = it.fields
            end
            if doIt then
                if exists and sel.mode ~= "add" then
                    MergeByGroup(exists, g, CG_IDENTITY, CGGroupOf, fields or { spells = true, layout = true, anchor = true })
                else
                    local ng = DeepCopy(g)
                    ng.id = cur.nextID; cur.nextID = cur.nextID + 1
                    if byName[ng.name or ""] then ng.name = (ng.name or "Group") .. " (imported)" end
                    cur.groups[#cur.groups + 1] = ng
                    byName[ng.name or ""] = ng
                end
            end
        end
    end,
}

COLL.barSetup = {
    fieldGroups = {
        { key = "layout", label = "Bars, order & size" },
        { key = "anchor", label = "Position & anchor" },
    },
    Items = function(data)
        local imp = data.barSetup or {}
        local existing = {}
        local db = Dest()
        for _, s in ipairs((db.barSetup and db.barSetup.setups) or {}) do
            existing[s.name or ""] = true
        end
        local out = {}
        for idx, s in ipairs(imp.setups or {}) do
            out[#out + 1] = { id = "b" .. idx, label = s.name or ("Setup " .. idx), exists = existing[s.name or ""] == true }
        end
        return out
    end,
    Apply = function(data, sel)
        local imp = data.barSetup; if not imp then return end
        local cur = Root("barSetup", { setups = {}, active = 1 })
        cur.setups = cur.setups or {}
        local byName = {}
        for _, s in ipairs(cur.setups) do byName[s.name or ""] = s end
        for idx, s in ipairs(imp.setups or {}) do
            local exists = byName[s.name or ""]
            local it = sel.items and sel.items["b" .. idx]
            local doIt, fields
            if sel.mode == "add" then
                doIt = not exists
            elseif it and it.include then
                doIt = true; fields = it.fields
            end
            if doIt then
                if exists and sel.mode ~= "add" then
                    MergeByGroup(exists, s, BS_IDENTITY, BSGroupOf, fields or { layout = true, anchor = true })
                else
                    local ns2 = DeepCopy(s)
                    if byName[ns2.name or ""] then ns2.name = (ns2.name or "Setup") .. " (imported)" end
                    cur.setups[#cur.setups + 1] = ns2
                    byName[ns2.name or ""] = ns2
                end
            end
        end
    end,
}

COLL.specialBars = {
    Items = function(data)
        local imp = data.specialBars or {}
        local out = {}
        for specKey, s in pairs(imp.specs or {}) do
            local nb, ni = 0, 0
            for _, d in pairs(s.bars or {})  do if type(d) == "table" and d.spellID then nb = nb + 1 end end
            for _, d in pairs(s.icons or {}) do if type(d) == "table" and d.spellID then ni = ni + 1 end end
            if nb + ni > 0 then
                local db = Dest()
                local curSpec = db.specialBars and db.specialBars.specs and db.specialBars.specs[specKey]
                local exists = false
                if curSpec then
                    for _, d in pairs(curSpec.bars or {})  do if type(d) == "table" and d.spellID then exists = true break end end
                    if not exists then for _, d in pairs(curSpec.icons or {}) do if type(d) == "table" and d.spellID then exists = true break end end end
                end
                out[#out + 1] = {
                    id = "s" .. specKey, sort = tonumber(specKey) or 0,
                    label = SpecLabel(specKey) .. (" |cFF888888(%d bars, %d icons)|r"):format(nb, ni),
                    exists = exists,
                }
            end
        end
        table.sort(out, function(a, b) return a.sort < b.sort end)
        return out
    end,
    Apply = function(data, sel)
        local imp = data.specialBars; if not imp then return end
        local cur = Root("specialBars", { specs = {} })
        cur.specs = cur.specs or {}
        for specKey, s in pairs(imp.specs or {}) do
            local exists = cur.specs[specKey] ~= nil
            local it = sel.items and sel.items["s" .. specKey]
            local doIt
            if sel.mode == "add" then doIt = not exists
            elseif it and it.include then doIt = true end
            if doIt then cur.specs[specKey] = DeepCopy(s) end
        end
    end,
}

COLL.specialStyles = {
    Items = function(data)
        local imp = data.specialStyles or {}
        local cur = Dest().specialStyles or {}
        local out = {}
        for _, kind in ipairs({ "bars", "icons" }) do
            local tag = (kind == "bars") and "|cFF9FD8FF[Bar]|r " or "|cFFFFC98A[Icon]|r "
            for name in pairs(imp[kind] or {}) do
                out[#out + 1] = {
                    id = kind .. ":" .. name, kind = kind, name = name,
                    label = tag .. name, exists = (cur[kind] and cur[kind][name]) ~= nil,
                }
            end
        end
        table.sort(out, function(a, b) return a.id < b.id end)
        return out
    end,
    Apply = function(data, sel)
        local imp = data.specialStyles; if not imp then return end
        local cur = Root("specialStyles", { bars = {}, icons = {} })
        cur.bars = cur.bars or {}; cur.icons = cur.icons or {}
        for _, kind in ipairs({ "bars", "icons" }) do
            for name, style in pairs(imp[kind] or {}) do
                local exists = cur[kind][name] ~= nil
                local it = sel.items and sel.items[kind .. ":" .. name]
                local doIt
                if sel.mode == "add" then doIt = not exists
                elseif it and it.include then doIt = true end
                if doIt then cur[kind][name] = DeepCopy(style) end
            end
        end
    end,
}

M.COLLECTIONS = COLL

-- a value as one sorted string: unset and false read the same, "_" keys and skip keys left out
local function Canon(v, skip, out)
    if type(v) ~= "table" then
        out[#out + 1] = (type(v) == "number") and ("%.4f"):format(v) or tostring(v)
        return
    end
    local keys = {}
    for k, x in pairs(v) do
        local ks = tostring(k)
        if x ~= false and ks:sub(1, 1) ~= "_" and not (skip and skip[ks]) then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
        out[#out + 1] = tostring(k) .. "="
        Canon(v[k], skip, out)
        out[#out + 1] = ";"
    end
    out[#out + 1] = "}"
end

-- a short fingerprint of a value (nil for nothing)
function M.Print(v, skip)
    if v == nil then return nil end
    local parts = {}
    Canon(v, skip, parts)
    local s = table.concat(parts)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return ("%08x:%d"):format(h, #s)
end

-- ids a profile gives its own groups, and the group links that follow them
local GROUP_SKIP = { id = true }
local SPEC_SKIP = { customGroup = true }

local function ByName(list, sec)
    local out = {}
    for _, g in ipairs(list or {}) do
        if not sec or Fits(sec, g) then out[g.name or ""] = g end
    end
    return out
end

-- every item of an import next to the same item here: { [section index] = { {id, ident, label, pack, cur} } }
-- (id = the wizard's item id, ident = what stays the same between profiles: a name, a spec)
function M.PackDiff(data)
    local db = E.db.thingsUI or {}
    local out = {}
    for i, sec in ipairs(M.SECTIONS) do
        if Present(sec, data) then
            local list = {}
            local c = sec.collection
            if c == "customGroups" or c == "customBars" then
                local k = sec.keys[1]
                local mine = ByName(db[k] and db[k].groups, sec.only and sec)
                for idx, g in ipairs((data[k] and data[k].groups) or {}) do
                    if Fits(sec, g) then
                        local n = g.name or ""
                        list[#list + 1] = { id = ((c == "customGroups") and "g" or "c") .. idx, ident = "n:" .. n, label = n,
                            pack = M.Print(g, GROUP_SKIP), cur = M.Print(mine[n], GROUP_SKIP) }
                    end
                end
            elseif c == "barSetup" then
                local mine = ByName(db.barSetup and db.barSetup.setups)
                for idx, s in ipairs((data.barSetup and data.barSetup.setups) or {}) do
                    local n = s.name or ""
                    list[#list + 1] = { id = "b" .. idx, ident = "n:" .. n, label = n,
                        pack = M.Print(s), cur = M.Print(mine[n]) }
                end
            elseif c == "specialBars" then
                local mine = (db.specialBars and db.specialBars.specs) or {}
                for specKey, s in pairs((data.specialBars and data.specialBars.specs) or {}) do
                    list[#list + 1] = { id = "s" .. specKey, ident = "s:" .. specKey, label = SpecLabel(specKey),
                        pack = M.Print(s, SPEC_SKIP), cur = M.Print(mine[specKey], SPEC_SKIP) }
                end
            elseif c == "specialStyles" then
                local mine = db.specialStyles or {}
                for _, kind in ipairs({ "bars", "icons" }) do
                    for name, st in pairs((data.specialStyles and data.specialStyles[kind]) or {}) do
                        list[#list + 1] = { id = kind .. ":" .. name, ident = kind .. ":" .. name, label = name,
                            pack = M.Print(st), cur = M.Print(mine[kind] and mine[kind][name]) }
                    end
                end
            else
                local p, m = {}, {}
                for _, k in ipairs(sec.keys) do p[k] = data[k]; m[k] = db[k] end
                list[1] = { id = "_", ident = "_", label = sec.name, pack = M.Print(p), cur = M.Print(m) }
            end
            out[i] = list
        end
    end
    return out
end

-- target: a profile name to compare with and write into (default: this profile)
function M.Analyze(str, target)
    local data = Decode(str)
    if not data then return nil end
    destName = target
    local out = { data = data, sections = {} }
    for i, sec in ipairs(M.SECTIONS) do
        if Present(sec, data) then
            local entry = { index = i, name = sec.name, keys = sec.keys, collection = sec.collection, color = sec.color }
            local coll = sec.collection and COLL[sec.collection]
            if coll then
                entry.items = coll.Items(data, sec)
                entry.fieldGroups = coll.fieldGroups
                local new, dup = 0, 0
                for _, it in ipairs(entry.items) do
                    if it.exists then dup = dup + 1 else new = new + 1 end
                end
                entry.newCount, entry.dupCount = new, dup
            end
            out.sections[#out.sections + 1] = entry
        end
    end
    destName = nil
    return out
end

function M.ApplyPlan(data, plan, target)
    if not (data and plan) then return false end
    destName = target
    for i, sec in ipairs(M.SECTIONS) do
        local p = plan[i]
        if p and p.mode and p.mode ~= "skip" then
            if Present(sec, data) then
                if p.mode == "overwrite" and sec.only then
                    COLL[sec.collection].Apply(data, { mode = "replace" }, sec)
                elseif p.mode == "overwrite" then
                    local db = Dest()
                    for _, k in ipairs(sec.keys) do
                        if data[k] ~= nil then db[k] = DeepCopy(data[k]) end
                    end
                elseif sec.collection and COLL[sec.collection] then
                    COLL[sec.collection].Apply(data, p, sec)
                end
            end
        end
    end
    destName = nil
    -- another profile migrates its own borders when it loads
    if not target then ns.SpecialBars.Styles.MigrateBorders() end
    return true
end

-- copy between this profile and another one through the import picker
-- only: a section index to copy just that module
function M.OpenCopy(dir, name, only)
    local W = ns.ShareWizard
    if not W then return end
    if not name or name == M.CurrentProfile() or not (E.data and E.data.profiles and E.data.profiles[name]) then
        print("|cFF8080FFthingsUI|r: pick another profile first.")
        return
    end
    local sel
    if only then
        sel = {}
        for i in ipairs(M.SECTIONS) do sel[i] = (i == only) end
    end
    if dir == "from" then
        local str = M.Export(sel, M.ProfileDB(name) or {})
        if not str then print("|cFF8080FFthingsUI|r: " .. name .. " has nothing of its own there.") return end
        W.Open(str, { title = "Copy from " .. name })
    else
        local str = M.Export(sel)
        if not str then print("|cFF8080FFthingsUI|r: nothing to copy.") return end
        W.Open(str, { title = "Copy to " .. name, dest = name })
    end
end
