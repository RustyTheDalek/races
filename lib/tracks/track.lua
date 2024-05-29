local arrow3Checkpoint <const> = 0        -- cylinder with 3 arrows
local blipRouteColor <const> = 18         -- light blue

local gridRadius<const> = 5.0
local gridSeparation<const> = 5
local gridCheckPointType<const> = 45

local maxNumVisible<const> = 3 -- maximum number of waypoints visible during a race
local numVisible = maxNumVisible -- number of waypoints visible during a race - may be less than maxNumVisible

Track = {
    waypoints = {}, -- waypoints[] = {coord = {x, y, z, r}, checkpoint, blip, sprite, color, number, name}
    startIsFinish = false,
    public = false,
    savedTrackName = nil,
    gridCheckpoint = nil,
    gridCheckpoints = {},
    map = ""
}

function Track:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Track:SerialiseWaypoints()
    return map(self.waypoints, function(waypoint)
        return {
            coord = waypoint.coord,
            heading = waypoint.heading,
            radius = waypoint.radius,
            next = waypoint.next
        }
    end)
end

function Track:Load(public, trackName, track)

    print("Loading track")

    self.public = public
    self.savedTrackName = trackName
    self.map = track.map

    print("Loaded metadata")

    self:LoadWaypointBlips(track.waypoints)
end

function Track:AddNewWaypointAtIndex(coord, heading, index)

    self.waypoints[index] = Waypoint:New({
        coord = coord,
        heading = heading,
        radius = Config.data.editing.defaultRadius
    })

    -- If Waypoint behind exists then set it's next waypoint to this one
    if (self.waypoints[index - 1] ~= nil) then
        -- TODO: Add to next, don't replace
        self.waypoints[index - 1].next = {index}
    end

    -- If Next waypoint exists then set this waypoint to next one 
    if (self.waypoints[index + 1] ~= nil) then
        -- TODO: Add to next, don't replace
        self.waypoints[index].next = {index + 1}
    end

    self.startIsFinish = 1 == #self.waypoints

    self.waypoints[index]:CreateBlip(index, #self.waypoints, self.startIsFinish)

    self:SetStartToFinishBlips()
    self:DeleteCheckpoints()
    self:SetStartToFinishCheckpoints()
end

function Track:AddNewWaypoint(coord, heading)
    self:AddNewWaypointAtIndex(coord, index, #self.waypoints + 1)
end

function Track:MoveWaypoint(index, coord, heading)

    self.waypoints[index]:MoveWaypoint(coord, heading)
    self:UpdateStartingGrid()

end

function Track:ShiftWaypointsForward(stopIndex)
    for i = #self.waypoints, stopIndex, -1 do
        if (not self.waypoints[i]:NextEmpty()) then
            self.waypoints[i].next[1] = self.waypoints[i].next[1] + 1
        end
        self.waypoints[i + 1] = self.waypoints[i]
    end
end

function Track:AddWaypointBetween(coord, heading, selectedIndex)
    self:ShiftWaypointsForward(selectedIndex)
    self:AddNewWaypointAtIndex(coord, heading, selectedIndex)
    self:UpdateTrackDisplay()
end

function Track:GetWaypoint(index)
    return self.waypoints[index]
end

function Track:GetTotalWaypoints()
    return #self.waypoints
end

function Track:UpdateTrackDisplay()
    for index, waypoint in ipairs(self.waypoints) do
        waypoint:SetBlipProperties()
    end
    self:DeleteCheckpoints()
    self:SetStartToFinishCheckpoints()
end

function Track:UpdateTrackDisplayFull()
    if #self.waypoints > 0 then
        if 1 == #self.waypoints then
            self.startIsFinish = true
        end
        self:UpdateTrackDisplay()
        SetBlipRoute(self.waypoints[1].blip, true)
        SetBlipRouteColour(self.waypoints[1].blip, blipRouteColor)
        self:GenerateStartingGrid(self.waypoints[1], 8)
    end
end

function Track:StartEditing()
    if (#self.waypoints > 0) then
        self:GenerateStartingGrid(self.waypoints[1], 8)
    end
    self:SetStartToFinishCheckpoints()
end

function Track:StopEditing()
    self:DeleteGridCheckPoints()
    self:DeleteCheckpoints()
end

function Track:SetFirstWaypointAsStart()
    self.waypoints[1]:SetAsStart()
end

-- For when Track is multiple laps
function Track:SetFirstWaypointAsLoop()
    self.waypoints[1]:SetAsStartLoop()
end

function Track:SetLastWaypointAsLoop()
    self.waypoints[#self.waypoints]:SetLastWaypointAsLoop(#self.waypoints - 1)
end

function Track:SetLastWaypointAsFinish()
    self.waypoints[#self.waypoints]:SetLastWaypointAsFinish()
end

function Track:SetStartFinishCheckpoints(checkpointType)
    self.waypoints[1]:SetBlipProperties()
    self.waypoints[#self.waypoints]:SetBlipProperties()

    self.waypoints[1]:UpdateCheckPointColour()
    self.waypoints[#self.waypoints]:UpdateLastCheckpoint(checkpointType)
end

function Track:AdjustCheckpointRadius(index, adjustment)
    if (self.waypoints[index] == nil) then
        print("Checkpoint nil")
        return
    end

    self.waypoints[index]:AdjustCheckpointRadius(adjustment)
end

function Track:SetStartToFinishCheckpoints()
    for index, waypoint in ipairs(self.waypoints) do
        waypoint:MakeCheckpoint(waypoint.coord, index - 1)
    end
end

function Track:LoadWaypointBlips(waypoints)

    print("Loading waypoint blips")

    self:DeleteWaypointBlips()
    self.waypoints = {}

    if (waypoints == nil or #waypoints == 0) then
        print("No Waypoints to load")
        return
    end

    self.startIsFinish = waypoints[#waypoints].next ~= nil and #waypoints[#waypoints].next > 0

    for index, waypoint in ipairs(waypoints) do

        if (self.startIsFinish and index == #waypoints and 
            waypoint.coord.x == self.waypoints[1].coord.x and
            waypoint.coord.y == self.waypoints[1].coord.y and 
            waypoint.coord.z == self.waypoints[1].coord.z) then
            print("Skipping last checkpoint as track is a loop")
            goto continue
        end

        print(dump(waypoint.next))

        self.waypoints[index] = Waypoint:New({
            coord = vector3(waypoint.coord.x, waypoint.coord.y, waypoint.coord.z),
            heading = waypoint.heading,
            radius = waypoint.radius,
            next = waypoint.next
        })

        self.waypoints[index]:CreateBlip(index, #waypoints, self.startIsFinish)

        ::continue::
    end
    print("Loaded waypoint blips")
    SetBlipRoute(self.waypoints[1].blip, true)
    SetBlipRouteColour(self.waypoints[1].blip, blipRouteColor)
end

function Track:SetStartToFinishBlips()
    for index, waypoint in ipairs(self.waypoints) do

        if (self.startIsFinish and index == #self.waypoints and
            waypoint.coord.x == self.waypoints[1].coord.x and
            waypoint.coord.y == self.waypoints[1].coord.y and 
            waypoint.coord.z == self.waypoints[1].coord.z) then
            print("Skipping last checkpoint as track is a loop")
            goto continue
        end

        self.waypoints[index]:UpdateBlip(index, #self.waypoints, self.startIsFinish)

        ::continue::
    end
end

function Track:ResetBlip(index)
    SetBlipColour(self.waypoints[index].blip, self.waypoints[index].color)
end

function Track:RestoreBlips()
    for i = 1, #self.waypoints do
        SetBlipDisplay(self.waypoints[i].blip, 2)
    end
end

function Track:SetBlipProperties(index)
    SetBlipSprite(self.waypoints[index].blip, self.waypoints[index].sprite)
    SetBlipColour(self.waypoints[index].blip, self.waypoints[index].color)
    ShowNumberOnBlip(self.waypoints[index].blip, self.waypoints[index].number)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(self.waypoints[index].name)
    EndTextCommandSetBlipName(self.waypoints[index].blip)
end

function Track:UpdateHeading(index, heading)
    self.waypoints[index].heading = heading
end

function Track:SelectWaypoint(index)
    self.waypoints[index]:SelectWaypoint()
end

function Track:DeselectSelectedWaypoint(index)
    self.waypoints[index]:DeselectSelectedWaypoint()
end

function Track:DeleteCheckpoints()
    for _, waypoint in ipairs(self.waypoints) do
        DeleteCheckpoint(waypoint.checkpoint)
    end
end

function Track:DeleteWaypointBlips()
    for i = 1, #self.waypoints do
        RemoveBlip(self.waypoints[i].blip)
    end
end

-- To reverse waypoints need to me much more complicated
function Track:WaypointsToCoordsRev()
    local waypointCoords = {}
    if true == self.startIsFinish then
        waypointCoords[1] = self.waypoints[1].coord
    end
    for i = #self.waypoints, 1, -1 do
        waypointCoords[#waypointCoords + 1] = self.waypoints[i].coord
    end
    return waypointCoords
end

function Track:Reverse()
    self.savedTrackName = nil
    self:DeleteCheckpoints()
    self:LoadWaypointBlips(self:WaypointsToCoordsRev())
    self:SetStartFinishCheckpoints()
    self:GenerateStartingGrid(self.waypoints[1], 8)
end

function Track:Clear()
    self:DeleteCheckpoints()
    self:DeleteGridCheckPoints()
    self:DeleteWaypointBlips()
    self.waypoints = {}
    self.startIsFinish = false
    self.savedTrackName = nil
end

function Track:CreateGridCheckpoint(position, gridNumber)

    self.gridCheckpoint = CreateCheckpoint(45, position.x, position.y, position.z - 1, position.x, position.y,
        position.z, gridRadius, 0, 255, 0, 127, gridNumber)

    SetCheckpointCylinderHeight(self.gridCheckpoint, 10.0, 10.0, gridRadius * 2.0)

    return self.gridCheckpoint
end

function Track:GenerateStartingGrid(startWaypoint, totalGridPositions)
    self:DeleteGridCheckPoints()

    print("Generating starting grid")

    -- print(string.format("Starting Grid: %.2f, %.2f, %.2f", startPoint.x, startPoint.y, startPoint.z))
    -- print(string.format("Starting Heading: %.2f", startWaypoint.heading))

    -- Calculate the forwardVector of the starting Waypoint
    local x = -math.sin(math.rad(startWaypoint.heading)) * math.cos(0)
    local y = math.cos(math.rad(startWaypoint.heading)) * math.cos(0)
    local z = math.sin(0);
    local forwardVector = norm(vector3(x, y, z))

    local leftVector = norm(vector3(math.cos(math.rad(startWaypoint.heading)),
        math.sin(math.rad(startWaypoint.heading)), 0.0))

    -- print(string.format("Forward Vector: %.2f, %.2f, %.2f", forwardVector.x, forwardVector.y, forwardVector.z))
    -- print(string.format("Left Vector: %.2f, %.2f, %.2f", leftVector.x, leftVector.y, leftVector.z))

    for i = 1, totalGridPositions do

        local gridPosition = startWaypoint.coord - forwardVector * (i + 1) * gridSeparation

        -- print(string.format("Initial grid position Position(%.2f,%.2f,%.2f)", gridPosition.x, gridPosition.y,
        -- gridPosition.z))

        if math.fmod(i, 2) == 0 then
            -- print("Right Grid")
            gridPosition = gridPosition + -leftVector * 3
        else
            -- print("Left Grid")
            gridPosition = gridPosition + leftVector * 3
        end

        table.insert(self.gridCheckpoints, self:CreateGridCheckpoint(gridPosition, i))
    end
end

function Track:UpdateStartingGrid()
    if (#self.waypoints > 0) then
        self:GenerateStartingGrid(self.waypoints[1], 8)
    end
end

function Track:DeleteGridCheckPoints()
    print("Deleting grid")
    for _, checkpoint in pairs(self.gridCheckpoints) do
        DeleteCheckpoint(checkpoint)
    end

    for k in next, self.gridCheckpoints do
        rawset(self.gridCheckpoints, k, nil)
    end
end

function Track:spawnCheckpoint(position, gridNumber)
    table.insert(self.gridCheckpoints, self:CreateGridCheckpoint(position, gridNumber))
end

function Track:SpawnCheckpoints(gridPositions)
    for index, gridPosition in ipairs(gridPositions) do
        self:spawnCheckpoint(gridPosition, index)
    end
end

function Track:RemoveWaypoint(waypointIndexToDelete)

    local waypointToDelete = self.waypoints[waypointIndexToDelete]

    print(("Deleting waypoint %i"):format(waypointIndexToDelete))
    print(dump(waypointToDelete.next))

    -- Find all waypoints that point to the one being Deleted
    -- Point them to what the deleted waypoint points to
    for waypointIndex, waypoint in ipairs(self.waypoints) do
        print(("Checking waypoint %i"):format(waypointIndex))
        print(dump(waypoint.next))

        for pointsToIndex, pointsTo in ipairs(waypoint.next) do
            --Waypoints that are aheead of the one deleted will need to point one waypoint back
            if(waypointIndex > waypointIndexToDelete) then
                print("Shifting point down")
                waypoint.next[pointsToIndex] = pointsTo - 1
            elseif (pointsTo == waypointIndexToDelete) then
                print("waypoint points to deleted waypoint")
                table.remove(waypoint.next, pointsToIndex)
                for _, next in ipairs(waypointToDelete.next) do
                    print(("Now pointing to %i"):format(next))
                    --Will not be shifted one back as well
                    table.insert(waypoint.next, next -1)
                end
            end
        end
    end

    table.remove(self.waypoints, waypointIndexToDelete)
end

function Track:RouteToTrack()
    SetBlipRoute(self.waypoints[1].blip, true)
    SetBlipRouteColour(self.waypoints[1].blip, blipRouteColor)
end

function Track:OnHitCheckpoint(currentWaypoint, currentLap, numLaps)

    local prev = currentWaypoint - 1
    local last = currentWaypoint + numVisible - 1
    local addLast = true
    local curr = currentWaypoint
    local checkpointType = -1

    if true == self.startIsFinish then
        prev = currentWaypoint
        if currentLap ~= numLaps then
            last = last % #self.waypoints + 1
        elseif last < #self.waypoints then
            last = last + 1
        elseif #self.waypoints == last then
            last = 1
        else
            addLast = false
        end
        curr = curr % #self.waypoints + 1
        checkpointType = (1 == curr and numLaps == currentLap) and finishCheckpoint or arrow3Checkpoint
    else
        if last > #self.waypoints then
            addLast = false
        end
        checkpointType = #self.waypoints == curr and finishCheckpoint or arrow3Checkpoint
    end

    SetBlipDisplay(self.waypoints[prev].blip, 0)

    if true == addLast then
        SetBlipDisplay(self.waypoints[last].blip, 2)
    end

    SetBlipRoute(self.waypoints[curr].blip, true)
    SetBlipRouteColour(self.waypoints[curr].blip, blipRouteColor)
    local waypointCoord = self.waypoints[curr].coord
    local nextCoord = waypointCoord
    if arrow3Checkpoint == checkpointType then
        nextCoord = curr < #self.waypoints and self.waypoints[curr + 1].coord or self.waypoints[1].coord
    end
    local raceCheckpoint = MakeCheckpoint(checkpointType, waypointCoord, nextCoord, color.yellow, 0)

    return waypointCoord, raceCheckpoint
end

function Track:Register(rData)
    TriggerServerEvent("races:register", self:SerialiseWaypoints(), self.public, self.savedTrackName, rData)
end

function Track:Unregister()
    self:RestoreBlips()
    SetBlipRoute(self.waypoints[1].blip, true)
    SetBlipRouteColour(self.waypoints[1].blip, blipRouteColor)
end

function Track:SetVisibleBlips()
    numVisible = maxNumVisible < #self.waypoints and maxNumVisible or (#self.waypoints - 1)
    for i = numVisible + 1, #self.waypoints do
        SetBlipDisplay(self.waypoints[i].blip, 0)
    end
end

function Track:OnStartRace()

    self:SetVisibleBlips()
    local currentWaypoint = 1

    local waypointCoord = self.waypoints[1].coord

    local nextCheckpoints = {}

    for index, next in ipairs(self.waypoints[1].next) do

        local nextWaypointCoords = self.waypoints[next].coord

        table.insert(nextCheckpoints, MakeCheckpoint(arrow3Checkpoint, waypointCoord, nextWaypointCoords, color.yellow, 0))
    end

    SetBlipRoute(waypointCoord, true)
    SetBlipRouteColour(waypointCoord, blipRouteColor)

    self:DeleteGridCheckPoints()

    return currentWaypoint, waypointCoord, nextCheckpoints
end

function Track:GetTrackRespawnPosition(index)
    if self.startIsFinish == true then
        if index > 0 then
            return self:GetWaypoint(index).coord
        end
    else
        if index > 1 then
            return self:GetWaypoint(index - 1).coord
        end
    end
end

Track.UpdateTrack = function(track)

    print("Updating track...")
    print(("Track version:%i"):format(track.version))

    if (track.version == 0) then
        -- Update everything

        track.waypoints = Track.UpdateWaypointCoords(track.waypointCoords)
        track.waypointCoords = nil

        track.version = 1
    end

    return track
end

Track.UpdateWaypointCoords = function(waypointCoords)

    print(("Updating %i waypoints..."):format(#waypointCoords))

    local newWaypoints = {}

    for index, waypointCoord in ipairs(waypointCoords) do
        print(("Updating Waypoint: %i"):format(index))

        local newCoord = vector3(waypointCoord.x, waypointCoord.y, waypointCoord.z)
        local next

        if (index < #waypointCoords) then
            next = {index + 1}
        else
            if (newCoord == newWaypoints[1].coord) then
                -- Looping track
                print("Track Loops")
                next = 1
            end
        end

        local newWaypoint = Waypoint:New({
            coord = newCoord,
            radius = waypointCoord.r,
            heading = waypointCoord.heading,
            next = next
        })

        newWaypoints[index] = newWaypoint

    end

    print(json.encode(newWaypoints))

    return newWaypoints
end