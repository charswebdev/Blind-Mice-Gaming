--[[
  Overlay schema (copy into any AllQuest_Data_*/Overlay.lua)

  Fields:
    id            unique chain id (expansion*100000 + n)
    category      category id from Expansion.lua
    expansion     0 Classic .. 11 Midnight
    name          story title (your words)
    major         true for zone story
    restrictions  { faction = "Alliance"|"Horde" }
    prerequisites { { type="level", min=n }, { type="quest", questID=n }, { type="chain", id=n } }
    nodes         ordered steps:
                  { id=n, type="quest", questID=n, next={ nextNodeId, ... }, x=column }
                  next can list several ids for side/sub quests on the same row.
                  x is an optional column (-2 left, 0 spine, 2 right), same idea as a campaign flowchart.

  Pipeline:
    1. Download QuestLine + QuestLineXQuest + Campaign CSVs:
         python AllQuest/tools/extract_chains.py --download --write-packs
       or pass --db2-dir to a folder of wago.tools CSVs.
       Classic Generated.lua is never overwritten (hand-authored chains).
    2. Optional JSON path still works: python extract_chains.py dump.json
    3. Edit Overlay.lua for story names and branches
    4. /reload in game
]]
