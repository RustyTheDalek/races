color = {
    white = { r = 255, g = 255, b = 255 },
    red = { r = 255, g = 0, b = 0 },
    green = { r = 0, g = 255, b = 0 },
    blue = { r = 0, g = 0, b = 255 },
    yellow = { r = 255, g = 255, b = 0 },
    orange = { r= 255, g = 128, b = 0},
    purple = { r = 255, g = 0, b = 255 },
}

function getCheckpointColor(blipColor)
    if 0 == blipColor then
        return color.white
    elseif 1 == blipColor then
        return color.red
    elseif 2 == blipColor then
        return color.green
    elseif 38 == blipColor then
        return color.blue
    elseif 5 == blipColor then
        return color.yellow
    elseif 83 == blipColor then
        return color.purple
    else
        return color.yellow
    end
end
