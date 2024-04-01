local defaultRadius <const> = 5.0                 -- default waypoint radius

local READY_RACERS_COUNTDOWN = 5000
local races = {} -- races[playerID] = { raceTime, state, waypointCoords[] = {x, y, z, r}, isPublic, trackName, owner, tier, laps, timeout, rtype, restrict, vclass, svehicle, vehicleList, numRacing, players[source] = {source, playerName,  numWaypointsPassed, data, coord}, results[] = {source, playerName, finishTime, bestLapTime, vehicleName}}

local racesMapManager = RacesMapManager:New()

local fxdkMode = GetConvarInt('sv_fxdkMode', 0) == 1

FileManager.CreateFileIfEmpty('raceData.json')
FileManager.CreateFileIfEmpty('vehicleListData.json')

local function getTrack(trackName)
    local track = FileManager:LoadCurrentResourceFileJson(trackName)
    if track ~= nil then
        if type(track) == "table" and type(track.waypointCoords) == "table" and type(track.bestLaps) == "table" then
            if #track.waypointCoords > 1 then
                for _, waypointCoord in ipairs(track.waypointCoords) do
                    if type(waypointCoord) ~= "table" or type(waypointCoord.x) ~= "number" or type(waypointCoord.y) ~= "number" or type(waypointCoord.z) ~= "number" or type(waypointCoord.r) ~= "number" then
                        print(
                            "getTrack: waypointCoord not a table or waypointCoord.x or waypointCoord.y or waypointCoord.z or waypointCoord.r not a number.")
                        return nil
                    end
                end
                for _, bestLap in ipairs(track.bestLaps) do
                    if type(bestLap) ~= "table" or type(bestLap.playerName) ~= "string" or type(bestLap.bestLapTime) ~= "number" or type(bestLap.vehicleName) ~= "string" then
                        print(
                            "getTrack: bestLap not a table or bestLap.playerName not a string or bestLap.bestLapTime not a number or bestLap.vehicleName not a string.")
                        return nil
                    end
                end
                return track
            else
                print("getTrack: number of waypoints is less than 2.")
            end
        else
            print("getTrack: track or track.waypointCoords or track.bestLaps not a table.")
        end
    else
        print("getTrack: Could not load track data.")
    end
    return nil
end

local function export(trackName, withBLT)
    if trackName ~= nil then
        local raceData = FileManager.LoadCurrentResourceFileJson('raceData')
        if raceData ~= nil then
            local publicTracks = raceData["PUBLIC"]
            if publicTracks ~= nil then
                if publicTracks[trackName] ~= nil then
                    local track = FileManager.LoadCurrentResourceFileJson(trackName)
                    if track == fail then
                        if false == withBLT then
                            publicTracks[trackName].bestLaps = {}
                        end
                        if true == FileManager.SaveCurrentResourceFileJson(trackName, publicTracks[trackName]) then
                            local msg = "export: Exported track '" .. trackName .. "'."
                            print(msg)
                        else
                            print("export: Could not export track '" .. trackName .. "'.")
                        end
                    else
                        file:close()
                        print("export: '" ..
                            trackFilePath .. "' exists.  Remove or rename the existing file, then export again.")
                    end
                else
                    print("export: No public track named '" .. trackName .. "'.")
                end
            else
                print("export: No public track data.")
            end
        else
            print("export: Could not load race data.")
        end
    else
        print("export: Name required.")
    end
end

local function import(trackName, withBLT)
    if trackName ~= nil then
        local raceData = FileManager.LoadCurrentResourceFileJson('raceData')
        if raceData ~= nil then
            local publicTracks = raceData["PUBLIC"] ~= nil and raceData["PUBLIC"] or {}
            if nil == publicTracks[trackName] then
                local track = getTrack(trackName)
                if track ~= nil then
                    if false == withBLT then
                        track.bestLaps = {}
                    end
                    publicTracks[trackName] = track
                    raceData["PUBLIC"] = publicTracks
                    if true == FileManager.SaveCurrentResourceFileJson('raceData', raceData) then
                        local msg = "import: Imported track '" .. trackName .. "'."
                        print(msg)
                    else
                        print("import: Could not import '" .. trackName .. "'.")
                    end
                else
                    print("import: Could not import '" .. trackName .. "'.")
                end
            else
                print("import: '" ..
                    trackName ..
                    "' already exists in the public tracks list.  Rename the file, then import with the new name.")
            end
        else
            print("import: Could not load race data.")
        end
    else
        print("import: Name required.")
    end
end

local function updateRaceData()
    local raceData = FileManager.LoadCurrentResourceFileJson('raceData')
    if raceData ~= nil then
        local update = false
        local newRaceData = {}
        for license, tracks in pairs(raceData) do
            local newTracks = {}
            for trackName, track in pairs(tracks) do
                local newWaypointCoords = {}
                for i, waypointCoord in ipairs(track.waypointCoords) do
                    local coordRad = waypointCoord
                    if nil == waypointCoord.r then
                        coordRad.r = defaultRadius
                        update = true
                    end
                    newWaypointCoords[i] = coordRad
                end
                if true == update then
                    newTracks[trackName] = { waypointCoords = newWaypointCoords, bestLaps = track.bestLaps }
                end
            end
            if true == update then
                newRaceData[license] = newTracks
            end
        end
        if true == update then
            if true == FileManager.SaveCurrentResourceFileJson('raceData_updated', newRaceData) then
                local msg = "updateRaceData: raceData.json updated to current format in 'raceData_updated.json'."
                print(msg)
            else
                print("updateRaceData: Could not update raceData.json.")
            end
        else
            print("updateRaceData: raceData.json not updated.")
        end
    else
        print("updateRaceData: Could not load race data.")
    end
end

local function updateTrack(trackName)
    if trackName ~= nil then
        local track = FileManager.LoadCurrentResourceFileJson(trackName)
        if track ~= nil then
            if type(track) == "table" and type(track.waypointCoords) == "table" and type(track.bestLaps) == "table" then
                if #track.waypointCoords > 1 then
                    local update = false
                    local newWaypointCoords = {}
                    for i, waypointCoord in ipairs(track.waypointCoords) do
                        if type(waypointCoord) ~= "table" or type(waypointCoord.x) ~= "number" or type(waypointCoord.y) ~= "number" or type(waypointCoord.z) ~= "number" then
                            print(
                                "updateTrack: waypointCoord not a table or waypointCoord.x or waypointCoord.y or waypointCoord.z not a number.")
                            return
                        end
                        local coordRad = waypointCoord
                        if nil == waypointCoord.r then
                            update = true
                            coordRad.r = defaultRadius
                        elseif type(waypointCoord.r) ~= "number" then
                            print("updateTrack: waypointCoord.r not a number.")
                            return
                        end
                        newWaypointCoords[i] = coordRad
                    end

                    if true == update then
                        for _, bestLap in ipairs(track.bestLaps) do
                            if type(bestLap) ~= "table" or type(bestLap.playerName) ~= "string" or type(bestLap.bestLapTime) ~= "number" or type(bestLap.vehicleName) ~= "string" then
                                print(
                                    "updateTrack: bestLap not a table or bestLap.playerName not a string or bestLap.bestLapTime not a number or bestLap.vehicleName not a string.")
                                return
                            end
                        end

                        if true == FileManager.SaveCurrentResourceFileJson(trackName, { waypointCoords = newWaypointCoords, bestLaps = track.bestLaps }) then
                            local msg = "updateTrack: '" ..
                                trackName .. ".json' updated to current format in '" .. trackName .. "_updated.json'."
                            print(msg)
                        else
                            print("updateTrack: Could not update track.")
                        end
                    else
                        print("updateTrack: '" .. trackName .. ".json' not updated.")
                    end
                else
                    print("updateTrack: number of waypoints is less than 2.")
                end
            else
                print("updateTrack: track or track.waypointCoords or track.bestLaps not a table.")
            end
        else
            print("updateTrack: Could not load track data.")
        end
    else
        print("updateTrack: Name required.")
    end
end

local function loadTrack(isPublic, source, trackName)
    local license = true == isPublic and "PUBLIC" or GetPlayerIdentifier(source, 0)
    if license ~= nil then
        local raceData = FileManager.LoadCurrentResourceFileJson('raceData')
        if raceData ~= nil then
            if license ~= "PUBLIC" then
                license = string.sub(license, 9)
            end
            local tracks = raceData[license]
            if tracks ~= nil then
                return tracks[trackName]
            end
        else
            notifyPlayer(source, "loadTrack: Could not load race data.\n")
        end
    else
        notifyPlayer(source, "loadTrack: Could not get license for player source ID: " .. source .. "\n")
    end
    return nil
end

local function saveTrack(isPublic, source, trackName, track)
    local license = true == isPublic and "PUBLIC" or GetPlayerIdentifier(source, 0)
    if license ~= nil then
        local raceData = FileManager.LoadCurrentResourceFileJson('raceData')
        if raceData ~= nil then
            if license ~= "PUBLIC" then
                license = string.sub(license, 9)
            end
            local tracks = raceData[license] ~= nil and raceData[license] or {}
            tracks[trackName] = track
            raceData[license] = tracks
            local saveRaceResult = FileManager.SaveCurrentResourceFileJson('raceData', raceData)
            if saveRaceResult == 1 or saveRaceResult == true then
                return true
            else
                notifyPlayer(source, "saveTrack: Could not write race data.\n")
            end
        else
            notifyPlayer(source, "saveTrack: Could not load race data.\n")
        end
    else
        notifyPlayer(source, "saveTrack: Could not get license for player source ID: " .. source .. "\n")
    end
    return false
end

local function loadVehicleList(isPublic, source, name)
    local license = true == isPublic and "PUBLIC" or GetPlayerIdentifier(source, 0)
    if license ~= nil then
        local vehicleListData = FileManager.LoadCurrentResourceFileJson('vehicleListData')
        if vehicleListData ~= nil then
            if license ~= "PUBLIC" then
                license = string.sub(license, 9)
            end
            local lists = vehicleListData[license]
            if lists ~= nil then
                return lists[name]
            end
        else
            notifyPlayer(source, "loadVehicleList: Could not load vehicle list data.\n")
        end
    else
        notifyPlayer(source, "loadVehicleList: Could not get license for player source ID: " .. source .. "\n")
    end
    return nil
end

local function saveVehicleList(isPublic, source, name, vehicleList)
    local license = true == isPublic and "PUBLIC" or GetPlayerIdentifier(source, 0)
    if license ~= nil then
        local vehicleListData = FileManager.LoadCurrentResourceFileJson('vehicleListData')
        if vehicleListData ~= nil then
            if license ~= "PUBLIC" then
                license = string.sub(license, 9)
            end
            local lists = vehicleListData[license] ~= nil and vehicleListData[license] or {}
            lists[name] = vehicleList
            vehicleListData[license] = lists
            if true == FileManager.SaveCurrentResourceFileJson('vehicleListData', vehicleListData) then
                return true
            else
                notifyPlayer(source, "saveVehicleList: Could not write vehicle list data.\n")
            end
        else
            notifyPlayer(source, "saveVehicleList: Could not load vehicle list data.\n")
        end
    else
        notifyPlayer(source, "saveVehicleList: Could not get license for player source ID: " .. source .. "\n")
    end
    return false
end

local function updateBestLapTimes(rIndex)

    if(races[rIndex] == nil) then
        print("No Race with that index")
        return
    end

    races[rIndex]:UpdateBestLapTimes(rIndex)
end


--In cases where you need to trigger a simple event for all players in a race
local function TriggerEventForRacers(raceIndex, event, ...)

    if(races[raceIndex] == nil) then
        print(("Ignoring event, no race with index %i"):format(raceIndex))
    end

    races[raceIndex]:TriggerEventForRacers(event, ...)

end

local function GenerateStartingGrid(startWaypoint, numRacers)
    local startPoint = vector3(startWaypoint.x, startWaypoint.y, startWaypoint.z)

    --Calculate the forwardVector of the starting Waypoint
    local x = -math.sin(math.rad(startWaypoint.heading)) * math.cos(0)
    local y = math.cos(math.rad(startWaypoint.heading)) * math.cos(0)
    local z = math.sin(0);
    local forwardVector = vector3(x, y, z)

    local leftVector = vector3(
        math.cos(math.rad(startWaypoint.heading)),
        math.sin(math.rad(startWaypoint.heading)),
        0.0
    )

    local gridPositions = {}

    for i = 1, numRacers do
        local gridPosition = startPoint - forwardVector * (i + 1) * gridSeparation

        if math.fmod(i, 2) == 0 then
            -- print("Right Grid")
            gridPosition = gridPosition + -leftVector * 3
        else
            -- print("Left Grid")
            gridPosition = gridPosition + leftVector * 3
        end

        table.insert(gridPositions, gridPosition)
    end

    return gridPositions
end

local function AddNewRace(waypointCoords, isPublic, trackName, owner, tier, timeout, laps, rdata)

    races[source] = RaceEvent:New({
        index = source,
        raceStart = 0,
        raceTime = 0,
        state = racingStates.Registering,
        waypointCoords = waypointCoords,
        isPublic = isPublic,
        trackName = trackName,
        owner = owner,
        tier = tier,
        specialClass = rdata.specialClass,
        laps = laps,
        timeout = timeout,
        rtype = rdata.rtype,
        restrict = rdata.restrict,
        vclass = rdata.vclass,
        svehicle = rdata.svehicle,
        vehicleList = rdata.vehicleList,
        numRacing = 0,
        numReady = 0,
        countdown = false,
        countdownTimeStart = 0,
        players = {},
        results = {},
        gridLineup = {},
        gridPositions = {},
        useRaceResults = false,
        map = rdata.map,
        checkpointTimes = {}
    })

    if(rdata.map ~= "") then
        print(("Map data, loading %s"):format(rdata.map))
        racesMapManager:LoadMap(rdata.map)
    end

end 

RegisterNetEvent("ghosting:setplayeralpha")
AddEventHandler('ghosting:setplayeralpha', function(alphaValue)
    TriggerClientEvent('ghosting:setplayeralpha', -1, alphaValue)
end)

RegisterNetEvent("races:resetupgrade")
AddEventHandler('races:resetupgrade', function(vehiclemodint, track)
    local source = source
    local playerName = GetPlayerName(source)

    if vehiclemodint == 11 or vehiclemodint == 12 or vehiclemodint == 13 then
        notifyPlayer(source, "*****")
        print("Current Track:", track)
    end

    if vehiclemodint == 11 then
        print("Engine reset for " .. playerName)
    elseif vehiclemodint == 12 then
        print("Brakes reset for " .. playerName)
    elseif vehiclemodint == 13 then
        print("Gearbox reset for " .. playerName)
        --elseif vehiclemodint == 17 then
        --print("Nitrous reset for "  .. playerName)
        --elseif vehiclemodint == 18 then
        --print("Turbo reset for "  .. playerName)
    else
        --print(vehiclemodint .. " Reset, unknown for"  .. playerName)
    end
end)

RegisterCommand("races", function(_, args)
    if nil == args[1] then
        local msg = "Commands:\n"
        msg = msg .. "races - display list of available races commands\n"
        msg = msg ..
            "races export [name] - export public track saved as [name] without best lap times to file named '[name].json'\n"
        msg = msg ..
            "races import [name] - import track file named '[name].json' into public tracks without best lap times\n"
        msg = msg ..
            "races exportwblt [name] - export public track saved as [name] with best lap times to file named '[name].json'\n"
        msg = msg ..
            "races importwblt [name] - import track file named '[name].json' into public tracks with best lap times\n"
        msg = msg .. "races updateRaceData - update 'raceData.json' to new format\n"
        msg = msg .. "races updateTrack [name] - update exported track '[name].json' to new format\n"
        print(msg)
    elseif "export" == args[1] then
        export(args[2], false)
    elseif "import" == args[1] then
        import(args[2], false)
    elseif "exportwblt" == args[1] then
        export(args[2], true)
    elseif "importwblt" == args[1] then
        import(args[2], true)
    elseif "updateRaceData" == args[1] then
        updateRaceData()
    elseif "updateTrack" == args[1] then
        updateTrack(args[2])
    else
        print("Unknown command.")
    end
end, true)

function ProcessPlayers(source)
    local playerName = GetPlayerName(source)

    print("Processing player " .. source .. " " .. playerName)

    for _, otherPlayerSource in pairs(GetPlayers()) do
        local otherPlayerName = GetPlayerName(otherPlayerSource)

        print("Other player " .. otherPlayerSource .. " " .. otherPlayerName)

        if (source ~= tonumber(otherPlayerSource)) then
            TriggerClientEvent("races:addplayerdisplay", tonumber(otherPlayerSource), tonumber(source), playerName)

            TriggerClientEvent("races:addplayerdisplay", tonumber(source), tonumber(otherPlayerSource), otherPlayerName)
        end
    end
end

AddEventHandler("playerJoining", function()
    local source = source

    --Players are sometimes given a temporary source when they first join ignore that 
    if (source < 100) then
        print("Adding players from connecting event")
        ProcessPlayers(source)
    end
end)

AddEventHandler("playerDropped", function()
    print("playerDropped")
    local source = source

    -- unregister race registered by dropped player that has not started
    if races[source] ~= nil and racingStates.Registering == races[source].state then
        races[source] = nil
        TriggerClientEvent("races:unregister", -1, source)
    end

    TriggerClientEvent("races:removeplayerdisplay", -1, source)

    -- make sure this is last code block in function because of early return if player found in race
    -- remove dropped player from the race they are joined to
    for i, race in pairs(races) do
        race:OnPlayerDropped(source)
    end
end)

AddEventHandler("playerEnteredScope", function(data)
    local playerName = GetPlayerName(data.player)
    TriggerClientEvent("races:addplayerdisplay", tonumber(data['for']), tonumber(data.player), playerName)
end)

AddEventHandler("playerLeftScope", function(data)
    TriggerClientEvent("races:removeplayerdisplay",tonumber(data['for']), tonumber(data.player))
end)

RegisterNetEvent("races:init")
AddEventHandler("races:init", function()
    local source = source

    ProcessPlayers(source)

    -- register any races created before player joined
    for rIndex, race in pairs(races) do
        race:Setup(source)
    end

    local allVehicles = FileManager.LoadCurrentResourceFileJson('vehicles')

    if (allVehicles == nil) then
        notifyPlayer(source, "Error opening file vehicles.json for read")
        return
    end

    table.sort(allVehicles)
    allVehicles = removeDuplicates(allVehicles)

    TriggerClientEvent("races:allVehicles", source, allVehicles)

    local configData = FileManager.LoadCurrentResourceFileJson('config')

    racesMapManager:LoadConfig(configData['mapManager'])

    TriggerClientEvent("races:config", source, configData)
end)

RegisterNetEvent("races:load")
AddEventHandler("races:load", function(isPublic, trackName)
    local source = source
    if isPublic == nil or trackName == nil then
        notifyPlayer(source, "Ignoring load track event.  Invalid parameters.\n")
        return
    end

    local track = loadTrack(isPublic, source, trackName)

    if track == nil then
        notifyPlayer(source, "Cannot load.   " .. (true == isPublic and "Public" or "Private") .. " track '" .. trackName .. "' not found.\n")
        return
    end
    
    TriggerClientEvent("races:load", source, isPublic, trackName, track.waypointCoords, track.map)
end)

RegisterNetEvent("races:save")
AddEventHandler("races:save", function(isPublic, trackName, waypointCoords, map)
    local source = source
    if isPublic ~= nil and trackName ~= nil and waypointCoords ~= nil then
        local track = loadTrack(isPublic, source, trackName)
        if nil == track then
            track = { waypointCoords = waypointCoords, bestLaps = {}, map = map }
            if true == saveTrack(isPublic, source, trackName, track) then
                TriggerClientEvent("races:save", source, isPublic, trackName)
                TriggerEvent("races:trackNames", isPublic, source)
            else
                notifyPlayer(source,
                    "Error saving " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
            end
        else
            notifyPlayer(source,
                (true == isPublic and "Public" or "Private") ..
                " track '" .. trackName .. "' exists.  Use 'overwrite' command instead.\n")
        end
    else
        notifyPlayer(source, "Ignoring save track event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:overwrite")
AddEventHandler("races:overwrite", function(isPublic, trackName, waypointCoords, map)

    print(("Recieved Overwrite with map %s"):format(map))

    local source = source
    if isPublic ~= nil and trackName ~= nil and waypointCoords ~= nil then
        local track = loadTrack(isPublic, source, trackName)
        if track ~= nil then
            track = { waypointCoords = waypointCoords, bestLaps = {}, map = map}
            if true == saveTrack(isPublic, source, trackName, track) then
                TriggerClientEvent("races:overwrite", source, isPublic, trackName)
            else
                notifyPlayer(source,
                    "Error overwriting " ..
                    (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
            end
        else
            notifyPlayer(source,
                (true == isPublic and "Public" or "Private") ..
                " track '" .. trackName .. "' does not exist.  Use 'save' command instead.\n")
        end
    else
        notifyPlayer(source, "Ignoring overwrite track event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:delete")
AddEventHandler("races:delete", function(isPublic, trackName)
    local source = source
    if isPublic ~= nil and trackName ~= nil then
        local track = loadTrack(isPublic, source, trackName)
        if track ~= nil then
            if true == saveTrack(isPublic, source, trackName, nil) then
                TriggerEvent("races:trackNames", isPublic, source)
                notifyPlayer(source,
                    "Deleted " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
            else
                notifyPlayer(source,
                    "Error deleting " ..
                    (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
            end
        else
            notifyPlayer(source,
                "Cannot delete.  " ..
                (true == isPublic and "Public" or "Private") .. " track '" .. trackName .. "' not found.\n")
        end
    else
        notifyPlayer(source, "Ignoring delete track event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:blt")
AddEventHandler("races:blt", function(isPublic, trackName)
    local source = source
    if isPublic ~= nil and trackName ~= nil then
        local track = loadTrack(isPublic, source, trackName)
        if track ~= nil then
            TriggerClientEvent("races:blt", source, isPublic, trackName, track.bestLaps)
        else
            notifyPlayer(source,
                "Cannot list best lap times.   " ..
                (true == isPublic and "Public" or "Private") .. " track '" .. trackName .. "' not found.\n")
        end
    else
        notifyPlayer(source, "Ignoring best lap times event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:list")
AddEventHandler("races:list", function(isPublic)
    local source = source
    if isPublic ~= nil then
        local license = true == isPublic and "PUBLIC" or GetPlayerIdentifier(source, 0)
        if license ~= nil then
            local raceData = FileManager.LoadCurrentResourceFileJson('raceData')
            if raceData ~= nil then
                if license ~= "PUBLIC" then
                    license = string.sub(license, 9)
                end
                local tracks = raceData[license]
                if tracks ~= nil then
                    local names = {}
                    for name in pairs(tracks) do
                        names[#names + 1] = name
                    end
                    if #names > 0 then
                        table.sort(names)
                        local msg = "Saved " .. (true == isPublic and "public" or "private") .. " tracks:\n"
                        for _, name in ipairs(names) do
                            msg = msg .. name .. "\n"
                        end
                        notifyPlayer(source, msg)
                    else
                        notifyPlayer(source, "No saved " .. (true == isPublic and "public" or "private") .. " tracks.\n")
                    end
                else
                    notifyPlayer(source, "No saved " .. (true == isPublic and "public" or "private") .. " tracks.\n")
                end
            else
                notifyPlayer(source, "Could not load race data.\n")
            end
        else
            notifyPlayer(source, "Could not get license for player source ID: " .. source .. "\n")
        end
    else
        notifyPlayer(source, "Ignoring list event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:register")
AddEventHandler("races:register", function(waypointCoords, isPublic, trackName, rdata)
    local source = source

    if waypointCoords == nil or isPublic == nil or rdata == nil then
        notifyPlayer(source, "Ignoring register event.  Invalid parameters.\n")
        return
    end

    if rdata.laps <= 0 then
        notifyPlayer(source, "Invalid number of laps.\n")
        return
    end

    if rdata.timeout <= 0 then
        notifyPlayer(source, "Invalid DNF timeout.\n")
        return
    end

    if races[source] ~= nil  then
        if racingStates.Racing == races[source].state then
            notifyPlayer(source, "Cannot register.  Previous race in progress.\n")
        else
            notifyPlayer(source, "Cannot register.  Previous race registered.  Unregister first.\n")
        end
        return
    end

    local umsg = ""
    if "rest" == rdata.rtype then
        if nil == rdata.restrict then
            notifyPlayer(source, "Cannot register.  Invalid restricted vehicle.\n")
            return
        end
        umsg = " : using '" .. rdata.restrict .. "' vehicle"
    elseif "class" == rdata.rtype then
        if nil == rdata.vclass or rdata.vclass < -1 or rdata.vclass > 21 then
            notifyPlayer(source, "Cannot register.  Invalid vehicle class.\n")
            return
        end
        if -1 == rdata.vclass and #rdata.vehicleList == 0 then
            notifyPlayer(source, "Cannot register.  Vehicle list is empty.\n")
            return
        end
        umsg = " : using " .. getClassName(rdata.vclass) .. " vehicle class"
    elseif "rand" == rdata.rtype then
        if #rdata.vehicleList == 0 then
            notifyPlayer(source, "Cannot register.  Vehicle list is empty.\n")
            return
        end
        umsg = " : using random "
        if rdata.vclass ~= nil then
            if (rdata.vclass < 0 or rdata.vclass > 21) then
                notifyPlayer(source, "Cannot register.  Invalid vehicle class.\n")
                return
            end
            umsg = umsg .. getClassName(rdata.vclass) .. " vehicle class"
        else
            umsg = umsg .. "vehicles"
        end
        if rdata.svehicle ~= nil then
            umsg = umsg .. " : '" .. rdata.svehicle .. "'"
        end
    elseif "wanted" == rdata.rtype then
        umsg = " : wanted race mode "
    elseif "ghost" == rdata.rtype then
        umsg = " : ghost race mode "
    elseif rdata.rtype ~= nil then
        notifyPlayer(source, "Cannot register.  Unknown race type.\n")
        return
    end
    local owner = GetPlayerName(source)
    local msg = "Registered race using "
    if nil == trackName then
        msg = msg .. "unsaved track "
    else
        msg = msg ..
            (true == isPublic and "publicly" or "privately") ..
            " saved track '" .. trackName .. "' "
    end
    msg = msg ..
        ("by %s : tier %s : Special Class %s : %d lap(s)"):format(owner, rdata.tier, rdata.specialClass, rdata.laps)
    msg = msg .. umsg .. "\n"
    if false == distValid then
        msg = msg .. "Prize distribution table is invalid\n"
    end

    if(rdata.map ~= "") then
        msg = msg .. (" with map %s"):format(rdata.map);
    end

    notifyPlayer(source, msg)

    AddNewRace(waypointCoords, isPublic, trackName, owner, rdata.tier, rdata.timeout, rdata.laps, rdata)
    TriggerClientEvent("races:register", -1, source, waypointCoords[1], isPublic, trackName,
        owner, rdata)
end)

RegisterNetEvent("races:unregister")
AddEventHandler("races:unregister", function()
    local source = source
    if races[source] == nil then
        notifyPlayer(source, "Cannot unregister.  No race registered.\n")
    end

    races[source]:Unregister()
    races[source] = nil

end)

RegisterNetEvent("races:endrace")
AddEventHandler("races:endrace", function()
    local source = source
    if races[source] ~= nil then
        races[source]:TriggerEventForRacers("races:leave")
        notifyPlayer(source, "Race Ended.\n")
    else
        notifyPlayer(source, "Cannot End race.  You have no active race.\n")
    end
end)

RegisterNetEvent("races:grid")
AddEventHandler("races:grid", function()
    local source = source

    --#region Validation

    if races[source] == nil then
        notifyPlayer(source, "Cannot setup grid. Race does not exist.\n")
    end

    if racingStates.Registering ~= races[source].state then
        notifyPlayer(source, "Cannot setup grid.  Race in progress.\n")
    end

    races[source]:SetupGrid()

end)

RegisterNetEvent("races:autojoin")
AddEventHandler("races:autojoin", function()
    local source = source

    --#region Validation
    if races[source] == nil then
        notifyPlayer(source, "Cannot autojoin. Race does not exist.\n")
    end

    if racingStates.Registering ~= races[source].state then
        notifyPlayer(source, "Cannot autojoin.  Race in progress.\n")
    end

    local playersToJoin = {}

    if(ResourceActive('Party-System') and exports['Party-System']:HostingParty()) then
        print("Using Party")
        playersToJoin = exports['Party-System']:HostingParty()
    else
        print("Using All players")
        playersToJoin = GetPlayers()
    end

    for _, otherPlayerSource in pairs(playersToJoin) do
        JoinRacer(tonumber(otherPlayerSource), source)
    end

    races[source]:SetupGrid()

end)

RegisterNetEvent("races:readyState")
AddEventHandler("races:readyState", function(raceIndex, ready)
    local source = source
    if races[raceIndex] == nil then
        print("can't find race to ready")
        return
    end

    races[raceIndex]:ReadyStateChange(source, ready)
end)

RegisterNetEvent("races:start")
AddEventHandler("races:start", function(delay, override)
    local source = source

    local race = races[source]

    if delay == nil then
        notifyPlayer(source, "Ignoring start event.  Invalid parameters.\n")
    end

    if race == nil then
        notifyPlayer(source, "Cannot start.  Race does not exist.\n")
    end

    race:Start(delay, override)
end)

RegisterNetEvent("races:loadLst")
AddEventHandler("races:loadLst", function(isPublic, name)
    local source = source
    if isPublic ~= nil and name ~= nil then
        local list = loadVehicleList(isPublic, source, name)
        if list ~= nil then
            TriggerClientEvent("races:loadLst", source, isPublic, name, list)
        else
            notifyPlayer(source,
                "Cannot load.   " ..
                (true == isPublic and "Public" or "Private") .. " vehicle list '" .. name .. "' not found.\n")
        end
    else
        notifyPlayer(source, "Ignoring load vehicle list event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:saveLst")
AddEventHandler("races:saveLst", function(isPublic, name, vehicleList)
    local source = source
    if isPublic ~= nil and name ~= nil and vehicleList ~= nil then
        if loadVehicleList(isPublic, source, name) == nil then
            if true == saveVehicleList(isPublic, source, name, vehicleList) then
                TriggerEvent("races:listNames", isPublic, source)
                notifyPlayer(source,
                    "Saved " .. (true == isPublic and "public" or "private") .. " vehicle list '" .. name .. "'.\n")
            else
                notifyPlayer(source,
                    "Error saving " ..
                    (true == isPublic and "public" or "private") .. " vehicle list '" .. name .. "'.\n")
            end
        else
            notifyPlayer(source,
                (true == isPublic and "Public" or "Private") ..
                " vehicle list '" .. name .. "' exists.  Use 'overwrite' command instead.\n")
        end
    else
        notifyPlayer(source, "Ignoring save vehicle list event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:overwriteLst")
AddEventHandler("races:overwriteLst", function(isPublic, name, vehicleList)
    local source = source
    if isPublic ~= nil and name ~= nil and vehicleList ~= nil then
        local list = loadVehicleList(isPublic, source, name)
        if list ~= nil then
            if true == saveVehicleList(isPublic, source, name, vehicleList) then
                --TriggerClientEvent("races:overwrite", source, isPublic, trackName)
                notifyPlayer(source,
                    "Overwrote " .. (true == isPublic and "public" or "private") .. " vehicle list '" .. name .. "'.\n")
            else
                notifyPlayer(source,
                    "Error overwriting " ..
                    (true == isPublic and "public" or "private") .. " vehicle list '" .. name .. "'.\n")
            end
        else
            notifyPlayer(source,
                (true == isPublic and "Public" or "Private") ..
                " vehicle list '" .. name .. "' does not exist.  Use 'save' command instead.\n")
        end
    else
        notifyPlayer(source, "Ignoring overwrite vehicle list event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:deleteLst")
AddEventHandler("races:deleteLst", function(isPublic, name)
    local source = source
    if isPublic ~= nil and name ~= nil then
        local list = loadVehicleList(isPublic, source, name)
        if list ~= nil then
            if true == saveVehicleList(isPublic, source, name, nil) then
                TriggerEvent("races:listNames", isPublic, source)
                notifyPlayer(source,
                    "Deleted " .. (true == isPublic and "public" or "private") .. " vehicle list '" .. name .. "'.\n")
            else
                notifyPlayer(source,
                    "Error deleting " ..
                    (true == isPublic and "public" or "private") .. " vehicle list '" .. name .. "'.\n")
            end
        else
            notifyPlayer(source,
                "Cannot delete.  " ..
                (true == isPublic and "Public" or "Private") .. " vehicle list '" .. name .. "' not found.\n")
        end
    else
        notifyPlayer(source, "Ignoring delete vehicle list event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:listLsts")
AddEventHandler("races:listLsts", function(isPublic)
    local source = source
    if isPublic ~= nil then
        local license = true == isPublic and "PUBLIC" or GetPlayerIdentifier(source, 0)
        if license ~= nil then
            local vehicleListData = FileManager.LoadCurrentResourceFileJson('vehicleListData')
            if vehicleListData ~= nil then
                if license ~= "PUBLIC" then
                    license = string.sub(license, 9)
                end
                local lists = vehicleListData[license]
                if lists ~= nil then
                    local names = {}
                    for name in pairs(lists) do
                        names[#names + 1] = name
                    end
                    if #names > 0 then
                        table.sort(names)
                        local msg = "Saved " .. (true == isPublic and "public" or "private") .. " vehicle lists:\n"
                        for _, name in ipairs(names) do
                            msg = msg .. name .. "\n"
                        end
                        notifyPlayer(source, msg)
                    else
                        notifyPlayer(source,
                            "No saved " .. (true == isPublic and "public" or "private") .. " vehicle lists.\n")
                    end
                else
                    notifyPlayer(source,
                        "No saved " .. (true == isPublic and "public" or "private") .. " vehicle lists.\n")
                end
            else
                notifyPlayer(source, "Could not load vehicle list data.\n")
            end
        else
            notifyPlayer(source, "Could not get license for player source ID: " .. source .. "\n")
        end
    else
        notifyPlayer(source, "Ignoring list vehicle lists event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:leave")
AddEventHandler("races:leave", function(rIndex)
    local source = source
    if rIndex == nil then
        notifyPlayer(source, "Ignoring leave event.  Invalid parameters.\n")
    end

    if races[rIndex] == nil then
        notifyPlayer(source, "Cannot leave.  Race does not exist.\n")
    end

    races[rIndex]:OnPlayerLeave(source)
end)

RegisterNetEvent("races:removeFromLeaderboard")
AddEventHandler("races:removeFromLeaderboard", function(raceIndex)
    local source = source
    if(raceIndex == nil or races[raceIndex] == nil) then
        print("No Race to remove from")
        return
    end

    races[raceIndex]:TriggerEventForRacers("races:removeFromLeaderboard", source)
end)


function JoinRacer(source, rIndex)
    if rIndex == nil then
        notifyPlayer(source, "Ignoring join event.  Invalid parameters.\n")
    end

    if races[rIndex] ~= nil then
        notifyPlayer(source, "Cannot join.  Race does not exist.\n")
    end

    races[rIndex]:JoinRacer(source)
end

RegisterNetEvent("races:join")
AddEventHandler("races:join", function(raceIndex)
    local source = source
    JoinRacer(source, raceIndex)
end)

RegisterNetEvent("races:finish")
AddEventHandler("races:finish", function(rIndex, numWaypointsPassed, dnf, altSource)
    local source = altSource or source

    if rIndex == nil or source == nil or numWaypointsPassed == nil then
        notifyPlayer(source, "Ignoring finish event.  Invalid parameters.\n")
        return
    end

    local race = races[rIndex]
    if race == nil then
        notifyPlayer(source, "Cannot finish.  Race does not exist.\n")
        return
    end

    if(race:Finish(source, numWaypointsPassed, dnf, altSource)) then

        local track = loadTrack(race.isPublic, rIndex, race.trackName)

        track.bestLaps = race:GetBestLaps(track.bestLaps)

        if false == saveTrack(race.isPublic, rIndex, race.trackName, track) then
            notifyPlayer(rIndex, "Save error updating best lap times.\n")
        end

        racesMapManager:UnloadMap(race.map)
        races[rIndex] = nil
    end
end)

RegisterNetEvent("races:report")
AddEventHandler("races:report", function(rIndex, numWaypointsPassed, distance)
    local source = source
    if rIndex == nil or numWaypointsPassed == nil or distance == nil then
        notifyPlayer(source, "Ignoring report event.  Invalid parameters.\n")
    end

    if races[rIndex] == nil then
        notifyPlayer(source, "Cannot report.  Race does not exist.\n")
    end

    races[rIndex]:Report(source, numWaypointsPassed, distance)
end)

RegisterNetEvent("races:trackNames")
AddEventHandler("races:trackNames", function(isPublic, altSource)
    local source = altSource or source
    if isPublic ~= nil then
        local trackNames = {}

        local license = true == isPublic and "PUBLIC" or GetPlayerIdentifier(source, 0)
        if license ~= nil then
            local raceData = FileManager.LoadCurrentResourceFileJson('raceData')
            if raceData ~= nil then
                if license ~= "PUBLIC" then
                    license = string.sub(license, 9)
                end
                local tracks = raceData[license]
                if tracks ~= nil then
                    for trackName in pairs(tracks) do
                        trackNames[#trackNames + 1] = trackName
                    end
                    table.sort(trackNames)
                end
            else
                notifyPlayer(source, "Could not load race data.\n")
            end
        else
            notifyPlayer(source, "Could not get license for player source ID: " .. source .. "\n")
        end

        TriggerClientEvent("races:trackNames", source, isPublic, trackNames)
    else
        notifyPlayer(source, "Ignoring list event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:listNames")
AddEventHandler("races:listNames", function(isPublic, altSource)
    local source = altSource or source
    if isPublic ~= nil then
        local listNames = {}

        local license = true == isPublic and "PUBLIC" or GetPlayerIdentifier(source, 0)
        if license ~= nil then
            local vehicleListData = FileManager.LoadCurrentResourceFileJson('vehicleListData')
            if vehicleListData ~= nil then
                if license ~= "PUBLIC" then
                    license = string.sub(license, 9)
                end
                local lists = vehicleListData[license]
                if lists ~= nil then
                    for listName in pairs(lists) do
                        listNames[#listNames + 1] = listName
                    end
                    table.sort(listNames)
                end
            else
                notifyPlayer(source, "Could not load vehicle list data.\n")
            end
        else
            notifyPlayer(source, "Could not get license for player source ID: " .. source .. "\n")
        end

        TriggerClientEvent("races:listNames", source, isPublic, listNames)
    else
        notifyPlayer(source, "Ignoring list vehicle lists event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:sendvehiclename")
AddEventHandler("races:sendvehiclename", function(raceIndex, currentVehicleName)
    local source = source
    TriggerEventForRacers(raceIndex, "races:sendvehiclename", source, currentVehicleName)
end)

RegisterNetEvent("races:sendCheckpointTime")
AddEventHandler("races:sendCheckpointTime", function(waypointsPassed, raceIndex)
    local source = source

    if (races[raceIndex] == nil) then
        print("No race by that index")
        return
    end

    races[raceIndex]:SendCheckpointTime(source, waypointsPassed)
end)

RegisterNetEvent("races:lapcompleted", function(raceIndex, currentVehicleName)
    local source = source

    if (races[raceIndex] == nil) then
        print("No race")
        return
    end

    races[raceIndex]:OnLapCompleted(source, currentVehicleName)

end)

function RaceServerUpdate()
    for rIndex, race in pairs(races) do
        if racingStates.Racing == race.state then
            local sortedPlayers = {} -- will contain players still racing and players that finished without DNF
            local complete = true

            -- race.players[source] = {source, playerName, numWaypointsPassed, data, coord}
            for _, player in pairs(race.players) do
                if -1 == player.numWaypointsPassed then -- player client hasn't updated numWaypointsPassed, data and coord
                    complete = false
                    break
                end

                -- player.data will be travel distance to next waypoint or finish time; finish time will be -1 if player DNF
                -- if player.data == -1 then player did not finish race - do not include in sortedPlayers
                if player.data ~= -1 then
                    sortedPlayers[#sortedPlayers + 1] = {
                        source = player.source,
                        numWaypointsPassed = player.numWaypointsPassed,
                        data = player.data,
                        playerName = GetPlayerName(player.source)
                    }
                end
            end

            if true == complete then -- all player clients have updated numWaypointsPassed and data
                table.sort(sortedPlayers, function(p0, p1)
                    return (p0.numWaypointsPassed > p1.numWaypointsPassed) or
                        (p0.numWaypointsPassed == p1.numWaypointsPassed and p0.data < p1.data)
                end)

                local racePositions = map(sortedPlayers,
                    function(item)
                        return {
                            source = item.source ,
                            playerName = item.playerName
                        }
                    end)

                TriggerEventForRacers(rIndex, "races:racerPositions", racePositions)

                -- players sorted into sortedPlayers table
                for position, sortedPlayer in pairs(sortedPlayers) do
                    TriggerClientEvent("races:position", sortedPlayer.source, rIndex, position, #sortedPlayers)
                end
            end
        end
    end
end

--Update every frame to track race time
function MainServerUpdate()
    for rIndex, race in pairs(races) do
        race:Update()
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        RaceServerUpdate()
    end
end)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        MainServerUpdate()
    end
end)
