local addonName, LPL = ...

LPL.VERSION = "1.4.3"
LPL.ADDON_NAME = addonName or "lpl-forever"
LPL.TITLE = "Light Paws Loadouts - WoW Forever"

local ICON_BASE = "Interface\\AddOns\\lpl-forever\\icons\\"

LPL.Icons = {
    BASE = ICON_BASE,
    ADDON = ICON_BASE .. "lpl_32.blp",
    ADDON_64 = ICON_BASE .. "lpl_64.blp",
}

function LPL:SetIconTexture(texture, stem)
    if not texture or type(stem) ~= "string" or stem == "" then
        return false
    end
    local base = self.Icons.BASE
    local extensions = { "tga", "blp", "png" }
    for i = 1, #extensions do
        local path = base .. stem .. "." .. extensions[i]
        texture:SetTexture(path)
        if texture.GetTextureFilePath then
            local resolved = texture:GetTextureFilePath()
            if type(resolved) == "string" and resolved ~= "" then
                texture:SetTexCoord(0, 1, 0, 1)
                return true
            end
        elseif texture:GetTexture() then
            texture:SetTexCoord(0, 1, 0, 1)
            return true
        end
    end
    return false
end

_G.LPL = LPL
_G.BINDING_HEADER_LPL = "LPL"
_G.BINDING_NAME_TOGGLE_LPL = "Toggle LPL"
