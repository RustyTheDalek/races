function safeLoadJson(path)
    if loadJson(path) == nil then
        print(SaveResourceFile(GetCurrentResourceName(), path, {}, -1))
    end
end

function loadJson(path)
    local string = LoadResourceFile(GetCurrentResourceName(), path)
    return json.decode(string)
end