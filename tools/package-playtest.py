#!/usr/bin/env python3
"""Verify the paired clean-source Android/Web delivery; no signing keys copied."""
import hashlib, json, subprocess, zipfile
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
android = repo/'artifacts/android'
web = repo/'artifacts/web'
a = json.loads((android/'build.json').read_text())
w = json.loads((web/'build.json').read_text())
for field in ['version','version_code','application_id','source_commit','features','godot']:
    assert a[field] == w[field], f'Android/Web mismatch: {field}'
assert not a['source_dirty'] and not w['source_dirty'], 'Rebuild both platforms from a clean commit'
for directory, manifest in [(android,a),(web,w)]:
    for name, info in manifest['files'].items():
        path = directory/name
        assert path.stat().st_size == info['bytes']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == info['sha256'], name
verification = json.loads((android/'verification.json').read_text())
assert verification['passed'] and verification['source_commit'] == a['source_commit']
assert verification['certificate_sha256'] == '58ef52f6279aedc86c8b4d59f6d68773e52dff19bad427ec75927bde24fec8c1'
subprocess.run(['python3',str(repo/'tools/package-mobile-web.py')],check=True)
bundle = repo/f"artifacts/mobile/SunshineHospital-Web-{w['version']}-{w['source_commit'][:7]}.zip"
with zipfile.ZipFile(bundle) as archive:
    assert archive.testzip() is None
    assert not any('keystore' in name or 'hospital_v2.json' in name for name in archive.namelist())
    embedded=json.loads(archive.read('햇살병원-iPhone체험/web/build.json'))
    assert embedded == w
apk = android/verification['apk']
report={key:a[key] for key in ['version','version_code','source_commit','features','godot','application_id']}
report.update(passed=True,source_dirty=False,development_certificate_sha256=verification['certificate_sha256'],android_hardware_tested=False,iphone_hardware_tested=False,files={})
for path in [apk,bundle]:
    report['files'][str(path.relative_to(repo))]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
target=repo/f"artifacts/mobile/delivery-{a['version']}-{a['source_commit'][:7]}.json"
target.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
