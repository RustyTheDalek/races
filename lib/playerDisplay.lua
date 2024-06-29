local defaultBlip <const> = 2
local defaultPlayerBlip <const> = 6

local defaultRacerBlipColor <const> = 0   -- white
local racerBehindBlipColor  <const> = 1   -- red
local racerAheadBlipColor   <const> = 2    -- green

local racerSprite <const> = 1 -- circle

local gamerTagInfix = ""

PlayerDisplay = {
    players = {}    -- players[netId] = { blip, nameTag, playerName } 
}

function PlayerDisplay:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function PlayerDisplay:LoadConfig(configData)
    if(configData~= nil) then
        gamerTagInfix = configData['raceDisplay']['gamerTagInfix']
    end
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

    local ped = GetPlayerPed(player)

    if(ped == 0) then
        print("No Ped yet, waiting for range")
        return -1
    end

    return ped
end

function PlayerDisplay:UpdateRacerDisplay(racePositions, position)
    for racerPosition, racerData in ipairs(racePositions) do
        if racerData.source == GetPlayerServerId(PlayerId()) then
            PlayerDisplay:SetOwnRacerBlip(position)
        else
            PlayerDisplay:SetOtherRacerBlip(racerPosition, racerData.source, position, racerData.playerName)
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
        SetMpGamerTagName(playerDisplay.nameTag, playerDisplay.playerName)
    end
end

function PlayerDisplay:SetOtherRacerBlip(racerPosition, source, racePosition, racerName)

    if(self.players[source] == nil or self.players[source].blip == nil ) then
        return
    end

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

    if(racerName ~= nil) then
        self.players[source].playerName = racerName
    end

    SetMpGamerTagName(self.players[source].nameTag, ("%i".. gamerTagInfix .. "%s"):format(racerPosition, self.players[source].playerName))
    SetBlipColour(blip, blipColour)
    ShowNumberOnBlip(blip, racerPosition)
    self.players[source].blip = blip
end

function PlayerDisplay:AddDisplay(source, playerName)

    print(("new player display name for Source:%i with name %s"):format(source, playerName))

    if self.players[source] ~= nil then
        print(("playerDisplay already exist for Source:%i with name %s"):format(source, self.players[source]))
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


function PlayerDisplay:UpdatePlayerNames(players)
    local ownSource = GetPlayerServerId(PlayerId())

    for _, player in pairs(players) do
        if(ownSource ~= player.source) then

            local existingPlayer = self.players[player.source]

            if(existingPlayer == nil or existingPlayer.playerName ~= player.name) then
                self:AddDisplay(player.source, player.name)
            end
        end
    end
end