import json, hashlib, shutil, os
from pathlib import Path
from PIL import Image

root=Path(r'D:\Godot\校园自由漫游')
preview=Path(r'D:\Godot\地图重绘预览')
root.joinpath('说明.md').write_text('''# 校园自由漫游

双击 **校园自由漫游.exe** 开始游玩。仅含校园外景和自由移动，没有剧情。

- WASD / 方向键：常态移动 4.2 米/秒；斜向移动保持同速。
- Shift：2 倍速，8.4 米/秒。
- 左键点击地面：5 倍速自动寻路，21 米/秒。可绕开建筑和树干，连续跨区。
- 右键或手动移动：取消自动寻路。
- M：校园区块图；点击目的地可发起跨区寻路。
- 滚轮：缩放镜头；F11：全屏；R：回到南门；Esc：暂停；F3：碰撞显示。

地图按建筑管理范围划为 20 个区块，每个区块使用独立高清背景。移动到相邻区块交界处的道路边缘时，先用 0.18 秒渐入黑屏，释放旧区块并加载新区块，再用 0.22 秒渐出黑屏。非道路边界不能切换区块；浅绿色圆圈标出道路出口。跨区自动寻路在切换后继续。

同一时间只保留一个区块场景及其背景纹理，不保留整张原地图。实测最大区块背景约 6 MB，20 张全部背景合计约 118 MB；这两个数字仅为未压缩背景纹理大小，不包含引擎、共享树木图片、导航及其他运行内存。

校园按东西 320 米、南北 360 米校准；田径场外圈约 150 × 250 米、足球场约 120 × 180 米。所有碰撞与移动使用同一米制坐标。

主角身高约 1.70 米、碰撞半径 0.30 米。独立树木显示宽 3.5 米、高 4.5 米，树干直径 0.35 米，仅树干阻挡行走，树冠按人物前后关系遮挡。门高 2.1 米、双扇门宽 1.9 米、窗户约 1.2 × 1.5 米、台阶进深 0.30 米、铺砖边长 0.50 米。这些建筑与地面细节由场景按米制补绘，避免直接放大背景中的门窗和铺砖。未提供实测尺寸的物体使用设计估计。

主角使用已有四向设计图，在内存中裁剪、按朝向切换，并添加轻微行走摆动；目前没有逐帧迈步动画。建筑室内尚未接入。

## 素材仍在包体外

原主角和原地图碰撞数据从工作区原项目只读引用。原地图只用于制作参考和道路分析，运行时不加载它。

20 张新重绘背景、独立树木图及区块数据存于相邻的「地图重绘预览」文件夹，游戏通过「素材引用.json」从外部读取。以上图片均未复制或嵌入游戏目录或 PCK。

需要保留工作区中的引用路径才能运行；得到你的确认后再复制所需素材，制作可搬到其他电脑的完整包体。

source 是独立 Godot 工程，runtime 包含引擎与代码包，tools 包含启动器与地图准备代码。区块及玩法验证结果见「区块验证报告.json」。
''',encoding='utf-8')

preview.joinpath('预览说明.md').write_text('''# 高清地图预览

「高清区块」包含 20 张按建筑管理范围重绘的区块背景和 1 张透明树木图。原素材保持在原路径，新图片尚未复制进游戏包体。

「区块清单.json」记录管理范围、原图坐标和米制坐标；「运行数据.json」记录道路出口、建筑碰撞、独立树木及寻路网格；「重绘提示词.json」保留生成提示词；「参考裁片」仅为制作参考，不参与游戏运行。

游戏按 1.70 米人物校准树木、门窗、台阶和铺砖，使用高清背景配合场景补绘。「试玩预览.png」「人体与树木比例.png」「区块总览.png」展示实际运行画面。地图设计尺寸为校园 320 × 360 米、田径场 150 × 250 米、足球场 120 × 180 米。

游玩入口位于相邻的「校园自由漫游」文件夹。WASD 移动，Shift 2 倍速，点击 5 倍速自动寻路，M 打开全区块地图。
''',encoding='utf-8')

for source,dest in [('campus-walk-review.png','试玩预览.png'),('campus-tree-review.png','人体与树木比例.png'),('campus-map-review.png','区块总览.png')]:
    shutil.copyfile(Path(os.environ['TEMP'])/source,preview/dest)

manifest=json.loads(preview.joinpath('区块清单.json').read_text(encoding='utf-8'))
assets=[]
for region in manifest['regions']:
    path=preview/region['image']
    with Image.open(path) as image: region['png_pixels']=list(image.size)
    region['status']='generated_pending_packaging_confirmation'
    region['sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
    assets.append(dict(id=region['id'],image=region['image'],pixels=region['png_pixels'],sha256=region['sha256']))
preview.joinpath('区块清单.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
preview.joinpath('素材校验.json').write_text(json.dumps(assets,ensure_ascii=False,indent=2),encoding='utf-8')

report=json.loads(root.joinpath('区块验证报告.json').read_text(encoding='utf-8'))
snapshot=json.loads(root.joinpath('原素材校验快照.json').read_text(encoding='utf-8-sig'))
config=json.loads(root.joinpath('素材引用.json').read_text(encoding='utf-8'))
paths={(root/config[k]).resolve() for k in ['map','hero','geometry']}
refs=[]
for row in snapshot:
    path=Path(row['Path'])
    if path in paths:
        refs.append(dict(Path=str(path),Unchanged=hashlib.sha256(path.read_bytes()).hexdigest().upper()==row['SHA256']))
check=dict(Checks=len(report['checks']),Failures=len(report['failures']),ReferencedFiles=refs,
           ImageFilesInGameFolder=sum(1 for p in root.rglob('*') if p.suffix.lower() in ['.png','.jpg','.webp']),
           Packaging='external_read_only_pending_confirmation',DimensionsMeters=dict(Campus=[320,360],Track=[150,250],Football=[120,180],HeroHeight=1.7,Tree=[3.5,4.5],DoorHeight=2.1,Paving=.5,StairTread=.3,SceneCount=20),
           MaximumLoadedScenes=report['max_loaded_scenes'],MaximumMapTextureBytes=report['largest_active_map_texture_bytes'])
root.joinpath('完成检查.json').write_text(json.dumps(check,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(check,ensure_ascii=False))
assert report['passed'] and len(refs)==3 and all(r['Unchanged'] for r in refs) and check['ImageFilesInGameFolder']==0
