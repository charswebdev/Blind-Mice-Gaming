local addonName, LPL = ...

-- Minimal BN share encode/decode for vault modules (keybinds, gear, bars, edit mode, loadouts).
-- Classic Era does not load Retail TalentShare.lua; EraStubs still owns talent/PvP/CDM import UX.

LPL.ShareCodec = LPL.ShareCodec or {}

local function Trim(text)
    if type(text) ~= "string" then
        return ""
    end
    return text:match("^%s*(.-)%s*$") or text
end

local function FormatTableKey(key)
    if type(key) == "number" then
        return "[" .. key .. "]"
    end
    if type(key) == "string" then
        if key:match("^[%a_][%w_]*$") then
            return key
        end
        return "[" .. string.format("%q", key) .. "]"
    end
    error("Invalid key type in export")
end

local function QuoteNumericTableKeys(text)
    if type(text) ~= "string" then
        return text
    end
    return text:gsub("([{,])(%d+)=", "%1[%2]=")
end

local function StringToTable(text)
    if type(text) ~= "string" or text:sub(1, 1) ~= "{" then
        return false, "Invalid share string."
    end
    text = QuoteNumericTableKeys(text)
    local func, err = loadstring("return " .. text, "LPLImport")
    if not func and load then
        func, err = load("return " .. text, "LPLImport", "t", {})
    end
    if not func then
        return false, err or "Invalid share string."
    end
    if setfenv then
        setfenv(func, {})
    end
    return pcall(func)
end

local function TableToString(tbl, visited)
    visited = visited or {}
    if visited[tbl] then
        error("Circular table in export")
    end
    visited[tbl] = true

    local parts = {}
    for key, value in pairs(tbl) do
        local keyText = FormatTableKey(key)
        local valueText
        if type(value) == "table" then
            valueText = TableToString(value, visited)
        elseif type(value) == "string" then
            valueText = string.format("%q", value)
        elseif type(value) == "number" or type(value) == "boolean" then
            valueText = tostring(value)
        else
            error("Invalid value type in export")
        end
        parts[#parts + 1] = keyText .. "=" .. valueText
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

local Base64Encode, Base64Decode
do
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    function Base64Encode(data)
        return ((data:gsub(".", function(char)
            local bits = ""
            local byte = char:byte()
            for i = 8, 1, -1 do
                bits = bits .. (byte % (2 ^ i) - byte % (2 ^ (i - 1)) > 0 and "1" or "0")
            end
            return bits
        end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(group)
            if #group < 6 then
                return ""
            end
            local value = 0
            for i = 1, 6 do
                value = value + ((group:sub(i, i) == "1") and (2 ^ (6 - i)) or 0)
            end
            return alphabet:sub(value + 1, value + 1)
        end) .. ({ "", "==", "=" })[#data % 3 + 1])
    end

    function Base64Decode(data)
        data = string.gsub(data, "[^" .. alphabet .. "=]", "")
        return (data:gsub(".", function(char)
            if char == "=" then
                return ""
            end
            local position = alphabet:find(char, 1, true)
            if not position then
                return ""
            end
            local bits = ""
            local value = position - 1
            for i = 6, 1, -1 do
                bits = bits .. (value % (2 ^ i) - value % (2 ^ (i - 1)) > 0 and "1" or "0")
            end
            return bits
        end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(group)
            if #group ~= 8 then
                return ""
            end
            local value = 0
            for i = 1, 8 do
                value = value + ((group:sub(i, i) == "1") and (2 ^ (8 - i)) or 0)
            end
            return string.char(value)
        end))
    end
end

local function Encode(content, format)
    format = format or "BN"
    if #format == 1 then
        if format == "N" then
            return "N" .. content
        elseif format == "B" then
            return "B" .. Base64Encode(content)
        end
        error("Unsupported export format")
    end
    local prefix, rest = format:match("^([A-Z])([A-Z]*)$")
    return Encode(Encode(content, rest), prefix)
end

local function Decode(content)
    if type(content) ~= "string" then
        return false, "Invalid share string."
    end
    local format, body = content:match("^([A-Z])(.*)$")
    if format == "N" then
        return true, body
    elseif format == "B" then
        return Decode(Base64Decode(body))
    end
    return false, "Unsupported share string format."
end

function LPL.ShareCodec:DecodeShareString(text)
    text = Trim(text)
    if text == "" then
        return false, "Empty share string."
    end

    local decodedText = text
    if text:match("^[BN]") then
        local ok, decoded = Decode(text)
        if not ok then
            return false, decoded or "Could not decode share string."
        end
        decodedText = decoded
    end

    if type(decodedText) == "string" and decodedText:sub(1, 1) == "{" then
        return StringToTable(decodedText)
    end

    return false, "Unrecognized share string."
end

function LPL.ShareCodec:EncodeShareTable(payload)
    if type(payload) ~= "table" then
        return nil, "Nothing to export."
    end
    local ok, encoded = pcall(function()
        return Encode(TableToString(payload), "BN")
    end)
    if not ok then
        return nil, encoded or "Could not encode share string."
    end
    return encoded
end

-- Vault share modules call LPL.TalentShare:EncodeShareTable / DecodeShareString.
local function AttachToTalentShare()
    LPL.TalentShare = LPL.TalentShare or {}
    LPL.TalentShare.EncodeShareTable = function(_, payload)
        return LPL.ShareCodec:EncodeShareTable(payload)
    end
    LPL.TalentShare.DecodeShareString = function(_, text)
        return LPL.ShareCodec:DecodeShareString(text)
    end
end

AttachToTalentShare()
