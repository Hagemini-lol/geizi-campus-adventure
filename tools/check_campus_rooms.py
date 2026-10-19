"""Exercise every mapped building, seating and actual rest/dining services."""
from pathlib import Path
import json,os,subprocess,sys,shutil,time
root=Path(__file__).resolve().parents[1];exported='--exported' in sys.argv
name='campus_rooms_apk' if exported else 'campus_rooms'
project=root/('runtime/android_apk_check' if exported else 'source')
if exported:
    (project/'tests').mkdir(exist_ok=True)
    shutil.copy2(root/'source/tests/relationship_check.gd',project/'tests/relationship_check.gd')
env=os.environ.copy();env['APPDATA']=str(root/'runtime'/(name+'-appdata'))
args=[str(root.parent/'Godot_v4.7.2-stable_win64_console.exe'),'--position','-2000,-2000','--path',str(project),'--script',str(root/'source/tests/campus_rooms_check.gd'),'--','--manual-story-checks','--save-dir='+str(root/'runtime'/(name+'-saves')),'--settings-path='+str(root/'runtime'/(name+'-settings.json')),'--mods-dir='+str(root/'runtime'/(name+'-mods')),'--report-path='+str(root/'runtime'/(name+'_checks.json'))]
logfile=root/'runtime'/(name+'-'+str(time.time_ns())+'.log')
with logfile.open('w',encoding='utf-8') as log:
    result=subprocess.run(args,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=500,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
text=logfile.read_text(encoding='utf-8');print(text[-10000:]);print('LOG',logfile.name)
assert result.returncode==0 and 'ERROR:' not in text,name
report=json.loads((root/'runtime'/(name+'_checks.json')).read_text(encoding='utf-8'));assert report['passed'];print(name,report['checks'],'PASS')
