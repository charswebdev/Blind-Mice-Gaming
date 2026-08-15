--[[
  AllQuest — event bus
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Events = AQ.Events or {}
local Events = AQ.Events

local listeners = {}
local frame = CreateFrame("Frame")

local function Dispatch(event, ...)
    local list = listeners[event]
    if not list then
        return
    end
    for i = 1, #list do
        local fn = list[i]
        if type(fn) == "function" then
            pcall(fn, event, ...)
        end
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    Dispatch(event, ...)
end)

function Events.Register(event, fn)
    if type(event) ~= "string" or type(fn) ~= "function" then
        return
    end
    if not listeners[event] then
        listeners[event] = {}
        if event ~= "AQ_TRACKER_REFRESH"
            and event ~= "AQ_JOURNAL_REFRESH"
            and event ~= "AQ_DATA_CHANGED"
            and event ~= "AQ_FOCUS_CHANGED"
        then
            pcall(frame.RegisterEvent, frame, event)
        end
    end
    listeners[event][#listeners[event] + 1] = fn
end

function Events.Fire(event, ...)
    Dispatch(event, ...)
end
