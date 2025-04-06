import numpy as np
import matplotlib.pyplot as plt

def main():
    # Ajustar estas dimensiones a lo que genere el ensamblador.
    # Ejemplo: 200 x 200
    alto = 200
    ancho = 200

    # Leer imagen_out.img en modo binario
    with open("imagen_out.img", "rb") as f:
        data = f.read()

    # Verificar si la cantidad de bytes coincide con alto*ancho
    num_bytes = len(data)
    esperado = alto*ancho
    if num_bytes < esperado:
        print(f"Advertencia: se esperaban {esperado} bytes, pero hay solo {num_bytes}.")
    elif num_bytes > esperado:
        print(f"Advertencia: se esperaban {esperado} bytes, pero hay {num_bytes}. (Sobrará algo?)")

    # Convertir a arreglo numpy
    arr = np.frombuffer(data, dtype=np.uint8, count=esperado)

    # Por si hay bytes de más, ignoramos el resto
    # si no quieres ignorar, quita "count=esperado"

    # Darle forma (alto, ancho)
    try:
        arr = arr.reshape((alto, ancho))
    except ValueError:
        print("No se pudo reajustar el buffer. Revisa las dimensiones o el archivo.")
        return

    # Mostrar con matplotlib
    plt.imshow(arr, cmap='gray')
    plt.title("Visualizando imagen_out.img")
    plt.show()

if __name__=="__main__":
    main()
