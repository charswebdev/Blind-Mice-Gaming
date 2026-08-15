--[[
  AllQuest — namespace
  Author: Blind Mice Gaming
  Lua 5.1 only.
]]

local addonName = ...

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.addonName = addonName
AQ.version = "1.0.0"
AQ.title = "AllQuest"
AQ.Logo = "Interface\\AddOns\\AllQuest\\Media\\AllQuestLogo"

local MEDIA = "Interface\\AddOns\\AllQuest\\Media\\"
AQ.Media = {
    Icons = {
        Home = MEDIA .. "Icons\\Home",
        Back = MEDIA .. "Icons\\Back",
        Close = MEDIA .. "Icons\\Close",
        Search = MEDIA .. "Icons\\Search",
        Grid = MEDIA .. "Icons\\Grid",
        List = MEDIA .. "Icons\\List",
        Here = MEDIA .. "Icons\\Here",
    },
    Covers = {
        [0] = MEDIA .. "Covers\\Classic",
        [1] = MEDIA .. "Covers\\TBC",
        [2] = MEDIA .. "Covers\\Wrath",
        [3] = MEDIA .. "Covers\\Cata",
        [4] = MEDIA .. "Covers\\MoP",
        [5] = MEDIA .. "Covers\\WoD",
        [6] = MEDIA .. "Covers\\Legion",
        [7] = MEDIA .. "Covers\\BFA",
        [8] = MEDIA .. "Covers\\Shadowlands",
        [9] = MEDIA .. "Covers\\Dragonflight",
        [10] = MEDIA .. "Covers\\TWW",
        [11] = MEDIA .. "Covers\\Midnight",
    },
    Zones = {},
}

function AQ.CoverTexture(expansionID, categoryID)
    if categoryID and AQ.Media.Zones and AQ.Media.Zones[categoryID] then
        return AQ.Media.Zones[categoryID]
    end
    return (AQ.Media.Covers[expansionID] or AQ.Logo)
end

function AQ:Print(msg)
    if type(msg) ~= "string" then
        msg = tostring(msg)
    end
    print("|cffffeb66[AllQuest]|r " .. msg)
end

function AQ:SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then
        return nil
    end
    return a, b, c, d, e
end

function AQ:Trim(s)
    if type(s) ~= "string" then
        return ""
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function AQ:StripMarkup(s)
    s = AQ:Trim(s)
    if s == "" then
        return ""
    end
    s = s:gsub("|T.-|t", " ")
    s = s:gsub("|A.-|a", " ")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    s = s:gsub("|H.-|h(.-)|h", "%1")
    s = s:gsub("|n", " ")
    s = s:gsub("%s+", " ")
    return AQ:Trim(s)
end

function AQ:AddonLoaded(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        return ok and loaded and true or false
    end
    if IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, name)
        return ok and loaded and true or false
    end
    return _G[name] ~= nil
end
