local addonName, LPL = ...

LPL.VERSION = "1.0.0"
LPL.ADDON_NAME = addonName

LPL.Icons = {
    BASE = "Interface\\AddOns\\lpl-classic-era\\icons\\",
    ADDON = "Interface\\AddOns\\lpl-classic-era\\icons\\lpl_32.blp",
    ADDON_64 = "Interface\\AddOns\\lpl-classic-era\\icons\\lpl_64.blp",
    TALENT = "Interface\\AddOns\\lpl-classic-era\\icons\\talent_64.tga",
    IMPORT = "Interface\\AddOns\\lpl-classic-era\\icons\\import_64.tga",
    ACTION_BARS = "Interface\\AddOns\\lpl-classic-era\\icons\\actionbars_64.tga",
    LOCK = "Interface\\AddOns\\lpl-classic-era\\icons\\lock_64.blp",
    ADDON_LOCKED = "Interface\\AddOns\\lpl-classic-era\\icons\\locked_64.png",
    ADDON_UNLOCKED = "Interface\\AddOns\\lpl-classic-era\\icons\\unlock_64.png",
    IGNORE_SLOT_STEM = "ignore_64",
    IGNORE_SLOT = "Interface\\AddOns\\lpl-classic-era\\icons\\ignore_64.tga",
}

local ICON_EXTENSIONS = { "blp", "tga", "png" }

function LPL:GetIconPath(name, size)
    return string.format("%s%s_%d.blp", self.Icons.BASE, name, size or 32)
end

function LPL:ResolveIconPath(stem)
    if type(stem) ~= "string" or stem == "" then
        return nil
    end

    if not self.iconProbe then
        local probeFrame = CreateFrame("Frame")
        self.iconProbe = probeFrame:CreateTexture(nil, "BACKGROUND")
        probeFrame:Hide()
    end

    local base = self.Icons.BASE
    for _, ext in ipairs(ICON_EXTENSIONS) do
        local path = base .. stem .. "." .. ext
        self.iconProbe:SetTexture(path)
        if self.iconProbe.GetTextureFilePath then
            local resolved = self.iconProbe:GetTextureFilePath()
            if resolved and resolved ~= "" then
                return path
            end
        elseif self.iconProbe:GetTexture() then
            return path
        end
    end

    return base .. stem .. ".blp"
end

function LPL:SetIconTexture(texture, stem)
    if not texture or type(stem) ~= "string" or stem == "" then
        return false
    end

    local path = self:ResolveIconPath(stem)
    if not path then
        return false
    end

    texture:SetTexture(path)
    texture:SetTexCoord(0, 1, 0, 1)
    return true
end

_G.LPL = LPL
_G.BINDING_HEADER_LPL = "Light Paws Loadouts - Classic Era"
_G.BINDING_NAME_TOGGLE_LPL = "Toggle LPL"
