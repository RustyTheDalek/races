SetManualShutdownLoadingScreenNui(true)

local raceState = racingStates.Idle

function RaceState()
    return raceState
end

local registerBlipColor <const> = 83      -- purple

local selectedBlipColor <const> = 1       -- red

local blipRouteColor <const> = 18         -- light blue

local registerSprite <const> = 58         -- circled star

local finishCheckpoint <const> = 4        -- cylinder checkered flag
local plainCheckpoint <const> = 45        -- cylinder
local arrow3Checkpoint <const> = 0        -- cylinder with 3 arrows

local defaultTier <const> = "none"        -- default race Tier
local defaultSpecialClass <const> = "none"-- default race Tier
local defaultLaps <const> = 3             -- default number of laps in a race
local defaultTimeout <const> = 1200       -- default DNF timeout
local defaultDelay <const> = 5            -- default race start delay
local defaultVehicle <const> = "adder"    -- default spawned vehicle

local raceIndex = -1                      -- index of race player has joined

local numLaps = -1                        -- number of laps in current race
local currentLap = -1                     -- current lap

local numWaypointsPassed = -1             -- number of waypoints player has passed
local previousWaypoint = -1
local currentWaypoints = {}               -- current waypoint - for multi-lap races, actual current waypoint is currentWaypoint % #waypoints + 1

local position = -1                       -- position in race out of numRacers players
local numRacers = -1                      -- number of players in race - no DNF players included

local nextWaypoints = {}                   -- Next checkpoints in world

local DNFTimeout = -1                     -- DNF timeout after first player finishes the race
local beginDNFTimeout = false             -- flag indicating if DNF timeout should begin
local timeoutStart = -1                   -- start time of DNF timeout

local vehicleList = {}                    -- vehicle list used for custom class races and random races
local restrictedHash = nil                -- vehicle hash of race with restricted vehicle
local restrictedClass = nil               -- restricted vehicle class

local customClassVehicleList = {}         -- list of vehicles in class Custom (-1) race

local originalVehicleHash = nil           -- vehicle hash of original vehicle before switching to other vehicles in random vehicle races
local colorPri = -1                       -- primary color of original vehicle
local colorSec = -1                       -- secondary color of original vehicle

local startVehicle = nil                  -- vehicle name hash of starting vehicle used in random races
local raceVehicleHash = nil               -- hash of current vehicle being driven
local raceVehicleName = nil
local currentVehicleName = nil            -- name of current vehicle being driven

local randVehicles = {}                   -- list of random vehicles used in random vehicle races
local randVehiclesUsed = {}               -- list of random vehicles already used in a random vehicle race


local respawnLock = false
local respawnCtrlPressed = false          -- flag indicating if respawn crontrol is pressed
local respawnTime = -1                    -- time when respawn control pressed
local respawnTimer = 500
local startCoord = nil                    -- coordinates of vehicle once race has started

local results = {}                        -- results[] = {source, playerName, finishTime, bestLapTime, vehicleName}

local starts = {}                         -- starts[playerID] = {isPublic, trackName, owner, tier, laps, timeout, rtype, restrict, vclass, svehicle, vehicleList, blip, checkpoint, gridData} - registration points

local panelShown = false                  -- flag indicating if main, edit, register, or list panel is shown
local allVehiclesList = {}                -- list of all vehicles from vehicles.txt
local allVehiclesHTML = ""                -- html option list of all vehicles

local enteringVehicle = false             -- flag indicating if player is entering a vehicle

local localPlayerPed = GetPlayerPed(-1)
local localVehicle = GetVehiclePedIsIn(localPlayerPed, false)

local ready = false

local currentRace = {
    trackName = "",
    raceType = ""
}

local ghosting = Ghosting:New()
local playerDisplay = PlayerDisplay:New()
local currentLapTimer = Timer:New()

local currentTrack = Track:New()
local trackEditor = TrackEditor:New()

local configData

local boost_active = false

local lobbySpawn = { x = -1413, y = -3007, z = 13.95}
local spawnOffsetVector = { x = 1, y = 0, z = 0}

local function getOffsetSpawn(startingSpawn)
    local offsetSpawn = vector3(startingSpawn.x, startingSpawn.y, startingSpawn.z)
    local offsetVector = vector3(spawnOffsetVector.x, spawnOffsetVector.y, spawnOffsetVector.z)

    offsetSpawn = offsetSpawn + (offsetVector * (GetPlayerServerId(PlayerId()) - 1))

    return {
        x = offsetSpawn.x,
        y = offsetSpawn.y,
        z = offsetSpawn.z,
        heading = startingSpawn.heading
    }
end

function SetSpawning()

    while(exports == nil) do
        print("Exports nil. waiting")
        Citizen.wait(1)
    end

    print("Setting autospawn")
    exports.spawnmanager:setAutoSpawnCallback(function()

        print("Overriding auto spawn")

        local spawnPosition = lobbySpawn

        if racingStates.Racing == raceState then
            spawnPosition = startCoord
            spawnPosition = currentTrack:GetTrackRespawnPosition(previousWaypoint)
        elseif racingStates.Registering == raceState then
            spawnPosition = startCoord
        elseif racingStates.Joining == raceState then
            spawnPosition = starts[raceIndex].registerPosition
        elseif racingStates.Idle == raceState then
            spawnPosition = getOffsetSpawn(lobbySpawn)
        end
        
        exports.spawnmanager:spawnPlayer({
            x = spawnPosition.x,
            y = spawnPosition.y,
            z = spawnPosition.z,
            heading = spawnPosition.heading,
            skipFade = true
        })
    end)

    exports.spawnmanager:setAutoSpawn(true)
    exports.spawnmanager:forceRespawn()
end

AddEventHandler('onClientGameTypeStart', SetSpawning)
AddEventHandler('onClientResourceStart', function(resourceName)

    if(GetCurrentResourceName() ~= resourceName) then
        return
    end
    SetSpawning()
end)
AddEventHandler('baseevents:onPlayerDied', SetSpawning)
AddEventHandler('baseevents:onPlayerKilled', SetSpawning)
AddEventHandler('baseevents:onPlayerWasted', SetSpawning)

math.randomseed(GetCloudTimeAsInt())

TriggerServerEvent("races:init")

local function notifyPlayer(msg)
    TriggerEvent("chat:addMessage", {
        color = { 255, 0, 0 },
        multiline = true,
        args = { "[races:client]", msg }
    })
end

function sendMessage(msg)
    if true == panelShown then
        SendNUIMessage({
            panel = "reply",
            message = string.gsub(msg, "\n", "<br>")
        })
    end
    notifyPlayer(msg)
end

local function TeleportPlayer(position, heading)

    local player = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(player, false)

    print(vehicle)

    local entityToMove
    if vehicle ~= nil and vehicle ~= 0 then
        print("moving vehicle")
        entityToMove = vehicle
    else
        entityToMove = player
        print("moving player")
    end

    --Heading needs to be a float
    if (heading ~= nil) then
        heading = int2float(heading)
    end

    print(heading)

    SetEntityCoords(entityToMove, position.x, position.y, position.z, false, false, false, true)
    SetEntityHeading(entityToMove, heading)

end

local function removeRegistrationPoint(rIndex)
    RemoveBlip(starts[rIndex].blip)             -- delete registration blip
    DeleteCheckpoint(starts[rIndex].checkpoint) -- delete registration checkpoint
    starts[rIndex] = nil
end

local function minutesSeconds(milliseconds)
    local seconds = milliseconds / 1000.0
    local minutes = math.floor(seconds / 60.0)
    seconds = seconds - minutes * 60.0
    return minutes, seconds
end

local function putPedInVehicle(ped, vehicleHash, coord)
    coord = coord or GetEntityCoords(ped)
    local vehicle = CreateVehicle(vehicleHash, coord.x, coord.y, coord.z, GetEntityHeading(ped), true, false)
    SetModelAsNoLongerNeeded(vehicleHash)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetPedIntoVehicle(ped, vehicle, -1)
    SetVehRadioStation(vehicle, "OFF")
    return vehicle
end

local function switchVehicle(ped, vehicleHash)
    sendMessage("Vehicle Hash " .. (vehicleHash))
    sendMessage("Vehicle Display name " .. GetDisplayNameFromVehicleModel(vehicleHash))
    sendMessage("Switched to " .. GetLabelText(GetDisplayNameFromVehicleModel(vehicleHash)))
    local vehicle = nil
    if vehicleHash ~= nil then
        if(CarTierUIActive()) then
            print("cartierspawn")
            vehicle = exports.CarTierUI:RequestVehicle(vehicleHash)
        else 
            print("defaultspawn")
            local pedVehicle = GetVehiclePedIsIn(ped, false)
            if pedVehicle ~= 0 then
                if GetPedInVehicleSeat(pedVehicle, -1) == ped then
                    RequestModel(vehicleHash)
                    while HasModelLoaded(vehicleHash) == false do
                        Citizen.Wait(0)
                    end
                    local passengers = {}
                    for i = 0, GetVehicleModelNumberOfSeats(GetEntityModel(pedVehicle)) - 2 do
                        local passenger = GetPedInVehicleSeat(pedVehicle, i)
                        if passenger ~= 0 then
                            passengers[#passengers + 1] = { ped = passenger, seat = i }
                        end
                    end
                    local coord = GetEntityCoords(pedVehicle)
                    local speed = GetEntitySpeed(ped)
                    SetEntityAsMissionEntity(pedVehicle, true, true)
                    DeleteVehicle(pedVehicle)
                    vehicle = putPedInVehicle(ped, vehicleHash, coord)
                    SetVehicleForwardSpeed(vehicle, speed)
                    for _, passenger in pairs(passengers) do
                        SetPedIntoVehicle(passenger.ped, vehicle, passenger.seat)
                    end
                end
            else
                RequestModel(vehicleHash)
                while HasModelLoaded(vehicleHash) == false do
                    Citizen.Wait(0)
                end
                vehicle = putPedInVehicle(ped, vehicleHash, nil)
            end
        end
    end
    return vehicle
end

local function getClassName(vclass)
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

local function vehicleInList(vehicle, list)
    for _, vehName in pairs(list) do
        if GetEntityModel(vehicle) == GetHashKey(vehName) then
            return true
        end
    end
    return false
end

local function StartRaceEffects()
    if(currentRace.raceType == 'ghost') then
        ghosting:StartGhostingNoTimer()
    end
end

local function StopRaceEffects()
    print("Stopping race effect")
    if currentRace.raceType == 'wanted' then
        SetMaxWantedLevel(0)
        SetPlayerWantedLevel(PlayerId(), 0, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
    elseif currentRace.raceType == 'ghost' then
        ghosting:StopGhosting()
    end

    currentRace.raceType = ''
end

local function finishRace(dnf)
    PlaySoundFrontend(-1, "CHECKPOINT_UNDER_THE_BRIDGE", "HUD_MINI_GAME_SOUNDSET", true)
    StopRaceEffects()
    TriggerServerEvent("races:finish", raceIndex, numWaypointsPassed, dnf, nil)
    ClearDNFTime()
    SetLeaderboardLower(true)
    ResetReady()
    currentVehicleName = nil
    raceVehicleHash = nil
    raceVehicleName = nil
    currentRace.currentTrack = ""
    currentRace.raceType = ""
    currentTrack:RestoreBlips()
    currentTrack:RouteToTrack()
    if originalVehicleHash ~= nil then
        local vehicle = switchVehicle(PlayerPedId(), originalVehicleHash)
        if vehicle ~= nil then
            SetVehicleColours(vehicle, colorPri, colorSec)
            SetEntityAsNoLongerNeeded(vehicle)
        end
    end
    raceState = racingStates.Idle
end

local function updateList()
    table.sort(vehicleList)
    local html = ""
    for _, vehicle in ipairs(vehicleList) do
        html = html .. "<option value = \"" .. vehicle .. "\">" .. vehicle .. "</option>"
    end
    SendNUIMessage({
        update = "vehicleList",
        vehicleList = html
    })
end

local function edit()
    if racingStates.Idle == raceState then
        raceState = racingStates.Editing
        trackEditor:StartEditing(currentTrack)
        sendMessage("Editing started.\n")
    elseif racingStates.Editing == raceState then
        raceState = racingStates.Idle
        trackEditor:StopEditing()
        sendMessage("Editing stopped.\n")
    else
        sendMessage("Cannot edit waypoints.  Leave race first.\n")
    end
end

local function clear()
    if racingStates.Idle == raceState then
        currentTrack:Clear()
        sendMessage("Waypoints cleared.\n")
    elseif racingStates.Editing == raceState then
        trackEditor:Clear()
        sendMessage("Waypoints cleared.\n")
    else
        sendMessage("Cannot clear waypoints.  Leave race first.\n")
    end
end

local function reverse()
    if currentTrack:GetTotalWaypoints() < 2 then
        sendMessage("Cannot reverse waypoints.  Track needs to have at least 2 waypoints.\n")
        return
    end

    if racingStates.Idle == raceState then
        currentTrack.savedTrackName = nil
        currentTrack:LoadWaypointBlips(currentTrack:WaypointsToCoordsRev())
        sendMessage("Waypoints reversed.\n")
    elseif racingStates.Editing == raceState then
        trackEditor:Reverse()
        sendMessage("Waypoints reversed.\n")
    else
        sendMessage("Cannot reverse waypoints.  Leave race first.\n")
    end
end

local function loadTrack(access, trackName)
    
    if "pvt" ~= access and "pub" ~= access then
        sendMessage("Cannot load.  Invalid access type.\n")
        return
    end

    if trackName == nil then
        sendMessage("Cannot load.  Name required.\n")
        return
    end

    if racingStates.Idle ~= raceState and racingStates.Editing ~= raceState then
        sendMessage("Cannot load.  Leave race first.\n")
        return
    end

    TriggerServerEvent("races:load", "pub" == access, trackName)
end

local function deleteTrack(access, trackName)
    if "pvt" == access or "pub" == access then
        if trackName ~= nil then
            TriggerServerEvent("races:delete", "pub" == access, trackName)
        else
            sendMessage("Cannot delete.  Name required.\n")
        end
    else
        sendMessage("Cannot delete.  Invalid access type.\n")
    end
end

local function bestLapTimes(access, trackName)
    if "pvt" == access or "pub" == access then
        if trackName ~= nil then
            TriggerServerEvent("races:blt", "pub" == access, trackName)
        else
            sendMessage("Cannot list best lap times.  Name required.\n")
        end
    else
        sendMessage("Cannot list best lap times.  Invalid access type.\n")
    end
end

local function listTracks(access)
    if "pvt" == access or "pub" == access then
        TriggerServerEvent("races:list", "pub" == access)
    else
        sendMessage("Cannot list tracks.  Invalid access type.\n")
    end
end

local function register(tier, specialClass, laps, timeout, rtype, arg7, arg8)
    tier = (nil == tier or "." == tier) and defaultTier or string.lower(tier)
    specialClass = (nil == specialClass or "." == specialClass) and defaultSpecialClass or specialClass

    laps = (nil == laps or "." == laps) and defaultLaps or math.tointeger(tonumber(laps))

    if(laps == nil or laps <= 0) then
        sendMessage("Invalid number of laps.\n")
        return
    end

    timeout = (nil == timeout or "." == timeout) and defaultTimeout or math.tointeger(tonumber(timeout))

    if timeout == nil or timeout <= 0 then
        sendMessage("Invalid DNF timeout.\n")
        return
    end

    if raceState == racingStates.Editing then
        sendMessage("Cannot register.  Stop editing first.\n")
        return
    elseif (raceState ~= racingStates.Idle) then
        sendMessage("Cannot register.  Leave race first.\n")
        return
    end

    if currentTrack:GetTotalWaypoints() <= 1 then
        sendMessage("Cannot register.  Track needs to have at least 2 waypoints.\n")
        return
    end

    if (laps > 1 and currentTrack.startIsFinish == false) then
        sendMessage(
            "For multi-lap races, start and finish waypoints need to be the same: While editing waypoints, select finish waypoint first, then select start waypoint.  To separate start/finish waypoint, add a new waypoint or select start/finish waypoint first, then select highest numbered waypoint.\n")
    end

    if "." == arg7 then
        arg7 = nil
    end
    if "." == arg8 then
        arg8 = nil
    end
    local restrict = nil
    local vclass = nil
    local svehicle = nil
    local vehList = nil
    
    if "rest" == rtype then
        restrict = arg7
        if nil == restrict or IsModelInCdimage(restrict) ~= 1 or IsModelAVehicle(restrict) ~= 1 then
            sendMessage("Cannot register.  Invalid restricted vehicle.\n")
            return
        end
    elseif "class" == rtype then
        vclass = math.tointeger(tonumber(arg7))
        if nil == vclass or vclass < -1 or vclass > 21 then
            sendMessage("Cannot register.  Invalid vehicle class.\n")
            return
        end
        if -1 == vclass then
            if #vehicleList == 0 then
                sendMessage("Cannot register.  Vehicle list is empty.\n")
                return
            end
            vehList = vehicleList
        end
    elseif "rand" == rtype then
        if #vehicleList == 0 then
            sendMessage("Cannot register.  Vehicle list is empty.\n")
            return
        end
        vclass = math.tointeger(tonumber(arg7))
        if nil == vclass then
            vehList = vehicleList
        else
            if vclass < 0 or vclass > 21 then
                sendMessage("Cannot register.  Invalid vehicle class.\n")
                return
            end
            vehList = {}
            for _, vehicle in pairs(vehicleList) do
                if GetVehicleClassFromName(vehicle) == vclass then
                    vehList[#vehList + 1] = vehicle
                end
            end
            if #vehList == 0 then
                sendMessage("Cannot register.  Vehicle list is empty.\n")
                return
            end
        end
        svehicle = arg8
        if svehicle ~= nil then
            if IsModelInCdimage(svehicle) ~= 1 or IsModelAVehicle(svehicle) ~= 1 then
                sendMessage("Cannot register.  Invalid start vehicle.\n")
                return
            elseif vclass ~= nil and GetVehicleClassFromName(svehicle) ~= vclass then
                sendMessage(
                "Cannot register.  Start vehicle not of restricted vehicle class.\n")
                return
            end
        end
    elseif "wanted" == rtype then
        print("wanted race type")
    elseif "ghost" == rtype then
        print("ghost race type")
    elseif rtype ~= nil then
        sendMessage("Cannot register.  Unknown race type.\n")
        return
    end
    local rdata = {
        tier = tier,
        laps = laps,
        timeout = timeout,
        rtype = rtype,
        restrict = restrict,
        vclass = vclass,
        svehicle = svehicle,
        vehicleList = vehList,
        specialClass = specialClass,
        map = currentTrack.map
    }

    currentTrack:Register(rdata)
end

local function unregister()
    TriggerServerEvent("races:unregister")
end

local function setupGrid()
    TriggerServerEvent("races:grid")
end

local function autojoin()
    TriggerServerEvent("races:autojoin")
end

local function startRace(delay, override)

    if override == nil then
        override = false
    end

    print(override)
    delay = math.tointeger(tonumber(delay)) or defaultDelay
    if delay ~= nil and delay >= 5 then
        TriggerServerEvent("races:start", delay, override)
    else
        sendMessage("Cannot start.  Invalid delay.\n")
    end
end

local function addVeh(vehicle)
    if vehicle ~= nil then
        if IsModelInCdimage(vehicle) == 1 and IsModelAVehicle(vehicle) == 1 then
            vehicleList[#vehicleList + 1] = vehicle
            if true == panelShown then
                updateList()
            end
            sendMessage("'" .. vehicle .. "' added to vehicle list.\n")
        else
            sendMessage("Cannot add vehicle.  Invalid vehicle.\n")
        end
    else
        sendMessage("Cannot add vehicle.  Vehicle name required.\n")
    end
end

local function delVeh(vehicle)
    if vehicle ~= nil then
        if IsModelInCdimage(vehicle) == 1 and IsModelAVehicle(vehicle) == 1 then
            for i = 1, #vehicleList do
                if vehicleList[i] == vehicle then
                    table.remove(vehicleList, i)
                    if true == panelShown then
                        updateList()
                    end
                    sendMessage("'" .. vehicle .. "' deleted from vehicle list.\n")
                    return
                end
            end
            sendMessage("Cannot delete vehicle.  '" .. vehicle .. "' not found.\n")
        else
            sendMessage("Cannot delete vehicle.  Invalid vehicle.\n")
        end
    else
        sendMessage("Cannot delete vehicle.  Vehicle name required.\n")
    end
end

local function addClass(class)
    class = math.tointeger(tonumber(class))
    if class ~= nil and class >= 0 and class <= 21 then
        for _, vehicle in pairs(allVehiclesList) do
            if GetVehicleClassFromName(vehicle) == class then
                vehicleList[#vehicleList + 1] = vehicle
            end
        end
        if true == panelShown then
            updateList()
        end
        sendMessage("Vehicles of class " .. getClassName(class) .. " added to vehicle list.\n")
    else
        sendMessage("Cannot add vehicles to vehicle list.  Invalid vehicle class.\n")
    end
end

local function deleteClass(class)
    class = math.tointeger(tonumber(class))
    if class ~= nil and class >= 0 and class <= 21 then
        for i = 1, #vehicleList do
            while true do
                if vehicleList[i] ~= nil then
                    if GetVehicleClassFromName(vehicleList[i]) == class then
                        table.remove(vehicleList, i)
                    else
                        break
                    end
                else
                    break
                end
            end
        end
        if true == panelShown then
            updateList()
        end
        sendMessage("Vehicles of class " .. getClassName(class) .. " deleted from vehicle list.\n")
    else
        sendMessage("Cannot delete vehicles from vehicle list.  Invalid vehicle class.\n")
    end
end

local function addAllVeh()
    for _, vehicle in pairs(allVehiclesList) do
        vehicleList[#vehicleList + 1] = vehicle
    end
    if true == panelShown then
        updateList()
    end
    sendMessage("Added all vehicles to vehicle list.\n")
end

local function delAllVeh()
    vehicleList = {}
    if true == panelShown then
        updateList()
    end
    sendMessage("All vehicles deleted from vehicle list.\n")
end

local function listVeh()
    if #vehicleList > 0 then
        table.sort(vehicleList)
        local msg = "Vehicle list: "
        for i = 1, #vehicleList do
            msg = msg .. vehicleList[i] .. ", "
        end
        msg = string.sub(msg, 1, -3)
        sendMessage(msg)
    else
        sendMessage("No vehicles in vehicle list.\n")
    end
end

local function loadLst(access, name)
    if "pvt" == access or "pub" == access then
        if name ~= nil then
            TriggerServerEvent("races:loadLst", "pub" == access, name)
        else
            sendMessage("Cannot load vehicle list.  Name required.\n")
        end
    else
        sendMessage("Cannot load vehicle list.  Invalid access type.\n")
    end
end

local function saveLst(access, name)
    if "pvt" == access or "pub" == access then
        if name ~= nil then
            if #vehicleList > 0 then
                TriggerServerEvent("races:saveLst", "pub" == access, name, vehicleList)
            else
                sendMessage("Cannot save vehicle list.  List is empty.\n")
            end
        else
            sendMessage("Cannot save vehicle list.  Name required.\n")
        end
    else
        sendMessage("Cannot save vehicle list.  Invalid access type.\n")
    end
end

local function overwriteLst(access, name)
    if "pvt" == access or "pub" == access then
        if name ~= nil then
            if #vehicleList > 0 then
                TriggerServerEvent("races:overwriteLst", "pub" == access, name, vehicleList)
            else
                sendMessage("Cannot overwrite vehicle list.  List is empty.\n")
            end
        else
            sendMessage("Cannot overwrite vehicle list.  Name required.\n")
        end
    else
        sendMessage("Cannot overwrite vehicle list.  Invalid access type.\n")
    end
end

local function deleteLst(access, name)
    if "pvt" == access or "pub" == access then
        if name ~= nil then
            TriggerServerEvent("races:deleteLst", "pub" == access, name)
        else
            sendMessage("Cannot delete vehicle list.  Name required.\n")
        end
    else
        sendMessage("Cannot delete vehicle list.  Invalid access type.\n")
    end
end

local function listLsts(access)
    if "pvt" == access or "pub" == access then
        TriggerServerEvent("races:listLsts", "pub" == access)
    else
        sendMessage("Cannot list vehicle lists.  Invalid access type.\n")
    end
end

local function ClearCurrentWaypoints()
    for _, currentWaypoint in ipairs(currentWaypoints) do
        DeleteCheckpoint(currentWaypoint.checkpoint)
    end

    for k in next, currentWaypoints do rawset(currentWaypoints, k, nil) end

end

local function leave()
    local player = PlayerPedId()
    currentVehicleName = nil
    raceVehicleHash = nil
    raceVehicleName = nil
    if racingStates.Joining == raceState then
        raceState = racingStates.Idle
        ResetReady()
        ClearLeaderboard()
        TriggerServerEvent("races:leave", raceIndex)
        playerDisplay:ResetRaceBlips()
        sendMessage("Left race.\n")
    elseif racingStates.Racing == raceState then
        if IsPedInAnyVehicle(player, false) == 1 then
            FreezeEntityPosition(GetVehiclePedIsIn(player, false), false)
        end
        RenderScriptCams(false, false, 0, true, true)
        ClearCurrentWaypoints()
        finishRace(true)
        playerDisplay:ResetRaceBlips()
        ResetReady()
        ClearLeaderboard()
        TriggerServerEvent("races:removeFromLeaderboard", raceIndex)
        sendMessage("Left race.\n")
    else
        sendMessage("Cannot leave.  Not joined to any race.\n")
    end
end

local function endrace()
    TriggerServerEvent("races:endrace")
end

local function repairVehicle(vehicle)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleFixed(vehicle)
end

local function respawn()
    if racingStates.Racing == raceState then
        ClearRespawnIndicator()
        if(currentRace.raceType ~= 'ghost') then
            ghosting:StartGhosting(configData['ghostingTime'])
        end
        local passengers = {}
        local player = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(player, true)
        local currentVehicleHash = GetEntityModel(vehicle)
        local coord = startCoord
        coord = currentTrack:GetTrackRespawnPosition(previousWaypoint)

        print(vehicle)
        print(currentVehicleHash)

        --Spawn vehicle is there is none
        if vehicle == 0 and raceVehicleHash ~= nil then
            if(CarTierUIActive()) then
                print("carTierSpawn")
                vehicle = exports.CarTierUI:RequestVehicle(raceVehicleName)
                raceVehicleHash = GetEntityModel(vehicle)
            else
                print("No vehicle found")
                RequestModel(raceVehicleName)
                while HasModelLoaded(raceVehicleName) == false do
                    Citizen.Wait(0)
                end
                vehicle = putPedInVehicle(player, raceVehicleName, coord)
                SetEntityAsNoLongerNeeded(vehicle)
                SetEntityHeading(vehicle, coord.heading)
                repairVehicle(vehicle)
                for _, passenger in pairs(passengers) do
                    SetPedIntoVehicle(passenger.ped, vehicle, passenger.seat)
                end
            end
        elseif raceVehicleHash == nil then
            print("Respawning on foot")
            SetEntityCoords(player, coord.x, coord.y, coord.z, false, false, false, true)
            SetEntityHeading(player, coord.heading)
        else
            print("Using previous vehicle found")
            repairVehicle(vehicle)
            SetEntityCoords(vehicle, coord.x, coord.y, coord.z, false, false, false, true)
            SetEntityHeading(vehicle, coord.heading)
            SetVehicleEngineOn(vehicle, true, true, false)
            SetVehRadioStation(vehicle, "OFF")
            SetPedIntoVehicle(player, vehicle, -1)
        end
    else
        sendMessage("Cannot respawn.  Not in a race.\n")
    end
end

local function viewResults(chatOnly)
    local msg = nil
    if #results > 0 then
        -- results[] = {source, playerName, finishTime, bestLapTime, vehicleName}
        msg = "Race results:\n"
        for pos, result in ipairs(results) do
            if -1 == result.finishTime then
                msg = msg .. "DNF - " .. result.playerName
                if result.bestLapTime >= 0 then
                    local minutes, seconds = minutesSeconds(result.bestLapTime)
                    msg = msg .. (" - best lap %02d:%05.2f using %s"):format(minutes, seconds, result.vehicleName)
                end
                msg = msg .. "\n"
            else
                local fMinutes, fSeconds = minutesSeconds(result.finishTime)
                local lMinutes, lSeconds = minutesSeconds(result.bestLapTime)
                msg = msg ..
                ("%d - %02d:%05.2f - %s - best lap %02d:%05.2f using %s\n"):format(pos, fMinutes, fSeconds,
                result.playerName, lMinutes, lSeconds, result.vehicleName)
            end
        end
    else
        msg = "No results.\n"
    end
    if true == chatOnly then
        notifyPlayer(msg)
    else
        sendMessage(msg)
    end
end

local function spawn(vehicleHash)
    vehicleHash = vehicleHash or defaultVehicle

    if(CarTierUIActive()) then
        print("cartierspawn")
        print(vehicleHash)
        exports.CarTierUI:RequestVehicle(vehicleHash)
    else
        print("defaultspawn")
        if IsModelInCdimage(vehicleHash) == 1 and IsModelAVehicle(vehicleHash) == 1 then
            RequestModel(vehicleHash)
            while HasModelLoaded(vehicleHash) == false do
                Citizen.Wait(0)
            end
            local vehicle = putPedInVehicle(PlayerPedId(), vehicleHash, nil)
            SetEntityAsNoLongerNeeded(vehicle)
    
            sendMessage("'" .. GetLabelText(GetDisplayNameFromVehicleModel(vehicleHash)) .. "' spawned.\n")
        else
            sendMessage("Cannot spawn vehicle.  Invalid vehicle.\n")
        end
    end
end

local function lvehicles(vclass)
    vclass = math.tointeger(tonumber(vclass))
    if nil == vclass or (vclass >= 0 and vclass <= 21) then
        local msg = "Available vehicles"
        if nil == vclass then
            msg = msg .. ": "
        else
            msg = msg .. " of class " .. getClassName(vclass) .. ": "
        end
        local vehicleFound = false
        for _, vehicle in ipairs(allVehiclesList) do
            if nil == vclass or GetVehicleClassFromName(vehicle) == vclass then
                msg = msg .. vehicle .. ", "
                vehicleFound = true
            end
        end
        if false == vehicleFound then
            msg = "No vehicles in list."
        else
            msg = string.sub(msg, 1, -3)
        end
        sendMessage(msg)
    else
        sendMessage("Cannot list vehicles.  Invalid vehicle class.\n")
    end
end

local function showPanel(panel)
    panelShown = true
    if nil == panel then
        SetNuiFocus(true, true)
        TriggerServerEvent("races:trackNames", false, nil)
        TriggerServerEvent("races:trackNames", true, nil)
        SendNUIMessage({
            panel = "main",
            defaultVehicle = defaultVehicle,
            allVehicles = allVehiclesHTML
        })
    elseif "edit" == panel then
        SetNuiFocus(true, true)
        TriggerServerEvent("races:trackNames", false, nil)
        TriggerServerEvent("races:trackNames", true, nil)
        SendNUIMessage({
            panel = "edit"
        })
    elseif "register" == panel then
        SetNuiFocus(true, true)
        TriggerServerEvent("races:trackNames", false, nil)
        TriggerServerEvent("races:trackNames", true, nil)
        SendNUIMessage({
            panel = "register",
            defaultLaps = defaultLaps,
            defaultTimeout = defaultTimeout,
            defaultDelay = defaultDelay,
            allVehicles = allVehiclesHTML
        })
    elseif "list" == panel then
        SetNuiFocus(true, true)
        updateList()
        TriggerServerEvent("races:listNames", false, nil)
        TriggerServerEvent("races:listNames", true, nil)
        SendNUIMessage({
            panel = "list",
            allVehicles = allVehiclesHTML
        })
    else
        notifyPlayer("Invalid panel.\n")
        panelShown = false
    end
end

function SendToRaceTier(tier, specialClass)

    if(not CarTierUIActive()) then
        print("CarTier not present, ignoring")
        return
    end

    local openCarTierUI = tier ~= "none" or specialClass ~= "none"

    local carTierRaceType = 0

    if (raceIndex ~= -1) then 
        if(#randVehicles > 0) then
            carTierRaceType = 3
        elseif (currentRace.trackName and string.find(string.lower(currentRace.trackName), 'wacky')) then
            carTierRaceType = 2
        end
    end

    exports.CarTierUI:RaceFilters(carTierRaceType, tier, specialClass, openCarTierUI)

end

function ResetCarTier()

    if(not CarTierUIActive()) then
        print("CarTier not present, ignoring")
        return
    end

    exports.CarTierUI:RaceFilters(0, 'NONE', 'none', false)
end

function SendRaceData(raceData)
    SendNUIMessage({
        type = "leaderboard",
        action = "sendRaceData",
        current_lap = 1,
        total_laps = raceData.laps,
        total_checkpoints = raceData.totalCheckpoints
    })
end

function UpdateCurrentCheckpoint()
    SendNUIMessage({
        type = "leaderboard",
        action = "updatecurrentcheckpoint",
        current_checkpoint = currentTrack.startIsFinish == true and previousWaypoint or previousWaypoint - 1
    })
end

function UpdateCurrentLap()
    SendNUIMessage({
        type = "leaderboard",
        action = "updatecurrentlap",
        current_lap = currentLap
    })
end

function SendCurrentLapTime(minutes, seconds)
    SendNUIMessage({
        type = "leaderboard",
        action = "updatecurrentlaptime",
        source = GetPlayerServerId(PlayerId()),
        minutes = minutes,
        seconds = seconds
    })
end

function UpdateDNFTime(minutes, seconds)
    SendNUIMessage({
        type = "leaderboard",
        action = "update_dnf_time",
        minutes = minutes,
        seconds = seconds
    })
end

function ClearDNFTime()
    SendNUIMessage({
        type = "leaderboard",
        action = "clear_dnf_time"
    })
end

RegisterNetEvent("races:updatebestlaptime")
AddEventHandler("races:updatebestlaptime", function(source, bestLapTime)
    local minutes, seconds = minutesSeconds(bestLapTime)
    SendNUIMessage({
        type = "leaderboard",
        action = "updatebestlaptime",
        source = source,
        minutes = minutes,
        seconds = seconds
    })
end)

function SetJoinMessage(message)
    SendNUIMessage({
        type = "ready",
        action = "set_join_text",
        value = message
    })
end

--#region NUI callbacks

RegisterNUICallback("edit", function()
    edit()
end)

RegisterNUICallback("clear", function()
    clear()
end)

RegisterNUICallback("reverse", function()
    reverse()
end)

RegisterNUICallback("load", function(data)
    loadTrack(data.access, data.trackName)
end)

RegisterNUICallback("save", function(data)
    local trackName = data.trackName
    if "" == trackName then
        trackName = nil
    end
    trackEditor:TrySave(data.access, trackName)
end)

RegisterNUICallback("overwrite", function(data)
    if racingStates.Editing == raceState then
        trackEditor:TryOverwrite(data.access, data.trackName, data.map)
        return
    else
        if "pvt" == data.access or "pub" == data.access then
            if data.trackName ~= nil then
                if currentTrack:GetTotalWaypoints() > 1 then
                    TriggerServerEvent("races:overwrite", "pub" == data.access, data.trackName, currentTrack:SerialiseWaypoints(), data.map)
                else
                    sendMessage("Cannot overwrite.  Track needs to have at least 2 waypoints.\n")
                end
            else
                sendMessage("Cannot overwrite.  Name required.\n")
            end
        else
            sendMessage("Cannot overwrite.  Invalid access type.\n")
        end
    end
end)

RegisterNUICallback("delete", function(data)
    deleteTrack(data.access, data.trackName)
end)

RegisterNUICallback("blt", function(data)
    bestLapTimes(data.access, data.trackName)
end)

RegisterNUICallback("list", function(data)
    listTracks(data.access)
end)

RegisterNUICallback("autojoin", function(data)
    autojoin()
end)

RegisterNUICallback("gridracers", function(data)
    setupGrid()
end)

RegisterNUICallback("register", function(data)

    local tier = data.tier
    if "" == tier then
        tier = nil
    end
    local specialClass = data.specialClass
    if specialClass == "" then
        specialClass = nil
    end
    local laps = data.laps
    if "" == laps then
        laps = nil
    end
    local timeout = data.timeout
    if "" == timeout then
        timeout = nil
    end
    local rtype = data.rtype
    if "norm" == rtype then
        rtype = nil
    end
    local restrict = data.restrict
    if "" == restrict then
        restrict = nil
    end
    local vclass = data.vclass
    if "-2" == vclass then
        vclass = nil
    end
    local svehicle = data.svehicle
    if "" == svehicle then
        svehicle = nil
    end
    if nil == rtype then
        register(tier, specialClass, laps, timeout, rtype, nil, nil)
    elseif "rest" == rtype then
        register(tier, specialClass, laps, timeout, rtype, restrict, nil)
    elseif "class" == rtype then
        register(tier, specialClass, laps, timeout, rtype, vclass, nil)
    elseif "rand" == rtype then
        register(tier, specialClass, laps, timeout, rtype, vclass, svehicle)
    else 
        register(tier, specialClass, laps, timeout, rtype, nil, nil)
    end
end)

RegisterNUICallback("unregister", function()
    unregister()
end)

RegisterNUICallback("start", function(data)
    local delay = data.delay
    if "" == delay then
        delay = nil
    end
    startRace(delay, true)
end)

RegisterNUICallback("add_veh", function(data)
    addVeh(data.vehicle)
end)

RegisterNUICallback("delete_veh", function(data)
    delVeh(data.vehicle)
end)

RegisterNUICallback("add_class", function(data)
    addClass(data.class)
end)

RegisterNUICallback("delete_class", function(data)
    deleteClass(data.class)
end)

RegisterNUICallback("add_all_veh", function()
    addAllVeh()
end)

RegisterNUICallback("delete_all_veh", function()
    delAllVeh()
end)

RegisterNUICallback("list_veh", function()
    listVeh()
end)

RegisterNUICallback("load_list", function(data)
    loadLst(data.access, data.name)
end)

RegisterNUICallback("save_list", function(data)
    local name = data.name
    if "" == name then
        name = nil
    end
    saveLst(data.access, name)
end)

RegisterNUICallback("overwrite_list", function(data)
    overwriteLst(data.access, data.name)
end)

RegisterNUICallback("delete_list", function(data)
    deleteLst(data.access, data.name)
end)

RegisterNUICallback("list_lists", function(data)
    listLsts(data.access)
end)

RegisterNUICallback("leave", function()
    leave()
end)

RegisterNUICallback("respawn", function()
    respawn()
end)

RegisterNUICallback("results", function()
    viewResults(false)
end)

RegisterNUICallback("spawn", function(data)
    local vehicle = data.vehicle
    if "" == vehicle then
        vehicle = nil
    end
    spawn(vehicle)
end)

RegisterNUICallback("lvehicles", function(data)
    local vclass = data.vclass
    if "-1" == vclass then
        vclass = nil
    end
    lvehicles(vclass)
end)

RegisterNUICallback("speedo", function(data)
    local unit = data.unit
    if "" == unit then
        unit = nil
    end
    setSpeedo(unit)
end)

RegisterNUICallback("show", function(data)
    local panel = data.panel
    if "main" == panel then
        panel = nil
    end
    showPanel(panel)
end)

RegisterNUICallback("close", function()
    panelShown = false
    SetNuiFocus(false, false)
end)

RegisterNUICallback("setnewmap", function(data)
    print(dump(data))
    currentTrack.map = data.map
    
    if(currentTrack.map ~= "") then
        notifyPlayer(("Map changed to %s"):format(data.map))
    else
        notifyPlayer("Map unset")
    end
end)

--#endregion

local function resetupgrades(vehicle)

    if vehicle == nil then
        local player = PlayerPedId()
        vehicle = GetVehiclePedIsIn(player, true)
    end

    local eUpgrade = GetVehicleMod(vehicle, 11)
    local bUpgrade = GetVehicleMod(vehicle, 12)
    local gUpgrade = GetVehicleMod(vehicle, 13)
    local nUpgrade = IsToggleModOn(vehicle, 17)
    local tUpgrade = IsToggleModOn(vehicle, 18)

    -- print("Engine Upgrade: " .. eUpgrade) --Engine upgrade
    -- print("Brakes Upgrade: " .. bUpgrade) --Brakes
    -- print("Gearbox Upgrade: " .. gUpgrade) --Gearbox
    -- print("Nitrous Upgrade: " .. tostring(nUpgrade)) --Nitrous
    -- print("Turbo Upgrade: " .. tostring(tUpgrade)) --Turbo


    if eUpgrade ~= -1 then
        SetVehicleMod(vehicle, 11, -1) --Engine upgrade
        TriggerServerEvent("races:resetupgrade", 11, currenTrack.savedTrackName)
    end

    if bUpgrade ~= -1 then
        SetVehicleMod(vehicle, 12, -1) --Brakes upgrade
        TriggerServerEvent("races:resetupgrade", 12, currenTrack.savedTrackName)
    end

    if gUpgrade ~= -1 then
        SetVehicleMod(vehicle, 13, -1) --Gearbox upgrade
        TriggerServerEvent("races:resetupgrade", 13, currenTrack.savedTrackName)
    end

    if nUpgrade ~= -1 then
        ToggleVehicleMod(vehicle, 17, 0) --Nitrous upgrade
        TriggerServerEvent("races:resetupgrade", 17)
    end

    if tUpgrade ~= -1 then
        ToggleVehicleMod(vehicle, 18, 0) --Turbo upgrade
        TriggerServerEvent("races:resetupgrade", 18)
    end

    -- print("Engine Upgrade: " .. GetVehicleMod(vehicle, 11)) --Engine upgrade
    -- print("Brakes Upgrade: " .. GetVehicleMod(vehicle, 12)) --Brakes
    -- print("Gearbox Upgrade: " .. GetVehicleMod(vehicle, 13)) --Gearbox
    -- print("Nitrous Upgrade: " .. tostring(IsToggleModOn(vehicle, 17))) --Nitrous
    -- print("Turbo Upgrade: " .. tostring(IsToggleModOn(vehicle, 18))) --Turbo

end

---@diagnostic disable-next-line: missing-parameter
RegisterCommand("races", function(_, args)
    if nil == args[1] then
        local msg = "Commands:\n"
        msg = msg .. "Required arguments are in square brackets.  Optional arguments are in parentheses.\n"
        msg = msg .. "/races - display list of available /races commands\n"
        msg = msg .. "/races edit - toggle editing track waypoints\n"
        msg = msg .. "/races clear - clear track waypoints\n"
        msg = msg .. "/races reverse - reverse order of track waypoints\n"
        msg = msg .. "\n"
        msg = msg ..
        "For the following '/races' commands, [access] = {'pvt', 'pub'} where 'pvt' operates on a private track and 'pub' operates on a public track\n"
        msg = msg .. "/races load [access] [name] - load private or public track saved as [name]\n"
        msg = msg .. "/races save [access] [name] - save new private or public track as [name]\n"
        msg = msg .. "/races overwrite [access] [name] - overwrite existing private or public track saved as [name]\n"
        msg = msg .. "/races delete [access] [name] - delete private or public track saved as [name]\n"
        msg = msg .. "/races blt [access] [name] - list 10 best lap times of private or public track saved as [name]\n"
        msg = msg .. "/races list [access] - list saved private or public tracks\n"
        msg = msg .. "\n"
        msg = msg ..
        "For the following '/races register' commands, (tier) defaults to none, (SpecialClass) defaults to none, (laps) defaults to 1 lap, (DNF timeout) defaults to 120 seconds and\n"
        msg = msg ..
        "/races register (tier) (laps) (DNF timeout) - register your race with no vehicle restrictions\n"
        msg = msg ..
        "/races register (tier) (laps) (DNF timeout) rest [vehicle] - register your race restricted to [vehicle]\n"
        msg = msg ..
        "/races register (tier) (laps) (DNF timeout) class [class] - register your race restricted to vehicles of type [class]; if [class] is '-1' then use custom vehicle list\n"
        msg = msg ..
        "/races register (tier) (laps) (DNF timeout) rand (class) (vehicle) - register your race changing vehicles randomly every lap; (class) defaults to any; (vehicle) defaults to any\n"
        msg = msg .. "\n"
        msg = msg .. "/races unregister - unregister your race\n"
        msg = msg .. "/races start (delay) - start your registered race; (delay) defaults to 30 seconds\n"
        msg = msg .. "\n"
        msg = msg .. "/races vl add [vehicle] - add [vehicle] to vehicle list\n"
        msg = msg .. "/races vl delete [vehicle] - delete [vehicle] from vehicle list\n"
        msg = msg .. "/races vl addClass [class] - add all vehicles of type [class] to vehicle list\n"
        msg = msg .. "/races vl deleteClass [class] - delete all vehicles of type [class] from vehicle list\n"
        msg = msg .. "/races vl addAll - add all vehicles to vehicle list\n"
        msg = msg .. "/races vl deleteAll - delete all vehicles from vehicle list\n"
        msg = msg .. "/races vl list - list all vehicles in vehicle list\n"
        msg = msg .. "\n"
        msg = msg ..
        "For the following '/races vl' commands, [access] = {'pvt', 'pub'} where 'pvt' operates on a private vehicle list and 'pub' operates on a public vehicle list\n"
        msg = msg .. "/races vl loadLst [access] [name] - load private or public vehicle list saved as [name]\n"
        msg = msg .. "/races vl saveLst [access] [name] - save new private or public vehicle list as [name]\n"
        msg = msg ..
        "/races vl overwriteLst [access] [name] - overwrite existing private or public vehicle list saved as [name]\n"
        msg = msg .. "/races vl deleteLst [access] [name] - delete private or public vehicle list saved as [name]\n"
        msg = msg .. "/races vl listLsts [access] - list saved private or public vehicle lists\n"
        msg = msg .. "\n"
        msg = msg .. "/races leave - leave a race that you joined\n"
        msg = msg .. "/races respawn - respawn at last waypoint\n"
        msg = msg .. "/races results - view latest race results\n"
        msg = msg .. "/races spawn (vehicle) - spawn a vehicle; (vehicle) defaults to 'adder'\n"
        msg = msg ..
        "/races lvehicles (class) - list available vehicles of type (class); otherwise list all available vehicles if (class) is not specified\n"
        msg = msg ..
        "/races speedo (unit) - change unit of speed measurement to (unit) = {imp, met}; otherwise toggle display of speedometer if (unit) is not specified\n"
        msg = msg ..
        "/races panel (panel) - display (panel) = {edit, register, list} panel; otherwise display main panel if (panel) is not specified\n"
        notifyPlayer(msg)
    elseif "edit" == args[1] then
        edit()
    elseif "clear" == args[1] then
        clear()
    elseif "reverse" == args[1] then
        reverse()
    elseif "load" == args[1] then
        loadTrack(args[2], args[3])
    elseif "save" == args[1] then
        trackEditor:TrySave(args[2], args[3])
    elseif "overwrite" == args[1] then
        if racingStates.Editing == raceState then
            trackEditor:TryOverwrite(args[2], args[3], args[4])
            return
        else
            if "pvt" == args[2] or "pub" == args[2] then
                if args[3] ~= nil then
                    if currentTrack:GetTotalWaypoints() > 1 then
                        TriggerServerEvent("races:overwrite", "pub" == args[2], args[3], currentTrack:SerialiseWaypoints(), args[4])
                    else
                        sendMessage("Cannot overwrite.  Track needs to have at least 2 waypoints.\n")
                    end
                else
                    sendMessage("Cannot overwrite.  Name required.\n")
                end
            else
                sendMessage("Cannot overwrite.  Invalid access type.\n")
            end
        end
    elseif "delete" == args[1] then
        deleteTrack(args[2], args[3])
    elseif "blt" == args[1] then
        bestLapTimes(args[2], args[3])
    elseif "list" == args[1] then
        listTracks(args[2])
    elseif "register" == args[1] then
        register(args[2], args[3], args[4], args[5], args[6], args[7], args[8])
    elseif "unregister" == args[1] then
        unregister()
    elseif "grid" == args[1] then
        setupGrid()
    elseif "autojoin" == args[1] then
        autojoin()
    elseif "start" == args[1] then
        startRace(args[2], args[3])
    elseif "vl" == args[1] then
        if "add" == args[2] then
            addVeh(args[3])
        elseif "delete" == args[2] then
            delVeh(args[3])
        elseif "addClass" == args[2] then
            addClass(args[3])
        elseif "deleteClass" == args[2] then
            deleteClass(args[3])
        elseif "addAll" == args[2] then
            addAllVeh()
        elseif "deleteAll" == args[2] then
            delAllVeh()
        elseif "list" == args[2] then
            listVeh()
        elseif "loadLst" == args[2] then
            loadLst(args[3], args[4])
        elseif "saveLst" == args[2] then
            saveLst(args[3], args[4])
        elseif "overwriteLst" == args[2] then
            overwriteLst(args[3], args[4])
        elseif "deleteLst" == args[2] then
            deleteLst(args[3], args[4])
        elseif "listLsts" == args[2] then
            listLsts(args[3])
        else
            notifyPlayer("Unknown vehicle list command.\n")
        end
    elseif "leave" == args[1] then
        leave()
    elseif "end" == args[1] then
        endrace()
    elseif "respawn" == args[1] then
        respawn()
    elseif "results" == args[1] then
        viewResults(true)
    elseif "spawn" == args[1] then
        spawn(args[2])
    elseif "lvehicles" == args[1] then
        lvehicles(args[2])
    elseif "speedo" == args[1] then
        setSpeedo(args[2])
    elseif "panel" == args[1] then
        showPanel(args[2])
    elseif "upgrade" == args[1] then
        resetupgrades()
    elseif "ghost" == args[1] then
        ghosting:StartGhosting(configData['ghostingTime'])
    elseif "source" == args[1] then
        notifyPlayer(GetPlayerServerId(PlayerId()))
    elseif "lobby" == args[1] then
        TeleportPlayer(getOffsetSpawn(lobbySpawn), lobbySpawn.heading)
        --[[
    elseif "test" == args[1] then
        if "0" == args[2] then
            TriggerEvent("races:finish", GetPlayerServerId(PlayerId()), "John Doe", (5 * 60 + 24) * 1000, (1 * 60 + 32) * 1000, "Duck")
        elseif "1" == args[2] then
            testCheckpoint(args[3])
        elseif "2" == args[2] then
            testSound(args[3], args[4])
        elseif "3" == args[2] then
            TriggerServerEvent("sounds0")
        elseif "4" == args[2] then
            TriggerServerEvent("sounds1")
        elseif "5" == args[2] then
            TriggerServerEvent("vehicles")
        elseif "6" == args[2] then
            setEngineHealth(args[3])
        elseif "7" == args[2] then
            getEngineHealth()
        elseif "8" == args[2] then
            giveWeapon()
        elseif "9" == args[2] then
            removeWeapons()
        elseif "a" == args[2] then
            clearWantedLevel()
        elseif "b" == args[2] then
            getNetId()
        elseif "c" == args[2] then
            vehInfo()
        elseif "d" == args[2] then
            printSource()
        elseif "dp" == args[2] then
            deletePeds()
        elseif "pp" == args[2] then
            putPedInSeat()
        elseif "gp" == args[2] then
            getPedInSeat()
        elseif "cp" == args[2] then
            createPedInSeat()
        elseif "gv0" == args[2] then
            getVeh0()
        elseif "gpiv0" == args[2] then
            getPedInVeh0()
        elseif "gv1" == args[2] then
            getVeh1()
        elseif "ppiv1" == args[2] then
            putPedInVeh1()
        end
--]]
    else
        notifyPlayer("Unknown command.\n")
    end
end)

RegisterNetEvent("races:message")
AddEventHandler("races:message", function(msg)
    sendMessage(msg)
end)

RegisterNetEvent("races:load")
AddEventHandler("races:load", function(isPublic, trackName, track)
    if isPublic == nil or trackName == nil and track.waypoints == nil then
        notifyPlayer("Ignoring load event.  Invalid parameters.\n")
        return
    end

    if racingStates.Idle ~= raceState or racingStates.Editing == raceState then
        notifyPlayer("Ignoring load event.  Currently joined to race.\n")
        return
    end

    if racingStates.Idle == raceState then
        currentTrack:Load(isPublic, trackName, track)
    elseif racingStates.Editing == raceState then
        trackEditor:Load(isPublic, trackName, track)
    end

    sendMessage("Loaded " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
end)

RegisterNetEvent("races:save")
AddEventHandler("races:save", function(isPublic, trackName)
    if isPublic ~= nil and trackName ~= nil then
        trackEditor:OnUpdateTrackMetaData(isPublic, trackName)
        sendMessage("Saved " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
    else
        notifyPlayer("Ignoring save event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:overwrite")
AddEventHandler("races:overwrite", function(isPublic, trackName, map)
    if isPublic ~= nil and trackName ~= nil then
        trackEditor:OnUpdateTrackMetaData(isPublic, trackName)
        sendMessage("Overwrote " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. (nil ~= map and " with map " .. map or "") ..  "'.\n")
    else
        notifyPlayer("Ignoring overwrite event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:blt")
AddEventHandler("races:blt", function(isPublic, trackName, bestLaps)
    if isPublic ~= nil and trackName ~= nil and bestLaps ~= nil then
        local msg = (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'"
        if #bestLaps > 0 then
            msg = "Best lap times for " .. msg .. ":\n"
            for pos, bestLap in ipairs(bestLaps) do
                local minutes, seconds = minutesSeconds(bestLap.bestLapTime)
                msg = msg ..
                ("%d - %s - %02d:%05.2f using %s\n"):format(pos, bestLap.playerName, minutes, seconds,
                bestLap.vehicleName)
            end
            sendMessage(msg)
        else
            sendMessage("No best lap times for " .. msg .. ".\n")
        end
    else
        notifyPlayer("Ignoring best lap times event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:loadLst")
AddEventHandler("races:loadLst", function(isPublic, name, list)
    if isPublic ~= nil and name ~= nil and list ~= nil then
        vehicleList = list
        if true == panelShown then
            updateList()
        end
        sendMessage((true == isPublic and "Public" or "Private") .. " vehicle list '" .. name .. "' loaded.\n")
    else
        notifyPlayer("Ignoring load vehicle list event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:register")
AddEventHandler("races:register",
function(rIndex, waypoint, isPublic, trackName, owner, rdata)

    if rIndex == nil and waypoint == nil and isPublic == nil and owner == nil and rdata.tier == nil and rdata.laps == nil and rdata.timeout == nil and rdata == nil then
        notifyPlayer("[R]Ignoring register event.  Invalid parameters.\n")
        return
    end

    local blip = AddBlipForCoordVector3(waypoint.coord) -- registration blip
    SetBlipSprite(blip, registerSprite)
    SetBlipColour(blip, registerBlipColor)
    BeginTextCommandSetBlipName("STRING")
    local msg = owner .. " (" .. "tier:" .. rdata.tier
    msg = msg .. " Special Class: " .. rdata.specialClass
    if " rest" == rdata.rtype then
        msg = msg .. " : using '" .. rdata.restrict .. "' vehicle"
    elseif " class" == rdata.rtype then
        msg = msg .. " : using " .. getClassName(rdata.vclass) .. " vehicle class"
    elseif " rand" == rdata.rtype then
        msg = msg .. " : using random "
        if rdata.vclass ~= nil then
            msg = msg .. getClassName(rdata.vclass) .. " vehicle class"
        else
            msg = msg .. "vehicles"
        end
        if rdata.svehicle ~= nil then
            msg = msg .. " : '" .. rdata.svehicle .. "'"
        end
    elseif " wanted" == rdata.rtype then
        msg = msg .. " : wanted race mode"
    elseif " ghost" == rdata.rtype then
        msg = msg .. " : ghost race mode"
    end

    if(rdata.map ~= nil and rdata.map ~= "") then
        msg = msg .. " map: " .. rdata.map
    end
    msg = msg .. ")"
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandSetBlipName(blip)

    local checkpoint = MakeCheckpoint(plainCheckpoint, waypoint.coord, waypoint.radius, waypoint.coord, color.purple, 0) -- registration checkpoint

    starts[rIndex] = {
        isPublic = isPublic,
        trackName = trackName,
        owner = owner,
        tier = rdata.tier,
        specialClass = rdata.specialClass,
        laps = rdata.laps,
        timeout = rdata.timeout,
        rtype = rdata.rtype,
        restrict = rdata.restrict,
        vclass = rdata.vclass,
        svehicle = rdata.svehicle,
        vehicleList = rdata.vehicleList,
        blip = blip,
        checkpoint = checkpoint,
        registerPosition = waypoint.coord,
        map = rdata.map
    }
end)

RegisterNetEvent("races:unregister")
AddEventHandler("races:unregister", function(rIndex)
    if rIndex ~= nil then
        if starts[rIndex] ~= nil then
            currentTrack:DeleteGridCheckPoints()
            removeRegistrationPoint(rIndex)
        end
        if rIndex == raceIndex then
            if racingStates.Joining == raceState then
                raceState = racingStates.Idle
                --Shouldn't need to reset here, but just incase
                playerDisplay:ResetRaceBlips()
                notifyPlayer("Race canceled.\n")
            elseif racingStates.Racing == raceState then
                raceState = racingStates.Idle
                ClearCurrentWaypoints()
                currentTrack:Unegister()
                --Shouldn't need to reset here, but just incase
                playerDisplay:ResetRaceBlips()
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
    else
        notifyPlayer("Ignoring unregister event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:greenflag")
AddEventHandler("races:greenflag", function()
    local player = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(player, false)
    FreezeEntityPosition(vehicle, false)
    raceState = racingStates.Racing
    PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET", true)
    currentLapTimer:Start()
    if(currentRace.raceType ~= 'ghost') then
        ghosting:StartGhosting(configData['raceStartGhostingTime'])
    end
end)

RegisterNetEvent("races:start")
AddEventHandler("races:start", function(rIndex, delay)
    if rIndex ~= nil and delay ~= nil then
        if delay >= 5 then
            if rIndex == raceIndex then
                if racingStates.Joining == raceState then
                    beginDNFTimeout = false
                    timeoutStart = -1
                    position = -1
                    numWaypointsPassed = 0
                    currentLap = 1
                    numRacers = -1
                    results = {}
                    startCoord = GetEntityCoords(PlayerPedId())

                    if startVehicle ~= nil then
                        local vehicle = switchVehicle(PlayerPedId(), startVehicle)
                        if vehicle ~= nil then
                            SetEntityAsNoLongerNeeded(vehicle)
                        end
                    end

                    currentWaypoints = currentTrack:OnStartRace()

                    raceState = racingStates.RaceCountdown

                    local player = PlayerPedId()
                    local vehicle = GetVehiclePedIsIn(player, true)
                    raceVehicleHash = GetEntityModel(vehicle)
                    raceVehicleName = GetDisplayNameFromVehicleModel(raceVehicleHash)

                    StartRaceEffects()

                    repairVehicle(vehicle)
                    resetupgrades(vehicle)
                    ClearReady();
                    notifyPlayer("Vehicle fixed.\n")

                    SetLeaderboardLower(false)
                    StartCountdownLights(delay)

                    if IsPedInAnyVehicle(player, false) == 1 then
                        FreezeEntityPosition(GetVehiclePedIsIn(player, false), true)
                    end
                    Citizen.CreateThread(RaceStartCameraTransition)

                elseif racingStates.Racing == raceState then
                    notifyPlayer("Ignoring start event.  Already in a race.\n")
                elseif racingStates.Editing == raceState then
                    notifyPlayer("Ignoring start event.  Currently editing.\n")
                else
                    notifyPlayer("Ignoring start event.  Currently idle.\n")
                end
            end
        else
            notifyPlayer("Ignoring start event.  Invalid delay.\n")
        end
    else
        notifyPlayer("Ignoring start event.  Invalid parameters.\n")
    end
end)

function FiveSecondWarning()
    print("Five second warning client")
    --God Save me
    for i = 1, 5 do
        PlaySoundFrontend(-1, "MP_5_SECOND_TIMER", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
        Citizen.Wait(1000)
    end

end

RegisterNetEvent("races:fivesecondwarning")
AddEventHandler("races:fivesecondwarning", function()
    Citizen.CreateThread(FiveSecondWarning)
end)

RegisterNetEvent("races:respawn")
AddEventHandler("races:respawn", function()
    respawn()
end)

RegisterNetEvent("races:hide")
AddEventHandler("races:hide", function(rIndex)
    if rIndex ~= nil then
        if starts[rIndex] ~= nil then
            removeRegistrationPoint(rIndex)
        else
            notifyPlayer("Ignoring hide event.  Race does not exist.\n")
        end
    else
        notifyPlayer("Ignoring hide event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:joinnotification")
AddEventHandler("races:joinnotification", function(joinNotificationData)

    local raceIndex = joinNotificationData.raceIndex
    local registrationCoords = joinNotificationData.waypoints
    local numRacing = joinNotificationData.numRacing
    local playerName = joinNotificationData.playerName
    local trackName = joinNotificationData.trackName
    local racerDictionary = joinNotificationData.racerDictionary

    UpdateRegistrationCheckpoint(raceIndex, registrationCoords, numRacing)
    sendMessage(string.format("%s has joined Race %s", playerName, trackName))
end)

RegisterNetEvent("races:onleave")
AddEventHandler("races:onleave", function()
    ClearLeaderboard()
end)

RegisterNetEvent("races:onplayerleave")
AddEventHandler("races:onplayerleave", function(otherRaceSource)
    ready = false
    SendReadyData({ source = GetPlayerServerId(PlayerId()), ready = ready})
    RemoveRacerFromLeaderboard(otherRaceSource)
end)

RegisterNetEvent("races:leave")
AddEventHandler("races:leave", function()
    leave()
end)

function UpdateRegistrationCheckpoint(raceIndex, waypoint, numRacing)
    DeleteCheckpoint(starts[raceIndex].checkpoint);
    local checkpoint = MakeCheckpoint(plainCheckpoint, waypoint.coord, Config.data.editing.defaultRadius, waypoint.coord, color.purple, numRacing)
    starts[raceIndex].checkpoint = checkpoint
end

RegisterNetEvent("races:leavenotification")
AddEventHandler("races:leavenotification", function(message, rIndex, numRacing, registrationCoords)
    UpdateRegistrationCheckpoint(rIndex, registrationCoords, numRacing)
    sendMessage(message)
end)

RegisterNetEvent("races:removeFromLeaderboard")
AddEventHandler("races:removeFromLeaderboard", function(source)
    RemoveRacerFromLeaderboard(source)
end)

RegisterNetEvent("races:join")
AddEventHandler("races:join", function(rIndex, tier, specialClass, waypoints, racerDictionary)
    if rIndex ~= nil and waypoints ~= nil then
        if starts[rIndex] ~= nil then
            if racingStates.Idle == raceState then
                SetJoinMessage('')
                raceState = racingStates.Joining
                raceIndex = rIndex
                numLaps = starts[rIndex].laps
                DNFTimeout = starts[rIndex].timeout * 1000
                restrictedHash = nil
                restrictedClass = starts[rIndex].vclass
                customClassVehicleList = {}
                startVehicle = starts[rIndex].svehicle
                randVehicles = {}
                currentTrack:LoadWaypointBlips(waypoints)
                playerDisplay:SetOwnRacerBlip()

                currentRace.trackName = starts[rIndex].trackName

                local raceData = {
                    laps = starts[rIndex].laps,
                    totalCheckpoints = currentTrack.startIsFinish == true and currentTrack:GetTotalWaypoints() or currentTrack:GetTotalWaypoints() - 1
                }
                SendRaceData(raceData)
                SetRaceLeaderboard(true)
                AddRacersToLeaderboard(racerDictionary, GetPlayerServerId(PlayerId()))

                local msg = "Joined race using "
                if nil == starts[rIndex].trackName then
                    msg = msg .. "unsaved track "
                else
                    msg = msg ..
                    (true == starts[rIndex].isPublic and "publicly" or "privately") ..
                    " saved track '" .. starts[rIndex].trackName .. "' "
                end
                msg = msg ..
                ("registered by %s : tier %s : Special Class %s : %d lap(s)"):format(starts[rIndex].owner, starts[rIndex].tier, starts[rIndex].specialClass,
                starts[rIndex].laps)
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
                elseif "wanted" == starts[rIndex].rtype then
                    msg = msg .. " : using wanted race mode"
                    currentRace.raceType = 'wanted'
                elseif starts[rIndex].rtype == "ghost" then
                    msg = msg .. " : using ghost race mode"
                    currentRace.raceType = 'ghost'
                end

                if(starts[rIndex].map ~= "") then
                    msg = msg .. (" with map %s"):format(starts[rIndex].map);
                end

                msg = msg .. ".\n"
                notifyPlayer(msg)
                SendToRaceTier(tier, specialClass)
                UpdateVehicleName()
                SendVehicleName()
            elseif racingStates.Editing == raceState then
                notifyPlayer("Ignoring join event.  Currently editing.\n")
            else
                notifyPlayer("Ignoring join event.  Already joined to a race.\n")
            end
        else
            notifyPlayer("Ignoring join event.  Race does not exist.\n")
        end
    else
        notifyPlayer("Ignoring join event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:racerJoined")
AddEventHandler("races:racerJoined", function(racerSource, racerName)
    AddRacerToLeaderboard(racerSource, racerName)
end)

-- SCENARIO:
-- 1. player finishes a race
-- 2. receives finish events from previous race because other players finished
-- 3. player joins another race
-- 4. joined race starts
-- 5. receives finish event from previous race before current race
-- if accepting finish events from previous race, DNF timeout for current race may be started
-- only accept finish events from current race
-- do not accept finish events from previous race
RegisterNetEvent("races:finish")
AddEventHandler("races:finish", function(finishData)

    local rIndex = finishData.raceIndex
    local playerName = finishData.playerName
    local raceFinishTime = finishData.finishTime
    local raceBestLapTime = finishData.bestLapTime
    local raceVehicleName = finishData.bestLapVehicleName

    if rIndex ~= nil and playerName ~= nil and raceFinishTime ~= nil and raceBestLapTime ~= nil and raceVehicleName ~= nil then
        if rIndex == raceIndex then
            if -1 == raceFinishTime then
                if -1 == raceBestLapTime then
                    notifyPlayer(playerName .. " did not finish.\n")
                else
                    local minutes, seconds = minutesSeconds(raceBestLapTime)
                    notifyPlayer(("%s did not finish and had a best lap time of %02d:%05.2f using %s.\n"):format(
                    playerName, minutes, seconds, raceVehicleName))
                end
            else
                local currentTime = GetGameTimer()
                if false == beginDNFTimeout then
                    beginDNFTimeout = true
                    timeoutStart = currentTime
                end
                local fMinutes, fSeconds = minutesSeconds(raceFinishTime)
                local lMinutes, lSeconds = minutesSeconds(raceBestLapTime)
                notifyPlayer(("%s finished in %02d:%05.2f and had a best lap time of %02d:%05.2f using %s.\n"):format(
                playerName, fMinutes, fSeconds, lMinutes, lSeconds, raceVehicleName))
            end
            ResetCarTier();
            playerDisplay:ResetRaceBlips()
        end
    else
        notifyPlayer("Ignoring finish event.  Invalid parameters.\n")
    end
end)

-- SCENARIO:
-- 1. player finishes a race
-- 2. doesn't receive results event because other players have not finished
-- 3. player joins another race
-- 4. joined race starts
-- 5. receives results event from previous race before current race
-- only accept results event from current race
-- do not accept results event from previous race
RegisterNetEvent("races:onendrace")
AddEventHandler("races:onendrace", function(rIndex, raceResults)

    ClearLeaderboard()

    if rIndex ~= nil and raceResults ~= nil then
        if rIndex == raceIndex then
            results = raceResults
            viewResults(true)
        end
    else
        notifyPlayer("Ignoring results event.  Invalid parameters.\n")
    end

    Citizen.Wait(5000)

    TeleportPlayer(getOffsetSpawn(lobbySpawn), lobbySpawn.heading)

end)

-- SCENARIO:
-- 1. player finishes previous race
-- 2. still receiving position events from previous race because other players have not finished
-- 3. player joins another race
-- 4. joined race started
-- receiving position events from previous race and joined race
-- only accept position events from joined race
-- do not accept position events from previous race
RegisterNetEvent("races:position")
AddEventHandler("races:position", function(rIndex, pos, numR)
    if rIndex ~= nil and pos ~= nil and numR ~= nil then
        if rIndex == raceIndex then
            position = pos
            numRacers = numR
        end
    else
        notifyPlayer("Ignoring position event.  Invalid parameters.\n")
    end
end)

--racePositions index is the position of the racer in the race, the value at the index is the source of the player at that position
RegisterNetEvent("races:racerPositions")
AddEventHandler("races:racerPositions", function(racePositions)
    playerDisplay:UpdateRacerDisplay(racePositions, position)

    SendNUIMessage({
        type = "leaderboard",
        action = "update_positions",
        racePositions = racePositions
    })
end)

RegisterNetEvent("races:addplayerdisplay")
AddEventHandler("races:addplayerdisplay", function(source, playerName)

    if (source == nil or source == GetPlayerServerId(PlayerId())) then
        return
    end

    playerDisplay:AddDisplay(source, playerName)
end)

RegisterNetEvent("races:removeplayerdisplay")
AddEventHandler("races:removeplayerdisplay", function(source)

    if (source == nil or source == GetPlayerServerId(PlayerId())) then
        return
    end

    playerDisplay:RemoveDisplay(source)
end)

RegisterNetEvent("races:allVehicles")
AddEventHandler("races:allVehicles", function(allVehicles)
    if allVehicles ~= nil then
        allVehiclesList = {}
        allVehiclesHTML = ""
        for _, vehicle in ipairs(allVehicles) do
            if IsModelInCdimage(vehicle) == 1 and IsModelAVehicle(vehicle) == 1 then
                allVehiclesList[#allVehiclesList + 1] = vehicle
                allVehiclesHTML = allVehiclesHTML .. "<option value = \"" .. vehicle .. "\">" .. vehicle .. "</option>"
            end
        end
    else
        notifyPlayer("Ignoring allVehicles event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:trackNames")
AddEventHandler("races:trackNames", function(isPublic, trackNames)
    if isPublic ~= nil and trackNames ~= nil then
        if true == panelShown then
            local html = ""
            for _, trackName in ipairs(trackNames) do
                html = html .. "<option value = \"" .. trackName .. "\">" .. trackName .. "</option>"
            end
            SendNUIMessage({
                update = "trackNames",
                access = false == isPublic and "pvt" or "pub",
                trackNames = html
            })
        end
    else
        notifyPlayer("Ignoring trackNames event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:listNames")
AddEventHandler("races:listNames", function(isPublic, listNames)
    if isPublic ~= nil and listNames ~= nil then
        if true == panelShown then
            local html = ""
            for _, listName in ipairs(listNames) do
                html = html .. "<option value = \"" .. listName .. "\">" .. listName .. "</option>"
            end
            SendNUIMessage({
                update = "listNames",
                access = false == isPublic and "pvt" or "pub",
                listNames = html
            })
        end
    else
        notifyPlayer("Ignoring listNames event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:spawncheckpoint")
AddEventHandler("races:spawncheckpoint", function(position, gridNumber)
    print('spawncheckpoint event')
    currentTrack:SpawnCheckpoint(position, gridNumber)
end)

RegisterNetEvent("races:spawncheckpoints")
AddEventHandler("races:spawncheckpoints", function(gridPositions)
    print("Spawn Checkpoints called")
    currentTrack:SpawnCheckpoints(gridPositions)
end)

RegisterNetEvent("races:teleportplayer")
AddEventHandler("races:teleportplayer", function(position, heading)
    TeleportPlayer({x = position.x, y = position.y, z = position.z}, heading)
end)

RegisterNetEvent("races:startPreRaceCountdown")
AddEventHandler("races:startPreRaceCountdown", function(countdownTimer)
    SendNUIMessage({
        type = "ready",
        action = "startPreRaceCountdown",
        countdown = countdownTimer / 1000
    })
end)

RegisterNetEvent("races:stopPreRaceCountdown")
AddEventHandler("races:stopPreRaceCountdown", function()
    SendNUIMessage({
        type = "ready",
        action = "stopPreRaceCountdown"
    })
end)


--#endregion

function LastPlaceBoost()

    boost_active = position == numRacers and numRacers ~= 1

    if(boost_active) then
        SetVehicleCheatPowerIncrease(GetVehiclePedIsIn(GetPlayerPed(-1), false), 1.8)
    else
        SetVehicleCheatPowerIncrease(GetVehiclePedIsIn(GetPlayerPed(-1), false), 1.0)
    end
end

function RacesReport()
    while true do
        Citizen.Wait(500)
        if racingStates.Racing == raceState then
            local player = PlayerPedId()
            --TODO:Send current waypoint index as well as distance
            local closestWaypoint = -1
            local closestWaypointDistance = 99999;
            for _, currentWaypoint in pairs(currentWaypoints) do
                local distance = #(GetEntityCoords(player) - currentWaypoint.coord)

                if(distance < closestWaypointDistance) then
                    closestWaypointDistance = distance
                    closestWaypoint = currentWaypoint.index
                end
            end

            TriggerServerEvent("races:report", raceIndex, numWaypointsPassed, closestWaypointDistance,closestWaypoint)
        end
    end
end

function ClearReady()
    SendNUIMessage({
        type = 'ready',
        action = 'clear_ready'
    })
end

function ResetReady()
    ready = false
    TriggerServerEvent("races:readyState", raceIndex, ready)
end

function SetRaceLeaderboard(enabled)
    SendNUIMessage({
        type = 'leaderboard',
        action = 'set_leaderboard',
        value = enabled
    })
end

function RemoveRacerFromLeaderboard(source)
    SendNUIMessage({
        type = 'leaderboard',
        action = 'remove_racer',
        source = source
    })
end

function ClearLeaderboard()
    SendNUIMessage({
        type = 'leaderboard',
        action = 'clear_leaderboard'
    })
end

function SetLeaderboardLower(lower)
    SendNUIMessage({
        type = 'leaderboard',
        action = 'set_leaderboard_lower',
        lower = lower
    })
end

function StartCountdownLights(countdown)
    SendNUIMessage({
        type = 'leaderboard',
        action = 'start_lights_countdown',
        time = countdown
    })
end

function HandleJoinState()
    --Down
    if IsControlJustReleased(0, 173) then
        ready = not ready
        TriggerServerEvent("races:readyState", raceIndex, ready)
    end
end

function SendVehicleName()
    TriggerServerEvent("races:sendvehiclename", raceIndex, currentVehicleName or 'N/A' )
end

RegisterNetEvent("races:sendvehiclename")
AddEventHandler("races:sendvehiclename", function(source, vehicleName)
    SendNUIMessage({
        type = 'leaderboard',
        action = 'update_vehicle_name',
        vehicleName = vehicleName,
        source = source,
    })
end)

function SendReadyData(racer)
    SendNUIMessage({
        type = 'ready',
        action = 'send_racer_ready_data',
        racer = racer
    })
end

function AddRacersToLeaderboard(racerDictionary, source)
    SendNUIMessage({
        type = 'leaderboard',
        action = 'add_racers',
        racers = racerDictionary,
        source = source
    })
end

function AddRacerToLeaderboard(racerSource, racerName)
    SendNUIMessage({
        type = 'leaderboard',
        action = 'add_racer',
        name = racerName,
        source = racerSource,
        ownSource = GetPlayerServerId(PlayerId())
    })
end

function SetRespawnIndicator(time)
    SendNUIMessage({
        type = 'leaderboard',
        action = 'set_respawn',
        time = time
    })
end

function ClearRespawnIndicator()
    SendNUIMessage({
        type = 'leaderboard',
        action = 'clear_respawn'
    })
end

function UpdateVehicleName(vehicleName)
    if(vehicleName ~= nil) then
        currentVehicleName = vehicleName
        if raceState == racingStates.Racing or raceState == racingStates.Joining then
            SendVehicleName()
        end
    else

        if(currentVehicleName ~= nil) then
            print("Already have car name, ignoring")
            return
        end

        local player = PlayerPedId()
        if IsPedInAnyVehicle(player, false) == 1 then
            local vehicle = GetVehiclePedIsIn(player, false)
            raceVehicleHash = GetEntityModel(vehicle)
            currentVehicleName = GetLabelText(GetDisplayNameFromVehicleModel(raceVehicleHash))
        else
            currentVehicleName = "On Feet"
        end
    end
end

function HandleRaceType()
    if currentRace.raceType == 'wanted' then
        local player = PlayerId()

        local wantedLevel = math.max(6-position, 0)
        wantedLevel = math.min(wantedLevel, 5)
        local currentWantedLevel =  GetPlayerWantedLevel(player)
        if currentWantedLevel ~= wantedLevel then
            SetMaxWantedLevel(wantedLevel)
            SetPlayerWantedLevel(player, wantedLevel, false)
            SetPlayerWantedLevelNow(player, false)
        end
    elseif currentRace.raceType == 'ghost' then
        --
    end
end

function SendCheckpointTime(waypointsPassed)
    TriggerServerEvent("races:sendCheckpointTime", waypointsPassed, raceIndex)
end

RegisterNetEvent("races:config")
AddEventHandler("races:config", function(_configData)
    configData = _configData
    print("Loaded config")

    ghosting:LoadConfig(configData['ghosting'])
    playerDisplay:LoadConfig(configData['playerDisplay'])

    lobbySpawn = _configData['spawning']['spawnLocation']
    spawnOffsetVector = _configData['spawning']['spawnOffsetVector']

    SetSpawning()

end)

RegisterNetEvent("races:clearLeaderboard")
AddEventHandler("races:clearLeaderboard", function()
    ClearLeaderboard()
end)

RegisterNetEvent("races:sendReadyData")
AddEventHandler("races:sendReadyData", function(isReady, source, playerName)
    SendReadyData({ source = source, playerName = playerName, ready = isReady})
end)

RegisterNetEvent("races:updateTimeSplit")
AddEventHandler("races:updateTimeSplit", function(source, timeSplit)
    SendNUIMessage({
        type = 'leaderboard',
        action = 'update_time_split',
        timeSplit = timeSplit,
        source = source,
    })
end)

RegisterNetEvent("races:compareTimeSplit")
AddEventHandler("races:compareTimeSplit", function(racersAhead)
    SendNUIMessage({
        type = 'leaderboard',
        action = 'bulk_update_time_splits',
        racersAhead = racersAhead
    })
end)

function RaceStartCameraTransition()

    local player = PlayerPedId()

    local entity = IsPedInAnyVehicle(player, false) == 1 and GetVehiclePedIsIn(player, false) or
    player

    local cam0 = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam0, GetOffsetFromEntityInWorldCoords(entity, 0.0, 5.0, 1.0))
    PointCamAtEntity(cam0, entity, 0.0, 0.0, 0.0, true)

    print("Stage 2")

    local cam1 = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam1, GetOffsetFromEntityInWorldCoords(entity, -5.0, 0.0, 1.0))
    PointCamAtEntity(cam1, entity, 0.0, 0.0, 0.0, true)

    print("Stage 3")

    local cam2 = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam2, GetOffsetFromEntityInWorldCoords(entity, 0.0, -5.0, 1.0))
    PointCamAtEntity(cam2, entity, 0.0, 0.0, 0.0, true)

    print("Stage 4")

    RenderScriptCams(true, false, 0, true, true)

    SetCamActiveWithInterp(cam1, cam0, 1000, 0, 0)
    Citizen.Wait(2000)

    SetCamActiveWithInterp(cam2, cam1, 1000, 0, 0)
    Citizen.Wait(2000)

    RenderScriptCams(false, true, 1000, true, true)

    print("Stage 5")

    SetGameplayCamRelativeRotation(GetEntityRotation(entity))

    DestroyAllCams(true)

    print("Stage 6")
end

function HandleRespawn(currentTime)
    if IsControlPressed(0, 19) == 1 then -- X key or A button or cross button
        if true == respawnCtrlPressed then
            if currentTime - respawnTime > respawnTimer then
                respawnCtrlPressed = false
                respawnLock = true
                respawn()
            end
        elseif respawnLock == false then
            SetRespawnIndicator(respawnTimer / 1000)
            respawnCtrlPressed = true
            respawnTime = currentTime
        end
    else
        ClearRespawnIndicator()
        respawnCtrlPressed = false
    end

    if IsControlReleased(0, 19) == 1 then
        respawnLock = false
    end
end

--Returns true when the race is finished
function OnNewLap(player)
    previousWaypoint = 1
    currentLapTimer:Reset()
    TriggerServerEvent("races:lapcompleted", raceIndex, currentVehicleName)

    if currentLap < numLaps then
        currentLap = currentLap + 1
        PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true)
        --Last lap gets a unique sound to signify it's end
        if(currentLap == numLaps) then
            PlaySoundFrontend(-1, "TENNIS_MATCH_POINT", "HUD_AWARDS", true)
        end
        UpdateCurrentLap()
        if #randVehicles > 0 then
            
            local randVehiclesNotUsed = uniqueValues(randVehicles, randVehiclesUsed)
            if(#randVehiclesNotUsed <= 0) then
                randVehiclesUsed = {}
                randVehiclesNotUsed = randVehicles
            end

            local randIndex = math.random(#randVehiclesNotUsed)
            sendMessage("Random Index: " .. randIndex)
            table.insert(randVehiclesUsed, randVehiclesNotUsed[randIndex])
            local randVehicle = switchVehicle(player,
            randVehiclesNotUsed[randIndex])
            if randVehicle ~= nil then
                SetEntityAsNoLongerNeeded(randVehicle)
            end
            PlaySoundFrontend(-1, "CHARACTER_SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
        end
    else
        finishRace(false)
        return true
    end
end

function OnHitCheckpoint(player, waypointHit)
    local vehicle = GetVehiclePedIsIn(player, false)

    if restrictedHash ~= nil then
        if nil == vehicle or raceVehicleHash ~= restrictedHash then
            return
        end
    elseif restrictedClass ~= nil then
        if vehicle ~= nil then
            if -1 == restrictedClass then
                if vehicleInList(vehicle, customClassVehicleList) == false then
                    return
                end
            elseif GetVehicleClass(vehicle) ~= restrictedClass then
                return
            end
        else
            return
        end
    end

    resetupgrades(vehicle)
    ClearCurrentWaypoints()

    numWaypointsPassed = numWaypointsPassed + 1

    SendCheckpointTime(numWaypointsPassed)

    previousWaypoint = waypointHit

    --If the waypoint points to at least one other waypoint
    if not currentTrack:AtEnd(waypointHit, numWaypointsPassed) then
        PlaySoundFrontend(-1, "CHECKPOINT_NORMAL", "HUD_MINI_GAME_SOUNDSET", true)
    else
        if (OnNewLap(player)) then
            return
        end
    end

    UpdateCurrentCheckpoint()

    --TODO:Make sure next waypoints are retrieved not just one
    currentWaypoints = currentTrack:OnHitCheckpoint(waypointHit, currentLap, numLaps)
end

function RaceUpdate(player, playerCoord, currentTime)
    HandleRespawn(currentTime)

    currentLapTimer:Update()
    local minutes, seconds = minutesSeconds(currentLapTimer.length)
    SendCurrentLapTime(minutes, seconds)

    LastPlaceBoost()
    HandleRaceType()

    if true == beginDNFTimeout then
        local milliseconds = timeoutStart + DNFTimeout - currentTime
        if milliseconds > 0 then
            minutes, seconds = minutesSeconds(milliseconds)
            UpdateDNFTime(minutes, seconds)
        else -- DNF
            ClearCurrentWaypoints()
            finishRace(true)
            return
        end
    end

    for _,currentWaypoint in ipairs(currentWaypoints) do
        if #(playerCoord - currentWaypoint.coord) < currentWaypoint.radius then
            OnHitCheckpoint(player, currentWaypoint.index)
        end
    end
end

function IdleUpdate(player, playerCoord)
    local closestIndex = -1
    local minDist = Config.data.editing.defaultRadius
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
            msg = msg ..
            (true == starts[closestIndex].isPublic and "publicly" or "privately") ..
            " saved track '" .. starts[closestIndex].trackName .. "' "
        end
        msg = msg .. "registered by " .. starts[closestIndex].owner
        msg = msg .. (" tier %s : Special Class %s : %d lap(s)"):format(starts[closestIndex].tier, starts[closestIndex].specialClass, starts[closestIndex].laps)
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
        elseif "wanted" == starts[closestIndex].rtype then
            msg = msg .. " : using wanted race mode"
        elseif "ghost" == starts[closestIndex].rtype then
            msg = msg .. " : using ghost race mode"
        end

        if (starts[closestIndex].map ~= nil and starts[closestIndex].map ~= "") then
            msg = msg .. " with map " .. starts[closestIndex].map
        end

        SetJoinMessage(msg)
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
                                "Cannot join race.  Player needs to be in one of the following vehicles: " ..
                                list)
                            end
                        else
                            joinRace = false
                            notifyPlayer(
                            "Cannot join race.  Player needs to be in one of the following vehicles: " .. list)
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
                TriggerServerEvent("races:join", closestIndex)
            end
        end
    else
        SetJoinMessage('')
    end
end

function MainUpdate()
    while true do
        Citizen.Wait(0)

        local player = PlayerPedId()
        local playerCoord = GetEntityCoords(player)
        local heading = GetEntityHeading(player)

        local currentTime = GetGameTimer()

        ghosting:Update()

        if racingStates.Editing == raceState then
            trackEditor:Update(playerCoord, heading)
        elseif racingStates.Racing == raceState then
            RaceUpdate(player, playerCoord, currentTime)
        elseif racingStates.Joining == raceState then
            HandleJoinState()
        elseif racingStates.Idle == raceState then
            IdleUpdate(player, playerCoord)
        end

        if true == panelShown then
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 18, true)
            DisableControlAction(0, 322, true)
            DisableControlAction(0, 106, true)
        end
    end
end

Citizen.CreateThread(MainUpdate)
Citizen.CreateThread(RacesReport)