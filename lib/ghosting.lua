local lowGhostingAlpha = 0
local highGhostingAlpha = 0
local ghostingTimeoutSoundStart = 0 -- At what time remaining does the Ghosting warning sound start

Ghosting = {
    active = false,
    length = 0,
    ghostedAlpha = 0,
    timer = Timer:new(),
    flickerTimer = Timer:new()
}

function Ghosting:new (o, configData)
    o = o or {}
    setmetatable(o, self)

    if(configData~= nil) then
        lowGhostingAlpha = configData['lowGhostingAlpha']
        highGhostingAlpha = configData['highGhostingAlpha']
        ghostingTimeoutSoundStart = configData['ghostingTimeoutSoundStart']
    end

    self.__index = self
    return o
end

function Ghosting:StartGhosting(newLength)
    if(self.active == true and newLength < self.length) then
        print("Ignoring ghosting, already happening")
        return
    end

    self.length = newLength
    self.timer:Start(newLength)
    self.flickerTimer:Start(newLength / 2)

    self.active = true
    SetLocalPlayerAsGhost(true)
    self.ghostedAlpha = lowGhostingAlpha
    SetGhostedEntityAlpha(lowGhostingAlpha)

    SendNUIMessage({
        type = "leaderboard",
        action = "set_ghosting",
        source = GetPlayerServerId(PlayerId()),
        time = newLength / 1000
    })
end

function Ghosting:StopGhosting()
    PlaySoundFrontend(-1, "CONFIRM_BEEP", "HUD_MINI_GAME_SOUNDSET", true)

    ResetGhostedEntityAlpha()
    SetLocalPlayerAsGhost(false)

    self.active = false
    self.ghostedAlpha = 0
    self.length = 0
    self.timer:Stop()
    self.flickerTimer:Stop()
end

function Ghosting:Update(currentTime, player)
    if(self.active ~= true) then
        return
    end

    self.timer:Update()
    self.flickerTimer:Update()

    if(self.timer.complete) then
        print("Ghosting complete")
        self.flickerTimer:Stop()
        self:StopGhosting()
    end

    if(self.flickerTimer.complete) then 

        print("Toggling Flicker")
        local newGhostingAlpha

        if(self.ghostedAlpha == lowGhostingAlpha) then
            newGhostingAlpha = highGhostingAlpha
        else
            newGhostingAlpha = lowGhostingAlpha
        end

        SetGhostedEntityAlpha(newGhostingAlpha)
        TriggerServerEvent('setplayeralpha', player, newGhostingAlpha)
        self.flickerTimer:Start(self.timer.length / 2)
    end

    local roundedTimer = round(self.timer.length, 0)

    if(roundedTimer <= ghostingTimeoutSoundStart and math.fmod(roundedTimer, 1000) <= 5 and math.fmod(roundedTimer, 1000) > 0 ) then
        PlaySoundFrontend(-1, "3_2_1", "HUD_MINI_GAME_SOUNDSET", true)
    end
end