# Alive UI presentation overhaul

Branch: `feature/alive-ui-presentation`. This changes presentation, not game rules.

## Interfaces and motion

- Shared navy/mint/coral/gold/lilac system: layered surfaces, corner accents, inset tracks, depth/shadows, explicit hierarchy, themed tabs/sliders/scrollbars, animated focus/press affordances and restrained ambient motion. Existing DejaVu fonts are reused, including the existing serif face for the main-menu title.
- Showdown retains its original three columns and unchanged 540×900 simulation/fit. ITEMS now has three differentiated cards with functional geometric emblems, quantities, descriptions, a moving selection cursor, disabled states, quantity pops and success/failure feedback. Alt still redirects controls without pausing combat.
- STATUS has labeled HP/EXP meters, a delayed damage fill, low-HP color, actual LV/EXP including MAX, prominent exact live score, shield duration, encounter context where space permits, and a large bottom-anchored live grade. Grade changes use different improvement/drop motion. The primary streak timer is removed; scoring itself is untouched. Original boss clocks, phases and stamina remain visible.
- Ordinary arena header has named enemy HP, exact numerical HP, a smoothly rendered secondary damage fill, SATURATE state and the existing playback-based countdown. FIGHT/FLEE use the shared interactive styling. Enemy hit/defeat feedback affects artwork only. Existing player hit feedback remains; added healing/shield arcs are faint, outside the damage center, and have no collision shape.
- Graded results now dim/fade into a composed portrait, score count-up, large rank impact with bounce/rays/particles, staggered rewards, PB/level-up details and continuation. The normal sequence is about two seconds. Its first confirm skips the reveal; the next continues. Skip cancels the remaining presentation and never re-applies rewards. Continue logic and the original victory transaction are preserved.
- Existing battle-entry animation remains intact. Failed FLEE pulses its existing message; departure captions accompany the existing fade for successful FLEE, defeat/checkpoint return and completed battles, without changing transition durations or outcomes.
- Main menu has an animated player portrait, custom title composition, ambient shader/rings/motes, and a framed navigation surface. All six existing options remain.
- Records uses unchanged saved PBs in portrait rows with large colored grades, unbeaten states, keyboard-focus highlighting and automatic scroll-to-focus. Future registered records still appear.
- PAWn Shop retains the keeper, wand, dialogue graph and theft animation. It adds a clear balance, item effect descriptions, colored choice cards, purchase toast and balance/particle feedback. Complete choices fit above the screen edge; the wand and balance no longer overlap. Prices/effects are read from the existing item definitions.
- Dialogue/choices, inventory/map overlays, save confirmations, pause/settings and overworld region/currency HUD share the new theme. Named notification Labels retain their original text/API and use readable compact toast surfaces. No NPC dialogue or quests were added.

## Four ordinary-encounter backgrounds

`region_background.gd` selects the active encounter's stored area (falling back to Session area). A reusable profile table supports future regions without adding any new world content.

| Region | Presentation |
|---|---|
| Forest Entrance | Dim green grass, existing foliage, slow light shafts and pollen |
| Deep Forest | Cooler enclosed foliage, mist and drifting faint details |
| Fluffy Forest | Pastel tint, soft leaf/petal accents and slow highlights |
| Flooded Forest | Dark existing water tile, gentle waves, mist and subtle tree reflections |

Trees sit at the edges; terrain and particles remain low contrast beneath enemy shots. Bosses keep their existing cinematic backgrounds and receive the shared side panels/meters/results. No map geography is recreated or modified.

## Asset handling

No external downloads, new creative assets, replacement character art, font generation, audio synthesis or soundtrack edits. See [asset credits and source/license evidence](alive-ui-asset-credits.md). Existing human-created images/fonts are sampled directly; new geometry and shaders are runtime Godot presentation effects. Existing license notices and in-game credits remain.

The before/after audit verified **808 protected original source/asset/dialogue files unchanged**. In addition, the original ordinary victory/FLEE/deadline functions, RPG reward transaction, control-mode routing, save/load/snapshot/checkpoint code remain unchanged. Shop purchase still calls the existing transaction once, with new UI feedback around its result.

## Verification

- Headless Godot import and diff whitespace checks.
- Presentation suite: **149 checks**, including four automatic backgrounds, center fit, panel/grade bounds, all live grade thresholds, exact/nonperfect score formatting, MAX EXP state, cursor size, empty inventory, active combat during item navigation, accurate meter values/ghost fill, live/final grade agreement, skip, single rewards and return, keyboard Records browsing and actual shop button signals.
- Existing foundation/integration, ordinary/FLEE/SATURATE/deadline, AI, quest/story/shop, Doppelcat/cross/Sequence, save-star, menu/slots/settings, physical region transition, music/hitbox, entry and camera suites passed.
- **2,361 projectile checks** passed across all eight enemies, including 576 actual weapon collisions through movement, damage, HP bars, victory, reward and return.
- **84 standalone fullscreen checks** passed on the native virtual monitor, including scaling, repeated switches and synchronized resume. Separate-process progression/record reload passed.
- Real standalone 1280×720 frames were rendered with X11/Mesa llvmpipe/dummy audio and inspected. The visual pass corrected a stretched selection overlay, a toast background covering text, the shop balance overlapping the wand, and an atlas region that exposed shoreline fragments. These are fixed in the delivered code.
- Seventeen PNGs in [the review folder](review/alive-ui/) show the menu, inventory, ordinary battles, each regional background, live A rank, S+ results, all three active bosses, Records, shop, overworld HUD, collectible toast and pause. These are actual game renders, not generated artwork.

No final assertion failures or runtime script errors remain in the focused checks. Some test shutdowns still emit ObjectDB/resource/RID cleanup warnings. Human-paced full fights, audible mix, other graphics backends/platforms and target-hardware performance still require manual playtesting. No newly sourced UI audio was added; existing music/voices remain.

## Changed files

Implementation and test file list follows; generated Godot UID metadata accompanies new scripts/shaders.

- `docs/alive-ui-asset-credits.md`
- `scripts/encounters/battle.gd`
- `scripts/encounters/hud.gd`
- `scripts/main_menu.gd`
- `scripts/maps/map_ui.gd`
- `scripts/rpg/battle_ui.gd`
- `scripts/story/shop_screen.gd`
- `scripts/systems/combat_host.gd`
- `scripts/systems/session.gd`
- `scripts/ui/battle_hud_style.gd`
- `scripts/ui/game_hud.gd`
- `scripts/ui/menu/background.gd`
- `scripts/ui/menu/theme.gd`
- `scripts/ui/pause_menu.gd`
- `scripts/ui/presentation/ambient.gd`
- `scripts/ui/presentation/button.gd`
- `scripts/ui/presentation/departure.gd`
- `scripts/ui/presentation/item_card.gd`
- `scripts/ui/presentation/menu_hero.gd`
- `scripts/ui/presentation/meter.gd`
- `scripts/ui/presentation/player_effect.gd`
- `scripts/ui/presentation/portraits.gd`
- `scripts/ui/presentation/region_background.gd`
- `scripts/ui/presentation/results.gd`
- `scripts/ui/presentation/style.gd`
- `scripts/ui/presentation/surface.gd`
- `scripts/ui/presentation/toast.gd`
- `scripts/ui/sketch_button.gd`
- `scripts/ui/sketch_theme.gd`
- `scripts/world/dialogue.gd`
- `scripts/world/overworld.gd`
- `shaders/showdown_environment.gdshader`
- `shaders/ui_aurora.gdshader`
- `tests/headless_alive_ui.gd`
- `tests/headless_rpg_battles.gd`
- `tests/headless_menu_overhaul.gd`
- `tests/render_alive_ui.gd`
