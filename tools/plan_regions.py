import json
from pathlib import Path

root = Path(r'D:\Godot\地图重绘预览')
root.mkdir(exist_ok=True)
definitions = [
 ('B01','秋实楼与北门',[[35,25,335,165]]),
 ('B02','实验楼',[[370,25,365,165]]),
 ('B03','体育馆',[[735,25,332,165]]),
 ('B04','小仓库',[[942,190,125,75]]),
 ('B05','夏耘楼与有顶连廊',[[448,190,494,155]]),
 ('B06','科技中心',[[942,265,125,325]]),
 ('S01','田径场与看台',[[35,190,413,766]]),
 ('S05','排球场',[[448,345,282,175]]),
 ('G01','花坛喷泉',[[730,345,212,245]]),
 ('S06','羽毛球场与中央林荫步道',[[448,520,282,305]]),
 ('B07','食堂',[[942,590,125,210]]),
 ('B09','设备辅助用房与庭院',[[730,590,212,235]]),
 ('S07','四块篮球场',[[448,825,327,171]]),
 ('B08','小食堂与礼堂后门',[[942,800,125,118],[775,825,167,93]]),
 ('B10','礼堂与入口台阶',[[775,918,292,174],[870,1092,80,28]]),
 ('B16','宿舍',[[775,1092,95,309],[950,1092,117,309],[870,1120,80,281]]),
 ('B12','春华楼',[[335,996,440,174],[335,956,113,40]]),
 ('B13','新教学楼与小篮球场',[[35,956,300,154]]),
 ('B15','办公楼与西南林荫区',[[35,1110,300,291]]),
 ('N02','南门广场与户外大屏幕',[[335,1170,440,231]])
]
regions=[]
for id_,name,areas in definitions:
    left=min(r[0] for r in areas); top=min(r[1] for r in areas)
    right=max(r[0]+r[2] for r in areas); bottom=max(r[1]+r[3] for r in areas)
    regions.append(dict(id=id_,name=name,areas=areas,source_bounds=[left,top,right-left,bottom-top],
                        reference=f'参考裁片/{id_}.png',image=f'高清区块/{id_}.png',
                        status='pending_redraw'))
manifest=dict(version=3,source_map='../Projects/赵慕gei的牙林冒险/assets/maps/outdoor/campus_named_v2.png',
              campus_meters=[320,360],track_meters=[150,250],football_meters=[120,180],
              regions=regions,approval='external_read_only_pending_confirmation')
(root/'区块清单.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
# Exact coverage, including L-shaped service territories and auditorium stairs.
for y in range(25,1401):
    for x in range(35,1067):
        owners=[r['id'] for r in regions if any(a<=x<a+w and b<=y<b+h for a,b,w,h in r['areas'])]
        if len(owners)!=1: raise RuntimeError(f'Coverage {x},{y}: {owners}')
print(f'{len(regions)} administrative regions; full campus coverage, no overlaps.')
