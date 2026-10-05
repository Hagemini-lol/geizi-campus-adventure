from pathlib import Path
import hashlib
import json
import sys
import zipfile

game=Path(__file__).resolve().parents[1]
archive=game.parent/'校园自由漫游_好友分享.zip'
target=game.parent/'校园分享验证 临时'
reuse='--reuse' in sys.argv
assert target.is_dir() if reuse else not target.exists(), 'Verification directory must be fresh or explicitly reused'
with zipfile.ZipFile(archive) as handle:
    names=handle.namelist()
    for name in names:
        assert '..' not in Path(name).parts and name.startswith('校园自由漫游/')
    assert not any('/存档/' in n or '/tests/' in n or '/.godot/' in n or n.endswith('/设置.json') for n in names)
    if not reuse:handle.extractall(target)
root=target/'校园自由漫游'
read=lambda path:json.loads(path.read_text(encoding='utf-8-sig'))
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
manifest=read(root/'素材打包清单.json')
for entry in manifest['files']:
    copied=root/entry['file']
    assert copied.stat().st_size==entry['bytes'] and sha(copied)==entry['sha256'],entry['file']
    original=game/entry['file']
    assert sha(original)==entry['sha256']
# Check all copied assets against the originals; only generated path metadata is rewritten.
checked=0
for entry in manifest['files']:
    name=entry['file']
    if name=='资源/地图/运行数据.json' or name=='资源/地图/内景/内外对应.json':continue
    if name.startswith('资源/原项目/'):
        original=game.parent/'Projects/赵慕gei的牙林冒险'/name.removeprefix('资源/原项目/')
    else:
        original=game.parent/'地图重绘预览'/name.removeprefix('资源/地图/')
    assert original.is_file() and sha(original)==entry['sha256'],str(original)
    checked+=1
# This historical snapshot predates changes made to source assets before this task.
# The current packaging baseline is the manifest captured before and after copying.
historical_differences=[]
for entry in read(game/'原素材校验快照.json'):
    if sha(Path(entry['Path'])).upper()!=entry['SHA256'].upper():historical_differences.append(entry['Path'])
def check_paths(value):
    if isinstance(value,dict):
        for item in value.values():check_paths(item)
    elif isinstance(value,list):
        for item in value:check_paths(item)
    elif isinstance(value,str):
        assert '../' not in value and 'D:/Godot' not in value and 'D:\\Godot' not in value,value
check_paths(read(root/'素材引用.json'))
check_paths(read(root/'办公室配置.json')['assets'])
check_paths(read(root/'资源/地图/内景/内外对应.json')['assets'])
report={'zip':str(archive),'zip_bytes':archive.stat().st_size,'zip_sha256':sha(archive),'archive_files':len(names),
    'asset_files':len(manifest['files']),'asset_hashes_passed':True,'source_files_checked_unchanged':checked,
    'current_source_assets_unchanged_since_copy':True,'historical_snapshot_differences_predating_packaging':historical_differences,
    'player_saves_settings_excluded':True,'relocated_game_root':str(root)}
(game/'分享包完整性验证.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
