"""Iconița aplicației Android din mascota existentă (Licurici fericit, cu aripi).

Rulare: python tools/art/make_icon.py
Scrie: mipmap-*/ic_launcher.png (pătrat rotunjit, pentru Android < 8) și iconița adaptivă
(mipmap-*/ic_launcher_foreground.png + fundal mentă în values/ic_launcher_background.xml).
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ART = os.path.join(ROOT, 'packages', 'game_content', 'art', 'illustrations', 'mascot')
RES = os.path.join(ROOT, 'apps', 'child_app', 'android', 'app', 'src', 'main', 'res')

LEGACY = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
ADAPTIVE = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}
TOP, BOTTOM = (0xCF, 0xEE, 0xE2), (0x9F, 0xD8, 0xE6)  # mentă → cer, ca tema aplicației


def mascot():
    canvas = Image.new('RGBA', (512, 512))
    for name in ('wing_left', 'wing_right', 'happy'):
        canvas.alpha_composite(Image.open(os.path.join(ART, name + '.webp')).convert('RGBA'))
    return canvas.crop(canvas.getbbox())


def gradient(size):
    g = Image.new('RGBA', (size, size))
    d = ImageDraw.Draw(g)
    for y in range(size):
        t = y / (size - 1)
        d.line([(0, y), (size, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)) + (255,))
    return g


def place(m, size, fill):
    """Mascota centrată, cât [fill] din latură (pe înălțime)."""
    h = round(size * fill)
    w = round(m.width * h / m.height)
    out = Image.new('RGBA', (size, size))
    out.alpha_composite(m.resize((w, h), Image.LANCZOS), ((size - w) // 2, (size - h) // 2 + round(size * 0.02)))
    return out


def main():
    m = mascot()
    big = 1024
    legacy = gradient(big)
    legacy.alpha_composite(place(m, big, 0.86))
    mask = Image.new('L', (big, big))
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, big - 1, big - 1], radius=round(big * 0.22), fill=255)
    rounded = Image.new('RGBA', (big, big))
    rounded.paste(legacy, mask=mask)
    # Iconița adaptivă: conținutul trebuie să stea în cercul sigur (66 din 108 dp).
    fg = place(m, big, 0.6)
    for dens, px in LEGACY.items():
        rounded.resize((px, px), Image.LANCZOS).save(os.path.join(RES, f'mipmap-{dens}', 'ic_launcher.png'))
    for dens, px in ADAPTIVE.items():
        fg.resize((px, px), Image.LANCZOS).save(os.path.join(RES, f'mipmap-{dens}', 'ic_launcher_foreground.png'))
    os.makedirs(os.path.join(RES, 'mipmap-anydpi-v26'), exist_ok=True)
    with open(os.path.join(RES, 'mipmap-anydpi-v26', 'ic_launcher.xml'), 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background"/>\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '</adaptive-icon>\n')
    with open(os.path.join(RES, 'values', 'ic_launcher_background.xml'), 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                '    <color name="ic_launcher_background">#B7E3E4</color>\n</resources>\n')
    rounded.resize((512, 512), Image.LANCZOS).save(os.path.join(ROOT, 'apps', 'child_app', 'test', 'shots', 'iconita.png'))
    print('iconițe scrise')


if __name__ == '__main__':
    main()
