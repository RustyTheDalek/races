Timer = {
    active = false,
    complete = false,
    startTime = 0, --Timer for how long you've been ghosting
    length = 0,
}

-- Derived class method new
function Timer:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Timer:Start(length)
    self.active = true
    self.complete = false
    self.startTime = GetGameTimer()
    self.length = length
end

function Timer:Pause()
    self.active = false
end

function Timer:Stop()
    self.active = false
    self.complete = false
    self.startTime = 0
    self.length = 0
end

function Timer:Update()
    if self.active ~= true then
        return
    end

    self.length = self.length - GetFrameTime() * 1000
    
    if self.length <= 0 then
        self.active = false
        self.complete = true
        self.length = 0
    end

end
