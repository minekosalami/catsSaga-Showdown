# Forest overhaul and tree size variation

All three areas now have editable, painted `Paths` TileMapLayers with winding approaches, varying widths and optional clearings. Forest Entrance introduces an inspection spur and a southern clearing. Deep Forest has denser clusters and two secluded branches around its existing NPC. Bart's approach leads into an open encounter clearing with an additional southern pocket. Existing entry markers, portals, NPC coordinates and dialogue are retained.

Only existing artwork is used: `assets/enironment/tree.png` and the 16×16 atlas `assets/enironment/grass-tileset.png`. Grass and flowers retain their existing atlas arrangements; paths use the atlas's single-cell soil tiles in column 6. No PNG bytes were changed. The existing Deep Forest NPC remains an editable placeholder because no dedicated NPC artwork is available. Its dialogue is unchanged.

## Trees

Trees are stored as individual reusable `scenes/world/tree.tscn` instances, rather than generated whenever an area loads. Their serialized `Variation Seed` selects a stable uniform size between 0.7× and 1.5×; the seed distribution favors medium trees. The authored map populations are:

| Area | Small | Medium | Large |
| --- | ---: | ---: | ---: |
| Forest Entrance | 10 | 21 | 3 |
| Deep Forest | 19 | 38 | 5 |
| Bart's Area | 9 | 20 | 3 |

The inspectable tree is an additional fixed 0.85× instance. Larger trees frame boundaries, while smaller and medium trees mix inside clusters. Full canopy rectangles leave paths unobstructed. Tree roots remain at trunk bases for Y-sorting, and each instance owns a capsule collider that scales with its trunk. Trees and characters share Y-sorting through the map; the overworld player also participates.

To edit an individual tree:

1. Open a map in `scenes/world/` and select an instance under **Trees**.
2. Move the instance normally in the 2D editor; its origin marks the trunk base.
3. Set **Size Override** between `0.7` and `1.5` in the Inspector. Sprite proportions and trunk collision update together. `0` restores seeded sizing.
4. Change **Variation Seed** to choose another deterministic size. Do not nonuniformly scale the tree root.
5. Duplicate a tree instance and choose a new seed to add variety. Keep its canopy clear of paths, portals, NPC interaction space and entry markers.

The texture is shared by all trees. Replace the single source PNG to update every tree; no duplicated or altered image files are introduced. Nearest filtering preserves crisp pixels.

## Painting maps

Open `forest_entrance.tscn`, `deep_forest.tscn` or `bart_area.tscn`. Select **GrassGround**, **GrassDetails** or **Paths** in the scene tree, then use the Godot TileMap bottom panel to choose atlas tiles and paint in the 2D viewport. All layers use the external `resources/world/forest_grass.tres` TileSet and its 16×16 grid.

Use the ordinary grass cells for ground, flowers and tufts for sparse details, and column 6 soil cells for paths. The atlas's connected 3×3 cutout is available as a complete pattern; avoid scattering its component cells. Ground, path and decorative layers do not create collisions. Tree capsules and the four retained outer boundary bodies provide collision. The old internal rectangular test obstacles and their colored visuals have been removed.

Entries and Portals remain organized separately. Move an exit together with its arrival marker in the destination map if you later redesign transitions. Camera limits still follow each map's original dimensions. If a restored save position intersects new solid geometry, the player moves to an existing entry marker without resetting progression; valid save positions remain exact.

The X menu-back event was corrected from input device 16 to the standard keyboard device 0, preserving the existing key. No battle scripts, dialogue, player artwork or resolution settings changed.

## Validation

Godot 4.6.3 headless import passed. **546 automated checks passed**: 36 new forest-overhaul checks, 460 existing headless checks and 50 graphical checks under Xvfb/software OpenGL. Coverage includes all three scenes, connected paths, collision-free path interiors, entry/exit access, canopy clearance, stable tree sizes, independent trunk colliders, Inspector overrides, blocked and valid saves, actual movement and area transitions, NPC interaction, Bart encounter/victory/return, controls, shooting, SATURATE, BEAM, CATA and music timeline state.

Run the focused validation with:

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/headless_forest_overhaul.gd
```

Existing regression suites remain in `tests/`. Run `reload_saved_progress.gd` after `headless_qol.gd` with the same user-data directory. Graphical captures and test saves were kept outside Git; graphical validation uses Dummy audio.

Manual playtesting remains for forest composition, preferred tree sizing, player/canopy depth perception while walking behind trees, exploration feel, native-window behavior and audible music. The installed engine is 4.6.3; the project's preexisting 4.7 declaration is retained.
