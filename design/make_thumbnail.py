"""Image de la page du mod : thumbnail.png (144x144, à la racine du mod) et une bannière de
présentation design/portal-banner.png, à partir de l'image « Locomotive rouge sous caténaire ».
python design/make_thumbnail.py"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
scene = Image.open(next((ROOT / "design").glob("Locomotive rouge*.png"))).convert("RGB")

# Miniature carrée autour de la locomotive et du portique
square = scene.crop((440, 105, 440 + 500, 105 + 500)).resize((144, 144), Image.LANCZOS)
square.save(ROOT / "ElectrifiedRailways" / "thumbnail.png")

# Bannière : la scène du haut avec le titre
banner = scene.crop((0, 0, 1536, 610))
draw = ImageDraw.Draw(banner, "RGBA")
draw.rectangle((0, 470, 1536, 610), fill=(10, 12, 16, 200))
title = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 64)
sub = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 30)
draw.text((50, 480), "Electrified Railways", font=title, fill=(255, 235, 200, 255))
draw.text((54, 552), "Electric locomotive, catenary gates, batteries and rail transformers", font=sub, fill=(235, 235, 235, 255))
banner.save(ROOT / "design" / "portal-banner.png")
