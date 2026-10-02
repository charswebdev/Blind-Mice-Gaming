local _, GPS = ...

function GPS:PlainString(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

function GPS:PlainNumber(value)
    if type(value) == "string" then
        if issecretvalue and issecretvalue(value) then
            return nil
        end
        value = tonumber(value)
    end
    if type(value) ~= "number" then
        return nil
    end
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end
