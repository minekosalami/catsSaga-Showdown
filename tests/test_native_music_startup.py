#!/usr/bin/env python3
"""Exercise the real engine main-scene bootstrap, rather than change_scene()."""
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
override = root / "override.cfg"
# Never replace a developer's local override. Exclusive create also prevents races.
with override.open("x") as stream:
    stream.write('[autoload]\nMusicStartupProbe="*res://tests/native_music_startup.gd"\n')
try:
    result = subprocess.run(
        [os.environ.get("GODOT", "godot"), "--headless", "--audio-driver", "Dummy", "--path", str(root)],
        timeout=25,
        check=False,
    )
finally:
    override.unlink()
raise SystemExit(result.returncode)
