from PIL import Image, ImageDraw

# =========================
# Configuración
# =========================

WIDTH = 256
HEIGHT = 256

# Ancho de cada franja blanca
STRIPE_WIDTH = 18

# Separación entre franjas
STRIPE_GAP = 46

# Grosor del borde negro
OUTLINE = 3

OUTPUT = "striped_pattern.tga"


# =========================
# Crear imagen transparente
# =========================

img = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)


# =========================
# Rayas diagonales
# =========================

period = STRIPE_WIDTH + STRIPE_GAP

# Dibujamos polígonos grandes que atraviesan
# toda la imagen para evitar problemas en las esquinas.
for offset in range(-HEIGHT, WIDTH + HEIGHT, period):

    # Polígono de la franja.
    # Dirección: diagonal descendente /
    points = [
        (offset, 0),
        (offset + STRIPE_WIDTH, 0),
        (offset + STRIPE_WIDTH - HEIGHT, HEIGHT),
        (offset - HEIGHT, HEIGHT),
    ]

    # Primero el borde negro.
    draw.polygon(
        points,
        fill=(0, 0, 0, 255),
    )

    # Después la parte blanca interior,
    # dejando OUTLINE píxeles de borde negro.
    inner = [
        (offset + OUTLINE, 0),
        (offset + STRIPE_WIDTH - OUTLINE, 0),
        (offset + STRIPE_WIDTH - HEIGHT - OUTLINE, HEIGHT),
        (offset - HEIGHT + OUTLINE, HEIGHT),
    ]

    draw.polygon(
        inner,
        fill=(255, 255, 255, 255),
    )


# =========================
# Guardar como TGA
# =========================

img.save(
    OUTPUT,
    format="TGA",
)

print(f"Generated: {OUTPUT}")