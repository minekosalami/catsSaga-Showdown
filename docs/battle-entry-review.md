# Shared encounter entry

The existing `Session.transition_to(path, true)` call sites now use one persistent
overlay: freeze (80 ms), blackout (200 ms), cat/star flash (120 ms), direct eased
star travel (650 ms), return flash and reveal (200 ms). Loading stays behind black.
Endpoints come from the actual player visuals, camera and portrait viewport transform.

Showdown, Endure, Sequence, their retries/previews, and the existing Boss 4 placeholder
share it. Sequence retains its playable star; the return cat is a brief overlay only.
Boss 4's existing camera/dialogue, placeholder and return behavior remain unchanged.

Original synthesized hit, rising tone and confirmation cues use separate audio players.
Showdown/Endure initialization now defers music like Sequence already did. The host
restores input/processing and starts the original soundtrack at zero after reveal;
existing music clocks, attacks, phases, damage, healing and victory logic are unchanged.
Failed loads and externally replaced scenes release the overlay and processing locks.
Future controllers using this host should also honor `Session.battle_entry_pending`
when initializing music, letting `finish_entry()` start playback.

Validation: Godot 4.6.3 headless import; focused headless/rendered entry checks; Bart,
Boss 2, BlankKitten, Sequence, cinematic, cave, gameplay and developer-menu regressions.
The rendered entry test uses `-- --capture` and saves frames outside the repository.
Visual captures include the white flashes and star against solid black. Listening,
subjective pacing and hardware display/audio checks remain manual. Validation used
dummy audio; some suites emit the existing ObjectDB shutdown warning.
