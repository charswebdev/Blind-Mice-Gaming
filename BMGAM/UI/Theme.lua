local _, BMGAM = ...

BMGAM.Theme = BMGAM.Theme or {}
local Theme = BMGAM.Theme

Theme.WIDTH = 1120
Theme.HEIGHT = 658
Theme.MIN_SCALE = 860 / 1120
Theme.MAX_SCALE = 1.25

function Theme.RGB(r, g, b, a)
    return r / 255, g / 255, b / 255, a or 1
end

Theme.BG = { Theme.RGB(22, 18, 15) }
Theme.PANEL = { Theme.RGB(14, 12, 10) }
Theme.GOLD = { Theme.RGB(224, 180, 74) }
Theme.GOLD_BRIGHT = { Theme.RGB(236, 204, 112) }
Theme.GOLD_DIM = { Theme.RGB(120, 90, 36) }
Theme.LINE = { Theme.RGB(90, 72, 36) }
Theme.CREAM = { Theme.RGB(236, 224, 196) }
Theme.DIM = { Theme.RGB(148, 136, 112) }
Theme.YELLOW = { Theme.RGB(255, 236, 64) }
Theme.WHITE = { 1, 1, 1, 1 }
Theme.ALLIANCE = { Theme.RGB(70, 140, 255) }
Theme.HORDE = { Theme.RGB(220, 40, 40) }

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

function Theme.Paint(frame, fill, border)
    if not frame.SetBackdrop then
        return
    end
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

function Theme.Font(object, size, color, flags)
    local font = GameFontNormal:GetFont()
    object:SetFont(font, size, flags or "")
    object:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function Theme.ApplyAtlas(texture, atlas)
    if not atlas or not texture or not texture.SetAtlas then
        return false
    end
    if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(atlas) then
        return false
    end
    texture:SetAtlas(atlas)
    return true
end

function Theme.ClassIcon(texture, classFile)
    texture:SetTexCoord(0, 1, 0, 1)
    if classFile and Theme.ApplyAtlas(texture, "classicon-" .. string.lower(classFile)) then
        return
    end
    texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    local coords = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if coords then
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    end
end

function Theme.RacePortrait(texture, raceFile, sex)
    texture:SetTexCoord(0, 1, 0, 1)
    if raceFile then
        local gender = (sex == 3) and "female" or "male"
        if Theme.ApplyAtlas(texture, "raceicon128-" .. string.lower(raceFile) .. "-" .. gender) then
            return
        end
        local sexName = (sex == 3) and "Female" or "Male"
        texture:SetTexture("Interface\\CHARACTERFRAME\\TemporaryPortrait-" .. sexName .. "-" .. raceFile)
        return
    end
    texture:SetTexture(nil)
end

function Theme.AttachScroll(scroll)
    local bar = CreateFrame("Slider", nil, scroll:GetParent())
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(8)
    bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 10, 0)
    bar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 10, 0)
    bar:SetObeyStepOnDrag(true)
    bar:SetValueStep(1)
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 0.95)
    thumb:SetSize(8, 28)
    bar:SetThumbTexture(thumb)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    local guard = false
    bar:SetScript("OnValueChanged", function(self, value)
        if guard then
            return
        end
        guard = true
        scroll:SetVerticalScroll(value or 0)
        guard = false
    end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local _, maxValue = bar:GetMinMaxValues()
        local value = bar:GetValue() - (delta * 36)
        if value < 0 then
            value = 0
        end
        if value > maxValue then
            value = maxValue
        end
        bar:SetValue(value)
    end)
    scroll.UpdateScroll = function()
        local child = scroll:GetScrollChild()
        local range = 0
        if child then
            range = (child:GetHeight() or 0) - (scroll:GetHeight() or 0)
        end
        if range < 0 then
            range = 0
        end
        bar:SetMinMaxValues(0, range)
        if bar:GetValue() > range then
            bar:SetValue(range)
        end
        if range <= 1 then
            bar:Hide()
        else
            bar:Show()
        end
    end
    scroll.ResetScroll = function()
        bar:SetValue(0)
        scroll.UpdateScroll()
    end
    return bar
end

function Theme.SideColor(side)
    if side == "Horde" then
        return Theme.HORDE
    end
    return Theme.ALLIANCE
end

function Theme.QualityColor(quality)
    if GetItemQualityColor then
        local r, g, b = GetItemQualityColor(quality or 1)
        return { r, g, b, 1 }
    end
    return Theme.CREAM
end
