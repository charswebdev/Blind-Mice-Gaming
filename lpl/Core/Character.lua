local addonName, LPL = ...

LPL.Character = {}

local function SpecIDFromInfoResult(result)
    if type(result) == "table" then
        return tonumber(result.specID or result.id or result[1])
    end
    return tonumber(result)
end

local function LooksLikeSpecID(value)
    value = tonumber(value)
    if not value or value <= 0 then
        return nil
    end

    local byID = GetSpecializationInfoByID
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID then
        byID = C_SpecializationInfo.GetSpecializationInfoByID
    end
    if byID then
        local first, second = byID(value)
        if type(first) == "table" and (first.name or first.specID or first.id) then
            return value
        end
        if type(second) == "string" and second ~= "" then
            return value
        end
        if type(first) == "number" and type(second) == "string" then
            return value
        end
    end

    -- Spec IDs are always well above the 1-5 spec-index range.
    if value > 5 then
        return value
    end
    return nil
end

function LPL.Character:GetSlug()
    local name = UnitName and UnitName("player")
    local realm = GetRealmName and GetRealmName()
    if not name or name == "" then
        return nil
    end
    realm = realm or ""
    return realm .. "-" .. name
end

function LPL.Character:GetClassFile()
    local _, classFile = UnitClass and UnitClass("player")
    return classFile
end

function LPL.Character:GetClassID()
    if LPL.TalentTree and LPL.TalentTree.GetDefaultClassID then
        return LPL.TalentTree:GetDefaultClassID()
    end
    local classFile = self:GetClassFile()
    if classFile and LPL.TalentTree and LPL.TalentTree.GetClasses then
        for _, class in ipairs(LPL.TalentTree:GetClasses()) do
            if class.file == classFile then
                return class.id
            end
        end
    end
    if GetNumClasses and GetClassInfo then
        for classID = 1, GetNumClasses() do
            local _, file = GetClassInfo(classID)
            if file == classFile then
                return classID
            end
        end
    end
    return nil
end

function LPL.Character:GetSpecID()
    if PlayerUtil and PlayerUtil.GetCurrentSpecID then
        local specID = LooksLikeSpecID(PlayerUtil.GetCurrentSpecID())
        if specID then
            return specID
        end
    end

    local raw
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        raw = C_SpecializationInfo.GetSpecialization()
    elseif GetSpecialization then
        raw = GetSpecialization()
    end

    local asSpec = LooksLikeSpecID(raw)
    if asSpec then
        return asSpec
    end

    local index = tonumber(raw)
    if index and index > 0 then
        if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
            local specID = SpecIDFromInfoResult(C_SpecializationInfo.GetSpecializationInfo(index))
            if specID then
                return specID
            end
        end
        if GetSpecializationInfo then
            local specID = SpecIDFromInfoResult(GetSpecializationInfo(index))
            if specID then
                return specID
            end
        end
    end

    return nil
end

function LPL.Character:GetRaceID()
    if C_PlayerInfo and C_PlayerInfo.GetPlayerRace then
        local race = C_PlayerInfo.GetPlayerRace()
        if race and race.raceID then
            return race.raceID
        end
    end
    if UnitRace then
        local raceID = select(3, UnitRace("player"))
        if raceID then
            return tonumber(raceID)
        end
    end
    return nil
end

function LPL.Character:GetCovenantID()
    if C_Covenants and C_Covenants.GetActiveCovenantID then
        local covenantID = C_Covenants.GetActiveCovenantID()
        if covenantID and covenantID > 0 then
            return covenantID
        end
    end
    return nil
end
