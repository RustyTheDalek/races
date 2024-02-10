Timer = {
    active = false,
    complete = false,
    stopwatch = false,
    startTime = 0, --Timer for how long you've been ghosting
    length = 0,
    deltaGameTime = 0
}

-- Derived class method new
function Timer:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Timer:Start(length)
    self.active = true
    self.complete = false
    if(length == nil) then
        self.stopwatch = true
        self.length = 0
    else
        self.length = length
    end
    self.startTime = GetGameTimer()
    self.deltaGameTime = GetGameTimer()
end

function Timer:Pause()
    self.active = false
end

function Timer:Stop()
    self.active = false
    self.complete = false
    self.stopwatch = false
    self.startTime = 0
    self.length = 0
    self.deltaGameTime = 0
end

function Timer:Reset()
    self.length = 0
    self.startTime = GetGameTimer()
    self.deltaGameTime = GetGameTimer()
end

function Timer:Update()
    if self.active ~= true then
        return
    end

    if (self.stopwatch) then
        self.length = self.length + (GetGameTimer() - self.deltaGameTime)
    else
        self.length = self.length - (GetGameTimer() - self.deltaGameTime)

        if self.length <= 0 then
            self.active = false
            self.complete = true
            self.length = 0
            self.deltaGameTime = 0
        end
    end

    self.deltaGameTime = GetGameTimer()
end
