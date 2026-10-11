# Evil Bart battle overhaul and 300 HP review

Evil Bart now starts every new fight at exactly **300/300 HP**. `scripts/boss.gd` exposes one `max_health` variable, initialized to 300, in the boss Inspector. The existing HUD reads the boss health signal and uses that same maximum. Player shots still inflict 1 damage; SATURATE still inflicts 30 damage once per target per activation. Health clamps to zero, and the existing single-trigger defeat animation, victory screen, Retry, and post-battle dialogue remain in use.

## Battle presentation and patterns

The existing boss controller, movement, health phase thresholds, attack cooldowns, music clock, and soundtrack remain intact. Reusable pattern helpers add expanding rings with gaps, alternating and counter-rotating spirals, petal formations, symmetric waves, and gentle curvature that stops after 0.8 seconds. Later sections have more complex formations. Rings reserve an angular escape gap and waves reserve a central opening; these geometric checks do not establish that every overlapping pattern is practically dodgeable.

Procedural bullets use four styles: standard (6.5 px radius), fast (4.5 px), heavy (8 px), and diamond (6 px). Each bright filled circular body matches its independent CircleShape2D radius. Diamond outlines, trails, and faint halos are decorative. Drawing replaces the old extra visual nodes; each projectile retains its existing Area2D and one collision shape. A 320-projectile budget and a 24-burst budget bound active objects. Colors assigned by the boss now reach the bullet before its ready callback.

Phase announcements, short translucent flashes, brief background shake, and bounded radial bursts follow actual music playback. Showdown() has a larger title. A shader on the existing background texture adds progressive color shifts, subtle ripple and chromatic separation; geometric borders and arcs remain behind actors. Shake affects scenery only, preserving actor and collision transforms.

### Preserved authoritative attack timeline

| Seconds | Existing attack event |
| --- | --- |
| 6.85 | Arrival |
| 20.57 | Second instrument / rising pressure |
| 48.00 | Calm section |
| 61.71 | Final climax |
| 89.14 | Showdown |
| 123.00 | Stop attacks |

Presentation additionally recognizes 0.00 (Introduction), 34.28 (Refraction), and 116.00 (FinalSequence). These do not replace existing attack section boundaries. The soundtrack is unchanged, and no announcement pauses or restarts it.

The game already supports early victory on zero health; that behavior remains. At 123 seconds, attacks stop without automatically removing remaining boss health. A confirmed bug previously rejected all damage after stopping attacks, leaving a surviving boss impossible to defeat. Damage now remains valid until actual defeat; the original zero-health victory path handles completion.

## SATURATE and focus

SATURATE gains rainbow charge particles around the actual player hitbox, an animated rainbow border, a white beam core, translucent aura, traveling sparks, and a boss impact burst/flash. X activation, once-per-battle usage, BEAM, 0.35-second charge, 1.25-second sweep, original sweep trajectory, projectile clearing, and 30 damage remain unchanged. Its text fades instead of rapidly blinking.

Holding Shift shows a small glowing circle at the player's actual CollisionShape2D position and radius (currently 7 internal pixels). Releasing Shift hides it; F3 retains the existing debug override. Death and victory hide the marker. Existing focus speed (150), normal speed (450), player artwork, collision layers, one-second invulnerability, CATA, and overworld collision are preserved.

## Inspector controls

| Node / resource | Setting | Default |
| --- | --- | --- |
| Boss | `max_health` | 300 |
| Main / BattlePresentation | `effect_intensity` | 0.45; zero disables background distortion and geometry |
| Main / BattlePresentation | `shake_intensity` | 0.6; zero disables scenery shake |
| Main / BattlePresentation | `phase_particles_enabled` | true |
| Main / UI | `phase_flash_strength` | 0.12; zero disables phase flashes, maximum 0.25 |
| Rainbow beam | `visual_intensity` | 0.7; adjusts supplemental glow and particles |
| Player / CollisionShape2D | Circle radius | 7; focus marker reads the actual shape |

The existing sprites, audio, fonts, dialogue, save system, 1280×720 overworld, and 540×900 battle viewport are unchanged. No artwork was generated, downloaded, or replaced.

## Automated validation

Godot 4.6.3 headless editor import and runtime validation passed. The existing project feature declaration was preserved. **649 checks passed, with no failures or script errors**:

| Suite | Checks |
| --- | ---: |
| Gameplay / menu / victory | 150 |
| Overworld | 59 |
| Quality of life / progression | 81 |
| Bart encounter / dialogue | 71 |
| Shared world assets | 53 |
| Controls / tree / collision | 39 |
| Forest overhaul | 41 |
| Saved progression reload | 7 |
| Music / hitbox regression | 37 |
| New boss overhaul | 47 |
| Existing graphical UI suite | 53 |
| New graphical boss captures | 11 |

The new headless suite exercises actual battle creation, 300/300 HUD, music seeks at phase boundaries, unchanged health phases at 210 and 105 HP, Shift focus, bullet radii and curvature, pattern openings, projectile/burst limits, real shot and SATURATE damage, overkill, single-trigger victory, Retry, the 123-second cutoff, damage after that cutoff, and existing post-battle dialogue/progression. Emitting a capped projectile batch took approximately 9–12 ms in the test environment; this is not a sustained frame-rate measurement.

Graphical captures used Xvfb and software Mesa with dummy audio. They validate scene rendering and exercised navigation, but do not establish audible synchronization or manual dodge difficulty. The renderer reported unsupported VSync adjustment in this environment; there were no shader compilation or runtime errors.

Focused commands (use isolated XDG data directories so tests do not touch your normal save):

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/headless_bart_overhaul.gd
# Requires a working display; the capture script uses dummy audio.
godot --path . --audio-driver Dummy --script res://tests/render_bart_overhaul.gd
```

### Rendered review captures

- [Showdown transition](review/bart-overhaul/showdown-transition.png)
- [Showdown flower pattern](review/bart-overhaul/showdown-flower.png)
- [Focus hitbox](review/bart-overhaul/focus-hitbox.png)
- [SATURATE white core](review/bart-overhaul/saturate-white-core.png)
- [Victory](review/bart-overhaul/victory-300hp-boss.png)

### Manual playtesting still needed

Play through the complete soundtrack with real audio to confirm perceptual synchronization and the ending. Dodge each phase, especially overlapping spirals and late flowers, to evaluate fairness and readable gaps. Measure sustained performance on target hardware at the projectile cap. Review background intensity, flash comfort, bullet readability over the original background, focus marker visibility, and SATURATE impact; adjust the exposed visual controls if needed. Screenshots and geometric gap assertions cannot replace these checks.

## Scope

Implementation touches the boss, enemy bullet, battle coordinator, player focus/debug visibility, SATURATE rendering, HUD phase presentation, one battle scene reference, and new procedural presentation helpers/shader. Tests and this review guide are included. Existing overworld, NPC dialogue, save/load logic, source artwork, audio, project resolution, player shooting, and damage values remain unchanged.
