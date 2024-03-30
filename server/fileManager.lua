FileManager = {

}

function FileManager:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function FileManager:SaveCurrentResourceFile(filename, data, length)
    if (length == nil) then length = -1 end
    return toBoolean(SaveResourceFile(GetCurrentResourceName(), filename, data, length))
end

function FileManager:SaveCurrentResourceFileJson(filename, data, length)
    return self:SaveCurrentResourceFile(filename .. '.json', json.encode(data), length)
end

function FileManager:LoadCurrentResourceFile(filename)
    return LoadResourceFile(GetCurrentResourceName(), filename)
end

function FileManager:LoadCurrentResourceFileJson(filename)
    return json.decode(self:LoadCurrentResourceFile(filename .. '.json'))
end

function FileManager:CreateFileIfEmpty(fileName)
    if self:LoadCurrentResourceFile(fileName) == nil then
        self:SaveCurrentResourceFile(fileName, {})
    end
end