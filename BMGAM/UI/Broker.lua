local _, BMGAM = ...

local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
if not ldb then
    return
end

local function ToggleWindow()
    if BMGAM.Window and BMGAM.Window.Toggle then
        BMGAM.Window.Toggle()
    end
end

-- The id has no spaces. Titan turns the id into a frame name, and a space in that
-- name leaves a bar button that is visible but does not receive the click.
-- The label is what Titan shows in the plugin list.
local obj = ldb:NewDataObject("BMGAM", {
    type = "launcher",
    tocname = "BMGAM",
    icon = "Interface\\AddOns\\BMGAM\\Media\\Icon.tga",
    label = "BMG Alt Manager",
    text = "BMG Alt Manager",
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
        tip:AddLine("BMG Alt Manager", 0.93, 0.80, 0.44)
        tip:AddLine("Left-click: Open or close", 0.93, 0.88, 0.77)
    end,
})

local function TitanButton()
    if TitanUtils_GetButton then
        local button = TitanUtils_GetButton("BMGAM")
        if button then
            return button
        end
    end
    return _G["TitanPanelBMGAMButton"]
end

local function HookTitanButton()
    local button = TitanButton()
    if not button or button.bmgamClick then
        return
    end
    button.bmgamClick = true
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
        if event == "ADDON_LOADED" and name ~= "Titan" and name ~= "BMGAM" then
            return
        end
        HookTitanButton()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, HookTitanButton)
            C_Timer.After(1, HookTitanButton)
        end
    end)
end
