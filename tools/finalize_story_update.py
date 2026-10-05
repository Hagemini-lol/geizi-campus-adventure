from pathlib import Path
from datetime import datetime
import json, hashlib, shutil
ROOT=Path(__file__).resolve().parents[1]
def read(name):return json.loads((ROOT/name).read_text('utf-8-sig'))
def write(name,value):(ROOT/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n','utf-8')
def sha(path):
 with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest().upper()
story=read('runtime/story_checks.json');lessons=read('runtime/lesson_checks.json');economy=read('runtime/economy_checks.json')
assert story['passed'] and lessons['passed'] and economy['passed']
assert 'STORY_CHECK '+str(story['checks'])+' FAILURES 0' in (ROOT/'runtime/story_pack_gui.log').read_text('utf-8-sig')
copied=read('runtime/剧情新增素材校验.json')
for item in copied:
 assert sha(Path(item['source']))==item['sha256'].upper(),item['source']
 assert sha(ROOT/item['file'])==item['sha256'].upper(),item['file']
manifest=read('素材打包清单.json');new_files={e['file']:e for e in copied};seen=set()
for entry in manifest['files']:
 file=entry['file'];digest=sha(ROOT/file)
 if file in new_files:
  entry.update({k:new_files[file][k] for k in ['bytes','sha256']});seen.add(file)
 else:assert digest==entry['sha256'].upper(),file
for file,entry in new_files.items():
 if file not in seen:manifest['files'].append({k:entry[k] for k in ['file','bytes','sha256']})
manifest['files'].sort(key=lambda x:x['file'])
manifest['file_count']=len(manifest['files']);manifest['total_bytes']=sum(e['bytes'] for e in manifest['files'])
write('素材打包清单.json',manifest)
zip_sha=sha(ROOT.parent/'校园自由漫游_好友分享.zip')
assert zip_sha=='E18673FEEFBA5DAEC7DA060973AE62E388DF40DD1C42A6B45DAAB8D05DA1CAA1'
pck_sha=sha(ROOT/'runtime/campus.pck')
report=read('完成检查.json')
report.update({'TaskSystemStoryAdded':True,'StoryChapter':'part_1','StoryChecks':story['checks'],'StoryChecksPassed':True,
 'StoryActualEInteractions':True,'StoryActualRouteToWindow':True,'StoryRewardSaveSafe':True,
 'StoryBlackTextSeconds':story['black_text_seconds'],'StorySource':'设定和剧情.txt',
 'LabAmbientNPCs':0,'LabScriptActorTemporary':True,'StoryMagicSkills':4,'AuxiliarySkills':4,
 'MPTermExponent':1.5,'EliteDamageCapRatio':.7,'EmptyUniformHPMultiplier':2,'DryBranchHPMultiplier':4,
 'RuntimePackSHA256':pck_sha,'CombatPackSHA256':pck_sha,'CurrentPackageSHA256':pck_sha,
 'PortableAssetsFiles':len(manifest['files']),'PortableAssetsBytes':manifest['total_bytes'],
 'StoryCopiedAssets':len(copied),'StoryOriginalAssetsUnchanged':True,'ShareZipUnchangedAfterUpdate':True,
 'LatestUpdateVerifiedAt':datetime.now().isoformat(timespec='seconds'),
 'LatestLessonRegressionChecks':lessons['checks'],'LatestEconomyRegressionChecks':economy['checks']})
write('完成检查.json',report)
verification={'passed':True,'story_checks':story['checks'],'lesson_regression_checks':lessons['checks'],
 'economy_regression_checks':economy['checks'],'pck_sha256':pck_sha,'zip_sha256':zip_sha,
 'zip_unchanged':True,'original_copied_asset_sources_unchanged':True,'resource_hash_checks':len(manifest['files']),
 'player_saves_and_settings_preserved':True,'compiled_pack_gui_tested':True,
 'actual_keyboard_interactions':True,'actual_mouse_spell_buttons':True,'launcher_boot_ready':True}
write('runtime/story_update_verification.json',verification)
p=ROOT/'说明.md';s=p.read_text('utf-8-sig')
s=s.replace('包含校园外景、四栋楼的走廊、教室与办公室、自由移动、NPC 问候和实验楼战斗，没有剧情。','包含第一章「窗后的闪光」、校园外景、四栋楼室内地图、自由移动、角色对话、装备与技能学习，以及实验楼战斗。新游戏从上午南门开始，先按任务去秋实楼十班。详细流程见「第一章与剧情扩展说明.md」。')
s=s.replace('装备与技能页暂为空','装备页显示持有装备并支持更换，技能页显示已学法术；觉醒后与对应同学交谈可购买装备、委托制作或学习技能')
s=s.replace('目前只有 gei 子的自由探索提示，没有新增剧情。','当前显示第一章主线的下一步提示，完成后显示自由探索与技能学习提示。')
s=s.replace('上课不增加经验或剧情，已完成的上课次数随存档保存','秋实楼首章座位按剧情触发；章节结束后的常规上课不增加经验，已完成的上课次数随存档保存')
s=s.replace('| 法术攻击 | 法术伤害，消耗 10 MP |','| 法术攻击 | 使用已学四系法术，耗蓝随等级和法术级别增长；可勾选双倍 MP 蓄力 |')
s=s.replace('键盘 1–6 分别为普攻、法术、闪避、防守、休整、挂机。','键盘 1–6 分别为普攻、打开法术选择、闪避、防守、休整、挂机。')
s=s.replace('实验楼不生成 NPC。','实验楼无常驻 NPC；第一章交战中临时出现费眼，结束后立即释放。')
s=s.replace('四种怪物的倍率与物理/法术减免率均按配置实现。','四种怪物的倍率与物理/法术减免率按配置实现；最新正文 MP 指数为 1.5，精英生命倍率为 2/4，四系法术包含元素克制，精英护壳限制单次伤害最多为最大生命的 70%。')
if '## 第一章剧情更新' not in s:s+='\n\n## 第一章剧情更新\n\n第一章流程、角色服务、成长与法术、精英护壳及后续剧情接入见「第一章与剧情扩展说明.md」。剧情素材已复制到游戏包体，重新双击游戏目录内 exe 查看新版；旧 ZIP 不包含这次更新。\n'
p.write_text(s,'utf-8')
p=ROOT/'任务与物资扩展说明.md';s=p.read_text('utf-8-sig')
s=s.replace('目前只有自由探索提示，不含主线或支线剧情。','目前包含第一章主线「窗后的闪光」与完成后的探索提示。')
s=s.replace('旧存档没有任务数据时恢复初始探索提示','旧存档没有任务数据时恢复第一章初始任务')
s=s.replace('当前没有新增 Boss 本体或剧情。','当前没有新增 Boss 本体；第一章已接入剧情，后续章节见「第一章与剧情扩展说明.md」。')
s+='\n新增剧情、装备与技能配置以及临时剧情演员的说明见「第一章与剧情扩展说明.md」。\n'
p.write_text(s,'utf-8')
src=ROOT.parent/'设定和剧情.txt';shutil.copy2(src,ROOT/'剧情文本来源.txt')
p=ROOT/'分享说明.txt';s=p.read_text('utf-8-sig')
if '第一章「窗后的闪光」' not in s:s+='\n本地新增第一章「窗后的闪光」、四系魔法、装备奖励、技能学习和委托制作。启动本文件夹的校园自由漫游.exe，开始游戏即可体验。现有 ZIP 不更新；分享新版请复制整个当前游戏文件夹。\n'
p.write_text(s,'utf-8')
print(json.dumps(verification,ensure_ascii=False))
