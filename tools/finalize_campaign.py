"""Verify local delivery without rebuilding ZIPs or touching player saves."""
from pathlib import Path
import hashlib, json, subprocess, os
from datetime import datetime

root=Path(__file__).resolve().parents[1]
read=lambda path:json.loads(path.read_text(encoding='utf-8-sig'))
def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        while block:=stream.read(1048576):h.update(block)
    return h.hexdigest()

reports={}
for name in ['campaign','balance','campaign_behavior','campaign_save','furniture_route','mobile','mobile_checks_wide','stream_recovery','update_save','update_save_checks_restart']:
    filename=name+'.json' if name in ['mobile_checks_wide','update_save_checks_restart'] else name+'_checks.json'
    result=read(root/'runtime'/filename)
    assert result['passed'],filename
    reports[name]=result
for source in (root/'source').glob('*.gd'):
    assert (root/'android_source'/source.name).read_bytes()==source.read_bytes(),source.name
personal=read(root/'runtime/personal-files-before-v1.2.2.json')
assert all(digest(root/name)==checksum for name,checksum in personal.items()),'Personal saves or settings were changed'
env=os.environ.copy();env['APPDATA']=str(root/'runtime/mobile-check-appdata')
result=subprocess.run([str(root/'gei子的冒险.exe'),'--smoke-test'],env=env,timeout=90)
log=(root/'runtime/smoke.log').read_text(encoding='utf-8',errors='replace')
assert result.returncode==0 and 'CAMPUS_READY' in log
errors=[line for line in log.splitlines() if 'ERROR:' in line and 'Failed to read the root certificate store' not in line]
assert not errors,errors
archive=root.parent/'gei子的冒险win.zip'
assert archive.stat().st_size==408939518
assert datetime.fromtimestamp(archive.stat().st_mtime).strftime('%Y-%m-%d %H:%M:%S')=='2026-10-05 17:56:18'
report={'game_version':(root/'VERSION').read_text(encoding='utf-8').strip(),'game_name':'gei子的冒险','windows_launcher_passed':True,'windows_pck_sha256':digest(root/'runtime/campus.pck'),'apk_sha256':digest(root/'gei子的冒险.apk'),'checks':reports,'performance_comparison':read(root/'runtime/stream_process_comparison.json'),'existing_zip':{'path':str(archive),'sha256':digest(archive),'bytes':archive.stat().st_size,'modified':False},'physical_phone_tested':False,'emulator_tested_this_version':False,'github_published':False,'original_assets_modified':False}
(root/'剧情续写完成检查.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'version':report['game_version'],'windows':True,'balance_cases':reports['balance']['checks'],'npc_checks':reports['campaign_behavior']['checks'],'emulator_tested_this_version':False,'apk':report['apk_sha256']},ensure_ascii=False))
