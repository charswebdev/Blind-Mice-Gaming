local addonName, LPL = ...

-- Matches Blizzard Class Talents apply-complete feedback:
-- SOUNDKIT.UI_CLASS_TALENT_APPLY_COMPLETE + talents-animations-gridburst expand.

LPL.ActivateFeedback = {}

local SOUND_APPLY_COMPLETE = 212391
local SOUND_APPLY_CHANGES = 207767

local overlay
local suppressCount = 0

local function ResolveSound(preferredKey, fallback)
    if SOUNDKIT and SOUNDKIT[preferredKey] then
        return SOUNDKIT[preferredKey]
    end
    return fallback
end

local function ResolveClassAtlas()
    local classFile = select(2, UnitClass("player"))
    if type(classFile) ~= "string" or classFile == "" then
        return "talents-animations-titans"
    end
    return "talents-animations-class-" .. string.lower(classFile)
end

local function EnsureOverlay()
    if overlay then
        return overlay
    end

    local frame = CreateFrame("Frame", "LPLActivateFeedbackOverlay", UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(10000)
    frame:SetAllPoints(UIParent)
    frame:EnableMouse(false)
    frame:Hide()

    local burst = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    burst:SetAtlas("talents-animations-gridburst", false)
    burst:SetSize(320, 320)
    burst:SetPoint("CENTER", frame, "CENTER", 0, 40)
    burst:SetAlpha(0)
    burst:SetBlendMode("ADD")
    frame.burst = burst

    local classFx = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    classFx:SetSize(256, 256)
    classFx:SetPoint("CENTER", burst, "CENTER", 0, 0)
    classFx:SetAlpha(0)
    classFx:SetBlendMode("ADD")
    frame.classFx = classFx

    local classFx2 = frame:CreateTexture(nil, "ARTWORK", nil, 3)
    classFx2:SetSize(256, 256)
    classFx2:SetPoint("CENTER", classFx, "CENTER", 0, 0)
    classFx2:SetAlpha(0)
    classFx2:SetBlendMode("ADD")
    frame.classFx2 = classFx2

    local anim = frame:CreateAnimationGroup()
    anim:SetToFinalAlpha(true)
    frame.anim = anim

    local function ConfigureScale(animation, fromX, fromY, toX, toY)
        if animation.SetScaleFrom and animation.SetScaleTo then
            animation:SetScaleFrom(fromX, fromY)
            animation:SetScaleTo(toX, toY)
        elseif animation.SetFromScale and animation.SetToScale then
            animation:SetFromScale(fromX, fromY)
            animation:SetToScale(toX, toY)
        end
    end

    local burstScale = anim:CreateAnimation("Scale")
    burstScale:SetTarget(burst)
    burstScale:SetSmoothing("IN")
    burstScale:SetDuration(1.4)
    ConfigureScale(burstScale, 1, 1, 12, 12)
    burstScale:SetOrder(1)

    local burstAlpha = anim:CreateAnimation("Alpha")
    burstAlpha:SetTarget(burst)
    burstAlpha:SetSmoothing("IN")
    burstAlpha:SetDuration(1.4)
    burstAlpha:SetFromAlpha(0.65)
    burstAlpha:SetToAlpha(0)
    burstAlpha:SetOrder(1)

    local classAlpha = anim:CreateAnimation("Alpha")
    classAlpha:SetTarget(classFx)
    classAlpha:SetSmoothing("OUT")
    classAlpha:SetDuration(1.2)
    classAlpha:SetFromAlpha(1)
    classAlpha:SetToAlpha(0)
    classAlpha:SetOrder(1)

    local classAlpha2 = anim:CreateAnimation("Alpha")
    classAlpha2:SetTarget(classFx2)
    classAlpha2:SetSmoothing("OUT")
    classAlpha2:SetDuration(1.2)
    classAlpha2:SetFromAlpha(0.45)
    classAlpha2:SetToAlpha(0)
    classAlpha2:SetOrder(1)

    local classScale2 = anim:CreateAnimation("Scale")
    classScale2:SetTarget(classFx2)
    classScale2:SetDuration(0.5)
    ConfigureScale(classScale2, 1, 1, 1.5, 1.5)
    classScale2:SetOrder(1)

    anim:SetScript("OnFinished", function()
        frame:Hide()
        burst:SetAlpha(0)
        classFx:SetAlpha(0)
        classFx2:SetAlpha(0)
    end)

    anim:SetScript("OnPlay", function()
        frame:Show()
    end)

    overlay = frame
    return overlay
end

function LPL.ActivateFeedback:PushSuppress()
    suppressCount = suppressCount + 1
end

function LPL.ActivateFeedback:PopSuppress()
    suppressCount = math.max(0, suppressCount - 1)
end

function LPL.ActivateFeedback:IsSuppressed()
    return suppressCount > 0
end

function LPL.ActivateFeedback:PlayStart()
    if PlaySound then
        PlaySound(ResolveSound("UI_CLASS_TALENT_APPLY_CHANGES", SOUND_APPLY_CHANGES), "SFX")
    end
end

function LPL.ActivateFeedback:Play()
    if suppressCount > 0 then
        return
    end

    if PlaySound then
        PlaySound(ResolveSound("UI_CLASS_TALENT_APPLY_COMPLETE", SOUND_APPLY_COMPLETE), "SFX")
    end

    local frame = EnsureOverlay()
    local atlas = ResolveClassAtlas()
    if frame.classFx.SetAtlas then
        frame.classFx:SetAtlas(atlas, true)
        frame.classFx2:SetAtlas(atlas, true)
    end

    if frame.anim:IsPlaying() then
        frame.anim:Stop()
    end
    frame.burst:SetAlpha(0.65)
    frame.classFx:SetAlpha(1)
    frame.classFx2:SetAlpha(0.45)
    frame:Show()
    frame.anim:Play()
end
