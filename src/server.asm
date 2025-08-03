
section .rodata
    ; data.asm -> .rodata
    extern ok_header
    extern ok_header_len
    extern not_found_header
    extern not_found_header_len
    extern content_length
    extern content_length_len
    extern content_type
    extern content_type_len
    extern err_header
    extern sockaddr_ipv4
    extern exit_socket
    extern exit_bind
    extern exit_listen
    extern exit_accept
    extern exit_read

section .bss
    ; data.asm -> .bss
    extern header_buffer
    extern request_data
    extern file_data
    extern file_data_length
    extern header_len

section .text
    global _start
    ; std.asm -> .text
    extern close
    extern socket
    extern bind
    extern listen
    extern accept
    extern write
    extern read
    extern exit

    ; string.asm -> .text
    extern println
    extern str_cp
    extern str_split
    extern len
    extern itoa

_start:
    ; Load the state table
    
    ; Fetch handle to socket
    call socket ; -> handle

    ; Load socket error message
    mov rsi, exit_socket
    call unwrap

    ; Copy socket handle to bind
    mov rdi, rax
    lea rsi, [rel sockaddr_ipv4] ; Address
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
    
    ; Save client data
    push rsi
    
    ; Load read error message
    mov rsi, exit_read
    call unwrap
    
    ; Return the client request data
    pop rdi
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
    
; TODO, FIX TO USE VARIABLES:
    lea rsi, [file_data + 100]
    lea rdx, [file_data_length - 100]
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
 ;   mov rdx, header_len - ok_header_len - content_length_len  - 2
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
    call len
   
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
