"""Guard existing gameplay and source assets against the pre-BlankKitten main."""
from pathlib import Path
import re
import subprocess
BASE = '612f98c'
checks = 0

def old(path):
    return subprocess.check_output(['git','show',f'{BASE}:{path}'])

def verify(path, expected=None):
    global checks
    assert Path(path).read_bytes() == (old(path) if expected is None else expected), path
    checks += 1

def functions(source):
    parts = re.split(r'(?=^func )',source,flags=re.M)
    return {re.match(r'func (\w+)',p).group(1) if p.startswith('func ') else 'declarations':p for p in parts}

paths = subprocess.check_output(['git','ls-tree','-r','--name-only',BASE],text=True).splitlines()
# Every old source image, soundtrack, font, shader, attack controller, save,
# map geometry and pre-existing dialogue stays byte-for-byte intact.
exceptions = {'scripts/systems/session.gd','scripts/systems/combat_host.gd',
              'scripts/boss2/combat_host.gd','scripts/world/overworld.gd',
              'scenes/world/deep_forest.tscn','scenes/world/flooded_forest.tscn',
              'scenes/boss2/battle.tscn'}
for path in paths:
    protected = (path.startswith(('assets/','scripts/','scenes/','data/','shaders/'))
                 or path == 'project.godot')
    if protected and path not in exceptions and not path.endswith('.import'):
        verify(path)
# Correct only the reference to the texture moved by main's asset commit.
for path in ['scenes/world/flooded_forest.tscn','scenes/boss2/battle.tscn']:
    verify(path,old(path).replace(b'assets/enironment/bosses/bosstwo.png',b'assets/enironment/bosses/boss2/bosstwo.png'))
scene = Path('scenes/world/deep_forest.tscn').read_text()
scene = scene.replace('[ext_resource type="PackedScene" path="res://scenes/blankkitten/npc.tscn" id="blankkitten"]\n\n','')
scene = scene.replace('\n[node name="BlankKitten" parent="Characters" instance=ExtResource("blankkitten")]\nposition = Vector2(824, 800)\n','')
assert scene == old('scenes/world/deep_forest.tscn').decode(); checks += 1
for path,scene in [('scripts/systems/combat_host.gd','scenes/combat_host.tscn'),('scripts/boss2/combat_host.gd','scenes/boss2/combat_host.tscn')]:
    expected = old(path).decode().replace('behind the white wipe','behind the black walls').replace(f'Session.transition_to("res://{scene}")',f'Session.transition_to("res://{scene}", true)')
    verify(path,expected.encode())
expected = old('scripts/world/overworld.gd').decode().replace('if pending_encounter == "boss2":\n','if pending_encounter == "blankkitten":\n\t\t\tSession.begin_blankkitten_battle(player.position)\n\t\telif pending_encounter == "boss2":\n')
verify('scripts/world/overworld.gd',expected.encode())
a,b = functions(old('scripts/systems/session.gd').decode()),functions(Path('scripts/systems/session.gd').read_text().replace('## Future encounters use this entry point without duplicating the curtain.\n',''))
changed = {'declarations','_ready','transition_to','save_boss_victory'}
for name in a:
    if name not in changed:
        assert a[name] == b[name],f'Session:{name}'; checks += 1
assert set(b)-set(a) == {'begin_encounter','begin_blankkitten_battle','return_from_blankkitten'}; checks += 1
expected = a['save_boss_victory'].replace('if encounter_active and (evil_bart_defeated if encounter_id == "bart" else story_flags.get("boss2_defeated", false)):', 'var completed: bool = evil_bart_defeated if encounter_id == "bart" else story_flags.get(encounter_id + "_defeated", false)\n\tif encounter_active and completed:')
assert b['save_boss_victory'] == expected; checks += 1
print(f'BLANKKITTEN PRESERVATION: {checks} exact source/function comparisons passed')
