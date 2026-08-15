--[[
  Manual overlay for Midnight.
  Branches side/sub quests that the linear QuestLine extract cannot see.
]]

local AQ = AllQuest
if not AQ or not AQ.Data then
    return
end

-- The Light's Summons: story spine with parallel side quests, then converge.
AQ.Data:AddChain({
    id = 1190026,
    category = 11911,
    expansion = 11,
    name = "The Light's Summons",
    major = true,
    prerequisites = { { type = "level", min = 80 } },
    nodes = {
        { id = 1, type = "quest", questID = 91281, x = 0, next = { 2 } },
        { id = 2, type = "quest", questID = 88719, x = 0, next = { 3 } },
        { id = 3, type = "quest", questID = 86769, x = 0, next = { 4, 5, 6 } },
        { id = 4, type = "quest", questID = 86770, x = -2, next = { 7, 8 } },
        { id = 5, type = "quest", questID = 89271, next = { 7, 8 } },
        { id = 6, type = "quest", questID = 86780, next = { 7, 8 } },
        { id = 7, type = "quest", questID = 86805, x = -1, next = { 9 } },
        { id = 8, type = "quest", questID = 89012, next = { 9 } },
        { id = 9, type = "quest", questID = 86806, x = 0, next = { 10 } },
        { id = 10, type = "quest", questID = 86807, x = 0, next = { 11, 12 } },
        { id = 11, type = "quest", questID = 91274, x = -1, next = { 13, 14 } },
        { id = 12, type = "quest", questID = 86834, next = { 13, 14 } },
        { id = 13, type = "quest", questID = 86811, x = -1, next = { 15 } },
        { id = 14, type = "quest", questID = 86848, next = { 15 } },
        { id = 15, type = "quest", questID = 86849, x = 0, next = { 16 } },
        { id = 16, type = "quest", questID = 86850, x = 0, next = { 17 } },
        { id = 17, type = "quest", questID = 86852, x = 0, next = {} },
    },
})
