local addonName, LPL = ...

LPL.Character = {}

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
    if LPL.TalentTree and LPL.TalentTree.GetPlayerIdentity then
        return select(1, LPL.TalentTree:GetPlayerIdentity())
    end
    local classFile = self:GetClassFile()
    if classFile and LPL.TalentTree and LPL.TalentTree.GetClasses then
        for _, class in ipairs(LPL.TalentTree:GetClasses()) do
            if class.file == classFile then
                return class.id
            end
        end
    end
    return nil
end

function LPL.Character:GetSpecID()
    if LPL.TalentTree and LPL.TalentTree.GetPlayerIdentity then
        return select(2, LPL.TalentTree:GetPlayerIdentity())
    end
    if GetSpecialization then
        local specIndex = GetSpecialization()
        if specIndex then
            return select(1, GetSpecializationInfo(specIndex))
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
