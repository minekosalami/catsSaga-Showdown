"""Verify unchanged source bytes, original assets, and protected gameplay files."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = "5f04f37"
source = ROOT / "assets/wonderland_human/rebuild"
manifest = json.loads((source / "provenance.json").read_text())
for item in manifest["files"]:
    assert hashlib.sha256((source / item["file"]).read_bytes()).hexdigest() == item["sha256"], item["file"]
audio_hash = (source / "audio/history.txt").read_text().split("SHA256: ")[1].strip()
assert hashlib.sha256((source / "audio/glass_clink.ogg").read_bytes()).hexdigest() == audio_hash
new_sheets = {item["file"] for item in manifest["files"] if item["file"].endswith(".png")}
assert new_sheets == {p.name for p in source.glob("*.png")}, "Unrecorded new art"
changes = subprocess.check_output(["git", "diff", "--name-only", BASE], cwd=ROOT, text=True).splitlines()
allowed = ("scenes/wonderland/", "scripts/wonderland/", "resources/wonderland/", "resources/maps/", "docs/", "tests/", "tools/", "shaders/wonderland_", "assets/wonderland_human/rebuild/")
exceptions = {"scripts/systems/session.gd", "scripts/systems/ambience.gd", "resources/ui/wonderland_asset_notices.tres"}
for path in changes:
    assert path in exceptions or path.startswith(allowed), "Unrelated original file changed: " + path
assert not subprocess.check_output(["git", "diff", "--name-only", "--diff-filter=MD", BASE, "--", "assets/"], cwd=ROOT), "Original asset changed"
assert not subprocess.check_output(["git", "diff", "--name-only", "--diff-filter=D", BASE], cwd=ROOT), "Original file deleted"
# Original encoded audio, including the approved ambush soundtrack, is untouched.
print(f"ASSET AUDIT: {len(manifest['files']) + 1} source hashes match; original assets/gameplay preserved")
