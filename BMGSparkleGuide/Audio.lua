local _, G = ...

local SOUND = "Interface\\AddOns\\BMGSparkleGuide\\Sounds\\"
local GAP = 0.85

local queue
local wait = 0

local driver = CreateFrame("Frame")
driver:Hide()

local function Play(file)
    local ok = PlaySoundFile(SOUND .. file .. ".ogg", "Master")
    return ok == true or ok == 1
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
    if not Play(file) and not Shared(file) then
        Play("object")
    end
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
}

function G.HasNameSound(key)
    return key ~= nil and G.NAME_SOUND ~= nil and G.NAME_SOUND[key] == true
end

local PREFIX = {
    lush = true, lightfused = true, primal = true, voidbound = true,
    transplanted = true, camouflaged = true, rich = true, webbed = true,
    smoldering = true,
}

local function ResolveName(kind, name)
    local key = G.SoundKey(name)
    if G.HasNameSound(key) then
        return key
    end
    if key then
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
    end
    return KIND_FILE[kind] or "object"
end

function G.SpeakTarget(kind, name, step)
    if not G.db.voice then
        return
    end
    local nameFile = ResolveName(kind, name)
    local files
    if step == "at" and G.db.steps.at then
        files = { "at", nameFile }
    elseif step == "20" or step == "15" or step == "10" or step == "5" then
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
