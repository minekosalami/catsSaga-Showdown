# Wonderland visual audit and replacement plan

Audited the implementation at `c5e8815` before editing its visuals.

| Previous visual | Dependencies | Finding / replacement |
| --- | --- | --- |
| `ornament.gd` drawing commands | All 18 maps; runtime pink door and chest key | AI-authored pixel drawings: replace every branch with unchanged atlas regions from credited Kenney artwork. Includes castle, tree, mushrooms, houses, all furniture, flowers, key, door, rugs, banners and crockery. |
| Embedded images in `grass.tres`, `wood.tres`, `marble.tres` | Six outdoor Ground layers / twelve interior Ground layers | AI-authored generated pixels: replace with licensed human atlas tiles; retain all occupied cells. |
| `ambience.gd` butterflies and steam | All new maps | AI-authored drawn effects: remove drawn shapes; animate only existing human sprites. |
| Polygon shadows, interior wall panels and trim | Trees/houses and twelve interiors | Replace decorative geometry with human tile artwork. Preserve the separate StaticBody2D/CollisionShape2D nodes. |
| Fan-tasy free trial sheets | Six outdoor maps, five village facades, flowers and path tiles | Bundled guide identifies Valerio Colonna, but no sufficiently explicit redistribution license was found. Replace Wonderland references; do not claim independently verified rights or remove user-supplied originals. |
| `mushroom_houses.png` | Mushroom Cottage facade | Unattributed source: replace; retain its building and door. |
| GFX trees / dirt used by Wonderland entrance | Flooded Forest addon | User confirmed permission previously, but creator/provenance remain undocumented. Replace only the addon visuals; original Flooded Forest artwork remains outside this task. |
| Existing cave chest / boulders newly reused for reward | Runtime Incarna chest and temporary barrier | Bundled notice credits Schwarnhild and allows game use but prohibits asset redistribution. Use Kenney chest/rocks for this addition; leave original cave content unchanged. |
| Foliage and roof shaders | Outdoor sprites | No generated source images, but remove bespoke palette drawing from new visuals; use original human palettes and ordinary sprite animation. |
| Earlier review screenshots | `docs/review/wonderland/*.png` | Contain previous AI drawings: replace with current Godot renders. |
| Map caches | `resources/maps/*_terrain.res` | Derived geographic data, not source artwork. Refresh from replacement terrain; retain map/fog coordinates and dimensions. |

## Replacement plan

Use the compatible 16px Kenney Roguelike RPG, Indoor and Cave & Dungeons sheets
for terrain, architecture, vegetation and furnishings. A single human-drawn 1-Bit
key glyph is tinted pink. Licenses, source paths and byte hashes are retained in
`assets/wonderland_human/`; provenance and use are documented in
[asset credits](wonderland-asset-credits.md).

Edit the existing packed scenes in place. Preserve region definitions, node
positions, occupied ground/path cells, collision transforms/shapes, markers,
portals, building count, destinations and progression scripts. Replace only
visual children/resources and the visual authoring routines. Do not run the world
generator. A before/after structure snapshot will check these constraints.

Source sheets are not repainted or generated. Atlas selection, repeated wall
tiles, native furniture arrangements, nearest-neighbor display and simple runtime
tints/transforms assemble human artwork as ordinary level decoration.
