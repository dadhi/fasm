format ELF64 executable

sys_write   equ 1
sys_exit    equ 60
sys_socket  equ 41
sys_bind    equ 49
sys_listen  equ 50
sys_close   equ 3

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

INADDR_ANY  equ 0; bind to all interfaces

macro socket_create
{
    mov rax, sys_socket
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    mov rdx, IPPROTO_IP
    syscall
}

macro socket_close fd
{
    mov rax, sys_close
    mov rdi, fd
    syscall
}

; todo: @simplify convert to 1 macro for 3 param syscalls
macro socket_bind fd, family, sockaddr_len
{
    mov rax, sys_bind
    mov rdi, fd
    mov rsi, family
    mov rdx, sockaddr_len
    syscall
}

MAX_CONN equ 10
macro socket_listen fd, max_conn
{
    mov rax, sys_listen
    mov rdi, fd
    mov rsi, max_conn
    syscall
}


segment readable executable
entry main
main:
    write std_out, start_msg, start_msg_len
    write std_out, socket_create_msg, socket_create_msg_len
    socket_create
    cmp rax, 0
    jl error ; socket returns negative error values, e.g. -1 = EPROTONOSUPPORT, and the 0 or positive value means OK
    mov qword [socket_fd], rax ; 32 bit alias of rax where create socket puts the result

    ; assign IP, PORT
    write std_out, socket_bind_msg, socket_bind_msg_len
    mov word  [sockaddr.sin_family], AF_INET
    mov word  [sockaddr.sin_port], 14619  ; 6969 in the reverse order, in hex 0x1b39 then reversing the bytes 0x391b gives us 14619
    mov dword [sockaddr.sin_addr], INADDR_ANY
    socket_bind [socket_fd], sockaddr.sin_family, sockaddr_len
    cmp rax, 0
    jl error

    ; listen for connection
    write std_out, socket_listen_msg, socket_listen_msg_len
    socket_listen [socket_fd], MAX_CONN
    cmp rax, 0
    jl error

    write std_out, ok_msg, ok_msg_len
    socket_close [socket_fd]
    exit 0

error:
    write std_err, err_msg, err_msg_len
    socket_close [socket_fd]
    exit 1

segment readable writeable

; db - byte
; dw - word - 2 bytes - 16 bits
; dd - double word - 4 bytes - 32 bits
; dq - quadruple bytes - 8 bytes - 64 bits

socket_fd dq 0 ; put here the result of creating the token

; struct sockaddr_in {
; 	sa_family_t sin_family;
; 	in_port_t sin_port; 
; 	struct in_addr sin_addr;
; 	uint8_t sin_zero[8];
; };
sockaddr.sin_family  dw 0
sockaddr.sin_port    dw 0
sockaddr.sin_addr    dd 0
sockaddr.sin_zero    dq 0
sockaddr_len         = $ - sockaddr.sin_family

start_msg db "Start weaver", 10
start_msg_len = $ - start_msg

socket_create_msg db "Create socket...", 10
socket_create_msg_len = $ - socket_create_msg

socket_bind_msg db "Bind socket...", 10
socket_bind_msg_len = $ - socket_bind_msg

socket_listen_msg db "Listen socket...", 10
socket_listen_msg_len = $ - socket_listen_msg

ok_msg db "OK!", 10
ok_msg_len = $ - ok_msg

err_msg db "ERROR!", 10
err_msg_len = $ - err_msg
