local RaceConfig = require 'shared/config/raceConfig'

local WaypointManager = {
    waypoints = {},
    currentWaypoint = -1,
    previousWaypoint = -1,
    waypointsHit = -1,
    currentSection = -1,
    currentSectionLength = -1,
    nextWaypoints = {},
    blips = {},
}

-- Initialize waypoint manager
function WaypointManager:init()
    self.waypoints = {}
    self.currentWaypoint = -1
    self.previousWaypoint = -1
    self.waypointsHit = -1
    self.currentSection = -1
    self.currentSectionLength = -1
    self.nextWaypoints = {}
    self.blips = {}
end

-- Set waypoints for a race
function WaypointManager:setWaypoints(waypoints)
    self.waypoints = waypoints
    self.currentWaypoint = 1
    self.waypointsHit = 0
    self:createBlips()
end

-- Create blips for waypoints
function WaypointManager:createBlips()
    -- Clear existing blips
    self:clearBlips()
    
    -- Create new blips
    for i, waypoint in ipairs(self.waypoints) do
        local blip = AddBlipForCoord(waypoint.x, waypoint.y, waypoint.z)
        SetBlipSprite(blip, RaceConfig.CHECKPOINT.PLAIN)
        SetBlipColour(blip, RaceConfig.BLIP.ROUTE_COLOR)
        SetBlipAsShortRange(blip, true)
        SetBlipScale(blip, 1.0)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Waypoint " .. i)
        EndTextCommandSetBlipName(blip)
        self.blips[i] = blip
    end
end

-- Clear all waypoint blips
function WaypointManager:clearBlips()
    for _, blip in pairs(self.blips) do
        RemoveBlip(blip)
    end
    self.blips = {}
end

-- Update next waypoints to show
function WaypointManager:updateNextWaypoints(numNext)
    self.nextWaypoints = {}
    for i = 1, numNext do
        local nextIndex = (self.currentWaypoint + i - 1) % #self.waypoints + 1
        table.insert(self.nextWaypoints, self.waypoints[nextIndex])
    end
end

-- Check if player has hit current waypoint
function WaypointManager:checkWaypointHit(playerCoords)
    if self.currentWaypoint <= 0 or self.currentWaypoint > #self.waypoints then
        return false
    end

    local waypoint = self.waypoints[self.currentWaypoint]
    local distance = #(playerCoords - vector3(waypoint.x, waypoint.y, waypoint.z))
    
    return distance <= waypoint.r
end

-- Advance to next waypoint
function WaypointManager:advanceWaypoint()
    self.previousWaypoint = self.currentWaypoint
    self.currentWaypoint = (self.currentWaypoint % #self.waypoints) + 1
    self.waypointsHit = self.waypointsHit + 1
end

-- Get current waypoint
function WaypointManager:getCurrentWaypoint()
    return self.waypoints[self.currentWaypoint]
end

-- Get next waypoints
function WaypointManager:getNextWaypoints()
    return self.nextWaypoints
end

-- Get total number of waypoints
function WaypointManager:getTotalWaypoints()
    return #self.waypoints
end

-- Get number of waypoints hit
function WaypointManager:getWaypointsHit()
    return self.waypointsHit
end

-- Initialize the waypoint manager
WaypointManager:init()

return WaypointManager 