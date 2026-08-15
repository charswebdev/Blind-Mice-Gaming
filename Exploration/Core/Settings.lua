local addon = Exploration

local L = addon.uiLayout
local frame = addon.ui.SettingsFrame

local function cycleSetting(current)
    if current == "auto" then return "enable"
    elseif current == "enable" then return "disable"
    else return "auto" end
end

local function settingLabel(name, value)
    if value == "enable" then return name .. ": On"
    elseif value == "disable" then return name .. ": Off"
    else return name .. ": Auto" end
end

function frame:Initialize()
    if frame._built then return end
    frame._built = true

    frame.context = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.context:SetPoint("TOPLEFT", frame, "TOPLEFT", L.pad, -4)
    frame.context:SetText("Settings")
    addon:StyleFont(frame.context, "accent")

    addon:HRule(frame, -L.contextH, L.pad)

    local y = -(L.contextH + 12)
    local function addButton(text, onClick)
        local btn = addon:CreateButton(frame, L.contentWidth, 24, text)
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", L.pad, y)
        btn:SetScript("OnClick", onClick)
        y = y - 28
        return btn
    end

    frame.ttsBtn = addButton("", function()
        addon.data.settings.tts = not addon.data.settings.tts
        frame:Refresh()
    end)
    frame.tomtomBtn = addButton("", function()
        addon.data.settings.tomtom = cycleSetting(addon.data.settings.tomtom or "auto")
        addon:UpdateWaypointArrow()
        frame:Refresh()
    end)
    frame.pinsBtn = addButton("", function()
        addon.data.settings.pins = cycleSetting(addon.data.settings.pins or "auto")
        addon:UpdateWaypointArrow()
        frame:Refresh()
    end)
    frame.overlayBtn = addButton("", function()
        addon.data.settings.mapOverlay = not addon.data.settings.mapOverlay
        addon:RefreshWorldMapOverlay()
        addon:RefreshMinimapOverlay()
        frame:Refresh()
    end)
    frame.noteBtn = addButton("", function()
        addon.data.note = addon.data.note or {}
        addon.data.note.visible = not addon.data.note.visible
        addon:RefreshNote()
        frame:Refresh()
    end)
    frame.autoTaxiBtn = addButton("", function()
        addon.data.settings.autoTaxi = not addon:IsAutoTaxiEnabled()
        frame:Refresh()
    end)
    frame.nearestBtn = addButton("", function()
        addon.data.settings.nearestUndiscovered = not addon:IsNearestUndiscoveredMode()
        if addon.active and addon.DetermineNextWaypoint then
            addon:DetermineNextWaypoint()
        end
        if addon.ui and addon.ui.SegmentFrame and addon.ui.SegmentFrame.Refresh then
            addon.ui.SegmentFrame:Refresh()
        end
        frame:Refresh()
        if addon:IsNearestUndiscoveredMode() then
            print("|cff00ccffExploration:|r Nearest undiscovered: On (current zone only).")
        else
            print("|cff00ccffExploration:|r Nearest undiscovered: Off (route order).")
        end
    end)
    frame.clearBtn = addButton("Clear character progress", function()
        addon:ClearActive()
        print("|cff00ccffExploration:|r Progress cleared for this character.")
    end)

    frame:Refresh()
end

function frame:Refresh()
    if not frame._built then
        frame:Initialize()
    end
    if not frame.ttsBtn then return end
    frame.ttsBtn:SetText(addon.data.settings.tts and "Text-to-speech: On" or "Text-to-speech: Off")
    frame.tomtomBtn:SetText(settingLabel("TomTom", addon.data.settings.tomtom or "auto"))
    frame.pinsBtn:SetText(settingLabel("Map pins", addon.data.settings.pins or "auto"))
    frame.overlayBtn:SetText(addon.data.settings.mapOverlay and "Route overlay: On" or "Route overlay: Off")
    local noteVisible = addon.data.note and addon.data.note.visible ~= false
    frame.noteBtn:SetText(noteVisible and "Step notes: On" or "Step notes: Off")
    frame.autoTaxiBtn:SetText(addon:IsAutoTaxiEnabled() and "Auto flight path: On" or "Auto flight path: Off")
    if frame.nearestBtn then
        frame.nearestBtn:SetText(
            addon:IsNearestUndiscoveredMode()
                and "Nearest undiscovered: On (zone)"
                or "Nearest undiscovered: Off"
        )
    end
    frame.clearBtn:SetEnabled(addon.active == nil)
end
