local addon = Exploration

addon.Overlay = addon.Overlay or {}

function addon.Overlay:Init()
    addon:InitializeWorldMapOverlay()
    addon:InitializeMinimapOverlay()
end

function addon.Overlay:Refresh()
    addon:RefreshWorldMapOverlay()
    addon:RefreshMinimapOverlay()
end
