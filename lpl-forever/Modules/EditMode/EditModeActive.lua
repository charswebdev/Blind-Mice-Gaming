local addonName, LPL = ...

LPL.EditModeActive = {}

local function SystemsMatch(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    if #a ~= #b then
        return false
    end

    -- Prefer stable serialize compare when available.
    if C_EditMode and C_EditMode.ConvertLayoutInfoToString then
        local left = {
            layoutName = "LPLCompare",
            layoutType = 1,
            systems = a,
        }
        local right = {
            layoutName = "LPLCompare",
            layoutType = 1,
            systems = b,
        }
        local okLeft, leftString = pcall(C_EditMode.ConvertLayoutInfoToString, left)
        local okRight, rightString = pcall(C_EditMode.ConvertLayoutInfoToString, right)
        if okLeft and okRight and type(leftString) == "string" and type(rightString) == "string" then
            return leftString == rightString
        end
    end

    return false
end

function LPL.EditModeActive:IsActive(set)
    if type(set) ~= "table" then
        return false
    end

    if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(set) then
        return false
    end

    local wanted = LPL.EditModeCodec
        and LPL.EditModeCodec:NormalizeLayoutString(set.layoutString)
        or ""
    if wanted == "" then
        return false
    end

    local current = LPL.EditModeCodec and LPL.EditModeCodec:GetCurrentLayoutString() or ""
    if current ~= "" and current == wanted then
        return true
    end

    -- Name/type often differ between LPL sets and Blizzard layouts; compare systems.
    local wantedInfo = LPL.EditModeCodec and LPL.EditModeCodec:ParseLayoutString(wanted)
    local currentInfo = LPL.EditModeCodec and LPL.EditModeCodec:GetActiveLayoutInfo()
    if type(wantedInfo) ~= "table" or type(currentInfo) ~= "table" then
        return false
    end

    return SystemsMatch(wantedInfo.systems, currentInfo.systems)
end
