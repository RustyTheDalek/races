FileManager = {

}

function FileManager:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function FileManager:SaveRacesFile(filename, data, length)
    if (length == nil) then length = -1 end
    return toBoolean(SaveResourceFile(GetCurrentResourceName(), filename, data, length))
end

function FileManager:SaveRacesFileJson(filename, data, length)
    return self:SaveRacesFile(filename .. '.json', json.encode(data), length)
end

function FileManager:LoadRacesFile(filename)
    return LoadResourceFile(GetCurrentResourceName(), filename)
end

function FileManager:LoadRacesFileJson(filename)
    return json.decode(self:LoadRacesFile(filename .. '.json'))
end

function FileManager:createFileIfEmpty(fileName)
    if self:LoadRacesFile(fileName) == nil then
        self:SaveRacesFile(fileName, {})
    end
end