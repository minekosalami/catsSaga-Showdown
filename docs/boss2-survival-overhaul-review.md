# Boss2 survival overhaul

This replaces Boss2's peaceful intermission and old moving/reversing cross with the requested ricochet and fixed-pivot survival attacks. The original photographic `assets/enironment/bosses/bosstwo.png` is still shared with the NPC, using the previously approved filename. All source images, soundtracks, overworld scenes, Evil Bart scripts, shared player controls and SATURATE implementation remain unchanged.

## Controls and damage

Boss2 only: hold **X** for SPRINT(), at 810 internal pixels/second (1.8 × normal 450). A full meter drains in five seconds and recharges in three inactive seconds. Partial stamina permits movement; Shift takes priority at the existing 150-pixel focus speed. Releasing X caps momentum immediately. After exhaustion, release X to re-arm sprint; the meter explicitly displays `RELEASE X` while recharging. The survival overrides still prohibit shooting and SATURATE, including BEAM-assisted SATURATE.

A fresh X press with at least 20% stamina gives 0.2 seconds of projectile/laser protection. Its independent 0.6-second cooldown prevents repeated taps from extending protection, without blocking ordinary sprint movement. White afterimages, a protection flash and sparks at protected laser contacts have no collision. A valid hit removes one HP and grants 1.5 seconds of visibly flickering damage immunity. All three HP, stamina, cooldowns, effects and audio reset on Retry. Death immediately disables hazards; its 0.8-second audio fade continues while gameplay is paused.

The actual player damage circle remains **7.5 pixels**, already enlarged by the earlier update. The focus indicator still reads that exact shape. The photographic player texture and its existing display scale are preserved; a Boss2-only shader supplies an outline and brief damage/protection flashes.

## Timeline and attacks

The existing soundtrack remains authoritative: playback position plus mix time minus output latency, sampled monotonically. Major attack and visual poses are derived from that clock. No dialogue or hit effect pauses/restarts the song.

| Song time | Behavior |
| --- | --- |
| 0–12.80 | Existing automatic introduction; movement enabled. |
| 12.80–38.40 | Original learnable ring/spiral/fan patterns; normal bullet speeds ×1.30 relative to the previous defaults, independently of density. |
| 38.40–64.00 | Existing coordinated blue laser/boss travel. Warning lasts 1.2 seconds and now depicts the exact 20-pixel moving beam footprint rather than its entire travel band. |
| 64.00–70.40 | RICOCHET(): four seven-shot angled fans at 64, 65.6, 67.2 and 68.8 seconds, aligned to four 150 BPM measures. Automatic original supplied dialogue remains in the HUD. |
| 70.40–71.20 | All remaining ricochets become harmless and shatter. `NOW DIE!` appears in the HUD; a separate enormous red warning contains exactly `LASERS!`, with a rapid overshoot, brief flash and background shake. |
| 71.20–72.00 | Warning text disappears; cross charge remains non-damaging. |
| 72.00–89.60 | Full-length, clockwise red cross around fixed internal pivot (270, 410). Sine easing accelerates over 3.2 seconds, holds **50 RPM**, then decelerates over the last 3.2 seconds. No normal bullets or blue laser damage occur in this phase. |
| 89.60 | Cross damage switches off immediately; all four arms break into 64 varied glass polygons with red/white sparks. Harmless fragments last 0.5 seconds into the finale. |
| 89.60–140.80 | Lighter closing patterns: reduced ring count and slower, measure-aligned volleys. |
| 140.80 | Existing survival victory, progression/save and forest return; original longer soundtrack tail fades over 0.8 seconds. |

Ricochets spawn at 320 pixels/second, reflect on the actual wall normals, and consume remaining motion after each impact to avoid tunneling/sticking. Each wall reflection reduces current speed by 10%, with a 160-pixel minimum (half spawn speed). There is no bounce limit. Peak scheduled density is 28; a soft cap of 30 dissolves the oldest bullet harmlessly if needed. Bounce flashes/trails immediately use the reflected direction. All projectiles remain in `enemy_bullets`; Boss2 adds its own encounter/ricochet groups.

Normal and ricochet bullet collision uses relative player/projectile swept segments, including every reflected segment. Red lasers have 1,600-pixel beams but **only the explicitly drawn three-pixel white core damages**; the 24-pixel red energy and outer glow are decorative. Two perpendicular shapes form four arms. Collision checks relative swept angles against the actual player circle, including between-frame contacts at 50 RPM, rather than testing only the final rotated pose. Rotation uses the closed-form integral of the sine-eased speed, without frame accumulation or reversals.

Grazing produces a tiny spark burst once per bullet and a quiet 40 ms synthesized electronic chirp. It grants no HP, stamina or rewards. There are no new downloaded sound/art dependencies.

## Presentation and files

The original grass PNG contains a baked `catsSaga()` title. `shaders/boss2_background.gdshader` repeats its unlettered upper half in place, preserving the source file and grass pixel scale. Boss2 grass is darkened 23%, mildly desaturated, with restrained vignette and a 0.16-second damage glitch. Overworld/Bart backgrounds are unaffected.

The compact top HUD now contains HP/3, remaining time, current phase, song progress and stamina. Dialogue lives inside this card; the large bottom offense footer and central phase titles are removed from active combat. The boss centers at y=205, clear of the HUD and inside the upper third, while retaining ±8-pixel bobbing over 3.2 seconds, 106% musical pulses, and shared original artwork. Aura/shadow and a brief attack emphasis are visual only. A thin cyan/red arena border changes with the phase.

Changed runtime files are the two `scenes/boss2/` scene references and the existing player, timeline, cross, blue laser, boss visual, HUD and battle scripts under `scripts/boss2/`. New encounter components are `projectile.gd`, `ricochet.gd`, `effects.gd`, `afterimages.gd`, `aura.gd` and `arena_overlay.gd`, plus three Boss2-only shaders. Effects use one bounded drawing pool (256 particles, 12 ghosts); cross shards use one fixed array, with no individual physics/particle nodes. Earlier cross review documentation describes the prior implementation; this document describes the current behavior.

Inspector tuning is local to Boss2: sprint multiplier/capacity/recharge and protection values in `player.gd`; normal speed multiplier and projectile budgets in `timeline.gd`; core width, maximum RPM, ramp durations and fragment settings in `cross_laser.gd`. Timeline boundaries remain the requested constants.

Screenshots from the graphical tests:

- [Ricochet density and HUD](review/boss2-overhaul/ricochet-28.png)
- [LASERS! impact warning](review/boss2-overhaul/lasers-slam.png)
- [50 RPM cross](review/boss2-overhaul/cross-50rpm.png)
- [Harmless glass shatter](review/boss2-overhaul/cross-glass.png)
- [Sprint afterimages](review/boss2-overhaul/sprint-afterimages.png)
- [Damage feedback](review/boss2-overhaul/damage-feedback.png)

## Validation and remaining manual checks

Validated with Godot 4.6.3, including headless editor import and load/instantiation of all 20 project scenes. **808 gameplay/regression assertions across 15 headless suites passed**, alongside 20 scene loads, three full-song checks and **94 graphical checks** across four render suites. Automated headless suites cover startup/menu navigation, original overworld/maps/assets/progression, Bart HP/phases/shooting/SATURATE/BEAM/CATA/victory, Boss2 phase boundaries, blue warnings/collision, sprint speed/drain/recharge/priority/cooldown, grazing, ricochet reflection/speed floor/cap, swept collisions, protected laser crossing, death, retry, music fade and forest return.

`tests/play_cross_survival.gd` uses the real movement/acceleration and eight-direction inputs, with no health changes or invincibility: an automated precision controller approaches the pivot during telegraphing and follows a close focus orbit through the entire 50 RPM attack. This establishes an attainable route, not human difficulty/readability. The isolated route samples the music-derived attack curve; the separate full-song run observes uninterrupted real audio playback with explicit **test invincibility**, reaching all seven phases and victory at 140.80.

Graphical tests run under Xorg/Mesa llvmpipe and capture the menu, overworld, both bosses, victory, new HUD, warnings, ricochets, afterimages and shattering. Synthetic rendering checks run 28 live ricochets and the 240 enhanced-bullet safety budget without accumulation. Measured 120-frame averages on software rendering were approximately 20–24 ms for 28 ricochets and 49–52 ms for the synthetic 240-bullet budget; the uninterrupted encounter peaked at 78 normal projectiles. These software-render timings are not a target-hardware benchmark or proof of human fairness.

Manual playtesting remains necessary for the full encounter's difficulty, learning the close-pivot cross route, flashing/contrast comfort, graze sound/music balance, and performance on the intended GPU. No missing resource or confirmed gameplay failure remains in automated checks. The configurable automatic introductory dialogue remains the repository's existing placeholder; no new story was invented.

Reproduce the focused checks from the project directory:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/headless_boss2_overhaul.gd
godot --headless --path . --script tests/headless_cross_lasers.gd
godot --headless --path . --script tests/play_cross_survival.gd
godot --headless --path . --script tests/full_boss2_survival.gd
godot --path . --rendering-method gl_compatibility --script tests/render_boss2_overhaul.gd -- --output=/tmp/boss2-overhaul-review
```
