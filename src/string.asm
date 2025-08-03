global str_split
global str_cp
global itoa

section .text
    extern len

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
    call len
    ; Copy it to rdx
    mov rdx, rax
    ; Null out rcx from len
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
