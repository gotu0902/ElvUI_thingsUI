local _, ns = ...
local E = ns.E

ns.Share = ns.Share or {}
local M = ns.Share

local PREFIX = "!TUI1!"

M.SECTIONS = {
    { name = "Bar Setup",            keys = { "barSetup" } },
    { name = "Buff Bars",            keys = { "buffBars" } },
    { name = "CDM Icons",            keys = { "cdmIcons" } },
    { name = "Charge Bar",           keys = { "chargeBar" } },
    { name = "Classbar",             keys = { "classbarMode" } },
    { name = "Custom Groups",        keys = { "customGroups" } },
    { name = "Special Bars & Icons", keys = { "specialBars" } },
    { name = "Timers",               keys = { "timers" } },
    { name = "Trinkets",             keys = { "trinketsCDM" } },
    { name = "Racials",              keys = { "racialsCDM" } },
    { name = "Cluster Positioning",  keys = { "clusterPositioning" } },
    { name = "Movers & General",     keys = { "essentialMover", "autoSetAudioChannels", "rightChatAsBackground", "rightChatWidthOffset", "rightChatHeightOffset" } },
}

local function Tools()
    local Deflate = E.Libs and E.Libs.Deflate
    local D = E.GetModule and E:GetModule("Distributor", true)
    if Deflate and D and D.Serialize and D.Deserialize then return Deflate, D end
end

function M.Export(selected)
    local Deflate, D = Tools()
    if not Deflate then return nil end
    local data = {}
    for i, sec in ipairs(M.SECTIONS) do
        if (not selected) or selected[i] ~= false then
            for _, k in ipairs(sec.keys) do
                if E.db.thingsUI[k] ~= nil then data[k] = E.db.thingsUI[k] end
            end
        end
    end
    if next(data) == nil then return nil end
    local serialized = D:Serialize(data)
    local compressed = serialized and Deflate:CompressDeflate(serialized, { level = 9 })
    if not compressed then return nil end
    return PREFIX .. Deflate:EncodeForPrint(compressed)
end

local function Decode(str)
    local Deflate, D = Tools()
    if not Deflate then return nil end
    str = tostring(str or ""):gsub("%s", "")
    if str == "" or str:sub(1, #PREFIX) ~= PREFIX then return nil end
    local compressed = Deflate:DecodeForPrint(str:sub(#PREFIX + 1))
    local serialized = compressed and Deflate:DecompressDeflate(compressed)
    if not serialized then return nil end
    local ok, data = D:Deserialize(serialized)
    if ok and type(data) == "table" then return data end
end

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
    if s:sub(1, #PREFIX) ~= PREFIX then return false, "Not a thingsUI export string." end
    local data = Decode(s)
    if not data then return false, "Could not decode the string." end
    for k, v in pairs(data) do E.db.thingsUI[k] = v end
    return true
end
