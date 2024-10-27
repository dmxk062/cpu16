local M = {}

local arch = require("arch")
local ffi = require("ffi")
local strbuf = require("string.buffer")


---@class dataitem
---@field offset integer?
---@field section "data"|"code"
---@field value integer[]
---@field pre_labels string[]
---@field width integer

---@class asm_error
---@field lnum integer
---@field text string

local data_generators = {
    ["byte"] = function(data)
        local val = data[2].value
        if val.valtype ~= "number" then
            return nil, nil, "Invalid type for argument to .byte: " .. val.valtype
        end
        if val.value > arch.byte_max then
            return nil, nil, string.format("Out of range argument to .byte: 0x%X", val.value)
        end
        return { val.value }, 1
    end,
    ["bytes"] = function(data)
        local res = {}
        for i = 2, #data do
            local val = data[i].value
            if val.valtype ~= "number" then
                return nil, nil, "Invalid type for argument to .bytes: " .. val.valtype
            end
            if val.value > arch.byte_max then
                return nil, nil, string.format("Out of range argument to .bytes: 0x%X", val.value)
            end
            table.insert(res, val.value)
        end
        return res, 1
    end,
    ["word"] = function(data)
        local val = data[2].value
        if val.valtype ~= "number" then
            return nil, nil, "Invalid type for argument to .word: " .. val.valtype
        end
        if val.value > arch.word_max then
            return nil, nil, string.format("Out of range argument to .word: 0x%X", val.value)
        end
        return { val.value }, 2
    end,
    ["words"] = function(data)
        local res = {}
        for i = 2, #data do
            local val = data[i].value
            if val.valtype ~= "number" then
                return nil, nil, "'" .. val.value .. "': Invalid type for argument to .words: " .. val.valtype
            end
            if val.value > arch.word_max then
                return nil, nil, string.format("Out of range argument to .words: 0x%X", val.value)
            end
            table.insert(res, val.value)
        end
        return res, 2
    end,
    ["string"] = function(data)
        local val = data[2].value
        if val.valtype ~= "string" then
            return nil, nil, "'" .. val.value .. "': Invalid type for argument to .string: " .. val.valtype
        end
        local res = { string.byte(val.value, 1, #val.value) }
        return res, 1
    end,
    ["zstring"] = function(data)
        local val = data[2].value
        if val.valtype ~= "string" then
            return nil, nil, "'" .. val.value .. "': Invalid type for argument to .string: " .. val.valtype
        end
        local res = { string.byte(val.value, 1, #val.value) }
        table.insert(res, 0)
        return res, 1
    end,
}

---@class irinst
---@field lnum integer
---@field op table
---@field r1 string?
---@field r2 string?
---@field immediate any?
---@field width integer
---@field long boolean
---@field pre_labels string[]?
---@field resolved boolean
---@field offset integer?
---@field section "data"|"code"

local function ir_for_op(node)
    local mn = node.fields[1]
    if not arch.instructions[mn] then
        return nil, { text = "Unknown mnemonic: '" .. mn .. "'" }
    end

    local inst = arch.instructions[mn]
    local argcount = #node.fields - 1

    if (inst.type == "none" and argcount > 0)
        or ((inst.type == "sr" or inst.type == "srow") and argcount > 1)
        or argcount > 2 then
        return nil, { text = "Excess arguments to '" .. mn .. "'" }
    end

    if ((inst.type == "sr" or inst.type == "srow") and argcount < 1)
        or ((inst.type == "drow" or inst.type == "dr") and argcount < 2) then
        return nil, { text = "Missing arguments to '" .. mn .. "'" }
    end

    ---@type irinst
    ---@diagnostic disable-next-line: missing-fields
    local op = {
        op = inst,
        long = false,
        resolved = true,
        width = 1
    }

    local r1, r2, imm

    if inst.type == "sr" then
        local a1 = node.fields[2].value
        if a1.type ~= "reg" then
            return nil, { text = "'" .. mn .. "' requires a single register operand" }
        elseif not arch.registers[a1.value] then
            return nil, { text = "Unknown register: %" .. a1.value }
        end

        r1 = a1.value
    elseif inst.type == "srow" then
        local a1 = node.fields[2].value
        if a1.type == "reg" and not arch.registers[a1.value] then
            return nil, { text = "Unknown register: %" .. a1.value }
        end

        if a1.type == "reg" then
            r1 = a1.value
        else
            imm = a1.value
            if a1.valtype == "identifier" then
                op.resolved = false
            end
        end
    elseif inst.type == "dr" then
        local a1 = node.fields[2].value
        local a2 = node.fields[3].value
        if a1.type ~= "reg" or a2.type ~= "reg" then
            return nil, { text = "'" .. mn .. "' requires two register operands" }
        end

        r1 = a1.value
        r2 = a2.value
    elseif inst.type == "drow" then
        local a1 = node.fields[2].value
        local a2 = node.fields[3].value
        if a1.type ~= "reg" or not a2.type == "reg" then
            return nil,
                { text = "'" .. mn .. "' requires two register, or one register and one word operand" }
        elseif not arch.registers[a1.value] then
            return nil, { text = "Unknown register: %" .. a1.value }
        elseif a2.type == "reg" and not arch.registers[a2.value] then
            return nil, { text = "Unknown register: %" .. a1.value }
        end

        r1 = a1.value
        if a2.type == "reg" then
            r2 = a2.value
        else
            imm = a2.value
            if a2.valtype == "identifier" then
                op.resolved = false
            end
        end
    end

    if r1 and r2 and (arch.registers[r1].large ~= arch.registers[r2].large) and (not inst.r2full) then
        return nil, { text = "Mismatched operand sizes: %" .. r1 .. " and %" .. r2 }
    elseif imm and r1 and not inst.r2full then
        if not op.resolved and not arch.registers[r1].large then
            return nil, { text = "Cannot store label value in 8-bit register %" .. r1 }
        end

        if op.resolved and (imm > arch.word_max or (imm > arch.byte_max and not arch.registers[r1].large)) then
            return nil, { text = string.format("Out of range immediate operand: 0x%X", imm) }
        end
    end

    if (imm and op.resolved and imm > arch.byte_max) or not op.resolved or (r1 and arch.registers[r1].large) then
        op.width = 2
        op.long = true
    elseif inst.r2full then
        op.long = true
    end


    op.r1 = r1
    op.r2 = r2
    op.immediate = imm

    return op
end

---@param tree expr[]
---@return irinst[]?
---@return dataitem[]?
---@return asm_error?
local function assemble_ir(tree)
    local cur_section = "code"
    local cur_labels = {}
    local cur_offset = {
        code = nil,
        data = nil,
    }

    ---@type irinst[]
    local data = {}
    local code = {}
    for i, node in ipairs(tree) do
        if node.type == "directive" then
            local dir = node.fields[1]
            if dir == "section" then
                local section = node.fields[2]
                if not section then
                    return nil, nil, { text = "Missing argument to .section directive [code,data]", lnum = node.lnum }
                elseif not (section.value.value == "code" or section.value.value == "data") then
                    return nil, nil,
                        { text = "Invalid section: '" .. section.value .. "' (valid are: [code,data])", lnum = node.lnum }
                end
                cur_section = section.value.value;
            elseif dir == "org" then
                local addr = node.fields[2]
                if not addr then
                    return nil, nil, { text = "Missing argument to .org directive [int]", lnum = node.lnum }
                end
                local val = addr.value
                if val.valtype ~= "number" then
                    return nil, nil, { text = "Invalid type for argument to .org: " .. val.valtype, lnum = node.lnum }
                end
                if val.value > arch.word_max then
                    return nil, nil,
                        { text = string.format("Out of range argument to .org: 0x%X", val.value), lnum = node.lnum }
                end
                cur_offset[cur_section] = val.value
            elseif data_generators[dir] then
                if not node.fields[2] then
                    return nil, nil, { text = "Missing argument to ." .. dir .. "directive", lnum = node.lnum }
                end
                local vals, width, err = data_generators[dir](node.fields)
                if err then
                    return nil, nil, { text = err, lnum = node.lnum }
                end
                table.insert(code, {
                    type = "data",
                    offset = cur_offset[cur_section],
                    value = vals,
                    section = cur_section,
                    width = width,
                    pre_labels = #cur_labels > 0 and cur_labels or nil
                })
                if #cur_labels > 0 then cur_labels = {} end
                if cur_offset[cur_section] then cur_offset[cur_section] = nil end
            end
        elseif node.type == "label" then
            table.insert(cur_labels, node.fields[1])
        elseif node.type == "statement" then
            local op, err = ir_for_op(node)
            if not op then
                err.lnum = node.lnum
                return nil, nil, err
            end
            op.pre_labels = #cur_labels > 0 and cur_labels or nil
            op.offset = cur_offset[cur_section]
            op.section = cur_section
            op.lnum = node.lnum
            op.type = "code"
            if #cur_labels > 0 then cur_labels = {} end
            if cur_offset[cur_section] then cur_offset[cur_section] = nil end

            table.insert(code, op)
        end
    end

    return code, data
end

---@param code (irinst|dataitem)[]
local function assemble_and_link(code)
    local linker_table = {}
    local linker_offsets = {}
    local codebuf = ffi.new("uint8_t[?]", arch.word_max)
    local databuf = ffi.new("uint8_t[?]", arch.word_max)

    local bufs = {
        code = codebuf,
        data = databuf,
    }
    local indices = {
        code = 0,
        data = 0
    }

    local section = "code"

    for i, expr in ipairs(code) do
        section = expr.section
        if expr.offset then
            indices[section] = expr.offset
        end
        local index = indices[section]
        if expr.pre_labels then
            for _, lbl in pairs(expr.pre_labels) do
                linker_table[lbl] = index
            end
        end

        if expr.type == "code" then
            local opcode = expr.op.code
            local spec = 0
            if expr.immediate then
                spec = bit.bor(spec, 0b00000001)
            end
            if expr.width == 2 then
                spec = bit.bor(spec, 0b10000000)
            end
            if expr.r1 then
                spec = bit.bor(spec, (bit.lshift(arch.registers[expr.r1].code, 4)))
            end
            if expr.r2 then
                spec = bit.bor(spec, (bit.lshift(arch.registers[expr.r2].code, 1)))
            end
            bufs[section][index] = opcode
            bufs[section][index + 1] = spec
            index = index + 2

            if expr.immediate then
                if expr.resolved then
                    if expr.width == 2 then
                        local low = bit.band(expr.immediate, 0xFF)
                        local high = bit.rshift(bit.band(expr.immediate, 0xFF00), 8)
                        bufs[section][index] = high
                        bufs[section][index + 1] = low
                        index = index + 2
                    else
                        bufs[section][index] = expr.immediate
                        index = index + 1
                    end
                else
                    table.insert(linker_offsets, { expr, index })
                    index = index + 2
                end
            end
        elseif expr.type == "data" then
            for _, val in ipairs(expr.value) do
                if expr.width == 2 then
                    local low = bit.band(val, 0xFF)
                    local high = bit.rshift(bit.band(val, 0xFF00), 8)
                    bufs[section][index] = high
                    bufs[section][index + 1] = low
                    index = index + 2
                else
                    bufs[section][index] = val
                    index = index + 1
                end
            end
        end
        indices[section] = index
    end

    for i, elem in pairs(linker_offsets) do
        local op = elem[1]
        local sym = op.immediate
        local addr = elem[2]
        local resolved = linker_table[sym]
        if not resolved then
            return nil, nil, { text = "Undefined symbol: '" .. sym .. "'", lnum = op.lnum }
        end
        bufs[op.section][addr] = bit.rshift(bit.band(resolved, 0xFF00), 8)
        bufs[op.section][addr + 1] = bit.band(resolved, 0xFF)
    end
    return codebuf, databuf
end


---@param text string
function M.assemble(text)
    local syntax, err = require("parser").parse(text)
    if not syntax then
        return nil, nil, err
    end

    local ir, data, asm_err = assemble_ir(syntax)
    if asm_err then
        return nil, nil, asm_err
    end

    local codebin, databin, linkerr = assemble_and_link(ir, data)
    if linkerr then
        return nil, nil, linkerr
    end

    local cbuf = strbuf.new(arch.word_max)
    local dbuf = strbuf.new(arch.word_max)

    cbuf:putcdata(codebin, arch.word_max)
    dbuf:putcdata(databin, arch.word_max)
    return cbuf, dbuf, nil
end

return M
