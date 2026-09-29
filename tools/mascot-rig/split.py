"""Împarte Licurici în straturi pentru animația din cod.

Intrare (assets-src/licurici/):
  base_green.jpg  personajul complet (aripi + braț cu baghetă), fundal verde
  body_green.jpg  aceeași poză fără aripi și fără brațul cu bagheta (generat din base)

Ieșire (apps/child_app/assets/mascot/licurici/):
  body.png, wing_left.png, wing_right.png, arm.png  (decupate, 1024 px pe latura mare a cadrului)
  rig.json  poziția fiecărui strat în cadrul comun + punctele de articulație

Aripile = ce e în base și nu e în body, fără braț. Zona ascunsă (sub corp și sub braț)
se completează prin difuzie din pixelii vecini, ca să nu apară găuri când se mișcă.
"""

import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from key import key_green  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "assets-src", "licurici")
OUT = os.path.join(ROOT, "apps", "child_app", "assets", "mascot", "licurici")
SCALE = 0.5  # 2048 -> 1024


def arr(im):
    return np.asarray(im).astype(np.float32) / 255.0


def to_im(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA")


def box_blur(a, r):
    """Blur cutie (2r+1) pe primele două axe, cu sume cumulative."""
    for axis in (0, 1):
        pad = [(0, 0)] * a.ndim
        pad[axis] = (r + 1, r)
        c = np.cumsum(np.pad(a, pad, mode="edge"), axis=axis)
        hi = np.take(c, np.arange(2 * r + 1, c.shape[axis]), axis=axis)
        lo = np.take(c, np.arange(0, c.shape[axis] - 2 * r - 1), axis=axis)
        a = (hi - lo) / (2 * r + 1)
    return a


def fill_hole(rgba, hole, iters=40):
    """Umple zona `hole` cu culori difuzate din vecinii opaci (convoluție normalizată)."""
    rgb = rgba[..., :3].copy()
    known = (rgba[..., 3] > 0.9) & ~hole
    w = known.astype(np.float32)
    for _ in range(iters):
        bw = box_blur(w, 4)
        est = box_blur(rgb * w[..., None], 4) / np.maximum(bw, 1e-6)[..., None]
        grow = hole & (bw > 0.05) & (w == 0)
        rgb = np.where(grow[..., None], est, rgb)
        w = np.where(grow, 1.0, w)
    out = rgba.copy()
    out[..., :3] = np.where(hole[..., None], rgb, rgba[..., :3])
    return out


def reconstruct(seed, mask):
    """Tot ce din `mask` e conectat de `seed` (8-vecini)."""
    cur = seed & mask
    while True:
        grown = np.asarray(Image.fromarray(cur.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(3))) > 0
        grown &= mask
        if (grown == cur).all():
            return cur
        cur = grown


def main():
    base = arr(key_green(Image.open(os.path.join(SRC, "base_green.jpg"))))
    body = arr(key_green(Image.open(os.path.join(SRC, "body_green.jpg"))))
    H, W = base.shape[:2]

    a_base = base[..., 3]
    a_body = body[..., 3]
    # corpul „crescut” puțin, ca marginea lui să nu rămână pe aripi
    body_mask = np.asarray(Image.fromarray((a_body > 0.5).astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(9))) > 0
    extra = (a_base > 0.5) & ~body_mask

    # brațul cu bagheta: în dreapta-jos, culori ne-lavandă (verde-turcoaz, maro, auriu, contur închis)
    yy, xx = np.mgrid[0:H, 0:W]
    rgb = base[..., :3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    # aripi: deschise, puțin saturate și cu albastrul >= verdele (lavandă/perlat);
    # corpul turcoaz are verdele peste albastru
    lavender = (mx > 0.55) & (sat < 0.35) & (rgb[..., 2] >= rgb[..., 1] - 0.01)
    region = (xx > W * 0.55) & (yy > H * 0.44) & (yy < H * 0.78)
    # peste pelerină: unde base diferă clar de body (braț turcoaz peste pelerina bleumarin)
    diff = np.abs(base[..., :3] - body[..., :3]).sum(-1)
    over_cape = body_mask & (diff > 0.35)
    arm_mask = region & (a_base > 0.5) & ((extra & ~lavender) | over_cape)
    # păstrează doar componenta mare (fără puncte izolate), apoi închide golurile
    am = Image.fromarray(arm_mask.astype(np.uint8) * 255)
    am = am.filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.MinFilter(9))
    arm_mask = (np.asarray(am) > 0) & (a_base > 0.5) & ~lavender
    # închiderea de mai sus poate lipi bucăți de aripă de braț: păstrăm doar ce e conectat
    # de bagheta maro (reconstrucție geodezică: dilatare repetată, limitată la mască)
    brown = (rgb[..., 0] > rgb[..., 1] + 0.08) & (rgb[..., 1] > rgb[..., 2]) & (mx < 0.6)
    arm_mask = reconstruct(arm_mask & brown, arm_mask)

    wing_mask = extra & ~arm_mask

    arm = base.copy()
    arm[..., 3] = np.where(arm_mask, a_base, 0)

    wings = base.copy()
    wings[..., 3] = np.where(wing_mask, a_base, 0)
    # completează aripile sub braț și puțin sub corp (zona din jurul rădăcinii)
    wing_hull = np.asarray(
        Image.fromarray(wing_mask.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(31)).filter(ImageFilter.MinFilter(21))
    ) > 0
    hole = wing_hull & ~wing_mask & (arm_mask | body_mask)
    wings = fill_hole(wings, hole)
    wings[..., 3] = np.where(hole, 1.0, wings[..., 3])

    cx = W / 2
    wl = wings.copy()
    wl[:, int(cx):, 3] = 0
    wr = wings.copy()
    wr[:, : int(cx), 3] = 0

    os.makedirs(OUT, exist_ok=True)
    layers = {"wing_left": wl, "wing_right": wr, "body": body, "arm": arm}
    rig = {"frame": [W * SCALE, H * SCALE], "layers": {}}
    for name, a in layers.items():
        im = to_im(a)
        bbox = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
        crop = im.crop(bbox)
        crop = crop.resize((round(crop.width * SCALE), round(crop.height * SCALE)), Image.LANCZOS)
        crop.save(os.path.join(OUT, f"{name}.png"), optimize=True)
        rig["layers"][name] = {"rect": [round(v * SCALE) for v in bbox]}
        print(name, bbox, crop.size)

    # pentru previzualizare
    prev = Image.new("RGBA", (W, H), (40, 40, 70, 255))
    for name in ["wing_left", "wing_right", "body", "arm"]:
        prev = Image.alpha_composite(prev, to_im(layers[name]))
    prev.resize((768, 768)).save(os.path.join(SRC, "_preview_split.png"))
    to_im(arm).resize((768, 768)).save(os.path.join(SRC, "_preview_arm.png"))
    to_im(wings).resize((768, 768)).save(os.path.join(SRC, "_preview_wings.png"))
    with open(os.path.join(OUT, "rig.json"), "w") as f:
        json.dump(rig, f, indent=2)


if __name__ == "__main__":
    main()
