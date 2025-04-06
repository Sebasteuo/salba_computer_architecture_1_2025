import numpy as np
import matplotlib.pyplot as plt
import sys

def ver_cuadrante(image_path, quadrant):
    """
    Esta función lee un archivo binario que asume tiene dimensiones de 400 x 400 píxeles,
    lo organiza como una matriz de esa forma y luego muestra un área específica de 100 x 100.
    El área que se muestra depende del cuadrante (de 1 a 16) que se indique.
    """

    # Abrimos el archivo binario y leemos todo su contenido en la variable 'data'.
    with open(image_path, "rb") as f:
        data = f.read()

    # Verificamos si el tamaño del archivo coincide con 400*400 bytes.
    # Si es menor, nos faltan datos; si es mayor, ignoramos lo que sobra.
    if len(data) < 400 * 400:
        print(f"Advertencia: el archivo {image_path} tiene menos de {400*400} bytes.")
    elif len(data) > 400 * 400:
        print(f"Advertencia: el archivo {image_path} tiene más de {400*400} bytes. (Se ignora lo que excede)")

    # Convertimos los bytes leídos en un arreglo de NumPy, tomando solo 400*400 bytes.
    arr_in = np.frombuffer(data, dtype=np.uint8, count=400*400)

    # Le damos la forma de 400 filas y 400 columnas, como si fuera una imagen de 400x400 píxeles.
    arr_in = arr_in.reshape((400, 400))

    # Determinamos a qué fila y columna corresponde el cuadrante que se quiere mostrar.
    # Existen 4 filas de cuadrantes (0 a 3) y 4 columnas (0 a 3), así que hay 16 cuadrantes en total.
    # Para obtener la fila, dividimos (quadrant-1) entre 4,
    # para la columna, calculamos el módulo (quadrant-1) con 4.
    row = (quadrant - 1) // 4
    col = (quadrant - 1) % 4

    # Cada cuadrante mide 100x100 dentro de la imagen de 400x400.
    # Entonces calculamos el inicio en filas y columnas con base en el cuadrante.
    r_start = row * 100
    c_start = col * 100

    # Extraemos la sección de la imagen que corresponde a ese cuadrante.
    sub_block = arr_in[r_start:r_start + 100, c_start:c_start + 100]

    # Mostramos la sección (100x100) del cuadrante solicitado en escala de grises.
    plt.imshow(sub_block, cmap='gray')
    plt.title(f"Quadrant={quadrant}: sub-bloque 100x100")
    plt.show()

def main():
    # Verificamos que se hayan pasado suficientes argumentos al script:
    # 1) Nombre del archivo de imagen.
    # 2) El número de cuadrante que se desea visualizar.
    if len(sys.argv) < 3:
        print("Uso: python3 ver_cuadrante_sub.py <imagen_in.img> <quadrant>")
        sys.exit(1)

    image_path = sys.argv[1]
    quadrant = int(sys.argv[2])

    # Llamamos a la función para visualizar el cuadrante solicitado.
    ver_cuadrante(image_path, quadrant)

if __name__ == "__main__":
    main()


#Se debe ejecutar asi python3 2_ver_cuadrante_seleccionado.py "imagen_in.img" #DeCuadrante

