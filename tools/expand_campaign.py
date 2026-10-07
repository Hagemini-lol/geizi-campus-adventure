from pathlib import Path
import copy, json, re

root = Path(__file__).resolve().parents[1]
def read(name): return json.loads((root/name).read_text(encoding='utf-8-sig'))
def write(name, value): (root/name).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
nodes=[]
def node(id, chapter, title, location, actor, text, **kw):
    nodes.append(dict(id=id,chapter=chapter,title=title,location=location,cast=[actor,'zhao_mugei'],
        dialogue=[dict(actor=actor,text=text)],timeWindow=kw.pop('periods',[0,1,2,3,4]),
        requires=[nodes[-1]['id']] if nodes else [],mutexGroup='campaign_main',priority=1,
        repeatable=False,fallback='wait_or_retry',onTrigger=kw.pop('effects',{}),**kw))
ten='B01:3:0';lab='B02:1:corridor';lib='B06:1:0';roof='B15:4:0';seal='STORY_SEAL:1:0'
node('night_hunt','part_2','深夜：实验楼第一战',lab,'fei_yan','墨泥怪怕电。试试闪电链；MP 不足就休整，撑不住可以撤离，双方保留血量。',periods=[4],battle=['ink_slime'],event='monster_defeated/ink_slime')
node('next_dawn','part_2','回家 / 宿舍休息','N02','zhao_mugei','白天上课，晚上刷怪。先回去睡一觉，明天再说。',rest=True,event='days_passed')
node('yang_awakened','part_2','阳子的连珠炮',ten,'yang_zi','昨晚实验楼蓝一道白一道的，别再跟我说球形闪电了！',periods=[1],effects={'RP_H':10,'BOND_yang_zi':15},event='story/yang_awakened',extra=[['fei_yan','行吧，一个两个都是侦探。阳子，你过来。法术我能教，魔法书找牢李印。'],['zhao_mugei','欢迎入伙。以后晚上一块儿——刷怪。']],effect='world_magic_circle')
node('team_meet','part_3','主席台后的小会','S02','fei_yan','法力淤积久了会凝成怪物。要么地下有东西，要么有人故意的。',effects={'RP_H':10,'RP_D':5},event='story/team_meet')
node('handout','part_3','牢李：基础法术讲义', 'B12:3:0','lao_li','魔法书没有，讲义我给阳子印一本。墨渣自带，工本费 20g。暂时凑不齐也能留下委托，回来补印。',cost=20,materials={'ink_fragment':1},items={'basic_spell_handout':1},event='item_received/basic_spell_handout')
node('library_trace','part_3','巡查科技中心图书室',lib,'lao_chou','最里侧书架已经拉绳。书页一块块缺，还掉渣。先记录，不在这里动手。',event='story/library_trace')
node('warehouse_trace','part_3','巡查小仓库','B04','lao_chou','码好的枯枝自己挪窝，煤渣地上还有拖痕。三处异常，得放一起看。',event='story/warehouse_trace')
node('elite_lesson','part_3','实验楼：护壳教学',lab,'fei_yan','空壳校服怕光。精英有护壳，单次最多打掉 70% 生命，别指望满血一击秒杀。',battle=['empty_uniform'],event='story/elite_lesson')
node('patrol_done','part_3','向牢抽汇总线索',ten,'lao_chou','三处魔力全汇向办公楼，还有人为疏通痕迹。自然淤积不会这么整齐。是人干的。',event='story/patrol_done')
node('medium_lesson','part_3','向费眼学习中级法术',ten,'fei_yan','先练到 5 级，再学任意一种中级法术。四系每种 100g。缺经验就补课、训练或去实验楼。',require_level=5,require_medium=True,event='skill_learned/fire_medium')
node('library_enter','part_4','图书室：选择进入办法','B06','la_jiao','虫害消杀，图书室暂时关闭。要进去先想好办法，别拿全班的安全开玩笑。',choice='entry',event='story/library_enter')
node('books_clear','part_4','书架间清除三只噬书怪',lib,'yang_zi','小火精准点杀，别烧书！蓄力或中高级火法会触发喷淋、赔偿和信任损失。',battle=['book_eater']*3,event='story/books_clear')
node('wr_meet','part_4','阅览区：爱看书的 wr',lib,'wr','你们也是来抓虫的？虫巢在下面，那只大的再不处理，明天这儿就剩架子。',effects={'RP_H':5,'RP_W':15,'BOND_wr':10},event='story/wr_meet',effect='fire_low')
node('book_queen','part_4','半地下书库：大噬书怪','B06:1:1','wr','你们的火太亮，只烧得到封皮；要暗一点的火，才钻得进书页缝。先清小怪，再处理虫巢。',battle=['book_eater','book_eater','book_eater_queen'],items={'book_core':1,'dark_page':1,'ink_fragment':5},effects={'F_BOOK':True},event='monster_defeated/book_eater_queen')
node('li_start','part_5','牢李被举报',ten,'lao_li','我没有。群里只聊技术，值日表每次都签了字。那些截图是拼的。',choice='li_start',effects={'STATE':1},event='story/li_defame_start',extra=[['gou_ga','我就是试试，看你们一着急会不会把他推出去自己撇清。']],deadline=3)
node('li_hearing','part_5','班会：为牢李澄清',ten,'la_jiao','原始记录、截图鉴定、后勤报修单和考勤台账。至少拿来三份，或者说明暂时搁置。',choice='li_hearing',event='story/li_case_resolved')
node('office_infiltrate','part_5','夜探办公楼','B15:1:corridor','fei_yan','周六那晚的线索都指向这里。窗口不止一晚，整备好再去顶层。',periods=[3,4],battle=['dry_branch','dry_branch'],event='story/office_infiltrate')
node('ancient','part_5','顶层仪式阵：老树枯枝',roof,'gou_ga','就想看看，跑得最快的人，摔一跤啥样。——今天这局，可别让我失望。',battle=['dry_branch_ancient'],items={'wood_heart':1,'ritual_ash':1},effects={'RP_H':5},choice_after='gou',event='monster_defeated/dry_branch_ancient',disruption=True)
node('yang_frame','part_5_plus','公告栏：阳子被指控','N02','wen_cong','周末校内多处破坏并报失窃。阳子被指夜闯校园。三天内把能核实的证据送到政教处。',choice='yang_start',event='story/yang_frame_start',deadline=4)
node('yang_hearing','part_5_plus','政教处听证','B15:1:0','wen_cong','时间线、物证摆放、监控和证人需要交叉验证。请提交至少三份证据，或者申请以后补证。',choice='yang_hearing',event='story/yang_case_resolved')
node('dong_talk','part_6','牢董：等了两周',ten,'lao_dong','实验楼的电光、科技中心的墨、办公楼的阵，我都知道。封印漏得出渣，却不该有这半年规模。跟我来。',event='story/dong_talk')
node('dong_house','part_6','牢家旧宅','STORY_HOUSE:1:0','lao_dong','祖上是守印人。有人喂它、引流它，封印年限又将到——三股劲凑一起了。',event='story/dong_house')
node('rune','part_6','石室：补全符文数列',seal,'lao_chou','符文是 2、4、8、16、？。按顺序点亮石柱，错一回多挡一波怪，线索可以再看。',choice='rune',event='story/rune_solved')
node('seal_defend','part_6','守住封印表门',seal,'lao_dong','光系对空壳、火系对枯枝。三条路现在不用选，门开那天总得选一条。',battle=['empty_uniform','empty_uniform','dry_branch'],effects={'RP_H':5,'RP_W':5,'RP_D':20},items={'seal_shard':1},event='story/seal_defend')
node('tide_lab','part_7','夜袭：实验楼防线',lab,'fei_yan','阳子跟我守实验楼，牢董和牢硕守操场南门，牢傲跟 gei 子守秋实楼。牢李支援电网。',periods=[4],effects={'STATE':2},battle=['ink_slime','empty_uniform'],event='story/tide_lab')
node('tide_gate','part_7','夜袭：南门与操场','N02','lao_shuo','保家卫国我说了三年。今天先把同学都护住！',choice='grid',event='story/tide_gate')
node('tide_school','part_7','夜袭：秋实楼楼梯口','B01:1:corridor','la_jiao','都别出声，往高层撤！楼下交给你，上面的人我一个都不会少！',battle=['empty_uniform','dry_branch'],event='story/tide_defend')
node('ao_transform','part_7','魔法少男变身','B01:1:corridor','lao_ao','对不起了，本来想藏到毕业的。接下来一周，靠你们了。',battle=['empty_uniform_leader'],effect='lightning_high',transform=True,effects={'F_AO_TRANSFORMED':True},event='story/ao_transform')
node('tide_clear','part_7','天亮：清点人数','S01','la_jiao','一个都不少。可是守印碎片被趁乱取走了，这一夜是调虎离山。',effects={'F_CIVILIAN_SAFE':True,'RP_H':10,'RP_D':10,'F_LI_PARTIAL':True,'GOU_UNDERSTAND':1},event='story/tide_clear')
node('exam','part_8','期中考试',ten,'fei_yan','考试不许用法术作弊。牢抽押了三张纸，先看看；班长还等着收作业呢。',choice='exam',effects={'STATE':3},event='story/exam_done')
node('preparation','part_8','决战前夜：准备与路线',ten,'yang_zi','去年我在这儿摔下去，明天我在这儿站住。先找大家谈谈、补证、查碎片，再选我们的路。',choice='route',event='story/route_lock')
node('gate','part_9','门开之日：门扉战',seal,'lao_dong','封门、吞噬，还是解开——先守住门。最终战可重整两次，理智归零和主动背叛会改变结局。',battle=['gate_entity'],event='monster_defeated/gate_entity')
node('choice','part_9','最终抉择',seal,'gou_ga','你们本该恨我。可恨着我，跟拉我一把，真的不耽误么？',choice='ending',event='story/final_choice')

titles={'part_2':'深夜刷怪与阳子启蒙','part_3':'据点、人脉与异常点巡查','part_4':'图书室·书与魔女','part_5':'混沌之女·勾尬','part_5_plus':'白日审判','part_6':'六边形战士·牢家的封印','part_7':'变身·夜守校园','part_8':'期中考试与决战前夜','part_9':'门开之日'}
calendar={'part_2':0,'part_3':2,'part_4':5,'part_5':8,'part_5_plus':11,'part_6':15,'part_7':24,'part_8':25,'part_9':40}
for n in nodes:
 if n['id']=='team_meet':n['onTrigger'].update(BOND_fei_yan=10,BOND_lao_li=10,BOND_lao_chou=10,BOND_la_jiao=10)
 if n['id']=='dong_talk':n['onTrigger'].update(BOND_lao_dong=15)
for n in nodes:n['min_day']=calendar[n['chapter']]
for n in nodes:
 if n['id']=='li_hearing':n['min_day']=10
 if n['id']=='yang_hearing':n['min_day']=14
 if n['id']=='preparation':n['min_day']=39
cfg=read('剧情配置.json');cfg['campaign']={'version':1,'nodes':nodes,'chapter_titles':titles,'ending_retry_limit':2,'san_safety':40}
write('剧情配置.json',cfg)
tasks=read('任务配置.json');tasks['tasks']=[t for t in tasks['tasks'] if t['id'] not in titles]
previous='part_1'
for chapter,title in titles.items():
 tasks['tasks'].append({'id':chapter,'type':'main','title':title,'auto_start':True,'prerequisites':[previous], 'steps':[{'hint':n['title']+' → '+n['location']+' 白圈（E / X）','event':'campaign/'+n['id']} for n in nodes if n['chapter']==chapter]})
 previous=chapter
for t in tasks['tasks']:
 if t['id']=='after_part_1':t['steps']=[{'hint':'第二章至终章已开放。按主线提示探索，菜单状态页可打开剧情手册、证据与伙伴服务。'}]
write('任务配置.json',tasks)
economy=read('物资与交易配置.json')
items={'basic_spell_handout':('基础法术讲义','阳子的四系入门讲义，可向牢李补印。'),'dark_page':('黑魔法残页','wr 的赠物，魔女路线钥匙。'),'seal_shard':('守印碎片','真实碎片；真结局需要四块，或三真一赝。'),'seal_shard_fake':('仿制守印碎片','牢李的复刻品；真结局至多计一块。'),'book_core':('残缺书芯','图书室虫巢残留的线索。'),'wood_heart':('枯木心','老树枯枝留下的核心。'),'ritual_ash':('阵法残灰','供牢抽分析魔力流向。'),'insulation_bracer':('绝缘护腕·清者自清','牢李澄清后解锁；携带时电系伤害提高 10%。'),'flash_bomb':('一次性强光雷','牢傲虚弱期间的光系替代，每场至多消耗一枚。')}
existing={i['id'] for i in economy['items']}
for id,(name,description) in items.items():
 if id not in existing:economy['items'].append({'id':id,'name':name,'description':description,'plot_item':True,'buy_price':-1,'sell_price':0,'restore':{}})
economy['monster_loot']['boss']={'ink_fragment':5}
write('物资与交易配置.json',economy)
combat=read('战斗与刷新配置.json')
for id,base,name,level,hp in [('book_eater_queen','book_eater','大噬书怪',8,2),('dry_branch_ancient','dry_branch','老树枯枝',10,4),('empty_uniform_leader','empty_uniform','升旗手',15,2),('gate_entity','empty_uniform','门扉之影',0,6)]:
 boss=copy.deepcopy(combat['monsters'][base]);boss.update(name=name,rarity='boss',level_mode='fixed' if level else 'hero_relative',level=level,scripted_only=True)
 boss['multipliers']['hp']=hp;boss['world_height']=60 if id=='gate_entity' else 48
 boss['elemental_reductions']={} if id=='gate_entity' else {'fire':-.5} if base in ['book_eater','dry_branch'] else {'light':-.5}
 combat['monsters'][id]=boss
combat['skills']['dark_flame']={'name':'黑火转化','kind':'magic','element':'dark','tier':'high','effect':'fire_high','teacher':'wr','level':1,'price':0,'san_cost':8}
write('战斗与刷新配置.json',combat)
print('CAMPAIGN_CONFIG_READY',len(nodes),'events, 9 chapters, 4 bosses')
