Respawn = {
    respawnPosition = nil,
    respawnTimer = 500,
    respawnHeading = nil,
    raceVehicleHash = nil,
    raceVehicleName = nil,
    vehicle = nil
}

function Respawn:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Respawn:SetRespawnPosition(newPosition)
    self.respawnPosition = newPosition
end

function Respawn:SetRespawnHeading(newHeading)
    self.respawnHeading = newHeading
end

function Respawn:UpdateRaceVehicle(raceVehicleHash, raceVehicleName)
    self.raceVehicleHash = raceVehicleHash
    self.raceVehicleName = raceVehicleName
end

function Respawn:UpdateCurrentVehicle(player)
    local currentVehicle = GetVehiclePedIsIn(player, true)
    local lastVehicle = GetVehiclePedIsIn(player, false)
    self.vehicle = currentVehicle ~= 0 and currentVehicle or lastVehicle
end

function Respawn:Update(player)
    if IsEntityDead(player) then
        Respawn:UpdateCurrentVehicle(player)
        self:Revive(player)
        Citizen.Wait(0)
        self:Respawn()
    end
end

function Respawn:Revive(player)
    print("Reviving")
    local playerPos = GetEntityCoords(player)
    local heading = GetEntityHeading(player)
    NetworkResurrectLocalPlayer(playerPos, heading, false, false) 
    SetPlayerInvincible(player, false)
    ClearPedBloodDamage(player)
end

function Respawn:TeleportToRespawnPosition(entity)
    SetEntityCoordsVector3(entity, self.respawnPosition)
    SetEntityHeading(entity, self.respawnHeading)
end

function Respawn:Respawn()
    print("Respawning")

    local player = PlayerPedId()

    if (self.vehicle == nil) then
        self:UpdateCurrentVehicle(player)
    end

    self:ClearRespawnIndicator()
    local passengers = getVehiclePassenegers(self.vehicle)

    print(("Vehicle: %i"):format(self.vehicle))
    
    if (self.vehicle ~= 0) then
        print("Using previous vehicle found")
        repairVehicle(self.vehicle)
    elseif self.vehicle == 0 and self.raceVehicleHash ~= nil then
        self.vehicle = self:RespawnWithNewVehicle(player, passengers)
    else
        print("Respawning on foot")
        self:TeleportToRespawnPosition(player)
    end
    
    local entityToMove = player
    if(self.vehicle ~= nil and self.vehicle ~= 0) then
        SetPedIntoVehicle(player, self.vehicle, -1)
        SetVehicleOnGroundProperly(self.vehicle)
        SetVehicleEngineOn(self.vehicle, true, true, false)
        SetVehRadioStation(self.vehicle, "OFF")
        entityToMove = self.vehicle
    end

    self:TeleportToRespawnPosition(entityToMove)

    self.vehicle = nil
end

function Respawn:RespawnWithNewVehicle(player, passengers)
    if (CarTierUIActive()) then
        return self:RespawnWithCarTier()
    else
        return self:RespawnWithRaces(player, passengers)
    end
end

function Respawn:RespawnWithCarTier()
    print("carTierSpawn")
    vehicle = exports.CarTierUI:RequestVehicle(self.raceVehicleName)
    print("Car tier done")
    self.raceVehicleHash = GetEntityModel(vehicle)
    return vehicle
end

function Respawn:RespawnWithRaces(player, passengers)
    print("No vehicle found")
    print(self.raceVehicleName)
    RequestModel(self.raceVehicleName)
    while HasModelLoaded(self.raceVehicleName) == false do
        Citizen.Wait(0)
    end
    vehicle = putPedInVehicle(player, self.raceVehicleName, self.respawnPosition)
    SetEntityAsNoLongerNeeded(vehicle)
    SetEntityHeading(vehicle, self.respawnHeading)
    repairVehicle(vehicle)
    for _, passenger in pairs(passengers) do
        SetPedIntoVehicle(passenger.ped, vehicle, passenger.seat)
    end
    return vehicle
end

function Respawn:ClearRespawnIndicator()
    SendNUIMessage({
        type = 'leaderboard',
        action = 'clear_respawn'
    })
end
