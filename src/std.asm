global close
global socket
global bind
global listen
global accept
global write
global read
global exit
global println
global len

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

;         RDI                    RSI
; fn bind(socket_handle: handle, addr_pointer: &ipv4_addr) -> status
bind:
    mov rax, 0x31                ; bind syscall id
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
    call len
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


; Expects the return value in RDI
exit:
    mov rax, 0x3c
    syscall

;            RDI
; fn println(message: &str)
println:
    push rdi
    call len
    mov rdx, rax
    mov rsi, rdi
    mov rax, 1
    mov rdi, 1
    
    syscall
    pop rdi
    ret

;            RDI
; fn len(input_str: &str) -> len
len:
    xor rcx, rcx    ; null rcx
    
    len_loop:
    mov al, byte [rdi + rcx]
    cmp al, 0
    je done
    inc rcx         ; i++
    jmp len_loop
    
    done:
    mov rax, rcx
    ret
