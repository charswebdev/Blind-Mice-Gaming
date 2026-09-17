--[[
  BMG Unit Frames — shared anchors for icons and text
  Lua 5.1 only.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.Pos = UF.Pos or {}
local Pos = UF.Pos

Pos.OPTIONS = {
    { id = "TOPLEFT", label = "Top left" },
    { id = "TOP", label = "Top" },
    { id = "TOPRIGHT", label = "Top right" },
    { id = "LEFT", label = "Left" },
    { id = "CENTER", label = "Center" },
    { id = "RIGHT", label = "Right" },
    { id = "BOTTOMLEFT", label = "Bottom left" },
    { id = "BOTTOM", label = "Bottom" },
    { id = "BOTTOMRIGHT", label = "Bottom right" },
}

Pos.ALIGN = {
    { id = "LEFT", label = "Left" },
    { id = "CENTER", label = "Center" },
    { id = "RIGHT", label = "Right" },
}

Pos.CAST_ATTACH = {
    { id = "BELOW", label = "Below frame" },
    { id = "ABOVE", label = "Above frame" },
    { id = "INSIDE", label = "Inside bottom" },
    { id = "FREE", label = "Free (drag to move)" },
}

local INSET = {
    TOPLEFT = { 3, -3 },
    TOP = { 0, 4 },
    TOPRIGHT = { -3, -3 },
    LEFT = { 3, 0 },
    CENTER = { 0, 0 },
    RIGHT = { -3, 0 },
    BOTTOMLEFT = { 3, 3 },
    BOTTOM = { 0, 3 },
    BOTTOMRIGHT = { -3, 3 },
}

function Pos.Normalize(p)
    if type(p) == "string" then
        p = string.upper(p)
        if INSET[p] then
            return p
        end
    end
    return "CENTER"
end

function Pos.Apply(region, parent, point, size)
    if not region then
        return
    end
    point = Pos.Normalize(point)
    local xy = INSET[point] or { 0, 0 }
    region:ClearAllPoints()
    if size then
        region:SetSize(size, size)
    end
    region:SetPoint(point, parent or region:GetParent(), point, xy[1], xy[2])
end

function Pos.ApplyText(fs, parent, point)
    if not fs or not parent then
        return
    end
    point = Pos.Normalize(point)
    fs:ClearAllPoints()
    if point == "LEFT" or point == "TOPLEFT" or point == "BOTTOMLEFT" then
        fs:SetJustifyH("LEFT")
    elseif point == "RIGHT" or point == "TOPRIGHT" or point == "BOTTOMRIGHT" then
        fs:SetJustifyH("RIGHT")
    else
        fs:SetJustifyH("CENTER")
    end
    local pad = 6
    if point == "TOPLEFT" or point == "TOP" or point == "TOPRIGHT" then
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, -2)
        fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -pad, -2)
    elseif point == "BOTTOMLEFT" or point == "BOTTOM" or point == "BOTTOMRIGHT" then
        fs:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", pad, 2)
        fs:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -pad, 2)
    else
        fs:SetPoint("LEFT", parent, "LEFT", pad, 0)
        fs:SetPoint("RIGHT", parent, "RIGHT", -pad, 0)
    end
    if fs.SetWordWrap then
        fs:SetWordWrap(false)
    end
end
