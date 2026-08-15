--[[
  AllQuest Classic — Elwynn Forest questlines
  Original grouping of public quest IDs. Lua 5.1 only.
]]

local AQ = AllQuest
if not AQ or not AQ.Data then
    return
end

AQ.Data:AddChain({
    id = 100101,
    category = 1001,
    expansion = 0,
    name = "Northshire Abbey",
    major = true,
    restrictions = { faction = "Alliance" },
    prerequisites = { { type = "level", min = 1 } },
    nodes = {
        { id = 1, type = "quest", questID = 783, next = { 2 } },
        { id = 2, type = "quest", questID = 5261, next = { 3 } },
        { id = 3, type = "quest", questID = 33, next = { 4 } },
        { id = 4, type = "quest", questID = 7, next = { 5 } },
        { id = 5, type = "quest", questID = 15, next = { 6 } },
        { id = 6, type = "quest", questID = 21, next = { 7 } },
        { id = 7, type = "quest", questID = 54, next = {} },
    },
})

AQ.Data:AddChain({
    id = 100102,
    category = 1001,
    expansion = 0,
    name = "Goldshire and the Mines",
    major = true,
    restrictions = { faction = "Alliance" },
    prerequisites = {
        { type = "level", min = 4 },
        { type = "chain", id = 100101 },
    },
    nodes = {
        { id = 1, type = "quest", questID = 62, next = { 2 } },
        { id = 2, type = "quest", questID = 76, next = {} },
        { id = 3, type = "quest", questID = 40, next = { 4 } },
        { id = 4, type = "quest", questID = 35, next = { 5 } },
        { id = 5, type = "quest", questID = 37, next = { 6 } },
        { id = 6, type = "quest", questID = 45, next = { 7 } },
        { id = 7, type = "quest", questID = 71, next = { 8 } },
        { id = 8, type = "quest", questID = 39, next = {} },
        { id = 9, type = "quest", questID = 239, next = { 10 } },
        { id = 10, type = "quest", questID = 11, next = {} },
    },
})
