--[[
  AllQuest — zone battle pets in the tracker
  Native map POIs / vignettes, plus PetTracker / Battle Pet Completionist.
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

local function PlayerMap()
    if AQ.Compat and AQ.Compat.GetPlayerMapPosition then
        return AQ.Compat.GetPlayerMapPosition()
    end
    if C_Map and C_Map.GetBestMapForUnit then
        return AQ:SafeCall(C_Map.GetBestMapForUnit, "player")
    end
    return nil
end

local function OwnedSpecies(speciesId)
    if type(speciesId) ~= "number" or not C_PetJournal or not C_PetJournal.GetNumCollectedInfo then
        return false
    end
    local n = AQ:SafeCall(C_PetJournal.GetNumCollectedInfo, speciesId)
    return type(n) == "number" and n > 0
end

local function SpeciesFromName(name)
    if type(name) ~= "string" or name == "" or not C_PetJournal then
        return nil
    end
    if C_PetJournal.FindPetIDByName then
        local id = AQ:SafeCall(C_PetJournal.FindPetIDByName, name)
        if type(id) == "number" then
            return id
        end
    end
    return nil
end

local function AddPetRow(rows, name, owned, speciesId, icon, mapID, x, y)
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
        petMapID = mapID,
        petX = x,
        petY = y,
        speech = "Pet " .. name .. (owned and " collected" or " missing"),
    }
end

local function LooksLikePet(name, atlas)
    local blob = string.lower(tostring(name or "") .. " " .. tostring(atlas or ""))
    if blob:find("treasure", 1, true) or blob:find("rare", 1, true) and not blob:find("pet", 1, true) then
        return false
    end
    return blob:find("pet", 1, true)
        or blob:find("battle pet", 1, true)
        or blob:find("wildpet", 1, true)
        or blob:find("critter", 1, true)
end

local function RowsFromMap()
    local rows = {}
    local seen = {}
    local mapID = PlayerMap()
    if type(mapID) ~= "number" then
        return rows
    end

    if C_VignetteInfo and C_VignetteInfo.GetVignettes then
        local guids = AQ:SafeCall(C_VignetteInfo.GetVignettes)
        if type(guids) == "table" then
            for i = 1, #guids do
                local guid = guids[i]
                local info = C_VignetteInfo.GetVignetteInfo and AQ:SafeCall(C_VignetteInfo.GetVignetteInfo, guid)
                if type(info) == "table" and LooksLikePet(info.name, info.atlasName) then
                    local name = info.name
                    if type(name) == "string" and name ~= "" and not seen[name] then
                        seen[name] = true
                        local x, y
                        if C_VignetteInfo.GetVignettePosition then
                            local pos = AQ:SafeCall(C_VignetteInfo.GetVignettePosition, guid, mapID)
                            if pos and pos.GetXY then
                                x, y = pos:GetXY()
                            end
                        end
                        local speciesId = SpeciesFromName(name)
                        local icon
                        if speciesId and C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID then
                            icon = select(2, C_PetJournal.GetPetInfoBySpeciesID(speciesId))
                        end
                        AddPetRow(rows, name, OwnedSpecies(speciesId), speciesId, icon, mapID, x, y)
                    end
                end
            end
        end
    end

    if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap then
        local pois = AQ:SafeCall(C_AreaPoiInfo.GetAreaPOIForMap, mapID)
        if type(pois) == "table" then
            for i = 1, #pois do
                local poiID = pois[i]
                local info = C_AreaPoiInfo.GetAreaPOIInfo and AQ:SafeCall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, poiID)
                if type(info) == "table" and LooksLikePet(info.name, info.atlasName) then
                    local name = info.name
                    if type(name) == "string" and name ~= "" and not seen[name] then
                        seen[name] = true
                        local x, y
                        if info.position and info.position.GetXY then
                            x, y = info.position:GetXY()
                        end
                        local speciesId = SpeciesFromName(name)
                        AddPetRow(rows, name, OwnedSpecies(speciesId), speciesId, info.textureIndex, mapID, x, y)
                    end
                end
            end
        end
    end
    return rows
end

local function RowsFromPetTracker()
    local rows = {}
    if not (AQ.Plugins and AQ.Plugins.IsEnabled("PetTracker") and AQ:AddonLoaded("PetTracker")) then
        return rows
    end
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
    if not (AQ.Plugins and AQ.Plugins.IsEnabled("BattlePetCompletionist") and AQ:AddonLoaded("BattlePetCompletionist")) then
        return rows
    end
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

local function MergeRows(base, extra)
    local seen = {}
    for i = 1, #base do
        seen[base[i].title] = true
    end
    for i = 1, #extra do
        if not seen[extra[i].title] then
            base[#base + 1] = extra[i]
            seen[extra[i].title] = true
        end
    end
    return base
end

local function GetRows()
    local rows = RowsFromMap()
    rows = MergeRows(rows, RowsFromPetTracker())
    rows = MergeRows(rows, RowsFromBattlePetCompletionist())
    return rows
end

AQ.Tracker.RegisterSection({
    id = "pets",
    title = "Pets",
    order = 70,
    flavor = "all",
    GetRows = GetRows,
})

local function RefreshPets()
    if AQ.Tracker then
        AQ.Tracker.Refresh()
    end
end

AQ.Events.Register("VIGNETTES_UPDATED", RefreshPets)
AQ.Events.Register("VIGNETTE_MINIMAP_UPDATED", RefreshPets)
AQ.Events.Register("AREA_POIS_UPDATED", RefreshPets)
AQ.Events.Register("PET_JOURNAL_LIST_UPDATE", RefreshPets)
