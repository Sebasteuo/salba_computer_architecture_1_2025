; ===========================================================================
; main.asm (x86_64, NASM)
; Lee ruta + cuadrante desde config.txt, procesa imagen 400x400,
; extrae sub-bloque 100x100, interpola a 200x200 y genera imagen_out.img.
; Se han eliminado todas las referencias a quad.txt.
; ===========================================================================

[bits 64]
default rel

global _start

section .data

    ; Archivos
    fname_out     db "imagen_out.img", 0
    fname_config  db "config.txt", 0   ; Contendrá:
                                       ;   1) Ruta de la imagen en la 1era línea
                                       ;   2) Cuadrante (1..16) en la 2da línea
    
    ; Mensajes
    msg_bytes_read        db "Bytes leidos (hex): 0x", 0
    msg_bytes_read_end:

    msg_checksum_sub      db "Checksum sub-bloque (hex): 0x", 0
    msg_checksum_sub_end:

    msg_checksum_interp   db "Checksum imagen interpolada (hex): 0x", 0
    msg_checksum_interp_end:

    msg_done              db "Procesamiento finalizado. Se genero imagen_out.img", 10, 0
    msg_done_end:

    new_line              db 10, 0

    msg_error_config      db "Error: config.txt malformado o cuadrante invalido.", 10, 0
    msg_error_config_end:

section .bss
    ; Buffers de trabajo
    buffer          resb 400*400      ; 160.000 bytes
    quad_buffer     resb 100*100      ; sub-bloque 100x100
    interp_buffer   resb 200*200      ; interpolado 200x200

    ; Para guardar cuántos bytes se leyeron de la imagen
    read_count      resq 1

    ; Variables de uso
    quadrant        resd 1
    row_var         resd 1
    col_var         resd 1

    ; Para leer config
    config_buffer   resb 256          ; leemos hasta 256 bytes de config.txt
    path_buffer     resb 240          ; donde guardamos la ruta de la imagen
    quad_input      resb 4            ; "7", "12", etc.

section .text

; ===========================================================================
; _start
; ===========================================================================
; Flujo principal:
;   1) Leer config.txt => path_buffer, quadrant
;   2) Abrir/leer la imagen en buffer (400x400)
;   3) Extraer sub-bloque 100x100
;   4) Interpolar => 200x200
;   5) Guardar en imagen_out.img
;   6) Imprimir checksums, mensaje final
;   7) exit(0)
; ===========================================================================
_start:
    sub rsp, 8  ; por seguridad/alineación

    ; 1) Leer config => path imagen + quadrant
    call read_config_from_file

    ; 2) Abrir la imagen usando path_buffer
    mov rax, 2             ; sys_open
    mov rdi, path_buffer   ; path leído de config.txt
    xor rsi, rsi           ; O_RDONLY
    xor rdx, rdx
    syscall
    cmp rax, 0
    js error_open_in
    mov rbx, rax           ; fd imagen en rbx

    ; Leer la imagen completa (400x400 = 160000 bytes)
    mov rax, 0             ; sys_read
    mov rdi, rbx
    mov rsi, buffer
    mov rdx, 400*400
    syscall
    cmp rax, 0
    js error_read_in
    mov [read_count], rax

    ; Cerrar la imagen
    mov rax, 3             ; sys_close
    mov rdi, rbx
    syscall

    ; 3) Extraer sub-bloque 100x100 según el cuadrante
    ;    quadrant (1..16) => fila,col en [0..3]
    mov eax, [quadrant]  ; 1..16
    dec eax              ; 0..15
    xor edx, edx
    mov edi, 4
    div edi              ; EAX=fila(0..3), EDX=col(0..3)
    mov r14, rax         ; fila
    mov r15, rdx         ; col

    mov r12, 100
    mov r13, 100

    imul r15, r12   ; col * 100
    imul r14, r13   ; fila * 100

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

    ; 4) Interpolar => 200x200
    xor eax, eax
    mov [row_var], eax

interp_outer_row:
    mov eax, [row_var]
    cmp eax, 100
    jge done_interp

    mov r8d, eax
    shl r8, 1  ; r8 = row*2

    xor edx, edx
    mov [col_var], edx

interp_inner_col:
    mov edx, [col_var]
    cmp edx, 100
    jge end_interp_row

    mov r10d, [row_var]
    cmp r10d, 99
    jl .ok_rplus
    jmp .no_rplus
.ok_rplus:
    add r10d, 1
.no_rplus:

    mov r11d, [col_var]
    cmp r11d, 99
    jl .ok_cplus
    jmp .no_cplus
.ok_cplus:
    add r11d, 1
.no_cplus:

    ; Píxeles originales en el sub-bloque
    mov eax, [row_var]
    mov edx, [col_var]

    mov rsi, quad_buffer
    mov ecx, eax
    imul ecx, 100
    add ecx, edx
    add rsi, rcx
    movzx r14, byte [rsi]  ; A

    mov rsi, quad_buffer
    mov ecx, r10d
    imul ecx, 100
    add ecx, edx
    add rsi, rcx
    movzx r15, byte [rsi]  ; B

    mov rsi, quad_buffer
    mov ecx, eax
    imul ecx, 100
    add ecx, r11d
    add rsi, rcx
    movzx rdi, byte [rsi]  ; C

    mov rsi, quad_buffer
    mov ecx, r10d
    imul ecx, 100
    add ecx, r11d
    add rsi, rcx
    movzx rsi, byte [rsi]  ; D

    mov r9d, [col_var]
    shl r9, 1  ; col*2

    ; (row*2, col*2) => A
    mov rcx, r8
    imul rcx, 200
    add rcx, r9
    mov rdx, interp_buffer
    add rdx, rcx
    mov [rdx], r14b

    ; (row*2+1, col*2) => average(A,B) => (3*A + B) / 4
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

    ; (row*2, col*2+1) => average(A,C) => (3*A + C) / 4
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

    ; (row*2+1, col*2+1) => average(A,B,C,D) => (A + B + C + D)/4
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

    ; siguiente columna
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

    ; 5) Crear imagen_out.img
    mov rax, 2
    mov rdi, fname_out
    mov rsi, 577   ; O_WRONLY|O_CREAT|O_TRUNC
    mov rdx, 420   ; 0644
    syscall
    cmp rax, 0
    js error_open_out
    mov rbx, rax

    ; Escribir => 200*200 = 40000 bytes
    mov rax, 1
    mov rdi, rbx
    mov rsi, interp_buffer
    mov rdx, 200*200
    syscall
    cmp rax, 0
    js error_write_out

    ; cerrar out
    mov rax, 3
    mov rdi, rbx
    syscall

    ; 6) Calcular e imprimir checksums
    ; -- sub-bloque 100x100 --
    xor rax, rax
    xor r8, r8
csum_sub_rows:
    cmp r8, 100
    jge csum_sub_done
    mov r9, r8
    imul r9, 100
    xor r11, r11
csum_sub_cols:
    cmp r11, 100
    jge end_sub_row
    mov rcx, r9
    add rcx, r11
    mov rsi, quad_buffer
    add rsi, rcx

    xor rbx, rbx
    mov bl, [rsi]
    add rax, rbx

    inc r11
    jmp csum_sub_cols

end_sub_row:
    inc r8
    jmp csum_sub_rows

csum_sub_done:
    mov r12, rax

    ; -- interpolado 200x200 --
    xor rax, rax
    xor r8, r8
csum_interp_rows:
    cmp r8, 200
    jge csum_interp_done
    mov r9, r8
    imul r9, 200
    xor r11, r11
csum_interp_cols:
    cmp r11, 200
    jge end_interp_sum_row2
    mov rcx, r9
    add rcx, r11
    mov rsi, interp_buffer
    add rsi, rcx

    xor rbx, rbx
    mov bl, [rsi]
    add rax, rbx

    inc r11
    jmp csum_interp_cols

end_interp_sum_row2:
    inc r8
    jmp csum_interp_rows

csum_interp_done:
    mov r13, rax

    ; Imprimir en pantalla
    ; (a) Bytes leídos
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_bytes_read
    mov rdx, msg_bytes_read_end - msg_bytes_read
    syscall

    mov rdi, [read_count]
    call print_hex

    ; newline
    mov rax, 1
    mov rdi, 1
    mov rsi, new_line
    mov rdx, 1
    syscall

    ; (b) Checksum sub-bloque
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_checksum_sub
    mov rdx, msg_checksum_sub_end - msg_checksum_sub
    syscall

    mov rdi, r12
    call print_hex

    ; newline
    mov rax, 1
    mov rdi, 1
    mov rsi, new_line
    mov rdx, 1
    syscall

    ; (c) Checksum interpolado
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_checksum_interp
    mov rdx, msg_checksum_interp_end - msg_checksum_interp
    syscall

    mov rdi, r13
    call print_hex

    ; newline
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

; ===========================================================================
; read_config_from_file:
;   Lee config.txt:
;     - Primera linea => path de la imagen => path_buffer
;     - Segunda linea => cuadrante (1..16) => [quadrant]
; ===========================================================================
read_config_from_file:
    push rbp
    mov rbp, rsp

    ; 1) Abrir config.txt en modo lectura (O_RDONLY)
    mov rax, 2             ; sys_open
    mov rdi, fname_config
    xor rsi, rsi           ; flags=0 => O_RDONLY
    xor rdx, rdx
    syscall
    cmp rax, 0
    js  error_open_config
    mov rbx, rax

    ; 2) Leer hasta 256 bytes
    mov rax, 0             ; sys_read
    mov rdi, rbx
    mov rsi, config_buffer
    mov rdx, 256
    syscall
    cmp rax, 0
    js  error_read_config
    ; rax = bytes leídos

    ; cerrar config.txt
    mov rax, 3             ; sys_close
    mov rdi, rbx
    syscall

    ; 3) Parsear la primera linea => path_buffer
    xor rcx, rcx   ; índice en config_buffer
    xor rdx, rdx   ; índice en path_buffer
.find_path_loop:
    mov al, [config_buffer + rcx]
    cmp al, 0
    je .error_bad_config   ; fin de buffer sin encontrar '\n'
    cmp al, 10
    je .end_path
    mov [path_buffer + rdx], al
    inc rcx
    inc rdx
    cmp rdx, 240
    jae .error_bad_config
    jmp .find_path_loop

.end_path:
    mov byte [path_buffer + rdx], 0
    inc rcx  ; saltamos el '\n'

    ; 4) Segunda linea => cuadrante => quad_input
    xor rdx, rdx
.next_line_loop:
    mov al, [config_buffer + rcx]
    cmp al, 0
    je .maybe_ok
    cmp al, 10
    je .end_quad
    mov [quad_input + rdx], al
    inc rcx
    inc rdx
    cmp rdx, 3
    jae .end_quad
    jmp .next_line_loop

.end_quad:
    mov byte [quad_input + rdx], 0

.maybe_ok:

    ; convertir quad_input => número en [quadrant]
    call parse_quadrant

    ; validar 1..16
    mov eax, [quadrant]
    cmp eax, 1
    jl .error_range
    cmp eax, 16
    jg .error_range

    leave
    ret

.error_bad_config:
.error_range:
.fail:
    ; Mensaje de error y salir
    mov rax, 1            ; sys_write
    mov rdi, 1            ; STDOUT
    mov rsi, msg_error_config
    mov rdx, msg_error_config_end - msg_error_config
    syscall

    mov rax, 60           ; sys_exit
    mov rdi, 1            ; código de salida
    syscall

error_open_config:
    mov rax, 60
    mov rdi, 17
    syscall

error_read_config:
    mov rax, 60
    mov rdi, 18
    syscall

; ===========================================================================
; parse_quadrant: Convierte quad_input (ASCII) => [quadrant] (entero).
;   Ej: "7" -> 7, "12" -> 12, etc.
; ===========================================================================
parse_quadrant:
    push rbp
    mov rbp, rsp

    mov rsi, quad_input
    xor r8, r8

    ; Primer dígito
    mov al, [rsi]
    cmp al, 0
    je .no_digits
    sub al, '0'
    cmp al, 9
    ja .not_digit
    mov r8, rax   ; primer dígito

    ; Segundo dígito opcional
    mov al, [rsi+1]
    cmp al, 0
    je .ok
    cmp al, 10
    je .ok
    sub al, '0'
    cmp al, 9
    ja .not_digit

    imul r8, r8, 10
    add r8, rax

    jmp .ok

.not_digit:
    mov dword [quadrant], 0
    jmp .done

.no_digits:
    mov dword [quadrant], 0
    jmp .done

.ok:
    mov [quadrant], r8d
.done:
    leave
    ret

; ===========================================================================
; print_hex: Imprime en pantalla RDI en hex de 16 dígitos
; ===========================================================================
print_hex:
    push rbp
    mov rbp, rsp

    push rbx
    sub rsp, 16

    mov rax, rdi
    mov rsi, rsp

    mov rcx, 16
.fill_loop:
    mov byte [rsi + rcx - 1], '0'
    loop .fill_loop

    mov rcx, 16
.hex_conv:
    mov rbx, rax
    and rbx, 0xF
    cmp rbx, 10
    jb .digit0_9
    add rbx, 55    ; 'A' (65) - 10 = 55
    jmp .store_char

.digit0_9:
    add rbx, 48    ; '0'
.store_char:
    mov byte [rsi + rcx - 1], bl
    shr rax, 4
    loop .hex_conv

    ; escribir
    mov rax, 1
    mov rdi, 1
    mov rdx, 16
    syscall

    add rsp, 16
    pop rbx
    leave
    ret

; ===========================================================================
; Manejo de errores de apertura/lectura/escritura de archivos
; ===========================================================================
error_open_in:
    mov rax, 60
    mov rdi, 11
    syscall

error_read_in:
    mov rax, 60
    mov rdi, 12
    syscall

error_open_out:
    mov rax, 60
    mov rdi, 13
    syscall

error_write_out:
    mov rax, 60
    mov rdi, 14
    syscall

