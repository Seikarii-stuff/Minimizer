from PIL import Image, ImageDraw

SIZE = 512
THICKNESS = 52

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

margin = THICKNESS // 2 + 8
bbox = (
    margin,
    margin,
    SIZE - margin,
    SIZE - margin,
)

# U abierta arriba (dibuja la mitad inferior del círculo)
draw.arc(
    bbox,
    start=330,
    end=210,
    fill=(255, 255, 255, 255),
    width=THICKNESS,
)

# Guardar en TGA
img.save("wheel.tga", rle=False)