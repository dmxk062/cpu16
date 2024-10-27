.section code
; initialize stack to a sane value on startup, so calling functions doesn't override memory
STACK_START = 0x0800
ROM_START = 0x8000

.org 0x0000
ld      %r3l,   %r0
start:
    set     %rsp,   STACK_START
    set     %r0,    msg
    call    puts
    call    show_ascii
exit:
    set     %r0,    goobye_msg
    call    puts
    stop

show_ascii:
    set     %r0l,   'A'
show_ascii_loop:
    wr      %r0l
    cmp     %r0l,   'z'
    jnn     show_ascii_done    
    add     %r0l,   1
    jmp     show_ascii_loop
show_ascii_done:
    wr      '\n'
    retf



puts:
    ld      %r3l,   %r0
    cmp     %r3l,   0
    jiz     puts_done
    wr      %r3l
    add     %r0,    1
    jmp     puts
puts_done:
    retf

.section data
.org ROM_START
msg:
    .zstring "Hello World!\n"
goobye_msg:
    .zstring "This is it for now...\n"
