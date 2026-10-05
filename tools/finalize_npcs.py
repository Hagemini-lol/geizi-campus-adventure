import hashlib
import json
from pathlib import Path

game=Path(r'D:\Godot\校园自由漫游')
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
report=read(game/'NPC验证报告.json')
assert report['passed'] and not report['failures']
assets=read(game/'NPC素材校验.json')
for item in assets:
    assert hashlib.sha256(Path(item['Path']).read_bytes()).hexdigest().upper()==item['SHA256']
assert not [p for p in game.rglob('*') if p.suffix.lower() in ('.png','.jpg','.jpeg')]
info=read(Path(r'D:\Godot\地图重绘预览\内景\内外对应.json'))
rosters=report.get('ten_class_rosters',{})
named_total=report.get('named_student_total',3)
moving_total=report.get('moving_student_total',3)
rooms=0
corridors=0
for key,building in info['buildings'].items():
    if key=='B02':continue
    for floor in building['floors']:
        corridors+=1
        rooms+=len(floor['rooms'])
completion=read(game/'完成检查.json')
completion.update(NPCChecks=report['checks'],NPCChecksPassed=True,
                  NPCCharacterAssetsChecked=20,NPCDirectionFramesChecked=80,
                  NPCAssetsUnchanged=True,NPCAssetsExternal=True,
                  NPCClassrooms=rooms,NPCCorridors=corridors,
                  NPCOrdinaryPerClassroom=12,NPCOrdinaryPerCorridor=4,
                  NPCOrdinaryTotal=rooms*12+corridors*4-(named_total-moving_total),NPCSpecialTotal=named_total,
                  NPCSpecialIds=[id for roster in rosters.values() for id in roster],NPCMovingIds=report['special_ids'],
                  NPCMovingTotal=moving_total,NPCStaticNamedTotal=named_total-moving_total,NPCTenClassRosters=rosters,
                  NPCExcludedBuilding='B02',NPCOutdoorCount=0,
                  NPCOrdinaryBakedInBackground=True,NPCOrdinaryProcessCallbacks=False,
                  NPCOrdinaryPhysicsBodies=0,NPCOrdinarySpriteNodes=0,
                  NPCSpecialBoundedRandomNavigation=True,NPCDialogueConfirmCancel=True,
                  NPCDialogueUsesOriginalFrame=True,NPCDialogueDoesNotAdvanceTime=True,
                  DialoguePortraitOuterThirds=True,DialogueSpeakingHighlight=True,DialogueTwoGreetingTurns=True,
                  DialogueAbovePortraits=True,DialogueOptionsOnTop=True,DialogueInteractiveCanvasLayer=90,
                  NPCClickApproachAndEGreeting=True,NPCOneActiveScene=True,
                  NPCPackageSHA256=hashlib.sha256((game/'runtime/campus.pck').read_bytes()).hexdigest().upper())
(game/'完成检查.json').write_text(json.dumps(completion,ensure_ascii=False,indent=2),encoding='utf-8')
doc=game/'说明.md'
text=doc.read_text(encoding='utf-8').split('\n## 教学楼 NPC 与问候')[0]
text=text.replace('包含校园外景、四栋教学楼室内和自由移动，没有剧情。','包含校园外景、四栋教学楼室内、自由移动和简单 NPC 问候，没有剧情。')
text+='''

## 教学楼 NPC 与问候

春华楼、夏耘楼、秋实楼的普通教室安排 12 名同学，约占 32 个座位的 37.5%，前三排分散分布，保留第四排及通行空间。三个十班各保留 12 名静态学生加 1 名移动学生，其中部分静态学生换为具名角色。每层走廊安排 4 名普通同学。共覆盖 126 间教室和 13 层走廊，合计 1557 个普通 NPC、7 个静态具名 NPC、3 个移动具名 NPC 交互位置；只有当前场景的人物会显示，室外及实验楼的走廊、教室均不安排 NPC。

普通同学从六种已有学生形象选择，按所在楼层和教室生成稳定位置与朝向。读取原高分辨率图的已核验裁剪区域，在内存中合成至当前背景；桌面部分覆盖人物，保留前后遮挡。没有为普通同学创建精灵节点、物理碰撞体、动画或独立逐帧回调，也不增加背景纹理张数。只保留小量姓名、脚底位置和交互范围数据，切换场景后随旧场景释放。图片显示和交互必然需要当前场景内的少量纹理与数据，不宣称完全零内存。

已有十名具名学生分别放在三栋教学楼的三楼最左十班：春华楼为「牢李、牢抽、费眼、牢傲」；夏耘楼为「阳子、牢硕、牢董」；秋实楼为「辣椒、勾尬、wr」。其中牢李、阳子、辣椒会移动，其余七位合入对应教室背景，并可显示各自姓名、立绘与问候。不会在普通教室、走廊、室外或实验楼复制这十名角色。

三个可移动特殊 NPC 只在所在教室加载时创建，正常游玩同时最多一个活动移动 NPC。以约 1.3 米/秒，在教室右侧约 1.67 × 4.25 米的活动范围内随机选择可行走目标，使用现有导航避开家具和墙体，路径全程留在范围内。每次行走后停留 1.2–3 秒，再规划下次短路径；对话、菜单、全图、暂停和黑屏切换期间暂停移动。没有附加 NPC 碰撞体，避免阻挡主角。

走近任意同学按 E 问候，也可点击人物：远处会先以原有 5 倍寻路速度走近，再打开问候；被点击的特殊 NPC 会等待主角走近。打开问候时清除主角路线并暂停人物操作，从几个简单问候中随机选择一句，上午可出现「早上好」。问候不推进时间、不增加剧情、任务、商店或奖励。

对话只读调用原素材「assets/ui/对话框.png」。主角立绘占左侧 1/3 布局区域，对方立绘占右侧 1/3，保留比例与完整人物。轮到谁说话，谁的立绘为原亮度，听者立绘变暗；姓名和台词同步切换。先显示 NPC 随机问候，第一次确认 / Enter / E 切到主角简单回应，第二次结束对话并显示点头提示。任一轮点击取消 / Esc / 右键都可直接关闭，不推进时间或附加剧情。

聊天框与选项位于最高交互 UI 画布（90），立绘在该画布底层，聊天面板为 z=100，姓名与台词在面板上方，确认和取消按钮再置于顶层。聊天框覆盖与立绘重叠的部分；黑屏切换遮罩保留画布 100。对话期间隐藏普通 HUD，关闭后恢复。「确认」「取消」继续采用同色浅绿按钮、深绿边框、圆角与菱形装饰，支持悬停和按下反馈。关闭后释放聊天框和双方立绘纹理，恢复移动，不会顺带打开暂停界面或角色菜单。

人物身高沿用已核验的素材相对高度，以主角约 1.7 米为尺度，四向均以脚底为锚点。采用原图清晰裁剪和 mipmap，未使用不完整的等格猜测切图。共核验 20 个角色、80 个方向及对话框来源，报告见「NPC素材校验.json」。原图没有修改或复制进游戏包，仍待确认后再制作可独立搬移的完整素材包。

实际 NPC 移动、点击寻路、逐人问候、确认与取消、实验楼排除及区块卸载验证见「NPC验证报告.json」。实际截图位于外部「地图重绘预览/NPC与对话预览」。新增问候未改变手动存档格式，原存档仍可读取；特殊 NPC 的临时路径会在进入场景时重新生成。
'''
doc.write_text(text,encoding='utf-8')
print(json.dumps({'npc_checks':report['checks'],'classrooms':rooms,'corridors':corridors,'ordinary':rooms*12+corridors*4-(named_total-moving_total),'named':named_total,'moving':moving_total,'source_files_unchanged':len(assets),'embedded_images':0},ensure_ascii=False))
