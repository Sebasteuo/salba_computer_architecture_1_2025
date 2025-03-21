[bits 64]
default rel

global _start

section .data

    ; Nombres de archivos
    fname_in     db "imagen_in.img", 0
    fname_out    db "imagen_out.img", 0
    fname_quad   db "quad.txt", 0

    ; Mensajes
    prompt_quad db "Ingrese el cuadrante (1..16): ", 0
prompt_quad_end:

    msg_invalid db "Valor no valido. Intente de nuevo.", 10, 0
msg_invalid_end:

    msg_bytes_read db "Bytes leidos (hex): 0x", 0
msg_bytes_read_end:

    msg_checksum_sub db "Checksum sub-bloque (hex): 0x", 0
msg_checksum_sub_end:

    msg_checksum_interp db "Checksum imagen interpolada (hex): 0x", 0
msg_checksum_interp_end:

    msg_done db "Procesamiento finalizado. Se genero imagen_out.img y quad.txt", 10, 0
msg_done_end:

    ; Salto de linea
    new_line db 10, 0

    debug_msg db "[DEBUG] quad_msg_buffer = ", 0
debug_msg_end:

    debug_len db "[DEBUG] length = 0x", 0
debug_len_end:

section .bss
    buffer         resb 400*400      ; 160000
    quad_buffer    resb 100*100      ; sub-bloque
    interp_buffer  resb 200*200      ; interpolado
    read_count     resq 1
    quadrant       resd 1

    row_var        resd 1
    col_var        resd 1

    quad_input     resb 4            ; leer 1..2 digitos + \n
    quad_msg_buffer resb 16          ; "7\n\0"

section .text

; ----------------------------------------------------------------------------
; _start: flujo
; 1) Pedir cuadrante
; 2) Leer imagen_in
; 3) Sub-bloque
; 4) Interpolar
; 5) out.img
; 6) Escribir quadrant en quad.txt
; 7) Imprimir checksums
; 8) exit(0)
; ----------------------------------------------------------------------------
_start:
    sub rsp, 8

    ; (1) Pide quadrant
    call read_quadrant_in_loop

    ; (2) open/read imagen_in.img
    mov rax, 2
    mov rdi, fname_in
    xor rsi, rsi
    xor rdx, rdx
    syscall
    cmp rax, 0
    js error_open_in
    mov rbx, rax

    mov rax, 0
    mov rdi, rbx
    mov rsi, buffer
    mov rdx, 400*400
    syscall
    cmp rax, 0
    js error_read_in
    mov [read_count], rax

    ; close
    mov rax, 3
    mov rdi, rbx
    syscall

    ; (3) sub-bloque
    mov eax, [quadrant]
    dec eax
    xor edx, edx
    mov edi, 4
    div edi
    mov r14, rax  ; fila
    mov r15, rdx  ; col

    mov r12, 100
    mov r13, 100

    imul r15, r12  ; col*100
    imul r14, r13  ; fila*100

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

    ; (4) Interpolar => 200x200
    xor eax, eax
    mov [row_var], eax

interp_outer_row:
    mov eax, [row_var]
    cmp eax, 100
    jge done_interp

    mov r8d, eax
    shl r8, 1

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

    mov eax, [row_var]
    mov edx, [col_var]

    mov rsi, quad_buffer
    mov ecx, eax
    imul ecx, 100
    add ecx, edx
    add rsi, rcx
    movzx r14, byte [rsi]

    mov rsi, quad_buffer
    mov ecx, r10d
    imul ecx, 100
    add ecx, edx
    add rsi, rcx
    movzx r15, byte [rsi]

    mov rsi, quad_buffer
    mov ecx, eax
    imul ecx, 100
    add ecx, r11d
    add rsi, rcx
    movzx rdi, byte [rsi]

    mov rsi, quad_buffer
    mov ecx, r10d
    imul ecx, 100
    add ecx, r11d
    add rsi, rcx
    movzx rsi, byte [rsi]

    mov r9d, [col_var]
    shl r9, 1

    mov rcx, r8
    imul rcx, 200
    add rcx, r9
    mov rdx, interp_buffer
    add rdx, rcx
    mov [rdx], r14b

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

    ; (5) Crear imagen_out.img
    mov rax, 2
    mov rdi, fname_out
    mov rsi, 577   ; O_WRONLY|O_CREAT|O_TRUNC
    mov rdx, 420   ; 0644
    syscall
    cmp rax, 0
    js error_open_out
    mov rbx, rax

    ; write => 200*200
    mov rax, 1
    mov rdi, rbx
    mov rsi, interp_buffer
    mov rdx, 200*200
    syscall
    cmp rax, 0
    js error_write_out

    ; close
    mov rax, 3
    mov rdi, rbx
    syscall

    ; (6) Convertir quadrant => "7\n"
    mov eax, [quadrant]
    call parse_quadrant_to_ascii

    ; [DEBUG] Imprimir en consola el debug_msg y el contenido de quad_msg_buffer
    ; "quad_msg_buffer="
    mov rax, 1
    mov rdi, 1
    mov rsi, debug_msg
    mov rdx, debug_msg_end - debug_msg
    syscall

    ; luego quad_msg_buffer
    mov rax, 1
    mov rdi, 1
    mov rsi, quad_msg_buffer
    mov rdx, 16
    syscall

    ; salto de linea
    mov rax, 1
    mov rdi, 1
    mov rsi, new_line
    mov rdx, 1
    syscall

    ; Calcular longitud => strlength
    mov rdi, quad_msg_buffer
    call strlength
    mov rcx, rax

    ; [DEBUG] Imprimir debug_len + el valor en hex
    mov rax, 1
    mov rdi, 1
    mov rsi, debug_len
    mov rdx, debug_len_end - debug_len
    syscall

    mov rdi, rcx
    call print_hex

    ; new line
    mov rax, 1
    mov rdi, 1
    mov rsi, new_line
    mov rdx, 1
    syscall

    ; Abrir quad.txt
    mov rax, 2
    mov rdi, fname_quad
    mov rsi, 577
    mov rdx, 420
    syscall
    cmp rax, 0
    js error_open_quad
    mov rbx, rax

    ; write => quad_msg_buffer, rcx
    mov rax, 1
    mov rdi, rbx
    mov rsi, quad_msg_buffer
    mov rdx, rcx
    syscall
    cmp rax, 0
    js error_write_quad

    ; close
    mov rax, 3
    mov rdi, rbx
    syscall

    ; (7) Checksum sub-bloque e interpolado
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

    ; Interpolado
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

    ; Imprimir bytes leidos
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_bytes_read
    mov rdx, msg_bytes_read_end - msg_bytes_read
    syscall

    mov rdi, [read_count]
    call print_hex

    ; new line
    mov rax, 1
    mov rdi, 1
    mov rsi, new_line
    mov rdx, 1
    syscall

    ; "Checksum sub-bloque (hex): 0x"
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_checksum_sub
    mov rdx, msg_checksum_sub_end - msg_checksum_sub
    syscall

    mov rdi, r12
    call print_hex

    ; new line
    mov rax, 1
    mov rdi, 1
    mov rsi, new_line
    mov rdx, 1
    syscall

    ; "Checksum imagen interpolada (hex): 0x"
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_checksum_interp
    mov rdx, msg_checksum_interp_end - msg_checksum_interp
    syscall

    mov rdi, r13
    call print_hex

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

; -------------------------------------------------------------------------
; read_quadrant_in_loop
; -------------------------------------------------------------------------
read_quadrant_in_loop:
    push rbp
    mov rbp, rsp

.ask_loop:
    ; "Ingrese el cuadrante (1..16):"
    mov rax, 1
    mov rdi, 1
    mov rsi, prompt_quad
    mov rdx, prompt_quad_end - prompt_quad
    syscall

    mov rax, 0
    mov rdi, 0
    mov rsi, quad_input
    mov rdx, 3
    syscall

    call parse_quadrant

    mov eax, [quadrant]
    cmp eax, 1
    jl .error
    cmp eax, 16
    jg .error
    leave
    ret

.error:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_invalid
    mov rdx, msg_invalid_end - msg_invalid
    syscall
    jmp .ask_loop

; -------------------------------------------------------------------------
; parse_quadrant: conv a entero => quadrant=0 si inval
; -------------------------------------------------------------------------
parse_quadrant:
    push rbp
    mov rbp, rsp

    mov rsi, quad_input
    xor r8, r8

    mov al, [rsi]
    cmp al, 10
    je .no_digits
    sub al, '0'
    cmp al, 9
    ja .not_digit
    mov r8, rax

    mov al, [rsi+1]
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

; -------------------------------------------------------------------------
; parse_quadrant_to_ascii: EAX => 1..16 => "7\n"
; -------------------------------------------------------------------------
parse_quadrant_to_ascii:
    push rbp
    mov rbp, rsp

    ; Limpia
    mov rdi, quad_msg_buffer
    mov rcx, 16
.clear_loop:
    mov byte [rdi + rcx - 1], 0
    loop .clear_loop

    mov r8d, eax
    mov rdi, quad_msg_buffer

    cmp r8d, 9
    jle .one_digit

    ; 2 digitos
    xor edx, edx
    mov eax, r8d
    mov ebx, 10
    div ebx
    add eax, '0'
    mov [rdi], al
    inc rdi

    add dl, '0'
    mov [rdi], dl
    inc rdi
    jmp .ok

.one_digit:
    add r8b, '0'
    mov [rdi], r8b
    inc rdi

.ok:
    mov byte [rdi], 10
    inc rdi
    mov byte [rdi], 0

    leave
    ret

; -------------------------------------------------------------------------
; strlength => RAX = len
; RDI => puntero
; -------------------------------------------------------------------------
strlength:
    push rbp
    mov rbp, rsp

    xor rax, rax
.loop_len:
    mov bl, [rdi]
    cmp bl, 0
    je .done
    inc rax
    inc rdi
    jmp .loop_len
.done:
    leave
    ret

; -------------------------------------------------------------------------
; print_hex: imprime RDI en hex 16 digitos
; -------------------------------------------------------------------------
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
    add rbx, 55
    jmp .store_char
.digit0_9:
    add rbx, 48
.store_char:
    mov byte [rsi + rcx - 1], bl
    shr rax, 4
    loop .hex_conv

    mov rax, 1
    mov rdi, 1
    mov rdx, 16
    syscall

    add rsp, 16
    pop rbx
    leave
    ret

; Manejo errores
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

error_open_quad:
    mov rax, 60
    mov rdi, 15
    syscall

error_write_quad:
    mov rax, 60
    mov rdi, 16
    syscall

