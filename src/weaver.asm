format ELF64 executable

sys_write   equ 1
sys_exit    equ 60
sys_socket  equ 41

std_out equ 1
std_err equ 2

macro write fd, buf, len
{
    mov rax, sys_write
    mov rdi, fd
    mov rsi, buf
    mov rdx, len
    syscall
}

macro exit code
{
    mov rax, sys_exit
    mov rdi, code
    syscall
}

AF_INET     equ 2; domain - internet domain
SOCK_STREAM equ 1; type   - tcp/ip type
macro create_socket
{
    mov rax, sys_socket
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    mov rdx, 0
    syscall
}

segment readable executable
entry main
main:
    write std_out, start_msg, start_msg_len
    write std_out, create_socket_msg, create_socket_msg_len
    create_socket
    write std_out, ok_msg, ok_msg_len
    exit 0

segment readable writeable
start_msg db "Start weaver", 10
start_msg_len = $ - start_msg

create_socket_msg db "Create socket...", 10
create_socket_msg_len = $ - create_socket_msg

ok_msg db "OK!", 10
ok_msg_len = $ - ok_msg
