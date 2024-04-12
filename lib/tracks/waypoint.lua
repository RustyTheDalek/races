local startFinishSprite<const> = 38 -- checkered flag
local startSprite<const> = 38 -- checkered flag
local finishSprite<const> = 38 -- checkered flag
local midSprite<const> = 1 -- numbered circle

local startFinishBlipColor<const> = 5 -- yellow
local startBlipColor<const> = 2 -- green
local finishBlipColor<const> = 0 -- white
local midBlipColor<const> = 38 -- dark blue
local blipRouteColor<const> = 18 -- light blue
local registerBlipColor<const> = 83 -- purple

local finishCheckpoint<const> = 4 -- cylinder checkered flag
local midCheckpoint<const> = 42 -- cylinder with number
local plainCheckpoint<const> = 45 -- cylinder
local arrow3Checkpoint<const> = 0 -- cylinder with 3 arrows

local checkpointAlpha <const> = 127

local selectedBlipColor <const> = 1       -- red
local blipRouteColor <const> = 18         -- light blue

local minRadius <const> = 0.5             -- minimum waypoint radius
local maxRadius <const> = 20.0  

Waypoint = {
    next = {}, --Table of of waypoints it connects to
    coord = vector3(0, 0, 0),
    heading = 0,
    radius = 0,
    checkpointHandle = -1, 
    blipHandle = -1, 
    sprite = -1, 
    color = -1, 
    number = -1, 
    name = ''
}

function Waypoint:New(o)
    o = o or {} 

    if(self.radius == nil) then
        self.radius = Config.data.editing.defaultRadius
    end
    setmetatable(o, self)
    self.__index = self
    return o
end

function Waypoint:NextEmpty() 
    return self.next == nil or #self.next < 1
end

function Waypoint:SetAsStart()
    self.sprite = startSprite
    self.color = startBlipColor
    self.number = -1
    self.name = "Start"
end

function Waypoint:SetAsStartLoop(number)
    self.sprite = startFinishSprite
    self.color = startFinishBlipColor
    self.number = -1
    self.name = "Start/Finish"
end

function Waypoint:SetLastWaypointAsLoop(number)
    self.sprite = midSprite
    self.color = midBlipColor
    self.number = number
    self.name = "Waypoint"
    self.next = { 1 }
end

function Waypoint:SetLastWaypointAsFinish(number)
    self.sprite = finishSprite
    self.color = finishBlipColor
    self.number = -1
    self.name = "Finish"
    self.next = nil
end

--#region Blips
function Waypoint:CreateBlip(index, totalWaypoints, looping)
    self.blip = AddBlipForCoordVector3(self.coord)
    self.sprite, self.color, self.number, self.name = self:GetBlipProperties(index, totalWaypoints, looping)
    self:SetBlipProperties()
end

function Waypoint:UpdateBlip(index, totalWaypoints, looping)
    self.sprite, self.color, self.number, self.name = self:GetBlipProperties(index, totalWaypoints, looping)
    self:SetBlipProperties()
end

function Waypoint:MoveBlip(coord)
    SetBlipCoordsVector3(self.blip, coord)
end

function Waypoint:GetBlipProperties(index, totalWaypoints, looping)
    print(looping)
    if(index == 1) then
        print("Setting start blip")
        if(looping) then
            return startFinishSprite, startFinishBlipColor, -1, "Start/Finish"
        else
            return startSprite, startBlipColor, -1, "Start"
        end
    elseif(totalWaypoints > 1 and index == totalWaypoints ) then
        print("Last Finish blip")
        if(looping) then
            return midSprite, midBlipColor, totalWaypoints-1, "Waypoint"
        else
            return finishSprite, finishBlipColor, -1, "Finish"
        end
    else
        print("Mid blip")
        return midSprite, midBlipColor, index - 1, "Waypoint"
    end
end

function Waypoint:SetBlipProperties()

    if(self.blip == nil) then
        print("Can't set blip properties, no blip passed")
        return
    end

    if(self.name == nil) then
        print("Can't set blip properties, no name passed")
        return
    end

    SetBlipSprite(self.blip, self.sprite)
    SetBlipColour(self.blip, self.color)
    ShowNumberOnBlip(self.blip, self.number)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(self.name)
    EndTextCommandSetBlipName(self.blip)
end

--#endregion 

--#region Checkpoint
function Waypoint:MakeCheckpoint(nextCoord, number, alpha, overrideCheckpointType, overrideColor)

    local color = getCheckpointColor(self.color)

    local checkpointType = 38 == self.sprite and finishCheckpoint or midCheckpoint

    if(overrideCheckpointType ~= nil) then
        checkpointType = overrideCheckpointType
    end

    if(overrideColor ~= nil) then
        print("overriding with color")
        color = overrideColor
    end

    --The -1 represents the roughly half the height of the ped
    --It's divided by the radius of the coord which is in turn divied by 2
    --Because it's actually the diameter or because 2 is actually the ped height?

    if(self.radius == nil ) then
        self.radius = Config.data.editing.defaultRadius
    end

    if(alpha == nil) then
        alpha = checkpointAlpha
    end

    print(("Attempting to make checkpoint "):format())

    local checkpoint = CreateCheckpoint(checkpointType,
        self.coord.x, self.coord.y, self.coord.z -1 / (self.radius / 2),
        nextCoord.x, nextCoord.y, nextCoord.z -1 / (self.radius / 2) ,
        self.radius * 2.0, color.r, color.g, color.b, 
        alpha, number)

    if(checkpoint == nil) then
        return false
    end

    SetCheckpointIconHeight(checkpoint, 0.3)
    self.checkpoint = checkpoint

    return true
end

function Waypoint:UpdateCheckPointColour()
    local color = getCheckpointColor(self.color)
    SetCheckpointRgba(self.checkpoint, color.r, color.g, color.b, 127)
    SetCheckpointRgba2(self.checkpoint, color.r, color.g, color.b, 127)
end

function Waypoint:UpdateLastCheckpoint(checkpointType)
    DeleteCheckpoint(self.checkpoint)
    local color = getCheckpointColor(self.color)

    self:MakeCheckpoint(self.coord, self.number, nil, checkpointType, color)
end

function Waypoint:AdjustCheckpointRadius(adjustment)

    print(dump(adjustment))
    print(("adjusting radius by %f"):format(adjustment))

    local oldRadius = self.radius
    self.radius = Clamp(self.radius + adjustment, minRadius, maxRadius)

    print(self.radius)

    if(self.radius == oldRadius) then
        return
    end

    DeleteCheckpoint(self.checkpoint)
    local color = getCheckpointColor(selectedBlipColor)
    local checkpointType = 38 == self.sprite and finishCheckpoint or midCheckpoint
    self:MakeCheckpoint(self.coord, self.number, 127, nil, color)

end


--#endregion

function Waypoint:MoveWaypoint(coord, heading)
    self.coord = coord
    self.heading = heading

    self:MoveBlip(coord)

    DeleteCheckpoint(self.checkpoint)
    local color = getCheckpointColor(selectedBlipColor)
    local checkpointType = 38 == self.sprite and finishCheckpoint or midCheckpoint
    self:MakeCheckpoint(self.coord, self.number, 127, checkpointType, color)
end

function Waypoint:SelectWaypoint()
    SetBlipColour(self.blip, selectedBlipColor)
    local color = getCheckpointColor(selectedBlipColor)
    SetCheckpointRgba(self.checkpoint, color.r, color.g, color.b, 127)
    SetCheckpointRgba2(self.checkpoint, color.r, color.g, color.b, 127)
end

function Waypoint:DeselectSelectedWaypoint()
    SetBlipColour(self.blip, self.color)
    local color = getCheckpointColor(self.color)
    SetCheckpointRgba(self.checkpoint, color.r, color.g, color.b, 127)
    SetCheckpointRgba2(self.checkpoint, color.r, color.g, color.b, 127)
end