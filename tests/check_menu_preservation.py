"""Read-only comparison against the reviewed starting revision."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = "d6ed8d1"
def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)
files = git("ls-tree", "-r", "--name-only", BASE).decode().splitlines()
checks = 0
for name in files:
    assert (ROOT / name).is_file(), f"Original file removed: {name}"
    checks += 1
    if name.startswith(("assets/", "data/", "resources/", "scenes/journey/", "scenes/incarna/", "scenes/wonderland/")):
        assert (ROOT / name).read_bytes() == git("show", f"{BASE}:{name}"), name
        checks += 1
protected = ["scripts/ui/battle_entry.gd", "scripts/ui/black_wall_entry.gd", "scripts/ui/encounter_sounds.gd", "shaders/encounter_flash.gdshader", "scripts/boss.gd", "scripts/boss2/timeline.gd", "scripts/blankkitten/timeline.gd", "scripts/blankkitten/hazards.gd"]
for name in protected:
    assert (ROOT / name).read_bytes() == git("show", f"{BASE}:{name}"), name
    checks += 1

def functions(source):
    matches = list(re.finditer(r"^func (\w+)\([^\n]*", source, re.M))
    return {m[1]: source[m.start():matches[i + 1].start() if i + 1 < len(matches) else len(source)].strip() for i, m in enumerate(matches)}
for name, methods in {
    "scripts/systems/session.gd": ["transition_to", "_battle_entry", "_freeze_entry_tree", "begin_battle", "begin_boss2_battle", "begin_blankkitten_battle", "begin_encounter"],
    "scenes/player.gd": ["take_damage", "activate_saturate", "shoot"],
    "scripts/boss2/player.gd": ["update_sprint", "try_protected_activation", "shoot", "activate_saturate"],
    "scripts/blankkitten/star.gd": ["step", "take_damage", "_draw"],
}.items():
    old = functions(git("show", f"{BASE}:{name}").decode())
    new = functions((ROOT / name).read_text())
    for method in methods:
        assert old[method] == new[method], f"Protected mechanic changed: {name}:{method}"
        checks += 1
print(f"MENU PRESERVATION: {checks} checks; all {len(files)} original files retained, original art/audio/data/layout and protected mechanics unchanged")
