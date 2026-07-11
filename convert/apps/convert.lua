--------------------------------------------------
-- Convert
--------------------------------------------------

local ui = use("ui")
local app = use("app")
local theme = use("theme")

--------------------------------------------------

local info = app.create({

    name = "convert",

    version = "1.0",

    author = "-ASTR-",

    description = "Converts between length, mass, volume, and temperature units."

})

if INFO_ONLY then return info end

--------------------------------------------------
-- Unit Tables
--
-- Length, mass and volume are plain multiplicative
-- factors relative to one base unit per category
-- (result = value * factors[from] / factors[to]).
-- Temperature is handled separately below since C/F/K
-- aren't related by a simple factor.
--------------------------------------------------

local CATEGORIES = {

    length = {

        base = "m",

        factors = {

            m = 1, meter = 1, meters = 1, metre = 1, metres = 1,
            block = 1, blocks = 1,

            km = 1000, kilometer = 1000, kilometers = 1000,
            cm = 0.01, centimeter = 0.01, centimeters = 0.01,
            mm = 0.001, millimeter = 0.001, millimeters = 0.001,

            ft = 0.3048, foot = 0.3048, feet = 0.3048,
            inch = 0.0254, inches = 0.0254, ["in"] = 0.0254,
            yd = 0.9144, yard = 0.9144, yards = 0.9144,
            mi = 1609.344, mile = 1609.344, miles = 1609.344

        }

    },

    mass = {

        base = "kg",

        factors = {

            kg = 1, kilogram = 1, kilograms = 1,
            g = 0.001, gram = 0.001, grams = 0.001,
            mg = 0.000001, milligram = 0.000001, milligrams = 0.000001,

            lb = 0.45359237, lbs = 0.45359237, pound = 0.45359237, pounds = 0.45359237,
            oz = 0.028349523125, ounce = 0.028349523125, ounces = 0.028349523125

        }

    },

    volume = {

        base = "l",

        factors = {

            l = 1, liter = 1, liters = 1, litre = 1, litres = 1,
            ml = 0.001, milliliter = 0.001, milliliters = 0.001,

            gal = 3.785411784, gallon = 3.785411784, gallons = 3.785411784

        }

    }

}

local TEMPERATURE_UNITS = {

    c = true, celsius = true,
    f = true, fahrenheit = true,
    k = true, kelvin = true

}

--------------------------------------------------
-- Convert Temperature
--
-- Routes through Celsius as a common intermediate.
--------------------------------------------------

local function toCelsius(value, unit)

    if unit == "c" or unit == "celsius" then
        return value
    elseif unit == "f" or unit == "fahrenheit" then
        return (value - 32) * 5 / 9
    elseif unit == "k" or unit == "kelvin" then
        return value - 273.15
    end

    return nil

end

local function fromCelsius(celsius, unit)

    if unit == "c" or unit == "celsius" then
        return celsius
    elseif unit == "f" or unit == "fahrenheit" then
        return celsius * 9 / 5 + 32
    elseif unit == "k" or unit == "kelvin" then
        return celsius + 273.15
    end

    return nil

end

local function convertTemperature(value, from, to)

    local celsius = toCelsius(value, from)

    if not celsius then
        return nil, "Unknown temperature unit: " .. from
    end

    local result = fromCelsius(celsius, to)

    if not result then
        return nil, "Unknown temperature unit: " .. to
    end

    return result

end

--------------------------------------------------
-- Find Category
--
-- Returns the CATEGORIES entry whose factors table
-- contains "unit", or nil if none does.
--------------------------------------------------

local function findCategory(unit)

    for _, category in pairs(CATEGORIES) do

        if category.factors[unit] then
            return category
        end

    end

    return nil

end

--------------------------------------------------
-- Convert
--
-- Returns result, nil on success or nil, errorText
-- on failure (unknown unit, or from/to in different
-- categories).
--------------------------------------------------

local function convert(value, from, to)

    from = from:lower()
    to = to:lower()

    if TEMPERATURE_UNITS[from] or TEMPERATURE_UNITS[to] then

        if not (TEMPERATURE_UNITS[from] and TEMPERATURE_UNITS[to]) then
            return nil, "Can't mix a temperature unit with a non-temperature one"
        end

        return convertTemperature(value, from, to)

    end

    local category = findCategory(from)

    if not category then
        return nil, "Unknown unit: " .. from
    end

    if not category.factors[to] then
        return nil, "'" .. to .. "' isn't a " .. category.base .. "-family unit like '" .. from .. "'"
    end

    return value * category.factors[from] / category.factors[to]

end

--------------------------------------------------
-- Format Number
--------------------------------------------------

local function formatNumber(n)

    if n ~= n then
        return "NaN"
    end

    local rounded = math.floor(n * 1e6 + 0.5) / 1e6

    if rounded == math.floor(rounded) then
        return tostring(math.floor(rounded))
    end

    return tostring(rounded)

end

--------------------------------------------------
-- Parse Input
--
-- Accepts "<value> <fromUnit> to <toUnit>" or the
-- same without the word "to". Returns value, from,
-- to or nil, errorText.
--------------------------------------------------

local function parseInput(input)

    local value, from, to = input:match("^%s*(-?%d+%.?%d*)%s+(%a+)%s+to%s+(%a+)%s*$")

    if not value then
        value, from, to = input:match("^%s*(-?%d+%.?%d*)%s+(%a+)%s+(%a+)%s*$")
    end

    if not value then
        return nil, nil, nil, "Usage: <value> <fromUnit> to <toUnit>"
    end

    return tonumber(value), from, to

end

--------------------------------------------------
-- Help Text
--------------------------------------------------

local HELP_LINES = {

    "Usage: <value> <fromUnit> to <toUnit>",
    "Example: 10 m to ft",
    "",
    "Length: m km cm mm ft in yd mi (block = m)",
    "Mass: kg g mg lb oz",
    "Volume: l ml gal",
    "Temperature: c f k",
    "",
    "'quit' to exit."

}

--------------------------------------------------
-- Main Loop
--------------------------------------------------

local lastMessage = nil
local lastMessageColor = nil

while true do

    ui.clear()

    print("Unit Converter")
    print()

    if lastMessage then

        term.setTextColor(lastMessageColor or theme.get("text"))
        print(lastMessage)
        term.setTextColor(theme.get("text"))
        print()

    end

    print("<value> <fromUnit> to <toUnit>   (e.g. 10 m to ft)")
    print("'help' for the full unit list, 'quit' to exit.")
    print()

    write("> ")

    local input = read()

    local trimmed = input:match("^%s*(.-)%s*$")

    if trimmed == "" then

        -- ignore, keep showing the last result/error

    elseif trimmed == "quit" or trimmed == "exit" then

        ui.clear()
        return

    elseif trimmed == "help" then

        ui.viewer("Convert Help", HELP_LINES)

    else

        local value, from, to, parseErr = parseInput(trimmed)

        if not value then

            lastMessage = "Error: " .. parseErr
            lastMessageColor = theme.get("error")

        else

            local result, convertErr = convert(value, from, to)

            if result then

                lastMessage = value .. " " .. from .. " = " .. formatNumber(result) .. " " .. to
                lastMessageColor = theme.get("success")

            else

                lastMessage = "Error: " .. convertErr
                lastMessageColor = theme.get("error")

            end

        end

    end

end
