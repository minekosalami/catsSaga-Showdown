# Flooded Forest and Boss2 survival encounter

## Scope and confirmed choices

A new, separate encounter extends the existing world without replacing Evil Bart. It uses `assets/enironment/bosses/bosstwo.png` for both NPC and battle, as confirmed by the user (there is no `boss2.png` in the repository). The original image is referenced directly with uniform scales and nearest filtering; no duplicate or altered artwork is included.

The only newly supplied soundtrack is `assets/soundtrack/SyNaPse - 003.mp3`. Its measured duration is 150.26 seconds. The user chose to **end gameplay at 140.80 seconds and fade the remaining audio**. The original file is unchanged; its unused tail fades over 0.8 seconds when the encounter ends.

The user's final instruction disables SATURATE in this survival fight. Both normal shooting and SATURATE are overridden only by `scripts/boss2/player.gd`. BEAM cannot bypass this encounter-specific override. The original player script and SATURATE implementation remain available to Bart and future attack-based encounters.

## Flooded Forest

`scenes/world/flooded_forest.tscn` is an editable 2048×1536 map presented through the existing 1280×720 overworld shell, player, camera, interaction indicator, and pause UI. It contains winding routes, optional branches, irregular pools, peninsulas, a small enclosed pool, open areas and a boss clearing. Existing grass/soil tiles and 86 existing tree instances use deterministic sizing, scaled trunk collision, and Y-sorting. Muted node tints distinguish the flooded area without editing source images.

`PlaceholderWater` is a separate TileMapLayer using `resources/world/placeholder_water.tres`: a deliberately simple 16×16 blue GradientTexture2D atlas tile with a matching solid collision polygon. There are 3,272 water cells. This is temporary terrain, not final water artwork. The entry and entire intended trail to the boss were checked with the actual player collision shape; a real movement check verifies the player stops at the shoreline. The return portal detects the existing player collision layer and leads back to Deep Forest's new `FromFlooded` marker.

### Editing water and terrain

Open the flooded scene in Godot and select `PlaceholderWater`. Use the TileMap painting tools to paint/erase source 0, atlas cell (0,0). Water cells inherit collision; the grass and trail layers remain non-solid.

To replace temporary water, open `resources/world/placeholder_water.tres`, select its atlas source, and replace the GradientTexture2D with your own future texture. Keep a 16×16 atlas region and a tile at (0,0) to preserve the existing map cells, or update cells to your new atlas coordinates. Retain the physics polygon for solid water tiles. Changing this shared resource updates the map. Paint grass, trails and decorative details on separate non-solid layers; existing `forest_grass.tres` can be reused for another details layer. Tree `size_override` remains adjustable per instance in the Inspector.

## Key and save progression

Deep Forest gains a Z-interaction gate in its existing side clearing at (1750,1090), preserving its NPC, paths, trees and original exits. Without a key it displays exactly: “The entrance is locked. A special key is required.” With the key, it sets `flooded_forest_unlocked` and travels to the new scene. The key is never consumed.

Bart's existing victory handler now calls a guarded, idempotent key reward immediately before its existing save. A brief notification displays “Obtained: Flooded Forest Key”. Defeat grants no reward. His existing victory and post-battle dialogue remain unchanged.

The existing version-one schema, backup recovery, atomic save writes and original `evil_bart_defeated` field remain. New boolean story flags are `bart_defeated`, `flooded_forest_key_obtained`, `flooded_forest_unlocked`, and `boss2_defeated`. Validation preserves unrelated flags, mirrors Bart completion, grants the key to older Bart victories, and defaults new gate/Boss2 completion flags to false. It also accepts a legacy root `bart_defeated` alias. Migration is applied on reads and persisted by the next normal save. Snapshot normalization prevents migration defaults from appearing as unsaved changes.

Only Boss2's host records `boss2_defeated`; its victory save uses the actual Flooded Forest return point. Death does not record completion. Victory offers Return to Flooded Forest, Retry and Main Menu; defeat offers Retry and Main Menu. Returning restores the overworld position without adding story dialogue. A completed Boss2 NPC does not restart the encounter. Retry restarts player health and audio from zero.

## Separate survival battle

`scenes/boss2/combat_host.tscn` reuses the existing host layout and 540×900 SubViewport, with a new battle scene and host subclass. `scripts/boss2/battle.gd` owns player initialization, audio clock, background presentation and victory/defeat. `timeline.gd` owns this boss's phases, patterns, formation and laser positions. `laser.gd` owns procedural beams and damage checks. The projectile scene reuses the existing circular bullet utility and its precise collider, with its own ownership group for cleanup. The HUD uses the existing theme and button component, with player health and remaining survival time; there is no boss health bar or boss damage interface.

Movement, focus, actual 7-pixel hitbox marker, health, invulnerability and CATA inherit the original battle player. Normal offense is disabled by the survival subclass. Bart's boss controller, 300 HP, attacks, music synchronization, shooting, SATURATE damage and visuals are unchanged.

### Authoritative clock and exact timeline

The clock is `AudioStreamPlayer.get_playback_position()` plus time since the last audio mix, minus output latency, clamped monotonically. Phase math and easing use song time, not accumulated frame timers. The entry wipe initializes safely before playback starts at zero. Pausing also pauses the music. Automatic dialogue is a plain presentation label; Z and mouse input cannot advance it or freeze movement.

| Song time | Event |
| --- | --- |
| 0.00 | Boss appears; configurable, clearly marked introduction placeholder; no bullets |
| 12.80 | Introduction disappears; opening circular rings, symmetric rotating pairs/spirals and aimed spreads |
| 38.40 | Laser assault; warning window then paired blue lasers and stronger circular patterns |
| 64.00 | Safe intermission: bullets cleared, lasers disabled; exact supplied dialogue |
| 70.00 | Intermission dialogue hides, before the next attack |
| 70.40 | Convergence warning; centered stationary boss, denser bullets |
| 89.60 | Lasers disabled and hostile convergence bullets cleared; lighter circular finale continues |
| 140.80 | Clear hazards; alive player wins, save Boss2 completion, fade remaining soundtrack |

Intermission uses exactly: “You're stronger than you look. But how long can you survive?” No new story lines were invented. The overworld NPC introduction and automatic battle introduction are labeled placeholders exported in their respective Inspectors.

Opening patterns grow gradually; finale resets to lighter opening density. Ring helpers reserve a downward gap, symmetric rotating pairs create spirals, and aimed spreads stay narrower during convergence. A 240-projectile budget bounds active bullets. This does not establish that every overlapping formation is practically dodgeable; manual difficulty review remains required.

## Blue lasers

Each beam has a solid 20-pixel blue dangerous body, a pale center, faint outer glow and slow energy streaks. Its RectangleShape2D matches that body, from y=270 to y=900; the boss sprite sits above the protected upper boundary. Warning zones are translucent red and non-damaging.

During assault, a smoothly eased center moves the boss and both lasers together with fixed ±185-pixel horizontal offsets. Each activation starts with a 1.2-second warning covering the swept region. During convergence, only the beams close inward; the boss stays at x=270. After the warning, easing takes ten seconds, then stops at clamped limits until finale. The default gap is derived from **two original player sprite widths**, approximately 193.3 internal pixels, between solid inner beam edges. The default stopped beam centers are approximately x=163.4 and x=376.6.

A physics shape query checks actual player overlap each tick, including persistent contact and moving beams. It calls the inherited damage handler, which retains one-second invulnerability; warnings never call damage. Neither background distortion nor brief scenery shake moves actors or collision coordinates.

### Inspector configuration

On `Boss2Battle/Boss2Timeline`: warning duration, activation duration, coordinated movement duration, convergence duration, easing power, beam width, side offset, coordinated travel, maximum inward travel, and `final_center_gap` (0 derives two sprite widths; positive overrides it). On `Boss2Battle`: introductory dialogue and background `effect_intensity` (0 disables distortion). On the map NPC: its introductory placeholder. Phase boundaries are centralized in `BOUNDARIES`; the approved ending is 140.80 seconds. Keep these ending values aligned when intentionally changing the design.

## Validation

Godot 4.6.3 headless editor import passed. **737 automated checks passed**: 651 existing regression checks (including two added actual Bart key/defeat assertions), 72 focused Boss2 checks, 11 new graphical captures, and 3 full-duration checks. Two prior assertions were updated for the intended new gate and boolean save defaults; their original behaviors remain tested.

The full uninterrupted dummy-audio run observed phases at 0.00, 12.808, 38.412, 64.011, 70.404, 89.610, and 140.812 seconds. Victory occurred within one physics frame of 140.80. Its peak was 73 projectiles, below the 240 budget. Explicit test invincibility was enabled for this run to observe every phase, not to demonstrate dodge difficulty or manual gameplay skill.

Focused checks cover legacy migration, exact locked message, actual gate and return portal, water collision/movement, the entire intended route, shared texture, save/load, NPC-to-battle dialogue routing, disabled shooting/SATURATE even with BEAM, focus movement and marker, pause/audio synchronization, exact phase boundaries, safe intermission, warning-only contact, active beam damage/i-frames, centered convergence and fixed stopping gap, protected boss space, projectile cap, rejection of early victory, audio-clock ending, fade, victory persistence, post-battle return, first-run defeat without completion, Retry, and Main Menu.

Existing regressions cover Bart's 300 HP, shooting, SATURATE/BEAM/CATA, phases, music, victory and dialogue; menu/controls; forest/tree/collision systems; saved progression; and actual graphical UI navigation. Rendered tests used Xvfb, software Mesa and dummy audio. The environment reports unsupported VSync adjustment; no script or shader errors remain. Rendering and headless timing do not establish audible synchronization or sustained target-hardware frame rate.

### Commands

Use isolated XDG data/config/cache directories to avoid touching your normal save.

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/headless_boss2.gd
godot --headless --path . --script res://tests/full_boss2_survival.gd
# Requires a display; writes eleven review images.
godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --script res://tests/render_boss2.gd -- --output=/tmp/boss2-review
```

### Screenshots

- [Flooded Forest overview](review/boss2/flooded-forest-overview.png)
- [Boss clearing](review/boss2/boss2-clearing.png)
- [Red warning zones](review/boss2/laser-warning.png)
- [Coordinated laser assault](review/boss2/laser-assault.png)
- [Stopped convergence](review/boss2/convergence-stopped.png)
- [Automatic intermission](review/boss2/intermission.png)
- [Survival victory](review/boss2/survival-victory.png)

### Remaining placeholders and manual checks

Replace the temporary water atlas texture and both clearly labeled introductory dialogue placeholders when your final assets/text are ready. The authorized original boss image and soundtrack are integrated; neither is a substitute.

Manually explore all optional branches and shoreline corners, assess tree occlusion and navigation, and play the full fight with real audio. Evaluate laser warnings, convergence gap comfort, overlapping pattern fairness, readability, background intensity and sustained performance on target hardware. Verify the music's audible alignment and the approved ending fade. No manual dodge playtest or listening test is claimed.
