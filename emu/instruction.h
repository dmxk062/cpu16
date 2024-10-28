#pragma once
#include "types.h"
#include <stdbool.h>

typedef union {
    word value;
    struct {
        bool zero : 1;
        bool negative : 1;
        bool carry : 1;
        bool overflow : 1;
        bool int_enable : 1;
        word unused : 11;
    };
} __attribute__((packed)) RFlags;

enum OP : byte {
    NOP = 0x00,
    LD = 0x01,
    LP = 0x02,
    SD = 0x03,
    SP = 0x04,
    SET = 0x05,
    PUSH = 0x06,
    PULL = 0x07,
    ADD = 0x10,
    SUB = 0x11,
    MUL = 0x12,
    DIV = 0x13,
    NOT = 0x14,
    AND = 0x15,
    OR = 0x16,
    XOR = 0x17,
    SHL = 0x18,
    SHR = 0x19,
    INC = 0x1A,
    DEC = 0x1B,
    CMP = 0x1F,
    JMP = 0x20,
    JIZ = 0x21,
    JNZ = 0x22,
    JIN = 0x23,
    JNN = 0x24,
    JIC = 0x25,
    JNC = 0x26,
    JIO = 0x27,
    JNO = 0x28,
    CALL = 0x30,
    RETF = 0x31,
    INT = 0x32,
    HALT = 0x33,
    STOP = 0x34,
    CFL = 0x40,
    CZF = 0x41,
    CNF = 0x42,
    CCF = 0x43,
    COF = 0x44,
    SZF = 0x45,
    SNF = 0x46,
    SCF = 0x47,
    SOF = 0x48,
    WR = 0x50,
    RD = 0x51,
};

typedef union {
    word value;
    struct {
        union {
            enum OP op : 8;
            byte high;
        };
        byte spec;
    };
} __attribute__((packed)) Inst;

#define IS16(op) (op.spec & 0b10000000)
#define HASI(op) (op.spec & 0b00000001)
#define R1(op) ((op.spec & 0b01110000) >> 4)
#define R2(op) ((op.spec & 0b00001110) >> 1)

typedef byte* R8bit[8];
typedef word* R16bit[8];
