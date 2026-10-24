# Forest atmosphere and ordinary Showdown encounters

Branch `feature/forest-encounters`, based on `f1c28a6`. Extends the merged story update; all original map scenes, paths, ponds, bridges, collision shapes, NPC placements, dialogue JSON, boss scripts/music and 1,408 existing asset files are unchanged.

## Gameplay

Eight enemies, in the supplied sheet's reading order: **Purrrresents!**, **FireKittens**, **TopCat**, **Sharpurr**, **BiNarty**, **Toasters**, **2kMEOWpH**, **Sir Swirlur**. Every type is equally eligible in every region; no region multipliers.

- Shared collision-based AStar navigation is built incrementally (384 cells/frame) and cached for subsequent returns. Wandering, line-of-sight pursuit, last-seen search for 3–5 seconds, 720px pursuit leash and physical retreat use ordinary movement/collisions. Distant actors suspend work.
- Up to four actors are active nearby. Each explored 1,024px pocket has four unique visit IDs. Defeated IDs stay dead throughout that region visit; new pockets can contain other enemies. Distant living actors are suspended at their actual positions. Crossing into another region starts a new visit/population. Loading a manual save starts a new visit; ordinary population is not durable story progress.
- New spawns are offscreen, on the validated navigation grid, reachable, and outside 170px safe areas around NPCs, shops, stars, region portals and spawn. An exhausted pocket may be quiet. This target is not a guarantee of 2–4 visible actors at every location.
- Existing Showdown player, shooting, movement, focus speed, 3 HP, 7.5px hitbox, hit effects, CATA, BEAM, SATURATE and portrait host/transition are reused. Ordinary-only subclass extends post-hit invulnerability to 1.5 seconds; bosses retain 1 second and their own existing settings.
- Enemy HP is 72 for every type. Projectiles deal 1 HP, with 10–12 shots per volley, fixed 0.9–1.3s randomized intervals and bounded per-family speeds. Eight themed patterns use permitted Godot geometry. No song-based density/speed/damage escalation. A 128-projectile cap bounds allocation; existing projectile removal/SATURATE semantics remain intact.
- The official name appears above a boss-style HP bar. FIGHT uses existing shooting; FLEE is a mouse button or V. There is no SPARE or extra introduction/dialogue. Each available FLEE attempt uses one success out of two uniformly sampled integers, exactly 50%. Failed attempts have a 1s retry cooldown and keep combat running.
- **Forest Capillaries** restarts from zero, does not loop, and uses actual playback position/finished notification. Measured file duration is **70.81795s**; runtime reads the stream duration. Killing the enemy before that deadline wins immediately. Zero HP or audio deadline loses. A same-frame endpoint race resolves as defeat. Pausing stops the audio clock.
- Victory grants exactly 10 NeCoins once. FLEE gives none, leaves the enemy alive, physically retreats it, and grants that enemy 10 seconds of ignore time. All returns give 3 seconds of global encounter protection; menus/dialogue/pause do not consume those active-exploration cooldowns.
- Ordinary defeat returns to the most recently activated star checkpoint (original spawn before any activation), restoring a fresh player's battle HP next fight. It does **not** load an old inventory snapshot. Currency, quest, feather/toy, boss flags and fog remain in memory, including earnings after the last manual save. Manual saving still determines what persists across quitting/loading. Boss death/retry behavior is unchanged.
- Checkpoint position is a separately validated optional field in version-one manual saves. Older saves default to their saved location. Ordinary kill IDs/cooldowns are visit state, never story flags or inventory.

Balancing is centralized in `scripts/encounters/catalog.gd`. At the existing 1 damage / 0.15s fire interval, 72 HP is 10.8 seconds of perfect stationary hit throughput, plus projectile travel and aiming. SATURATE still deals 30. Dodging/moving targets lower real accuracy. This is initial calibration, **not evidence that ordinary fights are harder than Smoki**: relative difficulty, comparable difficulty across all eight, and fairness still require human playtesting.

## Environment

The existing forest atmosphere/ambience system now adds distinct warm entrance, shadowed pond forest, soft purple Fluffy Forest and cool flooded palettes, gentle canopy/understory wind, existing human leaf frames, procedural wing/pollen/insect geometry, sunbeams, shop warmth and low mist. Geometry/navigation is unchanged.

A shared weather controller transitions among clear, overcast, light rain and heavy rain. Cloud/light/wind/rain blend over roughly 6 seconds (smooth asymptotic interpolation); new weather is selected after 75–140 active exploration seconds, following an initial clear period. Weather affects lighting, foliage, water ripples/currents, restrained screen-limited rain and recorded ambience. Water vs bridge/ground impacts differ. Recorded wooden creaks are localized to moving across bridges; pond proximity controls existing water ambience. Particle/stroke budgets are bounded (160 rain strokes, halved with reduced visuals; 42 ambient motes). No weather overlay runs inside combat, and rain audio fades out for battles/menus.

No new creative artwork, generated audio or fonts. Procedural geometry/shaders are code effects explicitly allowed by the request.

## Asset provenance

- Original `assets/npc textures/ENCOUNTERS-SHEET.png` and `assets/soundtrack/Forest Capillaries - 007.mp3` are user-provided and unchanged.
- `tools/extract_encounter_sprites.py` losslessly crops eight occupied cells, excludes blue dividers/empty ninth cell, and removes only exact black connected to the cell perimeter. Retained RGB and nonblack alpha values are unchanged, including near-black BiNarty lines. Enclosed black is retained. No threshold/repaint/upscale. `resources/encounters/sprite-provenance.json` records source/crop hashes and coordinates; `tests/check_encounter_sprites.py` verifies this. Pure black indistinguishable from connected background cannot be reconstructed; no missing detail was guessed. BiNarty uses a contrasting runtime backing rather than recoloring its artwork.
- Light rain: **Arctura**, [original recording](https://freesound.org/people/Arctura/sounds/34065/), **CC BY 3.0**.
- Heavy rain: **Q.K.**, [mymonths source collection](https://github.com/minetest-mods/mymonths/tree/master/sounds), **CC0**.
- Both rain recordings were obtained from [t-affeldt/regional_weather](https://github.com/t-affeldt/regional_weather). Bytes match historical revision `32ab2c4d23120e32101bc852aca373a1533cd67b`, April 22, 2020. Named recording credits/licenses and historical bytes support human provenance; no absolute forensic claim is made.
- Bridge creak: existing wooden opening recording by **CGEffex, modified by BlockMen**, **CC BY 3.0**, from [Minetest Game doors](https://github.com/luanti-org/minetest_game/tree/master/mods/doors), renamed from `doors_door_open.ogg`. Encoded recording unchanged, played quietly/spatially. Exact source revision/hash and original media-credit notice retained.
- Exact source archives, hashes, original notices and license URLs: `assets/weather_human/`. Credits are also bundled in `resources/ui/weather_asset_notices.tres` and displayed in the existing main-menu Credits page. No mod code/textures were imported.
- Existing human leaves, wind, insects/birds/water and fonts retain the project's existing credits and licenses. Added runtime art/audio storage is approximately 2.8 MiB, plus import metadata; review captures stay under ignored `docs/`.

## Verification

Godot 4.6.3, isolated profiles:

| Check | Result |
| --- | --- |
| Headless import | Passed, no final script/import errors |
| Ordinary battle, eight patterns, HP, iframe, SATURATE, music/pause/deadline, FLEE, rewards, checkpoint compatibility, all maps/weather | 148 checks passed |
| Real collision movement, chase/LOS/search/leash/retreat, spawn bounds, defeated slots, body-contact transition | 18 checks passed |
| Previous full story integration | 81 checks passed |
| Existing music/shooting/hitbox/SATURATE regression | 37 checks passed |
| Existing Doppelcat overhaul | 46 checks passed |
| Story progress/legacy save validation | 67 checks passed |
| Manual save-star/failure/Continue flow | 15 checks passed |
| Actual standalone window/fullscreen scaling | 84 checks passed |
| Original assets and sprite extraction | Original 1,408 files unchanged; exact retained pixels verified |

Sixteen actual standalone Godot/X11 captures (clear/rain in four regions and all eight ordinary enemies) are in `docs/review/forest-encounters/`. Captures were inspected; the render script supports isolated `--enemy-kind=0` through `7` runs. Software-renderer capture/viewer caching required fresh isolated captures during review; final image files contain full player/HUD/arena. Images are game renders, not generated artwork.

Manual testing remains: audible mixing (environment uses dummy audio), sustained performance on target hardware (rendering here is Mesa llvmpipe on a virtual X11 monitor), long human-paced exploration, and fight difficulty/fairness. Deadline tests seek near the real endpoint rather than claiming an entire real-time survival playthrough. Existing ObjectDB/resources-in-use warnings remain at some test shutdowns; no final runtime script errors.
