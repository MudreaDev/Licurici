"""Scoate fundalul verde (chroma key) din imaginile Gemini și salvează PNG-uri transparente.

Folosire: python tools/mascot-rig/key.py <in.jpg> <out.png>
"""

import sys

import numpy as np
from PIL import Image, ImageFilter


def key_green(img: Image.Image) -> Image.Image:
    rgb = np.asarray(img.convert("RGB")).astype(np.float32) / 255.0
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # cât de „verde de fundal” e pixelul: verdele domină roșul și albastrul
    spill = g - np.maximum(r, b)
    # sub 0.18 = personaj, peste 0.45 = fundal, între = margine moale
    alpha = 1.0 - np.clip((spill - 0.18) / (0.45 - 0.18), 0.0, 1.0)
    # despill: verdele rămas pe margini nu trece de max(r, b)
    g2 = np.minimum(g, np.maximum(r, b) + 0.04)
    out = np.dstack([r, g2, b, alpha])
    im = Image.fromarray((out * 255).astype(np.uint8), "RGBA")
    # alfa puțin mai strâns ca să nu rămână un halou verde
    a = im.getchannel("A").filter(ImageFilter.MinFilter(3))
    im.putalpha(a)
    return im


if __name__ == "__main__":
    key_green(Image.open(sys.argv[1])).save(sys.argv[2])
