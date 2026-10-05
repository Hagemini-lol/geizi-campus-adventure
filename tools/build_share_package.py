from pathlib import Path
import hashlib
import json
import re
import shutil
import zipfile

game=Path(__file__).resolve().parents[1]
original=game.parent/'Projects/赵慕gei的牙林冒险'
maps=game.parent/'地图重绘预览'
resources=game/'资源'
entries=[]

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def copy(source,target):
    target.parent.mkdir(parents=True,exist_ok=True)
    before=digest(source)
    shutil.copy2(source,target)
    assert digest(target)==before and digest(source)==before
    entries.append({'file':target.relative_to(game).as_posix(),'bytes':target.stat().st_size,'sha256':before})
def copy_tree(source,target):
    for path in sorted(source.rglob('*')):
        if path.is_file() and path.suffix not in ('.import',):copy(path,target/path.relative_to(source))

def assemble_assets():
    for folder in ['assets','data','scripts/ui','scenes/ui']:
        copy_tree(original/folder,resources/'原项目'/folder)
    for folder in ['静态区块','内景','高清区块']:
        copy_tree(maps/folder,resources/'地图'/folder)
    copy(maps/'运行数据.json',resources/'地图/运行数据.json')
    info=read(resources/'地图/内景/内外对应.json')
    for key,path in info['assets'].items():
        relative=Path(path).relative_to(original)
        info['assets'][key]=(Path('资源/原项目')/relative).as_posix()
    write(resources/'地图/内景/内外对应.json',info)
    model=read(resources/'地图/运行数据.json')
    for region in model['regions']:
        region.pop('reference',None)
        region['status']='packaged'
    write(resources/'地图/运行数据.json',model)
    config=read(game/'素材引用.json')
    backup=game/'runtime/打包前素材引用.json'
    if not backup.exists():write(backup,config)
    def local(value):
        if isinstance(value,dict):return {k:local(v) for k,v in value.items()}
        if isinstance(value,list):return [local(v) for v in value]
        if isinstance(value,str):
            return value.replace('../Projects/赵慕gei的牙林冒险','资源/原项目').replace('../地图重绘预览','资源/地图')
        return value
    config=local(config)
    config.update(mode='self_contained_local_assets',office_rules='办公室配置.json')
    write(game/'素材引用.json',config)
    for entry in entries:
        entry['sha256']=digest(game/entry['file'])
        entry['bytes']=(game/entry['file']).stat().st_size
    write(game/'素材打包清单.json',{'version':1,'mode':'self_contained_local_assets','files':entries,'total_bytes':sum(e['bytes'] for e in entries),'source_files_preserved':True})
    print(json.dumps({'copied_files':len(entries),'copied_MB':round(sum(e['bytes'] for e in entries)/1048576,1)},ensure_ascii=False))

def create_zip():
    archive=game.parent/'校园自由漫游_好友分享.zip'
    temporary=archive.with_suffix('.building.zip')
    required=[game/path for path in ['校园自由漫游.exe','runtime/engine.exe','runtime/campus.pck',
        '素材引用.json','战斗与刷新配置.json','办公室配置.json','剧情配置.json','任务配置.json',
        '物资与交易配置.json','分享说明.txt','说明.md','素材打包清单.json',
        '第一章与剧情扩展说明.md','任务与物资扩展说明.md','剧情文本来源.txt']]
    required+=sorted(p for p in resources.rglob('*') if p.is_file())
    required+=sorted(p for p in (game/'source').iterdir() if p.is_file())
    assert all(p.is_file() for p in required)
    def stream_digest(stream):
        result=hashlib.sha256()
        while block:=stream.read(1048576):result.update(block)
        return result.hexdigest()
    with zipfile.ZipFile(temporary,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=True) as handle:
        for file in required:handle.write(file,'校园自由漫游/'+file.relative_to(game).as_posix())
    with zipfile.ZipFile(temporary) as handle:
        assert len(handle.namelist())==len(set(handle.namelist()))==len(required)
        for file in required:
            name='校园自由漫游/'+file.relative_to(game).as_posix()
            with handle.open(name) as packed, file.open('rb') as local_file:
                assert stream_digest(packed)==stream_digest(local_file),name
        assert not any('/存档/' in n or '/tests/' in n or '/.godot/' in n or n.endswith('/设置.json') for n in handle.namelist())
        manifest=read(game/'素材打包清单.json')
        for entry in manifest['files']:
            with handle.open('校园自由漫游/'+entry['file']) as packed:
                assert stream_digest(packed)==entry['sha256'],entry['file']
    temporary.replace(archive)
    with archive.open('rb') as stream: archive_hash=stream_digest(stream)
    report={'archive':str(archive),'files':len(required),'bytes':archive.stat().st_size,
        'MB':round(archive.stat().st_size/1048576,1),'sha256':archive_hash,
        'all_archive_entries_match_game_folder':True,'asset_hashes_checked':len(manifest['files']),
        'player_saves_settings_excluded':True,'story_task_economy_configs_included':True}
    write(game/'分享包完整性验证.json',report)
    print(json.dumps(report,ensure_ascii=False))

if __name__=='__main__':
    import sys
    if '--zip' in sys.argv:create_zip()
    else:assemble_assets()
