local GHOSTING_IDLE <const> = 0
local GHOSTING_DOWN <const> = 1
local GHOSTING_UP <const> = 2

local GHOSTING_DEFAULT <const> = 3000 --Default Ghosting Length
local GHOSTING_RACE_START <const> = 30000

Ghosting = {
    ghostState = GHOSTING_IDLE,
    ghosting = false,
    ghostingTime = 0, --Timer for how long you've been ghosting
    ghostingMaxTime = GHOSTING_DEFAULT,
    ghostingInterval = 0.0,  --Timer for the animation of ghosting
    ghostingInternalMaxTime = 0.25 --How quickly alpha values animates (s)
}

-- Derived class method new
function Ghosting:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Ghosting:SetGhosting(_ghosting)
    self.ghosting = _ghosting
    SetLocalPlayerAsGhost(_ghosting)
    if self.ghosting == true then
        self.ghostState = GHOSTING_UP
        self.ghostingTime = GetGameTimer()
        self.ghostingInternalMaxTime = .5
        SendNUIMessage({
            type = "leaderboard",
            action = "set_ghosting",
            source = GetPlayerServerId(PlayerId()),
            time = self.ghostingMaxTime / 1000
        })
    else
        self.ghostingMaxTime = GHOSTING_DEFAULT
        self.ghostState = GHOSTING_IDLE
        self.ghostingInterval = 0.0
        self.ghostingTime = 0
    end
end

function Ghosting:SetGhostingOverride(_ghosting, ghostingTime)
    self.ghostingMaxTime = ghostingTime
    self:SetGhosting(_ghosting)
end

function Ghosting:SetGhostingRaceStart()
    self.ghostingMaxTime = GHOSTING_RACE_START
    self:SetGhosting(true)
end


function Ghosting:ResetGhostingOverride()
    self.ghostingMaxTime = GHOSTING_DEFAULT
end

function Ghosting:CalculateGhostingInterval(ghostingDifference)
    return lerp(0.5, 0.1, ghostingDifference / self.ghostingMaxTime)
end

function Ghosting:Update(currentTime, player)
    if self.ghosting == true then
        local ghostingDifference = currentTime - self.ghostingTime
        local deltaTime = GetFrameTime()

        if self.ghostState == GHOSTING_UP then
            if (self.ghostingInterval >= self.ghostingInternalMaxTime) then
                SetGhostedEntityAlpha(128)
                TriggerServerEvent('setplayeralpha', player, 150)
                self.ghostState = GHOSTING_DOWN
                self.ghostingInternalMaxTime = self:CalculateGhostingInterval(self.ghostingInterval)
                self.ghostingInterval = self.ghostingInternalMaxTime
            else
                self.ghostingInterval = self.ghostingInterval + deltaTime
            end
        elseif self.ghostState == GHOSTING_DOWN then
            if (self.ghostingInterval <= 0) then
                SetGhostedEntityAlpha(50)
                TriggerServerEvent('setplayeralpha', player, 50)
                self.ghostState = GHOSTING_UP
                self.ghostingInternalMaxTime = self:CalculateGhostingInterval(self.ghostingInterval)
                self.ghostingInterval = 0
            else
                self.ghostingInterval = self.ghostingInterval - deltaTime
            end
        end

        local ghostingRemaining = self.ghostingMaxTime - ghostingDifference
        --1000 = every second 
        if ghostingRemaining <= 5000 and ghostingRemaining >= 1000 and math.fmod(ghostingRemaining, 1000) <= 5 then
            PlaySoundFrontend(-1, "3_2_1", "HUD_MINI_GAME_SOUNDSET", true)
        end

        SetGhostedEntityAlpha(self.ghostingInterval * 254)
        if ghostingDifference > self.ghostingMaxTime then
            self:SetGhosting(false)
            PlaySoundFrontend(-1, "CONFIRM_BEEP", "HUD_MINI_GAME_SOUNDSET", true)
        end
    else
        self:SetGhosting(false)
    end
end