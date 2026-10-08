"""Append new runtime art while verifying every previously shipped asset."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
manifest_path=root/'素材打包清单.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8-sig'))
old=manifest['files'];known={f['file'] for f in old}
for f in old:
    assert sha(root/f['file'])==f['sha256'],f['file']
added=[]
for folder in [root/'资源/原项目/assets/characters/bosses',root/'资源/原项目/assets/characters/hero/battle/actions-v2']:
    for p in sorted(folder.rglob('*')):
        if not p.is_file() or p.suffix not in ['.png','.json']:continue
        rel=p.relative_to(root).as_posix()
        if rel not in known:added.append({'file':rel,'bytes':p.stat().st_size,'sha256':sha(p)})
manifest['files']+=added
manifest['file_count']=len(manifest['files']);manifest['total_bytes']=sum(f['bytes'] for f in manifest['files'])
manifest['source_files_preserved']=True
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report=root/'runtime/animation_assets.json'
data=json.loads(report.read_text(encoding='utf-8'))
for row in data:row['original']=row['original'].replace('资源/新增美术原图','美术生成记录')
report.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
baseline={name:sha(root/name) for name in ['存档/slot_1.json','设置.json']}
assert baseline==json.loads((root/'runtime/personal-files-before-v1.2.2.json').read_text(encoding='utf-8'))
archive=root.parent/'gei子的冒险win.zip'
result={'previous_asset_hashes_verified':len(old)-len(added),'added_runtime_art_files':len(added),'all_runtime_assets':manifest['file_count'],'personal_files_unchanged':True,'zip':{'path':str(archive),'bytes':archive.stat().st_size,'sha256':sha(archive),'mtime_ns':archive.stat().st_mtime_ns}}
(root/'runtime/expansion_preservation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
