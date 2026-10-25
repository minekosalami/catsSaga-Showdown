"""Compare this polish against its starting revision; never writes game files."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

BASE = sys.argv[1] if len(sys.argv) > 1 else "6c5674a"

def original(path):
    return subprocess.check_output(["git", "show", f"{BASE}:{path}"])

files = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", BASE], text=True).splitlines()
protected = [p for p in files if
             (p.startswith("assets/") and not p.endswith(".import"))
             or p.startswith("dialogue/") or ("dialogue" in p and p.endswith(".json"))
             or p.startswith(("scripts/story/", "scripts/boss2/", "scripts/blankkitten/", "scripts/rpg/"))
             or p in ["scripts/boss.gd", "scripts/systems/save_manager.gd"]]
for path in protected:
    assert Path(path).read_bytes() == original(path), f"Protected file changed: {path}"

def nodes(text):
    result = {}
    for block in re.split(r"\n\n+", text):
        if not block.startswith("[node "):
            continue
        header, *body = block.splitlines()
        name = re.search(r'name="([^"]+)"', header)[1]
        parent = re.search(r'parent="([^"]+)"', header)
        result[(parent[1] if parent else "") + "/" + name] = (header, dict(
            line.split(" = ", 1) for line in body if " = " in line))
    return result

count = 0
for name in ["forest_entrance", "deep_forest", "bart_area", "flooded_forest"]:
    path = f"scenes/journey/{name}.tscn"
    before, after = nodes(original(path).decode()), nodes(Path(path).read_text())
    for key, (_, properties) in before.items():
        if not (key.startswith(("Characters/", "Entries/", "Portals/", "Discoveries/", "Boundaries/"))
                or key in ["./Water", "./Bridges", "./WaterSurface"]):
            continue
        assert key in after, f"Missing meaningful node: {name}/{key}"
        for prop, value in properties.items():
            assert after[key][1].get(prop) == value, f"Changed {name}/{key}: {prop}"
        count += 1
    original_shapes = {k for k, v in before.items() if 'type="CollisionShape2D"' in v[0]}
    new_shapes = {k for k, v in after.items() if 'type="CollisionShape2D"' in v[0]}
    assert not new_shapes - original_shapes, f"New solid obstacles in {name}"
    for key in new_shapes:
        assert before[key][1] == after[key][1], f"Changed collider: {name}/{key}"

for folder in ["lpc", "lpc_revised"]:
    root = Path("assets/environment_human") / folder
    for asset in json.loads((root / "provenance.json").read_text())["files"]:
        assert hashlib.sha256((root / asset["file"]).read_bytes()).hexdigest() == asset["sha256"]
print(f"PRESERVATION: {len(protected)} files, {count} meaningful nodes, retained colliders and source hashes PASS")
