STACK_START = 0x0800
RODATA_START = 0x8000
PROGRAM_START = 0x1000

.section code
.org 0x0000
start:
    set     %rsp,       STACK_START
    set     %r0,        10000
    call    fizzbuzz
exit:
    stop


.org PROGRAM_START

fizzbuzz:
    set     %r1,        1
    set     %r3,        %r0
fizzbuzz_loop:
    set     %r0,        %r1
    call    numtostr
    call    puts
    wr      ' '

    push    %r3

    push    %r1
    set     %r2,        3
    div     %r1,        %r2
    jic     skip1
    set     %r0,        fizz
    call    puts

skip1:
    pull    %r1

    push    %r1
    set     %r2,        5
    div     %r1,        %r2
    jic     skip2
    set     %r0,        buzz
    call    puts

skip2:
    pull    %r1
    pull    %r3
    wr      '\n'

    add     %r1,        1
    cmp     %r3,        %r1
    jnn     fizzbuzz_loop
    jmp     fizzbuzz_done


fizzbuzz_done:
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
    sub     %r3,        1
    cmp     %r0,        0
    jnz     numtostr_loop

numtostr_done:
    ; return starting address of numeric string
    set     %r0,        %r3
    add     %r0,        1

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
    add     %r0,    1
    jmp     puts_loop

puts_done:
    pull    %r3
    retf

.section data
.org RODATA_START
fizz:
    .zstring "fizz"
buzz:
    .zstring "buzz"
numbuf:
    .fill   8, 0
numbuf_end:
    .fill   1, 0
