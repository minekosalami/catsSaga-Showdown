"""Read-only extraction/provenance verification; creates no artwork."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image
root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'resources/encounters/sprite-provenance.json').read_text())
source = root / manifest['source']
assert hashlib.sha256(source.read_bytes()).hexdigest() == manifest['source_sha256']
sheet = np.array(Image.open(source).convert('RGBA'))
expected = ['Purrrresents!', 'FireKittens', 'TopCat', 'Sharpurr', 'BiNarty', 'Toasters', '2kMEOWpH', 'Sir Swirlur']
for i, item in enumerate(manifest['sprites']):
    assert item['index'] == i and item['name'] == expected[i]
    p = root / item['file']
    assert hashlib.sha256(p.read_bytes()).hexdigest() == item['sha256']
    x, y, w, h = item['cell']
    x0, y0, x1, y1 = item['occupied_bbox']
    cell = sheet[y:y+h, x:x+w]
    extracted = np.array(Image.open(p).convert('RGBA'))
    retained = cell[y0:y1, x0:x1]
    assert np.array_equal(extracted[:, :, :3], retained[:, :, :3])
    # Every original nonblack pixel, including extremely dark BiNarty details,
    # remains fully opaque. No chroma key, threshold or generative edit.
    assert np.count_nonzero(cell[:, :, :3].any(axis=2)) == np.count_nonzero(extracted[:, :, :3].any(axis=2))
    mask = extracted[:, :, :3].any(axis=2)
    assert np.array_equal(extracted[:, :, 3][mask], retained[:, :, 3][mask])
    assert extracted[:, :, 3].min() == 0
print('PASS: eight exact-order extractions; every retained RGB and every nonblack detail preserved')
