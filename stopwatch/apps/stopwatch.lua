--------------------------------------------------
-- Stopwatch
--------------------------------------------------

local ui = use("ui")
local app = use("app")
local theme = use("theme")

--------------------------------------------------

local info = app.create({

    name = "stopwatch",

    version = "1.1",

    author = "-ASTR-",

    description = "A stopwatch and countdown timer in one app."

})

if INFO_ONLY then return info end

--------------------------------------------------
-- Optional system timer integration
--
-- OKOS 0.14.1+ ships lib/timer.lua, a background
-- countdown that keeps running after this app exits.
-- pcall-guarded so this package still works on older
-- OKOS versions - the [B] option simply doesn't
-- appear there.
--------------------------------------------------

local hasSystemTimer, systemTimer = pcall(use, "timer")

if not hasSystemTimer then
    systemTimer = nil
end

--------------------------------------------------
-- State
--
-- Kept as plain functions operating on a state
-- table, separate from drawing/input, so the whole
-- state machine can be exercised without a real
-- terminal.
--------------------------------------------------

local function newState()

    return {

        mode = "stopwatch",
        seconds = 0,
        timerDuration = 60,
        running = false

    }

end

--------------------------------------------------
-- Format Time
--------------------------------------------------

local function formatTime(totalSeconds)

    totalSeconds = math.max(0, math.floor(totalSeconds))

    local m = math.floor(totalSeconds / 60)
    local s = totalSeconds % 60

    return string.format("%02d:%02d", m, s)

end

--------------------------------------------------
-- Tick
--
-- Called once per elapsed second while running.
-- Returns state, message - message is non-nil only
-- when a countdown timer just reached zero.
--------------------------------------------------

local function tick(state)

    if not state.running then
        return state, nil
    end

    if state.mode == "stopwatch" then

        state.seconds = state.seconds + 1

        return state, nil

    end

    state.seconds = state.seconds - 1

    if state.seconds <= 0 then

        state.seconds = 0
        state.running = false

        return state, "Time's up!"

    end

    return state, nil

end

--------------------------------------------------
-- Toggle Run
--------------------------------------------------

local function toggleRun(state)

    state.running = not state.running

    return state

end

--------------------------------------------------
-- Reset
--
-- Stopwatch resets to 0. Timer resets to its
-- configured duration.
--------------------------------------------------

local function reset(state)

    state.running = false
    state.seconds = (state.mode == "timer") and state.timerDuration or 0

    return state

end

--------------------------------------------------
-- Switch Mode
--------------------------------------------------

local function switchMode(state)

    state.mode = (state.mode == "stopwatch") and "timer" or "stopwatch"
    state.running = false
    state.seconds = (state.mode == "timer") and state.timerDuration or 0

    return state

end

--------------------------------------------------
-- Set Duration
--
-- Only meaningful in timer mode. Returns state, ok.
--------------------------------------------------

local function setDuration(state, newDuration)

    if newDuration == nil or newDuration < 1 then
        return state, false
    end

    state.timerDuration = math.floor(newDuration)

    if state.mode == "timer" then

        state.running = false
        state.seconds = state.timerDuration

    end

    return state, true

end

--------------------------------------------------
-- Discards the trailing "char" event that follows
-- a printable key press, same approach as ui.lua.
--------------------------------------------------

local function discardChar()

    parallel.waitForAny(

        function() os.pullEvent("char") end,

        function() sleep(0.05) end

    )

end

--------------------------------------------------
-- Draw
--------------------------------------------------

local function draw(state, message, messageColor)

    ui.clear()

    print("Stopwatch / Timer")
    print()

    print("Mode: " .. (state.mode == "stopwatch" and "Stopwatch" or "Timer"))
    print()

    term.setTextColor(state.running and theme.get("success") or theme.get("secondary"))
    print(formatTime(state.seconds))
    term.setTextColor(theme.get("text"))

    print()
    print(state.running and "Running" or "Paused")
    print()

    if message then

        term.setTextColor(messageColor or theme.get("accent"))
        print(message)
        term.setTextColor(theme.get("text"))
        print()

    end

    print("[S] Start/Pause   [R] Reset   [M] Switch mode")

    if state.mode == "timer" then

        print("[D] Set duration (" .. state.timerDuration .. "s)")

        if systemTimer then
            print("[B] Continue in background")
        end

    end

    print("[Q] Quit")

end

--------------------------------------------------
-- Main Loop
--------------------------------------------------

local state = newState()
local message = nil
local messageColor = nil

local timerId = os.startTimer(1)

draw(state, message, messageColor)

while true do

    local event, p1 = os.pullEvent()

    if event == "timer" and p1 == timerId then

        local _, tickMessage = tick(state)

        if tickMessage then

            message = tickMessage
            messageColor = theme.get("accent")

        end

        timerId = os.startTimer(1)

        draw(state, message, messageColor)

    elseif event == "key" then

        local key = p1

        if key == keys.s or key == keys.space then

            toggleRun(state)

            message = nil

            draw(state, message, messageColor)

        elseif key == keys.r then

            reset(state)

            message = nil

            draw(state, message, messageColor)

        elseif key == keys.m then

            switchMode(state)

            message = nil

            draw(state, message, messageColor)

        elseif key == keys.d and state.mode == "timer" then

            local width, height = term.getSize()

            term.setCursorPos(1, height)
            term.setTextColor(theme.get("accent"))
            write("Seconds: ")
            term.setTextColor(theme.get("text"))

            local input = read()

            local newDuration = tonumber(input)

            local _, ok = setDuration(state, newDuration)

            if ok then

                message = "Duration set to " .. state.timerDuration .. "s."
                messageColor = theme.get("success")

            else

                message = "Enter a whole number of seconds."
                messageColor = theme.get("error")

            end

            -- read() may have silently swallowed the pending
            -- timer tick while the user was typing - start a
            -- fresh one rather than trust a possibly-stale id.
            timerId = os.startTimer(1)

            draw(state, message, messageColor)

        elseif key == keys.b and state.mode == "timer" and systemTimer then

            if state.seconds < 1 then

                message = "Nothing to continue - timer is at zero."
                messageColor = theme.get("error")

                draw(state, message, messageColor)

            else

                systemTimer.start(state.seconds)

                discardChar()
                ui.clear()

                print("Timer continues in the background: " .. formatTime(state.seconds) .. " left. Watch the panel; 'timer stop' cancels.")

                return

            end

        elseif key == keys.q then

            discardChar()
            ui.clear()

            return

        end

    end

end
