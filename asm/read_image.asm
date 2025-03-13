; =========================================================================
; read_image.asm
; =========================================================================
; Objetivo:
;   - Abrir un archivo .img en modo lectura.
;   - Leer su contenido en un buffer (hasta 64 KB).
;   - Almacenar la cantidad de bytes leídos en memoria.
;   - Imprimir un mensaje "BYTES: " más la cantidad leída (en formato decimal).
;   - Realizar una verificación interna comparando la cantidad leída
;     con el valor 16, imprimiendo un mensaje adicional.
; 
; Ambiente:
;   - Linux x86_64 (64 bits).
;   - Uso de syscalls: open (2), read (0), close (3), write (1), exit (60).
; 
; Ensamblar y linkear (en Linux):
;   nasm -f elf64 read_image.asm -o read_image.o
;   ld read_image.o -o read_image
; 
; Uso (en la misma carpeta):
;   echo "Pruebas" > imagen_in.img   ; archivo .img de ejemplo
;   ./read_image
; =========================================================================

global _start

section .data
    filename db "imagen_in.img", 0              ; Nombre del archivo a leer
    msg db "BYTES: ", 0                         ; Mensaje base de salida
    newline db 10, 0                            ; Salto de línea
    zero_char db '0'                            ; Carácter '0'
    space_char db ' ', 0                        ; Carácter de espacio

    ; Mensajes para verificación de la cantidad leída
    msg_is_16 db "Verificacion interna (memoria): Se leyeron efectivamente 16 bytes!", 0
    len_is_16 equ $ - msg_is_16

    msg_is_other db "Verificacion interna (memoria): Se leyo un valor distinto de 16 bytes", 0
    len_is_other equ $ - msg_is_other

section .bss
    buffer resb 65536      ; Buffer para almacenar datos leídos (hasta 64 KB)
    buffer_digits resb 32  ; Espacio para almacenar dígitos al convertir la cantidad a decimal
    digit_temp resb 1      ; Un byte auxiliar para impresión de cada dígito
    read_count resq 1      ; Variable en memoria para guardar la cantidad leída

section .text

; -------------------------------------------------------------------------
; _start: punto de entrada del programa
; -------------------------------------------------------------------------
_start:
    ; 1) Abrir archivo (syscall open, número 2)
    mov rax, 2          ; __NR_open
    mov rdi, filename
    mov rsi, 0          ; O_RDONLY
    mov rdx, 0
    syscall
    cmp rax, 0
    js error_open
    mov rbx, rax        ; Se guarda el file descriptor en rbx

    ; 2) Leer el archivo (syscall read, número 0)
    mov rax, 0          ; __NR_read
    mov rdi, rbx        ; file descriptor
    mov rsi, buffer
    mov rdx, 65536      ; máximo de lectura (64 KB)
    syscall
    cmp rax, 0
    js error_read

    ; Se almacena la cantidad leída en memoria (read_count)
    mov [read_count], rax

    ; 3) Cerrar el archivo (syscall close, número 3)
    mov rax, 3
    mov rdi, rbx
    syscall

    ; 4) Imprimir el mensaje base "BYTES: "
    mov rax, 1          ; __NR_write
    mov rdi, 1          ; stdout
    mov rsi, msg
    mov rdx, 7          ; longitud de "BYTES: "
    syscall

    ; 5) Imprimir en decimal la cantidad leída (usando la rutina print_r8_decimal)
    ;    Se lee el valor desde memoria para evitar alteraciones en registros
    mov rax, [read_count]
    mov r8, rax
    push r8
    call print_r8_decimal

    ; 6) Imprimir salto de línea
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall

    ; 7) Verificar internamente si read_count == 16
    mov rax, [read_count]
    cmp rax, 16
    jne not_sixteen_mem

    ; Caso en que es 16
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_is_16
    mov rdx, len_is_16
    syscall
    jmp done_check_mem

not_sixteen_mem:
    ; Caso en que difiere de 16
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_is_other
    mov rdx, len_is_other
    syscall

done_check_mem:
    ; 8) Finalizar el programa (syscall exit, número 60)
    mov rax, 60
    xor rdi, rdi
    syscall

; -------------------------------------------------------------------------
; error_open: termina con código 1 si no se puede abrir
; -------------------------------------------------------------------------
error_open:
    mov rax, 60
    mov rdi, 1
    syscall

; -------------------------------------------------------------------------
; error_read: termina con código 2 si no se puede leer
; -------------------------------------------------------------------------
error_read:
    mov rax, 60
    mov rdi, 2
    syscall

; -------------------------------------------------------------------------
; print_r8_decimal
; Convierte en decimal el valor en r8 y lo imprime por stdout,
; añadiendo un espacio tras cada dígito para mayor claridad.
; -------------------------------------------------------------------------
print_r8_decimal:
    push rbp
    mov rbp, rsp

    cmp r8, 0
    jne .convert
    ; Caso especial: valor 0
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
    div rdi               ; divide rax entre 10 -> cociente rax, residuo rdx
    add rdx, '0'          ; convierte residuo [0..9] a ASCII
    mov [rcx], dl         ; almacena el dígito ASCII
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
