; **************************************************************************************************************************************************
; (x86_64, NASM)
; Lee la ruta de la imagen + cuadrante desde config.txt, procesa una imagen
; de 400x400, extrae un sub-bloque 100x100, interpola a 200x200 y genera
; imagen_out.img.
; **************************************************************************************************************************************************

[bits 64]               ; Usaremos instrucciones e interfaces de 64 bits
default rel             ; Activamos direccionamiento  por defecto (recomendado en x86_64)

global _start           ; Define el símbolo _start como global para que sea el punto de entrada




; *****************************************************************SECTION.DATA***************************************************************
; Datos estáticos (para variables inmutables o inicializadas)
; **********************************************************************************************************************************************

section .data           

    fname_out db "imagen_out.img", 0           ;  Cadena terminada en 0 que contiene el nombre del archivo de salida

    fname_config db "config.txt", 0            ;  Cadena terminada en 0 para el nombre del archivo de configuración

    ; Mensajes para imprimir en pantalla
    msg_bytes_read db "Bytes leidos (hex): 0x", 0
    
    msg_bytes_read_end:                        ;  Etiqueta que sirve para calcular el tamaño de la cadena anterior

    msg_checksum_sub db "Checksum sub-bloque (hex): 0x", 0
    
    msg_checksum_sub_end:                      ;  Etiqueta para medir el tamaño de msg_checksum_sub

    msg_checksum_interp db "Checksum imagen interpolada (hex): 0x", 0
    
    msg_checksum_interp_end:                   ;  Etiqueta para medir el tamaño de msg_checksum_interp

    msg_done db "Procesamiento finalizado. Se genero imagen_out.img", 10, 0          ;  Mensaje final con salto de línea (10 en ASCII) + terminador 0
    
    msg_done_end:                              ;  Etiqueta para calcular longitud de msg_done

    new_line db 10, 0                          ;  Cadena con un único carácter: salto de línea (10) + terminador 0

    msg_error_config db "Error: config.txt malescrito o cuadrante invalido.", 10, 0  ;Mensaje de error si el config.txt está mal formateado o el cuadrante es inválido
    
    msg_error_config_end:                      ; ^ Etiqueta para calcular tamaño de msg_error_config
    
    
    
    
    
; *******************************************************************SECCIÓN .BSS*************************************************************
; Reserva de espacio en memoria sin inicializar
; **********************************************************************************************************************************************


section .bss            

    buffer          resb 400*400       ;  Buffer de 160000 bytes (400x400) para almacenar la imagen completa

    quad_buffer     resb 100*100       ;  Buffer de 10000 bytes (100x100) para el sub-bloque según el cuadrante

    interp_buffer   resb 200*200       ;  Buffer de 40000 bytes (200x200) para la imagen resultante de la interpolación

    read_count      resq 1             ;  Variable (8 bytes) para almacenar la cantidad de bytes leídos de la imagen original

    quadrant        resd 1             ;  Variable (4 bytes) que contendrá el cuadrante (1..16) leído de config.txt

    row_var         resd 1             ;  Variable (4 bytes) auxiliar para iterar sobre filas en la interpolación

    col_var         resd 1             ;  Variable (4 bytes) auxiliar para iterar sobre columnas en la interpolación

    config_buffer   resb 256           ;  Buffer de 256 bytes para leer el contenido de config.txt

    path_buffer     resb 240           ;  Buffer de 240 bytes para guardar la ruta de la imagen leída de config.txt

    quad_input      resb 4             ;  Buffer de 4 bytes para almacenar la cadena que representa el cuadrante (p.ej., "12")
    





; *******************************************************************SECCIÓN .TEXT*************************************************************
; Código ejecutable principal
; *********************************************************************************************************************************************

section .text


; -----------------------------------------------------------------------------
; PUNTO DE COMIEZO (_start)
; -----------------------------------------------------------------------------
;   Flujo principal:
;     1) Leer config.txt => path_buffer, quadrant
;     2) Abrir/leer la imagen en buffer (400x400)
;     3) Extraer sub-bloque 100x100
;     4) Interpolar => 200x200
;     5) Guardar en imagen_out.img
;     6) Calcular/Imprimir checksums y mensaje final
;     7) exit(0)
; -----------------------------------------------------------------------------

_start:
    sub rsp, 8               ; Ajuste de la pila para alineación (reservamos 8 bytes)
    
    
    
    


; **************************************************************************************************************************************************
; (1) Lectura de configuración
; **************************************************************************************************************************************************

    call read_config_from_file ; Llamada a la función que leerá config.txt con la ruta en path_buffer y el cuadrante en [quadrant]





; **************************************************************************************************************************************************
; (2) Apertura y lectura de la imagen
; **************************************************************************************************************************************************
; Abre un archivo (ruta en path_buffer), lee 160,000 bytes en "buffer" y 
; finalmente cierra el archivo. El número de bytes leídos se almacena en 
; "read_count".
; -----------------------------------------------------------------------------



    mov rax, 2               ; Indica que usaremos la syscall sys_open (abrir archivo)
    mov rdi, path_buffer     ; Nombre del archivo a abrir (primer argumento)
    xor rsi, rsi             ; Flags = 0 => O_RDONLY (lectura)
    xor rdx, rdx             ; Modo no aplica para lectura, se deja en 0
    syscall                  ; Llama al sistema operativo para abrir el archivo
    cmp rax, 0               ; Compara lo devuelto con 0
    js error_open_in         ; Si es negativo, hubo error al abrir -> saltar a "error_open_in"
    mov rbx, rax             ; Almacena el descriptor de archivo en rbx

    mov rax, 0               ; Indica que usaremos la syscall sys_read (leer archivo)
    mov rdi, rbx             ; Descriptor de archivo (segundo argumento) es un número que el s.o usa para identificar el archivo abierto
    mov rsi, buffer          ; Dirección donde se almacenará lo leído (tercer argumento)
    mov rdx, 400*400         ; Número de bytes a leer (160,000 = 400*400)
    syscall                  ; Llama al sistema para leer
    cmp rax, 0               ; Verifica si la lectura fue exitosa (rax < 0 => error)
    js error_read_in         ; Si hubo error, saltar a "error_read_in"
    mov [read_count], rax    ; Guarda la cantidad de bytes realmente leídos en read_count

    mov rax, 3               ; Indica syscall sys_close (cerrar archivo)
    mov rdi, rbx             ; Descriptor de archivo a cerrar
    syscall                  ; Cierra el archivo abierto

    
    
    
    
    
; **************************************************************************************************************************************************
; (3) Extracción del sub-bloque (100x100)
; **************************************************************************************************************************************************

; A partir de la variable 'quadrant' (un número entre 1 y 16), calculamos
; la posición en una cuadrícula de 4 columnas por 4 filas. Luego convertimos
; esa posición a coordenadas en píxeles, asumiendo que cada sub-bloque mide
; 100 píxeles de ancho y 100 de alto. Por último, preparamos r8 como contador
;   - Restamos 1 para ajustar 'quadrant' a un rango 0..15.
;   - Dividimos ese valor entre 4: el cociente (eax) es la fila (r14) y el
;     resto (edx) es la columna (r15). 
;   - Luego, cada uno se multiplica por 100 para obtener la posición en píxeles.
;   - Finalmente, se limpia r8 para usarlo como contador de filas más adelante.
;
; - quadrant 1 corresponde a la fila 0, columna 0.
; - quadrant 16 corresponde a la fila 3, columna 3.
;
; EXPLICACION UN POQUITO MAS DETALLADA
; 1. Cuando el código toma la variable quadrant (un número 1..16) y la convierte en una posición de sub-bloque dentro de la imagen de 400×400, 
; está asumiendo que la imagen completa se divide en 16 sub-bloques de 100×100, organizados como una matriz de 4 filas por 4 columnas:


;      +---+---+---+---+
;      | 1 | 2 | 3 | 4 |   Fila 0
;      +---+---+---+---+
;      | 5 | 6 | 7 | 8 |   Fila 1
;      +---+---+---+---+
;      | 9 |10 |11 |12 |   Fila 2
;      +---+---+---+---+
;      |13 |14 |15 |16 |   Fila 3
;      +---+---+---+---+
;      Col0 Col1 Col2 Col3

; 2. Restar 1 ( dec eax ): El valor quadrant llega en el rango 1..16. Para usarlo como un índice 0..15, se hace quadrant - 1. Por ejemplo:
;	quadrant=1 => índice 0
;	quadrant=16 => índice 15

; 3. Dividir entre 4 ( div edi donde edi=4 ): Ahora que eax está en 0..15, se interpreta como un índice lineal en una cuadrícula de 4 columnas.
; El cociente (eax) indica la fila (0..3), y el resto (edx) indica la columna (0..3). Por ejemplo: 
;	si quadrant=7, entonces:
;				7 -1 =6.
;				6 /4 => cociente=1, resto=2. Fila=1, Col=2.
;	(Corresponde al 7º cuadrante en la cuadrícula).

; 4. Multiplicar cada uno por 100: Como ya tenemos la fila y la columna (en sub-bloques), ocupamos sus coordenadas en píxeles dentro de la imagen de 400×400.
; Cada sub-bloque tiene un tamaño de 100×100. Tonces:

;	fila * 100 => posición vertical en píxeles (offset Y).
;	col * 100 => posición horizontal en píxeles (offset X).
;	Siguiendo el ejemplo quadrant=7:
;		Fila=1 => 1×100=100 => la posición vertical arranca en el píxel 100 de la imagen.
;		Col=2 => 2×100=200 => la posición horizontal arranca en el píxel 200.
;	Esto define la esquina superior‐izquierda del sub-bloque que se va a copiar.

; 5. Limpiar r8 para usarlo como contador: se hace xor r8, r8 para dejar r8=0, de modo que se utilice en el bucle copy_rows, donde r8 representará la fila dentro del sub-bloque (0..99).


; -----------------------------------------------------------------------------

    mov eax, [quadrant]      ; Carga el valor de 'quadrant' (1..16) en eax
    dec eax                  ; Ajusta de 1..16 a 0..15 para indexar cómodamente
    xor edx, edx             ; Limpia edx antes de dividir (requisito en 64-bit div)
    mov edi, 4               ; Vamos a dividir por 4 (la cuadrícula tiene 4 columnas)
    div edi                  ; eax / 4 => eax = fila (0..3), edx = columna (0..3)
    mov r14, rax             ; r14 guarda la fila donde se ubica el bloque
    mov r15, rdx             ; r15 guarda la columna donde se ubica el bloque

    mov r12, 100             ; r12 = 100 => el ancho de cada bloque, en píxeles
    mov r13, 100             ; r13 = 100 => la altura de cada bloque, en píxeles

    imul r15, r12            ; r15 = columna * 100 => coordenada X en píxeles
    imul r14, r13            ; r14 = fila * 100    => coordenada Y en píxeles

    xor r8, r8               ; Pone r8 en cero, para usarlo como contador de filas

    
    
    
; *****************************************************************************
; copy_rows:
; Bucle externo para recorrer filas del sub-bloque.
; -----------------------------------------------------------------------------
; Copia las filas de píxeles de un sub-bloque de 100x100 dentro de la imagen 
; completa, usando los desplazamientos de fila (r14) y columna (r15) que 
; calculamos antes. El registro r8 se usa como contador de filas locales (0..99).
; 
; Proceso paso a paso:
; 1. Comprobamos si ya se han copiado todas las filas (r8 >= 100).
; 2. Calculamos en r9 el índice de la fila real en la imagen original:
;    - Partimos de r8 (fila local) y le sumamos r14 (desplazamiento de fila base).
;    - Luego multiplicamos por 400 (ancho total de la imagen).
;    - Finalmente sumamos r15 (desplazamiento de columna base).
; 3. Calculamos en r10 la posición inicial dentro del sub-bloque (también en 
;    función de la fila local y ancho sub-bloque = 100).
; 4. Ponemos r11 a cero para usarlo como contador de columnas dentro de la fila.
; ******************************************************************************

copy_rows:
    cmp r8, r13              ; Compara el contador de filas copiadas (r8) con 100 (r13).
    jge done_copy            ; Si r8 >= 100, significa que ya copiamos todas las filas, saltamos a done_copy.

    mov r9, r8               ; r9 toma la fila local actual (0..99).
    add r9, r14              ; Suma la base vertical (r14) para obtener la fila "real" en la imagen completa.
    imul r9, 400             ; Multiplica por 400 para calcular el desplazamiento en la memoria de la imagen (anchura de 400).
    add r9, r15              ; Suma el desplazamiento horizontal (r15) para completar la posición de inicio de la fila.

    mov r10, r8              ; r10 también toma la fila local (0..99), pero se usará para indexar dentro del sub-bloque.
    imul r10, r12            ; Lo multiplicamos por 100 (r12) para obtener la posición de inicio de esa fila dentro del sub-bloque.

    xor r11, r11             ; Inicia r11 en 0: se usará como contador de columnas en la copia.




; -----------------------------------------------------------------------------
; copy_cols:
; Bucle interno para recorrer columnas y copiar cada píxel al quad_buffer.
; -----------------------------------------------------------------------------
; Bucle interno que copia los píxeles columna por columna dentro de la fila actual.
; - r11: contador de columna (0..99).
; - r12: ancho del sub-bloque (100).
; - r9: base para la fila en el buffer original.
; - r10: base para la fila en quad_buffer.
; 
; Proceso:
; 1. Verificar si hemos llegado a 100 columnas (r11 >= r12).
; 2. Calcular el índice exacto de píxel en la imagen original (rcx + rsi).
; 3. Calcular el índice exacto en el sub-bloque (rdx + rdi).
; 4. Copiar el byte (un píxel) de la imagen original al sub-bloque.
; 5. Incrementar la columna y repetir.
; =============================================================================

copy_cols:
    cmp r11, r12             ; Compara la columna actual (r11) con 100
    jge end_copy_row         ; Si es >= 100, terminamos la copia de la fila

    mov rcx, r9              ; rcx = índice base de la fila en la imagen original
    add rcx, r11             ; le sumamos la columna actual
    mov rsi, buffer          ; rsi apunta al inicio del buffer original
    add rsi, rcx             ; rsi ahora apunta al píxel específico en la imagen original

    mov rdx, r10             ; rdx = índice base de la fila en el sub-bloque (quad_buffer)
    add rdx, r11             ; le sumamos la columna actual
    mov rdi, quad_buffer     ; rdi apunta al inicio del sub-bloque
    add rdi, rdx             ; rdi apunta al píxel específico dentro del sub-bloque

    mov al, [rsi]            ; Leemos el píxel desde la imagen original
    mov [rdi], al            ; Escribimos el píxel en el sub-bloque

    inc r11                  ; Avanzamos a la siguiente columna
    jmp copy_cols            ; Repetimos este bucle interno para copiar más columnas
    
    
    

; -----------------------------------------------------------------------------
; end_copy_row: 
; Final de columna; incrementa la fila local.
; -----------------------------------------------------------------------------
; Al terminar la copia de una fila (ya sea porque llegamos a 100 columnas), 
; incrementamos r8 (para pasar a la siguiente fila) y volvemos a la rutina 
; copy_rows. 
; =============================================================================

end_copy_row:
    inc r8                   ; Pasa a la siguiente fila (r8 = r8 + 1)
    jmp copy_rows            ; Regresa al bucle principal de copiado por filas





; -----------------------------------------------------------------------------
; done_copy:
; Fin de la copia del sub-bloque 100x100.
; -----------------------------------------------------------------------------
; Indica que ya terminamos de copiar todas las filas (100). Se pone eax en 0 y 
; se asigna ese valor a row_var, para dejarlo listo para un posible uso posterior 
; (en este caso, una interpolación).
; =============================================================================

done_copy:
    xor eax, eax            ; Pone eax a 0 (equivalente a mov eax, 0)
    mov [row_var], eax      ; Guarda ese 0 en row_var, dejándolo listo para la siguiente etapa









 ; **************************************************************************************************************************************************
 ; (4) Interpolación: de 100x100 a 200x200
 ; **************************************************************************************************************************************************

; PASOS GENERALES:
; 1. Recorrer filas 0..99 del sub‐bloque (bucle externo).
; 2. Para cada fila, se recorre columnas 0..99 (bucle interno).
; 3. Identificar si hay fila siguiente (r < 99) y columna siguiente (c < 99).
; 4. Cargar A, B, C, D (de quad_buffer). En bordes, B y/o C y/o D pueden “repetir” la fila/col actual si no existe la siguiente.
; 5. Calcular 4 píxeles para la imagen final (200×200), usando promedios:

; (row*2,col*2) => A
; (row*2+1,col*2) => (3A + B)/4
; (row*2,col*2+1) => (3A + C)/4
; (row*2+1,col*2+1) => (A + B + C + D)/4

; 6. Incrementar la columna.
; 7. Al final de las 100 columnas, incrementar fila y volver al paso 2.
; 8. Al llegar fila=100, termina la interpolación => tenemos la imagen final en interp_buffer.

; ----------------------------------------------------------------------------------------------------------------------------------------
; EXPLICACION DETALLADA

; Se parte de un sub‐bloque de dimensión 100×100 (1 byte/píxel), y se genera una imagen de 200×200, duplicando ancho y alto. 
; Para cada píxel en coordenadas (𝑟,𝑐) del sub‐bloque, se genera un bloque 2×2 en la imagen resultante, haciendo promedios de píxeles 
; vecinos (A, B, C, D) para lograr un suavizado.

; Digamos que en un píxel central r,c en el sub‐bloque. Al escalar la imagen no solo usamos el valor de  (r,c), 
; sino también los de (r+1,c), (r,c+1) y (r+1,c+1) para calcular valores intermedios:

; A = sub-bloque (r,c)

; B = sub-bloque (r+1,c) (la misma columna pero la fila de abajo)

; C = sub-bloque (r,c+1) (la misma fila pero la columna de la derecha)

; D = sub-bloque (r+1,c+1)

; Estas 4 posiciones representan un “cuadradito” de 2×2 en la imagen original, cada píxel (r,c) del original se convierte en un bloque de 2×2. Un píxel “A” y su vecinos B, C, D forman un bloque:

;       columna   c    columna c+1
; fila r         [ A  |  C  ]
; fila r+1       [ B  |  D  ]

; (r*2,c*2) = A : El pixel de la imagen final que es el doble de la fila y columna es igual al valor A (el original).

; (r*2+1,c*2) = (3A + B)/4 : Justo abajo de ese pixel (fila +1), se calcula un promedio donde A tiene 3/4 de peso y B 1/4, generando una transición vertical suave entre A y B.

; (r*2,c*2+1) = (3A + C)/4 : Justo a la derecha (col+1), se calcula un promedio que combina A y C, con más peso en A (3/4) y 1/4 en C, suavizando horizontalmente.

; (r*2+1,c*2+1) = (A + B + C + D)/4 : El pixel “diagonal” (abajo-derecha) es el promedio completo de A,B,C,D (cada uno con 1/4). Esto suaviza en ambas direcciones.

; Así, cada píxel se “expande” a 4. 
; Por simplicidad, aquí se ha dado “más peso” a A en los primeros dos pixels y un promedio completo en el último. Cuando expandimos de 1×1 a 2×2, hacemos un suavizado: bilineal (un promedio en 2D (vertical y horizontal)). Por simplicidad, aquí se ha dado “más peso” a A en los primeros dos pixels y un promedio completo en el último.
; (3A+B)/4 y (3A+C)/4 hacen que A domine, pero con una pequena ayudita de B o C.
; (A+B+C+D)/4 es un promedio total para el pixel diagonal.
; El valor “A” recibe un peso de 3, mientras que B o C tienen un peso de 1. Al final, se divide entre 4 (suma de los pesos 3+1).


; -------------------------------------------------------------------------------------------------------------------------------------------

; Por qué dar más peso a A?
; A es el píxel “origen” (arriba‐izquierda del bloque). Para evitar un salto brusco, se quiere que el píxel interpolado en la fila de abajo o la columna de la derecha sea ; más parecido a A, y solo un poco influido (por asi decirlo) por el píxel vecino.

; Asi, (3A+B)/4 crea una transición vertical suave en la dirección de B (la fila siguiente), pero sin alejarse mucho de A.
; (3A+C)/4 hace lo mismo en la dirección horizontal respecto a C.

; Por ejemplo, si A=100 y B=200, un promedio (3A+B)/4 = (300+200)/4 = 125 y ese valor es más cercano a 100 que a 200, lo que hace que el píxel no “salte” a la mitad del  camino, sino que se incline fuertemente hacia A.


; Si hiciéramos (A+B)/2 Tendríamos un salto de “50%” entre A y B. Podría quedar bien para una interpolación lineal “pura”. Pero en muchos escalados 2× bilineal se hace una desigualdad que mantiene al píxel más cercano a su valor original (A) y aplica un menor peso al vecino (B).


; -------------------------------------------------------------------------------------------------------------------------------------------

; Como hacemos en r=99 o c=99?
; Cuando r=99 o c=99 (última fila/columna), no hay “r+1” o “c+1”, el algoritmo ajusta (replica) para no salir del rango.
; El algoritmo detecta este caso y repite el valor de la fila/columna actual para B, C, o D, en lugar de salirse del rango. 
; Por ejemplo, si r=99, se deja r+1=99 (repitiendo la última fila). Basicamente estamos “replicando el borde” o haciendo un “clamp”; así, el programa no lee memoria fuera del sub-bloque.


; -------------------------------------------------------------------------------------------------------------------------------------------

; De manera visual:

; Sub‐bloque original (2×2)
;       0     1
;    +-----+-----+
; 0  |  A  |  C  |
;    +-----+-----+
; 1  |  B  |  D  |
;    +-----+-----+

; Suponiendo que este bloque 2×2 es el inicial (fila=0..1, col=0..1), la parte resultante (2×2) en la imagen final se ve así:
;   +------------------------+------------------------+
;   |          A             |      (3A + C)/4        |
;   +------------------------+------------------------+
;   |    (3A + B)/4          |   (A + B + C + D)/4     |
;   +------------------------+------------------------+





; -----------------------------------------------------------------------------
; interp_outer_row:
; -----------------------------------------------------------------------------
; Bucle externo para la interpolación vertical (FILAS). Recorremos las filas desde 0 
; hasta 99 (row_var), y en cada paso:
;   - Se multiplica la fila por 2 (para duplicarla verticalmente en la 
;     imagen resultante).
;   - Se reinicia col_var a 0 para el siguiente bucle interno de columnas.
;   - Si ya se alcanzaron 100 filas (row >= 100), se sale a done_interp.
; =============================================================================

interp_outer_row:
    mov eax, [row_var]      ; Cargamos el valor actual de row_var (0..99)
    cmp eax, 100            ; Verificamos si ya estamos en la fila 100
    jge done_interp         ; Si row >= 100, terminamos la interpolación

    mov r8d, eax            ; Copiamos la fila actual en r8 (registro de 32 bits)
    shl r8, 1               ; Multiplicamos esa fila por 2 (imagen resultante duplicada en altura)

    xor edx, edx            ; Ponemos edx en 0
    mov [col_var], edx      ; Inicializamos col_var en 0, para el bucle de columnas




; -----------------------------------------------------------------------------
; interp_inner_col:
; Bucle interno de interpolación (COLUMNAS).
; -----------------------------------------------------------------------------
;   - Bucle interno de la interpolación. Recorre columnas 0..99 del sub-bloque.
;   - Cada píxel se expande en 4 píxeles: (row*2, col*2), (row*2+1, col*2),
;     (row*2, col*2+1) y (row*2+1, col*2+1).
;   - Calcula valores promedio (A,B,C,D) cuando sea posible usar la fila/col siguiente.
 
; - Lee la columna actual de col_var (0..99).
; - Si col >= 100, terminamos esta fila (saltamos a end_interp_row).
; - Toma la fila actual en r10 y verifica si hay una siguiente fila (row < 99).
;   - Si sí, salta a .ok_rplus para usar la fila siguiente en la interpolación.
;   - Si no, salta a .no_rplus (significa que estamos en la última fila).
; =============================================================================

interp_inner_col:
    mov edx, [col_var]      ; Cargamos en edx el valor actual de col (0..99)
    cmp edx, 100            ; Verificamos si col ya llegó a 100
    jge end_interp_row      ; Si col >= 100, terminamos la interpolación de esta fila

    mov r10d, [row_var]     ; Cargamos la fila actual en r10d
    cmp r10d, 99            ; Revisamos si existe una siguiente fila (row < 99)
    jl .ok_rplus            ; Si row < 99, hay una fila siguiente
    jmp .no_rplus           ; Si row >= 99, no hay fila siguiente (estamos en la última)




; -----------------------------------------------------------------------------
; .ok_rplus:
; -----------------------------------------------------------------------------
; Si el código salta a .ok_rplus, significa que hay una fila siguiente 
; disponible (row < 99), así que sumamos 1 a r10d para usar esa fila 
; en la interpolación. Si no, caemos en .no_rplus y no incrementamos r10d 
; (estamos en la última fila).
;
; Después de eso, leemos la columna actual desde col_var en r11d y vemos 
; si existe la columna siguiente (col < 99). Si sí, saltamos a .ok_cplus 
; para incrementarla; si no, saltamos a .no_cplus.
; =============================================================================

.ok_rplus:
    add r10d, 1              ; Se incrementa la fila (r10d) en 1
.no_rplus:

    mov r11d, [col_var]      ; Cargamos en r11 la columna actual desde col_var
    cmp r11d, 99             ; Verificamos si col+1 es posible (col < 99)
    jl .ok_cplus             ; Si col < 99, saltamos a .ok_cplus
    jmp .no_cplus            ; Si no, vamos a .no_cplus (estamos en la última columna)




; -----------------------------------------------------------------------------
; .ok_cplus:
; -----------------------------------------------------------------------------
; Si llegamos aquí, significa que sí hay una columna siguiente (col < 99). 
; Por ello, incrementamos r11d para preparar el uso de la siguiente columna.
; =============================================================================

.ok_cplus:
    add r11d, 1
    
    
    
    
    
.no_cplus:
    ; ------------------------------------------------------------------------------
    ;   - Se llega a este punto cuando la verificación de la columna siguiente (col+1)
    ;     determinó que no está dentro del rango (col == 99). Esto significa que no
    ;     podemos acceder a la columna siguiente.
    ;   - Aun así vamos a cargar y procesar los píxeles A, B, C, D de la posición
    ;     actual. Pero, como col+1 está fuera de rango, la variable r11d ya
    ;     no fue incrementada (en .ok_cplus sí se hacía).
    ;   - Se realiza la interpolación de los 4 píxeles de la esquina (o borde) basándose
    ;     en los valores disponibles. El resultado se escribe en `interp_buffer`.
    ; ------------------------------------------------------------------------------

    ; Cargamos A, B, C, D del sub-bloque:
    ; A => (row,   col)
    ; B => (row+1, col)
    ; C => (row,   col+1) Normalmente, r11d = col+1, pero en .no_cplus se no incrementó r11d; queda r11d=col. Entonces C apunta al mismo “col” y deja la imagen sin moverse horizontalmente C = (row,r11d)
    ; D => (row+1, col+1)  no hay “col+1” real, así que D repite la última columna en el borde D = (row+1,r11d)
    
	; Dado que aquí no hay col+1 disponible, ese valor se repetirá o quedará en 
	; el borde, según la lógica utilizada. Luego se calcula la interpolación 
	; (promediando los valores) y se escribe en 'interp_buffer', duplicando 
	; la escala tanto en filas como en columnas.
    
    mov eax, [row_var]       ; EAX = fila actual (0..99)
    mov edx, [col_var]       ; EDX = columna actual (en .no_cplus creo que debe ser 99)
    mov rsi, quad_buffer     ; RSI apunta al inicio del sub-bloque (100x100)

    mov ecx, eax             ; Copiamos la fila (row) a ECX
    imul ecx, 100            ; Multiplicamos por 100 para ubicar la fila en quad_buffer
    add ecx, edx             ; Sumamos la columna para apuntar al píxel exacto
    add rsi, rcx             ; RSI => posición del píxel A
    movzx r14, byte [rsi]    ; Cargamos el píxel A en r14 (extendido a 64 bits)

    mov rsi, quad_buffer     ; Volvemos a apuntar al inicio de quad_buffer
    mov ecx, r10d            ; r10d contiene row+1 (la fila siguiente)
    imul ecx, 100            ; Calculamos la posición base de esa fila
    add ecx, edx             ; Sumamos la misma columna (col)
    add rsi, rcx             ; RSI => posición del píxel B
    movzx r15, byte [rsi]    ; Cargamos el píxel B en r15

    mov rsi, quad_buffer     ; Otra vez, inicio del sub-bloque
    mov ecx, eax             ; ECX = fila actual (row)
    imul ecx, 100
    add ecx, r11d            ; r11d representa col+1, pero podría no haberse incrementado
    add rsi, rcx             ; RSI => píxel C (misma fila, siguiente columna)
    movzx rdi, byte [rsi]    ; Cargamos el píxel C en rdi

    mov rsi, quad_buffer     ; De nuevo al inicio
    mov ecx, r10d            ; ECX = row+1
    imul ecx, 100
    add ecx, r11d            ; Sumamos la columna 'col+1' (o la misma, si no se incrementó)
    add rsi, rcx             ; RSI => píxel D (fila siguiente, columna siguiente)
    movzx rsi, byte [rsi]    ; Cargamos el píxel D en rsi

    mov r9d, [col_var]       ; r9d = col actual
    shl r9, 1                ; col * 2, la imagen de salida es el doble de ancha

	; ------------------------------------------------------------------------------
	; 1) (row*2, col*2) => píxel original A
	;
	; Ahora escribimos los 4 píxeles resultantes en interp_buffer, expandiendo
	; (row,col) a (row*2, col*2) y sus vecinos.
	; ------------------------------------------------------------------------------

	; Se escribe el valor de A (almacenado en r14) en la posición (row*2, col*2)
	; de la imagen resultante (interp_buffer). La imagen se considera "doble 
	; tamaño" en ambas direcciones, de ahí que multipliquemos la fila por 2 
	; (ya guardado en r8) y la columna por 2 (guardada en r9).
	; =============================================================================

    mov rcx, r8             ; r8 contiene (row*2)
    imul rcx, 200           ; Multiplicamos por 200 (ancho de la imagen resultante)
    add rcx, r9             ; r9 contiene (col*2); sumamos para calcular la posición final
    mov rdx, interp_buffer  ; rdx apunta al inicio del buffer de la imagen escalada
    add rdx, rcx            ; rdx ahora señala a (row*2, col*2)
    mov [rdx], r14b         ; Guardamos A (r14b = 8 bits de r14) en esa posición
    
    

        ; =============================================================================
	; 2) (row*2+1, col*2) => promedio(A,B) => (3*A + B)/4
	; -----------------------------------------------------------------------------
	; Calcula el promedio de A y B dando más peso a A (3 partes de A vs 1 de B), 
	; luego lo guarda en la posición (row*2+1, col*2) en la imagen resultante 
	; (interp_buffer). Esto consigue una transición suave en la dirección vertical 
	; entre estos dos píxeles.
	; =============================================================================

    mov rcx, r8             ; r8 contiene (row*2)
    add rcx, 1              ; row*2 + 1 (la fila inmediatamente debajo en la imagen final)
    imul rcx, 200           ; Multiplicamos la fila por 200 (ancho de la imagen final)
    add rcx, r9             ; Sumamos col*2 para la posición horizontal
    mov rdx, interp_buffer  ; rdx apunta al inicio de la imagen escalada
    add rdx, rcx            ; rdx ahora es la dirección exacta del píxel (row*2+1, col*2)
    mov rax, r14            ; Carga el valor de A (64 bits) en rax
    imul rax, 3             ; Multiplica A por 3 (3*A)
    add rax, r15            ; Suma B (3*A + B)
    shr rax, 2              ; Desplaza a la derecha 2 bits => divide entre 4
    mov [rdx], al           ; Guarda el resultado (promedio) en un byte


	; =============================================================================
	; 3) (row*2, col*2+1) => promedio(A,C) => (3*A + C)/4
	; -----------------------------------------------------------------------------
	; Calcula un valor intermedio entre A y C, con más peso en A, y lo escribe en
	; la posición (row*2, col*2+1) de la imagen resultante. Esto suaviza la 
	; transición horizontal.
	; =============================================================================

    mov rcx, r8             ; rcx = row*2 (almacenado en r8)
    imul rcx, 200           ; Multiplica la fila por 200 (ancho de la imagen final)
    mov rdx, r9             ; rdx = col*2 (almacenado en r9)
    add rdx, 1              ; col*2 + 1 => siguiente columna horizontal
    add rcx, rdx            ; Sumamos fila y columna para obtener el índice
    mov rdx, interp_buffer  ; rdx => inicio del buffer de la imagen interpolada
    add rdx, rcx            ; rdx => posición (row*2, col*2+1)

    mov rax, r14            ; Cargamos A (64 bits) en rax
    imul rax, 3             ; Multiplica A por 3 => 3*A
    add rax, rdi            ; Suma C => (3*A + C)
    shr rax, 2              ; Divide entre 4
    mov [rdx], al           ; Guarda el promedio en 1 byte


	; =============================================================================
	; 4) (row*2+1, col*2+1) => (A + B + C + D)/4
	; -----------------------------------------------------------------------------
	; Calcula el promedio de los cuatro píxeles A, B, C y D. El resultado se 
	; coloca en la posición (row*2+1, col*2+1) de la imagen final, completando 
	; la interpolación tanto en el eje vertical como en el horizontal.
	; =============================================================================

    mov rcx, r8                 ; rcx = row*2 (almacenado en r8)
    add rcx, 1                  ; row*2 + 1 => la siguiente fila en la imagen resultante
    imul rcx, 200               ; Multiplicamos (row*2+1) por 200 (ancho de la imagen escalada)
    mov rdx, r9                 ; rdx = col*2 (almacenado en r9)
    add rdx, 1                  ; col*2 + 1 => la siguiente columna en la imagen resultante
    add rcx, rdx                ; Sumamos fila y columna para obtener el índice completo
    mov rdx, interp_buffer      ; rdx => inicio del buffer de la imagen
    add rdx, rcx                ; rdx => posición en (row*2+1, col*2+1)

    mov rax, r14                ; Cargamos A en rax
    add rax, r15                ; Sumamos B => A + B
    add rax, rdi                ; Sumamos C => A + B + C
    add rax, rsi                ; Sumamos D => A + B + C + D
    shr rax, 2                  ; Desplazamos 2 bits => dividimos entre 4 (promedio)
    mov [rdx], al               ; Guardamos el resultado en un byte (píxel interpolado)


; =============================================================================
; Al terminar de procesar el píxel en (row, col) (y sus vecinos), se incrementa
; la variable col_var para pasar a la siguiente columna. Luego se repite 
; el bucle interno de interpolación (interp_inner_col) hasta completar 
; las 100 columnas.
; =============================================================================

    mov eax, [col_var]      ; Cargamos el valor actual de col_var en EAX
    inc eax                 ; Incrementamos col_var en 1
    mov [col_var], eax      ; Guardamos el nuevo valor de col_var
    jmp interp_inner_col    ; Regresamos al bucle para la siguiente columna



; =============================================================================
; end_interp_row
; -----------------------------------------------------------------------------
; Se alcanza este punto cuando se completó la interpolación de todas las 
; columnas de la fila actual. Se incrementa row_var para procesar la siguiente 
; fila y se retorna al bucle externo de interpolación (interp_outer_row).
; =============================================================================

end_interp_row:
    mov eax, [row_var]       ; Carga row_var en eax
    inc eax                  ; Aumenta row_var en 1 (siguiente fila)
    mov [row_var], eax       ; Guarda el valor actualizado en memoria
    jmp interp_outer_row     ; Vuelve al bucle externo para procesar la siguiente fila

    
    
    
    
    

; **************************************************************************************************************************************************
; (5) Crear/Guardar imagen de salida
; **************************************************************************************************************************************************

; =============================================================================
; done_interp
; -----------------------------------------------------------------------------
; Se llega aquí cuando la interpolación ha finalizado. Ahora se crea un archivo 
; "imagen_out.img", se escriben en él los 40,000 bytes del buffer interpolado 
; (200×200), y finalmente se cierra el archivo.
; =============================================================================

done_interp:
    mov rax, 2              ; Número de syscall para abrir archivos (sys_open)
    mov rdi, fname_out      ; Nombre del archivo de salida ("imagen_out.img")
    mov rsi, 577            ; Flags => O_WRONLY|O_CREAT|O_TRUNC (577 decimal)
    mov rdx, 420            ; Modo => 0644 octal (420 decimal)
    syscall                 ; Llamada al sistema para abrir/crear el archivo
    
    cmp rax, 0              ; Verificamos el descriptor devuelto
    js error_open_out       ; Si es menor que 0, hubo error
    
    mov rbx, rax            ; Guardamos el descriptor de archivo en rbx

    mov rax, 1              ; Número de syscall para escribir (sys_write)
    mov rdi, rbx            ; Descriptor de archivo
    mov rsi, interp_buffer  ; Dirección del buffer de la imagen resultante
    mov rdx, 200*200        ; 40,000 bytes que vamos a escribir
    syscall                 ; Llamamos al sistema para escribir
    
    cmp rax, 0              ; Chequeamos la cantidad escrita
    js error_write_out      ; Si es negativo, error de escritura

    mov rax, 3              ; Número de syscall para cerrar archivos (sys_close)
    mov rdi, rbx            ; Descriptor de archivo que cerramos
    syscall                 ; Cerrar el archivo


    
    
    
; **************************************************************************************************************************************************
; (6) Cálculo de Checksums
; **************************************************************************************************************************************************
; El bloque de código que recorre todos los píxeles (bucle de filas y columnas) y los va sumando en un acumulador 
; (para el sub-bloque 100×100 y para la imagen final 200×200) es para verificación (Comprobar que se han leído todos los píxeles esperados y debuggear)
; El orden seria:
; 1. Lee la imagen completa (400×400).
; 2. Extrae el sub-bloque (100×100) y lo guarda en quad_buffer.
; 3.Hace la interpolación a 200×200 y lo guarda en interp_buffer.
; 4. Cálculo de checksums:
; 	Primero recorre quad_buffer (100×100) sumando todos sus píxeles y guarda la suma en r12.
;	Luego recorre interp_buffer (200×200) y guarda la suma en r13.
; Finalmente, imprime esos valores

    xor rax, rax            ; Pone rax en 0, para usarlo como sumador
    xor r8, r8              ; Pone r8 en 0, para usarlo como contador de filas

    
    
; =============================================================================
; csum_sub_rows
; -----------------------------------------------------------------------------
; Este fragmento se ejecuta en un bucle para procesar filas de un sub-bloque
; (100 filas en total). 
; - r8: Contador de filas procesadas. 
; - r9: Se usará para calcular el índice base de la fila (fila × 100).
; - r11: Se usará como contador de columnas.
; =============================================================================

csum_sub_rows:
    cmp r8, 100            ; Compara r8 (fila actual) con 100
    jge csum_sub_done      ; Si r8 >= 100, ya procesamos todas las filas, saltamos

    mov r9, r8             ; r9 = número de fila
    imul r9, 100           ; r9 *= 100 para obtener el índice base en quad_buffer
    xor r11, r11           ; Inicializa r11 en 0 (contador de columnas)

    
    

; =============================================================================
; csum_sub_cols
; -----------------------------------------------------------------------------
; Bucle interno para recorrer las columnas de la fila actual (0..99). 
; Suma el valor de cada píxel al acumulador (rax).
; - r11: Contador de columnas
; - r9:  Índice base de la fila (fila × 100)
; - rbx: Registro auxiliar para cargar el valor del píxel
; =============================================================================

csum_sub_cols:
    cmp r11, 100            ; Verifica si llegamos a 100 columnas
    jge end_sub_row         ; Si r11 >= 100, terminamos esta fila

    mov rcx, r9             ; rcx = índice base de la fila
    add rcx, r11            ; Sumamos la columna actual
    mov rsi, quad_buffer    ; rsi apunta al inicio del sub-bloque
    add rsi, rcx            ; rsi apunta al píxel actual dentro de quad_buffer

    xor rbx, rbx            ; Limpia rbx antes de usar su parte baja
    mov bl, [rsi]           ; Carga el píxel (1 byte) en bl
    add rax, rbx            ; Suma el valor del píxel al acumulador rax

    inc r11                 ; Avanza a la siguiente columna
    jmp csum_sub_cols       ; Repite hasta completar las 100 columnas

    
    
    
    
; =============================================================================
; end_sub_row
; -----------------------------------------------------------------------------
; Se llega aquí cuando se han procesado las 100 columnas de la fila actual.
; Incrementamos r8 para pasar a la siguiente fila, y volvemos a csum_sub_rows 
; para comprobar si hay más filas que procesar.
; =============================================================================

end_sub_row:
    inc r8              ; Pasa a la siguiente fila
    jmp csum_sub_rows   ; Regresa al bucle de filas para continuar





; =============================================================================
; csum_sub_done
; -----------------------------------------------------------------------------
; Al llegar aquí, ya se sumaron todos los píxeles de la región 100×100 en
; quad_buffer. Se almacena el resultado de la suma en r12. Luego, se resetean
; los registros rax y r8 a cero, para iniciar un conteo similar en la imagen
; interpolada de 200×200.
; =============================================================================

csum_sub_done:
    mov r12, rax       ; Guarda la suma total de los píxeles (100×100) en r12

    ; Ahora comenzamos con la imagen interpolada de 200×200
    xor rax, rax       ; Reinicia rax a 0 para usarlo como acumulador
    xor r8, r8         ; Reinicia r8 a 0 para usarlo como contador de filas




; =============================================================================
; csum_interp_rows
; -----------------------------------------------------------------------------
; Este bloque se repite para cada fila de la imagen interpolada, la cual mide
; 200×200 píxeles. 
; - r8: Contador de filas recorridas (0..199).
; - r9: Se usará para calcular el índice base de la fila (fila × 200).
; - r11: Se usará como contador de columnas dentro de cada fila.
; =============================================================================

csum_interp_rows:
    cmp r8, 200        ; Ya llegamos a la fila 200?
    jge csum_interp_done  ; Si r8 >= 200, ya terminamos de recorrer todas las filas

    mov r9, r8         ; r9 = número de fila
    imul r9, 200       ; r9 *= 200 para obtener el índice base de esa fila
    xor r11, r11       ; Inicializamos el contador de columnas (r11) en 0




; =============================================================================
; csum_interp_cols
; -----------------------------------------------------------------------------
; Bucle interno que recorre las columnas (0..199) de la fila actual en la imagen 
; interpolada (200×200). Suma el valor de cada píxel al acumulador rax.
; 
; - r11: Contador de columnas
; - r9: Índice base de la fila (fila × 200)
; - rbx: Registro auxiliar para cargar el valor del píxel
; =============================================================================

csum_interp_cols:
    cmp r11, 200            ; Ya terminamos las 200 columnas?
    jge end_interp_sum_row2 ; Si r11 >= 200, terminamos la fila

    mov rcx, r9             ; rcx = índice base de la fila
    add rcx, r11            ; sumamos el número de columna actual
    mov rsi, interp_buffer  ; rsi apunta al inicio del buffer interpolado
    add rsi, rcx            ; rsi ahora apunta al píxel específico (fila, columna)

    xor rbx, rbx            ; limpiamos rbx
    mov bl, [rsi]           ; cargamos el píxel (1 byte) en bl
    add rax, rbx            ; sumamos el valor del píxel al acumulador rax

    inc r11                 ; pasamos a la siguiente columna
    jmp csum_interp_cols    ; repetimos el bucle interno de columnas





; =============================================================================
; end_interp_sum_row2
; -----------------------------------------------------------------------------
; Este punto se alcanza cuando se han procesado todas las columnas (200) de 
; la fila actual en la imagen interpolada. Incrementamos r8 para pasar a 
; la siguiente fila y saltamos de nuevo a csum_interp_rows.
; =============================================================================

end_interp_sum_row2:
    inc r8              ; Pasa a la siguiente fila
    jmp csum_interp_rows  ; Vuelve al bucle principal de filas de la imagen interpolada





; =============================================================================
; csum_interp_done
; -----------------------------------------------------------------------------
; Esta etiqueta marca el final del proceso de suma para la imagen interpolada 
; (200×200). El valor acumulado en rax (suma de todos los píxeles) se guarda 
; en r13 para un posible uso posterior.
; =============================================================================

csum_interp_done:
    mov r13, rax      ; Guarda la suma acumulada de píxeles de la imagen interpolada en r13



; **************************************************************************************************************************************************
; (7) Imprimir checksums y mensaje final
; **************************************************************************************************************************************************

    ; Imprimir resultados

; (a) Bytes leídos
    mov rax, 1                      ; syscall write
    mov rdi, 1                      ; descriptor de archivo 1 (stdout)
    mov rsi, msg_bytes_read         ; dirección del mensaje "Bytes leídos: "
    mov rdx, msg_bytes_read_end - msg_bytes_read  ; longitud del mensaje
    syscall                         ; escribe el mensaje en pantalla

    mov rdi, [read_count]           ; carga la cantidad de bytes leídos en rdi
    call print_hex                  ; llama a print_hex para mostrarlo en hexadecimal

    mov rax, 1
    mov rdi, 1
    mov rsi, new_line               ; imprime un salto de línea
    mov rdx, 1
    syscall

    ; (b) Checksum sub-bloque
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_checksum_sub
    mov rdx, msg_checksum_sub_end - msg_checksum_sub
    syscall                         ; escribe "Checksum sub-bloque: "

    mov rdi, r12                    ; r12 contiene la suma de píxeles del sub-bloque (100×100)
    call print_hex                  ; imprime ese valor en hexadecimal

    mov rax, 1
    mov rdi, 1
    mov rsi, new_line
    mov rdx, 1
    syscall                         ; imprime un salto de línea

    ; (c) Checksum interpolado
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_checksum_interp
    mov rdx, msg_checksum_interp_end - msg_checksum_interp
    syscall                         ; escribe "Checksum interpolado: "

    mov rdi, r13                    ; r13 contiene la suma de píxeles de la imagen interpolada (200×200)
    call print_hex                  ; imprime ese valor en hexadecimal

    mov rax, 1
    mov rdi, 1
    mov rsi, new_line
    mov rdx, 1
    syscall                         ; imprime un salto de línea

    ; Mensaje final
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_done               ; "done\n"
    mov rdx, msg_done_end - msg_done
    syscall                         ; escribe el mensaje final

    ; exit(0)
    mov rax, 60                     ; syscall exit
    xor rdi, rdi                    ; poner rdi en 0 => exit code 0
    syscall                         ; finaliza el programa





; **************************************************************READ_CONFIG_FROM_FILE******************************************************************
; read_config_from_file:
;   Lee config.txt:
;     - Primera linea => path de la imagen => path_buffer
;     - Segunda linea => cuadrante (1..16) => [quadrant]
; **************************************************************************************************************************************************


; =============================================================================
; read_config_from_file
; -----------------------------------------------------------------------------
; Esta función abre el archivo "config.txt" en modo lectura, lee hasta 256 bytes 
; en el buffer config_buffer y luego cierra el archivo. También limpia dos 
; registros (rcx y rdx) para su uso posterior.
; =============================================================================



read_config_from_file:
    push rbp                    ; Guarda la referencia anterior de la pila 
    mov rbp, rsp                ; Ajusta esta referencia a la posición actual de la pila

    mov rax, 2                  ; Indica que usaremos la llamada al sistema para abrir archivos
    mov rdi, fname_config       ; Pasa la dirección del nombre del archivo ("config.txt")
    xor rsi, rsi                ; Indica modo de apertura en lectura (0)
    xor rdx, rdx                ; No ocupamos un modo específico para lectura
    syscall                     ; Llama al sistema operativo para abrir el archivo

    cmp rax, 0                  ; Verificamos si la apertura tuvo éxito a cachete!! (valor negativo = error)
    js  error_open_config       ; Si ocurrió un error, salta a la rutina que lo maneja

    mov rbx, rax                ; Almacenamos el descriptor de archivo en rbx, un número que el s.o usa para identificar el archivo abierto

    mov rax, 0                  ; Llamada al sistema para leer archivos
    mov rdi, rbx                ; Pasamos el descriptor de archivo
    mov rsi, config_buffer      ; Dirección donde se guardará lo leído
    mov rdx, 256                ; Cantidad máxima de bytes a leer
    syscall                     ; Llamamos al sistema operativo para leer

    cmp rax, 0                  ; Verificamos que la lectura no devolviera un valor negativo
    js  error_read_config       ; Si hubo error, salta a la rutina de manejo

    mov rax, 3                  ; Llamada al sistema para cerrar un archivo
    mov rdi, rbx                ; Usamos el descriptor de archivo que abrimos
    syscall                     ; Cerramos el archivo

    xor rcx, rcx                ; Reiniciamos este registro a cero (para usarlo mas tardito)
    xor rdx, rdx                ; Reiniciamos este otro registro a cero (para usrlo mas tardito)




; =============================================================================
; .find_path_loop:
; -----------------------------------------------------------------------------
; Bucle que lee la primera línea del config_buffer y la copia a path_buffer.
; Aca leemos caracter por caracter desde config_buffer y los copiamos a 
; path_buffer hasta encontrar un salto de línea (ASCII 10), que indica el final
; de la ruta, o un cero (ASCII 0), que indica un fin inesperado (error).
; =============================================================================


.find_path_loop:
    mov al, [config_buffer + rcx]   ; Carga en AL el siguiente carácter desde config_buffer
    cmp al, 0                       ; Compara el carácter con 0 (carácter nulo)
    je .error_bad_config            ; Si es 0, indica final inesperado (config corrupta)

    cmp al, 10                      ; Compara con 10 (salto de línea, '\n')
    je .end_path                    ; Si es salto de línea, termina la ruta

    mov [path_buffer + rdx], al     ; Copia el carácter a path_buffer
    inc rcx                         ; Avanza en config_buffer
    inc rdx                         ; Avanza en path_buffer

    cmp rdx, 240                    ; Verifica no exceder el tamaño máximo para path_buffer
    jae .error_bad_config           ; Si se pasa de 239, consideramos que es un error
    
    jmp .find_path_loop             ; Repite el proceso para el siguiente




; =============================================================================
; .end_path:
; -----------------------------------------------------------------------------
; Al encontrar '\n', se cierra la cadena en path_buffer y se avanza.
; Aquí finalizamos la ruta poniendo un carácter nulo en path_buffer, para indicar
; el fin de cadena, e incrementamos rcx para avanzar en config_buffer. Luego 
; reiniciamos rdx a cero para su uso posterior.
; =============================================================================


.end_path:
    mov byte [path_buffer + rdx], 0  ; Inserta un caracter nulo ('\0') al final de la ruta
    inc rcx                           ; Avanza en config_buffer (después del salto de línea)
    
    xor rdx, rdx                      ; Reinicia rdx a cero para usos posteriores



; =============================================================================
; .next_line_loop:
; -----------------------------------------------------------------------------
;  Segunda línea: cuadrante => se copia en quad_input hasta '\n' o fin.
;   - Lee la segunda línea, que debe contener el cuadrante (1..16).
;   - Copia los caracteres a quad_input hasta saltar de línea o fin de datos. Si encuentra
; un caracter nulo (0) o un salto de línea (10, '\n'), finaliza el bucle, pues 
; ya no hay más datos o se ha llegado al final de la línea.
; También se detiene cuando alcanza 3 caracteres en quad_input.
; =============================================================================

.next_line_loop:
    mov al, [config_buffer + rcx]   ; Carga el siguiente carácter desde config_buffer
    cmp al, 0                       ; Comprueba si es el carácter nulo (fin de datos)
    je .maybe_ok                    ; Si es 0, va a .maybe_ok (quizá todo esté bien)
    cmp al, 10                      ; Verifica si es un salto de línea (\n)
    je .end_quad                    ; Si es \n, salta a .end_quad
    mov [quad_input + rdx], al      ; Copia el carácter a quad_input
    inc rcx                         ; Avanza en config_buffer
    inc rdx                         ; Avanza la posición en quad_input
    cmp rdx, 3                      ; Revisa si ya se llenaron 3 caracteres en quad_input
    jae .end_quad                   ; Si llegamos a 3 (o más), salta a .end_quad
    jmp .next_line_loop             ; Vuelve a leer el siguiente carácter




; =============================================================================
; .end_quad:
; -----------------------------------------------------------------------------
;  Cierra la cadena en quad_input con 0.
;   - Al llegar aquí, se cierra quad_input con 0
;     (límite de 3 dígitos para el cuadrante).
; Finaliza la construcción de la cadena en quad_input añadiendo un carácter nulo
; ('\0') para indicar el final de la misma.
; =============================================================================

.end_quad:
    mov byte [quad_input + rdx], 0  ; Inserta el carácter nulo al final de quad_input





; =============================================================================
; .maybe_ok:
; -----------------------------------------------------------------------------
;  Llamamos a parse_quadrant y verificamos el rango (1..16).
;   - Punto cuando terminamos de leer el cuadrante.
;   - Llamamos a parse_quadrant para convertir la cadena ASCII a número.
; Llama a la función parse_quadrant, revisa el valor de la variable 'quadrant' 
; para asegurarse de que esté entre 1 y 16. Si está fuera de ese rango, salta a 
; .error_range. Si está en el rango correcto, limpia y retorna normalmente.
; =============================================================================

.maybe_ok:
    call parse_quadrant          ; Llama a la función que procesa/calcula el valor del cuadrante
    
    mov eax, [quadrant]          ; Carga el valor de 'quadrant' en el registro eax
    cmp eax, 1                   ; Verifica si es menor que 1
    jl .error_range              ; Si es menor que 1, salta al manejo de error de rango
    cmp eax, 16                  ; Verifica si es mayor que 16
    jg .error_range              ; Si es mayor que 16, también salta al error de rango

    leave                        ; Limpia la pila y restaura el punto de referencia anterior
    ret                          ; Retorna de la función





; =============================================================================
; Sección de manejo de errores. Si llegamos a uno de estos puntos, muestra
; un mensaje de error usando la llamada al sistema de escritura y luego
; sale del programa con código de salida 1.
; =============================================================================

.error_bad_config:
.error_range:
.fail:
    mov rax, 1                            ; Número de syscall para escribir
    mov rdi, 1                            ; Descriptor de archivo 1 (stdout)
    mov rsi, msg_error_config             ; Dirección del mensaje de error
    mov rdx, msg_error_config_end - msg_error_config ; Longitud del mensaje
    syscall                               ; Llamamos al sistema para imprimir el mensaje

    mov rax, 60                           ; Número de syscall para salir (exit)
    mov rdi, 1                            ; Código de salida 1
    syscall                               ; Sale del programa


error_open_config:
    mov rax, 60            ; Número de syscall para salir (exit)
    mov rdi, 17            ; Código de salida a devolver al sistema
    syscall                ; Llama al sistema para cerrar el programa
    

error_read_config:
    mov rax, 60            ; Número de syscall para salir (exit)
    mov rdi, 18            ; Código de salida al sistema
    syscall                ; Cierra el programa
    
    
    
    
    

; =============================================================================
; parse_quadrant:
; -----------------------------------------------------------------------------
;   Convierte quad_input (ASCII) => [quadrant] (entero).
;   Ejemplo: "7"  => 7
;            "12" => 12
; Esta función toma hasta dos caracteres de quad_input y los convierte a un 
; número que se guarda en r8. Solo acepta dígitos ('0' a '9'). Si el primer 
; carácter es nulo, salta a .no_digits. Si encuentra un dígito, lo almacena y
; si hay un segundo dígito, multiplica el primero por 10, le suma el segundo y 
; luego continúa en .ok
; =============================================================================

parse_quadrant:
    push rbp                   ; Guarda la referencia anterior de la pila
    mov rbp, rsp               ; Ajusta la referencia al marco actual

    mov rsi, quad_input        ; rsi apunta a la cadena quad_input
    xor r8, r8                 ; Limpia el registro r8 (lo uso como acumulador numérico)

    mov al, [rsi]              ; Carga el primer carácter en AL
    cmp al, 0                  ; Compara con 0 para ver si la cadena está vacía
    je .no_digits              ; Si está vacía, salta a .no_digits

    sub al, '0'                ; Convierte el carácter de '0'...'9' a 0...9
    cmp al, 9                  ; Verifica si está dentro de 0...9
    ja .not_digit              ; Si es mayor que 9, no es un dígito válido

    mov r8, rax                ; Guarda el valor numérico del primer dígito en r8

    mov al, [rsi+1]            ; Carga el segundo carácter (opcional)
    cmp al, 0                  ; Compara con 0 por si la cadena tiene un solo dígito
    je .ok                     ; Si es 0, vamos a .ok
    cmp al, 10                 ; Verifica si es un salto de línea \n
    je .ok                     ; Si lo es, vamos a .ok (tenemos un solo dígito)

    sub al, '0'                ; Convierte el segundo carácter de '0'...'9' a 0...9
    cmp al, 9                  ; Comprueba que sea un dígito válido
    ja .not_digit              ; Si no, salta a .not_digit

    imul r8, r8, 10            ; Multiplica el primer dígito por 10 (desplazamiento decimal). Multiplicar r8 por 10 “desplaza” el primer dígito a la siguiente posición decimal, dejando espacio para añadir el segundo dígito y formar correctamente el número.
    add r8, rax                ; Suma el valor del segundo dígito
    jmp .ok                    ; Continúa en .ok



; =============================================================================
; .not_digit:
; -----------------------------------------------------------------------------
;   - Si alguno de los caracteres no es un dígito válido (0..9),
;     se fuerza quadrant = 0, indicando error en el parseo.
; =============================================================================
.not_digit:
    mov dword [quadrant], 0
    jmp .done

; =============================================================================
; .no_digits:
; -----------------------------------------------------------------------------
;   - Si la cadena está vacía (cero bytes) y no hay dígitos,
;     asignamos quadrant = 0 directamente.
; =============================================================================
.no_digits:
    mov dword [quadrant], 0
    jmp .done

.ok:
    mov [quadrant], r8d

.done:
    leave
    ret












; **************************************************************************************************************************************************
; print_hex:
;   Imprime en pantalla (stdout) el valor en RDI en formato hexadecimal
;   de 16 dígitos (con padding de ceros a la izquierda).
; **************************************************************************************************************************************************

; Esta función recibe en rdi un número de 64 bits y lo muestra en pantalla como 
; un valor hexadecimal de 16 dígitos (con ceros a la izquierda). 
;   1. Preparo un buffer local de 16 caracteres en la pila.
;   2. Relleno ese buffer con '0' (padding).
;   3. Convierto cada 4 bits (1 nibble) de rax en un carácter hexadecimal, 
;      de menos significativo a más significativo, almacenándolo en el buffer.
;   4. Llamo a la syscall de escritura (write) para imprimir el buffer.
;   5. Limpio y retorno.
; =============================================================================

print_hex:
    push rbp                ; Guarda la base de la pila anterior
    mov rbp, rsp            ; Ajusta rbp al comienzo del marco actual

    push rbx                ; Guarda el registro rbx (lo usaremos abajo)
    sub rsp, 16             ; Reserva 16 bytes en la pila (espacio para el buffer)

    mov rax, rdi            ; Carga en rax el valor que se va a imprimir en hex
    mov rsi, rsp            ; rsi apuntará al buffer local en la pila

    mov rcx, 16             ; Necesitamos 16 dígitos hex

; -----------------------------------------------------------------------------
; .fill_loop:
;   - Rellena 16 posiciones en el buffer con '0' para que siempre tengamos 
;     16 dígitos (padding con ceros a la izquierda).
; -----------------------------------------------------------------------------
.fill_loop:
    mov byte [rsi + rcx - 1], '0'   ; En cada posición escribe el carácter '0'
    loop .fill_loop                 ; Decrementa rcx y repite hasta 16 veces

    mov rcx, 16             ; Restablece el contador a 16 para el siguiente bucle

; -----------------------------------------------------------------------------
; .hex_conv:
;   - Toma los bits de rax de 4 en 4 (un nibble) y los convierte a carácter hex.
;   - Escribimos ese carácter en la posición correspondiente, luego desplazamos
;     rax 4 bits a la derecha para el siguiente nibble.
; -----------------------------------------------------------------------------
.hex_conv:
    mov rbx, rax            ; Copiamos rax a rbx para aislar el nibble
    and rbx, 0xF            ; rbx = los últimos 4 bits de rax
    cmp rbx, 10             ; Comparamos si el nibble es < 10
    jb .digit0_9            ; Si < 10, usamos dígitos '0'..'9'
    add rbx, 55             ; Si >= 10, sumamos 55 para llegar a 'A'..'F' (ASCII)
    jmp .store_char

; -----------------------------------------------------------------------------
; .digit0_9:
;   - Si el nibble es menor que 10, lo convertimos a '0'..'9' sumando 48 
;     (ASCII de '0').
; -----------------------------------------------------------------------------
.digit0_9:
    add rbx, 48             ; Convierte 0..9 en ASCII '0'..'9'

; -----------------------------------------------------------------------------
; .store_char:
;   - Guarda el carácter en [rsi + rcx - 1].
;   - Desplaza rax 4 bits para procesar el siguiente nibble.
;   - Decrementa rcx y repite hasta que se hayan convertido los 16 nibbles.
; -----------------------------------------------------------------------------
.store_char:
    mov byte [rsi + rcx - 1], bl  ; Guarda el carácter calculado en el buffer
    shr rax, 4                    ; Mueve el siguiente nibble a la parte baja de rax
    loop .hex_conv                ; Decrementa rcx, repite hasta agotar los 16 dígitos

    mov rax, 1                    ; syscall write
    mov rdi, 1                    ; descriptor de archivo 1 (stdout)
    mov rdx, 16                   ; longitud a escribir = 16 bytes
    syscall                       ; imprime el buffer de 16 caracteres

    add rsp, 16                   ; Libera los 16 bytes reservados
    pop rbx                       ; Restaura el registro rbx
    leave                         ; Restaura rbp y la pila
    ret                           ; Retorna de la función



; **************************************************************************************************************************************************
; Manejo de errores de apertura/lectura/escritura de archivos
; **************************************************************************************************************************************************

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

