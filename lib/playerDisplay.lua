local defaultBlip <const> = 2
local defaultPlayerBlip <const> = 6

local defaultRacerBlipColor <const> = 0   -- white
local racerBehindBlipColor  <const> = 1   -- red
local racerAheadBlipColor   <const> = 2    -- green

local racerSprite <const> = 1 -- circle

PlayerDisplay = {
    players = {}    -- players[netId] = { blip, nameTag, playerName } 
}

function PlayerDisplay:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function PlayerDisplay:AddBlip(ped, playerName)

    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, racerSprite)

    local blipColour = defaultRacerBlipColor
    if(playerName == 'Rusty') then
        blipColour = 27
    end

    SetBlipColour(blip, blipColour)
    SetBlipAsShortRange(blip, false)
    SetBlipDisplay(blip, 8)

    return blip
end

function PlayerDisplay:AddNameTag(ped, playerName)

    local hudColour = 0
    if(playerName == 'Rusty') then
        hudColour = 49
    end
    local gamerTag = CreateFakeMpGamerTag(ped, playerName, false, false, nil, 0)
    SetMpGamerTagColour(gamerTag, 0, hudColour)
    SetMpGamerTagVisibility(gamerTag, 0, true)
    return gamerTag
end

function PlayerDisplay:GetPedFromPlayer(source)

    local player = GetPlayerFromServerId(source)

    if(player == -1) then
        print("No Player yet, waiting for range")
        return -1
    end

    Citizen.Wait(1000)

    local ped = GetPlayerPed(player)

    if(ped == 0) then
        print("No Ped yet, waiting for range")
        return -1
    end

    return ped
end

function PlayerDisplay:UpdateRacerDisplay(racePositions, position)
    for racerPosition, source in ipairs(racePositions) do
        if source == GetPlayerServerId(PlayerId()) then
            PlayerDisplay:SetOwnRacerBlip(position)
        else
            PlayerDisplay:SetOtherRacerBlip(racerPosition, source, position)
        end
    end
end

function PlayerDisplay:SetOwnRacerBlip(position)
    SetBlipSprite(GetMainPlayerBlipId(), racerSprite)
    SetBlipColour(GetMainPlayerBlipId(), defaultRacerBlipColor)

    if(position ~= nil and position ~= -1) then
        ShowNumberOnBlip(GetMainPlayerBlipId(), position)
    end
end

function PlayerDisplay:ResetOwnRaceBlip()
    SetBlipSprite(GetMainPlayerBlipId(), defaultPlayerBlip)
    SetBlipColour(GetMainPlayerBlipId(), defaultRacerBlipColor)
    HideNumberOnBlip(GetMainPlayerBlipId())
end

function PlayerDisplay:ResetRaceBlips()
    self:ResetOwnRaceBlip()

    for _, playerDisplay in pairs(self.players) do
        SetBlipSprite(playerDisplay.blip, defaultBlip)
        SetBlipColour(playerDisplay.blip, defaultRacerBlipColor)
        HideNumberOnBlip(playerDisplay.blip)
    end
end

function PlayerDisplay:SetOtherRacerBlip(racerPosition, source, racePosition)
    local blip = self.players[source].blip
    SetBlipSprite(blip, racerSprite)
    local blipColour = defaultRacerBlipColor

    if(source ~= GetPlayerServerId(PlayerId())) then
        if(racerPosition <= racePosition) then
            blipColour = racerAheadBlipColor
        else
            blipColour = racerBehindBlipColor
        end
    end

    SetMpGamerTagName(self.players[source].nameTag, ("%i.%s"):format(racerPosition, self.players[source].playerName))
    SetBlipColour(blip, blipColour)
    ShowNumberOnBlip(blip, racerPosition)
    self.players[source].blip = blip
end

function PlayerDisplay:AddDisplay(source, playerName)

    if self.players[source] ~= nil then
        print(("playerDisplay already exist for Source:%i"):format(source))
        return
    end

    local ped = PlayerDisplay:GetPedFromPlayer(source)
    local blip = -1
    local nameTag = -1

    if (ped > 0) then
        blip = self:AddBlip(ped, playerName)
        nameTag = self:AddNameTag(ped, playerName)

        self.players[source] = { blip = blip, nameTag = nameTag, playerName = playerName }
    end
end

function PlayerDisplay:RemoveDisplay(source)

    if self.players[source] == nil then
        print(("playerDisplay doesn't exist for Source:%s"):format(source))
        return
    end

    RemoveBlip(self.players[source].blip)
    RemoveMpGamerTag(self.players[source].nameTag)
    self.players[source] = nil
end
