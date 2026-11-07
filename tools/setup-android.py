#!/usr/bin/env python3
"""Pinned Linux x86_64 tools for Godot's non-Gradle development APK export.
No system install or license auto-acceptance. Downloads remain in .runtime/.
"""
import hashlib, os, platform, subprocess, tarfile, zipfile
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
runtime = repo / '.runtime'
downloads = runtime / 'downloads'
downloads.mkdir(parents=True, exist_ok=True)
if platform.system() != 'Linux' or platform.machine() != 'x86_64':
    raise SystemExit('This bootstrap is for Linux x86_64; on Mac use Android Studio SDK + JDK and the Godot Android preset.')

def fetch(name, url, sha):
    path = downloads / name
    if not path.exists():
        temporary = path.with_suffix('.downloading')
        subprocess.run(['curl','-fL','--max-time','300',url,'-o',str(temporary)],check=True)
        temporary.rename(path)
    if hashlib.sha256(path.read_bytes()).hexdigest() != sha:
        raise SystemExit(f'Checksum mismatch: {path}')
    return path

sdk = runtime / 'android-sdk'
for name, url, sha, destination in [
    ('android-build-tools-36.zip','https://dl.google.com/android/repository/build-tools_r36_linux.zip','5d9ac77fb6ff43d9da518a337b4fcf8f9097113df531d99ccefe80ef7ce8250b',sdk/'build-tools'/'36.0.0'),
    ('android-platform-tools.zip','https://dl.google.com/android/repository/platform-tools_r37.0.2-linux.zip','dfc80a84a6710e5674415d4b55ae599c01aa4961822f53097d747472f410f157',sdk/'platform-tools'),
]:
    with zipfile.ZipFile(fetch(name,url,sha)) as archive:
        for info in archive.infolist():
            parts = Path(info.filename).parts[1:]
            if '..' in parts: raise SystemExit('Unsafe archive entry')
            path = destination.joinpath(*parts)
            if info.is_dir(): path.mkdir(parents=True,exist_ok=True); continue
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(archive.read(info))
            path.chmod((info.external_attr >> 16) & 0o777 or 0o644)

jdk = fetch('jdk21.tar.gz','https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.9%2B10/OpenJDK21U-jdk_x64_linux_hotspot_21.0.9_10.tar.gz','810d3773df7e0d6c4394e4e244b264c8b30e0b05a0acf542d065fd78a6b65c2f')
with tarfile.open(jdk) as archive: archive.extractall(runtime/'java',filter='data')
java = runtime/'java'/'jdk-21.0.9+10'
# Keep one development key across updates. Never overwrite it or commit it.
key = runtime/'android-debug.keystore'
if not key.exists():
    subprocess.run([str(java/'bin/keytool'),'-genkeypair','-keystore',str(key),'-storepass','android','-alias','androiddebugkey','-keypass','android','-keyalg','RSA','-keysize','2048','-validity','10000','-dname','CN=Android Debug,O=Android,C=US'],check=True)
    key.chmod(0o600)
settings = runtime/'config'/'godot'/'editor_settings-4.6.tres'
settings.parent.mkdir(parents=True,exist_ok=True)
text = settings.read_text() if settings.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
values = {'export/android/java_sdk_path':str(java),'export/android/android_sdk_path':str(sdk),'export/android/debug_keystore':str(key),'export/android/debug_keystore_user':'androiddebugkey','export/android/debug_keystore_pass':'android'}
text = '\n'.join(line for line in text.splitlines() if not any(line.startswith(k+' =') for k in values))+'\n'
import json
text += ''.join(f'{k} = {json.dumps(v)}\n' for k,v in values.items())
settings.write_text(text)
print('Ready: JDK 21.0.9+10, Android build-tools 36.0.0, platform-tools 37.0.2; persistent local debug key.')
