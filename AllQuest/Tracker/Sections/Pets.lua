--[[
  AllQuest — nearby and zone battle pets in the tracker
  Native vignettes, nameplates, target/mouseover, plus PetTracker / Battle Pet Completionist.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local nearbyPlates = {}
local plateByUnit = {}
local refreshPending

local function RefreshSoon()
    if refreshPending then
        return
    end
    refreshPending = true
    local function run()
        refreshPending = false
        if AQ.Tracker and AQ.Tracker.Refresh then
            AQ.Tracker.Refresh()
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, run)
    else
        run()
    end
end

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

local function HasExactPet(speciesId, name)
    if OwnedSpecies(speciesId) then
        return true
    end
    if type(name) ~= "string" or name == "" or not C_PetJournal or not C_PetJournal.FindPetIDByName then
        return false
    end
    local petID, sid = AQ:SafeCall(C_PetJournal.FindPetIDByName, name)
    if type(sid) == "number" then
        return OwnedSpecies(sid)
    end
    return type(petID) == "string" and petID ~= ""
end

local function SpeciesIcon(speciesId)
    if type(speciesId) ~= "number" or not C_PetJournal or not C_PetJournal.GetPetInfoBySpeciesID then
        return nil
    end
    return select(2, C_PetJournal.GetPetInfoBySpeciesID(speciesId))
end

local function SpeciesFromName(name)
    if type(name) ~= "string" or name == "" or not C_PetJournal then
        return nil
    end
    if C_PetJournal.FindPetIDByName then
        local petID, speciesID = AQ:SafeCall(C_PetJournal.FindPetIDByName, name)
        if type(speciesID) == "number" then
            return speciesID
        end
        if type(petID) == "number" then
            return petID
        end
        if type(petID) == "string" and C_PetJournal.GetPetInfoByPetID then
            local speciesId = select(2, AQ:SafeCall(C_PetJournal.GetPetInfoByPetID, petID))
            if type(speciesId) == "number" then
                return speciesId
            end
        end
    end
    return nil
end

local function IsWildBattlePetUnit(unit)
    if type(unit) ~= "string" or unit == "" then
        return false
    end
    if not UnitExists or not UnitExists(unit) then
        return false
    end
    if UnitIsWildBattlePet then
        return UnitIsWildBattlePet(unit) and true or false
    end
    if UnitIsBattlePetCompanion and UnitIsBattlePetCompanion(unit) then
        return false
    end
    if UnitIsBattlePet then
        return UnitIsBattlePet(unit) and true or false
    end
    return false
end

local function SpeciesFromUnit(unit)
    if UnitBattlePetSpeciesID then
        local id = UnitBattlePetSpeciesID(unit)
        if type(id) == "number" and id > 0 then
            return id
        end
    end
    return SpeciesFromName(UnitName and UnitName(unit))
end

local function AddPetRow(rows, seen, name, owned, speciesId, icon, mapID, x, y, source)
    if type(name) ~= "string" or name == "" then
        return
    end
    if seen[name] then
        return
    end
    seen[name] = true
    if type(speciesId) ~= "number" then
        speciesId = SpeciesFromName(name)
    end
    owned = HasExactPet(speciesId, name)
    rows[#rows + 1] = {
        kind = "quest",
        title = name,
        status = owned and "DONE" or "ACTIVE",
        indent = 8,
        pet = true,
        petSource = source or "nearby",
        speciesId = speciesId,
        icon = icon or SpeciesIcon(speciesId),
        petMapID = mapID,
        petX = x,
        petY = y,
        speech = "Pet " .. name .. (owned and " collected" or " missing"),
    }
end

local function LooksLikePet(name, atlas)
    local n = string.lower(tostring(name or ""))
    local a = string.lower(tostring(atlas or ""))
    if n:find("treasure", 1, true) or a:find("treasure", 1, true) or a:find("loot", 1, true) then
        return false
    end
    if a:find("wildpet", 1, true)
        or a:find("battlepet", 1, true)
        or a:find("wildbattlepet", 1, true)
        or a:find("tracking_wildpet", 1, true)
        or a:find("tracking-wildpet", 1, true)
        or a:find("trackingbattlepet", 1, true)
    then
        return true
    end
    if n:find("battle pet", 1, true) then
        return true
    end
    if (n:find("pet", 1, true) or a:find("pet", 1, true) or a:find("critter", 1, true))
        and not a:find("rare", 1, true)
        and not a:find("vignettekill", 1, true)
    then
        return true
    end
    if SpeciesFromName(name) then
        return true
    end
    return false
end

local function RowsFromMap(rows, seen)
    local mapID = PlayerMap()
    if type(mapID) ~= "number" then
        return
    end

    if C_VignetteInfo and C_VignetteInfo.GetVignettes then
        local guids = AQ:SafeCall(C_VignetteInfo.GetVignettes)
        if type(guids) == "table" then
            for i = 1, #guids do
                local guid = guids[i]
                local info = C_VignetteInfo.GetVignetteInfo and AQ:SafeCall(C_VignetteInfo.GetVignetteInfo, guid)
                if type(info) == "table" and LooksLikePet(info.name, info.atlasName) then
                    local x, y
                    if C_VignetteInfo.GetVignettePosition then
                        local pos = AQ:SafeCall(C_VignetteInfo.GetVignettePosition, guid, mapID)
                        if pos and pos.GetXY then
                            x, y = pos:GetXY()
                        end
                    end
                    AddPetRow(rows, seen, info.name, nil, nil, nil, mapID, x, y, "nearby")
                end
            end
        end
    end

    if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap then
        local pois = AQ:SafeCall(C_AreaPoiInfo.GetAreaPOIForMap, mapID)
        if type(pois) == "table" then
            for i = 1, #pois do
                local info = C_AreaPoiInfo.GetAreaPOIInfo and AQ:SafeCall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, pois[i])
                if type(info) == "table" and LooksLikePet(info.name, info.atlasName) then
                    local x, y
                    if info.position and info.position.GetXY then
                        x, y = info.position:GetXY()
                    end
                    AddPetRow(rows, seen, info.name, nil, nil, info.textureIndex, mapID, x, y, "nearby")
                end
            end
        end
    end
end

local function RecordUnit(unit, gone, silent)
    if type(unit) ~= "string" or unit == "" then
        return
    end
    if gone then
        local name = plateByUnit[unit]
        plateByUnit[unit] = nil
        if name then
            nearbyPlates[name] = nil
            if not silent then
                RefreshSoon()
            end
        end
        return
    end
    if not IsWildBattlePetUnit(unit) then
        return
    end
    local name = UnitName and UnitName(unit)
    if type(name) ~= "string" or name == "" then
        return
    end
    plateByUnit[unit] = name
    nearbyPlates[name] = {
        time = GetTime and GetTime() or 0,
        speciesId = SpeciesFromUnit(unit),
        owned = OwnedSpecies(SpeciesFromUnit(unit)),
    }
    if not silent then
        RefreshSoon()
    end
end

local function ScanNameplates()
    if type(C_NamePlate) == "table" and C_NamePlate.GetNamePlates then
        local plates = AQ:SafeCall(C_NamePlate.GetNamePlates)
        if type(plates) == "table" then
            for i = 1, #plates do
                local frame = plates[i]
                local unit = frame and (frame.namePlateUnitToken or frame.unitToken)
                if unit then
                    RecordUnit(unit, false, true)
                end
            end
            return
        end
    end
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists and UnitExists(unit) then
            RecordUnit(unit, false, true)
        end
    end
end

local function RowsFromNearbyUnits(rows, seen)
    ScanNameplates()
    RecordUnit("target", false, true)
    RecordUnit("mouseover", false, true)
    local now = GetTime and GetTime() or 0
    local mapID = PlayerMap()
    for name, info in pairs(nearbyPlates) do
        if type(info) == "table" and (now - (info.time or 0)) < 90 then
            AddPetRow(rows, seen, name, info.owned, info.speciesId, nil, mapID, nil, nil, "nearby")
        else
            nearbyPlates[name] = nil
        end
    end
end

local function RowsFromPetTracker(rows, seen)
    if not (AQ.Plugins and AQ.Plugins.IsEnabled("PetTracker") and AQ:AddonLoaded("PetTracker")) then
        return
    end
    if not PetTracker or not PetTracker.Maps or type(PetTracker.Maps.GetCurrentProgress) ~= "function" then
        return
    end
    HidePetTrackerWindow()
    local ok, progress = pcall(PetTracker.Maps.GetCurrentProgress, PetTracker.Maps)
    if not ok or type(progress) ~= "table" then
        return
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
    local added = 0

    if type(progress[0]) == "table" and type(progress[0].total) == "number" then
        for quality = 0, maxQuality do
            local q = progress[quality]
            if type(q) == "table" then
                for level = 0, maxLevel do
                    local list = q[level]
                    if type(list) == "table" then
                        for i = 1, #list do
                            if added >= maxEntries then
                                return
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
                                local before = #rows
                                AddPetRow(rows, seen, name, quality > 0, speciesId, icon, nil, nil, nil, "zone")
                                if #rows > before then
                                    added = added + 1
                                end
                            end
                        end
                    end
                end
            end
        end
        return
    end

    for i = 1, #progress do
        local e = progress[i]
        if type(e) == "table" then
            AddPetRow(rows, seen, e.name or e.Name, e.owned or e.Owned, e.speciesId or e.id, e.icon, nil, nil, nil, "zone")
        end
    end
end

local function RowsFromBattlePetCompletionist(rows, seen)
    if not (AQ.Plugins and AQ.Plugins.IsEnabled("BattlePetCompletionist") and AQ:AddonLoaded("BattlePetCompletionist")) then
        return
    end
    local addon = BattlePetCompletionist
    if not addon or type(addon.GetModule) ~= "function" then
        return
    end
    local ok, mod = pcall(addon.GetModule, addon, "ObjectiveTrackerModule", true)
    if not ok or not mod or type(mod.GetFilteredPetList) ~= "function" then
        return
    end
    local okList, pets = pcall(mod.GetFilteredPetList, mod)
    if not okList or type(pets) ~= "table" then
        return
    end
    for i = 1, #pets do
        local e = pets[i]
        if type(e) == "table" then
            local owned = type(e.numCollected) == "number" and e.numCollected > 0
            AddPetRow(rows, seen, e.speciesName, owned, e.speciesId, nil, nil, nil, nil, "zone")
        end
    end
end

local function GroupRows(flat)
    local nearby, zone = {}, {}
    for i = 1, #flat do
        if flat[i].petSource == "zone" then
            zone[#zone + 1] = flat[i]
        else
            nearby[#nearby + 1] = flat[i]
        end
    end
    if #nearby == 0 or #zone == 0 then
        return flat
    end
    local rows = {
        {
            kind = "header",
            id = "pets:nearby",
            title = "Nearby",
            speech = "Nearby pets",
            fontSize = 12,
            indent = 14,
            subheader = true,
        },
    }
    for i = 1, #nearby do
        rows[#rows + 1] = nearby[i]
    end
    rows[#rows + 1] = {
        kind = "header",
        id = "pets:zone",
        title = "Zone",
        speech = "Zone pets",
        fontSize = 12,
        indent = 14,
        subheader = true,
    }
    for i = 1, #zone do
        rows[#rows + 1] = zone[i]
    end
    return rows
end

local function GetRows()
    local rows = {}
    local seen = {}
    RowsFromMap(rows, seen)
    RowsFromNearbyUnits(rows, seen)
    RowsFromPetTracker(rows, seen)
    RowsFromBattlePetCompletionist(rows, seen)
    return GroupRows(rows)
end

AQ.Tracker.RegisterSection({
    id = "pets",
    title = "Pets",
    order = 70,
    flavor = "all",
    GetRows = GetRows,
})

AQ.Events.Register("VIGNETTES_UPDATED", RefreshSoon)
AQ.Events.Register("VIGNETTE_MINIMAP_UPDATED", RefreshSoon)
AQ.Events.Register("AREA_POIS_UPDATED", RefreshSoon)
AQ.Events.Register("PET_JOURNAL_LIST_UPDATE", RefreshSoon)
AQ.Events.Register("PLAYER_TARGET_CHANGED", RefreshSoon)
AQ.Events.Register("UPDATE_MOUSEOVER_UNIT", RefreshSoon)
AQ.Events.Register("PLAYER_ENTERING_WORLD", RefreshSoon)
AQ.Events.Register("ZONE_CHANGED_NEW_AREA", RefreshSoon)
AQ.Events.Register("PET_BATTLE_CLOSE", RefreshSoon)
AQ.Events.Register("NAME_PLATE_UNIT_ADDED", function(_, unit)
    RecordUnit(unit, false, false)
end)
AQ.Events.Register("NAME_PLATE_UNIT_REMOVED", function(_, unit)
    RecordUnit(unit, true, false)
end)
