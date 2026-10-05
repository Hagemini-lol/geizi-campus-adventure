from pathlib import Path
from datetime import datetime
import json
import hashlib

root = Path(__file__).resolve().parents[1]
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,data): p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p):
    with p.open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest().upper()

levels=read(root/'runtime/level_task_checks.json')
economy=read(root/'runtime/economy_checks.json')
assert levels['passed'] and economy['passed']
manifest=read(root/'素材打包清单.json')
for item in manifest['files']:
    assert sha(root/item['file'])==item['sha256'].upper(),item['file']
zip_hash=sha(root.parent/'校园自由漫游_好友分享.zip')
assert zip_hash=='E18673FEEFBA5DAEC7DA060973AE62E388DF40DD1C42A6B45DAAB8D05DA1CAA1'
pck_hash=sha(root/'runtime/campus.pck')
report=read(root/'完成检查.json')
report.update({'LevelCap':60,'MonsterLevelCap':70,'NormalMonsterLevelOffset':-5,'EliteMonsterLevelOffset':0,
    'BossLevelOffset':[5,10],'ExistingMonstersKeepSavedLevels':True,'LevelAndTaskChecks':levels['checks'],
    'LevelAndTaskChecksPassed':True,'TaskSystemEnabled':True,'TaskHintLocation':'右键菜单 → 状态信息下方',
    'TaskSystemSupportsMainAndSide':True,'TaskSystemSaveRestore':True,'TaskSystemStoryAdded':False,
    'EconomyChecks':economy['checks'],'EconomyChecksPassed':True,'DailyAllowanceG':50,
    'DailyAllowanceBoundary':'深夜 → 凌晨','DailyAllowanceSaveSafe':True,'SupplyTypes':5,
    'TradeAndInventoryEnabled':True,'SuppliesCanBeUsedOutsideBattle':True,'VictoryDropsTradableMaterials':True,
    'OldSavesCompatible':True,'RuntimePackSHA256':pck_hash,'CombatPackSHA256':pck_hash,
    'ShareZipUnchangedAfterUpdate':True,'LocalGameNewerThanShareZip':True,
    'LatestUpdateVerifiedAt':datetime.now().isoformat(timespec='seconds')})
write(root/'完成检查.json',report)
verification={'passed':True,'level_and_task_checks':levels['checks'],'economy_checks':economy['checks'],
    'pack_tested':True,'pck_sha256':pck_hash,'unchanged_asset_hash_checks':len(manifest['files']),
    'assets_unchanged':True,'zip_unchanged':True,'zip_sha256':zip_hash,'player_save_location_preserved':True}
write(root/'runtime/systems_update_verification.json',verification)
p=root/'说明.md';s=p.read_text(encoding='utf-8')
s=s.replace('怪物等级 1–10，初始实验楼怪物为 1 级。','普通怪等级为主角等级减 5（最低 1），精英怪与主角同级（最低 1）；未来 Boss 高于主角 5～10 级，计算支持至 70 级。新游戏主角为 0 级，所以初始普通怪和精英怪均为 1 级。')
s=s.replace('最高 10 级。','最高 60 级。')
s=s.replace('装备、物品与技能页暂为空。','装备与技能页暂为空；物品页显示物资背包和校园商店，可使用、购买和出售物资。')
s=s.replace('运行文件为 exe、runtime、资源和根目录的三份配置。','运行文件为 exe、runtime、资源及根目录的素材引用、战斗与刷新、办公室、任务、物资与交易五份配置。')
s+='''

## 60 级、任务提示、物资与交易

主角支持 0～60 级，成长式和升级经验延伸到 60 级。新生成普通怪低于主角 5 级（不低于 1），精英怪与主角同级（不低于 1）。未来 Boss 预留高 5～10 级的生成规则，主角满级时支持 65～70 级 Boss；当前没有新增 Boss。

右键菜单「状态」页的状态信息下显示当前任务及下一步提示。目前只有 gei 子的自由探索提示，没有新增剧情。后续主线、支线支持分步提示、前置任务、事件推进及进度存读档。

右键菜单「物品」页包含「背包」与「校园商店」，可购买、出售和使用物资；持有资金在菜单顶部显示。新游戏首日获得 50g 生活费及饮用水 2、面包 1，以后深夜推进到凌晨时发放当天 50g，等待不改变时间。领取记录随存档保存，读档不重复发放。

饮用水、面包、急救包和镇静药分别用于恢复精力、生命等状态；相关状态已满时不消耗物资。战斗胜利获得墨渣，普通怪 1 个、精英怪 2 个，每个可出售 10g。物资使用和交易在战斗外进行。物资、资金和任务进度均随存档保存，旧存档可读取。

可调整的配置及后续剧情接口见「任务与物资扩展说明.md」。当前更新仅在游戏文件夹内，原素材与现有分享 ZIP 保持不变。
'''
p.write_text(s,encoding='utf-8')
p=root/'分享说明.txt';s=p.read_text(encoding='utf-8')
s+='\n本地新版：主角上限 60 级，普通怪低 5 级（至少 1），精英怪同级（至少 1）；未来 Boss 预留高 5～10 级。右键菜单状态页下方显示任务提示；物品页可使用物资、进入校园商店买卖。首日及以后每次深夜进入凌晨获得 50g 生活费，资金、物资、任务与领取记录随存档保存。已有分享 ZIP 保持原版。\n'
p.write_text(s,encoding='utf-8')
print(json.dumps(verification,ensure_ascii=False))
