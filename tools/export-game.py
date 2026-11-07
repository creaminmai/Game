#!/usr/bin/env python3
"""Export Godot builds using official SHA-512-verified templates, without storing build products in source."""
import argparse, hashlib, json, os, shutil, subprocess, zipfile
from pathlib import Path
repo = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('target', choices=['Web','Android','iOS'])
args = p.parse_args()
version = subprocess.check_output(["godot","--version"],text=True).strip()
if not version.startswith("4.6.3.stable."): raise SystemExit("Godot 4.6.3 stable is required, found "+version)
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
entries = {'Web':['web_nothreads_release.zip'],'Android':['android_debug.apk','android_release.apk'],'iOS':['ios.zip']}[args.target]
with zipfile.ZipFile(archive) as z:
    for entry in entries:
        z.extract('templates/' + entry, runtime / 'godot-export')
env = os.environ.copy()
for key, folder in [('XDG_DATA_HOME','data'),('XDG_CACHE_HOME','cache'),('XDG_CONFIG_HOME','config')]:
    env[key] = str(runtime / folder)
    Path(env[key]).mkdir(exist_ok=True)
if args.target == 'iOS':
    native_templates = Path(env['XDG_DATA_HOME'])/'godot/export_templates/4.6.3.stable'
    native_templates.mkdir(parents=True,exist_ok=True)
    shutil.copy2(runtime/'godot-export/templates/ios.zip',native_templates/'ios.zip')
output = repo / 'artifacts' / args.target.lower()
output.mkdir(parents=True, exist_ok=True)
(output/'build.json').unlink(missing_ok=True)
entry = output / {'Web':'index.html','Android':'SunshineHospital-0.3.0-dev.apk','iOS':'SunshineHospital.zip'}[args.target]
if args.target == 'Android':
    subprocess.run(['python3',str(repo/'tools/setup-android.py')],check=True)
imported = subprocess.run(['godot','--headless','--path',str(repo/'godot'),'--editor','--import','--quit'],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
if imported.returncode or 'ERROR:' in imported.stdout:
    raise SystemExit(imported.stdout)
result = subprocess.run(['godot','--headless','--path',str(repo/'godot'),'--export-debug' if args.target == 'Android' else '--export-release',args.target,str(entry)], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
print(result.stdout)
if result.returncode or 'ERROR:' in result.stdout:
    raise SystemExit(result.returncode or 1)
if not entry.is_file(): raise SystemExit('Missing exported entry point')
subprocess.run(['godot','--headless','--path',str(repo/'godot'),'--script',str(repo/'tools/export-licenses.gd'),'--',str(output)],env=env,check=True)
print(f'Exported {args.target} to {output}')

source = subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
manifest = {'version':'0.3.0-dev','source_commit':source,'source_dirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=repo,text=True).strip()),'godot':subprocess.check_output(['godot','--version'],text=True).strip(),'target':args.target,'build_kind':'development debug signed APK' if args.target == 'Android' else 'release export','files':{f.name:{'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in output.iterdir() if f.is_file() and (f.name == entry.name or f.name == 'LICENSE-Godot.txt' or (args.target == 'Web' and f.suffix in ['.js','.wasm','.pck','.png','.svg','.html']))}}
(output/'build.json').write_text(json.dumps(manifest,indent=2))
for name, info in manifest['files'].items():
    (output/(name+'.sha256')).write_text(info['sha256']+'  '+name+'\n')
