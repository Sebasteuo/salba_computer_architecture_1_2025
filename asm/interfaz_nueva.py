#!/usr/bin/env python3

import os
import subprocess
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

import numpy as np
from PIL import Image, ImageTk
import matplotlib
matplotlib.use("TkAgg")  # backend para usar en Tkinter
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure
import matplotlib.patches as patches
import matplotlib.patheffects as pe

ASSEMBLER_EXEC = "./procesamiento"
CONFIG_FILE    = "config.txt"
IMG_RAW_NAME   = "imagen_in.img"
IMG_OUT_NAME   = "imagen_out.img"

class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Procesamiento con matplotlib + cuadrícula + highlight relleno amarillo (sin ventana stdout)")
        self.geometry("1200x800")

        # (Opcional) estilo fondo oscuro, texto claro
        style = ttk.Style(self)
        style.theme_use("clam")
        style.configure(".", background="black", foreground="white")
        style.configure("TFrame", background="black", foreground="white")
        style.configure("TLabel", background="black", foreground="white")
        style.configure("TButton", background="black", foreground="white")

        # Creamos un estilo especial para el Spinbox con texto en negro
        style.configure("BlackSpin.TSpinbox",
                        foreground="black",
                        fieldbackground="white")

        self.configure(bg="black")

        self.selected_image_path = ""
        self.quadrant_var = tk.StringVar(value="1")

        self.create_widgets()

    def create_widgets(self):
        main_frame = ttk.Frame(self, padding=10)
        main_frame.pack(fill="both", expand=True)

        # Fila superior => 2 columnas
        self.frame_top_left = ttk.Frame(main_frame, borderwidth=1, relief="groove")
        self.frame_top_left.grid(row=0, column=0, sticky="nsew", padx=5, pady=5)

        self.frame_top_right = ttk.Frame(main_frame, borderwidth=1, relief="groove")
        self.frame_top_right.grid(row=0, column=1, sticky="nsew", padx=5, pady=5)

        # Fila inferior => subplots (matplotlib)
        self.frame_bottom = ttk.Frame(main_frame, borderwidth=1, relief="groove")
        self.frame_bottom.grid(row=1, column=0, columnspan=2, sticky="nsew", padx=5, pady=5)

        main_frame.rowconfigure(1, weight=1)
        main_frame.columnconfigure(0, weight=1)
        main_frame.columnconfigure(1, weight=1)

        # -- Imagen original (arriba izq)
        ttk.Label(self.frame_top_left, text="Imagen Original").pack(pady=5)
        self.lbl_original = ttk.Label(self.frame_top_left)
        self.lbl_original.pack(padx=5, pady=5)

        # -- Panel (arriba der) con info y controles
        ttk.Label(self.frame_top_right, text="Info / Parámetros").pack(pady=5)
        self.lbl_selected = ttk.Label(self.frame_top_right, text="(Ninguna imagen seleccionada)", wraplength=300)
        self.lbl_selected.pack(padx=5, pady=5)

        lbl_quad = ttk.Label(self.frame_top_right, text="Cuadrante (1..16):")
        lbl_quad.pack(pady=5)

        # Spinbox con estilo "BlackSpin.TSpinbox" => texto en negro
        self.spin = ttk.Spinbox(self.frame_top_right,
                                from_=1, to=16,
                                textvariable=self.quadrant_var,
                                width=5,
                                style="BlackSpin.TSpinbox")
        self.spin.pack(pady=5)

        btn_select = ttk.Button(self.frame_top_right, text="Seleccionar Imagen", command=self.select_image)
        btn_select.pack(pady=5)

        btn_process = ttk.Button(self.frame_top_right, text="Procesar", command=self.run_full_process)
        btn_process.pack(pady=5)

        # Figure de matplotlib con 3 subplots: Convertida, Cuadrante, Final
        self.fig = Figure(figsize=(8, 3), dpi=100)
        self.ax_conv = self.fig.add_subplot(131, title="Convertida")
        self.ax_quad = self.fig.add_subplot(132, title="Cuadrante")
        self.ax_final = self.fig.add_subplot(133, title="Final")

        self.canvas_mat = FigureCanvasTkAgg(self.fig, master=self.frame_bottom)
        self.canvas_mat.get_tk_widget().pack(fill="both", expand=True)

    def select_image(self):
        file_path = filedialog.askopenfilename(
            title="Seleccionar imagen (JPG/PNG)",
            filetypes=[("Imágenes", "*.jpg *.jpeg *.png *.bmp *.tif *.tiff"), ("Todos", "*.*")]
        )
        if file_path:
            self.selected_image_path = file_path
            self.lbl_selected.config(text=f"Seleccionada:\n{file_path}")

    def run_full_process(self):
        if not self.selected_image_path:
            messagebox.showerror("Error", "No has seleccionado imagen.")
            return

        quad_str = self.quadrant_var.get()
        if not quad_str.isdigit():
            messagebox.showerror("Error", "Cuadrante inválido.")
            return
        q = int(quad_str)
        if q < 1 or q > 16:
            messagebox.showerror("Error", "Cuadrante fuera de 1..16.")
            return

        # 1) Convert => imagen_in.img
        if not self.convert_to_raw(self.selected_image_path):
            return

        # 2) config.txt
        self.write_config(q)

        # 3) Ejecutar ensamblador (sin mostrar msg de stdout)
        self.run_assembler()

        # 4) Mostrar imágenes
        self.show_images(q)

    def convert_to_raw(self, file_path):
        cmd = [
            "convert",
            file_path,
            "-colorspace", "Gray",
            "-depth", "8",
            "-resize", "400x400!",
            "-type", "Grayscale",
            f"gray:{IMG_RAW_NAME}"
        ]
        try:
            subprocess.run(cmd, check=True)
            return True
        except FileNotFoundError:
            messagebox.showerror("Error", "No se encontró 'convert' (instala ImageMagick).")
        except subprocess.CalledProcessError as e:
            messagebox.showerror("Error", f"Fallo al convertir imagen:\n{e}")
        return False

    def write_config(self, quadrant):
        try:
            with open(CONFIG_FILE, "w") as f:
                f.write(f"{IMG_RAW_NAME}\n")
                f.write(f"{quadrant}\n")
        except Exception as e:
            messagebox.showerror("Error", f"No se pudo escribir {CONFIG_FILE}:\n{e}")

    def run_assembler(self):
        """
        Ejecuta ./procesamiento pero NO muestra ventanas con la salida.
        """
        if not os.path.exists(ASSEMBLER_EXEC):
            messagebox.showerror("Error", f"No se encontró {ASSEMBLER_EXEC}")
            return
        try:
            # Solo ejecutamos, sin mostrar messagebox
            # ni stdout, ni stderr
            subprocess.run([ASSEMBLER_EXEC], capture_output=True, text=True)
            # Si deseas ver la salida en consola Python:
            #   result = subprocess.run(...); print(result.stdout)
            # En este ejemplo lo omitimos por completo
        except Exception as e:
            messagebox.showerror("Error", f"Error ejecutando {ASSEMBLER_EXEC}:\n{e}")

    def show_images(self, quadrant):
        # 1) Imagen Original
        self.show_original()

        # 2) Convertida => leer imagen_in.img (400×400)
        arr_conv = self.read_raw_grayscale(IMG_RAW_NAME, 400, 400)
        # 3) Sub-bloque => 100×100, sin escalar
        arr_quad = self.extract_quadrant_100x100(IMG_RAW_NAME, quadrant)
        # 4) Final => 200×200
        arr_final = self.read_raw_grayscale(IMG_OUT_NAME, 200, 200)

        # Limpiar subplots
        self.ax_conv.clear()
        self.ax_quad.clear()
        self.ax_final.clear()

        # --- Mostrar Convertida (400×400) ---
        if arr_conv is not None:
            self.ax_conv.imshow(arr_conv, cmap="gray", origin="upper",
                                extent=[0, arr_conv.shape[1], arr_conv.shape[0], 0])
            self.ax_conv.set_title("Convertida")
            # Cuadrícula 4x4 + relleno amarillo
            self.draw_grid_4x4(self.ax_conv, arr_conv.shape[1], arr_conv.shape[0])
            self.highlight_quadrant_fill(self.ax_conv, quadrant)
        else:
            self.ax_conv.text(0.5, 0.5, "No data", ha="center", va="center")

        # --- Mostrar Cuadrante (100×100) ---
        if arr_quad is not None:
            self.ax_quad.imshow(arr_quad, cmap="gray", origin="upper",
                                extent=[0, arr_quad.shape[1], arr_quad.shape[0], 0])
            self.ax_quad.set_title(f"Cuadrante (size={arr_quad.shape})")
        else:
            self.ax_quad.text(0.5, 0.5, "No data", ha="center", va="center")

        # --- Mostrar Final (200×200) ---
        if arr_final is not None:
            self.ax_final.imshow(arr_final, cmap="gray", origin="upper",
                                 extent=[0, arr_final.shape[1], arr_final.shape[0], 0])
            self.ax_final.set_title("Final")
        else:
            self.ax_final.text(0.5, 0.5, "No data", ha="center", va="center")

        self.fig.tight_layout()
        self.canvas_mat.draw()

    def show_original(self):
        if not os.path.exists(self.selected_image_path):
            self.lbl_original.config(text="No existe la imagen original.")
            return
        try:
            im = Image.open(self.selected_image_path)
            im.thumbnail((300, 300))
            tk_img = ImageTk.PhotoImage(im)
            self.lbl_original.config(image=tk_img)
            self.lbl_original.image = tk_img
        except Exception as e:
            self.lbl_original.config(text="Error al cargar original")
            print(e)

    # -------------------------------------------------------------------------
    # Lectura .img crudo
    # -------------------------------------------------------------------------
    def read_raw_grayscale(self, path, width, height):
        """Lee un archivo .img (width x height) => numpy array (height, width)."""
        if not os.path.exists(path):
            return None
        try:
            with open(path, "rb") as f:
                data = f.read()
            if len(data) != width * height:
                return None
            arr = np.frombuffer(data, dtype=np.uint8).reshape((height, width))
            return arr
        except:
            return None

    def extract_quadrant_100x100(self, path, quadrant):
        """
        Lee imagen_in.img (400x400),
        extrae sub-bloque 100x100 sin escalar.
        """
        arr = self.read_raw_grayscale(path, 400, 400)
        if arr is None:
            return None
        q = quadrant - 1
        row = q // 4
        col = q % 4
        sub = arr[row*100:(row+1)*100, col*100:(col+1)*100]
        return sub

    # -------------------------------------------------------------------------
    # Cuadrícula y Highlight con relleno
    # -------------------------------------------------------------------------
    def draw_grid_4x4(self, ax, width, height):
        """
        Dibuja líneas rojas cada 100px en un 400×400,
        y la numeración (1..16) en el centro de cada sub-bloque.
        """
        for i in range(5):  # 0..4
            x = i * 100
            ax.axvline(x, color='red', linewidth=2,
                       path_effects=[pe.withStroke(linewidth=4, foreground='black')])
            y = i * 100
            ax.axhline(y, color='red', linewidth=2,
                       path_effects=[pe.withStroke(linewidth=4, foreground='black')])

        # Numeración sub-bloques
        for row in range(4):
            for col in range(4):
                q = row*4 + col + 1
                x_center = col*100 + 50
                y_center = row*100 + 50
                ax.text(x_center, y_center, str(q),
                        color='red', fontsize=12, ha='center', va='center',
                        path_effects=[pe.withStroke(linewidth=3, foreground='black')])

    def highlight_quadrant_fill(self, ax, quadrant):
        """
        Dibuja un rectángulo relleno amarillo con algo de transparencia
        para marcar el sub-bloque (1..16).
        """
        q = quadrant - 1
        row = q // 4
        col = q % 4

        x1 = col*100
        y1 = row*100

        rect = patches.Rectangle(
            (x1, y1), 100, 100,
            fill=True, facecolor='yellow', alpha=0.3,  # relleno semitransparente
            edgecolor='yellow', linewidth=3
        )
        ax.add_patch(rect)

def main():
    app = App()
    app.mainloop()

if __name__ == "__main__":
    main()

