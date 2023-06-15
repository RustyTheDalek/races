function loadJson(path)
    local string = LoadResourceFile(GetCurrentResourceName(), path)
    return json.decode(string)
end