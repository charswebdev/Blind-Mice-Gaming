local _, G = ...

local CVARS = {
    { "softTargetInteract", "3" },
    { "SoftTargetIconGameObject", "1" },
    { "SoftTargetInteractArc", "2" },
    { "SoftTargetInteractRange", "30" },
}

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
local lastIdentity, lastStep
local missingSince
local probe
local watch

local function GetC(name)
    if not C_CVar or not C_CVar.GetCVar then
        return nil
    end
    local ok, value = pcall(C_CVar.GetCVar, name)
    if not ok then
        return nil
    end
    return G.PlainString(value)
end

local function SetC(name, value)
    if C_CVar and C_CVar.SetCVar and not InCombatLockdown() then
        pcall(C_CVar.SetCVar, name, value)
    end
end

local function SameC(a, b)
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
        if current and not SameC(current, wanted) then
            if G.db.cvarSaved[name] == nil then
                G.db.cvarSaved[name] = current
            end
            SetC(name, wanted)
        end
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

local function ReadQuests()
    questWords = {}
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then
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
                    end
                end
            end
        end
    end
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
    text = text:lower()
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

local function IconText(texture)
    if not probe then
        probe = UIParent:CreateTexture(nil, "OVERLAY")
        probe:Hide()
    end
    local shown = texture and texture.IsShown and texture:IsShown()
    local atlas, path
    if shown then
        atlas = G.PlainString(texture:GetAtlas())
        local image = texture:GetTexture()
        path = G.PlainString(image) or (G.PlainNumber(image) and tostring(G.PlainNumber(image)))
    end
    if (not atlas and not path) and SetUnitCursorTexture then
        local unit = texture and texture.unit
        if unit and SetUnitCursorTexture(probe, unit, nil, true, true) then
            atlas = G.PlainString(probe:GetAtlas())
            local image = probe:GetTexture()
            path = G.PlainString(image) or (G.PlainNumber(image) and tostring(G.PlainNumber(image)))
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
    if icon then
        icon.unit = unit
    end
    local iconKind = KindFromIcon(IconText(icon))
    local named = NameKind(name)
    if named == "bobber" or ObjectID(unit) == 35591 or (object and Fishing() and iconKind == nil) then
        return "bobber", name
    end
    if object then
        if named == "herbs" or named == "ore" or named == "treasure" then
            return named, name
        end
        if iconKind == "quests" or HasWord(name) then
            return "quests", name
        end
        if iconKind == "herbs" or iconKind == "ore" or iconKind == "loot" then
            if iconKind == "loot" and named == nil then
                return "treasure", name
            end
            return iconKind == "loot" and "treasure" or iconKind, name
        end
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

local function Yards(unit)
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

local function Announce(unit, kind, name, forceAt)
    local step = forceAt and "at" or Band(Yards(unit))
    local identity = IdentityOf(unit, name, kind)
    missingSince = nil
    if identity == lastIdentity and step == lastStep then
        return
    end
    lastIdentity = identity
    lastStep = step
    G.SpeakTarget(kind, name, step)
end

function G.MarkArrived(targetName)
    local name = G.PlainString(targetName)
    if not name or not G.liveKind then
        return
    end
    if G.liveName and G.liveName == name then
        lastStep = nil
        Announce(G.liveUnit or "softinteract", G.liveKind, G.liveName, true)
    end
end

local function ClearLive()
    G.liveKind, G.liveName, G.liveUnit = nil, nil, nil
    G.HideSpark(G.worldHost)
    if not missingSince then
        missingSince = GetTime()
    elseif GetTime() - missingSince > 1 then
        lastIdentity, lastStep = nil, nil
    end
end

function G.Refresh()
    if not G.db then
        return
    end
    if G.Paused() or not G.AnySparkleOn() then
        ClearLive()
        return
    end
    if not G.IsTrue(UnitExists, "softinteract") then
        ClearLive()
        return
    end
    local plate = PlateFor("softinteract")
    if not plate and C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for _, candidate in ipairs(plates) do
                local frame = candidate and candidate.UnitFrame
                local unit = frame and frame.unit
                if unit and G.IsTrue(UnitIsUnit, unit, "softinteract") then
                    plate = candidate
                    break
                end
            end
        end
    end
    local unit = "softinteract"
    local kind, name = Classify(unit, IconFor(plate))
    if not kind or not G.db.enabled[kind] or not G.NodeAllowed(kind, name) then
        ClearLive()
        return
    end
    G.liveKind, G.liveName, G.liveUnit = kind, name, unit
    if plate then
        local host = G.WorldHost()
        local look = G.db.look[kind]
        G.ApplySpark(host, look, plate, "CENTER", "BOTTOM", 0, look.height or -24)
    end
    Announce(unit, kind, name, false)
end

local function ArmWatch()
    if not watch then
        watch = CreateFrame("Frame")
        watch.left = 0
        watch:SetScript("OnUpdate", function(self, elapsed)
            self.left = self.left - elapsed
            if self.left <= 0 then
                self.left = 0.25
                G.Refresh()
                self.ticks = (self.ticks or 0) + 1
                if self.ticks >= 8 then
                    self:Hide()
                end
            end
        end)
    end
    watch.ticks = 0
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
    events:SetScript("OnEvent", function(_, event, arg1, arg2)
        if event == "QUEST_LOG_UPDATE" then
            questWords = nil
            return
        end
        if event == "UNIT_SPELLCAST_SENT" and arg1 == "player" then
            G.MarkArrived(arg2)
            return
        end
        if event == "PLAYER_REGEN_ENABLED" and G.interactPending then
            G.ApplyInteract()
        end
        G.Refresh()
        if event == "PLAYER_SOFT_INTERACT_CHANGED" or event == "NAME_PLATE_UNIT_ADDED" then
            ArmWatch()
        end
    end)
    G.ApplyInteract()
    G.Refresh()
end
