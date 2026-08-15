--[[
  AllQuest Classic — Durotar questlines
  Original grouping of public quest IDs. Lua 5.1 only.
]]

local AQ = AllQuest
if not AQ or not AQ.Data then
    return
end

AQ.Data:AddChain({
    id = 100201,
    category = 1002,
    expansion = 0,
    name = "Valley of Trials",
    major = true,
    restrictions = { faction = "Horde" },
    prerequisites = { { type = "level", min = 1 } },
    nodes = {
        { id = 1, type = "quest", questID = 4641, next = { 2 } },
        { id = 2, type = "quest", questID = 788, next = { 3 } },
        { id = 3, type = "quest", questID = 789, next = { 4 } },
        { id = 4, type = "quest", questID = 790, next = { 5 } },
        { id = 5, type = "quest", questID = 792, next = { 6 } },
        { id = 6, type = "quest", questID = 794, next = { 7 } },
        { id = 7, type = "quest", questID = 805, next = {} },
    },
})
