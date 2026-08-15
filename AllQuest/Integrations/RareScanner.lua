--[[
  AllQuest — RareScanner detections in the tracker
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.RareScanner = AQ.RareScanner or {}

local hooked

local function RSButton()
    return _G.RARESCANNER_BUTTON
end

local function RefreshSoon()
    if AQ.Tracker and AQ.Tracker.Refresh then
        AQ.Tracker.Refresh()
    end
end

local function HookButton()
    local btn = RSButton()
    if hooked or not btn then
        return
    end
    hooked = true
    if type(btn.ShowButton) == "function" then
        hooksecurefunc(btn, "ShowButton", RefreshSoon)
    end
    if btn.HookScript then
        pcall(btn.HookScript, btn, "OnHide", RefreshSoon)
        pcall(btn.HookScript, btn, "OnShow", RefreshSoon)
    end
end

function AQ.RareScanner.EnsureHook()
    HookButton()
end

AQ:RegisterPlugin({
    id = "RareScanner",
    kind = "integration",
    label = "RareScanner",
    optionalAddon = "RareScanner",
    onEnable = function()
        HookButton()
        AQ:Print("RareScanner: detected rares appear in the AllQuest tracker. Left-click to target.")
        RefreshSoon()
    end,
})
