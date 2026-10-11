# Evil Bart encounter update

Evil Bart now uses the exact supplied first-encounter dialogue and selectable responses. Z starts, reveals, and advances dialogue; Up/Down selects a response, and Z or left click confirms it. Selecting **No.** closes the introduction without starting combat or recording completion; the next interaction restarts it. Both ability-response branches converge on the final warning.

## Inputs and presentation

`project.godot` overrides `ui_accept` with **Z only**, replacing the default Enter/Space confirmation. Arrow menu navigation, existing overworld movement, Shift sprint, Escape pause, and F11 fullscreen remain available. The indicator and menu help now show Z. Dialogue handles input before GUI propagation so selecting a response cannot also advance the next line. Overworld movement and interaction stop while dialogue or a modal menu is active.

The existing terminal panel and bundled monospace font render dialogue with RichTextLabel. `The Refraction` is purple (#B47AFF) and bold. SATURATE is matched case-insensitively and rendered character by character in the requested rainbow sequence, including parentheses. Raw text and capitalization are preserved, markup is escaped, and visible-character typing and in-memory history share the formatter. Existing optional typing-sound slots remain usable; no sound asset was added.

The overworld player scene references the supplied **`assets/player/player.png.png`**. This is the actual filename already tracked on main. The original 490×653 indexed PNG, including its palette transparency, remains byte-for-byte unchanged. Existing sprite-height scaling is uniform; horizontal flipping and standing facing direction are preserved. Only the texture reference and Godot import metadata were added.

## Transition and progression

The existing Session curtain performs a 0.5-second downward white wipe across the whole logical 1280×720 window. Combat loads while the curtain is fully white and reveals over 0.3 seconds. The combat host disables processing and input during reveal and restarts its original music at position zero when reveal finishes. The internal arena stays 540×900. Other scene transitions retain their existing black fade.

The existing boss-defeat animation, music fade, victory screen, Retry, and Return to Forest are retained. A confirmed victory saves `evil_bart_defeated` and sets `story_flags.bart_victory_dialogue_pending`. Returning to the forest shows the supplied victory line. Completing it sets `story_flags.bart_victory_dialogue_seen`, clears pending, and autosaves. Loading a saved pending victory also delivers the line; loading after it is completed does not repeat it. Subsequent Bart interactions always use the supplied repeat line and cannot start another encounter. Bart's overworld location and appearance are unchanged.

Save schema version remains 1. Legacy saves already marking Bart defeated, with neither new flag, are treated as having completed the victory conversation; they retain their position and unrelated story flags and proceed to repeat dialogue. Fresh victories explicitly have a pending flag, allowing recovery after closing the game on the victory screen. New Game resets progression through the existing mechanism. Loss and aborted encounters do not create victory flags.

## Editing dialogue

Edit `data/dialogue/evil_bart.json`, without changing the renderer:

- `start` names the initial node; `nodes` maps node IDs to definitions.
- Each node has `speaker` and `lines` (sequential strings).
- `choices` lists responses with `text` and either `next` or `end`.
- Nodes without choices use `next` to continue or `end` to finish.
- `end: "declined"` exits; `end: "battle"` requests the existing encounter.

The supplied BART_001–BART_005 IDs and exact dialogue are preserved, including “familar”. Linear forest, victory, and repeat conversations remain in `data/dialogue/test_dialogue.json`. Formatting is global in `scripts/world/dialogue_format.gd` and applies to both linear and branching entries.

## Files

- Dialogue: `data/dialogue/evil_bart.json`, `data/dialogue/test_dialogue.json`, `scripts/world/dialogue.gd`, new `scripts/world/dialogue_format.gd` and its UID.
- Integration: `scripts/world/overworld.gd`, `scripts/systems/session.gd`, `scripts/systems/combat_host.gd`, `scripts/systems/save_manager.gd`.
- Inputs/help/sprite: `project.godot`, `scripts/main_menu.gd`, `scenes/world/player.tscn`, `assets/player/player.png.png.import`.
- Tests: new `tests/headless_bart.gd` and its UID; adapted `headless_overworld.gd`, `headless_qol.gd`, `reload_saved_progress.gd`, and `render_ui.gd`.

Boss attacks, combat player/beam/bullet scripts, collision shapes, artwork, audio, and both configured resolutions were not modified.

## Validation

Godot **4.6.3** headless editor import completed without script or resource errors. Automated results:

| Suite | Checks | Result |
| --- | ---: | --- |
| `headless_gameplay.gd` | 150 | Pass |
| `headless_overworld.gd` | 59 | Pass |
| `headless_qol.gd` | 81 | Pass |
| `reload_saved_progress.gd` | 7 | Pass |
| `headless_bart.gd` | 71 | Pass |
| `render_ui.gd` (Xvfb/Mesa software OpenGL) | 43 | Pass |

Tests cover menu Z confirmation and arrow navigation, removed keys, both dialogue branches, mandatory What?, No/restart, rich text and history, movement locks, wipe coverage and entry timing, music/boss synchronization, original shooting/SATURATE/BEAM/CATA, pause, collision and sprint, victory/loss, saved pending dialogue recovery, legacy saves, repeat dialogue, and persistence in a fresh process. Graphical checks exercise real mouse choices, full-window captures, wrapping, fullscreen toggles, portrait arena scaling, Retry, and Return to Forest.

Run from the repository root:

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/headless_gameplay.gd
godot --headless --path . --script res://tests/headless_overworld.gd
godot --headless --path . --script res://tests/headless_qol.gd
godot --headless --path . --script res://tests/reload_saved_progress.gd
godot --headless --path . --script res://tests/headless_bart.gd
# Requires an actual or virtual graphical display:
godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --script res://tests/render_ui.gd -- --output=/tmp/catsSaga-bart-review
```

Reload validation must follow the QOL suite using the same user-data directory. Test suites use separate validation save slots, not the regular gameplay save. Render captures and logs are outside the repository.

Manual playtesting remains necessary for transition feel, readable text at physical display sizes, the sprite's preferred display size, and audible music/typing sound when an existing typing sound is assigned. Graphical tests use Dummy audio and software rendering; their only driver warning is unsupported V-Sync. No Godot 4.7 executable is installed here; the repository's existing 4.7 feature declaration was preserved, and tests used 4.6.3.
