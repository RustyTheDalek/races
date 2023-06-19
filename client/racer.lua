racer = {}

racer.isRacing = false

local startIsFinish = false               -- flag indicating if start and finish are same waypoint
local currentWaypoint = 0

local waypoints = {
    { x=0, y=0, z=0},
    { x=200, y=0, z=200}
}

math.randomseed(GetCloudTimeAsInt())

exports.spawnmanager:setAutoSpawnCallback(function()
    if isRacing == true then
        print("In race, spawning at race")
        local coord = startCoord
        if startIsFinish == true then
            if currentWaypoint > 0 then
                coord = waypoints[currentWaypoint].coord
            end
        else
            if currentWaypoint > 1 then
                coord = waypoints[currentWaypoint - 1].coord
            end
        end

        exports.spawnmanager:spawnPlayer({
            x = coord.x,
            y = coord.y,
            z = coord.z,
            heading = coord.heading,
            skipFade = true
        })
    else

        print("Not in Race, spawning at airport")
        exports.spawnmanager:spawnPlayer({
            x = -1437.03,
            y = -2993.15,
            z = 13.94,
            heading = 222.93,
            skipFade = true
        })

    end

    SetManualShutdownLoadingScreenNui(true)
end)
exports.spawnmanager:setAutoSpawn(true)

TriggerServerEvent("races:init")

local function notifyPlayer(msg)
    sendChatLog(msg, "racer")
end

print("Racer loaded")

return racer