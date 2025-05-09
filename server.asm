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
    err_header_len equ $ - err_header

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

section .bss
header_buffer: resb 100

request_data: resb 1024
file_data: resb 4096

file_data_length equ 4096
header_len equ 100

section .text
    global _start

_start:
    ; Load the state table
    
    ; Fetch handle to socket
    call socket ; -> handle

    ; Load socket error message
    mov rsi, exit_socket
    call unwrap

    ; Copy socket handle to bind
    mov rdi, rax
    call bind

    ; Load bind error message
    mov rsi, exit_bind
    call unwrap
   
    ; Copy socket handle for listen
    call listen

    ; Load listen error message
    mov rsi, exit_listen
    call unwrap

    ; Now that we have done the setup, this is the main "meat" of this program.
    push rdi ; Top of stack now holds the SOCKET handle

    main_loop:   
    pop rdi
    push rdi

    xor rsi, rsi ; We don't care about the client's address, so we push a null pointer
    xor rdx, rdx ; and a null length.
    call accept

    ; Load accept error message
    mov rsi, exit_accept
    call unwrap
    mov rbx, rax            ; Store the connection handle in RBX for the duration of the loop
    
    ;push rax ; Save connection handle

    mov rdi, rax            ; Load connection handle
    mov rsi, request_data   ; Load the request_data buffer to rsi
    mov rdx, 256            ; Length of the buffer (ish)
    call read               ; Read the user request

    ; Load read error message
    mov rsi, exit_read
    call unwrap
    
    ; Return the client request data 
    mov rdi, rsi
    ; Print the request
    call println

    ; Find the offset of the requested filepath by searching for the first '/'
    mov rsi, 0x2F ; '/'
    call str_split
    ; Rax contains the length

    ; Move to the start of the filepath
    inc rax                 ; + 1 to skip past the first /
    add rdi, rax            ; Offset the line buffer by the filepath, so the pointer now points to the actual file's name.

    ; Search for the end of the filepath, the first space should be enough.
    mov rsi, 0x20 ; ' '
    call str_split

    ; Rax contains the requested filename's end pointer
    ; We can terminate the implicit string adding a null:
    mov byte [rdi + rax], 0
    
    ; rdi contains a pointer to the implicit filename string now
    ; We offset header_len from the file_data in order to carve out empty space in front of the return buffer.
    ; This way we ensure we always have space for the header.
    mov rsi, file_data + header_len
    mov rdx, file_data_length - header_len
    call read_file

    ; 404
    cmp rax, -2
    je return_404
    
    ; Other errors
    cmp rax, 0
    jl panic

    jmp return_200

    return_200:
    ; Write the HTTP OK header to the header buffer
    mov rdi, header_buffer
    mov rsi, ok_header
    mov rdx, ok_header_len
    call str_cp
    
    ; Write the Content-Length header preface into the return buffer
    mov rsi, content_length
    mov rdx, content_length_len
    call str_cp

    ; Save header pointer
    push rdi

    ; itoa the read file's length to the header, this will write it directly
    mov rdi, rax ; File length
    pop rsi ; Pop offset
    mov rdx, header_len - ok_header_len - content_length_len  - 2
    call itoa

    ; Now rax contains the length of the read bytes as a string, we can offset by it
    ; and add the required carriage return.
    mov word [rsi + rax], 0x0a0d ; \r\n

    ; Finalize the header by adding the content-type header
    lea rdi, [rsi + rax + 2] ; Offset by the written bytes
    mov rsi, content_type
    mov rdx, content_type_len
    call str_cp

    ; Calculate the length of the full header portion
    mov rdi, header_buffer
    call str_len
   
    ; The first 100 bytes of the file_data are reserved for the header
    ; In order to find the right offset to write the header at, we have to calculate
    ; carved space - length = offset to write at
    mov rcx, header_len
    sub rcx, rax
    lea rdi, [file_data + rcx]

    ; Copy the finalized header to the return buffer
    mov rsi, header_buffer
    mov rdx, rax
    call str_cp
    sub rdi, rax

    ; Print the return data for good measure
    call println

    mov rsi, rdi
    mov rdi, rbx
    call write
    
    jmp cleanup
    
    return_404:

    ; Write the HTTP OK header to the header buffer
    mov rdi, header_buffer
    mov rsi, not_found_header
    mov rdx, not_found_header_len
    call str_cp
    
    ; Write the Content-Length header preface into the return buffer
    mov rsi, content_length
    mov rdx, content_length_len
    call str_cp

    mov byte [rdi], '0' ; Zero length
    mov word [rdi + 1], 0x0a0d ; \r\n

    mov rdi, header_buffer
    call println

    mov rsi, rdi
    mov rdi, rbx
    call write

    jmp cleanup

    ; RDI: connection handle
    cleanup:

    ; Let's close the connection handle
    call close

    ; Overwrite the return buffer with nulls
    xor rax, rax
    mov rdi, file_data
    mov rcx, 512
    rep stosq

    ; Overwrite header buffer with nulls
    xor rax, rax
    mov rdi, header_buffer
    mov rcx, 100
    rep stosb

    ; We jump back up
    jmp main_loop

;          RDI
; fn close(handle: handle)
close:
    mov rax, 3
    syscall

; fn socket() -> handle
socket:
    mov rax, 0x29   ; socket syscall ID
    mov rdi, 2      ; AF_INET, ipv4
    mov rsi, 1      ; SOCK_STREAM
    mov rdx, 6      ; TCP
    syscall
    ret

;         RDI
; fn bind(socket_handle: handle) -> status
bind:
    mov rax, 0x31                ; bind syscall id
    lea rsi, [rel sockaddr_ipv4] ; Address
    mov edx, 16                  ; Length of addr struct
    syscall
    ret

;           RDI
; fn listen(socket_handle: handle) -> status
listen:
    mov rax, 0x32               ; listen syscall id
    mov rsi, 0x5                ; Backlog
    syscall
    ret

;           RDI,                   RSI                        RDX
; fn accept(socket_handle: handle, client_info_buffer: &[u8], client_info_buffer_len: usize) -> handle, 
accept:
    ; Prelude for setting up the arguments
    mov r10, 0
    mov rax, 0x2b       ; Syscall id for accept
    syscall
    ret

; rdi: handle, rsi: buff
write:
    push rdi
    mov rdi, rsi
    call str_len
    pop rdi
    mov rdx, rax
    mov rax, 0x1
    syscall
    ret

;      rdi            rsi            rdx
; recv(handle: usize, buffer: &[u8], size: usize) -> status
read:
    mov rax, 0
    syscall
    ret

;           rdi         rsi            rdx
; read_file(path: &str, buffer: &[u8], buffer_len: usize) -> status
read_file:
    push rsi
    push rdx
    
    mov rsi, rdi    ; filepath
    mov rax, 257    ; openat
    mov rdi, -100   ; AT_FDCWD
    mov rdx, 0
    mov r10, 0
    syscall
    
    pop rdx
    pop rsi
    
    ; We should get proper error handling here
    cmp rax, -2     ; File does not exist
    jne read_data
    ret

    read_data:
    mov rdi, rax
    call read
    push rax
    call close
    pop rax
    ret

;      RDI             RSI            RDX
; itoa(numbers: usize, buffer: &[u8], buffer_len: usize) -> status
itoa:
    mov r9, 10
    mov r10, rdx  ; length
    lea r11, [rsi + rdx] ; Buffer's final byte
    mov rax, rdi ; Lower half, so the actual number
    
    xor rcx, rcx ; Empty out counter

    itoa_loop:
    ; Empty out top half of number
    xor rdx, rdx    
    div r9
                ; RAX -> quotient
                ; RDX -> Remainder
    add rdx, "0"; Turn remainder to ascii

    mov [r11], byte dl ; Move ascii to the buffer's end position

    inc rcx
    cmp rax, 0  ; If we are at the end, move to the exit loop
    je itoa_exit
    dec r11     ; Move back in buffer so we get the numbers in the correct position

    cmp rcx, r10 ; Check if we have hit the length of the buffer but are not done
    je itoa_error

    jmp itoa_loop


    itoa_exit:
    ; Let's shift the buffer to be at the correct location.
    ; r11 holds the first actual byte, rcx holds the length and
    ; rsi holds the buffer start.
    ; mov [rsi + (offset)], [r11, offset] rcx many times
    ; Move the 
    push rsi
    mov rdi, rsi
    mov rsi, r11
    mov rdx, rcx
    call str_cp
    
    pop rsi ; return buffer
    mov rax, rdx ; buffer length
    ret

    itoa_error:
    mov rax, -1
    ret

;        RDI          RSI           RDX
; str_cp(base: &[u8], addon: &[u8], length: usize) 
str_cp:
    cld
    mov rcx, rdx
    rep movsb
    ret

;              RDI              RSI
; fn str_split(input_str: &str, denominator: u8) -> offset
str_split:
    ; First fetch the length of the string so we don't read too much
    call str_len
    ; Copy it to rdx
    mov rdx, rax
    ; Null out rcx from str_len
    xor rcx, rcx

    str_split_loop:
    mov al, byte [rdi + rcx]
    cmp al, sil
    je str_split_done

    ; Max length check
    inc rcx
    cmp rcx, rax
    je str_split_fail

    jmp str_split_loop
    
    str_split_done:
    mov rax, rcx
    ret

    str_split_fail:
    mov rax, -1
    ret


;            RDI
; fn str_len(input_str: &str) -> len
str_len:
    xor rcx, rcx    ; null rcx
    
    str_len_loop:
    mov al, byte [rdi + rcx]
    cmp al, 0
    je done
    inc rcx         ; i++
    jmp str_len_loop
    
    done:
    mov rax, rcx
    ret


;            RDI
; fn println(message: &str)
println:
    push rdi
    call str_len
    mov rdx, rax
    mov rsi, rdi
    mov rax, 1
    mov rdi, 1
    
    syscall
    pop rdi
    ret

;          RDI               RSI
; fn panic(exit_code: usize, message: &str)
unwrap:
    cmp rax, -1
    je panic
    ret

    panic:
    ; Save exit code, message
    push rdi
    
    ; Move message to rdi
    mov rdi, rsi
    call println   
    pop rdi
    jmp exit

; Expects the return value in RDI
exit:
    mov rax, 0x3c
    syscall

