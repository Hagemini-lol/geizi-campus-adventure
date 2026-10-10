"""Re-run systems affected by the memoir/dialogue/gift update, with isolated data."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json, os, subprocess, sys
root=Path(__file__).resolve().parents[1]
names=sys.argv[1:] or ['campaign','campaign_behavior','campaign_save','sidequest','puzzle','campus_life','relationship','phone','story']
def run(name):
    env=os.environ.copy();env['APPDATA']=str(root/'runtime'/('v16-'+name+'-appdata'))
    display=['--position','-2000,-2000'] if name in ['phone','story'] else ['--headless']
    args=[str(root.parent/'Godot_v4.7.2-stable_win64_console.exe')]+display+['--path',str(root/'source'),
          '--script','res://tests/'+name+'_check.gd','--','--save-dir='+str(root/'runtime'/('v16-'+name+'-saves')),
          '--settings-path='+str(root/'runtime'/('v16-'+name+'-settings.json')),'--mods-dir='+str(root/'runtime'/('v16-'+name+'-mods')),'--manual-story-checks']
    logfile=root/'runtime'/('v16-'+name+'.log')
    with logfile.open('w',encoding='utf-8') as log:
        result=subprocess.run(args,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=210,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    text=logfile.read_text(encoding='utf-8')
    assert result.returncode==0 and 'SCRIPT ERROR' not in text and 'ERROR:' not in text,(name,text[-8000:])
    report=json.loads((root/'runtime'/(name+'_checks.json')).read_text(encoding='utf-8'));assert report['passed'],name
    print(name,report['checks'],'PASS',flush=True)
    return name,report['checks']
with ThreadPoolExecutor(max_workers=2) as pool:results=dict(pool.map(run,names))
report_file=root/'runtime/v16_fresh_content_checks.json'
saved=json.loads(report_file.read_text(encoding='utf-8')) if report_file.exists() else {}
saved.update(results);report_file.write_text(json.dumps(saved,indent=2)+'\n',encoding='utf-8')
