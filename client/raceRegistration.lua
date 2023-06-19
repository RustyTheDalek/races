raceRegistration = {}

raceRegistration.starts = {} -- starts[playerID] = {isPublic, trackName, owner, buyin, laps, timeout, rtype, restrict, vclass, svehicle, vehicleList, blip, checkpoint, gridData} - registration points

function removeRegistrationPoint(rIndex)
    RemoveBlip(starts[rIndex].blip) -- delete registration blip
    DeleteCheckpoint(starts[rIndex].checkpoint) -- delete registration checkpoint
    DeleteCheckpoint(gridCheckpoint)
    starts[rIndex] = nil
end

function register(rIndex, coord, isPublic, trackName, owner, buyin, laps, timeout, allowAI, rdata)
    if rIndex ~= nil and coord ~= nil and isPublic ~= nil and owner ~= nil and buyin ~= nil and laps ~= nil and timeout ~=
        nil and allowAI ~= nil and rdata ~= nil then
        local blip = AddBlipForCoord(coord.x, coord.y, coord.z) -- registration blip
        SetBlipSprite(blip, registerSprite)
        SetBlipColour(blip, registerBlipColor)
        BeginTextCommandSetBlipName("STRING")
        local msg = owner .. " (" .. buyin .. " buy-in"
        if "yes" == allowAI then
            msg = msg .. " : AI allowed"
        end
        if "rest" == rdata.rtype then
            msg = msg .. " : using '" .. rdata.restrict .. "' vehicle"
        elseif "class" == rdata.rtype then
            msg = msg .. " : using " .. getClassName(rdata.vclass) .. " vehicle class"
        elseif "rand" == rdata.rtype then
            msg = msg .. " : using random "
            if rdata.vclass ~= nil then
                msg = msg .. getClassName(rdata.vclass) .. " vehicle class"
            else
                msg = msg .. "vehicles"
            end
            if rdata.svehicle ~= nil then
                msg = msg .. " : '" .. rdata.svehicle .. "'"
            end
        end
        msg = msg .. ")"
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandSetBlipName(blip)

        coord.r = defaultRadius
        local checkpoint = makeCheckpoint(plainCheckpoint, coord, coord, purple, 127, 0) -- registration checkpoint

        starts[rIndex] = {
            isPublic = isPublic,
            trackName = trackName,
            owner = owner,
            buyin = buyin,
            laps = laps,
            timeout = timeout,
            allowAI = allowAI,
            rtype = rdata.rtype,
            restrict = rdata.restrict,
            vclass = rdata.vclass,
            svehicle = rdata.svehicle,
            vehicleList = rdata.vehicleList,
            blip = blip,
            checkpoint = checkpoint
        }
    else
        notifyPlayer("Ignoring register event.  Invalid parameters.\n")
    end
end

function unregister(rIndex)
    if rIndex ~= nil then
        if gridCheckpoint ~= nil then
            DeleteCheckpoint(gridCheckpoint)
        end
        if starts[rIndex] ~= nil then
            DeleteGridCheckPoints()
            removeRegistrationPoint(rIndex)
        end
        if rIndex == raceIndex then
            if STATE_JOINING == raceState then
                raceState = STATE_IDLE
                removeRacerBlipGT()
                notifyPlayer("Race canceled.\n")
            elseif STATE_RACING == raceState then
                raceState = STATE_IDLE
                DeleteCheckpoint(raceCheckpoint)
                restoreBlips()
                SetBlipRoute(waypoints[1].blip, true)
                SetBlipRouteColour(waypoints[1].blip, blipRouteColor)
                speedo = false
                removeRacerBlipGT()
                RenderScriptCams(false, false, 0, true, true)
                local player = PlayerPedId()
                if IsPedInAnyVehicle(player, false) == 1 then
                    FreezeEntityPosition(GetVehiclePedIsIn(player, false), false)
                end
                if originalVehicleHash ~= nil then
                    local vehicle = switchVehicle(player, originalVehicleHash)
                    if vehicle ~= nil then
                        SetVehicleColours(vehicle, colorPri, colorSec)
                        SetEntityAsNoLongerNeeded(vehicle)
                    end
                end
                notifyPlayer("Race canceled.\n")
            end
        end
        if aiState ~= nil and GetPlayerServerId(PlayerId()) == rIndex then
            for _, driver in pairs(aiState.drivers) do
                if driver.ped ~= nil then
                    SetEntityAsNoLongerNeeded(driver.ped)
                end
                if IsEntityDead(driver.ped) == false and driver.originalVehicleHash ~= nil then
                    driver.vehicle = switchVehicle(driver.ped, driver.originalVehicleHash)
                    if driver.vehicle ~= nil then
                        SetVehicleColours(driver.vehicle, driver.colorPri, driver.colorSec)
                    end
                end
                if driver.vehicle ~= nil then
                    SetEntityAsNoLongerNeeded(driver.vehicle)
                end
            end
            aiState = nil
        end
    else
        notifyPlayer("Ignoring unregister event.  Invalid parameters.\n")
    end
end

function join(rIndex, aiName, waypointCoords)
    if rIndex ~= nil and waypointCoords ~= nil then
        if starts[rIndex] ~= nil then
            if nil == aiName then
                if STATE_IDLE == raceState then
                    raceState = STATE_JOINING
                    raceIndex = rIndex
                    numLaps = starts[rIndex].laps
                    DNFTimeout = starts[rIndex].timeout * 1000
                    restrictedHash = nil
                    restrictedClass = starts[rIndex].vclass
                    customClassVehicleList = {}
                    startVehicle = starts[rIndex].svehicle
                    randVehicles = {}
                    loadWaypointBlips(waypointCoords)
                    local msg = "Joined race using "
                    if nil == starts[rIndex].trackName then
                        msg = msg .. "unsaved track "
                    else
                        msg =
                            msg .. (true == starts[rIndex].isPublic and "publicly" or "privately") .. " saved track '" ..
                                starts[rIndex].trackName .. "' "
                    end
                    msg = msg ..
                              ("registered by %s : %d buy-in : %d lap(s)"):format(starts[rIndex].owner,
                            starts[rIndex].buyin, starts[rIndex].laps)
                    if "yes" == starts[rIndex].allowAI then
                        msg = msg .. " : AI allowed"
                    end
                    if "rest" == starts[rIndex].rtype then
                        msg = msg .. " : using '" .. starts[rIndex].restrict .. "' vehicle"
                        restrictedHash = GetHashKey(starts[rIndex].restrict)
                    elseif "class" == starts[rIndex].rtype then
                        msg = msg .. " : using " .. getClassName(restrictedClass) .. " vehicle class"
                        customClassVehicleList = starts[rIndex].vehicleList
                    elseif "rand" == starts[rIndex].rtype then
                        msg = msg .. " : using random "
                        if restrictedClass ~= nil then
                            msg = msg .. getClassName(restrictedClass) .. " vehicle class"
                        else
                            msg = msg .. "vehicles"
                        end
                        if startVehicle ~= nil then
                            msg = msg .. " : '" .. startVehicle .. "'"
                        end
                        randVehicles = starts[rIndex].vehicleList
                    end
                    msg = msg .. ".\n"
                    notifyPlayer(msg)
                elseif STATE_EDITING == raceState then
                    notifyPlayer("Ignoring join event.  Currently editing.\n")
                else
                    notifyPlayer("Ignoring join event.  Already joined to a race.\n")
                end
            elseif aiState ~= nil then
                local driver = aiState.drivers[aiName]
                if driver ~= nil then
                    if nil == aiState.waypointCoords then
                        aiState.waypointCoords = waypointCoords
                        aiState.startIsFinish = waypointCoords[1].x == waypointCoords[#waypointCoords].x and
                                                    waypointCoords[1].y == waypointCoords[#waypointCoords].y and
                                                    waypointCoords[1].z == waypointCoords[#waypointCoords].z
                        if true == aiState.startIsFinish then
                            aiState.waypointCoords[#aiState.waypointCoords] = nil
                        end
                    end
                    driver.destCoord = aiState.waypointCoords[1]
                    driver.destSet = true
                    driver.currentWP = true == aiState.startIsFinish and 0 or 1
                    if "rand" == aiState.rtype then
                        aiState.randVehicles = aiState.vehicleList
                    end
                    notifyPlayer("AI driver '" .. aiName .. "' joined race.\n")
                else
                    notifyPlayer("Ignoring join event.  '" .. aiName .. "' is not a valid AI driver.\n")
                end
            else
                notifyPlayer("Ignoring join event.  No AI drivers added.\n")
            end
        else
            notifyPlayer("Ignoring join event.  Race does not exist.\n")
        end
    else
        notifyPlayer("Ignoring join event.  Invalid parameters.\n")
    end
end

function hide(rIndex)
    if rIndex ~= nil then
        if starts[rIndex] ~= nil then
            removeRegistrationPoint(rIndex)
        else
            notifyPlayer("Ignoring hide event.  Race does not exist.\n")
        end
    else
        notifyPlayer("Ignoring hide event.  Invalid parameters.\n")
    end
end

function handleRaceRegistration()
    local closestIndex = -1
    local minDist = defaultRadius
    for rIndex, start in pairs(starts) do
        local dist = #(playerCoord - GetBlipCoords(start.blip))
        if dist < minDist then
            minDist = dist
            closestIndex = rIndex
        end
    end
    if closestIndex ~= -1 then
        local msg = "Join race using "
        if nil == starts[closestIndex].trackName then
            msg = msg .. "unsaved track "
        else
            msg = msg .. (true == starts[closestIndex].isPublic and "publicly" or "privately") .. " saved track '" ..
                      starts[closestIndex].trackName .. "' "
        end
        msg = msg .. "registered by " .. starts[closestIndex].owner
        drawMsg(0.50, 0.50, msg, 0.7, 0)
        msg = ("%d buy-in : %d lap(s)"):format(starts[closestIndex].buyin, starts[closestIndex].laps)
        if "yes" == starts[closestIndex].allowAI then
            msg = msg .. " : AI allowed"
        end
        if "rest" == starts[closestIndex].rtype then
            msg = msg .. " : using '" .. starts[closestIndex].restrict .. "' vehicle"
        elseif "class" == starts[closestIndex].rtype then
            msg = msg .. " : using " .. getClassName(starts[closestIndex].vclass) .. " vehicle class"
        elseif "rand" == starts[closestIndex].rtype then
            msg = msg .. " : using random "
            if starts[closestIndex].vclass ~= nil then
                msg = msg .. getClassName(starts[closestIndex].vclass) .. " vehicle class"
            else
                msg = msg .. "vehicles"
            end
            if starts[closestIndex].svehicle ~= nil then
                msg = msg .. " : '" .. starts[closestIndex].svehicle .. "'"
            end
        end
        drawMsg(0.50, 0.54, msg, 0.7, 0)
        if IsControlJustReleased(0, 51) == 1 then -- E key or DPAD RIGHT
            local joinRace = true
            originalVehicleHash = nil
            colorPri = -1
            colorSec = -1
            local vehicle = nil
            if IsPedInAnyVehicle(player, false) == 1 then
                vehicle = GetVehiclePedIsIn(player, false)
            end
            if "rest" == starts[closestIndex].rtype then
                if vehicle ~= nil then
                    if GetEntityModel(vehicle) ~= GetHashKey(starts[closestIndex].restrict) then
                        joinRace = false
                        notifyPlayer("Cannot join race.  Player needs to be in restricted vehicle.")
                    end
                else
                    joinRace = false
                    notifyPlayer("Cannot join race.  Player needs to be in restricted vehicle.")
                end
            elseif "class" == starts[closestIndex].rtype then
                if starts[closestIndex].vclass ~= -1 then
                    if vehicle ~= nil then
                        if GetVehicleClass(vehicle) ~= starts[closestIndex].vclass then
                            joinRace = false
                            notifyPlayer("Cannot join race.  Player needs to be in vehicle of " ..
                                             getClassName(starts[closestIndex].vclass) .. " class.")
                        end
                    else
                        joinRace = false
                        notifyPlayer("Cannot join race.  Player needs to be in vehicle of " ..
                                         getClassName(starts[closestIndex].vclass) .. " class.")
                    end
                else
                    if #starts[closestIndex].vehicleList == 0 then
                        joinRace = false
                        notifyPlayer("Cannot join race.  No valid vehicles in vehicle list.")
                    else
                        local list = ""
                        for _, vehName in pairs(starts[closestIndex].vehicleList) do
                            list = list .. vehName .. ", "
                        end
                        list = string.sub(list, 1, -3)
                        if vehicle ~= nil then
                            if vehicleInList(vehicle, starts[closestIndex].vehicleList) == false then
                                joinRace = false
                                notifyPlayer(
                                    "Cannot join race.  Player needs to be in one of the following vehicles: " .. list)
                            end
                        else
                            joinRace = false
                            notifyPlayer("Cannot join race.  Player needs to be in one of the following vehicles: " ..
                                             list)
                        end
                    end
                end
            elseif "rand" == starts[closestIndex].rtype then
                if #starts[closestIndex].vehicleList == 0 then
                    joinRace = false
                    notifyPlayer("Cannot join race.  No valid vehicles in vehicle list.")
                else
                    if vehicle ~= nil then
                        originalVehicleHash = GetEntityModel(vehicle)
                        colorPri, colorSec = GetVehicleColours(vehicle)
                    end
                    if starts[closestIndex].vclass ~= nil then
                        if nil == starts[closestIndex].svehicle then
                            if vehicle ~= nil then
                                if GetVehicleClass(vehicle) ~= starts[closestIndex].vclass then
                                    joinRace = false
                                    notifyPlayer("Cannot join race.  Player needs to be in vehicle of " ..
                                                     getClassName(starts[closestIndex].vclass) .. " class.")
                                end
                            else
                                joinRace = false
                                notifyPlayer("Cannot join race.  Player needs to be in vehicle of " ..
                                                 getClassName(starts[closestIndex].vclass) .. " class.")
                            end
                        end
                    end
                end
            end
            if true == joinRace then
                removeRacerBlipGT()
                TriggerServerEvent("races:join", closestIndex, PedToNet(player), nil)
            end
        end
    end
end

RegisterNetEvent("races:register")
AddEventHandler("races:register", register)

RegisterNetEvent("races:unregister")
AddEventHandler("races:unregister", unregister)

RegisterNetEvent("races:hide")
AddEventHandler("races:hide", hide)

RegisterNetEvent("races:join")
AddEventHandler("races:join", join)

return raceRegistration
