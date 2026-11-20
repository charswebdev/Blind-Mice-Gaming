local _, G = ...

local CVARS = {
    { "softTargetInteract", "3" },
    { "SoftTargetIconGameObject", "1" },
    { "SoftTargetInteractArc", "2" },
    { "SoftTargetInteractRange", "30" },
}
local CORPSE_PLATE = "SoftTargetNameplateInteract"

local HERB_END = {
    "silverleaf", "peacebloom", "earthroot", "mageroyal", "briarthorn", "swiftthistle", "bruiseweed",
    "stranglekelp", "liferoot", "kingsblood", "goldthorn", "firebloom", "sungrass", "dreamfoil",
    "icecap", "plaguebloom", "hochenblume", "saxifrage", "writhebark", "mycobloom", "luredrop",
    "orbinid", "blessing blossom", "arathor's spear",
    "tranquility bloom", "argentleaf", "azeroot", "mana lily", "sanguithorn", "nocturnal lotus",
}
local ORE_END = { "vein", "deposit", "seam" }
local CHEST_END = { "chest", "coffer", "footlocker", "strongbox", "lockbox" }

local questWords
local questLabels
local questSig
local FlightUnit
local lastIdentity, lastStep
local missingSince
local probe
local watch

local function GetC(name)
    if not C_CVar or not C_CVar.GetCVar then
        return nil
    end
    local ok, value = pcall(C_CVar.GetCVar, name)
    if not ok or G.Secret(value) then
        return nil
    end
    if type(value) == "number" then
        return tostring(value)
    end
    return G.PlainString(value)
end

local function SetC(name, value)
    if C_CVar and C_CVar.SetCVar and not InCombatLockdown() then
        pcall(C_CVar.SetCVar, name, value)
    end
end

local function SameC(a, b)
    if a == nil or b == nil then
        return false
    end
    if a == b then
        return true
    end
    local na, nb = tonumber(a), tonumber(b)
    return na ~= nil and na == nb
end

function G.ApplyInteract()
    if InCombatLockdown() then
        G.interactPending = true
        return
    end
    G.interactPending = nil
    if not G.AnySparkleOn() then
        for name, old in pairs(G.db.cvarSaved) do
            if GetC(name) ~= nil then
                SetC(name, old)
            end
            G.db.cvarSaved[name] = nil
        end
        return
    end
    for _, entry in ipairs(CVARS) do
        local name, wanted = entry[1], entry[2]
        local current = GetC(name)
        if not SameC(current, wanted) then
            if current and G.db.cvarSaved[name] == nil then
                G.db.cvarSaved[name] = current
            end
            SetC(name, wanted)
        end
    end
end

local function CorpseUnit(unit)
    if G.IsTrue(UnitIsPlayer, unit) or G.IsTrue(UnitIsGameObject, unit) then
        return false
    end
    return G.IsTrue(UnitIsDead, unit)
end

function G.ApplyCorpsePlate()
    if not G.db or InCombatLockdown() then
        if InCombatLockdown() then
            G.interactPending = true
        end
        return
    end
    local want = ((G.db.enabled.skinning or G.db.enabled.loot) and CorpseUnit("softinteract"))
        or (G.db.enabled.flight and FlightUnit and FlightUnit("softinteract"))
    if want then
        local current = GetC(CORPSE_PLATE)
        if not SameC(current, "1") then
            if current and G.db.cvarSaved[CORPSE_PLATE] == nil then
                G.db.cvarSaved[CORPSE_PLATE] = current
            end
            SetC(CORPSE_PLATE, "1")
        end
    elseif G.db.cvarSaved[CORPSE_PLATE] ~= nil then
        SetC(CORPSE_PLATE, G.db.cvarSaved[CORPSE_PLATE])
        G.db.cvarSaved[CORPSE_PLATE] = nil
    end
end

function G.RestoreInteract()
    if InCombatLockdown() then
        return
    end
    for name, old in pairs(G.db.cvarSaved) do
        SetC(name, old)
        G.db.cvarSaved[name] = nil
    end
end

local QUEST_STOP = {
    slain = true, killed = true, collect = true, speak = true, talk = true,
    click = true, ["use"] = true, find = true, ["return"] = true, bring = true,
    complete = true, from = true, with = true, your = true, that = true,
    this = true, have = true, been = true, into = true, onto = true,
    over = true, ["then"] = true, them = true, they = true, kill = true,
    loot = true, item = true, quest = true, near = true, west = true,
    east = true, north = true, south = true, inside = true, outside = true,
    around = true, the = true, ["and"] = true,
}

local function QuestLabel(text)
    local label = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    label = label:gsub("%d+%s*/%s*%d+", "")
    label = label:gsub("^%s*%d+%s*", "")
    label = label:gsub(":%s*$", "")
    label = label:gsub("%s+", " ")
    label = label:gsub("^%s+", ""):gsub("%s+$", "")
    if #label > 48 then
        label = label:sub(1, 45)
        label = label:gsub("%s+%S*$", "")
    end
    if label == "" then
        return nil
    end
    return label
end

local function QuestItemWords(label)
    local words = { label:lower() }
    for word in label:lower():gmatch("%a%a%a%a+") do
        if not QUEST_STOP[word] then
            words[#words + 1] = word
        end
    end
    return words
end

local function PublishQuestTrack()
    local items = {}
    local keys = {}
    local names = {}
    for key, label in pairs(questLabels or {}) do
        keys[key] = true
        items[#items + 1] = { name = label, key = key, words = QuestItemWords(label) }
        names[#names + 1] = key
    end
    table.sort(items, function(a, b)
        return a.name < b.name
    end)
    table.sort(names)
    local sig = table.concat(names, ",")
    G.TRACK.quests = items
    G.TRACK_KEY.quests = keys
    if sig == questSig then
        return
    end
    questSig = sig
    if G.RelayoutTrack then
        G.RelayoutTrack("quests")
    end
end

local function ReadQuests()
    questWords = {}
    questLabels = {}
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then
        PublishQuestTrack()
        return
    end
    local count = C_QuestLog.GetNumQuestLogEntries()
    count = G.PlainNumber(count) or 0
    for index = 1, count do
        local info = C_QuestLog.GetInfo(index)
        if type(info) == "table" and info.isHeader ~= true and info.questID then
            local objectives = C_QuestLog.GetQuestObjectives(info.questID)
            if type(objectives) == "table" then
                for _, objective in ipairs(objectives) do
                    local text = type(objective) == "table" and G.PlainString(objective.text)
                    if text and objective.finished ~= true then
                        for word in text:lower():gmatch("%a%a%a+") do
                            questWords[word] = true
                        end
                        local label = QuestLabel(text)
                        local key = label and G.SoundKey(label)
                        if key and not questLabels[key] then
                            questLabels[key] = label
                        end
                    end
                end
            end
        end
    end
    PublishQuestTrack()
end

local function HasWord(name)
    if not questWords then
        ReadQuests()
    end
    local text = G.PlainString(name)
    if not text then
        return false
    end
    for word in text:lower():gmatch("%a%a%a+") do
        if questWords[word] then
            return true
        end
    end
    return false
end

local function EndsWith(text, ending)
    return text:sub(-#ending) == ending
end

local function NameKind(name)
    local text = G.PlainString(name)
    if not text then
        return nil
    end
    text = text:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if text:find("bobber", 1, true) then
        return "bobber"
    end
    for _, ending in ipairs(CHEST_END) do
        if EndsWith(text, ending) then
            return "treasure"
        end
    end
    for _, ending in ipairs(ORE_END) do
        if EndsWith(text, ending) then
            return "ore"
        end
    end
    for _, ending in ipairs(HERB_END) do
        if EndsWith(text, ending) then
            return "herbs"
        end
    end
    return nil
end

local function TextureWords(texture)
    if not texture or not texture.GetAtlas then
        return nil, nil
    end
    local atlas = G.PlainString(texture:GetAtlas())
    local image = texture:GetTexture()
    local path = G.PlainString(image)
    if not path then
        local id = G.PlainNumber(image)
        if id then
            path = tostring(id)
        end
    end
    return atlas, path
end

local function IconText(texture, unit)
    if not probe then
        probe = UIParent:CreateTexture(nil, "OVERLAY")
        probe:Hide()
    end
    local atlas, path
    local shown = texture and texture.IsShown and texture:IsShown()
    if shown then
        atlas, path = TextureWords(texture)
    end
    if (not atlas and not path) and unit and SetUnitCursorTexture then
        local ok, hit = pcall(SetUnitCursorTexture, probe, unit, nil, true, true)
        local accepted = false
        if ok then
            if G.Secret(hit) then
                if hit then
                    accepted = true
                end
            elseif hit == true or hit == 1 then
                accepted = true
            end
        end
        if accepted then
            atlas, path = TextureWords(probe)
        end
    end
    return ((atlas or "") .. " " .. (path or "")):lower()
end

local function KindFromIcon(text)
    if text:find("herb", 1, true) then
        return "herbs"
    end
    if text:find("mine", 1, true) or text:find("mining", 1, true) then
        return "ore"
    end
    if text:find("skin", 1, true) then
        return "skinning"
    end
    if text:find("loot", 1, true) then
        return "loot"
    end
    if text:find("quest", 1, true) then
        return "quests"
    end
    return nil
end

local function ObjectID(unit)
    if not UnitGUID then
        return nil
    end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok then
        return nil
    end
    guid = G.PlainString(guid)
    if not guid then
        return nil
    end
    return tonumber(guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
end

local function Fishing()
    if not UnitChannelInfo then
        return false
    end
    local ok, _, _, texture = pcall(UnitChannelInfo, "player")
    if not ok then
        return false
    end
    return G.PlainNumber(texture) == 136245
end

local function IsFlight(name, iconText)
    if G.ListedKey and G.ListedKey("flight", name) then
        return true
    end
    local text = G.PlainString(iconText)
    if not text then
        return false
    end
    text = text:lower()
    if text:find("taxi", 1, true) or text:find("flightmaster", 1, true) or text:find("flight_master", 1, true) then
        return true
    end
    return false
end

FlightUnit = function(unit)
    if G.IsTrue(UnitIsPlayer, unit) or G.IsTrue(UnitIsDead, unit) or G.IsTrue(UnitIsGameObject, unit) then
        return false
    end
    local name
    if UnitName then
        local ok, value = pcall(UnitName, unit)
        if ok then
            name = G.PlainString(value)
        end
    end
    return IsFlight(name, IconText(nil, unit))
end

local function Classify(unit, icon)
    local object = G.IsTrue(UnitIsGameObject, unit)
    local dead = G.IsTrue(UnitIsDead, unit)
    local player = G.IsTrue(UnitIsPlayer, unit)
    local name
    if UnitName then
        local ok, value = pcall(UnitName, unit)
        if ok then
            name = G.PlainString(value)
        end
    end
    local iconText = IconText(icon, unit)
    local iconKind = KindFromIcon(iconText)
    local named = NameKind(name)
    if not object and not dead and not player and IsFlight(name, iconText) then
        return "flight", name
    end
    if named == "bobber" or ObjectID(unit) == 35591 or (object and Fishing() and iconKind == nil) then
        return "bobber", name
    end
    if named == "herbs" or named == "ore" or named == "treasure" then
        return named, name
    end
    if iconKind == "herbs" or iconKind == "ore" then
        return iconKind, name
    end
    if iconKind == "quests" or (object and HasWord(name)) then
        return "quests", name
    end
    if iconKind == "loot" and (object or named == nil) then
        if object or not dead then
            return "treasure", name
        end
    end
    if object then
        if iconKind == nil then
            return "others", name
        end
        return iconKind, name
    end
    if dead and not player then
        if iconKind == "skinning" then
            return "skinning", name
        end
        if iconKind == "loot" then
            return "loot", name
        end
    end
    return nil, name
end

local function FromSquared(unit)
    if not UnitDistanceSquared then
        return nil
    end
    local ok, squared = pcall(UnitDistanceSquared, unit)
    if not ok then
        return nil
    end
    local n = G.PlainNumber(squared)
    if not n or n <= 0 then
        return nil
    end
    local dist = math.sqrt(n)
    if dist < 80 then
        return dist
    end
    return nil
end

local function FromPositions(unit)
    if not UnitPosition then
        return nil
    end
    local ok1, y1, x1 = pcall(UnitPosition, "player")
    local ok2, y2, x2 = pcall(UnitPosition, unit)
    if not ok1 or not ok2 then
        return nil
    end
    x1, y1 = G.PlainNumber(x1), G.PlainNumber(y1)
    x2, y2 = G.PlainNumber(x2), G.PlainNumber(y2)
    if not x1 or not y1 or not x2 or not y2 then
        return nil
    end
    local dist = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    if dist > 0 and dist < 80 then
        return dist
    end
    return nil
end

local function Yards(unit)
    local dist = FromSquared(unit) or FromPositions(unit)
    if dist then
        return dist
    end
    if unit ~= "softinteract" then
        return FromSquared("softinteract") or FromPositions("softinteract")
    end
    return nil
end

local function Band(dist)
    if not dist then
        return "near"
    end
    if dist >= 17.5 then
        return "20"
    end
    if dist >= 12.5 then
        return "15"
    end
    if dist >= 7.5 then
        return "10"
    end
    if dist >= 3 then
        return "5"
    end
    return "at"
end

local SQUARED_STEPS = {
    { 306.25, "20" },
    { 156.25, "15" },
    { 56.25, "10" },
    { 9, "5" },
}

local function SecretYes(value)
    if G.Secret(value) then
        if value then
            return true
        end
        return false
    end
    return value == true
end

local function StepFromSquared(raw)
    local n = G.PlainNumber(raw)
    if n and n > 0 then
        local dist = math.sqrt(n)
        if dist > 0 and dist < 80 then
            return Band(dist)
        end
        return nil
    end
    if not G.Secret(raw) then
        return nil
    end
    local okZero, aboveZero = pcall(function()
        return raw > 0
    end)
    if not okZero or not SecretYes(aboveZero) then
        return nil
    end
    for i = 1, #SQUARED_STEPS do
        local limit, step = SQUARED_STEPS[i][1], SQUARED_STEPS[i][2]
        local ok, result = pcall(function()
            return raw >= limit
        end)
        if not ok then
            return nil
        end
        if SecretYes(result) then
            return step
        end
    end
    return "at"
end

local function InteractRange(unit, index)
    if not CheckInteractDistance or not unit then
        return nil
    end
    local ok, value = pcall(CheckInteractDistance, unit, index)
    if not ok then
        return nil
    end
    if G.Secret(value) then
        if value then
            return true
        end
        return false
    end
    if value == nil then
        return nil
    end
    return value == true or value == 1
end

local function Bracket(unit)
    local close = InteractRange(unit, 2)
    if close == nil and unit ~= "softinteract" then
        close = InteractRange("softinteract", 2)
    end
    if close == nil then
        return nil
    end
    if close then
        return "10"
    end
    return "20"
end

local function StepFromUnit(unit)
    if UnitDistanceSquared then
        local ok, squared = pcall(UnitDistanceSquared, unit)
        if ok and (G.Secret(squared) or G.PlainNumber(squared)) then
            local step = StepFromSquared(squared)
            if step then
                return step
            end
        end
    end
    local yards = FromPositions(unit)
    if yards then
        return Band(yards)
    end
    return nil
end

local function SpokenStep(unit, forceAt)
    if forceAt then
        return "at"
    end
    local step = StepFromUnit(unit)
    if not step and unit ~= "softinteract" then
        step = StepFromUnit("softinteract")
    end
    if step then
        return step
    end
    return Bracket(unit) or "near"
end

local function PlateFor(unit)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then
        return nil
    end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok then
        return plate
    end
    return nil
end

local function IconFor(plate)
    local frame = plate and plate.UnitFrame
    local soft = frame and frame.SoftTargetFrame
    return soft and soft.Icon
end

local function IdentityOf(unit, name, kind)
    local guid
    if UnitGUID then
        local ok, value = pcall(UnitGUID, unit)
        if ok then
            guid = G.PlainString(value)
        end
    end
    return guid or ((name or kind or "object") .. ":" .. kind)
end

local function Announce(unit, kind, name, forceAt, label)
    local step = SpokenStep(unit, forceAt)
    local identity = IdentityOf(unit, name, kind)
    missingSince = nil
    if identity == lastIdentity and step == lastStep then
        return
    end
    lastIdentity = identity
    lastStep = step
    if kind == "loot" then
        label = "Corpse"
    end
    G.SpeakTarget(kind, name, step, label)
end

function G.MarkArrived(targetName)
    local name = G.PlainString(targetName)
    if not name or not G.liveKind then
        return
    end
    if G.liveName and G.liveName == name then
        lastStep = nil
        Announce(G.liveUnit or "softinteract", G.liveKind, G.liveName, true, G.liveLabel)
    end
end

local function ClearLive()
    G.liveKind, G.liveName, G.liveUnit, G.liveLabel = nil, nil, nil, nil
    G.HideSpark(G.worldHost)
    if not missingSince then
        missingSince = GetTime()
    elseif GetTime() - missingSince > 1 then
        lastIdentity, lastStep = nil, nil
    end
end

local function NameplateUnit(unit)
    if G.Secret(unit) or type(unit) ~= "string" then
        return false
    end
    return unit:find("^nameplate%d+$") ~= nil
end

local function SameUnit(a, b)
    if G.Secret(a) or G.Secret(b) then
        return false
    end
    return a == b
end

local function TapDenied(unit)
    return G.IsTrue(UnitIsTapDenied, unit)
end

local function PlayerCanLoot(unit)
    if TapDenied(unit) then
        return false
    end
    if CanLootUnit and G.IsTrue(CanLootUnit, unit) then
        return true
    end
    if unit ~= "softinteract" and CanLootUnit and G.IsTrue(CanLootUnit, "softinteract") then
        return true
    end
    return false
end

local function UpdateUnit(unit, plate)
    if not NameplateUnit(unit) then
        return false
    end
    if not G.db or G.Paused() or not G.AnySparkleOn() then
        return false
    end
    if not plate then
        plate = PlateFor(unit)
    end
    if not plate then
        return false
    end
    local object = G.IsTrue(UnitIsGameObject, unit)
    local corpse = (not object) and G.IsTrue(UnitIsDead, unit) and not G.IsTrue(UnitIsPlayer, unit)
    local icon
    local okIcon, iconValue = pcall(IconFor, plate)
    if okIcon then
        icon = iconValue
    end
    local kind, name = Classify(unit, icon)
    if corpse then
        local denied = TapDenied(unit)
        local mine = PlayerCanLoot(unit)
        if denied and kind == "loot" then
            kind = nil
        elseif kind == "skinning" and not G.db.enabled.skinning and G.db.enabled.loot and not denied then
            kind = "loot"
        elseif kind == "loot" and not G.db.enabled.loot and G.db.enabled.skinning then
            kind = "skinning"
        elseif not denied and G.db.enabled.loot and kind ~= "skinning" and (kind == "loot" or mine) then
            kind = "loot"
        end
    end
    local allowedName = name
    if kind == "others" then
        local group = G.OtherGroup(name, IconText(icon, unit))
        if group then
            allowedName = group
        else
            kind = nil
        end
    end
    if object and (not kind or kind == "others") and not G.db.enabled.others then
        if G.db.enabled.herbs then
            kind = "herbs"
        elseif G.db.enabled.ore then
            kind = "ore"
        elseif G.db.enabled.treasure then
            kind = "treasure"
        end
    end
    if not object and not corpse and kind ~= "herbs" and kind ~= "ore" and kind ~= "treasure" and kind ~= "quests" and kind ~= "bobber" and kind ~= "flight" then
        return false
    end
    local pageName = {
        bobber = "Fishing bobber",
        loot = "Corpse",
        skinning = "Skin",
        flight = "Flight path",
    }
    if kind and pageName[kind] then
        allowedName = pageName[kind]
    end
    if not kind or not G.db.enabled[kind] or not G.NodeAllowed(kind, allowedName) then
        if SameUnit(G.liveUnit, unit) then
            ClearLive()
        end
        return false
    end
    local label = allowedName
    if G.TrackLabel then
        label = G.TrackLabel(kind, name) or G.TrackLabel(kind, allowedName) or allowedName
    end
    G.liveKind, G.liveName, G.liveUnit, G.liveLabel = kind, name, unit, label
    Announce(unit, kind, name, false, label)
    local look = G.db.look[kind]
    G.PlaceOnPlate(G.WorldHost(), look, plate, look.height or -24)
    return true
end

local function UpdateAll()
    if not G.db or G.Paused() or not G.AnySparkleOn() then
        ClearLive()
        return
    end
    local shown = false
    local readable = 0
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for _, candidate in ipairs(plates) do
                local okUnit, unit = pcall(function()
                    local frame = candidate and candidate.UnitFrame
                    return frame and frame.unit
                end)
                if okUnit and NameplateUnit(unit) then
                    readable = readable + 1
                    if UpdateUnit(unit, candidate) then
                        shown = true
                    end
                end
            end
        end
    end
    if readable > 0 and not shown then
        ClearLive()
    end
end

function G.Refresh()
    if G.ApplyCorpsePlate then
        G.ApplyCorpsePlate()
    end
    UpdateAll()
end

local function ArmWatch()
    if not watch then
        watch = CreateFrame("Frame")
        watch.left = 0
        watch:SetScript("OnUpdate", function(self, elapsed)
            self.left = self.left - elapsed
            if self.left > 0 then
                return
            end
            self.left = 0.25
            if G.db and G.AnySparkleOn() and not G.Paused() then
                G.Refresh()
            end
        end)
    end
    watch.left = 0
    watch:Show()
end

function G.StartDetect()
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
    events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("QUEST_LOG_UPDATE")
    events:RegisterEvent("UNIT_SPELLCAST_SENT")
    events:RegisterEvent("LOOT_OPENED")
    events:SetScript("OnEvent", function(_, event, arg1, arg2)
        if event == "QUEST_LOG_UPDATE" then
            ReadQuests()
            return
        end
        if event == "LOOT_OPENED" and G.liveKind and lastStep ~= "at" then
            Announce(G.liveUnit or "softinteract", G.liveKind, G.liveName, true, G.liveLabel)
            return
        end
        if event == "UNIT_SPELLCAST_SENT" and arg1 == "player" then
            G.MarkArrived(arg2)
            return
        end
        if event == "PLAYER_REGEN_ENABLED" and G.interactPending then
            G.ApplyInteract()
        end
        if event == "NAME_PLATE_UNIT_ADDED" then
            UpdateUnit(arg1)
            return
        end
        if event == "NAME_PLATE_UNIT_REMOVED" and SameUnit(arg1, G.liveUnit) then
            ClearLive()
            return
        end
        G.Refresh()
    end)
    if hooksecurefunc and NamePlateDriverFrame then
        pcall(hooksecurefunc, NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit)
            UpdateUnit(unit)
        end)
        pcall(hooksecurefunc, NamePlateDriverFrame, "OnSoftTargetUpdate", function()
            UpdateAll()
        end)
    end
    ArmWatch()
    G.ApplyInteract()
    ReadQuests()
    G.Refresh()
end
