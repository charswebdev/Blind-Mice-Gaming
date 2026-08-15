--[[
  AllQuest — optional BtWQuests plugin
  Opens BtW chain view and reads public coordinates. Does not copy BtW data.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.BtWQuests = AQ.BtWQuests or {}
local BtW = AQ.BtWQuests

local function PluginOn()
    return AQ.Plugins and AQ.Plugins.IsEnabled("BtWQuests") and true or false
end

local function Loaded()
    return AQ:AddonLoaded("BtWQuests")
end

local function PlayerCharacter()
    if not (BtWQuestsCharacters and BtWQuestsCharacters.GetPlayer) then
        return nil
    end
    local ok, character = pcall(BtWQuestsCharacters.GetPlayer, BtWQuestsCharacters)
    if ok then
        return character
    end
    return nil
end

local function ChainItemForQuest(questID)
    if type(questID) ~= "number" or not BtWQuestsDatabase or not BtWQuestsDatabase.GetQuestItem then
        return nil
    end
    local ok, item = pcall(BtWQuestsDatabase.GetQuestItem, BtWQuestsDatabase, questID, PlayerCharacter())
    if ok and type(item) == "table" then
        return item.item or item
    end
    return nil
end

function BtW.HasChain(questID)
    if not PluginOn() or not Loaded() then
        return false
    end
    local item = ChainItemForQuest(questID)
    return type(item) == "table" and (item.type == "chain" or type(item.id) == "number")
end

function BtW.OpenChain(questID)
    if not PluginOn() then
        if AQ.Speech then
            AQ.Speech.Say("BtWQuests plugin is off")
        end
        return false
    end
    if not Loaded() or not BtWQuestsFrame then
        if AQ.Speech then
            AQ.Speech.Say("BtWQuests is not loaded")
        end
        return false
    end
    local item = ChainItemForQuest(questID)
    if type(item) ~= "table" then
        if AQ.Speech then
            AQ.Speech.Say("BtWQuests has no chain for this quest")
        end
        return false
    end
    if ShowUIPanel then
        pcall(ShowUIPanel, BtWQuestsFrame)
    else
        pcall(BtWQuestsFrame.Show, BtWQuestsFrame)
    end
    if BtWQuestsFrame.SelectCharacter and UnitName and GetRealmName then
        pcall(BtWQuestsFrame.SelectCharacter, BtWQuestsFrame, UnitName("player"), GetRealmName())
    end
    local ok = pcall(BtWQuestsFrame.SelectItem, BtWQuestsFrame, item)
    if ok then
        if AQ.Speech then
            AQ.Speech.Say("Opened BtWQuests chain")
        end
        return true
    end
    if AQ.Speech then
        AQ.Speech.Say("Could not open BtWQuests chain")
    end
    return false
end

local function NormalizeXY(x, y)
    x = tonumber(x)
    y = tonumber(y)
    if not x or not y then
        return nil
    end
    if x > 1 or y > 1 then
        x = x / 100
        y = y / 100
    end
    if x < 0 or y < 0 or x > 1 or y > 1 then
        return nil
    end
    return x, y
end

local function CoordsFromTable(obj)
    if type(obj) ~= "table" then
        return nil
    end
    local mapID = obj.uiMapID or obj.mapID
    local x, y = obj.x, obj.y
    if type(obj[1]) == "table" then
        mapID = mapID or obj[1].uiMapID or obj[1].mapID
        x = x or obj[1].x
        y = y or obj[1].y
    end
    x, y = NormalizeXY(x, y)
    if type(mapID) == "number" and x then
        return mapID, x, y
    end
    return nil
end

function BtW.ResolveLocation(questID)
    if not PluginOn() or not Loaded() or type(questID) ~= "number" then
        return nil
    end
    if not (BtWQuestsDatabase and BtWQuestsDatabase.GetQuestByID) then
        return nil
    end
    local ok, quest = pcall(BtWQuestsDatabase.GetQuestByID, BtWQuestsDatabase, questID)
    if not ok or type(quest) ~= "table" then
        return nil
    end
    if type(quest.GetSource) == "function" then
        local okSrc, source = pcall(quest.GetSource, quest, PlayerCharacter())
        if okSrc and type(source) == "table" and type(source.GetLocation) == "function" then
            local okLoc, mapID, coords = pcall(source.GetLocation, source)
            if okLoc and type(mapID) == "number" and type(coords) == "table" then
                local x, y = NormalizeXY(coords.x, coords.y)
                if x then
                    return mapID, x, y, "btwquests"
                end
            end
        end
    end
    local mapID, x, y = CoordsFromTable(quest.target)
    if mapID then
        return mapID, x, y, "btwquests"
    end
    mapID, x, y = CoordsFromTable(quest.targets)
    if mapID then
        return mapID, x, y, "btwquests"
    end
    if type(quest.objectives) == "table" then
        for i = 1, #quest.objectives do
            mapID, x, y = CoordsFromTable(quest.objectives[i])
            if mapID then
                return mapID, x, y, "btwquests"
            end
        end
    end
    return nil
end

AQ:RegisterPlugin({
    id = "BtWQuests",
    kind = "integration",
    label = "BtWQuests",
    optionalAddon = "BtWQuests",
    onEnable = function()
        AQ:Print("BtWQuests: right-click a tracker quest to open its chain. Journal waypoints can use BtW coordinates when Blizzard has none.")
    end,
})

SLASH_AQBTW1 = "/aqbtw"
SlashCmdList["AQBTW"] = function()
    local id = AQ.Compat and AQ.Compat.GetSuperTrackedQuestID and AQ.Compat.GetSuperTrackedQuestID()
    if not id then
        AQ:Print("No super-tracked quest.")
        return
    end
    BtW.OpenChain(id)
end
