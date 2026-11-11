--[[
  Accessibility Helper — TomTom / Zygor arrow reads
  /ahtt and the TomTom keybind. /ahz and the Zygor keybind.
  Lua 5.1 only. No goto, no continue, no //.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Waypoints = AH.Waypoints or {}
local Waypoints = AH.Waypoints

local lastTomTomAt = 0
local lastZygorAt = 0

local function Now()
    if not GetTime then
        return 0
    end
    local ok, t = pcall(GetTime)
    if ok ~= true then
        return 0
    end
    if AH.Compat and AH.Compat.CanUseNumber and AH.Compat.CanUseNumber(t) then
        return t
    end
    if type(t) == "number" then
        return t
    end
    return 0
end

local function Plain(v)
    if AH.Compat and AH.Compat.UsableString then
        return AH.Compat.UsableString(v)
    end
    if type(v) == "string" and v ~= "" then
        return v
    end
    return nil
end

local function Strip(s)
    s = Plain(s)
    if not s then
        return ""
    end
    s = s:gsub("|T.-|t", " ")
    s = s:gsub("|A.-|a", " ")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    s = s:gsub("|H.-|h(.-)|h", "%1")
    s = s:gsub("|n", " ")
    s = s:gsub("\n", ". ")
    s = s:gsub("%s+", " ")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function FirstText(...)
    local n = select("#", ...)
    local i
    for i = 1, n do
        local s = Strip(select(i, ...))
        if s ~= "" then
            return s
        end
    end
    return ""
end

local function FsText(fs)
    if not fs or not fs.GetText then
        return ""
    end
    local ok, t = pcall(function()
        return fs:GetText()
    end)
    if ok ~= true then
        return ""
    end
    return Strip(t)
end

local function Say(msg)
    msg = Plain(msg)
    if not msg then
        return
    end
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_NAV, { noEcho = true })
    else
        print("|cff66ccff[Helper]|r " .. msg)
    end
end

local function Recent(lastAt)
    local now = Now()
    if type(lastAt) == "number" and (now - lastAt) >= 0 and (now - lastAt) < 0.4 then
        return true, now
    end
    return false, now
end

local function AddonLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded and AH.Compat and AH.Compat.SafeBool then
        return AH.Compat.SafeBool(C_AddOns.IsAddOnLoaded, name)
    end
    if IsAddOnLoaded and AH.Compat and AH.Compat.SafeBool then
        return AH.Compat.SafeBool(IsAddOnLoaded, name)
    end
    return false
end

local function TomTomEnabled()
    local sv = AH.DB and AH.DB.Get and AH.DB.Get()
    return not sv or sv.tomtomReadEnabled ~= false
end

local function ZygorEnabled()
    local sv = AH.DB and AH.DB.Get and AH.DB.Get()
    return not sv or sv.zygorReadEnabled ~= false
end

local function Yards(dist)
    if AH.Compat and AH.Compat.CanUseNumber then
        if not AH.Compat.CanUseNumber(dist) then
            return ""
        end
    elseif type(dist) ~= "number" then
        return ""
    end
    return string.format("%d yards", math.floor(dist + 0.5))
end

--- Spoken line from the TomTom crazy arrow.
function Waypoints.ReadTomTom()
    local skip, now = Recent(lastTomTomAt)
    if skip then
        return
    end
    lastTomTomAt = now
    if AH.Speech and AH.Speech.ClearNavQueue then
        AH.Speech.ClearNavQueue()
    end
    if not TomTomEnabled() then
        Say("TomTom reading is disabled.")
        return
    end
    if not AddonLoaded("TomTom") and type(TomTom) ~= "table" then
        Say("TomTom is not loaded.")
        return
    end

    local arrow = TomTomCrazyArrow
    if not arrow then
        Say("TomTom arrow is not available.")
        return
    end

    local empty = false
    if type(TomTom) == "table" and type(TomTom.IsCrazyArrowEmpty) == "function" then
        local ok, result = pcall(TomTom.IsCrazyArrowEmpty, TomTom)
        if ok == true and result == true then
            empty = true
        end
    end
    if empty then
        Say("No TomTom waypoint is active.")
        return
    end

    local shown = false
    if arrow.IsShown then
        local ok, result = pcall(arrow.IsShown, arrow)
        if ok == true and result == true then
            shown = true
        end
    end
    local title = FsText(arrow.title)
    if not shown and title == "" then
        Say("TomTom arrow is hidden.")
        return
    end

    local status = FsText(arrow.status)
    local tta = FsText(arrow.tta)
    if title == "" and status == "" and tta == "" then
        Say("No TomTom waypoint text found.")
        return
    end

    local parts = {}
    if title ~= "" then
        parts[#parts + 1] = title
    end
    if status ~= "" then
        parts[#parts + 1] = status
    end
    if tta ~= "" then
        parts[#parts + 1] = "ETA " .. tta
    end
    Say(table.concat(parts, ". ") .. ".")
end

--- Spoken line from the Zygor arrow.
function Waypoints.ReadZygor()
    local skip, now = Recent(lastZygorAt)
    if skip then
        return
    end
    lastZygorAt = now
    if AH.Speech and AH.Speech.ClearNavQueue then
        AH.Speech.ClearNavQueue()
    end
    if not ZygorEnabled() then
        Say("Zygor reading is disabled.")
        return
    end
    local guide = nil
    if type(ZGV) == "table" then
        guide = ZGV
    elseif type(ZygorGuidesViewer) == "table" then
        guide = ZygorGuidesViewer
    end
    if not AddonLoaded("ZygorGuidesViewer") and not guide then
        Say("Zygor Guides is not loaded.")
        return
    end

    local pointer = guide and guide.Pointer
    local arrow = nil
    if type(pointer) == "table" then
        arrow = pointer.ArrowFrame
    end

    if arrow then
        local title = FsText(arrow.title)
        local desc = FsText(arrow.desc)
        if title ~= "" or desc ~= "" then
            local parts = {}
            if title ~= "" then
                parts[#parts + 1] = title
            end
            if desc ~= "" then
                parts[#parts + 1] = desc
            end
            Say(table.concat(parts, ". ") .. ".")
            return
        end

        local way = arrow.waypoint
        if type(way) == "table" then
            local parts = {}
            local wtitle = FirstText(way.title, way.tooltipText, way.goaltext)
            if wtitle ~= "" then
                parts[#parts + 1] = wtitle
            end
            local yards = Yards(way.dist)
            if yards == "" and type(guide.FormatDistance) == "function" and type(way.dist) == "number" then
                local ok, dtxt = pcall(guide.FormatDistance, way.dist)
                if ok == true then
                    yards = Strip(dtxt)
                end
            end
            if yards ~= "" then
                parts[#parts + 1] = yards
            end
            if #parts > 0 then
                Say(table.concat(parts, ". ") .. ".")
                return
            end
        end
    end

    if type(pointer) == "table" and type(pointer.DestinationWaypoint) == "table" then
        local way = pointer.DestinationWaypoint
        local wtitle = FirstText(way.title, way.tooltipText)
        if wtitle ~= "" then
            Say(wtitle .. ".")
            return
        end
    end

    Say("No Zygor waypoint arrow text found.")
end

_G["BINDING_NAME_CLICK AccessibilityHelperTomTomReadBindProxy:LeftButton"] = "Read TomTom waypoint distance (TTS)"
_G["BINDING_NAME_CLICK AccessibilityHelperZygorReadBindProxy:LeftButton"] = "Read Zygor waypoint arrow (TTS)"

local function SayStub(msg)
    Say(msg)
end

local function EnsureProxy(frameName, slash, reader)
    if _G[frameName] then
        return
    end
    local btn
    local ok = pcall(function()
        btn = CreateFrame("Button", frameName, UIParent, "SecureActionButtonTemplate")
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", slash)
    end)
    if ok ~= true or not btn then
        btn = CreateFrame("Button", frameName, UIParent)
        btn:SetScript("OnClick", function()
            reader()
        end)
    end
    btn:RegisterForClicks("AnyDown")
    btn:SetSize(1, 1)
    btn:SetAlpha(0)
    btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 200)
    btn:Show()
end

SLASH_AHTOMTOM1 = "/ahtt"
SLASH_AHTOMTOM2 = "/aharrow"
SLASH_AHTOMTOM3 = "/ahtomtom"
SlashCmdList["AHTOMTOM"] = function()
    if Waypoints.ReadTomTom then
        Waypoints.ReadTomTom()
        return
    end
    SayStub("TomTom reader unavailable.")
end

SLASH_AHZYGOR1 = "/ahzygor"
SLASH_AHZYGOR2 = "/ahz"
SlashCmdList["AHZYGOR"] = function()
    if Waypoints.ReadZygor then
        Waypoints.ReadZygor()
        return
    end
    SayStub("Zygor reader unavailable.")
end

EnsureProxy("AccessibilityHelperTomTomReadBindProxy", "/ahtt", Waypoints.ReadTomTom)
EnsureProxy("AccessibilityHelperZygorReadBindProxy", "/ahz", Waypoints.ReadZygor)
