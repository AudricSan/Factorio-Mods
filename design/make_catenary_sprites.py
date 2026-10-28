"""Découpe les sprites de la caténaire dans l'atlas de design (fond transparent) et les écrit
dans ElectrifiedRailways/graphics. À relancer si l'atlas change : python design/make_catenary_sprites.py"""
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
atlas = Image.open(next((ROOT / "design").glob("Atlas de cat*.png"))).convert("RGBA")
out = ROOT / "ElectrifiedRailways" / "graphics"
out.mkdir(exist_ok=True)


def crop(box):
    return atlas.crop(box)


def fit(img, height):
    return img.resize((max(1, round(img.width * height / img.height)), height), Image.LANCZOS)


# Poteau : le fût et le socle de « post left », sans le bras ni l'isolateur (le script les dessine)
post = crop((1263, 13, 1372, 386))
arr = np.array(post)
arr[:215, :50, 3] = 0     # bras et isolateur à gauche
arr[:90, 93:, 3] = 0      # petit support à droite du chapiteau
post = Image.fromarray(arr)
post = post.crop(post.getbbox())
post = fit(post, 221)     # 3,45 cases à 64 px par case
post.save(out / "catenary-post.png")

# Ombre : le fût couché vers la droite, aplati et légèrement incliné vers le bas
alpha = post.split()[3]
lying = alpha.rotate(-90, expand=True)
lying = lying.resize((lying.width, round(lying.height * 0.5)), Image.LANCZOS)
tilt = lying.transform((lying.width, lying.height + 16), Image.AFFINE, (1, 0, 0, -0.07, 1, 0), Image.BICUBIC)
tilt = tilt.point(lambda v: int(v * 0.45))
shadow = Image.merge("RGBA", (Image.new("L", tilt.size, 0),) * 3 + (tilt,))
shadow.save(out / "catenary-post-shadow.png")

# Éléments tracés par le script
fit(crop((718, 706, 898, 774)), 40).save(out / "er-catenary-beam.png")
fit(crop((334, 840, 379, 940)), 56).save(out / "er-catenary-insulator.png")
strut = crop((23, 838, 146, 948))
strut = strut.crop(strut.getbbox())
strut.resize((round(strut.width * 0.6), round(strut.height * 0.6)), Image.LANCZOS).save(out / "er-catenary-strut.png")
fit(crop((589, 860, 659, 925)), 32).save(out / "er-catenary-clamp.png")
fit(crop((765, 842, 807, 941)), 40).save(out / "er-catenary-dropper.png")
