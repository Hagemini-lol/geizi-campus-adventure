import json, pathlib, shutil, hashlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
ORIGINAL = ROOT.parent / 'Projects/赵慕gei的牙林冒险'
def read(name): return json.loads((ROOT/name).read_text('utf-8-sig'))
def write(name, value): (ROOT/name).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', 'utf-8')
effects=json.loads((ORIGINAL/'data/magic_effects_01.json').read_text('utf-8-sig'))
copied=[]
for rel in ['data/magic_effects_01.json']+[e['texture'].removeprefix('res://') for e in effects['entries']]:
    src=ORIGINAL/rel; dst=ROOT/'资源/原项目'/rel; dst.parent.mkdir(parents=True,exist_ok=True)
    original_hash=hashlib.sha256(src.read_bytes()).hexdigest()
    shutil.copy2(src,dst)
    copied.append({'source':str(src),'file':dst.relative_to(ROOT).as_posix(),'bytes':dst.stat().st_size,'sha256':original_hash})
write('runtime/剧情新增素材校验.json',copied)
config=read('战斗与刷新配置.json'); config['version']=2
config['hero']['stats']['mp']['exponent']=1.5
config['monsters']['empty_uniform']['multipliers']['hp']=2
config['monsters']['dry_branch']['multipliers']['hp']=4
for id,element,reduction in [('ink_slime','lightning',-1),('book_eater','fire',-1),('empty_uniform','light',-.5),('dry_branch','fire',-.5)]:
    config['monsters'][id]['elemental_reductions']={element:reduction}
config['elite_damage_cap_ratio']=.7
config['equipment']={
 'special_uniform':{'name':'特制校服','slot':'armor','bonuses':{'defense':20,'magic_resistance':20}},
 'basic_amulet':{'name':'基础护符','slot':'accessory','bonuses':{'attack':200}},
 'tech_amulet':{'name':'改装护符','slot':'accessory','bonuses':{'attack':240}},
 'patrol_uniform':{'name':'巡查校服','slot':'armor','bonuses':{'defense':30,'magic_resistance':20}}}
tiers={'low':{'base':10,'growth':20,'multiplier':1,'level':1,'price':0},'medium':{'base':50,'growth':30,'multiplier':1.5,'level':5,'price':100},'high':{'base':100,'growth':50,'multiplier':3,'level':15,'price':200},'super':{'base':1000,'growth':50,'multiplier':5,'level':35,'price':400}}
config['magic_tiers']=tiers
config['skills']={}
for element in ['fire','lightning','frost','light']:
    for tier in tiers:
        art=next(e for e in effects['entries'] if e['id']==element+'_'+('high' if tier=='super' else tier))
        names={'fire':'天火降临','lightning':'终末雷霆','frost':'永冻领域','light':'极昼辉光'}
        config['skills'][element+'_'+tier]={'name':names[element] if tier=='super' else art['name'],'kind':'magic','element':element,'tier':tier,'effect':art['id'],'teacher':'fei_yan','level':tiers[tier]['level'],'price':tiers[tier]['price']}
config['skills'].update({
 'barrier':{'name':'魔力屏障','kind':'support','teacher':'fei_yan','level':1,'price':30,'description':'消耗 20+5×等级 MP，连续两次敌方攻击减伤 50%，冷却 3 回合'},
 'focus':{'name':'专注施法','kind':'support','teacher':'fei_yan','level':1,'price':20,'description':'消耗 20 精力，下一次法术伤害提高 25%，冷却 3 回合；本回合敌方行动'},
 'mana_cycle':{'name':'魔力回流','kind':'support','teacher':'fei_yan','level':1,'price':30,'description':'消耗 30 精力，恢复 10+10×等级 MP，冷却 3 回合；本回合敌方行动'},
 'steady_guard':{'name':'稳固防线','kind':'support','teacher':'lao_shuo','level':1,'price':30,'description':'消耗 30 精力，本次敌方攻击减伤 65%，冷却 3 回合'}})
config['actions']=[a for a in config['actions'] if a['id']!='magic']
write('战斗与刷新配置.json',config)
economy=read('物资与交易配置.json')
extra={
 'special_uniform':('特制校服','防御 +20，法术抗性 +20',-1,''),
 'basic_amulet':('基础护符','攻击 +200',-1,''),
 'basic_magic_book':('基础魔法书','记载火、电、冰、光四种低级魔法',-1,''),
 'tech_amulet':('改装护符','攻击 +240；委托牢李制作，需要 2 份墨屑',100,'lao_li'),
 'patrol_uniform':('巡查校服','防御 +30，法术抗性 +20',150,'lao_shuo')}
economy['items']=[i for i in economy['items'] if i['id'] not in extra]
for id,(name,desc,price,merchant) in extra.items():economy['items'].append({'id':id,'name':name,'description':desc,'buy_price':price,'sell_price':0,'restore':{},'merchant':merchant,'plot_item':True})
write('物资与交易配置.json',economy)
def line(actor,text):return {'actor':actor,'text':text}
dialogues={
 'morning':[line(a,t) for a,t in [('zhao_mugei','你们是不是废啊，昨天阿根廷输了你们看没看啊。'),('fei_yan','没看啊，谁大晚上看这玩意啊。'),('zhao_mugei','对啊，我也没看，我昨天跟手机客服说能不能把手机邮给我打七天王者再退回去。'),('fei_yan','太贱了'),('lao_li','太贱了'),('lao_ao','太贱了'),('lao_shuo','太贱了'),('homeroom_teacher','都别说话了，到点了，好好读课文！')]],
 'evening':[line('zhao_mugei',t) for t in ['又上一天课，一会还有晚自习','能不能不上课啊，','把学校炸了吧，我不想上课','算了去整点辣肺子炒饭']],
 'window':[line('zhao_mugei','我造你的，这什么东西')],
 'entrance':[line('zhao_mugei','什么玩意装神弄鬼的，我惧你？')],
 'encounter':[line('zhao_mugei','！'),line('fei_yan','卧槽给子你他妈怎么在这'),line('fei_yan','算了，等我一会')],
 'reveal':[line(a,t) for a,t in [('fei_yan','不是你不是应该去踢球么，怎么跑这来了，你是不是gei啊'),('zhao_mugei','你tm才是gei呢，我看里面整的跟爆炸了似的过来看看'),('zhao_mugei','你刚才用的啥玩意啊，魔法啊'),('fei_yan','对啊'),('fei_yan','其实不瞒你了，我是一个魔法师'),('zhao_mugei','奥，然后呢'),('fei_yan','不是你不是应该表现的特别震惊么，然后求我教你魔法，把你带入魔法之路！'),('zhao_mugei','你说学我就学啊，你太gei了'),('fei_yan','你个gei处，你得学，你已经沾染上魔力了，以后会有怪物找上你的'),('fei_yan','你不学魔法哪天让人草饲在外面了'),('fei_yan','也不知道学校怎么了，突然出现这么多怪物，我本来只想度过一段和平的校园生活'),('fei_yan','别人，普通校园生活。我，处理怪物。就很……你们懂吧'),('zhao_mugei','你太贱了，你都这么说了，那我肯定得学啊'),('fei_yan','你看好吧')]],
 'gifts':[line('fei_yan','这个拿着，有用'),line('system','获得特制校服、基础护符、基础魔法书。\n等级 +1，习得烈焰弹、闪电链、冻结术、光弹。'),line('fei_yan','先回去上晚自习吧，你自己看吧，明天我们再商量'),line('zhao_mugei','行吧')]}
roles={
 'lao_li':['工具我收好了，别踩到线。','想改点东西？材料备齐了再来，我给你做。'],
 'lao_chou':['别急，先把条件列出来。','实验楼后面的动静不对。先看清楚，再从正门进去。'],
 'fei_yan':['你又整什么活呢，gei子？','魔法不是硬莽，先看属性和剩下多少蓝。'],
 'lao_ao':['这段节奏还差一点。','有些事不能装作没看见。费眼那边我会留意。'],
 'lao_shuo':['身体是本钱，战斗也得讲纪律。','装备检查好再出发，别光顾着逞强。'],
 'yang_zi':['走啊，下课跑两圈？我等你。','你别急，我有个点子。先看看学校哪儿不对劲。'],
 'lao_dong':['先观察。','别浪费魔力。'],
 'la_jiao':['出勤表在我这儿。晚自习出去得先说清楚。','回来别忘了签到。'],
 'gou_ga':['看起来很顺利嘛。你真觉得会一直这样？','你猜我知道些什么？'],
 'wr':['这本书还挺有意思，你想看吗？','有些知识，可不在课本里。']}
write('剧情配置.json',{'version':1,'chapter':'part_1','classroom':{'building':'B01','floor':3,'kind':'classroom','room':0},'lab_room':1,'dialogues':dialogues,'role_greetings':roles,'effects_index':'资源/原项目/data/magic_effects_01.json','end_hint':'第一章已完成。明天再和费眼商量；目前可以自由探索、学习技能和挑战实验楼怪物。'})
tasks=read('任务配置.json');tasks['tasks']=[t for t in tasks['tasks'] if t['id'] not in ['part_1','after_part_1']]
steps=[('去秋实楼三楼最左侧十班，在靠窗倒数第二排自己的白圈座位按 E。','story/morning'),('去实验楼北侧（后墙）查看闪光的窗户，走近白圈按 E。','story/window'),('绕到实验楼南侧正门，按 E 进入。','story/entrance'),('在实验楼一楼找到震动的 102 教室门，走近后按 E。','story/initiation'),('返回秋实楼十班，在自己的白圈座位按 E 上晚自习。','story/complete')]
tasks['tasks'].insert(0,{'id':'part_1','type':'main','title':'第一章 · 窗后的闪光','auto_start':True,'steps':[{'hint':h,'event':e} for h,e in steps]})
tasks['tasks'].insert(1,{'id':'after_part_1','type':'guide','title':'明日再议','auto_start':True,'prerequisites':['part_1'],'steps':[{'hint':'第一章已结束。与费眼学习法术，与牢李委托制作物品，或找牢硕购买装备、学习战斗专精。后续剧情尚未开放。'}]})
write('任务配置.json',tasks)
print('Story data ready; copied',len(copied),'assets without changing sources.')
