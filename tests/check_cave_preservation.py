"""Protect unrelated gameplay and original art; allow only cave integration hooks."""
from pathlib import Path
import re, subprocess
root=Path(__file__).resolve().parents[1]
base='8dbfc2d'
allowed={'scenes/world/flooded_forest.tscn','scripts/maps/exploration.gd','scripts/maps/map_canvas.gd','scripts/maps/map_ink.gd','scripts/maps/map_ui.gd','scripts/maps/world_layout.gd','scripts/systems/music.gd','scripts/systems/save_manager.gd','scripts/systems/session.gd','scripts/world/overworld.gd','resources/maps/world_terrain.res','tests/headless_cartography.gd'}
count=0
for path in subprocess.check_output(['git','ls-tree','-r','--name-only',base],cwd=root,text=True).splitlines():
 if path in allowed: continue
 assert (root/path).read_bytes()==subprocess.check_output(['git','show',f'{base}:{path}'],cwd=root),path
 count+=1
functions={'scripts/systems/session.gd':{'travel','transition_to'},'scripts/systems/music.gd':{'theme_for'},'scripts/systems/save_manager.gd':set(),'scripts/world/overworld.gd':{'_validate_saved_position','_process'},'scripts/maps/map_ui.gd':{'setup','_process'},'scripts/maps/map_canvas.gd':{'configure'},'scripts/maps/map_ink.gd':{'_draw'}}
for path,exceptions in functions.items():
 old=subprocess.check_output(['git','show',f'{base}:{path}'],cwd=root,text=True)
 new=(root/path).read_text()
 def funcs(text):
  blocks=re.split(r'(?=^func )',text,flags=re.M)
  return {re.match(r'func (\w+)',b).group(1):b.rstrip() for b in blocks if b.startswith('func ')}
 a,b=funcs(old),funcs(new)
 for name in a:
  if name in exceptions: continue
  assert a[name]==b[name],f'{path}:{name}'
  count+=1
scene='scenes/world/flooded_forest.tscn'
old=subprocess.check_output(['git','show',f'{base}:{scene}'],cwd=root,text=True).rstrip()
new=(root/scene).read_text()
new=re.sub(r'\[ext_resource[^\n]*id="cave_hole"\]\n\n','',new)
new=new[:new.index('\n[node name="FromCave"')].rstrip()
assert new==old,'Existing flooded terrain, NPCs, trees and portals changed'
print(f'PASS: {count} unchanged files/functions; original flooded geometry unchanged; all original artwork, player, boss mechanics, controls and dialogue preserved')
