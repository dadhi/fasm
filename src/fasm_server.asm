format ELF64 executable

HTTP_PORT   equ 6969
MAX_CONN    equ 10; backlog in `listen` syscall
INADDR_ANY  equ 0; bind to all interfaces, see also `in_addr sin_addr`

AF_INET     equ 2; internet domain, see also `sa_family_t sin_family`
SOCK_STREAM equ 1; tcp type
IPPROTO_IP  equ 0; ip protocol


sys_write   equ 1
sys_exit    equ 60
sys_socket  equ 41
sys_accept  equ 43
sys_bind    equ 49
sys_listen  equ 50
sys_close   equ 3

std_out equ 1
std_err equ 2

;; puts the return result into the rax register
macro syscall1 number, a
{
    mov rax, number
    mov rdi, a
    syscall
}

macro syscall2 number, a, b
{
    mov rax, number
    mov rdi, a
    mov rsi, b
    syscall
}

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
    syscall1 sys_exit, code
}

;; int socket(int domain, int type, int protocol);
macro socket_create
{
    syscall3 sys_socket, AF_INET, SOCK_STREAM, IPPROTO_IP
}

macro close fd
{
    syscall1 sys_close, fd
}

;; int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
macro socket_bind fd, sockaddr, sockaddr_len
{
    syscall3 sys_bind, fd, sockaddr, sockaddr_len
}

;; int listen(int sockfd, int backlog);
macro socket_listen fd
{
    syscall2 sys_listen, fd, MAX_CONN
}

;; int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
macro socket_accept fd, sockaddr, sockaddr_len
{
    syscall3 sys_accept, fd, sockaddr, sockaddr_len
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
    jl .error; socket returns negative error values, e.g. -1 = EPROTONOSUPPORT, and the 0 or positive value means OK
    mov qword [socket_fd], rax; 32 bit alias of rax where create socket puts the result

    ;; assign IP, PORT
    write std_out, socket_bind_msg, socket_bind_msg_len
    mov word  [sockaddr.sin_family], AF_INET
    mov ax, HTTP_PORT; ax is the lower 2 bytes of 8 byte rax, btw. eax is the lower 4 bytes of rax
    xchg al, ah; swaps the lower byte of ax (al) with the higher byte of ax (ah)
    mov word  [sockaddr.sin_port], ax; expects the port in the reverse networking order
    mov dword [sockaddr.sin_addr], INADDR_ANY
    socket_bind [socket_fd], sockaddr.sin_family, sockaddr_len
    cmp rax, 0
    jl .error

    ;; listen for the connection
    write std_out, socket_listen_msg, socket_listen_msg_len
    socket_listen [socket_fd]
    cmp rax, 0
    jl .error

; todo: @wip
.request_loop:
    write std_out, socket_accept_msg, socket_accept_msg_len
    socket_accept [socket_fd], sockaddr.sin_family, sockaddr_len
    cmp rax, 0
    jl .error

    mov qword [conn_fd], rax

.error:
    write std_err, err_msg, err_msg_len
    close [socket_fd]
    exit 1

segment readable writeable
;; db - byte
;; dw - word - 2 bytes - 16 bits
;; dd - double word - 4 bytes - 32 bits
;; dq - quadruple bytes - 8 bytes - 64 bits

socket_fd dq -1; put here the result of creating the token
conn_fd   dq -1; put here the result of accepting the connection

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

socket_accept_msg db "4. Accept connection...", 10
socket_accept_msg_len = $ - socket_accept_msg

ok_msg db "Done.", 10
ok_msg_len = $ - ok_msg

err_msg db "ERROR!", 10
err_msg_len = $ - err_msg
