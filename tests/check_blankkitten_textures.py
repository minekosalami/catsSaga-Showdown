"""Check that background removal preserves source files, white islands and color."""
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import binary_propagation, binary_dilation
folder = Path(__file__).resolve().parents[1] / 'assets/enironment/bosses/boss3-BlankKitten'
checks = 0
for name in ('normalKitten','kittenstage.1','kittenstage2','kittenstage3'):
    source = np.array(Image.open(folder / f'{name}.png').convert('RGBA'))
    result = np.array(Image.open(folder / f'{name}-transparent.png').convert('RGBA'))
    assert source.shape == result.shape; checks += 1
    rgb = source[..., :3].astype(float)
    neutral = rgb.max(2) - rgb.min(2) <= 8
    candidate = (rgb.min(2) >= 240) & neutral
    edge = np.zeros(candidate.shape,bool)
    edge[0,:] = edge[-1,:] = True
    edge[:,0] = edge[:,-1] = True
    exterior = binary_propagation(edge & candidate,mask=candidate)
    assert np.all(result[exterior,3] == 0); checks += 1
    interior_white = candidate & ~exterior & ~binary_dilation(exterior)
    assert np.array_equal(source[interior_white],result[interior_white]); checks += 1
    colored = ~neutral
    assert np.array_equal(source[colored],result[colored]); checks += 1
    untouched = ~exterior & ~(binary_dilation(exterior) & neutral & (rgb.min(2) >= 210))
    assert np.array_equal(source[untouched],result[untouched]); checks += 1
    assert np.count_nonzero(result[...,3]) > 100000; checks += 1
    print(name,'preserved white islands:',int(interior_white.sum()),'colored fringe pixels:',int(colored.sum()))
print(f'BLANKKITTEN TEXTURES: {checks} pixel/alpha checks passed')
