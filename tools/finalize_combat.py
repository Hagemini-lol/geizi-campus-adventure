import hashlib
import json
from pathlib import Path

game=Path(__file__).resolve().parents[1]
original=game.parent/'Projects/赵慕gei的牙林冒险'
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest().upper()
report=read(game/'战斗与刷新验证报告.json')
npc=read(game/'NPC验证报告.json')
assert not report['failures'] and npc['passed']
assert report['pack']==''  # Godot's exported res:// has no filesystem directory.
assert 'COMBAT_CHECK '+str(report['checks'])+' failures=0' in (game/'runtime/combat_pack_checks.log').read_text(encoding='utf-8')
assert not [p for p in game.rglob('*') if p.suffix.lower() in ('.png','.jpg','.jpeg')]
for item in read(game/'NPC素材校验.json'):assert sha(Path(item['Path']))==item['SHA256']
files=list((original/'assets/characters/monsters').glob('*.png'))
files+=list((original/'assets/characters/hero/battle').glob('*.png'))
files+=list((original/'scenes/ui/battle').rglob('*.tscn'))
files+=list((original/'scripts/ui/battle').rglob('*.gd'))
files+=[original/'scripts/ui/ui_style.gd',original/'scripts/ui/option_button.gd',original/'data/battle_ui_library.json',original/'data/battle_action_library.json']
audit=[{'Path':str(p),'SHA256':sha(p),'Access':'external_read_only'} for p in files]
(game/'战斗素材校验.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
completion=read(game/'完成检查.json')
completion.update(CombatChecks=report['checks'],CombatChecksPassed=True,CombatPackSHA256=sha(game/'runtime/campus.pck'),
                  BattleOriginalUIUsed=True,MonsterOriginalPortraitsUsed=True,BattleAssetsExternal=True,
                  MonsterSpawnZones=28,MonsterClassroomCap=2,MonsterCorridorCap=3,
                  InitialRarityWeights={'normal':.8,'elite':.2},PeriodOrdinarySpawns=1,PeriodEliteProbability=.2,
                  MutableMonsterRegions=True,MonsterReentryDoesNotReroll=True,CombatSaveRestore=True,
                  ExperienceRequirements='floor(100*level^1.5)',KillExperience='enemy_max_hp*hero_level',LevelCap=10,
                  HeroAttackGrowth='100+100*level',ZeroLevelDefenderDenominator=1,MinimumDamage='floor(attacker_attack/10)',
                  NPCChecks=npc['checks'],NPCChecksPassed=True,NPCOrdinaryTotal=1540,NPCSpecialTotal=30,
                  NPCMovingTotal=30,NPCStaticNamedTotal=0,NPCOrdinaryPerTenClass=4,
                  NPCMovingIds=list(report['named_copies']),NPCTenClassRosters=npc['ten_class_rosters'],
                  NPCMovingSpeedMetersPerSecond=.5,NPCNamedCopyCounts=report['named_copies'],
                  NPCPackageSHA256=sha(game/'runtime/campus.pck'))
(game/'完成检查.json').write_text(json.dumps(completion,ensure_ascii=False,indent=2),encoding='utf-8')
doc=game/'说明.md'
s=doc.read_text(encoding='utf-8')
s=s.replace('三个十班各保留 12 名静态学生加 1 名移动学生，其中部分静态学生换为具名角色。','三个十班各保留 4 名静态普通学生和 10 名移动具名学生，共 14 人，少于座位的一半。')
s=s.replace('合计 1557 个普通 NPC、7 个静态具名 NPC、3 个移动具名 NPC 交互位置','合计 1540 个普通 NPC、30 个移动具名 NPC 交互位置')
a=s.index('已有十名具名学生分别放在三栋教学楼')
b=s.index('\n走近任意同学按 E 问候',a)
s=s[:a]+'''已有十名具名学生「牢李、牢抽、费眼、牢傲、阳子、牢硕、牢董、辣椒、勾尬、wr」全部出现在春华楼、夏耘楼、秋实楼三楼最左十班中，每名角色各有三份，共 30 个具名 NPC。所有具名角色都以约 0.5 米/秒缓慢移动，只有加载十班时才创建，对话、战斗、菜单、全图、暂停及黑屏切换期间停止。路径受教室活动范围与导航约束，不会离开教室，也不会生成到普通教室、走廊、室外或实验楼。普通同学继续合入背景，具名角色不附加碰撞体，不阻挡主角。
''' +s[b:]
s=s.replace('新增问候未改变手动存档格式，原存档仍可读取；','战斗数据作为可选字段扩充手动存档，原存档仍可读取；')
s=s.split('\n## 怪物刷新区、战斗与经验')[0]
s+='''

## 怪物刷新区、战斗与经验

实验楼四层走廊和 24 间教室均为怪物刷新区，共 28 个独立加载场景，确认实验楼室内没有 NPC。每间教室最多 2 只、每条走廊最多 3 只。首次进入每个区块生成 1 只怪物：普通权重 0.8、精英权重 0.2，同类内部均匀抽取。刷新区的怪物位置避开墙、家具、出入口和生成时的主角位置。

每次手动快进或显式事件推进时间段，当前加载的刷新区尝试生成 1 只普通怪，并有 0.2 概率额外生成 1 只精英怪；人数上限优先，满员时停止生成。未加载的区块不会在后台补刷。首次生成和怪物剩余血量持久保存，离开再进入不会重新抽取。时间段循环到同名时段仍计作一次推进，走路、战斗回合、问候和场景切换不推动时间。

走近怪物按 E 进入战斗；点击怪物可先以原有 5 倍速自动寻路靠近再开始战斗。地图上的怪物不额外阻挡通路，避免在窄走廊卡住。只加载当前区块的怪物贴图，普通校园场景不加载怪物立绘或战斗界面。

战斗直接只读调用原项目的 battle_interface.tscn、共用战场、人物槽、六个类别、独立子菜单、按钮及动作素材。主角为原斜后视角，敌方为四向怪物素材的完整正面裁剪；界面和角色在退出战斗后释放。战斗期间锁定漫游、快进、地图、菜单和存读档。

| 操作 | 当前规则 |
| --- | --- |
| 普通攻击 | 物理伤害，消耗 10 精力 |
| 法术攻击 | 法术伤害，消耗 10 MP |
| 闪避 | 消耗 20 精力，50% 概率完全躲过本次敌方攻击 |
| 防守 | 本次敌方攻击减伤 50%，恢复 15 精力；仍遵守最低伤害 |
| 休整 | 恢复 20 MP、50 精力，敌方仍会行动 |
| 撤离 | 确认后退出，保留双方剩余血量，不获得经验 |
| 挂机 | 自动普攻，精力不足时休整；可再次选择停止 |

键盘 1–6 分别为普攻、法术、闪避、防守、休整、挂机。Esc / 右键打开撤离确认；Esc 取消确认。结算后点击「返回地图」或按 Enter。胜利从地图移除该只怪物并结算经验；失败不获得经验，返回南门恢复资源，敌方保留剩余血量。

物理伤害为 floor(攻击 × 攻击方等级 / max(1,防守方等级) × (100−有效防御)/100 × (1−物理减免率))；法术伤害为 floor(攻击 × 攻击方等级 / max(1,防守方等级) × (1−法术减免率) − 法术抗性)。最终伤害均不低于 floor(攻击方攻击/10)，因此 0 级攻击方有最低伤害，0 级防守方不会除零。有效防御为 max(0,防御−攻击穿透)，初始穿透为 0；防守临时减伤在最终最低伤害之前计算。属性、完整成长公式和最终伤害向下取整，中间等级比、指数、倍率和概率保留小数。

主角初始 0 级，攻击成长 100+100×等级；血量、MP、精力、SAN、防御和法术抗性采用指定成长式。怪物等级 1–10，初始实验楼怪物为 1 级。四种怪物的倍率与物理/法术减免率均按配置实现。

每次击杀获得「敌方最大血量 × 击杀时主角等级」经验，只在胜利时结算一次。升级需求为 floor(100×当前等级^1.5)，扣除该级需求后保留余数，支持一次击杀连续升级，最高 10 级。按照公式，0 级升 1 级需求为 0，所以 0 级首次击杀获得 0 经验，但在该次胜利后升至 1 级；不会在打开游戏或读档时自动升级。升级重新计算属性，并为当前资源增加最大值的成长差额，保留之前消耗的部分；不自动回满。菜单状态和战斗信息显示等级与经验。

存档新增可选 combat 字段，保存等级、经验、四种当前资源、所有已初始化区块的怪物及其血量/位置、刷新序号和区域事件覆盖规则。旧存档没有该字段时使用初始战斗状态。损坏或超限战斗数据在加载前拒绝，当前游戏不变。

### 调整数值与区域

游戏根目录「战斗与刷新配置.json」独立于 PCK。调整后重新打开游戏即可应用。hero.stats 的每个属性使用 base、growth、exponent；terms 可叠加多个成长项并在求和后统一向下取整。character_profiles 预留其它角色成长配置，combat_rules.character_stats(id,level) 可生成其数值；主角升级接口为 set_hero_level(level,refill)。monsters 按稳定 id 注册，增加条目即可加入相应 rarity（normal / elite）抽取池，支持独立倍率、减免、外部素材路径和物体高度。当前素材为 2×2 四向布局，运行时取左上正面。enemy attack_kind 可选择 physical / magic。

spawn_regions 支持 building、kinds、floors、rooms 过滤；空楼层/教室列表表示该楼全部。规则可设置 enabled、level、initial_count、capacity、bounds；bounds 为场景本地像素范围 [x,y,width,height]，始终受地图导航约束。事件接口 main.set_monster_region(context,patch) 可修改单个区块，立即更新当前加载场景；覆盖数据进入存档。禁用区块会隐藏其怪物但保留数据，再启用时恢复。改变范围会重新安置范围外的怪物，调整等级影响之后新增怪物，不回满既有怪物；容量始终不超过教室 2、走廊 3。没有增加剧情或自动剧情触发。

例：set_monster_region({"building":"B02","floor":2,"kind":"classroom","room":1},{"enabled":false}) 可关闭实验楼二楼第二间教室；将 enabled 设 true 可重新启用。其它教学楼室内也可通过该接口成为刷新区，原始校园区域默认不刷怪。

实装验证报告为「战斗与刷新验证报告.json」，素材只读校验为「战斗素材校验.json」，实际战斗和 NPC 截图位于外部「地图重绘预览/战斗与刷新预览」。原地图、人物、怪物及 UI 素材未复制到游戏包内，仍按既有要求等待确认。
'''
doc.write_text(s,encoding='utf-8')
print(json.dumps({'combat_checks':report['checks'],'named_copies':report['named_copies'],'original_external_files':len(audit),'embedded_images':0,'pack_bytes':(game/'runtime/campus.pck').stat().st_size},ensure_ascii=False))
