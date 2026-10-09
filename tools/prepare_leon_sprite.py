"""Pack the generated 12 poses into a small game atlas, retaining its master."""
from pathlib import Path
from PIL import Image
import json, shutil, hashlib

root=Path(__file__).resolve().parents[1]
original=Path(r'C:\Users\李科奇\.codex\generated_images\01a119fe-4fad-75e1-9efd-2badd4b2ddcd\exec-4a31a224-d00d-4189-9fac-b408e595b1b5.png')
masters=root/'美术生成记录/里昂小人v1.5';masters.mkdir(parents=True,exist_ok=True)
shutil.copy2(original,masters/'Leon_RPD_12poses_master.png')
source=Image.open(original).convert('RGBA')
assert source.size==(1536,1024) and source.getextrema()[-1][0]==0
# Hand-verified gutters, not nominal image quarters: generation placed actors
# at x=330/625/925/1220. Keep all feet and existing alpha inside each pose.
xs=[200,475,770,1065,1380];ys=[0,350,680,1024]
atlas=Image.new('RGBA',(256,240))
poses=[]
for row in range(3):
 for col in range(4):
  box=(xs[col],ys[row],xs[col+1],ys[row+1])
  cell=source.crop(box)
  # The used rectangle is measured at visible alpha to exclude almost invisible
  # generated edge pixels. The crop preserves alpha; no background recolouring.
  bounds=cell.getchannel('A').point(lambda a:255 if a>=128 else 0).getbbox()
  assert bounds
  crop=cell.crop(bounds)
  width=round(crop.width*70/crop.height)
  assert 0<width<=60
  crop=crop.resize((width,70),Image.Resampling.NEAREST)
  at=(col*64+(64-width)//2,row*80+8)
  atlas.alpha_composite(crop,at)
  poses.append({'row':row,'column':col,'master_cell':box,'visible_bounds':bounds,'logical_size':[width,70]})
target=root/'资源/原项目/assets/characters/leon_v15';target.mkdir(parents=True,exist_ok=True)
atlas.resize((512,480),Image.Resampling.NEAREST).save(target/'atlas.png')
metadata={'character':'Leon S. Kennedy / RE2 Remake 2019 RPD','use':'Feiyan overworld only; dialogue keeps original unredrawn render','generator':'built-in image_gen','master':str((masters/'Leon_RPD_12poses_master.png').relative_to(root)),'runtime_cell':[128,160],'logical_cell':[64,80],'directions':['front','back','left','right'],'rows':['idle','walk_a','walk_b'],'fps_max':4,'poses':poses,'reference':'资源/新增立绘/原图/Leon_RE2_2019_RPD.png','character_rights':'CAPCOM; fan depiction; not an original CC0 character','sha256':hashlib.sha256((target/'atlas.png').read_bytes()).hexdigest()}
(target/'motion.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('LEON_PIXEL_READY',target/'atlas.png')
