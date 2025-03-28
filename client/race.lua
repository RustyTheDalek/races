SetManualShutdownLoadingScreenNui(true)

local RaceConfig = require 'shared/config/raceConfig'
local RaceStateMachine = require 'client/state/raceStateMachine'
local WaypointManager = require 'client/waypoints/waypointManager'
local VehicleManager = require 'client/vehicles/vehicleManager'

-- Export race state for external use
function RaceState()
    return RaceStateMachine:getCurrentState()
end

-- Initialize race variables
local raceIndex = -1
local numLaps = -1
local currentLap = -1
local position = -1
local numRacers = -1
local DNFTimeout = -1
local beginDNFTimeout = false
local timeoutStart = -1

-- Main race loop
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local currentState = RaceStateMachine:getCurrentState()
        
        if currentState == RaceConfig.STATES.RACING then
            -- Get player coordinates
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            
            -- Check for waypoint hits
            if WaypointManager:checkWaypointHit(playerCoords) then
                WaypointManager:advanceWaypoint()
                TriggerServerEvent(RaceConfig.EVENTS.WAYPOINT_HIT, raceIndex)
            end
            
            -- Update next waypoints display
            WaypointManager:updateNextWaypoints(3)
        end
    end
end)

-- Event handlers
RegisterNetEvent(RaceConfig.EVENTS.RACE_START)
AddEventHandler(RaceConfig.EVENTS.RACE_START, function(raceData)
    raceIndex = raceData.index
    numLaps = raceData.laps
    currentLap = 1
    position = raceData.position
    numRacers = raceData.numRacers
    
    -- Set up waypoints
    WaypointManager:setWaypoints(raceData.waypoints)
    
    -- Spawn vehicle
    local vehicleModel = raceData.vehicle or VehicleManager:getRandomVehicle()
    VehicleManager:spawnVehicle(vehicleModel)
    VehicleManager:createVehicleBlip()
    
    -- Change state to racing
    RaceStateMachine:changeState(RaceConfig.STATES.RACING)
end)

RegisterNetEvent(RaceConfig.EVENTS.RACE_END)
AddEventHandler(RaceConfig.EVENTS.RACE_END, function(raceResults)
    -- Clean up
    VehicleManager:deleteCurrentVehicle()
    WaypointManager:clearBlips()
    
    -- Change state to finished
    RaceStateMachine:changeState(RaceConfig.STATES.FINISHED)
    
    -- Show results
    -- TODO: Implement results display
end)

RegisterNetEvent(RaceConfig.EVENTS.PLAYER_DNF)
AddEventHandler(RaceConfig.EVENTS.PLAYER_DNF, function()
    -- Clean up
    VehicleManager:deleteCurrentVehicle()
    WaypointManager:clearBlips()
    
    -- Change state to DNF
    RaceStateMachine:changeState(RaceConfig.STATES.DNF)
    
    -- Show DNF message
    -- TODO: Implement DNF message display
end)

-- Command handlers
RegisterCommand('joinrace', function(source, args)
    if RaceStateMachine:getCurrentState() ~= RaceConfig.STATES.IDLE then
        return
    end
    
    local raceId = tonumber(args[1])
    if not raceId then
        -- TODO: Show error message
        return
    end
    
    TriggerServerEvent('race:join', raceId)
    RaceStateMachine:changeState(RaceConfig.STATES.JOINING)
end)

RegisterCommand('leaverace', function()
    if RaceStateMachine:getCurrentState() == RaceConfig.STATES.RACING then
        TriggerServerEvent('race:leave')
        VehicleManager:deleteCurrentVehicle()
        WaypointManager:clearBlips()
        RaceStateMachine:changeState(RaceConfig.STATES.IDLE)
    end
end)

-- Initialize
RaceStateMachine:init()
WaypointManager:init()
VehicleManager:init()