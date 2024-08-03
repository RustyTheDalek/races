function lerp(a, b, t) return a * (1 - t) + b * t end

function round(f)
    return (f - math.floor(f) >= 0.5) and math.ceil(f) or math.floor(f)
end

function getTableSize(table)
    if(type(table) ~= 'table') then
        return 0
    end

    local count = 0

    for _ in pairs(table) do count = count + 1 end

    return count
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

function CarTierUIActive()
    return ResourceActive("CarTierUI")
end

function ResourceActive(resourceName)
    return GetResourceState(resourceName) ~= "stopped" and GetResourceState(resourceName) ~= "missing"
end

function explode(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

function removeDuplicates(table)
    local hash = {}
    local res = {}

    for _, v in ipairs(table) do
        if (not hash[v]) then
            res[#res + 1] = v
            hash[v] = true
        end
    end

    return res
end

function map(tbl, f)
    local t = {}
    for k, v in pairs(tbl) do
        t[k] = f(v)
    end
    return t
end

function mapToArray(tbl, f)
    local t = {}
    for k, v in pairs(tbl) do
        table.insert(t, f(v))
    end
    return t
end

function toast(source, msg)
    TriggerClientEvent("races:toast", source, msg)
end

function warn(source, msg)
    TriggerClientEvent("races:toastWarn", source, msg)
end

function error(source, msg)
    TriggerClientEvent("races:toastError", source, msg)
end

function getClassName(vclass)
    if -1 == vclass then
        return "'Custom'(-1)"
    elseif 0 == vclass then
        return "'Compacts'(0)"
    elseif 1 == vclass then
        return "'Sedans'(1)"
    elseif 2 == vclass then
        return "'SUVs'(2)"
    elseif 3 == vclass then
        return "'Coupes'(3)"
    elseif 4 == vclass then
        return "'Muscle'(4)"
    elseif 5 == vclass then
        return "'Sports Classics'(5)"
    elseif 6 == vclass then
        return "'Sports'(6)"
    elseif 7 == vclass then
        return "'Super'(7)"
    elseif 8 == vclass then
        return "'Motorcycles'(8)"
    elseif 9 == vclass then
        return "'Off-road'(9)"
    elseif 10 == vclass then
        return "'Industrial'(10)"
    elseif 11 == vclass then
        return "'Utility'(11)"
    elseif 12 == vclass then
        return "'Vans'(12)"
    elseif 13 == vclass then
        return "'Cycles'(13)"
    elseif 14 == vclass then
        return "'Boats'(14)"
    elseif 15 == vclass then
        return "'Helicopters'(15)"
    elseif 16 == vclass then
        return "'Planes'(16)"
    elseif 17 == vclass then
        return "'Service'(17)"
    elseif 18 == vclass then
        return "'Emergency'(18)"
    elseif 19 == vclass then
        return "'Military'(19)"
    elseif 20 == vclass then
        return "'Commercial'(20)"
    elseif 21 == vclass then
        return "'Trains'(21)"
    else
        return "'Unknown'(" .. vclass .. ")"
    end
end

function minutesSeconds(milliseconds)
    local seconds = milliseconds / 1000.0
    local minutes = math.floor(seconds / 60.0)
    seconds = seconds - minutes * 60.0
    return minutes, seconds
end

function AddBlipForCoordVector3(coord)
    local x, y, z = table.unpack(coord)
    return AddBlipForCoord(x, y, z)
end

function SetBlipCoordsVector3(blip, coord)
    local x, y, z = table.unpack(coord)
    return SetBlipCoords(blip, x, y, z)
end

function Clamp(num, lower, upper)
	assert(num and lower and upper, 'error: Clamp(num, lower, upper)')
	return math.max(lower, math.min(upper, num))
end

function getTableSize(table)
    if(type(table) ~= 'table') then
        return 0
    end

    local count = 0

    for _ in pairs(table) do count = count + 1 end

    return count
end

function SetEntityCoordsVector3(entity, coord, alive, deadFlag, ragdollFlag, clearArea)

    alive = alive ~= nil and alive or false
    deadFlag = deadFlag ~= nil and deadFlag or false
    ragdollFlag = ragdollFlag ~= nil and ragdollFlag or false
    clearArea = clearArea ~= nil and clearArea or true

    SetEntityCoords(entity, coord.x, coord.y, coord.z, alive, deadFlag, ragdollFlag, clearArea)
end

function getVehiclePassenegers(vehicle)
    local passengers = {}
    for i = 0, GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) - 2 do
        local passenger = GetPedInVehicleSeat(vehicle, i)
        if passenger ~= 0 then
            passengers[#passengers + 1] = { ped = passenger, seat = i }
        end
    end

    return passengers
end

function repairVehicle(vehicle)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleFixed(vehicle)
end

function putPedInVehicle(ped, vehicleHash, coord)
    coord = coord or GetEntityCoords(ped)
    local vehicle = CreateVehicle(vehicleHash, coord.x, coord.y, coord.z, GetEntityHeading(ped), true, false)
    SetModelAsNoLongerNeeded(vehicleHash)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetPedIntoVehicle(ped, vehicle, -1)
    SetVehRadioStation(vehicle, "OFF")
    return vehicle
end
