--[[
  AllQuest — PetTracker / Battle Pet Completionist zone pets in the tracker
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local function HidePetTrackerWindow()
    if not PetTracker or not PetTracker.Objectives then
        return
    end
    if PetTracker.Objectives.Hide then
        pcall(PetTracker.Objectives.Hide, PetTracker.Objectives)
    end
end

local function AddPetRow(rows, name, owned, speciesId, icon)
    if type(name) ~= "string" or name == "" then
        return
    end
    rows[#rows + 1] = {
        kind = "quest",
        title = name,
        status = owned and "DONE" or "ACTIVE",
        indent = 8,
        pet = true,
        speciesId = speciesId,
        icon = icon,
        speech = "Pet " .. name .. (owned and " collected" or " missing"),
    }
end

local function RowsFromPetTracker()
    local rows = {}
    if not PetTracker or not PetTracker.Maps or type(PetTracker.Maps.GetCurrentProgress) ~= "function" then
        return rows
    end
    HidePetTrackerWindow()
    local ok, progress = pcall(PetTracker.Maps.GetCurrentProgress, PetTracker.Maps)
    if not ok or type(progress) ~= "table" then
        return rows
    end

    local captured = true
    if PetTracker.sets and PetTracker.sets.capturedPets == false then
        captured = false
    end
    local maxQuality = 0
    if captured then
        maxQuality = PetTracker.MaxQuality or 6
    end
    local maxLevel = PetTracker.MaxLevel or 25
    local maxEntries = 24
    if PetTracker.Objectives and type(PetTracker.Objectives.MaxEntries) == "number" then
        maxEntries = PetTracker.Objectives.MaxEntries
    end

    if type(progress[0]) == "table" and type(progress[0].total) == "number" then
        for quality = 0, maxQuality do
            local q = progress[quality]
            if type(q) == "table" then
                for level = 0, maxLevel do
                    local list = q[level]
                    if type(list) == "table" then
                        for i = 1, #list do
                            if #rows >= maxEntries then
                                return rows
                            end
                            local specie = list[i]
                            if type(specie) == "table" then
                                local name, icon
                                if type(specie.GetInfo) == "function" then
                                    name, icon = specie:GetInfo()
                                end
                                local speciesId
                                if type(specie.GetSpecie) == "function" then
                                    speciesId = specie:GetSpecie()
                                end
                                AddPetRow(rows, name, quality > 0, speciesId, icon)
                            end
                        end
                    end
                end
            end
        end
        return rows
    end

    for i = 1, #progress do
        local e = progress[i]
        if type(e) == "table" then
            AddPetRow(rows, e.name or e.Name, e.owned or e.Owned, e.speciesId or e.id, e.icon)
        end
    end
    return rows
end

local function RowsFromBattlePetCompletionist()
    local rows = {}
    local addon = BattlePetCompletionist
    if not addon or type(addon.GetModule) ~= "function" then
        return rows
    end
    local ok, mod = pcall(addon.GetModule, addon, "ObjectiveTrackerModule", true)
    if not ok or not mod or type(mod.GetFilteredPetList) ~= "function" then
        return rows
    end
    local okList, pets = pcall(mod.GetFilteredPetList, mod)
    if not okList or type(pets) ~= "table" then
        return rows
    end
    for i = 1, #pets do
        local e = pets[i]
        if type(e) == "table" then
            local icon
            if e.speciesId and C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID then
                icon = select(2, C_PetJournal.GetPetInfoBySpeciesID(e.speciesId))
            end
            local owned = type(e.numCollected) == "number" and e.numCollected > 0
            AddPetRow(rows, e.speciesName, owned, e.speciesId, icon)
        end
    end
    return rows
end

local function GetRows()
    if AQ.Plugins and AQ.Plugins.IsEnabled("PetTracker") and AQ:AddonLoaded("PetTracker") then
        local rows = RowsFromPetTracker()
        if #rows > 0 then
            return rows
        end
    end
    if AQ.Plugins and AQ.Plugins.IsEnabled("BattlePetCompletionist") and AQ:AddonLoaded("BattlePetCompletionist") then
        return RowsFromBattlePetCompletionist()
    end
    return {}
end

AQ.Tracker.RegisterSection({
    id = "pets",
    title = "Pets",
    order = 70,
    flavor = "all",
    requiresAnyPlugin = { "PetTracker", "BattlePetCompletionist" },
    GetRows = GetRows,
})
