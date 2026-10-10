"""Regression for modal touch capture, mobile settings, font glyphs and low-FPS intro.
This runs actual touch events on the desktop engine, never an Android emulator.
Use --exported after check_android_payload.py and --wide for a wider viewport.
"""
from pathlib import Path
import os, subprocess, sys, json
root=Path(__file__).resolve().parents[1]
exported='--exported' in sys.argv;wide='--wide' in sys.argv
name='mobile_ui_fix'+('_apk' if exported else '')+('_wide' if wide else '')+'_checks'
settings=root/'runtime'/(name+'-settings.json')
if settings.exists():settings.unlink()
env=os.environ.copy();env['APPDATA']=str(root/'runtime'/(name+'-appdata'));Path(env['APPDATA']).mkdir(exist_ok=True)
project=root/('runtime/android_apk_check' if exported else 'source')
cmd=[str(root.parent/'Godot_v4.7.2-stable_win64_console.exe'),'--position','-2000,-2000','--path',str(project),'--script',str(root/'source/tests/mobile_ui_fix_check.gd'),'--','--mobile-controls','--save-dir='+str(root/'runtime'/(name+'-saves')),'--settings-path='+str(settings),'--report-root='+str(root/'runtime'),'--report-name='+name]
if wide:cmd.append('--wide-mobile')
with (root/'runtime'/(name+'.log')).open('w',encoding='utf-8') as log:
 result=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=150,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
text=(root/'runtime'/(name+'.log')).read_text(encoding='utf-8');print(text[-3000:])
assert result.returncode==0 and 'ERROR:' not in text, name
report=json.loads((root/'runtime'/(name+'.json')).read_text(encoding='utf-8'));assert report['passed']
print(name,report['checks'],'PASS')
