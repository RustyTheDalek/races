local RaceConfig = require 'shared/config/raceConfig'

local RaceStateMachine = {
    currentState = RaceConfig.STATES.IDLE,
    previousState = nil,
    stateHandlers = {},
}

-- Initialize state handlers
function RaceStateMachine:init()
    self.stateHandlers = {
        [RaceConfig.STATES.IDLE] = {
            enter = function() 
                -- Handle entering idle state
                print("Entering idle state")
            end,
            exit = function()
                -- Handle exiting idle state
                print("Exiting idle state")
            end
        },
        [RaceConfig.STATES.JOINING] = {
            enter = function()
                -- Handle entering joining state
                print("Entering joining state")
            end,
            exit = function()
                -- Handle exiting joining state
                print("Exiting joining state")
            end
        },
        [RaceConfig.STATES.WAITING] = {
            enter = function()
                -- Handle entering waiting state
                print("Entering waiting state")
            end,
            exit = function()
                -- Handle exiting waiting state
                print("Exiting waiting state")
            end
        },
        [RaceConfig.STATES.STARTING] = {
            enter = function()
                -- Handle entering starting state
                print("Entering starting state")
            end,
            exit = function()
                -- Handle exiting starting state
                print("Exiting starting state")
            end
        },
        [RaceConfig.STATES.RACING] = {
            enter = function()
                -- Handle entering racing state
                print("Entering racing state")
            end,
            exit = function()
                -- Handle exiting racing state
                print("Exiting racing state")
            end
        },
        [RaceConfig.STATES.FINISHED] = {
            enter = function()
                -- Handle entering finished state
                print("Entering finished state")
            end,
            exit = function()
                -- Handle exiting finished state
                print("Exiting finished state")
            end
        },
        [RaceConfig.STATES.DNF] = {
            enter = function()
                -- Handle entering DNF state
                print("Entering DNF state")
            end,
            exit = function()
                -- Handle exiting DNF state
                print("Exiting DNF state")
            end
        }
    }
end

-- Change state with proper enter/exit handlers
function RaceStateMachine:changeState(newState)
    if not self.stateHandlers[newState] then
        print("Invalid state: " .. tostring(newState))
        return false
    end

    -- Call exit handler for current state
    if self.stateHandlers[self.currentState] and self.stateHandlers[self.currentState].exit then
        self.stateHandlers[self.currentState].exit()
    end

    -- Update state
    self.previousState = self.currentState
    self.currentState = newState

    -- Call enter handler for new state
    if self.stateHandlers[newState] and self.stateHandlers[newState].enter then
        self.stateHandlers[newState].enter()
    end

    return true
end

-- Get current state
function RaceStateMachine:getCurrentState()
    return self.currentState
end

-- Get previous state
function RaceStateMachine:getPreviousState()
    return self.previousState
end

-- Initialize the state machine
RaceStateMachine:init()

return RaceStateMachine 