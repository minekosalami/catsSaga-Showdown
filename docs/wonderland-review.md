# Wonderland review

Wonderland adds six outdoor maps, eight enterable village buildings and four
connected castle interiors. It uses the existing overworld host, player, travel
signals, Z interactions, inventory, pause, safe-save format and fog implementation.
There are no new characters, dialogue, quests, battles, economy systems or music.
All areas remain in permanent daylight and reuse the existing overworld theme.

## Geography and playable content

| Outdoor map | Dimensions | Connections |
| --- | --- | --- |
| Wonderland Forest | 2560×1920 | Flooded Forest south; Tea Gardens west; Mushroom Thicket east |
| Tea Gardens | 2560×1920 | Forest east; Royal Woods north |
| Mushroom Thicket | 2560×1920 | Forest west; Village north |
| Royal Woods | 3840×1920 | Tea Gardens south; Village east; castle north (western entrance) |
| Wonderland Village | 3840×1920 | Mushroom Thicket south; Royal Woods west; castle north (eastern entrance) |
| Queen's Castle Grounds | 2560×1920 | Royal Woods and Village on separate southern paths; locked main gate |

Outdoor seams have equal physical coordinates in the Wonderland atlas. Opposite
edges have reciprocal portals, matching paths, inset arrival markers and inward
facing directions. The castle is northernmost, woods northwest, village northeast,
tea gardens southwest, mushrooms southeast and the forest in the southern center.

The village surrounds a fountain and winding streets. Its eight unique interiors
are Mushroom Cottage, Teapot House, Flower Shop, Clockmaker's House, Bakery, Royal
Gift Shop, Storyteller's Cottage and Tiny Pink House. Their furniture reflects
their purpose: clocks/workbench, ovens/bread racks, planted displays, writing desk,
bookcases, tea settings, beds and gift displays. Each returns to its own front door.

The compact castle facade has gardens, towers, flags, a rose window and one gate.
Inside, the Grand Entrance Hall connects west to the Royal Library, east to the
Banquet Hall and north to the Throne Room. The throne is empty. Interior scene
bounds are 1280×960 with framed room walls, furnishings and working passages.

## Entrance, key and locks

- The pink door is at **Flooded Forest (3072,208)**. A continuous tree-backed
  passage reaches the actual northern-edge transition at **(3072,48)**. This dry
  northeastern location is east of the existing Deep Forest route. A localized
  path spur joins the northern approach; only obstructing trunks/boulders on that
  spur are cleared. Existing water, NPCs, cave entrance and routes remain intact.
- Incarna's chest is at **Underground Cave (5536,3584)**, beyond his apparition in
  the long chamber. A stone barrier and the interaction condition prevent early
  access. His cave apparition's camera placement is capped before this alcove at
  wider views; the fight itself is unchanged.
- Surviving Incarna grants **no automatic key**. Return to the cave as before,
  walk east through Last Watch to the chest, and press Z. The closed chest opens
  and grants the permanent **Pink Wonderland Key**. Walk back through the existing
  cave and climb to the surface; no new teleport or return shortcut was added.
- Press Z at the pink door with the key, then walk through the passage. The key
  is retained and appears in the existing Space inventory.
- Persistent booleans are `pink_wonderland_key_obtained`,
  `incarna_wonderland_chest_opened`, `wonderland_door_unlocked` and
  `wonderland_castle_unlocked`. Missing flags in older saves default to locked or
  unopened; existing progress and fog remain valid.
- The castle stays locked in normal play. A future quest can call
  `preload("res://scripts/wonderland/layout.gd").unlock_castle()`; it sets the one
  unlock flag and saves through Session. No quest or required item is invented.
  Existing `anywhereiwant` supports development access without persisting unlocks.

## Art and editing

The supplied **Fan-tasy free trial** provides the matching 16px grass/path atlas,
trees, bushes, houses and animated flower clusters. `mushroom_houses.png` provides
the mushroom cottage. Existing GFX trees frame the Flooded Forest passage, and
the cave's existing closed/open chest textures are reused. Original pixel-grid
ornaments provide tea settings, giant crockery, twisting landmark tree, castle,
furniture and the pink key. All source PNGs and soundtracks are unchanged.

The art uses nearest filtering, shared foliage palettes, selective roof palettes,
trunk collision, foot shadows, layered canopies and native atlas arrangements.
One ambience controller updates visible flowers, clocks, mushrooms and fountains;
it also draws butterflies, steam and chimney smoke. Leaves sway in a shared shader.
No restricted TopDownFantasy-Forest assets are referenced. The supplied isometric
library and Halloween sheets were left unused because their perspective/mood does
not fit. Bundled guides were inspected; no AI-use restriction was found in these
used assets. Usage relies on the user's supplied assets and license confirmation.

Edit `scenes/wonderland/*.tscn` directly in Godot. Ground and GardenPaths are
editable TileMapLayers, with shared TileSets in `resources/wonderland/`. Select
GardenPaths → Terrain → Garden path for connected edge/corner painting. Original
ornaments preview in the editor; their kind, accent, variation and transform are
editable in the Inspector. Move complete sprites rather than splitting atlas art.

`scripts/wonderland/layout.gd` owns region dimensions, seams and progress names;
`builder.gd` records deterministic authoring. `tools/bake_wonderland.gd` refuses to
overwrite existing scenes unless explicitly run with `-- --rebuild`. That command
replaces authored Wonderland scenes: preserve manual scene edits before using it.
It also rebuilds Wonderland/interior cartography. Run `tools/bake_world_map.gd`
after changing the Flooded Forest entrance or legacy forest geometry.
After manually editing Wonderland scenes, refresh their map textures safely with
`godot --headless --path . --script tools/bake_wonderland.gd -- --maps-only`;
this mode reads the edited scenes and leaves them untouched. Ground source 1
contains the four opaque grass variants; paint atlas transition/decorative grass
on an additional layer above that base.

## Verification

Godot 4.6.3 headless import and the focused Wonderland suite pass. The suite checks
real collision/route connectivity, physically driven doorway crossings in both
directions, valid Incarna completion without an automatic key, chest acquisition,
physical cave backtracking, the boundary door, eight building returns, interior
position/fog save-load round trips, outdoor fog persistence, inventory/map/pause,
default castle collision/lock, debug access and the future persistent unlock API.

Existing gameplay, Boss 2, BlankKitten, Incarna, cave, save/UI, forest and cartography
regressions pass. Earlier boss/player scripts, music, dialogue and cave geometry
were compared against the starting revision and remain unchanged.

Rendered verification uses the actual project with Xorg and Mesa software OpenGL,
not mockups. Every outdoor map, eight building exteriors, twelve interiors, both
pink-door states, the in-game map and the cave chest were captured and inspected.
Iterations corrected transparent grass-base misuse, roof palette artifacts,
castle framing, overly empty planting, room walls/furnishing and chest appearance.
The geographic review map temporarily uses the existing terrain reveal mode;
normal fog persistence and isolation are verified separately. Short stationary
samples of four outdoor maps ran approximately 59–60 FPS with a 60 FPS cap under
software rendering after native flower batching. This is not a hardware benchmark
or a guarantee for every camera position.

- [Outdoor environments and map](review/wonderland/outdoors.png)
- [All eight building exteriors](review/wonderland/houses.png)
- [All eight village interiors](review/wonderland/interiors.png)
- [Castle rooms and Incarna chest](review/wonderland/castle.png)
- [Full-size forest](review/wonderland/forest.png)
- [Full-size castle](review/wonderland/castle-exterior.png)
- [Landmark tree](review/wonderland/great-tree.png)
- [Giant teapot](review/wonderland/giant-teapot.png) and [teacup](review/wonderland/giant-teacup.png)

Run `godot --headless --path . --script tests/headless_wonderland.gd` for functional
checks. `tests/render_wonderland.gd` requires a graphical display and stores captures
outside the repository. Tests use separate validation saves, never the normal slot.
Some existing suites retain ObjectDB shutdown warnings; software rendering reports
unsupported VSync. Human review is still needed for artistic preference, extended
free exploration, animation feel, alternate hardware and controller/display setups.
The overworld retains Shift sprint; its existing controller has no separate focus
binding. Existing battle focus behavior and the 540×900 earlier arenas are unchanged.
