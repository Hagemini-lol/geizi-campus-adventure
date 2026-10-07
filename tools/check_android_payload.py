from pathlib import Path
import json, os, shutil, subprocess, sys, zipfile

game=Path(__file__).resolve().parents[1]
target=game/'runtime/android_apk_check'
target.mkdir(exist_ok=True)
with zipfile.ZipFile(game/'gei子的冒险.apk') as archive:
    for item in archive.infolist():
        if not item.filename.startswith('assets/') or item.is_dir():continue
        name=Path(item.filename.removeprefix('assets/'))
        assert not name.is_absolute() and '..' not in name.parts
        if name.parts[0]=='package':continue # Already verified against the source bytes.
        path=target/name;path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes(archive.read(item))
shutil.copytree(game/'android_source/package',target/'package',dirs_exist_ok=True)
engine=game.parent/'Godot_v4.7.2-stable_win64_console.exe'
wide='--wide-mobile' in sys.argv
command=[str(engine),'--position','-2000,-2000','--path',str(target),'--script',str(game/'source/tests/mobile_check.gd'),
    '--log-file',str(game/('runtime/android_payload_boot_wide.log' if wide else 'runtime/android_payload_boot.log')),'--','--mobile-controls',
    '--save-dir='+str(game/('runtime/mobile_apk_wide_test_saves' if wide else 'runtime/mobile_apk_test_saves')),
    '--settings-path='+str(game/('runtime/mobile_apk_wide_test_settings.json' if wide else 'runtime/mobile_apk_test_settings.json'))]
if wide:command.append('--wide-mobile')
env=os.environ.copy()
appdata=game/'runtime/mobile-check-appdata';appdata.mkdir(exist_ok=True)
env['APPDATA']=str(appdata)
result=subprocess.run(command,env=env)
assert result.returncode==0,'Exported Android resource payload failed touch/runtime checks'
report=json.loads((game/'runtime/android_package_checks.json').read_text(encoding='utf-8'))
report['exported_resource_payload_tested_with_desktop_engine']=True
report['exported_payload_touch_checks_wide' if wide else 'exported_payload_touch_checks']=json.loads((game/('runtime/mobile_checks_wide.json' if wide else 'runtime/mobile_checks.json')).read_text(encoding='utf-8'))['checks']
(game/'runtime/android_package_checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('ANDROID_EXPORTED_PAYLOAD_PASSED')
