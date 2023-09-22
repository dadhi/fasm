format ELF64 executable

std_out = 1
SYS_write = 1
SYS_exit = 60

macro write fd, buf, len
{
    mov rax, SYS_write
    mov rdi, fd
    mov rsi, buf
    mov rdx, len
    syscall
}

macro exit code
{
    mov rax, SYS_exit
    mov rdi, code
    syscall
}

segment readable executable
entry main
main:
repeat 6
    write std_out, msg, msg_len
end repeat
    exit 0

segment readable writeable
msg db "Hello, Sailor!", 10
msg_len = $ - msg
