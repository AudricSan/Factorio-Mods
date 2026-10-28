"""Génère les icônes d'Electrified Railways (objets, technologies) à partir des icônes vanilla de
Factorio et de l'atlas de design : python design/make_icons.py [dossier data de Factorio]"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FACTORIO = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("C:/Program Files (x86)/Steam/steamapps/common/Factorio/data")
OUT = ROOT / "ElectrifiedRailways" / "graphics" / "icons"
OUT.mkdir(parents=True, exist_ok=True)
atlas = Image.open(next((ROOT / "design").glob("Atlas de cat*.png"))).convert("RGBA")
FONT = "C:/Windows/Fonts/arialbd.ttf"
ROMAN = {1: "I", 2: "II", 3: "III"}

# Couleurs de niveau : bleu, orange, rouge pour les transformateurs, vert, bleu, violet pour les batteries
TRANSFORMER_TINT = {1: (0.85, 0.95, 1.0), 2: (1.0, 0.85, 0.65), 3: (1.0, 0.7, 0.65)}
TRANSFORMER_BADGE = {1: (80, 150, 230), 2: (235, 150, 50), 3: (220, 70, 60)}
BATTERY_TINT = {1: (0.8, 1.0, 0.8), 2: (0.8, 0.9, 1.0), 3: (0.95, 0.8, 1.0)}
BATTERY_BADGE = {1: (90, 190, 90), 2: (80, 150, 230), 3: (170, 90, 220)}


def vanilla(rel, size):
    """Premier niveau de mipmap (carré) d'une icône vanilla."""
    return Image.open(FACTORIO / "base" / "graphics" / rel).convert("RGBA").crop((0, 0, size, size))


def tint(img, rgb):
    r, g, b, a = img.split()
    f = lambda band, k: band.point(lambda v: min(255, int(v * k)))
    return Image.merge("RGBA", (f(r, rgb[0]), f(g, rgb[1]), f(b, rgb[2]), a))


def badge(img, level, color):
    size = img.width
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, round(size * 0.34))
    text = ROMAN[level]
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    w, h = right - left, bottom - top
    pad = round(size * 0.05)
    x1, y1 = size - w - 2 * pad - 1, size - h - 2 * pad - 3
    draw.rounded_rectangle((x1, y1, size - 1, size - 1), radius=pad * 2, fill=(25, 25, 25, 235), outline=color + (255,), width=max(1, size // 40))
    draw.text((x1 + pad - left, y1 + pad - top), text, font=font, fill=(255, 255, 255, 255))
    return img


def paste_fit(base, img, box_height, anchor):
    scale = box_height / img.height
    img = img.resize((max(1, round(img.width * scale)), box_height), Image.LANCZOS)
    base.alpha_composite(img, (anchor[0] - img.width // 2, anchor[1] - img.height // 2))


# Icône du poteau : le poteau de l'atlas avec son bras et son isolateur
post_full = atlas.crop((1263, 13, 1372, 386))
post_full = post_full.crop(post_full.getbbox())
icon = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
draw = ImageDraw.Draw(icon)
# Deux poteaux face à face, avec fil porteur, pendules et fil de contact entre eux
left = post_full.resize((round(post_full.width * 236 / post_full.height), 236), Image.LANCZOS)
right = left.transpose(Image.FLIP_LEFT_RIGHT)
icon.alpha_composite(left, (24, 10))
icon.alpha_composite(right, (232 - right.width, 10))
x0, x1 = 24 + left.width - 30, 232 - right.width + 30
for t in range(0, 101):
    u = t / 100
    x = x0 + (x1 - x0) * u
    sag = 4 * u * (1 - u)
    draw.ellipse((x - 3, 70 + 22 * sag - 3, x + 3, 70 + 22 * sag + 3), fill=(175, 180, 188, 255))
    draw.ellipse((x - 3, 118 + 6 * sag - 3, x + 3, 118 + 6 * sag + 3), fill=(215, 150, 80, 255))
for u in (0.25, 0.5, 0.75):
    x = x0 + (x1 - x0) * u
    draw.line((x, 70 + 22 * 4 * u * (1 - u), x, 118 + 6 * 4 * u * (1 - u)), fill=(150, 150, 150, 255), width=4)
icon256 = icon
icon = icon.resize((64, 64), Image.LANCZOS)
icon.save(OUT / "er-catenary-pole.png")

# Icônes des transformateurs et des batteries
for level in (1, 2, 3):
    t = tint(vanilla("icons/train-stop.png", 64), TRANSFORMER_TINT[level])
    badge(t, level, TRANSFORMER_BADGE[level]).save(OUT / f"er-rail-transformer-{level}.png")
    b = tint(vanilla("icons/battery-equipment.png", 64), BATTERY_TINT[level])
    badge(b, level, BATTERY_BADGE[level]).save(OUT / f"er-train-battery-{level}.png")

# Locomotive électrique : icône vanilla virée au rouge électrique, avec un éclair
import colorsys
loco = vanilla("icons/locomotive.png", 64)
px = loco.load()
for y in range(64):
    for x in range(64):
        r, g, b, a = px[x, y]
        if a == 0:
            continue
        h, sat, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if sat > 0.35 and 0.02 < h < 0.15:      # le corps orange devient rouge profond
            h, sat, v = 0.995, min(1.0, sat * 1.1), v * 0.82
            r, g, b = (round(c * 255) for c in colorsys.hsv_to_rgb(h, sat, v))
            px[x, y] = (r, g, b, a)
bolt = [(44, 3), (30, 24), (38, 24), (30, 44), (52, 18), (43, 18), (50, 3)]
draw = ImageDraw.Draw(loco)
draw.polygon([(x + 1, y + 1) for x, y in bolt], fill=(20, 20, 20, 200))
draw.polygon(bolt, fill=(255, 220, 40, 255), outline=(60, 45, 0, 255))
loco.save(OUT.parent / "electric-locomotive.png")

# Technologies (256 px) : base vanilla + élément propre au mod
rail = vanilla("technology/railway.png", 256)
tech = rail.copy()
big_post = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
tech.alpha_composite(icon256)
tech.save(OUT / "tech-traction.png")

for level in (1, 2, 3):
    t = vanilla("technology/battery-equipment.png", 256)
    t = tint(t, BATTERY_TINT[level])
    badge(t, level, BATTERY_BADGE[level]).save(OUT / f"tech-battery-{level}.png")
    r = vanilla("technology/railway.png", 256)
    stop = tint(vanilla("icons/train-stop.png", 64), TRANSFORMER_TINT[level]).resize((128, 128), Image.LANCZOS)
    r.alpha_composite(stop, (120, 120))
    badge(r, level, TRANSFORMER_BADGE[level]).save(OUT / f"tech-transformer-{level}.png")

for p in sorted(OUT.glob("*.png")):
    print(p.name, Image.open(p).size)
