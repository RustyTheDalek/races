local gridSeparation <const> = 5

local READY_RACERS_COUNTDOWN = 5000

RaceEvent = {
    index = -1,
    raceStart = 0,
    raceTime = 0,
    state = racingStates.Registering,
    waypoints = {},
    isPublic = false,
    trackName = '',
    owner = '',
    tier = '',
    specialClass = '',
    laps = 0,
    timeout = 0,
    rtype = '',
    restrict = '',
    vclass = '',
    svehicle = '',
    vehicleList = {},
    numRacing = 0,
    numReady = 0,
    countdown = false,
    countdownTimeStart = 0,
    players = {},
    results = {},
    previousRaceResults = {},
    gridLineup = {},
    gridPositions = {},
    useRaceResults = false,
    map = '',
    checkpointTimes = {}
}

function RaceEvent:New(o)
    o = o or {}
    print(dump(o))
    setmetatable(o, self)
    self.__index = self
    return o
end

function RaceEvent:TriggerEventForRacers(event, ...)
    for racerSource, _ in pairs(self.players) do
        TriggerClientEvent(event, racerSource, ...)
    end
end

function RaceEvent:Setup(source)
    if self.state == racingStates.Registering then
        local rdata = {
            rtype = self.rtype,
            restrict = self.restrict,
            vclass = self.vclass,
            svehicle = self.svehicle,
            vehicleList = self.vehicleList,
            specialClass = self.specialClass,
            tier = self.tier,
            laps = self.laps,
            timeout = self.timeout
        }

        TriggerClientEvent("races:register", source, self.index, self.waypoints[1], self.isPublic, self.trackName, self.owner, rdata)
    end
end

function RaceEvent:Unregister()
    for k in next, self.gridLineup do rawset(self.gridLineup, k, nil) end
    TriggerClientEvent("races:cleargridpositions", self.index)
    TriggerClientEvent("races:unregister", -1, self.index)
    toast(self.index, "Race unregistered.\n")
end

function RaceEvent:Update()
    if self.state == racingStates.Registering then
        self:CheckReady()
    elseif(self.state == racingStates.RaceCountdown) then
        self.delayTimer:Update()

        if (self.delayTimer.length <= 5000 and self.fiveSecondWarning == false) then
            self.fiveSecondWarning = true
            print("Five second warning")

            self:TriggerEventForRacers("races:fivesecondwarning")
        end

        if (self.delayTimer.complete) then

            self.startTime = GetGameTimer()
            print(("Race starts at %i"):format(self.startTime))

            for _, player in pairs(self.players) do
                player.currentLapTimeStart = self.startTime
                TriggerClientEvent("races:greenflag", player.source, self.startTime)
            end
            self.state = racingStates.Racing
        end
    elseif(self.state == racingStates.Racing) then
        self.raceTime = GetGameTimer() - self.startTime
    end
end

function RaceEvent:GenerateStartingGrid(startWaypoint, numRacers)

    local startPoint = vector3(startWaypoint.coord.x, startWaypoint.coord.y, startWaypoint.coord.z)

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

    self.gridPositions = {}

    for i = 1, numRacers do
        local gridPosition = startPoint - forwardVector * (i + 1) * gridSeparation

        if math.fmod(i, 2) == 0 then
            -- print("Right Grid")
            gridPosition = gridPosition + -leftVector * 3
        else
            -- print("Left Grid")
            gridPosition = gridPosition + leftVector * 3
        end

        table.insert(self.gridPositions, gridPosition)
    end
end

function RaceEvent:SetupGrid()
    self:GenerateStartingGrid(self.waypoints[1], self.numRacing)

    if (self.gridPositions ~= nil) then
        self:TriggerEventForRacers("races:spawncheckpoints", self.gridPositions)
        self:PlaceRacersOnGrid()
    end
end

function RaceEvent:PlaceRacersOnGrid()

    local heading = self.waypoints[1].heading

    for index, player in pairs(self.gridLineup) do
        local gridPosition = self.gridPositions[index]
        print(dump(gridPosition))
        TriggerClientEvent("races:moveToGrid", player.source, index, gridPosition, heading)
        TriggerClientEvent("races:freezeplayer", player)
    end
end

function RaceEvent:UpdateGridPositions(gridPositions)
    print(dump(gridPositions))
    
    if(self.gridPositions == nil or #self.gridPositions < self.numRacing) then
        self:GenerateStartingGrid(self.waypoints[1], self.numRacing)

        if (self.gridPositions ~= nil) then
            self:TriggerEventForRacers("races:refreshcheckpoints", self.gridPositions)
        end
    end 

    self.gridLineup = gridPositions

    local gridHeading = self.waypoints[1].heading

    for gridIndex, gridPosition in ipairs(self.gridLineup) do
        if(self.players[gridPosition.source] == nil) then
            print(("%i is not in this race"):format(gridPosition.source))
        else
            TriggerClientEvent("races:moveToGrid", gridPosition.source, gridIndex, self.gridPositions[gridIndex], gridHeading)
        end
    end
end

function RaceEvent:SendRaceResults()
    self.useRaceResults = true
    for k in next, self.gridLineup do rawset(self.gridLineup, k, nil) end

    local raceResults = {}
    for index, racerResult in ipairs(self.results) do
        table.insert(raceResults, {
            source = racerResult.source,
            name = racerResult.playerName,
            position = index
        })
    end

    TriggerClientEvent("races:sendraceresults", self.index, raceResults)
end

function RaceEvent:ReadyStateChange(source, ready)
    local numReady = self.numReady
    local numRacing = self.numRacing

    if ready then
        numReady = numReady + 1
    else
        numReady = numReady - 1
    end

    if numReady < 0 then
        numReady = 0
    end

    if numReady > numRacing then
        numReady = numRacing
    end

    self.players[source].ready = ready
    self.numReady = numReady
    self.numRacing = numRacing

    self:TriggerEventForRacers("races:sendReadyData", ready, source, GetPlayerName(source))
end

function RaceEvent:CheckReady()
    if(self.numRacing == 0 ) then
        return
    end

    if self.numReady == self.numRacing and self.countdown == false then
        self:StartRaceCountdown()
    end

    if self.countdown == true and self.numReady ~= self.numRacing then
        self:StopRaceCountdown()
    end

    if self.countdown == true and GetGameTimer() - self.countdownTimeStart > READY_RACERS_COUNTDOWN then
        self:StartRace(Config.data.races.defaultStartDelay)
    end
end

function RaceEvent:StartRaceCountdown()
    for source,_ in pairs(self.players) do
        TriggerClientEvent("races:startPreRaceCountdown", source, READY_RACERS_COUNTDOWN)
    end
    self.countdown = true
    self.countdownTimeStart = GetGameTimer()
end

function RaceEvent:StopRaceCountdown()
    for source,_ in pairs(self.players) do
        TriggerClientEvent("races:stopPreRaceCountdown", source, READY_RACERS_COUNTDOWN)
    end
    self.countdown = false
    self.countdownTimeStart = 0
end

function RaceEvent:Start(delay, override)
    if self.state ~= racingStates.Registering then
        warn(self.index, "Cannot start.  Race in progress.\n")
        return
    end

    if delay <= 5 then
        warn(self.index, "Cannot start.  Invalid delay.\n")
        return
    end

    if self.numRacing <= 0 then
        warn(self.index, "Cannot start.  No players have joined race.\n")
        return
    end

    if (self.numReady ~= self.numRacing and override == false) then
        warn(self.index, "Cannot start. Not all Players ready.\n")
        return
    end

    if self.countdown == true then
        self:StopRaceCountdown()
    end

    self:StartRaceDelay(delay)

    self:TriggerEventForRacers("races:start", self.index, delay)

    TriggerClientEvent("races:hide", -1, self.index) -- hide race so no one else can join
    toast(self.index, "Race starting.\n")
end

function RaceEvent:StartRaceDelay(delay)
    self.state = racingStates.RaceCountdown
    self.fiveSecondWarning = false
    self.delayTimer = Timer:New()
    self.delayTimer:Start(delay * 1000)
end

--source is the source of racerOwner which is also the race's index
function RaceEvent:StartRace(delay)
    self.countdown = false
    self.countdownTimeStart = 0
    self.state = racingStates.RaceCountdown
    self.fiveSecondWarning = false
    self.delayTimer = Timer:New()
    self.delayTimer:Start(delay * 1000)

    self:TriggerEventForRacers("races:start", self.index, delay)
    TriggerClientEvent("races:hide", -1, self.index) -- hide race so no one else can join
    toast(self.index, "Race started.\n")
end

function RaceEvent:OnPlayerDropped(source)

    if (self.players[source] == nil) then
        return
    end

    local player = self.players[source]
    -- Remove player from gridLineup
    for j = 1, #self.gridLineup do
        if self.gridLineup[j] == source then
            table.remove(self.gridLineup, j)
            break
        end
    end

    if self.state == racingStates.Registering then
        print("removing racer from race")
        self:OnPlayerLeave(source)
        -- TODO:Find the ready state of player and remove appropriately, probably need an array with the net ids as indexs for ready
    else
        self:TriggerEventForRacers("races:removeFromLeaderboard", source)

        local finishData = {
            raceIndex = source,
            playerName = nil,
            data = 0,
            bestLapTime = -1,
            bestLapVehicleName = "",
            dnf = true,
            averageFPS = 0
        }

        TriggerEvent("races:finish", self.index, finishData, source)
    end
end

function RaceEvent:Finish(source, raceFinishData)

    if self.state ~= racingStates.Racing then
        warn(source, "Cannot finish.  Race not in progress.\n")
        return false
    end

    if self.players[source] == nil then
        warn(source, "Cannot finish.  Not a member of this race.\n")
        return false
    end

    local finishedRacer = self.players[source]

    if (raceFinishData.dnf) then
        finishedRacer.data = -1
    else
        finishedRacer.data = GetGameTimer() - self.startTime
    end

    finishedRacer.finishTime = GetGameTimer() - self.startTime

    print(("Finish Time: %i"):format(finishedRacer.data))

    local finishData = {
        raceIndex = self.index,
        playerName = finishedRacer.playerName,
        source = finishedRacer.source,
        finishTime = finishedRacer.data,
        bestLapTime = finishedRacer.bestLapTime,
        bestLapVehicleName = finishedRacer.bestLapVehicleName,
        averageFPS = raceFinishData.raceAverageFPS
    }

    self:TriggerEventForRacers("races:finish", finishData)

    self.results[#self.results + 1] = {
        source = source,
        playerName = finishedRacer.playerName,
        finishTime = finishedRacer.data,
        bestLapTime = finishedRacer.bestLapTime,
        vehicleName = finishedRacer.bestLapVehicleName,
        averageFPS = raceFinishData.raceAverageFPS
    }

    self.numRacing = self.numRacing - 1
    if 0 == self.numRacing then

        table.sort(self.results, function(p0, p1)
            return
                (p0.finishTime >= 0 and (-1 == p1.finishTime or p0.finishTime < p1.finishTime)) or
                (-1 == p0.finishTime and -1 == p1.finishTime and (p0.bestLapTime >= 0 and (-1 == p1.bestLapTime or p0.bestLapTime < p1.bestLapTime)))
        end)

        self:TriggerEventForRacers("races:onendrace", self.index, self.results)

        self:SaveResults()

        self:SendRaceResults()
        return true
    end

    return false
end

function RaceEvent:SaveResults()
    -- races[playerID] = {state, waypoints[] = {x, y, z, r}, isPublic, trackName, owner, tier, laps, timeout, rtype, restrict, vclass, svehicle, vehicleList, numRacing, players[netID] = {source, playerName,  data, coord}, results[] = {source, playerName, finishTime, bestLapTime, vehicleName}}
    local msg = "Race using "
    if nil == self.trackName then
        msg = msg .. "unsaved track "
    else
        msg = msg .. (true == self.isPublic and "publicly" or "privately") .. " saved track '" .. self.trackName .. "' "
    end
    msg = msg ..
        ("registered by %s : tier %s : SpecialClass %s : %d lap(s)"):format(self.owner, self.tier, self.specialClass,
            self.laps)
    if "rest" == self.rtype then
        msg = msg .. " : using '" .. self.restrict .. "' vehicle"
    elseif "class" == self.rtype then
        msg = msg .. " : using " .. getClassName(self.vclass) .. " vehicle class"
    elseif "rand" == self.rtype then
        msg = msg .. " : using random "
        if self.vclass ~= nil then
            msg = msg .. getClassName(self.vclass) .. " vehicle class"
        else
            msg = msg .. "vehicles"
        end
        if self.svehicle ~= nil then
            msg = msg .. " : '" .. self.svehicle .. "'"
        end
    elseif "wanted" == self.rtype then
        msg = msg .. " : using wanted race mode"
    end
    msg = msg .. "\n"

    local race_results_data = ("%s,%i\n"):format(self.trackName, self.laps)

    if #self.results > 0 then
        -- results[] = {source, playerName, finishTime, bestLapTime, vehicleName}
        msg = msg .. "Results:\n"
        for pos, result in ipairs(self.results) do
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

            local race_results_line = ("%d,%s,%02d:%05.3f,%.2f\n"):format(pos, result.playerName, best_minutes, best_seconds, result.averageFPS)
            race_results_data = race_results_data .. race_results_line
        end
    else
        msg = msg .. "No results.\n"
    end

    self:SaveResultsCSV(race_results_data)
end

function RaceEvent:SaveResultsCSV(raceResultData)
    local date = os.date("%d_%m", os.time())
    local resultsFileName = ('/results/%s_%s_results.csv'):format(self.trackName, date)
    local saveCSVResults = FileManager.SaveCurrentResourceFile(resultsFileName, raceResultData)

    if (saveCSVResults == nil) then
        print("Error saving file '" .. resultsFileName)
    end
end

function RaceEvent:JoinRacer(source)
    if self.state ~= racingStates.Registering then
        warn(source, "Cannot join.  Race in progress.\n")
        return
    end

    local playerName = GetPlayerName(source)
    self.numRacing = self.numRacing + 1

    self:TriggerEventForRacers("races:racerJoined", source, playerName)

    self.players[source] = {
        source = source,
        playerName = playerName,
        section = -1,
        waypoint = -1,
        data = -1,
        ready = false,
        bestLapTime = -1,
        bestLapVehicleName = "",
        currentLapTimeStart = -1,
        finishTime = -1
    }

    local racerDictionary = mapToArray(self.players,
        function(racer)
            return {
                source = racer.source,
                playerName = racer.playerName,
                ready = racer.ready,
            }
        end)

    local gridRacer = self:AddRacerToGrid(source, playerName)

    local joinNotificationData = {
        playerName = playerName,
        racerDictionary = racerDictionary,
        raceIndex = self.index,
        trackName = self.trackName,
        numRacing = self.numRacing,
        waypoints = self.waypoints[1]
    }

    TriggerClientEvent("races:joinnotification", -1, joinNotificationData)

    TriggerClientEvent("races:join", source, self.index, self.tier, self.specialClass,
    self.waypoints, racerDictionary)

    print(("Sending event to owner with source %i"):format(self.index))
    if(self.useRaceResults) then
        for _, gridPosition in pairs(self.gridPositions) do
            if(gridPosition.source == source) then
                print("Skipping Racer they're already in grid position")
                return
            end
        end
    end
    TriggerClientEvent("races:addracertogridlineup", self.index, gridRacer)
end

function RaceEvent:AddRacerToGrid(source, playerName)

    for i, racer in pairs(self.previousRaceResults) do
        if(source == racer.source) then
            table.insert(self.gridLineup, racer)
            return racer
        end
    end

    local newRacer = {
        source = source,
        name = playerName
    }

    table.insert(self.gridLineup, newRacer)
    return newRacer

end

function RaceEvent:OnPlayerLeave(source)

    print("On Player Leave called")
    self.numRacing = self.numRacing - 1

    if (self.players[source].ready) then
        self.numReady = self.numReady - 1
    end

    TriggerClientEvent("races:leavenotification", -1,
        string.format("%s has left Race %s", self.players[source].playerName, self.trackName), self.index,
        self.numRacing, self.waypoints[1])

    TriggerClientEvent("races:onleave", source)

    TriggerClientEvent("races:removeracerfromgridlineup", self.index, source)

    self.players[source] = nil

    self:TriggerEventForRacers("races:onplayerleave", source)
end

function RaceEvent:GetBestLaps(bestLaps)

    for _, result in pairs(self.results) do
        if result.bestLapTime ~= -1 then
            bestLaps[#bestLaps + 1] = {
                playerName = result.playerName,
                bestLapTime = result.bestLapTime,
                vehicleName = result.vehicleName
            }
        end
    end
    table.sort(bestLaps, function(p0, p1)
        return p0.bestLapTime < p1.bestLapTime
    end)
    for i = 11, #bestLaps do
        bestLaps[i] = nil
    end

    return bestLaps

end

function RaceEvent:OnLapCompleted(source, currentVehicleName)
    
    local racer = self.players[source]

    local gameTime = GetGameTimer()

    print(("Time at Lap completion: %i"):format(gameTime))

    --Get Current lap time
    local currentLapTime = gameTime - racer.currentLapTimeStart
    --Set offset for new lap
    racer.currentLapTimeStart = gameTime

    print(("Current Lap Time: %i"):format(currentLapTime))

    TriggerClientEvent("races:newlap", source, gameTime)

    if (racer.bestLapTime == -1 or currentLapTime < racer.bestLapTime ) then
        print(("Best lap for source %i in Race[%s] with time %i and Vehicle %s"):format(source, self.index, currentLapTime, currentVehicleName))
        racer.bestLapTime = currentLapTime
        racer.bestLapVehicleName = currentVehicleName

        self.players[source] = racer

        self:TriggerEventForRacers("races:updatebestlaptime", source, racer.bestLapTime)
    end
end

function RaceEvent:SendCheckpointTime(source, lap, currentSection, currentWaypoint)

    local currentLapTimes = self.checkpointTimes[lap]
    if (currentLapTimes == nil) then
        self:AddNewLapTime(lap, currentSection, currentWaypoint, source)
        return
    end

    local currentSectionTimes = currentLapTimes[currentSection]
    if(currentSectionTimes == nil) then
        self:AddNewSectionTime(currentLapTimes, currentSection, currentWaypoint, source)
        return
    end

    local currentWaypointTimes = currentSectionTimes[currentWaypoint]
    if(currentWaypointTimes == nil) then
        self:AddNewWaypointTime(currentSectionTimes, currentWaypoint, source)
        return
    end

    for otherRacerSource, otherRacerTime in pairs(currentWaypointTimes) do
        if (otherRacerSource ~= source) then
            self:CompareWaypointTimes(otherRacerSource, otherRacerTime, source)
        end
    end

    self:AddNewSourceTime(currentWaypointTimes, source)

    print(("Adding Time for Source %i"):format(source))
end

function RaceEvent:AddNewLapTime(lapNumber, section, waypoint, source)
    print(("Adding Lap %i"):format(lapNumber))
    self.checkpointTimes[lapNumber] = {}
    self:AddNewSectionTime(self.checkpointTimes[lapNumber], section, waypoint, source)
end

function RaceEvent:AddNewSectionTime(lapTimes, sectionNumber, waypoint, source)
    print(("Adding Section %i"):format(sectionNumber))
    lapTimes[sectionNumber] = {}
    self:AddNewWaypointTime(lapTimes[sectionNumber], waypoint, source)
end

function RaceEvent:AddNewWaypointTime(section, waypoint, source)
    print(("Adding Waypoint %i"):format(waypoint))
    section[waypoint] = {}
    self:AddNewSourceTime(section[waypoint], source)
end

function RaceEvent:AddNewSourceTime(waypoint, source)
    print(("Adding Source %i"):format(source))
    waypoint[source] = self.raceTime
    print(dump(self.checkpointTimes))
end

function RaceEvent:CompareWaypointTimes(otherRacerSource, otherRacerTime, source)
    print(("Comparing to Racer with source %i"):format(otherRacerSource))
    print(("And time %i"):format(otherRacerTime))

    local currentRacerTimeSplit = otherRacerTime - self.raceTime
    local otherRacerTimeSplit = self.raceTime - otherRacerTime

    TriggerClientEvent("races:updateTimeSplit", otherRacerSource, source, otherRacerTimeSplit)
    TriggerClientEvent("races:updateTimeSplit", source, otherRacerSource, currentRacerTimeSplit)
end

function RaceEvent:Report(source, currentLap, currentWaypoint, distanceToEnd, distance)
    if self.players[source] == nil then
        warn(source, "Cannot report.  Not a member of this race.\n")
    end

    self.players[source].lap = currentLap
    self.players[source].waypoint = currentWaypoint
    self.players[source].distanceToEnd = distanceToEnd
    self.players[source].data = distance
end

function RaceEvent:PollPositionsUpdate()
    local sortedPlayers = {} -- will contain players still racing and players that finished without DNF
    local complete = true

    -- race.players[source] = {source, playerName, section, waypoint, data, coord}
    for _, player in pairs(self.players) do
        if player.waypoint <= 0 then -- player client hasn't updated progress, data and coord
            complete = false
            break
        end

    -- player.data will be travel distance to next waypoint or finish time; finish time will be -1 if player DNF
    -- if player.data == -1 then player did not finish race - do not include in sortedPlayers
        if player.data ~= -1 then
            sortedPlayers[#sortedPlayers + 1] = {
                source = player.source,
                distanceToEnd = player.distanceToEnd,
                waypoint = player.waypoint,
                lap = player.lap,
                data = player.data,
                playerName = GetPlayerName(player.source),
                finishTime = player.finishTime
            }
        end
    end

    --TODO:Better way to determine progress with multiple sections
    if true == complete then -- all player clients have updated progress and data
        table.sort(sortedPlayers, function(racer1, racer2)
            if racer1.finishTime ~= -1 and racer2.finishTime ~= -1 then
                return racer1.finishTime < racer2.finishTime
            elseif racer1.finishTime ~= -1 and racer2.finishTime == -1 then
                return true
            elseif racer1.finishTime == -1 and racer2.finishTime ~= -1 then
                return false
            elseif racer1.lap ~= racer2.lap then
                return racer1.lap > racer2.lap
            elseif racer1.distanceToEnd ~= racer2.distanceToEnd then
                return racer1.distanceToEnd < racer2.distanceToEnd
            else
                return racer1.data < racer2.data
            end
        end)

        local racePositions = map(sortedPlayers,
            function(item)
                return {
                    source = item.source ,
                    playerName = item.playerName
                }
        end)

        -- players sorted into sortedPlayers table
        for position, sortedPlayer in pairs(sortedPlayers) do
            TriggerClientEvent("races:position", sortedPlayer.source, self.index, position, #sortedPlayers)
        end

        self:TriggerEventForRacers("races:racerPositions", racePositions)

    end
end
