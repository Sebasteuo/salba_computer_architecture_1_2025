import numpy as np
import matplotlib.pyplot as plt

def main():
    # Dimensiones que tiene tu imagen_in.img
    alto, ancho = 400, 400
    
    with open("imagen_in.img","rb") as f:
        data = f.read()

    # Asegurarte de que len(data) == 400*400 = 160000
    arr = np.frombuffer(data, dtype=np.uint8, count=alto*ancho)
    arr = arr.reshape((alto, ancho))

    plt.imshow(arr, cmap='gray')
    plt.title("Visualizando imagen_in.img (400x400)")
    plt.show()

if __name__ == "__main__":
    main()
