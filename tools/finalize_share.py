from pathlib import Path
import hashlib
import json

game=Path(__file__).resolve().parents[1]
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def write(path,value):path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

manifest=read(game/'素材打包清单.json')
for entry in manifest['files']:
    path=game/entry['file']
    assert path.is_file() and sha(path)==entry['sha256'],str(path)
    entry['bytes']=path.stat().st_size
manifest['total_bytes']=sum(e['bytes'] for e in manifest['files'])
write(game/'素材打包清单.json',manifest)

doc=(game/'说明.md').read_text(encoding='utf-8-sig')
begin=doc.index('## 素材仍在包体外') if '## 素材仍在包体外' in doc else doc.index('## 完整分享包')
end=doc.index('## 贴图与碰撞复核',begin)
doc=doc[:begin]+'''## 完整分享包

全部游戏素材现已复制到游戏内「资源」目录，运行时使用游戏文件夹内的相对路径。包括地图、高清切片、教室与办公室、人物、怪物、封面、菜单、对话框、战斗界面及其依赖。原工作区素材保留不动。

分享时发送「校园自由漫游_好友分享.zip」，请好友完整解压，再双击文件夹内的「校园自由漫游.exe」。适用于 Windows 64 位，无需安装 Godot；不要仅发送 exe。可把完整文件夹移到其他磁盘或改名，不需要原工作区。分享包不包含个人存档、设置或测试文件，首次启动使用默认设置。

运行文件为 exe、runtime、资源和根目录的三份配置。source 为可编辑的 Godot 工程；常规游玩不需要打开工程。存档和设置会保存在自己的游戏文件夹内，请放到有写入权限的位置。

「素材打包清单.json」记录每份资源的文件大小和 SHA-256；「分享说明.txt」包含简要操作。下文提到的外部截图与验证报告为开发历史记录，游戏运行不依赖这些目录。

'''+doc[end:]
doc=doc.replace('包含校园外景、四栋教学楼室内、自由移动和简单 NPC 问候，没有剧情。','包含校园外景、四栋楼的走廊、教室与办公室、自由移动、NPC 问候和实验楼战斗，没有剧情。')
doc=doc.replace('原图片未修改，素材仍从包体外只读加载。','原图片未修改，运行时读取游戏内的素材副本。')
doc=doc.replace('没有改动或复制进游戏目录。游戏仍需保留外部引用路径；素材入包继续等待你的确认。','原图没有改动，素材已按你的授权复制进游戏目录，游戏无需外部引用路径。')
doc=doc.replace('高清缓存和走廊合成图均位于外部「地图重绘预览」文件夹，没有复制进游戏包体。','高清缓存和走廊合成图已复制到游戏内「资源/地图」目录。')
doc=doc.replace('HP、MP、精力及 SAN 尚无数值系统，以 — 显示，装备、物品与技能页为空。','状态页显示实际等级、经验、HP、MP、精力和 SAN；装备、物品与技能页暂为空。')
doc=doc.replace('图片通过「素材引用.json」从原项目读取，没有改动原素材或将其复制到包体。','图片通过「素材引用.json」从游戏内的原素材副本读取，没有改动原素材。')
doc=doc.replace('原图没有修改或复制进游戏包，仍待确认后再制作可独立搬移的完整素材包。','原图没有修改，已按你的授权复制进游戏包，可独立搬移。')
doc=doc.replace('原地图、人物、怪物及 UI 素材未复制到游戏包内，仍按既有要求等待确认。','原地图、人物、怪物及 UI 素材已按你的授权复制到游戏包内，原素材保留不动。')
doc=doc.replace('合计 17 个楼层走廊、150 个教室入口。','合计 17 个楼层走廊、150 个房间入口，其中 34 间改为办公室。')
doc=doc.replace('原项目的 battle_interface.tscn','游戏内原项目副本的 battle_interface.tscn')
doc=doc.replace('封面、菜单和室内原素材均做了 SHA-256 复核，仍从包体外只读加载，没有改动或复制原图片。','封面、菜单和室内原素材均做了 SHA-256 复核，运行时读取游戏内的副本，没有改动原图片。')
doc=doc.replace('共覆盖 126 间教室和 13 层走廊，合计 1540 个普通 NPC、30 个移动具名 NPC 交互位置；只有当前场景的人物会显示，室外及实验楼的走廊、教室均不安排 NPC。','共覆盖 100 间教室、26 间办公室和 13 层走廊，合计 1254 名普通学生、78 名办公人员、30 名移动具名学生；只有当前场景的人物会显示，室外及实验楼的所有室内均不安排 NPC。')
if '## 四栋楼的办公室' not in doc:
    doc+='''
## 四栋楼的办公室

春华楼、夏耘楼、秋实楼和实验楼的每层最右侧房间、距中央楼梯最近的房间设为办公室，共 34 间。最右侧使用原有「教师办公室-白桌玻璃版」，楼梯旁使用「教师办公室-实木版」。门口显示办公室标识，前后门仍返回对应走廊位置。三楼最左侧十班保留原样。

三个教学楼的 26 间办公室各有一位班主任、一位英语老师、一位文聪和一名学生。班主任关心学习和作息，英语老师提供英语学习问候，文聪以教导主任身份提醒纪律；主角回应也与对方身份对应。办公室里的师生合入当前背景、无需独立移动回调，不挡路；走近按 E 或点击交互。

实验楼的 8 间办公室不放 NPC，继续使用怪物刷新规则，每间最多两只。办公室依旧只加载当前房间，家具保留 1×1 逻辑像素碰撞核心，墙体与门口边界保持有效。「办公室配置.json」可调整办公室素材、学生数量和身份问候。

普通教室仍安排 12 名普通学生，十班有 4 名普通学生及 10 名缓慢移动的具名学生，走廊各有 4 名普通学生。办公室和教室合计有 1,254 名普通学生、78 名办公人员及 30 名具名学生，均按当前室内场景加载；室外与实验楼没有 NPC。
'''
(game/'说明.md').write_text(doc,encoding='utf-8')
(game/'分享说明.txt').write_text('''校园自由漫游 · 完整分享版

适用于 Windows 64 位。完整解压后双击「校园自由漫游.exe」，无需安装 Godot。
请发送完整 ZIP，或复制整个游戏文件夹；单独发送 exe 无法运行。
全部地图、人物、怪物、室内场景和 UI 已放进「资源」文件夹，可独立搬移。

开始游戏：南门 / 上午 / 0 级。加载存档：恢复自己保存的进度。
设置：分辨率、全屏、帧率、音量。

WASD / 方向键：移动
Shift：2 倍速度
左键点击地面：5 倍速度自动寻路
E / 点击人物或门：交互
鼠标右键：角色菜单、存读档、设置
M：校园全图；楼门口告示牌可全图传送
滚轮：缩放；F11：全屏；Esc：关闭界面或暂停；R：回南门
左上角「快进 >>」：切换下一个时间段，黑屏过渡，2 秒冷却
战斗按键 1–6：普攻、法术、闪避、防守、休整、挂机；Esc / 右键：撤离确认

四栋楼每层最右侧和中央楼梯旁都有办公室。
教学楼办公室有班主任、英语老师、文聪和一名学生，可进行身份对应问候。
实验楼所有室内（含办公室）不放 NPC，保留怪物刷新区。
三个教学楼三楼最左侧仍为十班，具名学生仅在十班内缓慢移动。
当前没有剧情，时间只由快进或显式事件推动。

自己的存档保存在游戏文件夹「存档」，设置保存在「设置.json」。
本分享 ZIP 不包含开发者的存档和设置。建议放在有写入权限的目录。
详细操作和数值见「说明.md」。数值可在「战斗与刷新配置.json」调整，
办公室人员及问候可在「办公室配置.json」调整，修改后重新启动游戏。
''',encoding='utf-8-sig')

completion=read(game/'完成检查.json')
completion.update(Packaging='self_contained_local_assets',ImageFilesInGameFolder=len(list((game/'资源').rglob('*.png'))),
    MenuSourceImagesExternal=False,CoverSourceExternal=False,NPCAssetsExternal=False,BattleAssetsExternal=False,
    ExternalWorkspaceRequired=False,PortableAssetsFiles=len(manifest['files']),PortableAssetsBytes=manifest['total_bytes'],
    AssetsCopiedWithSourceUnchanged=True,NPCOrdinaryTotal=1254,NPCStaticNamedTotal=78,NPCSpecialTotal=108,
    OfficeRooms=34,OfficeBuildings=['春华楼','夏耘楼','秋实楼','实验楼'],OfficeLabRooms=8,OfficeLabNPCs=0,
    OfficeTeachingRooms=26,OfficeStudentPerRoom=1,OfficeStaffPerRoom=3,OfficeStaffTotal=78,
    OfficeFurnitureCollisionPixels=[1,1],OfficeChecks=5163,OfficeChecksPassed=True,
    CurrentPackageSHA256=sha(game/'runtime/campus.pck').upper())
completion['BakedMapFolder']=str(game/'资源/地图/静态区块')
write(game/'完成检查.json',completion)
print(json.dumps({'files':len(manifest['files']),'asset_MB':round(manifest['total_bytes']/1048576,1),'offices':34},ensure_ascii=False))
