--[[
  AllQuest — conflict warning for Kaliel's Tracker
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local function Has(name)
    return AQ:AddonLoaded(name)
end

local function WarnOnce()
    local db = AQ.DB.Get()
    if db.seenConflictWarning then
        return
    end
    if not (Has("!KalielsTracker") or Has("KalielsTracker")) then
        return
    end
    db.seenConflictWarning = true
    local msg = "AllQuest hides the Blizzard tracker. Disable Kaliel's Tracker to avoid two trackers fighting."
    AQ:Print(msg)
    AQ.Speech.Say(msg)
    StaticPopupDialogs = StaticPopupDialogs or {}
    StaticPopupDialogs["ALLQUEST_CONFLICT"] = {
        text = msg,
        button1 = "OK",
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }
    if StaticPopup_Show then
        pcall(StaticPopup_Show, "ALLQUEST_CONFLICT")
    end
end

AQ:RegisterPlugin({
    id = "Conflicts",
    kind = "integration",
    onEnable = function()
        WarnOnce()
    end,
})
