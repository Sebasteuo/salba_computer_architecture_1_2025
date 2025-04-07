import numpy as np
import matplotlib.pyplot as plt
import sys

def main():
    # 1) Leer quadrant desde quad.txt
    try:
        with open("quad.txt","r") as f:
            line = f.readline().strip()
        quad = int(line)
    except:
        print("No se pudo leer 'quad.txt' o no es un numero valido.")
        quad = 1

    # 2) Cargar imagen de entrada (400x400)
    try:
        data_in = open("imagen_in.img","rb").read()
    except:
        print("No se pudo leer 'imagen_in.img'")
        sys.exit(1)

    if len(data_in) != 400*400:
        print("imagen_in.img no tiene 160000 bytes")
        sys.exit(1)

    arr_in = np.frombuffer(data_in, dtype=np.uint8).reshape((400,400))

    # 3) Cargar imagen de salida (200x200)
    try:
        data_out = open("imagen_out.img","rb").read()
    except:
        print("No se pudo leer 'imagen_out.img'")
        sys.exit(1)

    if len(data_out) != 200*200:
        print("imagen_out.img no tiene 40000 bytes")
        sys.exit(1)

    arr_out = np.frombuffer(data_out, dtype=np.uint8).reshape((200,200))

    # 4) Calcular fila/col segun quadrante
    row = (quad-1)//4
    col = (quad-1)%4
    r_start = row*100
    c_start = col*100
    # Sub-bloque => 100x100
    sub_block = arr_in[r_start:r_start+100, c_start:c_start+100]

    # 5) Mostrar en 3 paneles:
    fig, axes = plt.subplots(1,3, figsize=(12,4))

    # Panel 1 => Imagen in + rect
    axes[0].imshow(arr_in, cmap='gray', origin='upper')
    axes[0].set_title("Imagen in (400x400)")
    # dibujar rectangulo
    rect = plt.Rectangle((c_start, r_start), 100, 100,
                         edgecolor='red', facecolor='none', lw=2)
    axes[0].add_patch(rect)
    axes[0].text(c_start+50, r_start+50, str(quad),
                 color='red', ha='center', va='center')

    # Panel 2 => El sub-bloque 100x100
    axes[1].imshow(sub_block, cmap='gray', origin='upper')
    axes[1].set_title(f"Sub-bloque (Q={quad})")

    # Panel 3 => Imagen out (200x200)
    axes[2].imshow(arr_out, cmap='gray', origin='upper')
    axes[2].set_title("Interpolada (200x200)")

    plt.tight_layout()

    # Aquí forzamos la ventana a abrir maximizada
    mng = plt.get_current_fig_manager()
    try:
        # Esto funciona en backends como Qt5Agg
        mng.window.showMaximized()
    except:
        # Si falla, otro intento (p.ej. TkAgg):
        try:
            mng.resize(*mng.window.maxsize())
        except:
            pass

    plt.show()

if __name__=="__main__":
    main()

