local M = {}

local comment_string = ";"

---@alias exprtype
---|"statement" -- set %r0, 1
---|"label"     -- function:
---|"macro"     -- value = 1
---|"directive" -- .org 0x00, .string "Hello world"

---@alias argtype
---|"reg"       -- %rsp
---|"literal"   -- 0x00, 'c', 0b100
---|"label"     -- label

---@class argument
---@field type argtype
---@field valtype "string"|"number"|"keyword"|"identifier"
---@field value any

---@class exprfield
---@field text string
---@field datatype "keyword"|"argument"
---@field value string|argument

---@class expr
---@field type exprtype
---@field fields exprfield[]
---@field lnum integer?

---@class syntax_err
---@field text string
---@field lnum integer

local function split(str, delim)
    local res = {}
    for part in string.gmatch(str, "([^" .. delim .. "]*)" .. delim .. "?") do
        table.insert(res, part)
    end
    return res
end

local function startswith(str, prefix)
    return str:sub(1, #prefix) == prefix
end

---@return string
local function advance(text, len)
    return text:sub(len):gsub("^%s*", "")
end

---@param text string
local function get_esc_string(text, char)
    local found = false
    local endpos = 1
    local startpos = text:find(char)
    if not startpos then
        return nil
    end

    for i = startpos + 1, #text do
        local c = text:sub(i, i)
        endpos = i
        if c == char and text:sub(i - 1, i - 1) ~= '\\' then
            found = true
            break
        end
    end

    if not found then
        return nil
    end

    return text:sub(startpos+1, endpos-1)
end


---@param text string
local function escape_inside_string(text)
    return text:gsub("\\0", "\0"):gsub("\\n", "\n"):gsub("\\r", "\r")
end


local macros = {}

---@param text string
---@return argument?
local function parse_arg(text)
    if macros[text] then
        text = macros[text]
    end

    local reg_match = text:match("^%%([%w%d]+)$")
    if reg_match then
        return {
            type = "reg",
            valtype = "keyword",
            value = reg_match
        }
    end

    local decimal_match = text:match("^(%d+)$")
    if decimal_match then
        return {
            type = "literal",
            valtype = "number",
            value = tonumber(decimal_match, 10)
        }
    end

    local bin_match = text:match("^0b([01]+)$")
    if bin_match then
        return {
            type = "literal",
            valtype = "number",
            value = tonumber(bin_match, 2)
        }
    end

    local hex_match = text:match("^0x(%x+)$")
    if hex_match then
        return {
            type = "literal",
            valtype = "number",
            value = tonumber(hex_match, 16)
        }
    end

    local string_match = get_esc_string(text, '"')
    if string_match then
        return {
            type = "literal",
            valtype = "string",
            value = escape_inside_string(string_match),
        }
    end

    local char_match = get_esc_string(text, "'")
    if char_match then
        local esc = escape_inside_string(char_match)
        if #esc == 1 then
            return {
                type = "literal",
                valtype = "number",
                value = string.byte(esc)
            }
        end
    end


    return {
        type = "label",
        valtype = "identifier",
        value = text
    }
end

---@return expr?
---@return syntax_err?
---@param _line string
local function get_expr_line(_line)
    local line = _line:gsub("^%s+", ""):gsub(comment_string .. ".*", "")
    if line == "" then
        return nil, nil
    end

    ---@type expr
    local expr = nil
    local start = 0

    local _, _, label_txt = line:find("^([%w_]+):")
    if label_txt then
        return {
            type = "label",
            fields = { label_txt }
        }
    end

    if not expr then
        local _, directive_end, directive_txt = line:find("^%.([%w_]+)")
        if directive_txt then
            expr = {
                type = "directive",
                fields = { directive_txt, }
            }
            start = directive_end + 1
        end
    end

    if not expr then
        local macro_name, macro_value = line:match("^([%w_]+)%s*=%s*(.*)%s*$")
        if macro_name and macro_value then
            expr = {
                type = "macro",
                fields = { macro_name, macro_value }
            }
            macros[macro_name] = macro_value
            return expr
        end
    end

    if not expr then
        local _, mn_end, mn_txt = line:find("^([%w_]+)")
        if mn_txt then
            expr = {
                type = "statement",
                fields = { mn_txt },
            }
            start = mn_end + 1
        end
    end

    if not expr then
        return nil, { text = "Invalid syntax" }
    end

    line = advance(line, start)
    while #line > 0 do
        local inside_quotes = false
        local endpos = 1
        -- intelligently find pattern
        for i = 1, #line do
            local char = line:sub(i, i)
            endpos = i
            if char == "," and not inside_quotes then
                endpos = endpos + 1
                break
            elseif (char == '"' and line:sub(i - 1, i - 1) ~= '\"') or (char == "'" and line:sub(i - 1, i - 1) ~= "\'") then
                inside_quotes = not inside_quotes
            end
        end
        local elem = line:sub(1, endpos):gsub("^%s+", ""):gsub(",?%s+$", "")
        line = line:sub(endpos + 1, #line)

        if elem == "" then
            break
        end
        local parsed = parse_arg(elem)
        if not parsed then
            return nil, { text = "Invalid argument: " .. elem }
        end
        table.insert(expr.fields, {type = "argument", value = parsed})
    end

    return expr
end

---comment
---@param lines any
---@return expr[]?
---@return syntax_err?
local function parse_lines(lines)
    ---@type expr[]
    local tree = {}
    for i, line in ipairs(lines) do
        if #line == 0 or line:match("^%s*" .. comment_string) then
            goto continue
        end

        local expr, err = get_expr_line(line)
        if err then
            err.lnum = i
            return nil, err
        end
        if not expr then
            goto continue
        end
        expr.lnum = i
        table.insert(tree, expr)

        ::continue::
    end
    return tree, nil
end

---@return expr[]?
---@return syntax_err[]?
function M.parse(text)
    local lines = split(text, "\n")
    local syntax_tree, err = parse_lines(lines)
    if err then
        return nil, err
    end
    return syntax_tree, nil
end

return M
