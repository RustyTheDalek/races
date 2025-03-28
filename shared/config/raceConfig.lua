local RaceConfig = {
    -- Blip Configuration
    BLIP = {
        REGISTER_COLOR = 83,      -- purple
        SELECTED_COLOR = 1,       -- red
        ROUTE_COLOR = 18,         -- light blue
        REGISTER_SPRITE = 58,     -- circled star
    },
    
    -- Checkpoint Configuration
    CHECKPOINT = {
        FINISH = 4,              -- cylinder checkered flag
        PLAIN = 45,              -- cylinder
        ARROW3 = 0,              -- cylinder with 3 arrows
    },
    
    -- Race Defaults
    DEFAULTS = {
        TIER = "none",           -- default race Tier
        SPECIAL_CLASS = "none",  -- default race Tier
        LAPS = 3,                -- default number of laps in a race
        TIMEOUT = 1200,          -- default DNF timeout
        DELAY = 5,               -- default race start delay
        VEHICLE = "adder",       -- default spawned vehicle
    },
    
    -- Race States
    STATES = {
        IDLE = "idle",
        JOINING = "joining",
        WAITING = "waiting",
        STARTING = "starting",
        RACING = "racing",
        FINISHED = "finished",
        DNF = "dnf",
    },
    
    -- Race Events
    EVENTS = {
        RACE_START = "race:start",
        RACE_END = "race:end",
        WAYPOINT_HIT = "race:waypointHit",
        PLAYER_DNF = "race:playerDNF",
    }
}

return RaceConfig 