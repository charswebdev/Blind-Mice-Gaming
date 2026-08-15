-- Explore achievement import disabled: fog pins clear only on Discover toast
-- (or Mark Discovered). Pre-clearing from Explore criteria marked stops done
-- before XP fired, which fights the leveling-via-Discover goal.

local addon = Exploration

function addon:ImportExploreAchievementsForCharacter()
    local saved = addon:GetCharacterProgress(false)
    if saved then
        saved.exploreCriterionNames = nil
        saved.exploreAreaIDs = nil
    end
    return 0
end
