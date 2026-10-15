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

Wonderland now uses only the credited **Kenney Roguelike RPG, Indoor, Cave &
Dungeons and 1-Bit** source sheets. All previous AI-authored ornament drawing,
embedded grass/floor pixels, decorative polygons and bespoke roof/foliage shaders
are removed. The source PNGs are unchanged. Original user-supplied packs remain
in the repository but are no longer referenced by Wonderland's art, entrance or
reward chest. See [the before-edit audit](wonderland-art-audit.md) and
[artist credits, license notices and provenance evidence](wonderland-asset-credits.md).

The compatible 16px human atlas artwork supplies grass, connected sand paths,
foliage, mushrooms, flowers, masonry, roofs, complete door arches, furniture,
crockery, chest/rocks and key. Ordinary level composition repeats human wall and
table tiles; it does not draw replacement pixels. Shared nearest filtering and
integer display scales keep edges crisp. Landmark teapot, cup and tree magnify
native human art and intentionally have larger pixels. Human plants sway gently;
fountain artwork receives a subtle tint animation. The previous drawn butterflies
and steam have been removed rather than replaced with generated effects.

Edit `scenes/wonderland/*.tscn` directly in Godot. Ground and GardenPaths remain
editable TileMapLayers, with shared TileSets in `resources/wonderland/`. Select
GardenPaths → Terrain → Garden path for edge painting. `ornament.gd` previews
human atlas compositions in the editor; kind, variation, footprint, accent and
transform remain editable. Keep complete native sprite arrangements intact.

`scripts/wonderland/layout.gd` still owns dimensions, seams and progression names.
The initial authoring tool remains available, with human-only visuals, but this
replacement did **not** run its world generator. `tools/replace_wonderland_art.gd`
is a guarded visual migration, not a map rebuilding tool. Do not use `--rebuild`
after hand-editing scenes: it intentionally replaces authored scene layouts.

Cartography now captures actual scene artwork into the existing atlas bounds,
replacing the earlier painted background/prop symbols. Refresh it with a graphical
Godot invocation, for example on this environment's display:

```sh
DISPLAY=:102 LIBGL_ALWAYS_SOFTWARE=1 godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/bake_wonderland.gd -- --maps-only
```

This mode reads existing scenes and leaves them untouched. A headless dummy
renderer cannot capture images; the tool reports that limitation without writing
replacement maps. Existing fog coordinates, region grouping and save data are
unchanged.

## Verification

The human-art replacement passed Godot 4.6.3 import and **163 focused gameplay
checks**. These exercise actual doorway crossing, all outdoor links both ways,
all eight building returns, normal castle locking/debug access, chest/key
progression, cave backtracking, inventory/map/pause, and position/fog save-load.

**87 art and structure checks** verify unchanged collision shapes/transforms,
spawn markers, portal destinations, map dimensions and occupied floor/path cells
against the pre-replacement `c5e8815` snapshot for all 18 scenes. They also verify
all source/licensing file hashes and reject the former generated pixel routines
or embedded floor images. No gameplay/progression, region, boss, player, save or
fog scripts were changed by the art replacement.

Existing gameplay, Incarna, cave, save/UI, forest and cartography regression suites
pass. Rendered verification uses Xorg/Mesa software OpenGL and dummy audio. All
six outdoor maps, eight building exteriors, twelve interiors, both entrance states,
the chest and geographic map are captured with `tests/render_wonderland.gd`.
Actual rendered inspection corrected atlas offsets, path seams, roof gaps,
truncated arches, table/bed arrangements, overlapping facade windows and flag
placement. The review overview temporarily uses the existing reveal mode; normal
fog and its persistence are checked independently.

- [Outdoor environments and map](review/wonderland/outdoors.png)
- [All eight building exteriors](review/wonderland/houses.png)
- [All eight village interiors](review/wonderland/interiors.png)
- [Castle rooms and Incarna chest](review/wonderland/castle.png)
- [Full-size forest](review/wonderland/forest.png)
- [Full-size castle](review/wonderland/castle-exterior.png)
- [Landmark tree](review/wonderland/great-tree.png)
- [Giant teapot](review/wonderland/giant-teapot.png) and [teacup](review/wonderland/giant-teacup.png)

Run `godot --headless --path . --script tests/headless_wonderland.gd` for gameplay
checks, and `tests/headless_wonderland_art.gd` for the provenance/structure checks.
`tests/render_wonderland.gd` requires a graphical display and writes captures
outside the repository. Tests use isolated validation saves.

Some existing suites retain ObjectDB shutdown warnings; software rendering reports
unsupported VSync. Human review remains necessary for artistic preference, longer
free exploration, animation feel and other hardware/display setups. Giant props
use enlarged low-resolution human sprites rather than newly illustrated high-detail
art. The overworld retains its existing controls and battle resolutions.
