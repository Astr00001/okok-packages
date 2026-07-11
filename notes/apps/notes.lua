--------------------------------------------------
-- Notes
--------------------------------------------------

local ui = use("ui")
local app = use("app")
local theme = use("theme")
local kernel = use("kernel")

--------------------------------------------------

local info = app.create({

    name = "notes",

    version = "1.0",

    author = "-ASTR-",

    description = "A shared, persistent to-do/notes list."

})

if INFO_ONLY then return info end

--------------------------------------------------
-- Storage
--
-- Plain text, one note per line: "<0|1>|<text>".
-- Deliberately reads/writes the file directly (not
-- lib/config.lua), since notes are an ordered list
-- rather than a set of named key=value settings.
--------------------------------------------------

local NOTES_PATH = kernel.path.data .. "/notes.txt"

local function loadNotes()

    local notes = {}

    if not fs.exists(NOTES_PATH) then
        return notes
    end

    local handle = fs.open(NOTES_PATH, "r")

    if not handle then
        return notes
    end

    while true do

        local line = handle.readLine()

        if line == nil then
            break
        end

        local doneFlag, text = line:match("^(%d)|(.*)$")

        if doneFlag then

            table.insert(notes, { done = (doneFlag == "1"), text = text })

        end

    end

    handle.close()

    return notes

end

local function saveNotes(notes)

    if not fs.exists(kernel.path.data) then
        fs.makeDir(kernel.path.data)
    end

    local handle = fs.open(NOTES_PATH, "w")

    if not handle then
        return false
    end

    for _, note in ipairs(notes) do
        handle.writeLine((note.done and "1" or "0") .. "|" .. note.text)
    end

    handle.close()

    return true

end

--------------------------------------------------
-- Help Text
--------------------------------------------------

local HELP_LINES = {

    "add <text>       Add a new note",
    "done <n>         Mark note n as done",
    "undone <n>       Mark note n as not done",
    "delete <n>       Remove note n",
    "clear done       Remove all completed notes",
    "clear all        Remove every note",
    "help             Show this help",
    "quit             Exit"

}

--------------------------------------------------
-- Main Loop
--------------------------------------------------

local notes = loadNotes()

local lastMessage = nil
local lastMessageColor = nil

while true do

    ui.clear()

    print("Notes")
    print()

    if #notes == 0 then

        term.setTextColor(theme.get("secondary"))
        print("(no notes yet - try 'add <text>')")
        term.setTextColor(theme.get("text"))

    else

        for i, note in ipairs(notes) do

            if note.done then

                term.setTextColor(theme.get("secondary"))
                print(i .. ". [x] " .. note.text)
                term.setTextColor(theme.get("text"))

            else

                print(i .. ". [ ] " .. note.text)

            end

        end

    end

    print()

    if lastMessage then

        term.setTextColor(lastMessageColor or theme.get("text"))
        print(lastMessage)
        term.setTextColor(theme.get("text"))
        print()

    end

    print("'help' for commands, 'quit' to exit.")
    print()

    write("> ")

    local input = read()

    local words = {}

    for word in input:gmatch("%S+") do
        table.insert(words, word)
    end

    local action = words[1]

    if action == nil then

        -- empty input, just redraw

    elseif action == "add" then

        local text = input:match("^add%s+(.*)$")

        if text and text ~= "" then

            table.insert(notes, { done = false, text = text })
            saveNotes(notes)

            lastMessage = "Added."
            lastMessageColor = theme.get("success")

        else

            lastMessage = "Usage: add <text>"
            lastMessageColor = theme.get("error")

        end

    elseif action == "done" or action == "undone" then

        local number = tonumber(words[2])

        if number == nil or number < 1 or number > #notes then

            lastMessage = "Usage: " .. action .. " <n>"
            lastMessageColor = theme.get("error")

        else

            notes[number].done = (action == "done")
            saveNotes(notes)

            lastMessage = "Updated note " .. number .. "."
            lastMessageColor = theme.get("success")

        end

    elseif action == "delete" then

        local number = tonumber(words[2])

        if number == nil or number < 1 or number > #notes then

            lastMessage = "Usage: delete <n>"
            lastMessageColor = theme.get("error")

        else

            table.remove(notes, number)
            saveNotes(notes)

            lastMessage = "Deleted note " .. number .. "."
            lastMessageColor = theme.get("success")

        end

    elseif action == "clear" and words[2] == "done" then

        local remaining = {}

        for _, note in ipairs(notes) do

            if not note.done then
                table.insert(remaining, note)
            end

        end

        notes = remaining
        saveNotes(notes)

        lastMessage = "Cleared completed notes."
        lastMessageColor = theme.get("success")

    elseif action == "clear" and words[2] == "all" then

        notes = {}
        saveNotes(notes)

        lastMessage = "Cleared all notes."
        lastMessageColor = theme.get("success")

    elseif action == "help" then

        ui.viewer("Notes Help", HELP_LINES)

    elseif action == "quit" or action == "exit" then

        ui.clear()
        return

    else

        lastMessage = "Unknown command: " .. action
        lastMessageColor = theme.get("error")

    end

end
