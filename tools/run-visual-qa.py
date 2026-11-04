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
p.add_argument('--diagnose', action='store_true', help='Isolate AO, shadow and albedo contributions during art capture')
p.add_argument('--portraits', action='store_true', help='Also capture transparent portraits from the actual game characters')
p.add_argument('--movie', action='store_true', help='Record an actual engine playthrough and encode MP4')
p.add_argument('--brief', action='store_true', help='A shorter movie with 6x simulation and shorter reading pauses')
p.add_argument('--normal', action='store_true', help='54 seconds at normal 1x speed, with clearly labeled automatic input')
p.add_argument('--rehearsal', action='store_true', help='Run the normal-speed input scenario with fixed time but without rendering or a movie')
p.add_argument('--input-check', action='store_true', help='Quick Movie Maker input regression check')
args = p.parse_args()
if args.input_check and not args.movie:
    p.error('--input-check requires --movie')
if args.brief and not args.movie:
    p.error('--brief requires --movie')
if args.normal and (not args.movie or args.brief or args.input_check):
    p.error('--normal requires --movie and cannot be combined with --brief/--input-check')
if args.rehearsal and not args.normal:
    p.error('--rehearsal requires --normal')
if args.art_capture and args.movie:
    p.error('--art-capture and --movie are mutually exclusive')
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
        script = 'tests/record_play.gd' if args.movie else ('tests/capture_art.gd' if args.art_capture else 'tests/test_scene.gd')
        if args.normal: script = 'tests/record_normal.gd'
        command = ['godot', '--path', str(repo / 'godot'), '--audio-driver', 'Dummy', '--script', script]
        if args.rehearsal:
            command += ['--resolution','1280x720','--fixed-fps','24','--disable-render-loop']
        elif args.movie:
            command += ['--resolution', '1280x720', '--write-movie', str(args.output_dir / 'playthrough.avi'), '--fixed-fps', '24']
        command += ['--', '--qa', f'--output-dir={args.output_dir}']
        if args.input_check: command += ['--input-check']
        if args.diagnose: command += ['--diagnose']
        if args.portraits: command += ['--portraits']
        if args.brief: command += ['--brief']
        with (args.output_dir / 'engine.log').open('w') as engine_log:
            result = subprocess.run(command, env=env, stdout=engine_log, stderr=subprocess.STDOUT, timeout=1800 if args.movie else 240)
        text = (args.output_dir / 'engine.log').read_text()
        print(text)
        code = result.returncode if result.returncode else (1 if 'SCRIPT ERROR' in text or 'ERROR:' in text else 0)
        if code == 0 and args.movie and not args.input_check and not args.rehearsal:
            import json
            report = json.loads((args.output_dir / 'movie-results.json').read_text())
            if not report['passed']:
                raise SystemExit('Movie scenario failed')
            subprocess.run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-i', str(args.output_dir / 'playthrough.avi'), '-vf', 'scale=out_color_matrix=bt709', '-c:v', 'libx264', '-preset', 'fast', '-crf', '20', '-pix_fmt', 'yuv420p', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709', '-an', '-movflags', '+faststart', str(args.output_dir / 'playthrough.mp4')], check=True)
            subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration,size:stream=codec_name,width,height,r_frame_rate', '-of', 'json', str(args.output_dir / 'playthrough.mp4')], check=True)
        raise SystemExit(code)
    finally:
        xorg.terminate()
        try:
            xorg.wait(timeout=5)
        except subprocess.TimeoutExpired:
            xorg.kill()
            xorg.wait()
