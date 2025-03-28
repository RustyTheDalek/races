local RaceConfig = require 'shared/config/raceConfig'

local VehicleManager = {
    currentVehicle = nil,
    vehicleList = {},
    vehicleBlips = {},
}

-- Initialize vehicle manager
function VehicleManager:init()
    self.currentVehicle = nil
    self.vehicleList = {}
    self.vehicleBlips = {}
end

-- Spawn a vehicle for the player
function VehicleManager:spawnVehicle(vehicleModel)
    -- Delete existing vehicle if any
    self:deleteCurrentVehicle()
    
    -- Request the model
    local modelHash = GetHashKey(vehicleModel)
    RequestModel(modelHash)
    
    -- Wait for model to load
    while not HasModelLoaded(modelHash) do
        Wait(1)
    end
    
    -- Get player position and heading
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    
    -- Spawn the vehicle
    self.currentVehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, false)
    
    -- Set vehicle properties
    SetEntityAsMissionEntity(self.currentVehicle, true, true)
    SetVehicleOnGroundProperly(self.currentVehicle)
    SetVehicleDoorsLocked(self.currentVehicle, 0)
    
    -- Put player in vehicle
    SetPedIntoVehicle(playerPed, self.currentVehicle, -1)
    
    -- Set vehicle mods (if any)
    self:applyVehicleMods()
    
    return self.currentVehicle
end

-- Delete current vehicle
function VehicleManager:deleteCurrentVehicle()
    if self.currentVehicle then
        DeleteEntity(self.currentVehicle)
        self.currentVehicle = nil
    end
end

-- Apply vehicle modifications
function VehicleManager:applyVehicleMods()
    if not self.currentVehicle then return end
    
    -- Example mods (customize as needed)
    SetVehicleModKit(self.currentVehicle, 0)
    SetVehicleMod(self.currentVehicle, 11, 3, false) -- Engine
    SetVehicleMod(self.currentVehicle, 12, 2, false) -- Brakes
    SetVehicleMod(self.currentVehicle, 13, 2, false) -- Transmission
    SetVehicleMod(self.currentVehicle, 16, 4, false) -- Armor
end

-- Create blip for vehicle
function VehicleManager:createVehicleBlip()
    if not self.currentVehicle then return end
    
    -- Remove existing blip if any
    self:removeVehicleBlip()
    
    -- Create new blip
    local blip = AddBlipForEntity(self.currentVehicle)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, RaceConfig.BLIP.ROUTE_COLOR)
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Race Vehicle")
    EndTextCommandSetBlipName(blip)
    
    self.vehicleBlips[self.currentVehicle] = blip
end

-- Remove vehicle blip
function VehicleManager:removeVehicleBlip()
    if self.currentVehicle and self.vehicleBlips[self.currentVehicle] then
        RemoveBlip(self.vehicleBlips[self.currentVehicle])
        self.vehicleBlips[self.currentVehicle] = nil
    end
end

-- Get current vehicle
function VehicleManager:getCurrentVehicle()
    return self.currentVehicle
end

-- Set vehicle list for custom class races
function VehicleManager:setVehicleList(vehicles)
    self.vehicleList = vehicles
end

-- Get random vehicle from list
function VehicleManager:getRandomVehicle()
    if #self.vehicleList == 0 then
        return RaceConfig.DEFAULTS.VEHICLE
    end
    return self.vehicleList[math.random(#self.vehicleList)]
end

-- Initialize the vehicle manager
VehicleManager:init()

return VehicleManager 