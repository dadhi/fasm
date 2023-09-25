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

AF_INET     equ 2; internet domain
SOCK_STREAM equ 1; tcp type
IPPROTO_IP  equ 0; ip protocol
macro create_socket
{
    mov rax, sys_socket
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    mov rdx, IPPROTO_IP
    syscall
}

segment readable executable
entry main
main:
    write std_out, start_msg, start_msg_len
    write std_out, create_socket_msg, create_socket_msg_len
    create_socket
    cmp rax, 0
    jl error ; socket returns negative error values, e.g. -1 = EPROTONOSUPPORT, and the 0 or positive value means OK
    mov dword [socket_fd], eax ; 32 bit alias of rax where create socket puts the result
    write std_out, ok_msg, ok_msg_len
    exit 0

error:
    write std_err, err_msg, err_msg_len
    exit 1

segment readable writeable

; db - byte
; dw - word - 2 bytes - 16 bits
; dd - double word - 4 bytes - 32 bits
; dq - quadruple bytes - 8 bytes - 64 bits

socket_fd dd 0 ; put here the result of creating the token 

start_msg db "Start weaver", 10
start_msg_len = $ - start_msg

create_socket_msg db "Create socket...", 10
create_socket_msg_len = $ - create_socket_msg

ok_msg db "OK!", 10
ok_msg_len = $ - ok_msg

err_msg db "ERROR!", 10
err_msg_len = $ - err_msg