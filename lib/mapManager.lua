local defaultMap = ""

RacesMapManager = {
    maps = {}
}

-- Derived class method new
function RacesMapManager:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function RacesMapManager:LoadConfig(config)
    defaultMap = config['defaultMap']
    self:Initalise()
end

function RacesMapManager:Initalise()
    print("Initalising")
    self.maps = exports.mapmanager:getMaps()
    self:SendMapData()
end

function RacesMapManager:UnloadMaps()
    print("Unloading Maps")
    for index, value in pairs(self.maps) do
        self:UnloadMap(self.maps)
    end
end

function RacesMapManager:UnloadMap(mapName)
    print(("Attempting unload of map %s"):format(mapName))
    if(mapName ~= defaultMap and self.maps[mapName] ~= nil and GetResourceState(mapName) == 'started') then 
        StopResource(mapName) 
    end
end

function RacesMapManager:LoadMap(mapName)
    print(("Attempting to load %s"):format(mapName))
    
    if(self.maps[mapName] ~= nil) then
        StartResource(mapName)
    else
        print("No map loaded by that name")
    end
end

function RacesMapManager:SendMapData()
    print("Sending map data")
    TriggerClientEvent("races:sendmapdata", -1, self.maps)
end

RegisterNetEvent("races:sendmapdata")
AddEventHandler("races:sendmapdata", function(maps)
    print("Recieving Map data")
    SendNUIMessage({
        type = "race_management",
        action = "send_maps",
        maps = maps
    })
end)