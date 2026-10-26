# Wonderland visual cohesion and interiors v2

Baseline: `df4efab` (now merged into main by PR #44). A pre-edit archive is retained at `/workspace/.catsSaga-validation/wonderland-v2/before/baseline.tar`; the entire original state remains recoverable from Git. The v2 branch preserves all six outdoor extents, authored routes, eight village building positions, entrance markers, portal destinations, progression gates, existing dialogue and Smoki's script.

## Outdoor corrections and common visual standard

All six outdoor maps retain their established trees, color identities, buildings, landmarks, winding geography, animation and music/ambience. This is a targeted correction of the previous outdoor scenes, not a regenerated world.

- Grass/path edges previously selected only nine outer pieces; recessed corners had no diagonal-neighbor rule. Paths and water now use four source-art quarters per occupied 32px cell, selecting convex, straight and recessed corners from cardinal and diagonal adjacency. Existing occupied geography is retained.
- Road fringes and the enlarged water atlas used different grass palettes, while only the ground had region tinting. A shared shader now matches grass pixels to that region's ground color without tinting the dirt or water. The castle pond receives the same correction. Water also gets restrained surface-light variation.
- Streetlights used a 16px crop from a sheet whose individual posts occupy 32px; the original region also missed the base. The full 32×80 region at `(0,4)` preserves the complete lamp and base.
- Tables, counters and shelves had incorrect atlas cuts. New semantic regions include complete legs and edges. Alpha-bound trimming aligns furniture with its feet; pendulum animation preserves the trimmed clock region rather than restoring an oversized rectangle each tick.
- The primary environmental standard is approximately two world pixels per source-art pixel at normal zoom. New interior furnishings use 2× scaling, 32px floors use 64px world cells, and modular window/trim pieces use the same density. The larger water PNG is an already enlarged source sheet, so its smaller display scale produces compatible effective pixels. Existing organic outdoor tree size variation is retained. All environment textures use nearest filtering; global camera/display settings are unchanged.
- 248 obstructing canopies were relocated within their existing regions using the existing path masks; the protected Smoki arrival space stays clear. Individual foreground trees/mushrooms fade smoothly to 38% only when their bounds cover the player, and restore to full opacity afterward. Collision bodies are unaffected by fading. Body positions follow relocated sprite roots.

## Shadows, anchoring and depth

`depth.gd` renders static directional silhouettes using the original sprite/atlas pixels, with one shared lighting shader and a consistent light direction. Trees, buildings, lamps, fences, signs and furniture cast different silhouettes; no replacement shadow artwork or generic oval texture is generated. Shadows render below actors and props, above ground. Existing root Y-sorting is retained. Wall-mounted art is layered with the walls; furniture anchors use visible feet rather than transparent padding.

Interior floor shaders add restrained wall-base and corner shading from each room's actual floor rectangles. Warm floor tint, paneling and daylight window variants provide atmosphere without real-time light nodes, bloom, night filters, weather, or moving canopy shadows. Interior camera limits now cover the full existing 1280×960 map so the throne bay and upper windows are visible when approached.

## Twelve reconstructed interiors

Rooms use individually authored shapes and furnishing groups rather than a shared rectangle/rug/plant template. Every original entrance and connection remains in place. Rugs use the source sheet's actual seven-column palette layout and complete borders.

| Room | Reconstruction | Before | After |
|---|---|---|---|
| Grand Entrance Hall | Cross-shaped arrival hall, fountain axis, waiting bays and royal runner. | [View](review/wonderland-v2/before/castle_hall.png) | [View](review/wonderland-v2/after/castle_hall.png) |
| Royal Library | Eight bookcases, paired reading desks, seating nook and open cross-aisle. | [View](review/wonderland-v2/before/royal_library.png) | [View](review/wonderland-v2/after/royal_library.png) |
| Banquet Hall | Staggered dressed tables, individual dining chairs and serving counter. | [View](review/wonderland-v2/before/banquet_hall.png) | [View](review/wonderland-v2/after/banquet_hall.png) |
| Throne Room | Raised-shaped throne bay, long bordered carpet, audience seating and banner/lamp pairs. | [View](review/wonderland-v2/before/throne_room.png) | [View](review/wonderland-v2/after/throne_room.png) |
| Mushroom Cottage | Sleeping side, upper mushroom nook, sofa and central wooden table. | [View](review/wonderland-v2/before/mushroom_cottage.png) | [View](review/wonderland-v2/after/mushroom_cottage.png) |
| Teapot House | Four connected bays for cooking, tea, sitting and sleeping; warm paper and daylight windows. | [View](review/wonderland-v2/before/teapot_house.png) | [View](review/wonderland-v2/after/teapot_house.png) |
| Flower Shop | Nursery alcove, floral displays, preparation table and dedicated counter. | [View](review/wonderland-v2/before/flower_shop.png) | [View](review/wonderland-v2/after/flower_shop.png) |
| Clockmaker’s House | Clock display bays, workbench, service counter and storage. | [View](review/wonderland-v2/before/clockmakers_house.png) | [View](review/wonderland-v2/after/clockmakers_house.png) |
| Bakery | Separate oven bays, preparation table, serving counter and bread racks. | [View](review/wonderland-v2/before/bakery.png) | [View](review/wonderland-v2/after/bakery.png) |
| Royal Gift Shop | Display alcove, cabinet and table group with counter kept clear of the entrance. | [View](review/wonderland-v2/before/royal_gift_shop.png) | [View](review/wonderland-v2/after/royal_gift_shop.png) |
| Storyteller’s Cottage | Book-lined side nook, sofa, reading table and recessed fireplace. | [View](review/wonderland-v2/before/storytellers_cottage.png) | [View](review/wonderland-v2/after/storytellers_cottage.png) |
| Tiny Pink House | Compact bedroom with dressing alcove, vanity and a small dining space. | [View](review/wonderland-v2/before/tiny_pink_house.png) | [View](review/wonderland-v2/after/tiny_pink_house.png) |

[Upper throne bay](review/wonderland-v2/after/throne_room-upper.png) and [upper Teapot House](review/wonderland-v2/after/teapot_house-upper.png) show the additional camera framing. The storyteller fireplace was moved clear of the reading table after inspecting the rendered overlap.

## Outdoor comparisons and navigation views

These are actual standalone Godot captures with the player camera and existing HUD, at normal zoom. Outdoor comparison poses match; interior comparisons use the original fixed camera center `(640,480)` for equivalent framing, with additional upper-room views. The test places the player on clear ground when the requested comparison point is occupied in a redesigned room.

| Region | Before | After | Second view |
|---|---|---|---|
| Wonderland Forest | [View](review/wonderland-v2/before/wonderland_forest-0.png) | [View](review/wonderland-v2/after/wonderland_forest-0.png) | [Shore/path detail](review/wonderland-v2/after/wonderland_forest-1.png) |
| Mushroom Thicket | [View](review/wonderland-v2/before/mushroom_thicket-0.png) | [View](review/wonderland-v2/after/mushroom_thicket-0.png) | [Shore/path detail](review/wonderland-v2/after/mushroom_thicket-1.png) |
| Tea Gardens | [View](review/wonderland-v2/before/tea_gardens-0.png) | [View](review/wonderland-v2/after/tea_gardens-0.png) | [Shore/path detail](review/wonderland-v2/after/tea_gardens-1.png) |
| Royal Woods | [View](review/wonderland-v2/before/royal_woods-0.png) | [View](review/wonderland-v2/after/royal_woods-0.png) | [Shore/path detail](review/wonderland-v2/after/royal_woods-1.png) |
| Wonderland Village | [View](review/wonderland-v2/before/wonderland_village-0.png) | [View](review/wonderland-v2/after/wonderland_village-0.png) | [Shore/path detail](review/wonderland-v2/after/wonderland_village-1.png) |
| Queen's Castle Grounds | [View](review/wonderland-v2/before/queens_castle-0.png) | [View](review/wonderland-v2/after/queens_castle-0.png) | [Shore/path detail](review/wonderland-v2/after/queens_castle-1.png) |

All eight village entrances were separately captured and inspected: [Mushroom Cottage](review/wonderland-v2/after/entrance-mushroom_cottage.png), [Teapot House](review/wonderland-v2/after/entrance-teapot_house.png), [Flower Shop](review/wonderland-v2/after/entrance-flower_shop.png), [Clockmaker’s House](review/wonderland-v2/after/entrance-clockmakers_house.png), [Bakery](review/wonderland-v2/after/entrance-bakery.png), [Royal Gift Shop](review/wonderland-v2/after/entrance-royal_gift_shop.png), [Storyteller’s Cottage](review/wonderland-v2/after/entrance-storytellers_cottage.png), [Tiny Pink House](review/wonderland-v2/after/entrance-tiny_pink_house.png).

Route snapshots and local foliage-fade captures are in `docs/review/wonderland-v2/navigation/`. Additional real 1920×1080 captures cover Village, Castle Grounds, Teapot House and Throne Room under `after-1920/`. These verify framing/scaling at that size; they are not a full display-mode test or a claim about every possible viewport size.

## Verification performed

- Godot 4.6.3 headless editor import: no script/import errors.
- Existing geometry suite: **190/190 checks passed**, including all 18 scenes, preserved functional-node signatures, entry clearance, paths to doors and castle lock/collider behavior.
- New standalone navigation suite: **94/94 passed**. The real player collision body traversed **34,985 world pixels** using `move_and_collide`, including routes to all eight village buildings and all existing room exits. Mid-route camera views were captured. This is accelerated automated collision traversal, not a human keyboard playtest. All six regions also passed local foliage fade and opacity restoration checks.
- Existing runtime suite: **128/128 passed headless**, covering all 18 world wrappers, connected portal callbacks, music continuation, castle lock/interaction, legacy obstructed-position recovery, save-point restrictions, reduced particles and ambience mute.
- Existing Smoki suite: **88/88 passed**; the story implementation was not modified.
- All 18 environments were individually rendered and visually inspected. Corrections included carpet border selection, furniture cropping/feet, repetitive floor color strips, daylight windows, the upper camera limit and fireplace overlap. Eight exterior building approaches and sampled navigation views were also inspected.
- Asset audit: **39 source hashes match**, including the retained prior pack notices and audio. Original asset files and unrelated gameplay remain unchanged. In-game asset attribution updated.

Logs accompany the screenshots. Some test exits still report ObjectDB/resource warnings. The added static atlas cache now uses `@static_unload`, and depth tweens clear on exit; a final focused shutdown capture still reports two resources in use. No clean teardown claim is made. No in-play script errors were observed in the validated runs.

## Performance

Same Godot Compatibility renderer, X11/Mesa llvmpipe software renderer, 1280×720, normal zoom, VSync disabled. Each stationary sample contains 90 frames at the second outdoor comparison pose or the matching interior frame. These are short environmental samples, not a controlled hardware benchmark or a sustained 60 FPS guarantee. Raw before/after measurements are included as JSON.

| Outdoor region | Before median ms | After median ms | After p95 ms | After draw calls |
|---|---:|---:|---:|---:|
| Wonderland Forest | 14.28 | 14.40 | 17.60 | 38 |
| Mushroom Thicket | 13.64 | 14.03 | 19.55 | 71 |
| Tea Gardens | 12.04 | 13.17 | 15.36 | 43 |
| Royal Woods | 12.38 | 14.86 | 17.89 | 32 |
| Wonderland Village | 12.30 | 12.40 | 15.11 | 66 |
| Queens Castle | 12.35 | 13.63 | 18.61 | 41 |

Interior medians: **6.91–10.53 ms**. Shadows add rendering cost; some outdoor p95 frames exceed 16.7 ms on this software renderer. Typical desktop hardware and long-session frame pacing still need testing.

Shared textures/materials, static silhouettes, batched terrain, no real-time light nodes, existing culled 12 Hz decorative animation and visibility-filtered opacity checks keep the added systems bounded. New source media/notices total about 230 KiB. Review screenshots live under the existing `docs/.gdignore` and do not become runtime game resources.

## Assets and modified files

[New asset provenance and artist/license record](wonderland-v2-credits.md). New art is the same credited LPC collection; no new recordings, music, fonts or generated creative assets were added.

Important implementation files: all `scenes/wonderland/*.tscn`; `scripts/wonderland/environment_prop.gd`, `ornament.gd`, `ambience.gd`, new `depth.gd`; new terrain/shadow/room-depth shaders; `tools/cohere_wonderland.gd`; new capture/navigation tests; updated asset audit, exportable credits and rendered map thumbnails. No Forest Chapter scene, Smoki script, player controller, battle script, music manager, save implementation or connection/layout script was changed.

The opt-in v2 authoring tool requires `-- --apply`. Runtime uses baked scenes. Original outdoor masks and tree locations are retained in the baseline/metadata; re-running the v2 tool reapplies its targeted corrections. Commit manual scene edits first. Use `tools/bake_wonderland.gd -- --maps-only` for thumbnails; older rebuild tools would replace authored dressing.

Remaining manual checks: subjective room composition and navigation recognition, rare occlusion/overlap cases during free exploration, audio listening balance and target-hardware performance. Music/ambience code paths were exercised with Dummy audio, so auditory balance is not claimed. Boss fights were preserved by source/scope checks rather than replaying every fight. No new save point, automatic save, character, quest, enemy, encounter, dialogue or story event was introduced.
