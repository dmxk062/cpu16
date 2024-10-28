# CPU-16 project

My idea of a 16 bit, RISC, non von Neumann CPU architecture

Features:
- 16 bit word and byte addressable address space for data and I/O
- 16 bit word and byte addressable address space for instructions: 32K instructions
- Big-Endian

# Registers

*The highest bit in the register code is the size select, inverted*

| Name  | Code  | Size          | Description
|-      |-      |-              |-
| r0    | 0     | 16 bit        | GP register 0
| r1    | 1     | 16 bit        | GP register 1
| r2    | 2     | 16 bit        | GP register 2
| r3    | 3     | 16 bit        | GP register 3
| rsp   | 4     | 16 bit        | Stack pointer
| rpp   | 5     | 16 bit        | Program pointer
| rfl   | 6     | 16 bit        | Program flags
| rint  | 7     | 16 bit        | Last interrupt
| r0l   | 8     | 8 bit         | GP register 0, lower
| r1l   | 9     | 8 bit         | GP register 1, lower
| r2l   | A     | 8 bit         | GP register 2, lower
| r3l   | B     | 8 bit         | GP register 3, lower
| r0u   | C     | 8 bit         | GP register 0, upper
| r1u   | D     | 8 bit         | GP register 1, upper
| r2u   | E     | 8 bit         | GP register 2, upper
| r3u   | F     | 8 bit         | GP register 3, upper

## Flags

| Mnemonic  | Position  | Description
|-          |-          |-
| Z         | 0         | Last arithmetic result was 0
| N         | 1         | Last arithmetic result was less than 0
| C         | 2         | Last arithmetic result resulted in a carry or borrow
| O         | 3         | Last arithmetic result resulted in overflow
| I         | 4         | Interrupt enable

# Instruction coding

Instructions are 16 bits long and can be followed by an operand
Operand size is determined by instruction size
Size interpretation of r2 depends on instruction

| Bits          | Width         | Meaning
|-              |-              |-
| 0..7          | 8 bits        | Opcode
| 8..8          | 1 bit         | 8 / 16 bit determinator
| 9..B          | 3 bits        | Register 1 select
| C..E          | 3 bits        | Register 2 select
| F..F          | 1 bit         | Data is immediate, not second register

# Instructions

| Mnemonic      | Code      | Parameters            | Description
|-              |-          |-                      |-
| nop           | 0x00      | -                     | Do nothing
| ld            | 0x01      | r1, r2 / r1, word     | Load *a2 -> a1
| lp            | 0x02      | r1, r2 / r1, word     | Load instruction *a2 -> a1
| sd            | 0x03      | r1, r2 / r1, word     | Store a1 -> a2
| sp            | 0x04      | r1, r2 / r1, word     | Store instruction a1 -> a2
| set           | 0x05      | r1, r2 / r1, word     | Store a2 -> a1
| push          | 0x06      | r1                    | Push r1 onto stack
| pull          | 0x07      | r1                    | Pull r1 from stack
| add           | 0x10      | r1, r2 / r1, word     | (a1 + a2) -> a1
| sub           | 0x11      | r1, r2 / r1, word     | (a1 - a2) -> a1
| mul           | 0x12      | r1, r2                | multiply r1 * r2; result -> r1, overflow -> r2
| div           | 0x13      | r1, r2                | divide r1 / r2; result -> r1, remainder -> r2
| not           | 0x14      | r1                    | invert r1
| and           | 0x15      | r1, r2 / r1, word     | bitwise and of a1 and a2 -> a1
| or            | 0x16      | r1, r2 / r1, word     | bitwise or of a1 and a2 -> a1
| xor           | 0x17      | r1, r2 / r1, word     | bitwise xor of a1 and a2 -> a1
| shl           | 0x18      | r1                    | shift r1 left
| shr           | 0x19      | r1                    | shift r1 right
| rol           | 0x1A      | r1, r2 / r1, word     | rotate a1 left by a2
| ror           | 0x1B      | r1, r2 / r1, word     | rotate a1 right by a2
| cmp           | 0x1F      | r1, r2 / r1, word     | "compare" r1 and r2, like sub but doesn't store result, just sets flags
| jmp           | 0x20      | r1 / word             | Jump to a1
| jiz           | 0x21      | r1 / word             | Jump to a1 if zero is set
| jnz           | 0x22      | r1 / word             | Jump to a1 if zero is not set
| jin           | 0x23      | r1 / word             | Jump to a1 if negative is set
| jnn           | 0x24      | r1 / word             | Jump to a1 if negative is not set
| jic           | 0x25      | r1 / word             | Jump to a1 if carry is set
| jnc           | 0x26      | r1 / word             | Jump to a1 if carry is not set
| jio           | 0x27      | r1 / word             | Jump to a1 if overflow is set
| jno           | 0x28      | r1 / word             | Jump to a1 if overflow is not set
| call          | 0x30      | r1 / word             | Call function at a1
| retf          | 0x31      | -                     | Return from function
| int           | 0x32      | r1 / word             | Trigger interrupt a1
| reti          | 0x33      | -                     | Return from interrupt
| halt          | 0x34      | -                     | Halt CPU until next interrupt
| stop          | 0x35      | -                     | Stop CPU fully
| cfl           | 0x40      | -                     | Clear all arithmetic flags
| czf           | 0x41      | -                     | Clear zero flag
| cnf           | 0x42      | -                     | Clear negative flag
| ccf           | 0x43      | -                     | Clear carry flag
| cof           | 0x44      | -                     | Clear overflow flag
| szf           | 0x45      | -                     | Set zero flag
| snf           | 0x46      | -                     | Set negative flag
| scf           | 0x47      | -                     | Set carry flag
| sof           | 0x48      | -                     | Set overflow flag

# Start sequence:

The reset vector is located at 0x0000
The interrupt vector is located at 0x00F0

# Calling convention:

The primary argument is parsed in `%r0` and `%r0` is always considered caller saved.
Further register arguments (up to a maximum of 3 total 16-bit arguments) are passed in `%r1` and `%r2`.
Other arguments are passed on the stack in reverse order (= the last argument is pushed first).
Return order is the exact opposite: the primary 16 bit return value is returned in `%r0`,
and the other two in `%r1` and `%r2`, additional return values are pushed onto the stack in order (= last value last).
Any registers used as arguments to a function are considered caller saved,
registers not used as arguments and `%r3` are callee saved.

For 8 bit arguments the same order is true, lower registers are used before higher, `%r3l` and `r%3u` are not used.

In order for pushing return values onto the stack to work, it is necessary to decrement the stack pointer.
The same is true for a function taking arguments on the stack: it needs to first decrement the stack pointer to get back
to before the return address: `sub %rsp, 2` and then pull the values. Before returning it needs to increment the stack
pointer again: `add %rsp, 2`

Instead of passing or returning further values on the stack, it is also permissible to use pointers returned or passed
in `%r0`.


## Error handling

In case it is considered necessary for a function to perform error handling, the flags register can be used to communicate
various states.
