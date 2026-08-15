local addon = Exploration

function addon:IsEarthen()
    if not UnitRace then return false end
    -- Alliance 85 / Horde 84; clientFileString is "EarthenDwarf" (not "Earthen").
    local localized, raceFile, raceID = UnitRace("player")
    if raceID == 84 or raceID == 85 then
        return true
    end
    local file = tostring(raceFile or "")
    if file == "EarthenDwarf" or file == "Earthen" or file:find("Earthen", 1, true) then
        return true
    end
    if localized and tostring(localized):find("Earthen", 1, true) then
        return true
    end
    if raceID and C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
        local info = C_CreatureInfo.GetRaceInfo(raceID)
        local cfs = info and info.clientFileString
        if cfs == "EarthenDwarf" or cfs == "Earthen" or (cfs and cfs:find("Earthen", 1, true)) then
            return true
        end
    end
    return false
end

function addon:EvaluateCondition(cond)
    if not cond or not cond.type then return false end
    local t = cond.type
    if t == "earthen" then
        return self:IsEarthen()
    elseif t == "achievement" then
        local _, _, _, completed = GetAchievementInfo(cond.id)
        return completed == true
    elseif t == "faction" then
        return UnitFactionGroup("player") == cond.faction
    elseif t == "level" then
        return UnitLevel("player") >= (cond.level or 0)
    elseif t == "class" then
        local _, classToken = UnitClass("player")
        return classToken == cond.class
    elseif t == "quest" then
        return C_QuestLog.IsQuestFlaggedCompleted(cond.id)
    elseif t == "all" then
        for _, sub in ipairs(cond.conditions or {}) do
            if not self:EvaluateCondition(sub) then return false end
        end
        return true
    elseif t == "any" then
        for _, sub in ipairs(cond.conditions or {}) do
            if self:EvaluateCondition(sub) then return true end
        end
        return false
    end
    return false
end
