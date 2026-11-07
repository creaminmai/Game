#!/usr/bin/env python3
"""Inspect the APK, not a claim that it booted on Android hardware."""
import hashlib, json, os, re, subprocess, zipfile
from pathlib import Path
repo=Path(__file__).resolve().parents[1]
output=repo/'artifacts/android'
apk=output/'SunshineHospital-0.3.0-dev.apk'
tools=repo/'.runtime/android-sdk/build-tools/36.0.0'
env=os.environ.copy();env['JAVA_HOME']=str(repo/'.runtime/java/jdk-21.0.9+10')
def run(*args): return subprocess.check_output(list(map(str,args)),env=env,text=True,stderr=subprocess.STDOUT)
signature=run(tools/'apksigner','verify','--verbose','--print-certs',apk)
badging=run(tools/'aapt','dump','badging',apk)
tree=run(tools/'aapt','dump','xmltree',apk,'AndroidManifest.xml')
run(tools/'zipalign','-c','-P','16','4',apk)
assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in signature
assert 'Verified using v3 scheme (APK Signature Scheme v3): true' in signature
assert "name='org.creaminmai.sunshinehospital.playtest' versionCode='300' versionName='0.3.0-dev'" in badging
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
for name,text in [('signature.txt',signature),('manifest.txt',badging),('manifest-tree.txt',tree)]:
    (output/name).write_text(text)
devices=run(repo/'.runtime/android-sdk/platform-tools/adb','devices','-l')
(output/'devices.txt').write_text(devices)
report={'passed':True,'apk':apk.name,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'certificate_sha256':re.search(r'certificate SHA-256 digest: ([a-f0-9]+)',signature).group(1),'debug':True,'landscape':True,'min_sdk':24,'target_sdk':36,'architectures':['arm64-v8a','x86_64'],'alignment_16kb':True,'device_list':devices,'installation_tested':False,'android_runtime_tested':False,'store_release':False}
(output/'verification.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
