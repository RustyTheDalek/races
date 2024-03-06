local startFinishSprite <const> = 38      -- checkered flag
local startSprite <const> = 38            -- checkered flag
local finishSprite <const> = 38           -- checkered flag
local midSprite <const> = 1               -- numbered circle

local startFinishBlipColor <const> = 5    -- yellow
local startBlipColor <const> = 2          -- green
local finishBlipColor <const> = 0         -- white
local midBlipColor <const> = 38           -- dark blue
local blipRouteColor <const> = 18         -- light blue
local registerBlipColor <const> = 83      -- purple

local finishCheckpoint <const> = 4        -- cylinder checkered flag
local midCheckpoint <const> = 42          -- cylinder with number
local plainCheckpoint <const> = 45        -- cylinder
local arrow3Checkpoint <const> = 0        -- cylinder with 3 arrows

local gridRadius <const> = 5.0
local gridSeparation <const> = 5
local gridCheckPointType <const> = 45

local maxNumVisible <const> = 3           -- maximum number of waypoints visible during a race
local numVisible = maxNumVisible          -- number of waypoints visible during a race - may be less than maxNumVisible

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

function Track:Load(public, trackName, waypointCoords, map)
    self.public = public
    self.savedTrackName = trackName
    self.map = map

    self:LoadWaypointBlips(waypointCoords)
end

function Track:GetWaypoint(index)
    return self.waypoints[index]
end

function Track:GetTotalWaypoints()
    return #self.waypoints
end

function Track:UpdateTrackDisplay()
    self:SetStartToFinishBlips()
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
        self:GenerateStartingGrid(self.waypoints[1].coord, 8)
    end
end

function Track:StartEditing()
    if(#self.waypoints > 0) then
        self:GenerateStartingGrid(self.waypoints[1].coord, 8)
    end
    self:SetStartToFinishCheckpoints()
end

function Track:StopEditing(waypointCoords)
    self:DeleteTrackCheckpoints()
    self:DeleteGridCheckPoints()
    self.LoadWaypointBlips(waypointCoords)
    self.setStartToFinishCheckpoints()
end

function Track:SetFirstWaypointAsStart()
    self.waypoints[1].sprite = startSprite
    self.waypoints[1].color = startBlipColor
    self.waypoints[1].number = -1
    self.waypoints[1].name = "Start" 
end

--For when Track is multiple laps
function Track:SetFirstWaypointAsLoop()
    self.waypoints[1].sprite = startFinishSprite
    self.waypoints[1].color = startFinishBlipColor
    self.waypoints[1].number = -1
    self.waypoints[1].name = "Start/Finish" 
end

function Track:SetLastWaypointAsLoop()
    self.waypoints[#self.waypoints].sprite = midSprite
    self.waypoints[#self.waypoints].color = midBlipColor
    self.waypoints[#self.waypoints].number = #self.waypoints - 1
    self.waypoints[#self.waypoints].name = "Waypoint"
end

function Track:SetLastWaypointAsFinish()
    self.waypoints[#self.waypoints].sprite = finishSprite
    self.waypoints[#self.waypoints].color = finishBlipColor
    self.waypoints[#self.waypoints].number = -1
    self.waypoints[#self.waypoints].name = "Finish"
end

function Track:SetStartFinishCheckpoints(checkpointType)
    self:SetBlipProperties(1)
    self:SetBlipProperties(#self.waypoints)

    local color = getCheckpointColor(self.waypoints[1].color)
    SetCheckpointRgba(self.waypoints[1].checkpoint, color.r, color.g, color.b, 127)
    SetCheckpointRgba2(self.waypoints[1].checkpoint, color.r, color.g, color.b, 127)

    DeleteCheckpoint(self.waypoints[#self.waypoints].checkpoint)
    color = getCheckpointColor(self.waypoints[#self.waypoints].color)
    self.waypoints[#self.waypoints].checkpoint = MakeCheckpoint(checkpointType, self.waypoints[#self.waypoints].coord,
    self.waypoints[#self.waypoints].coord, color, #self.waypoints - 1)

end

function Track:UpdateCheckpoint(checkpoint, color, index)
    DeleteCheckpoint(checkpoint.checkpoint)
    local color = getCheckpointColor(color)
    local checkpointType = 38 == checkpoint.sprite and finishCheckpoint or midCheckpoint
    checkpoint.checkpoint = MakeCheckpoint(checkpointType, checkpoint.coord,
    checkpoint.coord, color, index - 1)
    self.savedTrackName = nil
end

function Track:SetStartToFinishCheckpoints()
    for i = 1, #self.waypoints do
        local color = getCheckpointColor(self.waypoints[i].color)
        local checkpointType = 38 == self.waypoints[i].sprite and finishCheckpoint or midCheckpoint
        self.waypoints[i].checkpoint = MakeCheckpoint(checkpointType, self.waypoints[i].coord, self.waypoints[i].coord, color, i - 1)
    end
end

function Track:LoadWaypointBlips(waypointCoords)
    self:deleteWaypointBlips()
    self.waypoints = {}

    for i = 1, #waypointCoords - 1 do
        local blip = AddBlipForCoord(waypointCoords[i].x, waypointCoords[i].y, waypointCoords[i].z)
        self.waypoints[i] = { coord = waypointCoords[i], checkpoint = nil, blip = blip, sprite = -1, color = -1, number = -1,
            name = nil }
    end

    self.startIsFinish =
        waypointCoords[1].x == waypointCoords[#waypointCoords].x and
        waypointCoords[1].y == waypointCoords[#waypointCoords].y and
        waypointCoords[1].z == waypointCoords[#waypointCoords].z

    if false == self.startIsFinish then
        local blip = AddBlipForCoord(waypointCoords[#waypointCoords].x, waypointCoords[#waypointCoords].y,
        waypointCoords[#waypointCoords].z)
        self.waypoints[#waypointCoords] = { coord = waypointCoords[#waypointCoords], checkpoint = nil, blip = blip,
            sprite = -1, color = -1, number = -1, name = nil }
    else
        print("Start is finish")
    end

    self:SetStartToFinishBlips()
    SetBlipRoute(self.waypoints[1].blip, true)
    SetBlipRouteColour(self.waypoints[1].blip, blipRouteColor)
end

function Track:SetStartToFinishBlips()
    if true == self.startIsFinish then
        self.waypoints[1].sprite = startFinishSprite
        self.waypoints[1].color = startFinishBlipColor
        self.waypoints[1].number = -1
        self.waypoints[1].name = "Start/Finish"

        if #self.waypoints > 1 then
            self.waypoints[#self.waypoints].sprite = midSprite
            self.waypoints[#self.waypoints].color = midBlipColor
            self.waypoints[#self.waypoints].number = #self.waypoints - 1
            self.waypoints[#self.waypoints].name = "Waypoint"
        end
    else -- #waypoints should be > 1
        self.waypoints[1].sprite = startSprite
        self.waypoints[1].color = startBlipColor
        self.waypoints[1].number = -1
        self.waypoints[1].name = "Start"

        self.waypoints[#self.waypoints].sprite = finishSprite
        self.waypoints[#self.waypoints].color = finishBlipColor
        self.waypoints[#self.waypoints].number = -1
        self.waypoints[#self.waypoints].name = "Finish"
    end

    for i = 2, #self.waypoints - 1 do
        self.waypoints[i].sprite = midSprite
        self.waypoints[i].color = midBlipColor
        self.waypoints[i].number = i - 1
        self.waypoints[i].name = "Waypoint"
    end

    for i = 1, #self.waypoints do
        self:SetBlipProperties(i)
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

function Track:GetClosestWaypoint(coord, maxRadius)
    local selectedIndex = 0
    local minDist = maxRadius
    for index, waypoint in ipairs(self.waypoints) do
        local dist = #(coord - vector3(waypoint.coord.x, waypoint.coord.y, waypoint.coord.z))
        if dist < waypoint.coord.r and dist < minDist then
            minDist = dist
            selectedIndex = index
        end
    end

    return selectedIndex
end

function Track:DeleteCheckpoints()
    for _, waypoint in ipairs(self.waypoints) do
        DeleteCheckpoint(waypoint.checkpoint)
    end
end

function Track:LoadWaypointBlips(waypointCoords)
    self:DeleteWaypointBlips()
    self.waypoints = {}

    for i = 1, #waypointCoords - 1 do
        local blip = AddBlipForCoord(waypointCoords[i].x, waypointCoords[i].y, waypointCoords[i].z)
        self.waypoints[i] = { coord = waypointCoords[i], checkpoint = nil, blip = blip, sprite = -1, color = -1, number = -1,
            name = nil }
    end

    self.startIsFinish =
        waypointCoords[1].x == waypointCoords[#waypointCoords].x and
        waypointCoords[1].y == waypointCoords[#waypointCoords].y and
        waypointCoords[1].z == waypointCoords[#waypointCoords].z

    if false == self.startIsFinish then
        local blip = AddBlipForCoord(waypointCoords[#waypointCoords].x, waypointCoords[#waypointCoords].y,
        waypointCoords[#waypointCoords].z)
        self.waypoints[#waypointCoords] = { coord = waypointCoords[#waypointCoords], checkpoint = nil, blip = blip,
            sprite = -1, color = -1, number = -1, name = nil }
    end

    self:SetStartToFinishBlips()

    SetBlipRoute(self.waypoints[1].blip, true)
    SetBlipRouteColour(self.waypoints[1].blip, blipRouteColor)
end

function Track:DeleteWaypointBlips()
    for i = 1, #self.waypoints do
        RemoveBlip(self.waypoints[i].blip)
    end
end

function Track:WaypointsToCoords()
    local waypointCoords = {}
    for i = 1, #self.waypoints do
        waypointCoords[i] = self.waypoints[i].coord
    end
    if true == self.startIsFinish then
        waypointCoords[#waypointCoords + 1] = waypointCoords[1]
    end
    return waypointCoords
end

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
    self.DeleteCheckpoints()
    self.LoadWaypointBlips(self:WaypointsToCoordsRev())
    self.SetStartFinishCheckpoints()    
    self.GenerateStartingGrid(self.waypoints[1].coord, 8)
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

    self.gridCheckpoint = CreateCheckpoint(45,
        position.x, position.y, position.z - 1,
        position.x, position.y, position.z,
        gridRadius,
        0, 255, 0,
        127, gridNumber)

    SetCheckpointCylinderHeight(self.gridCheckpoint, 10.0, 10.0, gridRadius * 2.0)

    return self.gridCheckpoint
end

function Track:GenerateStartingGrid(startWaypoint, totalGridPositions)
    self:DeleteGridCheckPoints()

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

        table.insert(self.gridCheckpoints, self:CreateGridCheckpoint(gridPosition, i))
    end
end

function Track:UpdateStartingGrid()
    if (#self.waypoints > 0) then
        self:GenerateStartingGrid(self.waypoints[1].coord, 8)
    end
end

function Track:DeleteGridCheckPoints()
    print("Deleting grid")
    for _, checkpoint in pairs(self.gridCheckpoints) do
        DeleteCheckpoint(checkpoint)
    end

    for k in next, self.gridCheckpoints do rawset(self.gridCheckpoints, k, nil) end
end

function Track:spawnCheckpoint(position, gridNumber)
    table.insert(self.gridCheckpoints, self:CreateGridCheckpoint(position, gridNumber))
end

function Track:SpawnCheckpoints(gridPositions)
    for index, gridPosition in ipairs(gridPositions) do
        self:spawnCheckpoint(gridPosition, index)
    end
end

function Track:RemoveWaypoint(waypointIndex)
    table.remove(self.waypoints, waypointIndex)
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
        checkpointType = (1 == curr and numLaps == currentLap) and finishCheckpoint or
        arrow3Checkpoint
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
    local raceCheckpoint = MakeCheckpoint(checkpointType, waypointCoord, nextCoord, colour.yellow, 0)

    return waypointCoord, raceCheckpoint
end

function Track:Register(rData)
    TriggerServerEvent("races:register", self:WaypointsToCoords(), self.public, self.savedTrackName, rData)
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
    local currentWaypoint = true == self.startIsFinish and 0 or 1

    local waypointCoord = self.waypoints[1].coord
    local raceCheckpoint = MakeCheckpoint(arrow3Checkpoint, waypointCoord, self.waypoints[2].coord, colour.yellow, 0)

    SetBlipRoute(waypointCoord, true)
    SetBlipRouteColour(waypointCoord, blipRouteColor)

    self:DeleteGridCheckPoints()

    return currentWaypoint, waypointCoord, raceCheckpoint
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