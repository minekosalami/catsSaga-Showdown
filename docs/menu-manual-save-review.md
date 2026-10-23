# Menu, preferences and manual-save review

This change keeps the existing forest geography, encounters, attack scripts, soundtrack files and approved dialogue. Wonderland, Underground Cave and Incarna remain inactive. No original project files were removed. The shared battle-entry scripts, sounds, stage order and timings are unchanged.

## Interface and preferences

- Main menu: **Continue → New Game → Settings → Credits → Quit**. Continue loads the most recently used valid slot; it is disabled without one. A failed load reports failure and does not start a new game. The slot page also offers Load for each existing slot.
- Native Godot controls, anchored containers and the existing purple/pink battle shader provide the interface. Screen fades take 0.24 seconds. Credits retain **LLiosette — Creator** and the project's real source/license notices.
- Display: windowed, borderless fullscreen, and a distinct exclusive-fullscreen API choice on supported backends. Fullscreen uses the current monitor resolution; the resolution picker changes window size, rather than claiming to change monitor modes. Unsupported exclusive choices are hidden. Alt+Enter and the retained F11 shortcut go through a **12-second Keep/Revert trial**; closing Settings or timing out reverts. The previous window size and position are restored.
- Exploration zoom: **100%, 90%, 80%, 75%**. Lower values show more world without changing speed, coordinates, colliders, HUD scale, battle rendering or the frozen battle-entry camera. Battle viewports remain **540×900**; no extra render-resolution override was introduced.
- Master, Music and SFX sliders control actual buses immediately. Menu, Overworld and BossMusic feed Music; ambience and ordinary effects feed SFX. Existing track gains, samples, looping, pitch and soundtrack clocks remain intact.
- Preferences use `user://settings.cfg`; the existing visual/ambience preference files remain compatible and independent of saves. Display choices, volume, bindings, shake, reduced flashing, reduced battle effects and background motion persist. Restore Defaults and Restore Control Defaults require confirmation.
- Gameplay actions use InputMap with their existing keyboard defaults. Movement, attack/jump, interaction, SATURATE/Endure sprint, focus/exploration sprint, map and inventory are rebindable. Conflicting/reserved keys are rejected; attack and interaction may share their context-specific binding. Prompts reflect changed bindings. Menu arrows, Enter, Escape, Z/X and the minus developer shortcut remain available.
- Standard controller mappings: stick/D-pad move; A attack/jump/interact/confirm; B ability in gameplay and back in menus; LB focus; Y inventory; Back map; Start pause. B does **not** open pause during combat. Resume consumes menu confirmation/cancellation so it cannot carry into an attack or sprint.
- Pause: Resume, Settings, Controls, Return to Main Menu. Scene-tree processing and soundtrack playback pause together, including explicit ALWAYS combat children. Protected entry and other transitions cannot be paused. Returning with unsaved changes requires confirmation and does not save.

## Manual saves and compatibility

The previous implementation had one version-one JSON file, `user://save.json`. It validated location/position, Bart victory, story flags and fog, supported backup recovery, and automatically wrote progress on new game, area travel, victory and completed victory dialogue. The existing validator and its archived-area migrations are retained.

There are now **three independent slots**, `user://save-slot-1.json` through `save-slot-3.json`. They contain location/position, boss/progression flags, exploration and total playtime. An index remembers the last successfully loaded/saved slot. Missing legacy playtime safely defaults to zero. Existing movement/collider-based load-position recovery is retained.

On first migration, a valid single-save file (or its valid `.bak`) is copied into the first unoccupied slot. Its source remains untouched and an immutable `save.json.pre-slots.bak` is made first. If migration cannot proceed, the menu explains why; it never overwrites occupied slots or silently discards an unreadable old save. Successful migration is recorded. Original incompatible data remains available for manual recovery.

Only a deliberate **cat-statue → Save** confirmation writes current progress. Travel, boss victories and dialogue no longer save. The old `save_boss_victory()` API is retained as a no-op for existing hosts. Saving is rejected in combat, transitions, dialogue and away from a statue. Save writes validate a temporary file, preserve the previous valid `.bak`, and rename into place. A deliberately replaced unreadable primary is retained as `.invalid.bak`. Recovery from a valid backup is reported in-game.

Opening New Game or selecting an empty slot does not write progress. Replacing an occupied slot requires confirmation; its existing bytes remain until the new run's first deliberate statue save. Leaving that run without saving retains the previous disk save. This is explained on the slot screen.

Death's **Load Last Save** restores the active slot and discards unsaved victories/unlocks/fog. Before the first statue save in a new run, it restarts that fresh run at Forest Entrance instead of loading the overwritten slot's previous adventure. Victory Retry and explicit Sequence practice keep their existing encounter restart behavior. Returning from the final active boss still permits exploration.

### Cat statues

Reusable scene: `scenes/world/save_statue.tscn`; deterministic placements: `scripts/world/save_statue.gd`. Coordinates are local to each existing region (also global in the active overworld root).

| Region | Statue positions (Godot pixels) |
|---|---|
| Forest Entrance | (640, 912) |
| Deep Forest | (640, 768), (1440, 672), before BlankKitten |
| Evil Bart's Area | (1600, 864), before Evil Bart |
| Flooded Forest | (3008, 912), before Doppelcat |

All five have a small trunk collider, reuse the existing nearest-interactable system and stand on dry, approachable path space. Rendered checks prompted moving initially obscured placements out of foliage. No statue is instantiated in a battle arena.

## Assets and attribution

No artwork, font, audio, animation sheet or other creative asset was downloaded, generated, edited or replaced. QA screenshots are excluded from Godot import with `.gdignore`.

| Existing asset | Source / rights | Use |
|---|---|---|
| `assets/player/player.png.png` | Original user-supplied player artwork, reused in place | Static cat statue; original aspect/transparency preserved, runtime pixel/grayscale shader only |
| `assets/overhaul_human/ninja/rock.png` | Pixel-Boy, **Ninja Adventure**, CC0; [creator](https://pixel-boy.itch.io/ninja-adventure-asset-pack), [dated January 2022 distribution](https://github.com/clear-code-projects/Zelda/tree/5f4c57bfbb162d2f19b287a5c24816d93c17e08d) | Scaled statue pedestal; unchanged PNG |
| `assets/ui/fonts/DejaVuSansMono.ttf` | Bundled DejaVu / Bitstream Vera notices: `assets/ui/fonts/LICENSE.txt` | Existing coding typography |
| Existing battle shader and floor atlas | Technical shader plus already credited Pixel-Boy artwork | Subdued purple/pink menu background |

Existing detailed notices and hashes remain in `assets/overhaul_human/{LICENSE.md,provenance.json}` and `resources/ui/wonderland_asset_notices.tres`, and are accessible in Credits. No absolute provenance claim is made beyond the supplied artwork and documented existing sources.

## Verification

Godot **4.6.3**, headless and X11/llvmpipe with the Compatibility renderer. Tests use isolated user-data directories, not the player's real save directory. New mutating test scripts require `CATSSAGA_TEST_PROFILE=1` as an explicit guard.

Example:

```sh
CATSSAGA_TEST_PROFILE=1 \
XDG_CACHE_HOME=/tmp/catsSaga-menu-test/cache \
XDG_DATA_HOME=/tmp/catsSaga-menu-test/data \
XDG_CONFIG_HOME=/tmp/catsSaga-menu-test/config \
godot --headless --path . --audio-driver Dummy --script tests/headless_menu_overhaul.gd
```

Use a fresh isolated directory for the initial integration suite. `menu_save_restart.gd` then uses that same fixture directory in a second process. The display/restart probes similarly share their isolated preference directory. Never point fixture-writing tests at a real player profile.

| Verification | Result |
|---|---|
| Godot headless editor import | Passed, no script/shader import errors |
| New menu/manual-save integration, actual X11 render | **59 checks, 0 failures**; mouse clicks, arrows/D-pad/A, navigation, sliders, saves, death recovery |
| Save persistence/recovery in a second process | **14 checks, 0 failures**; all slots, real Continue/Load actions, corrupt primary, backup recovery, fresh-run death, cancelled overwrite/return |
| Native display modes and rollback | **9 checks, 0 failures** at 1280×720 and 960×540; rollback test shortens the countdown while retaining its real production path |
| Preference process restart | Passed; window size, zoom, audio, binding, shake, reduced effects and motion restored |
| Fullscreen process restart | Passed with actual backend fullscreen mode; fixed startup root-window mode synchronization found by this test |
| Restore Defaults UI | Passed; Cancel preserves preferences; confirmation resets defaults and separately confirms display, with no save-slot writes |
| Combat/menu regression | **39 checks, 0 failures**; all three active bosses pause clocks/player/projectiles/audio, resume synchronized; CATA/BEAM, rebound attack, controller ability, Bart 300 HP, Endure sprint/no SATURATE, no victory autosave |
| Evil Bart existing suite | **47 checks, 0 failures** |
| Doppelcat existing suite | **46 checks, 0 failures**; death Retry updated to manual-save contract, then fresh encounter reset verified |
| Sequence existing suite | **102 checks, 0 failures** |
| Forest journey suite | **220 checks, 0 failures**; save test now deliberately uses a statue |
| Protected battle entry | **3,088 frame-dependent checks, 0 failures**; exact original stage order/freezes/music reveal |
| Music levels / music and hitboxes | **38 / 37 checks, 0 failures** |
| Original content preservation | **2,769 checks**; all **1,723** starting tracked files retained, original assets/data/maps and protected mechanics unchanged |
| Real Quit button | Exits with status 0 |

Rendered screens were inspected and corrected, including all five statue placements, menus, credits, controls, fullscreen confirmation, default confirmation, pause/death and smaller-window Settings. [Sixteen actual screenshots](review/menu-overhaul/) are provided for review:

- [Main menu](review/menu-overhaul/01-main-menu.png), [slots](review/menu-overhaul/03-save-slots.png), [credits](review/menu-overhaul/02-credits.png)
- [Display](review/menu-overhaul/04-settings-display.png), [controls](review/menu-overhaul/05-settings-controls.png), [fullscreen confirmation](review/menu-overhaul/11-fullscreen-confirmation.png), [960×540](review/menu-overhaul/12-small-settings.png)
- [Pause](review/menu-overhaul/08-pause.png), [death](review/menu-overhaul/09-death.png), [statue before Evil Bart](review/menu-overhaul/statue-bart_area-1.png)

The review branch is `feature/menu-manual-save-overhaul`. GitHub API access is unavailable in this environment, so a PR cannot be opened through the API; the branch can be reviewed through GitHub's compare/PR form.

## Limits

The environment provides software rendering and a Dummy audio driver. Actual rendered screens, playback positions, buses and synthesized controller events can be inspected; hardware listening, physical controller devices, target-GPU performance, multiple-monitor/DPI configurations and Windows/macOS/Wayland behavior still need manual checks. Full songs were not replayed as human difficulty tests in this menu task. Existing ObjectDB/resource/RID shutdown warnings remain in some test processes; they are not a clean teardown result. No platform export was configured or performed.
