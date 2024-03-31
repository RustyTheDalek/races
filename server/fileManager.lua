FileManager = {}

FileManager.SaveCurrentResourceFile = function(filename, data, length)
    if (length == nil) then length = -1 end
    return toBoolean(SaveResourceFile(GetCurrentResourceName(), filename, data, length))
end

FileManager.SaveCurrentResourceFileJson = function(filename, data, length)
    return FileManager.SaveCurrentResourceFile(filename .. '.json', json.encode(data), length)
end

FileManager.LoadCurrentResourceFile = function(filename)
    return LoadResourceFile(GetCurrentResourceName(), filename)
end

FileManager.LoadCurrentResourceFileJson = function(filename)
    return json.decode(FileManager.LoadCurrentResourceFile(filename .. '.json'))
end

FileManager.CreateFileIfEmpty = function(fileName)
    if FileManager.LoadCurrentResourceFile(fileName) == nil then
        FileManager.SaveCurrentResourceFile(fileName, {})
    end
end