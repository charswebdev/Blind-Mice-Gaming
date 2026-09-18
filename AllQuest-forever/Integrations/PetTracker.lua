--[[
  AllQuest — optional PetTracker coexistence
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local hooked

local function HideObjectives()
    if PetTracker and PetTracker.Objectives and PetTracker.Objectives.Hide then
        pcall(PetTracker.Objectives.Hide, PetTracker.Objectives)
    end
end

AQ:RegisterPlugin({
    id = "PetTracker",
    kind = "integration",
    optionalAddon = "PetTracker",
    onEnable = function()
        HideObjectives()
        if not hooked and PetTracker and PetTracker.Objectives and PetTracker.Objectives.Update then
            hooked = true
            hooksecurefunc(PetTracker.Objectives, "Update", function(self)
                if AQ.Plugins and AQ.Plugins.IsEnabled("PetTracker") then
                    pcall(self.Hide, self)
                end
            end)
        end
        AQ:Print("PetTracker: zone pets now appear in the AllQuest tracker.")
        if AQ.Tracker and AQ.Tracker.Refresh then
            AQ.Tracker.Refresh()
        end
    end,
    onDisable = function()
        if PetTracker and PetTracker.Objectives and PetTracker.Objectives.Show then
            pcall(PetTracker.Objectives.Show, PetTracker.Objectives)
            if PetTracker.Objectives.Update then
                pcall(PetTracker.Objectives.Update, PetTracker.Objectives)
            end
        end
    end,
})
