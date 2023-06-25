RaceRegistration = {
    -- self.starts[playerID] = {isPublic, trackName, owner, buyin, laps, timeout, rtype, restrict, vclass, svehicle, vehicleList, blip, checkpoint, gridData} - registration points
    starts = {},
    startIsFinish = false
}

function RaceRegistration:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function RaceRegistration:removeRegistrationPoint(rIndex)
    RemoveBlip(self.starts[rIndex].blip) -- delete registration blip
    DeleteCheckpoint(self.starts[rIndex].checkpoint) -- delete registration checkpoint
    DeleteCheckpoint(gridCheckpoint)
    self.starts[rIndex] = nil
end

function RaceRegistration:unregister(rIndex)
    if rIndex ~= nil then
        if gridCheckpoint ~= nil then
            DeleteCheckpoint(gridCheckpoint)
        end
        if self.starts[rIndex] ~= nil then
            DeleteGridCheckPoints()
            removeRegistrationPoint(rIndex)
        end
        if rIndex == raceIndex then
            if STATE_JOINING == raceState then
                raceState = STATE_IDLE
                removeRacerBlipGT()
                notifyPlayer("Race canceled.\n")
            elseif STATE_RACING == raceState then
                raceState = STATE_IDLE
                DeleteCheckpoint(raceCheckpoint)
                restoreBlips()
                SetBlipRoute(waypoints[1].blip, true)
                SetBlipRouteColour(waypoints[1].blip, blipRouteColor)
                removeRacerBlipGT()
                RenderScriptCams(false, false, 0, true, true)
                local player = PlayerPedId()
                if IsPedInAnyVehicle(player, false) == 1 then
                    FreezeEntityPosition(GetVehiclePedIsIn(player, false), false)
                end
                if originalVehicleHash ~= nil then
                    local vehicle = switchVehicle(player, originalVehicleHash)
                    if vehicle ~= nil then
                        SetVehicleColours(vehicle, colorPri, colorSec)
                        SetEntityAsNoLongerNeeded(vehicle)
                    end
                end
                notifyPlayer("Race canceled.\n")
            end
        end
    else
        notifyPlayer("Ignoring unregister event.  Invalid parameters.\n")
    end
end

function RaceRegistration:join(rIndex, aiName, waypointCoords)
    if rIndex ~= nil and waypointCoords ~= nil then
        if self.starts[rIndex] ~= nil then
            if nil == aiName then
                if STATE_IDLE == raceState then
                    raceState = STATE_JOINING
                    raceIndex = rIndex
                    numLaps = self.starts[rIndex].laps
                    DNFTimeout = self.starts[rIndex].timeout * 1000
                    restrictedHash = nil
                    restrictedClass = self.starts[rIndex].vclass
                    customClassVehicleList = {}
                    startVehicle = self.starts[rIndex].svehicle
                    randVehicles = {}

                    self.startIsFinish =
                    waypointCoords[1].x == waypointCoords[#waypointCoords].x and
                    waypointCoords[1].y == waypointCoords[#waypointCoords].y and
                    waypointCoords[1].z == waypointCoords[#waypointCoords].z

                    loadWaypointBlips(waypointCoords)
                    local msg = "Joined race using "
                    if nil == self.starts[rIndex].trackName then
                        msg = msg .. "unsaved track "
                    else
                        msg =
                            msg .. (true == self.starts[rIndex].isPublic and "publicly" or "privately") .. " saved track '" ..
                                self.starts[rIndex].trackName .. "' "
                    end
                    msg = msg ..
                              ("registered by %s : %d buy-in : %d lap(s)"):format(self.starts[rIndex].owner,
                            self.starts[rIndex].buyin, self.starts[rIndex].laps)
                    if "rest" == self.starts[rIndex].rtype then
                        msg = msg .. " : using '" .. self.starts[rIndex].restrict .. "' vehicle"
                        restrictedHash = GetHashKey(self.starts[rIndex].restrict)
                    elseif "class" == self.starts[rIndex].rtype then
                        msg = msg .. " : using " .. getClassName(restrictedClass) .. " vehicle class"
                        customClassVehicleList = self.starts[rIndex].vehicleList
                    elseif "rand" == self.starts[rIndex].rtype then
                        msg = msg .. " : using random "
                        if restrictedClass ~= nil then
                            msg = msg .. getClassName(restrictedClass) .. " vehicle class"
                        else
                            msg = msg .. "vehicles"
                        end
                        if startVehicle ~= nil then
                            msg = msg .. " : '" .. startVehicle .. "'"
                        end
                        randVehicles = self.starts[rIndex].vehicleList
                    end
                    msg = msg .. ".\n"
                    notifyPlayer(msg)
                elseif STATE_EDITING == raceState then
                    notifyPlayer("Ignoring join event.  Currently editing.\n")
                else
                    notifyPlayer("Ignoring join event.  Already joined to a race.\n")
                end
            end
        else
            notifyPlayer("Ignoring join event.  Race does not exist.\n")
        end
    else
        notifyPlayer("Ignoring join event.  Invalid parameters.\n")
    end
end

function RaceRegistration:hide(rIndex)
    if rIndex ~= nil then
        if self.starts[rIndex] ~= nil then
            removeRegistrationPoint(rIndex)
        else
            notifyPlayer("Ignoring hide event.  Race does not exist.\n")
        end
    else
        notifyPlayer("Ignoring hide event.  Invalid parameters.\n")
    end
end

function RaceRegistration:handleRaceRegistration()
    local closestIndex = -1
    local minDist = defaultRadius
    for rIndex, start in pairs(self.starts) do
        local dist = #(playerCoord - GetBlipCoords(start.blip))
        if dist < minDist then
            minDist = dist
            closestIndex = rIndex
        end
    end
    if closestIndex ~= -1 then
        local msg = "Join race using "
        if nil == self.starts[closestIndex].trackName then
            msg = msg .. "unsaved track "
        else
            msg = msg .. (true == self.starts[closestIndex].isPublic and "publicly" or "privately") .. " saved track '" ..
                      self.starts[closestIndex].trackName .. "' "
        end
        msg = msg .. "registered by " .. self.starts[closestIndex].owner
        drawMsg(0.50, 0.50, msg, 0.7, 0)
        msg = ("%d buy-in : %d lap(s)"):format(self.starts[closestIndex].buyin, self.starts[closestIndex].laps)
        if "rest" == self.starts[closestIndex].rtype then
            msg = msg .. " : using '" .. self.starts[closestIndex].restrict .. "' vehicle"
        elseif "class" == self.starts[closestIndex].rtype then
            msg = msg .. " : using " .. getClassName(self.starts[closestIndex].vclass) .. " vehicle class"
        elseif "rand" == self.starts[closestIndex].rtype then
            msg = msg .. " : using random "
            if self.starts[closestIndex].vclass ~= nil then
                msg = msg .. getClassName(self.starts[closestIndex].vclass) .. " vehicle class"
            else
                msg = msg .. "vehicles"
            end
            if self.starts[closestIndex].svehicle ~= nil then
                msg = msg .. " : '" .. self.starts[closestIndex].svehicle .. "'"
            end
        end
        drawMsg(0.50, 0.54, msg, 0.7, 0)
        if IsControlJustReleased(0, 51) == 1 then -- E key or DPAD RIGHT
            local joinRace = true
            originalVehicleHash = nil
            colorPri = -1
            colorSec = -1
            local vehicle = nil
            if IsPedInAnyVehicle(player, false) == 1 then
                vehicle = GetVehiclePedIsIn(player, false)
            end
            if "rest" == self.starts[closestIndex].rtype then
                if vehicle ~= nil then
                    if GetEntityModel(vehicle) ~= GetHashKey(self.starts[closestIndex].restrict) then
                        joinRace = false
                        notifyPlayer("Cannot join race.  Player needs to be in restricted vehicle.")
                    end
                else
                    joinRace = false
                    notifyPlayer("Cannot join race.  Player needs to be in restricted vehicle.")
                end
            elseif "class" == self.starts[closestIndex].rtype then
                if self.starts[closestIndex].vclass ~= -1 then
                    if vehicle ~= nil then
                        if GetVehicleClass(vehicle) ~= self.starts[closestIndex].vclass then
                            joinRace = false
                            notifyPlayer("Cannot join race.  Player needs to be in vehicle of " ..
                                             getClassName(self.starts[closestIndex].vclass) .. " class.")
                        end
                    else
                        joinRace = false
                        notifyPlayer("Cannot join race.  Player needs to be in vehicle of " ..
                                         getClassName(self.starts[closestIndex].vclass) .. " class.")
                    end
                else
                    if #self.starts[closestIndex].vehicleList == 0 then
                        joinRace = false
                        notifyPlayer("Cannot join race.  No valid vehicles in vehicle list.")
                    else
                        local list = ""
                        for _, vehName in pairs(self.starts[closestIndex].vehicleList) do
                            list = list .. vehName .. ", "
                        end
                        list = string.sub(list, 1, -3)
                        if vehicle ~= nil then
                            if vehicleInList(vehicle, self.starts[closestIndex].vehicleList) == false then
                                joinRace = false
                                notifyPlayer(
                                    "Cannot join race.  Player needs to be in one of the following vehicles: " .. list)
                            end
                        else
                            joinRace = false
                            notifyPlayer("Cannot join race.  Player needs to be in one of the following vehicles: " ..
                                             list)
                        end
                    end
                end
            elseif "rand" == self.starts[closestIndex].rtype then
                if #self.starts[closestIndex].vehicleList == 0 then
                    joinRace = false
                    notifyPlayer("Cannot join race.  No valid vehicles in vehicle list.")
                else
                    if vehicle ~= nil then
                        originalVehicleHash = GetEntityModel(vehicle)
                        colorPri, colorSec = GetVehicleColours(vehicle)
                    end
                    if self.starts[closestIndex].vclass ~= nil then
                        if nil == self.starts[closestIndex].svehicle then
                            if vehicle ~= nil then
                                if GetVehicleClass(vehicle) ~= self.starts[closestIndex].vclass then
                                    joinRace = false
                                    notifyPlayer("Cannot join race.  Player needs to be in vehicle of " ..
                                                     getClassName(self.starts[closestIndex].vclass) .. " class.")
                                end
                            else
                                joinRace = false
                                notifyPlayer("Cannot join race.  Player needs to be in vehicle of " ..
                                                 getClassName(self.starts[closestIndex].vclass) .. " class.")
                            end
                        end
                    end
                end
            end
            if true == joinRace then
                removeRacerBlipGT()
                TriggerServerEvent("races:join", closestIndex, PedToNet(player), nil)
            end
        end
    end
end

local function notifyPlayer(msg)
    sendChatLog(msg, "raceregistration")
end


local function register(rIndex, coord, isPublic, trackName, owner, buyin, laps, timeout, rdata)
    
    print("RaceRegistration")
    print(rIndex)

    if rIndex == nil and coord == nil and isPublic == nil and owner == nil and buyin == nil and laps == nil and timeout == nil and rdata == nil then
        notifyPlayer("Ignoring register event.  Invalid parameters.\n")
        return
    end

    local blip = AddBlipForCoord(coord.x, coord.y, coord.z) -- registration blip
    SetBlipSprite(blip, registerSprite)
    SetBlipColour(blip, registerBlipColor)
    BeginTextCommandSetBlipName("STRING")
    local msg = owner .. " (" .. buyin .. " buy-in"
    if "rest" == rdata.rtype then
        msg = msg .. " : using '" .. rdata.restrict .. "' vehicle"
    elseif "class" == rdata.rtype then
        msg = msg .. " : using " .. getClassName(rdata.vclass) .. " vehicle class"
    elseif "rand" == rdata.rtype then
        msg = msg .. " : using random "
        if rdata.vclass ~= nil then
            msg = msg .. getClassName(rdata.vclass) .. " vehicle class"
        else
            msg = msg .. "vehicles"
        end
        if rdata.svehicle ~= nil then
            msg = msg .. " : '" .. rdata.svehicle .. "'"
        end
    end
    msg = msg .. ")"
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandSetBlipName(blip)

    coord.r = defaultRadius
    local checkpoint = makeCheckpoint(plainCheckpoint, coord, coord, purple, 127, 0) -- registration checkpoint

    self.starts[rIndex] = {
        isPublic = isPublic,
        trackName = trackName,
        owner = owner,
        buyin = buyin,
        laps = laps,
        timeout = timeout,
        allowAI = allowAI,
        rtype = rdata.rtype,
        restrict = rdata.restrict,
        vclass = rdata.vclass,
        svehicle = rdata.svehicle,
        vehicleList = rdata.vehicleList,
        blip = blip,
        checkpoint = checkpoint
    }
end


RegisterNetEvent("races:register")
AddEventHandler("races:register", register)

RegisterNetEvent("races:unregister")
AddEventHandler("races:unregister", unregister)

RegisterNetEvent("races:hide")
AddEventHandler("races:hide", hide)

RegisterNetEvent("races:join")
AddEventHandler("races:join", join)
