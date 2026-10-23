# Standalone fullscreen and display scaling fix

## Confirmed cause

On a standalone X11/llvmpipe display at **1920×1080**, the old code set the fullscreen mode flag but left the OS window and root framebuffer at **1280×720**, positioned at **(320,180)**. The root stretch transform remained **1×**, so the complete game occupied a smaller centered window. The previous display tests trusted the mode flag and ran on a monitor matching the 1280×720 design size, masking the problem.

This reproduces without the Godot editor. The intentional **540×900** battle SubViewport is not the cause of the whole-game rectangle; its existing host already scales it proportionally to the available height. `window/subwindows/embed_subwindows` controls in-game modal dialogs, not the editor's embedded Game view.

The default `keep` stretch aspect also leaves bars when a window has a different aspect than the 16:9 design base.

## Focused changes

Only three production files changed:

- `scripts/systems/game_settings.gd`: fullscreen explicitly applies the current monitor's **native size and origin**, borderless state and appropriate Godot window mode. Windowed mode restores the selected client size, normal borders and saved position. Effective borderless fullscreen is recognized from actual native geometry on window managers that leave the backend mode as WINDOWED; exclusive fullscreen is identified only by the distinct exclusive backend mode. Keep/Revert and Alt+Enter use the same effective state, preserving the previous window dimensions rather than accidentally saving the monitor size as the windowed preference. Trial rollback restores borderless state too.
- `project.godot`: retains **canvas_items** with a **1280×720 logical design base**, explicitly uses **expand** and **fractional** scaling. The renderer scales uniformly and extends the logical viewport to fill other aspect ratios. The design base is not a fixed physical render rectangle.
- `scripts/ui/options_dialog.gd`: shows the effective display mode and retains the saved **windowed** resolution while fullscreen. Window-resolution choices are limited to the usable desktop area; fullscreen uses the entire monitor, including space otherwise occupied by taskbars.

No camera, player, battle host, SubViewport, collision, attack, audio, save, asset, menu styling or protected battle-entry implementation was changed. All **1,769** starting project files remain. No creative assets were created or modified.

Menus and exploration use the full native display. Portrait battles retain their original 540×900 simulation and aspect ratio, occupy the **full monitor height**, and retain their existing surrounding presentation. Filling a widescreen monitor's width with the portrait playfield would require cropping, distortion or changing gameplay; this fix does none of those.

## Verification

Actual standalone Godot **4.6.3** processes using X11 dummy displays, llvmpipe and the Compatibility renderer were tested, including the normal project main-scene bootstrap rather than only a replacement test MainLoop.

| Verification | Result |
|---|---|
| 1920×1080 native display | **76 checks, 0 failures**: real Settings Apply, repeated window/fullscreen/Alt+Enter cycles, actual window/framebuffer dimensions, coverage, uniform scaling, zoom and protected entry |
| 2560×1440 native display | **60 checks, 0 failures**: repeated mode switches, exact native client area, rendered pixel dimensions and proportional UI scaling |
| 1920×1200 native display (16:10) | **84 checks, 0 failures**: full coverage without letterboxing, window/fullscreen cycles, exploration, protected entry, full-height battle, and synchronized music pause/resume across a battle display switch |
| Process restart, 1920×1080 and 1920×1200 | **9 checks, 0 failures each**: fullscreen restores at native monitor size; switching back restores the saved 960×540 normal window |
| Normal application bootstrap | **Two consecutive launches each at 1920×1080 and 1920×1200**, **9 checks, 0 failures per launch**; OS `xwininfo` confirms **1920×1080 at (0,0)** and the actual game screenshot is **1920×1080** |
| Manual resize | 1600×1000: logical viewport **1280×800**, uniform **1.25×** stretch, no unused root bars |
| Existing display preference/rollback regression | **9 checks, 0 failures** |
| Headless menu/save/control regression | **59 checks, 0 failures** |
| Protected entry regression | **3,080 frame-dependent checks, 0 failures** |
| Music/hitbox regression | **37 checks, 0 failures** |
| Headless editor import | Passed, no script/shader import errors |
| Existing preservation audit | **2,769 checks**; source art/audio/layout and protected mechanics unchanged |

Mode-flag assertions were strengthened in the existing display/restart probes. The new `tests/fullscreen_scaling.gd` tests actual native geometry, rendered image dimensions, transformed viewport coverage and equal X/Y scaling. It also verifies the 75% exploration zoom increases measured world visibility and the portrait arena fills the monitor height without changing its internal resolution.

`tests/test_native_display_startup.py` launches the normal application twice, observes it using a temporary test-only autoload, captures its real rendered framebuffer and asks the OS for the window dimensions. It refuses to overwrite an existing `override.cfg` or fixture settings file and removes only its own temporary override. Run with a native display, isolated XDG directories and `CATSSAGA_TEST_PROFILE=1`; the OS geometry portion requires X11 `xwininfo`.

[Actual screenshots and OS geometry before/after](review/fullscreen-scaling/):

- [Standalone main menu at 1920×1080](review/fullscreen-scaling/standalone-main-menu-1920x1080.png)
- [Main menu at 2560×1440](review/fullscreen-scaling/main-menu-2560x1440.png)
- [Settings at 1920×1080](review/fullscreen-scaling/settings-1920x1080.png)
- [Exploration at 1920×1200](review/fullscreen-scaling/overworld-1920x1200.png)
- [Portrait battle at full 1200-pixel height](review/fullscreen-scaling/battle-1920x1200.png)
- [Proportional 1600×1000 window](review/fullscreen-scaling/windowed-1600x1000.png)

The **before** image is the actual 1280×720 framebuffer produced while the backend claimed fullscreen on the 1920×1080 monitor; it is not a full-monitor desktop composite. The accompanying native geometry records show the smaller centered OS window before and the native-size window after.

## Standalone launch and remaining limits

From the repository directory, launch `godot --path .` without `--editor` or an embedding parent. In Godot's editor, turn off **Embed Game on Play** in the Game view/run controls when checking native fullscreen, or use its standalone run option. The editor owns the size of its embedded host; enlarging an embedded preview is not verification of an independent fullscreen window.

The environment permits software-rendered native-window tests and real game framebuffer captures. Physical monitors, multiple monitors, OS DPI settings and Windows/macOS/Wayland still need manual verification; these results establish the tested X11 behavior. Existing ObjectDB/resource/RID shutdown warnings remain in some test processes. No platform export or new art/audio was introduced.
