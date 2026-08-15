--[[
  AllQuest overlay format (manual story grouping)

  Overlay files run after Generated.lua. Use them to:
    * rename auto-chains
    * mark major vs side
    * add breadcrumbs / faction restrictions
    * splice branches the extractor cannot see

  Example (do not copy other addons' graphs):

  AllQuest.Data:AddChain({
      id = 100199,
      category = 1001,
      expansion = 0,
      name = "Story title you wrote",
      major = true,
      restrictions = { faction = "Alliance" },
      prerequisites = {
          { type = "level", min = 5 },
          { type = "quest", questID = 54 },
          { type = "chain", id = 100101 },
      },
      nodes = {
          { id = 1, type = "quest", questID = 109, next = { 2 } },
          { id = 2, type = "quest", questID = 112, next = {} },
      },
  })

  In-game: /aqdebug record while playing, then fold notes into an overlay.
]]
