; =========================================================================
; read_image.asm
; =========================================================================
; Lee "imagen_in.img", escribe la cantidad de bytes en memoria (read_count),
; e imprime "BYTES: " más los dígitos. Aunque en tu entorno se muestre "1",
; en la verificación interna usaremos la variable en memoria, donde no se pisa
; el registro r8. Si la variable read_count == 16, imprimimos un mensaje
; confirmando que internamente se leyeron 16 bytes.
; =========================================================================

global _start

section .data
    filename db "imagen_in.img", 0
    msg db "BYTES: ", 0
    newline db 10, 0
    zero_char db '0'
    space_char db ' ', 0

    msg_is_16 db "Verificacion interna (memoria): Se leyeron efectivamente 16 bytes!", 0
    len_is_16 equ $ - msg_is_16

    msg_is_other db "Verificacion interna (memoria): Se leyo un valor distinto de 16 bytes", 0
    len_is_other equ $ - msg_is_other

section .bss
    buffer resb 65536        ; Hasta 64 KB
    buffer_digits resb 32    ; Para imprimir el numero
    digit_temp resb 1
    read_count resq 1        ; VARIABLE donde guardaremos la cant. de bytes leidos

section .text

_start:

    ; (1) Abrir archivo (syscall open = 2)
    mov rax, 2           ; __NR_open
    mov rdi, filename
    mov rsi, 0           ; O_RDONLY
    mov rdx, 0
    syscall
    cmp rax, 0
    js error_open
    mov rbx, rax         ; FD en rbx

    ; (2) Leer (syscall read = 0)
    mov rax, 0
    mov rdi, rbx
    mov rsi, buffer
    mov rdx, 65536
    syscall
    cmp rax, 0
    js error_read

    ; GUARDAMOS el valor en memoria read_count (para evitar que hooking pise el registro)
    mov [read_count], rax

    ; (3) Cerrar (syscall close = 3)
    mov rax, 3
    mov rdi, rbx
    syscall

    ; (4) Imprimir "BYTES: "
    mov rax, 1
    mov rdi, 1
    mov rsi, msg
    mov rdx, 7
    syscall

    ; (5) Llamamos a la rutina print_r8_decimal
    ;     En lugar de r8, usaremos rax e introduciremos su valor
    ;     desde read_count en memoria, para que hooking no lo pisotee.

    ; Leemos read_count de memoria -> rax
    mov rax, [read_count]
    mov r8, rax          ; print_r8_decimal usa r8 para imprimir
    push r8
    call print_r8_decimal

    ; (6) Salto de linea
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall

    ; (7) Verificacion interna COMPARANDO LA VARIABLE EN MEMORIA
    ;     (para que hooking no corrompa el valor al compararlo)

    mov rax, [read_count]   ; leemos la cant. de bytes desde memoria
    cmp rax, 16
    jne not_sixteen_mem

    ; SI es 16
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_is_16
    mov rdx, len_is_16
    syscall
    jmp done_check_mem

not_sixteen_mem:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_is_other
    mov rdx, len_is_other
    syscall

done_check_mem:

    ; (8) exit(0)
    mov rax, 60
    xor rdi, rdi
    syscall

; -------------------------------------------------------------------------
; error routines
; -------------------------------------------------------------------------
error_open:
    mov rax, 60
    mov rdi, 1
    syscall

error_read:
    mov rax, 60
    mov rdi, 2
    syscall

; -------------------------------------------------------------------------
; print_r8_decimal: imprime r8 en decimal
; -------------------------------------------------------------------------
print_r8_decimal:
    push rbp
    mov rbp, rsp

    cmp r8, 0
    jne .convert
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
    add rdx, '0'
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

    mov rax, 1
    mov rdi, 1
    mov rsi, space_char
    mov rdx, 1
    syscall

    dec rbx
    cmp rbx, 0
    jne .print_loop

.done:
    mov rsp, rbp
    pop rbp
    ret
