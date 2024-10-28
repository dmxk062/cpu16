#include "instruction.h"
#include "types.h"
#include <endian.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define SPACE (64 * 1024)

byte* read_memfile(char* path, size_t size, size_t n) {
    struct stat st;
    int err = stat(path, &st);
    if (err) {
        fprintf(stderr, "Failed to stat() %s: %s\n", path, strerror(errno));
        return NULL;
    }
    if (!S_ISREG(st.st_mode)) {
        fprintf(stderr, "Not a regular file: %s\n", path);
        return NULL;
    }

    if (st.st_size > size * n) {
        fprintf(stderr, "%s: too large (%ld B > %zu B)\n", path, st.st_size,
                size * n);
        return NULL;
    }

    FILE* fl = fopen(path, "rb");
    if (!fl) {
        fprintf(stderr, "Failed to open() %s: %s\n", path, strerror(errno));
        return NULL;
    }

    byte* memory = calloc(n, size);
    if (!memory) {
        fclose(fl);
        fprintf(stderr, "Failed to calloc() %zu bytes", n * size);
        return NULL;
    }

    fread(memory, 1, st.st_size, fl);
    fclose(fl);
    return memory;
}

static inline word stack_get_word(byte* stack, word* index) {
    word upper = stack[*index];
    word lower = stack[*index + 1];
    *index += 2;
    return (upper << 8) + lower;
}

static inline word little2big(word w) {
    return ((w & 0xFF00) << 16) + (w & 0xFF);
}

#define GETA1_16(op)                                                           \
    (HASI(op) ? (stack_get_word(code, &rpp)) : *reg16bit[R1(op)])
#define GETA2_16(op)                                                           \
    (HASI(op) ? (stack_get_word(code, &rpp)) : *reg16bit[R2(op)])
#define GETA1_8(op) (HASI(op) ? (code[rpp++]) : *reg8bit[R1(op)])
#define GETA2_8(op) (HASI(op) ? (code[rpp++]) : *reg8bit[R2(op)])

#define JMP(target)                                                            \
    {                                                                          \
        rpp = target;                                                          \
        did_jump = true;                                                       \
        break;                                                                 \
    }
#define JMPI(expr)                                                             \
    {                                                                          \
        word _addr = GETA1_16(op);                                             \
        if (expr) {                                                            \
            rpp = _addr;                                                       \
            did_jump = true;                                                   \
        };                                                                     \
        break;                                                                 \
    }

int emu_loop(byte code[SPACE], byte data[SPACE]) {
    bool exit = false;
    // registers
    word rpp = 0;
    word rsp = 0;
    word rint = 0;
    word r0 = 0, r1 = 0, r2 = 0, r3 = 0;
    RFlags rfl = {0};

    R16bit reg16bit = {
        &r0, &r1, &r2, &r3, &rsp, &rpp, &rfl.value, &rint,
    };

    R8bit reg8bit = {
        (byte*)&r0,       (byte*)&r1,       (byte*)&r2,       (byte*)&r3,
        ((byte*)&r0) + 1, ((byte*)&r1) + 1, ((byte*)&r2) + 1, ((byte*)&r3) + 1,
    };

    bool did_jump = false;

    while (!exit) {
        Inst op = *((Inst*)(&code[rpp]));
        rpp += 2;

        switch (op.op) {
            // clang-format off
            case NOP: {break;}
            case LD: {
                // word arg2 = GETA2_16(op);
                word arg2 = *reg16bit[R2(op)];
                if (IS16(op)) {
                    *reg16bit[R1(op)] = *((word*)&data[arg2]);
                } else {
                    byte val = data[arg2];
                    *reg8bit[R1(op)] = val;
                }
                break;
            }
            case LP: {
                word arg2 = GETA2_16(op);
                if (IS16(op)) {
                    *reg16bit[R1(op)] = *((word*)&code[arg2]);
                } else {
                    *reg8bit[R1(op)] = code[arg2];
                }
                break;
            }
            case SD: {
                word arg2 = GETA2_16(op);
                if (IS16(op)) {
                    *((word*)&data[arg2]) = *reg16bit[R1(op)];
                } else {
                    data[arg2] = *reg8bit[R1(op)];
                }
                break;
            }
            case SP: {
                word arg2 = GETA2_16(op);
                if (IS16(op)) {
                    *((word*)&code[arg2]) = *reg16bit[R1(op)];
                } else {
                    code[arg2] = *reg8bit[R1(op)];
                }
                break;
            }
            case PUSH: {
                if (IS16(op)) {
                    word val = *reg16bit[R1(op)];
                    word lower = val & 0x00FF; 
                    word higher = (val & 0xFF00) >> 8; 
                    data[rsp] = higher;
                    data[rsp + 1] = lower;
                    rsp += 2;
                } else {
                    byte val = *reg8bit[R1(op)];
                    data[rsp++] = val;
                }
                break;
            }
            case PULL: {
                if (IS16(op)) {
                    word lower = data[rsp - 1];
                    word higher = data[rsp - 2];
                    word word = (higher << 8) | lower;
                    rsp -= 2;
                    *reg16bit[R1(op)] = word;
                } else {
                    *reg8bit[R1(op)] = data[rsp--];
                }
                break;
            }
            case SET: {
                if (IS16(op)) {
                    word arg2 = GETA2_16(op);
                    *reg16bit[R1(op)] = arg2;
                } else {
                    byte arg2 = GETA2_8(op); 
                    *reg8bit[R1(op)] = arg2;
                }
                break;
            }
            case ADD: {
                if (IS16(op)) {
                    word arg2 = GETA2_16(op);
                    word arg1 = *reg16bit[R1(op)];
                    int res = (arg1 + arg2);

                    rfl.carry = res > UINT16_MAX;
                    rfl.zero = res == 0;

                    *reg16bit[R1(op)] = (res & 0xFFFF);
                } else {
                    byte arg2 = GETA2_8(op);
                    byte arg1 = *reg8bit[R1(op)];
                    word res = arg1 + arg2;

                    rfl.carry = res > UINT8_MAX;
                    rfl.zero = (res & 0xFF) == 0;
                    *reg8bit[R1(op)] = (res & 0xFF);
                }
                break;
            }
            case INC: {
                if (IS16(op)) {
                    int res = (*reg16bit[R1(op)] + 1);

                    rfl.carry = res > UINT16_MAX;
                    rfl.zero = res == 0;

                    *reg16bit[R1(op)] = (res & 0xFFFF);
                } else {
                    int res = (*reg8bit[R1(op)] + 1);

                    rfl.carry = res > UINT8_MAX;
                    rfl.zero = res == 0;

                    *reg8bit[R1(op)] = (res & 0x00FF);
                }
                break;
            }
            case SUB: {
                if (IS16(op)) {
                    word arg2 = GETA2_16(op);
                    word arg1 = *reg16bit[R1(op)];
                    int res = arg1 - arg2;

                    rfl.negative = res < 0;
                    rfl.zero = res == 0;
                    *reg16bit[R1(op)] = (res & 0xFFFF);
                } else {
                    byte arg2 = GETA2_8(op);
                    byte arg1 = *reg8bit[R1(op)];
                    int res = arg1 - arg2;

                    rfl.negative = res < 0;
                    rfl.zero = res == 0;
                    *reg8bit[R1(op)] = (res & 0xFF);
                }
                break;
            }
            case DEC: {
                if (IS16(op)) {
                    int res = (*reg16bit[R1(op)] - 1);

                    rfl.negative = res < 0;
                    rfl.zero = res == 0;

                    *reg16bit[R1(op)] = (res & 0xFFFF);
                } else {
                    int res = (*reg8bit[R1(op)] - 1);

                    rfl.negative = res < 0;
                    rfl.zero = res == 0;

                    *reg8bit[R1(op)] = (res & 0x00FF);
                }
                break;
            }
            case CMP: {
                if (IS16(op)) {
                    word arg1 = *reg16bit[R1(op)];
                    word arg2 = GETA2_16(op);
                    int res = arg1 - arg2;

                    rfl.negative = res < 0;
                    rfl.zero = (res & 0xFFFF) == 0;
                } else {
                    byte arg1 = *reg8bit[R1(op)];
                    byte arg2 = GETA2_8(op);
                    int res = arg1 - arg2;

                    rfl.negative = res < 0;
                    rfl.zero = (res & 0xFF) == 0;
                }
                break;
            }
            case MUL: {
                if (IS16(op)) {
                    word arg1 = *reg16bit[R1(op)];
                    word arg2 = *reg16bit[R2(op)];
                    uint64_t res = arg1 * arg2;

                    rfl.carry = res > UINT32_MAX;
                    rfl.zero = res == 0;

                    word res1 = res & 0xFFFF;
                    word res2 = (res & 0xFFFF0000) >> 16;
                    rfl.overflow = (res2 ? 1 : 0);

                    *reg16bit[R1(op)] = res1;
                    *reg16bit[R2(op)] = res2;
                } else {
                    byte arg1 = *reg8bit[R1(op)];
                    byte arg2 = *reg8bit[R2(op)];
                    uint64_t res = arg1 * arg2;

                    if (res > UINT16_MAX) rfl.carry = true;
                    if (res == 0) rfl.zero = true;

                    word res1 = res & 0xFF;
                    word res2 = (res & 0xFF00) >> 8;
                    rfl.overflow = (res2 ? 1 : 0);

                    *reg8bit[R1(op)] = res1;
                    *reg8bit[R2(op)] = res2;
                }
                break;
            }
            case DIV: {
                if (IS16(op)) {
                    word arg1 = *reg16bit[R1(op)];
                    word arg2 = *reg16bit[R2(op)];
                    word res = arg1 / arg2;
                    word rest = arg1 % arg2;
                    
                    rfl.zero = res == 0;
                    rfl.carry = (rest ? 1 : 0);

                    
                    *reg16bit[R2(op)] = rest;
                    *reg16bit[R1(op)] = res;
                } else {
                    byte arg1 = *reg8bit[R1(op)];
                    byte arg2 = *reg8bit[R2(op)];
                    byte res = arg1 / arg2;
                    byte rest = arg1 % arg2;
                    
                    rfl.zero = res == 0;
                    rfl.carry = (rest ? 1 : 0);

                    *reg8bit[R2(op)] = rest;
                    *reg8bit[R1(op)] = res;
                }
                break;
            }
            case NOT: {
                if (IS16(op)) {
                    word res = ~*reg16bit[R1(op)];
                    rfl.zero = res == 0;
                    *reg16bit[R1(op)] = res;
                } else {
                    byte res = ~*reg8bit[R1(op)];
                    rfl.zero = res == 0;
                    *reg16bit[R1(op)] = res;
                }
                break;
            }
            case AND: {
                if (IS16(op)) {
                    word arg2 = GETA2_16(op);
                    word arg1 = *reg16bit[R1(op)];

                    word res = (arg2 & arg1);
                    rfl.zero = res == 0;
                    *reg16bit[R1(op)] = res;
                } else {
                    byte arg2 = GETA2_8(op);
                    byte arg1 = *reg8bit[R1(op)];

                    byte res = (arg2 & arg1);
                    rfl.zero = res == 0;
                    *reg8bit[R1(op)] = res;
                }
                break;
            }
            case OR: {
                if (IS16(op)) {
                    word arg2 = GETA2_16(op);
                    word arg1 = *reg16bit[R1(op)];

                    word res = (arg2 | arg1);
                    rfl.zero = res == 0;
                    *reg16bit[R1(op)] = res;
                } else {
                    byte arg2 = GETA2_8(op);
                    byte arg1 = *reg8bit[R1(op)];

                    byte res = (arg2 | arg1);
                    rfl.zero = res == 0;
                    *reg8bit[R1(op)] = res;
                }
                break;
            }
            case XOR: {
                if (IS16(op)) {
                    word arg2 = GETA2_16(op);
                    word arg1 = *reg16bit[R1(op)];

                    word res = (arg2 ^ arg1);
                    rfl.zero = res == 0;
                    *reg16bit[R1(op)] = res;
                } else {
                    byte arg2 = GETA2_8(op);
                    byte arg1 = *reg8bit[R1(op)];

                    byte res = (arg2 ^ arg1);
                    rfl.zero = res == 0;
                    *reg8bit[R1(op)] = res;
                }
                break;
            }
            case SHL: {
                if (IS16(op)) {
                    word arg1 = *reg16bit[R1(op)];
                    word res = (arg1 << 1);
                    rfl.zero = res == 0;

                    *reg16bit[R1(op)] = res;
                } else {
                    byte arg1 = *reg8bit[R1(op)];
                    byte res = (arg1 << 1);
                    rfl.zero = res == 0;

                    *reg8bit[R1(op)] = res;
                }
                break;              
            }
            case SHR: {
                if (IS16(op)) {
                    word arg1 = *reg16bit[R1(op)];
                    word res = (arg1 >> 1);
                    rfl.zero = res == 0;

                    *reg16bit[R1(op)] = res;
                } else {
                    byte arg1 = *reg8bit[R1(op)];
                    byte res = (arg1 >> 1);
                    rfl.zero = res == 0;

                    *reg8bit[R1(op)] = res;
                }
                break;              
            }
            case JMP: { word addr = GETA1_16(op);  JMP(addr);};
            case JIZ: JMPI(rfl.zero)
            case JNZ: JMPI(!rfl.zero)
            case JIN: JMPI(rfl.negative)
            case JNN: JMPI(!rfl.negative)
            case JIC: JMPI(rfl.carry)
            case JNC: JMPI(!rfl.carry)
            case JIO: JMPI(rfl.overflow)
            case JNO: JMPI(!rfl.overflow)
            case CALL: {
                word target_addr = GETA1_16(op);
                word cur_ptr = rpp;
                word lower = cur_ptr & 0x00FF; 
                word higher = (cur_ptr & 0xFF00) >> 8; 

                data[rsp] = higher;
                data[rsp + 1] = lower;
                rsp += 2;
                JMP(target_addr);
            }
            case RETF: {
                word lower = data[rsp - 1];
                word higher = data[rsp - 2];
                rsp -= 2;
                word address = (higher << 8) | lower;
                JMP(address);
            }
            case CFL: {
                rfl.negative = 0;
                rfl.zero = 0;
                rfl.carry = 0;
                rfl.overflow = 0;
                break;
            }
            case STOP: { exit = true; break;}
            case CZF: { rfl.zero = 0; break; }
            case CNF: { rfl.negative = 0; break; }
            case CCF: { rfl.carry = 0; break; }
            case COF: { rfl.overflow = 0; break; }
            case SZF: { rfl.zero = 1; break; }
            case SNF: { rfl.negative = 1; break; }
            case SCF: { rfl.carry = 1; break; }
            case SOF: { rfl.overflow = 1; break; }
            case WR: {
                if (IS16(op)) {
                    word arg1 = GETA1_16(op);
                    puts(&data[arg1]);
                } else {
                    byte arg1 = GETA1_8(op);
                    putc(arg1, stdout);
                }
                break;
            }
            // clang-format on
        }
    }

    return 0;
}

int main(int argc, char** argv) {
    if (argc < 2 || argc > 4) {
        fprintf(stderr,
                "Usage: %s CODE [DATA]\n"
                "Run CODE with DATA as RAM\n",
                argv[0]);
        return 1;
    }

    byte* code = read_memfile(argv[1], sizeof(byte), SPACE);
    if (!code) {
        return 1;
    }

    byte* data = NULL;
    if (argc == 3) {
        data = read_memfile(argv[2], sizeof(byte), SPACE);
    } else {
        data = calloc(SPACE, sizeof(byte));
    }
    if (!data) {
        return 1;
    }

    return emu_loop(code, data);
}
