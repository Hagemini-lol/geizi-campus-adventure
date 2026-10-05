from pathlib import Path
import hashlib
import json
from datetime import datetime
from PIL import Image

root = Path(__file__).resolve().parents[1]
def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p, value):
    p.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
def sha(p):
    with p.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

repairs = read(root/'runtime/stadium_repair.json')
manifest = read(root/'素材打包清单.json')
changed = set(repairs['files'])
found = set()
for item in manifest['files']:
    if item['file'] not in changed:
        assert sha(root/item['file']) == item['sha256'],item['file']
        continue
    p = root/item['file']
    item['bytes'] = p.stat().st_size
    item['sha256'] = sha(p)
    found.add(item['file'])
assert found == changed, changed-found
manifest['total_bytes'] = sum(item['bytes'] for item in manifest['files'])
manifest['local_sports_background_repair'] = 'runtime/stadium_repair.json'
write(root/'素材打包清单.json', manifest)

sizes = []
for relative in repairs['files']:
    with Image.open(root/relative) as im:
        if '/高清切片/' in relative:
            quality = int(Path(relative).stem.rsplit('_',1)[1])
            assert im.size == (258*quality,258*quality),relative
        sizes.append(im.size)
# Check duplicated bleed pixels inside the newly drawn field, where neighbouring
# tiles must show identical pixels at the same world coordinate.
tiles = root/'资源/地图/静态区块/高清切片'
seams = 0
for y in range(8,23):
    for x in range(4,12):
        with Image.open(tiles/f'{x}_{y}_4.png') as left, Image.open(tiles/f'{x+1}_{y}_4.png') as right:
            left = left.convert('RGBA');right = right.convert('RGBA')
            for row in [120,360,600,840]:
                for col in range(8):
                    assert left.getpixel((1024+col,row)) == right.getpixel((col,row)), (x,y,row,col)
                    seams += 1

originals = read(root/'原素材校验快照.json')
original_failures = []
historical_diffs = read(root/'分享包完整性验证.json')['historical_snapshot_differences_predating_packaging']
historical_verified = []
for item in originals:
    source = Path(item['Path'])
    current_sha = sha(source)
    if current_sha.upper() == item['SHA256'].upper():
        continue
    # The packaging report already records seven asset replacements predating
    # this update. Their unchanged packaged raw copies are the newer baseline.
    if item['Path'] in historical_diffs:
        packaged = root/'资源/原项目'/source.relative_to(root.parent/'Projects/赵慕gei的牙林冒险')
        if sha(packaged) == current_sha:
            historical_verified.append(item['Path'])
            continue
    original_failures.append(item['Path'])
assert not original_failures,original_failures
zip_path=root.parent/'校园自由漫游_好友分享.zip'
zip_sha=sha(zip_path).upper()
assert zip_sha=='E18673FEEFBA5DAEC7DA060973AE62E388DF40DD1C42A6B45DAAB8D05DA1CAA1'

lesson=read(root/'runtime/lesson_checks.json')
npcs=read(root/'NPC验证报告.json')
walk=read(root/'行走动画验证.json')
assert lesson['passed'] and npcs['passed'] and not walk['failures']
qa={'passed':True,'changed_background_files':len(changed),'hd_tiles':repairs['hd_tiles'],
    'hd_resolution_verified':True,'matching_bleed_pixels':seams,
    'original_source_hash_checks':len(originals),'original_sources_unchanged':True,
    'older_snapshot_differences_verified_against_packaged_raw_copies':historical_verified,
    'zip_sha256':zip_sha,'zip_unchanged':True,'pck_sha256':sha(root/'runtime/campus.pck').upper(),
    'lesson_checks':lesson['checks'],'lesson_hold_seconds':lesson['lesson_hold_seconds'],
    'npc_regression_checks':npcs['checks'],'walk_regression_checks':walk['checks'],
    'verified_at':datetime.now().isoformat(timespec='seconds')}
write(root/'runtime/lesson_update_verification.json',qa)
report=read(root/'完成检查.json')
report.update({'LessonSystemChecksPassed':True,'LessonSystemChecks':lesson['checks'],
    'LessonBlackTextSeconds':lesson['lesson_hold_seconds'],'LessonClassroomBuildings':['B12','B05','B01'],
    'LessonPeriods':['上午','下午'],'LessonStudentsPerClass':31,'LessonTeachersPerClass':1,
    'LessonOrdinaryStudentsPerTenClass':21,'LessonHeroSeatIndex':16,
    'NPCOrdinaryPerTenClass':{'上午':21,'下午':21,'凌晨':0,'晚上':0,'深夜':0},
    'TenClassNamedOnly':False,'TenClassNamedOnlyOutsideLessons':True,
    'OfficeAndCorridorNPCConfigUnchanged':True,'LaboratoryNPCFreeVerified':True,
    'InteractionRadiusMeters':.5,'InteractionRadiusWorldPixels':12,
    'SportsArtRepaired':True,'SportsHDRepairedTiles':repairs['hd_tiles'],
    'SportsRepairBackgroundFiles':len(changed),'SportsRepairSeamSamples':seams,
    'RuntimePackSHA256':qa['pck_sha256'],'CombatPackSHA256':qa['pck_sha256'],
    'ShareZipUnchangedAfterUpdate':True,'LocalGameNewerThanShareZip':True,
    'LatestUpdateVerifiedAt':qa['verified_at']})
write(root/'完成检查.json',report)

p=root/'说明.md'
s=p.read_text(encoding='utf-8')
s=s.replace('- E：与附近的门、楼梯或墙上告示牌交互。也可点击门的贴图自动走向入口。','- E：在交互点周围 0.5 米内与人物、怪物、门、楼梯、告示牌或自己的上课座位交互。点击人物或门会先自动走近；白色圆圈标出上课座位。')
s=s.replace('当前游戏目录中的十班仅有具名 NPC；既有 ZIP 保留制作时的内容。','当前游戏目录包含十班上课系统及体育场修复；既有 ZIP 保留制作时的内容。')
s=s.replace('三个十班各只保留 10 名移动具名学生，不生成普通学生。','三个十班在凌晨、晚上、深夜各只保留 10 名移动具名学生；上午、下午安排 10 名具名学生与 21 名普通学生入座，并安排 1 名老师，留下主角座位。')
s=s.replace('合计 1242 名普通学生、78 名办公人员、30 名移动具名学生','非上课时段合计 1242 名普通学生、78 名办公人员、30 名移动具名学生；上课时段普通学生增至 1305 名、讲台老师另有 3 名、具名学生改为坐姿')
s=s.replace('所有具名角色都以约 0.5 米/秒缓慢移动，只有加载十班时才创建，','非上课时段，所有具名角色都以约 0.5 米/秒缓慢移动，只有加载十班时才创建，')
s=s.replace('普通教室仍安排 12 名普通学生，十班只有 10 名缓慢移动的具名学生，走廊各有 4 名普通学生。','普通教室仍安排 12 名普通学生，走廊各有 4 名普通学生。十班在非上课时段有 10 名缓慢移动的具名学生，上午、下午则用普通学生补满除主角外的座位。')
s+='''

## 十班上课与近距离交互

上午、下午只在春华楼、夏耘楼、秋实楼三楼最左侧十班启用上课。31 个学生座位由 10 名具名学生与 21 名普通学生填满，主角靠窗倒数第二排的座位留空，并显示白色圆圈。上午的班主任、下午的英语老师在讲台旁；上课时段学生不移动，贴图一次合入当前教室背景，不为每个学生创建 AI 或独立精灵节点。其他时段移除补位普通学生和讲台老师，10 名具名同学恢复缓慢移动。办公室、走廊维持原配置，实验楼不生成 NPC。

走到白色圆圈旁按 E，确认上课后渐入黑屏，文字说明保持 2 秒；黑屏期间上午转为下午、下午转为晚上，随后渐出。取消不会改变时间。上课不增加经验或剧情，已完成的上课次数随存档保存；读取存档时会按恢复的时间段重新安排学生和老师。

人物、怪物及地图交互统一限定在交互点周围 12 个逻辑像素（0.5 米）内。点击人物仍可自动走近再问候，点击白圈会走到座位旁，按 E 开始；家具碰撞维持 1 个逻辑像素，道路跨区切换功能保持原样。

体育场保持跑道外圈 150 × 250 米、足球场 120 × 180 米，重新绘制人身比例的球门、标线、中圈、跑道与主席台。球门宽 7.32 米，中圈直径 18.3 米，跑道单道宽 1.22 米。修复同时更新 9 张重叠区块底图及 364 张高清切片的三档版本，仍按镜头加载。检查及运行画面位于游戏文件夹 runtime/上课与体育场预览。
'''
p.write_text(s,encoding='utf-8')
p=root/'分享说明.txt'
s=p.read_text(encoding='utf-8').replace('三个教学楼三楼最左侧仍为十班，只出现具名学生，均在十班内缓慢移动。','三个教学楼三楼最左侧为十班：上午、下午有 31 名入座学生和讲台旁老师，主角白圈座位按 E 上课，黑屏说明显示 2 秒后进入下个时间段；其他时段仅具名同学缓慢移动。')
s+='\n本地新版已修复体育场。交互距离为交互点周围 0.5 米；点击人物会先自动走近。上课仅用于三个教学楼十班，办公室和走廊配置保持原样，实验楼不放 NPC。\n'
p.write_text(s,encoding='utf-8')
print(json.dumps(qa,ensure_ascii=False))
