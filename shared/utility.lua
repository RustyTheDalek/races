function drawMsg(x, y, msg, scale, justify)
    SetTextFont(4)
    SetTextScale(0, scale)
    SetTextColour(255, 255, 0, 255)
    SetTextOutline()
    SetTextJustification(justify)
    SetTextWrap(0.0, 1.0)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayText(x, y)
end

--chat
function sendChatLog(msg, prefix)
    TriggerEvent("chat:addMessage", {
        color = { 255, 0, 0 },
        multiline = true,
        args = { "[races:prefix]", msg }
    })
end

--Checkpoints
function getCheckpointColor(blipColor)
    if 0 == blipColor then
        return white
    elseif 1 == blipColor then
        return red
    elseif 2 == blipColor then
        return green
    elseif 38 == blipColor then
        return blue
    elseif 5 == blipColor then
        return yellow
    elseif 83 == blipColor then
        return purple
    else
        return yellow
    end
end

--fileloading
function safeLoadJson(path)
    if loadJson(path) == nil then
        print(SaveResourceFile(GetCurrentResourceName(), path, {}, -1))
    end
end

function loadJson(path)
    local string = loadFile(path)
    return json.decode(string)
end

function loadFile(path)
    return LoadResourceFile(GetCurrentResourceName(), path)
end
