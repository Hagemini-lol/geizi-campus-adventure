import hashlib
import json
from pathlib import Path

game = Path(r'D:\Godot\校园自由漫游')
art = Path(r'D:\Godot\地图重绘预览')
def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

ui = read(game/'存读档验证报告_界面.json')
restart = read(game/'存读档验证报告_重启.json')
assert not ui['failures'] and not restart['failures']
assert ui['max_scenes'] == restart['max_scenes'] == 1
assert read(game/'菜单验证报告.json')['passed']
assert read(game/'时间昼夜验证报告.json')['passed']
snapshots = [read(game/'封面素材校验.json')]
for path in (game/'菜单素材校验.json', art/'内景/原素材校验.json'):
    snapshots.extend(read(path))
for item in snapshots:
    assert hashlib.sha256(Path(item['Path']).read_bytes()).hexdigest().upper() == item['SHA256']
assert not [p for p in game.rglob('*') if p.suffix.lower() in ('.png','.jpg','.jpeg')]
(game/'存档').mkdir(exist_ok=True)
report = read(game/'完成检查.json')
report.update(SaveFrontEndChecks=ui['checks'], SaveRestartChecks=restart['checks'],
              SaveChecksPassed=True, ManualSaveSlots=5, SaveBackups=True,
              SaveIntegrityChecked=True, SaveRestoresScenePositionPeriodFacingZoom=True,
              SaveInvalidDataPreservesLiveGame=True, SaveAndSettingsPersistAcrossRestart=True,
              TitleUsesOriginalCover=True, CoverSourceUnchanged=True, CoverSourceExternal=True,
              TitleButtons=['start','load','exit','settings'],
              ResolutionChoices=['1280x800','1280x720','1600x900','1920x1080','2560x1440','3840x2160'],
              SettingsFullscreen=True, SettingsVsync=True, SettingsFpsLimit=True,
              AudioVolumeBuses=['Master','Music','SFX'], ProceduralUIClickSound=True,
              MenuTabs=['status','equipment','items','skills','saves','settings'])
(game/'完成检查.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
path=game/'说明.md'
text=path.read_text(encoding='utf-8')
text=text.replace('双击 **校园自由漫游.exe** 开始游玩。','双击 **校园自由漫游.exe** 显示原素材封面，点击「开始游戏」进入南门广场，或点击「加载存档」恢复游玩。')
text=text.replace('包含状态、装备、物品、技能、设置五个页签。','包含状态、装备、物品、技能、存读档、设置六个页签。')
text=text.replace('设置可继续漫游、打开校园全图、回到南门、切换全屏或退出。','设置页可继续漫游、打开校园全图、调整游戏设置、回到南门、切换全屏、返回封面或退出。')
marker='\n## 封面、存读档与设置'
text=text.split(marker)[0]
text+='''

## 封面、存读档与设置

打开 exe 后显示原项目「assets/ui/covers/游戏封面.png」，保留完整图像的比例。封面有「开始游戏」「加载存档」「退出游戏」「设置」四个按钮。封面期间不加载漫游区块，进入游戏后释放封面纹理；返回封面时释放当前世界场景。「开始游戏」重置地点、人物朝向、视角和时间段至南门广场 / 上午，保留之前的手动存档。

在游戏中右键打开菜单，选择「存读档」，然后点击「保存游戏」或「加载存档」。有五个独立槽位，每项显示地点、保存时的时间段和现实保存日期。空槽不能读取；覆盖已有存档需要确认，取消不会改动旧档。关闭存读档界面后回到角色菜单，再右键或 Esc 返回漫游。

存档保存在游戏目录「存档/slot_1.json」至「slot_5.json」。记录室外区块或楼栋 / 楼层 / 教室、精确人物位置、朝向、镜头缩放、室外返回缩放和五段时间系统；预留事件状态字典，目前没有剧情。不会保存寻路中的临时路线。读取时黑色渐入渐出，卸载旧场景，仅加载存档对应的一个场景，恢复昼夜光照与人物操作。

存档先写临时文件并校验，再替换正式文件。每次覆盖保留上一份有效正式存档为同名 .bak；正式文件损坏时可读取备份，界面标注「备份」。读取前检查版本、校验值、建筑 / 楼层 / 教室编号、位置和时间段。无法使用的存档显示错误，当前游戏不变；若有效位置因墙体或家具变更而与碰撞重叠，会移至该场景内的邻近可行走位置。不要手工改写校验后的文件。

封面「设置」和角色菜单「设置 → 游戏设置」使用同一界面。可调分辨率为 1280×800、1280×720、1600×900、1920×1080、2560×1440、3840×2160；可切换全屏、垂直同步及 30 / 60 / 120 FPS / 不限帧率。选择后点击「应用设置」，设置保存在游戏目录「设置.json」，下次启动恢复。窗口模式应用所选尺寸；全屏模式按显示器尺寸显示。

总音量、音乐音量和音效音量均为 0–100%，拖动可试听，点击应用后持久保存；直接返回会撤销未应用的音量预览。零音量静音。已有素材没有背景音乐，因此目前音乐滑杆控制预留音乐通道；菜单按钮使用运行时生成的轻短点击音，受总音量与音效滑杆控制，没有额外音频素材复制。

封面、菜单和室内原素材均做了 SHA-256 复核，仍从包体外只读加载，没有改动或复制原图片。测试存档位于 runtime/存读档验证，与玩家「存档」目录隔离，不会覆盖玩家进度。界面及重启报告见「存读档验证报告_界面.json」「存读档验证报告_重启.json」；实际截图位于外部「地图重绘预览/存读档与封面预览」。
'''
path.write_text(text,encoding='utf-8')
print(json.dumps({'ui_checks':ui['checks'],'restart_checks':restart['checks'],'original_assets_unchanged':len(snapshots),'embedded_image_files':0},ensure_ascii=False))
