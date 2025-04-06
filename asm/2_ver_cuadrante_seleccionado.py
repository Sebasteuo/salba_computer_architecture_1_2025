import numpy as np
import matplotlib.pyplot as plt
import sys

def ver_cuadrante(image_path, quadrant):
    """
    Lee un archivo binario de 400x400 bytes (160000)
    Muestra el sub-bloque 100x100 que corresponde al 'quadrant' [1..16].
    """

    # 1) Leer archivo imagen_in.img (400x400 = 160000 bytes)
    with open(image_path, "rb") as f:
        data = f.read()

    if len(data) < 400*400:
        print(f"Advertencia: el archivo {image_path} tiene menos de {400*400} bytes.")
    elif len(data) > 400*400:
        print(f"Advertencia: el archivo {image_path} tiene más de {400*400} bytes. (Se ignora el sobrante)")

    # Convertir a array numpy de tamaño 400x400
    arr_in = np.frombuffer(data, dtype=np.uint8, count=400*400)
    arr_in = arr_in.reshape((400,400))

    # 2) Calcular fila/columna del cuadrante
    # quadrant en [1..16]. Dividimos la imagen en 4 filas (0..3) y 4 columnas (0..3), c/u 100x100
    # fila = (quadrant-1)//4, col = (quadrant-1)%4
    row = (quadrant-1)//4
    col = (quadrant-1)%4

    # Sub-bloque de 100x100
    r_start = row * 100
    c_start = col * 100
    sub_block = arr_in[r_start:r_start+100, c_start:c_start+100]

    # 3) Mostrar sub-bloque
    plt.imshow(sub_block, cmap='gray')
    plt.title(f"Quadrant={quadrant}: sub-bloque 100x100")
    plt.show()

def main():
    if len(sys.argv) < 3:
        print("Uso: python3 ver_cuadrante_sub.py <imagen_in.img> <quadrant>")
        sys.exit(1)

    image_path = sys.argv[1]
    quadrant = int(sys.argv[2])

    # Llamar a la funcion para visualizar
    ver_cuadrante(image_path, quadrant)

if __name__ == "__main__":
    main()
