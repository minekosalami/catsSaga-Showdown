# Shared Evil Bart artwork and forest grass

Both Evil Bart's overworld NPC and battle Sprite2D reference the existing **`assets/bartboss.png`**, using the same loaded Texture2D resource. Replace that file with your PNG, keeping the filename, and Godot's reimport updates both appearances. No duplicate image, replacement drawing, or shared gameplay script was added. If a replacement PNG has different dimensions, adjust both Scale axes equally on each scene's Sprite2D; leave the collision nodes unchanged.

The NPC stays at (1000, 450), with its existing 100-pixel interaction radius and Z dialogue behavior. Its uniform scale displays the current artwork at approximately 80 pixels high. The boss uses uniform scale 0.10603448, preserving its previous height (approximately 138 pixels) and keeping it clear of the boss HUD. Its previous scale was nonuniform; correcting the aspect ratio makes the artwork narrower. The existing movement code automatically accounts for the actual sprite width when keeping it inside the arena. Boss position, collision shape, attacks, movement logic, entrance squash/stretch, defeat animation, and music synchronization remain unchanged. Both sprites explicitly use nearest-neighbor filtering and preserve the source PNG's transparency.

## Grass atlas

The actual uploaded atlas is **`assets/enironment/grass-tileset.png`**, a 112×48 PNG; `assets/environment/Grass.png` is not present. The existing filename is used directly without copying, renaming, splitting, or modifying its pixels. This is the Simple Grass Tileset by Comp-3 Interactive, as identified by the project owner.

`resources/world/forest_grass.tres` is one shared editable TileSet with a 16×16 atlas grid. All 21 grid cells are available. Each tile has a `kind` custom-data label to distinguish grass, flowers, soil, and the connected cutout edges.

Each of the three forest maps has two persisted TileMapLayer nodes:

- **GrassGround**: replaces the old solid-color BackgroundPlaceholder, with plain grass and sparse single-cell tufts covering the map.
- **GrassDetails**: three small authored patches of flowers and leafy grass, placed off the paths and outside obstacles.

Both layers use nearest-neighbor filtering and have collision and navigation disabled. The shared TileSet has no physics layers. Existing path visuals, obstacle bodies, map boundaries, portals, markers, other NPCs, and the player texture remain unchanged. The layers draw behind the paths and entities. No runtime script repaints these tiles, so your editor changes persist.

The left three atlas columns form a connected **3×3 cutout border**, including a transparent center. They are preserved as one TileSet pattern and are not scattered through the maps. The soil column is available for painting but was not used to replace the existing paths.

## Paint tiles in Godot

1. Open `scenes/world/forest_entrance.tscn`, `deep_forest.tscn`, or `bart_area.tscn` in the 2D editor.
2. Select **GrassGround** in the Scene tree. Open the **TileMap** editing panel and select the grass atlas.
3. Select an atlas tile, choose the paint brush or rectangle tool, and left-click/drag to paint. Right-click erases. Save the scene with Ctrl+S.
4. Select **GrassDetails** to paint flowers or additional tufts on the separate decoration layer. Leave its collision setting disabled.
5. For the connected border, use the **Patterns** palette and stamp the saved 3×3 pattern as a unit; avoid painting isolated edge pieces as flowers.

Atlas coordinates are zero-based `(column, row)`:

| Tile | Coordinates |
| --- | --- |
| Plain grass | (3, 1) |
| Sparse grass tufts | (3, 0), (3, 2) |
| Additional leafy grass | (4, 0), (5, 0), (4, 1), (5, 1) |
| Red/yellow flowers | (4, 2), (5, 2) |
| Soil | (6, 0), (6, 1), (6, 2) |
| Connected cutout border | Columns 0–2, rows 0–2; use the saved pattern |

To edit the atlas, select the layer's TileSet resource in the Inspector and use the **TileSet** atlas editor. Keep **Tile Size** and **Texture Region Size** at 16×16. Changes to this external TileSet affect all three maps; painting a layer changes only that scene. If you replace the atlas with a larger image, create its additional cells in the atlas Setup editor rather than splitting the PNG. Keep the original cell positions if existing painted maps should retain their appearances.

## Validation

Godot 4.6.3 headless import completed without resource/script errors. Final results:

| Suite | Result |
| --- | --- |
| World assets | 53/53 passed |
| Combat gameplay | 150/150 passed |
| Overworld movement/collision/dialogue/navigation | 59/59 passed |
| QOL, pause, sprite, saves | 81/81 passed |
| Fresh-process saved progression reload | 7/7 passed |
| Evil Bart branching encounter | 70/71 passed; known upstream menu input failure below |
| Graphical UI/mouse/navigation under Xvfb/Mesa | 43/43 passed |

The new asset checks verify atlas coordinates, shared texture identity, nearest filtering, uniform scale, existing boss hitbox, NPC settings, noncolliding decoration, ground coverage, intact cutout pattern, placement outside paths/obstacles, and saving/reloading manual tile edits. Render captures were inspected for grass, flowers, player preservation, Bart's shared sprite, and boss HUD clearance. PNG bytes were compared to main and remain unchanged. All retained original map node sections are unchanged; only grass placeholders and Bart's visual placeholder were replaced.

An initial visual regression caught boss/HUD overlap when the old boss width was retained; preserving the old height fixed it. The gameplay and visual suites were rerun after that correction.

**Existing issue on main:** `project.godot` binds Z's `ui_accept` event to `device = 16`. On the installed Godot 4.6.3, normal keyboard events use device 0 and do not match; the menu Z-confirmation assertion fails. A device-16 synthetic event matches. This setting is unchanged by this patch. Mouse startup, overworld Z interaction, branching dialogue, fight transitions, victory, and navigation pass. The remaining menu input failure is reported rather than changing an unrelated input system.

Run `godot --headless --path . --script res://tests/headless_world_assets.gd` for the new checks. Existing suite commands are in `docs/evil-bart-encounter-guide.md`; run reload after the QOL suite using the same user-data directory. The installed engine is 4.6.3; the repository's 4.7 declaration is preserved.

Manual review remains for preferred NPC/boss visual sizes, physical-display pixel crispness, and audible music. Automated graphical tests use Dummy audio and software rendering; the driver reports unsupported V-Sync. No new artwork/audio, combat logic, dialogue, player artwork, or resolution settings were modified.
