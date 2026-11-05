"""Encode a continuous 1x review clip, excluding paused engine setup frames."""
import json
from pathlib import Path
import subprocess
import sys

def encode(input_path: Path, output_path: Path, report_path: Path):
    report=json.loads(report_path.read_text())
    assert report['passed'] and report['simulation_speed']==1
    streams=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=nb_frames,r_frame_rate','-of','json',str(input_path)]))['streams']
    assert streams[0]['r_frame_rate']=='24/1'
    frames=int(streams[0]['nb_frames'])
    gameplay=int(report['recorded_frames'])
    setup=frames-gameplay
    assert 0<=setup<=24, ('Unexpected setup duration',setup)
    # The game was stopped while preparing the normal simulation checkpoint
    # and settling the overview camera. Keep every subsequent gameplay frame.
    filters=f'trim=start_frame={setup},setpts=N/(24*TB),scale=out_color_matrix=bt709'
    subprocess.run(['ffmpeg','-y','-v','error','-i',str(input_path),'-vf',filters,'-r','24','-fps_mode','cfr','-c:v','libx264','-preset','fast','-crf','20','-pix_fmt','yuv420p','-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709','-an','-movflags','+faststart',str(output_path)],check=True)
    result=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=nb_frames','-of','json',str(output_path)]))
    assert int(result['streams'][0]['nb_frames'])==gameplay
    report['encoding']={'paused_setup_frames_removed':setup,'source_frames':frames,'delivered_frames':gameplay,'gameplay_frames_removed':0,'speed_changed':False}
    report_path.write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
    return report['encoding']

if __name__=='__main__':
    folder=Path(sys.argv[1])
    print(json.dumps(encode(folder/'playthrough.avi',folder/'playthrough.mp4',folder/'movie-results.json')))
