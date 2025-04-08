Este proyecto implementa un flujo de trabajo para:

1. Convertir una imagen a formato crudo de 400×400 píxeles, 8 bits en escala de grises.
2. Leer los datos de configuración (ruta de la imagen y cuadrante) desde un archivo de texto (config.txt).
3. Procesar la imagen en Ensamblador x86_64 (NASM), extrayendo un sub-bloque (100×100) y realizando una interpolación bilineal 2× para generar una imagen de salida (200×200).
4. Mostrar en pantalla:
	Los checksums y mensajes de progreso en la consola (salida estándar).
5. Una interfaz en Python (Tkinter + Matplotlib) que permite seleccionar la imagen, elegir un cuadrante, ejecutar el procesamiento ensamblador y visualizar el resultado.

**************************************************************************************************************************************************************************
********************************************************************* HERRAMIENTAS USADAS ********************************************************************************
**************************************************************************************************************************************************************************


	1. NASM (Netwide Assembler) para compilar el código en ensamblador x86_64.

	2. ld (o en su defecto gcc) para enlazar el código ensamblador y generar el binario ejecutable.

	3. ImageMagick (comando convert) para convertir la imagen de entrada al formato crudo imagen_in.img.

			Se utiliza -colorspace Gray, -depth 8, -resize 400x400!, -type Grayscale y finalmente gray:archivo_salida.

	4. Python 3 para la interfaz gráfica y la lógica de control:

	5. Tkinter: para las ventanas, botones, labels y diálogos.

	6. Matplotlib: para la visualización de sub-imágenes y la generación de animaciones/fade in.

	7. PIL (Pillow): para cargar imágenes en Python.

	8. NumPy: para leer bytes crudos (.img) y convertirlos a arrays, y viceversa.

	9. OpenCV (cv2) para capturar la webcam en la ventana de Live View.

	10. Git para la gestión de versiones, con un flujo de ramas (development, feat/..., etc.).
	
	
	
**************************************************************************************************************************************************************************
********************************************************************* ESTRUCTURA DEL PROYECTO ****************************************************************************
**************************************************************************************************************************************************************************


	salba_computer_architecture_1_2025/
	 ┣ asm/
	 ┃  ┣ procesamiento.asm          (Código ensamblador principal)
	 ┃  ┣ ver_interfaz.py           (Interfaz principal en Python)
	 ┃  ┣ config.txt                (Archivo config con ruta y cuadrante)
	 ┃  ┣ imagen_in.img             (Imagen cruda 400×400 en escala de grises, 8 bits)
	 ┃  ┣ imagen_out.img            (Imagen interpolada 200×200 generada por el ASM)
	 ┃  ┣ [otros scripts extra]
	 ┣ doc/
	 ┃  ┗ ...
	 ┣ .gitignore
	 ┣ README.md (este archivo)
	 ┗ ...

	procesamiento.asm: contiene la lógica en ensamblador que:

		Lee config.txt para saber el archivo imagen_in.img y el cuadrante (1..16).

		Lee 160000 bytes (400×400) desde imagen_in.img.

		Extrae sub-bloque (100×100).

		Interpola 2× (200×200).

		Guarda imagen_out.img (40000 bytes).

		Imprime checksums de sub-bloque e imagen interpolada.


	ver_interfaz.py (o tu interfaz final en Python) que:

		Permite seleccionar la imagen original (JPG/PNG).

		Usa convert (ImageMagick) para generar imagen_in.img.

		Genera config.txt con la ruta (imagen_in.img) y el cuadrante.

		Llama a ./procesamiento (el ejecutable ensamblador).

		Visualiza en 3 paneles la imagen convertida (400×400), el sub-bloque (100×100) y la imagen final (200×200).


	config.txt: 2 líneas

		Primera línea: imagen_in.img (o la ruta del archivo .img).

		Segunda línea: número de cuadrante (1..16).


	imagen_in.img: archivo crudo de 400×400 bytes en gris.


	imagen_out.img: archivo crudo de 200×200 bytes en gris (resultado del ASM).


**************************************************************************************************************************************************************************
********************************************************************* INSTRUCCIONES DE USO *******************************************************************************
**************************************************************************************************************************************************************************


	-----------------------------------------------------------EJECUCION MANUAL (SIN INTERFAZ)-----------------------------------------------------------

	1. Crear o asegurar que exista config.txt con el contenido (Por ejemplo, la primera línea es el archivo .img y la segunda el cuadrante.):

		imagen_in.img
		3
		
	1.1 Si la imagen_in.img no se encuentra creada se puede crear con el siguiente comando:
		
		convert nombre_de_la_imagen.png \
		  -colorspace Gray \
		  -depth 8 \
		  -resize 400x400\! \
		  -type Grayscale \
		  gray:imagen_in.img
		  
		  Esto crea un archivo de exactamente 400×400 = 160000 bytes. Y en 8 bits/píxel: cada byte corresponde a un valor [0..255] en escala de grises.
		  
	2. Compilar el archivo ensamblador (procesamiento.asm) con NASM, generando un objeto ELF64, Enlazar con ld para crear el binario ejecutable:

		nasm -f elf64 procesamiento.asm -o procesamiento.o
		ld procesamiento.o -o procesamiento

	3. Ejecutar:

		./procesamiento
		
	El programa leerá config.txt, abrirá imagen_in.img (400×400 bytes), extraerá el sub-bloque según el cuadrante, interpolará a 200×200 y generará imagen_out.img.

	Por consola imprimirá algo como:

	Bytes leidos (hex): 0x0000000000027100
	Checksum sub-bloque (hex): 0x000000000000XXXX
	Checksum imagen interpolada (hex): 0x00000000000YYYYY
	Procesamiento finalizado. Se genero imagen_out.img


	4. Se puede comprobar el funcionamiento del procesamiento manualmente ejecutando estos scripts de python, estos scripts son uno por uno para verificar cada proceso por separado:

		> 1_ver_imagen_in_sin_tratar.py> Para ver la imagen cruda que entra a el procesamiento (imagen_in.img)
		> 2_ver_cuadrante_seleccionado> En otra terminal en el mismo folder ejecutar 2_ver_cuadrante_seleccionado.py imagen_in.img #Cuadrante para ver el cuadrante seleccionadosin ser procesado
		> 3_ver_imagen_out(cuadrante)_tratada.py> En otra termina en el mismo folder ejecutar 3_ver_imagen_out(cuadrante)_tratada.py para ver el cuadrante seleccionado ya finalmente procesado. Se debe ejecutar con comillas "3_ver_imagen_out(cuadrante)_tratada.py"
	





		
	-----------------------------------------------------------EJECUCION CON INTERFAZ-----------------------------------------------------------


	1. Se debe tener o instalar:
		Python 3
		Módulos: tkinter, matplotlib, PIL, numpy, opencv
		ImageMagick (para convert).


	2. Ejecutar la interfaz:
		python3 ver_interfaz.py
		
	4. Ventana de Bienvenida:
		
		La interfaz pide una imagen local (JPG/PNG).
		En las opciones de abajo se veran 2 botones, uno para cargar la imagen y otro deshabilitado. Este segundo se habilita cuando se carga la imagen.
		Al cargar la imagen, esta se presenta en la interfaz, luego puede darsele click al boton de procesar.		
		
	3. Ventana principal:
		En el panel superior derecho puede seleccionar el cuadrante, y darle click en Procesar, y en el panel de abajo se vera el resultado.
		
		En el panel superior derecho se puede volver a cargar otra imagen, cambiar la imagen, cambiar el cuadrante y procesar nuevamente sin necesidad de salir de la 					interfaz.

		Con el botón “Procesar”, internamente hace el procesamiento.


	4. Boton de Procesar:
		Genera config.txt con:

			imagen_in.img

			cuadrante (1..16).

			Corre ./procesamiento (ensamblador).

			Lee imagen_out.img y la muestra junto al sub-bloque y la imagen original 400×400.


	5. Si la interfaz tiene Live View (webcam), se puede tomar una foto y usar esa imagen capturada como fuente.

	6. En la GUI, hay una cuadrícula 4×4 para “cuadrantes” donde se selecciona el cuadrante que se quiere. Al presionar “Procesar” se ejecuta la lógica descrita.







