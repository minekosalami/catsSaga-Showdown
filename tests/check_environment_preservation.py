"""Read-only preservation/provenance audit against the environmental checkpoint.

Run with Python 3 from any directory. No network, Godot import or writes occur.
This checks source preservation; gameplay/rendering need their runtime tests.
"""

import hashlib
import json
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[1]
BASE = "69771c5"
CHECKS = 0


def require(condition, message):
    global CHECKS
    CHECKS += 1
    if not condition:
        raise SystemExit("FAIL: " + message)


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def functions(source):
    matches = list(re.finditer(r"^func (\w+)\([^\n]*", source, re.M))
    return {
        match[1]: source[match.start():matches[i + 1].start()
                         if i + 1 < len(matches) else len(source)].strip()
        for i, match in enumerate(matches)
    }


def protected(name):
    # The new journey art/layout, exploration camera/input and save/menu labels
    # are intentionally edited. Combat, archived content and display are not.
    return (
        name.startswith(("assets/", "data/", "shaders/"))
        or name.startswith("resources/") and not name.startswith("resources/journey/")
        or name.startswith("scenes/")
        and not name.startswith("scenes/journey/")
        and name != "scenes/world/save_statue.tscn"
        or name.startswith(("scripts/boss2/", "scripts/blankkitten/",
                            "scripts/incarna/", "scripts/wonderland/",
                            "scripts/world/cave", "scripts/systems/", "scripts/ui/"))
        and name not in ("scripts/systems/session.gd", "scripts/ui/pause_menu.gd")
        or name in ("project.godot", "export_presets.cfg", "default_bus_layout.tres",
                    "scripts/main.gd", "scripts/boss.gd", "scripts/enemy.gd",
                    "scripts/enemybullet.gd", "scripts/rainbow_beam.gd")
    )


entries = []
for record in git("ls-tree", "-rz", "--full-tree", BASE).split(b"\0"):
    if record:
        metadata, encoded_name = record.split(b"\t", 1)
        mode, kind, oid = metadata.decode().split()
        name = encoded_name.decode()
        require(kind == "blob", f"Unexpected non-file checkpoint entry: {name}")
        require((ROOT / name).is_file(), f"Original file removed: {name}")
        entries.append((name, oid))

# One streaming Git process avoids hundreds of subprocesses and never collects
# the entire original asset library in memory. These are Git object bytes, not
# a second working checkout that could already contain the same edited files.
preserved = 0
assets = 0
with subprocess.Popen(["git", "cat-file", "--batch"], cwd=ROOT,
                      stdin=subprocess.PIPE, stdout=subprocess.PIPE) as objects:
    for name, oid in entries:
        if not protected(name):
            continue
        objects.stdin.write((oid + "\n").encode())
        objects.stdin.flush()
        header = objects.stdout.readline().decode().split()
        require(len(header) == 3 and header[1] == "blob", f"Missing Git blob: {name}")
        size = int(header[2])
        original = objects.stdout.read(size)
        require(objects.stdout.read(1) == b"\n", f"Invalid Git blob boundary: {name}")
        require((ROOT / name).read_bytes() == original, f"Protected source changed: {name}")
        preserved += 1
        assets += name.startswith("assets/")
    objects.stdin.close()
    objects.wait()
    require(objects.returncode == 0, "Git object reader failed")

session = "scripts/systems/session.gd"
before = functions(git("show", f"{BASE}:{session}").decode())
after = functions((ROOT / session).read_text())
entry_methods = ["transition_to", "_battle_entry", "_freeze_entry_tree",
                 "restore_suspended_modes", "begin_battle", "begin_encounter",
                 "begin_blankkitten_battle"]
for method in entry_methods:
    require(method in before and method in after, f"Missing protected entry method: {method}")
    require(before[method] == after[method], f"Protected entry method changed: {method}")

# The confirmed Boss 2 interaction repair makes the existing centralized debug
# override apply to its progression gate. Nothing else in encounter setup moves.
boss2 = "begin_boss2_battle"
gate = 'story_flags.get("flooded_forest_key_obtained", false)'
require(after[boss2] == before[boss2].replace(
    "not " + gate, "not region_access_allowed(" + gate + ")", 1),
    "Boss 2 setup changed beyond its centralized progression-gate repair")

source_count = 0
for directory in ("assets/environment_human/lpc", "assets/environment_human/lpc_revised"):
    folder = ROOT / directory
    records = json.loads((folder / "provenance.json").read_text())["files"]
    require(bool(records), f"Empty source manifest: {directory}")
    names = set()
    for record in records:
        name = record["file"]
        require(name not in names and Path(name).name == name,
                f"Duplicate or unsafe manifest filename: {name}")
        names.add(name)
        require(hashlib.sha256((folder / name).read_bytes()).hexdigest() == record["sha256"],
                f"Original source bytes differ from provenance: {directory}/{name}")
        source_count += 1
require(source_count == 21, "Expected all 21 original forest source files")

star = ROOT / "assets/save_star_human/star.png"
star_digest = "7cef301325d50f5b30dde827bb11da147753ac93ae2f4b310a5ba1d56217a1dc"
require(hashlib.sha256(star.read_bytes()).hexdigest() == star_digest,
        "Kenney's original save-star PNG changed")
require(star_digest in (star.parent / "README.md").read_text(),
        "Save-star provenance notice does not record its source hash")

print(f"ENVIRONMENT PRESERVATION: {CHECKS} checks passed; "
      f"all {len(entries)} checkpoint files retained; "
      f"{preserved} protected files unchanged, including all {assets} original asset files; "
      f"{len(entry_methods)} entry methods unchanged; "
      f"{source_count} forest source hashes and Kenney save-star hash verified.")
