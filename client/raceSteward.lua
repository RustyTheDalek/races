--Script for managing the actual race logic
RaceSteward = {
    isRacing = false,
    currentWaypoint = 0,
    waypoints = {
        { x=0, y=0, z=0},
        { x=200, y=0, z=200}
    }
}

function RaceSteward:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

-- TriggerServerEvent("races:init")

local function notifyPlayer(msg)
    sendChatLog(msg, "racer")
end