# Alive UI presentation: asset sources and reuse

This update downloads, generates and modifies **no image, font, music or sound files**. New surfaces, meters, cursors, item emblems, light shafts, mist, water motion, particles and grade effects are functional Godot UI geometry, shaders and animation code. No image generation or audio synthesis was used.

| Existing asset | Human creator / source | License and existing evidence | Presentation use |
|---|---|---|---|
| Ninja Adventure tree and leaf | Pixel-Boy, [Ninja Adventure](https://pixel-boy.itch.io/ninja-adventure-asset-pack) | CC0; original notice in `assets/overhaul_human/LICENSE.md`; historical distribution/source evidence also described in `docs/wonderland-polish-credits.md` | Dim edge foliage, drifting leaves in ordinary battle backgrounds. Original PNGs unchanged. |
| LPC grass and water | Lanea Zimmerman (Sharm), [Liberated Pixel Cup](https://github.com/OpenGameArt/LiberatedPixelCup) | Used under CC BY-SA 3.0. `assets/environment_human/lpc/provenance.json` pins upstream revision `f61104a1ecc54e7bce54b82ada7d7ba4c41bc524` and the original Sharm outdoor paths/hashes. Authors, README and full license remain beside the images. | Samples existing 32px terrain cells in the background shader; darkens/tints at runtime. PNGs are unmodified. Attribution: **Grass and water — Sharm, Liberated Pixel Cup, CC BY-SA 3.0.** |
| DejaVu Sans Mono, Bold, Serif Condensed | DejaVu contributors / Bitstream, [DejaVu fonts](https://dejavu-fonts.github.io/) | Existing `assets/ui/fonts/LICENSE.txt`: Bitstream Vera terms, with DejaVu changes in the public domain. All existing copyright/license notices retained. | UI body, hierarchy, large grades and main-menu title. No new or modified font. |
| Roguelike RPG atlas | Kenney Vleugels / Kenney, with Lynn Evers, [Roguelike RPG pack](https://kenney.nl/assets/roguelike-rpg-pack) | CC0; original `assets/wonderland_human/rpg/License.txt` retained. | Existing shop wall and coin icon continue unchanged. |
| Player, enemy, boss, SHOPKEEPER and wand textures | User-supplied repository artwork | Reused as provided; no new third-party creator or license claims are made for these files. | Main-menu player portrait, encounter portraits, Records, results and existing shop composition. |

Full original licenses and the existing in-game asset credits remain intact. No external audio was added; existing soundtrack and dialogue voices are unchanged. Required LPC credit already appears in the existing environmental notices used by the Credits page. No gameplay artwork is replaced.
