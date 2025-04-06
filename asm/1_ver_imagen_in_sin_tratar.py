import numpy as np
import matplotlib.pyplot as plt

def main():
    # Definimos las dimensiones que tendrá la imagen que vamos a leer.
    # En este caso, asumimos una imagen de 400 píxeles de alto por 400 de ancho.
    alto, ancho = 400, 400

    # Abrimos el archivo "imagen_in.img" en modo binario para leer todos sus bytes.
    with open("imagen_in.img", "rb") as f:
        data = f.read()

    # Convertimos los bytes del archivo en un arreglo de NumPy de tipo uint8 (valores de 0 a 255).
    # 'count=alto*ancho' limita la lectura de datos a la cantidad necesaria para rellenar la imagen de 400x400.
    arr = np.frombuffer(data, dtype=np.uint8, count=alto * ancho)

    # Ajustamos el arreglo unidimensional para que tenga forma de matriz de 400 filas y 400 columnas.
    arr = arr.reshape((alto, ancho))

    # Mostramos el contenido de la imagen en escala de grises usando matplotlib.
    plt.imshow(arr, cmap='gray')
    plt.title("Visualizando imagen_in.img (400x400)")
    plt.show()

if __name__ == "__main__":
    main()

