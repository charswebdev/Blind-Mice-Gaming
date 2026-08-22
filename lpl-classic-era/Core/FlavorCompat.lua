local addonName, LPL = ...

-- Classic Era sibling product flags. This is not Retail LPL with tabs hidden.
LPL.FlavorCompat = {
    flavor = "classic_era",
    displayName = "Light Paws Loadouts - Classic Era",
    hasThreeTreeTalents = true,
    hasMoPTalents = false,
    hasHeroTalents = false,
    hasRetailPvpTalents = false,
    hasCooldownManager = false,
    hasEditMode = true,
    hasSkyriding = false,
    hasCovenant = false,
    hasItemUpgradeTracks = false,
    pointBudget = 51,
}

function LPL.FlavorCompat:IsEra()
    return self.flavor == "classic_era"
end

function LPL.FlavorCompat:SupportsRestrictionType(restrictionType)
    if restrictionType == "herotalents" then
        return self.hasHeroTalents == true
    end
    if restrictionType == "covenant" then
        return self.hasCovenant == true
    end
    return true
end

function LPL.FlavorCompat:SupportsConditionLinkType(linkType)
    if linkType == "pvpTalent" then
        return self.hasRetailPvpTalents == true
    end
    if linkType == "cooldownManager" then
        return self.hasCooldownManager == true
    end
    if linkType == "editMode" then
        return self.hasEditMode == true
    end
    return true
end
