import glob
import os
import re

from PIL import Image

root = r'C:\Users\Mihai\Desktop\LicuRich\packages\game_content\art\illustrations'
# README.md + eventualele liste ale altor sesiuni de generare (README-*.md)
readme = '\n'.join(
    open(f, encoding='utf-8').read() for f in sorted(glob.glob(os.path.join(root, 'README*.md')))
)
sizes = {
    'mascot': (512, 512),
    'domains': (768, 576),
    'games': (512, 512),
    'sprites': (384, 384),
    'rewards': (384, 384),
    'scenes': (1536, 1024),
    'faces': (320, 320),
    'objects': (256, 256),
}
for m in re.finditer(r'## ([a-z_]+)/([a-z_\-]+)\.webp\s+Sursă PNG: `([^`]+)`', readme):
    folder, name, src = m.groups()
    if not os.path.exists(src):
        print('lipsă', folder, name)
        continue
    out = os.path.join(root, folder, name + '.webp')
    # doar ce s-a schimbat de la ultima conversie
    if os.path.exists(out) and os.path.getmtime(out) >= os.path.getmtime(src):
        continue
    im = Image.open(src).convert('RGBA')
    w, h = sizes.get(folder, (512, 512))
    if folder in ('domains', 'scenes'):
        # decupare centrală la 4:3, apoi micșorare
        r = w / h
        iw, ih = im.size
        if iw / ih > r:
            nw = int(ih * r)
            im = im.crop(((iw - nw) // 2, 0, (iw - nw) // 2 + nw, ih))
        else:
            nh = int(iw / r)
            im = im.crop((0, (ih - nh) // 2, iw, (ih - nh) // 2 + nh))
        im = im.resize((w, h), Image.LANCZOS)
    else:
        im = im.resize((w, h), Image.LANCZOS)
    os.makedirs(os.path.join(root, folder), exist_ok=True)
    if im.getchannel('A').getextrema()[0] == 255:
        im = im.convert('RGB')  # fundal opac: fără canal alfa
    im.save(out, 'WEBP', quality=85, method=6)
    print('ok', folder, name, im.size, os.path.getsize(out) // 1024, 'KB')
