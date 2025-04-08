#!/usr/bin/env python3
"""
Este archivo se ejecuta con Python 3 en un entorno Unix-like.
La línea 'shebang' indica dónde se ubica el intérprete de Python 3.
"""

# ---------------------------
# IMPORTS / BIBLIOTECAS
# ---------------------------
import os           # Para realizar operaciones del sistema (por ejemplo, comprobar si existe un archivo).
import subprocess   # Para invocar procesos externos (p.ej., llamar a 'convert' de ImageMagick o ejecutar el ensamblador).
import tkinter as tk            # Tkinter es la biblioteca estándar de Python para crear GUIs (interfaz gráfica).
from tkinter import ttk, filedialog, messagebox
"""
- ttk: Ofrece widgets 'tematizados' (botones, marcos, etc.) con estilos más modernos.
- filedialog: Permite abrir diálogos para seleccionar archivos, guardar archivos, etc.
- messagebox: Para mostrar ventanas emergentes de aviso, error o confirmación.
"""

import numpy as np              # Numpy para manejar arreglos de datos (por ejemplo, leer datos crudos en bytes y convertirlos a imágenes).
from PIL import Image, ImageTk  # PIL (Pillow) para manipular imágenes en Python; ImageTk para mostrar imágenes en Tkinter.
import matplotlib               # Matplotlib para dibujar gráficos e incrustarlos en Tkinter.
matplotlib.use("TkAgg")
"""
- Se especifica el backend "TkAgg" para que matplotlib dibuje dentro de un widget de Tkinter.
"""

from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
"""
- FigureCanvasTkAgg: Permite integrar la figura (gráfico) de Matplotlib directamente en un widget de Tkinter.
"""

from matplotlib.figure import Figure
"""
- Figure: Objeto principal de Matplotlib donde creamos subplots y dibujamos.
"""

import matplotlib.patches as patches
import matplotlib.patheffects as pe
"""
- patches: Para dibujar figuras geométricas (rectángulos, círculos, etc.) dentro de la figura de Matplotlib.
- patheffects: Efectos de trazo para resaltar líneas o textos.
"""

import cv2
"""
- OpenCV (cv2) para manipular la cámara (Live View). Permite capturar fotos, leer frames de la webcam, etc.
"""


# ------------------------------------------------------------------------------
# Clase: ToolTip
# ------------------------------------------------------------------------------
class ToolTip:
    """
    Esta clase se encarga de crear pequeñas ventanas emergentes (tooltips) al
    pasar el ratón por encima de un widget específico, mostrando un texto
    descriptivo. Ayuda a dar 'hints' al usuario sobre la función de un botón.
    """
    def __init__(self, widget, text):
        """
        Constructor:
        - widget: El widget de Tkinter al cual se le va a asociar el tooltip.
        - text: El texto que se mostrará en el globo de ayuda.
        """
        self.widget = widget      # Guardamos la referencia al widget
        self.text = text          # Guardamos el texto que se mostrará
        self.tipwindow = None     # Almacena la ventana emergente (si está abierta)

        # Asociamos eventos de ratón: al entrar y salir del widget
        widget.bind("<Enter>", self.showtip)
        widget.bind("<Leave>", self.hidetip)

    def showtip(self, event=None):
        """
        showtip: Se dispara al entrar el mouse en el widget.
        Crea una ventana Toplevel sin bordes para mostrar el tooltip.
        """
        if self.tipwindow or not self.text:
            return  # Si ya existe la ventana o no hay texto, salimos

        # Calculamos posición en pantalla para la ventana del tooltip
        x = self.widget.winfo_rootx() + 20
        y = self.widget.winfo_rooty() + self.widget.winfo_height() + 10

        # Creamos la ventana emergente
        self.tipwindow = tw = tk.Toplevel(self.widget)
        tw.wm_overrideredirect(1)  # Sin bordes, ni barra de título
        tw.wm_geometry(f"+{x}+{y}")  # Colocamos la ventana en la posición calculada

        # Creamos un label con el texto y estilo simple
        label = tk.Label(
            tw,
            text=self.text,
            background="lightyellow",
            relief=tk.SOLID,
            borderwidth=1,
            font=("tahoma", "8", "normal")
        )
        label.pack(ipadx=1, ipady=1)

    def hidetip(self, event=None):
        """
        hidetip: Se dispara al salir el mouse del widget.
        Destruye la ventana emergente si existe.
        """
        if self.tipwindow:
            self.tipwindow.destroy()
        self.tipwindow = None


# ------------------------------------------------------------------------------
# Clase: IntroWindow
# ------------------------------------------------------------------------------
class IntroWindow(tk.Toplevel):
    """
    IntroWindow es la ventana de bienvenida. Ocupa 1200x800 píxeles.
    - Muestra texto sobre la interpolación bilineal.
    - Permite al usuario cargar una imagen y la muestra en grande en la propia ventana.
    - Botón "Comenzar" cierra esta ventana y muestra la ventana principal (App).
    """
    def __init__(self, parent):
        """
        Constructor de IntroWindow.
        - parent: La ventana principal (App), la cual se ocultará hasta que
                  el usuario presione 'Comenzar' en esta ventana.
        """
        super().__init__(parent)
        self.parent = parent  # Guardamos referencia a la ventana principal

        # Ajustamos tamaño fijo y título
        self.geometry("1200x800")
        self.title("Procesamiento de Interpolación Bilineal")
        self.configure(bg="black")

        # Ocultamos la ventana principal mientras mostramos la intro
        self.parent.withdraw()

        # Estilo de la ventana de bienvenida (fondo negro, texto blanco)
        style = ttk.Style(self)
        style.theme_use("clam")
        style.configure(".", background="black", foreground="white")

        # Donde almacenaremos la ruta de la imagen seleccionada
        self.selected_image_path = None

        # Creamos un marco principal con margen de 20 px
        frame = ttk.Frame(self, padding=20)
        frame.pack(fill="both", expand=True)

        # Título grande
        lbl_title = ttk.Label(
            frame,
            text="Procesamiento de Interpolación Bilineal",
            font=("Helvetica", 20, "bold"),
            background="black",
            foreground="white"
        )
        lbl_title.pack(pady=15)

        # Texto de explicación
        texto_explicacion = (
            "La interpolación bilineal es un método para redimensionar o\n"
            "reconstruir imágenes, calculando cada píxel a partir de un\n"
            "promedio de los píxeles vecinos.\n\n"
            "¡Carga la imagen y luego haz clic en Comenzar!"
        )
        lbl_info = ttk.Label(
            frame,
            text=texto_explicacion,
            font=("Helvetica", 13),
            background="black",
            foreground="white",
            justify="center"
        )
        lbl_info.pack(pady=10)

        # Label donde mostraremos la imagen seleccionada (en grande)
        self.lbl_mini_imagen = ttk.Label(frame, background="black")
        self.lbl_mini_imagen.pack(pady=10)

        # Frame inferior para colocar los botones con íconos
        icons_frame = ttk.Frame(frame)
        icons_frame.pack(side=tk.BOTTOM, pady=30)

        # Preparamos íconos para "Cargar" y "Comenzar"
        icon_size = (64, 64)
        upload_img = Image.open("upload.png").resize(icon_size, Image.LANCZOS)
        self.upload_icon = ImageTk.PhotoImage(upload_img)

        play_img = Image.open("play.png").resize(icon_size, Image.LANCZOS)
        self.play_icon = ImageTk.PhotoImage(play_img)

        # Botón para Cargar (habilitado de entrada)
        btn_cargar = ttk.Button(
            icons_frame,
            image=self.upload_icon,
            style="Icon.TButton",
            command=self.cargar_imagen
        )
        btn_cargar.pack(side=tk.LEFT, padx=20)

        # Botón de Comenzar (deshabilitado hasta que se cargue imagen)
        self.btn_comenzar = ttk.Button(
            icons_frame,
            image=self.play_icon,
            style="Icon.TButton",
            command=self.comenzar,
            state="disabled"
        )
        self.btn_comenzar.pack(side=tk.LEFT, padx=20)

        # Si cierra esta ventana sin Comenzar, se cierra toda la aplicación
        self.protocol("WM_DELETE_WINDOW", self.salir)

    def cargar_imagen(self):
        """
        Abre un diálogo para seleccionar imagen, la muestra en grande (600x400).
        No muestra messagebox, sino que actualiza el label 'lbl_mini_imagen'.
        """
        file_path = filedialog.askopenfilename(
            title="Seleccionar imagen (JPG/PNG)",
            filetypes=[("Imágenes", "*.jpg *.jpeg *.png *.bmp *.tif *.tiff"), ("Todos", "*.*")]
        )
        if file_path:
            self.selected_image_path = file_path
            try:
                # Abrimos la imagen con Pillow
                im = Image.open(file_path)
                # Ajustamos a un tamaño grande, p.e. 600x400
                im.thumbnail((600, 400))
                imgtk = ImageTk.PhotoImage(im)
                self.lbl_mini_imagen.config(image=imgtk)
                self.lbl_mini_imagen.image = imgtk
            except Exception as e:
                print("Error cargando imagen:", e)
            # Al cargar imagen, habilitamos 'Comenzar'
            self.btn_comenzar.config(state="normal")

    def comenzar(self):
        """
        Función que cierra esta ventana e inmediatamente muestra la ventana principal.
        Asigna la imagen seleccionada a 'parent' para que se use en la ventana principal.
        """
        if not self.selected_image_path:
            return
        self.parent.selected_image_path = self.selected_image_path
        self.parent.show_original()

        # Cerramos la ventana de bienvenida
        self.destroy()
        # Mostramos la ventana principal (App)
        self.parent.deiconify()

    def salir(self):
        """
        Si cierran la ventana de bienvenida sin Comenzar, terminamos la app completa.
        """
        self.parent.destroy()


# ------------------------------------------------------------------------------
# Clase: QuadrantSelector
# ------------------------------------------------------------------------------
class QuadrantSelector(tk.Frame):
    """
    QuadrantSelector: Muestra una grilla 4x4 (16 celdas).
    - Cada celda tiene un número (1..16).
    - Al pasar el ratón, se ilumina un poco.
    - Al hacer clic, parpadea unas veces y queda en amarillo, llamando un callback
      para avisar qué cuadrante se seleccionó.
    """
    def __init__(self, parent, callback, *args, **kwargs):
        super().__init__(parent, *args, **kwargs)
        self.callback = callback
        self.configure(bg="black")

        self.labels = {}             # Diccionario: cuadrante -> Label
        self.selectedQuadrant = None # Cuadrante seleccionado

        for row in range(4):
            for col in range(4):
                # Calculamos el número de cuadrante
                q = row*4 + col + 1
                lbl = tk.Label(
                    self,
                    text=str(q),
                    width=4,
                    height=2,
                    bg="gray20",
                    fg="red",
                    font=("Arial", 14, "bold")
                )
                lbl.grid(row=row, column=col, padx=3, pady=3)

                # Guardamos referencia en un diccionario
                self.labels[q] = lbl

                # Vinculamos eventos de ratón: enter, leave, click
                lbl.bind("<Enter>", lambda e, quad=q: self.on_enter(quad))
                lbl.bind("<Leave>", lambda e, quad=q: self.on_leave(quad))
                lbl.bind("<Button-1>", lambda e, quad=q: self.on_click(quad))

    def on_enter(self, q):
        """
        Al pasar el ratón sobre un cuadrante, si no está seleccionado,
        cambiamos el fondo a gris claro para resaltarlo.
        """
        if self.selectedQuadrant == q:
            return
        self.labels[q].configure(bg="gray40")

    def on_leave(self, q):
        """
        Al salir el ratón, si no está seleccionado, vuelve a gris oscuro.
        """
        if self.selectedQuadrant == q:
            return
        self.labels[q].configure(bg="gray20")

    def on_click(self, q):
        """
        Al hacer clic, realizamos un 'blink' (parpadeo).
        Si había otro cuadrante seleccionado, lo volvemos a gris.
        """
        if self.selectedQuadrant and self.selectedQuadrant != q:
            old_lbl = self.labels[self.selectedQuadrant]
            old_lbl.configure(bg="gray20")
        self.blink(q, 0)

    def blink(self, q, count):
        """
        Efecto de parpadeo 2 ciclos on/off (4 pasos).
        Luego deja el label en amarillo y llama callback(q).
        """
        lbl = self.labels[q]
        if count < 4:
            new_bg = "yellow" if (count % 2 == 0) else "gray40"
            lbl.configure(bg=new_bg)
            self.after(150, lambda: self.blink(q, count+1))
        else:
            # Finalmente, dejamos amarillo
            lbl.configure(bg="yellow")
            self.selectedQuadrant = q
            # Avisamos al callback qué cuadrante se seleccionó
            if self.callback:
                self.callback(q)


# ------------------------------------------------------------------------------
# Clase: App (Ventana Principal)
# ------------------------------------------------------------------------------
class App(tk.Tk):
    """
    App es la ventana principal (1200x800):
    - Muestra la imagen original en la parte izq, y en la der la cuadrícula 4x4 y
      los botones (Cargar, Live, Procesar).
    - Abajo, tres subplots (Convertida, Cuadrante, Final) con animaciones de fade in y highlight.
    - Se crea un IntroWindow al inicio para la bienvenida. Cuando el usuario cierra la intro,
      aparece esta ventana.
    """
    def __init__(self):
        super().__init__()
        self.title("Procesamiento - Live View 'puro'")
        self.geometry("1200x800")
        self.configure(bg="black")

        # Estilos (fondo negro, texto blanco, etc.)
        style = ttk.Style(self)
        style.theme_use("clam")
        style.configure(".", background="black", foreground="white")
        style.configure("TFrame", background="black", foreground="white")
        style.configure("TLabel", background="black", foreground="white")

        style.configure("Icon.TButton",
                        background="black",
                        borderwidth=0,
                        relief="flat")

        style.map("Icon.TButton",
                  background=[
                      ("active", "#444444"),
                      ("pressed", "#333333")
                  ],
                  relief=[
                      ("pressed", "sunken")
                  ])

        # Ocultamos la ventana principal al inicio
        self.withdraw()

        self.selected_image_path = None     # Ruta de la imagen cargada
        self.quadrant_var = tk.IntVar(value=1)  # Cuadrante seleccionado

        # Variables para la cámara (Live)
        self.live_window = None
        self.live_label = None
        self.cap = None
        self.update_job_id = None

        # Arreglos de imagenes (arr_conv, arr_quad, arr_final) para las animaciones
        self.arr_conv = None
        self.arr_quad = None
        self.arr_final = None

        # Label para mostrar las dimensiones originales
        self.original_dims_label = None

        # Creamos la interfaz
        self.create_widgets()

        # Creamos la ventana de bienvenida (IntroWindow)
        self.intro = IntroWindow(self)

    def create_widgets(self):
        """
        create_widgets: Crea todos los frames, labels, botones, subplots, etc.
        de la ventana principal.
        """
        # Marco principal con padding=10
        main_frame = ttk.Frame(self, padding=10)
        main_frame.pack(fill="both", expand=True)

        # Frame (arriba izq) con borde
        self.frame_top_left = ttk.Frame(main_frame, borderwidth=1, relief="groove")
        self.frame_top_left.grid(row=0, column=0, sticky="nsew", padx=5, pady=5)

        # Frame (arriba der) con borde
        self.frame_top_right = ttk.Frame(main_frame, borderwidth=1, relief="groove")
        self.frame_top_right.grid(row=0, column=1, sticky="nsew", padx=5, pady=5)

        # Frame (abajo) con borde, abarca ambas columnas
        self.frame_bottom = ttk.Frame(main_frame, borderwidth=1, relief="groove")
        self.frame_bottom.grid(row=1, column=0, columnspan=2, sticky="nsew", padx=5, pady=5)

        # Hacemos que la fila 1 y columnas 0,1 se expandan al redimensionar
        main_frame.rowconfigure(1, weight=1)
        main_frame.columnconfigure(0, weight=1)
        main_frame.columnconfigure(1, weight=1)

        # En la parte izq: Imagen Original
        ttk.Label(self.frame_top_left, text="Imagen Original").pack(pady=5)
        self.lbl_original = ttk.Label(self.frame_top_left)
        self.lbl_original.pack(padx=5, pady=5)

        # Etiqueta para mostrar dimensiones originales
        self.original_dims_label = ttk.Label(self.frame_top_left, text="", foreground="yellow")
        self.original_dims_label.pack(pady=5)

        # En la parte der: Selector de cuadrantes y botones
        ttk.Label(self.frame_top_right, text="Seleccione Cuadrante:").pack(pady=5)
        self.quad_selector = QuadrantSelector(self.frame_top_right, callback=self.on_quadrant_selected)
        self.quad_selector.pack(pady=5)

        # Frame para los íconos (Cargar, Live, Procesar)
        icons_frame = ttk.Frame(self.frame_top_right)
        icons_frame.pack(pady=5)

        # Cargamos los íconos (upload, live-stream, play)
        icon_size = (64, 64)
        upload_img = Image.open("upload.png").resize(icon_size, Image.LANCZOS)
        self.upload_icon = ImageTk.PhotoImage(upload_img)

        live_img = Image.open("live-stream.png").resize(icon_size, Image.LANCZOS)
        self.live_icon = ImageTk.PhotoImage(live_img)

        play_img = Image.open("play.png").resize(icon_size, Image.LANCZOS)
        self.play_icon = ImageTk.PhotoImage(play_img)

        # Botón "Cargar"
        btn_upload = ttk.Button(
            icons_frame,
            style="Icon.TButton",
            image=self.upload_icon,
            command=self.select_image
        )
        btn_upload.pack(side=tk.LEFT, padx=5)
        # Tooltip
        ToolTip(btn_upload, "Cargar Imagen")

        # Botón "Live" (webcam)
        btn_live = ttk.Button(
            icons_frame,
            style="Icon.TButton",
            image=self.live_icon,
            command=self.open_live_view
        )
        btn_live.pack(side=tk.LEFT, padx=5)
        ToolTip(btn_live, "Vista en vivo (Webcam)")

        # Botón "Procesar" (llama a run_full_process)
        btn_process = ttk.Button(
            icons_frame,
            style="Icon.TButton",
            image=self.play_icon,
            command=self.run_full_process
        )
        btn_process.pack(side=tk.LEFT, padx=5)
        ToolTip(btn_process, "Procesar la imagen\n(animación y cuadrícula)")

        # Figure de Matplotlib
        self.fig = Figure(figsize=(8, 3), dpi=100)
        # Ajustamos márgenes para que no haya mucho espacio en blanco
        self.fig.subplots_adjust(left=0.05, right=0.95, top=0.90, bottom=0.05)

        # Creamos 3 subplots: Convertida, Cuadrante, Final
        self.ax_conv = self.fig.add_subplot(131, title="Convertida")
        self.ax_quad = self.fig.add_subplot(132, title="Cuadrante")
        self.ax_final = self.fig.add_subplot(133, title="Final")

        # Insertamos la figura en un widget de la parte de abajo
        self.canvas_mat = FigureCanvasTkAgg(self.fig, master=self.frame_bottom)
        self.canvas_mat.get_tk_widget().pack(fill="both", expand=True)

    def on_quadrant_selected(self, q):
        """
        on_quadrant_selected: Se llama cuando el usuario hace clic en un cuadrante
        en la grilla QuadrantSelector. Actualiza quadrant_var con ese valor.
        """
        self.quadrant_var.set(q)

    # ----------------------------------------------
    # LIVE VIEW
    # ----------------------------------------------
    def open_live_view(self):
        """
        Abre una ventana Toplevel donde se muestra la cámara en vivo, con un botón
        para tomar foto.
        """
        if self.live_window is not None and tk.Toplevel.winfo_exists(self.live_window):
            # Si ya está abierta, la traemos al frente
            self.live_window.lift()
            return

        self.live_window = tk.Toplevel(self)
        self.live_window.title("Live View - Webcam")
        self.live_window.protocol("WM_DELETE_WINDOW", self.close_live_window)

        # Iniciamos la cámara con OpenCV
        self.cap = cv2.VideoCapture(0)
        if not self.cap.isOpened():
            messagebox.showerror("Error", "No se pudo acceder a la webcam.")
            self.live_window.destroy()
            return

        # Label donde mostraremos el frame capturado
        self.live_label = tk.Label(self.live_window)
        self.live_label.pack()

        # Frame para el botón de tomar foto
        btn_frame = tk.Frame(self.live_window)
        btn_frame.pack(pady=5)

        # Cargamos icono "photo.png" para el botón
        photo_img = Image.open("photo.png").resize((64,64), Image.LANCZOS)
        self.photo_icon = ImageTk.PhotoImage(photo_img)

        # Botón para tomar foto
        btn_take = tk.Button(
            btn_frame,
            image=self.photo_icon,
            command=self.take_photo,
            bg="black",
            borderwidth=0,
            relief="flat"
        )
        btn_take.pack(side=tk.LEFT, padx=5)

        # Iniciamos actualización rápida (1 ms) para refrescar la cámara
        self.update_live_view_fast()

    def update_live_view_fast(self):
        """
        Lee frames de la cámara y los muestra en 'live_label'
        casi en tiempo real (cada 1ms).
        """
        if not self.cap or not self.cap.isOpened():
            return

        ret, frame = self.cap.read()
        if ret:
            # Convertimos BGR (OpenCV) a RGB (Pillow)
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            im = Image.fromarray(frame_rgb)
            imgtk = ImageTk.PhotoImage(im)
            self.live_label.config(image=imgtk)
            self.live_label.imgtk = imgtk

        # Si la ventana live sigue abierta, programamos la siguiente actualización
        if self.live_window is not None and tk.Toplevel.winfo_exists(self.live_window):
            self.update_job_id = self.live_label.after(1, self.update_live_view_fast)

    def take_photo(self):
        """
        Toma el frame actual y lo guarda como 'livephoto.png', luego la
        asigna como 'selected_image_path' y se cierra la ventana en 1 segundo.
        """
        if not self.cap or not self.cap.isOpened():
            messagebox.showerror("Error", "No hay cámara activa.")
            return

        # Cancelamos la actualización continua
        if self.update_job_id is not None:
            self.live_label.after_cancel(self.update_job_id)
            self.update_job_id = None

        # Leemos un frame
        ret, frame = self.cap.read()
        if ret:
            outfile = "livephoto.png"
            cv2.imwrite(outfile, frame)  # Guardamos el frame como .png
            self.selected_image_path = outfile
            self.show_original()

            # Mostramos la foto capturada (congelada) en la live window
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            im = Image.fromarray(frame_rgb)
            imgtk = ImageTk.PhotoImage(im)
            self.live_label.config(image=imgtk)
            self.live_label.imgtk = imgtk

            # Cerramos la ventana tras 1 segundo
            self.live_label.after(1000, self.close_live_window)
        else:
            messagebox.showerror("Error", "No se pudo capturar el frame.")

    def close_live_window(self):
        """
        Cierra la ventana de Live, liberando la cámara y cancelando
        cualquier actualización pendiente.
        """
        if self.cap:
            self.cap.release()
        if self.live_window:
            if self.update_job_id is not None:
                self.live_label.after_cancel(self.update_job_id)
                self.update_job_id = None
            self.live_window.destroy()
        self.live_window = None

    # ----------------------------------------------
    # CARGAR IMAGEN
    # ----------------------------------------------
    def select_image(self):
        """
        select_image: Abre un diálogo para escoger la imagen desde el disco,
        y llama show_original() para mostrarla.
        """
        file_path = filedialog.askopenfilename(
            title="Seleccionar imagen (JPG/PNG)",
            filetypes=[("Imágenes", "*.jpg *.jpeg *.png *.bmp *.tif *.tiff"), ("Todos", "*.*")]
        )
        if file_path:
            self.selected_image_path = file_path
            self.show_original()

    def show_original(self):
        """
        Carga la imagen 'self.selected_image_path' con Pillow, la redimensiona
        a 400x400, y la muestra en 'lbl_original'. También muestra dimensiones originales.
        """
        if not self.selected_image_path or not os.path.exists(self.selected_image_path):
            self.lbl_original.config(text="No existe la imagen original.")
            if self.original_dims_label:
                self.original_dims_label.config(text="")
            return
        try:
            im = Image.open(self.selected_image_path)
            w_orig, h_orig = im.size
            im.thumbnail((400, 400))
            tk_img = ImageTk.PhotoImage(im)
            self.lbl_original.config(image=tk_img)
            self.lbl_original.image = tk_img

            if self.original_dims_label:
                self.original_dims_label.config(
                    text=f"Dimensiones originales de la imagen: {w_orig} x {h_orig}"
                )
        except Exception as e:
            self.lbl_original.config(text="Error al cargar original")
            if self.original_dims_label:
                self.original_dims_label.config(text="")
            print(e)

    # ----------------------------------------------
    # PROCESAR (con fade in y highlight)
    # ----------------------------------------------
    def run_full_process(self):
        """
        run_full_process: Ejecuta toda la secuencia de procesamiento:
        1) Convertir imagen a grayscale 400x400 => imagen_in.img
        2) Escribir config.txt con 'imagen_in.img' y el cuadrante
        3) Ejecutar el ensamblador ./procesamiento
        4) Mostrar animaciones (fade in + highlight en Convertida,
           fade in de Cuadrante, fade in de Final).
        """
        if not self.selected_image_path:
            messagebox.showerror("Error", "No has seleccionado imagen.")
            return

        q = self.quadrant_var.get()
        if q < 1 or q > 16:
            messagebox.showerror("Error", "Cuadrante fuera de 1..16.")
            return

        # 1) Convert => 'imagen_in.img'
        if not self.convert_to_raw(self.selected_image_path):
            return

        # 2) config.txt
        self.write_config(q)

        # 3) Ejecutar ensamblador
        self.run_assembler()

        # 4) Iniciar las animaciones
        self.show_images_in_steps(q)

    def convert_to_raw(self, file_path):
        """
        Llama a 'convert' (ImageMagick) para convertir la imagen a:
        - Grayscale
        - 8 bits
        - 400x400
        - Lo escribe en un archivo raw: 'imagen_in.img'
        """
        cmd = [
            "convert",
            file_path,
            "-colorspace", "Gray",
            "-depth", "8",
            "-resize", "400x400!",
            "-type", "Grayscale",
            "gray:imagen_in.img"
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
        """
        Genera un archivo 'config.txt' donde:
        - Primera línea: nombre del archivo raw ('imagen_in.img')
        - Segunda línea: cuadrante (1..16)
        """
        try:
            with open("config.txt", "w") as f:
                f.write("imagen_in.img\n")
                f.write(f"{quadrant}\n")
        except Exception as e:
            messagebox.showerror("Error", f"No se pudo escribir config.txt:\n{e}")

    def run_assembler(self):
        """
        Ejecuta el ensamblador './procesamiento', que tomará 'imagen_in.img'
        y generará 'imagen_out.img', usando config.txt para saber el cuadrante.
        """
        assembler_exec = "./procesamiento"
        if not os.path.exists(assembler_exec):
            messagebox.showerror("Error", f"No se encontró {assembler_exec}")
            return
        try:
            subprocess.run([assembler_exec], capture_output=True, text=True)
        except Exception as e:
            messagebox.showerror("Error", f"Error ejecutando {assembler_exec}:\n{e}")

    def show_images_in_steps(self, quadrant):
        """
        1) Lee los archivos raw (imagen_in.img, imagen_out.img).
        2) Limpia subplots.
        3) Llama a fade_in_conv -> animate_highlight_movement -> fade_in_quad -> fade_in_final
        """
        self.arr_conv = self.read_raw_grayscale("imagen_in.img", 400, 400)
        self.arr_quad = self.extract_quadrant_100x100("imagen_in.img", quadrant)
        self.arr_final = self.read_raw_grayscale("imagen_out.img", 200, 200)

        self.ax_conv.clear()
        self.ax_quad.clear()
        self.ax_final.clear()
        self.canvas_mat.draw()

        # Iniciamos la animación
        self.fade_in_conv(quadrant)

    def fade_in_conv(self, quadrant, step=0, steps_fade=6, delay_fade=30):
        """
        fade_in_conv: Aparece gradualmente la imagen convertida (arr_conv).
        También dibuja la cuadrícula (líneas rojas).
        Al terminar, llama a animate_highlight_movement para resaltar el cuadrante.
        """
        alpha = step / steps_fade
        self.ax_conv.clear()

        if self.arr_conv is not None:
            # Mostramos la imagen con alpha
            self.ax_conv.imshow(self.arr_conv, cmap="gray",
                                alpha=alpha,
                                extent=[0,400,400,0],
                                origin="upper")

            self.ax_conv.set_xlim(0,400)
            self.ax_conv.set_ylim(400,0)
            self.ax_conv.set_aspect('equal', 'box')
            self.ax_conv.set_title("Convertida")

            # Dibujamos la cuadrícula (4x4)
            self.draw_grid_4x4(self.ax_conv, 400, 400)

        self.canvas_mat.draw()

        if step < steps_fade:
            self.after(delay_fade, lambda: self.fade_in_conv(quadrant, step+1, steps_fade, delay_fade))
        else:
            # Terminamos el fade in de la imagen Convertida,
            # ahora iniciamos el movimiento del rectángulo amarillo
            self.animate_highlight_movement(quadrant, current=1)

    def animate_highlight_movement(self, quadrant, current=1, delay_move=150):
        """
        Mueve el rectángulo amarillo desde 1 hasta 'quadrant' en la imagen Convertida,
        mostrando la cuadrícula en cada paso.
        """
        self.ax_conv.clear()

        if self.arr_conv is not None:
            self.ax_conv.imshow(self.arr_conv, cmap="gray",
                                extent=[0,400,400,0],
                                origin="upper")
            self.ax_conv.set_xlim(0,400)
            self.ax_conv.set_ylim(400,0)
            self.ax_conv.set_aspect('equal', 'box')
            self.ax_conv.set_title("Convertida")

            self.draw_grid_4x4(self.ax_conv, 400, 400)

        # Pintamos el cuadrante 'current' de amarillo
        self.highlight_quadrant_fill(self.ax_conv, current)
        self.canvas_mat.draw()

        if current < quadrant:
            self.after(delay_move, lambda: self.animate_highlight_movement(quadrant, current+1, delay_move))
        else:
            # Llegamos al cuadrante final
            self.fade_in_quad()

    def fade_in_quad(self, step=0, steps_fade=6, delay_fade=30):
        """
        fade_in_quad: Aparece gradualmente la sub-imagen (100x100) del cuadrante seleccionado.
        """
        alpha = step / steps_fade
        self.ax_quad.clear()

        if self.arr_quad is not None:
            self.ax_quad.imshow(self.arr_quad, cmap="gray",
                                alpha=alpha,
                                extent=[0,100,100,0],
                                origin="upper")
            self.ax_quad.set_xlim(0,100)
            self.ax_quad.set_ylim(100,0)
            self.ax_quad.set_aspect('equal', 'box')
            self.ax_quad.set_title("Cuadrante")

        self.canvas_mat.draw()

        if step < steps_fade:
            self.after(delay_fade, lambda: self.fade_in_quad(step+1, steps_fade, delay_fade))
        else:
            # Terminamos la animación del cuadrante
            self.fade_in_final()

    def fade_in_final(self, step=0, steps_fade=6, delay_fade=30):
        """
        fade_in_final: Despliega gradualmente la imagen final generada por el ensamblador
        (imagen_out.img, 200x200).
        """
        alpha = step / steps_fade
        self.ax_final.clear()

        if self.arr_final is not None:
            self.ax_final.imshow(self.arr_final, cmap="gray",
                                 alpha=alpha,
                                 extent=[0,200,200,0],
                                 origin="upper")
            self.ax_final.set_xlim(0,200)
            self.ax_final.set_ylim(200,0)
            self.ax_final.set_aspect('equal', 'box')
            self.ax_final.set_title("Final")

        self.canvas_mat.draw()

        if step < steps_fade:
            self.after(delay_fade, lambda: self.fade_in_final(step+1, steps_fade, delay_fade))
        else:
            # Terminó la animación final
            pass

    # ----------------------------------------------
    # Lectura de archivos RAW
    # ----------------------------------------------
    def read_raw_grayscale(self, path, width, height):
        """
        Abre un archivo binario con 'width*height' bytes, interpretados como 8 bits (uint8).
        Devuelve un arreglo numpy con forma (height, width).
        """
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
        Dado un RAW de 400x400, extrae un sub-bloque 100x100 correspondiente
        al 'quadrant' (1..16). Devuelve la porción de la matriz.
        """
        arr = self.read_raw_grayscale(path, 400, 400)
        if arr is None:
            return None
        q = quadrant - 1
        row = q // 4
        col = q % 4
        sub = arr[row*100:(row+1)*100, col*100:(col+1)*100]
        return sub

    def draw_grid_4x4(self, ax, width, height):
        """
        Dibuja líneas rojas formando una cuadrícula 4x4 en 'ax', con ejes
        adaptados a (width, height).
        """
        for i in range(5):
            x = i * 100
            ax.axvline(
                x, color='red', linewidth=2,
                path_effects=[pe.withStroke(linewidth=4, foreground='black')]
            )
            y = i * 100
            ax.axhline(
                y, color='red', linewidth=2,
                path_effects=[pe.withStroke(linewidth=4, foreground='black')]
            )
        # Numeramos cada sub-bloque (1..16)
        for row in range(4):
            for col in range(4):
                q = row*4 + col + 1
                x_center = col*100 + 50
                y_center = row*100 + 50
                ax.text(
                    x_center, y_center, str(q),
                    color='red', fontsize=12,
                    ha='center', va='center',
                    path_effects=[pe.withStroke(linewidth=3, foreground='black')]
                )

    def highlight_quadrant_fill(self, ax, quadrant):
        """
        Dibuja un rectángulo amarillo semitransparente (alpha=0.3)
        sobre el cuadrante seleccionado (1..16).
        """
        q = quadrant - 1
        row = q // 4
        col = q % 4
        x1 = col * 100
        y1 = row * 100
        rect = patches.Rectangle(
            (x1, y1), 100, 100,
            fill=True,
            facecolor='yellow',
            alpha=0.3,
            edgecolor='yellow',
            linewidth=3
        )
        ax.add_patch(rect)


def main():
    """
    Función principal. Crea la App y ejecuta el bucle principal de Tkinter.
    """
    app = App()
    app.mainloop()

if __name__ == "__main__":
    main()

