#!/usr/bin/env python3
"""Measure original music with FFmpeg EBU R128; never alter source audio.

Optional --decoded-dir checks Godot's imported decoder output, generated with
render_music_audit.gd. EQ/bus routing must be measured separately at the mixer.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def measure(path, gain=0.0, rate=None):
    command = ["ffmpeg", "-hide_banner", "-nostats", "-xerror", "-v", "info"]
    if rate:
        command += ["-f", "f32le", "-ar", str(int(rate)), "-ac", "2"]
    command += ["-i", str(path), "-af", f"volume={gain}dB,loudnorm=I=-16:TP=-1:LRA=11:print_format=json", "-f", "null", "-"]
    result = subprocess.run(command, text=True, capture_output=True, check=True)
    # loudnorm's INPUT statistics describe the measured signal. Its dynamically
    # normalized OUTPUT is discarded; no limiting/normalization is baked in.
    start = result.stderr.rfind("{\n")
    stats = json.loads(result.stderr[start:result.stderr.index("}", start)+1])
    diagnostics = [line for line in result.stderr.splitlines() if any(word in line.lower() for word in ("error", "invalid", "corrupt"))]
    if diagnostics:
        raise RuntimeError("\n".join(diagnostics))
    return {"lufs":float(stats["input_i"]),"true_peak_dbtp":float(stats["input_tp"]),"lra_lu":float(stats["input_lra"])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--decoded-dir", type=Path)
    parser.add_argument("--overworld-mix", type=Path, help="Full live-route f32le capture at 44100 Hz")
    args = parser.parse_args()
    script = (ROOT/"scripts/systems/music.gd").read_text()
    gains = {path:float(gain) for path,gain in re.findall(r'"res://([^"\n]+\.(?:wav|mp3|ogg))":\s*(-?[\d.]+)',script)}
    files = sorted(p for p in (ROOT/"assets/soundtrack").iterdir() if p.suffix.lower() in (".wav",".mp3",".ogg",".flac"))
    files += [ROOT/"assets/fight.v.scale - catsSaga version.mp3"]
    assert {str(p.relative_to(ROOT)) for p in files} == set(gains), "Music catalog/gain mismatch"
    decoded = {}
    if args.decoded_dir:
        decoded = {r["path"]:r for r in json.loads((args.decoded_dir/"manifest.json").read_text())}
    def audit(path):
        relative = str(path.relative_to(ROOT))
        info = json.loads(subprocess.check_output(["ffprobe","-v","error","-show_entries","format=duration:stream=codec_name,sample_rate,channels","-of","json",str(path)],text=True))
        row = {"path":relative,"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"duration_seconds":float(info["format"]["duration"]),"format":info["streams"][0],"source":measure(path),"player_gain_db":gains[relative],"decode_errors":[]}
        # Overworld's retained EQ and -1.2 dB bus require the separate mixer
        # measurement documented in the review; raw decoding is not that route.
        if decoded:
            entry = decoded[relative]
            row["godot_decode_after_player_gain"] = measure(args.decoded_dir/entry["file"],gains[relative],entry["sample_rate"])
            if relative != "assets/soundtrack/Overworld - 002.mp3":
                row["routed_playback"] = row["godot_decode_after_player_gain"]
        if relative == "assets/soundtrack/Overworld - 002.mp3" and args.overworld_mix:
            row["routed_playback"] = measure(args.overworld_mix,rate=44100)
            row["route"] = "Existing Overworld clarity EQ and -1.2 dB bus -> unchanged Master"
        if "routed_playback" in row:
            assert row["routed_playback"]["true_peak_dbtp"] <= -1.0, relative+": peak ceiling exceeded"
        return row
    with ThreadPoolExecutor(max_workers=3) as pool:
        rows = list(pool.map(audit,files))
    args.output.write_text(json.dumps({"method":"FFmpeg loudnorm input statistics, EBU R128, true-peak oversampling; static Godot gain only", "tracks":rows},indent=2)+"\n")
    for row in rows:
        print(row["path"],row["source"],"gain",row["player_gain_db"],row.get("godot_decode_after_player_gain",{}))

if __name__ == "__main__":
    main()
