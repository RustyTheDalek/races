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
    setmetatable(o, self)
    self.__index = self
    return o
end
