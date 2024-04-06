
local checkpointAlpha <const> = 127

function MakeCheckpoint(checkpointType, coord, nextCoord, color, num, alpha)
    --The -1 represents the roughly half the height of the ped
    --It's divided by the radius of the coord which is in turn divied by 2
    --Because it's actually the diameter or because 2 is actually the ped height?

    if(coord.r == nil ) then
        coord.r = Config.data.editing.defaultRadius
    end

    if(alpha == nil) then
        alpha = checkpointAlpha
    end

    local checkpoint = CreateCheckpoint(checkpointType,
        coord.x, coord.y, coord.z -1 / (coord.r / 2),
        nextCoord.x, nextCoord.y, nextCoord.z -1 / (coord.r / 2) ,
        coord.r * 2.0, color.r, color.g, color.b, 
        alpha, num)
    SetCheckpointIconHeight(checkpoint, 0.3)
    return checkpoint
end