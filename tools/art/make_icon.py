"""Iconița aplicației Android din mascota pictată: Licurici fericit, cu felinarul aprins, pe un cer
de seară cu stele și licurici mici (numele aplicației: licuriciul strălucește noaptea).

Rulare: python tools/art/make_icon.py
Scrie: mipmap-*/ic_launcher.png (pătrat rotunjit, Android < 8), iconița adaptivă (fundal + prim-plan,
Android 8+) și o previzualizare în apps/child_app/test/shots/iconita.png.
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ART = os.path.join(ROOT, 'packages', 'game_content', 'art', 'illustrations', 'mascot')
RES = os.path.join(ROOT, 'apps', 'child_app', 'android', 'app', 'src', 'main', 'res')

LEGACY = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
ADAPTIVE = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}
S = 1024


def mascot():
    """Aripile + Licurici fericit (aceeași pânză 512, straturile se suprapun exact)."""
    canvas = Image.new('RGBA', (512, 512))
    for name in ('wing_left', 'wing_right', 'happy'):
        canvas.alpha_composite(Image.open(os.path.join(ART, name + '.webp')).convert('RGBA'))
    return canvas


def radial(size, center, radius, inner, outer):
    """Degradeu radial (culori RGBA)."""
    img = Image.new('RGBA', (size, size))
    px = img.load()
    cx, cy = center
    for y in range(size):
        for x in range(size):
            t = min(1.0, math.hypot(x - cx, y - cy) / radius)
            t = t * t * (3 - 2 * t)
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(inner, outer))
    return img


def glow(size, center, radius, color, strength=1.0):
    """O lumină moale (strat aditiv)."""
    g = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    cx, cy = center
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=color + (round(255 * strength),))
    return g.filter(ImageFilter.GaussianBlur(radius * 0.45))


def sky(size):
    """Cerul de seară: indigo spre margini, violet-turcoaz în mijloc, stele și licurici mici."""
    bg = radial(size, (size * 0.5, size * 0.42), size * 0.78, (70, 86, 170, 255), (20, 24, 66, 255))
    # o aură caldă jos, de unde vine lumina felinarului
    bg.alpha_composite(glow(size, (size * 0.5, size * 0.7), size * 0.42, (255, 196, 92), 0.45))
    rnd = random.Random(7)
    d = ImageDraw.Draw(bg)
    for _ in range(46):
        x, y = rnd.random() * size, rnd.random() * size * 0.62
        r = size * (0.003 + rnd.random() * 0.005)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 250, 230, round(140 + rnd.random() * 115)))
    # câteva stele mai mari, în cruce
    for fx, fy, k in [(0.14, 0.16, 1.0), (0.86, 0.12, 0.8), (0.9, 0.42, 0.6), (0.1, 0.48, 0.7)]:
        cx, cy, L = fx * size, fy * size, size * 0.035 * k
        star = Image.new('RGBA', (size, size))
        sd = ImageDraw.Draw(star)
        sd.polygon([(cx, cy - L), (cx + L * 0.18, cy), (cx, cy + L), (cx - L * 0.18, cy)], fill=(255, 247, 214, 255))
        sd.polygon([(cx - L, cy), (cx, cy - L * 0.18), (cx + L, cy), (cx, cy + L * 0.18)], fill=(255, 247, 214, 255))
        bg.alpha_composite(glow(size, (cx, cy), L * 0.9, (255, 236, 160), 0.6))
        bg.alpha_composite(star)
    # licurici mici care plutesc
    for fx, fy, r in [(0.2, 0.3, 0.018), (0.78, 0.26, 0.014), (0.16, 0.7, 0.012), (0.85, 0.66, 0.016)]:
        c = (fx * size, fy * size)
        bg.alpha_composite(glow(size, c, size * r * 3.2, (255, 214, 90), 0.85))
        d = ImageDraw.Draw(bg)
        rr = size * r * 0.45
        d.ellipse([c[0] - rr, c[1] - rr, c[0] + rr, c[1] + rr], fill=(255, 250, 200, 255))
    return bg


def hero(size, scale, centered=False):
    """Licurici mare, centrat pe cap și burtă (picioarele ies din cadru), cu felinarul aprins."""
    m = mascot()
    # pânza 512: capul ~y 40, burta (felinarul) ~y 350; tăiem de la pălărie până sub burtă
    crop = m.crop((0, 10, 512, 430))
    w = round(size * scale)
    h = round(crop.height * w / crop.width)
    art = crop.resize((w, h), Image.LANCZOS)
    layer = Image.new('RGBA', (size, size))
    x = (size - w) // 2
    # în pătrat: jos, cu picioarele tăiate; în iconița adaptivă: centrat (cercul sigur, 66/108)
    y = (size - h) // 2 + round(size * 0.02) if centered else size - h + round(size * 0.11)
    # contur alb subțire în jurul personajului (se citește pe orice fundal și la 48 px)
    alpha = art.split()[3]
    rim = alpha.filter(ImageFilter.MaxFilter(9))
    halo = Image.new('RGBA', art.size, (255, 255, 255, 0))
    halo.putalpha(ImageChops.subtract(rim, alpha).point(lambda v: min(255, v * 2)))
    layer.alpha_composite(halo, (x, y))
    layer.alpha_composite(art, (x, y))
    # felinarul: o lumină caldă peste burtă
    belly = (x + w * 0.5, y + h * (340 / 420))
    layer.alpha_composite(glow(size, belly, w * 0.12, (255, 226, 120), 0.9))
    return layer


def main():
    full = sky(S)
    full.alpha_composite(hero(S, 1.22))
    mask = Image.new('L', (S, S))
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=round(S * 0.22), fill=255)
    rounded = Image.new('RGBA', (S, S))
    rounded.paste(full, mask=mask)
    for dens, px in LEGACY.items():
        rounded.resize((px, px), Image.LANCZOS).save(os.path.join(RES, f'mipmap-{dens}', 'ic_launcher.png'))
    # Adaptivă: fundalul = cerul întreg; prim-planul = Licurici în cercul sigur (66/108).
    back = sky(S)
    fore = hero(S, 0.7, centered=True)
    for dens, px in ADAPTIVE.items():
        back.resize((px, px), Image.LANCZOS).save(os.path.join(RES, f'mipmap-{dens}', 'ic_launcher_background.png'))
        fore.resize((px, px), Image.LANCZOS).save(os.path.join(RES, f'mipmap-{dens}', 'ic_launcher_foreground.png'))
    os.makedirs(os.path.join(RES, 'mipmap-anydpi-v26'), exist_ok=True)
    with open(os.path.join(RES, 'mipmap-anydpi-v26', 'ic_launcher.xml'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '</adaptive-icon>\n')
    old = os.path.join(RES, 'values', 'ic_launcher_background.xml')
    if os.path.exists(old):
        os.remove(old)
    shots = os.path.join(ROOT, 'apps', 'child_app', 'test', 'shots')
    rounded.resize((512, 512), Image.LANCZOS).save(os.path.join(shots, 'iconita.png'))
    # cum arată mic, pe ecranul tabletei
    strip = Image.new('RGBA', (48 * 3 + 96 + 192 + 40, 192), (236, 240, 238, 255))
    xpos = 8
    for px in (48, 72, 96, 192):
        strip.alpha_composite(rounded.resize((px, px), Image.LANCZOS), (xpos, 192 - px))
        xpos += px + 8
    strip.save(os.path.join(shots, 'iconita-marimi.png'))
    print('iconițe scrise')


if __name__ == '__main__':
    main()
