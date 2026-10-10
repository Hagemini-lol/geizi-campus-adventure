"""Exercise real mobile press/drag/lift sequences on source or APK payload."""
from pathlib import Path
import os, subprocess, sys, json, shutil
root=Path(__file__).resolve().parents[1]
exported='--exported' in sys.argv;wide='--wide' in sys.argv
name='touch_release'+('_apk' if exported else '')+('_wide' if wide else '')+'_checks'
project=root/('runtime/android_apk_check' if exported else 'source')
if exported:
    (project/'tests').mkdir(exist_ok=True)
    shutil.copy2(root/'source/tests/mobile_ui_fix_check.gd',project/'tests/mobile_ui_fix_check.gd')
env=os.environ.copy();env['APPDATA']=str(root/'runtime'/(name+'-appdata'));Path(env['APPDATA']).mkdir(exist_ok=True)
settings=root/'runtime'/(name+'-settings.json')
if settings.exists():settings.unlink()
cmd=[str(root.parent/'Godot_v4.7.2-stable_win64_console.exe'),'--position','-2000,-2000','--path',str(project),'--script',str(root/'source/tests/touch_release_check.gd'),'--','--mobile-controls','--manual-story-checks','--save-dir='+str(root/'runtime'/(name+'-saves')),'--settings-path='+str(settings),'--report-root='+str(root/'runtime'),'--report-name='+name]
if wide:cmd.append('--wide-mobile')
with (root/'runtime'/(name+'.log')).open('w',encoding='utf-8') as log:
    result=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=150,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
text=(root/'runtime'/(name+'.log')).read_text(encoding='utf-8');print(text[-5000:])
assert result.returncode==0 and 'ERROR:' not in text,name
report=json.loads((root/'runtime'/(name+'.json')).read_text(encoding='utf-8'));assert report['passed']
print(name,report['checks'],'PASS')
