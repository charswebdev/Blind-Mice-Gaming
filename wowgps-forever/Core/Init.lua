local addonName, GPS = ...

local ADDON = addonName or "wowgps-forever"
local announced = false
local uiReady = false

function GPS:Print(message)
    local text = self:PlainString(message) or ""
    print("|cff33CCFFWowGPS:|r " .. text)
end

local function EnsureUI()
    if uiReady then
        return true
    end
    local ok, err = pcall(function()
        GPS.Main:Init()
    end)
    if ok then
        uiReady = true
        GPS.Main:Hide()
        return true
    end
    GPS:Print("failed to open the window: " .. tostring(err))
    return false
end

function WowGPSForever_ToggleMainFrame()
    if not EnsureUI() then
        return
    end
    GPS.Main:Toggle()
end

_G.WowGPSForever_ToggleMainFrame = WowGPSForever_ToggleMainFrame

local function Slash(message)
    local text = GPS:PlainString(message)
    if text then
        local cmd, rest = text:match("^(%S+)%s*(.*)$")
        if cmd and string.lower(cmd) == "export" then
            local text = GPS.Import and GPS.Places and GPS.Import:FormatList(GPS.Places:List())
            if not text or not GPS.ExportDialog then
                GPS:Print("No saved locations to export.")
                return
            end
            if EnsureUI() then
                GPS.Main:Show()
                GPS.Main:SelectTab("saved", false)
                GPS.ExportDialog:Show(text)
            end
            return
        end
        if cmd and string.lower(cmd) == "import" then
            if rest and rest ~= "" and GPS.Import then
                GPS.Import:Run(rest)
            elseif GPS.ImportDialog then
                if EnsureUI() then
                    GPS.Main:Show()
                    GPS.Main:SelectTab("add", false)
                    GPS.ImportDialog:Show()
                end
            end
            return
        end
        GPS:Print("Use /gps to open the window.")
        return
    end
    WowGPSForever_ToggleMainFrame()
end

SLASH_WOWGPSFOREVER1 = "/gps"
SLASH_WOWGPSFOREVER2 = "/wowgps"
SlashCmdList["WOWGPSFOREVER"] = Slash

local function Boot(countLoad)
    GPS.DB:Bind(countLoad)
    if not announced then
        announced = true
        print("|cff33CCFFWowGPS:|r v" .. GPS.VERSION .. " loaded. |cff33CCFF/gps|r")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then
            return
        end
        Boot(true)
    elseif event == "PLAYER_ENTERING_WORLD" then
        GPS.DB:Bind(false)
        if not announced then
            Boot(true)
        end
    elseif event == "PLAYER_LOGOUT" then
        GPS.DB:Bind(false)
        if GPS.Main and GPS.Main.frame then
            GPS.DB:SaveWindow(GPS.Main.frame)
        end
    end
end)

