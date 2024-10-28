STACK_START = 0x0800
RODATA_START = 0xF000
BUFFER_START = 0x8000
PROGRAM_START = 0x1000

.section code
.org 0x0000
start:
    set     %rsp,       STACK_START
    set     %r0,        input_buffer
    set     %r1,        1024
    call    readline
    set     %r0,        input_buffer
    call    print
exit:
    stop


.org PROGRAM_START
readline:
    ; buffer in r0
    ; max length in r1
    ; returns count read in r0
    ; r1l contains our current byte
    ; r2 contains the base address
    push    %r2
    set     %r2,        %r0
    ; r3 contains the precomputed max address
    push    %r3
    set     %r3,        %r2
    add     %r3,        %r1
    push    %r1
readline_loop:
    rd      %r1l
    cmp     %r0,        %r3
    jiz     readline_done
    sd      %r1l,       %r0
    cmp     %r1l,       '\n'
    jiz     readline_done
    inc     %r0
    jmp     readline_loop

readline_done:
    sub     %r0,        %r2

    pull    %r1
    pull    %r3
    pull    %r2
    retf

print:
    ; buffer in r0
    ; max length in r1
    ; precompute largest buffer address
    add     %r1,    %r0
    ; %r2l contains our current byte
    push    %r2l
print_loop:
    cmp     %r0,    %r1
    jiz     print_done
    ld      %r2l,   %r0
    wr      %r2l
    inc     %r0
    jmp     print_loop

print_done:
    pull    %r2l
    retf


.section data
.org RODATA_START
.org BUFFER_START
input_buffer:
    .fill   1024,    0
accumulator:
    .word   0
