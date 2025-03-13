; test_print.asm
; Demostración mínima de impresión de un número en r8

global _start

section .data
    msg_bytes_read db "Valor en r8: ", 0
    newline db 10, 0
    zero_char db '0'

section .bss
    buffer_digits resb 32
    digit_temp resb 1

section .text

_start:
    ; 1) Ponemos el valor 16 en r8
    mov r8, 16

    ; 2) Imprimimos la cadena "Valor en r8: "
    mov rax, 1             ; write
    mov rdi, 1             ; stdout
    mov rsi, msg_bytes_read
    mov rdx, 13            ; "Valor en r8: " => 13 chars
    syscall

    ; 3) Llamamos a la rutina para imprimir r8 en decimal
    push r8
    call print_number_in_r8

    ; 4) Imprimir salto de línea
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall

    ; 5) Salir
    mov rax, 60
    xor rdi, rdi
    syscall

; -------------------------------------------------
; print_number_in_r8: Convierte r8 en decimal ASCII
; -------------------------------------------------
print_number_in_r8:
    push rbp
    mov rbp, rsp

    cmp r8, 0
    jne .convert
    ; Si es 0, imprimimos '0'
    mov rax, 1
    mov rdi, 1
    mov rsi, zero_char
    mov rdx, 1
    syscall
    jmp .done

.convert:
    xor rbx, rbx
    mov rcx, buffer_digits

.convert_loop:
    xor rdx, rdx
    mov rax, r8
    mov rdi, 10
    div rdi
    add rdx, '0'        ; convierte el residuo a carácter
    mov [rcx], dl
    inc rcx
    inc rbx
    mov r8, rax
    cmp r8, 0
    jne .convert_loop

.print_loop:
    dec rcx
    mov dl, [rcx]
    mov [digit_temp], dl

    mov rax, 1
    mov rdi, 1
    mov rsi, digit_temp
    mov rdx, 1
    syscall

    dec rbx
    cmp rbx, 0
    jne .print_loop

.done:
    mov rsp, rbp
    pop rbp
    ret
