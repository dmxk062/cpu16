#!/usr/bin/luajit

local os = require("os")

USAGE_INFO = [[
Usage: as.lua [OPTION]... FILE

Options:
    -o, --output FILE       Write machine code to FILE instead of a.out
    -O, --data-output FILE  Write ram output to FILE instead of mem.bin
    -p, --padd              Zero padd code
    -P, --padd-data         Zero padd memory
]]

function Main(argv)
    if #argv == 0 then
        print(USAGE_INFO)
        return 1
    end

    local input_file
    local code_out = "a.out"
    local data_out = "mem.bin"

    local skip = false

    for i = 1, #argv do
        local param = argv[i]
        if skip then
            skip = false
            goto continue
        end

        if param == "-o" or param == "--output" then
            code_out = argv[i + 1]
            i = i + 1
            skip = true
        elseif param == "-O" or param == "--data-output" then
            data_out = argv[i + 1];
            i = i + 1
            skip = true
        else
            input_file = param
        end
        ::continue::
    end

    if not input_file then
        print(USAGE_INFO)
        return 1
    end

    local input, err = io.open(input_file, "r")
    if not input then
        print(err)
        return 1
    end

    local code = input:read("*a")
    input:close()

    local machine_code, data, asm_err = require("assembly").assemble(code)
    if asm_err then
        print(asm_err.lnum .. ": " .. asm_err.text)
        return 1
    end

    local machine_code_out, oerr = io.open(code_out, "wb")
    if (oerr) then print(oerr); return 1 end
    local binary_data_out, derr = io.open(data_out, "wb")
    if (derr) then print(derr); return 1 end

    machine_code_out:write(tostring(machine_code))
    machine_code_out:close()
    binary_data_out:write(tostring(data))
    binary_data_out:close()
end

os.exit(Main(arg))
