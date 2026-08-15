local addonName = "Exploration"

_G["BINDING_NAME_CLICK ExplorationGoPreviousButton:LeftButton"] = "Previous Step"
_G["BINDING_NAME_CLICK ExplorationGoNextButton:LeftButton"] = "Next step"
_G["BINDING_NAME_CLICK ExplorationPrevZoneButton:LeftButton"] = "Previous Segment"
_G["BINDING_NAME_CLICK ExplorationNextZoneButton:LeftButton"] = "Next Segment"
_G["BINDING_NAME_CLICK ExplorationMarkDiscoveredButton:LeftButton"] = "Mark Discovered"
_G["BINDING_NAME_CLICK ExplorationAbandonButton:LeftButton"] = "Abandon"
_G["BINDING_NAME_CLICK ExplorationActionButton:LeftButton"] = "Action Button"

Exploration = Exploration or {}
local addon = Exploration

addon.VERSION = "2.0.0"
addon.ICON = "Interface\\AddOns\\Exploration\\Textures\\compass.tga"
addon.active = nil
addon.segment = { route = {} }
addon.waypoint = { index = nil, arrow = nil }

function addon:DefaultDB()
    return {
        version = addon.VERSION,
        routes = ExplorationRoutesData or {},
        progress = {},
        account = { learnedWaypoints = {}, learnedRouteInserts = {}, coordAdjustments = {} },
        settings = {
            tts = false,
            tomtom = "auto",
            pins = "auto",
            mapOverlay = true,
            autoTaxi = true,
            frameLocked = false,
            nearestUndiscovered = false,
        },
        note = {
            visible = true,
            anchor = "TOP",
            relative = "TOP",
            x = 0,
            y = -140,
        },
        ui = {},
    }
end

function addon:Initialize()
    if not ExplorationDB then
        ExplorationDB = self:DefaultDB()
    end
    ExplorationDB.routes = ExplorationRoutesData or ExplorationDB.routes or {}
    ExplorationDB.progress = ExplorationDB.progress or {}
    ExplorationDB.account = ExplorationDB.account or { learnedWaypoints = {} }
    ExplorationDB.account.learnedWaypoints = ExplorationDB.account.learnedWaypoints or {}
    ExplorationDB.account.learnedRouteInserts = ExplorationDB.account.learnedRouteInserts or {}
    ExplorationDB.account.coordAdjustments = ExplorationDB.account.coordAdjustments or {}
    ExplorationDB.settings = ExplorationDB.settings or self:DefaultDB().settings
    ExplorationDB.settings.frameLocked = ExplorationDB.settings.frameLocked == true
    if ExplorationDB.settings.autoTaxi == nil then
        ExplorationDB.settings.autoTaxi = true
    end
    if ExplorationDB.settings.nearestUndiscovered == nil then
        ExplorationDB.settings.nearestUndiscovered = false
    end
    ExplorationDB.note = ExplorationDB.note or self:DefaultDB().note
    ExplorationDB.ui = ExplorationDB.ui or {}
    addon.data = ExplorationDB

    if addon.MigrateLegacyProgress then
        addon:MigrateLegacyProgress()
    end

    addon.menu = addon.processRoutes(addon.data.routes)
    if addon.MigrateCuratedRouteRevisions then
        addon:MigrateCuratedRouteRevisions()
    end
    local merged = addon:BackfillLearnedRouteInserts()
    if merged > 0 then
        print("|cff00ccffExploration:|r Merged " .. merged .. " previously discovered location(s) into your routes.")
    end
    local relocated = addon:MigrateLearnedInsertsOffTravelSegments()
    if relocated > 0 then
        print("|cff00ccffExploration:|r Moved " .. relocated .. " Harandar stop(s) from travel segments back to exploration routes.")
    end
    local purged = 0
    if addon.PurgeZoneTitleLearnedInserts then
        purged = addon:PurgeZoneTitleLearnedInserts()
    end
    if purged > 0 then
        print("|cff00ccffExploration:|r Removed " .. purged .. " zone-title pin(s) that were blocking discovery clears.")
    end
    -- Dense curated routes: purgeLearned = true on the route (Gate 1).
    -- Run before and after coord backfill so autodug Quel'Danas/Midnight nudges cannot stick.
    local wiped = 0
    if addon.PurgeFlaggedRouteLearning then
        wiped = wiped + (addon:PurgeFlaggedRouteLearning() or 0)
    end
    if addon.PurgeInvalidLearnedInserts then
        wiped = wiped + (addon:PurgeInvalidLearnedInserts() or 0)
    end
    local adjusted = addon:BackfillCoordAdjustments()
    if addon.PurgeStaleCoordAdjustments then
        wiped = wiped + (addon:PurgeStaleCoordAdjustments() or 0)
    end
    if addon.PurgeFlaggedRouteLearning then
        wiped = wiped + (addon:PurgeFlaggedRouteLearning() or 0)
    end
    if wiped > 0 then
        print("|cff00ccffExploration:|r Cleared " .. wiped .. " outdated pin adjust/insert(s).")
    end
    if adjusted > 0 then
        print("|cff00ccffExploration:|r Updated " .. adjusted .. " route pin(s) from your discovery positions.")
    end
    if addon.ui and addon.ui.Initialize then
        addon.ui:Initialize()
    end
    addon:InitializeNoteFrame()
    addon:InitMinimapButton()
    if addon.Overlay and addon.Overlay.Init then
        addon.Overlay:Init()
    end
    addon:RegisterDiscoveryEvents()
    addon:RegisterTaxiEvents()

    if addon.MigrateLegacyProgress then
        addon:MigrateLegacyProgress()
    end
    addon:ClearTomTomWaypoints()
    addon:TryResumeProgress()
end

function addon:TryResumeProgress()
    -- Never keep a runtime journey that isn't backed by this character's slot.
    if addon.active and not addon:HasSavedActiveJourney() then
        if addon.ParkActiveJourney then
            addon:ParkActiveJourney()
        else
            addon.active = nil
            addon.waypoint.index = nil
        end
    end
    if addon.active then return true end
    if not addon:GetCharacterID() then return false end
    if addon.MigrateLegacyProgress then
        addon:MigrateLegacyProgress()
    end

    -- Parked runs (Change) stay under Resume and must not steal the browse UI,
    -- so a fresh alt can Start without /exp abandon.
    if not (addon.ShouldAutoResumeJourney and addon:ShouldAutoResumeJourney()) then
        if addon.HasSavedActiveJourney and addon:HasSavedActiveJourney() then
            -- One quiet tip so parked progress is discoverable.
            if not addon._parkedJourneyTip then
                addon._parkedJourneyTip = true
                print("|cff00ccffExploration:|r Saved journey parked — click Resume to continue, or Start a new one.")
            end
        end
        return false
    end

    if addon:ResumeProgress() then
        if addon.SyncActiveSegmentLearnedInserts then
            addon:SyncActiveSegmentLearnedInserts()
        end
        if ExplorationFrame then
            ExplorationFrame:Show()
        end
        return true
    end
    return false
end

function addon:RebuildLearnedRoutes()
    local added = 0
    if addon.BackfillLearnedRouteInserts then
        added = addon:BackfillLearnedRouteInserts() or 0
    end
    if addon.MigrateLearnedInsertsOffTravelSegments then
        added = added + (addon:MigrateLearnedInsertsOffTravelSegments() or 0)
    end
    if addon.PurgeInvalidLearnedInserts then
        addon:PurgeInvalidLearnedInserts()
    end
    if addon.PurgeZoneTitleLearnedInserts then
        addon:PurgeZoneTitleLearnedInserts()
    end

    local mergedLive = false
    if addon.active and addon.SyncActiveSegmentLearnedInserts then
        local before = addon.segment and addon.segment.route and #addon.segment.route or 0
        addon:SyncActiveSegmentLearnedInserts()
        local after = addon.segment and addon.segment.route and #addon.segment.route or 0
        mergedLive = after > before
    end

    if addon.ui and addon.ui.SegmentFrame then
        addon.ui.SegmentFrame:Refresh()
    end
    if addon.RefreshProgressUI then
        addon:RefreshProgressUI()
    end
    if addon.SaveProgress then
        addon:SaveProgress()
    end

    return added, mergedLive
end

SLASH_EXPLORATION1 = "/exploration"
SLASH_EXPLORATION2 = "/exp"
SlashCmdList["EXPLORATION"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" or msg == "show" then
        ExplorationFrame:Show()
    elseif msg == "hide" then
        ExplorationFrame:Hide()
    elseif msg == "abandon" or msg == "clear" then
        addon:ClearActive()
    elseif msg == "rebuild" or msg == "merge" then
        local added, mergedLive = addon:RebuildLearnedRoutes()
        if added > 0 then
            print("|cff00ccffExploration:|r Rebuilt routes — added "
                .. added .. " learned location(s) into the correct zone pack(s).")
        elseif mergedLive then
            print("|cff00ccffExploration:|r Rebuilt active route from saved learned locations.")
        else
            print("|cff00ccffExploration:|r Rebuild complete — no new learned locations to add.")
            print("|cff00ccffExploration:|r Tip: only places discovered while this addon was loaded "
                .. "(SavedVariables) can be backfilled. Pre-addon explores need a rediscovery or future import.")
        end
    elseif msg == "help" then
        print("|cff00ccffExploration commands:|r")
        print("  /exp show|hide — toggle the window")
        print("  /exp abandon — clear the active route")
        print("  /exp rebuild — merge already-learned discoveries into zone routes")
        print("  /exp help — this list")
    else
        ExplorationFrame:SetShown(not ExplorationFrame:IsShown())
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_LOGOUT")
boot:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        addon:Initialize()
    elseif event == "PLAYER_LOGIN" then
        -- ADDON_LOADED can run before UnitName/realm/faction are ready; migrate,
        -- rebuild the menu with live conditions, then resume.
        if addon.data then
            if addon.MigrateLegacyProgress then
                addon:MigrateLegacyProgress()
            end
            if addon.processRoutes and addon.data.routes then
                addon.menu = addon.processRoutes(addon.data.routes)
            end
            addon:TryResumeProgress()
            if addon.ui and addon.ui.SegmentFrame and addon.ui.SegmentFrame.Refresh then
                addon.ui.SegmentFrame:Refresh()
            end
        end
    elseif event == "PLAYER_LOGOUT" then
        if addon.active and addon.SaveProgress then
            addon:SaveProgress()
        end
    end
end)
