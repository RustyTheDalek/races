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

local waypointsHit = -1
local currentSection = -1
local currentSectionLength = -1
local currentWaypoint = -1

local previousWaypoint = -1
local currentWaypoints = {}               -- current waypoint - for multi-lap races, actual current waypoint is currentWaypoint % #waypoints + 1

local position = -1                       -- position in race out of numRacers players
local numRacers = -1                      -- number of players in race - no DNF players included

local nextWaypoints = {}                   -- Next checkpoints in world

local DNFTimeout = -1                     -- DNF timeout after first player finishes the race
local beginDNFTimeout = false             -- flag indicating if DNF timeout should begin
local timeoutStart = -1                   -- start time of DNF timeout

local vehicleList = {}                    -- vehicle list used for custom class races and random races
local formattedList = {}
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

local results = {}                        -- results[] = {source, playerName, finishTime, bestLapTime, vehicleName}

local starts = {}                         -- starts[playerID] = {isPublic, trackName, owner, tier, laps, timeout, rtype, restrict, vclass, svehicle, vehicleList, blip, checkpoint, gridData} - registration points

local panelShown = false                  -- flag indicating if main, edit, register, or list panel is shown
local allVehiclesList = {}                -- list of all vehicles from vehicles.txt
local enteringVehicle = false             -- flag indicating if player is entering a vehicle

local localPlayerPed = GetPlayerPed(-1)
local localVehicle = GetVehiclePedIsIn(localPlayerPed, false)

local ready = false

local currentRace = {
    trackName = "",
    raceType = ""
}

function RaceType()
    return currentRace.raceType
end

local ghosting = Ghosting:New()
local respawn = Respawn:New()
local playerDisplay = PlayerDisplay:New()
local currentLapTimer = Timer:New()

respawn:InjectGhosting(ghosting)

local currentTrack = Track:New()
local trackEditor = TrackEditor:New()

local fpsMonitor = FPSMonitor:New()

local configData

local boost_active = false

local lobbySpawn = { x = -1413, y = -3007, z = 13.95}
local spawnOffsetVector = { x = 1, y = 0, z = 0}

local currentGridLineup = {}
local previousRaceResults = {}
local currentGridIndex = -1
local currentGridPosition = nil
local currentGridHeading = nil

local function ClearGrid()
    currentGridLineup = { }
    SendNUIMessage({
        type = "grid",
        action = "clear_grid"
    })
end

local function getOffsetSpawn(startingSpawn)
    local offsetSpawn = vector3(startingSpawn.x, startingSpawn.y, startingSpawn.z)
    local offsetVector = vector3(spawnOffsetVector.x, spawnOffsetVector.y, spawnOffsetVector.z)

    offsetSpawn = offsetSpawn + (offsetVector * (GetPlayerServerId(PlayerId()) - 1))

    return offsetSpawn, startingSpawn.heading
end

math.randomseed(GetCloudTimeAsInt())

TriggerServerEvent("races:init")

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

    if(vehicle) then
        SetVehicleOnGroundProperly(vehicle)
    end

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

local function updateRaceVehicle(vehicle)
    raceVehicleHash = GetEntityModel(vehicle)
    raceVehicleName = GetDisplayNameFromVehicleModel(raceVehicleHash)
    respawn:UpdateRaceVehicle(raceVehicleHash, raceVehicleName)
end

local function resetRaceVehicle()
    raceVehicleHash = nil
    raceVehicleName = nil
    respawn:UpdateRaceVehicle(nil, nil)
end

local function switchVehicle(ped, vehicleHash)
    print("Vehicle Hash " .. (vehicleHash))
    print("Vehicle Display name " .. GetDisplayNameFromVehicleModel(vehicleHash))
    print("Switched to " .. GetLabelText(GetDisplayNameFromVehicleModel(vehicleHash)))
    local vehicle = nil

    if(vehicleHash == nil) then
        Notifications.warn("Vehicle Hash nil, not swapping")
        return
    end

    if(CarTierUIActive()) then
        print("cartierspawn")
        vehicle = exports.CarTierUI:RequestVehicle(vehicleHash)
        updateRaceVehicle(vehicle)
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

local function getDisplayNamesFromVehicleList(vehicleList)

    local vehicleListInfo = {}

    for index, vehicle in ipairs(vehicleList) do
        if IsModelInCdimage(vehicle) and IsModelAVehicle(vehicle) then
            --Fallback to spawncode 
            local name
            if (GetLabelText(vehicle) ~= 'NULL') then
                name = GetLabelText(vehicle)
            elseif (GetLabelText(GetDisplayNameFromVehicleModel(vehicle))) then
                name = GetLabelText(GetDisplayNameFromVehicleModel(vehicle))
            else
                name = vehicle
            end

            table.insert(vehicleListInfo, {
                spawnCode = vehicle,
                name = name
            })
        end
    end

    return vehicleListInfo;
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

    local finishData = {
        raceAverageFPS = fpsMonitor:StopTrackingAverage(),
        dnf = dnf
    }

    ghosting:StopGhosting()

    TriggerServerEvent("races:finish", raceIndex, finishData)
    ClearDNFTime()
    SetLeaderboardLower(true)
    ResetReady()
    currentVehicleName = nil
    updateRaceVehicle(nil, nil)
    respawn:ResetRespawn()

    currentRace.currentTrack = ""
    currentRace.raceType = ""
    currentTrack:RestoreBlips()
    currentTrack:RouteToTrack()
    currentGridIndex = -1
    currentGridPosition = nil
    currentGridHeading = nil
    if originalVehicleHash ~= nil then
        local vehicle = switchVehicle(PlayerPedId(), originalVehicleHash)
        if vehicle ~= nil then
            SetVehicleColours(vehicle, colorPri, colorSec)
            SetEntityAsNoLongerNeeded(vehicle)
        end
    end
    raceState = racingStates.Idle
end

local function updateList(isPublic)
    table.sort(vehicleList)
    SendNUIMessage({
        type = 'vehicle-list',
        action = "display_saved_list",
        isPublic = isPublic,
        vehicleList = formattedList
    })
end

local function edit()
    if racingStates.Idle == raceState then
        raceState = racingStates.Editing
        trackEditor:StartEditing(currentTrack)

        local startWaypoint = currentTrack:GetWaypoint(1)

        if (startWaypoint ~= nil) then
            TeleportPlayer(startWaypoint.coord, startWaypoint.heading)
        end

        Notifications.toast("Editing started.\n")
    elseif racingStates.Editing == raceState then
        raceState = racingStates.Idle
        trackEditor:StopEditing()
        Notifications.toast("Editing stopped.\n")
    else
        Notifications.toast("Cannot edit waypoints.  Leave race first.\n")
    end
end

local function clear()
    if racingStates.Idle == raceState then
        currentTrack:Clear()
        Notifications.toast("Waypoints cleared.\n")
    elseif racingStates.Editing == raceState then
        trackEditor:Clear()
        Notifications.toast("Waypoints cleared.\n")
    else
        Notifications.error("Cannot clear waypoints.  Leave race first.\n")
    end
end

local function reverse()
    if currentTrack:GetTotalWaypoints() < 2 then
        Notifications.warn("Cannot reverse waypoints.  Track needs to have at least 2 waypoints.\n")
        return
    end

    if racingStates.Idle == raceState then
        currentTrack.savedTrackName = nil
        currentTrack:LoadWaypointBlips(currentTrack:WaypointsToCoordsRev())
        Notifications.toast("Waypoints reversed.\n")
    elseif racingStates.Editing == raceState then
        trackEditor:Reverse()
        Notifications.toast("Waypoints reversed.\n")
    else
        Notifications.warn("Cannot reverse waypoints.  Leave race first.\n")
    end
end

local function loadTrack(access, trackName)
    
    if "pvt" ~= access and "pub" ~= access then
        Notifications.error("Cannot load.  Invalid access type.\n")
        return
    end

    if trackName == nil then
        Notifications.error("Cannot load.  Name required.\n")
        return
    end

    if racingStates.Idle ~= raceState and racingStates.Editing ~= raceState then
        Notifications.error("Cannot load.  Leave race first.\n")
        return
    end

    TriggerServerEvent("races:load", "pub" == access, trackName)
end

local function deleteTrack(access, trackName)
    if "pvt" == access or "pub" == access then
        if trackName ~= nil then
            TriggerServerEvent("races:delete", "pub" == access, trackName)
        else
            Notifications.error("Cannot delete.  Name required.\n")
        end
    else
        Notifications.error("Cannot delete.  Invalid access type.\n")
    end
end

local function bestLapTimes(access, trackName)
    if "pvt" == access or "pub" == access then
        if trackName ~= nil then
            TriggerServerEvent("races:blt", "pub" == access, trackName)
        else
            Notifications.error("Cannot list best lap times.  Name required.\n")
        end
    else
        Notifications.error("Cannot list best lap times.  Invalid access type.\n")
    end
end

local function listTracks(access)
    if "pvt" == access or "pub" == access then
        TriggerServerEvent("races:list", "pub" == access)
    else
        Notifications.error("Cannot list tracks.  Invalid access type.\n")
    end
end

local function register(tier, specialClass, laps, timeout, rtype, arg7, arg8, arg9, arg10)
    tier = (nil == tier or "." == tier) and defaultTier or string.lower(tier)
    specialClass = (nil == specialClass or "." == specialClass) and defaultSpecialClass or specialClass
    
    laps = (nil == laps or "." == laps) and defaultLaps or math.tointeger(tonumber(laps))
    
    if laps == nil or laps <= 0 then
        Notifications.error("Invalid number of laps.\n")
        return
    end

    timeout = (nil == timeout or "." == timeout) and defaultTimeout or math.tointeger(tonumber(timeout))
    if timeout == nil or timeout <= 0 then
        Notifications.error("Invalid DNF timeout.\n")
        return
    end

    if raceState == racingStates.Editing then
        Notifications.warn("Cannot register. Stop editing first.\n")
        return
    elseif raceState ~= racingStates.Idle then
        Notifications.error("Cannot register. Leave race first.\n")
        return
    end

    if currentTrack:GetTotalWaypoints() <= 1 then
        Notifications.error("Cannot register.  Track needs to have at least 2 waypoints.\n")
        return
    end

    if (laps > 1 and  currentTrack.startIsFinish == false) then
        Notifications.error("For multi-lap races, start and finish waypoints need to be the same: While editing waypoints, select finish waypoint first, then select start waypoint.  To separate start/finish waypoint, add a new waypoint or select start/finish waypoint first, then select highest numbered waypoint.\n")
        return
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
    local randomVehicleListName = nil
    local randomVehicleListPublic = nil
    if "rest" == rtype then
        restrict = arg7
        if nil == restrict or IsModelInCdimage(restrict) ~= 1 or IsModelAVehicle(restrict) ~= 1 then
            Notifications.error("Cannot register.  Invalid restricted vehicle.\n")
            return
        end
    elseif "class" == rtype then
        vclass = math.tointeger(tonumber(arg7))
        if nil == vclass or vclass < -1 or vclass > 21 then
            Notifications.error("Cannot register.  Invalid vehicle class.\n")
            return
        end
        if -1 == vclass then

            randomVehicleListName = arg9

            randomVehicleListPublic = arg10
            if randomVehicleListPublic == nil then 
                randomVehicleListPublic = true
            end
        end
    elseif "rand" == rtype then

        if(arg9 == nil) then
            Notifications.error("Cannot register.  Vehicle list is empty.\n")
            return
        end

        randomVehicleListName = arg9

        randomVehicleListPublic = arg10
        if randomVehicleListPublic == nil then 
            randomVehicleListPublic = true
        end

        vclass = math.tointeger(tonumber(arg7))
        if vclass ~= nil and (vclass < 0 or vclass > 21) then
            Notifications.error("Cannot register.  Invalid vehicle class.\n")
            return
        end
        
        svehicle = arg8
        if svehicle ~= nil then
            if IsModelInCdimage(svehicle) ~= 1 or IsModelAVehicle(svehicle) ~= 1 then
                Notifications.error("Cannot register.  Invalid start vehicle.\n")
                return
            elseif vclass ~= nil and GetVehicleClassFromName(svehicle) ~= vclass then
                Notifications.error(
                "Cannot register.  Start vehicle not of restricted vehicle class.\n")
                return
            end
        end
    elseif "wanted" == rtype then
        print("wanted race type")
    elseif "ghost" == rtype then
        print("ghost race type")
    elseif rtype ~= nil then
        Notifications.error("Cannot register.  Unknown race type.\n")
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
        randomVehicleListName = randomVehicleListName,
        randomVehicleListAccess = randomVehicleListPublic,
        specialClass = specialClass,
        map = currentTrack.map,
        previousRaceResults = previousRaceResults,
        gridLineup = currentGridLineup
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
        Notifications.error("Cannot start.  Invalid delay.\n")
    end
end

local function loadLst(access, name)
    if access ~= "Private" and access ~= "Public" then
        Notifications.error("Cannot load vehicle list.  Invalid access type.\n")
        return
    end

    if name == nil then
        Notifications.error("Cannot load vehicle list.  Name required.\n")
    end
    
    TriggerServerEvent("races:loadLst", access == "Public", name)
end

local function saveList(access, name, vehicles)

    if (access ~= "pvt" and access ~= "pub") then
        Notifications.error("Cannot save vehicle list.  Invalid access type.\n")
        return
    end

    if name == nil then
        Notifications.error("Cannot save vehicle list.  Name required.\n")
        return
    end

    -- if #vehicles == 0 then
    --     Notifications.error("Cannot save vehicle list.  List is empty.\n")
    --     return
    -- end

    vehicleList = vehicles
    TriggerServerEvent("races:saveLst", "pub" == access, name, vehicles)
end

RegisterNetEvent("races:setList")
AddEventHandler("races:setList", function(isPublic, name)
    SendNUIMessage({
        type = "vehicle-list",
        action = "set_list",
        isPublic = isPublic,
        name = name
    })
end)

local function deleteLst(access, name)

    if access ~= "pvt" and access ~= "pub" then
        Notifications.error("Cannot delete vehicle list.  Invalid access type.\n")
        return
    end

    if name == nil then
        Notifications.error("Cannot delete vehicle list.  Name required.\n")
        return
    end
    
    TriggerServerEvent("races:deleteLst", "pub" == access, name)
end

local function addClass(data)
    local class = math.tointeger(tonumber(data.class))

    if class == nil or class < 0 or class > 21 then
        Notifications.error("Cannot add vehicles to vehicle list.  Invalid vehicle class.\n")
        return
    end

    for _, vehicle in pairs(allVehiclesList) do
        if GetVehicleClassFromName(vehicle.spawnCode) == class then
            vehicleList[#vehicleList + 1] = vehicle.spawnCode
        end
    end

    vehicleList = removeDuplicates(vehicleList)

    formattedList = getDisplayNamesFromVehicleList(vehicleList)

    if true == panelShown then
        updateList()
    end
    
end

local function deleteClass(data)
    local class = math.tointeger(tonumber(data.class))

    if class == nil or class < 0 or class > 21 then
        Notifications.error("Cannot add vehicles to vehicle list.  Invalid vehicle class.\n")
        return
    end
    
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

    formattedList = getDisplayNamesFromVehicleList(vehicleList)

    if true == panelShown then
        updateList()
    end

end

local function ClearCurrentWaypoints()
    for _, currentWaypoint in ipairs(currentWaypoints) do
        DeleteCheckpoint(currentWaypoint.checkpoint)
    end

    for k in next, currentWaypoints do rawset(currentWaypoints, k, nil) end

end

local function setFreezeOnPlayer(player, freeze)

    FreezeEntityPosition(player, freeze)

    if IsPedInAnyVehicle(player, false) then
        FreezeEntityPosition(GetVehiclePedIsIn(player, false), freeze)
    else
        FreezeEntityPosition(GetVehiclePedIsIn(player, true), freeze)
    end
end

local function leave()
    local player = PlayerPedId()
    currentVehicleName = nil
    resetRaceVehicle()
    currentGridIndex = -1
    currentGridPosition = nil
    currentGridHeading = nil
    fpsMonitor:StopTracking()
    respawn:ResetRespawn()

    if racingStates.Joining == raceState then
        raceState = racingStates.Idle
        ResetReady()
        ClearLeaderboard()
        TriggerServerEvent("races:leave", raceIndex)
        playerDisplay:ResetRaceBlips()
        Notifications.toast("Left race.\n")
    elseif racingStates.Racing == raceState then
        setFreezeOnPlayer(player, false)
        RenderScriptCams(false, false, 0, true, true)
        ClearCurrentWaypoints()
        finishRace(true)
        playerDisplay:ResetRaceBlips()
        ResetReady()
        ClearLeaderboard()
        Notifications.toast("Left race.\n")
    else
        Notifications.warn("Cannot leave.  Not joined to any race.\n")
    end
end

local function endrace()
    TriggerServerEvent("races:endrace")
end

local function viewResults()

    if #results <= 0 then 
        Notifications.warn("No Race results to show");
        return 
    end

    local convertedResults = {}
    for pos, result in ipairs(results) do

        local fMinutes, fSeconds = minutesSeconds(result.finishTime)
        local lMinutes, lSeconds = minutesSeconds(result.bestLapTime)

        local finishTime = result.bestLapTime >= 0 and ("%02d:%05.2f"):format(fMinutes, fSeconds) or "N/A"
        local bestLapTime = result.bestLapTime >= 0 and ("%02d:%05.2f"):format(lMinutes, lSeconds) or "N/A"

        local result = {
            position = result.finishTime ~= -1 and pos or "DNF",
            playerName = result.playerName,
            time = finishTime,
            fastestLap = bestLapTime,
            vehicleName = result.vehicleName,
            averageFPS = result.averageFPS
        }

        table.insert(convertedResults, result)
    end

    SendNUIMessage({
        type = "results",
        action = "show_race_results",
        results = convertedResults,
        numberOfLaps = numLaps,
        trackName = currentRace.trackName,
    })

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
    
            Notifications.toast("'" .. GetLabelText(GetDisplayNameFromVehicleModel(vehicleHash)) .. "' spawned.\n")
        else
            Notifications.error("Cannot spawn vehicle.  Invalid vehicle.\n")
        end
    end
end

local function showPanel(panel)
    panelShown = true
    if nil == panel then
        SetNuiFocus(true, true)
        TriggerServerEvent("races:trackNames", false)
        TriggerServerEvent("races:trackNames", true)
        SendNUIMessage({
            panel = "main",
            defaultVehicle = defaultVehicle
        })
    elseif "edit" == panel then
        SetNuiFocus(true, true)
        TriggerServerEvent("races:trackNames", false)
        TriggerServerEvent("races:trackNames", true)
        SendNUIMessage({
            panel = "edit"
        })
    elseif "register" == panel then
        SetNuiFocus(true, true)
        TriggerServerEvent("races:trackNames", false)
        TriggerServerEvent("races:trackNames", true)
        SendNUIMessage({
            panel = "register",
            defaultLaps = defaultLaps,
            defaultTimeout = defaultTimeout,
            defaultDelay = defaultDelay,
            allVehicles = allVehiclesList
        })
    elseif "list" == panel then
        SetNuiFocus(true, true)
        -- updateList()
        SendNUIMessage({
            type = "vehicle-list",
            action = "display_list",
            allVehicles = allVehiclesList
        })
    else
        Notifications.warn("Invalid panel.\n")
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

function UpdateCurrentProgress()
    SendNUIMessage({
        type = "leaderboard",
        action = "updateCurrentProgress",
        section = currentSection,
        waypoint = currentWaypoint,
        totalWaypoints = currentSectionLength
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

RegisterNUICallback("uiReady", function()
    TriggerServerEvent("races:recieveUIData")
end)

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
                    Notifications.error("Cannot overwrite.  Track needs to have at least 2 waypoints.\n")
                end
            else
                Notifications.error("Cannot overwrite.  Name required.\n")
            end
        else
            Notifications.error("Cannot overwrite.  Invalid access type.\n")
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
        local randomVehicleList = data.randomVehicleList
        local randomVehicleListPublic = data.randomVehicleListPublic

        register(tier, specialClass, laps, timeout, rtype, vclass, svehicle, randomVehicleList, randomVehicleListPublic)
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

RegisterNUICallback("add_class", function(data)
    addClass(data)
end)

RegisterNUICallback("delete_class", function(data)
    deleteClass(data)
end)

RegisterNUICallback("load_list", function(data)
    loadLst(data.access, data.name)
end)

RegisterNUICallback("save_list", function(data)

    if data.name == nil or data.access == nil or data.vehicles == nil then
        return 
    end

    saveList(data.access, data.name, data.vehicles)
end)

RegisterNUICallback("delete_list", function(data)

    if (data.name == nil or data.access == nil) then
        return
    end

    deleteLst(data.access, data.name)
end)

RegisterNUICallback("leave", function()
    leave()
end)

RegisterNUICallback("respawn", function()
    respawn:Respawn(PlayerPedId())
end)

RegisterNUICallback("results", function()
    viewResults()
end)

RegisterNUICallback("spawn", function(data)
    local vehicle = data.vehicle
    if "" == vehicle then
        vehicle = nil
    end
    spawn(vehicle)
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
        Notifications.toast(("Map changed to %s"):format(data.map))
    else
        Notifications.toast("Map unset")
    end
end)

RegisterNUICallback("updateGridPositions", function(data)
    currentGridLineup = data.gridLineup
    TriggerServerEvent("races:updateGridPositions", data.gridLineup)
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
        TriggerServerEvent("races:resetupgrade", 11, currentTrack.savedTrackName)
    end

    if bUpgrade ~= -1 then
        SetVehicleMod(vehicle, 12, -1) --Brakes upgrade
        TriggerServerEvent("races:resetupgrade", 12, currentTrack.savedTrackName)
    end

    if gUpgrade ~= -1 then
        SetVehicleMod(vehicle, 13, -1) --Gearbox upgrade
        TriggerServerEvent("races:resetupgrade", 13, currentTrack.savedTrackName)
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
        msg = msg .. "/races leave - leave a race that you joined\n"
        msg = msg .. "/races respawn - respawn at last waypoint\n"
        msg = msg .. "/races results - view latest race results\n"
        msg = msg .. "/races spawn (vehicle) - spawn a vehicle; (vehicle) defaults to 'adder'\n"
        msg = msg ..
        "/races speedo (unit) - change unit of speed measurement to (unit) = {imp, met}; otherwise toggle display of speedometer if (unit) is not specified\n"
        msg = msg ..
        "/races panel (panel) - display (panel) = {edit, register, list} panel; otherwise display main panel if (panel) is not specified\n"
        Notifications.chat(msg)
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
                        Notifications.error("Cannot overwrite.  Track needs to have at least 2 waypoints.\n")
                    end
                else
                    Notifications.error("Cannot overwrite.  Name required.\n")
                end
            else
                Notifications.error("Cannot overwrite.  Invalid access type.\n")
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
    elseif "leave" == args[1] then
        leave()
    elseif "end" == args[1] then
        endrace()
    elseif "respawn" == args[1] then
        respawn:Respawn(PlayerPedId())
    elseif "results" == args[1] then
        viewResults()
    elseif "spawn" == args[1] then
        spawn(args[2])
    elseif "speedo" == args[1] then
        setSpeedo(args[2])
    elseif "panel" == args[1] then
        showPanel(args[2])
    elseif "upgrade" == args[1] then
        resetupgrades()
    elseif "ghost" == args[1] then
        ghosting:StartGhostingDefault()
    elseif "killme" == args[1] then
        SetEntityHealth(PlayerPedId(), 0)
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
        Notifications.warn("Unknown command.\n")
    end
end)

RegisterNetEvent("races:load")
AddEventHandler("races:load", function(isPublic, trackName, track)
    if isPublic == nil or trackName == nil and track.waypoints == nil then
        Notifications.warn("Ignoring load event.  Invalid parameters.\n")
        return
    end

    if racingStates.Idle ~= raceState and racingStates.Editing ~= raceState then
        Notifications.warn("Ignoring load event.  Currently joined to race.\n")
        return
    end

    if racingStates.Idle == raceState then
        currentTrack:Load(isPublic, trackName, track)
    elseif racingStates.Editing == raceState then
        trackEditor:Load(isPublic, trackName, track)
    end

    Notifications.toast("Loaded " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
end)

RegisterNetEvent("races:save")
AddEventHandler("races:save", function(isPublic, trackName)
    if isPublic ~= nil and trackName ~= nil then
        trackEditor:OnUpdateTrackMetaData(isPublic, trackName)
        Notifications.toast("Saved " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
    else
        Notifications.warn("Ignoring save event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:overwrite")
AddEventHandler("races:overwrite", function(isPublic, trackName, map)
    if isPublic ~= nil and trackName ~= nil then
        trackEditor:OnUpdateTrackMetaData(isPublic, trackName)
        Notifications.toast("Overwrote " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. (nil ~= map and " with map " .. map or "") ..  "'.\n")
    else
        Notifications.warn("Ignoring overwrite event.  Invalid parameters.\n")
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
            Notifications.toast(msg)
        else
            Notifications.warn("No best lap times for " .. msg .. ".\n")
        end
    else
        Notifications.warn("Ignoring best lap times event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:loadLst")
AddEventHandler("races:loadLst", function(isPublic, name, list)
    if isPublic == nil or name == nil then
        Notifications.warn("Ignoring load vehicle list event.  Invalid parameters.\n")
        return
    end

    vehicleList = list
    
    formattedList = getDisplayNamesFromVehicleList(list)

    if true == panelShown then
        updateList(isPublic)
    end
end)

RegisterNetEvent("races:register")
AddEventHandler("races:register",
function(rIndex, waypoint, isPublic, trackName, owner, rdata)

    if rIndex == nil and waypoint == nil and isPublic == nil and owner == nil and rdata.tier == nil and rdata.laps == nil and rdata.timeout == nil and rdata == nil then
        Notifications.warn("Ignoring register event.  Invalid parameters.\n")
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
        randomVehicleListName = rdata.randomVehicleListName,
        blip = blip,
        checkpoint = checkpoint,
        registerPosition = waypoint.coord,
        map = rdata.map
    }

    if(rIndex == GetPlayerServerId(PlayerId())) then
        respawn:SetRespawnPosition(waypoint.coord)
        respawn:SetRespawnHeading(waypoint.heading)
    end

end)

RegisterNetEvent("races:unregister")
AddEventHandler("races:unregister", function(rIndex)
    if rIndex ~= nil then
        if starts[rIndex] ~= nil then
            currentTrack:DeleteGridCheckPoints()
            removeRegistrationPoint(rIndex)
        end

        if rIndex == raceIndex then

            if(rIndex == GetPlayerServerId(PlayerId())) then
                respawn:resetRespawn()
            end

            local player = PlayerPedId()

            if racingStates.Joining == raceState then
                raceState = racingStates.Idle
                --Shouldn't need to reset here, but just incase
                playerDisplay:ResetRaceBlips()
                Notifications.toast("Race canceled.\n")
                setFreezeOnPlayer(player, false)
            elseif racingStates.Racing == raceState then
                raceState = racingStates.Idle
                ClearCurrentWaypoints()
                currentTrack:Unegister()
                --Shouldn't need to reset here, but just incase
                playerDisplay:ResetRaceBlips()
                RenderScriptCams(false, false, 0, true, true)
                setFreezeOnPlayer(player, false)
                if originalVehicleHash ~= nil then
                    local vehicle = switchVehicle(player, originalVehicleHash)
                    if vehicle ~= nil then
                        SetVehicleColours(vehicle, colorPri, colorSec)
                        SetEntityAsNoLongerNeeded(vehicle)
                    end
                end
                Notifications.toast("Race canceled.\n")
            end
        end
    else
        Notifications.warn("Ignoring unregister event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:greenflag")
AddEventHandler("races:greenflag", function()
    local player = PlayerPedId()
    setFreezeOnPlayer(player, false)
    raceState = racingStates.Racing
    PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET", true)
    currentLapTimer:Start()
    fpsMonitor:StartTrackingAverage()
    if(currentRace.raceType ~= 'ghost') then
        print(("Starting ghost with %i seconds"):format(configData['raceStartGhostingTime']))
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
                    waypointsHit = 0
                    currentLap = 1
                    numRacers = -1
                    results = {}
                    respawn:SetRespawnPosition(GetEntityCoords(PlayerPedId()))
                    respawn:SetRespawnHeading(GetEntityHeading(PlayerPedId()))

                    if startVehicle ~= nil then
                        local vehicle = switchVehicle(PlayerPedId(), startVehicle)
                        if vehicle ~= nil then
                            SetEntityAsNoLongerNeeded(vehicle)
                        end
                    end

                    currentWaypoints = currentTrack:OnStartRace()

                    raceState = racingStates.RaceCountdown

                    local player = PlayerPedId()
                    local currentVehicle = GetVehiclePedIsIn(player, true)
                    local lastVehicle = GetVehiclePedIsIn(player, false)
                    local vehicle = currentVehicle ~= 0 and currentVehicle or lastVehicle
                    updateRaceVehicle(vehicle)
                    respawn:Respawn()

                    StartRaceEffects()

                    repairVehicle(vehicle)
                    resetupgrades(vehicle)
                    ClearReady();

                    SetLeaderboardLower(false)
                    StartCountdownLights(delay)

                    setFreezeOnPlayer(player, true)
                    Citizen.CreateThread(RaceStartCameraTransition)

                elseif racingStates.Racing == raceState then
                    Notifications.warn("Ignoring start event.  Already in a race.\n")
                elseif racingStates.Editing == raceState then
                    Notifications.warn("Ignoring start event.  Currently editing.\n")
                else
                    Notifications.warn("Ignoring start event.  Currently idle.\n")
                end
            end
        else
            Notifications.warn("Ignoring start event.  Invalid delay.\n")
        end
    else
        Notifications.warn("Ignoring start event.  Invalid parameters.\n")
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
    respawn:Respawn(PlayerPedId())
end)

RegisterNetEvent("races:hide")
AddEventHandler("races:hide", function(rIndex)
    if rIndex ~= nil then
        if starts[rIndex] ~= nil then
            removeRegistrationPoint(rIndex)
        else
            Notifications.warn("Ignoring hide event.  Race does not exist.\n")
        end
    else
        Notifications.warn("Ignoring hide event.  Invalid parameters.\n")
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
    Notifications.toast(message)
end)

RegisterNetEvent("races:removeFromLeaderboard")
AddEventHandler("races:removeFromLeaderboard", function(source)
    RemoveRacerFromLeaderboard(source)
end)

RegisterNetEvent("races:join")
AddEventHandler("races:join", function(rIndex, tier, specialClass, waypoints, racerDictionary)
    if rIndex == nil or waypoints == nil then
        Notifications.warn("Ignoring join event.  Invalid parameters.\n")
        return
    end

    if starts[rIndex] == nil then
        Notifications.warn("Ignoring join event.  Race does not exist.\n")
        return 
    end

    if raceState == racingStates.Editing then
        Notifications.warn("Ignoring join event.  Currently editing.\n")
        return
    end

    if raceState ~= racingStates.Idle and raceState ~= racingStates.Editing then
        Notifications.warn("Already joined, ignoring")
        return
    end

    SetJoinMessage('')
    raceState = racingStates.Joining
    raceIndex = rIndex
    numLaps = starts[rIndex].laps
    DNFTimeout = starts[rIndex].timeout * 1000
    restrictedHash = nil
    restrictedClass = starts[rIndex].vclass
    customClassVehicleList = {}
    startVehicle = starts[rIndex].svehicle
    if (startVehicle ~= nil) then
        Notifications.toast("Pre-loading starting car...")
        RequestModel(startVehicle)
        while HasModelLoaded(startVehicle) == false do
            Citizen.Wait(0)
        end
        Notifications.toast("Starting car loaded...")
    end
    randVehicles = {}
    currentTrack:LoadWaypointBlips(waypoints)
    currentTrack:IdentifySections();
    playerDisplay:SetOwnRacerBlip()

    currentRace.trackName = starts[rIndex].trackName
    currentRace.raceType = starts[rIndex].rtype ~= nil and starts[rIndex].rtype  or 'normal'

    local raceData = {
        laps = starts[rIndex].laps,
        totalCheckpoints = currentTrack.startIsFinish == true and currentTrack:GetTotalWaypoints() or currentTrack:GetTotalWaypoints() - 1
    }
    SendRaceData(raceData)
    SetRaceLeaderboard(true)
    AddRacersToLeaderboard(racerDictionary, GetPlayerServerId(PlayerId()))

    fpsMonitor:StartTracking()

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
        print(dump(starts[rIndex].vehicleList))
        print(dump(starts[rIndex]))
    elseif "wanted" == starts[rIndex].rtype then
        msg = msg .. " : using wanted race mode"
    elseif starts[rIndex].rtype == "ghost" then
        msg = msg .. " : using ghost race mode"
    end

    if(starts[rIndex].map ~= "") then
        msg = msg .. (" with map %s"):format(starts[rIndex].map);
    end

    msg = msg .. ".\n"
    Notifications.toast(msg)
    SendToRaceTier(tier, specialClass)
    UpdateVehicleName()
    SendVehicleName()
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
    local averageFPS = finishData.averageFPS

    if finishData == nil then
        Notifications.warn("Ignoring finish event.  Invalid parameters.\n")
        return
    end

    if rIndex ~= raceIndex then
        return
    end

    if -1 == raceFinishTime then
        if -1 == raceBestLapTime then
            Notifications.toast(playerName .. " did not finish.\n")
        else
            local minutes, seconds = minutesSeconds(raceBestLapTime)
            Notifications.toast(("%s did not finish and had a best lap time of %02d:%05.2f using %s.\n"):format(
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
        Notifications.toast(("%s finished in %02d:%05.2f and had a best lap time of %02d:%05.2f using %s with an average FPS of %.2f.\n"):format(
        playerName, fMinutes, fSeconds, lMinutes, lSeconds, raceVehicleName, averageFPS))

        print(dump(finishData))
        print(dump(finishData.source))

        SendNUIMessage({
            type = "leaderboard",
            action = "set_leaderboard_finished",
            source = finishData.source
        })
    end
    ResetCarTier();
    playerDisplay:ResetRaceBlips()
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
    ClearGrid()

    if rIndex ~= nil and raceResults ~= nil then
        if rIndex == raceIndex then
            results = raceResults
            viewResults()
        end
    else
        Notifications.warn("Ignoring results event.  Invalid parameters.\n")
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
        Notifications.warn("Ignoring position event.  Invalid parameters.\n")
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

RegisterNetEvent("races:updatePlayers")
AddEventHandler("races:updatePlayers", function(players)
    if(raceState ~= racingStates.Racing) then
        playerDisplay:UpdatePlayerNames(players)
    end
end)

RegisterNetEvent("races:allVehicles")
AddEventHandler("races:allVehicles", function(allVehicles)
    if allVehicles == nil then
        Notifications.warn("Ignoring allVehicles event.  Invalid parameters.\n")
        return
    end

    allVehiclesList = getDisplayNamesFromVehicleList(allVehicles)
end)

RegisterNetEvent("races:trackNames")
AddEventHandler("races:trackNames", function(isPublic, trackNames)
    if isPublic == nil or trackNames == nil then
        Notifications.warn("Ignoring trackNames event.  Invalid parameters.\n")
        return
    end

    print("Sending track names")

    if true == panelShown then
        SendNUIMessage({
            update = "trackNames",
            access = false == isPublic and "pvt" or "pub",
            trackNames = trackNames
        })
    end
end)

RegisterNetEvent("races:vehicleLists")
AddEventHandler("races:vehicleLists", function(publicVehicleListNames, privateVehicleListNames)
    SendNUIMessage({
        type = "vehicle-list",
        action = "recieve_lists",
        public = publicVehicleListNames,
        private = privateVehicleListNames
    })
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

RegisterNetEvent("races:refreshcheckpoints")
AddEventHandler("races:refreshcheckpoints", function(gridPositions)
    currentTrack:DeleteGridCheckPoints()
    currentTrack:SpawnCheckpoints(gridPositions)
end)

RegisterNetEvent("races:teleportplayer")
AddEventHandler("races:teleportplayer", function(position, heading)
    TeleportPlayer({x = position.x, y = position.y, z = position.z}, heading)
end)

RegisterNetEvent("races:freezeplayer")
AddEventHandler("races:freezeplayer", function()
    print("freezing player")
    setFreezeOnPlayer(PlayerPedId(), true)
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

RegisterNetEvent("races:sendraceresults")
AddEventHandler("races:sendraceresults", function(raceResults)
    previousRaceResults = raceResults table.sort(raceResults, function(a, b) return a.position > b.position end )
end)

RegisterNetEvent("races:addgridlineup")
AddEventHandler("races:addgridlineup", function(gridLineup)
    currentGridLineup = gridLineup
    SendNUIMessage({
        type = "grid",
        action = "add_to_grid",
        gridLineup = gridLineup,
    })
end)

RegisterNetEvent("races:addracertogridlineup")
AddEventHandler("races:addracertogridlineup", function(gridRacer)

    SendNUIMessage({
        type = "grid",
        action = "add_racer_to_grid",
        racer = {
            source = gridRacer.source,
            name = gridRacer.name,
            position = gridRacer.position
        },
    })
end)

RegisterNetEvent("races:removeracerfromgridlineup")
AddEventHandler("races:removeracerfromgridlineup", function(source)
    SendNUIMessage({
        type = "grid",
        action = "remove_racer_from_grid",
        source = source
    })
end)

RegisterNetEvent("races:cleargridpositions")
AddEventHandler("races:cleargridpositions", function(source)
    ClearGrid()
end)

RegisterNetEvent("races:moveToGrid")
AddEventHandler("races:moveToGrid", function(gridIndex, gridPosition, gridHeading)
    if (currentGridIndex == gridIndex) then
        print("Alread on that grid position, ignoring")
        return
    end

    currentGridIndex = gridIndex
    currentGridPosition = gridPosition
    currentGridHeading = gridHeading

    respawn:SetRespawnPosition(currentGridPosition)
    respawn:SetRespawnHeading(gridHeading)

    TeleportPlayer(gridPosition, gridHeading)

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

        local player = PlayerPedId()
        if racingStates.Racing == raceState then
            --TODO:Send current waypoint index as well as distance
            local closestWaypointDistance = 99999;
            for _, currentWaypoint in pairs(currentWaypoints) do
                local distance = #(GetEntityCoords(player) - currentWaypoint.coord)

                if(distance < closestWaypointDistance) then
                    closestWaypointDistance = distance
                end
            end

            local distanceToEnd = currentTrack:DistanceToEnd(previousWaypoint)

            TriggerServerEvent("races:report", raceIndex, currentLap, currentWaypoint, distanceToEnd, closestWaypointDistance)
            TriggerServerEvent("races:updatefps", raceIndex, fpsMonitor.fps)
        end

        if(not CarTierUIActive()) then
            local vehicle = GetVehiclePedIsIn(player, false)

            if vehicle ~= 0 then
                currentVehicleName = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
            else
                currentVehicleName = "On foot"
            end

            UpdateVehicleName(currentVehicleName)
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

function HandleJoinState(player)

    if(currentGridPosition ~= nil) then
        local vehicle = GetVehiclePedIsIn(player, false)
        local entityToFreeze = vehicle ~= 0 and vehicle or player
        setFreezeOnPlayer(player, true)
        SetEntityHeading(entityToFreeze, currentGridHeading)
        local playerCoord = GetEntityCoords(player)
        local distanceFromGridPosition = #(playerCoord - currentGridPosition)
        
        if(distanceFromGridPosition > 3.0) then 
            if(GetPlayerName(PlayerId()) == "Payne") then
                Notifications.toast("Come on Payne, try and be a bit more patient please...") 
            else
                Notifications.toast("You moved too far from your grid position, resettting")
            end
            TeleportPlayer(currentGridPosition, currentGridHeading)
        end
    end

    if IsControlJustReleased(0, 173) then
        print("Down pressed")
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
            updateRaceVehicle(vehicle)
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

RegisterNetEvent("races:config")
AddEventHandler("races:config", function(_configData)
    configData = _configData
    print("Loaded config")

    ghosting:LoadConfig(configData['ghostingTime'], configData['ghosting'])
    playerDisplay:LoadConfig(configData['playerDisplay'])

    lobbySpawn = _configData['spawning']['spawnLocation']
    spawnOffsetVector = _configData['spawning']['spawnOffsetVector']

    local offsetSpawn = getOffsetSpawn(lobbySpawn)

    respawn:SetLobbySpawn(offsetSpawn)

    exports.spawnmanager:setAutoSpawn(false)
    exports.spawnmanager:forceRespawn()
    exports.spawnmanager:spawnPlayer({
        x = offsetSpawn.x,
        y = offsetSpawn.y,
        z = offsetSpawn.z,
        heading = offsetSpawn.heading,
        skipFade = true
    })

    Citizen.Wait(0)
    respawn:Respawn()
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

RegisterNetEvent("races:updatefps")
AddEventHandler("races:updatefps", function(source, fps)
    fpsMonitor:UpdateFPS(source, fps)
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

--Returns true when the race is finished
function OnNewLap(player)
    previousWaypoint = 1
    currentLapTimer:Reset()
    TriggerServerEvent("races:lapcompleted", raceIndex, currentVehicleName)
    fpsMonitor:SaveAverageChunk()

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
            Notifications.toast("Random Index: " .. randIndex)
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

    currentSection, currentWaypoint, currentSectionLength = currentTrack:CalculateProgress(waypointHit)

    local coord, heading = currentTrack:GetTrackRespawnPosition(previousWaypoint)
    respawn:SetRespawnPosition(coord)
    respawn:SetRespawnHeading(heading)

    --If the waypoint points to at least one other waypoint
    if not currentTrack:AtEnd(waypointHit, waypointsHit) then
        PlaySoundFrontend(-1, "CHECKPOINT_NORMAL", "HUD_MINI_GAME_SOUNDSET", true)
    else
        if (OnNewLap(player)) then
            return
        end
    end

    if(Config.data.playerDisplay.raceDisplay.splitTimes) then
        TriggerServerEvent("races:sendCheckpointTime", raceIndex, currentLap, currentSection, currentWaypoint)
    end

    waypointsHit = waypointsHit + 1

    UpdateCurrentProgress()

    --TODO:Make sure next waypoints are retrieved not just one
    currentWaypoints = currentTrack:OnHitCheckpoint(waypointHit, previousWaypoint, currentLap, numLaps)

    previousWaypoint = waypointHit
end

function RaceUpdate(player, playerCoord, currentTime)
    ghosting:Update();
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
            print("E pressed")
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
                        Notifications.warn("Cannot join race.  Player needs to be in restricted vehicle.")
                    end
                else
                    joinRace = false
                    Notifications.warn("Cannot join race.  Player needs to be in restricted vehicle.")
                end
            elseif "class" == starts[closestIndex].rtype then
                if starts[closestIndex].vclass ~= -1 then
                    if vehicle ~= nil then
                        if GetVehicleClass(vehicle) ~= starts[closestIndex].vclass then
                            joinRace = false
                            Notifications.warn("Cannot join race.  Player needs to be in vehicle of " ..
                            getClassName(starts[closestIndex].vclass) .. " class.")
                        end
                    else
                        joinRace = false
                        Notifications.warn("Cannot join race.  Player needs to be in vehicle of " ..
                        getClassName(starts[closestIndex].vclass) .. " class.")
                    end
                else
                    if #starts[closestIndex].vehicleList == 0 then
                        joinRace = false
                        Notifications.warn("Cannot join race.  No valid vehicles in vehicle list.")
                    else
                        local list = ""
                        for _, vehName in pairs(starts[closestIndex].vehicleList) do
                            list = list .. vehName .. ", "
                        end
                        list = string.sub(list, 1, -3)
                        if vehicle ~= nil then
                            if vehicleInList(vehicle, starts[closestIndex].vehicleList) == false then
                                joinRace = false
                                Notifications.warn(
                                "Cannot join race.  Player needs to be in one of the following vehicles: " ..
                                list)
                            end
                        else
                            joinRace = false
                            Notifications.warn(
                            "Cannot join race.  Player needs to be in one of the following vehicles: " .. list)
                        end
                    end
                end
            elseif "rand" == starts[closestIndex].rtype then
                if #starts[closestIndex].vehicleList == 0 then
                    joinRace = false
                    Notifications.warn("Cannot join race.  No valid vehicles in vehicle list.")
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
                                    Notifications.warn("Cannot join race.  Player needs to be in vehicle of " ..
                                    getClassName(starts[closestIndex].vclass) .. " class.")
                                end
                            else
                                joinRace = false
                                Notifications.warn("Cannot join race.  Player needs to be in vehicle of " ..
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

        respawn:Update(player, currentTime)

        if racingStates.Editing == raceState then
            trackEditor:Update(playerCoord, heading)
        elseif racingStates.Racing == raceState then
            RaceUpdate(player, playerCoord, currentTime)
        elseif racingStates.Joining == raceState then
            HandleJoinState(player)
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