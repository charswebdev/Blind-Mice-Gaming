--[[
  AllQuest — hide Blizzard WatchFrame / ObjectiveTrackerFrame
  Custom tracker only. No mixin replacement, no taint hacks.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.HideBlizzard = AQ.HideBlizzard or {}
local HB = AQ.HideBlizzard

local hooked = {}

local CANDIDATES = {
    "ObjectiveTrackerFrame",
    "WatchFrame",
    "QuestWatchFrame",
    "QuestTimerFrame",
}

local function HideFrame(f)
    if not f then
        return
    end
    pcall(f.Hide, f)
    if f.SetAlpha then
        pcall(f.SetAlpha, f, 0)
    end
    if f.EnableMouse then
        pcall(f.EnableMouse, f, false)
    end
end

local function Hook(name)
    local f = _G[name]
    if not f or hooked[name] then
        return
    end
    hooked[name] = true
    if f.HookScript then
        pcall(f.HookScript, f, "OnShow", function(self)
            if AQ.DB.Get().hideBlizzardTracker ~= false then
                HideFrame(self)
            end
        end)
    end
end

function HB.Apply()
    local hide = AQ.DB.Get().hideBlizzardTracker ~= false
    for i = 1, #CANDIDATES do
        local name = CANDIDATES[i]
        Hook(name)
        local f = _G[name]
        if f then
            if hide then
                HideFrame(f)
            else
                if f.SetAlpha then
                    pcall(f.SetAlpha, f, 1)
                end
                if f.EnableMouse then
                    pcall(f.EnableMouse, f, true)
                end
            end
        end
    end
end
