local addonName, LPL = ...

local function GetIgnoreSlotTexture()
    if not LPL._ignoreSlotTexture then
        LPL._ignoreSlotTexture = LPL:ResolveIconPath(LPL.Icons.IGNORE_SLOT_STEM) or LPL.Icons.IGNORE_SLOT
    end
    return LPL._ignoreSlotTexture
end

LPL.ActionBarSlotVisuals = {
    -- Match the square icon inset area (SLOT_SIZE 33, 2px padding each side).
    IGNORE_TEXTURE_SIZE = 29,
}

local function EnsureIgnoreOverlay(button)
    if button.ignoreTexture then
        return button.ignoreTexture
    end

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture(GetIgnoreSlotTexture())
    overlay:SetSize(LPL.ActionBarSlotVisuals.IGNORE_TEXTURE_SIZE, LPL.ActionBarSlotVisuals.IGNORE_TEXTURE_SIZE)
    overlay:SetPoint("CENTER")
    overlay:Hide()
    button.ignoreTexture = overlay
    return overlay
end

function LPL.ActionBarSlotVisuals:ApplyIgnoredState(button, ignored)
    if not button then
        return
    end

    local overlay = EnsureIgnoreOverlay(button)
    overlay:SetShown(ignored)

    if button.Icon then
        button.Icon:SetDesaturated(ignored)
        button.Icon:SetAlpha(ignored and 0.8 or 1)
    end
end
