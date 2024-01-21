local STATE_REGISTERING <const> = 0 -- registering race status
local STATE_RACING <const> = 1      -- racing race status

local ROLE_EDIT <const> = 1         -- edit tracks role
local ROLE_REGISTER <const> = 2     -- register races role
local ROLE_SPAWN <const> = 4        -- spawn vehicles role

local gridLineup = {}
UseRaceResults = false

local defaultDelay <const> = 5

local requirePermissionToEdit <const> = false     -- flag indicating if permission is required to edit tracks
local requirePermissionToRegister <const> = false -- flag indicating if permission is required to register races
local requirePermissionToSpawn <const> = false    -- flag indicating if permission is required to spawn vehicles

local requirePermissionBits <const> =             -- bit flag indicating if permission is required to edit tracks, register races or spawn vehicles
    (true == requirePermissionToEdit and ROLE_EDIT or 0) |
    (true == requirePermissionToRegister and ROLE_REGISTER or 0) |
    (true == requirePermissionToSpawn and ROLE_SPAWN or 0)

local allVehicleFileName <const> = "vehicles.txt" -- list of all vehicles filename

local defaultRadius <const> = 5.0                 -- default waypoint radius

local requests = {}                               -- requests[playerID] = {name, roleBit} - list of requests to edit tracks, register races and/or spawn vehicles

local READY_RACERS_COUNTDOWN = 5000
local races = {} -- races[playerID] = {state, waypointCoords[] = {x, y, z, r}, isPublic, trackName, owner, tier, laps, timeout, rtype, restrict, vclass, svehicle, vehicleList, numRacing, players[netID] = {source, playerName,  numWaypointsPassed, data, coord}, results[] = {source, playerName, finishTime, bestLapTime, vehicleName}}

--2D array for checkpointTimes
--1st dimension is checkpoint
--2nd dimension is rcers
local checkpointTimes = {}

function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

function explode(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

function removeDuplicates(table)
    local hash = {}
    local res = {}

    for _, v in ipairs(table) do
        if (not hash[v]) then
            res[#res + 1] = v
            hash[v] = true
        end
    end

    return res
end

local function SaveRacesFile(filename, data, length)
    if (length == nil) then length = -1 end
    return SaveResourceFile(GetCurrentResourceName(), filename, data, length)
end

local function LoadRacesFile(filename)
    return LoadResourceFile(GetCurrentResourceName(), filename)
end

local function createFileIfEmpty(fileName)
    if LoadRacesFile(fileName) == nil then
        SaveRacesFile(fileName, {})
    end
end

createFileIfEmpty('raceData.json')
createFileIfEmpty('rolesData.json')
createFileIfEmpty('vehicleListData.json')

local function map(tbl, f)
    local t = {}
    for k, v in pairs(tbl) do
        t[k] = f(v)
    end
    return t
end

local function mapToArray(tbl, f)
    local t = {}
    for k, v in pairs(tbl) do
        table.insert(t, f(v))
    end
    return t
end

local function notifyPlayer(source, msg)
    TriggerClientEvent("chat:addMessage", source, {
        color = { 255, 0, 0 },
        multiline = true,
        args = { "[races:server]", msg }
    })
end

local function sendMessage(source, msg)
    TriggerClientEvent("races:message", source, msg)
end

local function getTrack(trackName)
    local track = LoadRacesFile(trackName .. '.json')
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
        local raceData = LoadRacesFile('raceData.json')
        if raceData ~= nil then
            local publicTracks = raceData["PUBLIC"]
            if publicTracks ~= nil then
                if publicTracks[trackName] ~= nil then
                    local track = LoadRacesFile(trackName .. ".json")
                    if track == fail then
                        if false == withBLT then
                            publicTracks[trackName].bestLaps = {}
                        end
                        if true == SaveRacesFile(trackName .. '.json', publicTracks[trackName]) then
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
        local raceData = LoadRacesFile('raceData.json')
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
                    if true == SaveRacesFile('raceData.json', raceData) then
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

local function listReqs()
    --requests[playerID] = {name, roleBit}
    for playerID, request in pairs(requests) do
        local role = "INVALID ROLE"
        if ROLE_EDIT == request.roleBit then
            role = "EDIT"
        elseif ROLE_REGISTER == request.roleBit then
            role = "REGISTER"
        elseif ROLE_SPAWN == request.roleBit then
            role = "SPAWN"
        end
        print(playerID .. " : " .. request.name .. " : " .. role)
    end
end

local function approve(playerID)
    if playerID ~= nil then
        local name = GetPlayerName(playerID)
        if name ~= nil then
            playerID = tonumber(playerID)
            if requests[playerID] ~= nil then
                local license = GetPlayerIdentifier(playerID, 0)
                if license ~= nil then
                    local rolesData = LoadRacesFile('rolesData.json')
                    if rolesData ~= nil then
                        license = string.sub(license, 9)
                        --requests[playerID] = {name, roleBit}
                        if rolesData[license] ~= nil then
                            rolesData[license].roleBits = rolesData[license].roleBits | requests[playerID].roleBit
                        else
                            rolesData[license] = { name = name, roleBits = requests[playerID].roleBit }
                        end
                        if true == SaveRacesFile('rolesData.json', rolesData) then
                            local roleType = "SPAWN"
                            if ROLE_EDIT == requests[playerID].roleBit then
                                roleType = "EDIT"
                            elseif ROLE_REGISTER == requests[playerID].roleBit then
                                roleType = "REGISTER"
                            end
                            local msg = "approve: Request by '" .. name .. "' for " .. roleType .. " role approved."
                            print(msg)

                            TriggerClientEvent("races:roles", playerID, rolesData[license].roleBits)
                            notifyPlayer(playerID, "Request for " .. roleType .. " role approved.\n")
                            requests[playerID] = nil
                        else
                            print("approve: Could not approve role.")
                        end
                    else
                        print("approve: Could not load race data.")
                    end
                else
                    print("approve: Could not get license for player source ID: " .. playerID)
                end
            else
                print("approve: Player did not request approval.")
            end
        else
            print("approve: Invalid player ID.")
        end
    else
        print("approve: Player ID required.")
    end
end

local function deny(playerID)
    if playerID ~= nil then
        local name = GetPlayerName(playerID)
        if name ~= nil then
            playerID = tonumber(playerID)
            if requests[playerID] ~= nil then
                local roleType = "SPAWN"
                if ROLE_EDIT == requests[playerID].roleBit then
                    roleType = "EDIT"
                elseif ROLE_REGISTER == requests[playerID].roleBit then
                    roleType = "REGISTER"
                end
                local msg = "deny: Request by '" .. name .. "' for " .. roleType .. " role denied."
                print(msg)

                notifyPlayer(playerID, "Request for " .. roleType .. " role denied.\n")
                requests[playerID] = nil
            else
                print("deny: Player did not request approval.")
            end
        else
            print("deny: Invalid player ID.")
        end
    else
        print("deny: Player ID required.")
    end
end

local function listRoles()
    print("Permission to edit tracks: " .. (true == requirePermissionToEdit and "required" or "NOT required"))
    print("Permission to register races: " .. (true == requirePermissionToRegister and "required" or "NOT required"))
    print("Permission to spawn vehicles: " .. (true == requirePermissionToSpawn and "required" or "NOT required"))
    -- rolesData[license] = {name, roleBits}
    local rolesData = LoadRacesFile('rolesData.json')
    if rolesData ~= nil then
        local rolesFound = false
        for _, role in pairs(rolesData) do
            rolesFound = true
            local roleNames = ""
            if 0 == role.roleBits & ~(ROLE_EDIT | ROLE_REGISTER | ROLE_SPAWN) then
                if role.roleBits & ROLE_EDIT ~= 0 then
                    roleNames = " EDIT"
                end
                if role.roleBits & ROLE_REGISTER ~= 0 then
                    roleNames = roleNames .. " REGISTER"
                end
                if role.roleBits & ROLE_SPAWN ~= 0 then
                    roleNames = roleNames .. " SPAWN"
                end
            else
                roleNames = "INVALID ROLE"
            end
            print(role.name .. " :" .. roleNames)
        end
        if false == rolesFound then
            print("listRoles: No roles found.")
        end
    else
        print("listRoles: Could not load roles data.")
    end
end

local function removeRole(playerName, roleName)
    if playerName ~= nil then
        local rolesData = LoadRacesFile('rolesData.json')
        if rolesData ~= nil then
            local roleBits = (ROLE_EDIT | ROLE_REGISTER | ROLE_SPAWN)
            local roleType = ""
            if "edit" == roleName then
                roleBits = ROLE_EDIT
                roleType = "EDIT"
            elseif "register" == roleName then
                roleBits = ROLE_REGISTER
                roleType = "REGISTER"
            elseif "spawn" == roleName then
                roleBits = ROLE_SPAWN
                roleType = "SPAWN"
            elseif roleName ~= nil then
                print("removeRole: Invalid role.")
                return
            end
            local lic = nil
            for license, role in pairs(rolesData) do
                if role.name == playerName then
                    lic = license
                    if 0 == role.roleBits & roleBits then
                        print("removeRole: Role was not assigned.")
                        return
                    end
                    rolesData[lic].roleBits = rolesData[lic].roleBits & ~roleBits
                    break
                end
            end
            if lic ~= nil then
                if roleBits & ROLE_REGISTER ~= 0 then
                    for _, rIndex in pairs(GetPlayers()) do
                        local license = GetPlayerIdentifier(rIndex, 0)
                        if license ~= nil then
                            if string.sub(license, 9) == lic then
                                rIndex = tonumber(rIndex)
                                if races[rIndex] ~= nil and STATE_REGISTERING == races[rIndex].state then
                                    races[rIndex] = nil
                                    TriggerClientEvent("races:unregister", -1, rIndex)
                                end
                                TriggerClientEvent("races:roles", rIndex, rolesData[lic].roleBits)
                                break
                            end
                        else
                            print("removeRole: Could not get license for player source ID: " .. rIndex)
                        end
                    end
                end
                local msg = ""
                if 0 == rolesData[lic].roleBits then
                    rolesData[lic] = nil
                    msg = "removeRole: All '" .. playerName .. "' roles removed."
                else
                    msg = "removeRole: '" .. playerName .. "' role " .. roleType .. " removed."
                end
                if true == SaveRacesFile('rolesData.json', rolesData) then
                    print(msg)
                else
                    print("removeRole: Could not remove role.")
                end
            else
                print("removeRole: '" .. playerName .. "' not found.")
            end
        else
            print("removeRole: Could not load roles data.")
        end
    else
        print("removeRole: Name required.")
    end
end

local function updateRaceData()
    local raceData = LoadRacesFile('raceData.json')
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
            if true == SaveRacesFile('raceData_updated.json', newRaceData) then
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
        local track = LoadRacesFile(trackName .. '.json')
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

                        if true == SaveRacesFile(trackName .. '_updated.json', { waypointCoords = newWaypointCoords, bestLaps = track.bestLaps }) then
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
        local raceData = LoadRacesFile('raceData.json')
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
        local raceData = LoadRacesFile('raceData.json')
        if raceData ~= nil then
            if license ~= "PUBLIC" then
                license = string.sub(license, 9)
            end
            local tracks = raceData[license] ~= nil and raceData[license] or {}
            tracks[trackName] = track
            raceData[license] = tracks
            if true == SaveRacesFile('raceData.json', raceData) then
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
        local vehicleListData = LoadRacesFile('vehicleListData.json')
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
        local vehicleListData = LoadRacesFile('vehicleListData.json')
        if vehicleListData ~= nil then
            if license ~= "PUBLIC" then
                license = string.sub(license, 9)
            end
            local lists = vehicleListData[license] ~= nil and vehicleListData[license] or {}
            lists[name] = vehicleList
            vehicleListData[license] = lists
            if true == SaveRacesFile('vehicleListData.json', vehicleListData) then
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

local function getClassName(vclass)
    if -1 == vclass then
        return "'Custom'(-1)"
    elseif 0 == vclass then
        return "'Compacts'(0)"
    elseif 1 == vclass then
        return "'Sedans'(1)"
    elseif 2 == vclass then
        return "'SUVs'(2)"
    elseif 3 == vclass then
        return "'Coupes'(3)"
    elseif 4 == vclass then
        return "'Muscle'(4)"
    elseif 5 == vclass then
        return "'Sports Classics'(5)"
    elseif 6 == vclass then
        return "'Sports'(6)"
    elseif 7 == vclass then
        return "'Super'(7)"
    elseif 8 == vclass then
        return "'Motorcycles'(8)"
    elseif 9 == vclass then
        return "'Off-road'(9)"
    elseif 10 == vclass then
        return "'Industrial'(10)"
    elseif 11 == vclass then
        return "'Utility'(11)"
    elseif 12 == vclass then
        return "'Vans'(12)"
    elseif 13 == vclass then
        return "'Cycles'(13)"
    elseif 14 == vclass then
        return "'Boats'(14)"
    elseif 15 == vclass then
        return "'Helicopters'(15)"
    elseif 16 == vclass then
        return "'Planes'(16)"
    elseif 17 == vclass then
        return "'Service'(17)"
    elseif 18 == vclass then
        return "'Emergency'(18)"
    elseif 19 == vclass then
        return "'Military'(19)"
    elseif 20 == vclass then
        return "'Commercial'(20)"
    elseif 21 == vclass then
        return "'Trains'(21)"
    else
        return "'Unknown'(" .. vclass .. ")"
    end
end

local function updateBestLapTimes(rIndex)
    local track = loadTrack(races[rIndex].isPublic, rIndex, races[rIndex].trackName)
    if track ~= nil then -- saved track still exists - not deleted in middle of race
        local bestLaps = track.bestLaps
        for _, result in pairs(races[rIndex].results) do
            if result.bestLapTime ~= -1 then
                bestLaps[#bestLaps + 1] = {
                    playerName = result.playerName,
                    bestLapTime = result.bestLapTime,
                    vehicleName =
                        result.vehicleName
                }
            end
        end
        table.sort(bestLaps, function(p0, p1)
            return p0.bestLapTime < p1.bestLapTime
        end)
        for i = 11, #bestLaps do
            bestLaps[i] = nil
        end
        track.bestLaps = bestLaps
        if false == saveTrack(races[rIndex].isPublic, rIndex, races[rIndex].trackName, track) then
            notifyPlayer(rIndex, "Save error updating best lap times.\n")
        end
    else
        notifyPlayer(rIndex, "Cannot save best lap times.  Track '" .. races[rIndex].trackName .. "' has been deleted.\n")
    end
end

local function minutesSeconds(milliseconds)
    local seconds = milliseconds / 1000.0
    local minutes = math.floor(seconds / 60.0)
    seconds = seconds - minutes * 60.0
    return minutes, seconds
end

local function save_result_csv(trackName, results)
    local date = os.date("%d_%m", os.time())
    local resultsFileName = ('/results/%s_%s_results.csv'):format(trackName, date)
    local saveCSVResults = SaveRacesFile(resultsFileName, results)

    if (saveCSVResults == nil) then
        print("Error saving file '" .. resultsFilePath)
    end
end

local function saveResults(race)
    -- races[playerID] = {state, waypointCoords[] = {x, y, z, r}, isPublic, trackName, owner, tier, laps, timeout, rtype, restrict, vclass, svehicle, vehicleList, numRacing, players[netID] = {source, playerName,  numWaypointsPassed, data, coord}, results[] = {source, playerName, finishTime, bestLapTime, vehicleName}}
    local msg = "Race using "
    if nil == race.trackName then
        msg = msg .. "unsaved track "
    else
        msg = msg .. (true == race.isPublic and "publicly" or "privately") .. " saved track '" .. race.trackName .. "' "
    end
    msg = msg ..
        ("registered by %s : tier %s : SpecialClass %s : %d lap(s)"):format(race.owner, race.tier, race.specialClass,
            race.laps)
    if "rest" == race.rtype then
        msg = msg .. " : using '" .. race.restrict .. "' vehicle"
    elseif "class" == race.rtype then
        msg = msg .. " : using " .. getClassName(race.vclass) .. " vehicle class"
    elseif "rand" == race.rtype then
        msg = msg .. " : using random "
        if race.vclass ~= nil then
            msg = msg .. getClassName(race.vclass) .. " vehicle class"
        else
            msg = msg .. "vehicles"
        end
        if race.svehicle ~= nil then
            msg = msg .. " : '" .. race.svehicle .. "'"
        end
    elseif "wanted" == race.rtype then
        msg = msg .. " : using wanted race mode"
    end
    msg = msg .. "\n"

    local race_results_data = ""

    if #race.results > 0 then
        -- results[] = {source, playerName, finishTime, bestLapTime, vehicleName}
        msg = msg .. "Results:\n"
        for pos, result in ipairs(race.results) do
            local best_minutes = 99
            local best_seconds = 99

            if -1 == result.finishTime then
                msg = msg .. "DNF - " .. result.playerName
            else
                local fMinutes, fSeconds = minutesSeconds(result.finishTime)
                best_minutes, best_seconds = minutesSeconds(result.bestLapTime)
                msg = msg ..
                    ("%d - %02d:%05.2f - %s - best lap %02d:%05.2f using %s\n"):format(pos, fMinutes, fSeconds,
                        result.playerName, best_minutes, best_seconds, result.vehicleName)
            end

            if result.bestLapTime >= 0 then
                best_minutes, best_seconds = minutesSeconds(result.bestLapTime)
                msg = msg .. (" - best lap %02d:%05.2f using %s"):format(best_minutes, best_seconds, result.vehicleName)
            end
            msg = msg .. "\n"

            local race_results_line = ("%d,%s,%02d:%05.2f,\n"):format(pos, result.playerName, best_minutes, best_seconds)
            race_results_data = race_results_data .. race_results_line
        end
    else
        msg = msg .. "No results.\n"
    end

    save_result_csv(race.trackName, race_results_data)

    if (SaveRacesFile('results_' .. race.owner .. ".txt", msg) == nil) then
        print('Error Saving file file results_' .. race.owner .. '.txt')
    end
end

local function SetNextGridLineup(results)
    UseRaceResults = true
    for k in next, gridLineup do rawset(gridLineup, k, nil) end

    -- print(gridLineup)
    -- print(gridLineup[1])
    -- print(#gridLineup)

    -- print("Grid lineup setup")
    -- print(string.format("Total results: %i", #results))
    for i = 1, #results do
        -- print(string.format("Index: %i", #results + 1 - i))
        local racer = results[#results + 1 - i]
        --print("Player " .. racer.playerName)
        --print("Source " .. racer.source)
        table.insert(gridLineup, racer.source)
    end

    -- print(gridLineup)
    -- print(#gridLineup)
end

local function round(f)
    return (f - math.floor(f) >= 0.5) and math.ceil(f) or math.floor(f)
end

local function getRoleBits(source)
    local roleBits = (ROLE_EDIT | ROLE_REGISTER | ROLE_SPAWN) & ~requirePermissionBits
    local rolesData = LoadRacesFile('rolesData.json')
    if rolesData ~= nil then
        local license = GetPlayerIdentifier(source, 0)
        if license ~= nil then
            license = string.sub(license, 9)
            if rolesData[license] ~= nil then
                return rolesData[license].roleBits | roleBits
            end
        else
            print("getRoleBits: Could not get license for player source ID: " .. source)
        end
    else
        print("getRoleBits: Could not load roles data.")
    end
    return roleBits
end

local gridSeparation <const> = 5

local function GenerateStartingGrid(startWaypoint, totalGridPositions)
    -- print("Generating starting grid")
    local startPoint = vector3(startWaypoint.x, startWaypoint.y, startWaypoint.z)

    -- print(string.format("Starting Grid: %.2f, %.2f, %.2f", startPoint.x, startPoint.y, startPoint.z))
    -- print(string.format("Starting Heading: %.2f", startWaypoint.heading))

    --TriggerClientEvent("races:spawncheckpoint", -1, startWaypoint, i)

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

    -- print(string.format("Forward Vector: %.2f, %.2f, %.2f", forwardVector.x, forwardVector.y, forwardVector.z))
    -- print(string.format("Left Vector: %.2f, %.2f, %.2f", leftVector.x, leftVector.y, leftVector.z))

    local gridPositions = {}

    for i = 1, totalGridPositions do
        local gridPosition = startPoint - forwardVector * (i + 1) * gridSeparation

        -- print(string.format("Initial grid position Position(%.2f,%.2f,%.2f)", gridPosition.x, gridPosition.y, gridPosition.z))

        if math.fmod(i, 2) == 0 then
            -- print("Right Grid")
            gridPosition = gridPosition + -leftVector * 3
        else
            -- print("Left Grid")
            gridPosition = gridPosition + leftVector * 3
        end

        TriggerClientEvent("races:spawncheckpoint", -1, gridPosition, i)

        table.insert(gridPositions, gridPosition)
    end

    return gridPositions
end

local function OnPlayerLeave(race, rIndex, netID, source)
    print("On Player Leave called")
    race.numRacing = race.numRacing - 1

    if (race.players[netID].ready) then
        race.numReady = race.numReady - 1
    end

    TriggerClientEvent("races:onplayerleave", source)
    TriggerClientEvent("races:leavenotification", -1,
        string.format(
            "%s has left Race %s",
            race.players[netID].playerName,
            race.trackName
        ),
        race.players[netID].source,
        rIndex,
        race.numReady,
        race.numRacing,
        race.waypointCoords[1]
    )

    races[rIndex].players[netID] = nil
end

local function PlaceRacersOnGrid(gridPositions, players, totalPlayers, heading)
    -- print("Spawning racers on grid")

    -- print(gridLineup)
    -- print(gridPositions)
    -- print(players)
    -- print(heading)
    -- print(string.format("Total Players: %i", totalPlayers))

    local index = 1;

    -- print(string.format("Grid positions length %i", #gridPositions))
    for _, player in pairs(gridLineup) do
        --Get assigned Grid
        -- print(string.format("Find position for Index %i", index))
        local gridPosition = gridPositions[index]

        -- print(gridPositions[index])
        -- print(player)
        -- print(player)
        -- print(gridPosition)

        TriggerClientEvent("races:setupgrid", player, gridPosition, heading, index)

        index = index + 1
    end
    --print("finished placing playes")
end

local function StartRaceCountdown(raceIndex)
    TriggerClientEvent("races:startPreRaceCountdown", -1, READY_RACERS_COUNTDOWN)
    races[raceIndex].countdown = true
    races[raceIndex].countdownTimeStart = GetGameTimer()
end

local function StopRaceCountdown(raceIndex)
    TriggerClientEvent("races:stopPreRaceCountdown", -1)
    races[raceIndex].countdown = false
    races[raceIndex].countdownTimeStart = 0
end

local function CheckReady(race, raceIndex)
    if(race.numRacing == 0 ) then
        return
    end

    if race.numReady == race.numRacing and race.countdown == false then
        StartRaceCountdown(raceIndex)
    end

    if race.countdown == true and race.numReady ~= race.numRacing then
        StopRaceCountdown(raceIndex)
    end
end

local function ProcessReadyCountdown(raceIndex)
    if GetGameTimer() - races[raceIndex].countdownTimeStart > READY_RACERS_COUNTDOWN then
        --START races
        StartRace(races[raceIndex], raceIndex, defaultDelay)
    end
end

AddEventHandler("respawnPlayerPedEvent", function(player, content)
    TriggerClientEvent('races:respawn', player)
end)

RegisterNetEvent("setplayeralpha")
AddEventHandler('setplayeralpha', function(alphaValue)
    TriggerClientEvent('setplayeralpha', -1, alphaValue)
end)

RegisterNetEvent("races:resetupgrade")
AddEventHandler('races:resetupgrade', function(vehiclemodint, track)
    local source = source
    local playerName = GetPlayerName(source)

    if vehiclemodint == 11 or vehiclemodint == 12 or vehiclemodint == 13 then
        sendMessage(source, "*****")
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
        msg = msg .. "races listReqs - list requests to edit tracks, register races and spawn vehicles\n"
        msg = msg ..
            "races approve [playerID] - approve request of [playerID] to edit tracks, register races or spawn vehicles\n"
        msg = msg ..
            "races deny [playerID] - deny request of [playerID] to edit tracks, register races or spawn vehicles\n"
        msg = msg .. "races listRoles - list approved players' roles\n"
        msg = msg ..
            "races removeRole [name] (role) - remove player [name]'s (role) = {edit, register, spawn} role; otherwise remove all roles if (role) is not specified\n"
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
    elseif "listReqs" == args[1] then
        listReqs()
    elseif "approve" == args[1] then
        approve(args[2])
    elseif "deny" == args[1] then
        deny(args[2])
    elseif "listRoles" == args[1] then
        listRoles()
    elseif "removeRole" == args[1] then
        removeRole(args[2], args[3])
    elseif "updateRaceData" == args[1] then
        updateRaceData()
    elseif "updateTrack" == args[1] then
        updateTrack(args[2])
    else
        print("Unknown command.")
    end
end, true)

AddEventHandler("playerDropped", function()
    print("playerDropped")
    local source = source

    -- unregister race registered by dropped player that has not started
    if races[source] ~= nil and STATE_REGISTERING == races[source].state then
        races[source] = nil
        TriggerClientEvent("races:unregister", -1, source)
    end

    -- make sure this is last code block in function because of early return if player found in race
    -- remove dropped player from the race they are joined to
    for i, race in pairs(races) do
        for netID, player in pairs(race.players) do
            if player.source == source then
                --Remove player from gridLineup
                for j = 1, #gridLineup do
                    if gridLineup[j] == race.players[netID].source then
                        table.remove(gridLineup, j)
                        break
                    end
                end

                if STATE_REGISTERING == race.state then
                    print("removing racer from race")

                    OnPlayerLeave(race, i, netID, source)
                    --TODO:Find the ready state of player and remove appropriately, probably need an array with the net ids as indexs for ready
                else
                    TriggerEvent("races:removeFromLeaderboard", i, netID)
                    TriggerEvent("races:finish", i, netID, nil, 0, -1, -1, "", source)
                end
                return
            end
        end
    end
end)

RegisterNetEvent("races:init")
AddEventHandler("races:init", function()
    local source = source

    TriggerClientEvent("races:roles", source, getRoleBits(source))

    -- register any races created before player joined
    for rIndex, race in pairs(races) do
        if STATE_REGISTERING == race.state then
            local rdata = {
                rtype = race.rtype,
                restrict = race.restrict,
                vclass = race.vclass,
                svehicle = race.svehicle,
                vehicleList = race.vehicleList,
                specialClass = race.specialClass
            }
            TriggerClientEvent("races:register", source, rIndex, race.waypointCoords[1], race.isPublic, race.trackName,
                race.owner, race.tier, race.laps, race.timeout, rdata)
        end
    end

    local allVehicles = json.decode(LoadRacesFile('vehicles.json'))

    if (allVehicles == nil) then
        notifyPlayer(source, "Error opening file vehicles.json for read")
        return
    end

    table.sort(allVehicles)
    allVehicles = removeDuplicates(allVehicles)

    TriggerClientEvent("races:allVehicles", source, allVehicles)
end)

RegisterNetEvent("races:request")
AddEventHandler("races:request", function(roleBit)
    local source = source
    if roleBit ~= nil then
        if ROLE_EDIT == roleBit or ROLE_REGISTER == roleBit or ROLE_SPAWN == roleBit then
            if nil == requests[source] then
                if roleBit & requirePermissionBits ~= 0 then
                    local license = GetPlayerIdentifier(source, 0)
                    if license ~= nil then
                        local rolesData = LoadRacesFile('rolesData.json')
                        if rolesData ~= nil then
                            local roleType = "SPAWN"
                            if ROLE_EDIT == roleBit then
                                roleType = "EDIT"
                            elseif ROLE_REGISTER == roleBit then
                                roleType = "REGISTER"
                            end
                            license = string.sub(license, 9)
                            if nil == rolesData[license] then
                                requests[source] = { name = GetPlayerName(source), roleBit = roleBit }
                                sendMessage(source, "Request for " .. roleType .. " role submitted.")
                            else
                                if 0 == rolesData[license].roleBits & roleBit then
                                    requests[source] = { name = GetPlayerName(source), roleBit = roleBit }
                                    sendMessage(source, "Request for " .. roleType .. " role submitted.")
                                else
                                    sendMessage(source, "Request for " .. roleType .. " role already approved.\n")
                                end
                            end
                        else
                            sendMessage("Could not load roles data.")
                        end
                    else
                        sendMessage(source, "Could not get license for player source ID: " .. source .. "\n")
                    end
                else
                    sendMessage(source, "Permission not required.\n")
                end
            else
                sendMessage(source, "Previous request is pending approval.")
            end
        else
            sendMessage(source, "Invalid role.\n")
        end
    else
        sendMessage(source, "Ignoring request event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:load")
AddEventHandler("races:load", function(isPublic, trackName)
    local source = source
    if isPublic ~= nil and trackName ~= nil then
        local track = loadTrack(isPublic, source, trackName)
        if track ~= nil then
            TriggerClientEvent("races:load", source, isPublic, trackName, track.waypointCoords)
        else
            sendMessage(source,
                "Cannot load.   " ..
                (true == isPublic and "Public" or "Private") .. " track '" .. trackName .. "' not found.\n")
        end
    else
        sendMessage(source, "Ignoring load track event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:save")
AddEventHandler("races:save", function(isPublic, trackName, waypointCoords)
    local source = source
    if 0 == getRoleBits(source) & ROLE_EDIT then
        sendMessage(source, "Permission required.\n")
        return
    end
    if isPublic ~= nil and trackName ~= nil and waypointCoords ~= nil then
        local track = loadTrack(isPublic, source, trackName)
        if nil == track then
            track = { waypointCoords = waypointCoords, bestLaps = {} }
            if true == saveTrack(isPublic, source, trackName, track) then
                TriggerClientEvent("races:save", source, isPublic, trackName)
                TriggerEvent("races:trackNames", isPublic, source)
            else
                sendMessage(source,
                    "Error saving " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
            end
        else
            sendMessage(source,
                (true == isPublic and "Public" or "Private") ..
                " track '" .. trackName .. "' exists.  Use 'overwrite' command instead.\n")
        end
    else
        sendMessage(source, "Ignoring save track event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:overwrite")
AddEventHandler("races:overwrite", function(isPublic, trackName, waypointCoords)
    local source = source
    if 0 == getRoleBits(source) & ROLE_EDIT then
        sendMessage(source, "Permission required.\n")
        return
    end
    if isPublic ~= nil and trackName ~= nil and waypointCoords ~= nil then
        local track = loadTrack(isPublic, source, trackName)
        if track ~= nil then
            track = { waypointCoords = waypointCoords, bestLaps = {} }
            if true == saveTrack(isPublic, source, trackName, track) then
                TriggerClientEvent("races:overwrite", source, isPublic, trackName)
            else
                sendMessage(source,
                    "Error overwriting " ..
                    (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
            end
        else
            sendMessage(source,
                (true == isPublic and "Public" or "Private") ..
                " track '" .. trackName .. "' does not exist.  Use 'save' command instead.\n")
        end
    else
        sendMessage(source, "Ignoring overwrite track event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:delete")
AddEventHandler("races:delete", function(isPublic, trackName)
    local source = source
    if 0 == getRoleBits(source) & ROLE_EDIT then
        sendMessage(source, "Permission required.\n")
        return
    end
    if isPublic ~= nil and trackName ~= nil then
        local track = loadTrack(isPublic, source, trackName)
        if track ~= nil then
            if true == saveTrack(isPublic, source, trackName, nil) then
                TriggerEvent("races:trackNames", isPublic, source)
                sendMessage(source,
                    "Deleted " .. (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
            else
                sendMessage(source,
                    "Error deleting " ..
                    (true == isPublic and "public" or "private") .. " track '" .. trackName .. "'.\n")
            end
        else
            sendMessage(source,
                "Cannot delete.  " ..
                (true == isPublic and "Public" or "Private") .. " track '" .. trackName .. "' not found.\n")
        end
    else
        sendMessage(source, "Ignoring delete track event.  Invalid parameters.\n")
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
            sendMessage(source,
                "Cannot list best lap times.   " ..
                (true == isPublic and "Public" or "Private") .. " track '" .. trackName .. "' not found.\n")
        end
    else
        sendMessage(source, "Ignoring best lap times event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:list")
AddEventHandler("races:list", function(isPublic)
    local source = source
    if isPublic ~= nil then
        local license = true == isPublic and "PUBLIC" or GetPlayerIdentifier(source, 0)
        if license ~= nil then
            local raceData = LoadRacesFile('raceData.json')
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
                        sendMessage(source, msg)
                    else
                        sendMessage(source, "No saved " .. (true == isPublic and "public" or "private") .. " tracks.\n")
                    end
                else
                    sendMessage(source, "No saved " .. (true == isPublic and "public" or "private") .. " tracks.\n")
                end
            else
                sendMessage(source, "Could not load race data.\n")
            end
        else
            sendMessage(source, "Could not get license for player source ID: " .. source .. "\n")
        end
    else
        sendMessage(source, "Ignoring list event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:register")
AddEventHandler("races:register", function(waypointCoords, isPublic, trackName, tier, laps, timeout, rdata)
    local source = source
    if 0 == getRoleBits(source) & ROLE_REGISTER then
        sendMessage(source, "Permission required.\n")
        return
    end
    if waypointCoords ~= nil and isPublic ~= nil and tier ~= nil and laps ~= nil and timeout ~= nil and rdata ~= nil then
        if laps > 0 then
            if timeout >= 0 then
                if nil == races[source] then
                    local umsg = ""
                    if "rest" == rdata.rtype then
                        if nil == rdata.restrict then
                            sendMessage(source, "Cannot register.  Invalid restricted vehicle.\n")
                            return
                        end
                        umsg = " : using '" .. rdata.restrict .. "' vehicle"
                    elseif "class" == rdata.rtype then
                        if nil == rdata.vclass or rdata.vclass < -1 or rdata.vclass > 21 then
                            sendMessage(source, "Cannot register.  Invalid vehicle class.\n")
                            return
                        end
                        if -1 == rdata.vclass and #rdata.vehicleList == 0 then
                            sendMessage(source, "Cannot register.  Vehicle list is empty.\n")
                            return
                        end
                        umsg = " : using " .. getClassName(rdata.vclass) .. " vehicle class"
                    elseif "rand" == rdata.rtype then
                        if #rdata.vehicleList == 0 then
                            sendMessage(source, "Cannot register.  Vehicle list is empty.\n")
                            return
                        end
                        umsg = " : using random "
                        if rdata.vclass ~= nil then
                            if (rdata.vclass < 0 or rdata.vclass > 21) then
                                sendMessage(source, "Cannot register.  Invalid vehicle class.\n")
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
                    elseif rdata.rtype ~= nil then
                        sendMessage(source, "Cannot register.  Unknown race type.\n")
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
                        ("by %s : tier %s : Special Class %s : %d lap(s)"):format(owner, tier, rdata.specialClass, laps)
                    msg = msg .. umsg .. "\n"
                    if false == distValid then
                        msg = msg .. "Prize distribution table is invalid\n"
                    end
                    sendMessage(source, msg)
                    races[source] = {
                        state = STATE_REGISTERING,
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
                        gridPositions = {}
                    }
                    TriggerClientEvent("races:register", -1, source, waypointCoords[1], isPublic, trackName,
                        owner, tier, laps, timeout, rdata)
                else
                    if STATE_RACING == races[source].state then
                        sendMessage(source, "Cannot register.  Previous race in progress.\n")
                    else
                        sendMessage(source, "Cannot register.  Previous race registered.  Unregister first.\n")
                    end
                end
            else
                sendMessage(source, "Invalid DNF timeout.\n")
            end
        else
            sendMessage(source, "Invalid number of laps.\n")
        end
    else
        sendMessage(source, "Ignoring register event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:unregister")
AddEventHandler("races:unregister", function()
    local source = source
    if 0 == getRoleBits(source) & ROLE_REGISTER then
        sendMessage(source, "Permission required.\n")
        return
    end
    if races[source] ~= nil then
        races[source] = nil
        TriggerClientEvent("races:unregister", -1, source)
        sendMessage(source, "Race unregistered.\n")
    else
        sendMessage(source, "Cannot unregister.  No race registered.\n")
    end
end)

RegisterNetEvent("races:endrace")
AddEventHandler("races:endrace", function()
    local source = source
    if races[source] ~= nil then
        TriggerClientEvent("races:leave", -1)
        sendMessage(source, "Race Ended.\n")
    else
        sendMessage(source, "Cannot End race.  You have no active race.\n")
    end
end)

RegisterNetEvent("races:grid")
AddEventHandler("races:grid", function()
    local source = source

    --#region Validation
    if 0 == getRoleBits(source) & ROLE_REGISTER then
        sendMessage(source, "Permission required.\n")
        return
    end

    if races[source] == nil then
        sendMessage(source, "Cannot setup grid. Race does not exist.\n")
    end

    if STATE_REGISTERING ~= races[source].state then
        sendMessage(source, "Cannot setup grid.  Race in progress.\n")
    end

    local gridPositions = GenerateStartingGrid(races[source].waypointCoords[1], #GetPlayers())

    if (gridPositions ~= nil) then
        PlaceRacersOnGrid(gridPositions, races[source].players, #races[source].players,
            races[source].waypointCoords[1].heading)
    end
end)

RegisterNetEvent("races:autojoin")
AddEventHandler("races:autojoin", function()
    local source = source

    --#region Validation
    if 0 == getRoleBits(source) & ROLE_REGISTER then
        sendMessage(source, "Permission required.\n")
        return
    end

    if races[source] == nil then
        sendMessage(source, "Cannot setup grid. Race does not exist.\n")
    end

    if STATE_REGISTERING ~= races[source].state then
        sendMessage(source, "Cannot setup grid.  Race in progress.\n")
    end

    TriggerClientEvent("races:autojoin", -1, source)
end)

RegisterNetEvent("races:readyState")
AddEventHandler("races:readyState", function(raceIndex, ready, netID)
    local source = source
    if races[raceIndex] == nil then
        print("can't find race to ready")
        return
    end

    local numReady = races[raceIndex].numReady
    local numRacing = races[raceIndex].numRacing

    if ready then
        numReady += 1
    else
        numReady -= 1
    end

    if numReady < 0 then
        numReady = 0
    end

    if numReady > numRacing then
        numReady = numRacing
    end

    races[raceIndex].players[netID].ready = ready
    races[raceIndex].numReady = numReady
    races[raceIndex].numRacing = numRacing

    TriggerClientEvent("races:sendReadyData", -1, ready, source, GetPlayerName(source))
end)

function StartRace(race, source, delay)
    race.countdown = false
    race.countdownTimeStart = 0
    race.state = STATE_RACING
    for _, player in pairs(race.players) do
        TriggerClientEvent("races:start", player.source, source, delay)
    end
    TriggerClientEvent("races:hide", -1, source) -- hide race so no one else can join
    sendMessage(source, "Race started.\n")
end

RegisterNetEvent("races:start")
AddEventHandler("races:start", function(delay, override)
    local source = source
    if 0 == getRoleBits(source) & ROLE_REGISTER then
        sendMessage(source, "Permission required.\n")
        return
    end

    local race = races[source]

    if delay ~= nil then
        if race ~= nil then
            if STATE_REGISTERING == race.state then
                if delay >= 5 then
                    if race.numRacing > 0 then
                        if (race.numReady ~= race.numRacing and override == false) then
                            sendMessage(source, "Cannot start. Not all Players ready.\n")
                            return
                        end

                        if race.countdown == true then
                            StopRaceCountdown(source)
                        end

                        race.state = STATE_RACING

                        local sourceJoined = false
                        for _, player in pairs(race.players) do
                            TriggerClientEvent("races:start", player.source, source, delay)
                            if player.source == source then
                                sourceJoined = true
                            end
                        end
                        TriggerClientEvent("races:hide", -1, source) -- hide race so no one else can join
                        sendMessage(source, "Race started.\n")
                    else
                        sendMessage(source, "Cannot start.  No players have joined race.\n")
                    end
                else
                    sendMessage(source, "Cannot start.  Invalid delay.\n")
                end
            else
                sendMessage(source, "Cannot start.  Race in progress.\n")
            end
        else
            sendMessage(source, "Cannot start.  Race does not exist.\n")
        end
    else
        sendMessage(source, "Ignoring start event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:loadLst")
AddEventHandler("races:loadLst", function(isPublic, name)
    local source = source
    if 0 == getRoleBits(source) & ROLE_REGISTER then
        sendMessage(source, "Permission required.\n")
        return
    end
    if isPublic ~= nil and name ~= nil then
        local list = loadVehicleList(isPublic, source, name)
        if list ~= nil then
            TriggerClientEvent("races:loadLst", source, isPublic, name, list)
        else
            sendMessage(source,
                "Cannot load.   " ..
                (true == isPublic and "Public" or "Private") .. " vehicle list '" .. name .. "' not found.\n")
        end
    else
        sendMessage(source, "Ignoring load vehicle list event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:saveLst")
AddEventHandler("races:saveLst", function(isPublic, name, vehicleList)
    local source = source
    if 0 == getRoleBits(source) & ROLE_REGISTER then
        sendMessage(source, "Permission required.\n")
        return
    end
    if isPublic ~= nil and name ~= nil and vehicleList ~= nil then
        if loadVehicleList(isPublic, source, name) == nil then
            if true == saveVehicleList(isPublic, source, name, vehicleList) then
                TriggerEvent("races:listNames", isPublic, source)
                sendMessage(source,
                    "Saved " .. (true == isPublic and "public" or "private") .. " vehicle list '" .. name .. "'.\n")
            else
                sendMessage(source,
                    "Error saving " ..
                    (true == isPublic and "public" or "private") .. " vehicle list '" .. name .. "'.\n")
            end
        else
            sendMessage(source,
                (true == isPublic and "Public" or "Private") ..
                " vehicle list '" .. name .. "' exists.  Use 'overwrite' command instead.\n")
        end
    else
        sendMessage(source, "Ignoring save vehicle list event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:overwriteLst")
AddEventHandler("races:overwriteLst", function(isPublic, name, vehicleList)
    local source = source
    if 0 == getRoleBits(source) & ROLE_EDIT then
        sendMessage(source, "Permission required.\n")
        return
    end
    if isPublic ~= nil and name ~= nil and vehicleList ~= nil then
        local list = loadVehicleList(isPublic, source, name)
        if list ~= nil then
            if true == saveVehicleList(isPublic, source, name, vehicleList) then
                --TriggerClientEvent("races:overwrite", source, isPublic, trackName)
                sendMessage(source,
                    "Overwrote " .. (true == isPublic and "public" or "private") .. " vehicle list '" .. name .. "'.\n")
            else
                sendMessage(source,
                    "Error overwriting " ..
                    (true == isPublic and "public" or "private") .. " vehicle list '" .. name .. "'.\n")
            end
        else
            sendMessage(source,
                (true == isPublic and "Public" or "Private") ..
                " vehicle list '" .. name .. "' does not exist.  Use 'save' command instead.\n")
        end
    else
        sendMessage(source, "Ignoring overwrite vehicle list event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:deleteLst")
AddEventHandler("races:deleteLst", function(isPublic, name)
    local source = source
    if 0 == getRoleBits(source) & ROLE_REGISTER then
        sendMessage(source, "Permission required.\n")
        return
    end
    if isPublic ~= nil and name ~= nil then
        local list = loadVehicleList(isPublic, source, name)
        if list ~= nil then
            if true == saveVehicleList(isPublic, source, name, nil) then
                TriggerEvent("races:listNames", isPublic, source)
                sendMessage(source,
                    "Deleted " .. (true == isPublic and "public" or "private") .. " vehicle list '" .. name .. "'.\n")
            else
                sendMessage(source,
                    "Error deleting " ..
                    (true == isPublic and "public" or "private") .. " vehicle list '" .. name .. "'.\n")
            end
        else
            sendMessage(source,
                "Cannot delete.  " ..
                (true == isPublic and "Public" or "Private") .. " vehicle list '" .. name .. "' not found.\n")
        end
    else
        sendMessage(source, "Ignoring delete vehicle list event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:listLsts")
AddEventHandler("races:listLsts", function(isPublic)
    local source = source
    if 0 == getRoleBits(source) & ROLE_REGISTER then
        sendMessage(source, "Permission required.\n")
        return
    end
    if isPublic ~= nil then
        local license = true == isPublic and "PUBLIC" or GetPlayerIdentifier(source, 0)
        if license ~= nil then
            local vehicleListData = LoadRacesFile('vehicleListData.json')
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
                        sendMessage(source, msg)
                    else
                        sendMessage(source,
                            "No saved " .. (true == isPublic and "public" or "private") .. " vehicle lists.\n")
                    end
                else
                    sendMessage(source,
                        "No saved " .. (true == isPublic and "public" or "private") .. " vehicle lists.\n")
                end
            else
                sendMessage(source, "Could not load vehicle list data.\n")
            end
        else
            sendMessage(source, "Could not get license for player source ID: " .. source .. "\n")
        end
    else
        sendMessage(source, "Ignoring list vehicle lists event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:leave")
AddEventHandler("races:leave", function(rIndex, netID)
    local source = source
    if rIndex ~= nil and netID ~= nil then
        if races[rIndex] ~= nil then
            if STATE_REGISTERING == races[rIndex].state then
                if races[rIndex].players[netID] ~= nil then
                    for i = 1, #gridLineup do
                        if gridLineup[i] == races[rIndex].players[netID].source then
                            table.remove(gridLineup, i)
                            break
                        end
                    end

                    OnPlayerLeave(races[rIndex], rIndex, netID, source)
                else
                    sendMessage(source, "Cannot leave.  Not a member of this race.\n")
                end
            else
                -- player will trigger races:finish event
                sendMessage(source, "Cannot leave.  Race in progress.\n")
            end
        else
            sendMessage(source, "Cannot leave.  Race does not exist.\n")
        end
    else
        sendMessage(source, "Ignoring leave event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:removeFromLeaderboard")
AddEventHandler("races:removeFromLeaderboard", function(rIndex, netID)
    TriggerClientEvent("races:removeFromLeaderboard", -1, races[rIndex].players[netID].source)
end)

RegisterNetEvent("races:rivals")
AddEventHandler("races:rivals", function(rIndex)
    local source = source
    if rIndex ~= nil then
        if races[rIndex] ~= nil then
            local names = {}
            for _, player in pairs(races[rIndex].players) do
                names[#names + 1] = player.playerName
            end
            table.sort(names)
            local msg = "Competitors:\n"
            for _, name in ipairs(names) do
                msg = msg .. name .. "\n"
            end
            sendMessage(source, msg)
        else
            sendMessage(source, "Cannot list competitors.  Race does not exist.\n")
        end
    else
        sendMessage(source, "Ignoring rivals event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:join")
AddEventHandler("races:join", function(rIndex, netID)
    print(string.format("NetID:%s Joined", netID))
    local source = source
    if rIndex ~= nil and netID ~= nil then
        if races[rIndex] ~= nil then
            if STATE_REGISTERING == races[rIndex].state then
                local playerName = GetPlayerName(source)
                for nID, player in pairs(races[rIndex].players) do
                    TriggerClientEvent("races:addRacer", player.source, netID, playerName)
                end
                races[rIndex].numRacing = races[rIndex].numRacing + 1
                races[rIndex].players[netID] = {
                    source = source,
                    playerName = playerName,
                    numWaypointsPassed = -1,
                    data = -1,
                    ready = false,
                }

                local racerDictionary = mapToArray(races[rIndex].players,
                    function(racer)
                        return {
                            source = racer.source,
                            playerName = racer.playerName,
                            ready = racer.ready,
                        }
                    end)

                if UseRaceResults == false then
                    print("No race results, adding racer")
                    table.insert(gridLineup, source)
                end
                TriggerClientEvent("races:joinnotification", -1, playerName, racerDictionary, rIndex,
                    races[rIndex].trackName,
                    races[rIndex].numReady, races[rIndex].numRacing, races[rIndex].waypointCoords[1])
                TriggerClientEvent("races:join", source, rIndex, races[rIndex].tier, races[rIndex].specialClass,
                    races[rIndex].waypointCoords)
            else
                notifyPlayer(source, "Cannot join.  Race in progress.\n")
            end
        else
            notifyPlayer(source, "Cannot join.  Race does not exist.\n")
        end
    else
        notifyPlayer(source, "Ignoring join event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:finish")
AddEventHandler("races:finish",
    function(rIndex, netID, numWaypointsPassed, finishTime, bestLapTime, vehicleName, altSource)
        local source = altSource or source
        if rIndex ~= nil and netID ~= nil and numWaypointsPassed ~= nil and finishTime ~= nil and bestLapTime ~= nil and vehicleName ~= nil then
            local race = races[rIndex]
            if race ~= nil then
                if STATE_RACING == race.state then
                    if race.players[netID] ~= nil then
                        race.players[netID].numWaypointsPassed = numWaypointsPassed
                        race.players[netID].data = finishTime

                        for nID, player in pairs(race.players) do
                            TriggerClientEvent("races:finish", player.source, rIndex, race.players[netID].playerName,
                                finishTime, bestLapTime, vehicleName)
                            if nID ~= netID then
                                TriggerClientEvent("races:delRacer", player.source, netID)
                            end
                        end

                        race.results[#race.results + 1] = {
                            source = source,
                            playerName = race.players[netID].playerName,
                            finishTime = finishTime,
                            bestLapTime = bestLapTime,
                            vehicleName = vehicleName
                        }

                        race.numRacing = race.numRacing - 1
                        if 0 == race.numRacing then
                            table.sort(race.results, function(p0, p1)
                                return
                                    (p0.finishTime >= 0 and (-1 == p1.finishTime or p0.finishTime < p1.finishTime)) or
                                    (-1 == p0.finishTime and -1 == p1.finishTime and (p0.bestLapTime >= 0 and (-1 == p1.bestLapTime or p0.bestLapTime < p1.bestLapTime)))
                            end)

                            if true == distValid and race.rtype ~= "rand" then
                                local numRacers = #race.results
                                local numFinished = 0

                                for i, result in ipairs(race.results) do
                                    if result.finishTime ~= -1 then
                                        numFinished = numFinished + 1
                                    end
                                end
                            end

                            for _, player in pairs(race.players) do
                                TriggerClientEvent("races:results", player.source, rIndex, race.results)
                            end

                            TriggerClientEvent("races:clearLeaderboard", -1)

                            saveResults(race)

                            SetNextGridLineup(race.results)

                            if race.trackName ~= nil then
                                updateBestLapTimes(rIndex)
                            end

                            races[rIndex] = nil -- delete race after all players finish
                        end
                    else
                        notifyPlayer(source, "Cannot finish.  Not a member of this race.\n")
                    end
                else
                    notifyPlayer(source, "Cannot finish.  Race not in progress.\n")
                end
            else
                notifyPlayer(source, "Cannot finish.  Race does not exist.\n")
            end
        else
            notifyPlayer(source, "Ignoring finish event.  Invalid parameters.\n")
        end
    end)

RegisterNetEvent("races:report")
AddEventHandler("races:report", function(rIndex, netID, numWaypointsPassed, distance)
    if rIndex ~= nil and netID ~= nil and numWaypointsPassed ~= nil and distance ~= nil then
        if races[rIndex] ~= nil then
            if races[rIndex].players[netID] ~= nil then
                races[rIndex].players[netID].numWaypointsPassed = numWaypointsPassed
                races[rIndex].players[netID].data = distance
            else
                notifyPlayer(source, "Cannot report.  Not a member of this race.\n")
            end
        else
            notifyPlayer(source, "Cannot report.  Race does not exist.\n")
        end
    else
        notifyPlayer(source, "Ignoring report event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:trackNames")
AddEventHandler("races:trackNames", function(isPublic, altSource)
    local source = altSource or source
    if isPublic ~= nil then
        local trackNames = {}

        local license = true == isPublic and "PUBLIC" or GetPlayerIdentifier(source, 0)
        if license ~= nil then
            local raceData = LoadRacesFile('raceData.json')
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
                sendMessage(source, "Could not load race data.\n")
            end
        else
            sendMessage(source, "Could not get license for player source ID: " .. source .. "\n")
        end

        TriggerClientEvent("races:trackNames", source, isPublic, trackNames)
    else
        sendMessage(source, "Ignoring list event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:listNames")
AddEventHandler("races:listNames", function(isPublic, altSource)
    local source = altSource or source
    if isPublic ~= nil then
        local listNames = {}

        local license = true == isPublic and "PUBLIC" or GetPlayerIdentifier(source, 0)
        if license ~= nil then
            local vehicleListData = LoadRacesFile('vehicleListData.json')
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
                sendMessage(source, "Could not load vehicle list data.\n")
            end
        else
            sendMessage(source, "Could not get license for player source ID: " .. source .. "\n")
        end

        TriggerClientEvent("races:listNames", source, isPublic, listNames)
    else
        sendMessage(source, "Ignoring list vehicle lists event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:update_best_lap_time")
AddEventHandler("races:update_best_lap_time", function(minutes, seconds)
    local source = source
    TriggerClientEvent("races:update_best_lap_time", -1, source, minutes, seconds)
end)

RegisterNetEvent("races:sendvehiclename")
AddEventHandler("races:sendvehiclename", function(currentVehicleName)
    local source = source
    TriggerClientEvent("races:sendvehiclename", -1, source, currentVehicleName)
end)

RegisterNetEvent("races:sendCheckpointTime")
AddEventHandler("races:sendCheckpointTime", function(waypointsPassed, lapTime)
    local source = source

    local racersAhead = {}
    local racersBehind = {}

    print("Sending Checkpoint Time")
    print(waypointsPassed)
    print(source)

    table.insert(checkpointTimes, {})

    for racerAheadSource, racerAheadLapTime in pairs(checkpointTimes[waypointsPassed]) do
        if (racerAheadSource ~= source) then
            print("checkpointTimes at [" .. waypointsPassed .. "][" .. racerAheadSource .. "] has values")
            print("Updating time split for " ..
                racerAheadSource ..
                " with my source " .. source .. " and a difference of " .. lapTime - racerAheadLapTime)
            TriggerClientEvent("races:updateTimeSplit", racerAheadSource, source, lapTime - racerAheadLapTime)

            table.insert(racersAhead, { source = racerAheadSource, timeSplit = (racerAheadLapTime - lapTime) })
        end
    end

    checkpointTimes[waypointsPassed][source] = lapTime

    print(#checkpointTimes)
    print(checkpointTimes)
    print(#checkpointTimes[waypointsPassed])
    print(checkpointTimes[waypointsPassed])
    print(checkpointTimes[waypointsPassed][source])

    if (#racersAhead > 0) then
        TriggerClientEvent("races:compareTimeSplit", source, racersAhead)
    end
end)


Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)

        for rIndex, race in pairs(races) do
            if STATE_REGISTERING == race.state then
                CheckReady(race, rIndex)
                if race.countdown == true then
                    ProcessReadyCountdown(rIndex)
                end
            elseif STATE_RACING == race.state then
                local sortedPlayers = {} -- will contain players still racing and players that finished without DNF
                local complete = true

                -- race.players[netID] = {source, playerName, numWaypointsPassed, data, coord}
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
                            data = player.data
                        }
                    end
                end

                if true == complete then -- all player clients have updated numWaypointsPassed and data
                    table.sort(sortedPlayers, function(p0, p1)
                        return (p0.numWaypointsPassed > p1.numWaypointsPassed) or
                            (p0.numWaypointsPassed == p1.numWaypointsPassed and p0.data < p1.data)
                    end)

                    local racePositions = map(sortedPlayers, function(item) return item.source end)

                    TriggerClientEvent("races:racerPositions", -1, racePositions)

                    -- players sorted into sortedPlayers table
                    for position, sortedPlayer in pairs(sortedPlayers) do
                        TriggerClientEvent("races:position", sortedPlayer.source, rIndex, position, #sortedPlayers)
                    end
                end
            end
        end
    end
end)
