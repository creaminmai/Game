#!/usr/bin/env python3
"""Run the actual Godot renderer on a private local Xorg display and clean up."""
import argparse
import os
from pathlib import Path
import subprocess
import time

repo = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--output-dir', type=Path, default=repo / 'artifacts' / 'validation')
p.add_argument('--art-capture', action='store_true', help='Render the actual 3D scenes at larger size, without the HUD')
args = p.parse_args()
args.output_dir = args.output_dir.resolve()
args.output_dir.mkdir(parents=True, exist_ok=True)
runtime = repo / '.runtime'
runtime.mkdir(exist_ok=True)
env = os.environ.copy()
for key, child in [('XDG_DATA_HOME', 'visual-data'), ('XDG_CACHE_HOME', 'cache'), ('XDG_CONFIG_HOME', 'config')]:
    env[key] = str(runtime / child)
    Path(env[key]).mkdir(exist_ok=True)
env.update(DISPLAY=':98', LIBGL_ALWAYS_SOFTWARE='1')
with (runtime / 'xorg.log').open('w') as log:
    xorg = subprocess.Popen(['Xorg', ':98', '-config', str(repo / 'tools/xorg-dummy.conf'), '-logfile', str(runtime / 'Xorg.98.log'), '-nolisten', 'tcp', '-noreset'], stdout=log, stderr=subprocess.STDOUT)
    try:
        for _ in range(50):
            if xorg.poll() is not None:
                raise RuntimeError('Xorg exited; see .runtime/xorg.log')
            if subprocess.run(['xdpyinfo'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                break
            time.sleep(.1)
        else:
            raise RuntimeError('Xorg did not become ready')
        with (args.output_dir / 'engine.log').open('w') as engine_log:
            result = subprocess.run(['godot', '--path', str(repo / 'godot'), '--audio-driver', 'Dummy', '--script', ('tests/capture_art.gd' if args.art_capture else 'tests/test_scene.gd'), '--', '--qa', f'--output-dir={args.output_dir}'], env=env, stdout=engine_log, stderr=subprocess.STDOUT, timeout=180)
        text = (args.output_dir / 'engine.log').read_text()
        print(text)
        raise SystemExit(result.returncode if result.returncode else (1 if 'SCRIPT ERROR' in text or 'ERROR:' in text else 0))
    finally:
        xorg.terminate()
        try:
            xorg.wait(timeout=5)
        except subprocess.TimeoutExpired:
            xorg.kill()
            xorg.wait()
