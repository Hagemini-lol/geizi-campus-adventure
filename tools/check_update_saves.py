"""Exercise copies of old checkpoints, never the user's live save directory."""
from pathlib import Path
import hashlib, json, subprocess, os
root=Path(__file__).resolve().parents[1]
fixtures=root/'runtime/update-save-fixtures';fixtures.mkdir(exist_ok=True)
sources=[root/'存档/slot_1.json',root/'runtime/mobile_test_saves/slot_1.json',root/'runtime/story_check_saves/slot_2.json',root/'runtime/stream-recovery-saves/slot_1.json',root/'runtime/campaign-save-test/slot_1.json',root/'runtime/存读档验证/run4/slot_3.json']
checksums={}
for i,source in enumerate(sources):
    assert source.is_file(),source
    content=source.read_bytes();checksums[str(source)]=hashlib.sha256(content).hexdigest()
    (fixtures/f'checkpoint_{i+1}.json').write_bytes(content)
env=os.environ.copy();env['APPDATA']=str(root/'runtime/mobile-check-appdata')
engine=root.parent/'Godot_v4.7.2-stable_win64_console.exe'
for reader in [False,True]:
    args=[str(engine),'--position','-2000,-2000','--path',str(root/'runtime/android_apk_check'),'--script',str(root/'source/tests/update_save_check.gd'),'--','--fixture-dir='+str(fixtures),'--save-dir='+str(root/'runtime/update-save-target'),'--settings-path='+str(root/'runtime/update-save-settings.json')]
    if reader:args.append('--reader')
    with (root/'runtime'/('update-save-restart.log' if reader else 'update-save.log')).open('w',encoding='utf-8') as log:result=subprocess.run(args,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180)
    assert result.returncode==0,('Save compatibility test failed',reader)
    print('save restart' if reader else 'legacy save corpus','PASS',flush=True)
for source,checksum in checksums.items():assert hashlib.sha256(Path(source).read_bytes()).hexdigest()==checksum,source
print('All six source checkpoints untouched',flush=True)
