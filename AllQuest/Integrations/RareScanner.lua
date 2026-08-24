--[[
  AllQuest — RareScanner rares and treasures in the tracker
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.RareScanner = AQ.RareScanner or {}
AQ.RareScanner.recent = AQ.RareScanner.recent or {}

local MAX = 12
local hooked

local function RSButton()
    return _G.RARESCANNER_BUTTON
end

local function RefreshSoon()
    if AQ.Tracker and AQ.Tracker.Refresh then
        AQ.Tracker.Refresh()
    end
end

local function KindFromAtlas(atlas)
    local a = string.lower(tostring(atlas or ""))
    if a:find("loot", 1, true) or a:find("treasure", 1, true) or a:find("chest", 1, true) or a:find("object", 1, true) then
        return "treasure"
    end
    if a:find("event", 1, true) then
        return "treasure"
    end
    return "rare"
end

local function Push(title, mapID, x, y, atlas, entityID)
    if type(title) ~= "string" or title == "" then
        return
    end
    local kind = KindFromAtlas(atlas)
    local key = tostring(entityID or title) .. ":" .. kind
    local list = {}
    list[1] = {
        id = entityID,
        key = key,
        title = title,
        mapID = mapID,
        x = x,
        y = y,
        kind = kind,
        atlas = atlas,
    }
    for i = 1, #AQ.RareScanner.recent do
        if AQ.RareScanner.recent[i].key ~= key then
            list[#list + 1] = AQ.RareScanner.recent[i]
        end
        if #list >= MAX then
            break
        end
    end
    AQ.RareScanner.recent = list
    RefreshSoon()
end

local function CaptureButton()
    local btn = RSButton()
    if not btn then
        return
    end
    Push(btn.name, btn.mapID, btn.x, btn.y, btn.atlasName, btn.entityID)
end

local function HookButton()
    local btn = RSButton()
    if hooked or not btn then
        return
    end
    hooked = true
    if type(btn.ShowButton) == "function" then
        hooksecurefunc(btn, "ShowButton", CaptureButton)
    end
    if btn.HookScript then
        pcall(btn.HookScript, btn, "OnHide", RefreshSoon)
        pcall(btn.HookScript, btn, "OnShow", CaptureButton)
    end
    if btn:IsShown() then
        CaptureButton()
    end
end

function AQ.RareScanner.EnsureHook()
    HookButton()
end

function AQ.RareScanner.GetRecent()
    return AQ.RareScanner.recent
end

AQ:RegisterPlugin({
    id = "RareScanner",
    kind = "integration",
    label = "RareScanner",
    optionalAddon = "RareScanner",
    onEnable = function()
        HookButton()
        AQ:Print("RareScanner: detected rares and treasures appear in the AllQuest tracker.")
        RefreshSoon()
    end,
})
