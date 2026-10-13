# Underground Cave redesign and developer menu review

The ten-area cave follows the supplied mockup: **1–2, 1–3–4–5–6–7–8–9**,
with a two-way **4–8** hole shortcut and a sealed **6→10** viewing window.
The Flooded Forest entrance remains at **(1696, 1008)**; interact with Z.
The rebuilt cave is **6656×5888 world pixels**, using **32px displayed cells**.
This is larger than the flexible 90×75 guideline to support the long camera room;
it replaces the previous 20480×16384 cave. First-time 5–7-minute pacing remains
an acceptance target for human playtesting, not a measured result.

## Terrain and editing

All floors and walls use the newly committed Screaming Brain Studios dungeon
pack (`assets/enironment/sbs_-_top_down_dungeon_pack`), whose included license is
**CC0/public domain, with no restrictions**. The actual PNG/TSX atlases have
**64×64 native cells**; TileMapLayers use uniform 0.5 scale and nearest filtering
for a 32px world grid. No PNGs were altered, split, copied, or generated.
The authored Wang corners/sides define editable Godot terrain transitions.
Floor cell 47 is the seamless floor; only the wall atlas uses cell 47 as a
magenta placeholder, which is excluded. Walls have scaled, solid collision;
floors and rubble have none. Suitable existing GFX supply counters, chairs,
tables, storage chests, rubble, the boulder and a replaceable save-point chest.
The existing brown exit ladder is the only retained old cave-atlas visual.

Open `scenes/world/underground_cave.tscn`, select a TileMapLayer, then use the
TileMap painting/terrain toolbar. TileSets live in `resources/cave/dungeon_*.tres`.
Keep painting inside the authored room footprints: the room-ID visibility map
must agree with floor geometry. Change `scripts/world/cave_layout.gd` and rebuild
when altering room outlines/connections. A full bake replaces manual scene edits:

```sh
godot --headless --path . --script tools/import_dungeon_terrain.gd
godot --headless --path . --script tools/bake_underground_cave.gd
```

Refresh the map cache from a manually painted scene without replacing it:

```sh
godot --headless --path . --script tools/bake_underground_cave.gd -- --cache-only
```

## Progression and presentation

Area 2 uses the exact two-box riddle and responses, numeric choices including
3 and 14, repeatable failed attempts and one saved red-key reward. The existing
inventory lists that key. Obtaining it does not open the red barrier: Z unlocks
the barrier permanently and exposes both shortcut holes. Area 4 has populated
future shop space, the warning cat, and one Z save point reporting `Game saved!`.
Area 10 stays physically sealed even with the existing region debug override.
There is no green key, actual merchant, healing station, Boss 4 combat or reward.

Normal camera following and zoom are unchanged. A separate world-space room
mask hides other interiors, with a ray-clipped aperture for Area 10 only. It
sits below the HUD and does not replace map fog. Area 7 fades the entire screen,
including map/inventory/dialogue/developer UI, to grayscale over one second;
local ambience fades into a pitched-down drone. Leaving restores color/audio
immediately, without global rendering/audio changes.

Area 9 automatically locks movement, smoothly pans at the existing zoom from
an offscreen temporary boss to the far-edge framing, then uses the existing
character dialogue for `Welcome to the underground.` Advancing opens the existing
540×900 combat host with a clearly labeled placeholder. Both return/retry paths
restore a safe Area 8 position; entering Area 9 replays the introduction.
Menus cannot interrupt/skip it. Existing real fights and fresh-fight health
initialization are unchanged.

The minus-key developer menu retains every cheat/category and adds consistent
44px controls, focus/hover states, disabled explanations, automatic focus
scrolling, arrow/Tab/Enter navigation and previous-focus restoration. The current
project's accidental keyboard device-16 binding is corrected to device 0.

## Save compatibility

Save version, backups, unrelated flags, forest exploration and cave discovery
remain compatible. Legacy cave saves relocate to the redesigned entrance, and
**only the obsolete cave exploration bitset resets** because its geometry changed.
New cave saves retain valid position, puzzle/key, barrier/shortcut and exploration.
Invalid/hidden-room positions use the existing safe-spawn validation.

## Validation

Godot 4.6.3 headless import and affected-scene instantiation pass. Automated
checks: **cave 81**, **developer menu 60**, **map/debug 38**, **cartography 77**,
**overworld 59**, **location discovery 40**, and **rendering 68**. Rendering checks
use actual framebuffer probes for chamber isolation, aperture clipping, complete
UI grayscale and color restoration; camera framing is tested at 1280×720/zoom1
and 1920×1080/zoom0.75. Reachability uses the actual player collision shape.
The preservation script compares against `9280508`, protecting existing forest
scenes, artwork, player controls, battle scripts/timelines and original dialogue.

```sh
godot --headless --path . --editor --import
godot --headless --path . --script tests/headless_cave.gd
godot --headless --path . --script tests/headless_developer_menu.gd
python tests/check_cave_preservation.py
godot --path . --rendering-method gl_compatibility --script tests/render_cave.gd
```

Rendering was verified with Mesa llvmpipe. Its unsupported V-Sync warning is
expected; some test shutdowns emit an ObjectDB leak warning. No functional
validation failures remain. Manually judge first-time pacing/wayfinding, furniture
composition, audio levels/drone, and frame pacing on target hardware.

![Hub and future shop space](review/cave-redesign/hub.png)
![Sealed viewing aperture](review/cave-redesign/window.png)
![Temporary boss introduction](review/cave-redesign/introduction.png)
