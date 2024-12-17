format ELF64 executable

sys_write   equ 1
sys_exit    equ 60
sys_socket  equ 41
sys_bind    equ 49
sys_listen  equ 50
sys_accept  equ 43
sys_read    equ 0
sys_close   equ 3

std_out equ 1
std_err equ 2

HTTP_PORT        equ 6969
MAX_CONN    equ 10
AF_INET     equ 2
SOCK_STREAM equ 1
IPPROTO_IP  equ 0
INADDR_ANY  equ 0

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

macro socket_bind fd, sockaddr, sockaddr_len
{
    mov rax, sys_bind
    mov rdi, fd
    mov rsi, sockaddr
    mov rdx, sockaddr_len
    syscall
}

macro socket_listen fd, max_conn
{
    mov rax, sys_listen
    mov rdi, fd
    mov rsi, max_conn
    syscall
}

macro socket_accept fd
{
    mov rax, sys_accept
    mov rdi, fd
    xor rsi, rsi
    xor rdx, rdx
    syscall
}

macro socket_read fd, buf, len
{
    mov rax, sys_read
    mov rdi, fd
    mov rsi, buf
    mov rdx, len
    syscall
}

segment readable executable
entry main
main:
    write std_out, start_msg, start_msg_len
    socket_create
    cmp rax, 0                  ; compare the result of socket creation with 0
    jl error                    ; jump to error if the result is less than 0
    mov qword [socket_fd], rax  ; move the value in the rax register into the memory location labeled socket_fd

    mov word [sockaddr.sin_family], AF_INET
    mov ax, HTTP_PORT
    xchg al, ah                 ; reverse the bytes in the ax register, e.g. 6969 -> 14619, to match network byte order
    mov word [sockaddr.sin_port], ax
    mov dword [sockaddr.sin_addr], INADDR_ANY
    socket_bind [socket_fd], sockaddr, sockaddr_len
    cmp rax, 0
    jl error

    socket_listen [socket_fd], MAX_CONN
    cmp rax, 0
    jl error

    write std_out, listen_msg, listen_msg_len

request_loop:
    socket_accept [socket_fd]
    cmp rax, 0
    jl request_loop
    mov qword [client_fd], rax

    sub rsp, 1024                      ; This subtracts 1024 bytes from the stack pointer (rsp), effectively reserving space on the stack for the buffer to store the client's request
    socket_read [client_fd], rsp, 1024 ; Read up to 1024 bytes from the client socket into the buffer to process the request, `rax` will contain the number of bytes read

    mov rdx, rax                       ; rax is used to set the std_out as output, so save its value to rdx, to avoid the overwrite
    write std_out, rsp, rdx            ; Use the write macro to print the request content

    add rsp, 1024                      ; Deallocate the buffer from the stack to clean up after reading

    ; ; Check for /urmom URL
    ; mov rsi, rsp                       ; Set rsi to the buffer address to search within the request
    ; mov rdi, mom_url                   ; Set rdi to the mom_url address to search for this specific URL
    ; call _strstr                       ; todo: @libc
    ; test rax, rax                      ; Test if the result is NULL (0) to check if the URL was found
    ; jnz load_mom_response              ; If not NULL, jump to load_mom_response to send the appropriate response

    ; ; Check for /urdad URL
    ; mov rsi, rsp
    ; mov rdi, dad_url
    ; call strstr
    ; test rax, rax
    ; jnz load_dad_response

    jmp load_default_response

; load_mom_response:
;     mov rsi, mom_response
;     mov rdx, mom_response_len
;     jmp send_response

; load_dad_response:
;     mov rsi, dad_response
;     mov rdx, dad_response_len
;     jmp send_response

load_default_response:
    mov rsi, default_response
    mov rdx, default_response_len

send_response:
    mov rdi, [client_fd]
    call write
    socket_close [client_fd]
    write std_out, close_msg, close_msg_len
    jmp request_loop

error:
    write std_err, error_msg, error_msg_len
    socket_close [socket_fd]
    exit 1

segment readable writeable

socket_fd dq 0
client_fd dq 0

sockaddr.sin_family  dw 0
sockaddr.sin_port    dw 0
sockaddr.sin_addr    dd 0
sockaddr.sin_zero    dq 0
sockaddr_len         = $ - sockaddr.sin_family

start_msg db "Server starting on port ", HTTP_PORT, "...", 10
start_msg_len = $ - start_msg

listen_msg db "Server is listening...", 10
listen_msg_len = $ - listen_msg

close_msg db "Connection closed", 10
close_msg_len = $ - close_msg

error_msg db "Error occurred!", 10
error_msg_len = $ - error_msg

mom_response db "HTTP/1.1 413 Entity Too Large\r\nContent-Type: text/plain\r\nContent-Length: 43\r\n\r\nHoney, mama is busy right now. Ask your dad.", 10
mom_response_len = $ - mom_response

dad_response db "HTTP/1.1 410 Gone\r\nContent-Type: text/plain\r\nContent-Length: 36\r\n\r\nI'll buy some milk and get back soon", 10
dad_response_len = $ - dad_response

default_response db "HTTP/1.1 405 Method Not Allowed\r\nContent-Type: text/plain\r\nContent-Length: 29\r\nAllow: GET\r\n\r\nMethod is not allowed for URL", 10
default_response_len = $ - default_response

mom_url db "GET /urmom", 0
dad_url db "GET /urdad", 0
