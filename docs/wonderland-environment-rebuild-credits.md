# Wonderland environmental reconstruction: assets and provenance

No image/audio generation, enhancement, synthesis, redrawing, or new animation frames were used. Original game artwork remains in the repository. This reconstruction arranges original human atlas pixels using TileMapLayers, AtlasTextures, transforms, shader tinting and shader motion. Downloaded PNG/Ogg bytes are unchanged.

## New LPC artwork

Source: [Eliza Wyatt's LPC repository](https://github.com/ElizaWy/LPC/tree/f07f7f5892e67c932c68f70bb04472f2c64e46bc), revision `f07f7f5892e67c932c68f70bb04472f2c64e46bc` (2023-12-01).

License: [OGA-BY 3.0](https://opengameart.org/content/oga-by-30-faq), permitting commercial game use and redistribution with attribution. The artist's root `Credits.txt` describes the collection as hand drawn. Sheet-specific credits identify original artists, source packs, recoloring and adaptation. Those notices are retained verbatim under `assets/wonderland_human/rebuild/`. `provenance.json` records every source path and SHA-256 digest.

| Imported sheet | Artists credited by the source | Use |
| --- | --- | --- |
| `trees_spring.png` | Lanea Zimmerman (Sharm), Eliza Wyatt (DeathsDarling) | All outdoor groves and flowering-tree landmark |
| `cabinet.png`, `clock.png`, `fireplace.png` | Lanea Zimmerman, Eliza Wyatt | Existing house and castle interiors |
| `beds.png` | Lanea Zimmerman, BlueCarrot16, Eliza Wyatt | Existing bedrooms and Teapot House alcove |
| `rug.png` | Eliza Wyatt | Furnished interiors |
| `hipped_roof.png` | Lanea Zimmerman, Eliza Wyatt | Textured cottage and castle roofs |
| `cottage_wall.png` | Eliza Wyatt | Cottage siding |
| `wallpaper.png` | Lanea Zimmerman, Eliza Wyatt | Interior wall faces |
| `herringbone.png` | Eliza Wyatt | House floors |
| `ornate_table.png`, `lighting.png` | Lanea Zimmerman, Eliza Wyatt | Tea-party tables and outdoor lamps |
| `garden_fence.png` | Lanea Zimmerman, Eliza Wyatt | Short garden-fence segments |

Original source links and artist-specific details are in `Terrain-Credits.txt`, `Furniture-Credits.txt`, `Beds-Credits.txt`, `Rugs-Credits.txt`, `Roofing-Credits.txt`, `Walls-Credits.txt`, `Floor-Credits.txt`, and `Fences-Credits.txt`. The root notice explains the attribution requirements. The human-authorship basis is the first-party artist repository, its explicit hand-drawn description, named source artists and documented modification history; this is reasonable provenance evidence, not a forensic certification of every historical production step.

Already-imported LPC Revised flowers and mushrooms remain unchanged under `assets/environment_human/lpc_revised/`. Their retained terrain credits attribute flowers to Lanea Zimmerman, Hyptosis, BlueCarrot16 and Eliza Wyatt, and mushrooms to Hyptosis and Eliza Wyatt, under OGA-BY 3.0. Their source art is used for rose drifts, boundary undergrowth, and the fungal woodland. Shader tinting supplies turquoise/violet accents without changing the image files.

## New recorded environmental detail

`assets/wonderland_human/rebuild/audio/glass_clink.ogg` is the unchanged `mods/default/sounds/default_glass_footstep.ogg` from [Minetest Game / Luanti](https://github.com/luanti-org/minetest_game/tree/0.4.17), credited to **Mito551**, **CC BY-SA 3.0**. [License](https://creativecommons.org/licenses/by-sa/3.0/).

The downloaded bytes at revision `72e52f52d04026ca7cc9c712862e8365caf91550` were compared with tag `0.4.17`, commit `77d5406440e5ddb7613634b09bf8a53325d1e208`, dated 2018-05-18: identical. This predates contemporary generative audio systems and the historical repository credits the named sound artist. Both source attribution notices, the original license, revision and SHA-256 are retained in the audio folder. Used quietly near tea tables/cups; playback gain and slight pitch variation only. This audio remains CC BY-SA 3.0; no claim is made that its license covers unrelated game code or assets.

## Retained sources

- **Pixel-Boy, Ninja Adventure — CC0**: existing terrain/path/water tiles and six-frame pink-leaf particles. First-party repository inspected at `6ac78232d5aedcc85ce5f27d060ea92366f7c24a`; existing 2022 distribution notice corroborates the license. No pack music or character assets added.
- **Kenney Vleugels / Kenney (Roguelike RPG also credits Lynn Evers) — CC0**: existing furniture, gates, castle masonry, architectural trim, banners, tea props, windows and signs.
- **DejaVu contributors — DejaVu/Bitstream Vera license**: existing `DejaVuSerifCondensed.ttf` for region names; existing font license retained. No new font was downloaded.
- Existing human field recordings: laurent/felix.blume (wind/grass), HerbertBoland/reinsamba/UncleSigmund (birds), Mike Koenig (insects), volivieri (waterfall), and CGEffex/BlockMen (wood creak). Use is limited to the previously credited permissive files. The wind/bird/water source archive identifies some licenses as CC BY without a version; that historical limitation remains documented rather than assigning an invented version.

Canonical links, original license notices and archive evidence for retained assets: [Wonderland art credits](wonderland-asset-credits.md), [Wonderland polish credits](wonderland-polish-credits.md), `assets/ambience_human/SOURCE-LICENSES.txt`, and `assets/weather_human/`. No noncommercial-only archive files, pack soundtracks, or unverified artwork were imported.

The in-game Info → Credits → Asset Credits resource includes the new creator/source/license credits so they accompany exported games as well as the repository.
