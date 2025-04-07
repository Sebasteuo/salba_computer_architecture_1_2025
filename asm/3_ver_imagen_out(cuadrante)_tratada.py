import numpy as np
import matplotlib.pyplot as plt

def main():
    # En esta sección definimos las dimensiones de la imagen que esperamos ver.
    # Por ejemplo, si nuestro asm produce una imagen de 200 píxeles de alto
    # por 200 píxeles de ancho
    alto = 200
    ancho = 200

    # Abrimos el archivo "imagen_out.img" en modo binario.
    # Este archivo debería contener los datos en crudo (bytes) de la imagen.
    with open("imagen_out.img", "rb") as f:
        data = f.read()

    # Calculamos la cantidad de bytes que deberíamos tener (alto * ancho)
    # y verificamos si el archivo tiene exactamente esa cantidad, menos o más.
    num_bytes = len(data)
    esperado = alto * ancho
    if num_bytes < esperado:
        print(f"Advertencia: se esperaban {esperado} bytes, pero solo hay {num_bytes}.")
    elif num_bytes > esperado:
        print(f"Advertencia: se esperaban {esperado} bytes, pero hay {num_bytes} (sobran algunos datos).")

    # Convertimos los bytes en un arreglo NumPy de 8 bits sin signo.
    # Al usar 'count=esperado', solo tomamos la cantidad de datos que nos interesa.
    arr = np.frombuffer(data, dtype=np.uint8, count=esperado)

    # Si hay bytes de más, con 'count=esperado' simplemente ignoramos el resto.
    # Si no quieres ignorarlos, quita ese parámetro.

    # Intentamos redimensionar el arreglo para que tenga la forma (alto, ancho).
    # Si no coincide la cantidad de datos, se lanzará un ValueError.
    try:
        arr = arr.reshape((alto, ancho))
    except ValueError:
        print("No se pudo ajustar el arreglo a las dimensiones especificadas. ")
        return

    # Finalmente, mostramos la imagen en escala de grises con matplotlib.
    plt.imshow(arr, cmap='gray')
    plt.title("Visualizando imagen_out.img")
    plt.show()

if __name__ == "__main__":
    main()

