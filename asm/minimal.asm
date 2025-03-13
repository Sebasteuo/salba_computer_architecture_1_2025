; minimal.asm
; Código mínimo que sólo coloca 16 en r8 y sale.

global _start

section .text
_start:
    ; Poner 16 en r8
    mov r8, 16

    ; Hacer una syscall exit(0) para salir
    mov rax, 60   ; __NR_exit
    xor rdi, rdi  ; exit code = 0
    syscall
