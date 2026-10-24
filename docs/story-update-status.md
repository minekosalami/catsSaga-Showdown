# Full story update

Implemented on `feature/story-update`, based on `84b3576`.

## Changes

- Smoki retains the original NPC dialogue and fight, now at `(336, 912)` in Forest Entrance. Spawn remains `(240, 912)`. Talking unlocks Deep Forest; the denied message is exactly `Talk to Smoki first!`. Existing defeated saves and the session-only unrestricted-access cheat remain compatible.
- Butterscotch repeats either supplied branch. Cupid supports decline/reaccept, waiting, wand return, mutually exclusive 50/75 rewards and repeat completion dialogue.
- PAWn Shop uses the user-confirmed timber building in `assets/enironment/gfx/Overworld.png`, region `(96, 0, 80, 80)`, at 2× display scale. Only Deep Forest trees `Tree415`, `Tree416`, `Tree425` overlapping its building/access footprint were removed. Original PNGs, terrain, paths and other trees were preserved.
- Dedicated shop screen uses the supplied shopkeeper/wand, existing dialogue choices, licensed wall texture, purchase validation, two-box joke and repeatable distraction. The keeper leaves the frame and returns unaware; the camera does not move. Acquisition history prevents buying/stealing another wand after returning it to Cupid. Close exits the shop; X/Escape use existing back/cancel actions.
- BlankKitten moves to Fluffy Forest at `(320, 912)`. Entry automatically opens the existing encounter dialogue/transition. Victory returns directly to exploration with no extra dialogue, and removes the NPC. Boss timing, attacks, music and combat code are unchanged; only the host's post-victory return hook changes.
- Doppelcat stands on the existing northern bridge at `(1936, 816)`, remains after victory, and uses the existing defeated dialogue without rematches.
- Ten independently saved feather IDs create one permanent completed cat toy on the tenth collection. Existing inventory displays feathers, wand, toy and NeCoins. No toy ability, ground currency or other rewards were added.
- Top-right exploration HUD shows NeCoins. A separate validated `story_progress` save record stores currency, quest, wand, feather IDs and toy. Older saves default safely; existing boolean flags and manual save semantics remain intact.
- Exactly four unchanged-design save stars: Entrance `(640,1168)`, Deep Forest `(2600,1000)`, Fluffy Forest `(1568,1040)`, Flooded Forest `(3008,1120)`. Minimap/world-map terrain cache and encounter locations were refreshed from actual scenes; fog still controls discovery.

## Placement interpretation

The supplied ChatGPT-generated reference is guidance only and is not imported as artwork. Its drawn region headers disagree with actual region edges, and its terrain/landmarks are altered, so it cannot establish exact world coordinates. The existing planning JSON supplies the real region bounds, offsets and full-export origin `(320,416)` at one image pixel per Godot unit.

Approximate source-scene registration used the reference's actual terrain rectangles (at displayed width 2048): Entrance x18–432, Deep Forest x432–1090, Fluffy Forest x1090–1506, Flooded Forest x1506–2028, with terrain top near y116. These are approximate guides, not exact transforms for the generated image. Required existing spawn, S1/S5, actual northern bridge, and pond geography take precedence over conflicting drawn markers.

Final NPC points: Butterscotch `(2635,906)`; Cupid `(3104,1760)`, visible beside the northern pond-side path; shop `(2590,852)`. Feather points and colours are centralized in `scripts/story/world_content.gd`; all were adjusted to avoid existing tree canopies without clearing additional trees. Eighteen approach/collection points were checked with the real player collision shape, flood-fill connectivity and final swept-shape approach checks.

The 96-pixel approach distance for Smoki/BlankKitten is approximately 20 feet **if** one 16-pixel map unit represents one meter. The project defines no physical scale; 96 pixels is the actual implemented distance.

The existing lowercase `get out of my sight` line is in Doppelcat's pre-fight apology/decline branch, not his post-fight dialogue. That existing line now reads `Get out of my sight!`. The actual post-fight lines were preserved rather than inventing or moving dialogue.

## Asset provenance

No image generation, new artwork, audio, music or fonts. All 1,399 existing tracked files under `assets/` remain byte-identical to the starting revision.

| Use | Existing source | Provenance/license evidence |
| --- | --- | --- |
| Shop building | `assets/enironment/gfx/Overworld.png` | User-supplied pack; user previously confirmed licensing and explicitly selected this timber building. No independent creator identity or license is invented. |
| Butterscotch, Cupid, shopkeeper, wand | `assets/npc textures/nart-yellow-npc.png`, `nartheart-npc.png`, `SHOPKEEPER (1).png`, `wand.png` | Original repository uploads supplied and specifically requested by the user. |
| Ten feathers | `assets/enironment/collectibles/feather.png` | Original user-supplied texture, referenced once per instance with Godot modulate colours; PNG unchanged. |
| Coin and shop wall | `assets/wonderland_human/rpg/roguelikeSheet_transparent.png` | Kenney Vleugels/Kenney and Lynn Evers, Roguelike RPG Pack, CC0. https://kenney.nl/assets/roguelike-rpg-pack . Original `License.txt` and atlas grid notice retained. Coin cell `(53,30)`; wall cell `(27,14)`, 16×16 cells on 17-pixel pitch. |

Kenney atlas hash was verified against `assets/wonderland_human/provenance.json`: `808c8d734480bc949b284f3bcc252e87e1ee53b24178791a6838cce6a319c439`. Existing provenance records the named-artist/license notices and a 2020 archive revision, `45df48c4d45f8716216b1a9e22df0b69cd9f5932`, at https://github.com/ETdoFresh/kenney.nl . See `docs/wonderland-asset-credits.md` for evidence and its limits. This is reasonable historical provenance, not an absolute forensic guarantee.

## Validation

Godot 4.6.3, isolated test profiles:

| Check | Result |
| --- | --- |
| Headless editor import | No script/import errors |
| Story progress/state/save validation | 67 checks passed |
| Integrated story/dialogue/shop/HUD/save-load/automatic victory | 81 checks passed |
| All collection/save/NPC approaches | 18 reachable, clear points; zero failures |
| Existing music, shooting/damage, SATURATE and hitbox suite | 37 checks passed |
| Existing Doppelcat combat overhaul suite | 46 checks passed |
| Existing manual save interaction/failure/Continue suite | 15 checks passed |
| Save-marker discovery and persistence | 33 checks passed |
| Map labels and tooltip geometry | 27 checks passed |
| Cartography cache rebuild | Successful |
| Original assets and git whitespace audit | Unchanged assets; diff check passed |

Nine actual standalone Godot/X11 Compatibility screenshots were captured and inspected in `docs/review/story-update/`, including NPC placements, shop exterior, dialogue, merchandise and keeper-offscreen theft prompt. These are rendered game captures, not generated artwork. The render script is `tests/render_story_update.gd`.

The environment uses software rendering and a dummy audio driver. Audible mixing and a full human-paced playthrough still require manual testing. Automated victory verification advances the existing timeline to its endpoint; it does not claim a full real-time survival playthrough. Some existing test shutdowns report ObjectDB/resources-in-use warnings; no runtime script errors occurred in the final passing runs.

Archived cave/Wonderland/Incarna scenes and progression remain inactive and unchanged. Existing fullscreen, movement, collision geometry (apart from the explicit shop building and three cleared trees), cheat controls, combat attacks and timing are preserved.
