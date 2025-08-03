global ok_header
global ok_header_len
global not_found_header
global not_found_header_len
global content_length
global content_length_len
global content_type
global content_type_len
global err_header
global socketaddr_ipv4

global header_buffer
global request_data
global file_data
global file_data_length
global header_len

global sockaddr_ipv4
global exit_socket
global exit_bind
global exit_listen
global exit_accept
global exit_read

; Read only data
section .rodata
    ok_header db "HTTP/1.1 200 OK", 0xd, 0xa ; 0xd = \r, 0xa = \n
    ok_header_len equ $ - ok_header
    
    not_found_header db "HTTP/1.1 404 Not Found", 0xd, 0xa
    not_found_header_len equ $ - not_found_header

    content_length db "Content-Length: "
    content_length_len equ $ - content_length

    content_type db "Content-Type: text/plain", 0xd, 0xa, 0xd, 0xa
    content_type_len equ $ - content_type

    err_header db "HTTP/1.1 404 Not Found", 0xd, 0xa 

sockaddr_ipv4:
    dw  0x0002      ; family
    db  0x1F, 0x90  ; port
    dd  0x00000000  ; addr   
    times 8 db 0   
    
    exit_socket db "Failed creating socket", 0xA, 0x0
    exit_bind db "Failed binding to address", 0xA, 0x0
    exit_listen db "Failed listening on socket", 0xA, 0x0
    exit_accept db "Failed accepting connection on socket", 0xA, 0x0
    exit_read db "Failed reading on handle", 0xA, 0x0


; Buffers


section .bss
header_buffer: resb 100

request_data: resb 1024
file_data: resb 4096

file_data_length equ 4096
header_len equ 100
