--[[
  AllQuest — SavedVariables
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.DB = AQ.DB or {}
local DB = AQ.DB

local defaults = {
    trackerEnabled = true,
    trackerLocked = false,
    trackerWidth = 320,
    trackerMaxHeight = 520,
    trackerHeight = nil,
    trackerScale = 1,
    trackerPoint = "TOPRIGHT",
    trackerRelativePoint = "TOPRIGHT",
    trackerX = -180,
    trackerY = -220,
    trackerFontSize = 14,
    trackerHideEmpty = true,
    trackerCollapseInInstance = true,
    trackerShowCompletedObjectives = true,
    trackerShowItemButtons = true,
    trackerShowClosestItem = true,
    trackerObjectiveProgressColors = true,
    trackerDifficultyColors = true,
    soundQuest = true,
    soundQuestComplete = "Default",
    soundChannel = "Master",
    trackerAutoWatch = false,
    autoQuestAccept = true,
    autoQuestTurnIn = true,
    autoQuestNotify = true,
    hideBlizzardTracker = true,

    journalPoint = "CENTER",
    journalX = 0,
    journalY = 0,
    journalWidth = 760,
    journalHeight = 560,
    journalFontSize = 16,
    journalGrid = true,

    speechEnabled = true,
    speechOnSelect = true,
    speechOnQuestProgress = true,
    ttsRate = 0,
    ttsVolume = 100,

    minimapButtonEnabled = true,
    minimapButtonAngle = 200,

    fontScale = 1,

    filters = {
        hideComplete = false,
        hideDaily = false,
        hideWeekly = false,
    },

    collapsedHeaders = {},
    trackerCollapsed = false,
    seenConflictWarning = false,

    modules = {
        popups = true,
        quests = true,
        campaigns = true,
        scenarios = true,
        worldquests = true,
        achievements = true,
        recipes = true,
        activities = true,
        collectibles = true,
        pets = true,
        rares = true,
        questcompletist = true,
    },
    modulesOrder = {},
    plugins = {
        TomTom = true,
        Masque = true,
        PetTracker = true,
        RareScanner = true,
        BattlePetCompletionist = true,
        SilverDragon = true,
        QuestCompletist = true,
        AllTheThings = true,
        ZygorGuidesViewer = true,
        BtWQuests = true,
    },
    -- Per LoadOnDemand data pack (addon name -> true/false). nil uses TOC AutoLoad / current expansion.
    dataPacks = {},
}

local charDefaults = {
    trackerCollapsed = false,
    collapsedHeaders = {},
    activeProfile = "Default",
}

local ROOT_KEYS = {
    profiles = true,
}

local function CopyDefaults(src, dest)
    if type(dest) ~= "table" then
        dest = {}
    end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = CopyDefaults(v, dest[k])
        elseif dest[k] == nil then
            dest[k] = v
        end
    end
    return dest
end

local function DeepCopy(src)
    if type(src) ~= "table" then
        return src
    end
    local out = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            out[k] = DeepCopy(v)
        else
            out[k] = v
        end
    end
    return out
end

local function SanitizeName(name)
    if type(name) ~= "string" then
        return nil
    end
    name = name:gsub("|", ""):gsub("[%c]", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        return nil
    end
    if string.len(name) > 40 then
        name = string.sub(name, 1, 40)
    end
    return name
end

local function Serialize(value)
    local tv = type(value)
    if value == nil then
        return "N"
    end
    if tv == "boolean" then
        return value and "B1" or "B0"
    end
    if tv == "number" then
        local d = tostring(value)
        return "n" .. string.len(d) .. ":" .. d
    end
    if tv == "string" then
        return "s" .. string.len(value) .. ":" .. value
    end
    if tv ~= "table" then
        return "N"
    end
    local chunks = {}
    for k, v in pairs(value) do
        chunks[#chunks + 1] = Serialize(k) .. "=" .. Serialize(v)
    end
    local body = table.concat(chunks, ",")
    return "t" .. string.len(body) .. ":" .. body
end

local function Deserialize(s, pos)
    pos = pos or 1
    if type(s) ~= "string" or pos > string.len(s) then
        return nil, pos
    end
    local c = string.sub(s, pos, pos)
    if c == "N" then
        return nil, pos + 1
    end
    if c == "B" then
        return string.sub(s, pos + 1, pos + 1) == "1", pos + 2
    end
    if c ~= "n" and c ~= "s" and c ~= "t" then
        return nil, pos
    end
    local colon = string.find(s, ":", pos + 1, true)
    if not colon then
        return nil, pos
    end
    local len = tonumber(string.sub(s, pos + 1, colon - 1))
    if not len or len < 0 then
        return nil, pos
    end
    local start = colon + 1
    local stop = start + len - 1
    if stop > string.len(s) then
        return nil, pos
    end
    local body = string.sub(s, start, stop)
    local nextPos = stop + 1
    if c == "n" then
        return tonumber(body), nextPos
    end
    if c == "s" then
        return body, nextPos
    end
    local t = {}
    local p = 1
    local blen = string.len(body)
    while p <= blen do
        local key, p2 = Deserialize(body, p)
        if string.sub(body, p2, p2) ~= "=" then
            break
        end
        local val, p3 = Deserialize(body, p2 + 1)
        t[key] = val
        p = p3
        if string.sub(body, p, p) == "," then
            p = p + 1
        end
    end
    return t, nextPos
end

local function EnsureRoot()
    if type(AllQuestDB) ~= "table" then
        AllQuestDB = {}
    end
    if type(AllQuestDB.profiles) ~= "table" then
        local settings = {}
        local remove = {}
        for k, v in pairs(AllQuestDB) do
            if not ROOT_KEYS[k] then
                settings[k] = v
                remove[#remove + 1] = k
            end
        end
        for i = 1, #remove do
            AllQuestDB[remove[i]] = nil
        end
        AllQuestDB.profiles = {
            Default = CopyDefaults(defaults, settings),
        }
    end
    local any = false
    for name, prof in pairs(AllQuestDB.profiles) do
        if type(name) == "string" and type(prof) == "table" then
            any = true
            CopyDefaults(defaults, prof)
        end
    end
    if not any then
        AllQuestDB.profiles.Default = CopyDefaults(defaults, {})
    end
    return AllQuestDB
end

local function EnsureChar()
    if type(AllQuestCharDB) ~= "table" then
        AllQuestCharDB = {}
    end
    CopyDefaults(charDefaults, AllQuestCharDB)
    return AllQuestCharDB
end

function DB.Merge()
    EnsureRoot()
    EnsureChar()
end

function DB.Char()
    return EnsureChar()
end

function DB.GetActiveName()
    local root = EnsureRoot()
    local char = EnsureChar()
    local name = char.activeProfile
    if type(name) == "string" and type(root.profiles[name]) == "table" then
        return name
    end
    if type(root.profiles.Default) == "table" then
        char.activeProfile = "Default"
        return "Default"
    end
    for n, prof in pairs(root.profiles) do
        if type(n) == "string" and type(prof) == "table" then
            char.activeProfile = n
            return n
        end
    end
    root.profiles.Default = CopyDefaults(defaults, {})
    char.activeProfile = "Default"
    return "Default"
end

function DB.Get()
    local root = EnsureRoot()
    local name = DB.GetActiveName()
    return root.profiles[name]
end

function DB.GetDefault(key)
    return defaults[key]
end

function DB.ListProfiles()
    local root = EnsureRoot()
    local names = {}
    for name, prof in pairs(root.profiles) do
        if type(name) == "string" and type(prof) == "table" then
            names[#names + 1] = name
        end
    end
    table.sort(names, function(a, b)
        if a == "Default" then
            return true
        end
        if b == "Default" then
            return false
        end
        return a < b
    end)
    return names
end

function DB.ProfileExists(name)
    local root = EnsureRoot()
    return type(name) == "string" and type(root.profiles[name]) == "table"
end

function DB.CreateProfile(name, fromName)
    name = SanitizeName(name)
    if not name then
        return false, "Enter a profile name."
    end
    local root = EnsureRoot()
    if root.profiles[name] then
        return false, "A profile named " .. name .. " already exists."
    end
    fromName = fromName or DB.GetActiveName()
    local src = root.profiles[fromName]
    if type(src) ~= "table" then
        src = root.profiles[DB.GetActiveName()]
    end
    root.profiles[name] = CopyDefaults(defaults, DeepCopy(src or {}))
    EnsureChar().activeProfile = name
    return true, name
end

function DB.UseProfile(name)
    if not DB.ProfileExists(name) then
        return false, "That profile does not exist."
    end
    EnsureChar().activeProfile = name
    return true
end

function DB.RenameProfile(oldName, newName)
    oldName = SanitizeName(oldName)
    newName = SanitizeName(newName)
    if not oldName or not newName then
        return false, "Enter a profile name."
    end
    if oldName == newName then
        return true, newName
    end
    local root = EnsureRoot()
    if type(root.profiles[oldName]) ~= "table" then
        return false, "That profile does not exist."
    end
    if root.profiles[newName] then
        return false, "A profile named " .. newName .. " already exists."
    end
    root.profiles[newName] = root.profiles[oldName]
    root.profiles[oldName] = nil
    local char = EnsureChar()
    if char.activeProfile == oldName then
        char.activeProfile = newName
    end
    return true, newName
end

function DB.DeleteProfile(name)
    name = SanitizeName(name)
    if not name then
        return false, "That profile does not exist."
    end
    local names = DB.ListProfiles()
    if #names <= 1 then
        return false, "You must keep at least one profile."
    end
    local root = EnsureRoot()
    if type(root.profiles[name]) ~= "table" then
        return false, "That profile does not exist."
    end
    local char = EnsureChar()
    if char.activeProfile == name then
        local fallback = (name ~= "Default" and root.profiles.Default) and "Default" or nil
        if not fallback then
            for i = 1, #names do
                if names[i] ~= name then
                    fallback = names[i]
                    break
                end
            end
        end
        char.activeProfile = fallback or "Default"
    end
    root.profiles[name] = nil
    return true
end

function DB.ExportProfile(name)
    name = name or DB.GetActiveName()
    if not DB.ProfileExists(name) then
        return nil
    end
    local data = DeepCopy(EnsureRoot().profiles[name])
    return "AQ1:" .. string.len(name) .. ":" .. name .. Serialize(data)
end

function DB.ImportProfile(raw)
    if type(raw) ~= "string" then
        return false, "Paste an AllQuest profile string."
    end
    raw = raw:gsub("^%s+", ""):gsub("%s+$", "")
    if string.sub(raw, 1, 4) ~= "AQ1:" then
        return false, "That is not an AllQuest profile string."
    end
    if string.len(raw) > 120000 then
        return false, "That profile string is too large."
    end
    local rest = string.sub(raw, 5)
    local colon = string.find(rest, ":", 1, true)
    if not colon then
        return false, "That profile string is damaged."
    end
    local nlen = tonumber(string.sub(rest, 1, colon - 1))
    if not nlen or nlen < 1 then
        return false, "That profile string is damaged."
    end
    local name = SanitizeName(string.sub(rest, colon + 1, colon + nlen)) or "Imported"
    local payload = string.sub(rest, colon + 1 + nlen)
    local data = Deserialize(payload, 1)
    if type(data) ~= "table" then
        return false, "That profile string is damaged."
    end
    local root = EnsureRoot()
    local final = name
    local n = 2
    while root.profiles[final] do
        final = SanitizeName(name .. " " .. tostring(n)) or (name .. tostring(n))
        n = n + 1
        if n > 50 then
            return false, "Too many profiles with that name."
        end
    end
    root.profiles[final] = CopyDefaults(defaults, data)
    return true, final
end
