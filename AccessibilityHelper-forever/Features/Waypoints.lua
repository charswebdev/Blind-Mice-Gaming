--[[
  Accessibility Helper — TomTom / Zygor waypoint reads (Phase 5)
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Waypoints = AH.Waypoints or {}
local Waypoints = AH.Waypoints

local function Strip(s)
    if type(s) ~= "string" then
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

local function FsText(fs)
    if not fs or not fs.GetText then
        return ""
    end
    local ok, t = pcall(function()
        return fs:GetText()
    end)
    if not ok then
        return ""
    end
    return Strip(t)
end

local function Say(msg)
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_NAV)
    else
        print("|cff66ccff[Helper]|r " .. tostring(msg))
    end
end

local function AddonLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        return ok and loaded and true or false
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded(name) and true or false
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

--- Build spoken line from TomTom crazy arrow UI.
function Waypoints.ReadTomTom()
    if AH.Speech and AH.Speech.ClearNavQueue then
        AH.Speech.ClearNavQueue()
    end
    if not TomTomEnabled() then
        Say("TomTom reading is disabled.")
        return
    end
    if not AddonLoaded("TomTom") and not TomTom then
        Say("TomTom is not loaded.")
        return
    end

    local arrow = TomTomCrazyArrow
    if not arrow then
        Say("TomTom arrow is not available.")
        return
    end

    local shown = false
    pcall(function()
        shown = arrow:IsShown() and true or false
    end)
    if TomTom.IsCrazyArrowEmpty and TomTom:IsCrazyArrowEmpty() then
        Say("No TomTom waypoint is active.")
        return
    end
    if not shown then
        -- Still try to read text if empty check passed but frame hidden briefly.
        local title = FsText(arrow.title)
        if title == "" then
            Say("TomTom arrow is hidden.")
            return
        end
    end

    local title = FsText(arrow.title)
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

--- Build spoken line from Zygor Guides arrow UI / waypoint data.
function Waypoints.ReadZygor()
    if AH.Speech and AH.Speech.ClearNavQueue then
        AH.Speech.ClearNavQueue()
    end
    if not ZygorEnabled() then
        Say("Zygor reading is disabled.")
        return
    end
    if not AddonLoaded("ZygorGuidesViewer") and not (ZGV or ZygorGuidesViewer) then
        Say("Zygor Guides is not loaded.")
        return
    end

    local Z = ZGV or ZygorGuidesViewer
    local pointer = Z and Z.Pointer
    local arrow = pointer and pointer.ArrowFrame

    -- Prefer live FontStrings on the arrow frame.
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

        -- Fallback: waypoint object on the arrow.
        local way = arrow.waypoint
        if type(way) == "table" then
            local parts = {}
            local wtitle = Strip(way.title or way.tooltipText or way.goaltext or "")
            if wtitle ~= "" then
                parts[#parts + 1] = wtitle
            end
            if way.dist and type(way.dist) == "number" and Z.FormatDistance then
                local ok, dtxt = pcall(Z.FormatDistance, way.dist)
                if ok and type(dtxt) == "string" and dtxt ~= "" then
                    parts[#parts + 1] = Strip(dtxt)
                else
                    parts[#parts + 1] = string.format("%d yards", math.floor(way.dist + 0.5))
                end
            elseif way.dist and type(way.dist) == "number" then
                parts[#parts + 1] = string.format("%d yards", math.floor(way.dist + 0.5))
            end
            if #parts > 0 then
                Say(table.concat(parts, ". ") .. ".")
                return
            end
        end
    end

    -- Destination waypoint fallback.
    if pointer and type(pointer.DestinationWaypoint) == "table" then
        local way = pointer.DestinationWaypoint
        local wtitle = Strip(way.title or way.tooltipText or "")
        if wtitle ~= "" then
            Say(wtitle .. ".")
            return
        end
    end

    Say("No Zygor waypoint arrow text found.")
end
