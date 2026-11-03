#!/usr/bin/env python3
"""Export Godot builds using official SHA-512-verified templates, without storing build products in source."""
import argparse, hashlib, os, subprocess, zipfile
from pathlib import Path
repo = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('target', choices=['Web'])
args = p.parse_args()
runtime = repo / '.runtime'
runtime.mkdir(exist_ok=True)
name = 'Godot_v4.6.3-stable_export_templates.tpz'
archive = runtime / name
expected = 'da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68'
if not archive.exists():
    temporary = archive.with_suffix('.downloading')
    subprocess.run(['curl', '-fL', '--max-time', '300', f'https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/{name}', '-o', str(temporary)], check=True)
    with temporary.open('rb') as f:
        if hashlib.file_digest(f, 'sha512').hexdigest() != expected:
            raise SystemExit('Godot template checksum mismatch; download not used')
    temporary.rename(archive)
with archive.open('rb') as f:
    if hashlib.file_digest(f, 'sha512').hexdigest() != expected:
        raise SystemExit('Godot template checksum mismatch; archive not used')
entries = ['web_nothreads_release.zip']
with zipfile.ZipFile(archive) as z:
    for entry in entries:
        z.extract('templates/' + entry, runtime / 'godot-export')
env = os.environ.copy()
for key, folder in [('XDG_DATA_HOME','data'),('XDG_CACHE_HOME','cache'),('XDG_CONFIG_HOME','config')]:
    env[key] = str(runtime / folder)
    Path(env[key]).mkdir(exist_ok=True)
output = repo / 'artifacts' / args.target.lower()
output.mkdir(parents=True, exist_ok=True)
entry = output / 'index.html'
result = subprocess.run(['godot','--headless','--path',str(repo/'godot'),'--export-release',args.target,str(entry)], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
print(result.stdout)
if result.returncode or 'ERROR:' in result.stdout:
    raise SystemExit(result.returncode or 1)
if not entry.is_file(): raise SystemExit('Missing exported entry point')
subprocess.run(['godot','--headless','--path',str(repo/'godot'),'--script',str(repo/'tools/export-licenses.gd'),'--',str(output)],env=env,check=True)
print(f'Exported {args.target} to {output}')
