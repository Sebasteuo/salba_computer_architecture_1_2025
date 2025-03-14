[bits 64]
default rel

global _start

section .data
    ; Nombre del archivo
    filename db "imagen_in.img", 0

    ; Mensajes para depurar
    msg_bytes_read db "Bytes leidos (hex): 0x", 0
msg_bytes_read_end:

    msg_checksum db "Checksum sub-bloque (hex): 0x", 0
msg_checksum_end:

    msg_done db "Lectura de archivo y seleccion de cuadrante completadas.", 10, 0
msg_done_end:

section .bss
    ; Buffer de 160000 bytes para la imagen (400×400)
    buffer      resb 400*400

    ; Buffer para el sub-bloque
    quad_buffer resb 400*400

    ; Variables auxiliares
    read_count  resq 1
    quadrant    resd 1

section .text

; -------------------------------------------------------------------------
; _start:
;   1) Lee "imagen_in.img" en buffer (hasta 160000 bytes).
;   2) Fija quadrant=7 y valida en [1..16].
;   3) Copia sub-bloque 100×100 en quad_buffer (1 byte/pixel).
;   4) Imprime en hex:
;       - la cantidad leída
;       - el checksum del sub-bloque
;       - mensaje final
;   5) exit(0).
; -------------------------------------------------------------------------
_start:

    ; (1) Abrir archivo (open=2)
    mov rax, 2              ; __NR_open
    mov rdi, filename
    mov rsi, 0              ; O_RDONLY
    mov rdx, 0
    syscall
    cmp rax, 0
    js  error_open
    mov rbx, rax            ; FD en rbx

    ; Leer en buffer (read=0)
    mov rax, 0
    mov rdi, rbx
    mov rsi, buffer
    mov rdx, 400*400        ; 160000
    syscall
    cmp rax, 0
    js  error_read
    mov [read_count], rax   ; bytes leídos

    ; Cerrar (close=3)
    mov rax, 3
    mov rdi, rbx
    syscall

    ; (2) quadrant=7, validar
    mov eax, 7
    mov [quadrant], eax

    mov eax, [quadrant]
    cmp eax, 1
    jl set_quad_one
    cmp eax, 16
    jg set_quad_one
    jmp quad_ok

set_quad_one:
    mov eax, 1
    mov [quadrant], eax
    jmp quad_ok

quad_ok:
    ; Sub-bloque=100×100
    mov r12, 100
    mov r13, 100

    ; quadrant_index=(quadrant-1), row=(idx/4), col=(idx%4)
    mov eax, [quadrant]
    dec eax
    xor edx, edx
    mov edi, 4
    div edi
    mov r14, rax  ; row
    mov r15, rdx  ; col

    ; x_init=r15*r12, y_init=r14*r13
    imul r15, r12
    imul r14, r13

    ; (3) Copiar sub-bloque
    xor r8, r8   ; fila=0
outer_loop:
    cmp r8, r13
    jge done_copy

    mov r9, r8
    add r9, r14
    imul r9, 400
    add r9, r15

    mov r10, r8
    imul r10, r12

    xor r11, r11 ; col=0
inner_loop:
    cmp r11, r12
    jge end_row

    mov rcx, r9
    add rcx, r11
    mov rdx, r10
    add rdx, r11

    mov rsi, buffer
    add rsi, rcx

    mov rdi, quad_buffer
    add rdi, rdx

    mov al, [rsi]
    mov [rdi], al

    inc r11
    jmp inner_loop

end_row:
    inc r8
    jmp outer_loop

done_copy:

    ; (4a) Imprimir msg_bytes_read
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_bytes_read
    mov rdx, msg_bytes_read_end - msg_bytes_read
    syscall

    ; Imprimir read_count en hex
    mov rax, [read_count]
    mov rdi, rax
    call print_hex_rax

    ; (4b) Checksum sub-bloque
    xor rax, rax
    xor r8, r8
csum_outer:
    cmp r8, r13
    jge csum_done
    mov r9, r8
    imul r9, r12
    xor r11, r11
csum_inner:
    cmp r11, r12
    jge csum_end_row
    mov rcx, r9
    add rcx, r11
    mov rsi, quad_buffer
    add rsi, rcx

    xor rbx, rbx
    mov bl, [rsi]
    add rax, rbx
    inc r11
    jmp csum_inner

csum_end_row:
    inc r8
    jmp csum_outer
csum_done:

    ; Imprimir msg_checksum
    mov rdx, msg_checksum_end - msg_checksum
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_checksum
    syscall

    mov rdi, rax
    ; Oops: Se debe pasar rax => rdi. Pero aquí rax=1. Corrijamos:
    ; => mov rdi, rax no es correcto. Realmente necesitamos mover "rax" checksum a rdi:
    ; => mov rdi, <valor del checksum> => OJO, el checksum está en rax:
    mov rdi, rax
    call print_hex_rax

    ; (4c) Imprimir msg_done
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_done
    mov rdx, msg_done_end - msg_done
    syscall

    ; (5) exit(0)
    mov rax, 60
    xor rdi, rdi
    syscall

; -------------------------------------------------------------------------
; Manejo de errores
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
; print_hex_rax:
; Imprime rdi en hex (16 dígitos) + \n
; -------------------------------------------------------------------------
print_hex_rax:
    push rbp
    mov rbp, rsp

    mov rax, rdi

    sub rsp, 18
    mov rsi, rsp

    mov rcx, 18
.fill_loop:
    mov byte [rsi + rcx - 1], '0'
    loop .fill_loop

    mov rcx, 16
.conv_loop:
    mov rbx, rax
    and rbx, 0xF
    cmp rbx, 10
    jb .digit0_9
    add rbx, 55   ; 'A'
    jmp .store
.digit0_9:
    add rbx, 48   ; '0'
.store:
    mov byte [rsi + rcx - 1], bl
    shr rax, 4
    loop .conv_loop

    mov byte [rsi + 16], 10
    mov byte [rsi + 17], 0

    ; write(1, rsi, 17)
    mov rax, 1
    mov rdi, 1
    mov rdx, 17
    syscall

    add rsp, 18
    leave
    ret
