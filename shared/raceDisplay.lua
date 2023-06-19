-- waypoints[] = {coord = {x, y, z, r}, checkpoint, blip, sprite, color, number, name}
waypoints = {}

function deleteWaypointCheckpoints()
    for i = 1, #waypoints do
        DeleteCheckpoint(waypoints[i].checkpoint)
    end
end

function makeCheckpoint(checkpointType, coord, nextCoord, color, alpha, num)
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
function setStartToFinishCheckpoints()
    for i = 1, #waypoints do
        local color = getCheckpointColor(waypoints[i].color)
        local checkpointType = 38 == waypoints[i].sprite and finishCheckpoint or midCheckpoint
        waypoints[i].checkpoint = makeCheckpoint(checkpointType, waypoints[i].coord, waypoints[i].coord, color, 127,
        i - 1)
    end
end

--Blips
function deleteWaypointBlips()
    for i = 1, #waypoints do
        RemoveBlip(waypoints[i].blip)
    end
end

function setBlipProperties(index)
    SetBlipSprite(waypoints[index].blip, waypoints[index].sprite)
    SetBlipColour(waypoints[index].blip, waypoints[index].color)
    ShowNumberOnBlip(waypoints[index].blip, waypoints[index].number)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(waypoints[index].name)
    EndTextCommandSetBlipName(waypoints[index].blip)
end

function setStartToFinishBlips()
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

function loadWaypointBlips(waypointCoords)
    deleteWaypointBlips()
    waypoints = {}

    for i = 1, #waypointCoords - 1 do
        print(waypointCoords[i].x)
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

function restoreBlips()
    for i = 1, #waypoints do
        SetBlipDisplay(waypoints[i].blip, 2)
    end
end

--Grids
local gridSeparation <const> = 5

local gridCheckpoints = {}
local sologridCheckpoint = {}

function CreateGridCheckpoint(position, gridNumber)

    gridCheckpoint = CreateCheckpoint(45,
        position.x, position.y, position.z - gridRadius / 2.0,
        position.x, position.y, position.z,
        gridRadius,
        0, 255, 0,
        127, gridNumber)

    SetCheckpointCylinderHeight(gridCheckpoint, 10.0, 10.0, gridRadius * 2.0)

    return gridCheckpoint
end

function DeleteGridCheckPoints()
    print("Deleting grid")
    for _, checkpoint in pairs(gridCheckpoints) do
        DeleteCheckpoint(checkpoint)
    end

    for k in next, gridCheckpoints do rawset(gridCheckpoints, k, nil) end
end