"""Build current common source for both platforms, preserving player data."""
from pathlib import Path
import os, subprocess, sys
root=Path(__file__).resolve().parents[1]
engine=root.parent/'Godot_v4.7.2-stable_win64_console.exe'
env=os.environ.copy();env['APPDATA']=str(root/'runtime/v16-build-appdata')
commands=[
 ('source-import',[str(engine),'--headless','--path',str(root/'source'),'--editor','--import','--quit']),
 ('windows-pack',[str(engine),'--headless','--path',str(root/'source'),'--export-pack','WindowsPack',str(root/'runtime/campus.pck')]),
 ('launcher',[sys.executable,str(root/'tools/build_launcher.py')]),
 ('android-import',[str(engine),'--headless','--path',str(root/'android_source'),'--editor','--import','--quit']),
 ('android',[sys.executable,str(root/'tools/build_android.py')]),
]
for name,args in commands:
    with (root/'runtime'/('v16-build-'+name+'.log')).open('w',encoding='utf-8') as log:
        result=subprocess.run(args,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=600,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    assert result.returncode==0,(name,'see runtime/v16-build-'+name+'.log')
    print(name,'PASS',flush=True)
