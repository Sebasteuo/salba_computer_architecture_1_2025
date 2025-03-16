[bits 64]
default rel

global _start

section .data
    ; Nombre del archivo
    filename db "imagen_in.img", 0

    ; Mensaje para imprimir la cantidad leída
    msg_bytes_read db "Bytes leidos (hex): 0x", 0
msg_bytes_read_end:

    ; Salto de línea
    new_line db 10, 0

section .bss
    ; Buffer para leer hasta 160000 bytes
    buffer      resb 400*400

    ; Para almacenar la cantidad de bytes realmente leídos
    read_count  resq 1

section .text

; -------------------------------------------------------------------------
; _start
; Solo Fase 1:
; 1) Abrir imagen_in.img
; 2) Leer hasta 160000 bytes en buffer
; 3) Guardar la cantidad leída
; 4) Cerrar el archivo
; 5) Imprimir la cantidad leída en hex
; 6) exit(0)
; -------------------------------------------------------------------------
_start:
    ; Ajuste de la pila a 16 bytes (opcional pero suele mantenerse)
    sub rsp, 8

    ; (1) Abrir => syscall open(filename, O_RDONLY, 0)
    mov rax, 2               ; __NR_open
    mov rdi, filename
    xor rsi, rsi             ; O_RDONLY
    xor rdx, rdx
    syscall
    cmp rax, 0
    js  error_open
    mov rbx, rax             ; Guardar FD en rbx

    ; (2) Leer => syscall read(fd, buffer, 160000)
    mov rax, 0               ; __NR_read
    mov rdi, rbx
    mov rsi, buffer
    mov rdx, 400*400         ; 160000
    syscall
    cmp rax, 0
    js  error_read
    mov [read_count], rax    ; Almacenar bytes leídos

    ; (3) Cerrar => syscall close(fd)
    mov rax, 3               ; __NR_close
    mov rdi, rbx
    syscall

    ; (4) Imprimir "Bytes leidos (hex): 0x"
    mov rax, 1               ; __NR_write
    mov rdi, 1               ; STDOUT
    mov rsi, msg_bytes_read
    mov rdx, msg_bytes_read_end - msg_bytes_read
    syscall

    ; (5) Imprimir el valor de read_count en hex
    mov rax, [read_count]
    ; Se hace un buffer local de 16 bytes en la pila para imprimir 64 bits en hex.
    sub rsp, 16
    mov rsi, rsp

    ; Llenar de '0'
    mov rcx, 16
fill_loop:
    mov byte [rsi + rcx - 1], '0'
    loop fill_loop

    ; Convertir 64 bits -> 16 dígitos hex
    mov rcx, 16
conv_loop:
    mov rbx, rax
    and rbx, 0xF
    cmp rbx, 10
    jb  .digit0_9
    add rbx, 55      ; 'A' - 10
    jmp .store_char
.digit0_9:
    add rbx, 48      ; '0'
.store_char:
    mov byte [rsi + rcx - 1], bl
    shr rax, 4
    loop conv_loop

    ; write(1, rsi, 16)
    mov rax, 1
    mov rdi, 1
    mov rdx, 16
    syscall

    add rsp, 16

    ; Salto de línea
    mov rax, 1
    mov rdi, 1
    mov rsi, new_line
    mov rdx, 1
    syscall

    ; (6) exit(0)
    mov rax, 60      ; __NR_exit
    xor rdi, rdi
    syscall

; -------------------------------------------------------------------------
; Manejo de errores
; -------------------------------------------------------------------------
error_open:
    mov rax, 60      ; exit(1)
    mov rdi, 1
    syscall

error_read:
    mov rax, 60      ; exit(2)
    mov rdi, 2
    syscall
