colour = {
    white = { r = 255, g = 255, b = 255 },
    red = { r = 255, g = 0, b = 0 },
    green = { r = 0, g = 255, b = 0 },
    blue = { r = 0, g = 0, b = 255 },
    yellow = { r = 255, g = 255, b = 0 },
    purple = { r = 255, g = 0, b = 255 },
}

function getCheckpointColor(blipColor)
    if 0 == blipColor then
        return colour.white
    elseif 1 == blipColor then
        return colour.red
    elseif 2 == blipColor then
        return colour.green
    elseif 38 == blipColor then
        return colour.blue
    elseif 5 == blipColor then
        return colour.yellow
    elseif 83 == blipColor then
        return colour.purple
    else
        return colour.yellow
    end
end
