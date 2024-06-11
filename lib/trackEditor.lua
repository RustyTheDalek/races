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
    SendNUIMessage( { type = "editor", action = "toggle_editor_view" })
end

function TrackEditor:StopEditing(waypoints)

    if self.selectedIndex0 ~= 0 then
        self.track:ResetBlip(self.selectedIndex0)
        self.selectedIndex0 = 0
    end
    if self.selectedIndex1 ~= 0 then
        self.track:ResetBlip(self.selectedIndex1)
        self.selectedIndex1 = 0
    end

    self.highlightedCheckpoint = 0

    self.track:StopEditing(waypoints)

    SendNUIMessage( { type = "editor", action = "toggle_editor_view" })
end

function TrackEditor:EditWaypoints(coord, heading)
    print("Editing waypoints")
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
        print("Adding new waypoint")
        self:AddNewWaypoint(coord, heading)
    else                            -- first selected waypoint exists
        if 0 == self.selectedIndex1 then -- second selected waypoint does not exist, move first selected waypoint to new location
            print("Moving selected waypoint")
            self:MoveSelectedWaypoint(coord, heading)
        else -- second selected waypoint exists, add waypoint between first and second selected waypoints
            print("Adding new waypoint between")
            self:AddWaypointBetween(coord, heading)
        end
    end

    --If the track has been changed then reset the name
    self.track.savedTrackName = nil

    SetBlipRoute(self.track.waypoints[1].blip, true)
    SetBlipRouteColour(self.track.waypoints[1].blip, blipRouteColor)
end

function TrackEditor:AddNewWaypoint(coord, heading)
    self.track:AddNewWaypoint(coord, heading)
end

function TrackEditor:MoveSelectedWaypoint(coord, heading)
    self.track:MoveWaypoint(self.selectedIndex0, coord, heading)
end

function TrackEditor:AddWaypointBetween(coord, heading)
    --Shift all waypoints ahead forward
    self.track:AddWaypointBetween(coord, heading, self.selectedIndex1)

    self.selectedIndex0 = 0
    self.selectedIndex1 = 0
end

function TrackEditor:OnClosestWaypointExists(coord, heading)
    print("Existing waypoint selected")

    self.track:UpdateHeading(self.closestWaypointIndex, heading)

    local selectedWaypoint = self.track:GetWaypoint(self.closestWaypointIndex)

    if 0 == self.selectedIndex0 then -- no previous selected waypoint exists, show that waypoint is selected
        print("Print No previous waypoint, selecting new")
        self.track:SelectWaypoint(self.closestWaypointIndex)
        self.selectedIndex0 = self.closestWaypointIndex
    else  -- first selected waypoint exists

        print("First selected waypoint exists")

        if self.closestWaypointIndex == self.selectedIndex0 then -- selected waypoint and first selected waypoint are the same, unselect

            print("Deselecting")

            self.track:DeselectSelectedWaypoint(self.closestWaypointIndex)

            if self.selectedIndex1 ~= 0 then
                self.selectedIndex0 = self.selectedIndex1
                self.selectedIndex1 = 0
            else
                self.selectedIndex0 = 0
            end

        elseif self.closestWaypointIndex == self.selectedIndex1 then -- selected waypoint and second selected waypoint are the same

            print("Deselecting")

            self.track:DeselectSelectedWaypoint(self.closestWaypointIndex)
            self.selectedIndex1 = 0
        else                            -- selected waypoint and first and second selected waypoints are different

            print("no matching waypoints selected")

            if 0 == self.selectedIndex1 then -- second selected waypoint does not exist
                self:OnNoSecondSelectedWaypoint()
            else -- second selected waypoint exists
                self:OnSecondSelectedWaypoint()
            end
        end
    end
end

function TrackEditor:OnNoSecondSelectedWaypoint()

    print("No second waypoint selected")

    local checkpointType = finishCheckpoint
    local waypointNum = 0
    if true == self.track.startIsFinish then
        if self.track:GetTotalWaypoints() == self.closestWaypointIndex and 1 == self.selectedIndex0 then -- split start/finish waypoint
            print("Split start and finish")
            self.track.startIsFinish = false
            self:SplitStartAndFinish()
            self:SplitCombineTrack(finishCheckpoint)
            return
        end
    else
        if 1 == self.closestWaypointIndex and self.track:GetTotalWaypoints() == self.selectedIndex0 then -- combine start and finish waypoints
            print("Combine start and finish")
            self.track.startIsFinish = true
            self:CombineStartAndFinish()
            self:SplitCombineTrack(midCheckpoint)
            return
        end
    end

    if(self.track:GetWaypoint(self.selectedIndex0):NextEmpty()) then
        print("Completing split")
        print(dump(self.track:GetWaypoint(self.selectedIndex0).next))
        self.track:GetWaypoint(self.selectedIndex0):AddNext(self.closestWaypointIndex)
        print(dump(self.track:GetWaypoint(self.selectedIndex0).next))
        return
    end

    --If Selected waypoint is one in front of the second selected
    if self.closestWaypointIndex == self.selectedIndex0 + 1 then
        self.track:SelectWaypoint(self.closestWaypointIndex)
        self.selectedIndex1 = self.closestWaypointIndex
    elseif self.closestWaypointIndex == self.selectedIndex0 - 1 then
        self.track:SelectWaypoint(self.closestWaypointIndex)
        self.selectedIndex1 = self.selectedIndex0
        self.selectedIndex0 = self.closestWaypointIndex
    else
        self.track:SelectWaypoint(self.closestWaypointIndex)
        local selectedWaypoint0 = self.track:GetWaypoint(self.selectedIndex0)
        self.track:DeselectSelectedWaypoint(selectedWaypoint0)
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

function TrackEditor:OnSecondSelectedWaypoint()

    print("Second waypoint selected")

    if self.closestWaypointIndex == self.selectedIndex1 + 1 then
        self.track:SelectWaypoint(self.closestWaypointIndex)
        local selectedWaypoint0 = self.track:GetWaypoint(self.selectedIndex0)
        self.track:DeselectSelectedWaypoint(selectedWaypoint0)
        self.selectedIndex0 = self.selectedIndex1
        self.selectedIndex1 = self.closestWaypointIndex
    elseif self.closestWaypointIndex == self.selectedIndex0 - 1 then
        self.track:SelectWaypoint(self.closestWaypointIndex)
        local selectedWaypoint1 = self.track:GetWaypoint(self.selectedIndex1)
        self.track:DeselectSelectedWaypoint(selectedWaypoint1)
        self.selectedIndex1 = self.selectedIndex0
        self.selectedIndex0 = self.closestWaypointIndex
    else
        self.track:SelectWaypoint(self.closestWaypointIndex)
        local selectedWaypoint0 = self.track:GetWaypoints(self.selectedIndex0)
        self.track:DeselectSelectedWaypoint(selectedWaypoint0)

        local selectedWaypoint1 = self.track:GetWaypoints(self.selectedIndex1)
        self.track:DeselectSelectedWaypoint(selectedWaypoint1)
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
    self.selectedIndex0 = 0
    self.selectedIndex1 = 0

    self.track:Clear()
end

function TrackEditor:UpdateClosestCheckpointDisplay(closestIndex)
    --TODO: Stop this overriding the checkpoint
    if closestIndex ~= 0 then
        -- If previous highlighed checkpoint exists and new checkpoint is different
        if self.highlightedCheckpoint ~= 0 and closestIndex ~= self.highlightedCheckpoint then
            local color
            if(self.highlightedCheckpoint == self.selectedIndex0) then
                color = getCheckpointColor(selectedBlipColor) 
            else
                color = getCheckpointColor(self.track:GetWaypoint(self.highlightedCheckpoint).color)
            end

            SetCheckpointRgba(self.track:GetWaypoint(self.highlightedCheckpoint).checkpoint, color.r, color.g, color.b, 127)
        end
        
        local color 
        if(closestIndex == self.selectedIndex0) then
            color = getCheckpointColor(selectedBlipColor)
        else
            color = getCheckpointColor(self.track:GetWaypoint(closestIndex).color)
        end

        SetCheckpointRgba(self.track:GetWaypoint(closestIndex).checkpoint, color.r, color.g, color.b, 255)
        self.highlightedCheckpoint = closestIndex

        drawMsg(0.50, 0.50, "Press [ENTER] key, [A] button or [CROSS] button to select waypoint", 0.7, 0)

    elseif self.highlightedCheckpoint ~= 0 then
        local color
        if(self.highlightedCheckpoint == self.selectedIndex0) then
            color = getCheckpointColor(selectedBlipColor)
        else
            color = getCheckpointColor(self.track:GetWaypoint(self.highlightedCheckpoint).color)
        end

        SetCheckpointRgba(self.track:GetWaypoint(self.highlightedCheckpoint).checkpoint, color.r, color.g, color.b, 127)
        self.highlightedCheckpoint = 0
    end
end

function TrackEditor:Update(playerCoord, heading)
    local closestIndex = 0
    local minDist = maxRadius
    for index, waypoint in ipairs(self.track.waypoints) do
        local dist = #(playerCoord - waypoint.coord)
        if dist < waypoint.radius and dist < minDist then
            minDist = dist
            closestIndex = index
        end
    end

    self.closestWaypointIndex = closestIndex

    SendNUIMessage( { type = "editor", action = "update_closest_waypoint", waypointIndex = closestIndex })

    self:UpdateClosestCheckpointDisplay(closestIndex)

    --TODO:Find a better way to do this
    --Used to prevent the enter key that is used to start editing 
    if(GetGameTimer() - self.editStartTime < 500) then
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

            if(self.closestWaypointIndex == self.selectedIndex0) then
                DeleteCheckpoint(selectedWaypoint0.checkpoint)
                RemoveBlip(selectedWaypoint0.blip)
                self.track:RemoveWaypoint(self.selectedIndex0)

                if self.highlightedCheckpoint == self.selectedIndex0 then
                    self.highlightedCheckpoint = 0
                end
                self.selectedIndex0 = 0
                self.track.savedTrackName = nil
                self.track:UpdateTrackDisplayFull()
            elseif (self.closestWaypointIndex ~= 0) then

                print("Connecting / splitting waypoint")

                print(dump(self.track:GetWaypoint(self.selectedIndex0).next))
                print(dump(self.track:GetWaypoint(self.selectedIndex0).next))

                --If They're already linked then unlink them
                if(self.track:GetWaypoint(self.selectedIndex0):HasNext(self.closestWaypointIndex)) then
                    print("Unlinking")
                    self.track:GetWaypoint(self.selectedIndex0):RemoveNext(self.closestWaypointIndex)
                else --Link them
                    print("Linking")
                    self.track:GetWaypoint(self.selectedIndex0):AddNext(self.closestWaypointIndex)
                end

                self.track:SelectWaypoint(self.selectedIndex0);

                print(dump(self.track:GetWaypoint(self.selectedIndex0).next))

            else

                print("Splitting track")

                if (not self.track:Split(playerCoord, heading, self.selectedIndex0)) then
                    notifyPlayer("Couldn't split track")
                    return
                end

                self.selectedIndex0 = self.selectedIndex0 + 1
                self.track:SelectWaypoint(self.selectedIndex0)
                self.track.savedTrackName = nil
                self.track:UpdateTrackDisplayFull()

            end
        elseif IsControlJustReleased(0, 187) == 1  then -- arrow down or DPAD DOWN
            self.track:AdjustCheckpointRadius(self.selectedIndex0, -0.5)
        elseif IsControlJustReleased(0, 188) == 1 and selectedWaypoint0.coord.r < maxRadius then -- arrow up or DPAD UP
            self.track:AdjustCheckpointRadius(self.selectedIndex0, 0.5)
        end
    end
end

function TrackEditor:Load(isPublic, trackName, track)
    self.track:Load(isPublic, trackName, track)
    self.highlightedCheckpoint = 0
    self:DeleteTrackCheckpoints()
    self.track:SetStartToFinishCheckpoints()
end

--TODO: Try to check track is valid before saving/overwriting
function TrackEditor:TrySave(access, name)
    if "pvt" == access or "pub" == access then
        if name ~= nil then
            if #self.track.waypoints > 1 then
                TriggerServerEvent("races:save", "pub" == access, name, self.track:SerialiseWaypoints(), self.track.map)
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
                TriggerServerEvent("races:overwrite", "pub" == access, trackName, self.track:SerialiseWaypoints(), map)
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