--[[

Copyright (c) 2021, Neil J. Tan
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

--]]

local STATE_REGISTERING <const> = 0
local STATE_RACING <const> = 1

local raceDataFile <const> = "./resources/races/raceData.json"

local dist <const> = {60, 20, 10, 5, 3, 2}

local distValid = true
if #dist > 0 and dist[1] > 0 then
	local sum = dist[1]
	for i = 2, #dist do
		if dist[i] > 0 and dist[i - 1] >= dist[i] then
			sum = sum + dist[i]
		else
			distValid = false
			break
		end
	end
	distValid = distValid and 100 == sum
else
	distValid = false
end
if false == distValid then
    print("^1Prize distribution table is invalid.")
end

local races = {} -- races[] = {state, buyin, laps, timeout, waypointCoords[] = {x, y, z}, publicRace, savedRaceName, numRacing, players[] = {numWaypointsPassed, data, finished}, results[] = {source, playerName, finishTime, bestLapTime, vehicleName}}

local function notifyPlayer(source, msg)
    TriggerClientEvent("chat:addMessage", source, {
        color = {255, 0, 0},
        multiline = true,
        args = {"[races:server]", msg}
    })
end

local function sendMessage(source, msg)
    TriggerClientEvent("races:message", source, msg)
end

local function loadPlayerData(public, source)
    local license = true == public and "PUBLIC" or GetPlayerIdentifier(source, 0)

    local playerRaces = nil

    if license ~= nil then
        if license ~= "PUBLIC" then
            license = string.sub(license, 9)
        end

        local raceData = nil

        local file = io.open(raceDataFile, "r")
        if file ~= nil then
            raceData = json.decode(file:read("*a"));
            io.close(file)
        else
            notifyPlayer(source, "loadPlayerData: Error opening file '" .. raceDataFile .. "' for read.\n")
            return nil
        end

        if nil == raceData then
            notifyPlayer(source, "loadPlayerData: No race data.\n")
            return nil
        end

        playerRaces = raceData[license]

        if nil == playerRaces then
            playerRaces = {}
        end
    else
        notifyPlayer(source, "loadPlayerData: Could not get license.\n")
        return nil
    end

    return playerRaces
end

local function savePlayerData(public, source, data)
    local license = true == public and "PUBLIC" or GetPlayerIdentifier(source, 0)

    if license ~= nil then
        if license ~= "PUBLIC" then
            license = string.sub(license, 9)
        end

        local raceData = nil

        local file = io.open(raceDataFile, "r")
        if file ~= nil then
            raceData = json.decode(file:read("*a"));
            io.close(file)
        else
            notifyPlayer(source, "savePlayerData: Error opening file '" .. raceDataFile .. "' for read.\n")
            return false
        end

        if nil == raceData then
            notifyPlayer(source, "savePlayerData: No race data.\n")
            return false
        end

        raceData[license] = data

        file = io.open(raceDataFile, "w+")
        if file ~= nil then
            file:write(json.encode(raceData))
            io.close(file)
        else
            notifyPlayer(source, "savePlayerData: Error opening file '" .. raceDataFile .. "' for write.\n")
            return false
        end
    else
        notifyPlayer(source, "savePlayerData: Could not get license.\n")
        return false
    end

    return true
end

local function updateBestLapTimes(index)
    local playerRaces = loadPlayerData(races[index].publicRace, index)
    if playerRaces ~= nil then
        if playerRaces[races[index].savedRaceName] ~= nil then -- saved race still exists - not deleted in middle of race
            local bestLaps = playerRaces[races[index].savedRaceName].bestLaps
            for _, result in pairs(races[index].results) do
                if result.bestLapTime ~= -1 then
                    bestLaps[#bestLaps + 1] = {playerName = result.playerName, bestLapTime = result.bestLapTime, vehicleName = result.vehicleName}
                end
            end
            table.sort(bestLaps, function(p0, p1)
                return p0.bestLapTime < p1.bestLapTime
            end)
            if #bestLaps > 10 then
                for i = 11, #bestLaps do
                    bestLaps[i] = nil
                end
            end
            playerRaces[races[index].savedRaceName].bestLaps = bestLaps
            if false == savePlayerData(races[index].publicRace, index, playerRaces) then
                notifyPlayer(index, "Save error updating best lap times.\n")
            end
        else
            notifyPlayer(index, "Cannot save best lap times.  Race '" .. races[index].savedRaceName .. "' has been deleted.\n")
        end
    else
        notifyPlayer(index, "Load error updating best lap times.\n")
    end
end

local function round(f)
    return (f - math.floor(f) >= 0.5) and (math.floor(f) + 1) or math.floor(f)
end

RegisterNetEvent("races:initFunds")
AddEventHandler("races:initFunds", function(amount)
    local source = source
    SetFunds(source, amount)
end)

RegisterNetEvent("races:load")
AddEventHandler("races:load", function(public, raceName)
    local source = source
    if public ~= nil and raceName ~= nil then
        local playerRaces = loadPlayerData(public, source)
        if playerRaces ~= nil then
            if playerRaces[raceName] ~= nil then
                TriggerClientEvent("races:load", source, public, raceName, playerRaces[raceName].waypointCoords)
            else
                sendMessage(source, "Cannot load.  '" .. raceName .. "' not found.\n")
            end
        else
            sendMessage(source, "Cannot load.  Error loading data.\n")
        end
    else
        sendMessage(source, "Ignoring load event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:save")
AddEventHandler("races:save", function(public, raceName, waypointCoords)
    local source = source
    if public ~= nil and raceName ~= nil and waypointCoords ~= nil then
        local playerRaces = loadPlayerData(public, source)
        if playerRaces ~= nil then
            if nil == playerRaces[raceName] then
                playerRaces[raceName] = {waypointCoords = waypointCoords, bestLaps = {}}
                if true == savePlayerData(public, source, playerRaces) then
                    TriggerClientEvent("races:save", source, public, raceName)
                else
                    sendMessage(source, "Error saving '" .. raceName .. "'.\n")
                end
            else
                if true == public then
                    sendMessage(source, ("Public race '%s' exists.  Do public overwrite instead.\n"):format(raceName))
                else
                    sendMessage(source, ("Private race '%s' exists.  Do private overwrite instead.\n"):format(raceName))
                end
            end
        else
            sendMessage(source, "Cannot save.  Error loading data.\n")
        end
    else
        sendMessage(source, "Ignoring save event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:overwrite")
AddEventHandler("races:overwrite", function(public, raceName, waypointCoords)
    local source = source
    if public ~= nil and raceName ~= nil and waypointCoords ~= nil then
        local playerRaces = loadPlayerData(public, source)
        if playerRaces ~= nil then
            if playerRaces[raceName] ~= nil then
                playerRaces[raceName] = {waypointCoords = waypointCoords, bestLaps = {}}
                if true == savePlayerData(public, source, playerRaces) then
                    TriggerClientEvent("races:overwrite", source, public, raceName)
                else
                    sendMessage(source, "Error overwriting '" .. raceName .. "'.\n")
                end
            else
                if true == public then
                    sendMessage(source, ("Public race '%s' does not exist.  Do public save instead.\n"):format(raceName))
                else
                    sendMessage(source, ("Private race '%s' does not exist.  Do private save instead.\n"):format(raceName))
                end
            end
        else
            sendMessage(source, "Cannot overwrite.  Error loading data.\n")
        end
    else
        sendMessage(source, "Ignoring overwrite event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:delete")
AddEventHandler("races:delete", function(public, raceName)
    local source = source
    if public ~= nil and raceName ~= nil then
        local playerRaces = loadPlayerData(public, source)
        if playerRaces ~= nil then
            if playerRaces[raceName] ~= nil then
                playerRaces[raceName] = nil
                if true == savePlayerData(public, source, playerRaces) then
                    local msg = "Deleted "
                    msg = msg .. (true == public and "public" or "private")
                    msg = msg .. " race '" .. raceName .. "'.\n"
                    sendMessage(source, msg)
                else
                    sendMessage(source, "Error deleting '" .. raceName .. "'.\n")
                end
            else
                sendMessage(source, "Cannot delete.  '" .. raceName .. "' not found.\n")
            end
        else
            sendMessage(source, "Cannot delete.  Error loading data.\n")
        end
    else
        sendMessage(source, "Ignoring delete event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:blt")
AddEventHandler("races:blt", function(public, raceName)
    local source = source
    if public ~= nil and raceName ~= nil then
        local playerRaces = loadPlayerData(public, source)
        if playerRaces ~= nil then
            if playerRaces[raceName] ~= nil then
                TriggerClientEvent("races:blt", source, public, raceName, playerRaces[raceName].bestLaps)
            else
                sendMessage(source, "Cannot list best lap times.  '" .. raceName .. "' not found.\n")
            end
        else
            sendMessage(source, "Cannot list best lap times.  Error loading data.\n")
        end
    else
        sendMessage(source, "Ignoring best lap times event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:list")
AddEventHandler("races:list", function(public)
    local source = source
    if public ~= nil then
        local playerRaces = loadPlayerData(public, source)
        if playerRaces ~= nil then
            local names = {}
            for name in pairs(playerRaces) do
                names[#names + 1] = name
            end
            if #names > 0 then
                table.sort(names)
                local msg = "Saved "
                msg = msg .. (true == public and "public" or "private")
                msg = msg .. " races:\n"
                for _, name in ipairs(names) do
                    msg = msg .. name .. "\n"
                end
                sendMessage(source, msg)
            else
                sendMessage(source, "No saved races.\n")
            end
        else
            sendMessage(source, "Cannot list.  Error loading data.\n")
        end
    else
        sendMessage(source, "Ignoring list event.  Invalid parameters.\n")
   end
end)

RegisterNetEvent("races:register")
AddEventHandler("races:register", function(buyin, laps, timeout, waypointCoords, publicRace, savedRaceName)
    local source = source
    if buyin ~= nil and laps ~= nil and timeout ~= nil and waypointCoords ~= nil and publicRace ~= nil then
        if buyin >= 0 then
            if laps > 0 then
                if timeout >= 0 then
                    if nil == races[source] then
                        local owner = GetPlayerName(source)
                        races[source] = {state = STATE_REGISTERING, buyin = buyin, laps = laps, timeout = timeout, waypointCoords = waypointCoords, publicRace = publicRace, savedRaceName = savedRaceName, numRacing = 0, players = {}, results = {}}
                        TriggerClientEvent("races:register", -1, source, owner, buyin, laps, waypointCoords[1], publicRace, savedRaceName)
                        local msg = "Registered "
                        if nil == savedRaceName then
                            msg = msg .. "unsaved race "
                        else
                            msg = msg .. (true == publicRace and "publicly" or "privately")
                            msg = msg .. " saved race '" .. savedRaceName .. "' "
                        end
                        msg = msg .. ("by %s : %d buy-in : %d lap(s).\n"):format(owner, buyin, laps)
                        sendMessage(source, msg)
                        if false == distValid then
                            sendMessage(source, "Prize distribution table is invalid.\n")
                        end
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
            sendMessage(source, "Invalid buy-in amount.\n")
        end
    else
        sendMessage(source, "Ignoring register event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:unregister")
AddEventHandler("races:unregister", function()
    local source = source
    if races[source] ~= nil then
        for i in pairs(races[source].players) do
            Deposit(i, races[source].buyin)
            sendMessage(i, races[source].buyin .. " was deposited in your funds.\n")
        end
        races[source] = nil
        TriggerClientEvent("races:unregister", -1, source)
        sendMessage(source, "Race unregistered.\n")
    else
        sendMessage(source, "Cannot unregister.  No race registered.\n")
    end
end)

RegisterNetEvent("races:start")
AddEventHandler("races:start", function(delay)
    local source = source
    if delay ~= nil then
        if races[source] ~= nil then
            if STATE_REGISTERING == races[source].state then
                if delay >= 0 then
                    if races[source].numRacing > 0 then
                        races[source].state = STATE_RACING
                        for i in pairs(races[source].players) do
                            TriggerClientEvent("races:start", i, delay)
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

RegisterNetEvent("races:leave")
AddEventHandler("races:leave", function(index)
    local source = source
    if index ~= nil then
        if races[index] ~= nil then
            if STATE_REGISTERING == races[index].state then
                if races[index].players[source] ~= nil then
                    races[index].players[source] = nil
                    races[index].numRacing = races[index].numRacing - 1
                    Deposit(source, races[index].buyin)
                    sendMessage(source, races[index].buyin .. " was deposited in your funds.\n")
                else
                    sendMessage(source, "Cannot leave.  Not a member of this race.\n")
                end
            else
                sendMessage(source, "Cannot leave.  Race in progress.\n")
            end
        else
            sendMessage(source, "Cannot leave.  Race does not exist.\n")
        end
    else
        sendMessage(source, "Ignoring leave event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:rivals")
AddEventHandler("races:rivals", function(index)
    local source = source
    if index ~= nil then
        if races[index] ~= nil then
            if races[index].players[source] ~= nil then
                local names = {}
                for i in pairs(races[index].players) do
                    names[#names + 1] = GetPlayerName(i)
                end
                if #names > 0 then
                    table.sort(names)
                    local msg = "Competitors:\n"
                    for _, name in ipairs(names) do
                        msg = msg .. name .. "\n"
                    end
                    sendMessage(source, msg)
                else
                    sendMessage(source, "No competitors yet.\n")
                end
            else
                sendMessage(source, "Cannot list competitors.  Not a member of this race.\n")
            end
        else
            sendMessage(source, "Cannot list competitors.  Race does not exist.\n")
        end
    else
        sendMessage(source, "Ignoring rivals event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:viewFunds")
AddEventHandler("races:viewFunds", function()
    local source = source
    sendMessage(source, "Available funds: " .. GetFunds(source) .. "\n")
end)

RegisterNetEvent("races:join")
AddEventHandler("races:join", function(index)
    local source = source
    if index ~= nil then
        if races[index] ~= nil then
            if GetFunds(source) >= races[index].buyin then
                if STATE_REGISTERING == races[index].state then
                    races[index].numRacing = races[index].numRacing + 1
                    races[index].players[source] = {numWaypointsPassed = -1, data = -1, finished = false}
                    Withdraw(source, races[index].buyin)
                    sendMessage(source, races[index].buyin .. " was withdrawn from your funds.\n")
                    TriggerClientEvent("races:join", source, index, races[index].timeout, races[index].waypointCoords)
                else
                    notifyPlayer(source, "Cannot join.  Race in progress.\n")
                end
            else
                notifyPlayer(source, "Cannot join.  Insufficient funds.\n")
            end
        else
            notifyPlayer(source, "Cannot join.  Race does not exist.\n")
        end
    else
        notifyPlayer(source, "Ignoring join event.  Invalid parameters.\n")
    end
end)

RegisterNetEvent("races:finish")
AddEventHandler("races:finish", function(index, numWaypointsPassed, finishTime, bestLapTime, vehicleName)
    local source = source
    if index ~= nil and numWaypointsPassed ~= nil and finishTime ~= nil and bestLapTime ~= nil and vehicleName ~= nil then
        if races[index] ~= nil then
            if STATE_RACING == races[index].state then
                if races[index].players[source] ~= nil then
                    races[index].players[source].numWaypointsPassed = numWaypointsPassed
                    races[index].players[source].data = finishTime
                    races[index].players[source].finished = true

                    local playerName = GetPlayerName(source)

                    for i in pairs(races[index].players) do
                        TriggerClientEvent("races:finish", i, playerName, finishTime, bestLapTime, vehicleName)
                    end

                    races[index].results[#(races[index].results) + 1] = {source = source, playerName = playerName, finishTime = finishTime, bestLapTime = bestLapTime, vehicleName = vehicleName}

                    races[index].numRacing = races[index].numRacing - 1
                    if 0 == races[index].numRacing then
                        table.sort(races[index].results, function(p0, p1)
                            return
                                (p0.finishTime >= 0 and (-1 == p1.finishTime or p0.finishTime < p1.finishTime)) or
                                (-1 == p0.finishTime and -1 == p1.finishTime and (p0.bestLapTime >= 0 and (-1 == p1.bestLapTime or p0.bestLapTime < p1.bestLapTime)))
                        end)

                        local winningsRL = {}
                        for _, result in pairs(races[index].results) do
                            winningsRL[result.source] = races[index].buyin
                        end

                        if true == distValid then
                            local numRacers = #(races[index].results)
                            local numFinished = 0
                            local totalPool = numRacers * races[index].buyin
                            local pool = totalPool
                            local winnings = {}

                            for i, result in ipairs(races[index].results) do
                                winnings[i] = {payout = races[index].buyin, source = result.source}
                                if result.finishTime ~= -1 then
                                    numFinished = numFinished + 1
                                end
                            end

                            if numFinished >= #dist then
                                for i = numFinished + 1, numRacers do
                                    winnings[i].payout = 0
                                end
                                local payout = round(dist[#dist] / 100 * totalPool / (numFinished - #dist + 1))
                                for i = #dist, numFinished do
                                    winnings[i].payout = payout
                                    pool = pool - payout
                                end
                                for i = 2, #dist - 1 do
                                    payout = round(dist[i] / 100 * totalPool)
                                    winnings[i].payout = payout
                                    pool = pool - payout
                                end
                                winnings[1].payout = pool
                            elseif numFinished > 0 then
                                for i = numFinished + 1, numRacers do
                                    winnings[i].payout = 0
                                end
                                local bonus = dist[numFinished + 1]
                                for i = numFinished + 2, #dist do
                                    bonus = bonus + dist[i]
                                end
                                bonus = bonus / numFinished
                                for i = 2, numFinished do
                                    local payout = ((dist[i] + bonus) / 100 * totalPool)
                                    winnings[i].payout = payout
                                    pool = pool - payout
                                end
                                winnings[1].payout = pool
                            end

                            for _, winning in pairs(winnings) do
                                winningsRL[winning.source] = winning.payout
                            end
                        end

                        for i in pairs(races[index].players) do
                            TriggerClientEvent("races:results", i, races[index].results)
                            Deposit(i, winningsRL[i])
                            notifyPlayer(i, winningsRL[i] .. " was deposited in your funds.\n")
                        end

                        if races[index].savedRaceName ~= nil then
                            updateBestLapTimes(index)
                        end
                        races[index] = nil -- delete race after all players finish
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
AddEventHandler("races:report", function(index, numWaypointsPassed, distance)
    local source = source
    if index ~= nil and numWaypointsPassed ~= nil and distance ~= nil then
        if races[index] ~= nil then
            if races[index].players[source] ~= nil then
                races[index].players[source].numWaypointsPassed = numWaypointsPassed
                races[index].players[source].data = distance
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

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        for _, race in pairs(races) do
            if STATE_RACING == race.state then
                local sortedPlayers = {} -- will contain players still racing and players that finished without DNF
                local complete = true

                -- race.players[] = {numWaypointsPassed, data}
                for i, player in pairs(race.players) do
                    if -1 == player.numWaypointsPassed then -- player client hasn't updated numWaypointsPassed and data
                        complete = false
                        break
                    end

                    -- player.data will be travel distance to next waypoint or finish time; finish time will be -1 if player DNF
                    -- if player.data == -1 then player did not finish race - do not include in sortedPlayers
                    if player.data ~= -1 then
                        sortedPlayers[#sortedPlayers + 1] = {index = i, numWaypointsPassed = player.numWaypointsPassed, data = player.data, finished = player.finished}
                    end
                end

                if true == complete then -- all player clients have updated numWaypointsPassed and data
                    table.sort(sortedPlayers, function(p0, p1)
                        return (p0.numWaypointsPassed > p1.numWaypointsPassed) or (p0.numWaypointsPassed == p1.numWaypointsPassed and p0.data < p1.data)
                    end)
                    -- players sorted into sortedPlayers table
                    for position, sortedPlayer in pairs(sortedPlayers) do
                        if false == sortedPlayer.finished then
                            TriggerClientEvent("races:position", sortedPlayer.index, position, #sortedPlayers)
                        end
                    end
                end
            end
        end
    end
end)
