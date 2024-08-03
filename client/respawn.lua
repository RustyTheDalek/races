Respawn = {
    lobbyPosition = nil,
    lobbyHeading = nil,
    respawnPosition = nil,
    respawnHeading = nil,
    respawnTimer = 500,
    raceVehicleHash = nil,
    raceVehicleName = nil,
    vehicle = nil,
    respawnLock = false,
    respawnCtrlPressed = false, -- flag indicating if respawn crontrol is pressed
    respawnTime = -1,           -- time when respawn control pressed
    ghosting = nil
}

function Respawn:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Respawn:InjectGhosting(ghosting)
    self.ghosting = ghosting
end

function Respawn:SetLobbySpawn(lobbySpawn)
    self.lobbyPosition = lobbySpawn
    self.lobbyHeading = lobbySpawn.heading    
    self:ResetRespawn()
end

function Respawn:SetRespawnPosition(newPosition)
    self.respawnPosition = newPosition
end

function Respawn:SetRespawnHeading(newHeading)
    self.respawnHeading = newHeading
end

function Respawn:ResetRespawn()
    self.respawnPosition = self.lobbyPosition
    self.respawnHeading = self.lobbyHeading
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

function Respawn:Update(player, currentTime)
    if IsEntityDead(player) then
        Respawn:UpdateCurrentVehicle(player)
        self:Revive(player)
        Citizen.Wait(0)
        self:Respawn()
        return
    end

    self:Input(player, currentTime)

end

function Respawn:Input(player, currentTime)

    if (RaceState() == racingStates.RaceCountdown or RaceState() == racingStates.Joining) then return end

    self:IsRespawnPressed(player, currentTime)

    if IsControlJustReleased(0, 19) then
        self.respawnLock = false
    end
end

function Respawn:IsRespawnPressed(player, currentTime)
    if not IsControlPressed(0, 19) then -- X key or A button or cross button
        self:ClearRespawnIndicator()
        self.respawnCtrlPressed = false
        return
    end

    --If starting to press but not currently pressing it
    if self.respawnCtrlPressed == false and self.respawnLock == false then
        self:SetRespawnIndicator(self.respawnTimer / 1000)
        self.respawnCtrlPressed = true
        self.respawnTime = currentTime
        return
    end

    if self.respawnCtrlPressed and currentTime - self.respawnTime > self.respawnTimer then
        self.respawnCtrlPressed = false
        self.respawnLock = true
        self:Respawn(player)
    end
end

function Respawn:Revive(player)
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
    local player = PlayerPedId()

    if (self.vehicle == nil) then
        self:UpdateCurrentVehicle(player)
    end

    self:ClearRespawnIndicator()
    local passengers = getVehiclePassenegers(self.vehicle)
    
    if (self.vehicle ~= 0) then
        repairVehicle(self.vehicle)
    elseif self.vehicle == 0 and self.raceVehicleHash ~= nil and self.raceVehicleHash ~= 0 then
        self.vehicle = self:RespawnWithNewVehicle(player, passengers)
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

    if(RaceType() ~= nil and RaceType() ~= "" and RaceType() ~= 'ghost') then
        self.ghosting:StartGhostingDefault()
    end

end

function Respawn:RespawnWithNewVehicle(player, passengers)
    if (CarTierUIActive()) then
        return self:RespawnWithCarTier()
    else
        return self:RespawnWithRaces(player, passengers)
    end
end

function Respawn:RespawnWithCarTier()
    vehicle = exports.CarTierUI:RequestVehicle(self.raceVehicleName)
    self.raceVehicleHash = GetEntityModel(vehicle)
    return vehicle
end

function Respawn:RespawnWithRaces(player, passengers)
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

function Respawn:SetRespawnIndicator(time)
    SendNUIMessage({
        type = 'leaderboard',
        action = 'set_respawn',
        time = time
    })
end

function Respawn:ClearRespawnIndicator()
    SendNUIMessage({
        type = 'leaderboard',
        action = 'clear_respawn'
    })
end
