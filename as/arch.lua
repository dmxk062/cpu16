local M = {}

---@alias insttype
---|"none"    -- no arguments at all
---|"dr"      -- two registers
---|"sr"      -- a single register
---|"srow"    -- single register or word
---|"drow"    -- 2 registers or 1 register and one word

---@class instruction
---@field type insttype
---@field code integer
---@field r2full boolean?

---@type table<string, instruction>
M.instructions = {
    -- memory
    ["nop"]  = { type = "none", code = 0x00 },
    ["ld"]   = { type = "drow", code = 0x01, r2full = true },
    ["lp"]   = { type = "drow", code = 0x02, r2full = true },
    ["sd"]   = { type = "drow", code = 0x03, r2full = true },
    ["sp"]   = { type = "drow", code = 0x04, r2full = true },
    ["set"]  = { type = "drow", code = 0x05 },
    ["push"] = { type = "sr", code = 0x06 },
    ["pull"] = { type = "sr", code = 0x07 },

    -- arithmetic
    ["add"]  = { type = "drow", code = 0x10 },
    ["sub"]  = { type = "drow", code = 0x11 },
    ["mul"]  = { type = "dr", code = 0x12 },
    ["div"]  = { type = "dr", code = 0x13 },
    ["not"]  = { type = "sr", code = 0x14 },
    ["and"]  = { type = "drow", code = 0x15 },
    ["or"]   = { type = "drow", code = 0x16 },
    ["xor"]  = { type = "drow", code = 0x17 },
    ["shl"]  = { type = "sr", code = 0x18 },
    ["shr"]  = { type = "sr", code = 0x19 },
    ["rol"]  = { type = "drow", code = 0x1A },
    ["ror"]  = { type = "drow", code = 0x1B },
    ["cmp"]  = { type = "drow", code = 0x1F },

    -- branches
    ["jmp"]  = { type = "srow", code = 0x20, r2full = true },
    ["jiz"]  = { type = "srow", code = 0x21, r2full = true },
    ["jnz"]  = { type = "srow", code = 0x22, r2full = true },
    ["jin"]  = { type = "srow", code = 0x23, r2full = true },
    ["jnn"]  = { type = "srow", code = 0x24, r2full = true },
    ["jic"]  = { type = "srow", code = 0x25, r2full = true },
    ["jnc"]  = { type = "srow", code = 0x26, r2full = true },
    ["jio"]  = { type = "srow", code = 0x27, r2full = true },
    ["jno"]  = { type = "srow", code = 0x28, r2full = true },

    -- functions
    ["call"] = { type = "srow", code = 0x30, r2full = true },
    ["retf"] = { type = "none", code = 0x31 },
    ["int"]  = { type = "srow", code = 0x32 },
    ["reti"] = { type = "none", code = 0x33 },
    ["halt"] = { type = "none", code = 0x34 },
    ["stop"] = { type = "none", code = 0x35 },

    -- flags
    ["cfl"]  = { type = "none", code = 0x40 },
    ["czf"]  = { type = "none", code = 0x41 },
    ["cnf"]  = { type = "none", code = 0x42 },
    ["ccf"]  = { type = "none", code = 0x43 },
    ["cof"]  = { type = "none", code = 0x44 },
    ["szf"]  = { type = "none", code = 0x45 },
    ["snf"]  = { type = "none", code = 0x46 },
    ["scf"]  = { type = "none", code = 0x47 },
    ["sof"]  = { type = "none", code = 0x48 },

    ["wr"]   = { type = "srow", code = 0x50 },
}

M.registers = {
    ["r0"]   = { large = true, code = 0x0 },
    ["r1"]   = { large = true, code = 0x1 },
    ["r2"]   = { large = true, code = 0x2 },
    ["r3"]   = { large = true, code = 0x3 },
    ["rsp"]  = { large = true, code = 0x4 },
    ["psp"]  = { large = true, code = 0x5 },
    ["rfl"]  = { large = true, code = 0x6 },
    ["rint"] = { large = true, code = 0x7 },

    ["r0l"]  = { large = false, code = 0x0 },
    ["r1l"]  = { large = false, code = 0x1 },
    ["r2l"]  = { large = false, code = 0x2 },
    ["r3l"]  = { large = false, code = 0x3 },
    ["r0u"]  = { large = false, code = 0x4 },
    ["r1u"]  = { large = false, code = 0x5 },
    ["r2u"]  = { large = false, code = 0x6 },
    ["r3u"]  = { large = false, code = 0x7 },
}

M.word_max = math.pow(2, 16)
M.byte_max = 255
return M
