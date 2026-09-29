"""Împarte Licurici în straturi pentru animația din cod.

Intrare (assets-src/licurici/):
  base_green.jpg  personajul complet (aripi + braț cu baghetă), fundal verde
  body_green.jpg  aceeași poză fără aripi și fără brațul cu bagheta (generat din base)

Ieșire (apps/child_app/assets/mascot/licurici/):
  body.png, wing_left.png, wing_right.png, arm.png  (decupate, 1024 px pe latura mare a cadrului)
  rig.json  poziția fiecărui strat în cadrul comun (`rect`), punctele de articulație (`pivot`:
            rădăcina aripilor, umărul) și reperele efectelor desenate în cod (`anchors`: lanterna,
            vârful baghetei, ochii pentru clipit, culoarea pielii). Toate în coordonatele cadrului 1024.

Dependențe: pip install numpy pillow scipy

Aripile = ce e în base și nu e în body, fără braț. Zona ascunsă (sub corp și sub braț)
se completează prin difuzie din pixelii vecini, ca să nu apară găuri când se mișcă.
"""

import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

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


def largest(mask):
    """Cea mai mare componentă conexă din `mask`."""
    lab, _ = ndi.label(mask)
    sizes = np.bincount(lab.ravel())
    sizes[0] = 0
    return lab == sizes.argmax()


def contact_point(part, other, reach=30):
    """Centrul zonei din `part` aflate la cel mult `reach` px de `other` (rădăcina articulației)."""
    near = part & ndi.binary_dilation(other, iterations=reach)
    ys, xs = np.nonzero(near if near.any() else part)
    return float(xs.mean()), float(ys.mean())


def rnd(v):
    """Rotunjește recursiv numerele (rig.json lizibil)."""
    if isinstance(v, dict):
        return {k: rnd(x) for k, x in v.items()}
    if isinstance(v, (list, tuple)):
        return [rnd(x) for x in v]
    if isinstance(v, (float, np.floating)):
        return round(float(v), 1)
    return v


def main():
    base = arr(key_green(Image.open(os.path.join(SRC, "base_green.jpg"))))
    body = arr(key_green(Image.open(os.path.join(SRC, "body_green.jpg"))))
    H, W = base.shape[:2]

    a_base = base[..., 3]
    a_body = body[..., 3]
    # corpul „crescut” puțin, ca marginea lui să nu rămână pe aripi
    body_mask = ndi.binary_dilation(a_body > 0.5, iterations=4)
    extra = (a_base > 0.5) & ~body_mask

    # brațul cu bagheta: în dreapta-jos. Clasificare pe culori (turcoaz, contur închis, maro, auriu),
    # apoi doar componenta conexă mare. Aripa lavandă/perlată nu intră în nicio clasă, deci nu mai
    # rămân resturi de aripă (nici strălucirea stelei pe aripă, care e aproape albă).
    yy, xx = np.mgrid[0:H, 0:W]
    rgb = base[..., :3]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    teal = (g > r + 0.03) & (g > b - 0.06) & (sat > 0.12)
    dark = (mx < 0.5) & (b - g < 0.12) & (g > r - 0.02) & (sat > 0.15)  # conturul (nu pelerina bleumarin)
    brown = (r > g + 0.06) & (g > b) & (mx < 0.65)
    gold = (r > 0.55) & (r >= g - 0.02) & (g > b + 0.12)
    arm_colors = teal | dark | brown | gold
    region = (xx > W * 0.55) & (yy > H * 0.44) & (yy < H * 0.78)
    # peste pelerină: unde base diferă clar de body (braț turcoaz peste pelerina bleumarin)
    diff = np.abs(base[..., :3] - body[..., :3]).sum(-1)
    cand = region & (a_base > 0.5) & (extra | (body_mask & (diff > 0.35)))
    arm_mask = largest(ndi.binary_closing(ndi.binary_opening(cand & arm_colors), iterations=4))
    # a doua trecere: conturul brațului acolo unde base ≈ body (fără pixelii identici cu trunchiul)
    same = (a_body > 0.5) & (diff < 0.15)
    ring = ndi.binary_dilation(arm_mask, iterations=14) & region & (a_base > 0.5) & arm_colors & ~same
    arm_mask = largest(ndi.binary_closing(arm_mask | ring, iterations=3))
    arm_mask = ndi.binary_fill_holes(arm_mask) & (a_base > 0.3)

    wing_mask = extra & ~arm_mask

    arm = base.copy()
    arm[..., 3] = np.where(arm_mask, a_base, 0)

    wings = base.copy()
    wings[..., 3] = np.where(wing_mask, a_base, 0)
    # completează aripile sub braț și puțin sub corp (zona din jurul rădăcinii)
    wing_hull = ndi.binary_erosion(ndi.binary_dilation(wing_mask, iterations=15), iterations=10)
    hole = wing_hull & ~wing_mask & (arm_mask | body_mask)
    wings = fill_hole(wings, hole)
    wings[..., 3] = np.where(hole, 1.0, wings[..., 3])

    cx = W / 2
    wl = wings.copy()
    wl[:, int(cx):, 3] = 0
    wr = wings.copy()
    wr[:, : int(cx), 3] = 0

    # articulațiile (în cadrul 2048, scalate la scriere): rădăcina fiecărei aripi = unde atinge
    # corpul; umărul = capătul de sus al brațului
    body_solid = a_body > 0.5
    pivots = {
        "wing_left": contact_point(wing_mask & (xx < cx), body_solid),
        "wing_right": contact_point(wing_mask & (xx >= cx), body_solid),
    }
    ys, xs = np.nonzero(arm_mask)
    top = ys < ys.min() + 60
    pivots["arm"] = (float(xs[top].mean()), float(ys[top].mean()) + 20)

    # repere pentru efectele desenate în cod: lanterna (burta), vârful baghetei, ochii
    brgb = body[..., :3]
    lantern = largest(body_solid & (brgb[..., 0] > 0.85) & (brgb[..., 1] > 0.6) & (brgb[..., 2] < 0.55))
    ys, xs = np.nonzero(lantern)
    star = arm_mask & gold
    sy, sx = np.nonzero(star)
    # ochii: irisul mov (roșu ≈ albastru, mult peste verde), în jumătatea de sus
    purple = body_solid & (brgb[..., 2] > brgb[..., 1] + 0.12) & (brgb[..., 0] > brgb[..., 1] + 0.05) & (yy < H * 0.4)
    lab, n = ndi.label(ndi.binary_closing(purple, iterations=3))
    sizes = np.bincount(lab.ravel())
    sizes[0] = 0
    eyes = []
    for k in np.argsort(sizes)[::-1][:2]:
        ey, ex = np.nonzero(lab == k)
        eyes.append({"center": [ex.mean() * SCALE, ey.mean() * SCALE], "radius": [(ex.max() - ex.min()) / 2 * SCALE, (ey.max() - ey.min()) / 2 * SCALE]})
    eyes.sort(key=lambda e: e["center"][0])
    # culoarea pielii (pleoapa desenată la clipit): mediana turcoazului de lângă ochi
    ey0 = int(min(e["center"][1] for e in eyes) / SCALE)
    skin_zone = body_solid & (np.abs(yy - ey0 - 110) < 30) & (np.abs(xx - W / 2) < 60)
    skin = np.median(brgb[skin_zone], axis=0)
    anchors = {
        "lantern": {"center": [xs.mean() * SCALE, ys.mean() * SCALE], "radius": (xs.max() - xs.min()) / 2 * SCALE},
        "wand_tip": [sx.mean() * SCALE, sy.mean() * SCALE],
        "eyes": eyes,
        "skin": "#%02x%02x%02x" % tuple(int(v * 255) for v in skin),
    }

    os.makedirs(OUT, exist_ok=True)
    layers = {"wing_left": wl, "wing_right": wr, "body": body, "arm": arm}
    rig = {"frame": [W * SCALE, H * SCALE], "layers": {}, "anchors": rnd(anchors)}
    for name, a in layers.items():
        im = to_im(a)
        bbox = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
        crop = im.crop(bbox)
        crop = crop.resize((round(crop.width * SCALE), round(crop.height * SCALE)), Image.LANCZOS)
        crop.save(os.path.join(OUT, f"{name}.png"), optimize=True)
        rig["layers"][name] = {"rect": [round(v * SCALE) for v in bbox]}
        if name in pivots:
            rig["layers"][name]["pivot"] = [round(v * SCALE, 1) for v in pivots[name]]
        print(name, bbox, crop.size)

    # pentru previzualizare
    prev = Image.new("RGBA", (W, H), (40, 40, 70, 255))
    for name in ["wing_left", "wing_right", "body", "arm"]:
        prev = Image.alpha_composite(prev, to_im(layers[name]))
    from PIL import ImageDraw

    d = ImageDraw.Draw(prev)
    for x, y in pivots.values():
        d.ellipse((x - 14, y - 14, x + 14, y + 14), outline=(255, 60, 60, 255), width=6)
    prev.resize((768, 768)).save(os.path.join(SRC, "_preview_split.png"))
    to_im(arm).resize((768, 768)).save(os.path.join(SRC, "_preview_arm.png"))
    to_im(wings).resize((768, 768)).save(os.path.join(SRC, "_preview_wings.png"))
    with open(os.path.join(OUT, "rig.json"), "w") as f:
        json.dump(rig, f, indent=2)


if __name__ == "__main__":
    main()
