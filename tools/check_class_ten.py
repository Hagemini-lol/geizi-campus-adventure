"""Run story/gift/dialogue regressions in isolated player directories."""
from pathlib import Path
import os, subprocess, sys, json, shutil
root=Path(__file__).resolve().parents[1]
exported='--exported' in sys.argv
name='class_ten_apk' if exported else 'class_ten'
project=root/'runtime/android_apk_check' if exported else root/'source'
if exported:
    # Only the test harness is added to the extracted QA directory. Game code
    # and seven configurations remain exactly those verified inside the APK.
    (project/'tests').mkdir(exist_ok=True)
    for helper in ['class_ten_check.gd','sidequest_check.gd','puzzle_solver.gd']:
        shutil.copy2(root/'source/tests'/helper,project/'tests'/helper)
env=os.environ.copy();env['APPDATA']=str(root/'runtime/class-ten-appdata')
with (root/'runtime'/(name+'.log')).open('w',encoding='utf-8') as log:
    result=subprocess.run([str(root.parent/'Godot_v4.7.2-stable_win64_console.exe'),'--headless','--path',str(project),
        '--script','res://tests/class_ten_check.gd','--','--mobile-controls','--save-dir='+str(root/'runtime'/(name+'-saves')),
        '--settings-path='+str(root/'runtime'/(name+'-settings.json')),'--mods-dir='+str(root/'runtime'/(name+'-mods')),
        '--report-path='+str(root/'runtime'/(name+'_checks.json'))],
        env=env,stdout=log,stderr=subprocess.STDOUT,timeout=240,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
if result.returncode:
    print((root/'runtime'/(name+'.log')).read_text(encoding='utf-8')[-16000:]);sys.exit(result.returncode)
report=json.loads((root/'runtime'/(name+'_checks.json')).read_text(encoding='utf-8'));assert report['passed']
print(name,report['checks'],'PASS')
