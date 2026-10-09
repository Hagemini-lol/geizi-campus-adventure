from pathlib import Path
import os, subprocess, json, sys

root=Path(__file__).resolve().parents[1]
engine=root.parent/'Godot_v4.7.2-stable_win64_console.exe'
env=os.environ.copy();env['APPDATA']=str(root/'runtime/mobile-check-appdata')
names=sys.argv[1:] or ['clarity_check','campaign_save_check','campaign_behavior_check','campaign_check','stream_probe']
for name in names:
    log=root/'runtime'/f'{name}-1.2.1.log'
    with log.open('w',encoding='utf-8') as output:
        result=subprocess.run([str(engine),'--position','-2000,-2000','--path',str(root/'source'),'--script',f'res://tests/{name}.gd','--','--probe=after',*(['--manual-story-checks'] if name!='story_region_check' else []),
        '--mods-dir='+str(root/'runtime'/f'{name}-mods'),'--save-dir='+str(root/'runtime'/f'{name}-1.2.1-saves'),'--settings-path='+str(root/'runtime'/f'{name}-1.2.1-settings.json')],env=env,stdout=output,stderr=subprocess.STDOUT,timeout=420)
    text=log.read_text(encoding='utf-8',errors='replace')
    assert result.returncode==0 and 'SCRIPT ERROR:' not in text,(name,text[-3500:])
    print(name, 'PASS',text.splitlines()[-1][:800],flush=True)
