[bits 64]
default rel

global _start

section .data
    filename db "imagen_in.img", 0

    msg_bytes_read db "Bytes leidos (hex): 0x", 0
msg_bytes_read_end:

    msg_checksum_sub db "Checksum sub-bloque (hex): 0x", 0
msg_checksum_sub_end:

    msg_checksum_interp db "Checksum imagen interpolada (hex): 0x", 0
msg_checksum_interp_end:

    msg_done db "Lectura, sub-bloque y interpolacion completadas.", 10, 0
msg_done_end:

    new_line db 10, 0

section .bss
    buffer         resb 400*400      ; 160000 bytes
    quad_buffer    resb 100*100      ; 10000 bytes sub-bloque
    interp_buffer  resb 200*200      ; 40000 bytes interpolado
    read_count     resq 1
    quadrant       resd 1

    row_var        resd 1            ; Para la fila en bucle
    col_var        resd 1            ; Para la columna en bucle

section .text

; ----------------------------------------------------------------------------
; _start
; 1) Alinear la pila a 16 bytes
; 2) Leer imagen_in.img
; 3) Copiar sub-bloque 100x100
; 4) Checksum e imprimir
; 5) Interpolar 2x (200x200), usando row_var, col_var en MEM
; 6) Checksum interpolado e imprimir
; 7) exit(0)
; ----------------------------------------------------------------------------
_start:
    ; Ajuste de la pila a 16 bytes
    sub rsp, 8

    ; (1) Abrir archivo => open
    mov rax, 2
    mov rdi, filename
    xor rsi, rsi
    xor rdx, rdx
    syscall
    cmp rax, 0
    js error_open
    mov rbx, rax  ; FD

    ; Leer => read(fd, buffer, 160000)
    mov rax, 0
    mov rdi, rbx
    mov rsi, buffer
    mov rdx, 400*400
    syscall
    cmp rax, 0
    js error_read
    mov [read_count], rax

    ; Cerrar => close(fd)
    mov rax, 3
    mov rdi, rbx
    syscall

    ; quadrant=7 (forzado a [1..16])
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

quad_ok:
    ; (fila, col) = ((quadrant-1)/4, (quadrant-1)%4)
    mov eax, [quadrant]
    dec eax
    xor edx, edx
    mov edi, 4
    div edi
    mov r14, rax   ; fila
    mov r15, rdx   ; col

    ; sub-bloque=100x100
    mov r12, 100
    mov r13, 100

    ; x_init = col*100, y_init = fila*100
    imul r15, r12
    imul r14, r13

    ; (2) Copiar sub-bloque 100x100 => quad_buffer
    xor r8, r8
copy_rows:
    cmp r8, r13
    jge copy_done

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

copy_done:

    ; (3) Imprimir "Bytes leidos (hex): 0x"
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_bytes_read
    mov rdx, msg_bytes_read_end - msg_bytes_read
    syscall

    ; Imprimir [read_count] en hex (inline)
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
    add rbx, 55   ; 'A'
    jmp rc_store
rc_digit0_9:
    add rbx, 48
rc_store:
    mov byte [rsi + rcx - 1], bl
    shr rax, 4
    loop conv_readcount

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

    ; (4) Checksum sub-bloque
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

    ; (5) Interpolar 2x => interp_buffer usando row_var, col_var
    ; Inicializamos row_var=0
    xor eax, eax
    mov [row_var], eax

interp_outer_row:
    mov eax, [row_var]
    cmp eax, 100
    jge done_interp

    ; row2 = 2*row_var => r8
    mov r8d, eax
    shl r8, 1

    ; col_var=0
    xor edx, edx
    mov [col_var], edx

interp_inner_col:
    mov edx, [col_var]
    cmp edx, 100
    jge end_interp_row

    ; rplus = (row_var<99)?(row_var+1):row_var => r10
    mov r10d, [row_var]
    cmp r10d, 99
    jl .ok_rplus
    jmp .no_rplus
.ok_rplus:
    add r10d, 1
.no_rplus:

    ; cplus = (col_var<99)?(col_var+1):col_var => r11
    mov r11d, [col_var]
    cmp r11d, 99
    jl .ok_cplus
    jmp .no_cplus
.ok_cplus:
    add r11d, 1
.no_cplus:

    ; oldVal0 => r14
    ; row_var en eax, col_var en edx => manipular con 32 bits
    mov eax, [row_var]
    mov edx, [col_var]

    ; oldVal0 = quad_buffer[eax, edx]
    mov rsi, quad_buffer
    mov ecx, eax
    imul ecx, 100
    add ecx, edx
    add rsi, rcx
    movzx r14, byte [rsi]

    ; oldVal1 => r15
    mov rsi, quad_buffer
    mov ecx, r10d
    imul ecx, 100
    add ecx, edx
    add rsi, rcx
    movzx r15, byte [rsi]

    ; oldVal2 => rdi
    mov rsi, quad_buffer
    mov ecx, eax
    imul ecx, 100
    add ecx, r11d
    add rsi, rcx
    movzx rdi, byte [rsi]

    ; oldVal3 => rsi
    mov rsi, quad_buffer
    mov ecx, r10d
    imul ecx, 100
    add ecx, r11d
    add rsi, rcx
    movzx rsi, byte [rsi]

    ; col2 = 2*col_var => r9
    mov r9d, [col_var]
    shl r9, 1

    ; new(2r,2c) = oldVal0
    mov rcx, r8
    imul rcx, 200
    add rcx, r9
    mov rdx, interp_buffer
    add rdx, rcx
    mov [rdx], r14b

    ; new(2r+1,2c) = (3*oldVal0 + oldVal1)/4
    mov rcx, r8
    add rcx, 1
    imul rcx, 200
    add rcx, r9
    mov rdx, interp_buffer
    add rdx, rcx

    mov rax, r14
    imul rax, 3
    add rax, r15
    shr rax, 2
    mov [rdx], al

    ; new(2r,2c+1) = (3*oldVal0 + oldVal2)/4
    mov rcx, r8
    imul rcx, 200
    mov rdx, r9
    add rdx, 1
    add rcx, rdx
    mov rdx, interp_buffer
    add rdx, rcx

    mov rax, r14
    imul rax, 3
    add rax, rdi
    shr rax, 2
    mov [rdx], al

    ; new(2r+1,2c+1) = (oldVal0 + oldVal1 + oldVal2 + oldVal3)/4
    mov rcx, r8
    add rcx, 1
    imul rcx, 200
    mov rdx, r9
    add rdx, 1
    add rcx, rdx
    mov rdx, interp_buffer
    add rdx, rcx

    mov rax, r14
    add rax, r15
    add rax, rdi
    add rax, rsi
    shr rax, 2
    mov [rdx], al

    ; col_var++
    mov eax, [col_var]
    inc eax
    mov [col_var], eax

    jmp interp_inner_col

end_interp_row:
    mov eax, [row_var]
    inc eax
    mov [row_var], eax
    jmp interp_outer_row

done_interp:

    ; (6) Checksum de interp_buffer
    xor rax, rax
    xor r8, r8
interp_sum_rows:
    cmp r8, 200
    jge interp_sum_done
    mov r9, r8
    imul r9, 200
    xor r11, r11
interp_sum_cols:
    cmp r11, 200
    jge end_interp_sum_row
    mov rcx, r9
    add rcx, r11
    mov rsi, interp_buffer
    add rsi, rcx

    xor rbx, rbx
    mov bl, [rsi]
    add rax, rbx

    inc r11
    jmp interp_sum_cols

end_interp_sum_row:
    inc r8
    jmp interp_sum_rows

interp_sum_done:
    mov r12, rax

    ; Imprimir "Checksum imagen interpolada (hex): 0x"
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_checksum_interp
    mov rdx, msg_checksum_interp_end - msg_checksum_interp
    syscall

    mov rax, r12
    sub rsp, 16
    mov rsi, rsp

    mov rcx, 16
fill_interpchk:
    mov byte [rsi + rcx - 1], '0'
    loop fill_interpchk

    mov rcx, 16
conv_interpchk:
    mov rbx, rax
    and rbx, 0xF
    cmp rbx, 10
    jb ic_digit0_9
    add rbx, 55
    jmp ic_store
ic_digit0_9:
    add rbx, 48
ic_store:
    mov byte [rsi + rcx - 1], bl
    shr rax, 4
    loop conv_interpchk

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

    ; exit(0)
    mov rax, 60
    xor rdi, rdi
    syscall

; Manejo errores
error_open:
    mov rax, 60
    mov rdi, 1
    syscall

error_read:
    mov rax, 60
    mov rdi, 2
    syscall
