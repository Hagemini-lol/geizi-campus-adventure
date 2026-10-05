import json, math
from pathlib import Path
from PIL import Image

root=Path(r'D:\Godot\地图重绘预览')
manifest=json.loads((root/'区块清单.json').read_text(encoding='utf-8'))
data=json.loads(Path(r'D:\Godot\Projects\赵慕gei的牙林冒险\data\campus_regions.json').read_text(encoding='utf-8'))
image=Image.open(r'D:\Godot\Projects\赵慕gei的牙林冒险\assets\maps\outdoor\campus_named_v2.png').convert('RGB')
sx=[35,88,146,391,447,1067]; mx=[0,18,33,153,168,320]
sy=[25,223,355,805,957,1401]; my=[0,45,80,260,295,360]
def interp(v,s,t):
    i=next((i for i in range(len(s)-1) if v<=s[i+1]),len(s)-2)
    return t[i]+(v-s[i])*(t[i+1]-t[i])/(s[i+1]-s[i])
def project(x,y):return interp(x,sx,mx),interp(y,sy,my)
def inverse(x,y):return interp(x,mx,sx),interp(y,my,sy)
def world_rect(a):
    x,y,w,h=a; l,t=project(x,y); r,b=project(x+w,y+h)
    return [l,t,r-l,b-t]
def inside(p,r,margin=0):
    x,y=p; a,b,w,h=r
    return a-margin<=x<=a+w+margin and b-margin<=y<=b+h+margin
regions=manifest['regions']
for r in regions:
    r['world_bounds']=world_rect(r['source_bounds'])
    r['world_areas']=[world_rect(a) for a in r['areas']]
def owner(x,y):
    return next((i for i,r in enumerate(regions) if any(a<=x<a+w and b<=y<b+h for a,b,w,h in r['world_areas'])), -1)
solid_rows=[b for b in data['blockers'] if b['owner'] not in ('trees','fountain_basin')]
solids=[world_rect(b['rect']) for b in solid_rows]
solid_owners=[b['owner'] for b in solid_rows]
# The source map is a drawing, not a surveyed screen elevation. Use a 10 m
# wide 16:9 panel at its existing frontage; visuals and blockers share this box.
for i, solid_owner in enumerate(solid_owners):
    if solid_owner == 'outdoor_screen':
        x,y,w,h = solids[i]
        solids[i] = [x+w/2-5, y+h-5.625, 10.0, 5.625]
ellipses=[world_rect(b['rect']) for b in data['blockers'] if b['owner']=='fountain_basin']
props=[]
# Ground-contact anchors read from the HD sprites, in image pixels.
# Posts and nets use slim physical footprints; court markings stay walkable.
anchors={
    'S05': [('net',578,425,578,865)],
    'S06': [('net',145,369,316,369),('net',361,369,528,369),
            ('net',145,1094,316,1094),('net',361,1094,528,1094)],
    'S07': [('hoop',x,y,x,y) for x in [332,663,991,1324] for y in [215,753]],
}
for region_id,entries in anchors.items():
    i=next(i for i,r in enumerate(regions) if r['id']==region_id)
    region=regions[i]; a,b,w,h=region['world_bounds']
    with Image.open(root/region['image']) as sprite: iw,ih=sprite.size
    for kind,x1,y1,x2,y2 in entries:
        px,py=a+x1/iw*w,b+y1/ih*h
        qx,qy=a+x2/iw*w,b+y2/ih*h
        pw,ph=(max(abs(qx-px),.12),max(abs(qy-py),.12)) if kind=='net' else (1.0,.6)
        rect=[(px+qx-pw)/2,(py+qy-ph)/2,pw,ph]
        solids.append(rect); solid_owners.append('sport_'+kind)
        props.append(dict(region=i,kind=kind,rect=rect,texture_anchor=[(x1+x2)/2/iw,(y1+y2)/2/ih]))

def ellipse_hit(x,y,e,margin=0):
    a,b,w,h=e
    return ((x-a-w/2)/(w/2+margin))**2+((y-b-h/2)/(h/2+margin))**2<=1
tree_beds=[world_rect(b['rect']) for b in data['blockers'] if b['owner']=='trees']
bridges=[world_rect(a) for a in data['bridges']]
trees=[]; cells=set()
for bed in tree_beds:
    a,b,w,h=bed
    for yi in range(math.ceil(b/3.8),math.floor((b+h)/3.8)+1):
        for xi in range(math.ceil(a/3.8),math.floor((a+w)/3.8)+1):
            if (xi,yi) in cells:continue
            cells.add((xi,yi))
            x,y=xi*3.8,yi*3.8
            if any(inside((x,y),v,0.5) for v in bridges+solids):continue
            px,py=inverse(x,y); rr,gg,bb=image.getpixel((round(px),round(py)))
            if gg<rr*1.05 or gg<bb*1.05:continue
            region=owner(x,y)
            if region>=0:trees.append([round(x,3),round(y,3),region])
width,height=320,360
blocked=bytearray(width*height); roads=bytearray(width*height)
owners=[]
for y in range(height):
    for x in range(width):
        owners.append(owner(x+.5,y+.5))
# Rasterize blockers conservatively for a 0.30m-radius character.
for a,b,w,h in solids:
    for y in range(max(0,math.floor(b-.6)),min(height,math.ceil(b+h+.6))):
        for x in range(max(0,math.floor(a-.6)),min(width,math.ceil(a+w+.6))):
            if inside((x+.5,y+.5),[a,b,w,h],.6):blocked[y*width+x]=1
for tx,ty,_ in trees:
    for y in range(max(0,int(ty)-1),min(height,int(ty)+2)):
        for x in range(max(0,int(tx)-1),min(width,int(tx)+2)):
            if math.hypot(x+.5-tx,y+.5-ty)<.8:blocked[y*width+x]=1
for ellipse in ellipses:
    a,b,w,h=ellipse
    for y in range(max(0,math.floor(b-.6)),min(height,math.ceil(b+h+.6))):
        for x in range(max(0,math.floor(a-.6)),min(width,math.ceil(a+w+.6))):
            if ellipse_hit(x+.5,y+.5,ellipse,.6):blocked[y*width+x]=1
for y in range(height):
    for x in range(width):
        i=y*width+x
        if x==0 or x==width-1 or y==0 or y==height-1:blocked[i]=1
        px,py=inverse(x+.5,y+.5); rr,gg,bb=image.getpixel((round(px),round(py)))
        is_paving=(rr>90 and gg>80 and bb>55 and rr>=gg*.97 and max(rr,gg,bb)-min(rr,gg,bb)<135)
        if is_paving or any(inside((x+.5,y+.5),a) for a in bridges): roads[i]=1
# Border gates are determined from connected, obstacle-free paved cells.
gates=[]; gate_cells=set()
for y in range(height-1):
    for x in range(width-1):
        i=y*width+x
        for nx,ny in ((x+1,y),(x,y+1)):
            j=ny*width+nx
            if owners[i]!=owners[j] and owners[i]>=0 and owners[j]>=0:
                if not blocked[i] and not blocked[j] and roads[i] and roads[j]:
                    gates.append([owners[i],owners[j],(x+nx+1)/2,(y+ny+1)/2])
                    gate_cells.update((i,j))
# Prevent automatic routes from crossing non-road administrative boundaries.
for y in range(height-1):
    for x in range(width-1):
        i=y*width+x
        for nx,ny in ((x+1,y),(x,y+1)):
            j=ny*width+nx
            if owners[i]!=owners[j] and not (roads[i] and roads[j]):
                if i not in gate_cells:blocked[i]=1
                if j not in gate_cells:blocked[j]=1
graph={i:set() for i in range(len(regions))}
for a,b,x,y in gates:graph[a].add(b);graph[b].add(a)
reached={19}; pending=[19]
while pending:
    for n in graph[pending.pop()]-reached:reached.add(n);pending.append(n)
if len(reached)!=len(regions):raise RuntimeError('Unreachable regions: '+str([regions[i]['id'] for i in graph if i not in reached]))
model=dict(regions=regions,solids=solids,solid_owners=solid_owners,ellipses=ellipses,props=props,trees=trees,bridges=bridges,gates=gates,
           blocked=''.join('1' if n else '0' for n in blocked),roads=''.join('1' if n else '0' for n in roads),
           width=width,height=height,cell_meters=1,tree_diameter_meters=3.5,tree_height_meters=4.5,tree_trunk_diameter_meters=.35)
(root/'运行数据.json').write_text(json.dumps(model,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
(root/'区块清单.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'Road-only border gates: {len(gates)}; reachable administrative regions: {len(reached)}; independent trees: {len(trees)}')
