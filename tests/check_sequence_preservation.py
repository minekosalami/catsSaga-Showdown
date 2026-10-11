"""Read-only exact preservation check against the merged first BlankKitten implementation."""
from pathlib import Path
import subprocess
BASE = 'a39aaf4'
root = Path(__file__).resolve().parents[1]
paths = subprocess.check_output(['git','ls-tree','-r','--name-only',BASE],cwd=root,text=True).splitlines()
count = 0
for path in paths:
    if path.startswith(('scripts/blankkitten/', 'shaders/blankkitten_', 'tests/', 'docs/')):
        # Original NPC interaction and art are also protected below.
        if path != 'scripts/blankkitten/npc.gd':
            continue
    source = subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=root)
    assert (root/path).read_bytes() == source, f'Unrelated file changed: {path}'
    count += 1
for path in subprocess.check_output(['git','diff','--name-only',BASE],cwd=root,text=True).splitlines():
    assert path.startswith(('scripts/blankkitten/','shaders/blankkitten_','tests/','docs/')), path
print(f'PASS: {count} existing files preserved byte-for-byte, including all other bosses, world, artwork, soundtrack, dialogue, saves and configuration')
