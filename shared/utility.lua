function lerp(a,b,t) return a * (1-t) + b * t end

function round(f)
    return (f - math.floor(f) >= 0.5) and math.ceil(f) or math.floor(f)
end