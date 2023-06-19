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

function GenerateStartingGrid(startWaypoint, totalGridPositions)
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
