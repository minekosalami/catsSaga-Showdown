# Music normalization and menu repair

All original music bytes, import settings, sound effects, environmental recordings,
ambient playback, EQ, soundtrack assignments, compositions, and encounter cue
sheets are unchanged. Only music playback gain and background-theme startup/recovery
changed. No compression, limiting, resampling, generated audio, or re-encoding was
added to the game.

## Inventory and original measurements

FFmpeg 7.1.5 decoded every complete file with `-xerror`. EBU R128 integrated
loudness and oversampled true peak come from `loudnorm` **input** statistics;
its processed output was discarded. No decode errors or missing resources were
found. These are full-file values, including intentional quiet passages.

Paths below are relative to `assets/`, with `soundtrack/` abbreviated as `st/`.

| Track / file | Use | Format | Duration | Original LUFS | Original dBTP |
|---|---|---|---:|---:|---:|
| `st/Menu - 001.wav` | Main menu | Stereo 44.1 kHz, 24-bit PCM WAV | 91.349 s | -18.37 | -2.34 |
| `st/Overworld - 002.mp3` | Forest and Wonderland outdoors/interiors; cave intentionally has ambience only | Stereo 44.1 kHz MP3 | 113.528 s | -20.01 | -1.76 |
| `st/SyNaPse - 003.mp3` | Boss 2 | Stereo 44.1 kHz MP3 | 150.256 s | -9.84 | +0.20 |
| `st/catVibes - 004.mp3` | BlankKitten / Sequence() | Stereo 44.1 kHz MP3 | 145.868 s | -11.39 | +0.08 |
| `st/NatoKyofu - 005.mp3` | Present/imported, no scene/script assignment | Stereo 44.1 kHz MP3 | 136.438 s | -13.76 | -1.18 |
| `st/Malware - 006.mp3` | Incarna / Endure() | Stereo 44.1 kHz MP3 | 113.607 s | -13.12 | +0.08 |
| `fight.v.scale - catsSaga version.mp3` | Evil Bart and preceding combat | Stereo 44.1 kHz MP3 | 128.758 s | -6.31 | +0.50 |

Several lossy sources have reconstructed true peaks above 0 dBTP. This establishes
intersample overs, not proof that their original masters clipped. Attenuation keeps
the new playback safely below full scale; it cannot repair distortion already
baked into a source.

## Playback normalization

The target is -16 LUFS, constrained by a -1.1 dBTP safety ceiling (0.1 dB margin
below the requested maximum). Gains are static and stored once in
`scripts/systems/music.gd:TRACK_GAIN_DB`.

| Track | Player gain | Result LUFS | Result dBTP | Safety |
|---|---:|---:|---:|---|
| Menu | +1.24 dB | -17.13 | -1.10 | Pass, peak constrained |
| Overworld | +0.76 dB* | -19.34 | -1.10 | Pass, peak constrained |
| SyNaPse | -6.16 dB | -16.00 | -5.96 | Pass |
| catVibes | -4.61 dB | -16.00 | -4.53 | Pass |
| NatoKyofu (unused) | -2.24 dB | -16.00 | -3.38 | Pass if assigned using `Music.apply_gain` |
| Malware | -2.88 dB | -16.00 | -2.80 | Pass |
| fight.v.scale | -9.69 dB | -16.00 | -9.19 | Pass |

*Overworld retains its existing clarity EQ and -1.2 dB bus. Its values were
verified with a full-length **live Godot mixer capture after that route**, not
estimated from raw source gain. Capture: 44.1 kHz stereo, 5,017,600 frames,
zero discarded frames. Before player gain and bus attenuation, the EQ output
measured -18.90 LUFS / -0.66 dBTP. The +0.76 player gain, then -1.2 bus gain,
yields -19.34 LUFS / -1.10 dBTP. Its raw decoder-only measurement is not its final
playback route.

Other final values were measured from complete Godot-imported stream decodes
with the exact static player gain applied; those players route directly to the
unchanged 0 dB Master. NatoKyofu was decoded/audited but deliberately remains
unassigned. The menu WAV was also checked through the live mixer at native boot.
The menu and overworld cannot reach -16 LUFS without exceeding the ceiling;
retaining dynamics takes priority over forcing equal integrated loudness.

The ceiling describes isolated music at default routing, not an arbitrary sum
of simultaneous music, sound effects and ambience or user-modified bus gains.

## Confirmed menu bug and repair

Before editing, an instrumented **normal application launch** reached the actual
main menu with `current_theme=""`, `playing=false`, and `stream=null` after 0.8 s.
The intended WAV existed and imported successfully. The manager listened only to
`SceneTree.scene_changed`; Godot's initial main-scene bootstrap does not emit that
signal. Older tests used `change_scene_to_file`, so they missed this failure.

Music now synchronizes once on the first process frame, after the initial scene
is installed, and keeps the existing scene-change connection. Native-launch
validation confirms automatic playback, advancing position, correct gain, an
unmuted route, non-silent mixer samples, and end-of-file WAV looping.

Same-theme recovery now cancels a pending stop/fade and restores the measured
level without restarting the track. This prevents a failed/cancelled transition
from silencing the scene it returns to. Existing scene fades and theme continuity
across overworld regions remain intact.

## Focused implementation

- `scripts/systems/music.gd`: measured gain catalog, initial synchronization,
  interrupted-fade recovery, and `apply_gain` for existing battle players.
- `scripts/main.gd`, `scripts/{boss2,blankkitten,incarna}/battle.gd`: apply the
  centralized music gain before playback. Sequence practice/debug seeks restore
  that gain instead of the former hard-coded -12 dB.
- Two existing tests now expect measured gain rather than obsolete fixed volume.
- New native-startup and music integration tests; reproducible audit/decode/mixer
  capture tools; machine-readable measurements and original SHA-256 hashes in
  `docs/music-loudness-audit.json`.

No battle clocks, pitch, attacks, cue timestamps, health, damage, collisions,
controls, fades' durations, victory conditions, saves, or story flags changed.
Boss 2 still ends at 140.80 s and fades its remaining audio; Incarna still requires
113.14 s. Ambience and sound effects are untouched.

## Validation

Godot 4.6.3 headless import: passed, no import/parse/script errors.

| Check | Result |
|---|---|
| Native application bootstrap + live menu samples + looping | 7 checks, 0 failures |
| Music gains, interrupted transition, overworld/Wonderland/cave assignment, all four encounter entry cues, clocks/seeks, return-to-menu/no overlap | 43 checks, 0 failures |
| Existing music/hitbox integration | 37 checks, 0 failures |
| Boss 2 regression | 72 checks, 0 failures |
| BlankKitten regression | 566 checks, 0 failures |
| Incarna regression | 195 checks, 0 failures |
| Existing gameplay, shooting, SATURATE, victory/retry/menu | Functional validation: 0 failures |
| Full source decode + full imported decoder loudness + overworld live EQ route | All seven audited; every routed peak <= -1.0 dBTP |
| Source preservation | All seven original music SHA-256 hashes unchanged; no tracked asset, import, bus, or project configuration changes |

There are **920 counted checks**, plus the existing functional gameplay suite.
Some runners still report ObjectDB/resource-in-use messages at shutdown, including
an ObjectDB warning in the new native probe. They do not indicate a failed audio
assertion; cleanup remains a limitation rather than being silently reported clean.

Runtime output used the Dummy audio driver. Actual PCM/mixer output was inspected
and measured, but headphone/speaker listening, device-specific playback, perceived
transition quality and long-session subjective balance still require manual
playtesting. No audible listening result is claimed.

## Reproduce

Set writable XDG cache/data/config directories, then run from the project root:

```sh
# Run native bootstrap separately from other Godot processes using this checkout.
python3 tests/test_native_music_startup.py
godot --headless --audio-driver Dummy --path . --script tests/headless_music_levels.gd

godot --headless --path . --script tools/render_music_audit.gd -- /tmp/catsSaga-music-decodes
godot --headless --audio-driver Dummy --path . --script tools/capture_music_mix.gd -- overworld /tmp/catsSaga-overworld.f32le
python3 tools/audit_music.py --decoded-dir /tmp/catsSaga-music-decodes --overworld-mix /tmp/catsSaga-overworld.f32le --output /tmp/catsSaga-music-audit.json
```

The native test exclusively creates a temporary `override.cfg` to add its probe
autoload, runs the **real configured main scene**, then removes its override in a
`finally` block. It refuses to overwrite any existing local override. Decode and
capture outputs above live outside the checkout and never replace source music.
