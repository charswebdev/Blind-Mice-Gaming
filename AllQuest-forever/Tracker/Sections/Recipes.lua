--[[
  AllQuest — tracked profession recipes (Retail)
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local function RecipeName(id)
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local info = AQ:SafeCall(C_TradeSkillUI.GetRecipeInfo, id)
        if type(info) == "table" and type(info.name) == "string" then
            return info.name
        end
        if type(info) == "string" then
            return info
        end
    end
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
        local sch = AQ:SafeCall(C_TradeSkillUI.GetRecipeSchematic, id, false)
        if type(sch) == "table" and type(sch.name) == "string" then
            return sch.name
        end
    end
    return "Recipe " .. tostring(id)
end

local function GetRows()
    local rows = {}
    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipesTracked) then
        return rows
    end
    local seen = {}
    local function AddList(list)
        if type(list) ~= "table" then
            return
        end
        for i = 1, #list do
            local id = list[i]
            if type(id) == "number" and not seen[id] then
                if AQ.Tracker and AQ.Tracker.IsSuppressed and AQ.Tracker.IsSuppressed("recipe", id) then
                    -- skipped
                else
                seen[id] = true
                local name = RecipeName(id)
                rows[#rows + 1] = {
                    kind = "quest",
                    title = name,
                    status = "ACTIVE",
                    recipeID = id,
                    indent = 8,
                    speech = "Recipe " .. name,
                    detail = "Recipe ID " .. tostring(id),
                }
            end
            end
        end
    end
    AddList(AQ:SafeCall(C_TradeSkillUI.GetRecipesTracked, false))
    AddList(AQ:SafeCall(C_TradeSkillUI.GetRecipesTracked, true))
    return rows
end

AQ.Tracker.RegisterSection({
    id = "recipes",
    title = "Professions",
    order = 50,
    flavor = "retail",
    GetRows = GetRows,
})

AQ.Events.Register("TRACKED_RECIPE_UPDATE", function(_, recipeID, added)
    if added and type(recipeID) == "number" and AQ.Tracker and AQ.Tracker.ClearSuppress then
        AQ.Tracker.ClearSuppress("recipe", recipeID)
    end
    if AQ.Tracker then
        AQ.Tracker.Refresh()
    end
end)
