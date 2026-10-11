# Boss presentation and rotating cross review

Boss2 now declares **NOW DIE!** at 70.40 seconds, then uses a moving, alternating red cross formation during the same hardest phase. Both perpendicular beams share one pivot and two rectangular damage shapes. Brilliant gradient cores, electrical lines, flow, sparks, red targeting zones and warning triangles are procedural CanvasItem effects; no artwork files were added or altered.

## Fair sequencing and exact music timing

The suggested subdivision in the request would overlap the existing inward blue beams with the rotating cross. The request explicitly permits a configurable sequence when these hazards conflict. The default retains the blue pattern's original 1.2-second warning, ten-second inward movement and two-player stopping gap, then hands over to red:

| Song position | Action |
| --- | --- |
| 70.40 | Original hardest phase begins; NOW DIE! automatically appears in the existing phase title, with eased entrance and restrained border/flash. |
| 70.40–71.60 | Blue convergence warning. |
| 71.60–81.60 | Blue beams close inward with the original easing, centered boss and stopping gap. |
| 79.20 | Non-damaging red cross targeting starts at its initial horizontal/vertical pose. |
| 80.00 | Red charge begins; warnings still do not damage. |
| 81.60 | Blue damage switches off; red cross becomes dangerous and starts moving/rotating. No stacked damaging laser formations. |
| 89.08 | Cracks spread through the red beams with a restrained brightness accent. |
| 89.20 | Red hitboxes switch off; both beams burst into tumbling angular fragments. |
| 89.60 | All fragments and cross hitboxes are cleared; existing finale starts. |
| 140.80 | Existing survival victory, with the previously approved audio fade. |

Normal bullets continue through the entire hardest phase at the previous default difficulty multiplier (1.25). No firing cadence, projectile speed, pattern, player attack or damage value was changed by this PR. The phase boundaries are still 0, 12.80, 38.40, 64, 70.40, 89.60 and 140.80. The original intermission text remains unchanged; NOW DIE! is the only added line. Music and movement never pause for dialogue or effects.

All cross poses, energy, warning states and shards sample the authoritative song clock. Rotation uses a cached fixed-grid integral of a smooth velocity curve, rather than integrating frame delta. Default speed rises from 0.32 to 1.10 radians/second with a 1.4-power curve. Direction alternates every 1.6 seconds (one 150 BPM measure); a 0.28-second eased reversal passes continuously through zero speed. A bounded, eased curved pivot path starts without teleporting and never tracks the player.

Shards use a deterministic array of 64 varied triangles/quadrilaterals/pentagons, with independent velocity/spin, exponential deceleration, red glow, white highlights and fading trails. They add no physics or individual particle nodes. Colliders disable as soon as shattering begins; geometry/query guards also prevent any damage during warning or breakup. Defeat, Retry, victory and phase changes clean the formation up.

## Other presentation changes

Blue lasers now share the same reusable gradient/energy renderer as red, with white-hot centers, cyan/blue edges, electricity and flow. Red warning locators gain a dim cyan charge line without changing activation timing. A short visual deactivation tail has no collision.

All existing enemy projectile styles in both fights use smoothly shaded energy bodies, bright white centers, precise antialiased danger rims, faint halos, fast trails, animated layered heavy cores and distinctive rotating special outlines. Mathematical ramps are packed into one shared in-memory texture atlas to reduce texture switches for hundreds of bullets. No per-projectile shader or new scene nodes are added. The four dangerous radii remain 6.5, 4.5, 8 and 6 pixels, with unchanged physics and SATURATE grouping.

The existing shared HUD and phase component are refined rather than duplicated: consistent padded cards, restrained accents, clearer Boss2 health/phase/countdown typography and progress, and stronger emphasis on dramatic phase titles. Bart still uses his 300 HP bar and real health animation, with SATURATE states. Boss2 still has only player health, phase, remaining song time and progress; no boss HP bar. Existing 150 BPM/4-beat pulsing (100→106→100%) and ±8-pixel floating over 3.2 seconds remain active together through the song clock and drawing offset. Attack coordinates and spawn positions are unaffected.

The authorized shared texture remains `assets/enironment/bosses/bosstwo.png`. The request's `boss2.png` and `NOW DIE!.png` reference were not present; no substitute image or new artwork was created. The written perpendicular starting arrangement was implemented.

## Overworld EQ and battle hitbox

`default_bus_layout.tres` adds an editable **Overworld** audio bus with one AudioEffectEQ6: 100 Hz −0.3 dB, 320 Hz −0.8 dB, 3.2 kHz +0.8 dB and 10 kHz +1.2 dB; other bands remain neutral. Bus gain is −1.2 dB for headroom. Only the existing overworld theme routes through it. Menu/boss music and effects stay on Master. The source audio and original −12 dB music level are unchanged. Adjust or bypass the effect through Godot's Audio panel.

The shared battle player's configurable `damage_hitbox_radius` changes from 7 to **7.5 pixels** (+7.14%). The scene default matches it. Each instance still duplicates its shape, centers it on the original sprite, and supplies the actual radius to the focus/F3 indicator. Movement, sprite size, i-frames and overworld collisions are unchanged. Both fights inherit this same increase.

## Inspector settings

Open `scenes/boss2/battle.tscn` and select `Boss2Timeline/RotatingCross`. All absolute timing controls are song seconds: `start_time`, `end_time`, `warning_start`, `warning_duration`, `charging_duration`, `activation_duration`, `shatter_time`. Activation is max(start time, warning start) + warning duration + charging duration (default 1.6 seconds). Active duration defaults to 7.6 seconds; breakup occurs at its expiry or the configured shatter/phase end, whichever is earlier. Suggested early activation can be configured, but it shortens the blue damaging window; keep the default 81.60 handover to retain its full inward convergence. Cross updates are additionally restricted to the existing hardest phase, so changing component timings cannot spill damage/shards into another phase.

Tune `initial_rotation_speed`, `maximum_rotation_speed`, `acceleration_curve`, `reversal_interval`, `reversal_easing`; `pivot_center`, `pivot_amplitude`, `pivot_cycle`, `pivot_bounds`; `beam_width`, `beam_length`, `glow_intensity`; and `fragment_count`, `fragment_velocity`, `fragment_lifetime`. Default red width is 24 pixels, length 1600, glow 0.65, 64 shards, velocity 280 and lifetime 0.38 seconds. Visual glow extends past the rectangle and never increases its dangerous width. Fragment lifetime is capped by the phase end.

Previous BossSprite pulse/float/downbeat controls, UI flash/border controls and Timeline difficulty remain available. This PR does not change the saved game or Boss2's disabled shooting/SATURATE rule; Bart and future attacking fights preserve SATURATE, BEAM and CATA.

## Validation and manual review

Godot 4.6.3 headless editor import passes. **761 headless assertions** pass across the existing regressions and the new 46-check cross suite. **91 graphical checks** pass across menu/UI navigation, Bart, Boss2, shared bullet styles and the new cross captures. **Three uninterrupted full-song checks** pass: all phases observed, survival victory at 140.80, safe intermission and projectile cap; peak 99/240. Total: **855 checks**.

The cross suite tests exact cues, dialogue, warning/charge safety, actual rotated collision damage, two-beam i-frame behavior, harmless outer glow, collider/perpendicular geometry, alternating eased velocity, acceleration, bounded motion, deterministic seeking, continuing bullets, varied harmless shards, phase/defeat cleanup, Retry/menu, EQ routing/values, and the 7.5-pixel centered hitbox. A 0.1-second laser-only safe-cell reachability test finds a route at 450 pixels/second; it excludes normal bullets and is not a human dodgeability proof. The full song run uses explicit test invincibility to observe the complete timeline.

The final dense rendering run draws 240 mixed-style bullets plus the animated cross over 120 frames, averaging **47.69 ms/frame on Mesa llvmpipe software rendering**. Earlier software runs varied substantially with rendering load. Target-GPU frame rate and stable hardware performance are unverified. Only the software driver's unsupported V-Sync warning remains in graphical logs.

Manual testing is required for combined-pattern fairness without invincibility, red/blue warnings and glowing collision boundaries during motion, shard/phase comfort, target-GPU/export performance, listening to overworld EQ and audio fade, and confirming the first audible downbeat offset. Screenshots use Dummy audio and cannot establish audible quality. The absent reference image's exact visual arrangement could not be checked.

Review screenshots: [NOW DIE](review/rotating-cross/now-die.png), [warnings and blue convergence](review/rotating-cross/cross-warning-blue-convergence.png), [charge](review/rotating-cross/cross-charging.png), [moving cross](review/rotating-cross/cross-rotation.png), [cracks](review/rotating-cross/cross-cracks.png), [shatter](review/rotating-cross/cross-shatter.png), [dense projectiles](review/rotating-cross/cross-dense-bullets.png). They are documentation captures, not new game assets.

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script tests/headless_cross_lasers.gd
godot --headless --path . --script tests/headless_boss2.gd
godot --headless --path . --script tests/full_boss2_survival.gd
# A display is required for rendered checks:
godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --script tests/render_cross_lasers.gd -- --output=/tmp/cross-review
```

The full-song test takes about 143 seconds. Validation uses separate test save paths. Reusable headless and Xorg dummy-display startup instructions were saved in the cloud environment configuration draft; review/save them in environment settings and publish to activate them for future environments. No new dependencies were installed.
