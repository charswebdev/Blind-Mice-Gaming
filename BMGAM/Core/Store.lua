local _, BMGAM = ...

BMGAM.Store = BMGAM.Store or {}
local Store = BMGAM.Store

local view = {}

local function Saved(name)
    local current = _G[name]
    if type(current) ~= "table" then
        current = {}
        _G[name] = current
    end
    return current
end

local function Take(saved, guid, field, record)
    local pack = saved[guid]
    if type(pack) ~= "table" and record and type(record[field]) == "table" then
        pack = record[field]
        saved[guid] = pack
    end
    if record then
        record[field] = nil
    end
    return pack
end

function Store.Quests(record, create)
    if type(record) ~= "table" or not record.guid then
        return nil
    end
    local saved = Saved("bmgam_Quests")
    local pack = Take(saved, record.guid, "quests", record)
    if type(pack) ~= "table" and create then
        pack = {}
        saved[record.guid] = pack
    end
    return pack
end

function Store.Achievements(record, pack)
    if type(record) ~= "table" or not record.guid then
        return nil
    end
    local saved = Saved("bmgam_Achievements")
    if type(pack) == "table" then
        saved[record.guid] = pack
        record.achievements = nil
        return pack
    end
    return Take(saved, record.guid, "achievements", record)
end

local function Append(into, items)
    local index = 1
    while type(items) == "table" and items[index] do
        into[#into + 1] = items[index]
        index = index + 1
    end
end

function Store.SaveCollections(guid, accountItems, ownItems)
    if not guid then
        return
    end
    local account = Saved("bmgam_Account")
    account.collections = {
        scanned = true,
        scannedAt = time(),
        items = accountItems or {},
    }
    local own = Saved("bmgam_Collections")
    own[guid] = {
        scanned = true,
        scannedAt = time(),
        items = ownItems or {},
    }
    view[guid] = nil
end

function Store.Collections(record)
    if type(record) ~= "table" or not record.guid then
        return nil
    end
    if view[record.guid] then
        return view[record.guid]
    end
    local accountSaved = Saved("bmgam_Account")
    local ownSaved = Saved("bmgam_Collections")
    if type(record.collections) == "table" and type(ownSaved[record.guid]) ~= "table" and type(accountSaved.collections) ~= "table" then
        return record.collections
    end
    local account = accountSaved.collections
    local own = ownSaved[record.guid]
    local scanned = (type(account) == "table" and account.scanned == true) or (type(own) == "table" and own.scanned == true)
    if not scanned then
        return nil
    end
    local items = {}
    if type(account) == "table" then
        Append(items, account.items)
    end
    if type(own) == "table" then
        Append(items, own.items)
    end
    local pack = {
        scanned = true,
        items = items,
    }
    view[record.guid] = pack
    return pack
end

local function SplitItems(items)
    local shared = {}
    local own = {}
    local index = 1
    while type(items) == "table" and items[index] do
        local item = items[index]
        if type(item) == "table" and item.type == "manuscript" then
            own[#own + 1] = item
        elseif type(item) == "table" then
            shared[#shared + 1] = item
        end
        index = index + 1
    end
    return shared, own
end

function Store.Migrate()
    if type(bmgam_SavedVariables) ~= "table" or type(bmgam_SavedVariables.characters) ~= "table" then
        return
    end
    local quests = Saved("bmgam_Quests")
    local achievements = Saved("bmgam_Achievements")
    local ownSaved = Saved("bmgam_Collections")
    local account = Saved("bmgam_Account")
    local bestAt = -1
    local bestItems = nil
    local bestWhen = nil
    for guid, record in pairs(bmgam_SavedVariables.characters) do
        if type(record) == "table" then
            record.guid = record.guid or guid
            if type(record.quests) == "table" and type(quests[guid]) ~= "table" then
                quests[guid] = record.quests
            end
            record.quests = nil
            if type(record.achievements) == "table" and type(achievements[guid]) ~= "table" then
                achievements[guid] = record.achievements
            end
            record.achievements = nil
            local pack = record.collections
            if type(pack) == "table" and type(pack.items) == "table" then
                local when = tonumber(pack.scannedAt) or 0
                if when >= bestAt then
                    bestAt = when
                    bestItems = pack.items
                    bestWhen = when
                end
            end
        end
    end
    if type(account.collections) ~= "table" and bestItems then
        local shared = SplitItems(bestItems)
        account.collections = {
            scanned = true,
            scannedAt = bestWhen or time(),
            items = shared,
        }
    end
    for guid, record in pairs(bmgam_SavedVariables.characters) do
        if type(record) == "table" and type(record.collections) == "table" then
            if type(ownSaved[guid]) ~= "table" then
                local _, own = SplitItems(record.collections.items)
                if own[1] then
                    ownSaved[guid] = {
                        scanned = true,
                        scannedAt = tonumber(record.collections.scannedAt) or time(),
                        items = own,
                    }
                end
            end
            record.collections = nil
            view[guid] = nil
        end
    end
end

function Store.ClearView()
    view = {}
end

function Store.Forget(guid)
    if not guid then
        return
    end
    if type(bmgam_Quests) == "table" then
        bmgam_Quests[guid] = nil
    end
    if type(bmgam_Achievements) == "table" then
        bmgam_Achievements[guid] = nil
    end
    if type(bmgam_Collections) == "table" then
        bmgam_Collections[guid] = nil
    end
    view[guid] = nil
end
