# Showdown RPG and scoring review

Branch: `feature/showdown-rpg-scoring`.

## Implemented behavior

- LV1 starts with 20 HP; LV20 caps at 100 HP. HP, cumulative EXP thresholds and fractional shooting damage use the requested formulas. EXP caps at 9,500. Damage multiplier ranges from 1.0 to 1.95. Enemy HP, movement, firing cadence and music cues do not scale with level.
- Victory EXP: ordinary 25, Smoki 100, BlankKitten 150, Doppelcat 200. A persisted boss-reward ledger prevents repeat boss EXP in a playthrough. Ordinary enemies can earn rewards again as new encounters on later region visits. Rewards and level-ups occur after victory; level-ups fully heal. Ordinary NeCoins remain 10; no new boss coin rewards were added.
- Ordinary projectiles deal 3 HP. Existing three-hit boss damage becomes 7 HP per former damage point; Sequence's former five-hit balance becomes 4 HP per hit. Existing invulnerability windows remain, including ordinary 1.5s. Shared player bullet damage stays fractional through enemy health and HP bars. The corrected ordinary collision layer remains 1.
- PAWn Shop sells First Aid Kit (50), Cat Treats (20), Shield Ring (30). Wand price, acquisition guard, jokes and distraction/theft logic remain. Five shop choices fit the existing dialogue UI, with the original portraits and wand above them.
- Every combat host has ITEMS / original arena / STATUS columns. Alt toggles item controls without pausing. Directions select, existing confirm uses one item. Healing cannot be wasted at full HP; shields block damage for five active seconds and refresh rather than stack. Existing boss clocks/stamina controls are reused in STATUS. Alt+Enter keeps its fullscreen function.
- Scores integrate squared no-damage streaks over active encounter time. Actual HP damage alone breaks a streak. Perfect wins are explicitly 100% S+; nonperfect display cannot round to 100%. Thresholds, items and EXP rewards are configurable in `scripts/rpg/`.
- Graded results show enemy, percent, grade slam/bounce/shake/particles, rewards, level-ups and new PB. Continue returns ordinary and Sequence wins to their existing forest destination; other boss result navigation remains available behind the grading screen. Defeat/FLEE never grade or improve records. Practice/development Sequence runs never reward or record.
- Main-menu Records lists all eleven requested entries, with independent unrounded PBs and placeholders. Records are profile-wide; RPG/inventory/story progress are slot-specific.

## Persistence and compatibility

Manual save-star interaction and checkpoint placement remain. Automatic **earned progress** uses validated, atomic `user://progress-slot-N.json` journals (temporary file, verification, backup, rename), while original manual `save-slot-N.json` files remain. Continue/manual reload prefers the latest progress journal, preserving checkpoint coordinates and earned quests, feathers, currency, items, boss flags and EXP. Death restores the last activated checkpoint without loading an older inventory. New fights start at derived maximum HP. Old saves receive LV1 / zero EXP / empty consumables; already-cleared legacy bosses cannot be farmed for first-clear EXP.

`user://showdown-records.json` is independent of checkpoint reloads and new games. Record JSON uses full float precision, validation and atomic replacement. Opening an unloaded main menu cannot write default progression over an existing slot. Important updates, application close and explicit menu quit flush earned progress.

## Validation

Final focused checks passed:

| Suite | Checks |
|---|---:|
| RPG formulas, items, scoring, PB persistence, legacy validation | 103 |
| Actual ordinary/boss integration, items, controls, victory/FLEE/death, shop | 53 |
| All eight moving targets, 576 real weapon hits, HP, victory/reward/return | 2,361 |
| Existing ordinary encounters / FLEE / SATURATE / deadline / weather | 148 |
| Forest AI | 18 |
| Story data / quest validation | 67 |
| Story interactions / wand / feathers / transitions | 81 |
| Doppelcat combat/sprint/hazards | 45 |
| Cross lasers | 44 |
| Sequence mechanics/practice | 102 |
| Save stars | 15 |
| Main menu, slots and settings | 56 |
| Physical region transitions / map | 17 |
| Music and player hitboxes | 37 |
| Protected battle-entry transitions | 3,037 |
| Camera stability | 9 |
| Standalone fullscreen switching and scaling | 84 |

A separate Godot process restored the integration profile's EXP, inventory, quests, feathers, boss flags and four separate PBs. Headless editor import and `git diff --check` passed. Existing tests were updated where the requested HP, results step, Records menu and non-rollback deaths superseded their old assertions. Historical archived-region harnesses were not used to re-enable excluded content.

Eight real standalone 1280×720 renders are in `docs/review/showdown-rpg/`: ordinary battle/items, S+ result, Smoki, Doppelcat, Sequence, Records, shop. These use X11 / Mesa llvmpipe / dummy audio. UI renders were inspected, including complete shop choices and preserved boss clock/stamina controls. Native virtual-monitor fullscreen tests passed at 1920×1200.

No final assertion or runtime script failures remain in these checks. Several harnesses still print ObjectDB/resource/RID cleanup warnings on shutdown. Human-paced full fights, audible mixing, difficulty across levels and performance on target hardware still need manual playtesting; timeline and endpoint tests are not claims of full soundtrack survival runs.

## Assets and scope

No creative assets were generated, downloaded or altered. Original images, audio, fonts, map scenes, dialogue JSON, attack pattern/timeline code and artwork remain unchanged. New effects are Godot UI/tweens/built-in particles. Review screenshots are under the already ignored `docs/` directory, outside game exports. The pre-existing world-map preview was left untouched.

## Changed implementation and test files

- `scenes/bullet.gd`
- `scenes/player.gd`
- `scripts/blankkitten/combat_host.gd`
- `scripts/blankkitten/hud.gd`
- `scripts/blankkitten/star.gd`
- `scripts/boss.gd`
- `scripts/boss2/combat_host.gd`
- `scripts/boss2/hud.gd`
- `scripts/boss2/player.gd`
- `scripts/encounters/battle.gd`
- `scripts/encounters/enemy.gd`
- `scripts/encounters/hud.gd`
- `scripts/encounters/player.gd`
- `scripts/encounters/service.gd`
- `scripts/enemy.gd`
- `scripts/incarna/combat_host.gd`
- `scripts/incarna/hud.gd`
- `scripts/main_menu.gd`
- `scripts/rpg/battle_ui.gd`
- `scripts/rpg/progress.gd`
- `scripts/rpg/records.gd`
- `scripts/rpg/score.gd`
- `scripts/story/shop_screen.gd`
- `scripts/systems/combat_host.gd`
- `scripts/systems/save_manager.gd`
- `scripts/systems/session.gd`
- `scripts/ui/cinematic_arena.gd`
- `scripts/ui/game_hud.gd`
- `scripts/world/dialogue.gd`
- `scripts/world/overworld.gd`
- `tests/headless_battle_entry.gd`
- `tests/headless_boss2_overhaul.gd`
- `tests/headless_cross_lasers.gd`
- `tests/headless_forest_encounters.gd`
- `tests/headless_journey_transitions.gd`
- `tests/headless_menu_overhaul.gd`
- `tests/headless_music_hitbox.gd`
- `tests/headless_ordinary_projectile_hits.gd`
- `tests/headless_rpg.gd`
- `tests/headless_rpg_battles.gd`
- `tests/headless_sequence_overhaul.gd`
- `tests/headless_story_integration.gd`
- `tests/reload_rpg_progress.gd`
- `tests/render_showdown_rpg.gd`

Godot-generated `.gd.uid` metadata accompanies new scripts/tests.
