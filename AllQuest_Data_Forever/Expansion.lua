--[[
  AllQuest WoW Forever data pack
  Author: Blind Mice Gaming
  Lua 5.1 only.

  Expansion id 60 is a BMG journal id (client 1.60). It is not Midnight (11)
  and not Classic Era (0). Do not load those packs on Forever.
]]

local AQ = AllQuest
if not AQ or not AQ.Data then
    return
end

AQ.Data:AddExpansion({
    id = 60,
    name = "WoW Forever",
})
