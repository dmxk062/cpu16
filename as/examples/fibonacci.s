STACK_START = 0x0800
RODATA_START = 0x8000
PROGRAM_START = 0x1000

.section code
.org 0x0000
start:
    set     %rsp,       STACK_START
    set     %r0,        0xFFFE
    call    fibonacci
exit:
    stop


.org PROGRAM_START
fibonacci:
    set     %r1,        1    
    set     %r2,        0    
    set     %r3,        0
fibonacci_loop:
    set     %r0,        %r2
    call    numtostr
    call    puts
    set     %r3,        %r2
    add     %r3,        %r1
    jio     fibonacci_done
    set     %r2,        %r1
    set     %r1,        %r3
    jmp     fibonacci_loop
fibonacci_done:
    retf


numtostr:
    push    %r3
    push    %r1
    set     %r3,        numbuf_end

numtostr_loop:
    set     %r1,        10
    div     %r0,        %r1
    add     %r1,        '0'
    sd      %r1l,       %r3
    dec     %r3
    cmp     %r0,        0
    jnz     numtostr_loop

numtostr_done:
    ; return starting address of numeric string
    set     %r0,        %r3
    inc     %r0

    pull    %r1
    pull    %r3
    retf


puts:
    push    %r3

puts_loop:
    ld      %r3l,   %r0
    cmp     %r3l,   0
    jiz     puts_done
    wr      %r3l
    inc     %r0
    jmp     puts_loop

puts_done:
    pull    %r3
    wr      '\n'
    retf

.section data
.org RODATA_START
numbuf:
    .fill   8, 0
numbuf_end:
    .byte   0
