--[[
  AllQuest — auto-quest accept/complete popups in the tracker (Kaliel-style)
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local function GetRows()
    local rows = {}
    local popups = AQ.Compat.GetAutoQuestPopUps and AQ.Compat.GetAutoQuestPopUps() or {}
    for i = 1, #popups do
        local pop = popups[i]
        local title = AQ.Compat.GetQuestTitle(pop.questID) or ("Quest " .. tostring(pop.questID))
        if pop.popupType == "OFFER" then
            rows[#rows + 1] = {
                kind = "quest",
                questID = pop.questID,
                title = title,
                status = "READY",
                popupType = "OFFER",
                speech = "Accept quest " .. title,
                detail = "Left-click to accept this quest.",
            }
        else
            rows[#rows + 1] = {
                kind = "quest",
                questID = pop.questID,
                title = title,
                status = "DONE",
                popupType = "COMPLETE",
                autoComplete = true,
                speech = "Click to complete " .. title,
                detail = "Left-click to complete this quest from the tracker.",
            }
            if AQ.AutoQuest and AQ.AutoQuest.AddClickToComplete then
                AQ.AutoQuest.AddClickToComplete(rows, pop.questID, nil, true, true)
            end
        end
    end
    return rows
end

AQ.Tracker.RegisterSection({
    id = "popups",
    title = "Ready",
    order = 5,
    flavor = "all",
    GetRows = GetRows,
})
