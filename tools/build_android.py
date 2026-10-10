from pathlib import Path
import hashlib, json, os, shutil, subprocess, sys, zipfile

game=Path(__file__).resolve().parents[1]
tools=game/'android_tools'
java=next((tools/'jdk').glob('*/bin/java.exe')).parent.parent
env=os.environ.copy();env['JAVA_HOME']=str(java)
temporary=game/'android_tools/temp';temporary.mkdir(exist_ok=True)
env['TEMP']=str(temporary);env['TMP']=str(temporary)
signing=tools/'signing'
credentials=signing/'credentials.json'
key=signing/'campus-release.keystore'
assert credentials.is_file() and key.is_file(),'Original release signing files are required; never generate a replacement key for an update'
secret=json.loads(credentials.read_text(encoding='utf-8'))
env['GODOT_ANDROID_KEYSTORE_RELEASE_PATH']=str(key)
env['GODOT_ANDROID_KEYSTORE_RELEASE_USER']=secret['alias']
env['GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD']=secret['password']
engine=game.parent/'Godot_v4.7.2-stable_win64_console.exe'
apk=game/'gei子的冒险.apk'
if '--verify-only' not in sys.argv:
    with (game/'runtime/android_export.log').open('w',encoding='utf-8') as log:
        result=subprocess.run([str(engine),'--headless','--path',str(game/'android_source'),'--export-release','Android',str(apk)],env=env,stdout=log,stderr=subprocess.STDOUT)
    assert result.returncode==0 and apk.is_file(),'Android export failed; inspect runtime/android_export.log'
assert apk.is_file(),'APK missing'
verify=subprocess.run([str(java/'bin/java.exe'),'-jar',str(tools/'sdk/build-tools/35.0.1/lib/apksigner.jar'),'verify','--verbose','--print-certs',str(apk)],capture_output=True,text=True,env=env)
(game/'runtime/android_signature.txt').write_text(verify.stdout+verify.stderr,encoding='utf-8')
assert verify.returncode==0,'APK signature validation failed'
signer_sha256='bb245f6fd4c7913545b3d0e846a21bb4450336d220cdffc1e081f5c2d01b2327'
assert 'Number of signers: 1' in verify.stdout
assert 'Signer #1 certificate SHA-256 digest: '+signer_sha256 in verify.stdout,'Update must use the original signing certificate'
# Windows aapt still mishandles non-ASCII APK paths; inspect an ASCII hard link.
ascii_apk=game.parent/'output/campus-android-inspection.apk'
ascii_apk.parent.mkdir(exist_ok=True)
if ascii_apk.exists():ascii_apk.unlink()
try:os.link(apk,ascii_apk)
except PermissionError:shutil.copy2(apk,ascii_apk)
metadata=subprocess.run([str(tools/'sdk/build-tools/35.0.1/aapt.exe'),'dump','badging',str(ascii_apk)],capture_output=True,text=True,encoding='utf-8',errors='replace')
ascii_apk.unlink()
assert metadata.returncode==0,metadata.stderr
assert "package: name='org.campus.gei.adventure'" in metadata.stdout,'Update package identity changed'
assert "versionCode='12'" in metadata.stdout and "versionName='1.6.1'" in metadata.stdout
(game/'runtime/android_manifest.txt').write_text(metadata.stdout,encoding='utf-8')
manifest=json.loads((game/'素材打包清单.json').read_text(encoding='utf-8-sig'))
with zipfile.ZipFile(apk) as archive:
    assert archive.testzip() is None
    names=archive.namelist()
    for item in manifest['files']:
        prefix='assets/package/'+item['file']
        assert hashlib.sha256(archive.read(prefix)).hexdigest()==item['sha256'],prefix
    for name in ['素材引用.json','战斗与刷新配置.json','办公室配置.json','剧情配置.json','任务配置.json','物资与交易配置.json','关系与攻略配置.json']:
        assert archive.read('assets/package/'+name)==(game/name).read_bytes()
    assert not any('credentials.json' in n or '.keystore' in n or '/存档/' in n or '/tests/' in n or n.endswith('/设置.json') for n in names)
report={'apk':str(apk),'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),
    'signature_verified':True,'asset_hashes_checked':len(manifest['files']),'configuration_files_checked':7,
    'saves_settings_signing_keys_excluded':True,'native_abis':[n.split('/')[1] for n in names if n.endswith('/libgodot_android.so')],
    'package':'org.campus.gei.adventure','signer_sha256':signer_sha256,'original_update_identity_verified':True,'physical_device_tested':False}
previous_report=game/'runtime/android_package_checks.json'
if '--verify-only' in sys.argv and previous_report.is_file():
    previous=json.loads(previous_report.read_text(encoding='utf-8'))
    if previous.get('sha256')==report['sha256']:
        for field in ['exported_resource_payload_tested_with_desktop_engine','exported_payload_touch_checks','exported_payload_touch_checks_wide']:
            if field in previous:report[field]=previous[field]
(game/'runtime/android_package_checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
