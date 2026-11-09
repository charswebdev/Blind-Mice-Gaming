local _, LPL = ...

local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
if not ldb then
    return
end

local function ToggleWindow()
    if LPL_ToggleMainFrame then
        LPL_ToggleMainFrame()
    end
end

-- The id has no spaces. Titan turns the id into a frame name, and a space in that
-- name leaves a bar button that is visible but does not receive the click.
-- The label is the name shown next to the icon.
local obj = ldb:NewDataObject("LPLForever", {
    type = "launcher",
    tocname = "lpl-forever",
    icon = "Interface\\AddOns\\lpl-forever\\icons\\lpl_32.blp",
    label = "Light Paws Loadouts",
    text = "Light Paws Loadouts",
    OnClick = function(_, button)
        if button == "RightButton" then
            return
        end
        ToggleWindow()
    end,
    OnTooltipShow = function(tip)
        if not tip or not tip.AddLine then
            return
        end
        tip:AddLine("Light Paws Loadouts", 1, 0.82, 0)
        tip:AddLine("Click the icon or the name to open or close.", 0.8, 0.8, 0.8)
    end,
})

local function TitanButton()
    if TitanUtils_GetButton then
        local button = TitanUtils_GetButton("LPLForever")
        if button then
            return button
        end
    end
    return _G["TitanPanelLPLForeverButton"]
end

local function HookTitanButton()
    local button = TitanButton()
    if not button or button.lplClick then
        return
    end
    button.lplClick = true
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            if Titan_G and Titan_G.plugins and Titan_G.plugins.OnClick then
                Titan_G.plugins.OnClick(self, mouseButton)
            end
            return
        end
        ToggleWindow()
    end)
    local icon = _G[button:GetName() .. "Icon"]
    if icon then
        icon:SetWidth(16)
        icon:Show()
    end
    if (button:GetWidth() or 0) < 16 then
        button:SetWidth(16)
    end
end

if obj then
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_LOGIN")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" and name ~= "Titan" and name ~= "lpl-forever" then
            return
        end
        HookTitanButton()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, HookTitanButton)
            C_Timer.After(1, HookTitanButton)
        end
    end)
end
