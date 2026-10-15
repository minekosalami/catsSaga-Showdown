# Wonderland polish: human artwork and recorded ambience

No image/audio generation model or service was used. Original downloaded files
are unchanged; atlas regions, tile placement, animation, volume envelopes,
pitch variation, sprite transforms and masking compose those human sources.
`assets/wonderland_human/polish-provenance.json` records repository revisions,
upstream paths and SHA-256 hashes. The automated polish test verifies every hash.
The same creator/source/license credits are accessible in-game via Info → Credits → Asset Credits. The preloaded `resources/ui/wonderland_asset_notices.tres` includes the notices in Godot exports even when loose Markdown files are excluded.

Existing Kenney sheets retain their notices and
[earlier credits](wonderland-asset-credits.md).

## Pixel-Boy — Ninja Adventure (CC0)

Canonical creator/pack: [Pixel-Boy](https://pixel-boy.itch.io/ninja-adventure-asset-pack).
The creator's [NinjaAdventure Godot repository](https://github.com/pixel-boy/NinjaAdventure)
identifies itself as the Ninja Adventure Asset Pack. Selected original sheets,
shadow and six-frame petal art are pinned to
`6ac78232d5aedcc85ce5f27d060ea92366f7c24a` (2024-04-19).

Additional unchanged terrain/water, detail sheet and two tree images come from
[Clear Code's Zelda distribution](https://github.com/clear-code-projects/Zelda/tree/5f4c57bfbb162d2f19b287a5c24816d93c17e08d),
commit `5f4c57bfbb162d2f19b287a5c24816d93c17e08d` (2022-01-23),
inside `15 - fixes audio.zip`. Its original README explicitly credits Pixel-Boy
and AAA, links the canonical Ninja Adventure pack, and states the art and
soundtrack are CC0. That unmodified notice is preserved as
`assets/wonderland_human/ninja/SOURCE-LICENSE.md`. **No soundtrack or character
art from this distribution is used.** AAA is credited there for the original
pack's music; the imported environment artwork is attributed to Pixel-Boy.

Use: Wonderland terrain, river banks, bridge/interior wood, floor tiles,
three tree silhouettes, shrubs, daisies, falling petals, and shared cat shadows.
Kenney artwork supplies existing architecture, furniture, mushrooms, tea props,
flowers, gates, chest, and the new physical wooden signs. The detailed and tiny
source sheets have different native sizes; AtlasTexture/TileSet display scales
reconcile those sizes without resampling or editing their files. Petals use the
artist's six horizontal frames, not the whole sheet as a particle.

Provenance basis: named pixel artist, first-party art repository, an explicit
CC0 redistribution notice linking that pack, and an archived distribution from
January 2022. Direct itch.io access is blocked here; the original download page
could not be independently re-read. This is credible attribution and archive
evidence, not a forensic guarantee of every historical production step.

## Lorc — Game-icons.net (CC BY 3.0)

**Icons made by Lorc.** [Paw-print](https://game-icons.net/1x1/lorc/paw-print.html)
and [echo-ripples](https://game-icons.net/1x1/lorc/echo-ripples.html),
[original source repository](https://github.com/game-icons/icons),
[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).
The repository's contributor/license notice is preserved at
`assets/movement_human/LICENSE.txt`; its Lorc directory identifies the artist.
The unchanged white SVG ink is masked over its original black background and
scaled/tinted for transient pawprints and water ripples. No new icon was drawn.

## Human nature recordings

The selected files are archived in
[Neuromancer56's MinetestAmbience](https://github.com/Neuromancer56/MinetestAmbience/tree/4b78eb558617662c2c47f029679692780fcc46cf/ambience/sounds),
commit `4b78eb558617662c2c47f029679692780fcc46cf` (2016-03-18).
The original per-sound notice is retained at
`assets/ambience_human/SOURCE-LICENSES.txt`. This notice also describes other
assets **not included or used here**, including noncommercial sounds and music.
Only the following permissively licensed recordings were selected:

| Included file | Human creator / original recording | License in the archive | Use |
| --- | --- | --- | --- |
| ComboWind.ogg | [laurent — Wind in the trees](https://freesound.org/people/laurent/sounds/16995/) and [felix.blume — Dry grass in wind](https://freesound.org/people/felix.blume/sounds/146436/) | CC BY; CC0 respectively; archived combination credits both | Soft overlapping outdoor breeze; quieter through interior walls |
| birdsongnl.ogg | [HerbertBoland](https://freesound.org/people/HerbertBoland/sounds/28312/) | CC BY, version unspecified in archive | Randomized birdsong |
| robin2.ogg | [reinsamba](https://freesound.org/people/reinsamba/sounds/32479/) | CC BY, version unspecified in archive | Randomized birdsong |
| bluejay.ogg | [UncleSigmund](https://freesound.org/people/UncleSigmund/sounds/42382/) | CC0 | Randomized birdsong |
| Crickets_At_NightCombo.ogg | Mike Koenig — [Nightime](https://soundbible.com/951-Nightime.html), [Crickets at Night](https://soundbible.com/365-Crickets-At-Night.html) | CC BY 3.0 | Restrained intermittent insect layer |
| Spooky_Water_Drops.ogg | [Mike Koenig](https://soundbible.com/380-Spooky-Water-Drops.html) | CC BY 3.0 | Cave bed, with a dedicated reverb bus |
| drippingwater_drip_a.ogg, drippingwater_drip_b.ogg | kddekadenz — [Dripping Water mod](https://minetest.net/forum/viewtopic.php?id=1688) | CC0 | Random cave drips |
| lake_waves_2_calm.ogg | [Benboncan — Lake Waves 2](https://freesound.org/people/Benboncan/sounds/67884/) | CC BY, version unspecified in archive | Flooded Forest and proximity to water |
| small_waterfall.ogg | [volivieri](https://freesound.org/people/volivieri/sounds/38390/) | CC BY, version unspecified in archive | Quiet water detail near Wonderland rivers |

CC BY permits commercial use with attribution. For the older Freesound entries
whose archived notice says only “Attribution License,” a license version is not
invented; the original creator, recording title/ID and source are listed above.
Recordings remain in their archived Ogg encoding. Playback uses gain envelopes,
layering and small pitch adjustments; cave ambience receives reverb. No new
waveform was synthesized or exported, and none of the archive's noncommercial
recordings or music are loaded. The existing synthesized cave-bed/drip routine
was removed in favor of this recorded ambience; the quiet room still fades and
muffles the regional layer.

The 2016 archive's explicit recording credits and source links are the available
human provenance evidence. Freesound and SoundBible source pages could not all
be revisited from this environment. Their licensing is represented according to
the archived per-file notice, with that access limitation made explicit.
