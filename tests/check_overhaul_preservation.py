#!/usr/bin/env python3
"""Compare mechanics and original assets against the pre-overhaul Git revision."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = "6eb50b0"


def before(path):
    return subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT)


def function(source, name):
    match = re.search(r"^(?:static )?func " + re.escape(name) + r"\(.*?(?=^(?:static )?func |\Z)", source, re.M | re.S)
    assert match, name
    return match.group(0)


def main():
    tree = subprocess.check_output(["git", "ls-tree", "-r", BASE], cwd=ROOT, text=True)
    count = 0
    music = 0
    for line in tree.splitlines():
        metadata, path = line.split("\t", 1)
        expected = metadata.split()[2]
        file = ROOT/path
        assert file.is_file(), "Original file missing: " + path
        if path.startswith("assets/") or path.startswith(("scenes/wonderland/", "scripts/wonderland/", "scripts/incarna/", "scenes/incarna/")) or path.startswith("scripts/world/cave") or path == "scenes/world/underground_cave.tscn":
            data = file.read_bytes()
            actual = hashlib.sha1(f"blob {len(data)}\0".encode()+data).hexdigest()
            assert actual == expected, "Preserved source/content changed: " + path
            count += 1
            if file.suffix.lower() in (".mp3", ".wav"):
                music += 1
    for path in ["scripts/boss.gd", "scenes/player.gd", "scripts/world/player.gd", "scripts/boss2/timeline.gd", "scripts/boss2/player.gd", "scripts/boss2/projectile.gd", "scripts/boss2/ricochet.gd", "scripts/boss2/laser.gd", "scripts/boss2/cross_laser.gd", "scripts/blankkitten/battle.gd", "scripts/blankkitten/star.gd", "scripts/blankkitten/timeline.gd", "scripts/systems/music.gd", "scripts/systems/ambience.gd", "default_bus_layout.tres"]:
        assert (ROOT/path).read_bytes() == before(path), "Mechanics/audio changed: " + path
        count += 1
    protected = {
        "scripts/enemybullet.gd": ["_physics_process", "_on_area_entered"],
        "scripts/blankkitten/hazards.gd": ["configure", "build_pillars", "shapes_at", "ball_position", "advance", "circle_hits_rect", "stop_damage", "clear"],
        "scripts/main.gd": ["_process", "_update_boss", "_on_boss_defeated", "navigate_victory"],
        "scripts/boss2/battle.gd": ["_physics_process", "finish_survival", "_defeat", "_fade_music"],
    }
    for path, names in protected.items():
        old = before(path).decode()
        current = (ROOT/path).read_text()
        for name in names:
            assert function(old, name) == function(current, name), path+":"+name
            count += 1
    manifest = json.loads((ROOT/"assets/overhaul_human/provenance.json").read_text())
    for path, evidence in manifest["files"].items():
        assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest() == evidence["sha256"], path
        count += 1
    evidence = manifest["license_evidence"]
    assert hashlib.sha256((ROOT/evidence["notice_path"]).read_bytes()).hexdigest() == evidence["sha256"], "License notice changed"
    count += 1
    print(f"PRESERVATION: {count} content/function checks passed; {music} original music files unchanged; every original project file exists")


if __name__ == "__main__":
    main()
