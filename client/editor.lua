local defaultBuyin <const> = 0            -- default race buy-in
local defaultLaps <const> = 3             -- default number of laps in a race
local defaultTimeout <const> = 1200       -- default DNF timeout
local defaultDelay <const> = 5            -- default race start delay
local defaultVehicle <const> = "adder"    -- default spawned vehicle
local defaultRadius <const> = 8.0         -- default waypoint radius

local minRadius <const> = 0.5             -- minimum waypoint radius
local maxRadius <const> = 20.0            -- maximum waypoint radius

editor = {}

editor.isEditing = false

editor.highlightedCheckpoint = 0           -- index of highlighted checkpoint
editor.selectedIndex0 = 0                  -- index of first selected waypoint
editor.selectedIndex1 = 0                  -- index of second selected waypoint

local waypoints = {}                      -- waypoints[] = {coord = {x, y, z, r}, checkpoint, blip, sprite, color, number, name}
local startIsFinish = false               -- flag indicating if start and finish are same waypoint

print("Editor loaded")

return editor