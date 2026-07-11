--------------------------------------------------
-- Stopwatch
--------------------------------------------------

local ui = use("ui")
local app = use("app")
local theme = use("theme")

--------------------------------------------------

local info = app.create({

    name = "stopwatch",

    version = "1.2",

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

-- True while this app is just SHOWING a countdown/
-- stopwatch that lives in the background task, rather
-- than ticking its own local one. Set on startup when
-- a background item is already running, and again when
-- switching into the mode that matches it.
local attached = false

--------------------------------------------------
-- Maps this app's mode name to the system timer
-- lib's mode name.
--------------------------------------------------

local function systemModeFor(appMode)

    if appMode == "timer" then
        return "countdown"
    end

    return "stopwatch"

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

    local shownSeconds = state.seconds

    if attached then

        if state.mode == "timer" then
            shownSeconds = systemTimer.getRemaining()
        else
            shownSeconds = systemTimer.getElapsed()
        end

    end

    term.setTextColor((state.running or attached) and theme.get("success") or theme.get("secondary"))
    print(formatTime(shownSeconds))
    term.setTextColor(theme.get("text"))

    print()

    if attached then
        print("Running in background")
    else
        print(state.running and "Running" or "Paused")
    end

    print()

    if message then

        term.setTextColor(messageColor or theme.get("accent"))
        print(message)
        term.setTextColor(theme.get("text"))
        print()

    end

    if attached then

        print("[S] Pause here   [R] Reset   [M] Switch mode")
        print("[Q] Quit (keeps running)")

    else

        print("[S] Start/Pause   [R] Reset   [M] Switch mode")

        if state.mode == "timer" then
            print("[D] Set duration (" .. state.timerDuration .. "s)")
        end

        if systemTimer then
            print("[B] Continue in background")
        end

        print("[Q] Quit")

    end

end

--------------------------------------------------
-- Main Loop
--------------------------------------------------

local state = newState()
local message = nil
local messageColor = nil

-- If a background countdown/stopwatch is already
-- running, open in the matching mode and show it
-- live instead of starting fresh.
if systemTimer and systemTimer.isRunning() then

    local bgMode = systemTimer.getMode()

    if bgMode == "countdown" then

        state.mode = "timer"
        state.timerDuration = math.max(1, systemTimer.getDuration())
        attached = true

    elseif bgMode == "stopwatch" then

        state.mode = "stopwatch"
        attached = true

    end

end

local timerId = os.startTimer(1)

draw(state, message, messageColor)

while true do

    local event, p1 = os.pullEvent()

    if event == "timer" and p1 == timerId then

        if attached then

            -- The background task owns the ticking; this
            -- app just refreshes what it shows, and steps
            -- aside if the background item finished or was
            -- stopped from elsewhere (timer stop).
            if systemTimer.isFinished() then

                attached = false

                state.running = false
                state.seconds = 0

                message = "Time's up!"
                messageColor = theme.get("accent")

            elseif not systemTimer.isRunning() then

                attached = false

                state.running = false
                state.seconds = (state.mode == "timer") and state.timerDuration or 0

                message = "Background timer was stopped."
                messageColor = theme.get("secondary")

            end

        else

            local _, tickMessage = tick(state)

            if tickMessage then

                message = tickMessage
                messageColor = theme.get("accent")

            end

        end

        timerId = os.startTimer(1)

        draw(state, message, messageColor)

    elseif event == "key" then

        local key = p1

        if key == keys.s or key == keys.space then

            if attached then

                -- Take the countdown/stopwatch over from the
                -- background: capture its current value, stop
                -- the background task, continue locally paused.
                local value

                if state.mode == "timer" then
                    value = systemTimer.getRemaining()
                else
                    value = systemTimer.getElapsed()
                end

                systemTimer.stop()

                attached = false

                state.seconds = value
                state.running = false

                message = "Paused here - taken over from background."
                messageColor = theme.get("secondary")

            else

                toggleRun(state)

                message = nil

            end

            draw(state, message, messageColor)

        elseif key == keys.r then

            if attached then

                systemTimer.stop()

                attached = false

            end

            reset(state)

            message = nil

            draw(state, message, messageColor)

        elseif key == keys.m then

            -- Switching away from an attached mode leaves the
            -- background item running - the app just stops
            -- showing it. Switching back re-attaches below.
            attached = false

            switchMode(state)

            message = nil

            if systemTimer and systemTimer.isRunning()
                and systemTimer.getMode() == systemModeFor(state.mode) then

                attached = true

                if state.mode == "timer" then
                    state.timerDuration = math.max(1, systemTimer.getDuration())
                end

                message = "Showing the background " .. (state.mode == "timer" and "timer" or "stopwatch") .. "."
                messageColor = theme.get("secondary")

            end

            draw(state, message, messageColor)

        elseif key == keys.d and state.mode == "timer" and not attached then

            -- The "key" event for D is followed by a "char"
            -- event ("d") that would otherwise land inside
            -- the read() below and show up as typed input -
            -- discard it first.
            discardChar()

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

        elseif key == keys.b and systemTimer then

            if attached then

                message = "Already running in the background."
                messageColor = theme.get("secondary")

                draw(state, message, messageColor)

            elseif state.mode == "timer" then

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

            else

                systemTimer.startStopwatch(state.seconds)

                discardChar()
                ui.clear()

                print("Stopwatch continues in the background from " .. formatTime(state.seconds) .. ". Watch the panel; 'timer stop' stops it.")

                return

            end

        elseif key == keys.q then

            discardChar()
            ui.clear()

            return

        end

    end

end
