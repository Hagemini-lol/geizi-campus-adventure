from pathlib import Path
import hashlib
import json
import shutil

game=Path(__file__).resolve().parents[1]
original=game.parent/'Projects/赵慕gei的牙林冒险'
target=game/'资源/原项目'
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
library=json.loads((original/'data/character_walk_library.json').read_text(encoding='utf-8-sig'))
required=set()
for name in ['character_walk_library.json','character_walk_source_regions.json','character_walk_assembly.json']:
    required.add(Path('data')/name)
for entry in library['characters']:
    required.add(Path(entry['source'].removeprefix('res://')))
    folder=Path('assets/characters/runtime')/entry['id']
    required.update(folder/name for name in ['行走.png','行走.tres','行走注释.json'])
    required.update(folder/('walk_'+direction+'_'+phase+'.png') for direction in ['front','back','left','right'] for phase in ['a','b'])
manifest_path=game/'素材打包清单.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8-sig'))
entries={e['file']:e for e in manifest['files']}
for relative in sorted(required):
    source=original/relative; copied=target/relative
    before=sha(source)
    copied.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,copied)
    assert sha(source)==before and sha(copied)==before
    name=copied.relative_to(game).as_posix()
    entries[name]={'file':name,'bytes':copied.stat().st_size,'sha256':before}
manifest.update(files=sorted(entries.values(),key=lambda e:e['file']),zip_frozen=True)
manifest['total_bytes']=sum(e['bytes'] for e in manifest['files'])
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
config_path=game/'素材引用.json'
config=json.loads(config_path.read_text(encoding='utf-8-sig'))
config['walk_library']='资源/原项目/data/character_walk_library.json'
config_path.write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(game/'行走素材复制校验.json').write_text(json.dumps({'files_copied':len(required),'characters':len(library['characters']),'originals_unchanged':True,'zip_modified':False},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'copied_files':len(required),'characters':len(library['characters']),'zip_modified':False}))
