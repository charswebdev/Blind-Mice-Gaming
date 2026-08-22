local addonName, LPL = ...

-- Classic Era activate celebration: full-screen flash + peon "Work Complete".
-- Retail talent atlases / SOUNDKIT.UI_CLASS_TALENT_* are not available here.

LPL.ActivateFeedback = {}

-- PeonBuildingComplete1.ogg — "Work Complete!"
local WORK_COMPLETE_FILE_ID = 558132
local WORK_COMPLETE_PATH = "Sound\\Creature\\Peon\\PeonBuildingComplete1.ogg"

local overlay
local suppressCount = 0

local function ResolveSound(preferredKey, fallback)
    if SOUNDKIT and preferredKey and SOUNDKIT[preferredKey] then
        return SOUNDKIT[preferredKey]
    end
    return fallback
end

local function PlayCelebrateSound()
    local channel = "Dialog"
    if PlaySoundFile then
        local ok = pcall(PlaySoundFile, WORK_COMPLETE_FILE_ID, channel)
        if ok then
            return
        end
        ok = pcall(PlaySoundFile, WORK_COMPLETE_PATH, channel)
        if ok then
            return
        end
    end
    -- Last resort if FileDataID/path are unavailable on this client.
    if PlaySound then
        PlaySound(ResolveSound("IG_QUEST_COMPLETE", 878), "SFX")
    end
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

    local flash = frame:CreateTexture(nil, "BACKGROUND")
    flash:SetAllPoints(frame)
    flash:SetColorTexture(1, 0.92, 0.25, 0)
    flash:SetBlendMode("ADD")
    frame.flash = flash

    local burst = frame:CreateTexture(nil, "ARTWORK")
    burst:SetSize(220, 220)
    burst:SetPoint("CENTER", frame, "CENTER", 0, 36)
    burst:SetColorTexture(1, 1, 1, 0)
    burst:SetBlendMode("ADD")
    frame.burst = burst

    local ring = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    ring:SetSize(160, 160)
    ring:SetPoint("CENTER", burst, "CENTER", 0, 0)
    ring:SetColorTexture(1, 0.85, 0.2, 0)
    ring:SetBlendMode("ADD")
    frame.ring = ring

    local ring2 = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    ring2:SetSize(120, 120)
    ring2:SetPoint("CENTER", burst, "CENTER", 0, 0)
    ring2:SetColorTexture(0.35, 0.65, 1, 0)
    ring2:SetBlendMode("ADD")
    frame.ring2 = ring2

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 42, "OUTLINE")
    title:SetPoint("CENTER", frame, "CENTER", 0, 36)
    title:SetTextColor(1, 0.92, 0.35, 1)
    title:SetText("ACTIVATED")
    title:SetAlpha(0)
    frame.title = title

    local subtitle = frame:CreateFontString(nil, "OVERLAY")
    subtitle:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -10)
    subtitle:SetTextColor(0.95, 0.95, 0.97, 1)
    subtitle:SetText("")
    subtitle:SetAlpha(0)
    frame.subtitle = subtitle

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

    local flashIn = anim:CreateAnimation("Alpha")
    flashIn:SetTarget(flash)
    flashIn:SetDuration(0.12)
    flashIn:SetFromAlpha(0)
    flashIn:SetToAlpha(0.55)
    flashIn:SetOrder(1)

    local flashOut = anim:CreateAnimation("Alpha")
    flashOut:SetTarget(flash)
    flashOut:SetDuration(0.9)
    flashOut:SetFromAlpha(0.55)
    flashOut:SetToAlpha(0)
    flashOut:SetOrder(2)
    flashOut:SetSmoothing("OUT")

    local burstScale = anim:CreateAnimation("Scale")
    burstScale:SetTarget(burst)
    burstScale:SetDuration(0.85)
    ConfigureScale(burstScale, 0.4, 0.4, 8, 8)
    burstScale:SetOrder(1)
    burstScale:SetSmoothing("OUT")

    local burstAlpha = anim:CreateAnimation("Alpha")
    burstAlpha:SetTarget(burst)
    burstAlpha:SetDuration(0.85)
    burstAlpha:SetFromAlpha(0.85)
    burstAlpha:SetToAlpha(0)
    burstAlpha:SetOrder(1)
    burstAlpha:SetSmoothing("OUT")

    local ringScale = anim:CreateAnimation("Scale")
    ringScale:SetTarget(ring)
    ringScale:SetDuration(1.0)
    ConfigureScale(ringScale, 0.5, 0.5, 10, 10)
    ringScale:SetOrder(1)
    ringScale:SetSmoothing("OUT")

    local ringAlpha = anim:CreateAnimation("Alpha")
    ringAlpha:SetTarget(ring)
    ringAlpha:SetDuration(1.0)
    ringAlpha:SetFromAlpha(0.9)
    ringAlpha:SetToAlpha(0)
    ringAlpha:SetOrder(1)

    local ring2Scale = anim:CreateAnimation("Scale")
    ring2Scale:SetTarget(ring2)
    ring2Scale:SetDuration(0.7)
    ConfigureScale(ring2Scale, 0.6, 0.6, 6, 6)
    ring2Scale:SetOrder(1)

    local ring2Alpha = anim:CreateAnimation("Alpha")
    ring2Alpha:SetTarget(ring2)
    ring2Alpha:SetDuration(0.7)
    ring2Alpha:SetFromAlpha(0.75)
    ring2Alpha:SetToAlpha(0)
    ring2Alpha:SetOrder(1)

    local titleIn = anim:CreateAnimation("Alpha")
    titleIn:SetTarget(title)
    titleIn:SetDuration(0.15)
    titleIn:SetFromAlpha(0)
    titleIn:SetToAlpha(1)
    titleIn:SetOrder(1)

    local titleOut = anim:CreateAnimation("Alpha")
    titleOut:SetTarget(title)
    titleOut:SetDuration(0.55)
    titleOut:SetStartDelay(0.55)
    titleOut:SetFromAlpha(1)
    titleOut:SetToAlpha(0)
    titleOut:SetOrder(1)

    local subIn = anim:CreateAnimation("Alpha")
    subIn:SetTarget(subtitle)
    subIn:SetDuration(0.2)
    subIn:SetFromAlpha(0)
    subIn:SetToAlpha(1)
    subIn:SetOrder(1)

    local subOut = anim:CreateAnimation("Alpha")
    subOut:SetTarget(subtitle)
    subOut:SetDuration(0.5)
    subOut:SetStartDelay(0.6)
    subOut:SetFromAlpha(1)
    subOut:SetToAlpha(0)
    subOut:SetOrder(1)

    anim:SetScript("OnFinished", function()
        frame:Hide()
        flash:SetAlpha(0)
        burst:SetAlpha(0)
        ring:SetAlpha(0)
        ring2:SetAlpha(0)
        title:SetAlpha(0)
        subtitle:SetAlpha(0)
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

function LPL.ActivateFeedback:Speak(message)
    if type(message) ~= "string" or message == "" then
        return
    end
    print("|cff33cc33LPL:|r " .. message)
end

function LPL.ActivateFeedback:PlayStart()
    if PlaySound then
        PlaySound(ResolveSound("IG_MAINMENU_OPTION", 852), "SFX")
    end
end

function LPL.ActivateFeedback:Play(message)
    if suppressCount > 0 then
        return
    end

    PlayCelebrateSound()

    local frame = EnsureOverlay()
    if type(message) == "string" and message ~= "" then
        frame.subtitle:SetText(message)
    else
        frame.subtitle:SetText("")
    end
    frame.title:SetText("ACTIVATED")

    if frame.anim:IsPlaying() then
        frame.anim:Stop()
    end

    frame.flash:SetAlpha(0)
    frame.burst:SetAlpha(0.85)
    frame.ring:SetAlpha(0.9)
    frame.ring2:SetAlpha(0.75)
    frame.title:SetAlpha(0)
    frame.subtitle:SetAlpha(0)
    frame:Show()
    frame.anim:Play()
end
