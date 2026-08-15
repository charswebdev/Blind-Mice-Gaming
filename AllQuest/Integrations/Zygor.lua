--[[
  AllQuest — Zygor Guides Viewer (journal waypoints when the plugin is on)
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ:RegisterPlugin({
    id = "ZygorGuidesViewer",
    kind = "integration",
    label = "Zygor",
    optionalAddon = "ZygorGuidesViewer",
    onEnable = function()
        AQ:Print("Zygor: journal double-click can use Zygor coordinates when Blizzard has none.")
    end,
})
