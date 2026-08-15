local _, ns = ...

local PlayerContext = {}
ns.PlayerContext = PlayerContext

function PlayerContext:Snapshot()
    local db = ns.Database:GetProfile()
    local mode = db.phaseMode or "auto"
    local detected = self:DetectPhase()

    if mode == "auto" then
        mode = detected
    end

    return {
        mapId = C_Map.GetBestMapForUnit("player"),
        faction = UnitFactionGroup("player"),
        inChromieTime = C_PlayerInfo and C_PlayerInfo.IsPlayerInChromieTime and C_PlayerInfo.IsPlayerInChromieTime(),
        phaseMode = mode,
        detectedPhase = detected,
        inCombat = InCombatLockdown(),
    }
end

function PlayerContext:DetectPhase()
    if C_PlayerInfo and C_PlayerInfo.IsPlayerInChromieTime and C_PlayerInfo.IsPlayerInChromieTime() then
        return ns.Constants.PHASE_MODES.CHROMIE
    end

    local mapId = C_Map.GetBestMapForUnit("player")
    if mapId and ns.TravelRegions then
        local resolved = ns.TravelRegions:ResolveZoneMapId(mapId)
        if resolved and ns.TravelRegions:IsMidnightMap(resolved) then
            return "midnight"
        end
    end

    return ns.Constants.PHASE_MODES.RETAIL
end

function PlayerContext:DestinationAvailable(dest)
    if not dest or not dest.phaseRules then
        return true, nil
    end

    local ctx = self:Snapshot()
    local rules = dest.phaseRules

    if rules.chromieOnly and ctx.phaseMode ~= ns.Constants.PHASE_MODES.CHROMIE then
        return false, "chromie"
    end
    if rules.retailOnly and ctx.phaseMode == ns.Constants.PHASE_MODES.CHROMIE then
        return false, "chromie"
    end
    if rules.questId and not C_QuestLog.IsQuestFlaggedCompleted(rules.questId) then
        return false, "quest"
    end

    return true, nil
end

function PlayerContext:GetPhaseWarning(dest)
    local ok, _ = self:DestinationAvailable(dest)
    if ok then
        return nil
    end
    return LibStub("AceLocale-3.0"):GetLocale("WowGPS", true).PHASE_WARNING
end
