# Incarna Endure() review

The cave's existing camera pan, greeting and shared cat → star → cat entry now
lead to Incarna. Survive to **113.14 seconds** to save `incarna_defeated` and
return to the cave junction. No keys or inventory rewards are added. Retry starts
fresh; defeat offers Retry and Main Menu. Completed encounters do not retrigger.

## Assets and framing

- Art: `assets/enironment/bosses/boss4 - incarna/Untitled design/Sprites.png`.
  AtlasTexture regions and textured deformable meshes reference this one original
  sheet. No source artwork is modified; Mockup and Original Cat are not used.
- Music: `assets/soundtrack/Malware - 006.mp3`, normal playback rate. Its measured
  duration is 113.61 seconds; the requested ending is 113.14, followed by a
  0.35-second audio fade rather than an abrupt stop.
- Only this encounter uses a **1280×720** internal arena. Existing fights retain
  **540×900**. The actual player hit center stays within x=96–1184, y=424–660,
  inset by its collision radius. Three HP, focus, sprint, CATA and the existing
  Endure controls are reused; shooting and SATURATE remain unavailable in Endure.

The giant monochrome rig inches into frame over ten seconds, with movement and
damage locked during emergence. Heads exchange sockets on curved paths while
retaining metal tethers. Fur/jaws deform, eyes follow and blink, paws anticipate,
lunge and return along weighted arcs, and the mechanical base absorbs impulses.
Only the lower part of the oversized creature fits on screen. Slow red pulses
and upper-screen interference leave the lower playfield readable. Reduced FX
softens pulses and removes interference without changing attacks.

## Timing and attacks

`scripts/incarna/config.gd` centralizes authored timing, play bounds and attack
tuning. `battle.gd` uses the AudioStreamPlayer position plus mix/latency correction;
the rig, attacks, projectiles, effects and ending all sample that same clock.
The existing transition finishes before music starts at zero. No separate combat
timer or playback-rate change is used.

| Soundtrack time | Response |
| --- | --- |
| 0–10.00 | Slow protected emergence; movement unlocks at 10.00 |
| 20.57 | First warning and smaller attacks |
| 27.42 | Faster attacks, additional radial pressure |
| 41.14 | Paired lunges, denser pressure and subtle interference |
| 82.28 | Strong rig/red response, release old hazards, 15-spear warning |
| 96.00 | Longer attack intervals and slower projectiles |
| 102.85 | Sparse final pressure; interference fades |
| 113.14 | Clear all hazards, save survival victory, fade music |

The 82.28 response has an authored two-beat anticipation; that lead-in is a
design choice, not a claim about a measured stop in the recording. Spear barrages
warn for 1.15 seconds, then launch 10–15 spears at 0.1-second intervals, aiming
anew at each shot. Connected paws warn before striking their marked positions.
Seeded danger zones warn before radial bursts. Swept collision accounts for
both moving player and projectiles. Late events are skipped rather than producing
an unfair catch-up burst. Fragment pressure reserves room for complete barrages.

## Validation and visual review

Godot 4.6.3 headless import, focused Incarna tests, the full actual-song clock run,
shared-entry and cave checks pass. Bart/gameplay, Boss 2, BlankKitten and developer
menu regressions pass. Rendered Incarna and cave checks pass at native and larger
window sizes. Earlier boss logic, shared transition, artwork and cave geometry
were compared against the starting revision and remain unchanged.

Run the focused checks with `godot --headless --path . --script
tests/headless_incarna.gd` and `tests/full_incarna_survival.gd`. Render checks use
`tests/render_incarna.gd` and require a display. Test saves and captures are
isolated from normal saves. Some suites retain the existing ObjectDB shutdown
warning; software rendering also reports unsupported VSync.

- [Looming creature](review/incarna/looming-creature.png)
- [Tracking barrage](review/incarna/tracking-barrage.png)
- [Survival result](review/incarna/endured.png)
- [Motion preview](review/incarna/motion.mp4): silent 60 FPS capture of the shared
  transition, emergence, then jump cuts to paw/zone and spear attacks. It is a
  visual preview, not a full fight or performance benchmark.

Rendered poses and motion samples were inspected and refined. The full-song test
uses an invulnerable observer to verify timing/completion, so it does not prove
human survivability. Manual playtesting remains necessary for relative difficulty,
dodge fairness, subjective animation quality, audible cue alignment and hardware
performance. Validation used dummy audio and software rendering.
