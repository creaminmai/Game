#!/usr/bin/env python3
"""Run the actual Godot renderer on a private local Xorg display and clean up."""
import argparse
import os
from pathlib import Path
import subprocess
import time
import tempfile
import fcntl

repo = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--output-dir', type=Path, default=repo / 'artifacts' / 'validation')
p.add_argument('--art-capture', action='store_true', help='Render the actual 3D scenes at larger size, without the HUD')
p.add_argument('--diagnose', action='store_true', help='Isolate AO, shadow and albedo contributions during art capture')
p.add_argument('--portraits', action='store_true', help='Also capture transparent portraits from the actual game characters')
p.add_argument('--movie', action='store_true', help='Record an actual engine playthrough and encode MP4')
p.add_argument('--brief', action='store_true', help='A shorter movie with 6x simulation and shorter reading pauses')
p.add_argument('--motion-capture', action='store_true', help='Capture actual intermediate couch poses for visual review')
p.add_argument('--motion', choices=['admission','therapy','dual'], help='Normal 1x motion segment from a real simulation checkpoint')
p.add_argument('--mobile-preview', action='store_true', help='Record compact safe-area layout; Linux engine, not a mobile device')
p.add_argument('--performance', action='store_true', help='Measure actual frame time without Movie Maker/fixed FPS')
p.add_argument('--mobile-check', action='store_true', help='Actual renderer: safe areas, touch-sized UI and input regression')
p.add_argument('--staff-check', action='store_true', help='Admission delegation UI at four landscape sizes')
p.add_argument('--capacity-portraits',action='store_true')
p.add_argument('--capacity-check',action='store_true')
p.add_argument('--capacity',choices=['booking','flow','journal'])
p.add_argument('--planner-portrait',action='store_true')
p.add_argument('--researcher-portrait',action='store_true')
p.add_argument('--research-check',action='store_true')
p.add_argument('--research',choices=['building','progress','application'])
p.add_argument('--operations-check',action='store_true')
p.add_argument('--operations',choices=['education','flow','completion'])
p.add_argument('--chapter-check', action='store_true', help='Chapter goals, story and journal at four landscape sizes')
p.add_argument('--chapter', choices=['journal','annex','completion'], help='Normal 1x chapter progression segment')
p.add_argument('--staff', choices=['offer','flow','restore'], help='Normal 1x admission delegation segment')
p.add_argument('--story-check', action='store_true', help='Verify the first-day story through actual GUI input')
p.add_argument('--story', choices=['welcome','completion','ending'], help='Normal 1x first-day tutorial/story recording')
p.add_argument('--polish', choices=['welcome','expansion','journal'], help='Normal 1x improved first-day play, annex and journal')
p.add_argument('--normal', action='store_true', help='54 seconds at normal 1x speed, with clearly labeled automatic input')
p.add_argument('--rehearsal', action='store_true', help='Run the normal-speed input scenario with fixed time but without rendering or a movie')
p.add_argument('--input-check', action='store_true', help='Quick Movie Maker input regression check')
args = p.parse_args()
if args.research and (not args.movie or args.operations or args.chapter or args.staff or args.normal or args.motion or args.story or args.polish or args.brief or args.input_check):
    p.error('--research requires --movie alone')
if args.staff and (not args.movie or args.normal or args.motion or args.story or args.polish or args.brief or args.input_check):
    p.error('--staff requires --movie alone')
if args.chapter and (not args.movie or args.staff or args.normal or args.motion or args.story or args.polish or args.brief or args.input_check):
    p.error('--chapter requires --movie alone')
if args.operations and (not args.movie or args.chapter or args.staff or args.normal or args.motion or args.story or args.polish or args.brief or args.input_check):
    p.error('--operations requires --movie alone')
if args.input_check and not args.movie:
    p.error('--input-check requires --movie')
if args.brief and not args.movie:
    p.error('--brief requires --movie')
if args.normal and (not args.movie or args.brief or args.input_check):
    p.error('--normal requires --movie and cannot be combined with --brief/--input-check')
if args.motion and (not args.movie or args.normal or args.brief or args.input_check):
    p.error('--motion requires --movie alone')
if args.story and (not args.movie or args.normal or args.motion or args.brief or args.input_check or args.story_check):
    p.error('--story requires --movie alone')
if args.polish and (not args.movie or args.normal or args.motion or args.story or args.brief or args.input_check or args.story_check):
    p.error('--polish requires --movie alone')
if args.rehearsal and not (args.normal or args.motion or args.story or args.polish or args.staff or args.chapter or args.operations or args.research or args.capacity):
    p.error('--rehearsal requires --normal, --motion or --story')
if args.art_capture and args.movie:
    p.error('--art-capture and --movie are mutually exclusive')
args.output_dir = args.output_dir.resolve()
args.output_dir.mkdir(parents=True, exist_ok=True)
runtime = repo / '.runtime'
runtime.mkdir(exist_ok=True)
qa_lock=(runtime/'visual-qa.lock').open('w')
try:
    fcntl.flock(qa_lock,fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    raise SystemExit('Another visual QA job is using :98; finish it first.')
env = os.environ.copy()
for key, child in [('XDG_DATA_HOME', 'visual-data'), ('XDG_CACHE_HOME', 'cache'), ('XDG_CONFIG_HOME', 'config')]:
    env[key] = str(runtime / child)
    Path(env[key]).mkdir(exist_ok=True)
env.update(DISPLAY=':98', LIBGL_ALWAYS_SOFTWARE='1')
# Movie Maker chooses its writer size from project window overrides before a
# SceneTree script can resize. Stage only that config; all source/assets are
# the actual repository files. Never edit the live project during recording.
staged = None
project = repo/'godot'
if args.mobile_preview and args.movie:
    staged = tempfile.TemporaryDirectory(prefix='mobile-movie-',dir=runtime)
    project = Path(staged.name)
    for child in (repo/'godot').iterdir():
        if child.name != 'project.godot': (project/child.name).symlink_to(child,target_is_directory=child.is_dir())
    config=(repo/'godot/project.godot').read_text().replace('window_width_override=1280','window_width_override=844').replace('window_height_override=720','window_height_override=390')
    (project/'project.godot').write_text(config)
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
        if args.motion: script = 'tests/record_motion.gd'
        if args.story_check: script = 'tests/test_story_ui.gd'
        if args.mobile_check: script = 'tests/test_mobile_ui.gd'
        if args.staff_check: script = 'tests/test_staff_ui.gd'
        if args.capacity_portraits: script = 'tests/capture_capacity_portraits.gd'
        if args.capacity_check: script = 'tests/test_capacity_ui.gd'
        if args.capacity: script = 'tests/record_capacity.gd'
        if args.planner_portrait: script = 'tests/capture_planner.gd'
        if args.researcher_portrait: script = 'tests/capture_researcher.gd'
        if args.research_check: script = 'tests/test_research_ui.gd'
        if args.research: script = 'tests/record_research.gd'
        if args.operations_check: script = 'tests/test_operations_ui.gd'
        if args.operations: script = 'tests/record_operations.gd'
        if args.chapter_check: script = 'tests/test_chapter_ui.gd'
        if args.chapter: script = 'tests/record_chapters.gd'
        if args.staff: script = 'tests/record_staff_admission.gd'
        if args.performance: script = 'tests/measure_mobile_preflight.gd'
        if args.story: script = 'tests/record_story.gd'
        if args.polish: script = 'tests/record_first_day_polish.gd'
        if args.motion_capture: script = 'tests/capture_motion.gd'
        command = ['godot', '--path', str(project), '--audio-driver', 'Dummy', '--script', script]
        if args.rehearsal:
            command += ['--resolution','844x390' if args.mobile_preview else '1280x720','--fixed-fps','24','--disable-render-loop']
        elif args.movie:
            command += ['--resolution', '844x390' if args.mobile_preview else '1280x720', '--write-movie', str(args.output_dir / 'playthrough.avi'), '--fixed-fps', '24']
        command += ['--', '--qa', f'--output-dir={args.output_dir}']
        if args.story_check or args.mobile_check or args.story or args.polish or args.staff_check or args.staff or args.chapter_check or args.chapter or args.operations_check or args.operations or args.research_check or args.research or args.capacity_check or args.capacity: command += ['--tutorial']
        if args.chapter: command += [f'--segment={args.chapter}']
        if args.operations: command += [f'--segment={args.operations}']
        if args.capacity: command += [f'--segment={args.capacity}']
        if args.research: command += [f'--segment={args.research}']
        if args.staff: command += [f'--segment={args.staff}']
        if args.polish: command += [f'--segment={args.polish}']
        if args.mobile_preview: command += ['--mobile-preview']
        if args.story: command += [f'--segment={args.story}']
        if args.motion: command += [f'--segment={args.motion}']
        if args.input_check: command += ['--input-check']
        if args.diagnose: command += ['--diagnose']
        if args.portraits: command += ['--portraits']
        if args.brief: command += ['--brief']
        import json
        (args.output_dir/'launch.json').write_text(json.dumps({'argv':command,'platform':'Linux llvmpipe','physical_mobile':False,'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),'source_dirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=repo,text=True).strip()),'software_render_threads':env.get('LP_NUM_THREADS','default')},indent=2))
        with (args.output_dir / 'engine.log').open('w') as engine_log:
            result = subprocess.run(command, env=env, stdout=engine_log, stderr=subprocess.STDOUT, timeout=1800 if args.movie else (600 if args.operations_check or args.research_check or args.capacity_check else 240))
        text = (args.output_dir / 'engine.log').read_text()
        print(text)
        code = result.returncode if result.returncode else (1 if 'SCRIPT ERROR' in text or 'ERROR:' in text else 0)
        if code == 0 and args.movie and not args.input_check and not args.rehearsal:
            import json
            report = json.loads((args.output_dir / 'movie-results.json').read_text())
            if not report['passed']:
                raise SystemExit('Movie scenario failed')
            if args.motion or args.story or args.polish or args.staff or args.chapter or args.operations or args.research or args.capacity:
                from encode_motion import encode
                encode(args.output_dir/'playthrough.avi', args.output_dir/'playthrough.mp4', args.output_dir/'movie-results.json')
            else:
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
        if staged is not None: staged.cleanup()
