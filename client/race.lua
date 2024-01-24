SetManualShutdownLoadingScreenNui(true)

local STATE_IDLE <const> = 0
local STATE_EDITING <const> = 1
local STATE_JOINING <const> = 2
local STATE_RACING <const> = 3
local raceState = STATE_IDLE -- race state

local gridRadius <const> = 5.0
local gridCheckpoint

local ROLE_EDIT <const> = 1     -- edit tracks role
local ROLE_REGISTER <const> = 2 -- register races role
local ROLE_SPAWN <const> = 4    -- spawn vehicles role

local white <const> = { r = 255, g = 255, b = 255 }
local red <const> = { r = 255, g = 0, b = 0 }
local green <const> = { r = 0, g = 255, b = 0 }
local blue <const> = { r = 0, g = 0, b = 255 }
local yellow <const> = { r = 255, g = 255, b = 0 }
local purple <const> = { r = 255, g = 0, b = 255 }

local startFinishBlipColor <const> = 5    -- yellow
local startBlipColor <const> = 2          -- green
local finishBlipColor <const> = 0         -- white
local midBlipColor <const> = 38           -- dark blue
local registerBlipColor <const> = 83      -- purple
local racerBlipColor <const> = 2          -- green

local selectedBlipColor <const> = 1       -- red

local blipRouteColor <const> = 18         -- light blue

local startFinishSprite <const> = 38      -- checkered flag
local startSprite <const> = 38            -- checkered flag
local finishSprite <const> = 38           -- checkered flag
local midSprite <const> = 1               -- numbered circle
local registerSprite <const> = 58         -- circled star
local racerSprite <const> = 1             -- circle

local finishCheckpoint <const> = 9        -- cylinder checkered flag
local midCheckpoint <const> = 42          -- cylinder with number
local plainCheckpoint <const> = 45        -- cylinder
local arrow3Checkpoint <const> = 7        -- cylinder with 3 arrows

local defaultTier <const> = "none"        -- default race Tier
local defaultSpecialClass <const> = "none"-- default race Tier
local defaultLaps <const> = 3             -- default number of laps in a race
local defaultTimeout <const> = 1200       -- default DNF timeout
local defaultDelay <const> = 5            -- default race start delay
local defaultVehicle <const> = "adder"    -- default spawned vehicle
local defaultRadius <const> = 8.0         -- default waypoint radius

local minRadius <const> = 0.5             -- minimum waypoint radius
local maxRadius <const> = 20.0            -- maximum waypoint radius

local maxNumVisible <const> = 3           -- maximum number of waypoints visible during a race
local numVisible = maxNumVisible          -- number of waypoints visible during a race - may be less than maxNumVisible

local highlightedCheckpoint = 0           -- index of highlighted checkpoint
local selectedIndex0 = 0                  -- index of first selected waypoint
local selectedIndex1 = 0                  -- index of second selected waypoint

local raceIndex = -1                      -- index of race player has joined
local isPublicTrack = false               -- flag indicating if saved track is public or not
local savedTrackName = nil                -- name of saved track - nil if track not saved

local waypoints = {}                      -- waypoints[] = {coord = {x, y, z, r}, checkpoint, blip, sprite, color, number, name}
local startIsFinish = false               -- flag indicating if start and finish are same waypoint

local numLaps = -1                        -- number of laps in current race
local currentLap = -1                     -- current lap

local numWaypointsPassed = -1             -- number of waypoints player has passed
local currentWaypoint = -1                -- current waypoint - for multi-lap races, actual current waypoint is currentWaypoint % #waypoints + 1
local waypointCoord = nil                 -- coordinates of current waypoint

local raceStart = -1                      -- start time of race before delay
local raceDelay = -1                      -- delay before official start of race
local countdown = -1                      -- countdown before start
local drawLights = false                  -- draw start lights

local position = -1                       -- position in race out of numRacers players
local numRacers = -1                      -- number of players in race - no DNF players included
local racerBlipGT = {}                    -- blips and gamer tags for all racers participating in race

local lapTimeStart = -1                   -- start time of current lap
local bestLapTime = -1                    -- best lap time

local raceCheckpoint = nil                -- race checkpoint in world

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
local currentVehicleHash = nil            -- hash of current vehicle being driven
local currentVehicleName = nil            -- name of current vehicle being driven
local bestLapVehicleName = nil            -- name of vehicle in which player recorded best lap time

local randVehicles = {}                   -- list of random vehicles used in random vehicle races

local respawnLock = false
local respawnCtrlPressed = false          -- flag indicating if respawn crontrol is pressed
local respawnTime = -1                    -- time when respawn control pressed
local respawnTimer = 500
local startCoord = nil                    -- coordinates of vehicle once race has started

local results = {}                        -- results[] = {source, playerName, finishTime, bestLapTime, vehicleName}

local started = false                     -- flag indicating if race started

local starts = {}                         -- starts[playerID] = {isPublic, trackName, owner, tier, laps, timeout, rtype, restrict, vclass, svehicle, vehicleList, blip, checkpoint, gridData} - registration points

local panelShown = false                  -- flag indicating if main, edit, register, or list panel is shown
local allVehiclesList = {}                -- list of all vehicles from vehicles.txt
local allVehiclesHTML = ""                -- html option list of all vehicles

local roleBits = 0                        -- bit flag indicating if player is permitted to create tracks, register races, and/or spawn vehicles

local enteringVehicle = false             -- flag indicating if player is entering a vehicle

local camTransStarted = false             -- flag indicating if camera transition at start of race has started

local localPlayerPed = GetPlayerPed(-1)
local localVehicle = GetVehiclePedIsIn(localPlayerPed, false)

local ready = false

local wantedMode = false

local ghosting = Ghosting:new()

local configData

AddEventHandler('onClientGameTypeStart', function()
    exports.spawnmanager:setAutoSpawnCallback(function()
        if STATE_RACING == raceState then
            print("In race, spawning at race")
            local coord = startCoord
            if true == startIsFinish then
                if currentWaypoint > 0 then
                    coord = waypoints[currentWaypoint].coord
                end
            else
                if currentWaypoint > 1 then
                    coord = waypoints[currentWaypoint - 1].coord
                end
            end

            exports.spawnmanager:spawnPlayer({
                x = coord.x,
                y = coord.y,
                z = coord.z,
                heading = coord.heading,
                skipFade = true
            })
        else

            print("Not in Race, spawning at airport")
            exports.spawnmanager:spawnPlayer({
                x = -1437.03,
                y = -2993.15,
                z = 13.94,
                heading = 222.93,
                skipFade = true
            })

        end
    end)

    exports.spawnmanager:setAutoSpawn(true)
    exports.spawnmanager:forceRespawn()
end)

math.randomseed(GetCloudTimeAsInt())

TriggerServerEvent("races:init")

local function notifyPlayer(msg)
    TriggerEvent("chat:addMessage", {
        color = { 255, 0, 0 },
        multiline = true,
        args = { "[races:client]", msg }
    })
end

local function sendMessage(msg)
    if true == panelShown then
        SendNUIMessage({
            panel = "reply",
            message = string.gsub(msg, "\n", "<br>")
        })
    end
    notifyPlayer(msg)
end

local function deleteWaypointCheckpoints()
    for i = 1, #waypoints do
        DeleteCheckpoint(waypoints[i].checkpoint)
    end
end

local gridSeparation <const> = 5
local gridCheckpoints = {}
local sologridCheckpoint = {}

local function CreateGridCheckpoint(position, gridNumber)

    gridCheckpoint = CreateCheckpoint(45,
        position.x, position.y, position.z - gridRadius / 2.0,
        position.x, position.y, position.z,
        gridRadius,
        0, 255, 0,
        127, gridNumber)

    SetCheckpointCylinderHeight(gridCheckpoint, 10.0, 10.0, gridRadius * 2.0)

    return gridCheckpoint
end

local function DeleteGridCheckPoints()
    print("Deleting grid")
    for _, checkpoint in pairs(gridCheckpoints) do
        DeleteCheckpoint(checkpoint)
    end

    for k in next, gridCheckpoints do rawset(gridCheckpoints, k, nil) end
end

local function GenerateStartingGrid(startWaypoint, totalGridPositions)
    DeleteGridCheckPoints()

    print("Generating starting grid")
    local startPoint = vector3(startWaypoint.x, startWaypoint.y, startWaypoint.z)

    -- print(string.format("Starting Grid: %.2f, %.2f, %.2f", startPoint.x, startPoint.y, startPoint.z))
    -- print(string.format("Starting Heading: %.2f", startWaypoint.heading))

    --Calculate the forwardVector of the starting Waypoint
    local x = -math.sin(math.rad(startWaypoint.heading)) * math.cos(0)
    local y = math.cos(math.rad(startWaypoint.heading)) * math.cos(0)
    local z = math.sin(0);
    local forwardVector = norm(vector3(x, y, z))

    local leftVector = norm(vector3(
        math.cos(math.rad(startWaypoint.heading)),
        math.sin(math.rad(startWaypoint.heading)),
        0.0)
    )

    -- print(string.format("Forward Vector: %.2f, %.2f, %.2f", forwardVector.x, forwardVector.y, forwardVector.z))
    -- print(string.format("Left Vector: %.2f, %.2f, %.2f", leftVector.x, leftVector.y, leftVector.z))

    for i = 1, totalGridPositions do

        local gridPosition = startPoint - forwardVector * (i + 1) * gridSeparation

        -- print(string.format("Initial grid position Position(%.2f,%.2f,%.2f)", gridPosition.x, gridPosition.y,
        -- gridPosition.z))

        if math.fmod(i, 2) == 0 then
            -- print("Right Grid")
            gridPosition = gridPosition + -leftVector * 3
        else
            -- print("Left Grid")
            gridPosition = gridPosition + leftVector * 3
        end

        table.insert(gridCheckpoints, CreateGridCheckpoint(gridPosition, i))
    end

    return gridPositions
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

    SetEntityCoords(entityToMove, position.x, position.y, position.z + 2, false, false, false, true)
    SetEntityHeading(entityToMove, heading)
end

local function getCheckpointColor(blipColor)
    if 0 == blipColor then
        return white
    elseif 1 == blipColor then
        return red
    elseif 2 == blipColor then
        return green
    elseif 38 == blipColor then
        return blue
    elseif 5 == blipColor then
        return yellow
    elseif 83 == blipColor then
        return purple
    else
        return yellow
    end
end

local function makeCheckpoint(checkpointType, coord, nextCoord, color, alpha, num)
    local zCoord = coord.z
    if 42 == checkpointType or 45 == checkpointType then
        zCoord = zCoord - coord.r / 2.0
    else
        zCoord = zCoord + coord.r / 2.0
    end
    local checkpoint = CreateCheckpoint(checkpointType, coord.x, coord.y, zCoord, nextCoord.x, nextCoord.y, nextCoord.z,
    coord.r * 2.0, color.r, color.g, color.b, alpha, num)
    SetCheckpointCylinderHeight(checkpoint, 10.0, 10.0, coord.r * 2.0)
    return checkpoint
end

--Load waypoints
local function setStartToFinishCheckpoints()
    for i = 1, #waypoints do
        local color = getCheckpointColor(waypoints[i].color)
        local checkpointType = 38 == waypoints[i].sprite and finishCheckpoint or midCheckpoint
        waypoints[i].checkpoint = makeCheckpoint(checkpointType, waypoints[i].coord, waypoints[i].coord, color, 127,
        i - 1)
    end
end

local function deleteWaypointBlips()
    for i = 1, #waypoints do
        RemoveBlip(waypoints[i].blip)
    end
end

local function setBlipProperties(index)
    SetBlipSprite(waypoints[index].blip, waypoints[index].sprite)
    SetBlipColour(waypoints[index].blip, waypoints[index].color)
    ShowNumberOnBlip(waypoints[index].blip, waypoints[index].number)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(waypoints[index].name)
    EndTextCommandSetBlipName(waypoints[index].blip)
end

local function setStartToFinishBlips()
    if true == startIsFinish then
        waypoints[1].sprite = startFinishSprite
        waypoints[1].color = startFinishBlipColor
        waypoints[1].number = -1
        waypoints[1].name = "Start/Finish"

        if #waypoints > 1 then
            waypoints[#waypoints].sprite = midSprite
            waypoints[#waypoints].color = midBlipColor
            waypoints[#waypoints].number = #waypoints - 1
            waypoints[#waypoints].name = "Waypoint"
        end
    else -- #waypoints should be > 1
        waypoints[1].sprite = startSprite
        waypoints[1].color = startBlipColor
        waypoints[1].number = -1
        waypoints[1].name = "Start"

        waypoints[#waypoints].sprite = finishSprite
        waypoints[#waypoints].color = finishBlipColor
        waypoints[#waypoints].number = -1
        waypoints[#waypoints].name = "Finish"
    end

    for i = 2, #waypoints - 1 do
        waypoints[i].sprite = midSprite
        waypoints[i].color = midBlipColor
        waypoints[i].number = i - 1
        waypoints[i].name = "Waypoint"
    end

    for i = 1, #waypoints do
        setBlipProperties(i)
    end
end

local function loadWaypointBlips(waypointCoords)
    deleteWaypointBlips()
    waypoints = {}

    for i = 1, #waypointCoords - 1 do
        local blip = AddBlipForCoord(waypointCoords[i].x, waypointCoords[i].y, waypointCoords[i].z)
        waypoints[i] = { coord = waypointCoords[i], checkpoint = nil, blip = blip, sprite = -1, color = -1, number = -1,
            name = nil }
    end

    startIsFinish =
        waypointCoords[1].x == waypointCoords[#waypointCoords].x and
        waypointCoords[1].y == waypointCoords[#waypointCoords].y and
        waypointCoords[1].z == waypointCoords[#waypointCoords].z

    if false == startIsFinish then
        local blip = AddBlipForCoord(waypointCoords[#waypointCoords].x, waypointCoords[#waypointCoords].y,
        waypointCoords[#waypointCoords].z)
        waypoints[#waypointCoords] = { coord = waypointCoords[#waypointCoords], checkpoint = nil, blip = blip,
            sprite = -1, color = -1, number = -1, name = nil }
    end

    setStartToFinishBlips()

    SetBlipRoute(waypoints[1].blip, true)
    SetBlipRouteColour(waypoints[1].blip, blipRouteColor)
end

local function restoreBlips()
    for i = 1, #waypoints do
        SetBlipDisplay(waypoints[i].blip, 2)
    end
end

local function removeRegistrationPoint(rIndex)
    RemoveBlip(starts[rIndex].blip)             -- delete registration blip
    DeleteCheckpoint(starts[rIndex].checkpoint) -- delete registration checkpoint
    DeleteCheckpoint(gridCheckpoint)
    starts[rIndex] = nil
end

local function drawMsg(x, y, msg, scale, justify)
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

local function drawRect(x, y, w, h, r, g, b, a)
    DrawRect(x + w / 2.0, y + h / 2.0, w, h, r, g, b, a)
end


local function waypointsToCoords()
    local waypointCoords = {}
    for i = 1, #waypoints do
        waypointCoords[i] = waypoints[i].coord
    end
    if true == startIsFinish then
        waypointCoords[#waypointCoords + 1] = waypointCoords[1]
    end
    return waypointCoords
end

local function waypointsToCoordsRev()
    local waypointCoords = {}
    if true == startIsFinish then
        waypointCoords[1] = waypoints[1].coord
    end
    for i = #waypoints, 1, -1 do
        waypointCoords[#waypointCoords + 1] = waypoints[i].coord
    end
    return waypointCoords
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

local function vehicleInList(vehicle, list)
    for _, vehName in pairs(list) do
        if GetEntityModel(vehicle) == GetHashKey(vehName) then
            return true
        end
    end
    return false
end

local function finishRace(time)
    PlaySoundFrontend(-1, "CHECKPOINT_UNDER_THE_BRIDGE", "HUD_MINI_GAME_SOUNDSET", true)
    if wantedMode == true then
        wantedMode = false
        SetMaxWantedLevel(0)
        SetPlayerWantedLevel(PlayerId(), 0, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
    end
    TriggerServerEvent("races:finish", raceIndex, PedToNet(PlayerPedId()), numWaypointsPassed, time, bestLapTime,
    bestLapVehicleName, nil)
    SetLeaderboardLower(true)
    ResetReady(PedToNet(PlayerPedId()))
    restoreBlips()
    SetBlipRoute(waypoints[1].blip, true)
    SetBlipRouteColour(waypoints[1].blip, blipRouteColor)
    if originalVehicleHash ~= nil then
        local vehicle = switchVehicle(PlayerPedId(), originalVehicleHash)
        if vehicle ~= nil then
            SetVehicleColours(vehicle, colorPri, colorSec)
            SetEntityAsNoLongerNeeded(vehicle)
        end
    end
    raceState = STATE_IDLE
end

local function editWaypoints(coord, heading)
    print("Editing waypoints")
    local selectedIndex = 0
    local minDist = maxRadius
    sendMessage(string.format("Heading: %.2f", heading))
    for index, waypoint in ipairs(waypoints) do
        local dist = #(coord - vector3(waypoint.coord.x, waypoint.coord.y, waypoint.coord.z))
        if dist < waypoint.coord.r and dist < minDist then
            minDist = dist
            selectedIndex = index
        end
    end

    if (#waypoints > 0) then
        GenerateStartingGrid(waypoints[1].coord, 8)
    end

    if 0 == selectedIndex then      -- no existing waypoint selected
        print("No existing waypoints selected")
        if 0 == selectedIndex0 then -- no previous selected waypoints exist, add new waypoint
            local blip = AddBlipForCoord(coord.x, coord.y, coord.z)

            waypoints[#waypoints + 1] = {
                coord = { x = coord.x, y = coord.y, z = coord.z, r = defaultRadius, heading = heading },
                checkpoint = nil, blip = blip, sprite = -1, color = -1, number = -1, name = nil }

            startIsFinish = 1 == #waypoints
            setStartToFinishBlips()
            deleteWaypointCheckpoints()
            setStartToFinishCheckpoints()
        else                            -- first selected waypoint exists
            if 0 == selectedIndex1 then -- second selected waypoint does not exist, move first selected waypoint to new location
                local selectedWaypoint0 = waypoints[selectedIndex0]
                selectedWaypoint0.coord = { x = coord.x, y = coord.y, z = coord.z, r = selectedWaypoint0.coord.r,
                    heading = heading }

                SetBlipCoords(selectedWaypoint0.blip, coord.x, coord.y, coord.z)

                DeleteCheckpoint(selectedWaypoint0.checkpoint)
                local color = getCheckpointColor(selectedBlipColor)
                local checkpointType = 38 == selectedWaypoint0.sprite and finishCheckpoint or midCheckpoint
                selectedWaypoint0.checkpoint = makeCheckpoint(checkpointType, selectedWaypoint0.coord, coord, color, 127,
                selectedIndex0 - 1)
                GenerateStartingGrid(waypoints[1].coord, 8)
            else -- second selected waypoint exists, add waypoint between first and second selected waypoints
                for i = #waypoints, selectedIndex1, -1 do
                    waypoints[i + 1] = waypoints[i]
                end

                local blip = AddBlipForCoord(coord.x, coord.y, coord.z)

                waypoints[selectedIndex1] = {
                    coord = { x = coord.x, y = coord.y, z = coord.z, r = defaultRadius, heading = heading },
                    checkpoint = nil, blip = blip, sprite = -1, color = -1, number = -1, name = nil }

                setStartToFinishBlips()
                deleteWaypointCheckpoints()
                setStartToFinishCheckpoints()

                selectedIndex0 = 0
                selectedIndex1 = 0
            end
        end

        savedTrackName = nil

        SetBlipRoute(waypoints[1].blip, true)
        SetBlipRouteColour(waypoints[1].blip, blipRouteColor)
    else -- existing waypoint selected
        print("Existing waypoint selected")
        local selectedWaypoint = waypoints[selectedIndex]
        selectedWaypoint.coord.heading = heading
        if 0 == selectedIndex0 then -- no previous selected waypoint exists, show that waypoint is selected
            SetBlipColour(selectedWaypoint.blip, selectedBlipColor)
            local color = getCheckpointColor(selectedBlipColor)
            SetCheckpointRgba(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)
            SetCheckpointRgba2(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)

            selectedIndex0 = selectedIndex
        else                                        -- first selected waypoint exists
            if selectedIndex == selectedIndex0 then -- selected waypoint and first selected waypoint are the same, unselect
                SetBlipColour(selectedWaypoint.blip, selectedWaypoint.color)
                local color = getCheckpointColor(selectedWaypoint.color)
                SetCheckpointRgba(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)
                SetCheckpointRgba2(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)

                if selectedIndex1 ~= 0 then
                    selectedIndex0 = selectedIndex1
                    selectedIndex1 = 0
                else
                    selectedIndex0 = 0
                end
            elseif selectedIndex == selectedIndex1 then -- selected waypoint and second selected waypoint are the same
                SetBlipColour(selectedWaypoint.blip, selectedWaypoint.color)
                local color = getCheckpointColor(selectedWaypoint.color)
                SetCheckpointRgba(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)
                SetCheckpointRgba2(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)

                selectedIndex1 = 0
            else                            -- selected waypoint and first and second selected waypoints are different
                if 0 == selectedIndex1 then -- second selected waypoint does not exist
                    local splitCombine = false
                    local checkpointType = finishCheckpoint
                    local waypointNum = 0
                    if true == startIsFinish then
                        if #waypoints == selectedIndex and 1 == selectedIndex0 then -- split start/finish waypoint
                            splitCombine = true

                            startIsFinish = false

                            waypoints[1].sprite = startSprite
                            waypoints[1].color = startBlipColor
                            waypoints[1].number = -1
                            waypoints[1].name = "Start"

                            waypoints[#waypoints].sprite = finishSprite
                            waypoints[#waypoints].color = finishBlipColor
                            waypoints[#waypoints].number = -1
                            waypoints[#waypoints].name = "Finish"
                        end
                    else
                        if 1 == selectedIndex and #waypoints == selectedIndex0 then -- combine start and finish waypoints
                            splitCombine = true

                            startIsFinish = true

                            waypoints[1].sprite = startFinishSprite
                            waypoints[1].color = startFinishBlipColor
                            waypoints[1].number = -1
                            waypoints[1].name = "Start/Finish"

                            waypoints[#waypoints].sprite = midSprite
                            waypoints[#waypoints].color = midBlipColor
                            waypoints[#waypoints].number = #waypoints - 1
                            waypoints[#waypoints].name = "Waypoint"

                            checkpointType = midCheckpoint
                            waypointNum = #waypoints - 1
                        end
                    end
                    if true == splitCombine then
                        setBlipProperties(1)
                        setBlipProperties(#waypoints)

                        local color = getCheckpointColor(waypoints[1].color)
                        SetCheckpointRgba(waypoints[1].checkpoint, color.r, color.g, color.b, 127)
                        SetCheckpointRgba2(waypoints[1].checkpoint, color.r, color.g, color.b, 127)

                        DeleteCheckpoint(waypoints[#waypoints].checkpoint)
                        color = getCheckpointColor(waypoints[#waypoints].color)
                        waypoints[#waypoints].checkpoint = makeCheckpoint(checkpointType, waypoints[#waypoints].coord,
                        waypoints[#waypoints].coord, color, 127, waypointNum)

                        selectedIndex0 = 0
                        savedTrackName = nil
                    else
                        if selectedIndex == selectedIndex0 + 1 then
                            SetBlipColour(selectedWaypoint.blip, selectedBlipColor)
                            color = getCheckpointColor(selectedBlipColor)
                            SetCheckpointRgba(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)
                            SetCheckpointRgba2(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)

                            selectedIndex1 = selectedIndex
                        elseif selectedIndex == selectedIndex0 - 1 then
                            SetBlipColour(selectedWaypoint.blip, selectedBlipColor)
                            color = getCheckpointColor(selectedBlipColor)
                            SetCheckpointRgba(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)
                            SetCheckpointRgba2(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)

                            selectedIndex1 = selectedIndex0
                            selectedIndex0 = selectedIndex
                        else
                            SetBlipColour(selectedWaypoint.blip, selectedBlipColor)
                            color = getCheckpointColor(selectedBlipColor)
                            SetCheckpointRgba(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)
                            SetCheckpointRgba2(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)

                            local selectedWaypoint0 = waypoints[selectedIndex0]
                            SetBlipColour(selectedWaypoint0.blip, selectedWaypoint0.color)
                            color = getCheckpointColor(selectedWaypoint0.color)
                            SetCheckpointRgba(selectedWaypoint0.checkpoint, color.r, color.g, color.b, 127)
                            SetCheckpointRgba2(selectedWaypoint0.checkpoint, color.r, color.g, color.b, 127)

                            selectedIndex0 = selectedIndex
                        end
                    end
                else -- second selected waypoint exists
                    if selectedIndex == selectedIndex1 + 1 then
                        SetBlipColour(selectedWaypoint.blip, selectedBlipColor)
                        color = getCheckpointColor(selectedBlipColor)
                        SetCheckpointRgba(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)
                        SetCheckpointRgba2(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)

                        local selectedWaypoint0 = waypoints[selectedIndex0]
                        SetBlipColour(selectedWaypoint0.blip, selectedWaypoint0.color)
                        color = getCheckpointColor(selectedWaypoint0.color)
                        SetCheckpointRgba(selectedWaypoint0.checkpoint, color.r, color.g, color.b, 127)
                        SetCheckpointRgba2(selectedWaypoint0.checkpoint, color.r, color.g, color.b, 127)

                        selectedIndex0 = selectedIndex1
                        selectedIndex1 = selectedIndex
                    elseif selectedIndex == selectedIndex0 - 1 then
                        SetBlipColour(selectedWaypoint.blip, selectedBlipColor)
                        color = getCheckpointColor(selectedBlipColor)
                        SetCheckpointRgba(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)
                        SetCheckpointRgba2(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)

                        local selectedWaypoint1 = waypoints[selectedIndex1]
                        SetBlipColour(selectedWaypoint1.blip, selectedWaypoint1.color)
                        color = getCheckpointColor(selectedWaypoint1.color)
                        SetCheckpointRgba(selectedWaypoint1.checkpoint, color.r, color.g, color.b, 127)
                        SetCheckpointRgba2(selectedWaypoint1.checkpoint, color.r, color.g, color.b, 127)

                        selectedIndex1 = selectedIndex0
                        selectedIndex0 = selectedIndex
                    else
                        SetBlipColour(selectedWaypoint.blip, selectedBlipColor)
                        color = getCheckpointColor(selectedBlipColor)
                        SetCheckpointRgba(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)
                        SetCheckpointRgba2(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)

                        local selectedWaypoint0 = waypoints[selectedIndex0]
                        SetBlipColour(selectedWaypoint0.blip, selectedWaypoint0.color)
                        color = getCheckpointColor(selectedWaypoint0.color)
                        SetCheckpointRgba(selectedWaypoint0.checkpoint, color.r, color.g, color.b, 127)
                        SetCheckpointRgba2(selectedWaypoint0.checkpoint, color.r, color.g, color.b, 127)

                        local selectedWaypoint1 = waypoints[selectedIndex1]
                        SetBlipColour(selectedWaypoint1.blip, selectedWaypoint1.color)
                        color = getCheckpointColor(selectedWaypoint1.color)
                        SetCheckpointRgba(selectedWaypoint1.checkpoint, color.r, color.g, color.b, 127)
                        SetCheckpointRgba2(selectedWaypoint1.checkpoint, color.r, color.g, color.b, 127)

                        selectedIndex0 = selectedIndex
                        selectedIndex1 = 0
                    end
                end
            end
        end
    end
end

local function removeRacerBlipGT()
    for _, racer in pairs(racerBlipGT) do
        RemoveBlip(racer.blip)
        RemoveMpGamerTag(racer.gamerTag)
    end
    racerBlipGT = {}
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

local function request(role)
    if role ~= nil then
        local roleBit = 0
        if "edit" == role then
            roleBit = ROLE_EDIT
        elseif "register" == role then
            roleBit = ROLE_REGISTER
        elseif "spawn" == role then
            roleBit = ROLE_SPAWN
        end
        if roleBit ~= 0 then
            TriggerServerEvent("races:request", roleBit)
        else
            sendMessage("Cannot make request.  Invalid role.\n")
        end
    else
        sendMessage("Cannot make request.  Role required.\n")
    end
end

local function edit()
    if 0 == roleBits & ROLE_EDIT then
        sendMessage("Permission required.\n")
        return
    end
    if STATE_IDLE == raceState then
        raceState = STATE_EDITING
        SetWaypointOff()
        if(#waypoints > 0) then
            GenerateStartingGrid(waypoints[1].coord, 8)
        end
        setStartToFinishCheckpoints()
        sendMessage("Editing started.\n")
    elseif STATE_EDITING == raceState then
        raceState = STATE_IDLE
        highlightedCheckpoint = 0
        if selectedIndex0 ~= 0 then
            SetBlipColour(waypoints[selectedIndex0].blip, waypoints[selectedIndex0].color)
            selectedIndex0 = 0
        end
        if selectedIndex1 ~= 0 then
            SetBlipColour(waypoints[selectedIndex1].blip, waypoints[selectedIndex1].color)
            selectedIndex1 = 0
        end
        deleteWaypointCheckpoints()
        DeleteGridCheckPoints()
        sendMessage("Editing stopped.\n")
    else
        sendMessage("Cannot edit waypoints.  Leave race first.\n")
    end
end

local function clear()
    if STATE_IDLE == raceState then
        deleteWaypointBlips()
        waypoints = {}
        startIsFinish = false
        savedTrackName = nil
        sendMessage("Waypoints cleared.\n")
    elseif STATE_EDITING == raceState then
        highlightedCheckpoint = 0
        selectedIndex0 = 0
        selectedIndex1 = 0
        deleteWaypointCheckpoints()
        deleteWaypointBlips()
        DeleteGridCheckPoints()
        waypoints = {}
        startIsFinish = false
        savedTrackName = nil
        sendMessage("Waypoints cleared.\n")
    else
        sendMessage("Cannot clear waypoints.  Leave race first.\n")
    end
end

local function reverse()
    if 0 == roleBits & ROLE_EDIT then
        sendMessage("Permission required.\n")
        return
    end
    if #waypoints > 1 then
        if STATE_IDLE == raceState then
            savedTrackName = nil
            loadWaypointBlips(waypointsToCoordsRev())
            sendMessage("Waypoints reversed.\n")
        elseif STATE_EDITING == raceState then
            savedTrackName = nil
            highlightedCheckpoint = 0
            selectedIndex0 = 0
            selectedIndex1 = 0
            deleteWaypointCheckpoints()
            GenerateStartingGrid(waypoints[1].coord, 8)
            loadWaypointBlips(waypointsToCoordsRev())
            setStartToFinishCheckpoints()
            sendMessage("Waypoints reversed.\n")
        else
            sendMessage("Cannot reverse waypoints.  Leave race first.\n")
        end
    else
        sendMessage("Cannot reverse waypoints.  Track needs to have at least 2 waypoints.\n")
    end
end

local function loadTrack(access, trackName)
    if 0 == roleBits & (ROLE_EDIT | ROLE_REGISTER) then
        sendMessage("Permission required.\n")
        return
    end
    if "pvt" == access or "pub" == access then
        if trackName ~= nil then
            if STATE_IDLE == raceState or STATE_EDITING == raceState then
                TriggerServerEvent("races:load", "pub" == access, trackName)
            else
                sendMessage("Cannot load.  Leave race first.\n")
            end
        else
            sendMessage("Cannot load.  Name required.\n")
        end
    else
        sendMessage("Cannot load.  Invalid access type.\n")
    end
end

local function saveTrack(access, trackName)
    if 0 == roleBits & ROLE_EDIT then
        sendMessage("Permission required.\n")
        return
    end
    if "pvt" == access or "pub" == access then
        if trackName ~= nil then
            if #waypoints > 1 then
                TriggerServerEvent("races:save", "pub" == access, trackName, waypointsToCoords())
            else
                sendMessage("Cannot save.  Track needs to have at least 2 waypoints.\n")
            end
        else
            sendMessage("Cannot save.  Name required.\n")
        end
    else
        sendMessage("Cannot save.  Invalid access type.\n")
    end
end

local function overwriteTrack(access, trackName)
    if 0 == roleBits & ROLE_EDIT then
        sendMessage("Permission required.\n")
        return
    end
    if "pvt" == access or "pub" == access then
        if trackName ~= nil then
            if #waypoints > 1 then
                TriggerServerEvent("races:overwrite", "pub" == access, trackName, waypointsToCoords())
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

local function deleteTrack(access, trackName)
    if 0 == roleBits & ROLE_EDIT then
        sendMessage("Permission required.\n")
        return
    end
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
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end

    tier = (nil == tier or "." == tier) and defaultTier or string.lower(tier)
    specialClass = (nil == specialClass or "." == specialClass) and defaultSpecialClass or specialClass

    laps = (nil == laps or "." == laps) and defaultLaps or math.tointeger(tonumber(laps))
    if laps ~= nil and laps > 0 then
        timeout = (nil == timeout or "." == timeout) and defaultTimeout or math.tointeger(tonumber(timeout))
        if timeout ~= nil and timeout >= 0 then
            if STATE_IDLE == raceState then
                if #waypoints > 1 then
                    if laps == 1 or (laps > 1 and true == startIsFinish) then
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
                        elseif rtype ~= nil then
                            sendMessage("Cannot register.  Unknown race type.\n")
                            return
                        end
                        local rdata = {
                            rtype = rtype,
                            restrict = restrict,
                            vclass = vclass,
                            svehicle = svehicle,
                            vehicleList = vehList,
                            specialClass = specialClass
                        }
                        TriggerServerEvent("races:register", waypointsToCoords(), isPublicTrack, savedTrackName,
                        tier, laps, timeout, rdata)
                    else
                        sendMessage(
                        "For multi-lap races, start and finish waypoints need to be the same: While editing waypoints, select finish waypoint first, then select start waypoint.  To separate start/finish waypoint, add a new waypoint or select start/finish waypoint first, then select highest numbered waypoint.\n")
                    end
                else
                    sendMessage("Cannot register.  Track needs to have at least 2 waypoints.\n")
                end
            elseif STATE_EDITING == raceState then
                sendMessage("Cannot register.  Stop editing first.\n")
            else
                sendMessage("Cannot register.  Leave race first.\n")
            end
        else
            sendMessage("Invalid DNF timeout.\n")
        end
    else
        sendMessage("Invalid number of laps.\n")
    end
end

local function unregister()
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
    TriggerServerEvent("races:unregister")
end

local function setupGrid()
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end

    TriggerServerEvent("races:grid")
end

local function autojoin()
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end

    TriggerServerEvent("races:autojoin")
end

local function startRace(delay, override)

    if override == nil then
        override = false
    end

    print(override)
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
    delay = math.tointeger(tonumber(delay)) or defaultDelay
    if delay ~= nil and delay >= 5 then
        TriggerServerEvent("races:start", delay, override)
    else
        sendMessage("Cannot start.  Invalid delay.\n")
    end
end

local function addVeh(vehicle)
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
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
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
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
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
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
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
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
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
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
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
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
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
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
    if 0 == roleBits & ROLE_EDIT then
        sendMessage("Permission required.\n")
        return
    end
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
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
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
    if 0 == roleBits & ROLE_REGISTER then
        sendMessage("Permission required.\n")
        return
    end
    if "pvt" == access or "pub" == access then
        TriggerServerEvent("races:listLsts", "pub" == access)
    else
        sendMessage("Cannot list vehicle lists.  Invalid access type.\n")
    end
end

local function leave()
    local player = PlayerPedId()
    if STATE_JOINING == raceState then
        raceState = STATE_IDLE
        ResetReady(PedToNet(player))
        ClearLeaderboard()
        TriggerServerEvent("races:leave", raceIndex, PedToNet(player), nil)
        removeRacerBlipGT()
        DeleteCheckpoint(gridCheckpoint)
        sendMessage("Left race.\n")
    elseif STATE_RACING == raceState then
        if IsPedInAnyVehicle(player, false) == 1 then
            FreezeEntityPosition(GetVehiclePedIsIn(player, false), false)
        end
        RenderScriptCams(false, false, 0, true, true)
        DeleteCheckpoint(raceCheckpoint)
        finishRace(-1)
        removeRacerBlipGT()
        ResetReady(PedToNet(player))
        ClearLeaderboard()
        TriggerServerEvent("races:removeFromLeaderboard", raceIndex, PedToNet(player))
        DeleteCheckpoint(gridCheckpoint)
        sendMessage("Left race.\n")
    else
        sendMessage("Cannot leave.  Not joined to any race.\n")
    end
end

local function endrace()
    TriggerServerEvent("races:endrace")
end

local function rivals()
    if STATE_JOINING == raceState or STATE_RACING == raceState then
        TriggerServerEvent("races:rivals", raceIndex)
    else
        sendMessage("Cannot list competitors.  Not joined to any race.\n")
    end
end

local function repairVehicle(vehicle)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleFixed(vehicle)
end

local function respawn()
    if STATE_RACING == raceState then
        ClearRespawnIndicator()
        ghosting:StartGhosting(configData['ghostingTime'])
        local passengers = {}
        local player = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(player, true)

        local coord = startCoord
        if true == startIsFinish then
            if currentWaypoint > 0 then
                coord = waypoints[currentWaypoint].coord
            end
        else
            if currentWaypoint > 1 then
                coord = waypoints[currentWaypoint - 1].coord
            end
        end

        print(vehicle)
        print(currentVehicleHash)

        --Spawn vehicle is there is none
        if vehicle == 0 and currentVehicleHash ~= nil then
            print("No vehicle found")
            RequestModel(currentVehicleHash)
            while HasModelLoaded(currentVehicleHash) == false do
                Citizen.Wait(0)
            end
            vehicle = putPedInVehicle(player, currentVehicleHash, coord)
            SetEntityAsNoLongerNeeded(vehicle)
            SetEntityHeading(vehicle, coord.heading)
            repairVehicle(vehicle)
            for _, passenger in pairs(passengers) do
                SetPedIntoVehicle(passenger.ped, vehicle, passenger.seat)
            end
        elseif currentVehicleHash == nil then
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
    if 0 == roleBits & ROLE_SPAWN then
        sendMessage("Permission required.\n")
        return
    end
    vehicleHash = vehicleHash or defaultVehicle
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

    local openCarTierUI = tier ~= "none" or specialClass ~= "none"

    print("Sending message to car tier")
    SendNUIMessage({
        type = "cartierui",
        action = "sendCarData",
        tier = tier,
        specialClass = specialClass,
        openui = openCarTierUI
    })
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
        current_checkpoint = startIsFinish == true and currentWaypoint or currentWaypoint - 1
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

function SendBestLapTime(minutes, seconds)
    TriggerServerEvent("races:update_best_lap_time", minutes, seconds)
end

RegisterNetEvent("races:update_best_lap_time")
AddEventHandler("races:update_best_lap_time", function(source, minutes, seconds)
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

RegisterNUICallback("request", function(data)
    request(data.role)
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
    saveTrack(data.access, trackName)
end)

RegisterNUICallback("overwrite", function(data)
    overwriteTrack(data.access, data.trackName)
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
    elseif "wanted" == rtype then
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

RegisterNUICallback("rivals", function()
    rivals()
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
        TriggerServerEvent("races:resetupgrade", 11, savedTrackName)
    end

    if bUpgrade ~= -1 then
        SetVehicleMod(vehicle, 12, -1) --Brakes upgrade
        TriggerServerEvent("races:resetupgrade", 12, savedTrackName)
    end

    if gUpgrade ~= -1 then
        SetVehicleMod(vehicle, 13, -1) --Gearbox upgrade
        TriggerServerEvent("races:resetupgrade", 13, savedTrackName)
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
        msg = msg .. "/races request [role] - request permission to have [role] = {edit, register, spawn} role\n"
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
        msg = msg .. "/races rivals - list competitors in a race that you joined\n"
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
    elseif "request" == args[1] then
        request(args[2])
    elseif "edit" == args[1] then
        edit()
    elseif "clear" == args[1] then
        clear()
    elseif "reverse" == args[1] then
        reverse()
    elseif "load" == args[1] then
        loadTrack(args[2], args[3])
    elseif "save" == args[1] then
        saveTrack(args[2], args[3])
    elseif "overwrite" == args[1] then
        overwriteTrack(args[2], args[3])
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
    elseif "rivals" == args[1] then
        rivals()
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

RegisterNetEvent("races:roles")
AddEventHandler("races:roles", function(roles)
    if 0 == roles & ROLE_EDIT and STATE_EDITING == raceState then
        roleBits = roleBits | ROLE_EDIT
        edit()
    end
    roleBits = roles
end)

RegisterNetEvent("races:message")
AddEventHandler("races:message", function(msg)
    sendMessage(msg)
end)

RegisterNetEvent("races:load")
AddEventHandler("races:load", function(isPublic, trackName, waypointCoords)
    if isPublic ~= nil and trackName ~= nil and waypointCoords ~= nil then
        if STATE_IDLE == raceState then
            isPublicTrack = isPublic
            savedTrackName = trackName
            loadWaypointBlips(waypointCoords)
            sendMessage("Loaded " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
        elseif STATE_EDITING == raceState then
            isPublicTrack = isPublic
            savedTrackName = trackName
            highlightedCheckpoint = 0
            selectedIndex0 = 0
            selectedIndex1 = 0
            deleteWaypointCheckpoints()
            loadWaypointBlips(waypointCoords)
            setStartToFinishCheckpoints()
            sendMessage("Loaded " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
        else
            notifyPlayer("Ignoring load event.  Currently joined to race.\n")
        end
    else
        notifyPlayer("Ignoring load event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:save")
AddEventHandler("races:save", function(isPublic, trackName)
    if isPublic ~= nil and trackName ~= nil then
        isPublicTrack = isPublic
        savedTrackName = trackName
        sendMessage("Saved " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
    else
        notifyPlayer("Ignoring save event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:overwrite")
AddEventHandler("races:overwrite", function(isPublic, trackName)
    if isPublic ~= nil and trackName ~= nil then
        isPublicTrack = isPublic
        savedTrackName = trackName
        sendMessage("Overwrote " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
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
function(rIndex, coord, isPublic, trackName, owner, tier, laps, timeout, rdata)
    if rIndex ~= nil and coord ~= nil and isPublic ~= nil and owner ~= nil and tier ~= nil and laps ~= nil and timeout ~= nil and rdata ~= nil then
        local blip = AddBlipForCoord(coord.x, coord.y, coord.z) -- registration blip
        SetBlipSprite(blip, registerSprite)
        SetBlipColour(blip, registerBlipColor)
        BeginTextCommandSetBlipName("STRING")
        local msg = owner .. " (" .. "tier" .. tier
        msg = msg .. " Special Class" .. rdata.specialClass
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
        elseif "wanted" == rdata.rtype then
            msg = msg .. " : wanted race mode"
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
            tier = tier,
            specialClass = rdata.specialClass,
            laps = laps,
            timeout = timeout,
            rtype = rdata.rtype,
            restrict = rdata.restrict,
            vclass = rdata.vclass,
            svehicle = rdata.svehicle,
            vehicleList = rdata.vehicleList,
            blip = blip,
            checkpoint = checkpoint,
            registerPosition = coord
        }
    else
        notifyPlayer("Ignoring register event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:unregister")
AddEventHandler("races:unregister", function(rIndex)
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
    else
        notifyPlayer("Ignoring unregister event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:start")
AddEventHandler("races:start", function(rIndex, delay)
    if rIndex ~= nil and delay ~= nil then
        if delay >= 5 then
            local currentTime = GetGameTimer()

            if rIndex == raceIndex then
                if STATE_JOINING == raceState then

                    UpdateVehicleName()
                    SendVehicleName()
                    raceStart = currentTime
                    raceDelay = delay
                    beginDNFTimeout = false
                    timeoutStart = -1
                    started = false
                    position = -1
                    numWaypointsPassed = 0
                    currentLap = 1
                    bestLapTime = -1
                    bestLapVehicleName = currentVehicleName
                    countdown = 5
                    drawLights = false
                    numRacers = -1
                    results = {}
                    startCoord = GetEntityCoords(PlayerPedId())
                    camTransStarted = false

                    if startVehicle ~= nil then
                        local vehicle = switchVehicle(PlayerPedId(), startVehicle)
                        if vehicle ~= nil then
                            SetEntityAsNoLongerNeeded(vehicle)
                        end
                    end

                    numVisible = maxNumVisible < #waypoints and maxNumVisible or (#waypoints - 1)
                    for i = numVisible + 1, #waypoints do
                        SetBlipDisplay(waypoints[i].blip, 0)
                    end

                    currentWaypoint = true == startIsFinish and 0 or 1

                    waypointCoord = waypoints[1].coord
                    raceCheckpoint = makeCheckpoint(arrow3Checkpoint, waypointCoord, waypoints[2].coord, yellow, 127, 0)

                    SetBlipRoute(waypointCoord, true)
                    SetBlipRouteColour(waypointCoord, blipRouteColor)

                    raceState = STATE_RACING

                    local player = PlayerPedId()
                    local vehicle = GetVehiclePedIsIn(player, true)

                    repairVehicle(vehicle)
                    resetupgrades(vehicle)
                    DeleteGridCheckPoints()
                    print(sologridCheckpoint)
                    ClearReady();
                    notifyPlayer("Vehicle fixed.\n")

                elseif STATE_RACING == raceState then
                    notifyPlayer("Ignoring start event.  Already in a race.\n")
                elseif STATE_EDITING == raceState then
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
AddEventHandler("races:joinnotification", function(playerName, racerDictionary, rIndex, trackName, numReady, numRacing, registrationCoords)
    DeleteCheckpoint(starts[rIndex].checkpoint);
    registrationCoords.r = defaultRadius
    local checkpoint = makeCheckpoint(plainCheckpoint, registrationCoords, registrationCoords, purple, 127, numRacing)
    starts[rIndex].checkpoint = checkpoint
    sendMessage(string.format("%s has joined Race %s", playerName, trackName))
    AddRacersToLeaderboard(racerDictionary, GetPlayerServerId(PlayerId()))
end)

RegisterNetEvent("races:onplayerleave")
AddEventHandler("races:onplayerleave", function()
    ClearReady()
end)

RegisterNetEvent("races:leave")
AddEventHandler("races:leave", function()
    leave()
end)

RegisterNetEvent("races:leavenotification")
AddEventHandler("races:leavenotification", function(message, source, rIndex, numReady, numRacing, registrationCoords)
    print("Leave race notification")
    DeleteCheckpoint(starts[rIndex].checkpoint);
    registrationCoords.r = defaultRadius
    local checkpoint = makeCheckpoint(plainCheckpoint, registrationCoords, registrationCoords, purple, 127, numRacing)
    starts[rIndex].checkpoint = checkpoint
    print(string.format("NumberRacing: %i", numRacing))
    RemoveRacerFromLeaderboard(source)
    sendMessage(message)
end)

RegisterNetEvent("races:removeFromLeaderboard")
AddEventHandler("races:removeFromLeaderboard", function(source)
    RemoveRacerFromLeaderboard(source)
end)

RegisterNetEvent("races:join")
AddEventHandler("races:join", function(rIndex, tier, specialClass, waypointCoords)
    if rIndex ~= nil and waypointCoords ~= nil then
        if starts[rIndex] ~= nil then
            if STATE_IDLE == raceState then
                SetJoinMessage('')
                SendToRaceTier(tier, specialClass)
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

                local raceData = {
                    laps = starts[rIndex].laps,
                    totalCheckpoints = startIsFinish == true and #waypoints or #waypoints - 1
                }
                SendRaceData(raceData)
                SetRaceLeaderboard(true)

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
                    wantedMode = true
                end
                msg = msg .. ".\n"
                notifyPlayer(msg)
            elseif STATE_EDITING == raceState then
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
AddEventHandler("races:finish", function(rIndex, playerName, raceFinishTime, raceBestLapTime, raceVehicleName)
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
RegisterNetEvent("races:results")
AddEventHandler("races:results", function(rIndex, raceResults)
    if rIndex ~= nil and raceResults ~= nil then
        if rIndex == raceIndex then
            results = raceResults
            viewResults(true)
        end
    else
        notifyPlayer("Ignoring results event.  Invalid parameters.\n")
    end
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

RegisterNetEvent("races:racerPositions")
AddEventHandler("races:racerPositions", function(racePositions)
    SendNUIMessage({
        type = "leaderboard",
        action = "update_positions",
        racePositions = racePositions
    })
end)

RegisterNetEvent("races:addRacer")
AddEventHandler("races:addRacer", function(netID, name)
    if netID ~= nil and name ~= nil then
        if racerBlipGT[netID] ~= nil then
            RemoveBlip(racerBlipGT[netID].blip)
            RemoveMpGamerTag(racerBlipGT[netID].gamerTag)
        end
        local ped = NetToPed(netID)
        if DoesEntityExist(ped) == 1 then
            local blip = AddBlipForEntity(ped)
            SetBlipSprite(blip, racerSprite)
            SetBlipColour(blip, racerBlipColor)
            local gamerTag = CreateFakeMpGamerTag(ped, name, false, false, nil, 0)
            SetMpGamerTagVisibility(gamerTag, 0, true)
            racerBlipGT[netID] = { blip = blip, gamerTag = gamerTag, netID = netID, name = name }
        end
    else
        notifyPlayer("Ignoring addRacer event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:delRacer")
AddEventHandler("races:delRacer", function(netID)
    if netID ~= nil then
        if racerBlipGT[netID] ~= nil then
            DeleteCheckpoint(gridCheckpoint)
            RemoveBlip(racerBlipGT[netID].blip)
            RemoveMpGamerTag(racerBlipGT[netID].gamerTag)
            racerBlipGT[netID] = nil
        end
    else
        notifyPlayer("Ignoring delRacer event.  Invalid parameters.\n")
    end
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
    table.insert(gridCheckpoints, CreateGridCheckpoint(position, gridNumber))
end)

RegisterNetEvent("races:autojoin")
AddEventHandler("races:autojoin", function(raceIndex)

    if raceState ~= STATE_IDLE then
        notifyPlayer("Cannnot join race. already joined.\n")
        return
    end

    removeRacerBlipGT()
    local player = PlayerPedId()

    local registerPosition = starts[raceIndex].registerPosition

    ghosting:StartGhosting(configData['ghostingTime'])
    local startPoint = vector3(registerPosition.x, registerPosition.y, registerPosition.z)
    TeleportPlayer(startPoint, registerPosition.heading)

    TriggerServerEvent("races:join", raceIndex, PedToNet(player), nil)
end)

RegisterNetEvent("races:setupgrid")
AddEventHandler("races:setupgrid", function(position, heading, gridNumber)

    print("Setup Grid called")
    TeleportPlayer(position, heading)

    -- sologridCheckpoint = CreateGridCheckpoint(position, gridNumber)
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

local boost_active = false

--Race extras
Citizen.CreateThread(function()
    while true do
        if STATE_RACING ~= true then
            Citizen.Wait(0)
        end

        boost_active = position == numRacers and numRacers ~= 1

        if(boost_active) then
            SetVehicleCheatPowerIncrease(GetVehiclePedIsIn(GetPlayerPed(-1), false), 1.8)
        else
            SetVehicleCheatPowerIncrease(GetVehiclePedIsIn(GetPlayerPed(-1), false), 1.0)
        end

        Citizen.Wait(0)
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        if STATE_RACING == raceState then
            local player = PlayerPedId()
            local distance = #(GetEntityCoords(player) - vector3(waypointCoord.x, waypointCoord.y, waypointCoord.z))
            TriggerServerEvent("races:report", raceIndex, PedToNet(player), numWaypointsPassed, distance)
        end
    end
end)

function ResetReady(netID)
    ready = false
    TriggerServerEvent("races:readyState", raceIndex, ready, netID)
end

function ClearReady()
    SendNUIMessage({
        type = 'ready',
        action = 'clear_ready'
    })
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

function HandleJoinState()
    --Down
    if IsControlJustReleased(0, 173) then
        ready = not ready
        TriggerServerEvent("races:readyState", raceIndex, ready, PedToNet(PlayerPedId()))
    end
end

function SendVehicleName()
    TriggerServerEvent("races:sendvehiclename", currentVehicleName or 'N/A' )
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


function UpdateVehicleName()
    local player = PlayerPedId()
    if IsPedInAnyVehicle(player, false) == 1 then
        local vehicle = GetVehiclePedIsIn(player, false)
        currentVehicleHash = GetEntityModel(vehicle)
        currentVehicleName = GetLabelText(GetDisplayNameFromVehicleModel(currentVehicleHash))
    else
        currentVehicleName = "On Feet"
    end
end

function HandleWanted()
    if wantedMode == true then
        local player = PlayerId()

        local wantedLevel = math.max(6-position, 0)
        wantedLevel = math.min(wantedLevel, 5)
        local currentWantedLevel =  GetPlayerWantedLevel(player)
        if currentWantedLevel ~= wantedLevel then
            SetMaxWantedLevel(wantedLevel)
            SetPlayerWantedLevel(player, wantedLevel, false)
            SetPlayerWantedLevelNow(player, false)
        end
    end
end

function SendCheckpointTime(waypointsPassed, lapTime)
    TriggerServerEvent("races:sendCheckpointTime", waypointsPassed, lapTime)
end

RegisterNetEvent("races:config")
AddEventHandler("races:config", function(_configData)
    configData = _configData

    ghosting = Ghosting:new(nil, configData['ghosting'])

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

--Update Vehicle Name thread
--TODO: See if you can listen to events when a player enters/exits a vehicle
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if raceState == STATE_RACING or raceState == STATE_JOINING then
            UpdateVehicleName()
            SendVehicleName()
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        local player = PlayerPedId()
        local playerCoord = GetEntityCoords(player)
        local heading = GetEntityHeading(player)

        local currentTime = GetGameTimer()

        -- drawMsg(0.50, 0.46, "Race starting in", 0.7, 0)
        -- drawMsg(0.50, 0.50, ("%05.2f"):format(-currentTime / 1000.0), 0.7, 0)
        -- drawMsg(0.50, 0.54, "seconds", 0.7, 0)

        ghosting:Update()

        if STATE_EDITING == raceState then
            local closestIndex = 0
            local minDist = maxRadius
            for index, waypoint in ipairs(waypoints) do
                local dist = #(playerCoord - vector3(waypoint.coord.x, waypoint.coord.y, waypoint.coord.z))
                if dist < waypoint.coord.r and dist < minDist then
                    minDist = dist
                    closestIndex = index
                end
            end

            if closestIndex ~= 0 then
                if highlightedCheckpoint ~= 0 and closestIndex ~= highlightedCheckpoint then
                    local color = (highlightedCheckpoint == selectedIndex0 or highlightedCheckpoint == selectedIndex1) and
                    getCheckpointColor(selectedBlipColor) or getCheckpointColor(waypoints[highlightedCheckpoint].color)
                    SetCheckpointRgba(waypoints[highlightedCheckpoint].checkpoint, color.r, color.g, color.b, 127)
                end
                local color = (closestIndex == selectedIndex0 or closestIndex == selectedIndex1) and
                getCheckpointColor(selectedBlipColor) or getCheckpointColor(waypoints[closestIndex].color)
                SetCheckpointRgba(waypoints[closestIndex].checkpoint, color.r, color.g, color.b, 255)
                highlightedCheckpoint = closestIndex
                drawMsg(0.50, 0.50, "Press [ENTER] key, [A] button or [CROSS] button to select waypoint", 0.7, 0)
            elseif highlightedCheckpoint ~= 0 then
                local color = (highlightedCheckpoint == selectedIndex0 or highlightedCheckpoint == selectedIndex1) and
                getCheckpointColor(selectedBlipColor) or getCheckpointColor(waypoints[highlightedCheckpoint].color)
                SetCheckpointRgba(waypoints[highlightedCheckpoint].checkpoint, color.r, color.g, color.b, 127)
                highlightedCheckpoint = 0
            end

            --Add waypoints by using waypoint system
            if IsWaypointActive() == 1 then
                SetWaypointOff()
                local coord = GetBlipCoords(GetFirstBlipInfoId(8))
                for height = 1000.0, 0.0, -50.0 do
                    RequestAdditionalCollisionAtCoord(coord.x, coord.y, height)
                    Citizen.Wait(0)
                    local foundZ, groundZ = GetGroundZFor_3dCoord(coord.x, coord.y, height, true)
                    if 1 == foundZ then
                        coord = vector3(coord.x, coord.y, groundZ)
                        editWaypoints(coord, heading)
                        break
                    end
                end
            elseif IsControlJustReleased(0, 215) == 1 then -- enter key or A button or cross button
                editWaypoints(playerCoord, heading)
            elseif selectedIndex0 ~= 0 and 0 == selectedIndex1 then
                local selectedWaypoint0 = waypoints[selectedIndex0]
                if IsControlJustReleased(2, 216) == 1 then -- space key or X button or square button
                    DeleteCheckpoint(selectedWaypoint0.checkpoint)
                    RemoveBlip(selectedWaypoint0.blip)
                    table.remove(waypoints, selectedIndex0)

                    if highlightedCheckpoint == selectedIndex0 then
                        highlightedCheckpoint = 0
                    end
                    selectedIndex0 = 0

                    savedTrackName = nil

                    if #waypoints > 0 then
                        if 1 == #waypoints then
                            startIsFinish = true
                        end
                        setStartToFinishBlips()
                        GenerateStartingGrid(waypoints[1].coord, 8)
                        deleteWaypointCheckpoints()
                        setStartToFinishCheckpoints()
                        SetBlipRoute(waypoints[1].blip, true)
                        SetBlipRouteColour(waypoints[1].blip, blipRouteColor)
                    end
                elseif IsControlJustReleased(0, 187) == 1 and selectedWaypoint0.coord.r > minRadius then -- arrow down or DPAD DOWN
                    selectedWaypoint0.coord.r = selectedWaypoint0.coord.r - 0.5
                    DeleteCheckpoint(selectedWaypoint0.checkpoint)
                    local color = getCheckpointColor(selectedBlipColor)
                    local checkpointType = 38 == selectedWaypoint0.sprite and finishCheckpoint or midCheckpoint
                    selectedWaypoint0.checkpoint = makeCheckpoint(checkpointType, selectedWaypoint0.coord,
                    selectedWaypoint0.coord, color, 127, selectedIndex0 - 1)
                    savedTrackName = nil
                elseif IsControlJustReleased(0, 188) == 1 and selectedWaypoint0.coord.r < maxRadius then -- arrow up or DPAD UP
                    selectedWaypoint0.coord.r = selectedWaypoint0.coord.r + 0.5
                    DeleteCheckpoint(selectedWaypoint0.checkpoint)
                    local color = getCheckpointColor(selectedBlipColor)
                    local checkpointType = 38 == selectedWaypoint0.sprite and finishCheckpoint or midCheckpoint
                    selectedWaypoint0.checkpoint = makeCheckpoint(checkpointType, selectedWaypoint0.coord,
                    selectedWaypoint0.coord, color, 127, selectedIndex0 - 1)
                    savedTrackName = nil
                end
            end
        elseif STATE_RACING == raceState then
            local elapsedTime = currentTime - raceStart - raceDelay * 1000
            local vehicle = GetVehiclePedIsIn(player, false)

            SetLeaderboardLower(false)

            if elapsedTime < 0 then
                drawMsg(0.50, 0.46, "Race starting in", 0.7, 0)
                drawMsg(0.50, 0.50, ("%05.2f"):format(-elapsedTime / 1000.0), 0.7, 0)
                drawMsg(0.50, 0.54, "seconds", 0.7, 0)

                if false == camTransStarted then
                    camTransStarted = true
                    Citizen.CreateThread(function()
                        local entity = IsPedInAnyVehicle(player, false) == 1 and GetVehiclePedIsIn(player, false) or
                        player

                        local cam0 = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
                        SetCamCoord(cam0, GetOffsetFromEntityInWorldCoords(entity, 0.0, 5.0, 1.0))
                        PointCamAtEntity(cam0, entity, 0.0, 0.0, 0.0, true)

                        local cam1 = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
                        SetCamCoord(cam1, GetOffsetFromEntityInWorldCoords(entity, -5.0, 0.0, 1.0))
                        PointCamAtEntity(cam1, entity, 0.0, 0.0, 0.0, true)

                        local cam2 = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
                        SetCamCoord(cam2, GetOffsetFromEntityInWorldCoords(entity, 0.0, -5.0, 1.0))
                        PointCamAtEntity(cam2, entity, 0.0, 0.0, 0.0, true)

                        RenderScriptCams(true, false, 0, true, true)

                        SetCamActiveWithInterp(cam1, cam0, 1000, 0, 0)
                        Citizen.Wait(2000)

                        SetCamActiveWithInterp(cam2, cam1, 1000, 0, 0)
                        Citizen.Wait(2000)

                        RenderScriptCams(false, true, 1000, true, true)

                        SetGameplayCamRelativeRotation(GetEntityRotation(entity))

                        DestroyAllCams(true)
                    end)
                end

                if elapsedTime > -countdown * 1000 then
                    drawLights = true
                    countdown = countdown - 1
                    PlaySoundFrontend(-1, "MP_5_SECOND_TIMER", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                end

                if true == drawLights then
                    for i = 0, 4 - countdown do
                        drawRect(i * 0.2 + 0.05, 0.15, 0.1, 0.1, 255, 0, 0, 255)
                    end
                end

                if IsPedInAnyVehicle(player, false) == 1 then
                    FreezeEntityPosition(GetVehiclePedIsIn(player, false), true)
                end
            else

                if false == started then
                    started = true
                    PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET", true)
                    bestLapVehicleName = currentVehicleName
                    lapTimeStart = currentTime
                    ghosting:StartGhosting(configData['raceStartGhostingTime'])
                end

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

                FreezeEntityPosition(vehicle, false)

                local lapTime = currentTime - lapTimeStart
                local minutes, seconds = minutesSeconds(lapTime)
                SendCurrentLapTime(minutes, seconds)

                HandleWanted()

                if true == beginDNFTimeout then
                    local milliseconds = timeoutStart + DNFTimeout - currentTime
                    if milliseconds > 0 then
                        minutes, seconds = minutesSeconds(milliseconds)
                        UpdateDNFTime(minutes, seconds)
                    else -- DNF
                        DeleteCheckpoint(raceCheckpoint)
                        finishRace(-1)
                    end
                end

                if STATE_RACING == raceState then
                    if #(playerCoord - vector3(waypointCoord.x, waypointCoord.y, waypointCoord.z)) < waypointCoord.r then
                        local waypointPassed = true
                        if restrictedHash ~= nil then
                            if nil == vehicle or currentVehicleHash ~= restrictedHash then
                                waypointPassed = false
                            end
                        elseif restrictedClass ~= nil then
                            if vehicle ~= nil then
                                if -1 == restrictedClass then
                                    if vehicleInList(vehicle, customClassVehicleList) == false then
                                        waypointPassed = false
                                    end
                                elseif GetVehicleClass(vehicle) ~= restrictedClass then
                                    waypointPassed = false
                                end
                            else
                                waypointPassed = false
                            end
                        end

                        if true == waypointPassed then

                            resetupgrades(vehicle)
                            DeleteCheckpoint(raceCheckpoint)

                            numWaypointsPassed = numWaypointsPassed + 1

                            SendCheckpointTime(numWaypointsPassed, lapTime)

                            if currentWaypoint < #waypoints then
                                PlaySoundFrontend(-1, "CHECKPOINT_NORMAL", "HUD_MINI_GAME_SOUNDSET", true)
                                currentWaypoint = currentWaypoint + 1
                            else
                                currentWaypoint = 1
                                lapTimeStart = currentTime
                                if -1 == bestLapTime or lapTime < bestLapTime then
                                    bestLapTime = lapTime
                                    minutes, seconds = minutesSeconds(bestLapTime)
                                    SendBestLapTime(minutes, seconds)
                                    bestLapVehicleName = currentVehicleName
                                end
                                if currentLap < numLaps then
                                    currentLap = currentLap + 1
                                    PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true)
                                    --Last lap gets a unique sound to signify it's end
                                    if(currentLap == numLaps) then
                                        PlaySoundFrontend(-1, "TENNIS_MATCH_POINT", "HUD_AWARDS", true)
                                    end
                                    UpdateCurrentLap()
                                    if #randVehicles > 0 then
                                        local randIndex = math.random(#randVehicles)
                                        sendMessage("Random Index: " .. randIndex)
                                        local randVehicle = switchVehicle(player,
                                        randVehicles[randIndex])
                                        if randVehicle ~= nil then
                                            SetEntityAsNoLongerNeeded(randVehicle)
                                        end
                                        PlaySoundFrontend(-1, "CHARACTER_SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                                    end
                                else
                                    finishRace(elapsedTime)
                                end
                            end

                            UpdateCurrentCheckpoint()

                            if STATE_RACING == raceState then
                                local prev = currentWaypoint - 1

                                local last = currentWaypoint + numVisible - 1
                                local addLast = true

                                local curr = currentWaypoint
                                local checkpointType = -1

                                if true == startIsFinish then
                                    prev = currentWaypoint
                                    if currentLap ~= numLaps then
                                        last = last % #waypoints + 1
                                    elseif last < #waypoints then
                                        last = last + 1
                                    elseif #waypoints == last then
                                        last = 1
                                    else
                                        addLast = false
                                    end
                                    curr = curr % #waypoints + 1
                                    checkpointType = (1 == curr and numLaps == currentLap) and finishCheckpoint or
                                    arrow3Checkpoint
                                else
                                    if last > #waypoints then
                                        addLast = false
                                    end
                                    checkpointType = #waypoints == curr and finishCheckpoint or arrow3Checkpoint
                                end

                                SetBlipDisplay(waypoints[prev].blip, 0)

                                if true == addLast then
                                    SetBlipDisplay(waypoints[last].blip, 2)
                                end

                                SetBlipRoute(waypoints[curr].blip, true)
                                SetBlipRouteColour(waypoints[curr].blip, blipRouteColor)
                                waypointCoord = waypoints[curr].coord
                                local nextCoord = waypointCoord
                                if arrow3Checkpoint == checkpointType then
                                    nextCoord = curr < #waypoints and waypoints[curr + 1].coord or waypoints[1].coord
                                end
                                raceCheckpoint = makeCheckpoint(checkpointType, waypointCoord, nextCoord, yellow, 127, 0)
                            end
                        end
                    end
                end
            end
        elseif STATE_JOINING == raceState then
            HandleJoinState()
        elseif STATE_IDLE == raceState then
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
                        removeRacerBlipGT()
                        TriggerServerEvent("races:join", closestIndex, PedToNet(player), nil)
                    end
                end
            else
                SetJoinMessage('')
            end
        end

        -- if IsPedInAnyVehicle(player, true) == false then
        --     local vehicle = GetVehiclePedIsTryingToEnter(player)
        --     if DoesEntityExist(vehicle) == 1 then
        --         if false == enteringVehicle then
        --             enteringVehicle = true
        --             local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))
        --             if numSeats > 0 then
        --                 for seat = -1, numSeats - 2 do
        --                     if IsVehicleSeatFree(vehicle, seat) == 1 then
        --                         TaskEnterVehicle(player, vehicle, 10.0, seat, 1.0, 1, 0)
        --                         break
        --                     end
        --                 end
        --             end
        --         end
        --     end
        -- else
        --     enteringVehicle = false
        -- end

        if true == panelShown then
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 18, true)
            DisableControlAction(0, 322, true)
            DisableControlAction(0, 106, true)
        end
    end
end)

Citizen.CreateThread(function()
    local recreated = false
    while true do
        Citizen.Wait(0)
        if IsPauseMenuActive() == false then
            if false == recreated then
                for _, racer in pairs(racerBlipGT) do
                    ped = NetToPed(racer.netID)
                    if DoesEntityExist(ped) == 1 then
                        racer.gamerTag = CreateFakeMpGamerTag(ped, racer.name, false, false, nil, 0)
                        SetMpGamerTagVisibility(racer.gamerTag, 0, true)
                    end
                end
                recreated = true
            end
        else
            recreated = false
        end
    end
end)
