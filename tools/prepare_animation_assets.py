"""Slice generated poses; keep original artwork and import small shared atlases."""
from pathlib import Path
from PIL import Image
import json, shutil
root=Path(__file__).resolve().parents[1]
generated=Path('C:/Users/李科奇/.codex/generated_images/01a119fe-4fad-75e1-9efd-2badd4b2ddcd')
files={
'ink_slime':'exec-945028cc-8137-4bcf-aa6e-1221c9a4158f.png',
'book_eater':'exec-b39c6707-9bdd-43ec-aacb-83142c046e85.png',
'empty_uniform':'exec-628e4f79-1194-4e4a-9ff9-897349bde658.png',
'dry_branch':'exec-70d1551e-98f8-4a02-a0a4-cdf33cc05081.png',
'gou_ga_boss':'exec-0bbffbb9-b7a0-48bc-8556-d8df5aa75d87.png',
'book_eater_queen':'exec-fd36d411-45b2-4483-bf17-6cff5e7a3f9c.png',
'dry_branch_ancient':'exec-bd14a8b2-c937-40df-b747-84f8816d9936.png',
'empty_uniform_leader':'exec-723f478f-8a7d-47e6-91c0-d98d21b8e4e2.png',
'hero_actions':'exec-fa25c7fb-e0b1-41ae-ad41-72e8b9f37ecd.png',
}
rules=json.loads((root/'战斗与刷新配置.json').read_text(encoding='utf-8'))
reports=[]
for id,file in files.items():
    im=Image.open(generated/file).convert('RGBA');cols=4 if id=='gou_ga_boss' else 3
    folder=root/'资源/原项目/assets/characters'/('hero/battle/actions-v2' if id=='hero_actions' else 'bosses/'+id)
    folder.mkdir(parents=True,exist_ok=True)
    original=root/'美术生成记录'/f'{id}.png';original.parent.mkdir(exist_ok=True);shutil.copy2(generated/file,original)
    cw,ch=im.width//cols,im.height//2
    boxes=[((i%cols)*cw,(i//cols)*ch,(i%cols+1)*cw,(i//cols+1)*ch) for i in range(cols*2)]
    # Generated effects sometimes exceed an ideal grid; these measured source
    # bounds preserve whole silhouettes instead of cutting hands/page wings.
    if id=='book_eater_queen':boxes=[(5,0,505,489),(511,0,1032,492),(1037,0,1536,508),(0,490,630,1024),(632,510,1043,1024),(1045,540,1536,1024)]
    if id=='ink_slime':boxes=[(0,0,510,510),(512,0,1035,510),(1038,0,1536,510),(0,515,638,1024),(640,515,1035,1024),(1038,515,1536,1024)]
    if id=='book_eater':boxes=[(0,0,510,505),(512,0,1027,505),(1030,0,1536,505),(0,510,574,1024),(575,510,1035,1024),(1040,510,1536,1024)]
    atlas=Image.new('RGBA',(cols*256,640))
    for i,box in enumerate(boxes):
        crop=im.crop(box)
        # Inspect alpha > 32 to ignore a handful of anti-aliasing specks.
        bounds=crop.getchannel('A').point(lambda a:255 if a>32 else 0).getbbox()
        if bounds:crop=crop.crop(bounds)
        crop.thumbnail((244,300),Image.Resampling.LANCZOS)
        atlas.alpha_composite(crop,((i%cols)*256+(256-crop.width)//2,(i//cols)*320+310-crop.height))
    atlas.save(folder/'atlas.png',optimize=True)
    portrait=atlas.crop((0,0,256,320));portrait.save(folder/'portrait.png',optimize=True)
    world=Image.new('RGBA',(512,640))
    for x,y in [(0,0),(256,0),(0,320),(256,320)]:world.alpha_composite(portrait,(x,y))
    world.save(folder/'world.png',optimize=True)
    if id=='hero_actions':poses=dict(idle=[0],windup=[1],attack=[2],guard=[3],hit=[4],rest=[5],phase=[0],defeat=[5])
    else:poses=dict(idle=[0,1],windup=[2],attack=[3],hit=[5 if cols==4 else 4],guard=[4 if cols==4 else 0],phase=[6 if cols==4 else 0],defeat=[7 if cols==4 else 5])
    (folder/'motion.json').write_text(json.dumps(dict(columns=cols,rows=2,cell=[256,320],poses=poses,fps=6),ensure_ascii=False,indent=2),encoding='utf-8')
    if id in rules['monsters']:
        rules['monsters'][id]['portrait_atlas']=f'assets/characters/bosses/{id}/atlas.png'
        rules['monsters'][id]['art']=f'assets/characters/bosses/{id}/world.png'
    reports.append(dict(id=id,frames=cols*2,atlas_rgba_bytes=atlas.width*atlas.height*4,original=str(original.relative_to(root))))
rules['monsters']['gate_entity']=json.loads(json.dumps(rules['monsters']['gou_ga_boss']))
(root/'战斗与刷新配置.json').write_text(json.dumps(rules,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(root/'runtime/animation_assets.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(atlases=len(files),poses=sum(x['frames'] for x in reports),active_battle_atlas_bytes_max=4*256*640*4+3*256*640*4),ensure_ascii=False))
