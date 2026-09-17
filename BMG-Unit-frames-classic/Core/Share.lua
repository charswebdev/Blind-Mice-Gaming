--[[
  BMG Unit Frames — export / import codes
  Lua 5.1 only.

  Format: !BMGUF:1!<4 hex checksum><base64 JSON>
  Only tables, strings, numbers, and booleans are encoded.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.Share = UF.Share or {}
local Share = UF.Share

local PREFIX = "!BMGUF:1!"
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function Checksum(s)
    local n = 0
    for i = 1, #s do
        n = (n + string.byte(s, i) * ((i % 7) + 1)) % 65521
    end
    return string.format("%04X", n)
end

local function EncodeBase64(data)
    local out = {}
    local i = 1
    local len = #data
    while i <= len do
        local a, b, c = string.byte(data, i, i + 2)
        a = a or 0
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        if not b then
            out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1) .. "=="
        elseif not c then
            out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1) .. B64:sub(c3 + 1, c3 + 1) .. "="
        else
            out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1) .. B64:sub(c3 + 1, c3 + 1) .. B64:sub(c4 + 1, c4 + 1)
        end
        i = i + 3
    end
    return table.concat(out)
end

local function DecodeBase64(data)
    data = data:gsub("[^A-Za-z0-9+%/=]", "")
    local map = {}
    for i = 1, #B64 do
        map[B64:sub(i, i)] = i - 1
    end
    local out = {}
    local i = 1
    while i <= #data do
        local c1 = map[data:sub(i, i)] or 0
        local c2 = map[data:sub(i + 1, i + 1)] or 0
        local c3 = map[data:sub(i + 2, i + 2)] or 0
        local c4 = map[data:sub(i + 3, i + 3)] or 0
        local n = c1 * 262144 + c2 * 4096 + c3 * 64 + c4
        local a = math.floor(n / 65536) % 256
        local b = math.floor(n / 256) % 256
        local c = n % 256
        out[#out + 1] = string.char(a)
        if data:sub(i + 2, i + 2) ~= "=" then
            out[#out + 1] = string.char(b)
        end
        if data:sub(i + 3, i + 3) ~= "=" then
            out[#out + 1] = string.char(c)
        end
        i = i + 4
    end
    return table.concat(out)
end

local function Escape(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    return s
end

local function Encode(value)
    local t = type(value)
    if t == "nil" then
        return "null"
    end
    if t == "boolean" then
        if value then
            return "true"
        end
        return "false"
    end
    if t == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return "0"
        end
        return tostring(value)
    end
    if t == "string" then
        return '"' .. Escape(value) .. '"'
    end
    if t == "table" then
        local keys = {}
        for k in pairs(value) do
            if type(k) == "string" or type(k) == "number" then
                keys[#keys + 1] = k
            end
        end
        table.sort(keys, function(a, b)
            return tostring(a) < tostring(b)
        end)
        local parts = {}
        for i = 1, #keys do
            local k = keys[i]
            parts[#parts + 1] = Encode(tostring(k)) .. ":" .. Encode(value[k])
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

local function Skip(s, i)
    while i <= #s do
        local c = s:sub(i, i)
        if c ~= " " and c ~= "\n" and c ~= "\r" and c ~= "\t" then
            return i
        end
        i = i + 1
    end
    return i
end

local Decode

local function DecodeString(s, i)
    i = i + 1
    local out = {}
    while i <= #s do
        local c = s:sub(i, i)
        if c == '"' then
            return table.concat(out), i + 1
        end
        if c == "\\" then
            local n = s:sub(i + 1, i + 1)
            if n == "n" then
                out[#out + 1] = "\n"
            elseif n == "r" then
                out[#out + 1] = "\r"
            else
                out[#out + 1] = n
            end
            i = i + 2
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return nil, i, "Unfinished string."
end

Decode = function(s, i)
    i = Skip(s, i or 1)
    local c = s:sub(i, i)
    if c == '"' then
        return DecodeString(s, i)
    end
    if c == "{" then
        local obj = {}
        i = Skip(s, i + 1)
        if s:sub(i, i) == "}" then
            return obj, i + 1
        end
        while i <= #s do
            local key, ni, err = Decode(s, i)
            if err then
                return nil, ni, err
            end
            i = Skip(s, ni)
            if s:sub(i, i) ~= ":" then
                return nil, i, "Missing colon."
            end
            local value
            value, ni, err = Decode(s, i + 1)
            if err then
                return nil, ni, err
            end
            if type(key) == "string" then
                obj[key] = value
            end
            i = Skip(s, ni)
            local sep = s:sub(i, i)
            if sep == "}" then
                return obj, i + 1
            end
            if sep ~= "," then
                return nil, i, "Missing comma."
            end
            i = i + 1
        end
        return nil, i, "Unfinished table."
    end
    if s:sub(i, i + 3) == "true" then
        return true, i + 4
    end
    if s:sub(i, i + 4) == "false" then
        return false, i + 5
    end
    if s:sub(i, i + 3) == "null" then
        return nil, i + 4
    end
    local num, rest = s:match("^(%-?%d+%.?%d*)()", i)
    if num then
        return tonumber(num), rest
    end
    return nil, i, "Bad value."
end

function Share.Encode(profile)
    local payload = Encode(UF.DB.Exportable(profile))
    return PREFIX .. Checksum(payload) .. EncodeBase64(payload)
end

function Share.Decode(code)
    if type(code) ~= "string" then
        return nil, "Paste a BMG Unit Frames code."
    end
    code = code:gsub("%s+", "")
    if code:sub(1, #PREFIX) ~= PREFIX then
        return nil, "That is not a BMG Unit Frames code."
    end
    local body = code:sub(#PREFIX + 1)
    local sum = body:sub(1, 4)
    local b64 = body:sub(5)
    if #sum ~= 4 or b64 == "" then
        return nil, "That code is incomplete."
    end
    local payload = DecodeBase64(b64)
    if Checksum(payload) ~= sum then
        return nil, "That code is damaged. Copy it again."
    end
    local data, _, err = Decode(payload, 1)
    if err or type(data) ~= "table" then
        return nil, err or "That code could not be read."
    end
    return data
end

function Share.Export()
    return Share.Encode(UF.DB.Get())
end

function Share.Import(code, name)
    local data, err = Share.Decode(code)
    if not data then
        return false, err
    end
    return UF.DB.ApplyExportTable(data, name)
end
