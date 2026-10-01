import os
import re

from PIL import Image

root = r'C:\Users\Mihai\Desktop\LicuRich\packages\game_content\art\illustrations'
readme = open(os.path.join(root, 'README.md'), encoding='utf-8').read()
sizes = {'mascot': (512, 512), 'domains': (768, 576), 'games': (512, 512)}
for m in re.finditer(r'## ([a-z_]+)/([a-z_\-]+)\.webp\s+Sursă PNG: `([^`]+)`', readme):
    folder, name, src = m.groups()
    if not os.path.exists(src):
        print('lipsă', folder, name)
        continue
    im = Image.open(src).convert('RGBA')
    w, h = sizes.get(folder, (512, 512))
    if folder == 'domains':
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
    out = os.path.join(root, folder, name + '.webp')
    im.save(out, 'WEBP', quality=85, method=6)
    print('ok', folder, name, im.size, os.path.getsize(out) // 1024, 'KB')
