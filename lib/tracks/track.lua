local finishCheckpoint <const> = 4         -- cylinder checkered flag
local arrow3Checkpoint <const> = 0         -- cylinder with 3 arrows
local noArrowCheckpoint <const> = 47       -- cylinder with 3 arrows
local loopCheckpoint <const> = 3           -- cyling with loop icon
local blipRouteColor <const> = 18          -- light blue

local gridRadius<const> = 5.0
local gridSeparation<const> = 5
local gridCheckPointType<const> = 45

local maxNumVisible<const> = 5 -- maximum number of waypoints visible during a race
local numVisible = maxNumVisible -- number of waypoints visible during a race - may be less than maxNumVisible

Track = {
    waypoints = {}, -- waypoints[] = {coord = {x, y, z, r}, checkpoint, blip, sprite, color, number, name}
    startIsFinish = false,
    sections = {},
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
    self:IdentifySections();
end

-- Function to find the next waypoints in the track
function Track:FindNextWaypoints(index, visited)
    visited[index] = true
    local waypoint = self.waypoints[index]
    local next_indices = waypoint.next
    local next_waypoints = {}
    for _, next_index in ipairs(next_indices) do
        if not visited[next_index] then
            table.insert(next_waypoints, next_index)
        end
    end
    return next_waypoints
end

-- Function to identify sections of the track
function Track:IdentifySections()
    self.sections = {}

    local section = {}
    local visited = {}
    local reverse_links = {}
    local stack = {1}

    -- Build reverse links to detect convergence
    for i, waypoint in ipairs(self.waypoints) do
        for _, next_index in ipairs(waypoint.next) do
            if not reverse_links[next_index] then
                reverse_links[next_index] = {}
            end
            table.insert(reverse_links[next_index], i)
        end
    end

    while #stack > 0 do
        local current = table.remove(stack)
        local is_convergence = reverse_links[current] and #reverse_links[current] > 1
        local next_waypoints = self:FindNextWaypoints(current, visited)

        -- If convergence, close current section and start new one with current waypoint
        if is_convergence then
            if #section > 0 then
                table.insert(self.sections, section)
            end
            section = {current}
        else
            table.insert(section, current)
        end

        -- If split, close current section but do not start new section
        if #next_waypoints > 1 then
            if #section > 0 then
                table.insert(self.sections, section)
            end
            section = {}
        end

        for _, next_index in ipairs(next_waypoints) do
            table.insert(stack, next_index)
        end

        if #next_waypoints == 0 then
            if #section > 0 then
                table.insert(self.sections, section)
            end
            section = {}
        end
    end

    -- Sort sections based on the minimum waypoint index in each section
    table.sort(self.sections, function(a, b)
        return a[1] < b[1]
    end)

end

-- Function to calculate the race progress
function Track:CalculateProgress(targetWaypoint)
    for sectionIndex, section in ipairs(self.sections) do
        for waypointIndex, waypoint in pairs(section) do
            if (waypoint == targetWaypoint) then
                return sectionIndex, waypointIndex, getTableSize(section)
            end
        end
    end

    return 0, 0, 0
end

function Track:AddNewWaypointAtIndex(coord, heading, index, linkWaypointInFront)

    self.waypoints[index] = Waypoint:New({
        coord = coord,
        heading = heading,
        radius = Config.data.editing.defaultRadius
    })

    local previousWaypoint = self.waypoints[index - 1]

    if (previousWaypoint ~= nil and not previousWaypoint:HasNext(index)) then
        print(("Pointing waypoint %i to %i"):format(index - 1, index))
        --Stop this line adding multiple links to future waypoints
        -- TODO: Add to next, don't replace
        print("Pointing previous waypoint to this")

        print(dump(self.waypoints[index - 1].next))
        self.waypoints[index - 1]:AddNext(index)
        print(dump(self.waypoints[index - 1].next))

    end

    print("checking current waypoint")

    print(dump(self.waypoints[index].next))
    
    self.waypoints[index]:ClearNext()
    
    print(dump(self.waypoints[index].next))

    if (linkWaypointInFront) then
        print("Linking forwards")
        -- If Next waypoint exists then set this waypoint to next one 
        if (self.waypoints[index + 1] ~= nil) then
            -- TODO: Add to next, don't replace
            print("Link found pointing")
            self.waypoints[index]:AddNext(index + 1)
        end
    end

    self.startIsFinish = 1 == #self.waypoints

    self.waypoints[index]:CreateBlip(index, #self.waypoints, self.startIsFinish)

    self:SetStartToFinishBlips()
    self:DeleteCheckpoints()
    self:SetStartToFinishCheckpoints()
end

function Track:AddNewWaypoint(coord, heading)
    self:AddNewWaypointAtIndex(coord, heading, #self.waypoints + 1, true)
end

function Track:MoveWaypoint(index, coord, heading)

    self.waypoints[index]:MoveWaypoint(coord, heading)
    self:UpdateStartingGrid()

end

function Track:ShiftWaypointsForward(stopIndex)
    for i = #self.waypoints, stopIndex, -1 do
        print(("Shifting Waypoint %i forward"):format(i))
        self.waypoints[i]:ShiftNextsForward()
        self.waypoints[i + 1] = self.waypoints[i]
    end
    self.waypoints[stopIndex] = nil
end

function Track:Split(coord, heading, index)

    --We only want to shift what's ahead of the waypoint
    self:ShiftWaypointsForward(index + 1)

    self:IncrementNextsAtIndex(index)

    self:AddNewWaypointAtIndex(coord, heading, index + 1, false)
    self:UpdateTrackDisplay()

    return true
end

--Loop through the track and increment links on waypoints that point to the old
function Track:IncrementNextsAtIndex(index)
    print("Incrementing nexts")
    for _, waypoint in ipairs(self.waypoints) do
        waypoint:ShiftNextsIfFurtherAhead(index)
    end
end

function Track:AddWaypointBetween(coord, heading, selectedIndex)
    self:ShiftWaypointsForward(selectedIndex)
    self:AddNewWaypointAtIndex(coord, heading, selectedIndex, true)
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
        waypoint:MakeCheckpoint(waypoint.coord, index, 127, 44, nil)
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

    print(dump(waypoints))

    for index, waypoint in ipairs(waypoints) do

        if (index == #waypoints and 
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

    self.startIsFinish = self.waypoints[#self.waypoints]:NextIsLinked()

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
    SendNUIMessage( {
        type = "editor",
        action = "update_selected_waypoint",
        waypointIndex = index,
        pointsTo = self.waypoints[index]:GetNextAsString()
    })
end

function Track:DeselectSelectedWaypoint(index)
    self.waypoints[index]:DeselectSelectedWaypoint()
    SendNUIMessage( { type = "editor", action = "update_selected_waypoint", waypointIndex = 'none', pointsTo = nil })
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

        waypoint:RemoveNextLinks(waypointIndexToDelete, waypointToDelete.next)
    end

    table.remove(self.waypoints, waypointIndexToDelete)
end

function Track:RouteToTrack()
    SetBlipRoute(self.waypoints[1].blip, true)
    SetBlipRouteColour(self.waypoints[1].blip, blipRouteColor)
end

function Track:OnHitCheckpoint(waypointHit, previousWaypoint, currentLap, numLaps)

    if(previousWaypoint >= 1) then
        for _, previousWaypointIndex in ipairs(self.waypoints[previousWaypoint].next) do
            SetBlipDisplay(self.waypoints[previousWaypointIndex].blip, 0)
        end
    end


    local checkpointType = -1

    local nextCheckpoints = {}

    for _, nextWaypointIndex in ipairs(self.waypoints[waypointHit].next) do

        local nextWaypoint = self.waypoints[nextWaypointIndex]

        if(getTableSize(nextWaypoint.next) == 0 or (nextWaypointIndex == 1 and currentLap == numLaps)) then
            checkpointType = finishCheckpoint
        elseif(nextWaypointIndex == 1 and currentLap < numLaps) then
            checkpointType = loopCheckpoint
        else
            checkpointType = arrow3Checkpoint
        end

        SetBlipDisplay(nextWaypoint.blip, 2)

        local coord = nextWaypoint.coord
        local radius = nextWaypoint.radius

        if(checkpointType == arrow3Checkpoint and getTableSize(nextWaypoint.next) > 1) then

            table.insert(nextCheckpoints, {
                checkpoint = MakeCheckpoint(noArrowCheckpoint, coord, radius, coord, color.orange, 0),
                coord = coord,
                radius = radius,
                index = nextWaypointIndex
            })

            for index, splitWaypointIndex in ipairs(nextWaypoint.next) do
                local nextCoord = self.waypoints[splitWaypointIndex].coord

                SetBlipDisplay(self.waypoints[splitWaypointIndex].blip, 2)

                table.insert(nextCheckpoints, {
                    checkpoint = MakeCheckpoint(checkpointType, coord, radius, nextCoord, color.lightBlue, 0, 255),
                    coord = coord,
                    radius = radius,
                    index = nextWaypointIndex
                })

                --We only really want the arrow to show, but overlapping checkpoints makes the the checpoint 'thicker'
                --The Fix is to hide the cylinder of the checkpoints that follow
                SetCheckpointCylinderHeight(nextCheckpoints[#nextCheckpoints].checkpoint, 0.0, 0.0, 0.0)
                SetCheckpointIconHeight(nextCheckpoints[#nextCheckpoints].checkpoint, 0.15 * #nextCheckpoints)
                SetCheckpointIconScale(nextCheckpoints[#nextCheckpoints].checkpoint, 0.5)
            end
        else
            local nextCoord = (nextWaypoint.next ~= nil and getTableSize(nextWaypoint.next) == 1 ) and self.waypoints[nextWaypoint.next[1]].coord or coord

            table.insert(nextCheckpoints, {
                checkpoint = MakeCheckpoint(checkpointType, coord, radius, nextCoord, color.yellow, 0),
                coord = coord,
                radius = radius,
                index = nextWaypointIndex
            })

            SetBlipRoute(nextWaypoint.blip, true)
            SetBlipRouteColour(nextWaypoint.blip, blipRouteColor)
        end
    end

    return nextCheckpoints
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

    if (self.waypoints == nil or self.waypoints[1] == nil or self.waypoints[1].coord == nil) then
        notifyPlayer("Could not start race no start waypoint");
        return nil
    end

    local startWaypoint = {
        checkpoint = MakeCheckpoint(finishCheckpoint, self.waypoints[1].coord, self.waypoints[1].radius, self.waypoints[1].coord, color.yellow, 0),
        coord = self.waypoints[1].coord,
        radius = self.waypoints[1].radius,
        index = 1
    }

    SetBlipRoute(self.waypoints[1].blip, true)
    SetBlipRouteColour(self.waypoints[1].blip, blipRouteColor)

    self:DeleteGridCheckPoints()

    return { startWaypoint }
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

function Track:WaypointLoops(currentWaypoint)
    return self.waypoints[currentWaypoint]:Loops()
end

function Track:AtEnd(currentWaypoint, waypointsHit)
    return self.waypoints[currentWaypoint]:AtEnd() or (currentWaypoint == 1 and waypointsHit > 1)
end

function Track:Validate()

    for waypointIndex, waypoint in ipairs(self.waypoints) do
        for nextIndex, pointsTo in ipairs(waypoint.next) do
            if(self.waypoints[pointsTo] == nil) then
                sendMessage(("Waypoint %i Points to %i, but doesn't exist, removing..."):format(waypointIndex, pointsTo))

                table.remove(self.waypoints[waypointIndex].next, nextIndex)
            end
        end

        waypoint:RemoveDuplicateNexts()
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

            newWaypoints[index] = Track.AddWaypoint(newCoord, waypointCoord, next)

        else
            if (newCoord == newWaypoints[1].coord) then
                -- Looping track
                print("Track Loops")
                --If the track loops then we ignore the last checkpoint, in the old style there 2 checkpoints for start and finish but this is no longer done that way, so we point the previous waypoint to the start and skip the last
                newWaypoints[index-1].next = {1}
            else
                newWaypoints[index] = Track.AddWaypoint(newCoord, waypointCoord, {})
            end
        end


    end

    print(json.encode(newWaypoints))

    return newWaypoints
end

Track.AddWaypoint = function(newCoord, waypointCoord, next)

    local newWaypoint = Waypoint:New({
        coord = newCoord,
        radius = waypointCoord.r,
        heading = waypointCoord.heading,
        next = next
    })

    return  newWaypoint

end
