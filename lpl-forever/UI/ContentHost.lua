local addonName, LPL = ...

LPL.ContentHost = {}

function LPL.ContentHost:Create(parent)
    local host = CreateFrame("Frame", "LPLContentHost", parent, "BackdropTemplate")
    host:SetPoint("TOPLEFT", parent.sidebar, "TOPRIGHT", 1, 0)
    host:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    LPL.Theme:ApplyBackdrop(host, "panel", "bgPrimary", "border")
    self.frame = host
    LPL.Modules:SetContentHost(host)
    return host
end
