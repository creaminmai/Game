#!/usr/bin/env python3
"""Inspect the APK, not a claim that it booted on Android hardware."""
import hashlib, json, os, re, subprocess, zipfile
from pathlib import Path
repo=Path(__file__).resolve().parents[1]
output=repo/'artifacts/android'
build=json.loads((output/'build.json').read_text())
apk=output/next(name for name in build['files'] if name.endswith('.apk'))
previous=json.loads((output/'verification.json').read_text()) if (output/'verification.json').exists() else {}
tools=repo/'.runtime/android-sdk/build-tools/36.0.0'
env=os.environ.copy();env['JAVA_HOME']=str(repo/'.runtime/java/jdk-21.0.9+10')
def run(*args): return subprocess.check_output(list(map(str,args)),env=env,text=True,stderr=subprocess.STDOUT)
signature=run(tools/'apksigner','verify','--verbose','--print-certs',apk)
badging=run(tools/'aapt','dump','badging',apk)
tree=run(tools/'aapt','dump','xmltree',apk,'AndroidManifest.xml')
run(tools/'zipalign','-c','-P','16','4',apk)
assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in signature
assert 'Verified using v3 scheme (APK Signature Scheme v3): true' in signature
assert f"name='{build['application_id']}' versionCode='{build['version_code']}' versionName='{build['version']}'" in badging
assert "application-label:'햇살병원 체험'" in badging
assert "sdkVersion:'24'" in badging and "targetSdkVersion:'36'" in badging
assert 'android:screenOrientation(0x0101001e)=(type 0x10)0x0' in tree
assert 'android:debuggable(0x0101000f)=(type 0x12)0xffffffff' in tree
with zipfile.ZipFile(apk) as z:
    assert z.testzip() is None
    names=z.namelist()
    assert len(names)==len(set(names))
    assert 'lib/arm64-v8a/libgodot_android.so' in names and 'lib/x86_64/libgodot_android.so' in names
    assert not any('/tests/' in n for n in names)
    for script in ['chapter_progress','chapter_panel','admission_duty','operations_training']:
        assert any(script in n for n in names), 'Missing production feature script: '+script
for name,text in [('signature.txt',signature),('manifest.txt',badging),('manifest-tree.txt',tree)]:
    (output/name).write_text(text)
devices=run(repo/'.runtime/android-sdk/platform-tools/adb','devices','-l')
(output/'devices.txt').write_text(devices)
report={'passed':True,'apk':apk.name,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'certificate_sha256':re.search(r'certificate SHA-256 digest: ([a-f0-9]+)',signature).group(1),'debug':True,'landscape':True,'min_sdk':24,'target_sdk':36,'architectures':['arm64-v8a','x86_64'],'alignment_16kb':True,'device_list':devices,'installation_tested':False,'android_runtime_tested':False,'store_release':False}
report['version']=build['version'];report['source_commit']=build['source_commit'];report['features']=build['features']
if previous.get('certificate_sha256'):
    assert report['certificate_sha256']==previous['certificate_sha256'], 'Development signing identity changed'
    report['same_development_signer_as_previous']=True
(output/'verification.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
