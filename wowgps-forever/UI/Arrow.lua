local _, GPS = ...

GPS.Arrow = GPS.Arrow or {}
local Arrow = GPS.Arrow

function Arrow:Init()
    if self.frame then
        return
    end
    local frame = CreateFrame("Frame", "WowGPSForeverArrow", UIParent)
    frame:SetSize(64, 64)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:Hide()

    frame.arrow = frame:CreateTexture(nil, "ARTWORK")
    frame.arrow:SetSize(52, 52)
    frame.arrow:SetPoint("CENTER")
    frame.arrow:SetTexture("Interface\\Minimap\\Minimap-Arrow")

    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.label:SetPoint("TOP", frame, "BOTTOM", 0, -4)
    frame.label:SetWidth(280)
    frame.label:SetJustifyH("CENTER")
    frame.label:SetTextColor(0.95, 0.95, 0.95)

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(selfFrame, elapsed)
        local step = GPS:PlainNumber(elapsed) or 0
        selfFrame.elapsed = selfFrame.elapsed + step
        if selfFrame.elapsed < 0.1 then
            return
        end
        selfFrame.elapsed = 0
        Arrow:Update()
    end)
    self.frame = frame
end

function Arrow:Show(dest)
    self:Init()
    self.dest = dest
    self.frame.label:SetText(dest and dest.name or "")
    self.frame:Show()
    self:Update()
end

function Arrow:Hide()
    self.dest = nil
    if self.frame then
        self.frame:Hide()
    end
end

function Arrow:Update()
    local frame = self.frame
    local dest = self.dest
    if not frame or not dest or not frame:IsShown() then
        return
    end
    local here = GPS.Here and GPS.Here:Read()
    if not here or here.mapId ~= dest.mapId or not here.x or not here.y then
        frame.arrow:SetRotation(0)
        return
    end
    local east = dest.x - here.x
    local north = here.y - dest.y
    local bearing = math.atan2(east, north)
    local facing
    if type(GetPlayerFacing) == "function" then
        local ok, value = pcall(GetPlayerFacing)
        if ok then
            facing = GPS:PlainNumber(value)
        end
    end
    if facing then
        frame.arrow:SetRotation(bearing - facing)
    else
        frame.arrow:SetRotation(bearing)
    end
end
