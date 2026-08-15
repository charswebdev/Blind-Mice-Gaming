--[[
  AllQuest Classic data — expansion + zones
  Original Blind Mice Gaming packaging. Quest IDs are game data.
  Lua 5.1 only.
]]

local AQ = AllQuest
if not AQ or not AQ.Data then
    return
end

AQ.Data:AddExpansion({
    id = 0,
    name = "Classic",
})

AQ.Data:AddCategory({
    id = 1001,
    expansion = 0,
    name = "Elwynn Forest",
})

AQ.Data:AddCategory({
    id = 1002,
    expansion = 0,
    name = "Durotar",
})
