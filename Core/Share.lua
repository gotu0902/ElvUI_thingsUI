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
    { name = "Groups - Bars",        keys = { "customBars" },                                 color = "F27D2A" },
    { name = "Special Bars & Icons", keys = { "specialBars" },  collection = "specialBars",   color = "80FF80" },
    { name = "Special Styles",       keys = { "specialStyles" }, collection = "specialStyles", color = "FF80C0" },
    { name = "Timers",               keys = { "timers" },                                     color = "FFC04D" },
    { name = "Racials",              keys = { "racialsCDM" } },
    { name = "Cluster Positioning",  keys = { "clusterPositioning" } },
    { name = "Movers & General",     keys = { "essentialMover", "autoSetAudioChannels", "rightChatAsBackground", "rightChatWidthOffset", "rightChatHeightOffset" } },
}

local COMPRESS = Enum.CompressionMethod and Enum.CompressionMethod.Deflate or 0
local OPTIMIZE = Enum.CompressionLevel and Enum.CompressionLevel.Default or 0

local function Tools()
    local CE = C_EncodingUtil
    if CE and CE.SerializeCBOR and CE.CompressString and CE.EncodeBase64
        and CE.DeserializeCBOR and CE.DecompressString and CE.DecodeBase64 then
        return CE
    end
end

function M.Export(selected)
    local CE = Tools()
    if not CE then return nil end
    local data = {}
    for i, sec in ipairs(M.SECTIONS) do
        if (not selected) or selected[i] ~= false then
            for _, k in ipairs(sec.keys) do
                if E.db.thingsUI[k] ~= nil then data[k] = E.db.thingsUI[k] end
            end
        end
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

function M.SectionsInString(str)
    local data = Decode(str)
    if not data then return nil end
    local out = {}
    for _, sec in ipairs(M.SECTIONS) do
        for _, k in ipairs(sec.keys) do
            if data[k] ~= nil then out[#out + 1] = sec.name; break end
        end
    end
    return out
end

function M.Import(str)
    if not Tools() then return false, "Serialization unavailable." end
    local s = tostring(str or ""):gsub("%s", "")
    if s == "" then return false, "Paste an export string first." end
    if s:sub(1, #OLD_PREFIX) == OLD_PREFIX then return false, "Old export format - generate a new string with this version." end
    if s:sub(1, #PREFIX) ~= PREFIX then return false, "Not a thingsUI export string." end
    local data = Decode(s)
    if not data then return false, "Could not decode the string." end
    for k, v in pairs(data) do E.db.thingsUI[k] = v end
    return true
end

local function Root(key, seed)
    local db = E.db.thingsUI
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

COLL.customGroups = {
    fieldGroups = {
        { key = "spells", label = "Spells / members" },
        { key = "layout", label = "Layout & size" },
        { key = "anchor", label = "Position & anchor" },
    },
    Items = function(data)
        local imp = data.customGroups or {}
        local existing = {}
        for _, g in ipairs((E.db.thingsUI.customGroups and E.db.thingsUI.customGroups.groups) or {}) do
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
        for _, s in ipairs((E.db.thingsUI.barSetup and E.db.thingsUI.barSetup.setups) or {}) do
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
                local curSpec = E.db.thingsUI.specialBars and E.db.thingsUI.specialBars.specs and E.db.thingsUI.specialBars.specs[specKey]
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
        local cur = E.db.thingsUI.specialStyles or {}
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

function M.Analyze(str)
    local data = Decode(str)
    if not data then return nil end
    local out = { data = data, sections = {} }
    for i, sec in ipairs(M.SECTIONS) do
        local present = false
        for _, k in ipairs(sec.keys) do if data[k] ~= nil then present = true break end end
        if present then
            local entry = { index = i, name = sec.name, keys = sec.keys, collection = sec.collection, color = sec.color }
            local coll = sec.collection and COLL[sec.collection]
            if coll then
                entry.items = coll.Items(data)
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
    return out
end

function M.ApplyPlan(data, plan)
    if not (data and plan) then return false end
    for i, sec in ipairs(M.SECTIONS) do
        local p = plan[i]
        if p and p.mode and p.mode ~= "skip" then
            local present = false
            for _, k in ipairs(sec.keys) do if data[k] ~= nil then present = true break end end
            if present then
                if p.mode == "overwrite" then
                    for _, k in ipairs(sec.keys) do
                        if data[k] ~= nil then E.db.thingsUI[k] = DeepCopy(data[k]) end
                    end
                elseif sec.collection and COLL[sec.collection] then
                    COLL[sec.collection].Apply(data, p)
                end
            end
        end
    end
    return true
end
