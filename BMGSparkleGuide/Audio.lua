local _, G = ...

local SOUND = "Interface\\AddOns\\BMGSparkleGuide\\Sounds\\"
local GAP = 0.85

local queue
local wait = 0

local driver = CreateFrame("Frame")
driver:Hide()

local function Play(file)
    if not PlaySoundFile then
        return false
    end
    local path = SOUND .. file .. ".ogg"
    local ok, result = pcall(PlaySoundFile, path, "Master")
    if not ok then
        ok, result = pcall(PlaySoundFile, path, "SFX")
    end
    return ok and (result == true or result == 1)
end

local function Shared(file)
    return file == "at" or file == "object" or file == "herb" or file == "ore"
        or file == "treasure" or file == "quest" or file == "bobber"
        or file == "loot" or file == "skin" or file:sub(1, 1) == "y"
end

local function Next()
    if not queue or not queue[1] then
        queue = nil
        driver:Hide()
        return
    end
    local file = table.remove(queue, 1)
    Play(file)
    if queue[1] then
        wait = GAP
    else
        queue = nil
        driver:Hide()
    end
end

driver:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait <= 0 then
        Next()
    end
end)

function G.SoundKey(name)
    local text = G.PlainString(name)
    if not text then
        return nil
    end
    text = text:lower():gsub("'", ""):gsub("[^a-z0-9]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if text == "" then
        return nil
    end
    return text
end

function G.Say(files)
    if not files or not files[1] then
        return
    end
    queue = {}
    for i = 1, #files do
        queue[i] = files[i]
    end
    wait = 0
    driver:Show()
    Next()
end

local KIND_FILE = {
    herbs = "herb",
    ore = "ore",
    treasure = "treasure",
    quests = "quest",
    bobber = "bobber",
    loot = "loot",
    skinning = "skin",
    others = "object",
    flight = "flight_path",
}

function G.HasNameSound(key)
    return key ~= nil and G.NAME_SOUND ~= nil and G.NAME_SOUND[key] == true
end

local PREFIX = {
    lush = true, lightfused = true, primal = true, voidbound = true,
    transplanted = true, camouflaged = true, rich = true, webbed = true,
    smoldering = true,
}

local function KnownKey(name)
    local key = G.SoundKey(name)
    if G.HasNameSound(key) then
        return key
    end
    if not key then
        return nil
    end
    local trimmed = key
    for _ = 1, 3 do
        local prefix, rest = trimmed:match("^([a-z0-9]+)_(.+)$")
        if prefix and PREFIX[prefix] and rest then
            trimmed = rest
            if G.HasNameSound(trimmed) then
                return trimmed
            end
        else
            break
        end
    end
    local shorter = trimmed:gsub("_seam$", ""):gsub("_deposit$", ""):gsub("_vein$", "")
    if G.HasNameSound(shorter) then
        return shorter
    end
    return nil
end

local function ResolveName(kind, name, label)
    return KnownKey(label) or KnownKey(name)
end

function G.SpeakTarget(kind, name, step, label)
    if not G.db.voice then
        return
    end
    local nameFile = ResolveName(kind, name, label)
    if not nameFile then
        return
    end
    local files
    if step == "at" and G.db.steps.at then
        files = { "at", nameFile }
    elseif step == "50" or step == "45" or step == "40" or step == "35" or step == "30" or step == "25" or step == "20" or step == "15" or step == "10" or step == "5" then
        if G.db.steps[step] then
            files = { nameFile, "y" .. step }
        else
            files = { nameFile }
        end
    else
        files = { nameFile }
    end
    G.Say(files)
end

function G.PlaySample()
    G.Say({ "silverleaf", "y10" })
end
