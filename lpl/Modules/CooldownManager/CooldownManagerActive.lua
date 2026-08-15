local addonName, LPL = ...

LPL.CooldownManagerActive = {}

function LPL.CooldownManagerActive:IsActive(set)
    if type(set) ~= "table" then
        return false
    end

    if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(set) then
        return false
    end

    local wanted = LPL.CooldownManagerCodec
        and LPL.CooldownManagerCodec:NormalizeLayoutString(set.layoutString)
        or ""
    if wanted == "" then
        return false
    end

    local current = LPL.CooldownManagerCodec and LPL.CooldownManagerCodec:GetCurrentLayoutString() or ""
    if current == "" then
        return false
    end

    return current == wanted
end
