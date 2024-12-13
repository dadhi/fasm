format ELF64 executable

sys_write   equ 1
sys_exit    equ 60
sys_socket  equ 41
sys_bind    equ 49
sys_listen  equ 50
sys_close   equ 3

std_out equ 1
std_err equ 2

;; puts the return result into the rax register
macro syscall3 number, a, b, c
{
    mov rax, number
    mov rdi, a
    mov rsi, b
    mov rdx, c
    syscall
}

macro write fd, buf, len
{
    syscall3 sys_write, fd, buf, len
}

macro exit code
{
    mov rax, sys_exit
    mov rdi, code
    syscall
}

MAX_CONN    equ 10; backlog in `listen` syscall
INADDR_ANY  equ 0; bind to all interfaces, see also `in_addr sin_addr`

AF_INET     equ 2; internet domain, see also `sa_family_t sin_family`
SOCK_STREAM equ 1; tcp type
IPPROTO_IP  equ 0; ip protocol

;; int socket(int domain, int type, int protocol);
macro socket_create
{
    syscall3 sys_socket, AF_INET, SOCK_STREAM, IPPROTO_IP
}

macro socket_close fd
{
    mov rax, sys_close
    mov rdi, fd
    syscall
}

;; int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
macro socket_bind fd, family, sockaddr_len
{
    syscall3 sys_bind, fd, family, sockaddr_len
}

;; int listen(int sockfd, int backlog);
macro socket_listen fd
{
    mov rax, sys_listen
    mov rdi, fd
    mov rsi, MAX_CONN
    syscall
}

;; struct sockaddr_in {
;; 	sa_family_t sin_family;
;; 	in_port_t sin_port; 
;; 	struct in_addr sin_addr;
;; 	uint8_t sin_zero[8];
;; };
struc sockaddr_in
{
    .sin_family dw 0
    .sin_port   dw 0
    .sin_addr   dd 0
    .sin_zero   dq 0
}

segment readable executable
entry main
main:
    write std_out, start_msg, start_msg_len
    write std_out, socket_create_msg, socket_create_msg_len

    socket_create
    cmp rax, 0
    jl error; socket returns negative error values, e.g. -1 = EPROTONOSUPPORT, and the 0 or positive value means OK
    mov qword [socket_fd], rax; 32 bit alias of rax where create socket puts the result

    ;; assign IP, PORT
    write std_out, socket_bind_msg, socket_bind_msg_len
    mov word  [sockaddr.sin_family], AF_INET
    mov word  [sockaddr.sin_port], 14619; 6969 in the reverse order, in hex 0x1b39 then reversing the bytes 0x391b gives us 14619
    mov dword [sockaddr.sin_addr], INADDR_ANY
    socket_bind [socket_fd], sockaddr.sin_family, sockaddr_len
    cmp rax, 0
    jl error

    ;; listen for the connection
    write std_out, socket_listen_msg, socket_listen_msg_len
    socket_listen [socket_fd]
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
;; db - byte
;; dw - word - 2 bytes - 16 bits
;; dd - double word - 4 bytes - 32 bits
;; dq - quadruple bytes - 8 bytes - 64 bits

socket_fd dq 0 ; put here the result of creating the token

sockaddr sockaddr_in
sockaddr_len = $ - sockaddr.sin_family

start_msg db "Start the Weaver", 10
start_msg_len = $ - start_msg

socket_create_msg db "1. Create socket...", 10
socket_create_msg_len = $ - socket_create_msg

socket_bind_msg db "2. Bind socket...", 10
socket_bind_msg_len = $ - socket_bind_msg

socket_listen_msg db "3. Listen socket...", 10
socket_listen_msg_len = $ - socket_listen_msg

ok_msg db "Done.", 10
ok_msg_len = $ - ok_msg

err_msg db "ERROR!", 10
err_msg_len = $ - err_msg
