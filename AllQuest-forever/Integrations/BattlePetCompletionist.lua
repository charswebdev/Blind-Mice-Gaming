--[[
  AllQuest — optional Battle Pet Completionist coexistence
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ:RegisterPlugin({
    id = "BattlePetCompletionist",
    kind = "integration",
    optionalAddon = "BattlePetCompletionist",
    onEnable = function()
        AQ:Print("Battle Pet Completionist: zone pets appear in the AllQuest tracker when PetTracker is off.")
        if AQ.Tracker and AQ.Tracker.Refresh then
            AQ.Tracker.Refresh()
        end
    end,
})
