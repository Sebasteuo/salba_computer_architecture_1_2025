[bits 64]
default rel

global _start

section .data
    filename db "imagen_in.img", 0

    msg_bytes_read db "Bytes leidos (hex): 0x", 0
msg_bytes_read_end:

    msg_checksum_sub db "Checksum sub-bloque (hex): 0x", 0
msg_checksum_sub_end:

    msg_done db "Lectura y sub-bloque completados.", 10, 0
msg_done_end:

    new_line db 10, 0

section .bss
    buffer         resb 400*400      ; 160000 bytes
    quad_buffer    resb 100*100      ; 10000 bytes para el sub-bloque
    read_count     resq 1
    quadrant       resd 1

section .text

; -------------------------------------------------------------------------
; _start:
; 1) Ajustar pila (opcional)
; 2) Abrir y leer imagen_in.img (hasta 160000 bytes)
; 3) Fijar un cuadrante y copiar sub-bloque 100x100 => quad_buffer
; 4) Imprimir bytes leidos en hex
; 5) Calcular e imprimir checksum del sub-bloque
; 6) exit(0)
; -------------------------------------------------------------------------
_start:
    ; Ajuste de la pila a 16 bytes
    sub rsp, 8

    ; (1) Abrir => syscall open(filename, O_RDONLY, 0)
    mov rax, 2           ; __NR_open
    mov rdi, filename
    xor rsi, rsi         ; O_RDONLY
    xor rdx, rdx
    syscall
    cmp rax, 0
    js  error_open
    mov rbx, rax         ; FD en rbx

    ; (2) Leer => syscall read(fd, buffer, 160000)
    mov rax, 0           ; __NR_read
    mov rdi, rbx
    mov rsi, buffer
    mov rdx, 400*400
    syscall
    cmp rax, 0
    js error_read
    mov [read_count], rax

    ; Cerrar => syscall close(fd)
    mov rax, 3           ; __NR_close
    mov rdi, rbx
    syscall

    ; (3) Escoger un cuadrante [1..16], forzado a 7
    mov eax, 7
    mov [quadrant], eax

    ; Validar [quadrant] = [1..16]
    mov eax, [quadrant]
    cmp eax, 1
    jl set_quad_one
    cmp eax, 16
    jg set_quad_one
    jmp quad_ok

set_quad_one:
    mov eax, 1
    mov [quadrant], eax

quad_ok:
    ; fila, col = ((quadrant-1)/4, (quadrant-1)%4)
    mov eax, [quadrant]
    dec eax
    xor edx, edx
    mov edi, 4
    div edi
    mov r14, rax  ; fila
    mov r15, rdx  ; col

    ; sub-bloque=100x100
    mov r12, 100
    mov r13, 100

    ; x_init= col*100, y_init= fila*100
    imul r15, r12
    imul r14, r13

    ; Copiar sub-bloque 100x100 => quad_buffer
    xor r8, r8
copy_rows:
    cmp r8, r13
    jge done_copy

    mov r9, r8
    add r9, r14
    imul r9, 400
    add r9, r15

    mov r10, r8
    imul r10, r12

    xor r11, r11
copy_cols:
    cmp r11, r12
    jge end_copy_row

    mov rcx, r9
    add rcx, r11
    mov rsi, buffer
    add rsi, rcx

    mov rdx, r10
    add rdx, r11
    mov rdi, quad_buffer
    add rdi, rdx

    mov al, [rsi]
    mov [rdi], al

    inc r11
    jmp copy_cols

end_copy_row:
    inc r8
    jmp copy_rows

done_copy:

    ; (4a) Imprimir "Bytes leidos (hex): 0x"
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_bytes_read
    mov rdx, msg_bytes_read_end - msg_bytes_read
    syscall

    ; Imprimir read_count en hex
    mov rax, [read_count]
    sub rsp, 16
    mov rsi, rsp

    mov rcx, 16
fill_readcount:
    mov byte [rsi + rcx - 1], '0'
    loop fill_readcount

    mov rcx, 16
conv_readcount:
    mov rbx, rax
    and rbx, 0xF
    cmp rbx, 10
    jb rc_digit0_9
    add rbx, 55
    jmp rc_store
rc_digit0_9:
    add rbx, 48
rc_store:
    mov byte [rsi + rcx - 1], bl
    shr rax, 4
    loop conv_readcount

    ; write(1, rsi, 16)
    mov rax, 1
    mov rdi, 1
    mov rdx, 16
    syscall

    add rsp, 16

    ; Salto de linea
    mov rax, 1
    mov rdi, 1
    mov rsi, new_line
    mov rdx, 1
    syscall

    ; (5) Calcular checksum del sub-bloque en quad_buffer
    xor rax, rax
    xor r8, r8
sub_checksum_rows:
    cmp r8, r13
    jge sub_checksum_done
    mov r9, r8
    imul r9, r12
    xor r11, r11
sub_checksum_cols:
    cmp r11, r12
    jge end_subsum_row
    mov rcx, r9
    add rcx, r11
    mov rsi, quad_buffer
    add rsi, rcx

    xor rbx, rbx
    mov bl, [rsi]
    add rax, rbx

    inc r11
    jmp sub_checksum_cols

end_subsum_row:
    inc r8
    jmp sub_checksum_rows

sub_checksum_done:
    mov r12, rax

    ; Imprimir "Checksum sub-bloque (hex): 0x"
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_checksum_sub
    mov rdx, msg_checksum_sub_end - msg_checksum_sub
    syscall

    mov rax, r12
    sub rsp, 16
    mov rsi, rsp

    mov rcx, 16
fill_subchk:
    mov byte [rsi + rcx - 1], '0'
    loop fill_subchk

    mov rcx, 16
conv_subchk:
    mov rbx, rax
    and rbx, 0xF
    cmp rbx, 10
    jb sb_digit0_9
    add rbx, 55
    jmp sb_store
sb_digit0_9:
    add rbx, 48
sb_store:
    mov byte [rsi + rcx - 1], bl
    shr rax, 4
    loop conv_subchk

    ; write(1, rsi, 16)
    mov rax, 1
    mov rdi, 1
    mov rdx, 16
    syscall

    add rsp, 16

    ; Salto de linea
    mov rax, 1
    mov rdi, 1
    mov rsi, new_line
    mov rdx, 1
    syscall

    ; Mensaje final
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_done
    mov rdx, msg_done_end - msg_done
    syscall

    ; (6) exit(0)
    mov rax, 60
    xor rdi, rdi
    syscall

; Errores
error_open:
    mov rax, 60
    mov rdi, 1
    syscall

error_read:
    mov rax, 60
    mov rdi, 2
    syscall
