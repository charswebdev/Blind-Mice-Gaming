--[[
  AllQuest Shadowlands data pack
  Author: Blind Mice Gaming
  Lua 5.1 only.
]]

local AQ = AllQuest
if not AQ or not AQ.Data then
    return
end

AQ.Data:AddExpansion({
    id = 8,
    name = "Shadowlands",
})
