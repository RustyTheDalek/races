local deltaFrames = 0
local deltaTime = 0

local currentTime = 0
local currentFrames = 0

FPSMonitor = {
    active = false,
    fps = 0,
    trackingAverage = false,
    averageFPSChunk = {},   -- Tracks current Average FPS
    averageFPSTotals = {}   -- Tracks Average FPS chunks over time
}

function FPSMonitor:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function FPSMonitor:StartTracking()
    Citizen.CreateThread(function()
        self:Update()
    end)
end

function FPSMonitor:StopTracking()
    self.active = false
end

function FPSMonitor:StartTrackingAverage()
    self.averageFPS = {}
    self.trackingAverage = true
end

function FPSMonitor:SaveAverageChunk()
    local chunkAverage = self:GetAverageFPS()
    table.insert(self.averageFPSTotals, chunkAverage)
    self.averageFPSChunk = {}
end

function FPSMonitor:StopTrackingAverage()
    self:SaveAverageChunk()

    local fpsTotal = 0
    for index, fps in pairs(self.averageFPSTotals) do
        fpsTotal = fpsTotal + fps
    end

    return fpsTotal / #self.averageFPSTotals

end

function FPSMonitor:GetAverageFPS()
    local fpsTotal = 0
    for index, fps in pairs(self.averageFPSChunk) do
        fpsTotal = fpsTotal + fps
    end

    return fpsTotal / #self.averageFPSChunk
end

function FPSMonitor:Update()
    while self.active do
        Citizen.Wait(250)
        deltaFrames = GetFrameCount()
        deltaTime = GetGameTimer()
    end

    while self.active do
        currentTime = GetGameTimer()
        currentFrames = GetFrameCount()

        if ((currentTime - deltaTime) > 1000) then
            self.fps = (currentFrames - deltaFrames) - 1

            if (self.trackingAverage) then
                table.insert(self.averageFPSChunk, self.fps)
            end

            deltaTime = currentTime
            deltaFrames = currentFrames
        end

        if self.fps >= 0 then
            print(("FPS:%i"):format(self.fps))
        end

        if self.trackingAverage and #self.averageFPSChunk > 0 then
            print(("Average FPS:%i"):format(self:GetAverageFPS()))
        end
        Citizen.Wait(1)
    end
end
