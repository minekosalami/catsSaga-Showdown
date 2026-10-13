"""Protect existing regions, artwork, controls and boss mechanics during the cave redesign."""
from pathlib import Path
import re, subprocess
root = Path(__file__).resolve().parents[1]
base = "01057ad"
allowed = {'resources/maps/underground_terrain.res', 'scenes/world/underground_cave.tscn', 'docs/underground-cave-review.md', 'scripts/maps/world_layout.gd', 'scripts/world/cave_actor.gd', 'tools/import_dungeon_terrain.gd', 'docs/review/cave-redesign/hub.png', 'tests/render_cave.gd', 'scripts/world/cave_layout.gd', 'scripts/world/cave.gd', 'tests/check_cave_preservation.py', 'scripts/main_menu.gd', 'docs/review/cave-redesign/introduction.png', 'tests/headless_cave.gd', 'resources/cave/room_ids.res', 'scripts/world/overworld.gd', 'docs/review/cave-redesign/window.png', 'tests/headless_gameplay.gd', 'scripts/world/cave_atmosphere.gd', 'shaders/cave_room_mask.gdshader', 'tools/bake_underground_cave.gd', 'scripts/systems/save_manager.gd'}
count = 0
for path in subprocess.check_output(["git","ls-tree","-r","--name-only",base],cwd=root,text=True).splitlines():
    if path in allowed: continue
    assert (root/path).read_bytes() == subprocess.check_output(["git","show",f"{base}:{path}"],cwd=root), path
    count += 1
functions = {"scripts/systems/session.gd":set(), "scripts/world/overworld.gd":{"map_modal_open"}, "scripts/maps/map_ui.gd":set(), "scripts/main_menu.gd":{"_show_credits"}}
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
