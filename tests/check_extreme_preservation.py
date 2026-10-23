#!/usr/bin/env python3
"""Verify the visual pass against its actual starting branch, not an older design."""
import hashlib
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = "6279633"

def old(path):
    return subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT)

def functions(source):
    return {m.group(1): m.group(0).strip() for m in re.finditer(
        r"^(?:static )?func (\w+)\(.*?(?=^(?:static )?func |\Z)", source, re.M | re.S)}

def main():
    entries = subprocess.check_output(["git", "ls-tree", "-r", BASE], cwd=ROOT, text=True)
    original_count = checks = music = 0
    for entry in entries.splitlines():
        meta, path = entry.split("\t", 1)
        original_count += 1
        file = ROOT / path
        assert file.is_file(), f"Original file missing: {path}"
        if path.startswith(("assets/", "gfx/", "scenes/wonderland/", "scripts/wonderland/", "scripts/incarna/", "scenes/incarna/", "scripts/world/cave", "data/")) or path == "scenes/world/underground_cave.tscn":
            data = file.read_bytes()
            digest = hashlib.sha1(f"blob {len(data)}\0".encode()+data).hexdigest()
            assert digest == meta.split()[2], f"Protected source asset changed: {path}"
            checks += 1
            if file.suffix.lower() in (".wav", ".mp3", ".ogg"): music += 1
    for path in ["scripts/ui/battle_entry.gd", "scripts/ui/black_wall_entry.gd", "scripts/ui/encounter_sounds.gd", "shaders/encounter_flash.gdshader", "scripts/systems/session.gd", "scripts/systems/save_manager.gd", "scripts/systems/music.gd", "scripts/systems/ambience.gd", "scenes/player.gd", "scenes/player.tscn", "scripts/boss2/player.gd", "scripts/boss2/projectile.gd", "scripts/boss2/ricochet.gd", "scripts/boss2/laser.gd", "scripts/boss2/cross_laser.gd", "scripts/blankkitten/timeline.gd", "scripts/blankkitten/star.gd", "scripts/blankkitten/hazards.gd", "scripts/blankkitten/battle.gd", "scripts/blankkitten/presentation.gd", "scripts/main.gd", "scripts/boss2/battle.gd", "scripts/enemybullet.gd", "default_bus_layout.tres"]:
        assert (ROOT/path).read_bytes() == old(path), f"Protected implementation changed: {path}"
        checks += 1
    assert (ROOT/"scripts/world/player.gd").read_bytes() == old("scripts/world/player.gd"), "Overworld movement implementation changed"
    checks += 1
    exceptions = {"scripts/boss.gd": {"fire_gapped_ring", "fire_flower"}, "scripts/boss2/timeline.gd": {"ring"}, "scripts/world/player.gd": set(), "scripts/blankkitten/feedback.gd": {"_draw"}, "scripts/boss2/effects.gd": {"_draw", "afterimage"}}
    for path, allowed in exceptions.items():
        before = functions(old(path).decode())
        after = functions((ROOT/path).read_text())
        for name, body in before.items():
            if name not in allowed:
                assert after.get(name) == body, f"Unapproved mechanics change: {path}:{name}"
                checks += 1
    print(f"EXTREME PRESERVATION: {checks} checks; all {original_count} original files exist; {music} original audio files unchanged; protected entry and Sequence implementation byte-identical")

if __name__ == "__main__": main()
