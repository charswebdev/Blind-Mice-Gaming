--[[
  AllQuest Battle for Azeroth data pack
  Author: Blind Mice Gaming
  Lua 5.1 only.
]]

local AQ = AllQuest
if not AQ or not AQ.Data then
    return
end

AQ.Data:AddExpansion({
    id = 7,
    name = "Battle for Azeroth",
})
