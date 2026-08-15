--[[
  AllQuest — All The Things (journal waypoints when the plugin is on)
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ:RegisterPlugin({
    id = "AllTheThings",
    kind = "integration",
    label = "All The Things",
    optionalAddon = "AllTheThings",
    onEnable = function()
        AQ:Print("All The Things: journal double-click can use ATT coordinates when Blizzard has none.")
    end,
})
