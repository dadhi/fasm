format ELF64 executable

HTTP_PORT   equ 6969
MAX_CONN    equ 10; backlog in `listen` syscall
INADDR_ANY  equ 0; bind to all interfaces, see also `in_addr sin_addr`

AF_INET     equ 2; internet domain, see also `sa_family_t sin_family`
SOCK_STREAM equ 1; tcp type
IPPROTO_IP  equ 0; ip protocol

SYS_WRITE   equ 1
SYS_EXIT    equ 60
SYS_SOCKET  equ 41
SYS_ACCEPT  equ 43
SYS_BIND    equ 49
SYS_LISTEN  equ 50
SYS_CLOSE   equ 3

STD_OUT equ 1
STD_ERR equ 2

;; macro to simplify sys call with whatever numebr of args, see https://blog.rchapman.org/posts/Linux_System_Call_Table_for_x86_64/
;; puts the return result into the rax register
macro scall number, a, b, c, d, e, f
{
    mov rax, number
    if ~ a eq ;; if argument is provided, means it is not equal nothing
        mov rdi, a
    end if
    if ~ b eq
        mov rsi, b
    end if
    if ~ c eq
        mov rdx, c
    end if
    if ~ c eq
        mov rdx, c
    end if
    if ~ d eq
        mov r10, c
    end if
    if ~ e eq
        mov r8, c
    end if
    if ~ f eq
        mov r9, c
    end if
    syscall
}

macro print buf
{
    scall SYS_WRITE, STD_OUT, buf, buf#.len
}

macro print_err buf
{
    scall SYS_WRITE, STD_ERR, buf, buf#.len
}

macro exit code
{
    scall SYS_EXIT, code
}

;; int socket(int domain, int type, int protocol);
macro socket_create
{
    scall SYS_SOCKET, AF_INET, SOCK_STREAM, IPPROTO_IP
}

macro close fd
{
    scall SYS_CLOSE, fd
}

;; int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
macro socket_bind fd, sockaddr
{
    mov word [sockaddr.sin_family], AF_INET
    mov ax, HTTP_PORT; ax is the lower 2 bytes of 8 byte rax, btw. eax is the lower 4 bytes of rax
    xchg al, ah; swaps the lower byte of ax (al) with the higher byte of ax (ah)
    mov word [sockaddr.sin_port], ax; expects the port in the reverse networking order
    mov dword [sockaddr.sin_addr], INADDR_ANY

    scall SYS_BIND, fd, sockaddr, sockaddr.len
}

;; int listen(int sockfd, int backlog);
macro socket_listen fd
{
    scall SYS_LISTEN, fd, MAX_CONN
}

;; int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
macro socket_accept fd, sockaddr
{
    scall SYS_ACCEPT, fd, sockaddr.sin_family, sockaddr.len
}

;; struct sockaddr_in {
;; 	sa_family_t sin_family;
;; 	in_port_t sin_port; 
;; 	struct in_addr sin_addr;
;; 	uint8_t sin_zero[8];
;; };
struc define_sockaddr_fields
{
    .sin_family dw 0
    .sin_port   dw 0
    .sin_addr   dd 0
    .sin_zero   dq 0
    .len = $ - .sin_family
}

struc db_msg [args]
{
common
    . db args
    .len = $ - .
}

segment readable executable
entry main
main:
    print start_msg

    print socket_create_msg
    socket_create
    cmp rax, 0
    jl .error; socket returns negative error values, e.g. -1 = EPROTONOSUPPORT, and the 0 or positive value means OK
    mov qword [socket_fd], rax; 32 bit alias of rax where create socket puts the result

    print socket_bind_msg
    socket_bind [socket_fd], sockaddr
    cmp rax, 0
    jl .error

    print socket_listen_msg
    socket_listen [socket_fd]
    cmp rax, 0
    jl .error

; todo: @wip
.request_loop:
    print socket_accept_msg
    socket_accept [socket_fd], sockaddr
    cmp rax, 0
    jl .error

    mov qword [conn_fd], rax

.error:
    print_err err_msg
    close [socket_fd]
    exit 1

segment readable writeable
;; d - stands for the define the memory with value, 
;; there are also corresponding rb, rw, rd, rq to reserve the uninitialized amount of memory, `hey rq 2` is reserve 2 x 8 bytes
;; db - byte
;; dw - word - 2 bytes - 16 bits
;; dd - double word - 4 bytes - 32 bits
;; dq - quadruple bytes - 8 bytes - 64 bits


socket_fd dq -1; put here the result of creating the token
conn_fd   dq -1; put here the result of accepting the connection

sockaddr define_sockaddr_fields

start_msg db_msg "Start the Weaver", 10

socket_create_msg db_msg "1. Create socket...", 10

socket_bind_msg db_msg "2. Bind socket...", 10

socket_listen_msg db_msg "3. Listen socket...", 10

socket_accept_msg db_msg "4. Accept connection...", 10

ok_msg db_msg "Done.", 10

err_msg db_msg "ERROR!", 10
