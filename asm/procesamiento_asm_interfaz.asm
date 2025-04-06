; ****************************************************************************
; procesamiento_asm_interfaz.asm
;
; Demostración: 
;  - Define _start (ASM puro), lee config.txt (ruta imagen + cuadrante),
;  - procesa imagen 400x400 => extrae sub-bloque 100x100 => interpola a 200x200
;  - guarda en imagen_out.img, calcula checksums y los imprime,
;  - luego abre ventana X11 (200x200) y muestra la imagen interpolada (escala gris).
;
; Para enlazar dinámicamente con X11, se requiere -lX11 -lc --dynamic-linker ...
; ****************************************************************************

[bits 64]
default rel

global _start

; --- Declaraciones EXTERN de funciones X11 que usaremos ---
extern XOpenDisplay
extern XDefaultScreen
extern XDefaultDepth
extern XDefaultVisual
extern XCreateSimpleWindow
extern XSelectInput
extern XMapWindow
extern XNextEvent
extern XDestroyWindow
extern XCloseDisplay
extern XCreateImage
extern XPutImage

; ---------------------------------------------------------------------------
section .data

    ; Nombres de archivo
    fname_out       db "imagen_out.img", 0
    fname_config    db "config.txt", 0

    ; Mensajes
    msg_bytes_read  db "Bytes leidos (hex): 0x", 0
    msg_bytes_read_end:

    msg_checksum_sub db "Checksum sub-bloque (hex): 0x", 0
    msg_checksum_sub_end:

    msg_checksum_interp db "Checksum imagen interpolada (hex): 0x", 0
    msg_checksum_interp_end:

    msg_done db "Procesamiento finalizado. Se genero imagen_out.img", 10, 0
    msg_done_end:

    new_line db 10, 0

    msg_error_config db "Error: config.txt malescrito o cuadrante invalido.", 10, 0
    msg_error_config_end:

    ; Mensaje de error al abrir display X11
    msg_x11_error db "Error al abrir Display X11", 10, 0
    msg_x11_error_len equ $ - msg_x11_error

    ; Constantes de X11: máscaras de eventos
    ExposureMask         equ 0x000080
    KeyPressMask         equ 0x000004
    StructureNotifyMask  equ 0x000200

    ; Tipos de eventos que nos interesan
    Expose       equ 12
    KeyPress     equ 2
    DestroyNotify equ 17
    ClientMessage equ 33

; ---------------------------------------------------------------------------
section .bss

    ; Buffers y variables
    buffer          resb 400*400      ; 160,000 bytes => imagen original (400x400)
    quad_buffer     resb 100*100      ; 10,000 bytes => sub-bloque
    interp_buffer   resb 200*200      ; 40,000 bytes => imagen interpolada
    x11_bgra_buffer resb 200*200*4    ; 160,000 bytes => BGRA para X11

    read_count      resq 1
    quadrant        resd 1
    row_var         resd 1
    col_var         resd 1

    config_buffer   resb 256
    path_buffer     resb 240
    quad_input      resb 4

; ---------------------------------------------------------------------------
section .text

; =============================================================================
; _start
; =============================================================================
_start:
    ; Ajustar la pila a 16 bytes (System V ABI requiere RSP % 16 == 0 al hacer 'call')
    ; Después de 'call', el hardware resta 8 al stack (retaddr), quedando alineado a 16.
    ; Para seguridad, hacemos:
    sub rsp, 8

    ; (1) Leer config.txt => path + quadrant
    call read_config_from_file

    ; (2) Abrir y leer la imagen (400x400)
    mov rax, 2               ; sys_open
    mov rdi, path_buffer
    xor rsi, rsi             ; O_RDONLY
    xor rdx, rdx
    syscall
    cmp rax, 0
    js error_open_in
    mov rbx, rax             ; descriptor

    mov rax, 0               ; sys_read
    mov rdi, rbx
    mov rsi, buffer
    mov rdx, 400*400
    syscall
    cmp rax, 0
    js error_read_in
    mov [read_count], rax

    mov rax, 3               ; sys_close
    mov rdi, rbx
    syscall

    ; (3) Extraer sub-bloque 100x100 (según quadrant)
    mov eax, [quadrant]
    dec eax
    xor edx, edx
    mov edi, 4
    div edi
    mov r14, rax   ; fila
    mov r15, rdx   ; columna

    mov r12, 100
    mov r13, 100
    imul r15, r12
    imul r14, r13
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
    xor eax, eax
    mov [row_var], eax

    ; (4) Interpolar (100x100) => (200x200)
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
    jl ok_rplus
    jmp no_rplus

ok_rplus:
    add r10d, 1
no_rplus:
    mov r11d, [col_var]
    cmp r11d, 99
    jl ok_cplus
    jmp no_cplus

ok_cplus:
    add r11d, 1

no_cplus:
    ; A,B,C,D
    mov eax, [row_var]
    mov edx, [col_var]
    mov rsi, quad_buffer

    mov ecx, eax
    imul ecx, 100
    add ecx, edx
    add rsi, rcx
    movzx r14, byte [rsi]    ; A

    mov rsi, quad_buffer
    mov ecx, r10d
    imul ecx, 100
    add ecx, edx
    add rsi, rcx
    movzx r15, byte [rsi]    ; B

    mov rsi, quad_buffer
    mov ecx, eax
    imul ecx, 100
    add ecx, r11d
    add rsi, rcx
    movzx rdi, byte [rsi]    ; C

    mov rsi, quad_buffer
    mov ecx, r10d
    imul ecx, 100
    add ecx, r11d
    add rsi, rcx
    movzx rsi, byte [rsi]    ; D

    mov r9d, [col_var]
    shl r9, 1

    ; (row*2, col*2) = A
    mov rcx, r8
    imul rcx, 200
    add rcx, r9
    mov rdx, interp_buffer
    add rdx, rcx
    mov [rdx], r14b

    ; (row*2+1, col*2) = (3A + B)/4
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

    ; (row*2, col*2+1) = (3A + C)/4
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

    ; (row*2+1, col*2+1) = (A + B + C + D)/4
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
    ; (5) Crear/Guardar imagen => "imagen_out.img"
    mov rax, 2
    mov rdi, fname_out
    mov rsi, 577            ; O_WRONLY|O_CREAT|O_TRUNC
    mov rdx, 420            ; 0644
    syscall
    cmp rax, 0
    js error_open_out
    mov rbx, rax

    mov rax, 1              ; sys_write
    mov rdi, rbx
    mov rsi, interp_buffer
    mov rdx, 200*200
    syscall
    cmp rax, 0
    js error_write_out

    mov rax, 3              ; sys_close
    mov rdi, rbx
    syscall

    ; (6) Checksums
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

    ; (7) Imprimir checksums
    ; (a) Bytes leidos
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_bytes_read
    mov rdx, msg_bytes_read_end - msg_bytes_read
    syscall

    mov rdi, [read_count]
    call print_hex

    mov rax, 1
    mov rdi, 1
    mov rsi, new_line
    mov rdx, 1
    syscall

    ; (b) Sub-bloque
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_checksum_sub
    mov rdx, msg_checksum_sub_end - msg_checksum_sub
    syscall

    mov rdi, r12
    call print_hex

    mov rax, 1
    mov rdi, 1
    mov rsi, new_line
    mov rdx, 1
    syscall

    ; (c) Interpolado
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

    ; Llamar a la función que abre la ventana X11 y muestra la imagen
    call display_image_in_window

    ; exit(0)
    mov rax, 60
    xor rdi, rdi
    syscall


; ============================================================================
; read_config_from_file: Lee config.txt => path_buffer y quadrant
; ============================================================================
read_config_from_file:
    push rbp
    mov rbp, rsp

    mov rax, 2
    mov rdi, fname_config
    xor rsi, rsi
    xor rdx, rdx
    syscall
    cmp rax, 0
    js  error_open_config
    mov rbx, rax

    mov rax, 0
    mov rdi, rbx
    mov rsi, config_buffer
    mov rdx, 256
    syscall
    cmp rax, 0
    js  error_read_config

    mov rax, 3
    mov rdi, rbx
    syscall

    xor rcx, rcx
    xor rdx, rdx

find_path_loop:
    mov al, [config_buffer + rcx]
    cmp al, 0
    je error_bad_config
    cmp al, 10
    je end_path
    mov [path_buffer + rdx], al
    inc rcx
    inc rdx
    cmp rdx, 240
    jae error_bad_config
    jmp find_path_loop

end_path:
    mov byte [path_buffer + rdx], 0
    inc rcx
    xor rdx, rdx

next_line_loop:
    mov al, [config_buffer + rcx]
    cmp al, 0
    je maybe_ok
    cmp al, 10
    je end_quad
    mov [quad_input + rdx], al
    inc rcx
    inc rdx
    cmp rdx, 3
    jae end_quad
    jmp next_line_loop

end_quad:
    mov byte [quad_input + rdx], 0

maybe_ok:
    call parse_quadrant
    mov eax, [quadrant]
    cmp eax, 1
    jl error_range
    cmp eax, 16
    jg error_range

    leave
    ret

error_bad_config:
error_range:
fail_config:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_error_config
    mov rdx, msg_error_config_end - msg_error_config
    syscall
    mov rax, 60
    mov rdi, 1
    syscall

error_open_config:
    mov rax, 60
    mov rdi, 17
    syscall

error_read_config:
    mov rax, 60
    mov rdi, 18
    syscall


; ============================================================================
; parse_quadrant: quad_input (ASCII) => [quadrant] (1..16)
; ============================================================================
parse_quadrant:
    push rbp
    mov rbp, rsp

    mov rsi, quad_input
    xor r8, r8

    mov al, [rsi]
    cmp al, 0
    je no_digits
    sub al, '0'
    cmp al, 9
    ja not_digit
    mov r8, rax

    mov al, [rsi+1]
    cmp al, 0
    je ok_parse
    cmp al, 10
    je ok_parse
    sub al, '0'
    cmp al, 9
    ja not_digit

    imul r8, r8, 10
    add r8, rax
    jmp ok_parse

not_digit:
    mov dword [quadrant], 0
    jmp done_parse

no_digits:
    mov dword [quadrant], 0
    jmp done_parse

ok_parse:
    mov [quadrant], r8d

done_parse:
    leave
    ret


; ============================================================================
; print_hex: Imprime el valor en RDI en formato hex (64 bits, 16 dígitos)
; ============================================================================
print_hex:
    push rbp
    mov rbp, rsp

    push rbx
    sub rsp, 16

    mov rax, rdi         ; valor
    mov rsi, rsp         ; buffer local
    mov rcx, 16          ; 16 dígitos

fill_loop:
    mov byte [rsi + rcx - 1], '0'
    loop fill_loop

    mov rcx, 16
hex_conv:
    mov rbx, rax
    and rbx, 0xF
    cmp rbx, 10
    jb digit0_9
    add rbx, 55          ; 'A'..'F'
    jmp store_char

digit0_9:
    add rbx, 48          ; '0'..'9'

store_char:
    mov byte [rsi + rcx - 1], bl
    shr rax, 4
    loop hex_conv

    mov rax, 1           ; sys_write
    mov rdi, 1
    mov rdx, 16
    syscall

    add rsp, 16
    pop rbx
    leave
    ret


; ============================================================================
; Manejo de errores sys_open/sys_read/sys_write
; ============================================================================
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


; ============================================================================
; display_image_in_window:
;   - Abre XOpenDisplay
;   - Crea ventana 200x200 con XCreateSimpleWindow
;   - Convierte interp_buffer => x11_bgra_buffer (BGRA)
;   - XCreateImage + XPutImage
;   - Espera evento (tecla/cerrar) => cierra
; ============================================================================
display_image_in_window:
    push rbp
    mov rbp, rsp

    ; =====================================================
    ; 1) XOpenDisplay(NULL)
    ; =====================================================
    ; Alinear (por si hay SSE en XOpenDisplay)
    sub rsp, 8         ; ahora RSP % 16 == 0

    xor rdi, rdi
    call XOpenDisplay

    add rsp, 8         ; restaurar
    cmp rax, 0
    jne x11_ok_display

    ; Error => imprime msg
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_x11_error
    mov rdx, msg_x11_error_len
    syscall
    jmp x11_done

x11_ok_display:
    mov rbx, rax   ; display en rbx

    ; =====================================================
    ; 2) XDefaultScreen(display)
    ; =====================================================
    sub rsp, 8
    mov rdi, rbx
    call XDefaultScreen
    add rsp, 8
    mov r12, rax   ; screen

    ; XDefaultDepth(display, screen)
    sub rsp, 8
    mov rdi, rbx
    mov rsi, r12
    call XDefaultDepth
    add rsp, 8
    mov r13, rax   ; depth

    ; XDefaultVisual(display, screen)
    sub rsp, 8
    mov rdi, rbx
    mov rsi, r12
    call XDefaultVisual
    add rsp, 8
    mov r14, rax   ; visual*

    ; =====================================================
    ; 3) XCreateSimpleWindow(display, parent=0, 0,0, 200,200, 0,0,0)
    ;    => 9 argumentos
    ; =====================================================
    ;   7mo=border_width, 8vo=border, 9no=background => push en orden inverso
    ;   1) rdi=display, 2) rsi=parent, 3) rdx=x, 4)rcx=y, 5)r8=width, 6)r9=height
    ;   => call
    sub rsp, 8   ; alinear => RSP % 16 == 0
    push qword 0 ; background
    push qword 0 ; border
    push qword 0 ; border_width

    mov rdi, rbx ; display
    xor rsi, rsi ; parent=0
    xor rdx, rdx ; x=0
    xor rcx, rcx ; y=0
    mov r8, 200  ; width=200
    mov r9, 200  ; height=200

    call XCreateSimpleWindow

    add rsp, 24  ; 3 pushes = 24 bytes
    add rsp, 8   ; restaurar la alineacion
    mov r15, rax ; window

    ; XSelectInput(display, window, masks)
    sub rsp, 8
    mov rdi, rbx
    mov rsi, r15
    mov rdx, KeyPressMask | ExposureMask | StructureNotifyMask
    call XSelectInput
    add rsp, 8

    ; XMapWindow(display, window)
    sub rsp, 8
    mov rdi, rbx
    mov rsi, r15
    call XMapWindow
    add rsp, 8

    ; =====================================================
    ; 4) Convertir interp_buffer => x11_bgra_buffer (BGRA)
    ; =====================================================
    xor r8, r8
conv_rows_label:
    cmp r8, 200
    jge conv_done_label
    xor r9, r9
conv_cols_label:
    cmp r9, 200
    jge end_conv_cols_label

    mov rax, r8
    imul rax, 200
    add rax, r9
    mov rsi, interp_buffer
    add rsi, rax
    xor rax, rax
    mov al, [rsi]  ; pixel gris

    mov rdi, x11_bgra_buffer
    mov r10, r8
    imul r10, 200
    add r10, r9
    imul r10, 4
    add rdi, r10

    mov [rdi], al       ; B
    mov [rdi+1], al     ; G
    mov [rdi+2], al     ; R
    mov byte [rdi+3], 0xFF  ; A=255

    inc r9
    jmp conv_cols_label

end_conv_cols_label:
    inc r8
    jmp conv_rows_label

conv_done_label:

    ; =====================================================
    ; 5) XCreateImage (10 args)
    ;   XCreateImage(dpy,visual,depth,format,offset,data,w,h,pad,bpl)
    ; =====================================================
    ;  - Los 6 primeros van en rdi,rsi,rdx,rcx,r8,r9
    ;  - Los 4 restantes a la pila en orden inverso
    ;
    ; Queremos:
    ;   dpy=rbx, visual=r14, depth=r13, format=2 (ZPixmap),
    ;   offset=0, data=x11_bgra_buffer,
    ;   w=200,h=200, pad=32, bpl=800
    sub rsp, 8              ; alineación
    push qword 800          ; bytes_per_line
    push qword 32           ; pad
    push qword 200          ; height
    push qword 200          ; width

    mov rdi, rbx            ; dpy
    mov rsi, r14            ; visual
    mov rdx, r13            ; depth
    mov rcx, 2              ; format=ZPixmap
    xor r8, r8              ; offset=0
    mov r9, x11_bgra_buffer ; data

    call XCreateImage
    add rsp, 32
    add rsp, 8
    cmp rax, 0
    je x11_done
    mov rsi, rax   ; ximage*

    ; =====================================================
    ; 6) XPutImage (10 args):
    ;   XPutImage(dpy,drawable,gc,ximage,src_x,src_y,dst_x,dst_y,width,height)
    ; =====================================================
    ;  - 6 primeros: rdi,dpy / rsi,drawable / rdx,gc / rcx,ximage / r8,src_x / r9,src_y
    ;  - 4 en la pila: (dst_x, dst_y, width, height) en orden inverso
    sub rsp, 8              ; alinear
    push qword 200          ; height
    push qword 200          ; width
    push qword 0            ; dst_y
    push qword 0            ; dst_x

    mov rdi, rbx            ; display
    mov rsi, r15            ; drawable (la window)
    xor rdx, rdx            ; GC=0
    mov rcx, rsi            ; OJO: rsi ya la usamos... CUIDADO: a ver...
    ; Aquí, debemos tener ximage en un registro. Lo guardamos en rax o rsi. 
    ; Arriba mov rsi, rax => ximage
    ; Pero ahora en "mov rsi, r15" (window), hemos machacado rsi.
    ; => Necesitamos ximage en, digamos, rax. 
    ; Ajustemos: 
    ;   mov rax, rsi ; ximage => rax
    ;   mov rsi, r15 ; window
    ; => y rcx=rax

    ; Lo haremos:
    mov rax, rsi    ; rax = XImage*
    mov rsi, r15    ; window
    mov rcx, rax    ; ximage

    xor r8, r8      ; src_x=0
    xor r9, r9      ; src_y=0

    call XPutImage
    add rsp, 32
    add rsp, 8

    ; =====================================================
    ; 7) Bucle de eventos: XNextEvent -> si KeyPress/Destroy => salir
    ; =====================================================
event_loop:
    ; XNextEvent(display, &event)
    ; => 2 args => rdi=display, rsi=&event
    ; Guardaremos 64 bytes en la pila para XEvent
    sub rsp, 8   ; alinear
    sub rsp, 64  ; reservamos 64 para XEvent
    mov rdi, rbx
    mov rsi, rsp
    call XNextEvent
    add rsp, 64
    add rsp, 8

    ; type = [rsp]? Hemos hecho 'add rsp,64' antes de leer. 
    ; => Debimos leerlo ANTES de "add rsp,64". 
    ; Lo lógico es: 
    ;   sub rsp,8 -> align
    ;   sub rsp,64 -> space 
    ;   call XNextEvent
    ;   mov eax, [rsp] => type
    ;   ...
    ;   add rsp,64
    ;   add rsp,8
    ; => Veámoslo bien. Ajustemos:

    ;  => Repetimos:
    sub rsp, 8
    sub rsp, 64
    mov rdi, rbx
    mov rsi, rsp
    call XNextEvent
    ; leer event.xany.type en [rsp]
    mov eax, [rsp]
    add rsp, 64
    add rsp, 8

    cmp eax, KeyPress
    je exit_loop
    cmp eax, DestroyNotify
    je exit_loop
    cmp eax, ClientMessage
    je exit_loop

    jmp event_loop

exit_loop:
    ; 8) Cerrar ventana y display
    sub rsp, 8
    mov rdi, rbx
    mov rsi, r15
    call XDestroyWindow
    add rsp, 8

    sub rsp, 8
    mov rdi, rbx
    call XCloseDisplay
    add rsp, 8

x11_done:
    leave
    ret

