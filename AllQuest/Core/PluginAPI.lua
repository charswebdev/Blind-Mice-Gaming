--[[
  AllQuest — plugin + questline data API
  Feature plugins (tracker / journal / integration) and LoadOnDemand data packs.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Plugins = AQ.Plugins or {}
local Plugins = AQ.Plugins

local plugins = {}
local pluginOrder = {}

function AQ:RegisterPlugin(spec)
    if type(spec) ~= "table" or type(spec.id) ~= "string" or spec.id == "" then
        return false
    end
    if plugins[spec.id] then
        return false
    end
    spec.kind = spec.kind or "integration"
    plugins[spec.id] = spec
    pluginOrder[#pluginOrder + 1] = spec.id
    return true
end

function Plugins.Get(id)
    return plugins[id]
end

function Plugins.CanLoad(spec)
    if type(spec) ~= "table" then
        return false
    end
    if type(spec.optionalAddon) == "string" and spec.optionalAddon ~= "" then
        return AQ:AddonLoaded(spec.optionalAddon)
    end
    return true
end

function Plugins.IsEnabled(id)
    local db = AQ.DB and AQ.DB.Get and AQ.DB.Get() or {}
    if db.plugins and db.plugins[id] == false then
        return false
    end
    local spec = plugins[id]
    if spec and not Plugins.CanLoad(spec) then
        return false
    end
    return true
end

function Plugins.SetEnabled(id, on)
    local db = AQ.DB.Get()
    db.plugins = db.plugins or {}
    db.plugins[id] = on and true or false
    local spec = plugins[id]
    if spec then
        local was = spec.enabled and true or false
        spec.enabled = on and Plugins.CanLoad(spec) and true or false
        if spec.enabled and not was and type(spec.onEnable) == "function" then
            pcall(spec.onEnable, AQ)
        elseif (not spec.enabled) and was and type(spec.onDisable) == "function" then
            pcall(spec.onDisable, AQ)
        end
    end
    if AQ.Tracker and AQ.Tracker.Refresh then
        AQ.Tracker.Refresh()
    end
end

function Plugins.OnExternalAddonLoaded(name)
    if type(name) ~= "string" then
        return
    end
    for i = 1, #pluginOrder do
        local spec = plugins[pluginOrder[i]]
        if spec and spec.optionalAddon == name then
            if Plugins.IsEnabled(spec.id) and not spec.enabled then
                spec.enabled = true
                if type(spec.onEnable) == "function" then
                    pcall(spec.onEnable, AQ)
                end
                if AQ.Tracker and AQ.Tracker.Refresh then
                    AQ.Tracker.Refresh()
                end
            end
        end
    end
end

function Plugins.List()
    local out = {}
    for i = 1, #pluginOrder do
        out[i] = plugins[pluginOrder[i]]
    end
    return out
end

function Plugins.EnableAll()
    for i = 1, #pluginOrder do
        local spec = plugins[pluginOrder[i]]
        if spec then
            local should = Plugins.IsEnabled(spec.id) and true or false
            if should and not spec.enabled then
                spec.enabled = true
                if type(spec.onEnable) == "function" then
                    pcall(spec.onEnable, AQ)
                end
            else
                spec.enabled = should
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Data: expansions / categories / chains
-- ---------------------------------------------------------------------------

AQ.Data = AQ.Data or {}
local Data = AQ.Data

local expansions = {}
local expansionOrder = {}
local categories = {}
local chains = {}
local questIndex = {} -- questID -> { chainID, nodeIndex }

local function IndexChain(chain)
    if type(chain) ~= "table" or type(chain.nodes) ~= "table" then
        return
    end
    for i = 1, #chain.nodes do
        local node = chain.nodes[i]
        if type(node) == "table" and node.type == "quest" and type(node.questID) == "number" then
            local list = questIndex[node.questID]
            if not list then
                list = {}
                questIndex[node.questID] = list
            end
            list[#list + 1] = { chainID = chain.id, nodeIndex = i }
        end
    end
end

function Data:AddExpansion(item)
    if type(item) ~= "table" or type(item.id) ~= "number" then
        return nil
    end
    if not expansions[item.id] then
        expansionOrder[#expansionOrder + 1] = item.id
        item.categories = item.categories or {}
        expansions[item.id] = item
    else
        local existing = expansions[item.id]
        if item.name and not existing.name then
            existing.name = item.name
        end
    end
    if AQ.Events then
        AQ.Events.Fire("AQ_DATA_CHANGED")
    end
    return expansions[item.id]
end

function Data:AddCategory(item)
    if type(item) ~= "table" or type(item.id) ~= "number" then
        return nil
    end
    item.chains = item.chains or {}
    categories[item.id] = item
    if type(item.expansion) == "number" then
        local exp = expansions[item.expansion]
        if not exp then
            exp = Data:AddExpansion({ id = item.expansion, name = "Expansion " .. tostring(item.expansion) })
        end
        local found = false
        for i = 1, #exp.categories do
            if exp.categories[i] == item.id then
                found = true
                break
            end
        end
        if not found then
            exp.categories[#exp.categories + 1] = item.id
        end
    end
    if AQ.Events then
        AQ.Events.Fire("AQ_DATA_CHANGED")
    end
    return item
end

local function UnindexChain(chainID)
    for qid, list in pairs(questIndex) do
        local n = 1
        while n <= #list do
            if list[n].chainID == chainID then
                table.remove(list, n)
            else
                n = n + 1
            end
        end
        if #list == 0 then
            questIndex[qid] = nil
        end
    end
end

local function RemoveChainFromCategory(chainID, categoryID)
    local cat = categories[categoryID]
    if not cat or type(cat.chains) ~= "table" then
        return
    end
    local n = 1
    while n <= #cat.chains do
        if cat.chains[n] == chainID then
            table.remove(cat.chains, n)
        else
            n = n + 1
        end
    end
end

function Data:AddChain(item)
    if type(item) ~= "table" or type(item.id) ~= "number" then
        return nil
    end
    local previous = chains[item.id]
    if previous then
        UnindexChain(item.id)
        RemoveChainFromCategory(item.id, previous.category)
    end
    item.nodes = item.nodes or {}
    item.prerequisites = item.prerequisites or {}
    item.restrictions = item.restrictions or {}
    chains[item.id] = item
    IndexChain(item)
    if type(item.category) == "number" then
        local cat = categories[item.category]
        if not cat then
            cat = Data:AddCategory({
                id = item.category,
                name = "Category " .. tostring(item.category),
                expansion = item.expansion,
            })
        end
        local found = false
        for i = 1, #cat.chains do
            if cat.chains[i] == item.id then
                found = true
                break
            end
        end
        if not found then
            cat.chains[#cat.chains + 1] = item.id
        end
    end
    if AQ.Events then
        AQ.Events.Fire("AQ_DATA_CHANGED")
    end
    return item
end

function Data:FindChainByName(expansionID, name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    for _, chain in pairs(chains) do
        if chain and chain.name == name and (expansionID == nil or chain.expansion == expansionID) then
            return chain
        end
    end
    return nil
end

function Data:GetExpansion(id)
    return expansions[id]
end

function Data:GetCategory(id)
    return categories[id]
end

function Data:GetChain(id)
    return chains[id]
end

function Data:GetExpansions()
    local out = {}
    for i = 1, #expansionOrder do
        out[#out + 1] = expansions[expansionOrder[i]]
    end
    table.sort(out, function(a, b)
        return (a.id or 0) < (b.id or 0)
    end)
    return out
end

--- Blizzard internal / test QuestLine names. Keep real titles like "Testing Loyalties".
function Data.IsInternalContent(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    local n = name:lower()
    if n:find("delete me", 1, true) then
        return true
    end
    if n:find("%(stm%)") or n:find("%(poc%)") or n:find("%(dnt%)") then
        return true
    end
    if n:find("%[dnt%]") or n:find("%[ph%]") then
        return true
    end
    if n:find("peter's test", 1, true) or n:find("^test %-") or n:find("zone 3 neck", 1, true) then
        return true
    end
    if n:find("prototype", 1, true) then
        return true
    end
    if n:find("testing %-") then
        return true
    end
    -- "The Testing of Azj-Kahet"; keep "Testing Loyalties".
    if n:find("the testing of ", 1, true) or n:find(" testing of ", 1, true) then
        return true
    end
    if n:find("%- rpe %-") or n:find(" rpe %-") then
        return true
    end
    if n:sub(-5) == " test" then
        return true
    end
    -- Version-prefixed internal buckets: "12.0 Z3 - ...", "12.0 Prelaunch - WQs".
    if n:find("^%d+%.%d+") then
        if n:find(" z%d+") or n:find("prelaunch", 1, true) or n:find("preorder", 1, true)
            or n:find("tutorial", 1, true) or n:find("endeavor", 1, true)
            or n:find("housing", 1, true) or n:find("cleanup", 1, true) then
            return true
        end
    end
    if n:find("moth hunt %- group", 1, true) then
        return true
    end
    if n:find("catch up", 1, true) or n:find("lorewalking", 1, true) then
        return true
    end
    return false
end

--- Census leftover buckets (ID ranges, not a real questline).
function Data.IsUnlistedBucket(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    return name:lower():find("^unlisted") and true or false
end

--- QuestLine buckets named as world quests / repeatables. Journal setting can hide them.
function Data.IsWorldQuestBucket(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    local n = name:lower()
    if n:find("world quest", 1, true) or n:find("repeatable", 1, true) then
        return true
    end
    return false
end

function Data.ShowWorldQuestBuckets()
    local db = AQ.DB and AQ.DB.Get and AQ.DB.Get() or nil
    if not db then
        return true
    end
    return db.journalShowWorldQuests ~= false
end

local function CategoryVisible(cat)
    if not cat or Data.IsInternalContent(cat.name) then
        return false
    end
    if Data.IsWorldQuestBucket(cat.name) and not Data.ShowWorldQuestBuckets() then
        return false
    end
    return true
end

function Data:GetCategories(expansionID)
    local exp = expansions[expansionID]
    local out = {}
    if not exp then
        return out
    end
    for i = 1, #exp.categories do
        local cat = categories[exp.categories[i]]
        if CategoryVisible(cat) then
            local visible = Data:GetChains(cat.id)
            if #visible > 0 then
                out[#out + 1] = cat
            end
        end
    end
    return out
end

local function FirstQuestID(chain)
    local nodes = chain and chain.nodes
    if type(nodes) ~= "table" then
        return 0
    end
    for i = 1, #nodes do
        local qid = nodes[i] and nodes[i].questID
        if type(qid) == "number" then
            return qid
        end
    end
    return 0
end

local function ChainPlayLess(a, b)
    local qa, qb = FirstQuestID(a), FirstQuestID(b)
    if qa ~= qb then
        return qa < qb
    end
    local na, nb = a.name or "", b.name or ""
    if na ~= nb then
        return na < nb
    end
    return (a.id or 0) < (b.id or 0)
end

local function SortChainsForPlay(list)
    if #list < 2 then
        return list
    end
    local byID = {}
    local indeg = {}
    local children = {}
    for i = 1, #list do
        local id = list[i].id
        byID[id] = list[i]
        indeg[id] = 0
        children[id] = {}
    end
    for i = 1, #list do
        local ch = list[i]
        local prereqs = ch.prerequisites
        if type(prereqs) == "table" then
            for p = 1, #prereqs do
                local pr = prereqs[p]
                if type(pr) == "table" and pr.type == "chain" and byID[pr.id] then
                    indeg[ch.id] = (indeg[ch.id] or 0) + 1
                    children[pr.id][#children[pr.id] + 1] = ch.id
                end
            end
        end
    end
    local ready = {}
    for i = 1, #list do
        if (indeg[list[i].id] or 0) == 0 then
            ready[#ready + 1] = list[i]
        end
    end
    table.sort(ready, ChainPlayLess)
    local sorted = {}
    local seen = {}
    while #ready > 0 do
        local n = table.remove(ready, 1)
        if not seen[n.id] then
            seen[n.id] = true
            sorted[#sorted + 1] = n
            local kids = children[n.id]
            local added = {}
            for k = 1, #kids do
                local cid = kids[k]
                indeg[cid] = (indeg[cid] or 0) - 1
                if indeg[cid] == 0 and not seen[cid] then
                    added[#added + 1] = byID[cid]
                end
            end
            if #added > 0 then
                table.sort(added, ChainPlayLess)
                for a = 1, #added do
                    ready[#ready + 1] = added[a]
                end
                table.sort(ready, ChainPlayLess)
            end
        end
    end
    for i = 1, #list do
        if not seen[list[i].id] then
            sorted[#sorted + 1] = list[i]
        end
    end
    return sorted
end

function Data:GetChains(categoryID)
    local cat = categories[categoryID]
    local out = {}
    if not cat then
        return out
    end
    for i = 1, #cat.chains do
        local chain = chains[cat.chains[i]]
        if chain and not Data.IsInternalContent(chain.name) then
            if not (Data.IsWorldQuestBucket(chain.name) and not Data.ShowWorldQuestBuckets()) then
                out[#out + 1] = chain
            end
        end
    end
    return SortChainsForPlay(out)
end

function Data:FindChainsForQuest(questID)
    return questIndex[questID]
end

local function ChainOpenScore(chain)
    if not chain then
        return -1
    end
    local name = chain.name
    if Data.IsInternalContent(name) then
        return 0
    end
    if Data.IsUnlistedBucket(name) then
        return 1
    end
    if Data.IsWorldQuestBucket(name) then
        return 2
    end
    return 10
end

function Data:FindFirstChainForQuest(questID)
    local list = questIndex[questID]
    if not list or not list[1] then
        return nil
    end
    local best, bestNode, bestScore
    for i = 1, #list do
        local chain = chains[list[i].chainID]
        local score = ChainOpenScore(chain)
        if not bestScore or score > bestScore then
            bestScore = score
            best = chain
            bestNode = list[i].nodeIndex
        end
    end
    return best, bestNode
end

local function RestrictionOk(restrictions)
    if type(restrictions) ~= "table" then
        return true
    end
    local faction = restrictions.faction
    if type(faction) == "string" and faction ~= "" then
        local player = AQ.Compat.UnitFaction()
        if player and player ~= faction then
            return false
        end
    end
    local classFile = restrictions.class
    if type(classFile) == "string" and classFile ~= "" then
        local player = AQ.Compat.UnitClassFile and AQ.Compat.UnitClassFile()
        if player and player ~= classFile then
            return false
        end
    end
    local classes = restrictions.classes
    if type(classes) == "table" and #classes > 0 then
        local player = AQ.Compat.UnitClassFile and AQ.Compat.UnitClassFile()
        if player then
            local ok = false
            for i = 1, #classes do
                if classes[i] == player then
                    ok = true
                    break
                end
            end
            if not ok then
                return false
            end
        end
    end
    return true
end

local function PrerequisitesMet(prereqs)
    if type(prereqs) ~= "table" then
        return true
    end
    for i = 1, #prereqs do
        local p = prereqs[i]
        if type(p) == "table" then
            if p.type == "level" then
                local min = p.min or p.level or 0
                if AQ.Compat.UnitLevel() < min then
                    return false
                end
            elseif p.type == "quest" and type(p.questID) == "number" then
                if not AQ.Compat.IsQuestFlaggedCompleted(p.questID) then
                    return false
                end
            elseif p.type == "chain" and type(p.id) == "number" then
                local st = Data:GetChainStatus(p.id)
                if st ~= "DONE" then
                    return false
                end
            end
        end
    end
    return true
end

function Data:GetNodeStatus(node)
    if type(node) ~= "table" then
        return "LOCKED"
    end
    if node.type ~= "quest" or type(node.questID) ~= "number" then
        return "READY"
    end
    if AQ.Compat.IsQuestFlaggedCompleted(node.questID) then
        return "DONE"
    end
    if AQ.Compat.IsQuestActive(node.questID) then
        if AQ.Compat.IsQuestComplete(node.questID) then
            return "ACTIVE"
        end
        return "ACTIVE"
    end
    return "READY"
end

function Data:GetChainStatus(chainID)
    local chain = chains[chainID]
    if not chain then
        return "LOCKED"
    end
    if not RestrictionOk(chain.restrictions) then
        return "LOCKED"
    end
    if not PrerequisitesMet(chain.prerequisites) then
        return "LOCKED"
    end
    local nodes = chain.nodes or {}
    if #nodes == 0 then
        return "READY"
    end
    local anyActive = false
    local allDone = true
    local anyReady = false
    for i = 1, #nodes do
        local st = Data:GetNodeStatus(nodes[i])
        if st == "ACTIVE" then
            anyActive = true
            allDone = false
        elseif st == "DONE" then
            -- keep
        else
            allDone = false
            anyReady = true
        end
    end
    if allDone then
        return "DONE"
    end
    if anyActive then
        return "ACTIVE"
    end
    if anyReady then
        return "READY"
    end
    return "LOCKED"
end

local KNOWN_PACKS = {
    { addon = "AllQuest_Data_Classic", expansionID = 0, name = "Classic" },
    { addon = "AllQuest_Data_TBC", expansionID = 1, name = "The Burning Crusade" },
    { addon = "AllQuest_Data_Wrath", expansionID = 2, name = "Wrath of the Lich King" },
    { addon = "AllQuest_Data_Cata", expansionID = 3, name = "Cataclysm" },
    { addon = "AllQuest_Data_MoP", expansionID = 4, name = "Mists of Pandaria" },
    { addon = "AllQuest_Data_WoD", expansionID = 5, name = "Warlords of Draenor" },
    { addon = "AllQuest_Data_Legion", expansionID = 6, name = "Legion" },
    { addon = "AllQuest_Data_BFA", expansionID = 7, name = "Battle for Azeroth" },
    { addon = "AllQuest_Data_Shadowlands", expansionID = 8, name = "Shadowlands" },
    { addon = "AllQuest_Data_Dragonflight", expansionID = 9, name = "Dragonflight" },
    { addon = "AllQuest_Data_TWW", expansionID = 10, name = "The War Within" },
    { addon = "AllQuest_Data_Midnight", expansionID = 11, name = "Midnight" },
}

local function NewestAllowedExpansion()
    local allowed = AQ.Compat.AllowedExpansionIDs()
    local maxID = allowed[1]
    for i = 2, #allowed do
        if allowed[i] > maxID then
            maxID = allowed[i]
        end
    end
    return maxID
end

local function PackDisplayName(addon, expansionID)
    local named = AQ.Compat.GetAddOnMetadata(addon, "X-AllQuest-Expansion-Name")
    if type(named) == "string" and named ~= "" then
        return named
    end
    for i = 1, #KNOWN_PACKS do
        if KNOWN_PACKS[i].addon == addon then
            return KNOWN_PACKS[i].name
        end
    end
    return addon
end

function Data.DefaultPackEnabled(addon, expansionID)
    local meta = AQ.Compat.GetAddOnMetadata(addon, "X-AllQuest-AutoLoad")
    if meta == "1" then
        return true
    end
    if meta == "0" then
        return false
    end
    return expansionID == NewestAllowedExpansion()
end

function Data.IsPackEnabled(addon)
    if type(addon) ~= "string" or addon == "" then
        return false
    end
    local db = AQ.DB and AQ.DB.Get and AQ.DB.Get() or {}
    local packs = db.dataPacks
    if type(packs) == "table" and packs[addon] ~= nil then
        return packs[addon] and true or false
    end
    local expMeta = AQ.Compat.GetAddOnMetadata(addon, "X-AllQuest-Expansion")
    local expID = tonumber(expMeta)
    return Data.DefaultPackEnabled(addon, expID)
end

function Data.SetPackEnabled(addon, on)
    if type(addon) ~= "string" or addon == "" then
        return false
    end
    local db = AQ.DB.Get()
    db.dataPacks = db.dataPacks or {}
    db.dataPacks[addon] = on and true or false
    if on and not AQ.Compat.IsAddOnLoaded(addon) then
        AQ.Compat.LoadAddOn(addon)
    end
    if AQ.Events then
        AQ.Events.Fire("AQ_DATA_CHANGED")
    end
    if AQ.Journal and AQ.Journal.Refresh then
        AQ.Journal.Refresh()
    end
    return true
end

function Data.ListPacks()
    local byAddon = {}
    local out = {}

    local function Add(addon, expansionID, name)
        if type(addon) ~= "string" or addon == "" or byAddon[addon] then
            return
        end
        local installed = AQ.Compat.DoesAddOnExist(addon)
        local loaded = installed and AQ.Compat.IsAddOnLoaded(addon) and true or false
        local enabledInList = installed and AQ.Compat.IsAddOnEnabled and AQ.Compat.IsAddOnEnabled(addon)
        if enabledInList == nil then
            enabledInList = installed
        end
        local allowed = expansionID and AQ.Compat.ExpansionAllowed(expansionID) and true or false
        local display = name or PackDisplayName(addon, expansionID)
        local entry = {
            addon = addon,
            expansionID = expansionID,
            name = display,
            installed = installed and true or false,
            loaded = loaded,
            enabledInList = enabledInList and true or false,
            allowed = allowed,
            canToggle = installed and allowed and enabledInList and true or false,
        }
        byAddon[addon] = entry
        out[#out + 1] = entry
    end

    for i = 1, #KNOWN_PACKS do
        local pack = KNOWN_PACKS[i]
        Add(pack.addon, pack.expansionID, pack.name)
    end

    local n = AQ.Compat.GetNumAddOns()
    for i = 1, n do
        local name = AQ.Compat.GetAddOnInfo(i)
        if type(name) == "string" then
            local expMeta = AQ.Compat.GetAddOnMetadata(name, "X-AllQuest-Expansion")
            if type(expMeta) == "string" and expMeta ~= "" then
                local expID = tonumber(expMeta)
                Add(name, expID, PackDisplayName(name, expID))
            end
        end
    end

    table.sort(out, function(a, b)
        local ai = tonumber(a.expansionID) or 0
        local bi = tonumber(b.expansionID) or 0
        if ai == bi then
            return (a.name or "") < (b.name or "")
        end
        return ai < bi
    end)
    return out
end

function Data:DiscoverAndLoad()
    local n = AQ.Compat.GetNumAddOns()
    for i = 1, n do
        local name = AQ.Compat.GetAddOnInfo(i)
        if type(name) == "string" then
            local expMeta = AQ.Compat.GetAddOnMetadata(name, "X-AllQuest-Expansion")
            if type(expMeta) == "string" and expMeta ~= "" then
                local expID = tonumber(expMeta)
                if expID and AQ.Compat.ExpansionAllowed(expID) and Data.IsPackEnabled(name) then
                    if not AQ.Compat.IsAddOnLoaded(name) then
                        AQ.Compat.LoadAddOn(name)
                    end
                end
            end
        end
    end
    if AQ.Events then
        AQ.Events.Fire("AQ_DATA_CHANGED")
    end
end
