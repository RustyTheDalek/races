local minRadius <const> = 0.5             -- minimum waypoint radius
local maxRadius <const> = 20.0            -- maximum waypoint radius

local selectedBlipColor <const> = 1       -- red
local blipRouteColor <const> = 18         -- light blue

local finishCheckpoint <const> = 4        -- cylinder checkered flag
local midCheckpoint <const> = 42          -- cylinder with number
local plainCheckpoint <const> = 45        -- cylinder
local arrow3Checkpoint <const> = 0        -- cylinder with 3 arrows

TrackEditor = {
    track = Track:New(),
    closestWaypointIndex = 0,
    highlightedCheckpoint = 0,            -- Index of highlighted checkpoint
    selectedIndex0 = 0,                   -- Index of first selected waypoint
    selectedIndex1 = 0,                   -- Index of second selected waypoint
    editStartTime = 0
}

function TrackEditor:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function TrackEditor:StartEditing(track)
    SetWaypointOff()
    self.track = track
    self.track:StartEditing()
    self.editStartTime = GetGameTimer()
end

function TrackEditor:StopEditing(waypointCoords)

    if self.selectedIndex0 ~= 0 then
        self.track:ResetBlip(self.selectedIndex0)
        self.selectedIndex0 = 0
    end
    if self.selectedIndex1 ~= 0 then
        self.track:ResetBlip(self.selectedIndex1)
        self.selectedIndex1 = 0
    end

    self.highlightedCheckpoint = 0

    self.track:StopEditing(waypointCoords)
end

function TrackEditor:EditWaypoints(coord, heading)
    print("Editing waypoints")

    self.closestWaypointIndex = self.track:GetClosestWaypoint(coord, maxRadius)

    self.track:UpdateStartingGrid()

    if 0 == self.closestWaypointIndex then          -- no existing waypoint selected
        self:OnNoClosestWaypoint(coord, heading)
    else                                            -- existing waypoint selected
        self:OnClosestWaypointExists(coord, heading)
    end
end

function TrackEditor:OnNoClosestWaypoint(coord, heading)
    print("No existing waypoints selected")
    if 0 == self.selectedIndex0 then -- no previous selected waypoints exist, add new waypoint
        self:AddNewWaypoint(coord, heading)
    else                            -- first selected waypoint exists
        if 0 == self.selectedIndex1 then -- second selected waypoint does not exist, move first selected waypoint to new location
            self:MoveSelectedWaypoint(coord, heading)
        else -- second selected waypoint exists, add waypoint between first and second selected waypoints
            self:AddWaypointBetween(coord, heading)
        end
    end

    --If the track has been changed then reset the name
    self.track.savedTrackName = nil

    SetBlipRoute(self.track.waypoints[1].blip, true)
    SetBlipRouteColour(self.track.waypoints[1].blip, blipRouteColor)
end

function TrackEditor:AddNewWaypoint(coord, heading)
    local blip = AddBlipForCoord(coord.x, coord.y, coord.z)

    self.track.waypoints[#self.track.waypoints + 1] = {
        coord = { x = coord.x, y = coord.y, z = coord.z, heading = heading },
        checkpoint = nil, blip = blip, sprite = -1, color = -1, number = -1, name = nil 
    }

    self.track.startIsFinish = 1 == #self.track.waypoints
    self.track:SetStartToFinishBlips()
    self.track:DeleteCheckpoints()
    self.track:SetStartToFinishCheckpoints()
end

function TrackEditor:MoveSelectedWaypoint(coord, heading)
    local selectedWaypoint0 = self.track.waypoints[self.selectedIndex0]
    selectedWaypoint0.coord = { x = coord.x, y = coord.y, z = coord.z, r = selectedWaypoint0.coord.r, heading = heading }

    SetBlipCoords(selectedWaypoint0.blip, coord.x, coord.y, coord.z)

    DeleteCheckpoint(selectedWaypoint0.checkpoint)
    local color = getCheckpointColor(selectedBlipColor)
    local checkpointType = 38 == selectedWaypoint0.sprite and finishCheckpoint or midCheckpoint
    selectedWaypoint0.checkpoint = MakeCheckpoint(checkpointType, selectedWaypoint0.coord, coord, color, self.selectedIndex0 - 1)
    self.track:UpdateStartingGrid()
end

function TrackEditor:AddWaypointBetween(coord, heading)
    for i = #self.track.waypoints, self.selectedIndex1, -1 do
        self.track.waypoints[i + 1] = self.track.waypoints[i]
    end

    local blip = AddBlipForCoord(coord.x, coord.y, coord.z)

    self.track.waypoints[self.selectedIndex1] = {
        coord = { x = coord.x, y = coord.y, z = coord.z, heading = heading },
        checkpoint = nil, blip = blip, sprite = -1, color = -1, number = -1, name = nil }

    self.track:UpdateTrackDisplay()

    self.selectedIndex0 = 0
    self.selectedIndex1 = 0
end

function TrackEditor:OnClosestWaypointExists(coord, heading)
    print("Existing waypoint selected")
    local selectedWaypoint = self.track:GetWaypoint(self.closestWaypointIndex)
    selectedWaypoint.coord.heading = heading
    if 0 == self.selectedIndex0 then -- no previous selected waypoint exists, show that waypoint is selected
        self:SelectWaypoint(selectedWaypoint)
        self.selectedIndex0 = self.closestWaypointIndex
    else                                        -- first selected waypoint exists
        if self.closestWaypointIndex == self.selectedIndex0 then -- selected waypoint and first selected waypoint are the same, unselect
            self:DeselectSelectedWaypoint(selectedWaypoint)

            if self.selectedIndex1 ~= 0 then
                self.selectedIndex0 = self.selectedIndex1
                self.selectedIndex1 = 0
            else
                self.selectedIndex0 = 0
            end

        elseif self.closestWaypointIndex == self.selectedIndex1 then -- selected waypoint and second selected waypoint are the same
            self:DeselectSelectedWaypoint(selectedWaypoint)
            self.selectedIndex1 = 0
        else                            -- selected waypoint and first and second selected waypoints are different
            if 0 == self.selectedIndex1 then -- second selected waypoint does not exist
                self:OnNoSecondSelectedWaypoint(selectedWaypoint)
            else -- second selected waypoint exists
                self:OnSecondSelectedWaypoint(selectedWaypoint)
            end
        end
    end
end

function TrackEditor:SelectWaypoint(selectedWaypoint)
    SetBlipColour(selectedWaypoint.blip, selectedBlipColor)
    local color = getCheckpointColor(selectedBlipColor)
    SetCheckpointRgba(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)
    SetCheckpointRgba2(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)
end

function TrackEditor:DeselectSelectedWaypoint(selectedWaypoint)
    SetBlipColour(selectedWaypoint.blip, selectedWaypoint.color)
    local color = getCheckpointColor(selectedWaypoint.color)
    SetCheckpointRgba(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)
    SetCheckpointRgba2(selectedWaypoint.checkpoint, color.r, color.g, color.b, 127)
end

function TrackEditor:OnNoSecondSelectedWaypoint(selectedWaypoint)
    local checkpointType = finishCheckpoint
    local waypointNum = 0
    if true == self.track.startIsFinish then
        if self.track:GetTotalWaypoints() == self.closestWaypointIndex and 1 == self.selectedIndex0 then -- split start/finish waypoint

            self.track.startIsFinish = false
            self:SplitStartAndFinish()
            self:SplitCombineTrack(finishCheckpoint)
            return
        end
    else
        if 1 == self.closestWaypointIndex and self.track:GetTotalWaypoints() == self.selectedIndex0 then -- combine start and finish waypoints


            self.track.startIsFinish = true
            self:CombineStartAndFinish()
            self:SplitCombineTrack(midCheckpoint)
            return
        end
    end

    --If Selected waypoint is one in front of the second selected
    if self.closestWaypointIndex == self.selectedIndex0 + 1 then
        self:SelectWaypoint(selectedWaypoint)
        self.selectedIndex1 = self.closestWaypointIndex
    elseif self.closestWaypointIndex == self.selectedIndex0 - 1 then
        self:SelectWaypoint(selectedWaypoint)
        self.selectedIndex1 = self.selectedIndex0
        self.selectedIndex0 = self.closestWaypointIndex
    else
        self:SelectWaypoint(selectedWaypoint)
        local selectedWaypoint0 = self.track:GetWaypoint(self.selectedIndex0)
        self:DeselectSelectedWaypoint(selectedWaypoint0)
        self.selectedIndex0 = self.closestWaypointIndex
    end
end

function TrackEditor:SplitStartAndFinish()
    self.track.startIsFinish = false

    self.track:SetFirstWaypointAsStart()
    self.track:SetLastWaypointAsFinish()
end

function TrackEditor:CombineStartAndFinish()
    self.track.startIsFinish = true
    self.track:SetFirstWaypointAsLoop()
    self.track:SetLastWaypointAsLoop()
end

function TrackEditor:SplitCombineTrack(checkpointType)

    self.track:SetStartFinishCheckpoints(checkpointType)

    self.selectedIndex0 = 0
    self.track.savedTrackName = nil
end

function TrackEditor:OnSecondSelectedWaypoint(selectedWaypoint)
    if self.closestWaypointIndex == self.selectedIndex1 + 1 then
        self:SelectWaypoint(selectedWaypoint)
        local selectedWaypoint0 = self.track:GetWaypoint(self.selectedIndex0)
        self:DeselectSelectedWaypoint(selectedWaypoint0)
        self.selectedIndex0 = self.selectedIndex1
        self.selectedIndex1 = self.closestWaypointIndex
    elseif self.closestWaypointIndex == self.selectedIndex0 - 1 then
        self:SelectWaypoint(selectedWaypoint)
        local selectedWaypoint1 = self.track:GetWaypoint(self.selectedIndex1)
        self:DeselectSelectedWaypoint(selectedWaypoint1)
        self.selectedIndex1 = self.selectedIndex0
        self.selectedIndex0 = self.closestWaypointIndex
    else
        self:SelectWaypoint(selectedWaypoint)
        local selectedWaypoint0 = self.track:GetWaypoints(self.selectedIndex0)
        self:DeselectSelectedWaypoint(selectedWaypoint0)

        local selectedWaypoint1 = self.track:GetWaypoints(self.selectedIndex1)
        self:DeselectSelectedWaypoint(selectedWaypoint1)
        self.selectedIndex0 = self.closestWaypointIndex
        self.selectedIndex1 = 0
    end
end

function TrackEditor:DeleteTrackCheckpoints()
    self.track:DeleteCheckpoints()
end

function TrackEditor:Reverse()
    self.track:Reverse()
    self.highlightedCheckpoint = 0
    self.selectedIndex0 = 0
    self.selectedIndex1 = 0
end

function TrackEditor:Clear()
    self.highlightedCheckpoint = 0
    self.selfselectedIndex0 = 0
    self.selectedIndex1 = 0

    self.track:Clear()
end

function TrackEditor:UpdateClosestCheckpointDisplay(closestIndex)
    if closestIndex ~= 0 then
        if self.highlightedCheckpoint ~= 0 and closestIndex ~= self.highlightedCheckpointhighlightedCheckpoint then
            local color = (self.highlightedCheckpoint == self.selectedIndex0 or self.highlightedCheckpoint == self.selectedIndex1) and
            getCheckpointColor(selectedBlipColor) or getCheckpointColor(self.track:GetWaypoint(self.highlightedCheckpoint).color)
            SetCheckpointRgba(self.track:GetWaypoint(self.highlightedCheckpoint).checkpoint, color.r, color.g, color.b, 127)
        end
        local color = (closestIndex == self.selectedIndex0 or closestIndex == self.selectedIndex1) and
        getCheckpointColor(selectedBlipColor) or getCheckpointColor(self.track:GetWaypoint(closestIndex).color)
        SetCheckpointRgba(self.track:GetWaypoint(closestIndex).checkpoint, color.r, color.g, color.b, 255)
        self.highlightedCheckpoint = closestIndex
        drawMsg(0.50, 0.50, "Press [ENTER] key, [A] button or [CROSS] button to select waypoint", 0.7, 0)
    elseif self.highlightedCheckpoint ~= 0 then
        local color = (self.highlightedCheckpoint == self.selectedIndex0 or self.highlightedCheckpoint == self.selectedIndex1) and
        getCheckpointColor(selectedBlipColor) or getCheckpointColor(self.track:GetWaypoint(self.highlightedCheckpoint).color)
        SetCheckpointRgba(self.track:GetWaypoint(self.highlightedCheckpoint).checkpoint, color.r, color.g, color.b, 127)
        self.highlightedCheckpoint = 0
    end
end

function TrackEditor:Update(playerCoord, heading)
    local closestIndex = 0
    local minDist = maxRadius
    for index, waypoint in ipairs(self.track.waypoints) do
        local dist = #(playerCoord - vector3(waypoint.coord.x, waypoint.coord.y, waypoint.coord.z))
        if dist < waypoint.coord.r and dist < minDist then
            minDist = dist
            closestIndex = index
        end
    end

    self:UpdateClosestCheckpointDisplay(closestIndex)

    --TODO:Find a better way to do this
    --Used to prevent the enter key that is used to start editing 
    if(GetGameTimer() - self.editStartTime < 100) then
        return
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
                self:EditWaypoints(coord, heading)
                break
            end
        end
    elseif IsControlJustReleased(0, 215) == 1 then -- enter key or A button or cross button
        self:EditWaypoints(playerCoord, heading)
    elseif self.selectedIndex0 ~= 0 and 0 == self.selectedIndex1 then
        local selectedWaypoint0 = self.track:GetWaypoint(self.selectedIndex0)
        if IsControlJustReleased(2, 216) == 1 then -- space key or X button or square button
            DeleteCheckpoint(selectedWaypoint0.checkpoint)
            RemoveBlip(selectedWaypoint0.blip)
            self.track:RemoveWaypoint(self.selectedIndex0)

            if self.highlightedCheckpoint == self.selectedIndex0 then
                self.highlightedCheckpoint = 0
            end
            self.selectedIndex0 = 0

            self.track.savedTrackName = nil

            self.track:UpdateTrackDisplayFull()

        elseif IsControlJustReleased(0, 187) == 1 and selectedWaypoint0.coord.r > minRadius then -- arrow down or DPAD DOWN
            selectedWaypoint0.coord.r = selectedWaypoint0.coord.r - 0.5
            self.track:UpdateCheckpoint(selectedWaypoint0, selectedBlipColor, self.selectedIndex0)
        elseif IsControlJustReleased(0, 188) == 1 and selectedWaypoint0.coord.r < maxRadius then -- arrow up or DPAD UP
            selectedWaypoint0.coord.r = selectedWaypoint0.coord.r + 0.5
            self.track:UpdateCheckpoint(selectedWaypoint0, selectedBlipColor, self.selectedIndex0)
        end
    end
end

function TrackEditor:Load(isPublic, trackName, waypointCoords)
    self.track:Load(isPublic, trackName, waypointCoords)
    self.highlightedCheckpoint = 0
    self.track:DeleteTrackCheckpoints()
    self.track:SetStartToFinishCheckpoints()
end

function TrackEditor:TrySave(access, name)
    if "pvt" == access or "pub" == access then
        if name ~= nil then
            if #self.track.waypoints > 1 then
                TriggerServerEvent("races:save", "pub" == access, name, self.track:WaypointsToCoords(), self.track.map)
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

function TrackEditor:TryOverwrite(access, trackName, map)

    print(("overwriting with map %s"):format(map))

    if "pvt" == access or "pub" == access then
        if trackName ~= nil then
            if #self.track.waypoints > 1 then
                TriggerServerEvent("races:overwrite", "pub" == access, trackName, self.track:WaypointsToCoords(), map)
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

function TrackEditor:OnUpdateTrackMetaData(public, name)
    self.track.isPublicTrack = public
    self.track.savedTrackName = name
end