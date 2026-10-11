"""Create transparent copies; source artwork is never overwritten.
Requires Pillow, numpy, scipy. Only neutral near-white pixels connected to
an image edge are removed. Interior white islands and chromatic fringes stay.
"""
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import binary_propagation, binary_dilation

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'assets/enironment/bosses/boss3-BlankKitten'
for name in ('normalKitten', 'kittenstage.1', 'kittenstage2', 'kittenstage3'):
    source = np.array(Image.open(FOLDER / f'{name}.png').convert('RGBA'))
    rgb = source[..., :3].astype(float)
    neutral = rgb.max(2) - rgb.min(2) <= 8
    candidate = (rgb.min(2) >= 240) & neutral
    seed = np.zeros(candidate.shape, bool)
    seed[0, :] = seed[-1, :] = True
    seed[:, 0] = seed[:, -1] = True
    exterior = binary_propagation(seed & candidate, mask=candidate)
    result = source.copy()
    result[exterior, 3] = 0
    # One-pixel neutral antialiased fringe: remove its white matte, retaining
    # luminance coverage. Never touch the colored distortion fringes.
    fringe = binary_dilation(exterior) & ~exterior & neutral & (rgb.min(2) >= 210)
    coverage = np.clip((255 - rgb.max(2)) / 45, 0, 1)
    result[fringe, 3] = np.rint(source[fringe, 3] * coverage[fringe]).astype('uint8')
    unmatte = np.clip((rgb - 255 * (1 - coverage[..., None])) / np.maximum(coverage[..., None], .001), 0, 255)
    result[fringe, :3] = unmatte[fringe].astype('uint8')
    Image.fromarray(result).save(FOLDER / f'{name}-transparent.png')
    print(name, 'removed exterior pixels:', int(exterior.sum()), 'fringe:', int(fringe.sum()))
