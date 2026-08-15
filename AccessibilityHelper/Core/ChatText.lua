--[[
  Accessibility Helper — turn Blizzard chat/UI strings into speakable text
  Keeps visible wording exactly as printed; strips only markup (colors, links, textures).
  Fills leftover %s / %d format tokens (achievements, emotes, notices, etc.).
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.ChatText = AH.ChatText or {}
local ChatText = AH.ChatText

local function Trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function ChatText.HasFormatTokens(s)
    if type(s) ~= "string" or s == "" then
        return false
    end
    if s:find("%%s", 1, true) then
        return true
    end
    if s:find("%%d", 1, true) then
        return true
    end
    if s:find("%%%d+%$") then
        return true
    end
    if s:find("%%[%-%+ #0]*%d*%.?%d*[sdf]") then
        return true
    end
    return false
end

--- Strip markup but keep format tokens (%s, %d, …).
function ChatText.StripMarkupKeepFormat(s)
    if type(s) ~= "string" then
        return ""
    end
    s = s:gsub("|T.-|t", " ")
    s = s:gsub("|A.-|a", " ")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    s = s:gsub("|H.-|h(.-)|h", "%1")
    s = s:gsub("|n", " ")
    s = s:gsub("||", "|")
    s = s:gsub("%s+", " ")
    return Trim(s)
end

--- Convert a Blizzard printed string into TTS text without rephrasing.
-- Hyperlink display text is kept (including [brackets] when present).
function ChatText.ForSpeech(s)
    if type(s) ~= "string" then
        return ""
    end
    return ChatText.StripMarkupKeepFormat(s)
end

local function BareName(name)
    if type(name) ~= "string" or name == "" then
        return ""
    end
    name = ChatText.ForSpeech(name)
    return name:match("^([^%-]+)") or name
end

local function ArgValue(a)
    if type(a) == "string" and a ~= "" then
        local bare = BareName(a)
        if bare ~= "" then
            return bare
        end
        return ChatText.ForSpeech(a)
    end
    if type(a) == "number" then
        return a
    end
    return nil
end

--- Fill Blizzard chat/UI templates that still contain %s / %1$s / etc.
-- Extra args are substitution values in order (player, target, item, …).
-- Does not invent filler words for missing args — leftover tokens are stripped.
function ChatText.FillFormat(text, ...)
    if type(text) ~= "string" or text == "" then
        return ""
    end
    local cleaned = ChatText.StripMarkupKeepFormat(text)
    if not ChatText.HasFormatTokens(cleaned) then
        return cleaned
    end

    local raw = { ... }
    local filledArgs = {}
    for i = 1, #raw do
        local v = ArgValue(raw[i])
        if v ~= nil then
            filledArgs[#filledArgs + 1] = v
        end
    end

    -- Globals like LEVEL_UP / ERR_* usually format cleanly with string.format.
    if #filledArgs > 0 then
        local ok, filled = pcall(string.format, cleaned, unpack(filledArgs))
        if ok and type(filled) == "string" and not ChatText.HasFormatTokens(filled) then
            return Trim(filled:gsub("%s+", " "))
        end
    end

    -- Chat templates (achievements, emotes, notices): fill %s in order from args.
    -- Achievement text is usually "%s has earned the achievement [Name]!" — one name.
    local idx = 0
    cleaned = cleaned:gsub("%%%d*%$?s", function()
        idx = idx + 1
        local v = filledArgs[idx]
        if type(v) == "string" and v ~= "" then
            return v
        end
        if type(v) == "number" then
            return tostring(v)
        end
        return ""
    end)
    cleaned = cleaned:gsub("%%%d*%$?d", function()
        idx = idx + 1
        local v = filledArgs[idx]
        if type(v) == "number" then
            return tostring(v)
        end
        if type(v) == "string" and v:match("^%-?%d+$") then
            return v
        end
        return "0"
    end)

    -- Never speak leftover placeholders ("percent s").
    cleaned = cleaned:gsub("%%%d*%$?[sdf]", "")
    cleaned = cleaned:gsub("%%[%-%+ #0]*%d*%.?%d*[sdf]", "")
    cleaned = cleaned:gsub("%s+", " ")
    return Trim(cleaned)
end

--- Speakable chat line: fill author/target into templates, then strip markup.
function ChatText.ForChatMessage(text, author, target)
    if type(text) ~= "string" or text == "" then
        return ""
    end
    local stripped = ChatText.StripMarkupKeepFormat(text)
    if ChatText.HasFormatTokens(stripped) or ChatText.HasFormatTokens(text) then
        return ChatText.FillFormat(text, author, target)
    end
    return stripped
end

--- Format a global string (e.g. LEVEL_UP) then strip for speech.
function ChatText.Format(globalName, ...)
    local fmt = _G[globalName]
    if type(fmt) ~= "string" then
        return ""
    end
    if ChatText.HasFormatTokens(fmt) then
        return ChatText.FillFormat(fmt, ...)
    end
    local ok, text = pcall(string.format, fmt, ...)
    if not ok or type(text) ~= "string" then
        return ""
    end
    return ChatText.ForSpeech(text)
end

-- Shared short-window dedupe for ChatChannels + AddonChat (same line twice).
local lastSpokenKey, lastSpokenAt = nil, 0

--- Returns true if this key was spoken within sec (default 0.5). Otherwise remembers it.
function ChatText.WasRecentlySpoken(key, sec)
    if type(key) ~= "string" or key == "" then
        return false
    end
    sec = sec or 0.5
    local now = GetTime and GetTime() or 0
    if key == lastSpokenKey and (now - lastSpokenAt) < sec then
        return true
    end
    lastSpokenKey = key
    lastSpokenAt = now
    return false
end

function ChatText.RememberSpoken(key)
    if type(key) ~= "string" or key == "" then
        return
    end
    lastSpokenKey = key
    lastSpokenAt = GetTime and GetTime() or 0
end
