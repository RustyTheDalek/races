function lerp(a, b, t) return a * (1 - t) + b * t end

function round(f)
    return (f - math.floor(f) >= 0.5) and math.ceil(f) or math.floor(f)
end

function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

function idump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in ipairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

function contains(table, val)
    for i = 1, #table do
        if table[i] == val then
            return true
        end
    end
    return false
end

function int2float(integer)
    return integer + 0.0
end

function drawMsg(x, y, msg, scale, justify)
    SetTextFont(4)
    SetTextScale(0, scale)
    SetTextColour(255, 255, 0, 255)
    SetTextOutline()
    SetTextJustification(justify)
    SetTextWrap(0.0, 1.0)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayText(x, y)
end

function uniqueValues(a, b)
    local uniqueElements = {}

    -- Create a set from table b for faster lookup
    local bSet = {}
    for _, v in ipairs(b) do
        bSet[v] = true
    end

    -- Check each element in table a
    for _, v in ipairs(a) do
        -- If the element is not found in table b, add it to the result
        if not bSet[v] then
            table.insert(uniqueElements, v)
        end
    end

    return uniqueElements
end

function toBoolean(number)
    if number == 1 then
        return true
    else
        return false
    end
end
