# Wonderland environmental reconstruction

The six outdoor scenes and twelve existing interiors have been rebuilt with authored winding routes, planted groves, clearings, new room footprints and credited human artwork. Existing region extents, geographical offsets, entrance markers, portal destinations and village building positions are retained. No characters, encounters, quests, dialogue or rewards were added.

| Region | Environmental changes | Actual Godot capture |
| --- | --- | --- |
| Wonderland Forest | Layered green/pink groves, flowering-tree landmark, fountain, two open clearings, northern and southern exploration loops; reserved Smoki arrival space | [Overview](review/wonderland-rebuild/wonderland_forest.png) |
| Mushroom Thicket | Violet/turquoise mushroom groves, oversized formations, pond, branching loops and drifting spores using existing leaf frames | [Overview](review/wonderland-rebuild/mushroom_thicket.png) |
| Tea Gardens | Flowering garden loops, ornate clothed tea tables, cup/teapot centerpieces, fenced planting and rose clusters | [Overview](review/wonderland-rebuild/tea_gardens.png) |
| Royal Woods | Irregular emerald groves, woodland arch, banners, fountain, pond and connected scenic routes | [Overview](review/wonderland-rebuild/royal_woods.png) |
| Wonderland Village | All eight original buildings/doors retained; textured roofs/siding, connected cottage lanes, floral borders and fountain square | [Overview](review/wonderland-rebuild/wonderland_village.png) |
| Queen's Castle Grounds | Preserved locked castle, shingled towers, flowering approaches, twin garden ponds, banners and fountain | [Overview](review/wonderland-rebuild/queens_castle.png) |

Interiors use smaller furnished rooms and alcoves, herringbone floors, floral wallpaper, original-art bookshelves, cabinets, clocks, beds and rugs. The [Teapot House](review/wonderland-rebuild/teapot_house.png) retains its original Village connection and now has a tea area, kitchen and sleeping alcove. [Royal Library](review/wonderland-rebuild/royal_library.png), [Flower Shop](review/wonderland-rebuild/flower_shop.png), [Bakery](review/wonderland-rebuild/bakery.png), [Clockmaker](review/wonderland-rebuild/clockmakers_house.png), and [Throne Room](review/wonderland-rebuild/throne_room.png) show their retained purposes.

## Implementation and preservation

- `scenes/wonderland/*.tscn`: 18 editable baked maps. Primary/secondary paths, water, flowers, boundaries and interior walls use TileMapLayers. Props expose kind, variant, scale and animation in the Inspector.
- `scripts/wonderland/environment_plan.gd` and `tools/reconstruct_wonderland.gd`: explicit route/clearing definitions and an opt-in authoring tool (`-- --apply`). Runtime never generates geography. Re-running the tool replaces environmental dressing, so commit hand edits first.
- `environment_prop.gd`, `ornament.gd`, `ambience.gd`, and four Wonderland shaders: credited atlas art, independent foliage sway, mushroom wobble/tint, flower motion, pendulum frames, fluttering banners/signs, fountain motion and subtle light variation. No day/night, rain, canopy-shadow or weather lighting is installed.
- `scripts/systems/session.gd`: ordinary Wonderland-to-Wonderland travel gets a roughly 1.6-second [curved page wipe](review/wonderland-rebuild/storybook-transition.png) and the destination's existing name. The active Smoki story sequence keeps its original transition path.
- `scripts/systems/ambience.gd`: distinct sunny Wonderland profiles, quiet wind/birds/insects and crossfades. Map-local fountain, glass and wood details use positional audio with limited voices. The existing soundtrack player and battle clocks are untouched.
- `resources/maps/*_terrain.res`: actual rendered map thumbnails regenerated without changing map offsets or exploration/fog/save formats.
- [Asset provenance, original artist credits and licenses](wonderland-environment-rebuild-credits.md); new credits also included in the exportable in-game credits resource.

Original maps are recoverable from Git revision `5f04f37` (the branch base). An additional pre-edit archive was saved at `/workspace/.catsSaga-validation/wonderland-rebuild/before/maps-resources.tar.gz` in this environment. `tests/fixtures/wonderland_connections.json` records original functional-node coordinates and destinations. No original asset file was modified or deleted. The completed `scripts/story/ambush.gd`, player, combat, music, save implementation, Forest Chapter scenes and Wonderland connection/layout scripts remain unchanged.

## Validation actually performed

Godot 4.6.3, Compatibility renderer; isolated test save/config profiles.

- Headless editor import: completed without script/import errors.
- `tests/headless_wonderland_rebuild.gd`: **190 checks passed**. All 18 scene extents, preserved entries/connections, 28×28 player-body clearance and collision-grid routes to every entry/usable portal; castle lock and deferred collider unlock included. The test waits for the existing gate's deferred physics update before querying it.
- `tests/wonderland_live.gd`: **128 checks passed headless and 128 passed in a standalone X11 window**. Actual seam crossing, existing portal callbacks/return destinations, all 18 world wrappers, music continuation, castle lock/interaction, no encounter director/new dialogue, legacy obstructed-position recovery, progress load, save-point restriction, reduced particles and ambience mute.
- `tests/headless_ambush.gd`: **88 existing checks passed**, including unchanged dialogue ordering, Smoki/player landings, portal arrival, interrupted-arrival recovery, one-way return lock and no cutscene replay. This test emitted shutdown-only resource/RID warnings; no in-play failure occurred.
- `tests/render_wonderland_rebuild.gd`: captured all 18 maps, six close views; verified outdoor image pixels change over time. Actual images were inspected, then furnishings, overlap, doorway clearance and wall framing corrected and re-rendered.
- Standalone visual sampling: **80 checks passed**; six outdoor landmark views sampled for 150 frames each. Final interior dressing was subsequently checked again by collision validation and the full 18-map renderer.
- `tests/audit_wonderland_assets.py`: checks source hashes and that original artwork/protected gameplay files are untouched. `git diff --check` passes.

Logs and screenshots are in `docs/review/wonderland-rebuild/`, excluded from Godot resources by the existing `docs/.gdignore`. Some test exits still report two resources/ObjectDB instances in use, including the existing ambush test. The evidence logs retain those warnings; they are not presented as clean process teardown.

## Performance and limitations

The final outdoor sample used a standalone 1280×720 X11 window, Mesa llvmpipe software rendering, VSync disabled, existing exploration zoom. Median frame times ranged **10.81–14.62 ms**, p95 **14.03–17.38 ms**, with **33–50 draw calls** in sampled views. [Per-region measurements](review/wonderland-rebuild/performance.json) describe short stationary samples, not a hardware benchmark or sustained 60 FPS guarantee.

Ground/flower/wall batching, shared atlases/shaders, baked dressing, 12 Hz visibility-culled decoration updates, 42 camera-local particles and limited positional voices keep runtime overhead bounded. New source media and notices total about half a megabyte; screenshot review files are outside runtime exports.

Human playtesting is still needed for the **4–6 minute thorough-exploration target**, subjective composition/animation comfort, rare movement edge cases and target-hardware frame pacing. No exploration-duration claim is made. Audio playback/muting/crossfades were exercised using Godot's Dummy audio driver; **listening balance was not verified**. Existing combat was preserved by scope/source checks and the intro regression, not by re-running every boss fight. Castle interiors were inspected through the test harness; normal gameplay still respects the castle's locked state.

## Reproduction

Use a disposable `XDG_DATA_HOME`/`XDG_CONFIG_HOME` and `CATSSAGA_TEST_PROFILE=1` to protect real saves. Run the three headless scripts above with `godot --headless --path . --script <test>`. Run `tests/wonderland_live.gd` and `tests/render_wonderland_rebuild.gd` without `--headless` under X11 for native rendering. `-- --visual-only` on the live test captures scenes/performance without repeating the door/save suite. `tools/bake_wonderland.gd -- --maps-only` updates cartography; do not use its older `--rebuild` option on the new layouts.
