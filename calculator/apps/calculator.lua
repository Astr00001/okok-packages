--------------------------------------------------
-- Calculator
--------------------------------------------------

local ui = use("ui")
local app = use("app")
local theme = use("theme")

--------------------------------------------------

local info = app.create({

    name = "calculator",

    version = "1.0",

    author = "-ASTR-",

    description = "Arithmetic calculator with operator precedence and parentheses."

})

if INFO_ONLY then return info end

--------------------------------------------------
-- Tokenize
--
-- Turns an expression string into a flat list of
-- number/operator tokens. Returns nil + an error
-- message on the first unrecognised character.
--------------------------------------------------

local function tokenize(s)

    local tokens = {}
    local i = 1
    local len = #s

    while i <= len do

        local c = s:sub(i, i)

        if c:match("%s") then

            i = i + 1

        elseif c:match("%d") or (c == "." and s:sub(i + 1, i + 1):match("%d")) then

            local j = i

            while j <= len and s:sub(j, j):match("[%d%.]") do
                j = j + 1
            end

            local numStr = s:sub(i, j - 1)
            local num = tonumber(numStr)

            if not num then
                return nil, "Invalid number: " .. numStr
            end

            table.insert(tokens, { type = "number", value = num })

            i = j

        elseif c == "+" or c == "-" or c == "*" or c == "/" or c == "%" or c == "^" or c == "(" or c == ")" then

            table.insert(tokens, { type = "op", value = c })

            i = i + 1

        else

            return nil, "Unexpected character: " .. c

        end

    end

    return tokens

end

--------------------------------------------------
-- Parse / Evaluate
--
-- Straight recursive-descent, evaluating directly
-- as it parses (no separate AST) - deliberately NOT
-- using load()/loadstring() on user input, so a
-- malformed expression can only ever produce an
-- error message, never arbitrary Lua execution.
--
-- Precedence, low to high:
--   expr  := term (('+' | '-') term)*
--   term  := unary (('*' | '/' | '%') unary)*
--   unary := '-' unary | power
--   power := primary ('^' unary)?     (right-assoc)
--   primary := number | '(' expr ')'
--------------------------------------------------

local function parse(tokens)

    local pos = 1

    local function peek()
        return tokens[pos]
    end

    local function advance()
        local t = tokens[pos]
        pos = pos + 1
        return t
    end

    local parseExpr, parseTerm, parseUnary, parsePower, parsePrimary

    function parsePrimary()

        local t = peek()

        if not t then
            return nil, "Unexpected end of expression"
        end

        if t.type == "number" then
            advance()
            return t.value
        end

        if t.type == "op" and t.value == "(" then

            advance()

            local value, err = parseExpr()

            if not value then
                return nil, err
            end

            local closing = peek()

            if not closing or closing.value ~= ")" then
                return nil, "Missing closing parenthesis"
            end

            advance()

            return value

        end

        return nil, "Unexpected token: " .. tostring(t.value)

    end

    function parsePower()

        local base, err = parsePrimary()

        if not base then
            return nil, err
        end

        local t = peek()

        if t and t.type == "op" and t.value == "^" then

            advance()

            local exponent, expErr = parseUnary()

            if not exponent then
                return nil, expErr
            end

            return base ^ exponent

        end

        return base

    end

    function parseUnary()

        local t = peek()

        if t and t.type == "op" and t.value == "-" then

            advance()

            local value, err = parseUnary()

            if not value then
                return nil, err
            end

            return -value

        end

        return parsePower()

    end

    function parseTerm()

        local value, err = parseUnary()

        if not value then
            return nil, err
        end

        while true do

            local t = peek()

            if t and t.type == "op" and (t.value == "*" or t.value == "/" or t.value == "%") then

                advance()

                local rhs, rhsErr = parseUnary()

                if not rhs then
                    return nil, rhsErr
                end

                if t.value == "*" then

                    value = value * rhs

                elseif t.value == "/" then

                    if rhs == 0 then
                        return nil, "Division by zero"
                    end

                    value = value / rhs

                else

                    if rhs == 0 then
                        return nil, "Modulo by zero"
                    end

                    value = value % rhs

                end

            else

                break

            end

        end

        return value

    end

    function parseExpr()

        local value, err = parseTerm()

        if not value then
            return nil, err
        end

        while true do

            local t = peek()

            if t and t.type == "op" and (t.value == "+" or t.value == "-") then

                advance()

                local rhs, rhsErr = parseTerm()

                if not rhs then
                    return nil, rhsErr
                end

                if t.value == "+" then
                    value = value + rhs
                else
                    value = value - rhs
                end

            else

                break

            end

        end

        return value

    end

    local result, err = parseExpr()

    if not result then
        return nil, err
    end

    if pos <= #tokens then
        return nil, "Unexpected token: " .. tostring(tokens[pos].value)
    end

    return result

end

--------------------------------------------------
-- Evaluate
--------------------------------------------------

local function evaluate(expression)

    local tokens, tokenizeErr = tokenize(expression)

    if not tokens then
        return nil, tokenizeErr
    end

    if #tokens == 0 then
        return nil, "Empty expression"
    end

    return parse(tokens)

end

--------------------------------------------------
-- Format Number
--
-- Rounds away float noise (e.g. 0.1 + 0.2 showing
-- as 0.30000000000004) and drops a trailing ".0"
-- for whole-number results.
--------------------------------------------------

local function formatNumber(n)

    if n ~= n then
        return "NaN"
    end

    if n == math.huge then
        return "inf"
    end

    if n == -math.huge then
        return "-inf"
    end

    local rounded = math.floor(n * 1e10 + 0.5) / 1e10

    if rounded == math.floor(rounded) then
        return tostring(math.floor(rounded))
    end

    return tostring(rounded)

end

--------------------------------------------------
-- Main Loop
--------------------------------------------------

local lastMessage = nil
local lastMessageColor = nil

while true do

    ui.clear()

    print("Calculator")
    print()

    if lastMessage then

        term.setTextColor(lastMessageColor or theme.get("text"))
        print(lastMessage)
        term.setTextColor(theme.get("text"))
        print()

    end

    print("Enter an expression: + - * / % ^ ( )")
    print("Type 'quit' to exit.")
    print()

    write("> ")

    local input = read()

    local trimmed = input:match("^%s*(.-)%s*$")

    if trimmed == "" then

        -- ignore, keep showing the last result/error

    elseif trimmed == "quit" or trimmed == "exit" then

        ui.clear()
        return

    else

        local result, err = evaluate(trimmed)

        if result then

            lastMessage = trimmed .. " = " .. formatNumber(result)
            lastMessageColor = theme.get("success")

        else

            lastMessage = "Error: " .. err
            lastMessageColor = theme.get("error")

        end

    end

end
