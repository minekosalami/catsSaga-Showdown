#!/usr/bin/env python3
"""Run the unmodified main-scene bootstrap twice on an actual native display.
Requires CATSSAGA_TEST_PROFILE=1 and isolated XDG_DATA_HOME/XDG_CONFIG_HOME.
"""
import os
from pathlib import Path
import subprocess
import threading

if os.environ.get("CATSSAGA_TEST_PROFILE") != "1" or not os.environ.get("XDG_DATA_HOME"):
    raise SystemExit("Use CATSSAGA_TEST_PROFILE=1 and an isolated XDG_DATA_HOME.")
root = Path(__file__).resolve().parents[1]
output = Path(os.environ.get("CATSSAGA_DISPLAY_OUTPUT", "/tmp/catsSaga-native-display"))
output.mkdir(parents=True, exist_ok=True)
prefs = Path(os.environ["XDG_DATA_HOME"]) / "godot/app_userdata/catsSaga()/settings.cfg"
# An occupied profile is deliberately never replaced by this fixture writer.
prefs.parent.mkdir(parents=True, exist_ok=True)
with prefs.open("x") as stream:
    stream.write('[settings]\ndisplay_mode=1\nwindow_size=Vector2i(960, 540)\nwindow_position=Vector2i(100, 100)\n')
override = root / "override.cfg"
# Existing developer overrides must never be overwritten, even on test failure.
with override.open("x") as stream:
    stream.write('[autoload]\nNativeDisplayProbe="*res://tests/native_display_startup.gd"\n')
try:
    for attempt in (1, 2):
        env = os.environ.copy()
        env["CATSSAGA_DISPLAY_CAPTURE"] = str(output / f"native-startup-{attempt}.png")
        with (output / f"native-startup-{attempt}.log").open("w") as log:
            process = subprocess.Popen(
                [os.environ.get("GODOT", "godot"), "--path", str(root),
                 "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy"],
                env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            )
            timeout = threading.Timer(60, process.kill)
            timeout.start()
            try:
                for line in process.stdout:
                    log.write(line)
                    if "NATIVE DISPLAY READY" in line:
                        geometry = subprocess.check_output(["xwininfo", "-root", "-tree"], env=env, text=True)
                        (output / f"native-startup-{attempt}-geometry.txt").write_text(geometry)
                result = process.wait(timeout=15)
            finally:
                timeout.cancel()
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=10)
        print(f"normal main-scene launch {attempt}: exit {result}", flush=True)
        if result:
            raise SystemExit(result)
finally:
    override.unlink()
