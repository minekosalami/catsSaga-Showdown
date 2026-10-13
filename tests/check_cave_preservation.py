"""Protect existing regions, artwork, controls and boss mechanics during the cave redesign."""
from pathlib import Path
import re, subprocess
root = Path(__file__).resolve().parents[1]
base = "9280508"
allowed = {'tests/render_cave.gd', 'tests/headless_cave.gd', 'resources/maps/underground_terrain.res', 'scripts/world/cave_layout.gd', 'docs/underground-cave-review.md', 'scenes/world/cave_return.tscn', 'scripts/systems/session.gd', 'project.godot', 'scripts/world/overworld.gd', 'tests/check_cave_preservation.py', 'scripts/ui/developer_menu.gd', 'scripts/world/cave.gd', 'tools/bake_underground_cave.gd', 'scripts/maps/map_ui.gd', 'scenes/world/underground_cave.tscn', 'scripts/systems/save_manager.gd', 'scripts/maps/world_layout.gd'}
count = 0
for path in subprocess.check_output(["git","ls-tree","-r","--name-only",base],cwd=root,text=True).splitlines():
    if path in allowed: continue
    assert (root/path).read_bytes() == subprocess.check_output(["git","show",f"{base}:{path}"],cwd=root), path
    count += 1
functions = {"scripts/systems/session.gd":{"world_menu_open","can_pause","request_main_menu"}, "scripts/world/overworld.gd":{"_build_hud"}, "scripts/maps/map_ui.gd":{"handle_input"}}
def funcs(text):
    blocks = re.split(r"(?=^func )",text,flags=re.M)
    return {re.match(r"func (\w+)",block).group(1):block.rstrip() for block in blocks if block.startswith("func ")}
for path, exceptions in functions.items():
    old = funcs(subprocess.check_output(["git","show",f"{base}:{path}"],cwd=root,text=True))
    new = funcs((root/path).read_text())
    for name in old:
        if name in exceptions: continue
        assert old[name] == new[name], f"{path}:{name}"
        count += 1
print(f"PASS: {count} existing files/functions unchanged; forest scenes, original art, player controls, bosses, battle timelines and dialogue preserved")
