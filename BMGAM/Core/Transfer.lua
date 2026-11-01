local _, BMGAM = ...

BMGAM.Transfer = BMGAM.Transfer or {}
local Transfer = BMGAM.Transfer

local HEADER = "BMGAM1"
local HEADER2 = "BMGAM2"

local function KeyLess(left, right)
    local leftKind = type(left)
    local rightKind = type(right)
    if leftKind ~= rightKind then
        return leftKind < rightKind
    end
    if leftKind == "number" or leftKind == "string" then
        return left < right
    end
    if leftKind == "boolean" then
        return left == false and right == true
    end
    return tostring(left) < tostring(right)
end

local function Write(value, parts, seen, depth)
    if type(issecretvalue) == "function" and issecretvalue(value) then
        parts[#parts + 1] = "Z"
        return true
    end
    local kind = type(value)
    if kind == "nil" then
        parts[#parts + 1] = "Z"
        return true
    end
    if kind == "boolean" then
        parts[#parts + 1] = value and "B1" or "B0"
        return true
    end
    if kind == "number" then
        local text = tostring(value)
        if type(tonumber(text)) ~= "number" then
            return false
        end
        parts[#parts + 1] = "N" .. text .. ";"
        return true
    end
    if kind == "string" then
        parts[#parts + 1] = "S" .. tostring(#value) .. ":" .. value
        return true
    end
    if kind ~= "table" then
        parts[#parts + 1] = "Z"
        return true
    end
    if depth > 32 or seen[value] then
        return false
    end
    seen[value] = true
    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
    end
    table.sort(keys, KeyLess)
    parts[#parts + 1] = "T" .. tostring(#keys) .. ";"
    local index = 1
    while keys[index] do
        local key = keys[index]
        if not Write(key, parts, seen, depth + 1) then
            return false
        end
        if not Write(value[key], parts, seen, depth + 1) then
            return false
        end
        index = index + 1
    end
    seen[value] = nil
    return true
end

local function ReadValue(text, pos)
    if pos > #text then
        return nil, nil
    end
    local mark = string.sub(text, pos, pos)
    if mark == "Z" then
        return nil, pos + 1
    end
    if mark == "B" then
        local bit = string.sub(text, pos + 1, pos + 1)
        if bit == "1" then
            return true, pos + 2
        end
        if bit == "0" then
            return false, pos + 2
        end
        return nil, nil
    end
    if mark == "N" then
        local semi = string.find(text, ";", pos + 1, true)
        if not semi then
            return nil, nil
        end
        local number = tonumber(string.sub(text, pos + 1, semi - 1))
        if type(number) ~= "number" then
            return nil, nil
        end
        return number, semi + 1
    end
    if mark == "S" then
        local colon = string.find(text, ":", pos + 1, true)
        if not colon then
            return nil, nil
        end
        local len = tonumber(string.sub(text, pos + 1, colon - 1))
        if type(len) ~= "number" or len < 0 or len % 1 ~= 0 then
            return nil, nil
        end
        local startAt = colon + 1
        if len == 0 then
            return "", startAt
        end
        local stopAt = startAt + len - 1
        if stopAt > #text then
            return nil, nil
        end
        return string.sub(text, startAt, stopAt), stopAt + 1
    end
    if mark ~= "T" then
        return nil, nil
    end
    local semi = string.find(text, ";", pos + 1, true)
    if not semi then
        return nil, nil
    end
    local count = tonumber(string.sub(text, pos + 1, semi - 1))
    if type(count) ~= "number" or count < 0 or count % 1 ~= 0 then
        return nil, nil
    end
    local cursor = semi + 1
    local out = {}
    local index = 1
    while index <= count do
        local key, keyPos = ReadValue(text, cursor)
        if not keyPos or key == nil then
            return nil, nil
        end
        local val, valPos = ReadValue(text, keyPos)
        if not valPos then
            return nil, nil
        end
        out[key] = val
        cursor = valPos
        index = index + 1
    end
    return out, cursor
end

local function TailIsBlank(text, pos)
    while pos <= #text do
        local ch = string.sub(text, pos, pos)
        if ch ~= " " and ch ~= "\n" and ch ~= "\r" and ch ~= "\t" then
            return false
        end
        pos = pos + 1
    end
    return true
end

local function Pack()
    return {
        saved = type(bmgam_SavedVariables) == "table" and bmgam_SavedVariables or {},
        quests = type(bmgam_Quests) == "table" and bmgam_Quests or {},
        achievements = type(bmgam_Achievements) == "table" and bmgam_Achievements or {},
        catalog = type(bmgam_Account) == "table" and bmgam_Account or {},
        manuscripts = type(bmgam_Collections) == "table" and bmgam_Collections or {},
    }
end

local function DecodePacked(payload)
    if payload == "" or not C_EncodingUtil then
        return nil
    end
    if type(C_EncodingUtil.DecodeBase64) ~= "function" or type(C_EncodingUtil.DecompressString) ~= "function" or type(C_EncodingUtil.DeserializeCBOR) ~= "function" then
        return nil
    end
    local decoded, binary = pcall(C_EncodingUtil.DecodeBase64, payload)
    if not decoded or type(binary) ~= "string" or binary == "" then
        return nil
    end
    local inflated, plain = pcall(C_EncodingUtil.DecompressString, binary)
    if not inflated or type(plain) ~= "string" or plain == "" then
        return nil
    end
    local read, pack = pcall(C_EncodingUtil.DeserializeCBOR, plain)
    if not read or type(pack) ~= "table" or type(pack.saved) ~= "table" then
        return nil
    end
    return pack
end

function Transfer.Encode()
    if not C_EncodingUtil or type(C_EncodingUtil.SerializeCBOR) ~= "function" or type(C_EncodingUtil.CompressString) ~= "function" or type(C_EncodingUtil.EncodeBase64) ~= "function" then
        return nil
    end
    local method = Enum and Enum.CompressionMethod and Enum.CompressionMethod.Deflate
    local level = Enum and Enum.CompressionLevel and Enum.CompressionLevel.OptimizeForSize
    if not method or not level then
        return nil
    end
    local packed, serialized = pcall(C_EncodingUtil.SerializeCBOR, Pack())
    if not packed or type(serialized) ~= "string" or serialized == "" then
        return nil
    end
    local squeezed, compressed = pcall(C_EncodingUtil.CompressString, serialized, method, level)
    if not squeezed or type(compressed) ~= "string" or compressed == "" then
        return nil
    end
    local coded, encoded = pcall(C_EncodingUtil.EncodeBase64, compressed)
    if not coded or type(encoded) ~= "string" or encoded == "" then
        return nil
    end
    return HEADER2 .. encoded
end

function Transfer.Decode(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    local compact = string.gsub(text, "%s", "")
    if string.sub(compact, 1, 6) == HEADER2 then
        return DecodePacked(string.sub(compact, 7))
    end
    local pos = 1
    while pos <= #text do
        local ch = string.sub(text, pos, pos)
        if ch ~= " " and ch ~= "\n" and ch ~= "\r" and ch ~= "\t" then
            break
        end
        pos = pos + 1
    end
    if string.sub(text, pos, pos + 5) ~= HEADER then
        return nil
    end
    local value, nextPos = ReadValue(text, pos + 6)
    if not nextPos or type(value) ~= "table" or type(value.saved) ~= "table" then
        return nil
    end
    if not TailIsBlank(text, nextPos) then
        return nil
    end
    return value
end

function Transfer.Apply(pack)
    if type(pack) ~= "table" or type(pack.saved) ~= "table" then
        return false
    end
    bmgam_SavedVariables = pack.saved
    bmgam_Quests = type(pack.quests) == "table" and pack.quests or {}
    bmgam_Achievements = type(pack.achievements) == "table" and pack.achievements or {}
    bmgam_Account = type(pack.catalog) == "table" and pack.catalog or {}
    bmgam_Collections = type(pack.manuscripts) == "table" and pack.manuscripts or {}
    if BMGAM.Store and BMGAM.Store.ClearView then
        BMGAM.Store.ClearView()
    end
    if BMGAM.DB and BMGAM.DB.Init then
        BMGAM.DB.Init()
    end
    if BMGAM.Minimap and BMGAM.Minimap.Refresh then
        BMGAM.Minimap.Refresh()
    end
    return true
end
