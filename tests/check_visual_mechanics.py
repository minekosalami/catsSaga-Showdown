"""Compare the presentation branch with its recorded base, not its own code."""
from pathlib import Path
import re
import subprocess

BASE = "683591d"
protected = [
    "scripts/main.gd", "scripts/boss.gd", "scenes/player.gd",
    "scripts/boss2/player.gd", "scripts/boss2/battle.gd",
    "scripts/boss2/timeline.gd", "scripts/boss2/ricochet.gd",
    "scripts/boss2/laser.gd", "scripts/rainbow_beam.gd",
    "scripts/systems/session.gd", "scripts/systems/combat_host.gd",
    "scripts/boss2/combat_host.gd", "scripts/boss2/npc.gd",
    "scripts/world/dialogue.gd", "scripts/world/player.gd",
    "scenes/boss.tscn", "scenes/player.tscn", "scenes/bullet.tscn",
    "scenes/enemybullet.tscn", "scenes/boss2/projectile.tscn",
    "project.godot", "data/dialogue/boss2.json",
]
# Only rendering functions differ in enemy/cross projectiles and player shots.
allowed = {"scripts/enemybullet.gd": {"_draw"},
           "scripts/boss2/projectile.gd": {"_draw"},
           "scripts/boss2/cross_laser.gd": {"_draw"},
           "scenes/bullet.gd": {"_ready"}}

def baseline(path):
    return subprocess.check_output(["git", "show", f"{BASE}:{path}"])

def functions(text):
    pieces = re.split(r"(?=^func )", text, flags=re.M)
    return {re.match(r"func (\w+)", p).group(1) if p.startswith("func ") else "declarations": p
            for p in pieces}

checks = 0
for path in protected:
    assert Path(path).read_bytes() == baseline(path), path
    checks += 1
for path, visual in allowed.items():
    old, new = functions(baseline(path).decode()), functions(Path(path).read_text())
    assert old.keys() == new.keys(), path
    for name in old:
        if name not in visual:
            assert old[name] == new[name], f"{path}:{name}"
            checks += 1
# Source artwork, world scenes, dialogue, soundtracks and save systems stay exact.
paths = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", BASE], text=True).splitlines()
for path in paths:
    if (path.startswith(("assets/", "scenes/world/", "data/dialogue/"))
            or path.startswith("scripts/systems/")):
        assert Path(path).read_bytes() == baseline(path), path
        checks += 1
print(f"MECHANICS/ASSET PRESERVATION: {checks} exact baseline comparisons passed")
