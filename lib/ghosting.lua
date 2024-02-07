local lowGhostingAlpha = 0
local highGhostingAlpha = 0
local ghostingTimeoutStart = 0 -- At what time to start indicating that ghosting is running out
local flickerInterval = 0

Ghosting = {
    active = false,
    length = 0,
    currentGhostedAlpha = 0,
    timer = Timer:New(),
    flickerTimer = Timer:New()
}

function Ghosting:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Ghosting:LoadConfig(configData)
    if(configData~= nil) then
        lowGhostingAlpha = configData['lowGhostingAlpha']
        highGhostingAlpha = configData['highGhostingAlpha']
        ghostingTimeoutStart = configData['ghostingTimeoutStart']
        flickerInterval = configData['flickerInterval']
    end
end

function Ghosting:StartGhostingNoTimer()

    SendNUIMessage({
        type = "leaderboard",
        action = "set_ghosting",
        source = GetPlayerServerId(PlayerId())
    })

    self.active = true
    self.length = 0
    SetLocalPlayerAsGhost(true)
    self.currentGhostedAlpha = lowGhostingAlpha
    SetGhostedEntityAlpha(lowGhostingAlpha)
    TriggerServerEvent('ghosting:setplayeralpha', lowGhostingAlpha)

end

function Ghosting:StartGhosting(newLength)

    if(self.active == true and newLength < self.length) then
        print("Ignoring ghosting, already happening")
        return
    end

    SendNUIMessage({
        type = "leaderboard",
        action = "set_ghosting",
        source = GetPlayerServerId(PlayerId()),
        time = newLength / 1000
    })

    self.length = newLength
    self.timer:Start(newLength)

    self.active = true
    SetLocalPlayerAsGhost(true)
    self.currentGhostedAlpha = lowGhostingAlpha
    SetGhostedEntityAlpha(lowGhostingAlpha)
    TriggerServerEvent('ghosting:setplayeralpha', lowGhostingAlpha)
end

function Ghosting:StopGhosting()
    PlaySoundFrontend(-1, "CONFIRM_BEEP", "HUD_MINI_GAME_SOUNDSET", true)

    SetGhostedEntityAlpha(254)
    SetLocalPlayerAsGhost(false)
    ResetGhostedEntityAlpha()

    SendNUIMessage({
        type = "leaderboard",
        action = "clear_ghosting",
        source = GetPlayerServerId(PlayerId())
    })

    self.active = false
    self.currentGhostedAlpha = 0
    self.length = 0
    self.timer:Stop()
    self.flickerTimer:Stop()
end

function Ghosting:Update()

    if(self.active ~= true or self.length == 0) then
        return
    end

    self.timer:Update()
    self.flickerTimer:Update()

    if(self.timer.complete) then
        self:StopGhosting()
        return
    end

    if(self.flickerTimer.complete) then

        PlaySoundFrontend(-1, "3_2_1", "HUD_MINI_GAME_SOUNDSET", true)
        print("Toggling Flicker")
        local newGhostingAlpha = nil

        if(self.currentGhostedAlpha == lowGhostingAlpha) then
            newGhostingAlpha = highGhostingAlpha
            TriggerServerEvent('ghosting:setplayeralpha', 150)
        else
            newGhostingAlpha = lowGhostingAlpha
            TriggerServerEvent('ghosting:setplayeralpha', 50)
        end

        self.currentGhostedAlpha = newGhostingAlpha
        SetGhostedEntityAlpha(newGhostingAlpha)
        self.flickerTimer:Start(flickerInterval)
    end

    if(self.timer.length <= ghostingTimeoutStart and not self.flickerTimer.active) then
        self.flickerTimer:Start(flickerInterval)
    end
end

RegisterNetEvent("ghosting:setplayeralpha")
AddEventHandler("ghosting:setplayeralpha", function(alphaValue)
    SetGhostedEntityAlpha(alphaValue)
end)